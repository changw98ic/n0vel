import 'dart:math';

import 'memory_models.dart';
import 'memory_policy.dart';

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

/// Abstract vector store for semantic search over memory chunks.
abstract interface class VectorStore {
  /// Insert or update a single vector entry.
  Future<void> upsert({
    required String id,
    required String content,
    required List<double> embedding,
    required MemoryTier tier,
    Map<String, dynamic> metadata = const {},
  });

  /// Search for the closest vectors to [embedding].
  ///
  /// If [tiers] is non-null, only entries in those tiers are considered.
  Future<List<VectorSearchHit>> search({
    required List<double> embedding,
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
  Future<void> delete(String id);
}

/// Cosine similarity between two equal-length vectors.
/// Returns 0 when either vector is zero-length or has zero norm.
double cosineSimilarity(List<double> a, List<double> b) {
  assert(a.length == b.length, 'Embedding dimensions must match');
  var dot = 0.0, normA = 0.0, normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = sqrt(normA) * sqrt(normB);
  return denom == 0 ? 0 : dot / denom;
}
