import '../domain/contracts/settings_contract.dart';

import '../domain/roleplay_models.dart';
import '../domain/scene_models.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import 'formal_evaluation_policy.dart';

/// Draft prose from resolved beats with fact discipline.
///
/// The editor must not introduce facts absent from accepted beats or
/// the allowed narration context. The system prompt enforces this
/// constraint; the [EditorialDraft] provides helpers for external
/// fact-audit checks.
class SceneEditor {
  SceneEditor({required StoryGenerationSettingsContract settingsStore})
    : _settingsStore = settingsStore;

  final StoryGenerationSettingsContract _settingsStore;

  Future<EditorialDraft> draft({
    required SceneBrief brief,
    required SceneStateDelta delta,
    String? allowedNarrationContext,
  }) async {
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    final acceptedBeats = delta.acceptedBeats;
    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'editorial',
      callSiteId: 'scene-editor',
    );
    final resolvedVariables = <String, Object?>{
      'sceneTitle': brief.sceneTitle,
      'targetLength': brief.targetLength,
      'sceneSummary': brief.sceneSummary,
      'acceptedBeats': acceptedBeats
          .map((rb) => '- ${rb.beat.characterId}: ${rb.beat.action}')
          .join('\n'),
      'allowedNarrationContext': allowedNarrationContext?.trim() ?? '',
    };
    final messages = promptIdentity.render(resolvedVariables).messages;
    final result = await requestFormalStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      promptInvocation: promptIdentity,
      promptInvocationEvidence: promptIdentity.evidence(
        messages,
        resolvedVariables: resolvedVariables,
      ),
      initialMaxTokens: storyGenerationEditorialMaxTokens,
      messages: messages,
    );

    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene editorial pass failed.');
    }

    final text = result.text!.trim();
    if (text.isEmpty &&
        FormalEvaluationPolicy.isActive(
          brief.metadata,
          formalExecution: brief.formalExecution,
        )) {
      throw StateError('formal scene editor returned empty text');
    }
    return EditorialDraft(
      text: text,
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
