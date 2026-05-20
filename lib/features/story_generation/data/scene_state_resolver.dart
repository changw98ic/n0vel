// Barrel export — preserves the public API for all existing consumers.
export 'scene_transition_models.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'prompt_string_utils.dart';
import 'scene_beat_helpers.dart';
import 'scene_pipeline_models.dart';
import 'scene_roleplay_session_models.dart';
import 'scene_transition_models.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_templates.dart';
import '../domain/contracts/event_log.dart';
import '../domain/contracts/stage_runner.dart';

/// Resolves [RolePlayTurnOutput]s and [LightContextCapsule]s into accepted
/// [SceneBeat]s before any prose is written.
///
/// This stage enforces the fact-first pipeline: no prose generation
/// happens until the resolver has produced an ordered list of beats.
class SceneStateResolver {
  SceneStateResolver({
    required AppSettingsStore settingsStore,
    PipelineEventLog? eventLog,
  }) : _settingsStore = settingsStore,
       _eventLog = eventLog;

  final AppSettingsStore _settingsStore;
  final PipelineEventLog? _eventLog;

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
    _eventLog?.emit(PipelineEvent(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      stageId: 'beat_resolution',
      eventType: 'status',
      metadata: {
        'sceneId': '${taskCard.brief.chapterId}/${taskCard.brief.sceneId}',
        'message': 'resolving beats',
      },
    ));

    if (taskCard.metadata['localStructuredRoleplayOnly'] == true ||
        taskCard.brief.metadata['localStructuredRoleplayOnly'] == true) {
      return fallbackBeats(
        taskCard: taskCard,
        roleTurns: roleTurns,
        capsules: capsules,
        roleplaySession: roleplaySession,
      );
    }

    final l = StoryPromptTemplates.locale;
    final hasAuthority = hasAuthoritativeRoleplay(roleTurns, roleplaySession);
    final messages = [
      AppLlmChatMessage(
        role: 'system',
        content: StoryPromptTemplates.sysSceneBeatResolve,
      ),
      AppLlmChatMessage(
        role: 'user',
        content: [
          '${l.taskLabel}${l.colon}scene_beat_resolve',
          '${l.sceneShortLabel}${l.colon}${PromptStringUtils.compact(taskCard.brief.sceneTitle, maxChars: 40)}',
          if (hasAuthority) ...[
            '规划背景（非既定事实，不得直接输出为场景拍）：${PromptStringUtils.compact(taskCard.brief.sceneSummary, maxChars: 120)}',
            if (taskCard.directorPlan.trim().isNotEmpty)
              '导演规划（非既定事实，不得直接输出为场景拍）：${PromptStringUtils.compact(taskCard.directorPlan, maxChars: 120)}',
          ] else ...[
            '${l.summaryLabel}${l.colon}${PromptStringUtils.compact(taskCard.brief.sceneSummary, maxChars: 120)}',
            '${l.directorLabel}${l.colon}${PromptStringUtils.compact(taskCard.directorPlan, maxChars: 120)}',
          ],
          if (taskCard.directorPlanParsed != null) ...[
            if (taskCard.directorPlanParsed!.tone.isNotEmpty)
              '${l.toneFieldLabel}${l.colon}${taskCard.directorPlanParsed!.tone}',
            '${l.pacingFieldLabel}${l.colon}${pacingLabel(taskCard.directorPlanParsed!.pacing)}',
          ],
          turnSummary(roleTurns),
          if (roleplaySession != null && !roleplaySession.isEmpty)
            '角色扮演裁决（权威事实源）：${roleplaySession.toCommittedPromptText(maxChars: 2400)}',
          if (stageCapsules(capsules).isNotEmpty)
            '场景旁白/舞台信息（权威场景源）：${PromptStringUtils.mapJoin(stageCapsules(capsules), (c) => c.summary, separator: l.listSeparator)}',
          if (retrievalCapsules(capsules).isNotEmpty)
            '${l.retrievalContextLabel}${l.colon}${PromptStringUtils.mapJoin(retrievalCapsules(capsules), (c) => c.summary, separator: l.listSeparator)}',
          if (hasAuthority)
            '约束：只从角色输入、角色扮演裁决和检索上下文抽取场景拍；场景旁白/舞台信息可作为环境、氛围、物理机制与公共证据；规划背景只用于场景边界和语气，不是已发生事件。',
          '${l.targetLengthLabel}${l.colon}~${taskCard.brief.targetLength} ${l.charactersUnit}',
        ].join('\n'),
      ),
    ];

    while (true) {
      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        maxTransientRetries: 0,
        maxEscalatedTokens: storyGenerationEditorialMaxTokens,
        messages: messages,
      );

      if (!result.succeeded) {
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
        continue;
      }

      return List<SceneBeat>.unmodifiable(beats);
    }
  }
}
