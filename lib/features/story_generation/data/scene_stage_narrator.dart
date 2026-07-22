import '../domain/contracts/settings_contract.dart';

import 'prompt_string_utils.dart';
import 'scene_pipeline_models.dart' as pipeline;
import 'scene_roleplay_session_models.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import 'story_prompt_templates.dart';
import 'formal_evaluation_policy.dart';
import '../domain/contracts/event_log.dart';
import '../domain/contracts/stage_runner.dart';
import '../domain/scene_models.dart';

/// Produces scene-level observable context that no character should be forced
/// to narrate: environment, atmosphere, physical mechanisms, and public clues.
class SceneStageNarrator {
  SceneStageNarrator({
    required StoryGenerationSettingsContract settingsStore,
    PipelineEventLog? eventLog,
  }) : _settingsStore = settingsStore,
       _eventLog = eventLog;

  static const String capsuleToolName = 'scene_stage_narrator';

  final StoryGenerationSettingsContract _settingsStore;
  final PipelineEventLog? _eventLog;

  Future<pipeline.LightContextCapsule?> generate({
    required pipeline.SceneTaskCard taskCard,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required List<pipeline.RolePlayTurnOutput> roleTurns,
    required List<pipeline.LightContextCapsule> retrievalCapsules,
    SceneRoleplaySession? roleplaySession,
    String? ragContext,
  }) async {
    final noContentRedraw = _noContentRedraw;
    final formalEvaluation = FormalEvaluationPolicy.isActive(
      taskCard.brief.metadata,
      formalExecution: taskCard.brief.formalExecution,
    );
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      taskCard.metadata,
      formalExecution: taskCard.brief.formalExecution,
    );
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      taskCard.brief.metadata,
      formalExecution: taskCard.brief.formalExecution,
    );
    if (_disabled(taskCard)) {
      if (noContentRedraw) {
        throw StoryGenerationEvidencePreflightFailure(
          'no-redraw stage narration cannot be disabled after invocation',
        );
      }
      if (formalEvaluation) {
        throw StateError('formal evaluation cannot disable stage narration');
      }
      return null;
    }

    _eventLog?.emit(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: 'stage_narrator',
        eventType: 'status',
        metadata: {
          'sceneId': '${taskCard.brief.chapterId}/${taskCard.brief.sceneId}',
          'message': 'stage narrator',
        },
      ),
    );

    try {
      final promptIdentity = StoryPromptRegistry.production.invocation(
        stageId: 'stage-narration',
        callSiteId: 'stage-narrator',
      );
      final l = StoryPromptTemplates.locale;
      final resolvedVariables = <String, Object?>{
        'sceneTitle': PromptStringUtils.compact(
          taskCard.brief.sceneTitle,
          maxChars: 40,
        ),
        'sceneSummary': PromptStringUtils.compact(
          taskCard.brief.sceneSummary,
          maxChars: 140,
        ),
        'director': PromptStringUtils.compact(director.text, maxChars: 220),
        'tone': taskCard.directorPlanParsed?.tone ?? '',
        'roleTurns': roleTurns.isEmpty ? '' : _formatRoleTurns(roleTurns),
        'roleOutputs': roleOutputs.isEmpty
            ? ''
            : PromptStringUtils.mapJoin(
                roleOutputs,
                (output) => '${output.name}:${output.text}',
                separator: l.listSeparator,
              ),
        'roleplayProcess': roleplaySession != null && !roleplaySession.isEmpty
            ? roleplaySession.toCommittedPromptText(maxChars: 2200)
            : '',
        'retrievalContext': retrievalCapsules.isEmpty
            ? ''
            : PromptStringUtils.mapJoin(
                retrievalCapsules,
                (capsule) => capsule.summary,
                separator: l.listSeparator,
              ),
        'ragContext': ragContext == null || ragContext.trim().isEmpty
            ? ''
            : PromptStringUtils.compact(ragContext, maxChars: 1000),
      };
      final messages = promptIdentity.render(resolvedVariables).messages;
      final evidence = noContentRedraw
          ? StoryGenerationAttemptEvidenceCapture()
          : null;
      final result = await requestFormalStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        promptInvocation: promptIdentity,
        promptInvocationEvidence: promptIdentity.evidence(
          messages,
          resolvedVariables: resolvedVariables,
        ),
        maxTransientRetries: 0,
        maxOutputRetries: formalEvaluation ? 2 : 0,
        shouldRetryOutput: formalEvaluation
            ? _shouldRejectExactStageText
            : null,
        onAttemptEvidence: evidence?.record,
        messages: messages,
      );
      _requireCompleteNoRedrawEvidence(
        noContentRedraw: noContentRedraw,
        evidence: evidence,
      );
      if (!result.succeeded || result.text == null) {
        if (formalEvaluation || noContentRedraw) {
          throw StateError(
            result.detail ?? 'formal scene stage narration failed',
          );
        }
        return null;
      }
      final summary = formalEvaluation
          ? _parseExactStageText(result.text!)
          : _normalizeStageText(result.text!);
      if (summary == null || summary.isEmpty) {
        if (formalEvaluation || noContentRedraw) {
          throw StateError('formal scene stage narration output was malformed');
        }
        return null;
      }
      return pipeline.LightContextCapsule(
        intent: const pipeline.LightRetrievalIntent(
          toolName: capsuleToolName,
          query: 'scene stage narration',
          purpose: 'scene-level observable facts and atmosphere',
        ),
        summary: summary,
        tokenBudget: 240,
      );
    } on StoryGenerationEvidencePreflightFailure {
      rethrow;
    } on Object catch (error) {
      if (noContentRedraw) {
        rethrow;
      }
      if (formalEvaluation) {
        throw StateError('formal scene stage narration failed: $error');
      }
      return null;
    }
  }

  bool get _noContentRedraw =>
      StoryGenerationRetryScope.current?.allowsContentRedraw == false;

  bool _disabled(pipeline.SceneTaskCard taskCard) {
    final value =
        taskCard.metadata['disableStageNarrator'] ??
        taskCard.brief.metadata['disableStageNarrator'];
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return const {'true', '1', 'yes', 'on'}.contains(normalized);
  }

  String _formatRoleTurns(List<pipeline.RolePlayTurnOutput> turns) {
    final l = StoryPromptTemplates.locale;
    return PromptStringUtils.mapJoin(turns, (turn) {
      final parts = <String>[
        turn.name,
        if (turn.action.trim().isNotEmpty)
          '${l.actionLabel}${l.colon}${turn.action}',
        if (turn.disclosure.trim().isNotEmpty) '披露${l.colon}${turn.disclosure}',
        if (turn.proseFragment.trim().isNotEmpty)
          '正文片段${l.colon}${turn.proseFragment}',
      ];
      return parts.join('/');
    }, separator: l.listSeparator);
  }

  String _normalizeStageText(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return '';
    }
    return PromptStringUtils.compact(lines.join('\n'), maxChars: 1000);
  }

  String? _parseExactStageText(String raw) {
    if (raw.isEmpty || raw != raw.trim() || raw.length > 1000) {
      return null;
    }
    const labels = <String>['舞台事实', '环境氛围', '可见证据', '边界'];
    final lines = raw.split('\n');
    if (lines.length != labels.length) return null;
    for (var index = 0; index < labels.length; index += 1) {
      final line = lines[index];
      final prefix = '${labels[index]}：';
      if (line != line.trim() || !line.startsWith(prefix)) return null;
      final value = line.substring(prefix.length);
      if (value != value.trim() || _isPlaceholder(value)) return null;
    }
    return raw;
  }

  bool _shouldRejectExactStageText(String raw) =>
      _parseExactStageText(raw) == null;

  bool _isPlaceholder(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ||
        normalized == '-' ||
        normalized == '—' ||
        normalized == '...' ||
        normalized == '…' ||
        normalized == '……';
  }
}

void _requireCompleteNoRedrawEvidence({
  required bool noContentRedraw,
  required StoryGenerationAttemptEvidenceCapture? evidence,
}) {
  if (!noContentRedraw) return;
  if (evidence == null || !evidence.toEnvelope().evidenceComplete) {
    throw StoryGenerationEvidencePreflightFailure(
      'no-redraw stage narration produced incomplete attempt evidence',
    );
  }
}
