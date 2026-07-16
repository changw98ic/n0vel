import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('indexed CJK RAG retrieval', () {
    late Database db;
    late LocalRagStorage storage;

    setUp(() {
      db = sqlite3.openInMemory();
      storage = LocalRagStorage(db: db);
    });

    tearDown(() => db.dispose());

    test('uses the CJK FTS side index for unsegmented prose', () async {
      await storage.indexDocument(
        projectId: 'p1',
        path: 'p1/world/heita.md',
        content: '黑塔隐藏在深山之中，蕴含神秘力量。',
        category: 'world',
      );

      final indexed = db.select(
        "SELECT count(*) AS count FROM rag_cjk_fts WHERE rag_cjk_fts MATCH '黑塔 OR 神秘'",
      );
      expect(indexed.single['count'], 1);

      final hits = await storage.searchFts(projectId: 'p1', query: '黑塔神秘');
      expect(hits.map((hit) => hit.path), contains('p1/world/heita.md'));
    });

    test('indexes CJK terms beyond the former 512-token boundary', () async {
      final run = String.fromCharCodes(
        List<int>.generate(700, (index) => 0x4e00 + index),
      );
      final tailTerm = String.fromCharCodes(<int>[0x4e00 + 698, 0x4e00 + 699]);
      await storage.indexDocument(
        projectId: 'p1',
        path: 'p1/long-chapter.md',
        content: run,
        category: 'scene',
      );

      final hits = await storage.searchFts(projectId: 'p1', query: tailTerm);
      expect(hits.map((hit) => hit.path), contains('p1/long-chapter.md'));
    });

    test(
      'updates and deletes CJK index rows with their source document',
      () async {
        await storage.indexDocument(
          projectId: 'p1',
          path: 'p1/scene.md',
          content: '旧城门已经关闭。',
          category: 'scene',
        );
        await storage.indexDocument(
          projectId: 'p1',
          path: 'p1/scene.md',
          content: '新港口已经开放。',
          category: 'scene',
        );

        expect(await storage.searchFts(projectId: 'p1', query: '旧城门'), isEmpty);
        expect(
          await storage.searchFts(projectId: 'p1', query: '新港口'),
          hasLength(1),
        );

        await storage.clearProject('p1');
        expect(db.select('SELECT rowid FROM rag_cjk_fts'), isEmpty);
      },
    );

    test(
      'rebuilds same-sized CJK index when its version and content are stale',
      () async {
        await storage.indexDocument(
          projectId: 'p1',
          path: 'p1/stale.md',
          content: '旧城门已经关闭。',
          category: 'scene',
        );
        final rowCountBefore = db
            .select('SELECT COUNT(*) AS count FROM rag_cjk_fts')
            .single['count'];
        db.execute('UPDATE rag_documents SET content = ? WHERE path = ?', [
          '新港口已经开放。',
          'p1/stale.md',
        ]);
        db.execute(
          "UPDATE rag_index_meta SET value = 'stale' WHERE key = 'cjk_index_version'",
        );
        expect(
          db
              .select(
                "SELECT COUNT(*) AS count FROM rag_cjk_fts WHERE rag_cjk_fts MATCH '旧城'",
              )
              .single['count'],
          1,
        );
        expect(
          db
              .select(
                "SELECT COUNT(*) AS count FROM rag_cjk_fts WHERE rag_cjk_fts MATCH '新港'",
              )
              .single['count'],
          0,
        );

        final reopened = LocalRagStorage(db: db);
        await reopened.ensureTables();

        expect(
          db
              .select('SELECT COUNT(*) AS count FROM rag_cjk_fts')
              .single['count'],
          rowCountBefore,
        );
        expect(
          db
              .select(
                "SELECT COUNT(*) AS count FROM rag_cjk_fts WHERE rag_cjk_fts MATCH '旧城'",
              )
              .single['count'],
          0,
        );
        expect(
          db
              .select(
                "SELECT COUNT(*) AS count FROM rag_cjk_fts WHERE rag_cjk_fts MATCH '新港'",
              )
              .single['count'],
          1,
        );
      },
    );

    test('keeps project and category filters in SQLite', () async {
      await storage.indexDocument(
        projectId: 'p1',
        path: 'p1/character.md',
        content: '银月骑士守护北门。',
        category: 'character',
      );
      await storage.indexDocument(
        projectId: 'p2',
        path: 'p2/world.md',
        content: '银月骑士守护南门。',
        category: 'world',
      );

      final hits = await storage.searchFts(
        projectId: 'p1',
        query: '银月骑士',
        category: 'character',
      );
      expect(hits.map((hit) => hit.path), ['p1/character.md']);
    });

    test(
      'offline semantic embedding overlaps short and long CJK text',
      () async {
        final retriever = HybridRetriever.local(db: db);
        await retriever.indexChunks([
          const StoryMemoryChunk(
            id: 'p1/world/heita.md',
            projectId: 'p1',
            scopeId: 'p1',
            kind: MemorySourceKind.worldFact,
            content: '黑塔隐藏在深山之中，蕴含神秘力量。',
            tier: MemoryTier.canon,
          ),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'p1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: '黑塔神秘',
            maxResults: 10,
          ),
          const RagRetrievalPolicy(
            roleId: 'cjk-semantic-test',
            allowedTiers: [MemoryTier.canon],
            excludeDraftTier: false,
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        expect(pack.hits.map((hit) => hit.chunk.id), ['p1/world/heita.md']);
        expect(pack.hits.single.score, greaterThan(0));
      },
    );
  });
}
