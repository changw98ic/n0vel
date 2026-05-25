part of '../story_generation_run_store.dart';

/// Collaborator that owns run snapshot persistence and caching.
///
/// Extracted from [StoryGenerationRunStore] to isolate snapshot storage/cache
/// mechanics from run orchestration concerns.
class StoryGenerationRunSnapshotRepository {
  StoryGenerationRunSnapshotRepository(this._storage);

  final StoryGenerationRunStorage _storage;
  final Map<String, StoryGenerationRunSnapshot> _cachedSnapshots =
      <String, StoryGenerationRunSnapshot>{};

  /// Restores a snapshot for [sceneScopeId] from storage and refreshes cache.
  ///
  /// Returns `null` if no snapshot exists for the scope.
  Future<StoryGenerationRunSnapshot?> restore(String sceneScopeId) async {
    final loaded = await _storage.load(sceneScopeId: sceneScopeId);
    if (loaded == null) {
      return null;
    }
    final snapshot = StoryGenerationRunSnapshot.fromJson({
      for (final entry in loaded.entries)
        entry.key: cloneStorageValue(entry.value),
    });
    _cachedSnapshots[sceneScopeId] = snapshot;
    return snapshot;
  }

  /// Persists [snapshot] for [sceneScopeId] to storage and cache.
  Future<void> persist(
    StoryGenerationRunSnapshot snapshot,
    String sceneScopeId,
  ) async {
    final payload = {...snapshot.toJson(), 'sceneScopeId': sceneScopeId};
    await _storage.save(payload, sceneScopeId: sceneScopeId);
    _cachedSnapshots[sceneScopeId] = snapshot;
  }

  /// Returns the cached snapshot for [sceneScopeId] if available.
  StoryGenerationRunSnapshot? getCached(String sceneScopeId) {
    return _cachedSnapshots[sceneScopeId];
  }

  /// Clears the cached snapshot for [sceneScopeId].
  void clearCached(String sceneScopeId) {
    _cachedSnapshots.remove(sceneScopeId);
  }

  /// Clears all cached snapshots for [projectId].
  void clearCachedProject(String projectId) {
    final sceneScopePrefix = '$projectId::';
    _cachedSnapshots.removeWhere(
      (key, _) => key == projectId || key.startsWith(sceneScopePrefix),
    );
  }

  /// Clears all cached snapshots.
  void clearAllCached() {
    _cachedSnapshots.clear();
  }

  /// Clears storage for [sceneScopeId] if provided, otherwise clears all.
  Future<void> clearStorage([String? sceneScopeId]) async {
    await _storage.clear(sceneScopeId: sceneScopeId);
  }

  /// Clears storage for all scene scopes under [projectId].
  Future<void> clearProjectStorage(String projectId) async {
    await _storage.clearProject(projectId);
  }

  /// Exports snapshots for all scenes in [sceneScopeIds] that have [hasRun].
  ///
  /// Returns a cloned map to prevent callers from mutating the internal cache.
  /// Each snapshot JSON is also cloned to prevent reference mutation.
  Map<String, Object?> exportProjectSnapshots(List<String> sceneScopeIds) {
    final result = <String, Object?>{};
    for (final sceneScopeId in sceneScopeIds) {
      final cached = _cachedSnapshots[sceneScopeId];
      if (cached != null && cached.hasRun) {
        result[sceneScopeId] = _cloneSnapshotJson(cached.toJson());
        continue;
      }
    }
    return Map<String, Object?>.unmodifiable(result);
  }

  /// Loads and exports snapshots for [sceneScopeIds] from storage.
  ///
  /// Only includes snapshots that have [hasRun].
  /// Returns a cloned map to prevent callers from mutating storage payloads.
  Future<Map<String, Object?>> exportStoredSnapshots(
    List<String> sceneScopeIds,
  ) async {
    final result = <String, Object?>{};
    for (final sceneScopeId in sceneScopeIds) {
      final restored = await _storage.load(sceneScopeId: sceneScopeId);
      if (restored == null) {
        continue;
      }
      final restoredSnapshot = StoryGenerationRunSnapshot.fromJson({
        for (final entry in restored.entries)
          entry.key: cloneStorageValue(entry.value),
      });
      if (!restoredSnapshot.hasRun) {
        continue;
      }
      _cachedSnapshots[sceneScopeId] = restoredSnapshot;
      result[sceneScopeId] = _cloneSnapshotJson(restoredSnapshot.toJson());
    }
    return Map<String, Object?>.unmodifiable(result);
  }

  /// Imports [snapshotMap] into storage and cache.
  ///
  /// Clears all cached snapshots for [knownScopeIds] before importing.
  /// Accepts any map-valued entry key as a scene scope.
  /// Each imported payload is cloned before storage to prevent caller mutation.
  Future<void> importProjectSnapshots(
    Map<String, Object?> snapshotMap,
    List<String> knownScopeIds,
  ) async {
    await clearKnownScopes(knownScopeIds);

    for (final entry in snapshotMap.entries) {
      final sceneScopeId = entry.key.toString();
      if (entry.value is! Map) {
        continue;
      }
      final payload = _asStringObjectMap(entry.value);
      await _storage.save(payload, sceneScopeId: sceneScopeId);
      final restoredSnapshot = StoryGenerationRunSnapshot.fromJson(payload);
      _cachedSnapshots[sceneScopeId] = restoredSnapshot;
    }
  }

  /// Clears storage and cache for all [knownScopeIds].
  Future<void> clearKnownScopes(List<String> knownScopeIds) async {
    for (final sceneScopeId in knownScopeIds) {
      _cachedSnapshots.remove(sceneScopeId);
      await _storage.clear(sceneScopeId: sceneScopeId);
    }
  }

  /// Deep-clones a snapshot JSON map to prevent caller mutation.
  static Map<String, Object?> _cloneSnapshotJson(Map<String, Object?> json) {
    return cloneStorageMap(json);
  }
}
