import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RagRetrievalPolicy', () {
    test('default weights are valid', () {
      const policy = RagRetrievalPolicy(roleId: 'test');
      expect(policy.weightsValid, isTrue);
      expect(policy.semanticWeight + policy.keywordWeight, closeTo(1.0, 0.01));
    });

    test('default excludes draft tier', () {
      const policy = RagRetrievalPolicy(roleId: 'test');
      expect(policy.excludeDraftTier, isTrue);
    });

    test('allowedTiers defaults to canon+character+scene', () {
      const policy = RagRetrievalPolicy(roleId: 'test');
      expect(policy.allowedTiers, [
        MemoryTier.canon,
        MemoryTier.character,
        MemoryTier.scene,
      ]);
    });
  });

  group('RagRetrievalPolicy.director()', () {
    test('must include canon', () {
      final policy = RagRetrievalPolicy.director();
      expect(policy.mustIncludeCanon, isTrue);
      expect(policy.roleId, 'director');
      expect(policy.maxTokens, 3000);
    });
  });

  group('RagRetrievalPolicy.roleplay()', () {
    test('has standard token budget', () {
      final policy = RagRetrievalPolicy.roleplay();
      expect(policy.roleId, 'roleplay');
      expect(policy.maxTokens, 2000);
      expect(policy.mustIncludeCanon, isFalse);
    });
  });

  group('RagRetrievalPolicy.review()', () {
    test('only accesses canon tier', () {
      final policy = RagRetrievalPolicy.review();
      expect(policy.roleId, 'review');
      expect(policy.allowedTiers, [MemoryTier.canon]);
      expect(policy.maxTokens, 1000);
      expect(policy.keywordWeight, greaterThan(policy.semanticWeight));
    });
  });

  group('RankingStrategy', () {
    test('has three strategies', () {
      expect(RankingStrategy.values, hasLength(3));
    });
  });
}
