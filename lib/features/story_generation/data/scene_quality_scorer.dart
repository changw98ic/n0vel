import '../../../app/llm/app_llm_canonical_hash.dart';
import '../domain/contracts/settings_contract.dart';

import 'evaluation/agent_evaluation_trace_context.dart';
import 'generation_evidence_fingerprints.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

final Expando<VerifiedSceneQualityProvenance> _verifiedSceneQualityProvenance =
    Expando<VerifiedSceneQualityProvenance>(
      'verified-scene-quality-provenance',
    );

/// Runtime-only proof that one exact score object came from the frozen quality
/// parser applied to one durably admitted provider outcome.
@pragma('vm:isolate-unsendable')
final class VerifiedSceneQualityProvenance {
  const VerifiedSceneQualityProvenance._({
    required this.outcome,
    required this.parsedOutputDigest,
  });

  final StoryGenerationFormalOutcomeProvenance outcome;
  final String parsedOutputDigest;
}

/// Burns and returns provenance for the exact score identity once.
///
/// A value-equal public DTO, a checkpoint rehydration, or any mismatched
/// presentation consumes no authority and cannot be retried with corrections.
VerifiedSceneQualityProvenance? consumeVerifiedSceneQualityProvenance({
  required SceneQualityScore score,
  required StoryGenerationEvaluationPhase phase,
  required ArtifactDigest artifactDigest,
}) {
  final provenance = _verifiedSceneQualityProvenance[score];
  _verifiedSceneQualityProvenance[score] = null;
  final promptIdentity = StoryPromptRegistry.production.invocation(
    stageId: 'quality-gate',
    callSiteId: 'quality-scorer',
  );
  if (provenance == null ||
      phase != StoryGenerationEvaluationPhase.quality ||
      provenance.outcome.stageId != 'quality-gate' ||
      provenance.outcome.callSiteId != 'quality-scorer' ||
      provenance.outcome.evaluationPhase != phase ||
      provenance.outcome.promptReleaseContentHash !=
          promptIdentity.release.contentHash ||
      provenance.outcome.parserRelease !=
          promptIdentity.release.parserRelease ||
      !_sameArtifactDigest(
        provenance.outcome.evaluatedArtifactDigest,
        artifactDigest,
      ) ||
      provenance.parsedOutputDigest !=
          storyGenerationParsedOutputDigest(score.toJson())) {
    return null;
  }
  return provenance;
}

final class SceneQualityScorer implements SceneQualityScorerService {
  SceneQualityScorer({required StoryGenerationSettingsContract settingsStore})
    : _settingsStore = settingsStore;

  final StoryGenerationSettingsContract _settingsStore;

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async {
    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'quality-gate',
      callSiteId: 'quality-scorer',
    );
    final resolvedVariables = <String, Object?>{
      'sceneTitle': _compact(brief.sceneTitle, maxChars: 40),
      'sceneSummary': _compact(brief.sceneSummary, maxChars: 80),
      'director': _compact(director.text, maxChars: 120),
      'prose': prose.text,
      'review': _compact(review.editorialFeedback, maxChars: 1200),
      'faithfulnessContext': _faithfulnessContext(brief),
    };
    final messages = promptIdentity.render(resolvedVariables).messages;
    final promptEvidence = promptIdentity.evidence(
      messages,
      resolvedVariables: resolvedVariables,
    );
    const evaluationPhase = StoryGenerationEvaluationPhase.quality;
    final evaluatedArtifactDigest = ArtifactDigest.fromUtf8String(prose.text);
    final currentEvaluationScope = StoryGenerationEvaluationScope.current;
    if (currentEvaluationScope != null &&
        (currentEvaluationScope.phase != evaluationPhase ||
            !_sameArtifactDigest(
              currentEvaluationScope.artifactDigest,
              evaluatedArtifactDigest,
            ))) {
      throw StoryGenerationEvidencePreflightFailure(
        'scene quality score does not match the runner evaluation scope',
        code: 'story_generation_quality_scope_mismatch',
      );
    }
    final evaluationTrace = AgentEvaluationTraceContext.current;
    final evaluationBundleHash =
        evaluationTrace?.evaluationBundleHash ??
        AppLlmCanonicalHash.domainHash(
          'scene-quality-evaluation-bundle-v1',
          <String, Object?>{
            'promptReleaseContentHash': promptIdentity.release.contentHash,
            'parserRelease': promptIdentity.release.parserRelease,
            'phase': evaluationPhase.name,
          },
        );
    final result = await StoryGenerationEvaluationScope.run(
      phase: evaluationPhase,
      artifactText: prose.text,
      body: () => requestFormalStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        promptInvocation: promptIdentity,
        promptInvocationEvidence: promptEvidence,
        messages: messages,
        evaluationFingerprintSeed: StoryGenerationEvaluationFingerprintSeed(
          artifactDigest: evaluatedArtifactDigest,
          evaluationBundleHash: evaluationBundleHash,
          judgeInput: <String, Object?>{
            'role': storyGenerationEvaluationJudgeInput(
              phase: evaluationPhase,
              stageId: promptIdentity.callSite.stageId,
              callSiteId: promptIdentity.callSite.callSiteId,
              artifactDigest: evaluatedArtifactDigest,
            ),
            'renderedMessagesDigest': promptEvidence.renderedMessagesDigest,
          },
          rubricHash: storyGenerationEvaluationRubricHash(
            phase: evaluationPhase,
            promptInvocation: promptIdentity,
          ),
          blindingPolicy: evaluationTrace == null
              ? 'story-generation-runtime-evaluation-v1'
              : 'formal-evaluation-context-v1',
        ),
        traceName: 'scene_quality_scoring',
        traceMetadata: {
          'chapterId': brief.chapterId,
          'sceneId': brief.sceneId,
          'sceneTitle': brief.sceneTitle,
        },
      ),
    );
    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene quality scoring failed.');
    }

    final score = parseScore(
      result.text!.trim(),
      requireExtendedRubric:
          brief.formalExecution ||
          brief.metadata['requireExtendedQualityRubric'] == true,
    );
    final outcomeProvenance = takeStoryGenerationFormalOutcomeAdmission(
      result: result,
      stageId: promptIdentity.callSite.stageId,
      callSiteId: promptIdentity.callSite.callSiteId,
      parserRelease: promptIdentity.release.parserRelease,
      evaluationPhase: evaluationPhase,
      evaluatedArtifactDigest: evaluatedArtifactDigest,
    )?.consume();
    if (outcomeProvenance == null) {
      if (StoryGenerationRetryScope.current?.allowsContentRedraw == false) {
        throw StoryGenerationEvidenceIntegrityFailure(
          'formal quality score has no admitted provider outcome provenance',
        );
      }
      return score;
    }
    final parsedOutputDigest = storyGenerationParsedOutputDigest(
      score.toJson(),
    );
    _verifiedSceneQualityProvenance[score] = VerifiedSceneQualityProvenance._(
      outcome: outcomeProvenance,
      parsedOutputDigest: parsedOutputDigest,
    );
    return score;
  }

  /// Parses a quality score from raw LLM output text.
  static SceneQualityScore parseScore(
    String rawText, {
    bool requireExtendedRubric = false,
  }) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    double? prose;
    double? coherence;
    double? character;
    double? completeness;
    double? style;
    double? imagery;
    double? rhythm;
    double? faithfulness;
    double? overall;
    String summary = '';
    final seenFields = <String>{};

    for (final line in lines) {
      final normalized = _normalizeScoreLine(line);
      if (normalized.startsWith('文笔：')) {
        _recordUniqueField(seenFields, '文笔', rawText);
        prose = _extractScore(normalized);
      } else if (normalized.startsWith('连贯：')) {
        _recordUniqueField(seenFields, '连贯', rawText);
        coherence = _extractScore(normalized);
      } else if (normalized.startsWith('角色：')) {
        _recordUniqueField(seenFields, '角色', rawText);
        character = _extractScore(normalized);
      } else if (normalized.startsWith('完整：')) {
        _recordUniqueField(seenFields, '完整', rawText);
        completeness = _extractScore(normalized);
      } else if (normalized.startsWith('文风：')) {
        _recordUniqueField(seenFields, '文风', rawText);
        style = _extractScore(normalized);
      } else if (normalized.startsWith('修辞：')) {
        _recordUniqueField(seenFields, '修辞', rawText);
        imagery = _extractScore(normalized);
      } else if (normalized.startsWith('节奏：')) {
        _recordUniqueField(seenFields, '节奏', rawText);
        rhythm = _extractScore(normalized);
      } else if (normalized.startsWith('忠实：')) {
        _recordUniqueField(seenFields, '忠实', rawText);
        faithfulness = _extractScore(normalized);
      } else if (normalized.startsWith('综合：')) {
        _recordUniqueField(seenFields, '综合', rawText);
        overall = _extractScore(normalized);
      } else if (normalized.startsWith('总结：')) {
        _recordUniqueField(seenFields, '总结', rawText);
        summary = normalized.substring(3).trim();
      }
    }

    if (prose == null ||
        coherence == null ||
        character == null ||
        completeness == null ||
        overall == null ||
        summary.isEmpty) {
      throw FormatException(
        'Quality scorecard is incomplete or malformed; all five scores and a summary are required.',
        rawText,
      );
    }

    if (requireExtendedRubric &&
        (style == null ||
            imagery == null ||
            rhythm == null ||
            faithfulness == null)) {
      throw FormatException(
        'Formal quality scorecard is missing 文风、修辞、节奏或忠实评分。',
        rawText,
      );
    }

    return SceneQualityScore(
      overall: overall,
      prose: prose,
      coherence: coherence,
      character: character,
      completeness: completeness,
      style: style,
      imagery: imagery,
      rhythm: rhythm,
      faithfulness: faithfulness,
      summary: summary,
    );
  }

  String _faithfulnessContext(SceneBrief brief) {
    final parts = <String>[
      '允许依据：',
      if (brief.sceneSummary.trim().isNotEmpty) '场景概要：${brief.sceneSummary}',
      if (brief.targetBeat.trim().isNotEmpty) '目标节拍：${brief.targetBeat}',
      if (brief.cast.isNotEmpty)
        '出场角色：${brief.cast.map((member) => '${member.name}(${member.role})').join('、')}',
      if (brief.worldNodeIds.isNotEmpty) '世界节点：${brief.worldNodeIds.join('、')}',
      if (brief.characterProfiles.isNotEmpty)
        '角色资料：${brief.characterProfiles.map((profile) => profile.toJson()).join('；')}',
      if (brief.knowledgeAtoms.isNotEmpty)
        '知识边界：${brief.knowledgeAtoms.map((atom) => '${atom.ownerScope}:${atom.content}').join('；')}',
    ];
    return _compact(parts.join('\n'), maxChars: 2200);
  }

  static double? _extractScore(String line) {
    final colonIndex = line.indexOf('：');
    if (colonIndex < 0) return null;
    final raw = line.substring(colonIndex + 1).trim();
    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)').firstMatch(raw);
    final value = match == null ? null : double.tryParse(match.group(1)!);
    if (value == null || !value.isFinite || value < 0 || value > 100) {
      return null;
    }
    return value;
  }

  static String _normalizeScoreLine(String line) {
    var normalized = line
        .replaceFirst(RegExp(r'^\s*(?:[-*]\s+|\d+[.)]\s*)'), '')
        .replaceAll('**', '')
        .replaceAll('`', '')
        .trim();
    // GLM sometimes emits an ASCII colon even when the Chinese rubric uses
    // the full-width form. Accept the transport variation without weakening
    // the required dimension set or numeric bounds.
    for (final label in const <String>[
      '文笔',
      '连贯',
      '角色',
      '完整',
      '文风',
      '修辞',
      '节奏',
      '忠实',
      '综合',
      '总结',
    ]) {
      normalized = normalized.replaceFirst(
        RegExp('^${RegExp.escape(label)}\\s*:'),
        '$label：',
      );
    }
    return normalized;
  }

  static void _recordUniqueField(
    Set<String> seenFields,
    String field,
    String rawText,
  ) {
    if (!seenFields.add(field)) {
      throw FormatException('Duplicate quality score field: $field.', rawText);
    }
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}

bool _sameArtifactDigest(ArtifactDigest left, ArtifactDigest right) =>
    left.digest == right.digest && left.byteLength == right.byteLength;
