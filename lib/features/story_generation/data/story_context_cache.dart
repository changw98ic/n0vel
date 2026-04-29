import '../domain/scene_models.dart';

/// Computes a stable fingerprint from material content strings.
int _materialFingerprint(ProjectMaterialSnapshot materials) {
  return Object.hash(
    Object.hashAllUnordered(materials.worldFacts),
    Object.hashAllUnordered(materials.characterProfiles),
    Object.hashAllUnordered(materials.relationshipHints),
    Object.hashAllUnordered(materials.outlineBeats),
    Object.hashAllUnordered(materials.sceneSummaries),
    Object.hashAllUnordered(materials.acceptedStates),
    Object.hashAllUnordered(materials.reviewFindings),
  );
}

class _CacheEntry {
  _CacheEntry({
    required this.assembly,
    required this.fingerprint,
    required this.createdAtMs,
  });

  final SceneContextAssembly assembly;
  final int fingerprint;
  final int createdAtMs;
}

/// Caches [SceneContextAssembly] results keyed by project and scope.
///
/// When generating multiple scenes in the same chapter, the project materials
/// rarely change between scenes. This cache avoids redundant indexing work by
/// returning a previously assembled context when the materials fingerprint
/// matches. Entries expire after a configurable TTL.
class StoryContextCache {
  StoryContextCache({this.defaultTtlMs = 300000});

  final int defaultTtlMs;

  final Map<String, Map<String, _CacheEntry>> _entries = {};

  int _hits = 0;
  int _misses = 0;

  /// Total cache hits since creation.
  int get hits => _hits;

  /// Total cache misses since creation.
  int get misses => _misses;

  /// Looks up a cached assembly for the given scope.
  ///
  /// Returns the cached assembly if it exists, the materials fingerprint
  /// matches, and the entry has not expired. Returns `null` otherwise.
  SceneContextAssembly? lookup(
    String projectId,
    String scopeId,
    ProjectMaterialSnapshot materials, {
    int? nowMs,
  }) {
    final effectiveNow = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final projectEntries = _entries[projectId];
    if (projectEntries == null) {
      _misses++;
      return null;
    }

    final entry = projectEntries[scopeId];
    if (entry == null) {
      _misses++;
      return null;
    }

    final fingerprint = _materialFingerprint(materials);
    if (entry.fingerprint != fingerprint) {
      projectEntries.remove(scopeId);
      if (projectEntries.isEmpty) _entries.remove(projectId);
      _misses++;
      return null;
    }

    if (effectiveNow >= entry.createdAtMs + defaultTtlMs) {
      projectEntries.remove(scopeId);
      if (projectEntries.isEmpty) _entries.remove(projectId);
      _misses++;
      return null;
    }

    _hits++;
    return entry.assembly;
  }

  /// Stores an assembly in the cache.
  void store(
    String projectId,
    String scopeId,
    SceneContextAssembly assembly,
    ProjectMaterialSnapshot materials, {
    int? nowMs,
  }) {
    final effectiveNow = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _entries.putIfAbsent(projectId, () => {});
    _entries[projectId]![scopeId] = _CacheEntry(
      assembly: assembly,
      fingerprint: _materialFingerprint(materials),
      createdAtMs: effectiveNow,
    );
  }

  /// Invalidates all cache entries for a project.
  void invalidateProject(String projectId) {
    _entries.remove(projectId);
  }

  /// Clears all cache entries and resets hit/miss counters.
  void clearAll() {
    _entries.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Number of cached entries across all projects.
  int get size => _entries.values.fold(0, (sum, map) => sum + map.length);

  /// Number of projects with cached entries.
  int get projectCount => _entries.length;
}
