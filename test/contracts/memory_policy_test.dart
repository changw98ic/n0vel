import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryTier', () {
    test('has five tiers', () {
      expect(MemoryTier.values, hasLength(5));
    });

    test('tier order is authoritative to ephemeral', () {
      expect(MemoryPolicy.tierOrder, [
        MemoryTier.canon,
        MemoryTier.character,
        MemoryTier.scene,
        MemoryTier.draft,
        MemoryTier.meta,
      ]);
    });
  });

  group('MemoryPolicy', () {
    test('canon policy requires soul validation', () {
      expect(MemoryPolicy.canonPolicy.requireSoulValidation, isTrue);
      expect(MemoryPolicy.canonPolicy.tier, MemoryTier.canon);
      expect(MemoryPolicy.canonPolicy.retentionScenes, 0);
    });

    test('character policy requires soul validation', () {
      expect(MemoryPolicy.characterPolicy.requireSoulValidation, isTrue);
    });

    test('scene policy is indexed', () {
      expect(MemoryPolicy.scenePolicy.indexForRetrieval, isTrue);
      expect(MemoryPolicy.scenePolicy.retentionScenes, 50);
    });

    test('draft policy is not indexed', () {
      expect(MemoryPolicy.draftPolicy.indexForRetrieval, isFalse);
    });

    test('meetsMinimum: canon meets everything', () {
      for (final tier in MemoryTier.values) {
        expect(
          MemoryPolicy.meetsMinimum(MemoryTier.canon, tier),
          isTrue,
          reason: 'canon should meet $tier',
        );
      }
    });

    test('meetsMinimum: draft meets only draft and meta', () {
      expect(MemoryPolicy.meetsMinimum(MemoryTier.draft, MemoryTier.draft), isTrue);
      expect(MemoryPolicy.meetsMinimum(MemoryTier.draft, MemoryTier.meta), isTrue);
      expect(MemoryPolicy.meetsMinimum(MemoryTier.draft, MemoryTier.scene), isFalse);
      expect(MemoryPolicy.meetsMinimum(MemoryTier.draft, MemoryTier.canon), isFalse);
    });

    test('meetsMinimum: same tier meets itself', () {
      for (final tier in MemoryTier.values) {
        expect(MemoryPolicy.meetsMinimum(tier, tier), isTrue);
      }
    });
  });
}
