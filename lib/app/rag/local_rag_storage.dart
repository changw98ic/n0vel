import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

/// A single document stored in the local RAG index.
class LocalRagDocument {
  const LocalRagDocument({
    required this.path,
    required this.content,
    required this.projectId,
    required this.category,
    this.embedding,
    this.metadata = const {},
  });

  final String path;
  final String content;
  final String projectId;
  final String category;
  final Float64List? embedding;
  final Map<String, Object?> metadata;
}

/// A search result from the local RAG index.
class LocalRagSearchResult {
  const LocalRagSearchResult({
    required this.path,
    required this.content,
    required this.score,
    this.rowid,
    this.metadata = const {},
  });

  final String path;
  final String content;
  final double score;

  /// SQLite rowid for embedding lookup (internal use).
  final int? rowid;
  final Map<String, Object?> metadata;
}

/// SQLite FTS5-backed local RAG document store.
///
/// Replaces the external OpenViking server with on-device full-text search.
/// Embeddings are stored as BLOBs for optional hybrid search.
class LocalRagStorage {
  LocalRagStorage({required this.db});

  final Database db;
  bool _migrated = false;

  Future<void> ensureTables() async {
    if (_migrated) return;
    db.execute('''
      CREATE TABLE IF NOT EXISTS rag_documents (
        rowid INTEGER PRIMARY KEY,
        path TEXT NOT NULL,
        content TEXT NOT NULL,
        project_id TEXT NOT NULL,
        category TEXT NOT NULL,
        embedding BLOB,
        metadata TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_rag_docs_path
      ON rag_documents (path)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rag_docs_project
      ON rag_documents (project_id)
    ''');
    // FTS5 only over path, content, project_id, category (not embedding/metadata)
    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS rag_fts USING fts5(
        path, content, project_id, category,
        content='rag_documents', content_rowid='rowid'
      )
    ''');
    _migrated = true;
  }

  /// Indexes a single document. Upserts by path.
  Future<void> indexDocument({
    required String projectId,
    required String path,
    required String content,
    required String category,
    Float64List? embedding,
    Map<String, Object?> metadata = const {},
  }) async {
    await ensureTables();
    final metaJson = jsonEncode(metadata);
    final embBlob = embedding != null ? _embeddingToBlob(embedding) : null;

    // Check existence by path
    final existing = db.select(
      'SELECT rowid FROM rag_documents WHERE path = ?',
      [path],
    );
    if (existing.isNotEmpty) {
      final rowid = existing.first['rowid'] as int;
      db.execute(
        'UPDATE rag_documents SET content = ?, project_id = ?, category = ?, embedding = ?, metadata = ? WHERE rowid = ?',
        [content, projectId, category, embBlob, metaJson, rowid],
      );
    } else {
      db.execute(
        'INSERT INTO rag_documents (path, content, project_id, category, embedding, metadata) VALUES (?, ?, ?, ?, ?, ?)',
        [path, content, projectId, category, embBlob, metaJson],
      );
    }
  }

  /// Removes a document by path.
  Future<void> removeDocument(String path) async {
    await ensureTables();
    db.execute('DELETE FROM rag_documents WHERE path = ?', [path]);
  }

  /// Removes all documents for a project.
  Future<void> clearProject(String projectId) async {
    await ensureTables();
    db.execute(
      'DELETE FROM rag_documents WHERE project_id = ?',
      [projectId],
    );
  }

  /// Full-text search using FTS5 BM25 ranking.
  Future<List<LocalRagSearchResult>> searchFts({
    required String projectId,
    required String query,
    int limit = 10,
    String? category,
  }) async {
    await ensureTables();
    // Build FTS5 match expression — escape double quotes
    final safeQuery = query.replaceAll('"', '""');
    final matchExpr = '"$safeQuery"';

    final rows = category != null
        ? db.select(
            '''
      SELECT rd.rowid, rd.path, rd.content, rd.metadata, fts.rank
      FROM rag_fts AS fts
      JOIN rag_documents AS rd ON fts.rowid = rd.rowid
      WHERE fts.rag_fts MATCH ? AND fts.project_id = ? AND fts.category = ?
      ORDER BY fts.rank
      LIMIT ?
      ''',
            [matchExpr, projectId, category, limit],
          )
        : db.select(
            '''
      SELECT rd.rowid, rd.path, rd.content, rd.metadata, fts.rank
      FROM rag_fts AS fts
      JOIN rag_documents AS rd ON fts.rowid = rd.rowid
      WHERE fts.rag_fts MATCH ? AND fts.project_id = ?
      ORDER BY fts.rank
      LIMIT ?
      ''',
            [matchExpr, projectId, limit],
          );

    return [
      for (final row in rows)
        LocalRagSearchResult(
          rowid: row['rowid'] as int,
          path: row['path'] as String,
          content: row['content'] as String,
          score: _bm25ToScore(row['rank'] as double),
          metadata: _parseMetadata(row['metadata']),
        ),
    ];
  }

  /// Loads stored embedding for a set of row IDs.
  Future<Map<int, Float64List>> loadEmbeddings(List<int> rowids) async {
    if (rowids.isEmpty) return {};
    await ensureTables();
    final placeholders = rowids.map((_) => '?').join(',');
    final rows = db.select(
      'SELECT rowid, embedding FROM rag_documents WHERE rowid IN ($placeholders) AND embedding IS NOT NULL',
      rowids,
    );
    return {
      for (final row in rows)
        if (row['embedding'] != null)
          row['rowid'] as int: _blobToEmbedding(row['embedding'] as List<int>),
    };
  }

  /// Returns all rowids for documents matching project + optional category.
  Future<List<int>> rowidsForProject(String projectId, {String? category}) async {
    await ensureTables();
    final rows = category != null
        ? db.select(
            'SELECT rowid FROM rag_documents WHERE project_id = ? AND category = ?',
            [projectId, category],
          )
        : db.select(
            'SELECT rowid FROM rag_documents WHERE project_id = ?',
            [projectId],
          );
    return [for (final row in rows) row['rowid'] as int];
  }

  /// Stores embedding for a document identified by rowid.
  Future<void> storeEmbedding(int rowid, Float64List embedding) async {
    await ensureTables();
    final blob = _embeddingToBlob(embedding);
    db.execute(
      'UPDATE rag_documents SET embedding = ? WHERE rowid = ?',
      [blob, rowid],
    );
  }

  /// Converts BM25 rank (negative) to a 0-1 score.
  double _bm25ToScore(double rank) {
    // BM25 rank is negative; more negative = more relevant
    if (rank >= 0) return 0.0;
    // Simple normalization: invert and cap at 1.0
    final normalized = 1.0 / (1.0 - rank);
    return normalized.clamp(0.0, 1.0);
  }

  Float64List _blobToEmbedding(List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    return data.buffer.asFloat64List();
  }

  List<int> _embeddingToBlob(Float64List embedding) {
    final bytes = Uint8List.view(embedding.buffer);
    return bytes.toList();
  }

  Map<String, Object?> _parseMetadata(Object? raw) {
    if (raw is String) {
      return Map<String, Object?>.from(
        jsonDecode(raw) as Map,
      );
    }
    return const {};
  }
}
