import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

/// In-memory [VectorStore] for testing, using the same cosine scoring.
class FakeVectorStore implements VectorStore {
  final _entries = <String, _Entry>{};

  @override
  Future<void> upsert({
    required String id,
    required String projectId,
    required String content,
    required List<double> embedding,
    required MemoryTier tier,
    Map<String, dynamic> metadata = const {},
  }) async {
    final effectiveProjectId = _requireProjectId(projectId);
    _entries[_key(effectiveProjectId, id)] = _Entry(
      id: id,
      projectId: effectiveProjectId,
      content: content,
      embedding: List<double>.from(embedding),
      tier: tier,
      metadata: Map<String, dynamic>.from(metadata),
    );
  }

  @override
  Future<void> upsertAll(List<VectorStoreEntry> entries) async {
    for (final entry in entries) {
      await upsert(
        id: entry.id,
        projectId: entry.projectId,
        content: entry.content,
        embedding: entry.embedding,
        tier: entry.tier,
        metadata: entry.metadata,
      );
    }
  }

  @override
  Future<List<VectorSearchHit>> search({
    required List<double> embedding,
    required String projectId,
    Set<MemoryTier>? tiers,
    int limit = 10,
  }) async {
    return (await searchDetailed(
      embedding: embedding,
      projectId: projectId,
      tiers: tiers,
      limit: limit,
    )).hits;
  }

  @override
  Future<VectorSearchResult> searchDetailed({
    required List<double> embedding,
    required String projectId,
    Set<MemoryTier>? tiers,
    int limit = 10,
  }) async {
    final effectiveProjectId = _requireProjectId(projectId);
    final hits = <VectorSearchHit>[];
    for (final e in _entries.values) {
      if (e.projectId != effectiveProjectId) continue;
      if (e.embedding.length != embedding.length) continue;
      if (tiers != null && !tiers.contains(e.tier)) continue;
      hits.add(
        VectorSearchHit(
          id: e.id,
          score: cosineSimilarity(embedding, e.embedding),
          content: e.content,
          tier: e.tier,
          metadata: e.metadata,
        ),
      );
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    final boundedLimit = limit < 0 ? 0 : limit;
    return VectorSearchResult(
      hits: hits.take(boundedLimit).toList(),
      diagnostics: VectorSearchDiagnostics(
        totalRows: _entries.length,
        eligibleRows: hits.length,
        candidateRows: hits.length,
        decodedRows: hits.length,
        scoredRows: hits.length,
        candidateLimit: hits.length,
        probeCount: 0,
        usedFullScan: true,
      ),
    );
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
        projectId: chunk.projectId,
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
  Future<void> delete(String id, {required String projectId}) async {
    _entries.remove(_key(_requireProjectId(projectId), id));
  }

  @override
  Future<void> clearProject(String projectId) async {
    final effectiveProjectId = _requireProjectId(projectId);
    _entries.removeWhere((_, entry) => entry.projectId == effectiveProjectId);
  }

  static String _key(String projectId, String id) => '$projectId\u0000$id';

  static String _requireProjectId(String projectId) {
    final normalized = projectId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', 'must not be empty');
    }
    return normalized;
  }
}

class _Entry {
  _Entry({
    required this.id,
    required this.projectId,
    required this.content,
    required this.embedding,
    required this.tier,
    required this.metadata,
  });

  final String id;
  final String projectId;
  final String content;
  final List<double> embedding;
  final MemoryTier tier;
  final Map<String, dynamic> metadata;
}
