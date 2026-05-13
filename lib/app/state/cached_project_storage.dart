import 'dart:async';

import 'app_storage_clone.dart';
import 'project_storage.dart';

/// Caching decorator for [ProjectStorage] that reduces redundant disk I/O.
///
/// **Read cache**: previously loaded data is kept in memory so repeated loads
/// for the same project skip the database entirely.
///
/// **Debounced writes**: rapid successive saves are coalesced — only the
/// latest data per project is written to disk after a short idle window
/// (default 100 ms).  Call [flush] to force immediate persistence.
class CachedProjectStorage implements ProjectStorage {
  CachedProjectStorage(
    this._delegate, {
    Duration writeDelay = const Duration(milliseconds: 100),
  }) : _writeDelay = writeDelay;

  final ProjectStorage _delegate;
  final Duration _writeDelay;

  /// In-memory read cache keyed by projectId.
  /// Missing rows are intentionally not cached, so imports or external writes
  /// can become visible the next time a store restores the active project.
  final Map<String, Map<String, Object?>> _cache = {};

  /// Projects with pending writes not yet flushed to disk.
  final Map<String, Map<String, Object?>> _pending = {};

  Timer? _writeTimer;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    if (_cache.containsKey(projectId)) {
      final cached = _cache[projectId]!;
      return cloneStorageMap(cached);
    }
    final data = await _delegate.load(projectId: projectId);
    if (data == null) {
      return null;
    }
    _cache[projectId] = cloneStorageMap(data);
    return cloneStorageMap(data);
  }

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    final cloned = cloneStorageMap(data);
    _cache[projectId] = cloned;
    _pending[projectId] = cloned;
    _scheduleFlush();
  }

  @override
  Future<void> clear({String? projectId}) async {
    _writeTimer?.cancel();
    _writeTimer = null;
    if (projectId == null) {
      _cache.clear();
      _pending.clear();
    } else {
      _cache.remove(projectId);
      _pending.remove(projectId);
    }
    await _delegate.clear(projectId: projectId);
  }

  @override
  Future<void> clearProject(String projectId) async {
    _writeTimer?.cancel();
    _writeTimer = null;
    final sceneScopePrefix = '$projectId::';
    _cache.removeWhere(
      (key, _) => key == projectId || key.startsWith(sceneScopePrefix),
    );
    _pending.removeWhere(
      (key, _) => key == projectId || key.startsWith(sceneScopePrefix),
    );
    await _delegate.clearProject(projectId);
  }

  /// Forces all pending writes to disk immediately.
  Future<void> flush() async {
    _writeTimer?.cancel();
    _writeTimer = null;
    await _flushPending();
  }

  /// Flushes any pending writes to disk, then releases the timer.
  Future<void> dispose() async {
    _writeTimer?.cancel();
    _writeTimer = null;
    await _flushPending();
  }

  void _scheduleFlush() {
    _writeTimer ??= Timer(_writeDelay, _onTimer);
  }

  void _onTimer() {
    _writeTimer = null;
    unawaited(_flushPending());
  }

  Future<void> _flushPending() async {
    if (_pending.isEmpty) return;
    final batch = Map<String, Map<String, Object?>>.from(_pending);
    _pending.clear();
    for (final entry in batch.entries) {
      await _delegate.save(entry.value, projectId: entry.key);
    }
  }
}
