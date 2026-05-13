part of '../story_generation_run_store.dart';

extension _StoryGenerationRunSceneBrief on StoryGenerationRunStore {
  List<AuthorFeedbackItem> _activeRevisionRequestsForCurrentScene({
    required String chapterId,
    required String sceneId,
  }) {
    return _authorFeedbackStore?.activeRevisionRequestsForScene(
          chapterId: chapterId,
          sceneId: sceneId,
        ) ??
        const <AuthorFeedbackItem>[];
  }

  Map<String, Object?> _runtimeMetadata({
    List<AuthorFeedbackItem> revisionRequests = const [],
  }) {
    final localOnly = !_settingsStore.hasReadyConfiguration;
    final revisionNotes = [
      for (final request in revisionRequests)
        if (request.note.trim().isNotEmpty) request.note.trim(),
    ];
    return {
      'structuredRoleplayPipeline': true,
      'roleplayRounds': 1,
      'reviewMode': 'blocking',
      if (revisionNotes.isNotEmpty)
        'authorRevisionRequests': List<String>.unmodifiable(revisionNotes),
      if (localOnly) 'localDirectorOnly': true,
      if (localOnly) 'localStructuredRoleplayOnly': true,
      if (localOnly) 'localEditorialOnly': true,
      if (localOnly) 'localReviewOnly': true,
    };
  }

  String _sceneLabel() {
    return '${_workspaceStore.currentProject.title} / ${_workspaceStore.currentScene.displayLocation}';
  }
}
