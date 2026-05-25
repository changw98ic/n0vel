import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'local_rag_storage.dart';
import 'memory_models.dart';
import 'memory_policy.dart';
import 'rag_retrieval_policy.dart';
import 'sqlite_vss_store.dart';
import 'story_memory_retrieval_service.dart';
import 'vector_store.dart';

/// A single search result from the hybrid RAG index.
class RagSearchResult {
  const RagSearchResult({
    required this.path,
    required this.content,
    required this.score,
    this.metadata = const {},
  });

  final String path;
  final String content;
  final double score;
  final Map<String, Object?> metadata;
}

/// Context retrieved from RAG for a scene.
class RagSceneContext {
  const RagSceneContext({
    required this.results,
    required this.formattedContext,
  });

  factory RagSceneContext.fromPack(StoryRetrievalPack pack) {
    final results = [
      for (final hit in pack.hits)
        RagSearchResult(
          path: hit.chunk.id,
          content: hit.chunk.content,
          score: hit.score,
          metadata: hit.chunk.toJson(),
        ),
    ];
    return RagSceneContext(
      results: results,
      formattedContext: _formatContext(results),
    );
  }

  final List<RagSearchResult> results;
  final String formattedContext;

  bool get isEmpty => results.isEmpty;

  static String _formatContext(List<RagSearchResult> results) {
    if (results.isEmpty) return '';
    final buffer = StringBuffer('【RAG检索上下文】\n');
    for (final result in results) {
      final snippet = result.content.length > 200
          ? '${result.content.substring(0, 197)}...'
          : result.content;
      buffer.writeln(
        '- [${result.path}] ${result.score.toStringAsFixed(2)}: $snippet',
      );
    }
    return buffer.toString();
  }
}

/// Fuses keyword (FTS5) and semantic (vector) retrieval for story memory.
class HybridRetriever implements StoryMemoryRetrievalService {
  HybridRetriever({
    required this.ftsStorage,
    required this.vectorStore,
    required this.embeddingForText,
  });

  factory HybridRetriever.local({
    required Database db,
    Future<List<double>> Function(String text)? embeddingForText,
  }) {
    return HybridRetriever(
      ftsStorage: LocalRagStorage(db: db),
      vectorStore: SqliteVssStore(db),
      embeddingForText: embeddingForText ?? defaultEmbedding,
    );
  }

  final LocalRagStorage ftsStorage;
  final VectorStore vectorStore;
  final Future<List<double>> Function(String text) embeddingForText;

  /// Deterministic local fallback embedding for tests and offline indexing.
  static Future<List<double>> defaultEmbedding(String text) async {
    const dims = 64;
    final vector = List<double>.filled(dims, 0.0);
    final tokens = RegExp(r'[\p{L}\p{N}_]+', unicode: true)
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .where((token) => token.isNotEmpty);

    for (final token in tokens) {
      var hash = 2166136261;
      for (final codeUnit in token.codeUnits) {
        hash ^= codeUnit;
        hash = (hash * 16777619) & 0x7fffffff;
      }
      vector[hash % dims] += 1.0;
    }

    final norm = sqrt(vector.fold(0.0, (sum, value) => sum + value * value));
    if (norm == 0) return vector;
    return [for (final value in vector) value / norm];
  }

  /// Indexes [chunks] into both FTS and vector stores.
  Future<void> indexChunks(List<StoryMemoryChunk> chunks) async {
    await Future.wait([_indexIntoFts(chunks), _indexIntoVectorStore(chunks)]);
  }

  /// Replaces a project's hybrid index with parsed project materials.
  Future<void> syncProject({
    required String projectId,
    required List<String> characterProfiles,
    required List<String> outlineBeats,
    required List<String> worldFacts,
    List<String> chapterContents = const [],
  }) async {
    await ftsStorage.clearProject(projectId);
    final chunks = <StoryMemoryChunk>[
      for (var i = 0; i < characterProfiles.length; i++)
        StoryMemoryChunk(
          id: '$projectId/characters/char_$i.md',
          projectId: projectId,
          scopeId: projectId,
          kind: MemorySourceKind.characterProfile,
          content: characterProfiles[i],
          tier: MemoryTier.character,
          producer: 'hybrid-sync',
          tags: const ['character'],
        ),
      for (var i = 0; i < outlineBeats.length; i++)
        StoryMemoryChunk(
          id: '$projectId/outlines/beat_$i.md',
          projectId: projectId,
          scopeId: projectId,
          kind: MemorySourceKind.outlineBeat,
          content: outlineBeats[i],
          tier: MemoryTier.canon,
          producer: 'hybrid-sync',
          tags: const ['outline'],
        ),
      for (var i = 0; i < worldFacts.length; i++)
        StoryMemoryChunk(
          id: '$projectId/worldbuilding/fact_$i.md',
          projectId: projectId,
          scopeId: projectId,
          kind: MemorySourceKind.worldFact,
          content: worldFacts[i],
          tier: MemoryTier.canon,
          producer: 'hybrid-sync',
          tags: const ['world'],
        ),
      for (var i = 0; i < chapterContents.length; i++)
        StoryMemoryChunk(
          id: '$projectId/chapters/chapter_$i.md',
          projectId: projectId,
          scopeId: projectId,
          kind: MemorySourceKind.sceneSummary,
          content: chapterContents[i],
          tier: MemoryTier.scene,
          producer: 'hybrid-sync',
          tags: const ['chapter'],
        ),
    ];
    await indexChunks(chunks);
  }

  /// Indexes generated chapter content into the hybrid index.
  Future<void> pushChapter({
    required String projectId,
    required int chapterIndex,
    required String content,
  }) async {
    await indexChunks([
      StoryMemoryChunk(
        id: '$projectId/chapters/chapter_$chapterIndex.md',
        projectId: projectId,
        scopeId: projectId,
        kind: MemorySourceKind.sceneSummary,
        content: content,
        tier: MemoryTier.scene,
        producer: 'chapter-finalization',
        tags: const ['chapter'],
      ),
    ]);
  }

  /// Retrieves formatted scene context through the hybrid index.
  Future<RagSceneContext> retrieveForScene({
    required String projectId,
    required String sceneTitle,
    required String sceneSummary,
    List<String> castNames = const [],
    List<String> worldNodeIds = const [],
    RagRetrievalPolicy policy = const RagRetrievalPolicy(roleId: 'scene'),
  }) async {
    final query = StoryMemoryQuery(
      projectId: projectId,
      queryType: StoryMemoryQueryType.sceneContinuity,
      text: [
        sceneTitle,
        sceneSummary,
        if (castNames.isNotEmpty) '${castNames.join(' ')} 角色关系 性格',
        if (worldNodeIds.isNotEmpty) '${worldNodeIds.join(' ')} 世界观 规则',
      ].where((part) => part.trim().isNotEmpty).join(' '),
      tags: [for (final name in castNames) 'char-$name', ...worldNodeIds],
      maxResults: 10,
      tokenBudget: policy.maxTokens,
    );
    return RagSceneContext.fromPack(await retrieve(query, policy));
  }

  /// Retrieves memory hits by fusing FTS and vector scores per [policy].
  @override
  Future<StoryRetrievalPack> retrieve(
    StoryMemoryQuery query, [
    RagRetrievalPolicy policy = const RagRetrievalPolicy(roleId: 'default'),
  ]) async {
    final tierSet = _effectiveTierSet(policy);
    final strategy = policy.rankingStrategy;
    final byId = <String, _Candidate>{};

    if (strategy != RankingStrategy.semantic) {
      final ftsHits = await ftsStorage.searchFts(
        projectId: query.projectId,
        query: query.text,
        limit: query.maxResults * 3,
      );
      for (final hit in ftsHits) {
        final metadata = Map<String, dynamic>.from(hit.metadata);
        final tier = _parseTier(metadata['tier']);
        if (!tierSet.contains(tier)) continue;
        byId[hit.path] = _Candidate(
          id: hit.path,
          content: hit.content,
          metadata: metadata,
          explicitTier: null,
          ftsScore: hit.score,
          vectorScore: 0.0,
        );
      }
    }

    if (strategy != RankingStrategy.keyword) {
      final embedding = await embeddingForText(query.text);
      final vectorHits = await vectorStore.search(
        embedding: embedding,
        tiers: tierSet,
        limit: query.maxResults * 3,
      );
      for (final hit in vectorHits) {
        final metadata = Map<String, dynamic>.from(hit.metadata);
        if (metadata['projectId']?.toString() != query.projectId) continue;
        final existing = byId[hit.id];
        if (existing != null) {
          byId[hit.id] = existing.copyWith(vectorScore: hit.score);
        } else {
          byId[hit.id] = _Candidate(
            id: hit.id,
            content: hit.content,
            metadata: metadata,
            explicitTier: hit.tier,
            ftsScore: 0.0,
            vectorScore: hit.score,
          );
        }
      }
    }

    final scored = <_Scored>[];
    for (final candidate in byId.values) {
      final score = switch (strategy) {
        RankingStrategy.keyword => candidate.ftsScore,
        RankingStrategy.semantic => candidate.vectorScore,
        RankingStrategy.hybrid =>
          candidate.ftsScore * policy.keywordWeight +
              candidate.vectorScore * policy.semanticWeight,
      };
      if (score > 0) {
        scored.add(_Scored(candidate: candidate, score: score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final hits = <StoryMemoryHit>[];
    var deferred = 0;
    var spent = 0;
    for (final scoredHit in scored) {
      final chunk = _reconstructChunk(scoredHit.candidate);
      final cost = _tokenEstimate(chunk);
      if (hits.length >= query.maxResults) {
        deferred++;
        continue;
      }
      if (spent + cost > query.tokenBudget && hits.isNotEmpty) {
        deferred++;
        continue;
      }
      hits.add(StoryMemoryHit(chunk: chunk, score: scoredHit.score));
      spent += cost;
    }

    final sourceRefs = <MemorySourceRef>[
      for (final hit in hits) ...hit.chunk.sourceRefs,
    ];

    return StoryRetrievalPack(
      query: query,
      hits: List.unmodifiable(hits),
      sourceRefs: sourceRefs,
      summary: _buildSummary(hits),
      tokenBudget: query.tokenBudget,
      spentTokenEstimate: spent,
      deferredHitCount: deferred,
    );
  }

  Future<void> _indexIntoFts(List<StoryMemoryChunk> chunks) async {
    for (final chunk in chunks) {
      await ftsStorage.indexDocument(
        projectId: chunk.projectId,
        path: chunk.id,
        content: chunk.content,
        category: chunk.kind.name,
        metadata: _chunkMetadata(chunk),
      );
    }
  }

  Future<void> _indexIntoVectorStore(List<StoryMemoryChunk> chunks) async {
    for (final chunk in chunks) {
      await vectorStore.upsert(
        id: chunk.id,
        content: chunk.content,
        embedding: await embeddingForText(chunk.content),
        tier: chunk.tier,
        metadata: _chunkMetadata(chunk),
      );
    }
  }

  static Map<String, Object?> _chunkMetadata(StoryMemoryChunk chunk) => {
    'projectId': chunk.projectId,
    'scopeId': chunk.scopeId,
    'kind': chunk.kind.name,
    'tier': chunk.tier.name,
    'producer': chunk.producer,
    'sourceRefs': [for (final ref in chunk.sourceRefs) ref.toJson()],
    'rootSourceIds': chunk.rootSourceIds,
    'visibility': chunk.visibility.name,
    'tags': chunk.tags,
    'priority': chunk.priority,
    'tokenCostEstimate': chunk.tokenCostEstimate,
    'createdAtMs': chunk.createdAtMs,
  };

  static Set<MemoryTier> _effectiveTierSet(RagRetrievalPolicy policy) {
    final tiers = policy.allowedTiers.toSet();
    if (policy.excludeDraftTier) tiers.remove(MemoryTier.draft);
    return tiers;
  }

  static StoryMemoryChunk _reconstructChunk(_Candidate candidate) {
    final metadata = candidate.metadata;
    return StoryMemoryChunk(
      id: candidate.id,
      content: candidate.content,
      projectId: metadata['projectId']?.toString() ?? '',
      scopeId: metadata['scopeId']?.toString() ?? '',
      kind: _parseKind(metadata['kind']),
      tier: candidate.explicitTier ?? _parseTier(metadata['tier']),
      producer: metadata['producer']?.toString() ?? '',
      sourceRefs: _parseSourceRefs(metadata['sourceRefs']),
      rootSourceIds: _stringList(metadata['rootSourceIds']),
      visibility: _parseVisibility(metadata['visibility']),
      tags: _stringList(metadata['tags']),
      priority: _parseInt(metadata['priority']),
      tokenCostEstimate: _parseInt(metadata['tokenCostEstimate']),
      createdAtMs: _parseInt(metadata['createdAtMs']),
    );
  }

  static int _tokenEstimate(StoryMemoryChunk chunk) {
    if (chunk.tokenCostEstimate > 0) return chunk.tokenCostEstimate;
    return chunk.content.length ~/ 4;
  }

  static String _buildSummary(List<StoryMemoryHit> hits) {
    if (hits.isEmpty) return '';
    return hits
        .take(3)
        .map(
          (hit) => hit.chunk.content.length > 80
              ? '${hit.chunk.content.substring(0, 77)}...'
              : hit.chunk.content,
        )
        .join(' | ');
  }

  static MemoryTier _parseTier(Object? raw) =>
      _tierByName[raw?.toString()] ?? MemoryTier.scene;

  static MemorySourceKind _parseKind(Object? raw) =>
      _kindByName[raw?.toString()] ?? MemorySourceKind.sceneSummary;

  static MemoryVisibility _parseVisibility(Object? raw) =>
      _visibilityByName[raw?.toString()] ?? MemoryVisibility.publicObservable;

  static List<MemorySourceRef> _parseSourceRefs(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          MemorySourceRef.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final value in raw)
        if (value != null) value.toString(),
    ];
  }

  static int _parseInt(Object? raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}

final _tierByName = {for (final tier in MemoryTier.values) tier.name: tier};
final _kindByName = {
  for (final kind in MemorySourceKind.values) kind.name: kind,
};
final _visibilityByName = {
  for (final visibility in MemoryVisibility.values) visibility.name: visibility,
};

class _Candidate {
  const _Candidate({
    required this.id,
    required this.content,
    required this.metadata,
    required this.explicitTier,
    required this.ftsScore,
    required this.vectorScore,
  });

  final String id;
  final String content;
  final Map<String, dynamic> metadata;
  final MemoryTier? explicitTier;
  final double ftsScore;
  final double vectorScore;

  _Candidate copyWith({double? vectorScore}) => _Candidate(
    id: id,
    content: content,
    metadata: metadata,
    explicitTier: explicitTier,
    ftsScore: ftsScore,
    vectorScore: vectorScore ?? this.vectorScore,
  );
}

class _Scored {
  const _Scored({required this.candidate, required this.score});

  final _Candidate candidate;
  final double score;
}
