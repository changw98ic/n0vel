import 'dart:async';

import '../domain/contracts/settings_contract.dart';

import 'scene_pipeline_models.dart';
import 'scene_type_classifier.dart';
import 'scene_type_prompts.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import 'formal_evaluation_policy.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

class SceneDirectorOrchestrator implements SceneDirectorService {
  static const Duration _requestTimeout = Duration(seconds: 60);

  SceneDirectorOrchestrator({
    required StoryGenerationSettingsContract settingsStore,
    Duration requestTimeout = _requestTimeout,
  }) : _settingsStore = settingsStore,
       _providerRequestTimeout = requestTimeout;

  final StoryGenerationSettingsContract _settingsStore;
  final Duration _providerRequestTimeout;
  final SceneTypeClassifier _typeClassifier = SceneTypeClassifier();
  final SceneTypePrompts _typePrompts = const SceneTypePrompts();

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async {
    final noContentRedraw = _noContentRedraw;
    final formalEvaluation = FormalEvaluationPolicy.isActive(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    final localPlanText = _buildLocalPlan(brief: brief, cast: cast);
    final localPlan = _buildStructuredPlan(
      text: localPlanText,
      brief: brief,
      cast: cast,
    );

    if (brief.metadata['localDirectorOnly'] == true) {
      if (noContentRedraw) {
        throw StoryGenerationEvidencePreflightFailure(
          'no-redraw scene director cannot use a local-only plan',
        );
      }
      return SceneDirectorOutput(text: localPlanText, plan: localPlan);
    }

    try {
      final promptIdentity = StoryPromptRegistry.production.invocation(
        stageId: 'director',
        callSiteId: 'scene-director',
      );
      final sceneType = _typeClassifier.classify(brief);
      final resolvedVariables = <String, Object?>{
        'sceneTypeLabel': sceneType.label,
        'confidencePercent': (sceneType.confidence * 100).toInt(),
        'suggestedTone': sceneType.suggestedTone,
        'suggestedPacing': sceneType.suggestedPacing,
        'chapter': _compact(
          '${brief.chapterTitle} ${brief.chapterId}',
          maxChars: 40,
        ),
        'scene': _compact('${brief.sceneTitle} ${brief.sceneId}', maxChars: 40),
        'targetBeat': _compact(brief.targetBeat, maxChars: 80),
        'sceneSummary': _compact(brief.sceneSummary, maxChars: 80),
        'castSummary': cast.isEmpty
            ? '出场角色：无'
            : '出场角色：${cast.map((m) => '${m.name}(${m.role})').join('、')}',
        'revisionPrompt': _revisionRequestPrompt(brief),
        'ragContext': ragContext ?? '',
        'localPlanText': localPlanText,
        'typeSupplement': _typePrompts.directorSupplement(sceneType),
      };
      final messages = promptIdentity.render(resolvedVariables).messages;
      final evidence = noContentRedraw
          ? StoryGenerationAttemptEvidenceCapture()
          : null;
      final request = requestFormalStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        promptInvocation: promptIdentity,
        promptInvocationEvidence: promptIdentity.evidence(
          messages,
          resolvedVariables: resolvedVariables,
        ),
        onAttemptEvidence: evidence?.record,
        messages: messages,
      );
      final result = noContentRedraw
          ? await request
          : await request.timeout(_providerRequestTimeout);
      _requireCompleteNoRedrawEvidence(
        noContentRedraw: noContentRedraw,
        evidence: evidence,
      );

      if (!result.succeeded || result.text == null) {
        if (formalEvaluation || noContentRedraw) {
          throw StateError(
            result.detail ?? 'formal scene director provider call failed',
          );
        }
        return SceneDirectorOutput(text: localPlanText, plan: localPlan);
      }
      final parsed = SceneDirectorPlan.tryParse(result.text!.trim());
      if (parsed == null) {
        if (formalEvaluation || noContentRedraw) {
          throw StateError('formal scene director output was malformed');
        }
        return SceneDirectorOutput(text: localPlanText, plan: localPlan);
      }
      final polishedText = parsed.toText();
      return SceneDirectorOutput(
        text: polishedText,
        plan: _buildStructuredPlan(
          text: polishedText,
          brief: brief,
          cast: cast,
        ),
      );
    } on StoryGenerationEvidencePreflightFailure {
      rethrow;
    } on TimeoutException {
      if (noContentRedraw) {
        rethrow;
      }
      if (formalEvaluation) {
        throw StateError('formal scene director request timed out');
      }
      return SceneDirectorOutput(text: localPlanText, plan: localPlan);
    } catch (error) {
      if (noContentRedraw) {
        rethrow;
      }
      if (formalEvaluation) {
        throw StateError('formal scene director failed: $error');
      }
      return SceneDirectorOutput(text: localPlanText, plan: localPlan);
    }
  }

  bool get _noContentRedraw =>
      StoryGenerationRetryScope.current?.allowsContentRedraw == false;

  String _buildLocalPlan({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
  }) {
    final target = _compact(
      brief.targetBeat.trim().isNotEmpty
          ? brief.targetBeat
          : brief.sceneSummary,
      maxChars: 48,
    );
    final conflict = cast.isEmpty
        ? '冲突：围绕场景目标推进'
        : '冲突：${cast.map((member) => member.name).join('与')}在目标上相互施压';
    final progression = brief.targetBeat.trim().isNotEmpty
        ? '推进：${_compact(brief.targetBeat, maxChars: 48)}'
        : '推进：${_compact(brief.sceneSummary, maxChars: 48)}';
    final baseConstraints = brief.worldNodeIds.isEmpty
        ? '遵守当前世界观和角色设定'
        : '遵守${brief.worldNodeIds.join('/')}相关规则';
    final roleConstraints = cast.isEmpty
        ? ''
        : '；出场：${cast.map((member) => '${member.name}(${member.role})').join('、')}';
    final revisionConstraints = _revisionRequestConstraint(brief);
    final constraintText = [
      roleConstraints.isEmpty
          ? _compact(baseConstraints, maxChars: 48)
          : '$baseConstraints$roleConstraints',
      if (revisionConstraints.isNotEmpty) revisionConstraints,
    ].join('；');
    final constraints = '约束：$constraintText';
    return ['目标：$target', conflict, progression, constraints].join('\n');
  }

  String _revisionRequestPrompt(SceneBrief brief) {
    final notes = _revisionRequestNotes(brief);
    if (notes.isEmpty) {
      return '';
    }
    return [
      for (var i = 0; i < notes.length; i++)
        '${i + 1}. ${_compact(notes[i], maxChars: 120)}',
    ].join('\n');
  }

  String _revisionRequestConstraint(SceneBrief brief) {
    final notes = _revisionRequestNotes(brief);
    if (notes.isEmpty) {
      return '';
    }
    return '落实作者修订：${_compact(notes.join('；'), maxChars: 80)}';
  }

  List<String> _revisionRequestNotes(SceneBrief brief) {
    final raw = brief.metadata['authorRevisionRequests'];
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item != null && item.toString().trim().isNotEmpty)
          item.toString().trim(),
    ];
  }

  SceneDirectorPlan? _buildStructuredPlan({
    required String text,
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
  }) {
    final parsed =
        SceneDirectorPlan.tryParse(text) ??
        SceneDirectorPlan.tryParse(_buildLocalPlan(brief: brief, cast: cast));
    if (parsed == null) {
      return null;
    }
    return SceneDirectorPlan(
      target: parsed.target,
      conflict: parsed.conflict,
      progression: parsed.progression,
      constraints: parsed.constraints,
      tone: _inferTone(brief),
      pacing: _inferPacingFromType(brief),
      characterNotes: _buildCharacterNotes(brief: brief, cast: cast),
    );
  }

  List<DirectorCharacterNote> _buildCharacterNotes({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
  }) {
    final target = _compact(
      brief.targetBeat.trim().isNotEmpty
          ? brief.targetBeat
          : brief.sceneSummary,
      maxChars: 48,
    );
    return [
      for (final member in cast)
        DirectorCharacterNote(
          characterId: member.characterId,
          name: member.name,
          motivation: '$target (${member.role})',
          emotionalArc: '${_classifyTone(brief)}中随压力推进',
          keyAction: member.contributions.isEmpty
              ? '围绕场景目标行动'
              : '承担${member.contributions.map((c) => c.name).join('/')}功能',
        ),
    ];
  }

  String _inferTone(SceneBrief brief) {
    final result = _typeClassifier.classify(brief);
    return result.suggestedTone;
  }

  String _classifyTone(SceneBrief brief) {
    final result = _typeClassifier.classify(brief);
    return result.suggestedTone;
  }

  ScenePacing _inferPacingFromType(SceneBrief brief) {
    final result = _typeClassifier.classify(brief);
    return switch (result.suggestedPacing) {
      'fast' => ScenePacing.fast,
      'slow' => ScenePacing.slow,
      _ => ScenePacing.medium,
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

void _requireCompleteNoRedrawEvidence({
  required bool noContentRedraw,
  required StoryGenerationAttemptEvidenceCapture? evidence,
}) {
  if (!noContentRedraw) return;
  if (evidence == null || !evidence.toEnvelope().evidenceComplete) {
    throw StoryGenerationEvidencePreflightFailure(
      'no-redraw scene director produced incomplete attempt evidence',
    );
  }
}
