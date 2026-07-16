import 'dart:math';

import '../../features/story_generation/domain/contracts/memory_policy.dart';
import '../../features/story_generation/domain/memory_models.dart';

/// A single hit from a vector similarity search.
class VectorSearchHit {
  const VectorSearchHit({
    required this.id,
    required this.score,
    required this.content,
    required this.tier,
    this.metadata = const {},
  });

  final String id;
  final double score;
  final String content;
  final MemoryTier tier;
  final Map<String, dynamic> metadata;
}

/// One vector record prepared for a batched store write.
class VectorStoreEntry {
  const VectorStoreEntry({
    required this.id,
    required this.projectId,
    required this.content,
    required this.embedding,
    required this.tier,
    this.metadata = const {},
  });

  final String id;
  final String projectId;
  final String content;
  final List<double> embedding;
  final MemoryTier tier;
  final Map<String, dynamic> metadata;
}

/// Per-query evidence about how much of the vector corpus was inspected.
class VectorSearchDiagnostics {
  const VectorSearchDiagnostics({
    required this.totalRows,
    required this.eligibleRows,
    required this.candidateRows,
    required this.decodedRows,
    required this.scoredRows,
    required this.candidateLimit,
    required this.probeCount,
    required this.usedFullScan,
  });

  final int totalRows;
  final int eligibleRows;
  final int candidateRows;
  final int decodedRows;
  final int scoredRows;
  final int candidateLimit;
  final int probeCount;
  final bool usedFullScan;
}

/// Immutable vector-search response containing hits and query diagnostics.
class VectorSearchResult {
  VectorSearchResult({
    required List<VectorSearchHit> hits,
    required this.diagnostics,
  }) : hits = List.unmodifiable(hits);

  final List<VectorSearchHit> hits;
  final VectorSearchDiagnostics diagnostics;
}

/// Abstract vector store for semantic search over memory chunks.
abstract interface class VectorStore {
  /// Insert or update a single vector entry.
  Future<void> upsert({
    required String id,
    required String projectId,
    required String content,
    required List<double> embedding,
    required MemoryTier tier,
    Map<String, dynamic> metadata = const {},
  });

  /// Insert or update [entries] atomically when the implementation supports it.
  Future<void> upsertAll(List<VectorStoreEntry> entries);

  /// Search for the closest vectors to [embedding].
  ///
  /// If [tiers] is non-null, only entries in those tiers are considered.
  Future<List<VectorSearchHit>> search({
    required List<double> embedding,
    required String projectId,
    Set<MemoryTier>? tiers,
    int limit = 10,
  });

  /// Search and return immutable evidence about candidate pruning.
  Future<VectorSearchResult> searchDetailed({
    required List<double> embedding,
    required String projectId,
    Set<MemoryTier>? tiers,
    int limit = 10,
  });

  /// Batch-index [chunks] by computing embeddings via [embeddingForChunk].
  ///
  /// The callback isolates this interface from any specific embedding model.
  Future<void> indexChunks(
    List<StoryMemoryChunk> chunks,
    Future<List<double>> Function(String content) embeddingForChunk,
  );

  /// Remove the entry with the given [id].
  Future<void> delete(String id, {required String projectId});

  /// Remove every vector entry belonging to [projectId].
  Future<void> clearProject(String projectId);
}

/// Cosine similarity between two equal-length vectors.
/// Returns 0 when either vector is zero-length or has zero norm.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError('Embedding dimensions must match');
  }
  var dot = 0.0, normA = 0.0, normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = sqrt(normA) * sqrt(normB);
  return denom == 0 ? 0 : dot / denom;
}
