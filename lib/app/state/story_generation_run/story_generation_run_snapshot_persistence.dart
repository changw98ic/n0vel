part of '../story_generation_run_store.dart';

extension _StoryGenerationRunSnapshotPersistence on StoryGenerationRunStore {
  Future<void> _restoreCurrentScene() async {
    final restoreVersion = _mutationVersion;
    final sceneScopeId = _activeSceneScopeId;
    final restored = await _storage.load(sceneScopeId: sceneScopeId);
    if (restoreVersion != _mutationVersion || restored == null) {
      return;
    }
    final snapshot = StoryGenerationRunSnapshot.fromJson({
      for (final entry in restored.entries)
        entry.key: cloneStorageValue(entry.value),
    });
    _snapshot = snapshot;
    _snapshotsBySceneScope[sceneScopeId] = snapshot;
    _syncFeedbackCache(sceneScopeId, snapshot);
    _notifySnapshotListeners();
  }

  Future<void> _persistSnapshot(
    StoryGenerationRunSnapshot snapshot,
    String sceneScopeId,
  ) {
    return _storage.save({
      ...snapshot.toJson(),
      'sceneScopeId': sceneScopeId,
    }, sceneScopeId: sceneScopeId);
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
    await _persistSnapshot(next, sceneScopeId);
    _snapshotsBySceneScope[sceneScopeId] = next;
    _syncFeedbackCache(sceneScopeId, next);
    if (mutationVersion == _mutationVersion &&
        sceneScopeId == _activeSceneScopeId) {
      _snapshot = next;
      _notifySnapshotListeners();
    }
  }

}

Map<String, Object?> _asStringObjectMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): cloneStorageValue(entry.value),
  };
}
