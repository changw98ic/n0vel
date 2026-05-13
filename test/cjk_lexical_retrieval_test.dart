import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/agentic_rag.dart';

void main() {
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
      // Single character should still appear as individual token
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

  group('CJK scoreAtom recall', () {
    late AgenticRag rag;

    setUp(() {
      rag = AgenticRag();
    });

    test('Chinese bigram query scores each adjacent overlap', () {
      const atom = RetrievalAtom(
        id: 'a1',
        content: '古代钥匙在火灾中遗失了，英雄需要找到替代方案。',
        sourceTool: 'plot',
        tags: ['plot', 'key'],
      );

      final score = rag.scoreAtom(atom, '钥匙 遗失', []);
      expect(score, equals(2.0 * 4.0));
    });

    test('CJK partial match scores higher than zero', () {
      const atom = RetrievalAtom(
        id: 'a2',
        content: '柳絮是一个谨慎而善于分析的角色',
        sourceTool: 'character',
        tags: ['character'],
      );

      // "柳絮" should match via bigram overlap
      final score = rag.scoreAtom(atom, '柳絮 角色', []);
      expect(score, greaterThan(0.0));
    });

    test('mixed CJK and ASCII query scores both token families', () {
      const atom = RetrievalAtom(
        id: 'mixed',
        content: 'Liu Xi 柳絮 keeps the ancient key hidden.',
        sourceTool: 'character',
        tags: [],
      );

      final score = rag.scoreAtom(atom, 'Liu Xi 柳絮 key', []);
      expect(score, equals(4.0 * 4.0));
    });

    test('CJK bigram overlap captures adjacent character matches', () {
      const atom = RetrievalAtom(
        id: 'a3',
        content: '黑暗中的影子将在第三章背叛主角。',
        sourceTool: 'plot',
        tags: [],
      );

      // "影子" and "背叛" are in the content, so bigrams should find them.
      final score = rag.scoreAtom(atom, '影子 背叛', []);
      expect(score, greaterThan(0.0));
    });

    test('English-only scoring is unchanged after CJK support', () {
      const atom = RetrievalAtom(
        id: 'a4',
        content: 'The ancient key was lost in the fire.',
        sourceTool: 'state',
        tags: ['state', 'key'],
      );

      // "key", "lost", "fire" all match: keyword=3; tag "key"=1.
      final score = rag.scoreAtom(atom, 'key lost fire', ['key']);
      expect(score, equals(3.0 * 4.0 + 1.0 * 6.0));
    });

    test('CJK query with no match scores zero', () {
      const atom = RetrievalAtom(
        id: 'a5',
        content: 'The weather is sunny and mild.',
        sourceTool: 'world',
        tags: ['weather'],
      );

      final score = rag.scoreAtom(atom, '钥匙 遗失', []);
      expect(score, equals(0.0));
    });

    test('CJK query ranks relevant atom above irrelevant one', () {
      const relevant = RetrievalAtom(
        id: 'rel',
        content: '古代钥匙在火中烧毁了。',
        sourceTool: 'state',
        tags: ['key'],
      );
      const irrelevant = RetrievalAtom(
        id: 'irr',
        content: '首都的天气晴朗温和。',
        sourceTool: 'world',
        tags: ['weather'],
      );

      final scored = rag.query([relevant, irrelevant], '钥匙 火灾', []);
      expect(scored.first.id, equals('rel'));
    });
  });
}
