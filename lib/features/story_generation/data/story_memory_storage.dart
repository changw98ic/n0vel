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

/// Storage capability for replacing one producer-owned scene generation.
///
/// Implementations must preserve chunks owned by every other scope or
/// producer. [includeLegacyContextRows] is a one-way compatibility cleanup for
/// the historical context-enrichment ID format and must remain fail-closed.
abstract interface class OwnedGenerationMemoryStorage {
  Future<void> replaceOwnedGeneration({
    required String projectId,
    required String scopeId,
    required String producer,
    required List<StoryMemoryChunk> chunks,
    bool includeLegacyContextRows = false,
  });
}
