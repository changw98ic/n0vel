import 'app_storage_clone.dart';

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
