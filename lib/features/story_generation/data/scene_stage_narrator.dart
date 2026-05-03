import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'prompt_string_utils.dart';
import 'scene_pipeline_models.dart' as pipeline;
import 'scene_roleplay_session_models.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_templates.dart';
import '../domain/scene_models.dart';

/// Produces scene-level observable context that no character should be forced
/// to narrate: environment, atmosphere, physical mechanisms, and public clues.
class SceneStageNarrator {
  SceneStageNarrator({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  static const String capsuleToolName = 'scene_stage_narrator';

  final AppSettingsStore _settingsStore;

  Future<pipeline.ContextCapsule?> generate({
    required pipeline.SceneTaskCard taskCard,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required List<pipeline.RolePlayTurnOutput> roleTurns,
    required List<pipeline.ContextCapsule> retrievalCapsules,
    SceneRoleplaySession? roleplaySession,
    String? ragContext,
    void Function(String message)? onStatus,
  }) async {
    if (_disabled(taskCard)) {
      return null;
    }

    onStatus?.call(
      '场景 ${taskCard.brief.chapterId}/${taskCard.brief.sceneId} · stage narrator',
    );

    try {
      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        maxTransientRetries: 0,
        maxOutputRetries: 0,
        messages: [
          const AppLlmChatMessage(role: 'system', content: _systemPrompt),
          AppLlmChatMessage(
            role: 'user',
            content: _buildUserPrompt(
              taskCard: taskCard,
              director: director,
              roleOutputs: roleOutputs,
              roleTurns: roleTurns,
              retrievalCapsules: retrievalCapsules,
              roleplaySession: roleplaySession,
              ragContext: ragContext,
            ),
          ),
        ],
      );
      if (!result.succeeded || result.text == null) {
        return null;
      }
      final summary = _normalizeStageText(result.text!);
      if (summary.isEmpty) {
        return null;
      }
      return pipeline.ContextCapsule(
        intent: const pipeline.RetrievalIntent(
          toolName: capsuleToolName,
          query: 'scene stage narration',
          purpose: 'scene-level observable facts and atmosphere',
        ),
        summary: summary,
        tokenBudget: 240,
      );
    } on Object {
      return null;
    }
  }

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

  String _buildUserPrompt({
    required pipeline.SceneTaskCard taskCard,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required List<pipeline.RolePlayTurnOutput> roleTurns,
    required List<pipeline.ContextCapsule> retrievalCapsules,
    SceneRoleplaySession? roleplaySession,
    String? ragContext,
  }) {
    final l = StoryPromptTemplates.locale;
    final brief = taskCard.brief;
    return [
      '${l.taskLabel}${l.colon}scene_stage_narration',
      '${l.sceneShortLabel}${l.colon}${PromptStringUtils.compact(brief.sceneTitle, maxChars: 40)}',
      '${l.summaryLabel}${l.colon}${PromptStringUtils.compact(brief.sceneSummary, maxChars: 140)}',
      '${l.directorLabel}${l.colon}${PromptStringUtils.compact(director.text, maxChars: 220)}',
      if (taskCard.directorPlanParsed != null) ...[
        if (taskCard.directorPlanParsed!.tone.isNotEmpty)
          '${l.toneFieldLabel}${l.colon}${taskCard.directorPlanParsed!.tone}',
      ],
      if (roleTurns.isNotEmpty) '角色公开行动：${_formatRoleTurns(roleTurns)}',
      if (roleOutputs.isNotEmpty)
        '角色原始输出：${PromptStringUtils.mapJoin(roleOutputs, (o) => '${o.name}:${o.text}', separator: l.listSeparator)}',
      if (roleplaySession != null && !roleplaySession.isEmpty)
        '角色扮演公开过程：${roleplaySession.toCommittedPromptText(maxChars: 2200)}',
      if (retrievalCapsules.isNotEmpty)
        '${l.retrievalContextLabel}${l.colon}${PromptStringUtils.mapJoin(retrievalCapsules, (c) => c.summary, separator: l.listSeparator)}',
      if (ragContext != null && ragContext.trim().isNotEmpty)
        '外部检索：${PromptStringUtils.compact(ragContext, maxChars: 1000)}',
      '边界：只补舞台层面的可观察信息、环境氛围、物理机制与公共证据；不要替角色新增行动、对白、决定或内心。',
      '输出四行：舞台事实：... / 环境氛围：... / 可见证据：... / 边界：...',
    ].join('\n');
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

  static const String _systemPrompt =
      'You are a scene stage narrator for a Chinese novel. '
      'Produce only stage-level observable information: environment, sensory atmosphere, '
      'physical mechanisms, offscreen effects, and public evidence. '
      'Do not choose character actions, dialogue, decisions, or private thoughts. '
      'Do not write final prose. Use four short Chinese lines: '
      '舞台事实：... 环境氛围：... 可见证据：... 边界：...';
}
