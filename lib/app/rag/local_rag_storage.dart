import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;

import 'package:sqlite3/sqlite3.dart';

/// A single document stored in the local RAG index.
class LocalRagDocument {
  const LocalRagDocument({
    required this.path,
    required this.content,
    required this.projectId,
    required this.category,
    this.metadata = const {},
  });

  final String path;
  final String content;
  final String projectId;
  final String category;
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

  /// SQLite rowid for storage-level diagnostics.
  final int? rowid;
  final Map<String, Object?> metadata;
}

/// SQLite FTS5-backed local RAG document store.
///
/// The indexed content comes from LLM-parsed story annotations and generated
/// chapter text. No remote RAG service or embedding vector store is involved.
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
    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS rag_fts USING fts5(
        path, content, project_id, category,
        content='rag_documents', content_rowid='rowid'
      )
    ''');
    _ensureFtsTriggers();
    db.execute("INSERT INTO rag_fts(rag_fts) VALUES('rebuild')");
    _migrated = true;
  }

  /// Indexes a single document. Upserts by path.
  Future<void> indexDocument({
    required String projectId,
    required String path,
    required String content,
    required String category,
    Map<String, Object?> metadata = const {},
  }) async {
    await ensureTables();
    final metaJson = jsonEncode(metadata);

    final existing = db.select(
      'SELECT rowid FROM rag_documents WHERE path = ?',
      [path],
    );
    if (existing.isNotEmpty) {
      final rowid = existing.first['rowid'] as int;
      db.execute(
        'UPDATE rag_documents SET content = ?, project_id = ?, category = ?, metadata = ? WHERE rowid = ?',
        [content, projectId, category, metaJson, rowid],
      );
    } else {
      db.execute(
        'INSERT INTO rag_documents (path, content, project_id, category, metadata) VALUES (?, ?, ?, ?, ?)',
        [path, content, projectId, category, metaJson],
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
    db.execute('DELETE FROM rag_documents WHERE project_id = ?', [projectId]);
  }

  /// Full-text search using FTS5 BM25 ranking.
  Future<List<LocalRagSearchResult>> searchFts({
    required String projectId,
    required String query,
    int limit = 10,
    String? category,
  }) async {
    await ensureTables();
    final matchExpr = _buildMatchExpression(query);
    if (matchExpr.isEmpty) return const [];

    final rows = category != null
        ? db.select(
            '''
      SELECT rd.rowid, rd.path, rd.content, rd.metadata, fts.rank
      FROM rag_fts AS fts
      JOIN rag_documents AS rd ON fts.rowid = rd.rowid
      WHERE fts.rag_fts MATCH ? AND rd.project_id = ? AND rd.category = ?
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
      WHERE fts.rag_fts MATCH ? AND rd.project_id = ?
      ORDER BY fts.rank
      LIMIT ?
      ''',
            [matchExpr, projectId, limit],
          );

    final results = [
      for (final row in rows)
        LocalRagSearchResult(
          rowid: row['rowid'] as int,
          path: row['path'] as String,
          content: row['content'] as String,
          score: _bm25ToScore(row['rank'] as double),
          metadata: _parseMetadata(row['metadata']),
        ),
    ];
    if (!_containsCjk(query)) return results;

    final cjkResults = _searchCjkLexical(
      projectId: projectId,
      query: query,
      limit: limit,
      category: category,
    );
    if (cjkResults.isEmpty) return results;

    final merged = <String, LocalRagSearchResult>{
      for (final result in results) result.path: result,
    };
    for (final result in cjkResults) {
      final existing = merged[result.path];
      if (existing == null || result.score > existing.score) {
        merged[result.path] = result;
      }
    }

    final sorted = merged.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return sorted.take(limit).toList();
  }

  /// Converts BM25 rank (negative) to a 0-1 score.
  double _bm25ToScore(double rank) {
    if (rank >= 0) return 0.0;
    final normalized = 1.0 / (1.0 - rank);
    return normalized.clamp(0.0, 1.0);
  }

  String _buildMatchExpression(String query) {
    final terms = core.RegExp(r'[\p{L}\p{N}_-]+', unicode: true)
        .allMatches(query)
        .map((match) => match.group(0)!.trim())
        .where((term) => term.isNotEmpty)
        .take(16)
        .toList();
    if (terms.isEmpty) return '';
    return terms.map(_expandTermForFts).join(' OR ');
  }

  List<LocalRagSearchResult> _searchCjkLexical({
    required String projectId,
    required String query,
    required int limit,
    String? category,
  }) {
    final needles = _buildCjkLexicalNeedles(query);
    if (needles.isEmpty) return const [];

    final clauses = needles
        .map((_) => '(rd.content LIKE ? OR rd.path LIKE ?)')
        .join(' OR ');
    final params = <Object?>[
      projectId,
      ?category,
      for (final needle in needles) ...['%$needle%', '%$needle%'],
      limit * 4,
    ];
    final rows = db.select('''
      SELECT rd.rowid, rd.path, rd.content, rd.metadata
      FROM rag_documents AS rd
      WHERE rd.project_id = ?
        ${category != null ? 'AND rd.category = ?' : ''}
        AND ($clauses)
      LIMIT ?
      ''', params);

    final results = [
      for (final row in rows)
        LocalRagSearchResult(
          rowid: row['rowid'] as int,
          path: row['path'] as String,
          content: row['content'] as String,
          score: _scoreCjkLexical(
            row['path'] as String,
            row['content'] as String,
            needles,
          ),
          metadata: _parseMetadata(row['metadata']),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    return results.take(limit).toList();
  }

  List<String> _buildCjkLexicalNeedles(String query) {
    final needles = <String>{};
    final runes = query.runes.toList();
    for (var i = 0; i < runes.length; i++) {
      if (!_isFtsCjk(runes[i])) continue;

      final start = i;
      while (i + 1 < runes.length && _isFtsCjk(runes[i + 1])) {
        i++;
      }

      final cjkRun = String.fromCharCodes(runes.sublist(start, i + 1));
      if (cjkRun.runes.length <= 2) {
        needles.add(cjkRun);
      } else {
        final cjkRunes = cjkRun.runes.toList();
        for (var j = 0; j < cjkRunes.length - 1; j++) {
          needles.add(String.fromCharCodes(cjkRunes.sublist(j, j + 2)));
        }
      }
    }
    return needles.take(16).toList();
  }

  double _scoreCjkLexical(String path, String content, List<String> needles) {
    final haystack = '$path\n$content';
    var matchedWeight = 0.0;
    var totalWeight = 0.0;

    for (final needle in needles) {
      final weight = needle.runes.length > 1 ? 2.0 : 0.5;
      totalWeight += weight;
      if (haystack.contains(needle)) {
        matchedWeight += weight;
      }
    }

    if (matchedWeight == 0 || totalWeight == 0) return 0.0;
    return (0.35 + (matchedWeight / totalWeight) * 0.65).clamp(0.0, 1.0);
  }

  /// Expand a single term for FTS5 matching.
  /// CJK runs are split into individual character AND clauses for reliable
  /// matching regardless of tokenizer behavior.
  String _expandTermForFts(String term) {
    final cjkChars = <String>[];
    final nonCjk = StringBuffer();
    for (final rune in term.runes) {
      if (_isFtsCjk(rune)) {
        cjkChars.add(String.fromCharCode(rune));
      } else {
        nonCjk.writeCharCode(rune);
      }
    }

    final parts = <String>[];
    if (nonCjk.isNotEmpty) {
      parts.add('"${nonCjk.toString().replaceAll('"', '""')}"');
    }
    for (final ch in cjkChars) {
      parts.add('"$ch"');
    }

    if (parts.length == 1) return parts.first;
    return '(${parts.join(' AND ')})';
  }

  static bool _isFtsCjk(int codeUnit) {
    return (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
        (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) ||
        (codeUnit >= 0x3040 && codeUnit <= 0x309F) ||
        (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) ||
        (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF);
  }

  static bool _containsCjk(String value) {
    return value.runes.any(_isFtsCjk);
  }

  Map<String, Object?> _parseMetadata(Object? raw) {
    if (raw is String) {
      try {
        return Map<String, Object?>.from(jsonDecode(raw) as Map);
      } on Object {
        return const {};
      }
    }
    return const {};
  }

  void _ensureFtsTriggers() {
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS rag_docs_ai
      AFTER INSERT ON rag_documents BEGIN
        INSERT INTO rag_fts(rowid, path, content, project_id, category)
        VALUES (new.rowid, new.path, new.content, new.project_id, new.category);
      END
    ''');
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS rag_docs_ad
      AFTER DELETE ON rag_documents BEGIN
        INSERT INTO rag_fts(rag_fts, rowid, path, content, project_id, category)
        VALUES('delete', old.rowid, old.path, old.content, old.project_id, old.category);
      END
    ''');
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS rag_docs_au
      AFTER UPDATE ON rag_documents BEGIN
        INSERT INTO rag_fts(rag_fts, rowid, path, content, project_id, category)
        VALUES('delete', old.rowid, old.path, old.content, old.project_id, old.category);
        INSERT INTO rag_fts(rowid, path, content, project_id, category)
        VALUES (new.rowid, new.path, new.content, new.project_id, new.category);
      END
    ''');
  }
}
