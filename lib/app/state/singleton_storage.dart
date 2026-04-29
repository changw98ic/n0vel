import 'app_storage_clone.dart';

/// Abstract interface for singleton (non-project-scoped) key-value storage.
///
/// Used by storage backends that manage a single global record
/// without project scoping (e.g. workspace state).
abstract class SingletonStorage {
  Future<Map<String, Object?>?> load();

  Future<void> save(Map<String, Object?> data);

  Future<void> clear();
}

/// In-memory implementation of [SingletonStorage].
class InMemorySingletonStorage implements SingletonStorage {
  Map<String, Object?>? _data;

  @override
  Future<Map<String, Object?>?> load() async {
    return _data == null ? null : cloneStorageMap(_data!);
  }

  @override
  Future<void> save(Map<String, Object?> data) async {
    _data = cloneStorageMap(data);
  }

  @override
  Future<void> clear() async {
    _data = null;
  }
}
