import 'dart:convert';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../llm/app_llm_canonical_hash.dart';
import '../state/sqlite_write_coordinator.dart';

import '../../features/story_generation/domain/contracts/memory_policy.dart';
import '../../features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import '../../features/story_generation/domain/memory_models.dart';
import '../../features/story_generation/domain/story_pipeline_interfaces.dart'
    show StoryMemoryRetrievalService;
import '../../features/story_generation/data/story_memory_indexer.dart';
import 'cjk_text_normalizer.dart';
import 'local_rag_storage.dart';
import 'sqlite_vss_store.dart';
import 'vector_store.dart';
import 'vector_embedding_profile.dart';
import 'vector_store_schema.dart';

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
  static const _promptExcerptMaxRunes = 200;

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
      formattedContext: _formatContext(results, query: pack.query.text),
    );
  }

  final List<RagSearchResult> results;
  final String formattedContext;

  bool get isEmpty => results.isEmpty;

  static String _formatContext(
    List<RagSearchResult> results, {
    required String query,
  }) {
    if (results.isEmpty) return '';
    final buffer = StringBuffer('【RAG检索上下文】\n');
    for (final result in results) {
      final snippet = _queryAwareExcerpt(
        result.content,
        query,
        maxRunes: _promptExcerptMaxRunes,
      );
      buffer.writeln(
        '- [${result.path}] ${result.score.toStringAsFixed(2)}: $snippet',
      );
    }
    return buffer.toString();
  }

  static String _queryAwareExcerpt(
    String content,
    String query, {
    required int maxRunes,
  }) {
    if (maxRunes <= 0 || content.isEmpty) return '';
    final contentRunes = content.runes.toList(growable: false);
    if (contentRunes.length <= maxRunes) return content;
    if (maxRunes == 1) return '…';

    final anchor = _longestQueryAnchor(contentRunes, query);
    if (anchor == null) {
      return String.fromCharCodes([...contentRunes.take(maxRunes - 1), 0x2026]);
    }

    // Reserve one rune for each possible ellipsis. A window touching either
    // edge can be shorter than the limit, but never risks hiding the anchor.
    final bodyLength = max(1, maxRunes - 2);
    final anchorCenter = anchor.start + anchor.length ~/ 2;
    var start = anchorCenter - bodyLength ~/ 2;
    if (start < 0) start = 0;
    final maxStart = contentRunes.length - bodyLength;
    if (start > maxStart) start = maxStart;
    final end = min(contentRunes.length, start + bodyLength);

    return String.fromCharCodes([
      if (start > 0) 0x2026,
      ...contentRunes.sublist(start, end),
      if (end < contentRunes.length) 0x2026,
    ]);
  }

  static ({int start, int length})? _longestQueryAnchor(
    List<int> contentRunes,
    String query,
  ) {
    final tokens = localEmbeddingTokens(query, maxTokens: 32).toSet().toList()
      ..sort((first, second) {
        final lengthOrder = second.runes.length.compareTo(first.runes.length);
        return lengthOrder != 0 ? lengthOrder : first.compareTo(second);
      });
    if (tokens.isEmpty) return null;

    final folded = _foldRunesForSearch(contentRunes);
    for (final token in tokens) {
      final tokenRunes = token.toLowerCase().runes.toList(growable: false);
      if (tokenRunes.isEmpty) continue;
      final foldedIndex = _indexOfRunes(folded.runes, tokenRunes);
      if (foldedIndex < 0) continue;
      final start = folded.originalIndices[foldedIndex];
      final lastIndex = foldedIndex + tokenRunes.length - 1;
      final end = folded.originalIndices[lastIndex] + 1;
      return (start: start, length: max(1, end - start));
    }
    return null;
  }

  static ({List<int> runes, List<int> originalIndices}) _foldRunesForSearch(
    List<int> originalRunes,
  ) {
    final foldedRunes = <int>[];
    final originalIndices = <int>[];
    for (var index = 0; index < originalRunes.length; index++) {
      for (final foldedRune in String.fromCharCode(
        originalRunes[index],
      ).toLowerCase().runes) {
        foldedRunes.add(foldedRune);
        originalIndices.add(index);
      }
    }
    return (runes: foldedRunes, originalIndices: originalIndices);
  }

  static int _indexOfRunes(List<int> haystack, List<int> needle) {
    if (needle.isEmpty || needle.length > haystack.length) return -1;
    final lastStart = haystack.length - needle.length;
    for (var start = 0; start <= lastStart; start++) {
      var matched = true;
      for (var offset = 0; offset < needle.length; offset++) {
        if (haystack[start + offset] != needle[offset]) {
          matched = false;
          break;
        }
      }
      if (matched) return start;
    }
    return -1;
  }
}

/// Read-only work counters emitted after a successful hybrid retrieval.
class HybridRetrievalDiagnostics {
  HybridRetrievalDiagnostics({
    required this.expansionRounds,
    required List<int> candidateLimits,
    required this.ftsSearches,
    required this.vectorSearches,
    required this.nearDuplicateComparisons,
  }) : candidateLimits = List.unmodifiable(candidateLimits);

  /// Number of candidate-window expansions after the initial fetch.
  final int expansionRounds;

  /// Candidate limit used by each main retrieval round, in order.
  final List<int> candidateLimits;

  /// Total FTS calls, including mandatory-canon reservation calls.
  final int ftsSearches;

  /// Total vector calls, including mandatory-canon reservation calls.
  final int vectorSearches;

  /// Candidate-to-representative comparisons during diversity reranking.
  final int nearDuplicateComparisons;
}

/// Immutable, embedded owned-generation write ready for a DB-only commit.
class HybridOwnedGenerationWrite {
  const HybridOwnedGenerationWrite._({
    required this.projectId,
    required this.scopeId,
    required this.producer,
    required this.chunks,
    required this.vectorBatches,
    required this.includeLegacyContextRows,
  });

  final String projectId;
  final String scopeId;
  final String producer;
  final List<StoryMemoryChunk> chunks;
  final List<List<VectorStoreEntry>> vectorBatches;
  final bool includeLegacyContextRows;
}

/// Fuses keyword (FTS5) and semantic (vector) retrieval for story memory.
class HybridRetriever implements StoryMemoryRetrievalService {
  /// Bounds adaptive recall to the initial fetch plus two expansions.
  static const _maxAdaptiveExpansionRounds = 2;

  static final String localReleaseHash = AppLlmCanonicalHash.domainHash(
    'hybrid-retriever-local-release-v1',
    const <String, Object?>{
      'fts': 'local-rag-storage-fts5',
      'vector': 'sqlite-lsh-exact-rerank',
      'admission': 'project-tier-visibility-owner-scope-tags-before-ranking',
      'adaptiveExpansionRounds': _maxAdaptiveExpansionRounds,
      'exactSearchThreshold': SqliteVssStore.exactSearchThreshold,
      'minimumAnnCandidates': SqliteVssStore.minCandidateRows,
      'maximumAnnCandidates': SqliteVssStore.maxCandidateRows,
      'annCandidatesPerHit': SqliteVssStore.candidateRowsPerHit,
      'annJoinOrder': 'probe-first-cross-join-v1',
      'embeddingProfileSchemaVersion': vectorEmbeddingProfileSchemaVersion,
      'indexWriteBatchSize': indexWriteBatchSize,
      'vectorSchema': <String, Object?>{
        'lshVersion': vectorLshVersion,
        'tableCount': vectorLshTableCount,
        'bitsPerTable': vectorLshBitsPerTable,
        'probeRadius': vectorLshProbeRadius,
        'admissionVersion': vectorAdmissionSchemaVersion,
      },
      'localRagSchemaVersion': LocalRagStorage.schemaReleaseVersion,
      'cjkTextNormalizerVersion': cjkTextNormalizerVersion,
    },
  );

  HybridRetriever({
    required this.ftsStorage,
    required this.vectorStore,
    required this.embeddingForText,
    this.embeddingForTexts,
    this.onDiagnostics,
    SqliteWriteCoordinator? writeCoordinator,
  }) : writeCoordinator = writeCoordinator ?? ftsStorage.writeCoordinator;

  factory HybridRetriever.local({
    required Database db,
    Future<List<double>> Function(String text)? embeddingForText,
    Future<List<List<double>>> Function(List<String> texts)? embeddingForTexts,
    void Function(HybridRetrievalDiagnostics diagnostics)? onDiagnostics,
    SqliteWriteCoordinator? writeCoordinator,
  }) {
    final effectiveWriteCoordinator =
        writeCoordinator ?? SqliteWriteCoordinator.forDatabase(db);
    return HybridRetriever(
      ftsStorage: LocalRagStorage(
        db: db,
        writeCoordinator: effectiveWriteCoordinator,
      ),
      vectorStore: SqliteVssStore(
        db,
        writeCoordinator: effectiveWriteCoordinator,
      ),
      embeddingForText: embeddingForText ?? defaultEmbedding,
      embeddingForTexts: embeddingForTexts,
      onDiagnostics: onDiagnostics,
      writeCoordinator: effectiveWriteCoordinator,
    );
  }

  final LocalRagStorage ftsStorage;
  final VectorStore vectorStore;
  final Future<List<double>> Function(String text) embeddingForText;
  final Future<List<List<double>>> Function(List<String> texts)?
  embeddingForTexts;
  final void Function(HybridRetrievalDiagnostics diagnostics)? onDiagnostics;
  final SqliteWriteCoordinator writeCoordinator;

  /// Bounds prepared embeddings retained during bulk indexing and sync.
  static const int indexWriteBatchSize = SqliteVssStore.indexWriteBatchSize;

  /// Deterministic local fallback embedding for tests and offline indexing.
  static Future<List<double>> defaultEmbedding(String text) async {
    const dims = 64;
    final vector = List<double>.filled(dims, 0.0);
    for (final token in localEmbeddingTokens(text)) {
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
    final sqliteStore = vectorStore;
    if (sqliteStore is SqliteVssStore &&
        sqliteStore.usesDatabase(ftsStorage.db)) {
      await ftsStorage.ensureTables();
      final vectorBatches = await _prepareVectorBatches(chunks);
      await writeCoordinator.synchronized<void>((lease) async {
        ftsStorage.db.execute('SAVEPOINT hybrid_incremental_index');
        try {
          await _indexIntoFts(chunks, lease: lease);
          await _writeVectorBatches(sqliteStore, vectorBatches, lease: lease);
          ftsStorage.db.execute('RELEASE SAVEPOINT hybrid_incremental_index');
        } catch (_) {
          ftsStorage.db.execute(
            'ROLLBACK TO SAVEPOINT hybrid_incremental_index',
          );
          ftsStorage.db.execute('RELEASE SAVEPOINT hybrid_incremental_index');
          rethrow;
        }
      });
      return;
    }
    await Future.wait([
      _indexIntoFts(chunks),
      _indexIntoVectors(chunks, vectorStore),
    ]);
  }

  /// Replaces one producer-owned generation without touching other memories.
  ///
  /// The local production path requires FTS and vector storage to share one
  /// SQLite connection so deletion and insertion are atomic. Historical
  /// context-enrichment rows are removed only when their exact scope, empty
  /// producer, ID shape, and kind all agree.
  Future<void> replaceOwnedGeneration({
    required String projectId,
    required String scopeId,
    required String producer,
    required List<StoryMemoryChunk> chunks,
    bool includeLegacyContextRows = false,
  }) async {
    final prepared = await prepareOwnedGeneration(
      projectId: projectId,
      scopeId: scopeId,
      producer: producer,
      chunks: chunks,
      includeLegacyContextRows: includeLegacyContextRows,
    );
    await writeCoordinator.synchronized<void>((lease) {
      return commitOwnedGeneration(prepared, lease: lease);
    });
  }

  /// Validates and embeds an owned generation before acquiring the DB queue.
  Future<HybridOwnedGenerationWrite> prepareOwnedGeneration({
    required String projectId,
    required String scopeId,
    required String producer,
    required List<StoryMemoryChunk> chunks,
    bool includeLegacyContextRows = false,
  }) async {
    final normalizedProducer = producer.trim();
    if (normalizedProducer.isEmpty) {
      throw ArgumentError.value(producer, 'producer', 'must not be empty');
    }
    final ids = <String>{};
    for (final chunk in chunks) {
      if (chunk.projectId != projectId ||
          chunk.scopeId != scopeId ||
          chunk.producer != normalizedProducer ||
          !StoryMemoryIndexer.ownsGenerationChunkId(
            id: chunk.id,
            projectId: projectId,
            scopeId: scopeId,
            producer: normalizedProducer,
            kind: chunk.kind,
          ) ||
          !ids.add(chunk.id)) {
        throw StateError(
          'All chunks must have unique IDs in the canonical requested '
          'project, scope, producer, and kind namespace',
        );
      }
    }

    final sqliteStore = vectorStore;
    if (sqliteStore is! SqliteVssStore ||
        !sqliteStore.usesDatabase(ftsStorage.db)) {
      throw StateError(
        'Atomic owned-generation replacement requires FTS and vector storage '
        'to share the same SQLite database',
      );
    }

    await ftsStorage.ensureTables();
    return HybridOwnedGenerationWrite._(
      projectId: projectId,
      scopeId: scopeId,
      producer: normalizedProducer,
      chunks: List<StoryMemoryChunk>.unmodifiable(chunks),
      vectorBatches: await _prepareVectorBatches(chunks),
      includeLegacyContextRows: includeLegacyContextRows,
    );
  }

  /// Commits a prepared generation while holding [lease].
  Future<void> commitOwnedGeneration(
    HybridOwnedGenerationWrite prepared, {
    required SqliteWriteLease lease,
  }) => writeCoordinator.synchronized<void>((_) async {
    final sqliteStore = vectorStore;
    if (sqliteStore is! SqliteVssStore ||
        !sqliteStore.usesDatabase(ftsStorage.db)) {
      throw StateError(
        'Atomic owned-generation replacement requires FTS and vector storage '
        'to share the same SQLite database',
      );
    }
    await ftsStorage.ensureTables(lease: lease);
    final db = ftsStorage.db;
    for (final chunk in prepared.chunks) {
      if (_hasOwnedGenerationIndexCollision(
        db,
        id: chunk.id,
        projectId: prepared.projectId,
        scopeId: prepared.scopeId,
        producer: prepared.producer,
      )) {
        throw StateError(
          'Owned generation chunk ID ${chunk.id} is already used by another '
          'project, scope, or producer',
        );
      }
    }
    db.execute('SAVEPOINT hybrid_replace_owned_generation');
    try {
      final ownership = _ownedGenerationIndexIds(
        db,
        projectId: prepared.projectId,
        scopeId: prepared.scopeId,
        producer: prepared.producer,
        includeLegacyContextRows: prepared.includeLegacyContextRows,
      );
      for (final id in ownership.fts) {
        await ftsStorage.removeDocumentCoordinated(
          id,
          projectId: prepared.projectId,
          lease: lease,
        );
      }
      for (final id in ownership.vector) {
        await sqliteStore.deleteCoordinated(
          id,
          projectId: prepared.projectId,
          lease: lease,
        );
      }
      await _indexIntoFts(prepared.chunks, lease: lease);
      await _writeVectorBatches(
        sqliteStore,
        prepared.vectorBatches,
        lease: lease,
      );
      db.execute('RELEASE SAVEPOINT hybrid_replace_owned_generation');
    } catch (_) {
      db.execute('ROLLBACK TO SAVEPOINT hybrid_replace_owned_generation');
      db.execute('RELEASE SAVEPOINT hybrid_replace_owned_generation');
      rethrow;
    }
  }, lease: lease);

  /// Whether the production local stores share [database].
  bool usesDatabase(Database database) {
    final sqliteStore = vectorStore;
    return identical(ftsStorage.db, database) &&
        sqliteStore is SqliteVssStore &&
        sqliteStore.usesDatabase(database);
  }

  /// Prepares persistent index tables before a caller opens a wider savepoint.
  Future<void> prepareOwnedGenerationStorage() => ftsStorage.ensureTables();

  /// Replaces a project's hybrid index with parsed project materials.
  Future<void> syncProject({
    required String projectId,
    required List<String> characterProfiles,
    required List<String> outlineBeats,
    required List<String> worldFacts,
    List<String> chapterContents = const [],
  }) async {
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
    await _replaceProjectIndex(projectId, chunks);
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
    final requiredCanon = query.mustIncludeCanon || policy.mustIncludeCanon;
    final retrievalTiers = requiredCanon
        ? {...tierSet, MemoryTier.canon}
        : tierSet;
    final admission = _admissionFor(query, retrievalTiers);
    final strategy = policy.rankingStrategy;
    final embedding = strategy == RankingStrategy.keyword
        ? null
        : await embeddingForText(query.text);
    var candidateLimit = max(0, query.maxResults * 3);
    var cachedFtsHits = const <LocalRagFtsResult>[];
    var cachedVectorHits = const <VectorSearchHit>[];
    var ftsCanExpand = strategy != RankingStrategy.semantic;
    var vectorCanExpand = embedding != null;
    final candidateLimits = <int>[];
    var expansionRounds = 0;
    var ftsSearches = 0;
    var vectorSearches = 0;
    var nearDuplicateComparisons = 0;
    late _RankedCandidates ranked;

    while (true) {
      candidateLimits.add(candidateLimit);
      final byId = <String, _Candidate>{};

      if (ftsCanExpand) {
        ftsSearches++;
        cachedFtsHits = await ftsStorage.searchFts(
          projectId: query.projectId,
          query: query.text,
          limit: candidateLimit,
          admission: admission,
        );
        if (candidateLimit == 0 || cachedFtsHits.length < candidateLimit) {
          ftsCanExpand = false;
        }
      }
      for (final hit in cachedFtsHits) {
        final metadata = Map<String, dynamic>.from(hit.metadata);
        final tier = _parseTier(metadata['tier']);
        if (!retrievalTiers.contains(tier) || !_isAdmitted(metadata, query)) {
          continue;
        }
        byId[hit.path] = _Candidate(
          id: hit.path,
          content: hit.content,
          metadata: metadata,
          explicitTier: null,
          ftsScore: hit.score,
          vectorScore: 0.0,
        );
      }

      if (vectorCanExpand) {
        vectorSearches++;
        cachedVectorHits = vectorStore is SqliteVssStore
            ? (await (vectorStore as SqliteVssStore).searchDetailed(
                embedding: embedding!,
                projectId: query.projectId,
                tiers: retrievalTiers,
                limit: candidateLimit,
                admission: admission,
              )).hits
            : await vectorStore.search(
                embedding: embedding!,
                projectId: query.projectId,
                tiers: retrievalTiers,
                limit: candidateLimit,
              );
        if (candidateLimit == 0 || cachedVectorHits.length < candidateLimit) {
          vectorCanExpand = false;
        }
      }
      for (final hit in cachedVectorHits) {
        final metadata = Map<String, dynamic>.from(hit.metadata);
        if (metadata['projectId']?.toString() != query.projectId ||
            !_isAdmitted(metadata, query)) {
          continue;
        }
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

      if (requiredCanon) {
        final reservationSearches = await _addCanonReservationCandidates(
          byId: byId,
          query: query,
          strategy: strategy,
          embedding: embedding,
          candidateLimit: candidateLimit,
          admission: admission,
        );
        ftsSearches += reservationSearches.fts;
        vectorSearches += reservationSearches.vector;
      }
      ranked = _rankCandidates(
        byId.values,
        strategy,
        policy,
        queryType: query.queryType,
        representativeLimit: query.maxResults,
        boostTags: _stableUniqueStrings([
          for (final tag in [...query.tags, ...query.boostTags])
            if (tag.trim().isNotEmpty) tag.trim(),
        ]),
      );
      nearDuplicateComparisons += ranked.nearDuplicateComparisons;
      // Deferred near-duplicates are fallback material, not evidence that the
      // current window contains enough distinct facts. Mandatory canon is
      // deliberately part of this count because it consumes one result slot.
      final hasEnoughCandidates = ranked.preferredCount >= query.maxResults;
      if (hasEnoughCandidates ||
          (!ftsCanExpand && !vectorCanExpand) ||
          expansionRounds >= _maxAdaptiveExpansionRounds) {
        break;
      }
      expansionRounds++;
      candidateLimit *= 2;
    }
    final reranked = ranked.hits;

    final hits = <StoryMemoryHit>[];
    final mandatoryCanon = requiredCanon
        ? reranked
              .where(
                (hit) =>
                    _reconstructChunk(hit.candidate).tier == MemoryTier.canon,
              )
              .firstOrNull
        : null;
    var deferred = 0;
    var spent = 0;
    if (mandatoryCanon != null) {
      final canon = _reconstructChunk(mandatoryCanon.candidate);
      final canonCost = _promptInjectionTokenEstimate(canon, query.text);
      if (query.maxResults <= 0 || canonCost > query.tokenBudget) {
        final pack = StoryRetrievalPack(
          query: query,
          hits: const [],
          sourceRefs: const [],
          tokenBudget: query.tokenBudget,
          deferredHitCount: reranked.length,
          canonRequired: requiredCanon,
          canonAvailable: true,
        );
        onDiagnostics?.call(
          HybridRetrievalDiagnostics(
            expansionRounds: expansionRounds,
            candidateLimits: candidateLimits,
            ftsSearches: ftsSearches,
            vectorSearches: vectorSearches,
            nearDuplicateComparisons: nearDuplicateComparisons,
          ),
        );
        return pack;
      }
      hits.add(StoryMemoryHit(chunk: canon, score: mandatoryCanon.score));
      spent = canonCost;
    }
    final selectedOrder = [
      for (final hit in reranked)
        if (!identical(hit, mandatoryCanon)) hit,
    ];
    for (final scoredHit in selectedOrder) {
      final chunk = _reconstructChunk(scoredHit.candidate);
      final cost = _promptInjectionTokenEstimate(chunk, query.text);
      if (hits.length >= query.maxResults) {
        deferred++;
        continue;
      }
      if (spent + cost > query.tokenBudget) {
        deferred++;
        continue;
      }
      hits.add(StoryMemoryHit(chunk: chunk, score: scoredHit.score));
      spent += cost;
    }

    final sourceRefs = _stableUniqueSourceRefs([
      for (final hit in hits) ...hit.chunk.sourceRefs,
    ]);

    final pack = StoryRetrievalPack(
      query: query,
      hits: List.unmodifiable(hits),
      sourceRefs: sourceRefs,
      summary: _buildSummary(hits),
      tokenBudget: query.tokenBudget,
      spentTokenEstimate: spent,
      deferredHitCount: deferred,
      canonRequired: requiredCanon,
      canonAvailable: mandatoryCanon != null,
    );
    onDiagnostics?.call(
      HybridRetrievalDiagnostics(
        expansionRounds: expansionRounds,
        candidateLimits: candidateLimits,
        ftsSearches: ftsSearches,
        vectorSearches: vectorSearches,
        nearDuplicateComparisons: nearDuplicateComparisons,
      ),
    );
    return pack;
  }

  Future<void> _indexIntoFts(
    List<StoryMemoryChunk> chunks, {
    SqliteWriteLease? lease,
  }) async {
    for (final chunk in chunks) {
      await ftsStorage.indexDocumentCoordinated(
        projectId: chunk.projectId,
        path: chunk.id,
        content: chunk.content,
        category: chunk.kind.name,
        metadata: _chunkMetadata(chunk),
        lease: lease,
      );
    }
  }

  Future<List<List<VectorStoreEntry>>> _prepareVectorBatches(
    List<StoryMemoryChunk> chunks,
  ) async {
    final batches = <List<VectorStoreEntry>>[];
    for (
      var offset = 0;
      offset < chunks.length;
      offset += indexWriteBatchSize
    ) {
      final batchChunks = chunks.sublist(
        offset,
        min(chunks.length, offset + indexWriteBatchSize),
      );
      final batchEmbedding = embeddingForTexts;
      final embeddings = batchEmbedding == null
          ? await Future.wait([
              for (final chunk in batchChunks) embeddingForText(chunk.content),
            ])
          : await batchEmbedding([
              for (final chunk in batchChunks) chunk.content,
            ]);
      if (embeddings.length != batchChunks.length) {
        throw StateError(
          'Embedding batch returned ${embeddings.length} vectors for '
          '${batchChunks.length} chunks',
        );
      }
      batches.add([
        for (var index = 0; index < batchChunks.length; index++)
          VectorStoreEntry(
            id: batchChunks[index].id,
            projectId: batchChunks[index].projectId,
            content: batchChunks[index].content,
            embedding: embeddings[index],
            tier: batchChunks[index].tier,
            metadata: _chunkMetadata(batchChunks[index]),
          ),
      ]);
    }
    return batches;
  }

  static Future<void> _writeVectorBatches(
    SqliteVssStore store,
    List<List<VectorStoreEntry>> batches, {
    required SqliteWriteLease lease,
  }) async {
    for (final entries in batches) {
      await store.upsertAllCoordinated(entries, lease: lease);
    }
  }

  Future<void> _indexIntoVectors(
    List<StoryMemoryChunk> chunks,
    VectorStore store,
  ) async {
    var entries = <VectorStoreEntry>[];
    for (final chunk in chunks) {
      entries.add(
        VectorStoreEntry(
          id: chunk.id,
          projectId: chunk.projectId,
          content: chunk.content,
          embedding: await embeddingForText(chunk.content),
          tier: chunk.tier,
          metadata: _chunkMetadata(chunk),
        ),
      );
      if (entries.length == indexWriteBatchSize) {
        await store.upsertAll(entries);
        entries = <VectorStoreEntry>[];
      }
    }
    if (entries.isNotEmpty) await store.upsertAll(entries);
  }

  Future<void> _replaceProjectIndex(
    String projectId,
    List<StoryMemoryChunk> chunks,
  ) async {
    final sqliteStore = vectorStore;
    if (sqliteStore is SqliteVssStore &&
        sqliteStore.usesDatabase(ftsStorage.db)) {
      await ftsStorage.ensureTables();
      final vectorBatches = await _prepareVectorBatches(chunks);
      await writeCoordinator.synchronized<void>((lease) async {
        ftsStorage.db.execute('SAVEPOINT hybrid_project_replace');
        try {
          await ftsStorage.clearProjectCoordinated(projectId, lease: lease);
          await _indexIntoFts(chunks, lease: lease);
          await sqliteStore.clearProjectCoordinated(projectId, lease: lease);
          await _writeVectorBatches(sqliteStore, vectorBatches, lease: lease);
          ftsStorage.db.execute('RELEASE SAVEPOINT hybrid_project_replace');
        } catch (_) {
          ftsStorage.db.execute('ROLLBACK TO SAVEPOINT hybrid_project_replace');
          ftsStorage.db.execute('RELEASE SAVEPOINT hybrid_project_replace');
          rethrow;
        }
      });
      return;
    }

    throw StateError(
      'Atomic project replacement requires FTS and vector storage to share '
      'the same SQLite database',
    );
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
    'ownerId': chunk.ownerId,
    'tags': chunk.tags,
    'priority': chunk.priority,
    'tokenCostEstimate': chunk.tokenCostEstimate,
    'createdAtMs': chunk.createdAtMs,
  };

  static bool _hasOwnedGenerationIndexCollision(
    Database db, {
    required String id,
    required String projectId,
    required String scopeId,
    required String producer,
  }) {
    final ftsRows = db.select(
      'SELECT project_id, scope_id, metadata FROM rag_documents WHERE path = ?',
      [id],
    );
    for (final row in ftsRows) {
      final metadata = _decodeMetadata(row['metadata']);
      if (row['project_id']?.toString() != projectId ||
          row['scope_id']?.toString() != scopeId ||
          metadata['producer']?.toString().trim() != producer) {
        return true;
      }
    }

    final vectorRows = db.select(
      'SELECT project_id, scope_id, metadata_json FROM $vectorEmbeddingsTable '
      'WHERE id = ?',
      [id],
    );
    for (final row in vectorRows) {
      final metadata = _decodeMetadata(row['metadata_json']);
      if (row['project_id']?.toString() != projectId ||
          row['scope_id']?.toString() != scopeId ||
          metadata['producer']?.toString().trim() != producer) {
        return true;
      }
    }
    return false;
  }

  static ({Set<String> fts, Set<String> vector}) _ownedGenerationIndexIds(
    Database db, {
    required String projectId,
    required String scopeId,
    required String producer,
    required bool includeLegacyContextRows,
  }) {
    final ftsOwned = <String>{};
    final vectorOwned = <String>{};
    final ftsState =
        <
          String,
          ({
            String scopeId,
            String ownerId,
            String producer,
            String kind,
            String tier,
            String visibility,
            bool owned,
          })
        >{};
    final vectorState =
        <
          String,
          ({
            String scopeId,
            String ownerId,
            String producer,
            String kind,
            String tier,
            String visibility,
            bool owned,
          })
        >{};
    final ftsRows = db.select(
      'SELECT path, category, tier, visibility, scope_id, owner_id, metadata '
      'FROM rag_documents WHERE project_id = ?',
      [projectId],
    );
    for (final row in ftsRows) {
      final metadata = _decodeMetadata(row['metadata']);
      final id = row['path'] as String;
      final rowScopeId = row['scope_id']?.toString() ?? '';
      final ownerId = row['owner_id']?.toString().trim() ?? '';
      final rowProducer = metadata['producer']?.toString().trim() ?? '';
      final kind = metadata['kind']?.toString() ?? row['category']?.toString();
      final owned =
          rowScopeId == scopeId &&
          _ownsGenerationIndexRow(
            id: id,
            kind: kind,
            metadata: metadata,
            projectId: projectId,
            producer: producer,
            includeLegacyContextRows: includeLegacyContextRows,
          );
      ftsState[id] = (
        scopeId: rowScopeId,
        ownerId: ownerId,
        producer: rowProducer,
        kind: kind ?? '',
        tier: row['tier']?.toString() ?? '',
        visibility: row['visibility']?.toString() ?? '',
        owned: owned,
      );
      if (owned) {
        ftsOwned.add(id);
      }
    }

    final vectorRows = db.select(
      'SELECT id, tier, visibility, scope_id, owner_id, metadata_json '
      'FROM $vectorEmbeddingsTable WHERE project_id = ?',
      [projectId],
    );
    for (final row in vectorRows) {
      final metadata = _decodeMetadata(row['metadata_json']);
      final id = row['id'] as String;
      final rowScopeId = row['scope_id']?.toString() ?? '';
      final ownerId = row['owner_id']?.toString().trim() ?? '';
      final rowProducer = metadata['producer']?.toString().trim() ?? '';
      final kind = metadata['kind']?.toString() ?? '';
      final owned =
          rowScopeId == scopeId &&
          _ownsGenerationIndexRow(
            id: id,
            kind: kind,
            metadata: metadata,
            projectId: projectId,
            producer: producer,
            includeLegacyContextRows: includeLegacyContextRows,
          );
      vectorState[id] = (
        scopeId: rowScopeId,
        ownerId: ownerId,
        producer: rowProducer,
        kind: kind,
        tier: row['tier']?.toString() ?? '',
        visibility: row['visibility']?.toString() ?? '',
        owned: owned,
      );
      if (owned) {
        vectorOwned.add(id);
      }
    }
    final sharedIds = ftsState.keys.toSet().intersection(
      vectorState.keys.toSet(),
    );
    for (final id in sharedIds) {
      final fts = ftsState[id]!;
      final vector = vectorState[id]!;
      if (fts.scopeId != vector.scopeId ||
          fts.ownerId != vector.ownerId ||
          fts.producer != vector.producer ||
          fts.kind != vector.kind ||
          fts.tier != vector.tier ||
          fts.visibility != vector.visibility ||
          fts.owned != vector.owned) {
        throw StateError(
          'Owned generation index drift for $id: FTS and vector ownership '
          'metadata disagree',
        );
      }
    }
    return (fts: ftsOwned, vector: vectorOwned);
  }

  static bool _ownsGenerationIndexRow({
    required String id,
    required String? kind,
    required Map<String, Object?> metadata,
    required String projectId,
    required String producer,
    required bool includeLegacyContextRows,
  }) {
    final rowProducer = metadata['producer']?.toString().trim() ?? '';
    if (rowProducer == producer) return true;
    if (!includeLegacyContextRows || rowProducer.isNotEmpty || kind == null) {
      return false;
    }
    return _isLegacyContextIndexId(id, projectId, kind);
  }

  static bool _isLegacyContextIndexId(
    String id,
    String projectId,
    String kind,
  ) {
    final code = switch (_kindByName[kind]) {
      MemorySourceKind.worldFact => 'wf',
      MemorySourceKind.characterProfile => 'cp',
      MemorySourceKind.relationshipHint => 'rh',
      MemorySourceKind.outlineBeat => 'ob',
      MemorySourceKind.sceneSummary => 'ss',
      MemorySourceKind.acceptedState => 'as',
      MemorySourceKind.reviewFinding => 'rf',
      MemorySourceKind.draft || null => null,
    };
    if (code == null) return false;
    return RegExp('^${RegExp.escape(projectId)}_${code}_[0-9]+\$').hasMatch(id);
  }

  static Map<String, Object?> _decodeMetadata(Object? raw) {
    if (raw is! String || raw.isEmpty) return const {};
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return const {};
      return {
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
    } on FormatException {
      return const {};
    }
  }

  static Set<MemoryTier> _effectiveTierSet(RagRetrievalPolicy policy) {
    final tiers = policy.allowedTiers.toSet();
    if (policy.excludeDraftTier) tiers.remove(MemoryTier.draft);
    return tiers;
  }

  static RagAdmission _admissionFor(
    StoryMemoryQuery query,
    Set<MemoryTier> tiers,
  ) {
    final scopes = <String>{
      if (query.scopeId?.trim().isNotEmpty == true) query.scopeId!.trim(),
      for (final scope in query.allowedAncestorScopeIds)
        if (scope.trim().isNotEmpty) scope.trim(),
    };
    return RagAdmission(
      allowedTiers: tiers,
      viewerId: query.viewerId,
      viewerRole: query.viewerRole,
      allowedScopeIds: scopes.toList(growable: false),
      requiredTagGroups: normalizeRequiredTagGroups(query.requiredTagGroups),
    );
  }

  static bool _isAdmitted(
    Map<String, dynamic> metadata,
    StoryMemoryQuery query,
  ) {
    final visibility = _parseVisibility(metadata['visibility']);
    if (visibility == MemoryVisibility.agentPrivate) {
      final ownerId = metadata['ownerId']?.toString().trim() ?? '';
      final viewerId = query.viewerId?.trim() ?? '';
      if (ownerId.isEmpty || viewerId.isEmpty || ownerId != viewerId) {
        return false;
      }
    }
    if (visibility == MemoryVisibility.editorOnly &&
        query.viewerRole != MemoryViewerRole.editor) {
      return false;
    }
    final allowedScopes = <String>{
      if (query.scopeId?.trim().isNotEmpty == true) query.scopeId!.trim(),
      for (final scope in query.allowedAncestorScopeIds)
        if (scope.trim().isNotEmpty) scope.trim(),
    };
    if (allowedScopes.isNotEmpty &&
        !allowedScopes.contains(metadata['scopeId']?.toString())) {
      return false;
    }
    final tags = _stringList(
      metadata['tags'],
    ).map((tag) => tag.trim()).where(_nonEmpty).toSet();
    for (final group in normalizeRequiredTagGroups(query.requiredTagGroups)) {
      if (group.every((tag) => !tags.contains(tag))) {
        return false;
      }
    }
    return true;
  }

  Future<({int fts, int vector})> _addCanonReservationCandidates({
    required Map<String, _Candidate> byId,
    required StoryMemoryQuery query,
    required RankingStrategy strategy,
    required List<double>? embedding,
    required int candidateLimit,
    required RagAdmission admission,
  }) async {
    var ftsSearches = 0;
    var vectorSearches = 0;
    final canonAdmission = RagAdmission(
      allowedTiers: const {MemoryTier.canon},
      viewerId: admission.viewerId,
      viewerRole: admission.viewerRole,
      allowedScopeIds: admission.allowedScopeIds,
      requiredTagGroups: admission.requiredTagGroups,
    );
    if (strategy != RankingStrategy.semantic) {
      ftsSearches++;
      final ftsHits = await ftsStorage.searchFts(
        projectId: query.projectId,
        query: query.text,
        limit: max(1, candidateLimit),
        admission: canonAdmission,
      );
      for (final hit in ftsHits) {
        final metadata = Map<String, dynamic>.from(hit.metadata);
        if (!_isAdmitted(metadata, query)) continue;
        final existing = byId[hit.path];
        byId[hit.path] =
            existing?.copyWith(ftsScore: hit.score) ??
            _Candidate(
              id: hit.path,
              content: hit.content,
              metadata: metadata,
              explicitTier: MemoryTier.canon,
              ftsScore: hit.score,
              vectorScore: 0,
            );
      }
    }
    if (embedding != null) {
      vectorSearches++;
      final hits = vectorStore is SqliteVssStore
          ? (await (vectorStore as SqliteVssStore).searchDetailed(
              embedding: embedding,
              projectId: query.projectId,
              tiers: const {MemoryTier.canon},
              limit: max(1, candidateLimit),
              admission: canonAdmission,
            )).hits
          : await vectorStore.search(
              embedding: embedding,
              projectId: query.projectId,
              tiers: const {MemoryTier.canon},
              limit: max(1, candidateLimit),
            );
      for (final hit in hits) {
        final metadata = Map<String, dynamic>.from(hit.metadata);
        if (!_isAdmitted(metadata, query)) continue;
        final existing = byId[hit.id];
        byId[hit.id] =
            existing?.copyWith(vectorScore: hit.score) ??
            _Candidate(
              id: hit.id,
              content: hit.content,
              metadata: metadata,
              explicitTier: MemoryTier.canon,
              ftsScore: 0,
              vectorScore: hit.score,
            );
      }
    }
    return (fts: ftsSearches, vector: vectorSearches);
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
      ownerId: metadata['ownerId']?.toString() ?? '',
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

  static int _promptInjectionTokenEstimate(
    StoryMemoryChunk chunk,
    String query,
  ) {
    if (chunk.content.runes.length <= RagSceneContext._promptExcerptMaxRunes) {
      return _tokenEstimate(chunk);
    }
    final excerpt = RagSceneContext._queryAwareExcerpt(
      chunk.content,
      query,
      maxRunes: RagSceneContext._promptExcerptMaxRunes,
    );
    return (excerpt.runes.length / 4).ceil();
  }

  static _RankedCandidates _rankCandidates(
    Iterable<_Candidate> candidates,
    RankingStrategy strategy,
    RagRetrievalPolicy policy, {
    required StoryMemoryQueryType queryType,
    required int representativeLimit,
    List<String> boostTags = const [],
  }) {
    final scored = <_Scored>[];
    for (final candidate in candidates) {
      final score = switch (strategy) {
        RankingStrategy.keyword => candidate.ftsScore,
        RankingStrategy.semantic => candidate.vectorScore,
        RankingStrategy.hybrid =>
          candidate.ftsScore * policy.keywordWeight +
              candidate.vectorScore * policy.semanticWeight,
      };
      if (score <= 0) continue;
      final boosts = boostTags
          .where(_nonEmpty)
          .where(_stringList(candidate.metadata['tags']).contains)
          .length;
      final priority = _parseInt(candidate.metadata['priority']).clamp(0, 10);
      final kind = _parseKind(candidate.metadata['kind']);
      final intentBoost = _preferredKinds(queryType).contains(kind) ? 0.05 : 0;
      final boostedScore =
          score + boosts * 0.05 + priority * 0.01 + intentBoost;
      scored.add(_Scored(candidate: candidate, score: boostedScore));
    }
    scored.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      return scoreOrder != 0
          ? scoreOrder
          : a.candidate.id.compareTo(b.candidate.id);
    });
    return _rerankNearDuplicates(
      _deduplicateExactContent(scored),
      representativeLimit: representativeLimit,
    );
  }

  static List<_Scored> _deduplicateExactContent(List<_Scored> scored) {
    final representativeByContent = <String, int>{};
    final deduplicated = <_Scored>[];
    for (final scoredHit in scored) {
      final contentKey = _exactDedupeKey(scoredHit.candidate);
      final representativeIndex = representativeByContent[contentKey];
      if (representativeIndex == null) {
        representativeByContent[contentKey] = deduplicated.length;
        deduplicated.add(scoredHit);
        continue;
      }

      deduplicated[representativeIndex] = _mergeExactDuplicate(
        deduplicated[representativeIndex],
        scoredHit,
      );
    }
    return deduplicated;
  }

  static _Scored _mergeExactDuplicate(
    _Scored representative,
    _Scored duplicate,
  ) {
    final representativeChunk = _reconstructChunk(representative.candidate);
    final duplicateChunk = _reconstructChunk(duplicate.candidate);
    final metadata =
        Map<String, dynamic>.from(representative.candidate.metadata)
          ..['sourceRefs'] = [
            for (final ref in _stableUniqueSourceRefs([
              ...representativeChunk.sourceRefs,
              ...duplicateChunk.sourceRefs,
            ]))
              ref.toJson(),
          ]
          ..['rootSourceIds'] = _stableUniqueStrings([
            ...representativeChunk.rootSourceIds,
            ...duplicateChunk.rootSourceIds,
          ])
          ..['tags'] = _stableUniqueStrings([
            ...representativeChunk.tags,
            ...duplicateChunk.tags,
          ]);

    return _Scored(
      candidate: _Candidate(
        id: representative.candidate.id,
        content: representative.candidate.content,
        metadata: metadata,
        explicitTier: representative.candidate.explicitTier,
        ftsScore: representative.candidate.ftsScore,
        vectorScore: representative.candidate.vectorScore,
      ),
      score: representative.score,
    );
  }

  static _RankedCandidates _rerankNearDuplicates(
    List<_Scored> scored, {
    required int representativeLimit,
  }) {
    const nearDuplicateThreshold = 0.85;
    final prioritized = <_Scored>[];
    final deferred = <_Scored>[];
    final prioritizedChunks = <StoryMemoryChunk>[];
    final prioritizedFeatures = <Set<String>>[];
    var comparisons = 0;

    for (final scoredHit in scored) {
      final chunk = _reconstructChunk(scoredHit.candidate);
      final features = _orderedLocalFeatures(chunk.content);
      var isNearDuplicate = false;
      for (var i = 0; i < prioritizedChunks.length; i++) {
        comparisons++;
        final selected = prioritizedChunks[i];
        if (!_sameRetrievalBoundary(selected, chunk)) {
          continue;
        }
        if (_jaccard(features, prioritizedFeatures[i]) >=
            nearDuplicateThreshold) {
          isNearDuplicate = true;
          break;
        }
      }

      if (isNearDuplicate) {
        deferred.add(scoredHit);
      } else {
        prioritized.add(scoredHit);
        if (prioritizedChunks.length < representativeLimit) {
          prioritizedChunks.add(chunk);
          prioritizedFeatures.add(features);
        }
      }
    }
    return _RankedCandidates(
      hits: [...prioritized, ...deferred],
      preferredCount: prioritized.length,
      nearDuplicateComparisons: comparisons,
    );
  }

  static Set<String> _orderedLocalFeatures(String content) {
    final tokens = localEmbeddingTokens(content);
    final features = <String>{};
    if (tokens.length < 2) {
      for (final token in tokens) {
        features.add('token\u0000$token');
      }
      return features;
    }
    for (var i = 0; i + 1 < tokens.length; i++) {
      features.add('${tokens[i]}\u0000${tokens[i + 1]}');
    }
    return features;
  }

  static String _normalizeContent(String content) =>
      content.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _exactDedupeKey(_Candidate candidate) {
    final chunk = _reconstructChunk(candidate);
    return '${_retrievalBoundaryKey(chunk)}\u0000'
        '${_normalizeContent(chunk.content)}';
  }

  static bool _sameRetrievalBoundary(
    StoryMemoryChunk first,
    StoryMemoryChunk second,
  ) =>
      first.visibility == second.visibility &&
      first.ownerId.trim() == second.ownerId.trim() &&
      first.scopeId.trim() == second.scopeId.trim() &&
      first.tier == second.tier &&
      first.kind == second.kind;

  static String _retrievalBoundaryKey(StoryMemoryChunk chunk) =>
      '${chunk.visibility.name}\u0000${chunk.ownerId.trim()}\u0000'
      '${chunk.scopeId.trim()}\u0000${chunk.tier.name}\u0000${chunk.kind.name}';

  static Set<MemorySourceKind> _preferredKinds(
    StoryMemoryQueryType queryType,
  ) => switch (queryType) {
    StoryMemoryQueryType.concreteFact => const {
      MemorySourceKind.worldFact,
      MemorySourceKind.acceptedState,
    },
    StoryMemoryQueryType.sceneContinuity => const {
      MemorySourceKind.outlineBeat,
      MemorySourceKind.sceneSummary,
      MemorySourceKind.acceptedState,
    },
    StoryMemoryQueryType.persona => const {
      MemorySourceKind.characterProfile,
      MemorySourceKind.relationshipHint,
    },
    StoryMemoryQueryType.causality => const {
      MemorySourceKind.outlineBeat,
      MemorySourceKind.sceneSummary,
      MemorySourceKind.acceptedState,
    },
    StoryMemoryQueryType.foreshadowing => const {MemorySourceKind.outlineBeat},
    StoryMemoryQueryType.style => const {
      MemorySourceKind.sceneSummary,
      MemorySourceKind.reviewFinding,
    },
  };

  static List<MemorySourceRef> _stableUniqueSourceRefs(
    Iterable<MemorySourceRef> refs,
  ) {
    final seen = <String>{};
    final unique = <MemorySourceRef>[];
    for (final ref in refs) {
      final key = '${ref.sourceType.name}\u0000${ref.sourceId}';
      if (seen.add(key)) unique.add(ref);
    }
    return unique;
  }

  static List<String> _stableUniqueStrings(Iterable<String> values) {
    final seen = <String>{};
    final unique = <String>[];
    for (final value in values) {
      if (seen.add(value)) unique.add(value);
    }
    return unique;
  }

  static double _jaccard(Set<String> first, Set<String> second) {
    if (first.isEmpty && second.isEmpty) return 1.0;
    if (first.isEmpty || second.isEmpty) return 0.0;
    var intersection = 0;
    for (final token in first) {
      if (second.contains(token)) intersection++;
    }
    final union = first.length + second.length - intersection;
    return union == 0 ? 0.0 : intersection / union;
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

  static bool _nonEmpty(String value) => value.trim().isNotEmpty;

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

  _Candidate copyWith({double? ftsScore, double? vectorScore}) => _Candidate(
    id: id,
    content: content,
    metadata: metadata,
    explicitTier: explicitTier,
    ftsScore: ftsScore ?? this.ftsScore,
    vectorScore: vectorScore ?? this.vectorScore,
  );
}

class _Scored {
  const _Scored({required this.candidate, required this.score});

  final _Candidate candidate;
  final double score;
}

class _RankedCandidates {
  const _RankedCandidates({
    required this.hits,
    required this.preferredCount,
    required this.nearDuplicateComparisons,
  });

  final List<_Scored> hits;
  final int preferredCount;
  final int nearDuplicateComparisons;
}
