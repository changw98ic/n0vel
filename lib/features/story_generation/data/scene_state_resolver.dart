// Barrel export — preserves the public API for all existing consumers.
export 'scene_transition_models.dart';

import 'dart:async';

import '../domain/contracts/settings_contract.dart';

import 'prompt_string_utils.dart';
import 'scene_beat_helpers.dart';
import 'scene_pipeline_models.dart';
import 'scene_roleplay_session_models.dart';
import 'scene_transition_models.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import 'story_prompt_templates.dart';
import 'formal_evaluation_policy.dart';
import '../domain/contracts/event_log.dart';
import '../domain/contracts/stage_runner.dart';

/// Resolves [RolePlayTurnOutput]s and [LightContextCapsule]s into accepted
/// [SceneBeat]s before any prose is written.
///
/// This stage enforces the fact-first pipeline: no prose generation
/// happens until the resolver has produced an ordered list of beats.
class SceneStateResolver {
  static const Duration _formalRequestTimeout = Duration(seconds: 120);

  SceneStateResolver({
    required StoryGenerationSettingsContract settingsStore,
    PipelineEventLog? eventLog,
    Duration formalRequestTimeout = _formalRequestTimeout,
  }) : _settingsStore = settingsStore,
       _eventLog = eventLog,
       _requestTimeout = formalRequestTimeout;

  final StoryGenerationSettingsContract _settingsStore;
  final PipelineEventLog? _eventLog;
  final Duration _requestTimeout;

  static SceneTransitionReport trackTransitions({
    required SceneTaskCard taskCard,
    required List<SceneBeat> resolvedBeats,
  }) {
    final requirements = [
      ...requirementsFromMetadata(
        taskCard.metadata['requiredTransitions'],
        isRequired: true,
      ),
      ...requirementsFromMetadata(
        taskCard.metadata['optionalTransitions'],
        isRequired: false,
      ),
      ...requirementsFromMixedMetadata(taskCard.metadata['transitions']),
    ];

    return SceneTransitionReport(
      checks: [
        for (final requirement in requirements)
          checkTransition(requirement, resolvedBeats),
      ],
    );
  }

  /// Resolve role turns + capsules into scene beats.
  ///
  /// The resolver sends a structured request to the LLM asking it to
  /// decompose the scene into ordered beats. Each beat is classified
  /// by [SceneBeatKind] and attributed to a source character.
  Future<List<SceneBeat>> resolve({
    required SceneTaskCard taskCard,
    required List<RolePlayTurnOutput> roleTurns,
    required List<LightContextCapsule> capsules,
    SceneRoleplaySession? roleplaySession,
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
    _eventLog?.emit(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: 'beat_resolution',
        eventType: 'status',
        metadata: {
          'sceneId': '${taskCard.brief.chapterId}/${taskCard.brief.sceneId}',
          'message': 'resolving beats',
        },
      ),
    );

    if (taskCard.metadata['localStructuredRoleplayOnly'] == true ||
        taskCard.brief.metadata['localStructuredRoleplayOnly'] == true) {
      if (noContentRedraw) {
        throw StoryGenerationEvidencePreflightFailure(
          'no-redraw beat resolution cannot use local fallback beats',
        );
      }
      return fallbackBeats(
        taskCard: taskCard,
        roleTurns: roleTurns,
        capsules: capsules,
        roleplaySession: roleplaySession,
      );
    }

    final l = StoryPromptTemplates.locale;
    final hasAuthority = hasAuthoritativeRoleplay(roleTurns, roleplaySession);
    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'beat-resolution',
      callSiteId: 'beat-resolver',
    );
    final planningContext = hasAuthority
        ? <String>[
            '规划背景（非既定事实，不得直接输出为场景拍）：${PromptStringUtils.compact(taskCard.brief.sceneSummary, maxChars: 120)}',
            if (taskCard.directorPlan.trim().isNotEmpty)
              '导演规划（非既定事实，不得直接输出为场景拍）：${PromptStringUtils.compact(taskCard.directorPlan, maxChars: 120)}',
          ].join('\n')
        : <String>[
            '${l.summaryLabel}${l.colon}${PromptStringUtils.compact(taskCard.brief.sceneSummary, maxChars: 120)}',
            '${l.directorLabel}${l.colon}${PromptStringUtils.compact(taskCard.directorPlan, maxChars: 120)}',
          ].join('\n');
    final tonePacing = taskCard.directorPlanParsed == null
        ? ''
        : <String>[
            if (taskCard.directorPlanParsed!.tone.isNotEmpty)
              '${l.toneFieldLabel}${l.colon}${taskCard.directorPlanParsed!.tone}',
            '${l.pacingFieldLabel}${l.colon}${pacingLabel(taskCard.directorPlanParsed!.pacing)}',
          ].join('\n');
    final resolvedVariables = <String, Object?>{
      'sceneTitle': PromptStringUtils.compact(
        taskCard.brief.sceneTitle,
        maxChars: 40,
      ),
      'planningContext': planningContext,
      'tonePacing': tonePacing,
      'turnSummary': turnSummary(roleTurns),
      'roleplayAuthority': roleplaySession != null && !roleplaySession.isEmpty
          ? roleplaySession.toCommittedPromptText(maxChars: 2400)
          : '',
      'stageContext': stageCapsules(capsules).isEmpty
          ? ''
          : PromptStringUtils.mapJoin(
              stageCapsules(capsules),
              (c) => c.summary,
              separator: l.listSeparator,
            ),
      'retrievalContext': retrievalCapsules(capsules).isEmpty
          ? ''
          : PromptStringUtils.mapJoin(
              retrievalCapsules(capsules),
              (c) => c.summary,
              separator: l.listSeparator,
            ),
      'authorityConstraint': hasAuthority
          ? '只从角色输入、角色扮演裁决和检索上下文抽取场景拍；场景旁白/舞台信息可作为环境、氛围、物理机制与公共证据；规划背景只用于场景边界和语气，不是已发生事件。'
          : '',
      'targetLength': taskCard.brief.targetLength,
    };
    final messages = promptIdentity.render(resolvedVariables).messages;

    while (true) {
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
        maxTransientRetries: 0,
        maxEscalatedTokens: storyGenerationEditorialMaxTokens,
        onAttemptEvidence: evidence?.record,
        messages: messages,
      );
      final result = formalEvaluation && !noContentRedraw
          ? await request.timeout(_requestTimeout)
          : await request;
      _requireCompleteNoRedrawEvidence(
        noContentRedraw: noContentRedraw,
        evidence: evidence,
      );

      if (!result.succeeded) {
        if (formalEvaluation || noContentRedraw) {
          throw StateError(
            result.detail ?? 'formal scene beat resolution failed',
          );
        }
        return fallbackBeats(
          taskCard: taskCard,
          roleTurns: roleTurns,
          capsules: capsules,
          roleplaySession: roleplaySession,
        );
      }

      final beats = filterPlanningOnlyBeats(
        parseBeatsFromRaw(result.text!),
        taskCard: taskCard,
        roleTurns: roleTurns,
        capsules: capsules,
        roleplaySession: roleplaySession,
      );
      if (beats.isEmpty) {
        if (formalEvaluation || noContentRedraw) {
          throw StateError(
            'formal scene beat resolution produced no valid beats',
          );
        }
        continue;
      }

      return List<SceneBeat>.unmodifiable(beats);
    }
  }

  bool get _noContentRedraw =>
      StoryGenerationRetryScope.current?.allowsContentRedraw == false;
}

void _requireCompleteNoRedrawEvidence({
  required bool noContentRedraw,
  required StoryGenerationAttemptEvidenceCapture? evidence,
}) {
  if (!noContentRedraw) return;
  if (evidence == null || !evidence.toEnvelope().evidenceComplete) {
    throw StoryGenerationEvidencePreflightFailure(
      'no-redraw beat resolution produced incomplete attempt evidence',
    );
  }
}
