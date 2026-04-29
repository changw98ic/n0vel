import '../domain/memory_models.dart';

/// Abstract storage contract for local-first memory persistence.
abstract interface class StoryMemoryStorage {
  Future<void> saveSources(String projectId, List<StoryMemorySource> sources);
  Future<List<StoryMemorySource>> loadSources(String projectId);
  Future<void> saveChunks(String projectId, List<StoryMemoryChunk> chunks);
  Future<List<StoryMemoryChunk>> loadChunks(String projectId);
  Future<void> saveThoughts(String projectId, List<ThoughtAtom> thoughts);
  Future<List<ThoughtAtom>> loadThoughts(String projectId);
  Future<void> clearProject(String projectId);
}
