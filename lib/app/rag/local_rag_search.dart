import 'dart:math';
import 'dart:typed_data';

import '../../features/story_generation/data/story_embedding_provider.dart';
import 'local_rag_storage.dart';

/// Configuration for the local RAG search engine.
class LocalRagSearchConfig {
  const LocalRagSearchConfig({
    this.bm25Weight = 0.4,
    this.semanticWeight = 0.6,
    this.scoreThreshold = 0.3,
    this.defaultLimit = 10,
  });

  final double bm25Weight;
  final double semanticWeight;
  final double scoreThreshold;
  final int defaultLimit;
}

/// Hybrid search engine combining BM25 full-text search with optional
/// semantic cosine similarity via embeddings.
///
/// When embeddings are available, uses Reciprocal Rank Fusion (RRF) to
/// combine lexical and semantic scores. Falls back to pure BM25 otherwise.
class LocalRagSearchEngine {
  LocalRagSearchEngine({
    required this.storage,
    this.embeddingProvider,
    this.config = const LocalRagSearchConfig(),
  });

  final LocalRagStorage storage;
  final StoryEmbeddingProvider? embeddingProvider;
  final LocalRagSearchConfig config;

  /// Executes a hybrid search for documents matching [query] within [projectId].
  Future<List<LocalRagSearchResult>> search({
    required String projectId,
    required String query,
    List<String>? categories,
    int? limit,
    double? scoreThreshold,
  }) async {
    final effectiveLimit = limit ?? config.defaultLimit;
    final effectiveThreshold = scoreThreshold ?? config.scoreThreshold;

    if (embeddingProvider != null) {
      return _hybridSearch(
        projectId: projectId,
        query: query,
        categories: categories,
        limit: effectiveLimit,
        scoreThreshold: effectiveThreshold,
      );
    }
    return _bm25OnlySearch(
      projectId: projectId,
      query: query,
      categories: categories,
      limit: effectiveLimit,
      scoreThreshold: effectiveThreshold,
    );
  }

  /// Pure BM25 full-text search via FTS5.
  Future<List<LocalRagSearchResult>> _bm25OnlySearch({
    required String projectId,
    required String query,
    required int limit,
    required double scoreThreshold,
    List<String>? categories,
  }) async {
    if (categories != null && categories.length == 1) {
      final results = await storage.searchFts(
        projectId: projectId,
        query: query,
        limit: limit,
        category: categories.first,
      );
      return results.where((r) => r.score >= scoreThreshold).toList();
    }

    // Multi-category or no category: search across all, then merge
    if (categories != null && categories.length > 1) {
      final allResults = <LocalRagSearchResult>[];
      for (final cat in categories) {
        final catResults = await storage.searchFts(
          projectId: projectId,
          query: query,
          limit: limit,
          category: cat,
        );
        allResults.addAll(catResults);
      }
      allResults.sort((a, b) => b.score.compareTo(a.score));
      return _deduplicate(allResults)
          .where((r) => r.score >= scoreThreshold)
          .take(limit)
          .toList();
    }

    final results = await storage.searchFts(
      projectId: projectId,
      query: query,
      limit: limit,
    );
    return results.where((r) => r.score >= scoreThreshold).toList();
  }

  /// Hybrid BM25 + semantic search with RRF fusion.
  Future<List<LocalRagSearchResult>> _hybridSearch({
    required String projectId,
    required String query,
    required int limit,
    required double scoreThreshold,
    List<String>? categories,
  }) async {
    // Step 1: Get BM25 results (fetch more for re-ranking)
    final bm25Results = await _bm25OnlySearch(
      projectId: projectId,
      query: query,
      limit: limit * 3,
      scoreThreshold: 0.0, // Lower threshold for initial retrieval
      categories: categories,
    );

    if (bm25Results.isEmpty) return [];

    // Step 2: Compute query embedding
    final List<double> queryEmbedding;
    try {
      queryEmbedding = await embeddingProvider!.embedText(query);
    } on Object {
      // Fallback to BM25 if embedding fails
      return bm25Results.take(limit).toList();
    }

    // Step 3: Load stored embeddings for the results
    final rowids = await _findRowids(projectId, categories);
    final storedEmbeddings = await storage.loadEmbeddings(rowids);

    // Step 4: Get path→rowid mapping
    final pathToRowid = await _pathToRowidMap(projectId, categories);

    // Step 5: Compute semantic scores via cosine similarity
    final semanticScores = <String, double>{};
    for (final result in bm25Results) {
      final rowid = pathToRowid[result.path];
      if (rowid == null) continue;
      final docEmbedding = storedEmbeddings[rowid];
      if (docEmbedding == null) continue;
      semanticScores[result.path] = _cosineSimilarity(
        queryEmbedding,
        docEmbedding,
      );
    }

    // Step 6: If no embeddings found for any result, embed content on-the-fly
    if (semanticScores.isEmpty && bm25Results.isNotEmpty) {
      try {
        final contents = bm25Results.map((r) => r.content).toList();
        final docEmbeddings = await embeddingProvider!.embedBatch(contents);
        for (var i = 0; i < bm25Results.length; i++) {
          semanticScores[bm25Results[i].path] = _cosineSimilarity(
            queryEmbedding,
            docEmbeddings[i],
          );
          // Store the embedding for future use
          final rowid = pathToRowid[bm25Results[i].path];
          if (rowid != null) {
            final emb = docEmbeddings[i];
            await storage.storeEmbedding(
              rowid,
              Float64List.fromList(emb),
            );
          }
        }
      } on Object {
        // If batch embedding fails, fall back to BM25
        return bm25Results.take(limit).toList();
      }
    }

    // Step 7: RRF fusion — combine BM25 rank and semantic rank
    final combined = <_ScoredResult>[];
    final bm25Ranked = _sortByScore(bm25Results);
    final semanticRanked = _sortByPathScore(semanticScores);

    for (final result in bm25Results) {
      final bm25Rank = bm25Ranked.indexOf(result.path) + 1;
      final semRank = semanticRanked.indexOf(result.path) + 1;

      // RRF score: 1/(k + rank) for each signal
      const k = 60; // Standard RRF constant
      final rrfScore = config.bm25Weight / (k + bm25Rank) +
          config.semanticWeight / (k + semRank);

      combined.add(_ScoredResult(
        result: result,
        combinedScore: rrfScore,
      ));
    }

    combined.sort((a, b) => b.combinedScore.compareTo(a.combinedScore));

    return combined
        .where((c) => c.combinedScore >= scoreThreshold * 0.1) // RRF scores are small
        .take(limit)
        .map((c) => LocalRagSearchResult(
              path: c.result.path,
              content: c.result.content,
              score: c.combinedScore,
              metadata: c.result.metadata,
            ))
        .toList();
  }

  List<String> _sortByScore(List<LocalRagSearchResult> results) {
    final sorted = List<LocalRagSearchResult>.from(results)
      ..sort((a, b) => b.score.compareTo(a.score));
    return sorted.map((r) => r.path).toList();
  }

  List<String> _sortByPathScore(Map<String, double> scores) {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  Future<List<int>> _findRowids(
    String projectId,
    List<String>? categories,
  ) async {
    if (categories == null || categories.isEmpty) {
      return storage.rowidsForProject(projectId);
    }
    final all = <int>[];
    for (final cat in categories) {
      all.addAll(await storage.rowidsForProject(projectId, category: cat));
    }
    return all;
  }

  Future<Map<String, int>> _pathToRowidMap(
    String projectId,
    List<String>? categories,
  ) async {
    final rowids = await _findRowids(projectId, categories);
    if (rowids.isEmpty) return {};
    final placeholders = rowids.map((_) => '?').join(',');
    final rows = storage.db.select(
      'SELECT rowid, path FROM rag_documents WHERE rowid IN ($placeholders)',
      rowids,
    );
    return {
      for (final row in rows)
        row['path'] as String: row['rowid'] as int,
    };
  }

  List<LocalRagSearchResult> _deduplicate(
    List<LocalRagSearchResult> results,
  ) {
    final seen = <String>{};
    return [
      for (final r in results)
        if (seen.add(r.path)) r,
    ];
  }

  /// Cosine similarity between two equal-length vectors.
  static double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    if (magA == 0 || magB == 0) return 0.0;
    return dot / (sqrt(magA) * sqrt(magB));
  }
}

class _ScoredResult {
  const _ScoredResult({
    required this.result,
    required this.combinedScore,
  });

  final LocalRagSearchResult result;
  final double combinedScore;
}
