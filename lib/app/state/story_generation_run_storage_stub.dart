import 'story_generation_run_storage.dart';

class _NoopStoryGenerationRunStorage implements StoryGenerationRunStorage {
  @override
  Future<Map<String, Object?>?> load({required String sceneScopeId}) async =>
      null;

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String sceneScopeId,
  }) async {}

  @override
  Future<void> clear({String? sceneScopeId}) async {}
}

StoryGenerationRunStorage createStoryGenerationRunStorage() =>
    _NoopStoryGenerationRunStorage();
