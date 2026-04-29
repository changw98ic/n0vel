import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'prompt_string_utils.dart';
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
      );
    }

    final l = StoryPromptTemplates.locale;
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
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
            '${l.summaryLabel}${l.colon}${PromptStringUtils.compact(taskCard.brief.sceneSummary, maxChars: 120)}',
            _formatBeats(resolvedBeats),
            if (capsules.isNotEmpty)
              '${l.contextLabel}${l.colon}${PromptStringUtils.mapJoin(capsules, (c) => c.summary, separator: l.listSeparator)}',
            if (roleplaySession != null && !roleplaySession.isEmpty)
              '角色扮演公开过程：${roleplaySession.toCommittedPromptText(maxChars: 2200)}',
            if (roleplaySession != null && !roleplaySession.isEmpty)
              '硬约束：正文只能扩写角色扮演过程中的可见事件与已提交事实；不得引入未裁决事实；不得泄漏非POV角色内心。',
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

  SceneEditorialDraft _localDraft({
    required SceneTaskCard taskCard,
    required List<SceneBeat> resolvedBeats,
    required int attempt,
  }) {
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
