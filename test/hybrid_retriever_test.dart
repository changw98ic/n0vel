import 'dart:math';

import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_indexer.dart';
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
  String scopeId = 'scope1',
  String producer = '',
  List<MemorySourceRef> sourceRefs = const [],
  List<String> rootSourceIds = const [],
  MemoryVisibility visibility = MemoryVisibility.publicObservable,
  String ownerId = '',
  List<String> tags = const [],
  int tokenCostEstimate = 0,
}) => StoryMemoryChunk(
  id: id,
  content: content,
  tier: tier,
  kind: kind,
  projectId: projectId,
  scopeId: scopeId,
  producer: producer,
  sourceRefs: sourceRefs,
  rootSourceIds: rootSourceIds,
  visibility: visibility,
  ownerId: ownerId,
  tags: tags,
  tokenCostEstimate: tokenCostEstimate,
);

String _generationId({
  required String scopeId,
  int index = 0,
  MemorySourceKind kind = MemorySourceKind.sceneSummary,
  String producer = StoryMemoryIndexer.contextEnrichmentProducer,
}) => StoryMemoryIndexer.generationChunkId(
  projectId: 'proj1',
  scopeId: scopeId,
  producer: producer,
  kind: kind,
  kindIndex: index,
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
  late _RecordingVectorStore vec;
  late HybridRetriever retriever;

  setUp(() {
    db = sqlite3.openInMemory();
    fts = LocalRagStorage(db: db);
    vec = _RecordingVectorStore();
    retriever = HybridRetriever(
      ftsStorage: fts,
      vectorStore: vec,
      embeddingForText: _embed,
    );
  });

  tearDown(() => db.dispose());

  group('indexChunks + retrieve round trip', () {
    test('large indexing batches keep prepared embeddings bounded', () async {
      await retriever.indexChunks(<StoryMemoryChunk>[
        for (var index = 0; index < 300; index += 1)
          _chunk(id: 'bounded-$index', content: 'bounded content $index'),
      ]);

      expect(vec.upsertBatchSizes, <int>[128, 128, 44]);
      expect(
        vec.upsertBatchSizes.reduce(max),
        lessThanOrEqualTo(HybridRetriever.indexWriteBatchSize),
      );
    });

    test(
      'local indexing uses the configured batch embedding callback',
      () async {
        var scalarCalls = 0;
        final embeddedBatches = <List<String>>[];
        final local = HybridRetriever.local(
          db: db,
          embeddingForText: (text) async {
            scalarCalls++;
            return _embed(text);
          },
          embeddingForTexts: (texts) async {
            embeddedBatches.add(List<String>.of(texts));
            return [for (final text in texts) await _embed(text)];
          },
        );

        await local.indexChunks([
          _chunk(id: 'batch-a', content: 'first batch document'),
          _chunk(id: 'batch-b', content: 'second batch document'),
        ]);

        expect(scalarCalls, 0);
        expect(embeddedBatches, [
          ['first batch document', 'second batch document'],
        ]);
        expect(
          db
              .select('SELECT COUNT(*) AS count FROM vector_embeddings')
              .single['count'],
          2,
        );
      },
    );

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

    test(
      'budgets long hits by the same query-aware excerpts used in prompts',
      () async {
        final firstContent = [
          List<String>.filled(90, 'first unrelated material').join(' '),
          'dragon first tail fact',
          List<String>.filled(8, 'closing').join(' '),
        ].join(' ');
        final secondContent = [
          List<String>.filled(90, 'second unrelated material').join(' '),
          'dragon second tail fact',
          List<String>.filled(8, 'ending').join(' '),
        ].join(' ');
        await retriever.indexChunks([
          _chunk(
            id: 'long-first',
            content: firstContent,
            tokenCostEstimate: 600,
          ),
          _chunk(
            id: 'long-second',
            content: secondContent,
            tokenCostEstimate: 600,
          ),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.sceneContinuity,
            text: 'dragon',
            maxResults: 2,
            tokenBudget: 100,
          ),
          const RagRetrievalPolicy(
            roleId: 'prompt-budget-test',
            allowedTiers: [MemoryTier.scene],
            excludeDraftTier: false,
            rankingStrategy: RankingStrategy.keyword,
          ),
        );
        final context = RagSceneContext.fromPack(pack);
        final excerpts = _formattedExcerpts(context);
        final formattedCost = excerpts.fold<int>(
          0,
          (total, excerpt) => total + (excerpt.runes.length / 4).ceil(),
        );

        expect(pack.hits, hasLength(2));
        expect(
          pack.hits.map((hit) => hit.chunk.content),
          containsAll([firstContent, secondContent]),
        );
        expect(excerpts, hasLength(2));
        expect(excerpts.every((excerpt) => excerpt.contains('dragon')), isTrue);
        expect(
          excerpts.every((excerpt) => excerpt.runes.length <= 200),
          isTrue,
        );
        expect(pack.spentTokenEstimate, formattedCost);
        expect(pack.spentTokenEstimate, lessThanOrEqualTo(pack.tokenBudget));
      },
    );

    test('never admits the first long hit beyond the token budget', () async {
      final content = [
        List<String>.filled(100, 'unrelated material').join(' '),
        'dragon tail fact',
        List<String>.filled(10, 'closing').join(' '),
      ].join(' ');
      await retriever.indexChunks([
        _chunk(id: 'over-budget', content: content, tokenCostEstimate: 900),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.sceneContinuity,
          text: 'dragon',
          maxResults: 1,
          tokenBudget: 49,
        ),
        const RagRetrievalPolicy(
          roleId: 'prompt-budget-test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.keyword,
        ),
      );

      expect(pack.hits, isEmpty);
      expect(pack.spentTokenEstimate, 0);
      expect(pack.deferredHitCount, 1);
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
      expect(vec.lastProjectId, 'proj1');
      expect(vec.lastTiers, {MemoryTier.scene});
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
          content: 'lexicalneedle alpha beta gamma delta epsilon',
          tier: MemoryTier.scene,
        ),
        _chunk(id: 'sem', content: 'vectorproxy', tier: MemoryTier.scene),
      ]);

      const query = StoryMemoryQuery(
        projectId: 'proj1',
        queryType: StoryMemoryQueryType.concreteFact,
        text: 'lexicalneedle',
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

      // Keyword: only 'kw' contains the lexical query token.
      expect(kwPack.hits.first.chunk.id, equals('kw'));
      // Semantic: the deterministic fallback maps vectorproxy to the same
      // bucket as lexicalneedle, without creating a second FTS match.
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
      final kwMatches = kwPack.hits
          .where((hit) => hit.chunk.id == 'c1')
          .toList();
      expect(kwMatches, hasLength(1));
      final kwScore = kwMatches.single.score;

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
      final semMatches = semPack.hits
          .where((hit) => hit.chunk.id == 'c1')
          .toList();
      expect(semMatches, hasLength(1));
      final semScore = semMatches.single.score;

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
      final hybridMatches = hybridPack.hits
          .where((hit) => hit.chunk.id == 'c1')
          .toList();
      expect(hybridMatches, hasLength(1));
      final hybridScore = hybridMatches.single.score;

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
        final ids = hybridPack.hits.map((h) => h.chunk.id).toList();
        expect(ids, hasLength(2));
        expect(ids, containsAll(['kw_only', 'vec_only']));
      },
    );
  });

  group('retrieval deduplication', () {
    test('same chunk hit by FTS and vector appears exactly once', () async {
      await retriever.indexChunks([
        _chunk(id: 'shared-hit', content: 'alpha dragon witness fact'),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'alpha dragon',
          maxResults: 10,
        ),
        _allTiers,
      );

      expect(pack.hits, hasLength(1));
      expect(pack.hits.single.chunk.id, 'shared-hit');
    });

    test(
      'exact content merges unique provenance before result and token budgets',
      () async {
        const sharedRef = MemorySourceRef(
          sourceId: 'shared-source',
          sourceType: MemorySourceKind.sceneSummary,
        );
        await retriever.indexChunks([
          _chunk(
            id: 'a-representative',
            content: '  Alpha   dragon fact  ',
            tier: MemoryTier.scene,
            producer: 'representative-producer',
            sourceRefs: const [
              sharedRef,
              MemorySourceRef(
                sourceId: 'source-a',
                sourceType: MemorySourceKind.sceneSummary,
              ),
            ],
            rootSourceIds: const ['root-shared', 'root-a'],
            tags: const ['shared', 'a'],
            tokenCostEstimate: 10,
          ),
          _chunk(
            id: 'b-duplicate',
            content: 'alpha dragon FACT',
            tier: MemoryTier.scene,
            kind: MemorySourceKind.sceneSummary,
            producer: 'duplicate-producer',
            sourceRefs: const [
              sharedRef,
              MemorySourceRef(
                sourceId: 'source-b',
                sourceType: MemorySourceKind.outlineBeat,
              ),
            ],
            rootSourceIds: const ['root-shared', 'root-b'],
            tags: const ['shared', 'b'],
            tokenCostEstimate: 10,
          ),
          _chunk(
            id: 'c-independent',
            content: 'independent witness fact',
            tokenCostEstimate: 10,
          ),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.sceneContinuity,
            text: 'alpha dragon independent',
            maxResults: 2,
            tokenBudget: 20,
          ),
          _allTiers,
        );

        expect(pack.hits, hasLength(2));
        expect(pack.hits.map((hit) => hit.chunk.id).toList(), [
          'a-representative',
          'c-independent',
        ]);
        final merged = pack.hits.first.chunk;
        expect(merged.tier, MemoryTier.scene);
        expect(merged.kind, MemorySourceKind.sceneSummary);
        expect(merged.visibility, MemoryVisibility.publicObservable);
        expect(merged.producer, 'representative-producer');
        expect(merged.sourceRefs.map((ref) => ref.sourceId).toList(), [
          'shared-source',
          'source-a',
          'source-b',
        ]);
        expect(merged.rootSourceIds, ['root-shared', 'root-a', 'root-b']);
        expect(merged.tags, ['shared', 'a', 'b']);
        expect(pack.sourceRefs.map((ref) => ref.sourceId).toList(), [
          'shared-source',
          'source-a',
          'source-b',
        ]);
        expect(pack.spentTokenEstimate, 20);
        expect(pack.deferredHitCount, 0);
      },
    );

    test(
      'exact content preserves tier and kind authority boundaries',
      () async {
        await retriever.indexChunks([
          _chunk(
            id: 'scene-summary',
            content: 'alpha dragon authority fact',
            tier: MemoryTier.scene,
            kind: MemorySourceKind.sceneSummary,
          ),
          _chunk(
            id: 'canon-summary',
            content: 'alpha dragon authority fact',
            tier: MemoryTier.canon,
            kind: MemorySourceKind.sceneSummary,
          ),
          _chunk(
            id: 'scene-world-fact',
            content: 'alpha dragon authority fact',
            tier: MemoryTier.scene,
            kind: MemorySourceKind.worldFact,
          ),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.sceneContinuity,
            text: 'alpha dragon authority',
            maxResults: 3,
          ),
          _allTiers,
        );

        expect(pack.hits.map((hit) => hit.chunk.id).toSet(), {
          'scene-summary',
          'canon-summary',
          'scene-world-fact',
        });
      },
    );

    test(
      'exact public and private text never merges private provenance into public',
      () async {
        await retriever.indexChunks([
          _chunk(
            id: 'a-public',
            content: 'alpha dragon shared secret',
            sourceRefs: const [
              MemorySourceRef(
                sourceId: 'public-source',
                sourceType: MemorySourceKind.sceneSummary,
              ),
            ],
            rootSourceIds: const ['public-root'],
          ),
          _chunk(
            id: 'b-private',
            content: 'alpha dragon shared secret',
            visibility: MemoryVisibility.agentPrivate,
            ownerId: 'alice',
            sourceRefs: const [
              MemorySourceRef(
                sourceId: 'private-source',
                sourceType: MemorySourceKind.characterProfile,
              ),
            ],
            rootSourceIds: const ['private-root'],
          ),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'alpha dragon secret',
            viewerId: 'alice',
            maxResults: 1,
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        expect(pack.hits.single.chunk.id, 'a-public');
        expect(pack.hits.single.chunk.sourceRefs.map((ref) => ref.sourceId), [
          'public-source',
        ]);
        expect(pack.hits.single.chunk.rootSourceIds, ['public-root']);
        expect(pack.sourceRefs.map((ref) => ref.sourceId), ['public-source']);
      },
    );

    test('expands a saturated candidate window after exact dedupe', () async {
      await retriever.indexChunks([
        for (var i = 0; i < 7; i++)
          _chunk(id: 'duplicate-$i', content: 'alpha dragon fact'),
        _chunk(id: 'z-independent', content: 'independent witness fact'),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'alpha dragon independent',
          maxResults: 2,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.semantic,
        ),
      );

      expect(pack.hits.map((hit) => hit.chunk.id).toList(), [
        'duplicate-0',
        'z-independent',
      ]);
      expect(vec.searchLimits, [6, 12]);
      expect(pack.deferredHitCount, 0);
    });

    test('caps exact-dedupe expansion at two rounds', () async {
      HybridRetrievalDiagnostics? diagnostics;
      final boundedRetriever = HybridRetriever(
        ftsStorage: fts,
        vectorStore: vec,
        embeddingForText: _embed,
        onDiagnostics: (value) => diagnostics = value,
      );
      await boundedRetriever.indexChunks([
        for (var i = 0; i < 100; i++)
          _chunk(id: 'duplicate-$i', content: 'alpha dragon fact'),
      ]);

      final pack = await boundedRetriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'alpha dragon',
          maxResults: 2,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.semantic,
        ),
      );

      expect(pack.hits, hasLength(1));
      expect(diagnostics?.expansionRounds, 2);
      expect(diagnostics?.candidateLimits, [6, 12, 24]);
      expect(diagnostics?.vectorSearches, 3);
    });

    test(
      'long near duplicates expand until the next window finds a distinct fact',
      () async {
        HybridRetrievalDiagnostics? diagnostics;
        final recordingVec = _RecordingVectorStore();
        final boundedRetriever = HybridRetriever(
          ftsStorage: fts,
          vectorStore: recordingVec,
          embeddingForText: (text) async {
            if (text == 'find independent fact') return const [1.0, 0.0];
            if (text.startsWith('independent fact')) {
              return const [0.9, 0.435889894];
            }
            return const [1.0, 0.0];
          },
          onDiagnostics: (value) => diagnostics = value,
        );
        final shared = List.generate(
          700,
          (index) => 'shared_token_$index',
        ).join(' ');
        expect(shared.length, greaterThan(3000));
        await boundedRetriever.indexChunks([
          for (var i = 0; i < 7; i++)
            _chunk(id: 'retelling-$i', content: '$shared version_$i'),
          _chunk(
            id: 'z-independent',
            content: 'independent fact from a separate witness',
          ),
        ]);

        final pack = await boundedRetriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'find independent fact',
            maxResults: 2,
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            excludeDraftTier: false,
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        expect(pack.hits.map((hit) => hit.chunk.id).toList(), [
          'retelling-0',
          'z-independent',
        ]);
        expect(recordingVec.searchLimits, [6, 12]);
        expect(diagnostics?.expansionRounds, 1);
        expect(diagnostics?.candidateLimits, [6, 12]);
        expect(diagnostics?.vectorSearches, 2);
      },
    );

    test('near-duplicate comparisons are bounded by maxResults', () async {
      HybridRetrievalDiagnostics? diagnostics;
      final boundedRetriever = HybridRetriever(
        ftsStorage: fts,
        vectorStore: vec,
        embeddingForText: _embed,
        onDiagnostics: (value) => diagnostics = value,
      );
      await boundedRetriever.indexChunks([
        for (var i = 0; i < 30; i++)
          _chunk(
            id: 'distinct-$i',
            content: 'alpha unique_${i}_left unique_${i}_right',
          ),
      ]);

      final pack = await boundedRetriever.retrieve(
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

      expect(pack.hits, hasLength(10));
      expect(diagnostics?.candidateLimits, [30]);
      expect(diagnostics?.nearDuplicateComparisons, 245);
    });

    test(
      'hybrid expansion reuses an exhausted route and expands only the full route',
      () async {
        final recordingFts = _RecordingLocalRagStorage(db: db);
        final recordingVec = _RecordingVectorStore();
        final hybridRetriever = HybridRetriever(
          ftsStorage: recordingFts,
          vectorStore: recordingVec,
          embeddingForText: (_) async => const [1.0],
        );
        await hybridRetriever.indexChunks([
          for (var i = 0; i < 7; i++)
            _chunk(id: 'duplicate-$i', content: 'repeated memory fact'),
          _chunk(id: 'z-independent', content: 'separate witness account'),
        ]);

        final pack = await hybridRetriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'unmatched_query_token',
            maxResults: 2,
          ),
          _allTiers,
        );

        expect(pack.hits.map((hit) => hit.chunk.id).toList(), [
          'duplicate-0',
          'z-independent',
        ]);
        expect(recordingFts.searchLimits, [6]);
        expect(recordingVec.searchLimits, [6, 12]);
      },
    );

    test(
      'high-overlap Chinese retelling yields to an independent fact',
      () async {
        final cjkRetriever = HybridRetriever(
          ftsStorage: fts,
          vectorStore: vec,
          embeddingForText: HybridRetriever.defaultEmbedding,
        );
        const original = '林澈在雨夜抵达旧港码头，发现失踪船长留下的铜制罗盘，随后沿着潮湿石阶追查北岸仓库的秘密暗门。';
        const retelling = '林澈在雨夜抵达旧港码头，发现失踪船长留下的铜制罗盘，随后沿着潮湿石阶追查北岸仓库的隐秘暗门。';
        const independent = '北境粮仓昨夜失火，守卫确认冬季储备只剩三成。';
        await cjkRetriever.indexChunks([
          _chunk(id: 'a-original', content: original),
          _chunk(id: 'b-retelling', content: retelling),
          _chunk(id: 'c-independent', content: independent),
        ]);

        final pack = await cjkRetriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.sceneContinuity,
            text: '$original 北境粮仓',
            maxResults: 2,
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            excludeDraftTier: false,
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        expect(pack.hits.map((hit) => hit.chunk.id).toList(), [
          'a-original',
          'c-independent',
        ]);
      },
    );

    test('shared character name does not suppress distinct facts', () async {
      final cjkRetriever = HybridRetriever(
        ftsStorage: fts,
        vectorStore: vec,
        embeddingForText: HybridRetriever.defaultEmbedding,
      );
      const first = '顾南舟在议事厅拒绝王后的联姻请求，决定独自前往西境。';
      const second = '顾南舟在河谷救下受伤信使，从密函中得知北军将在黎明突袭。';
      const lowerRanked = '王城钟楼的铜钟每逢冬至会连续鸣响十二次。';
      await cjkRetriever.indexChunks([
        _chunk(id: 'a-first', content: first),
        _chunk(id: 'b-second', content: second),
        _chunk(id: 'c-lower', content: lowerRanked),
      ]);

      final pack = await cjkRetriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.sceneContinuity,
          text: '$first $second',
          maxResults: 2,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.semantic,
        ),
      );

      final ids = pack.hits.map((hit) => hit.chunk.id).toList();
      expect(ids, hasLength(2));
      expect(ids, containsAll(['a-first', 'b-second']));
    });

    for (final testCase in const [
      (name: 'reversed roles', variant: 'Bob killed Alice'),
      (name: 'explicit negation', variant: 'Alice did not kill Bob'),
    ]) {
      test('${testCase.name} remains a distinct ordered fact', () async {
        final orderedRetriever = HybridRetriever(
          ftsStorage: fts,
          vectorStore: vec,
          embeddingForText: HybridRetriever.defaultEmbedding,
        );
        const original = 'Alice killed Bob';
        const independent = 'Carol found the hidden map';
        await orderedRetriever.indexChunks([
          _chunk(id: 'a-original', content: original),
          _chunk(id: 'b-variant', content: testCase.variant),
          _chunk(id: 'c-independent', content: independent),
        ]);

        final pack = await orderedRetriever.retrieve(
          StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: '$original ${testCase.variant}',
            maxResults: 2,
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            excludeDraftTier: false,
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        final ids = pack.hits.map((hit) => hit.chunk.id).toList();
        expect(ids, hasLength(2));
        expect(ids, containsAll(['a-original', 'b-variant']));
      });
    }

    test('different kind does not suppress near-duplicate content', () async {
      await _expectNearDuplicateBoundary(
        fts: fts,
        vec: vec,
        variantKind: MemorySourceKind.worldFact,
      );
    });

    test(
      'different visibility does not suppress near-duplicate content',
      () async {
        await _expectNearDuplicateBoundary(
          fts: fts,
          vec: vec,
          variantVisibility: MemoryVisibility.agentPrivate,
        );
      },
    );

    test('different scope does not suppress near-duplicate content', () async {
      await _expectNearDuplicateBoundary(
        fts: fts,
        vec: vec,
        variantScopeId: 'scope2',
      );
    });

    test('near duplicate is refilled when candidates are scarce', () async {
      final cjkRetriever = HybridRetriever(
        ftsStorage: fts,
        vectorStore: vec,
        embeddingForText: HybridRetriever.defaultEmbedding,
      );
      const original = '林澈在雨夜抵达旧港码头，发现失踪船长留下的铜制罗盘，随后沿着潮湿石阶追查北岸仓库的秘密暗门。';
      const retelling = '林澈在雨夜抵达旧港码头，发现失踪船长留下的铜制罗盘，随后沿着潮湿石阶追查北岸仓库的隐秘暗门。';
      await cjkRetriever.indexChunks([
        _chunk(id: 'a-original', content: original),
        _chunk(id: 'b-retelling', content: retelling),
      ]);

      final pack = await cjkRetriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.sceneContinuity,
          text: original,
          maxResults: 2,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          excludeDraftTier: false,
          rankingStrategy: RankingStrategy.semantic,
        ),
      );

      expect(pack.hits, hasLength(2));
      expect(pack.hits.map((hit) => hit.chunk.id).toList(), [
        'a-original',
        'b-retelling',
      ]);
    });
  });

  group('retrieval contract admission and intent ranking', () {
    test(
      'agent-private chunks fail closed and only admit their owner',
      () async {
        await retriever.indexChunks([
          _chunk(id: 'public', content: 'alpha public memory'),
          _chunk(
            id: 'private',
            content: 'alpha private memory',
            visibility: MemoryVisibility.agentPrivate,
            ownerId: 'alice',
          ),
        ]);
        const policy = RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          rankingStrategy: RankingStrategy.semantic,
        );

        final anonymous = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'alpha memory',
          ),
          policy,
        );
        final wrongViewer = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'alpha memory',
            viewerId: 'bob',
          ),
          policy,
        );
        final owner = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'alpha memory',
            viewerId: 'alice',
          ),
          policy,
        );

        expect(anonymous.hits.map((hit) => hit.chunk.id), ['public']);
        expect(wrongViewer.hits.map((hit) => hit.chunk.id), ['public']);
        expect(
          owner.hits.map((hit) => hit.chunk.id),
          containsAll(['public', 'private']),
        );
      },
    );

    test(
      'scope ancestry and required tag groups are hard admission constraints',
      () async {
        await retriever.indexChunks([
          _chunk(
            id: 'current-match',
            content: 'alpha current fact',
            scopeId: 'current',
            tags: const ['wanted'],
          ),
          _chunk(
            id: 'ancestor-match',
            content: 'alpha ancestor fact',
            scopeId: 'ancestor',
            tags: const ['wanted'],
          ),
          _chunk(
            id: 'wrong-scope',
            content: 'alpha outside fact',
            scopeId: 'outside',
            tags: const ['wanted'],
          ),
          _chunk(
            id: 'wrong-tag',
            content: 'alpha unrelated fact',
            scopeId: 'current',
            tags: const ['other'],
          ),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'alpha fact',
            scopeId: 'current',
            allowedAncestorScopeIds: ['ancestor'],
            requiredTagGroups: [
              ['wanted'],
            ],
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        expect(
          pack.hits.map((hit) => hit.chunk.id),
          containsAll(['current-match', 'ancestor-match']),
        );
        expect(
          pack.hits.map((hit) => hit.chunk.id),
          isNot(contains('wrong-scope')),
        );
        expect(
          pack.hits.map((hit) => hit.chunk.id),
          isNot(contains('wrong-tag')),
        );
      },
    );

    test('blank required tag groups do not reject hybrid candidates', () async {
      await retriever.indexChunks([
        _chunk(id: 'untagged', content: 'alpha untagged fact'),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'alpha',
          requiredTagGroups: [
            [' ', ''],
            [],
          ],
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          rankingStrategy: RankingStrategy.hybrid,
        ),
      );

      expect(pack.hits.map((hit) => hit.chunk.id), ['untagged']);
    });

    test('legacy query tags boost once without filtering other hits', () async {
      await retriever.indexChunks([
        _chunk(
          id: 'a-untagged',
          content: 'lexicalneedle',
          tags: const ['other'],
        ),
        _chunk(id: 'z-tagged', content: 'vectorproxy', tags: const ['wanted']),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.sceneContinuity,
          text: 'lexicalneedle',
          tags: ['wanted', 'wanted'],
          boostTags: ['wanted'],
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          rankingStrategy: RankingStrategy.semantic,
        ),
      );

      expect(pack.hits.map((hit) => hit.chunk.id), ['z-tagged', 'a-untagged']);
      expect(pack.hits.first.score - pack.hits.last.score, closeTo(0.05, 1e-9));
    });

    test('policy mustIncludeCanon reserves an eligible Canon hit', () async {
      await retriever.indexChunks([
        _chunk(id: 'scene', content: 'alpha shared fact'),
        _chunk(
          id: 'canon',
          content: 'alpha shared fact',
          tier: MemoryTier.canon,
          kind: MemorySourceKind.worldFact,
        ),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.sceneContinuity,
          text: 'alpha shared fact',
          maxResults: 1,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          rankingStrategy: RankingStrategy.semantic,
          mustIncludeCanon: true,
        ),
      );

      expect(pack.canonRequired, isTrue);
      expect(pack.canonAvailable, isTrue);
      expect(pack.canonIncluded, isTrue);
      expect(pack.hits.single.chunk.id, 'canon');
    });

    test(
      'required Canon that exceeds budget blocks cheaper non-Canon hits',
      () async {
        await retriever.indexChunks([
          _chunk(
            id: 'canon-too-large',
            content: 'alpha canon rule',
            tier: MemoryTier.canon,
            kind: MemorySourceKind.worldFact,
            tokenCostEstimate: 50,
          ),
          _chunk(
            id: 'cheap-scene',
            content: 'alpha scene clue',
            tokenCostEstimate: 5,
          ),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'alpha',
            maxResults: 2,
            tokenBudget: 10,
            mustIncludeCanon: true,
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        expect(pack.canonAvailable, isTrue);
        expect(pack.canonIncluded, isFalse);
        expect(pack.hits, isEmpty);
        expect(pack.spentTokenEstimate, 0);
        expect(pack.deferredHitCount, 2);
      },
    );

    test(
      'required Canon is selected before filling the remaining budget',
      () async {
        await retriever.indexChunks([
          _chunk(
            id: 'canon-fits',
            content: 'alpha canon rule',
            tier: MemoryTier.canon,
            kind: MemorySourceKind.worldFact,
            tokenCostEstimate: 10,
          ),
          _chunk(
            id: 'scene-fits',
            content: 'alpha scene clue',
            tokenCostEstimate: 5,
          ),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'proj1',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'alpha',
            maxResults: 2,
            tokenBudget: 15,
            mustIncludeCanon: true,
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            rankingStrategy: RankingStrategy.semantic,
          ),
        );

        expect(pack.hits.map((hit) => hit.chunk.id), [
          'canon-fits',
          'scene-fits',
        ]);
        expect(pack.canonIncluded, isTrue);
        expect(pack.spentTokenEstimate, 15);
      },
    );

    test('required Canon with maxResults zero returns no substitute', () async {
      await retriever.indexChunks([
        _chunk(
          id: 'canon-available',
          content: 'alpha canon rule',
          tier: MemoryTier.canon,
          kind: MemorySourceKind.worldFact,
          tokenCostEstimate: 1,
        ),
        _chunk(id: 'scene-available', content: 'alpha scene clue'),
      ]);

      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'alpha',
          maxResults: 0,
          tokenBudget: 100,
          mustIncludeCanon: true,
        ),
        const RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          rankingStrategy: RankingStrategy.semantic,
        ),
      );

      expect(pack.canonAvailable, isTrue);
      expect(pack.canonIncluded, isFalse);
      expect(pack.hits, isEmpty);
      expect(pack.spentTokenEstimate, 0);
      expect(pack.deferredHitCount, greaterThanOrEqualTo(1));
    });

    test('query type and priority boost ranking without filtering', () async {
      await retriever.indexChunks([
        _chunk(
          id: 'a-scene',
          content: 'lexicalneedle',
          kind: MemorySourceKind.sceneSummary,
        ),
        _chunk(
          id: 'z-persona',
          content: 'vectorproxy',
          kind: MemorySourceKind.characterProfile,
        ),
      ]);
      const semantic = RagRetrievalPolicy(
        roleId: 'test',
        allowedTiers: [MemoryTier.scene],
        rankingStrategy: RankingStrategy.semantic,
      );

      final persona = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.persona,
          text: 'lexicalneedle',
        ),
        semantic,
      );

      expect(persona.hits.map((hit) => hit.chunk.id), contains('a-scene'));
      expect(persona.hits.first.chunk.id, 'z-persona');

      final priorityVec = _RecordingVectorStore();
      final priorityRetriever = HybridRetriever(
        ftsStorage: fts,
        vectorStore: priorityVec,
        embeddingForText: (_) async => const [1.0],
      );
      await priorityRetriever.indexChunks(const [
        StoryMemoryChunk(
          id: 'a-low-priority',
          projectId: 'proj1',
          scopeId: 'scope1',
          kind: MemorySourceKind.relationshipHint,
          content: 'low priority memory',
          priority: 1,
        ),
        StoryMemoryChunk(
          id: 'z-high-priority',
          projectId: 'proj1',
          scopeId: 'scope1',
          kind: MemorySourceKind.relationshipHint,
          content: 'high priority memory',
          priority: 8,
        ),
      ]);
      final prioritized = await priorityRetriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'proj1',
          queryType: StoryMemoryQueryType.persona,
          text: 'priority',
        ),
        semantic,
      );
      final relationshipHits = prioritized.hits
          .where((hit) => hit.chunk.kind == MemorySourceKind.relationshipHint)
          .map((hit) => hit.chunk.id)
          .toList();
      expect(relationshipHits.first, 'z-high-priority');
      expect(relationshipHits, contains('a-low-priority'));
    });
  });

  group('owned generation replacement', () {
    test(
      'scene generations replace independently and preserve other producers',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        await local.indexChunks([
          _chunk(
            id: 'outbox',
            content: 'outbox memory',
            scopeId: 'scene-a',
            producer: 'generation-outbox',
          ),
        ]);
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: 'context-enrichment',
          chunks: [
            _chunk(
              id: _generationId(scopeId: 'scene-a'),
              content: 'old alpha one',
              scopeId: 'scene-a',
              producer: 'context-enrichment',
            ),
            _chunk(
              id: _generationId(scopeId: 'scene-a', index: 1),
              content: 'old alpha two',
              scopeId: 'scene-a',
              producer: 'context-enrichment',
            ),
          ],
        );
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-b',
          producer: 'context-enrichment',
          chunks: [
            _chunk(
              id: _generationId(scopeId: 'scene-b'),
              content: 'beta scene memory',
              scopeId: 'scene-b',
              producer: 'context-enrichment',
            ),
          ],
        );

        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: 'context-enrichment',
          chunks: [
            _chunk(
              id: _generationId(scopeId: 'scene-a'),
              content: 'new alpha memory',
              scopeId: 'scene-a',
              producer: 'context-enrichment',
            ),
          ],
        );

        final currentA = _generationId(scopeId: 'scene-a');
        final currentB = _generationId(scopeId: 'scene-b');
        expect(_indexedIds(db, 'rag_documents'), {
          'outbox',
          currentA,
          currentB,
        });
        expect(_indexedIds(db, 'vector_embeddings'), {
          'outbox',
          currentA,
          currentB,
        });

        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: 'context-enrichment',
          chunks: const [],
        );

        expect(_indexedIds(db, 'rag_documents'), {'outbox', currentB});
        expect(_indexedIds(db, 'vector_embeddings'), {'outbox', currentB});
      },
    );

    test(
      'failed replacement rolls back the previous FTS and vector generation',
      () async {
        var rejectNewGeneration = false;
        final local = HybridRetriever.local(
          db: db,
          embeddingForText: (text) {
            if (rejectNewGeneration && text.contains('new')) {
              throw StateError('embedding failed');
            }
            return _embed(text);
          },
        );
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: 'context-enrichment',
          chunks: [
            _chunk(
              id: _generationId(scopeId: 'scene-a'),
              content: 'old alpha memory',
              scopeId: 'scene-a',
              producer: 'context-enrichment',
            ),
          ],
        );

        rejectNewGeneration = true;
        await expectLater(
          local.replaceOwnedGeneration(
            projectId: 'proj1',
            scopeId: 'scene-a',
            producer: 'context-enrichment',
            chunks: [
              _chunk(
                id: _generationId(scopeId: 'scene-a'),
                content: 'new alpha memory',
                scopeId: 'scene-a',
                producer: 'context-enrichment',
              ),
            ],
          ),
          throwsStateError,
        );

        final ownedId = _generationId(scopeId: 'scene-a');
        expect(_indexedIds(db, 'rag_documents'), {ownedId});
        expect(_indexedIds(db, 'vector_embeddings'), {ownedId});
      },
    );

    test(
      'invalid namespace fails before replacing the previous generation',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        final ownedId = _generationId(scopeId: 'scene-a');
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: StoryMemoryIndexer.contextEnrichmentProducer,
          chunks: [
            _chunk(
              id: ownedId,
              content: 'old alpha memory',
              scopeId: 'scene-a',
              producer: StoryMemoryIndexer.contextEnrichmentProducer,
            ),
          ],
        );

        await expectLater(
          local.replaceOwnedGeneration(
            projectId: 'proj1',
            scopeId: 'scene-a',
            producer: StoryMemoryIndexer.contextEnrichmentProducer,
            chunks: [
              _chunk(
                id: 'outside-owned-namespace',
                content: 'new alpha memory',
                scopeId: 'scene-a',
                producer: StoryMemoryIndexer.contextEnrichmentProducer,
              ),
            ],
          ),
          throwsStateError,
        );

        expect(_indexedIds(db, 'rag_documents'), {ownedId});
        expect(_indexedIds(db, 'vector_embeddings'), {ownedId});
      },
    );

    test(
      'same ID owned by another producer fails before any index write',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        final collidingId = _generationId(scopeId: 'scene-a');
        await local.indexChunks([
          _chunk(
            id: collidingId,
            content: 'other producer memory',
            scopeId: 'scene-a',
            producer: 'generation-outbox',
          ),
        ]);

        await expectLater(
          local.replaceOwnedGeneration(
            projectId: 'proj1',
            scopeId: 'scene-a',
            producer: StoryMemoryIndexer.contextEnrichmentProducer,
            chunks: [
              _chunk(
                id: collidingId,
                content: 'replacement memory',
                scopeId: 'scene-a',
                producer: StoryMemoryIndexer.contextEnrichmentProducer,
              ),
            ],
          ),
          throwsStateError,
        );

        expect(_indexedIds(db, 'rag_documents'), {collidingId});
        expect(_indexedIds(db, 'vector_embeddings'), {collidingId});
        expect(
          db.select('SELECT content FROM rag_documents WHERE path = ?', [
            collidingId,
          ]).single['content'],
          'other producer memory',
        );
      },
    );

    test(
      'legacy cleanup requires exact scope, ID pattern, and matching kind',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        await local.indexChunks([
          _chunk(
            id: 'proj1_wf_0',
            content: 'legacy owned world fact',
            scopeId: 'scene-a',
            kind: MemorySourceKind.worldFact,
          ),
          _chunk(
            id: 'proj1_wf_99',
            content: 'same shape but wrong kind',
            scopeId: 'scene-a',
            kind: MemorySourceKind.sceneSummary,
          ),
          _chunk(
            id: 'proj1_wf_1',
            content: 'same shape but another scope',
            scopeId: 'scene-b',
            kind: MemorySourceKind.worldFact,
          ),
        ]);

        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: 'context-enrichment',
          chunks: const [],
          includeLegacyContextRows: true,
        );

        expect(_indexedIds(db, 'rag_documents'), {'proj1_wf_99', 'proj1_wf_1'});
        expect(_indexedIds(db, 'vector_embeddings'), {
          'proj1_wf_99',
          'proj1_wf_1',
        });
      },
    );

    test(
      'one-sided owned row is deleted only from its proving index',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        final ownedId = _generationId(scopeId: 'scene-a');
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: StoryMemoryIndexer.contextEnrichmentProducer,
          chunks: [
            _chunk(
              id: ownedId,
              content: 'owned only in FTS after drift',
              scopeId: 'scene-a',
              producer: StoryMemoryIndexer.contextEnrichmentProducer,
            ),
          ],
        );
        db.execute('DELETE FROM vector_embeddings WHERE id = ?', [ownedId]);

        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: StoryMemoryIndexer.contextEnrichmentProducer,
          chunks: const [],
        );

        expect(_indexedIds(db, 'rag_documents'), isEmpty);
        expect(_indexedIds(db, 'vector_embeddings'), isEmpty);
      },
    );

    test(
      'producer drift for the same ID fails closed before either index deletes',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        final ownedId = _generationId(scopeId: 'scene-a');
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: StoryMemoryIndexer.contextEnrichmentProducer,
          chunks: [
            _chunk(
              id: ownedId,
              content: 'stable generation',
              scopeId: 'scene-a',
              producer: StoryMemoryIndexer.contextEnrichmentProducer,
            ),
          ],
        );
        final metadata =
            db.select(
                  'SELECT metadata_json FROM vector_embeddings WHERE id = ?',
                  [ownedId],
                ).single['metadata_json']
                as String;
        db.execute(
          '''UPDATE vector_embeddings SET metadata_json = replace(?,
            'context-enrichment', 'foreign-producer') WHERE id = ?''',
          [metadata, ownedId],
        );

        await expectLater(
          local.replaceOwnedGeneration(
            projectId: 'proj1',
            scopeId: 'scene-a',
            producer: StoryMemoryIndexer.contextEnrichmentProducer,
            chunks: const [],
          ),
          throwsStateError,
        );

        expect(_indexedIds(db, 'rag_documents'), {ownedId});
        expect(_indexedIds(db, 'vector_embeddings'), {ownedId});
      },
    );

    test(
      'owner ID drift aborts an empty generation and preserves both sides',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        final ownedId = _generationId(scopeId: 'scene-a');
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: StoryMemoryIndexer.contextEnrichmentProducer,
          chunks: [
            _chunk(
              id: ownedId,
              content: 'private stable generation',
              scopeId: 'scene-a',
              producer: StoryMemoryIndexer.contextEnrichmentProducer,
              visibility: MemoryVisibility.agentPrivate,
              ownerId: 'owner-a',
            ),
          ],
        );
        db.execute(
          "UPDATE vector_embeddings SET owner_id = 'foreign-owner' "
          'WHERE id = ?',
          [ownedId],
        );

        await expectLater(
          local.replaceOwnedGeneration(
            projectId: 'proj1',
            scopeId: 'scene-a',
            producer: StoryMemoryIndexer.contextEnrichmentProducer,
            chunks: const [],
          ),
          throwsStateError,
        );

        expect(_indexedIds(db, 'rag_documents'), {ownedId});
        expect(_indexedIds(db, 'vector_embeddings'), {ownedId});
        expect(
          db.select('SELECT owner_id FROM rag_documents WHERE path = ?', [
            ownedId,
          ]).single['owner_id'],
          'owner-a',
        );
        expect(
          db.select('SELECT owner_id FROM vector_embeddings WHERE id = ?', [
            ownedId,
          ]).single['owner_id'],
          'foreign-owner',
        );
      },
    );

    test(
      'visibility drift aborts an empty generation and preserves both sides',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        final ownedId = _generationId(scopeId: 'scene-a');
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: StoryMemoryIndexer.contextEnrichmentProducer,
          chunks: [
            _chunk(
              id: ownedId,
              content: 'public stable generation',
              scopeId: 'scene-a',
              producer: StoryMemoryIndexer.contextEnrichmentProducer,
            ),
          ],
        );
        db.execute(
          "UPDATE vector_embeddings SET visibility = 'editorOnly' "
          'WHERE id = ?',
          [ownedId],
        );

        await expectLater(
          local.replaceOwnedGeneration(
            projectId: 'proj1',
            scopeId: 'scene-a',
            producer: StoryMemoryIndexer.contextEnrichmentProducer,
            chunks: const [],
          ),
          throwsStateError,
        );

        expect(_indexedIds(db, 'rag_documents'), {ownedId});
        expect(_indexedIds(db, 'vector_embeddings'), {ownedId});
        expect(
          db.select('SELECT visibility FROM rag_documents WHERE path = ?', [
            ownedId,
          ]).single['visibility'],
          'publicObservable',
        );
        expect(
          db.select('SELECT visibility FROM vector_embeddings WHERE id = ?', [
            ownedId,
          ]).single['visibility'],
          'editorOnly',
        );
      },
    );

    test(
      'tier drift aborts a shrinking generation and rolls back retained rows',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        final retainedId = _generationId(scopeId: 'scene-a');
        final shrinkingId = _generationId(scopeId: 'scene-a', index: 1);
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: StoryMemoryIndexer.contextEnrichmentProducer,
          chunks: [
            _chunk(
              id: retainedId,
              content: 'old retained tier generation',
              scopeId: 'scene-a',
              producer: StoryMemoryIndexer.contextEnrichmentProducer,
            ),
            _chunk(
              id: shrinkingId,
              content: 'old shrinking tier generation',
              scopeId: 'scene-a',
              producer: StoryMemoryIndexer.contextEnrichmentProducer,
            ),
          ],
        );
        db.execute("UPDATE vector_embeddings SET tier = 'canon' WHERE id = ?", [
          shrinkingId,
        ]);

        await expectLater(
          local.replaceOwnedGeneration(
            projectId: 'proj1',
            scopeId: 'scene-a',
            producer: StoryMemoryIndexer.contextEnrichmentProducer,
            chunks: [
              _chunk(
                id: retainedId,
                content: 'new retained tier generation',
                scopeId: 'scene-a',
                producer: StoryMemoryIndexer.contextEnrichmentProducer,
              ),
            ],
          ),
          throwsStateError,
        );

        expect(_indexedIds(db, 'rag_documents'), {retainedId, shrinkingId});
        expect(_indexedIds(db, 'vector_embeddings'), {retainedId, shrinkingId});
        expect(
          db.select('SELECT content FROM rag_documents WHERE path = ?', [
            retainedId,
          ]).single['content'],
          'old retained tier generation',
        );
        expect(
          db.select('SELECT tier FROM vector_embeddings WHERE id = ?', [
            shrinkingId,
          ]).single['tier'],
          'canon',
        );
      },
    );

    test(
      'scope drift aborts a shrinking generation and preserves both sides',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        final retainedId = _generationId(scopeId: 'scene-a');
        final shrinkingId = _generationId(scopeId: 'scene-a', index: 1);
        await local.replaceOwnedGeneration(
          projectId: 'proj1',
          scopeId: 'scene-a',
          producer: StoryMemoryIndexer.contextEnrichmentProducer,
          chunks: [
            _chunk(
              id: retainedId,
              content: 'old retained generation',
              scopeId: 'scene-a',
              producer: StoryMemoryIndexer.contextEnrichmentProducer,
            ),
            _chunk(
              id: shrinkingId,
              content: 'old shrinking generation',
              scopeId: 'scene-a',
              producer: StoryMemoryIndexer.contextEnrichmentProducer,
            ),
          ],
        );
        db.execute(
          "UPDATE vector_embeddings SET scope_id = 'foreign-scope', "
          "metadata_json = replace(metadata_json, 'scene-a', "
          "'foreign-scope') WHERE id = ?",
          [shrinkingId],
        );

        await expectLater(
          local.replaceOwnedGeneration(
            projectId: 'proj1',
            scopeId: 'scene-a',
            producer: StoryMemoryIndexer.contextEnrichmentProducer,
            chunks: [
              _chunk(
                id: retainedId,
                content: 'new retained generation',
                scopeId: 'scene-a',
                producer: StoryMemoryIndexer.contextEnrichmentProducer,
              ),
            ],
          ),
          throwsStateError,
        );

        expect(_indexedIds(db, 'rag_documents'), {retainedId, shrinkingId});
        expect(_indexedIds(db, 'vector_embeddings'), {retainedId, shrinkingId});
        expect(
          db.select('SELECT content FROM rag_documents WHERE path = ?', [
            retainedId,
          ]).single['content'],
          'old retained generation',
        );
        expect(
          db.select('SELECT scope_id FROM vector_embeddings WHERE id = ?', [
            shrinkingId,
          ]).single['scope_id'],
          'foreign-scope',
        );
      },
    );

    test(
      'legacy kind drift fails closed without deleting either side',
      () async {
        final local = HybridRetriever.local(db: db, embeddingForText: _embed);
        const legacyId = 'proj1_wf_0';
        await local.indexChunks([
          _chunk(
            id: legacyId,
            content: 'legacy fact',
            scopeId: 'scene-a',
            kind: MemorySourceKind.worldFact,
          ),
        ]);
        db.execute(
          '''UPDATE vector_embeddings SET metadata_json =
            replace(metadata_json, 'worldFact', 'sceneSummary') WHERE id = ?''',
          [legacyId],
        );

        await expectLater(
          local.replaceOwnedGeneration(
            projectId: 'proj1',
            scopeId: 'scene-a',
            producer: StoryMemoryIndexer.contextEnrichmentProducer,
            chunks: const [],
            includeLegacyContextRows: true,
          ),
          throwsStateError,
        );

        expect(_indexedIds(db, 'rag_documents'), {legacyId});
        expect(_indexedIds(db, 'vector_embeddings'), {legacyId});
      },
    );
  });
}

Set<String> _indexedIds(Database db, String table) {
  final column = table == 'rag_documents' ? 'path' : 'id';
  return {
    for (final row in db.select('SELECT $column FROM $table'))
      row[column] as String,
  };
}

List<String> _formattedExcerpts(RagSceneContext context) {
  return context.formattedContext
      .trimRight()
      .split('\n')
      .skip(1)
      .map((line) => line.substring(line.indexOf(': ') + 2))
      .toList();
}

Future<void> _expectNearDuplicateBoundary({
  required LocalRagStorage fts,
  required VectorStore vec,
  MemorySourceKind variantKind = MemorySourceKind.sceneSummary,
  MemoryVisibility variantVisibility = MemoryVisibility.publicObservable,
  String variantScopeId = 'scope1',
}) async {
  final retriever = HybridRetriever(
    ftsStorage: fts,
    vectorStore: vec,
    embeddingForText: HybridRetriever.defaultEmbedding,
  );
  const original = '林澈在雨夜抵达旧港码头，发现失踪船长留下的铜制罗盘，随后沿着潮湿石阶追查北岸仓库的秘密暗门。';
  const retelling = '林澈在雨夜抵达旧港码头，发现失踪船长留下的铜制罗盘，随后沿着潮湿石阶追查北岸仓库的隐秘暗门。';
  const independent = '北境粮仓昨夜失火，守卫确认冬季储备只剩三成。';
  await retriever.indexChunks([
    _chunk(id: 'a-original', content: original),
    _chunk(
      id: 'b-retelling',
      content: retelling,
      kind: variantKind,
      scopeId: variantScopeId,
      visibility: variantVisibility,
      ownerId: variantVisibility == MemoryVisibility.agentPrivate
          ? 'test-agent'
          : '',
    ),
    _chunk(id: 'c-independent', content: independent),
  ]);

  final pack = await retriever.retrieve(
    StoryMemoryQuery(
      projectId: 'proj1',
      queryType: StoryMemoryQueryType.sceneContinuity,
      text: '$original 北境粮仓',
      scopeId: 'scope1',
      maxResults: 2,
      viewerId: 'test-agent',
      allowedAncestorScopeIds: [if (variantScopeId != 'scope1') variantScopeId],
    ),
    const RagRetrievalPolicy(
      roleId: 'test',
      allowedTiers: [MemoryTier.scene],
      excludeDraftTier: false,
      rankingStrategy: RankingStrategy.semantic,
    ),
  );

  expect(pack.hits.map((hit) => hit.chunk.id).toList(), [
    'a-original',
    'b-retelling',
  ]);
}

class _RecordingVectorStore extends FakeVectorStore {
  String? lastProjectId;
  Set<MemoryTier>? lastTiers;
  final searchLimits = <int>[];
  final upsertBatchSizes = <int>[];

  @override
  Future<void> upsertAll(List<VectorStoreEntry> entries) {
    upsertBatchSizes.add(entries.length);
    return super.upsertAll(entries);
  }

  @override
  Future<List<VectorSearchHit>> search({
    required List<double> embedding,
    String projectId = '',
    Set<MemoryTier>? tiers,
    int limit = 10,
  }) {
    lastProjectId = projectId;
    lastTiers = tiers == null ? null : Set<MemoryTier>.from(tiers);
    searchLimits.add(limit);
    return super.search(
      embedding: embedding,
      projectId: projectId,
      tiers: tiers,
      limit: limit,
    );
  }
}

class _RecordingLocalRagStorage extends LocalRagStorage {
  _RecordingLocalRagStorage({required super.db});

  final searchLimits = <int>[];

  @override
  Future<List<LocalRagFtsResult>> searchFts({
    required String projectId,
    required String query,
    int limit = 10,
    String? category,
    RagAdmission? admission,
  }) {
    searchLimits.add(limit);
    return super.searchFts(
      projectId: projectId,
      query: query,
      limit: limit,
      category: category,
      admission: admission,
    );
  }
}
