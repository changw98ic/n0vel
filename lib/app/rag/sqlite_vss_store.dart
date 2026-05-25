import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'memory_models.dart';
import 'memory_policy.dart';
import 'vector_store.dart';

/// SQLite-backed vector store using JSON-persisted embeddings and Dart-side
/// cosine similarity. Named for the planned sqlite-vss boundary; does not
/// require the extension at runtime.
class SqliteVssStore implements VectorStore {
  SqliteVssStore(this._db) {
    _initTable();
  }

  final Database _db;
  static const _table = 'vector_embeddings';

  void _initTable() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        embedding TEXT NOT NULL,
        tier TEXT NOT NULL,
        metadata TEXT NOT NULL DEFAULT '{}'
      )
    ''');
  }

  @override
  Future<void> upsert({
    required String id,
    required String content,
    required List<double> embedding,
    required MemoryTier tier,
    Map<String, dynamic> metadata = const {},
  }) async {
    _db.execute(
      'INSERT OR REPLACE INTO $_table (id, content, embedding, tier, metadata) '
      'VALUES (?, ?, ?, ?, ?)',
      [id, content, jsonEncode(embedding), tier.name, jsonEncode(metadata)],
    );
  }

  @override
  Future<List<VectorSearchHit>> search({
    required List<double> embedding,
    Set<MemoryTier>? tiers,
    int limit = 10,
  }) async {
    final rows = _db.select(
      'SELECT id, content, embedding, tier, metadata FROM $_table',
    );

    final hits = <VectorSearchHit>[];
    for (final row in rows) {
      final tier = MemoryTier.values.firstWhere((t) => t.name == row['tier']);
      if (tiers != null && !tiers.contains(tier)) continue;

      final stored = (jsonDecode(row['embedding'] as String) as List)
          .cast<double>();
      final score = cosineSimilarity(embedding, stored);

      hits.add(
        VectorSearchHit(
          id: row['id'] as String,
          score: score,
          content: row['content'] as String,
          tier: tier,
          metadata:
              jsonDecode(row['metadata'] as String) as Map<String, dynamic>,
        ),
      );
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
    _db.execute('DELETE FROM $_table WHERE id = ?', [id]);
  }
}
