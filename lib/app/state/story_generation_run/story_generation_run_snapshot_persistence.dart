part of '../story_generation_run_store.dart';

extension _StoryGenerationRunSnapshotPersistence on StoryGenerationRunStore {
  Future<void> _restoreCurrentScene() async {
    final restoreVersion = _mutationVersion;
    final sceneScopeId = _activeSceneScopeId;
    final restored = await _snapshotRepository.restore(sceneScopeId);
    if (restoreVersion != _mutationVersion || restored == null) {
      return;
    }
    _snapshot = restored;
    _syncFeedbackCache(sceneScopeId, restored);
    _notifySnapshotListeners();
  }

  void _syncFeedbackCache(
    String sceneScopeId,
    StoryGenerationRunSnapshot snapshot,
  ) {
    _directorFeedbackBySceneScope[sceneScopeId] = [
      for (final message in snapshot.messages)
        if (message.kind == StoryGenerationRunMessageKind.authorFeedback &&
            message.body.trim().isNotEmpty)
          message.body.trim(),
    ];
  }

  Future<void> _setSnapshot(StoryGenerationRunSnapshot next) async {
    _mutationVersion += 1;
    final mutationVersion = _mutationVersion;
    final sceneScopeId = _activeSceneScopeId;
    await _snapshotRepository.persist(next, sceneScopeId);
    _syncFeedbackCache(sceneScopeId, next);
    if (mutationVersion == _mutationVersion &&
        sceneScopeId == _activeSceneScopeId) {
      _snapshot = next;
      _notifySnapshotListeners();
    }
  }
}
