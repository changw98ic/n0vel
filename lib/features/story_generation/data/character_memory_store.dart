import 'character_memory_delta_models.dart';

abstract interface class CharacterMemoryStore {
  Future<void> saveAcceptedDeltas({
    required String projectId,
    required String chapterId,
    required String sceneId,
    required List<CharacterMemoryDelta> deltas,
  });

  Future<List<CharacterMemoryDelta>> loadCharacterMemories({
    required String projectId,
    required String characterId,
  });

  Future<List<CharacterMemoryDelta>> loadPublicMemories({
    required String projectId,
  });

  Future<void> clearProject(String projectId);
}
