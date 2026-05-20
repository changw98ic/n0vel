import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake/fake_vector_store.dart';

// Recreate import here to avoid touching existing RAG files.
// ignore: implementation_imports
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';

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
          content: 'cat',
          embedding: [1.0, 0.0, 0.0],
          tier: MemoryTier.scene,
        );
        await store.upsert(
          id: 'b',
          content: 'dog',
          embedding: [0.0, 1.0, 0.0],
          tier: MemoryTier.scene,
        );

        final hits = await store.search(embedding: [1.0, 0.0, 0.0], limit: 5);
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
        content: 'world rule',
        embedding: [1.0, 0.0],
        tier: MemoryTier.canon,
      );
      await store.upsert(
        id: 'draft',
        content: 'draft text',
        embedding: [1.0, 0.0],
        tier: MemoryTier.draft,
      );

      final hits = await store.search(
        embedding: [1.0, 0.0],
        tiers: {MemoryTier.canon},
      );
      expect(hits, hasLength(1));
      expect(hits.first.id, 'canon');
    });

    test('delete removes entry from search results', () async {
      await store.upsert(
        id: 'x',
        content: 'temporary',
        embedding: [1.0],
        tier: MemoryTier.draft,
      );
      await store.delete('x');

      final hits = await store.search(embedding: [1.0]);
      expect(hits, isEmpty);
    });

    test('indexChunks inserts via callback', () async {
      final chunks = [
        _chunk(id: 'c1', content: 'chunk one'),
        _chunk(id: 'c2', content: 'chunk two'),
      ];
      await store.indexChunks(chunks, (content) async => _embed(content));

      final hits = await store.search(embedding: _embed('chunk one'));
      expect(hits, hasLength(2));
      expect(hits.first.id, 'c1');
    });

    test('upsert overwrites existing entry', () async {
      await store.upsert(
        id: 'a',
        content: 'old',
        embedding: [1.0, 0.0],
        tier: MemoryTier.scene,
      );
      await store.upsert(
        id: 'a',
        content: 'new',
        embedding: [0.0, 1.0],
        tier: MemoryTier.canon,
      );

      final hits = await store.search(embedding: [0.0, 1.0]);
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
        content: 'hello',
        embedding: [1.0, 0.0, 0.0],
        tier: MemoryTier.canon,
        metadata: {'source': 'test'},
      );

      final hits = await store.search(embedding: [1.0, 0.0, 0.0]);
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
        content: 'a',
        embedding: [1.0, 0.0],
        tier: MemoryTier.canon,
      );
      await store.upsert(
        id: 'b',
        content: 'b',
        embedding: [1.0, 0.0],
        tier: MemoryTier.draft,
      );

      final hits = await store.search(
        embedding: [1.0, 0.0],
        tiers: {MemoryTier.draft},
      );
      expect(hits, hasLength(1));
      expect(hits.first.id, 'b');
    });

    test('delete removes persisted entry', () async {
      await store.upsert(
        id: 'x',
        content: 'x',
        embedding: [1.0],
        tier: MemoryTier.scene,
      );
      await store.delete('x');

      final hits = await store.search(embedding: [1.0]);
      expect(hits, isEmpty);
    });

    test('indexChunks round trip', () async {
      final chunks = [
        _chunk(id: 'c1', content: 'alpha', tier: MemoryTier.canon),
        _chunk(id: 'c2', content: 'beta', tier: MemoryTier.character),
      ];
      await store.indexChunks(chunks, (content) async => _embed(content));

      final all = await store.search(embedding: _embed('alpha'), limit: 10);
      expect(all, hasLength(2));
    });

    test('upsert replaces existing row', () async {
      await store.upsert(
        id: 'a',
        content: 'v1',
        embedding: [1.0, 0.0],
        tier: MemoryTier.scene,
      );
      await store.upsert(
        id: 'a',
        content: 'v2',
        embedding: [0.0, 1.0],
        tier: MemoryTier.canon,
      );

      final hits = await store.search(embedding: [0.0, 1.0]);
      expect(hits, hasLength(1));
      expect(hits.first.content, 'v2');
      expect(hits.first.tier, MemoryTier.canon);
    });
  });
}
