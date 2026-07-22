import '../../../app/llm/app_llm_client.dart';
import '../../../app/llm/app_llm_canonical_hash.dart';
import '../domain/contracts/settings_contract.dart';

import 'evaluation/agent_evaluation_trace_context.dart';
import 'generation_evidence_fingerprints.dart';
import 'scene_review_models.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import '../domain/contracts/memory_policy.dart';
import '../domain/contracts/memory_writeback_gate.dart' as gate;
import '../domain/scene_models.dart';
import '../domain/memory_models.dart';
import '../domain/story_pipeline_interfaces.dart';
import 'canon_keeper.dart';
import 'scene_roleplay_session_models.dart';
import 'scene_cast_roleplay_policy.dart';
import 'scene_hard_gates.dart';
import 'scene_type_classifier.dart';
import 'scene_type_prompts.dart';
import 'story_generation_formatter_trace.dart';
import 'formal_evaluation_policy.dart';

final Expando<VerifiedSceneReviewPassProvenance>
_verifiedSceneReviewPassProvenance = Expando<VerifiedSceneReviewPassProvenance>(
  'verified-scene-review-pass-provenance',
);
final Expando<VerifiedSceneReviewProvenance> _verifiedSceneReviewProvenance =
    Expando<VerifiedSceneReviewProvenance>('verified-scene-review-provenance');

/// One ordered, frozen-parser pass within an aggregate review proof.
@pragma('vm:isolate-unsendable')
final class VerifiedSceneReviewPassProvenance {
  const VerifiedSceneReviewPassProvenance._({
    required this.outcome,
    required this.parsedOutputDigest,
  });

  final StoryGenerationFormalOutcomeProvenance outcome;
  final String parsedOutputDigest;
}

/// Runtime-only proof that one exact aggregate review came from its ordered
/// frozen provider passes and no local substitution.
@pragma('vm:isolate-unsendable')
final class VerifiedSceneReviewProvenance {
  VerifiedSceneReviewProvenance._({
    required List<VerifiedSceneReviewPassProvenance> orderedPasses,
    required this.parsedOutputDigest,
  }) : orderedPasses = List<VerifiedSceneReviewPassProvenance>.unmodifiable(
         orderedPasses,
       );

  final List<VerifiedSceneReviewPassProvenance> orderedPasses;

  List<StoryGenerationFormalOutcomeProvenance> get orderedOutcomes =>
      List<StoryGenerationFormalOutcomeProvenance>.unmodifiable(
        orderedPasses.map((pass) => pass.outcome),
      );
  final String parsedOutputDigest;
}

/// Burns and returns provenance for the exact aggregate review identity once.
VerifiedSceneReviewProvenance? consumeVerifiedSceneReviewProvenance({
  required SceneReviewResult result,
  required StoryGenerationEvaluationPhase phase,
  required ArtifactDigest artifactDigest,
}) {
  final provenance = _verifiedSceneReviewProvenance[result];
  _verifiedSceneReviewProvenance[result] = null;
  final bindings = _reviewProviderPassBindings(result);
  if (provenance == null ||
      !_isReviewEvaluationPhase(phase) ||
      provenance.orderedPasses.length != bindings.length ||
      provenance.parsedOutputDigest !=
          storyGenerationParsedOutputDigest(
            canonicalSceneReviewEvaluationOutput(result),
          )) {
    return null;
  }
  for (var index = 0; index < bindings.length; index += 1) {
    final passProvenance = provenance.orderedPasses[index];
    final outcome = passProvenance.outcome;
    final binding = bindings[index];
    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'review',
      callSiteId: binding.callSiteId,
    );
    if (outcome.stageId != 'review' ||
        outcome.callSiteId != binding.callSiteId ||
        outcome.evaluationPhase != phase ||
        !_sameReviewArtifactDigest(
          outcome.evaluatedArtifactDigest,
          artifactDigest,
        ) ||
        outcome.promptReleaseContentHash !=
            promptIdentity.release.contentHash ||
        outcome.parserRelease != promptIdentity.release.parserRelease ||
        passProvenance.parsedOutputDigest !=
            storyGenerationParsedOutputDigest(
              _canonicalReviewPass(binding.pass),
            )) {
      return null;
    }
  }
  return provenance;
}

/// Stable, authority-free representation of the exact parsed review output.
///
/// This function is public so finalization and proof payloads can recompute
/// the same digest without duplicating a second canonicalization contract.
Map<String, Object?> canonicalSceneReviewEvaluationOutput(
  SceneReviewResult result,
) => <String, Object?>{
  'judge': _canonicalReviewPass(result.judge),
  'consistency': _canonicalReviewPass(result.consistency),
  'readerFlow': _canonicalNullableReviewPass(result.readerFlow),
  'lexicon': _canonicalNullableReviewPass(result.lexicon),
  'adjudication': _canonicalNullableReviewPass(result.adjudication),
  'roleplayFidelity': _canonicalNullableReviewPass(result.roleplayFidelity),
  'decision': result.decision.name,
  'refinementGuidance': _canonicalRefinementGuidance(result.refinementGuidance),
};

final class SceneReviewCoordinator implements SceneReviewService {
  SceneReviewCoordinator({
    required StoryGenerationSettingsContract settingsStore,
    StoryGenerationFormatterTraceSink? formatterTraceSink,
    this.hardGatesEnabled = true,
    CanonKeeper? canonKeeper,
  }) : _settingsStore = settingsStore,
       _formatterTraceSink = formatterTraceSink,
       _canonKeeper = canonKeeper;

  final StoryGenerationSettingsContract _settingsStore;
  final StoryGenerationFormatterTraceSink? _formatterTraceSink;
  final bool hardGatesEnabled;
  final CanonKeeper? _canonKeeper;
  final SceneTypeClassifier _typeClassifier = SceneTypeClassifier();
  final SceneTypePrompts _typePrompts = const SceneTypePrompts();

  static const List<SceneReviewCategory> _judgeCategories = [
    SceneReviewCategory.prose,
    SceneReviewCategory.scenePlan,
  ];

  static const List<SceneReviewCategory> _consistencyCategories = [
    SceneReviewCategory.chapterPlan,
    SceneReviewCategory.continuity,
    SceneReviewCategory.characterState,
    SceneReviewCategory.worldState,
  ];

  @override
  Future<SceneReviewResult> review({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    bool enableReaderFlowReview = false,
    bool enableLexiconReview = false,
    List<StoryMemoryChunk> canonFacts = const [],
  }) async {
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    if (brief.metadata['localReviewOnly'] == true) {
      return _localReviewResult(
        brief: brief,
        prose: prose,
        canonFacts: canonFacts,
      );
    }
    final evaluationPhase = _reviewEvaluationPhaseFor(prose.text);

    final judgeCategories = [
      ..._judgeCategories,
      if (roleplaySession != null && !roleplaySession.isEmpty)
        SceneReviewCategory.roleplayFidelity,
    ];
    // Each reviewer below is a distinct provider request. Do not derive a
    // nominally independent council member from another member's response:
    // that would certify correlated evidence as if it were independent.
    final judge = await _runReviewPass(
      passName: 'scene judge review',
      taskType: 'scene_judge_review',
      passLabel: 'judge',
      categories: judgeCategories,
      brief: brief,
      director: director,
      roleOutputs: roleOutputs,
      prose: prose,
      roleplaySession: roleplaySession,
      retrievalPack: retrievalPack,
      canonFacts: canonFacts,
      evaluationPhase: evaluationPhase,
    );
    final consistency = await _runReviewPass(
      passName: 'scene consistency review',
      taskType: 'scene_consistency_review',
      passLabel: 'consistency',
      categories: _consistencyCategories,
      brief: brief,
      director: director,
      roleOutputs: roleOutputs,
      prose: prose,
      roleplaySession: roleplaySession,
      retrievalPack: retrievalPack,
      canonFacts: canonFacts,
      evaluationPhase: evaluationPhase,
    );
    final readerFlow = enableReaderFlowReview
        ? await _runReviewPass(
            passName: 'scene reader-flow review',
            taskType: 'scene_reader_flow_review',
            passLabel: 'reader_flow',
            categories: const [SceneReviewCategory.prose],
            brief: brief,
            director: director,
            roleOutputs: roleOutputs,
            prose: prose,
            roleplaySession: roleplaySession,
            retrievalPack: retrievalPack,
            canonFacts: canonFacts,
            evaluationPhase: evaluationPhase,
          )
        : null;
    final lexicon = enableLexiconReview
        ? await _runReviewPass(
            passName: 'scene lexicon review',
            taskType: 'scene_lexicon_review',
            passLabel: 'lexicon',
            categories: const [SceneReviewCategory.prose],
            brief: brief,
            director: director,
            roleOutputs: roleOutputs,
            prose: prose,
            roleplaySession: roleplaySession,
            retrievalPack: retrievalPack,
            canonFacts: canonFacts,
            evaluationPhase: evaluationPhase,
          )
        : null;
    final adjudication = _needsReplanAdjudication(judge, consistency)
        ? await _runReplanAdjudication(
            brief: brief,
            director: director,
            roleOutputs: roleOutputs,
            prose: prose,
            roleplaySession: roleplaySession,
            retrievalPack: retrievalPack,
            canonFacts: canonFacts,
            judge: judge,
            consistency: consistency,
            evaluationPhase: evaluationPhase,
          )
        : null;
    final reviewResult = SceneReviewResult(
      judge: judge,
      consistency: consistency,
      adjudication: adjudication,
      readerFlow: readerFlow,
      lexicon: lexicon,
      decision: _deriveDecision(
        judge: judge,
        consistency: consistency,
        adjudication: adjudication,
        readerFlow: readerFlow,
        lexicon: lexicon,
      ),
    );
    final aggregateResult = SceneReviewResult(
      judge: reviewResult.judge,
      consistency: reviewResult.consistency,
      adjudication: reviewResult.adjudication,
      readerFlow: reviewResult.readerFlow,
      lexicon: reviewResult.lexicon,
      decision: reviewResult.decision,
      refinementGuidance: reviewResult.synthesizeGuidance(),
    );
    _registerVerifiedReviewProvenance(
      result: aggregateResult,
      phase: evaluationPhase,
      artifactDigest: ArtifactDigest.fromUtf8String(prose.text),
    );
    return aggregateResult;
  }

  StoryGenerationEvaluationPhase _reviewEvaluationPhaseFor(
    String artifactText,
  ) {
    final current = StoryGenerationEvaluationScope.current;
    if (current == null) {
      return StoryGenerationEvaluationPhase.preliminaryReview;
    }
    if (!_isReviewEvaluationPhase(current.phase)) {
      throw StoryGenerationEvidencePreflightFailure(
        'scene review cannot run under a non-review evaluation phase',
        code: 'story_generation_review_phase_mismatch',
      );
    }
    final artifactDigest = ArtifactDigest.fromUtf8String(artifactText);
    if (!_sameReviewArtifactDigest(current.artifactDigest, artifactDigest)) {
      throw StoryGenerationEvidencePreflightFailure(
        'scene review artifact does not match the runner evaluation scope',
        code: 'story_generation_review_artifact_mismatch',
      );
    }
    return current.phase;
  }

  bool _needsReplanAdjudication(
    SceneReviewPassResult judge,
    SceneReviewPassResult consistency,
  ) {
    return (judge.status == SceneReviewStatus.replanScene &&
            consistency.status == SceneReviewStatus.pass) ||
        (consistency.status == SceneReviewStatus.replanScene &&
            judge.status == SceneReviewStatus.pass);
  }

  Future<SceneReviewPassResult> _runReplanAdjudication({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    required SceneReviewPassResult judge,
    required SceneReviewPassResult consistency,
    required StoryGenerationEvaluationPhase evaluationPhase,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    List<StoryMemoryChunk> canonFacts = const [],
  }) {
    return _runReviewPass(
      passName: 'scene review adjudication',
      taskType: 'scene_review_adjudication',
      passLabel: 'adjudication',
      categories: const [
        SceneReviewCategory.prose,
        SceneReviewCategory.scenePlan,
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
      ],
      brief: brief,
      director: director,
      roleOutputs: roleOutputs,
      prose: prose,
      roleplaySession: roleplaySession,
      retrievalPack: retrievalPack,
      canonFacts: canonFacts,
      evaluationPhase: evaluationPhase,
      adjudicationContext:
          '裁决任务：Judge 与 Consistency 对是否必须重规划存在分歧。'
          '只根据正文、导演要求和下列已记录意见裁决。\n'
          'Judge：${judge.rawText}\n'
          'Consistency：${consistency.rawText}\n'
          '只有在正文缺失不可由一次改写修复的核心剧情功能，或与导演/既有事实直接矛盾时，才可选 REPLAN_SCENE。'
          '若正文已呈现具体目标、阻碍及局面变化/下一压力，不得仅以“压力不够”“威胁悬浮”等主观措辞否决；此时应选 PASS 或针对可定位文本问题选 REWRITE_PROSE。',
    );
  }

  SceneReviewResult _localReviewResult({
    required SceneBrief brief,
    required SceneProseDraft prose,
    List<StoryMemoryChunk> canonFacts = const [],
  }) {
    final hasDraft = prose.text.trim().isNotEmpty;
    final hardGateViolation = hasDraft
        ? sceneHardGateViolationText(
            brief: brief,
            proseText: prose.text,
            enabled: hardGatesEnabled,
          )
        : '';
    var passed = hasDraft && hardGateViolation.isEmpty;

    // Canon consistency check: only when hard gates passed.
    String? canonReason;
    if (passed && _canonKeeper != null && canonFacts.isNotEmpty) {
      final write = gate.ProposedWrite(
        tier: MemoryTier.canon,
        content: prose.text,
      );
      final issues = _canonKeeper.checkConsistency(write, canonFacts);
      if (issues.isNotEmpty) {
        passed = false;
        canonReason = 'Canon consistency violation: ${issues.join("; ")}';
      }
    }

    final status = passed
        ? SceneReviewStatus.pass
        : SceneReviewStatus.rewriteProse;
    final decision = passed
        ? SceneReviewDecision.pass
        : SceneReviewDecision.rewriteProse;
    final reason = !hasDraft
        ? '正文为空，需要补写。'
        : hardGateViolation.isNotEmpty
        ? hardGateViolation
        : canonReason ?? '本地结构化审查通过。';
    final judge = SceneReviewPassResult(
      status: status,
      reason: reason,
      rawText: '决定：${passed ? 'PASS' : 'REWRITE_PROSE'}\n原因：$reason',
      categories: const [
        SceneReviewCategory.prose,
        SceneReviewCategory.scenePlan,
      ],
    );
    final consistency = SceneReviewPassResult(
      status: status,
      reason: reason,
      rawText: '决定：${passed ? 'PASS' : 'REWRITE_PROSE'}\n原因：$reason',
      categories: const [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
        SceneReviewCategory.characterState,
        SceneReviewCategory.worldState,
      ],
    );
    final result = SceneReviewResult(
      judge: judge,
      consistency: consistency,
      decision: decision,
    );
    return SceneReviewResult(
      judge: result.judge,
      consistency: result.consistency,
      decision: result.decision,
      refinementGuidance: result.synthesizeGuidance(),
    );
  }

  Future<SceneReviewPassResult> _runReviewPass({
    required String passName,
    required String taskType,
    required String passLabel,
    required List<SceneReviewCategory> categories,
    required StoryGenerationEvaluationPhase evaluationPhase,
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    List<StoryMemoryChunk> canonFacts = const [],
    String? adjudicationContext,
  }) async {
    final formalEvaluation = FormalEvaluationPolicy.isActive(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    final evidenceSection = _buildEvidenceSection(retrievalPack);
    final noninteractiveCastBoundary = noninteractiveCastBoundaryText(brief);
    final reviewCallSite = switch (passLabel) {
      'judge' => 'judge',
      'consistency' => 'consistency',
      'reader_flow' => 'reader-flow',
      'lexicon' => 'lexicon',
      'adjudication' => 'adjudication',
      _ => throw StateError('Unknown formal review pass: $passLabel'),
    };
    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'review',
      callSiteId: reviewCallSite,
    );
    final hasRoleplay = roleplaySession != null && !roleplaySession.isEmpty;
    // Preliminary and final councils may legitimately inspect byte-identical
    // prose when polish is a no-op. Bind the phase into a frozen rendered
    // variable so their durable logical-attempt identities cannot collide.
    final phaseBoundTaskType = '$taskType:${evaluationPhase.name}';
    final resolvedVariables = <String, Object?>{
      'taskType': phaseBoundTaskType,
      'passLabel': passLabel,
      'categories': _categoryList(categories),
      'sceneNumber': brief.sceneIndex + 1,
      'totalScenes': brief.totalScenesInChapter,
      'openingBoundary': brief.sceneIndex == 0
          ? '⚠️ 这是本章首个场景，前50字必须包含悬念信号。'
          : '',
      'closingBoundary':
          brief.totalScenesInChapter > 0 &&
              brief.sceneIndex == brief.totalScenesInChapter - 1
          ? '⚠️ 这是本章最后场景，结尾必须留下未决冲突或悬念钩子。'
          : '',
      'sceneTitle': _compact(brief.sceneTitle, maxChars: 40),
      'director': _compact(director.text, maxChars: 120),
      'noninteractiveBoundary': noninteractiveCastBoundary,
      'roleSummary': _roleSummary(roleOutputs),
      'roleplayProcess': hasRoleplay ? roleplaySession.toPromptText() : '',
      'roleplayGuidance': hasRoleplay
          ? '忠实性指引：正文围绕角色扮演过程中的可见动作、对白、裁决事实和局面推进展开；关键互动、裁决事实、角色可见信息共同决定评审结果。'
          : '',
      'prose': prose.text,
      'adjudicationContext': adjudicationContext ?? '',
      'evidenceSection': evidenceSection,
      'reviewCriteria': _typePrompts.reviewCriteria(
        _typeClassifier.classify(brief),
      ),
    };
    final messages = promptIdentity.render(resolvedVariables).messages;
    final promptEvidence = promptIdentity.evidence(
      messages,
      resolvedVariables: resolvedVariables,
    );
    final evaluatedArtifactDigest = ArtifactDigest.fromUtf8String(prose.text);
    final evaluationTrace = AgentEvaluationTraceContext.current;
    final evaluationBundleHash =
        evaluationTrace?.evaluationBundleHash ??
        AppLlmCanonicalHash.domainHash(
          'scene-review-evaluation-bundle-v1',
          <String, Object?>{
            'promptReleaseContentHash': promptIdentity.release.contentHash,
            'parserRelease': promptIdentity.release.parserRelease,
            'phase': evaluationPhase.name,
          },
        );
    Future<AppLlmChatResult> requestPass() =>
        requestFormalStoryGenerationPassWithRetry(
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
              'passLabel': passLabel,
              'categories': <String>[
                for (final category in categories) _categoryKey(category),
              ],
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
          traceName: taskType,
          traceMetadata: {
            'chapterId': brief.chapterId,
            'sceneId': brief.sceneId,
            'sceneTitle': brief.sceneTitle,
            'passLabel': passLabel,
            'reviewCategories': _categoryList(categories),
          },
        );
    final result = await (StoryGenerationEvaluationScope.current == null
        ? StoryGenerationEvaluationScope.run(
            phase: evaluationPhase,
            artifactText: prose.text,
            body: requestPass,
          )
        : requestPass());
    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene $passLabel review failed.');
    }

    final originalRawText = result.text!.trim();
    var rawText = originalRawText;
    var parsed = _parseReviewOutput(rawText, passLabel: passLabel);
    var exactProviderParsedOutput = !parsed.usedFallback;
    final noContentRedraw =
        StoryGenerationRetryScope.current?.allowsContentRedraw == false;
    var repairAttempted = false;
    String? repairedRawText;
    if (parsed.usedFallback && !noContentRedraw) {
      exactProviderParsedOutput = false;
      repairAttempted = true;
      final repaired = await _repairReviewFormat(
        passName: passName,
        passLabel: passLabel,
        rawText: rawText,
      );
      if (repaired != null && !repaired.parsed.usedFallback) {
        repairedRawText = repaired.rawText;
        rawText = repaired.rawText;
        parsed = repaired.parsed;
      } else if (repaired != null) {
        repairedRawText = repaired.rawText;
      }
    }
    if (parsed.usedFallback) {
      if (formalEvaluation || noContentRedraw) {
        throw StateError(
          noContentRedraw
              ? 'no-redraw scene $passLabel review output was malformed; '
                    'format repair redispatch is forbidden'
              : 'formal scene $passLabel review output remained malformed '
                    'after format repair',
        );
      }
    }
    final noninteractiveViolation = noninteractiveCastViolationText(
      brief,
      prose.text,
    );
    if (noninteractiveViolation.isNotEmpty &&
        parsed.status == SceneReviewStatus.pass) {
      exactProviderParsedOutput = false;
      parsed = _ParsedReviewOutput(
        status: SceneReviewStatus.rewriteProse,
        reason: noninteractiveViolation,
      );
      rawText = '决定：REWRITE_PROSE\n原因：$noninteractiveViolation';
    }

    final hardGateViolation = sceneHardGateViolationText(
      brief: brief,
      proseText: prose.text,
      enabled: hardGatesEnabled,
    );
    if (hardGateViolation.isNotEmpty &&
        parsed.status == SceneReviewStatus.pass) {
      exactProviderParsedOutput = false;
      parsed = _ParsedReviewOutput(
        status: SceneReviewStatus.rewriteProse,
        reason: hardGateViolation,
      );
      rawText = '决定：REWRITE_PROSE\n原因：$hardGateViolation';
    }

    // Canon consistency check: only when status is still pass.
    if (parsed.status == SceneReviewStatus.pass &&
        _canonKeeper != null &&
        canonFacts.isNotEmpty) {
      final write = gate.ProposedWrite(
        tier: MemoryTier.canon,
        content: prose.text,
      );
      final issues = _canonKeeper.checkConsistency(write, canonFacts);
      if (issues.isNotEmpty) {
        exactProviderParsedOutput = false;
        final canonReason = 'Canon consistency violation: ${issues.join("; ")}';
        parsed = _ParsedReviewOutput(
          status: SceneReviewStatus.rewriteProse,
          reason: canonReason,
        );
        rawText = '决定：REWRITE_PROSE\n原因：$canonReason';
      }
    }
    await _recordFormatterTrace(
      brief: brief,
      passName: passName,
      passLabel: passLabel,
      rawText: originalRawText,
      repairedText: repairedRawText,
      finalText: rawText,
      repairAttempted: repairAttempted,
      usedFallback: parsed.usedFallback,
    );
    final passResult = SceneReviewPassResult(
      status: parsed.status,
      reason: parsed.reason,
      rawText: rawText,
      categories: categories,
    );
    final outcome = takeStoryGenerationFormalOutcomeAdmission(
      result: result,
      stageId: promptIdentity.callSite.stageId,
      callSiteId: promptIdentity.callSite.callSiteId,
      parserRelease: promptIdentity.release.parserRelease,
      evaluationPhase: evaluationPhase,
      evaluatedArtifactDigest: evaluatedArtifactDigest,
    )?.consume();
    if (!exactProviderParsedOutput || outcome == null) {
      if (noContentRedraw) {
        throw StoryGenerationEvidenceIntegrityFailure(
          exactProviderParsedOutput
              ? 'formal scene $passLabel review has no admitted provider '
                    'outcome provenance'
              : 'formal scene $passLabel review was locally substituted '
                    'after provider parsing',
        );
      }
      return passResult;
    }
    _verifiedSceneReviewPassProvenance[passResult] =
        VerifiedSceneReviewPassProvenance._(
          outcome: outcome,
          parsedOutputDigest: storyGenerationParsedOutputDigest(
            _canonicalReviewPass(passResult),
          ),
        );
    return passResult;
  }

  Future<void> _recordFormatterTrace({
    required SceneBrief brief,
    required String passName,
    required String passLabel,
    required String rawText,
    required String? repairedText,
    required String finalText,
    required bool repairAttempted,
    required bool usedFallback,
  }) async {
    final sink = _formatterTraceSink;
    if (sink == null) return;
    try {
      await sink.record(
        StoryGenerationFormatterTraceEntry(
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          chapterId: brief.chapterId,
          sceneId: brief.sceneId,
          sceneTitle: brief.sceneTitle,
          formatter: 'scene_review',
          passName: passName,
          passLabel: passLabel,
          rawText: rawText,
          repairedText: repairedText,
          finalText: finalText,
          repairAttempted: repairAttempted,
          usedFallback: usedFallback,
        ),
      );
    } on Object {
      // Formatter tracing should never block review completion.
    }
  }

  Future<_RepairedReviewOutput?> _repairReviewFormat({
    required String passName,
    required String passLabel,
    required String rawText,
  }) async {
    final repairCallSite = switch (passLabel) {
      'judge' => 'format-repair-judge',
      'consistency' => 'format-repair-consistency',
      'reader_flow' => 'format-repair-reader-flow',
      'lexicon' => 'format-repair-lexicon',
      'adjudication' => 'format-repair-adjudication',
      _ => throw StateError('Unknown formal review repair pass: $passLabel'),
    };
    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'review',
      callSiteId: repairCallSite,
    );
    final resolvedVariables = <String, Object?>{'rawText': rawText};
    final messages = promptIdentity.render(resolvedVariables).messages;
    final result = await requestFormalStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      promptInvocation: promptIdentity,
      promptInvocationEvidence: promptIdentity.evidence(
        messages,
        resolvedVariables: resolvedVariables,
      ),
      messages: messages,
      maxTransientRetries: 1,
      traceName: 'scene_review_format_repair',
      traceMetadata: {'passLabel': passLabel, 'passName': passName},
    );
    if (!result.succeeded || result.text == null) {
      return null;
    }

    final repairedRaw = result.text!.trim();
    return _RepairedReviewOutput(
      rawText: repairedRaw,
      parsed: _parseReviewOutput(repairedRaw, passLabel: passLabel),
    );
  }

  /// Builds an evidence section from the retrieval pack for grounded review.
  String _buildEvidenceSection(StoryRetrievalPack? pack) {
    if (pack == null || pack.hits.isEmpty) return '';

    final acceptedFacts = pack.hits
        .where(
          (h) =>
              h.chunk.kind == MemorySourceKind.acceptedState ||
              h.chunk.kind == MemorySourceKind.worldFact,
        )
        .take(5)
        .map((h) => '- ${_compact(h.chunk.content, maxChars: 80)}')
        .toList();

    final sourceIds = <String>{
      for (final hit in pack.hits) ...hit.chunk.rootSourceIds,
    };

    final parts = <String>[];
    if (acceptedFacts.isNotEmpty) {
      parts.add('已知事实：');
      parts.addAll(acceptedFacts);
    }
    if (sourceIds.isNotEmpty) {
      parts.add('来源：${sourceIds.take(10).join(", ")}');
    }
    if (pack.deferredHitCount > 0) {
      parts.add('注意：${pack.deferredHitCount}条相关记录未包含在审查中');
    }

    return parts.isEmpty ? '' : '\n证据：\n${parts.join('\n')}';
  }

  /// Creates a repair query from a consistency failure for re-retrieval.
  StoryMemoryQuery createRepairQuery(SceneBrief brief, String failureReason) {
    return StoryMemoryQuery(
      projectId: brief.projectId ?? brief.chapterId,
      queryType: StoryMemoryQueryType.concreteFact,
      text: failureReason,
      tags: [
        ...brief.worldNodeIds,
        for (final c in brief.cast) 'char-${c.characterId}',
      ],
      scopeId: '${brief.projectId ?? brief.chapterId}:${brief.sceneId}',
      maxResults: 5,
      tokenBudget: 300,
    );
  }

  SceneReviewDecision _deriveDecision({
    required SceneReviewPassResult judge,
    required SceneReviewPassResult consistency,
    SceneReviewPassResult? adjudication,
    SceneReviewPassResult? readerFlow,
    SceneReviewPassResult? lexicon,
    SceneReviewPassResult? roleplayFidelity,
  }) {
    if (adjudication != null) {
      return switch (adjudication.status) {
        SceneReviewStatus.pass => SceneReviewDecision.pass,
        SceneReviewStatus.rewriteProse => SceneReviewDecision.rewriteProse,
        SceneReviewStatus.replanScene => SceneReviewDecision.replanScene,
      };
    }
    final allPasses = [
      judge,
      consistency,
      readerFlow,
      lexicon,
      roleplayFidelity,
    ];
    for (final pass in allPasses) {
      if (pass != null && pass.status == SceneReviewStatus.replanScene) {
        return SceneReviewDecision.replanScene;
      }
    }
    for (final pass in allPasses) {
      if (pass != null && pass.status == SceneReviewStatus.rewriteProse) {
        return SceneReviewDecision.rewriteProse;
      }
    }
    return SceneReviewDecision.pass;
  }

  _ParsedReviewOutput _parseReviewOutput(
    String rawText, {
    required String passLabel,
  }) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      return _malformedReviewFallback(rawText, passLabel: passLabel);
    }

    if (lines.length != 2) {
      return _malformedReviewFallback(rawText, passLabel: passLabel);
    }

    final status = _statusFromDecisionLine(lines.first);
    final reason = _reasonFromReasonLine(lines.last);
    if (status != null && reason != null) {
      return _ParsedReviewOutput(status: status, reason: reason);
    }

    return _malformedReviewFallback(rawText, passLabel: passLabel);
  }

  SceneReviewStatus? _statusFromDecisionLine(String line) {
    final normalizedLine = line.replaceFirst('：', ':').trim();
    final colonIndex = normalizedLine.indexOf(':');
    if (colonIndex < 0) return null;

    final label = normalizedLine.substring(0, colonIndex).trim().toLowerCase();
    if (label != '决定') return null;

    final value = normalizedLine
        .substring(colonIndex + 1)
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '_');

    if (value == 'PASS') {
      return SceneReviewStatus.pass;
    }
    if (value == 'REWRITE_PROSE') {
      return SceneReviewStatus.rewriteProse;
    }
    if (value == 'REPLAN_SCENE') {
      return SceneReviewStatus.replanScene;
    }

    return null;
  }

  String? _reasonFromReasonLine(String line) {
    final normalizedLine = line.replaceFirst('：', ':').trim();
    const label = '原因:';
    if (!normalizedLine.startsWith(label)) return null;
    return normalizedLine.substring(label.length).trim();
  }

  _ParsedReviewOutput _malformedReviewFallback(
    String rawText, {
    required String passLabel,
  }) {
    final parsedReason = _parseReason(rawText).trim();
    final reason = parsedReason.isNotEmpty
        ? '$passLabel评审决定格式异常，已降级为正文复核：$parsedReason'
        : '$passLabel评审决定格式异常，已降级为正文复核。原始输出：'
              '${_compact(rawText, maxChars: 120)}';
    return _ParsedReviewOutput(
      status: SceneReviewStatus.rewriteProse,
      reason: reason,
      usedFallback: true,
    );
  }

  String _parseReason(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final reasonIndex = lines.indexWhere((line) => line.startsWith('原因：'));
    if (reasonIndex < 0) return '';
    return lines
        .skip(reasonIndex)
        .map((line) => line.replaceFirst(RegExp(r'^原因：\s*'), ''))
        .join('\n');
  }

  String _roleSummary(List<DynamicRoleAgentOutput> roleOutputs) {
    if (roleOutputs.isEmpty) {
      return '无';
    }
    return roleOutputs
        .map(
          (output) => '${output.name}：${_compact(output.text, maxChars: 80)}',
        )
        .join('；');
  }

  String _categoryList(List<SceneReviewCategory> categories) {
    return categories.map(_categoryKey).join(', ');
  }

  String _categoryKey(SceneReviewCategory category) {
    return switch (category) {
      SceneReviewCategory.prose => 'prose',
      SceneReviewCategory.scenePlan => 'scene_plan',
      SceneReviewCategory.chapterPlan => 'chapter_plan',
      SceneReviewCategory.continuity => 'continuity',
      SceneReviewCategory.characterState => 'character_state',
      SceneReviewCategory.worldState => 'world_state',
      SceneReviewCategory.roleplayFidelity => 'roleplay_fidelity',
      SceneReviewCategory.characterConsistency => 'character_consistency',
    };
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}

final class _ReviewProviderPassBinding {
  const _ReviewProviderPassBinding({
    required this.pass,
    required this.callSiteId,
  });

  final SceneReviewPassResult pass;
  final String callSiteId;
}

void _registerVerifiedReviewProvenance({
  required SceneReviewResult result,
  required StoryGenerationEvaluationPhase phase,
  required ArtifactDigest artifactDigest,
}) {
  final bindings = _reviewProviderPassBindings(result);
  final orderedPasses = <VerifiedSceneReviewPassProvenance>[];
  var complete = _isReviewEvaluationPhase(phase);
  for (final binding in bindings) {
    final passProvenance = _verifiedSceneReviewPassProvenance[binding.pass];
    _verifiedSceneReviewPassProvenance[binding.pass] = null;
    if (passProvenance == null) {
      complete = false;
      continue;
    }
    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'review',
      callSiteId: binding.callSiteId,
    );
    final outcome = passProvenance.outcome;
    final valid =
        outcome.stageId == 'review' &&
        outcome.callSiteId == binding.callSiteId &&
        outcome.evaluationPhase == phase &&
        _sameReviewArtifactDigest(
          outcome.evaluatedArtifactDigest,
          artifactDigest,
        ) &&
        outcome.promptReleaseContentHash ==
            promptIdentity.release.contentHash &&
        outcome.parserRelease == promptIdentity.release.parserRelease &&
        passProvenance.parsedOutputDigest ==
            storyGenerationParsedOutputDigest(
              _canonicalReviewPass(binding.pass),
            );
    if (!valid) {
      complete = false;
      continue;
    }
    orderedPasses.add(passProvenance);
  }
  if (!complete || orderedPasses.length != bindings.length) {
    if (StoryGenerationRetryScope.current?.allowsContentRedraw == false) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'formal aggregate scene review has incomplete parsed-result '
        'provenance',
      );
    }
    return;
  }
  _verifiedSceneReviewProvenance[result] = VerifiedSceneReviewProvenance._(
    orderedPasses: orderedPasses,
    parsedOutputDigest: storyGenerationParsedOutputDigest(
      canonicalSceneReviewEvaluationOutput(result),
    ),
  );
}

List<_ReviewProviderPassBinding> _reviewProviderPassBindings(
  SceneReviewResult result,
) => <_ReviewProviderPassBinding>[
  _ReviewProviderPassBinding(pass: result.judge, callSiteId: 'judge'),
  _ReviewProviderPassBinding(
    pass: result.consistency,
    callSiteId: 'consistency',
  ),
  if (result.readerFlow != null)
    _ReviewProviderPassBinding(
      pass: result.readerFlow!,
      callSiteId: 'reader-flow',
    ),
  if (result.lexicon != null)
    _ReviewProviderPassBinding(pass: result.lexicon!, callSiteId: 'lexicon'),
  if (result.adjudication != null)
    _ReviewProviderPassBinding(
      pass: result.adjudication!,
      callSiteId: 'adjudication',
    ),
];

Map<String, Object?> _canonicalReviewPass(
  SceneReviewPassResult pass,
) => <String, Object?>{
  'status': pass.status.name,
  'reason': pass.reason,
  'rawText': pass.rawText,
  'categories': <String>[for (final category in pass.categories) category.name],
};

Object? _canonicalNullableReviewPass(SceneReviewPassResult? pass) =>
    pass == null ? null : _canonicalReviewPass(pass);

Object? _canonicalRefinementGuidance(RefinementGuidance? guidance) =>
    guidance == null
    ? null
    : <String, Object?>{
        'plotIssues': <String>[...guidance.plotIssues],
        'consistencyFixes': <String>[...guidance.consistencyFixes],
        'styleTargets': <String>[...guidance.styleTargets],
        'preserve': <String>[...guidance.preserve],
        'focusInstruction': guidance.focusInstruction,
      };

bool _isReviewEvaluationPhase(StoryGenerationEvaluationPhase phase) =>
    phase == StoryGenerationEvaluationPhase.preliminaryReview ||
    phase == StoryGenerationEvaluationPhase.finalCouncil;

bool _sameReviewArtifactDigest(ArtifactDigest left, ArtifactDigest right) =>
    left.digest == right.digest && left.byteLength == right.byteLength;

class _ParsedReviewOutput {
  const _ParsedReviewOutput({
    required this.status,
    required this.reason,
    this.usedFallback = false,
  });

  final SceneReviewStatus status;
  final String reason;
  final bool usedFallback;
}

class _RepairedReviewOutput {
  const _RepairedReviewOutput({required this.rawText, required this.parsed});

  final String rawText;
  final _ParsedReviewOutput parsed;
}

/// Maps changed-aspect strings to their corresponding [SceneReviewCategory].
///
/// Aspect strings are matched against known prefixes. Unknown aspects are
/// ignored and produce no categories.
const _aspectToCategory = <String, SceneReviewCategory>{
  'prose': SceneReviewCategory.prose,
  'dialogue': SceneReviewCategory.prose,
  'narration': SceneReviewCategory.prose,
  'style': SceneReviewCategory.prose,
  'scene_plan': SceneReviewCategory.scenePlan,
  'beat': SceneReviewCategory.scenePlan,
  'pacing': SceneReviewCategory.scenePlan,
  'chapter_plan': SceneReviewCategory.chapterPlan,
  'chapter': SceneReviewCategory.chapterPlan,
  'arc': SceneReviewCategory.chapterPlan,
  'continuity': SceneReviewCategory.continuity,
  'timeline': SceneReviewCategory.continuity,
  'transition': SceneReviewCategory.continuity,
  'character_state': SceneReviewCategory.characterState,
  'character': SceneReviewCategory.characterState,
  'cognition': SceneReviewCategory.characterState,
  'role': SceneReviewCategory.characterState,
  'world_state': SceneReviewCategory.worldState,
  'world': SceneReviewCategory.worldState,
  'setting': SceneReviewCategory.worldState,
};

/// Categorize what needs review based on what changed.
///
/// Returns a deduplicated list of [SceneReviewCategory] values derived from
/// the provided [changedAspects]. Unknown aspects are handled gracefully:
/// they are simply ignored.
List<SceneReviewCategory> categorizeChanges(Set<String> changedAspects) {
  final categories = <SceneReviewCategory>{};
  for (final aspect in changedAspects) {
    final normalized = aspect.trim().toLowerCase();
    final category = _aspectToCategory[normalized];
    if (category != null) {
      categories.add(category);
    }
  }
  return categories.toList();
}
