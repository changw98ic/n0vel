import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/agentic_rag_ranker.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';

void main() {
  const keywordPolicy = RagRetrievalPolicy(
    roleId: 'test',
    rankingStrategy: RankingStrategy.keyword,
  );
  const ranker = AgenticRagRanker();

  group('CJK tokenizeForOverlap', () {
    test('splits ASCII on whitespace', () {
      final tokens = tokenizeForOverlap('the ancient key');
      expect(tokens, containsAll(['the', 'ancient', 'key']));
    });

    test('produces character bigrams for CJK text', () {
      final tokens = tokenizeForOverlap('古代钥匙');
      expect(tokens, containsAll(['古代', '代钥', '钥匙']));
    });

    test('handles mixed CJK and ASCII', () {
      final tokens = tokenizeForOverlap('Liu Xi 柳絮 is cautious');
      expect(tokens, containsAll(['liu', 'xi', 'is', 'cautious']));
      expect(tokens, containsAll(['柳絮']));
    });

    test('handles single CJK character gracefully', () {
      final tokens = tokenizeForOverlap('钥匙');
      expect(tokens, containsAll(['钥匙']));
      final single = tokenizeForOverlap('门');
      expect(single, contains('门'));
    });

    test('empty string returns empty tokens', () {
      expect(tokenizeForOverlap(''), isEmpty);
    });

    test('whitespace-only returns empty tokens', () {
      expect(tokenizeForOverlap('   '), isEmpty);
    });
  });

  group('CJK ranker recall', () {
    double score(
      AgenticRagRankInput input,
      String query, [
      List<String> tags = const [],
    ]) => ranker.score(input, query, tags, keywordPolicy);

    test('Chinese bigram query scores each adjacent overlap', () {
      const input = AgenticRagRankInput(
        id: 'a1',
        content: '古代钥匙在火灾中遗失了，英雄需要找到替代方案。',
        tags: ['plot', 'key'],
      );

      expect(score(input, '钥匙 遗失'), equals(2.0 * 4.0));
    });

    test('CJK partial match scores higher than zero', () {
      const input = AgenticRagRankInput(
        id: 'a2',
        content: '柳絮是一个谨慎而善于分析的角色',
        tags: ['character'],
      );

      expect(score(input, '柳絮 角色'), greaterThan(0.0));
    });

    test('mixed CJK and ASCII query scores both token families', () {
      const input = AgenticRagRankInput(
        id: 'mixed',
        content: 'Liu Xi 柳絮 keeps the ancient key hidden.',
      );

      expect(score(input, 'Liu Xi 柳絮 key'), equals(4.0 * 4.0));
    });

    test('CJK bigram overlap captures adjacent character matches', () {
      const input = AgenticRagRankInput(id: 'a3', content: '黑暗中的影子将在第三章背叛主角。');

      expect(score(input, '影子 背叛'), greaterThan(0.0));
    });

    test('English-only scoring keeps legacy weights', () {
      const input = AgenticRagRankInput(
        id: 'a4',
        content: 'The ancient key was lost in the fire.',
        tags: ['state', 'key'],
      );

      expect(
        score(input, 'key lost fire', ['key']),
        equals(3.0 * 4.0 + 1.0 * 6.0),
      );
    });

    test('CJK query with no match scores zero', () {
      const input = AgenticRagRankInput(
        id: 'a5',
        content: 'The weather is sunny and mild.',
        tags: ['weather'],
      );

      expect(score(input, '钥匙 遗失'), equals(0.0));
    });

    test('CJK query ranks relevant input above irrelevant one', () {
      const inputs = [
        AgenticRagRankInput(id: 'relevant', content: '柳絮拿起古代钥匙，准备进入黑塔。'),
        AgenticRagRankInput(id: 'irrelevant', content: '天气晴朗，城门外人群熙攘。'),
      ];

      final ranked = ranker.rank(inputs, '古代钥匙 黑塔', [], keywordPolicy);
      expect(ranked.first.input.id, equals('relevant'));
      expect(ranked.first.finalScore, greaterThan(ranked.last.finalScore));
    });
  });
}
