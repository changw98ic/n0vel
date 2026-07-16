import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/app/rag/vector_store_schema.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake/fake_vector_store.dart';

// Recreate import here to avoid touching existing RAG files.
// ignore: implementation_imports
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';

const _testProjectId = 'proj';

List<double> _embed(String text) {
  final chars = text.codeUnits;
  return List.generate(
    8,
    (i) => chars.isNotEmpty ? (chars[i % chars.length] / 128.0) - 1.0 : 0.0,
  );
}

StoryMemoryChunk _chunk({
  String id = 'c1',
  String content = 'hello world',
  MemoryTier tier = MemoryTier.scene,
  List<String> tags = const [],
}) {
  return StoryMemoryChunk(
    id: id,
    projectId: 'proj',
    scopeId: 'scope',
    kind: MemorySourceKind.sceneSummary,
    content: content,
    tier: tier,
    tags: tags,
  );
}

void main() {
  // ── FakeVectorStore ─────────────────────────────────────────────────

  group('FakeVectorStore', () {
    late FakeVectorStore store;

    setUp(() => store = FakeVectorStore());

    test(
      'upsert and search returns scored hits sorted by similarity',
      () async {
        await store.upsert(
          id: 'a',
          projectId: _testProjectId,
          content: 'cat',
          embedding: [1.0, 0.0, 0.0],
          tier: MemoryTier.scene,
        );
        await store.upsert(
          id: 'b',
          projectId: _testProjectId,
          content: 'dog',
          embedding: [0.0, 1.0, 0.0],
          tier: MemoryTier.scene,
        );

        final hits = await store.search(
          embedding: [1.0, 0.0, 0.0],
          projectId: _testProjectId,
          limit: 5,
        );
        expect(hits, hasLength(2));
        expect(hits.first.id, 'a');
        expect(hits.first.score, closeTo(1.0, 1e-9));
        expect(hits.last.id, 'b');
        expect(hits.last.score, closeTo(0.0, 1e-9));
      },
    );

    test('tier filtering excludes non-matching tiers', () async {
      await store.upsert(
        id: 'canon',
        projectId: _testProjectId,
        content: 'world rule',
        embedding: [1.0, 0.0],
        tier: MemoryTier.canon,
      );
      await store.upsert(
        id: 'draft',
        projectId: _testProjectId,
        content: 'draft text',
        embedding: [1.0, 0.0],
        tier: MemoryTier.draft,
      );

      final hits = await store.search(
        embedding: [1.0, 0.0],
        projectId: _testProjectId,
        tiers: {MemoryTier.canon},
      );
      expect(hits, hasLength(1));
      expect(hits.first.id, 'canon');
    });

    test('delete removes entry from search results', () async {
      await store.upsert(
        id: 'x',
        projectId: _testProjectId,
        content: 'temporary',
        embedding: [1.0],
        tier: MemoryTier.draft,
      );
      await store.delete('x', projectId: _testProjectId);

      final hits = await store.search(
        embedding: [1.0],
        projectId: _testProjectId,
      );
      expect(hits, isEmpty);
    });

    test('indexChunks inserts via callback', () async {
      final chunks = [
        _chunk(id: 'c1', content: 'chunk one'),
        _chunk(id: 'c2', content: 'chunk two'),
      ];
      await store.indexChunks(chunks, (content) async => _embed(content));

      final hits = await store.search(
        embedding: _embed('chunk one'),
        projectId: _testProjectId,
      );
      expect(hits, hasLength(2));
      expect(hits.first.id, 'c1');
    });

    test('upsert overwrites existing entry', () async {
      await store.upsert(
        id: 'a',
        projectId: _testProjectId,
        content: 'old',
        embedding: [1.0, 0.0],
        tier: MemoryTier.scene,
      );
      await store.upsert(
        id: 'a',
        projectId: _testProjectId,
        content: 'new',
        embedding: [0.0, 1.0],
        tier: MemoryTier.canon,
      );

      final hits = await store.search(
        embedding: [0.0, 1.0],
        projectId: _testProjectId,
      );
      expect(hits, hasLength(1));
      expect(hits.first.content, 'new');
      expect(hits.first.tier, MemoryTier.canon);
    });
  });

  // ── SqliteVssStore ──────────────────────────────────────────────────

  group('SqliteVssStore', () {
    late Database db;
    late SqliteVssStore store;

    setUp(() {
      db = sqlite3.openInMemory();
      store = SqliteVssStore(db);
    });

    tearDown(() => db.dispose());

    test('upsert persists and search retrieves with metadata', () async {
      await store.upsert(
        id: 'a',
        projectId: _testProjectId,
        content: 'hello',
        embedding: [1.0, 0.0, 0.0],
        tier: MemoryTier.canon,
        metadata: {'source': 'test'},
      );

      final hits = await store.search(
        embedding: [1.0, 0.0, 0.0],
        projectId: _testProjectId,
      );
      expect(hits, hasLength(1));
      expect(hits.first.id, 'a');
      expect(hits.first.content, 'hello');
      expect(hits.first.tier, MemoryTier.canon);
      expect(hits.first.score, closeTo(1.0, 1e-9));
      expect(hits.first.metadata['source'], 'test');
    });

    test('search with tier filter', () async {
      await store.upsert(
        id: 'a',
        projectId: _testProjectId,
        content: 'a',
        embedding: [1.0, 0.0],
        tier: MemoryTier.canon,
      );
      await store.upsert(
        id: 'b',
        projectId: _testProjectId,
        content: 'b',
        embedding: [1.0, 0.0],
        tier: MemoryTier.draft,
      );

      final hits = await store.search(
        embedding: [1.0, 0.0],
        projectId: _testProjectId,
        tiers: {MemoryTier.draft},
      );
      expect(hits, hasLength(1));
      expect(hits.first.id, 'b');
    });

    test('delete removes persisted entry', () async {
      await store.upsert(
        id: 'x',
        projectId: _testProjectId,
        content: 'x',
        embedding: [1.0],
        tier: MemoryTier.scene,
      );
      await store.delete('x', projectId: _testProjectId);

      final hits = await store.search(
        embedding: [1.0],
        projectId: _testProjectId,
      );
      expect(hits, isEmpty);
    });

    test('indexChunks round trip', () async {
      final chunks = [
        _chunk(id: 'c1', content: 'alpha', tier: MemoryTier.canon),
        _chunk(id: 'c2', content: 'beta', tier: MemoryTier.character),
      ];
      await store.indexChunks(chunks, (content) async => _embed(content));

      final all = await store.search(
        embedding: _embed('alpha'),
        projectId: _testProjectId,
        limit: 10,
      );
      expect(all, hasLength(2));
    });

    test(
      'indexChunks rolls back earlier batches when a later embedding fails',
      () async {
        await store.upsert(
          id: 'stable',
          projectId: _testProjectId,
          content: 'stable',
          embedding: const [1.0, 0.0],
          tier: MemoryTier.canon,
        );
        final chunks = <StoryMemoryChunk>[
          for (
            var index = 0;
            index < SqliteVssStore.indexWriteBatchSize + 2;
            index += 1
          )
            _chunk(id: 'new-$index', content: 'content-$index'),
        ];

        await expectLater(
          store.indexChunks(chunks, (content) async {
            if (content == 'content-${SqliteVssStore.indexWriteBatchSize}') {
              throw StateError('injected later-batch embedding failure');
            }
            return const <double>[0.0, 1.0];
          }),
          throwsStateError,
        );

        expect(
          db
              .select('SELECT id FROM $vectorEmbeddingsTable ORDER BY id')
              .map((row) => row['id']),
          <String>['stable'],
        );
        expect(
          db
              .select('SELECT COUNT(*) AS count FROM $vectorLshBucketsTable')
              .single['count'],
          vectorLshTableCount,
        );
      },
    );

    test('upsert replaces existing row', () async {
      await store.upsert(
        id: 'a',
        projectId: _testProjectId,
        content: 'v1',
        embedding: [1.0, 0.0],
        tier: MemoryTier.scene,
      );
      await store.upsert(
        id: 'a',
        projectId: _testProjectId,
        content: 'v2',
        embedding: [0.0, 1.0],
        tier: MemoryTier.canon,
      );

      final hits = await store.search(
        embedding: [0.0, 1.0],
        projectId: _testProjectId,
      );
      expect(hits, hasLength(1));
      expect(hits.first.content, 'v2');
      expect(hits.first.tier, MemoryTier.canon);
    });

    test('persists normalized embeddings as Float32 BLOBs', () async {
      await store.upsert(
        id: 'blob',
        projectId: 'project-a',
        content: 'blob vector',
        embedding: [3.0, 4.0],
        tier: MemoryTier.scene,
        metadata: const {'projectId': 'project-a'},
      );

      final row = db
          .select(
            '''
        SELECT typeof(embedding_blob) AS kind, length(embedding_blob) AS bytes,
               dimension
        FROM $vectorEmbeddingsTable
        WHERE project_id = ? AND id = ?
      ''',
            ['project-a', 'blob'],
          )
          .single;
      expect(row['kind'], 'blob');
      expect(row['bytes'], 2 * 4);
      expect(row['dimension'], 2);

      final hits = await store.search(
        embedding: [3.0, 4.0],
        projectId: 'project-a',
      );
      expect(hits.single.score, closeTo(1.0, 1e-6));
    });

    test('same logical id remains isolated by project', () async {
      await store.upsertAll([
        const VectorStoreEntry(
          id: 'shared-id',
          projectId: 'project-a',
          content: 'project a',
          embedding: [1.0, 0.0],
          tier: MemoryTier.scene,
          metadata: {'projectId': 'project-a'},
        ),
        const VectorStoreEntry(
          id: 'shared-id',
          projectId: 'project-b',
          content: 'project b',
          embedding: [0.0, 1.0],
          tier: MemoryTier.scene,
          metadata: {'projectId': 'project-b'},
        ),
      ]);

      final projectA = await store.search(
        embedding: [1.0, 0.0],
        projectId: 'project-a',
      );
      final projectB = await store.search(
        embedding: [0.0, 1.0],
        projectId: 'project-b',
      );
      expect(projectA.single.content, 'project a');
      expect(projectB.single.content, 'project b');
    });

    test(
      'search rejects embedding dimension mismatch without assertions',
      () async {
        await store.upsert(
          id: 'dim-2',
          projectId: 'project-a',
          content: 'two dimensions',
          embedding: [1.0, 0.0],
          tier: MemoryTier.scene,
        );

        final page = await store.searchDetailed(
          embedding: [1.0, 0.0, 0.0],
          projectId: 'project-a',
        );
        expect(page.hits, isEmpty);
        expect(page.diagnostics.eligibleRows, 0);
        expect(page.diagnostics.decodedRows, 0);
      },
    );

    test('streamed bulk normalization rolls back the whole batch', () async {
      await store.upsert(
        id: 'preserved',
        projectId: 'project-a',
        content: 'preserved',
        embedding: const [1.0, 0.0],
        tier: MemoryTier.scene,
      );

      await expectLater(
        store.upsertAll(const [
          VectorStoreEntry(
            id: 'must-roll-back',
            projectId: 'project-a',
            content: 'first row',
            embedding: [0.0, 1.0],
            tier: MemoryTier.scene,
          ),
          VectorStoreEntry(
            id: 'invalid',
            projectId: 'project-a',
            content: 'invalid vector',
            embedding: [],
            tier: MemoryTier.scene,
          ),
        ]),
        throwsArgumentError,
      );

      final ids = db
          .select('SELECT id FROM $vectorEmbeddingsTable ORDER BY id')
          .map((row) => row['id'])
          .toList();
      expect(ids, ['preserved']);
      expect(
        db
            .select('SELECT COUNT(*) AS count FROM $vectorLshBucketsTable')
            .single['count'],
        vectorLshTableCount,
      );
    });

    test(
      'rejects blank project ids at every scoped public entry point',
      () async {
        final projectError = throwsA(isA<ArgumentError>());

        expect(
          () => store.upsert(
            id: 'blank-upsert',
            projectId: '   ',
            content: 'invalid',
            embedding: const [1.0, 0.0],
            tier: MemoryTier.scene,
          ),
          throwsArgumentError,
        );
        await expectLater(
          store.upsertAll(const [
            VectorStoreEntry(
              id: 'blank-batch',
              projectId: '',
              content: 'invalid',
              embedding: [1.0, 0.0],
              tier: MemoryTier.scene,
            ),
          ]),
          projectError,
        );
        await expectLater(
          store.search(embedding: const [1.0, 0.0], projectId: ''),
          projectError,
        );
        await expectLater(
          store.searchDetailed(embedding: const [1.0, 0.0], projectId: '  '),
          projectError,
        );
        await expectLater(store.delete('missing', projectId: ''), projectError);
        await expectLater(store.clearProject('  '), projectError);
        await expectLater(store.replaceProject('', const []), projectError);
        await expectLater(
          store.indexChunks(const [
            StoryMemoryChunk(
              id: 'blank-chunk',
              projectId: '',
              scopeId: 'scope',
              kind: MemorySourceKind.sceneSummary,
              content: 'invalid',
            ),
          ], (_) async => const [1.0, 0.0]),
          projectError,
        );

        expect(
          db
              .select('SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable')
              .single['count'],
          0,
        );
      },
    );
  });
}
