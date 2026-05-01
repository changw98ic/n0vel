import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'prompt_string_utils.dart';
import 'scene_cast_roleplay_policy.dart';
import 'scene_stage_narrator.dart';
import 'story_generation_pass_retry.dart';
import 'scene_pipeline_models.dart';
import 'scene_roleplay_session_models.dart';
import 'story_prompt_templates.dart';

/// Generates prose only from resolved [SceneBeat]s and allowed narration state.
///
/// Unlike [SceneProseGenerator] which operates on raw role-summary text,
/// the editorial generator stitches beats into coherent prose, preserving
/// factual boundaries established by the resolver.
class SceneEditorialGenerator {
  SceneEditorialGenerator({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

  /// Generate an editorial draft from resolved beats.
  ///
  /// [reviewFeedback] from a previous attempt is included for rewrite passes.
  Future<SceneEditorialDraft> generate({
    required SceneTaskCard taskCard,
    required List<SceneBeat> resolvedBeats,
    required List<ContextCapsule> capsules,
    required int attempt,
    SceneRoleplaySession? roleplaySession,
    String? reviewFeedback,
  }) async {
    if (taskCard.metadata['localEditorialOnly'] == true ||
        taskCard.brief.metadata['localEditorialOnly'] == true) {
      return _localDraft(
        taskCard: taskCard,
        resolvedBeats: resolvedBeats,
        attempt: attempt,
        roleplaySession: roleplaySession,
      );
    }

    final l = StoryPromptTemplates.locale;
    final hardLimit = taskCard.brief.targetLength < 1
        ? 800
        : taskCard.brief.targetLength * 2;
    final roleplayDraft = roleplaySession?.toRoleplayDraftPromptText(
      maxChars: hardLimit * 2,
    );
    final noninteractiveCastBoundary = noninteractiveCastBoundaryText(
      taskCard.brief,
    );
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      initialMaxTokens: storyGenerationEditorialMaxTokens,
      messages: [
        AppLlmChatMessage(
          role: 'system',
          content: StoryPromptTemplates.sysSceneEditorial,
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '${l.taskLabel}${l.colon}scene_editorial',
            '${l.sceneShortLabel}${l.colon}${PromptStringUtils.compact(taskCard.brief.sceneTitle, maxChars: 40)}',
            '${l.targetLengthLabel}${l.colon}~${taskCard.brief.targetLength} ${l.charactersUnit}',
            '长度边界${l.colon}接近目标长度，硬上限为$hardLimit ${l.charactersUnit}',
            '${l.summaryLabel}${l.colon}${PromptStringUtils.compact(taskCard.brief.sceneSummary, maxChars: 120)}',
            if (noninteractiveCastBoundary.isNotEmpty)
              noninteractiveCastBoundary,
            if (roleplayDraft != null && roleplayDraft.isNotEmpty) ...[
              '角色扮演正文草稿：',
              roleplayDraft,
              '润色边界：以角色扮演正文草稿为正文底稿，保留角色动作、对白、顺序和已裁定事实；补顺段落衔接、语气和节奏。',
            ],
            _formatBeats(resolvedBeats),
            if (_stageCapsules(capsules).isNotEmpty)
              '场景旁白/舞台信息（权威场景源）：'
                  '${PromptStringUtils.mapJoin(_stageCapsules(capsules), (c) => c.summary, separator: l.listSeparator)}',
            if (_retrievalCapsules(capsules).isNotEmpty)
              '${l.contextLabel}${l.colon}${PromptStringUtils.mapJoin(_retrievalCapsules(capsules), (c) => c.summary, separator: l.listSeparator)}',
            if (roleplaySession != null && !roleplaySession.isEmpty)
              '角色扮演公开过程：${roleplaySession.toCommittedPromptText(maxChars: 2200)}',
            if (roleplaySession != null && !roleplaySession.isEmpty)
              '正文依据：围绕角色扮演过程中的可见事件、正文片段与已提交事实润色；角色内心用于POV当下判断。',
            '${l.currentAttemptLabel}${l.colon}$attempt',
            if (reviewFeedback != null)
              '${l.editorialFeedbackLabel}${l.colon}${reviewFeedback.trim()}',
          ].join('\n'),
        ),
      ],
    );

    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene editorial generation failed.');
    }

    return SceneEditorialDraft(
      text: result.text!.trim(),
      beatCount: resolvedBeats.length,
      attempt: attempt,
    );
  }

  String _formatBeats(List<SceneBeat> beats) {
    final l = StoryPromptTemplates.locale;
    if (beats.isEmpty) return '${l.sceneBeatsLabel}${l.colon}${l.noneLabel}';
    String kindLabel(SceneBeatKind k) => switch (k) {
      SceneBeatKind.fact => l.beatFact,
      SceneBeatKind.dialogue => l.beatDialogue,
      SceneBeatKind.action => l.beatAction,
      SceneBeatKind.internal => l.beatInternal,
      SceneBeatKind.narration => l.beatNarration,
    };
    final buf = StringBuffer('${l.sceneBeatsLabel}${l.colon}');
    for (final b in beats) {
      buf
        ..writeln()
        ..write('[${kindLabel(b.kind)}]@${b.sourceCharacterId} ${b.content}');
    }
    return buf.toString();
  }

  List<ContextCapsule> _stageCapsules(List<ContextCapsule> capsules) {
    return [
      for (final capsule in capsules)
        if (capsule.intent.toolName == SceneStageNarrator.capsuleToolName)
          capsule,
    ];
  }

  List<ContextCapsule> _retrievalCapsules(List<ContextCapsule> capsules) {
    return [
      for (final capsule in capsules)
        if (capsule.intent.toolName != SceneStageNarrator.capsuleToolName)
          capsule,
    ];
  }

  SceneEditorialDraft _localDraft({
    required SceneTaskCard taskCard,
    required List<SceneBeat> resolvedBeats,
    required int attempt,
    SceneRoleplaySession? roleplaySession,
  }) {
    final roleplayDraft = roleplaySession?.roleplayDraft.trim();
    if (roleplayDraft != null && roleplayDraft.isNotEmpty) {
      return SceneEditorialDraft(
        text: roleplayDraft,
        beatCount: resolvedBeats.length,
        attempt: attempt,
      );
    }
    final parts = <String>[];
    final summary = taskCard.brief.sceneSummary.trim();
    if (summary.isNotEmpty) {
      parts.add(summary);
    }
    for (final beat in resolvedBeats) {
      final content = beat.content.trim();
      if (content.isEmpty || parts.contains(content)) {
        continue;
      }
      final characterName = _characterName(taskCard, beat.sourceCharacterId);
      parts.add(switch (beat.kind) {
        SceneBeatKind.dialogue =>
          characterName.isEmpty ? '“$content”' : '$characterName说：“$content”',
        SceneBeatKind.action =>
          characterName.isEmpty ? content : '$characterName$content',
        SceneBeatKind.internal =>
          characterName.isEmpty ? content : '$characterName心中确认：$content',
        SceneBeatKind.fact || SceneBeatKind.narration => content,
      });
    }
    final text = parts.isEmpty
        ? taskCard.brief.targetBeat.trim()
        : parts.join('。');
    return SceneEditorialDraft(
      text: text.trim(),
      beatCount: resolvedBeats.length,
      attempt: attempt,
    );
  }

  String _characterName(SceneTaskCard taskCard, String characterId) {
    for (final member in taskCard.cast) {
      if (member.characterId == characterId) {
        return member.name;
      }
    }
    return '';
  }
}
