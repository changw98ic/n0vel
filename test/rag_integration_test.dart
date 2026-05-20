import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('RagSceneContext', () {
    test('is empty when there are no results', () {
      const context = RagSceneContext(results: [], formattedContext: '');
      expect(context.isEmpty, isTrue);
    });

    test('is not empty with local annotation results', () {
      const context = RagSceneContext(
        results: [
          RagSearchResult(
            path: 'project-1/characters/liuxi.md',
            content: 'liuxi investigator',
            score: 0.92,
          ),
        ],
        formattedContext: 'some text',
      );

      expect(context.isEmpty, isFalse);
    });
  });

  group('Local RAG storage', () {
    test('returns indexed annotation documents from FTS', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      final storage = LocalRagStorage(db: db);
      await storage.indexDocument(
        projectId: 'project-1',
        path: 'project-1/characters/liuxi.md',
        content: 'liuxi investigator blacktower annotation',
        category: 'characters',
      );

      final results = await storage.searchFts(
        projectId: 'project-1',
        query: 'liuxi',
      );

      expect(results, hasLength(1));
      expect(results.single.path, 'project-1/characters/liuxi.md');
      expect(results.single.content, contains('blacktower'));
    });

    test(
      'updates the FTS index when an annotation path is rewritten',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);

        final storage = LocalRagStorage(db: db);
        await storage.indexDocument(
          projectId: 'project-1',
          path: 'project-1/worldbuilding/rule.md',
          content: 'oldmarker rule',
          category: 'worldbuilding',
        );
        await storage.indexDocument(
          projectId: 'project-1',
          path: 'project-1/worldbuilding/rule.md',
          content: 'newmarker rule',
          category: 'worldbuilding',
        );

        expect(
          await storage.searchFts(projectId: 'project-1', query: 'oldmarker'),
          isEmpty,
        );
        final results = await storage.searchFts(
          projectId: 'project-1',
          query: 'newmarker',
        );
        expect(results, hasLength(1));
        expect(results.single.content, 'newmarker rule');
      },
    );

    test(
      'matches unsegmented Chinese queries without leaking projects',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);

        final storage = LocalRagStorage(db: db);
        await storage.indexDocument(
          projectId: 'project-1',
          path: 'project-1/worldbuilding/heita.md',
          content: '黑塔隐藏在深山之中，蕴含神秘力量。',
          category: 'worldbuilding',
        );
        await storage.indexDocument(
          projectId: 'project-2',
          path: 'project-2/worldbuilding/heita.md',
          content: '黑塔隐藏在海边，蕴含神秘力量。',
          category: 'worldbuilding',
        );

        final results = await storage.searchFts(
          projectId: 'project-1',
          query: '黑塔神秘',
        );

        expect(results, hasLength(1));
        expect(results.single.path, 'project-1/worldbuilding/heita.md');
      },
    );
  });

  group('CJK lexical retrieval', () {
    test('finds Chinese content via FTS5 character-level matching', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      final storage = LocalRagStorage(db: db);
      await storage.indexDocument(
        projectId: 'project-1',
        path: 'project-1/worldbuilding/heita.md',
        content: '黑塔是古老的建筑，隐藏在深山之中。黑塔蕴含神秘力量。',
        category: 'worldbuilding',
      );

      final results = await storage.searchFts(
        projectId: 'project-1',
        query: '黑塔神秘',
      );

      expect(results, hasLength(1));
      expect(results.single.content, contains('黑塔'));
    });

    test('retrieves Chinese scene context through HybridRetriever', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      final rag = HybridRetriever.local(db: db);
      await rag.syncProject(
        projectId: 'project-1',
        characterProfiles: const ['刘锡是一位谨慎而富有分析力的学者。他总是带着一把备用钥匙。'],
        outlineBeats: const [],
        worldFacts: const [],
      );

      final context = await rag.retrieveForScene(
        projectId: 'project-1',
        sceneTitle: '刘锡',
        sceneSummary: '谨慎的学者进行调查',
      );

      expect(context.results, isNotEmpty);
      expect(context.formattedContext, contains('刘锡'));
    });
  });

  group('HybridRetriever local flow', () {
    test('indexes parsed annotations and formats scene context', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      final rag = HybridRetriever.local(db: db);
      await rag.syncProject(
        projectId: 'project-1',
        characterProfiles: const [
          'liuxi investigator who tracks blacktower anomalies',
        ],
        outlineBeats: const ['chapter beat opens the blacktower gate'],
        worldFacts: const ['blacktower rule forbids duplicated memories'],
      );

      final context = await rag.retrieveForScene(
        projectId: 'project-1',
        sceneTitle: 'blacktower',
        sceneSummary: 'liuxi investigates duplicated memories',
        castNames: const ['liuxi'],
      );

      expect(context.results, isNotEmpty);
      expect(context.formattedContext, contains('【RAG检索上下文】'));
      expect(context.formattedContext, contains('blacktower'));
      expect(
        context.results.map((result) => result.path),
        contains('project-1/characters/char_0.md'),
      );
    });
  });
}
