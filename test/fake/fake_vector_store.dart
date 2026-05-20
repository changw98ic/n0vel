import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

/// In-memory [VectorStore] for testing, using the same cosine scoring.
class FakeVectorStore implements VectorStore {
  final _entries = <String, _Entry>{};

  @override
  Future<void> upsert({
    required String id,
    required String content,
    required List<double> embedding,
    required MemoryTier tier,
    Map<String, dynamic> metadata = const {},
  }) async {
    _entries[id] = _Entry(
      id: id,
      content: content,
      embedding: List<double>.from(embedding),
      tier: tier,
      metadata: Map<String, dynamic>.from(metadata),
    );
  }

  @override
  Future<List<VectorSearchHit>> search({
    required List<double> embedding,
    Set<MemoryTier>? tiers,
    int limit = 10,
  }) async {
    final hits = <VectorSearchHit>[];
    for (final e in _entries.values) {
      if (tiers != null && !tiers.contains(e.tier)) continue;
      hits.add(VectorSearchHit(
        id: e.id,
        score: cosineSimilarity(embedding, e.embedding),
        content: e.content,
        tier: e.tier,
        metadata: e.metadata,
      ));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }

  @override
  Future<void> indexChunks(
    List<StoryMemoryChunk> chunks,
    Future<List<double>> Function(String content) embeddingForChunk,
  ) async {
    for (final chunk in chunks) {
      final embedding = await embeddingForChunk(chunk.content);
      await upsert(
        id: chunk.id,
        content: chunk.content,
        embedding: embedding,
        tier: chunk.tier,
        metadata: {
          'projectId': chunk.projectId,
          'scopeId': chunk.scopeId,
          'kind': chunk.kind.name,
          'tags': chunk.tags,
        },
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    _entries.remove(id);
  }
}

class _Entry {
  _Entry({
    required this.id,
    required this.content,
    required this.embedding,
    required this.tier,
    required this.metadata,
  });

  final String id;
  final String content;
  final List<double> embedding;
  final MemoryTier tier;
  final Map<String, dynamic> metadata;
}
