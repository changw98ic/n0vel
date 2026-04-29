import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import '../domain/roleplay_models.dart';
import '../domain/scene_models.dart';
import 'story_generation_pass_retry.dart';

/// Draft prose from resolved beats with fact discipline.
///
/// The editor must not introduce facts absent from accepted beats or
/// the allowed narration context. The system prompt enforces this
/// constraint; the [EditorialDraft] provides helpers for external
/// fact-audit checks.
class SceneEditor {
  SceneEditor({required AppSettingsStore settingsStore})
      : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

  Future<EditorialDraft> draft({
    required SceneBrief brief,
    required SceneStateDelta delta,
    String? allowedNarrationContext,
  }) async {
    final acceptedBeats = delta.acceptedBeats;
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      messages: [
        const AppLlmChatMessage(
          role: 'system',
          content:
              'You are a scene editor for a Chinese novel. '
              'Draft scene prose from the accepted beats below. '
              'CRITICAL RULE: Do NOT introduce any new facts, events, '
              'or character knowledge that are not present in the accepted '
              'beats or the allowed narration context. '
              'Only narrate what the beats describe. '
              'Return only the finished prose.',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：scene_editorial',
            '场景：${brief.sceneTitle}',
            '目标字数：约${brief.targetLength}汉字',
            '摘要：${brief.sceneSummary}',
            '已接受节奏：',
            for (final rb in acceptedBeats)
              '  - ${rb.beat.characterId}: ${rb.beat.action}',
            if (allowedNarrationContext != null &&
                allowedNarrationContext.trim().isNotEmpty)
              '允许的叙述上下文：$allowedNarrationContext',
          ].join('\n'),
        ),
      ],
    );

    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene editorial pass failed.');
    }

    return EditorialDraft(
      text: result.text!.trim(),
      acceptedBeats: acceptedBeats,
      allowedNarrationContext: allowedNarrationContext,
    );
  }
}

/// Output of an editorial pass, carrying the prose and the facts it was
/// grounded on so external callers can audit for fact discipline.
class EditorialDraft {
  EditorialDraft({
    required this.text,
    required this.acceptedBeats,
    this.allowedNarrationContext,
  });

  final String text;
  final List<ResolvedBeat> acceptedBeats;
  final String? allowedNarrationContext;

  /// Collects all fact strings the draft is allowed to reference:
  /// accepted beat actions plus the narration context.
  Iterable<String> get allowedFacts sync* {
    for (final rb in acceptedBeats) {
      yield rb.beat.action;
    }
    if (allowedNarrationContext != null) {
      yield allowedNarrationContext!;
    }
  }

  /// Returns true if [candidate] is not grounded in any allowed fact.
  /// A fact is considered "novel" if it appears in the prose but cannot
  /// be traced to any accepted beat or narration context.
  bool isNovelFact(String candidate) {
    if (!text.contains(candidate)) return false;
    for (final fact in allowedFacts) {
      if (fact.contains(candidate)) return false;
    }
    return true;
  }
}
