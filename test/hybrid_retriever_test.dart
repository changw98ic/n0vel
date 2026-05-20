import 'dart:math';

import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

import 'fake/fake_vector_store.dart';

// -- Shared helpers -----------------------------------------------------------

/// Deterministic token-bucket embedding: named buckets for key terms, hash
/// fallback buckets so unknown tokens also produce nonzero vectors.
Future<List<double>> _embed(String text) async {
  const named = <String>[
    'alpha',
    'unique_keyword_match',
    'dragon',
    'hero',
    'villain',
    'world',
    'canon',
    'draft',
    'quantum',
    'cat',
  ];
  const fallbackBuckets = 8;
  final dim = named.length + fallbackBuckets;
  final words = text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9_]+'))
      .where((w) => w.isNotEmpty);
  final vec = List<double>.filled(dim, 0.0);
  for (final w in words) {
    final idx = named.indexOf(w);
    if (idx >= 0) {
      vec[idx] += 1.0;
    } else {
      var h = 0;
      for (final c in w.codeUnits) {
        h = (h * 31 + c) & 0x7FFFFFFF;
      }
      vec[named.length + (h % fallbackBuckets)] += 1.0;
    }
  }
  final norm = sqrt(vec.fold(0.0, (s, v) => s + v * v));
  if (norm > 0) {
    for (var i = 0; i < vec.length; i++) {
      vec[i] /= norm;
    }
  }
  return vec;
}

StoryMemoryChunk _chunk({
  required String id,
  required String content,
  MemoryTier tier = MemoryTier.scene,
  MemorySourceKind kind = MemorySourceKind.sceneSummary,
  String projectId = 'proj1',
}) => StoryMemoryChunk(
  id: id,
  content: content,
  tier: tier,
  kind: kind,
  projectId: projectId,
  scopeId: 'scope1',
);

const _allTiers = RagRetrievalPolicy(
  roleId: 'test',
  allowedTiers: [
    MemoryTier.canon,
    MemoryTier.character,
    MemoryTier.scene,
    MemoryTier.draft,
  ],
  excludeDraftTier: false,
  rankingStrategy: RankingStrategy.hybrid,
  semanticWeight: 0.6,
  keywordWeight: 0.4,
);

// -- Tests --------------------------------------------------------------------

void main() {
  late Database db;
  late LocalRagStorage fts;
  late FakeVectorStore vec;
  late HybridRetriever retriever;

  setUp(() {
    db = sqlite3.openInMemory();
    fts = LocalRagStorage(db: db);
    vec = FakeVectorStore();
    retriever = HybridRetriever(
      ftsStorage: fts,
      vectorStore: vec,
      embeddingForText: _embed,
    );
  });

  tearDown(() => db.dispose());

  group('indexChunks + retrieve round trip', () {
    test('hybrid retrieve returns indexed chunks via FTS and vector', () async {
      final chunks = [
        _chunk(id: 'c1', content: 'The dragon flew over the misty mountains'),
        _chunk(
          id: 'c2',
          content: 'A brave knight rode through the dark forest',
        ),
        _chunk(
          id: 'c3',
          content: 'The ancient castle overlooked the stormy sea',
        ),
      ];
      await retriever.indexChunks(chunks);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'dragon mountains',
          maxResults: 5,
        ),
        _allTiers,
      );

      expect(pack.hits, isNotEmpty);
      // c1 contains both query terms — should rank first.
      expect(pack.hits.first.chunk.id, equals('c1'));
      expect(pack.hits.first.score, greaterThan(0));
    });

    test(
      'chunks are searchable via vector-only path when no FTS match',
      () async {
        await retriever.indexChunks([
          _chunk(id: 'c1', content: 'quantum entanglement theorem'),
        ]);

        // Query with completely unrelated keywords — FTS will miss, vector still
        // returns results because FakeVectorStore has no keyword filter.
        final semOnly = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'cat dog bird',
            maxResults: 10,
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            excludeDraftTier: false,
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        expect(semOnly.hits, hasLength(1));
        expect(semOnly.hits.first.chunk.id, equals('c1'));
      },
    );

    test('retrieve reconstructs preserved chunk metadata', () async {
      await retriever.indexChunks([
        const StoryMemoryChunk(
          id: 'meta1',
          content: 'detailed character backstory with many words',
          tier: MemoryTier.character,
          kind: MemorySourceKind.acceptedState,
          projectId: 'proj1',
          scopeId: 'customScope',
          producer: 'producerA',
          tags: ['tagA', 'tagB'],
          priority: 7,
          tokenCostEstimate: 42,
          createdAtMs: 1234,
          rootSourceIds: ['root1'],
          sourceRefs: [
            MemorySourceRef(
              sourceId: 'src1',
              sourceType: MemorySourceKind.acceptedState,
            ),
          ],
        ),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'character backstory',
          maxResults: 10,
          tokenBudget: 42,
        ),
        _allTiers,
      );

      expect(pack.hits, hasLength(1));
      final chunk = pack.hits.first.chunk;
      expect(chunk.scopeId, equals('customScope'));
      expect(chunk.kind, equals(MemorySourceKind.acceptedState));
      expect(chunk.tier, equals(MemoryTier.character));
      expect(chunk.producer, equals('producerA'));
      expect(chunk.tags, equals(['tagA', 'tagB']));
      expect(chunk.priority, equals(7));
      expect(chunk.tokenCostEstimate, equals(42));
      expect(chunk.createdAtMs, equals(1234));
      expect(chunk.rootSourceIds, equals(['root1']));
      expect(chunk.sourceRefs, hasLength(1));
      expect(chunk.sourceRefs.first.sourceId, equals('src1'));
      expect(pack.tokenBudget, equals(42));
      expect(pack.spentTokenEstimate, equals(42));
    });
  });

  group('project isolation', () {
    test('semantic retrieval excludes chunks from other projects '
        'even when VectorStore has them and FTS has no match', () async {
      await retriever.indexChunks([
        _chunk(
          id: 'c_proj1',
          content: 'alpha beta quantum entanglement theorem proof',
          projectId: 'proj1',
        ),
        _chunk(
          id: 'c_proj2',
          content: 'alpha beta quantum entanglement corollary proof',
          projectId: 'proj2',
        ),
      ]);

      // Semantic strategy skips FTS entirely — only vector path runs.
      // VectorStore holds chunks from both projects but results must be
      // scoped to the queried projectId.
      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'alpha beta quantum',
          maxResults: 10,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.semantic,
        ),
      );

      for (final hit in pack.hits) {
        expect(hit.chunk.projectId, equals('proj1'));
      }
      expect(pack.hits.any((h) => h.chunk.id == 'c_proj2'), isFalse);
    });
  });

  group('tier filtering', () {
    test('allowedTiers restricts results to specified tiers only', () async {
      final chunks = [
        _chunk(
          id: 'canon1',
          content: 'world was created by gods',
          tier: MemoryTier.canon,
        ),
        _chunk(
          id: 'char1',
          content: 'the hero was born in a village',
          tier: MemoryTier.character,
        ),
        _chunk(
          id: 'scene1',
          content: 'the hero fought the villain',
          tier: MemoryTier.scene,
        ),
        _chunk(
          id: 'draft1',
          content: 'the hero won the final battle',
          tier: MemoryTier.draft,
        ),
      ];
      await retriever.indexChunks(chunks);

      final canonOnly = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'hero world',
          maxResults: 10,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.canon],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.hybrid,
        ),
      );

      for (final hit in canonOnly.hits) {
        expect(hit.chunk.tier, equals(MemoryTier.canon));
      }
      expect(canonOnly.hits.any((h) => h.chunk.id == 'canon1'), isTrue);
    });

    test('excludeDraftTier removes draft even when in allowedTiers', () async {
      await retriever.indexChunks([
        _chunk(
          id: 'scene1',
          content: 'hero fought villain in the arena',
          tier: MemoryTier.scene,
        ),
        _chunk(
          id: 'draft1',
          content: 'hero fought villain in the draft note',
          tier: MemoryTier.draft,
        ),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'hero villain',
          maxResults: 10,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene, MemoryTier.draft],
          excludeDraftTier: true,
          rankingStrategy: RankingStrategy.hybrid,
        ),
      );

      for (final hit in pack.hits) {
        expect(hit.chunk.tier, isNot(equals(MemoryTier.draft)));
      }
      expect(pack.hits.any((h) => h.chunk.id == 'scene1'), isTrue);
    });
  });

  group('ranking strategy changes ranking', () {
    test('keyword-only returns only FTS-matching chunks', () async {
      await retriever.indexChunks([
        _chunk(id: 'c1', content: 'alpha beta gamma dragon slayer'),
        _chunk(id: 'c2', content: 'delta epsilon zeta eta theta iota'),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'dragon',
          maxResults: 10,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.keyword,
        ),
      );

      // Only c1 contains "dragon" — c2 has zero FTS score and is filtered out.
      expect(pack.hits, hasLength(1));
      expect(pack.hits.first.chunk.id, equals('c1'));
      expect(pack.hits.first.score, greaterThan(0));
    });

    test(
      'semantic-only returns all chunks ranked by vector similarity',
      () async {
        await retriever.indexChunks([
          _chunk(id: 'c1', content: 'alpha beta gamma delta'),
          _chunk(id: 'c2', content: 'alpha zzzz zzzz zzzz'),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'alpha',
            maxResults: 10,
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            excludeDraftTier: false,
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        // Both appear — vector search has no keyword filter.
        expect(pack.hits, hasLength(2));
        // Both share "alpha"; c1 has less dilution from non-matching tokens → higher cosine.
        expect(pack.hits.first.chunk.id, equals('c1'));
        expect(pack.hits.first.score, greaterThan(pack.hits.last.score));
      },
    );

    test('switching strategy changes which chunk ranks first', () async {
      await retriever.indexChunks([
        _chunk(
          id: 'kw',
          content: 'unique_keyword_match alpha beta gamma delta epsilon',
          tier: MemoryTier.scene,
        ),
        _chunk(
          id: 'sem',
          content: 'unique_keyword_match',
          tier: MemoryTier.scene,
        ),
      ]);

      const query = StoryMemoryQuery(
        projectId: 'proj1',
        queryType: StoryMemoryQueryType.concreteFact,
        text: 'unique_keyword_match',
        maxResults: 10,
      );

      final kwPack = await retriever.retrieve(
        query,
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.keyword,
        ),
      );

      final semPack = await retriever.retrieve(
        query,
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.semantic,
        ),
      );

      // Keyword: 'kw' is the only FTS match.
      expect(kwPack.hits.first.chunk.id, equals('kw'));
      // Semantic: 'sem' is an exact token match for the query → perfect cosine.
      expect(semPack.hits.first.chunk.id, equals('sem'));
    });
  });

  group('fused hybrid scores', () {
    test('hybrid score equals weighted sum of FTS and vector scores', () async {
      await retriever.indexChunks([
        _chunk(id: 'c1', content: 'dragon fire mountain flame'),
        _chunk(id: 'c2', content: 'ocean wave breeze storm'),
      ]);

      const query = StoryMemoryQuery(
        projectId: 'proj1',
        queryType: StoryMemoryQueryType.concreteFact,
        text: 'dragon',
        maxResults: 10,
      );

      // Pure keyword score for c1.
      final kwPack = await retriever.retrieve(
        query,
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.keyword,
        ),
      );
      final kwScore = kwPack.hits.firstWhere((h) => h.chunk.id == 'c1').score;

      // Pure semantic score for c1.
      final semPack = await retriever.retrieve(
        query,
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.semantic,
        ),
      );
      final semScore = semPack.hits.firstWhere((h) => h.chunk.id == 'c1').score;

      // Hybrid score should equal kwScore * 0.4 + semScore * 0.6.
      const kwWeight = 0.4;
      const semWeight = 0.6;
      final hybridPack = await retriever.retrieve(
        query,
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.hybrid,
          keywordWeight: kwWeight,
          semanticWeight: semWeight,
        ),
      );
      final hybridScore = hybridPack.hits
          .firstWhere((h) => h.chunk.id == 'c1')
          .score;

      expect(
        hybridScore,
        closeTo(kwScore * kwWeight + semScore * semWeight, 0.001),
      );
    });

    test(
      'hybrid retrieve fuses both sources — more hits than either alone',
      () async {
        await retriever.indexChunks([
          _chunk(id: 'kw_only', content: 'unique_keyword_match zzzz zzzz'),
          _chunk(id: 'vec_only', content: 'alpha beta gamma delta'),
        ]);

        const query = StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'unique_keyword_match alpha',
          maxResults: 10,
        );

        final hybridPack = await retriever.retrieve(query, _allTiers);

        // Both chunks should appear in hybrid results (one via FTS, one via vector).
        final ids = hybridPack.hits.map((h) => h.chunk.id).toSet();
        expect(ids, containsAll(['kw_only', 'vec_only']));
      },
    );
  });
}
