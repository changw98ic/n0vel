import '../domain/pipeline_models.dart';
import '../domain/memory_models.dart';

/// Visibility scope for capsule access.
enum KnowledgeVisibility {
  /// Visible to all agents and review passes.
  publicObservable,

  /// Visible only to the agent that created it.
  agentPrivate,
}

/// A capsule entry with TTL, access metadata, source trace, and thought priority.
class CapsuleEntry {
  const CapsuleEntry({
    required this.capsule,
    required this.scopeId,
    required this.insertedAtMs,
    required this.ttlMs,
    required this.visibility,
    this.viewerId,
    this.sourceRefs = const [],
    this.thoughtPriority = 0,
  });

  final ContextCapsule capsule;
  final String scopeId;
  final int insertedAtMs;
  final int ttlMs;
  final KnowledgeVisibility visibility;
  final String? viewerId;

  /// Source references from memory retrieval, preserved for audit.
  final List<MemorySourceRef> sourceRefs;

  /// Thought priority level for ranking. Higher = more important.
  final int thoughtPriority;

  bool isExpired(int nowMs) => nowMs >= insertedAtMs + ttlMs;
}

/// Turn-local store for [ContextCapsule]s with TTL, capacity, source trace,
/// and thought priority behavior.
///
/// Capsules are scoped by turn/scope ID and expire after a configurable TTL.
/// Capacity limits prevent prompt bloat. Viewer-based access enforces
/// visibility rules.
class ContextCapsuleStore {
  ContextCapsuleStore({
    this.defaultTtlMs = 60000,
    this.maxCapsulesPerScope = 10,
  });

  final int defaultTtlMs;
  final int maxCapsulesPerScope;

  final List<CapsuleEntry> _entries = [];

  /// Inserts a capsule into the given scope.
  ///
  /// If the scope is at capacity, the oldest entry with the lowest thought
  /// priority is evicted first.
  void insert(
    ContextCapsule capsule,
    String scopeId, {
    int? ttlMs,
    KnowledgeVisibility visibility = KnowledgeVisibility.publicObservable,
    String? viewerId,
    int? nowMs,
    List<MemorySourceRef> sourceRefs = const [],
    int thoughtPriority = 0,
  }) {
    final effectiveNow = nowMs ?? DateTime.now().millisecondsSinceEpoch;

    _evictExpired(effectiveNow);
    _evictToCapacity(scopeId);

    _entries.add(CapsuleEntry(
      capsule: capsule,
      scopeId: scopeId,
      insertedAtMs: effectiveNow,
      ttlMs: ttlMs ?? defaultTtlMs,
      visibility: visibility,
      viewerId: viewerId,
      sourceRefs: sourceRefs,
      thoughtPriority: thoughtPriority,
    ));
  }

  /// Returns all non-expired capsules visible to [viewerId] in [scopeId].
  List<ContextCapsule> query(
    String scopeId,
    String? viewerId, {
    int? nowMs,
  }) {
    final effectiveNow = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _evictExpired(effectiveNow);

    return [
      for (final entry in _entries)
        if (entry.scopeId == scopeId &&
            !entry.isExpired(effectiveNow) &&
            _isVisibleTo(entry, viewerId))
          entry.capsule,
    ];
  }

  /// Returns all entries (including source refs and priority) for a scope.
  List<CapsuleEntry> queryEntries(
    String scopeId,
    String? viewerId, {
    int? nowMs,
  }) {
    final effectiveNow = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _evictExpired(effectiveNow);

    return [
      for (final entry in _entries)
        if (entry.scopeId == scopeId &&
            !entry.isExpired(effectiveNow) &&
            _isVisibleTo(entry, viewerId))
          entry,
    ];
  }

  /// Returns source refs for all capsules in a scope.
  List<MemorySourceRef> sourceRefsForScope(String scopeId, {int? nowMs}) {
    final effectiveNow = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _evictExpired(effectiveNow);
    return [
      for (final entry in _entries)
        if (entry.scopeId == scopeId && !entry.isExpired(effectiveNow))
          ...entry.sourceRefs,
    ];
  }

  /// Clears all entries for a given scope.
  void clearScope(String scopeId) {
    _entries.removeWhere((e) => e.scopeId == scopeId);
  }

  /// Clears all entries.
  void clearAll() {
    _entries.clear();
  }

  /// Number of active entries across all scopes.
  int get size => _entries.length;

  void _evictExpired(int nowMs) {
    _entries.removeWhere((e) => e.isExpired(nowMs));
  }

  void _evictToCapacity(String scopeId) {
    final scopeEntries =
        _entries.where((e) => e.scopeId == scopeId).toList();
    if (scopeEntries.length < maxCapsulesPerScope) return;

    // Evict lowest priority first, then oldest
    scopeEntries.sort((a, b) {
      final priorityCmp = a.thoughtPriority.compareTo(b.thoughtPriority);
      if (priorityCmp != 0) return priorityCmp;
      return a.insertedAtMs.compareTo(b.insertedAtMs);
    });
    final toEvict = scopeEntries.length - maxCapsulesPerScope + 1;
    for (var i = 0; i < toEvict; i++) {
      _entries.remove(scopeEntries[i]);
    }
  }

  bool _isVisibleTo(CapsuleEntry entry, String? viewerId) {
    if (entry.visibility == KnowledgeVisibility.publicObservable) return true;
    if (viewerId == null) return false;
    return entry.viewerId == viewerId;
  }
}
