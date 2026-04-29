import 'app_storage_clone.dart';
import 'story_generation_run_storage_stub.dart'
    if (dart.library.io) 'story_generation_run_storage_io.dart';

abstract class StoryGenerationRunStorage {
  Future<Map<String, Object?>?> load({required String sceneScopeId});

  Future<void> save(Map<String, Object?> data, {required String sceneScopeId});

  Future<void> clear({String? sceneScopeId});
}

class InMemoryStoryGenerationRunStorage implements StoryGenerationRunStorage {
  final Map<String, Map<String, Object?>> _records = {};

  @override
  Future<Map<String, Object?>?> load({required String sceneScopeId}) async {
    final data = _records[sceneScopeId];
    return data == null ? null : cloneStorageMap(data);
  }

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String sceneScopeId,
  }) async {
    _records[sceneScopeId] = cloneStorageMap(data);
  }

  @override
  Future<void> clear({String? sceneScopeId}) async {
    if (sceneScopeId == null) {
      _records.clear();
      return;
    }
    _records.remove(sceneScopeId);
  }
}

StoryGenerationRunStorage createDefaultStoryGenerationRunStorage() =>
    createStoryGenerationRunStorage();
