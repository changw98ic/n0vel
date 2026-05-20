import 'character_memory_delta_models.dart';
import '../domain/contracts/memory_policy.dart';

abstract interface class CharacterMemoryStore {
  Future<void> saveAcceptedDeltas({
    required String projectId,
    required String chapterId,
    required String sceneId,
    required MemoryTier tier,
    required String producer,
    required List<CharacterMemoryDelta> deltas,
  });

  Future<List<CharacterMemoryDelta>> loadCharacterMemories({
    required String projectId,
    required String characterId,
    required MemoryTier tier,
  });

  Future<List<CharacterMemoryDelta>> loadPublicMemories({
    required String projectId,
    required MemoryTier tier,
  });

  Future<void> clearProject(String projectId);
}
