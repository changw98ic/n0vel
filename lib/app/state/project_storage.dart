import 'app_storage_clone.dart';

/// Optional lifecycle contract implemented by storage decorators that batch
/// writes (for example [CachedProjectStorage]).
///
/// The base [ProjectStorage] API intentionally remains unchanged so existing
/// in-memory and synchronous implementations do not need lifecycle plumbing.
abstract interface class ProjectStorageFlushable {
  Future<void> flush();
}

/// Cancels deferred writes without making them durable.
///
/// This is used when a database is being replaced during disaster recovery.
/// Pending edits belong to the discarded database and must not be flushed
/// before the backup is installed. Implementations should invalidate any
/// in-flight completion callbacks as far as their backend permits.
abstract interface class ProjectStorageDiscardable {
  void discard();
}

/// Quiesces a storage scope for disaster recovery without flushing pending
/// snapshots. Implementations wait for an already-started backend call to
/// leave its critical section before the owning database is replaced.
abstract interface class ProjectStorageQuiesceable {
  Future<void> quiesce();
}

/// Flushes a project storage when it has an asynchronous write queue.
///
/// Most storage implementations write synchronously inside their Future and
/// therefore have nothing to do here.  Keeping the check at this boundary
/// lets stores expose one common lifecycle hook without depending on a
/// concrete cache implementation.
Future<void> flushProjectStorage(ProjectStorage? storage) async {
  if (storage case final ProjectStorageFlushable flushable) {
    await flushable.flush();
  }
}

Future<void> quiesceProjectStorage(ProjectStorage? storage) async {
  if (storage case final ProjectStorageQuiesceable quiesceable) {
    await quiesceable.quiesce();
  }
}

/// Abstract interface for project-scoped key-value storage.
///
/// All project-scoped storage backends (outline, generation, version,
/// simulation, AI history, scene context, draft) share this identical
/// load/save/clear contract keyed by [projectId].
abstract class ProjectStorage {
  Future<Map<String, Object?>?> load({required String projectId});

  Future<void> save(Map<String, Object?> data, {required String projectId});

  Future<void> clear({String? projectId});

  Future<void> clearProject(String projectId) => clear(projectId: projectId);
}

/// In-memory implementation of [ProjectStorage] for testing and web targets.
class InMemoryProjectStorage implements ProjectStorage {
  final Map<String, Map<String, Object?>> _records = {};

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    final data = _records[projectId];
    return data == null ? null : cloneStorageMap(data);
  }

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    _records[projectId] = cloneStorageMap(data);
  }

  @override
  Future<void> clear({String? projectId}) async {
    if (projectId == null) {
      _records.clear();
      return;
    }
    _records.remove(projectId);
  }

  @override
  Future<void> clearProject(String projectId) async {
    final sceneScopePrefix = '$projectId::';
    _records.removeWhere(
      (key, _) => key == projectId || key.startsWith(sceneScopePrefix),
    );
  }
}
