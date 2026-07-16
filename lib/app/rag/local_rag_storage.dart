import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;

import 'package:sqlite3/sqlite3.dart';

import 'cjk_text_normalizer.dart';
import '../state/sqlite_write_coordinator.dart';
import '../../features/story_generation/domain/contracts/memory_policy.dart';
import '../../features/story_generation/domain/memory_models.dart';

/// SQL-admission inputs for local RAG. These are query inputs only; document
/// tags and access fields remain structured storage fields.
class RagAdmission {
  const RagAdmission({
    required this.allowedTiers,
    this.viewerId,
    this.viewerRole = MemoryViewerRole.reader,
    this.allowedScopeIds = const [],
    this.requiredTagGroups = const [],
  });

  final Set<MemoryTier> allowedTiers;
  final String? viewerId;
  final MemoryViewerRole viewerRole;
  final List<String> allowedScopeIds;
  final List<List<String>> requiredTagGroups;
}

/// Canonicalizes hard tag constraints for every retrieval implementation.
/// Empty/whitespace-only groups carry no constraint and are discarded.
List<List<String>> normalizeRequiredTagGroups(
  Iterable<Iterable<String>> groups,
) {
  final normalized = <List<String>>[];
  for (final rawGroup in groups) {
    final group = {
      for (final tag in rawGroup)
        if (tag.trim().isNotEmpty) tag.trim(),
    }.toList()..sort();
    if (group.isNotEmpty) normalized.add(List.unmodifiable(group));
  }
  return List.unmodifiable(normalized);
}

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
class LocalRagFtsResult {
  const LocalRagFtsResult({
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
  LocalRagStorage({required this.db, SqliteWriteCoordinator? writeCoordinator})
    : writeCoordinator =
          writeCoordinator ?? SqliteWriteCoordinator.forDatabase(db);

  static const _admissionSchemaVersion = '1';
  static const _cjkIndexVersion = '3';
  static const _ftsIndexVersion = '1';
  static const int schemaMigrationBatchSize = 256;
  static const String schemaReleaseVersion =
      'local-rag-schema-admission-1-fts-1-cjk-3-normalizer-2';

  final Database db;
  final SqliteWriteCoordinator writeCoordinator;
  bool _migrated = false;

  Future<void> ensureTables({SqliteWriteLease? lease}) {
    if (_migrated && lease == null) return Future<void>.value();
    return writeCoordinator.synchronized<void>((_) {
      _ensureTablesNow();
    }, lease: lease);
  }

  void _ensureTablesNow() {
    if (_migrated) return;
    _ensureDocumentSchema();
    final hadDocumentTags = _tableExists('rag_document_tags');
    final hadFtsIndex = _tableExists('rag_fts');
    final hadCjkIndex = _tableExists('rag_cjk_fts');
    db.execute('''
      CREATE TABLE IF NOT EXISTS rag_document_tags (
        project_id TEXT NOT NULL,
        document_path TEXT NOT NULL,
        tag TEXT NOT NULL CHECK (length(trim(tag)) > 0),
        PRIMARY KEY (project_id, document_path, tag),
        FOREIGN KEY (project_id, document_path)
          REFERENCES rag_documents(project_id, path) ON DELETE CASCADE
      ) WITHOUT ROWID
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rag_document_tags_lookup
      ON rag_document_tags (project_id, tag, document_path)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rag_docs_admission
      ON rag_documents (project_id, tier, visibility, owner_id, scope_id)
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS rag_index_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS rag_fts USING fts5(
        path, content, project_id, category,
        content='rag_documents', content_rowid='rowid'
      )
    ''');
    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS rag_cjk_fts USING fts5(
        tokens,
        tokenize='unicode61'
      )
    ''');
    _ensureFtsTriggers();
    if (!hadFtsIndex ||
        _indexMetaValue('fts_index_version') != _ftsIndexVersion) {
      db.execute("INSERT INTO rag_fts(rag_fts) VALUES('rebuild')");
      _setIndexMeta('fts_index_version', _ftsIndexVersion);
    }
    if (!hadDocumentTags ||
        _indexMetaValue('admission_schema_version') !=
            _admissionSchemaVersion) {
      _backfillDocumentAdmission();
      _setIndexMeta('admission_schema_version', _admissionSchemaVersion);
    }
    _backfillCjkIndex(force: !hadCjkIndex);
    _migrated = true;
  }

  void _ensureDocumentSchema() {
    final exists = db
        .select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'rag_documents'",
        )
        .isNotEmpty;
    if (exists && _hasAdmissionColumns()) {
      db.execute('DROP INDEX IF EXISTS idx_rag_docs_path');
      db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_rag_docs_project_path
        ON rag_documents (project_id, path)
      ''');
      return;
    }
    if (exists) {
      _dropFtsArtifacts();
      db.execute('DROP TABLE IF EXISTS rag_document_tags');
      db.execute('ALTER TABLE rag_documents RENAME TO rag_documents_legacy');
    }
    _createDocumentTable();
    if (exists) {
      db.execute('''
        INSERT INTO rag_documents (
          rowid, path, content, project_id, category, tier, visibility,
          owner_id, scope_id, metadata
        )
        SELECT rowid, path, content, project_id, category, 'scene',
          'publicObservable', '', '', metadata
        FROM rag_documents_legacy
      ''');
      db.execute('DROP TABLE rag_documents_legacy');
    }
  }

  bool _hasAdmissionColumns() {
    final names = {
      for (final row in db.select('PRAGMA table_info(rag_documents)'))
        row['name']?.toString(),
    };
    return names.containsAll({'tier', 'visibility', 'owner_id', 'scope_id'});
  }

  bool _tableExists(String table) => db.select(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    <Object?>[table],
  ).isNotEmpty;

  void _createDocumentTable() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS rag_documents (
        rowid INTEGER PRIMARY KEY,
        path TEXT NOT NULL,
        content TEXT NOT NULL,
        project_id TEXT NOT NULL CHECK (length(trim(project_id)) > 0),
        category TEXT NOT NULL,
        tier TEXT NOT NULL CHECK (tier IN ('canon', 'character', 'scene', 'draft', 'meta')),
        visibility TEXT NOT NULL CHECK (visibility IN ('publicObservable', 'agentPrivate', 'editorOnly')),
        owner_id TEXT NOT NULL DEFAULT '' CHECK (visibility != 'agentPrivate' OR length(trim(owner_id)) > 0),
        scope_id TEXT NOT NULL DEFAULT '',
        metadata TEXT NOT NULL DEFAULT '{}'
        , UNIQUE (project_id, path)
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rag_docs_project
      ON rag_documents (project_id)
    ''');
  }

  void _dropFtsArtifacts() {
    for (final trigger in const [
      'rag_docs_ai',
      'rag_docs_ad',
      'rag_docs_au',
      'rag_docs_cjk_ad',
    ]) {
      db.execute('DROP TRIGGER IF EXISTS $trigger');
    }
    db.execute('DROP TABLE IF EXISTS rag_fts');
    db.execute('DROP TABLE IF EXISTS rag_cjk_fts');
  }

  void _backfillDocumentAdmission() {
    var lastRowId = -1;
    while (true) {
      final rows = db.select(
        '''
        SELECT rowid, project_id, path, metadata, scope_id, visibility, owner_id
        FROM rag_documents WHERE rowid > ? ORDER BY rowid
        LIMIT $schemaMigrationBatchSize
        ''',
        <Object?>[lastRowId],
      );
      if (rows.isEmpty) return;
      for (final row in rows) {
        final metadata = _parseMetadata(row['metadata']);
        final visibility = row['visibility']?.toString() == 'publicObservable'
            ? metadata['visibility']?.toString() ?? 'publicObservable'
            : row['visibility']?.toString() ?? 'publicObservable';
        final ownerId = row['owner_id']?.toString().trim().isNotEmpty == true
            ? row['owner_id']!.toString()
            : metadata['ownerId']?.toString() ??
                  (visibility == 'agentPrivate'
                      ? 'legacy-private-${row['rowid']}'
                      : '');
        final scopeId = row['scope_id']?.toString().trim().isNotEmpty == true
            ? row['scope_id']!.toString()
            : metadata['scopeId']?.toString() ?? '';
        db.execute(
          '''UPDATE rag_documents
          SET scope_id = ?, visibility = ?, owner_id = ? WHERE rowid = ?''',
          [scopeId, visibility, ownerId, row['rowid']],
        );
        _replaceTags(
          row['project_id'] as String,
          row['path'] as String,
          _stringList(metadata['tags']),
        );
        lastRowId = row['rowid'] as int;
      }
    }
  }

  /// Indexes a single document. Upserts by path.
  Future<void> indexDocument({
    required String projectId,
    required String path,
    required String content,
    required String category,
    Map<String, Object?> metadata = const {},
  }) => indexDocumentCoordinated(
    projectId: projectId,
    path: path,
    content: content,
    category: category,
    metadata: metadata,
  );

  /// [indexDocument] with an optional lease for a wider atomic write.
  Future<void> indexDocumentCoordinated({
    required String projectId,
    required String path,
    required String content,
    required String category,
    Map<String, Object?> metadata = const {},
    SqliteWriteLease? lease,
  }) async {
    await ensureTables(lease: lease);
    final metaJson = jsonEncode(metadata);
    final admission = _documentAdmission(metadata);
    await writeCoordinator.synchronized<void>((_) {
      db.execute('SAVEPOINT rag_index_document');
      try {
        final existing = db.select(
          'SELECT rowid FROM rag_documents WHERE project_id = ? AND path = ?',
          [projectId, path],
        );
        if (existing.isNotEmpty) {
          final rowid = existing.first['rowid'] as int;
          db.execute(
            '''UPDATE rag_documents SET
            content = ?, category = ?, tier = ?, visibility = ?, owner_id = ?,
            scope_id = ?, metadata = ? WHERE rowid = ?''',
            [
              content,
              category,
              admission.tier.name,
              admission.visibility.name,
              admission.ownerId,
              admission.scopeId,
              metaJson,
              rowid,
            ],
          );
        } else {
          db.execute(
            '''INSERT INTO rag_documents (
            path, content, project_id, category, tier, visibility, owner_id,
            scope_id, metadata
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            [
              path,
              content,
              projectId,
              category,
              admission.tier.name,
              admission.visibility.name,
              admission.ownerId,
              admission.scopeId,
              metaJson,
            ],
          );
        }
        final row = db.select(
          'SELECT rowid FROM rag_documents WHERE project_id = ? AND path = ?',
          [projectId, path],
        ).single;
        _replaceTags(projectId, path, admission.tags);
        _upsertCjkIndex(row['rowid'] as int, path: path, content: content);
        db.execute('RELEASE SAVEPOINT rag_index_document');
      } on Object {
        db.execute('ROLLBACK TO SAVEPOINT rag_index_document');
        db.execute('RELEASE SAVEPOINT rag_index_document');
        rethrow;
      }
    }, lease: lease);
  }

  /// Removes one project's document by path.
  Future<void> removeDocument(String path, {required String projectId}) =>
      removeDocumentCoordinated(path, projectId: projectId);

  /// [removeDocument] with an optional lease for a wider atomic write.
  Future<void> removeDocumentCoordinated(
    String path, {
    required String projectId,
    SqliteWriteLease? lease,
  }) async {
    await ensureTables(lease: lease);
    await writeCoordinator.synchronized<void>((_) {
      db.execute('SAVEPOINT rag_remove_document');
      try {
        db.execute(
          'DELETE FROM rag_document_tags WHERE project_id = ? AND document_path = ?',
          <Object?>[projectId, path],
        );
        db.execute(
          'DELETE FROM rag_documents WHERE project_id = ? AND path = ?',
          <Object?>[projectId, path],
        );
        db.execute('RELEASE SAVEPOINT rag_remove_document');
      } on Object {
        db.execute('ROLLBACK TO SAVEPOINT rag_remove_document');
        db.execute('RELEASE SAVEPOINT rag_remove_document');
        rethrow;
      }
    }, lease: lease);
  }

  /// Removes all documents for a project.
  Future<void> clearProject(String projectId) =>
      clearProjectCoordinated(projectId);

  /// [clearProject] with an optional lease for a wider atomic write.
  Future<void> clearProjectCoordinated(
    String projectId, {
    SqliteWriteLease? lease,
  }) async {
    await ensureTables(lease: lease);
    await writeCoordinator.synchronized<void>((_) {
      db.execute('SAVEPOINT rag_clear_project');
      try {
        db.execute('DELETE FROM rag_document_tags WHERE project_id = ?', [
          projectId,
        ]);
        db.execute('DELETE FROM rag_documents WHERE project_id = ?', [
          projectId,
        ]);
        db.execute('RELEASE SAVEPOINT rag_clear_project');
      } on Object {
        db.execute('ROLLBACK TO SAVEPOINT rag_clear_project');
        db.execute('RELEASE SAVEPOINT rag_clear_project');
        rethrow;
      }
    }, lease: lease);
  }

  /// Full-text search using FTS5 BM25 ranking.
  Future<List<LocalRagFtsResult>> searchFts({
    required String projectId,
    required String query,
    int limit = 10,
    String? category,
    RagAdmission? admission,
  }) async {
    await ensureTables();
    final matchExpr = _buildMatchExpression(query);
    if (matchExpr.isEmpty) return const [];

    final rows = _searchFtsRows(
      table: 'rag_fts',
      rankColumn: 'fts.rank',
      matchColumn: 'fts.rag_fts',
      matchExpr: matchExpr,
      projectId: projectId,
      category: category,
      limit: limit,
      admission: admission,
    );

    final results = [
      for (final row in rows)
        LocalRagFtsResult(
          rowid: row['rowid'] as int,
          path: row['path'] as String,
          content: row['content'] as String,
          score: _bm25ToScore(row['rank'] as double),
          metadata: _parseMetadata(row['metadata']),
        ),
    ];
    if (!containsCjk(query)) return results;

    final cjkResults = _searchCjkLexical(
      projectId: projectId,
      query: query,
      limit: limit,
      category: category,
      admission: admission,
    );
    if (cjkResults.isEmpty) return results;

    final merged = <String, LocalRagFtsResult>{
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

  List<Row> _searchFtsRows({
    required String table,
    required String rankColumn,
    required String matchColumn,
    required String matchExpr,
    required String projectId,
    required String? category,
    required int limit,
    required RagAdmission? admission,
  }) {
    final clause = _admissionClause(admission, alias: 'rd');
    final parameters = <Object?>[
      matchExpr,
      projectId,
      ?category,
      ...clause.parameters,
      limit,
    ];
    return db.select('''
      SELECT rd.rowid, rd.path, rd.content, rd.metadata, $rankColumn AS rank
      FROM $table AS fts
      JOIN rag_documents AS rd ON fts.rowid = rd.rowid
      WHERE $matchColumn MATCH ?
        AND rd.project_id = ?
        ${category != null ? 'AND rd.category = ?' : ''}
        ${clause.sql}
      ORDER BY $rankColumn
      LIMIT ?
    ''', parameters);
  }

  _SqlClause _admissionClause(
    RagAdmission? admission, {
    required String alias,
  }) {
    if (admission == null) return const _SqlClause('', []);
    final clauses = <String>[];
    final params = <Object?>[];
    final tiers = admission.allowedTiers.map((tier) => tier.name).toList()
      ..sort();
    if (tiers.isEmpty) return const _SqlClause('AND 0', []);
    clauses.add(
      '$alias.tier IN (${List.filled(tiers.length, '?').join(', ')})',
    );
    params.addAll(tiers);

    clauses.add('''(
      $alias.visibility = 'publicObservable'
      OR ($alias.visibility = 'editorOnly' AND ? = 1)
      OR ($alias.visibility = 'agentPrivate' AND $alias.owner_id = ?)
    )''');
    params.add(admission.viewerRole == MemoryViewerRole.editor ? 1 : 0);
    params.add(admission.viewerId?.trim() ?? '');

    final scopes = {
      for (final scope in admission.allowedScopeIds)
        if (scope.trim().isNotEmpty) scope.trim(),
    }.toList()..sort();
    if (scopes.isNotEmpty) {
      clauses.add(
        '$alias.scope_id IN (${List.filled(scopes.length, '?').join(', ')})',
      );
      params.addAll(scopes);
    }

    for (final group in normalizeRequiredTagGroups(
      admission.requiredTagGroups,
    )) {
      clauses.add('''EXISTS (
        SELECT 1 FROM rag_document_tags AS dt
        WHERE dt.project_id = $alias.project_id
          AND dt.document_path = $alias.path
          AND dt.tag IN (${List.filled(group.length, '?').join(', ')})
      )''');
      params.addAll(group);
    }
    return _SqlClause('AND ${clauses.join(' AND ')}', params);
  }

  _DocumentAdmission _documentAdmission(Map<String, Object?> metadata) {
    final tier = _tierByName(metadata['tier']);
    final visibility = _visibilityByName(metadata['visibility']);
    final ownerId = metadata['ownerId']?.toString().trim() ?? '';
    if (visibility == MemoryVisibility.agentPrivate && ownerId.isEmpty) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'agentPrivate documents require a non-empty ownerId',
      );
    }
    return _DocumentAdmission(
      tier: tier,
      visibility: visibility,
      ownerId: ownerId,
      scopeId: metadata['scopeId']?.toString().trim() ?? '',
      tags: _stringList(metadata['tags']),
    );
  }

  void _replaceTags(String projectId, String path, List<String> tags) {
    db.execute(
      'DELETE FROM rag_document_tags WHERE project_id = ? AND document_path = ?',
      [projectId, path],
    );
    final statement = db.prepare('''
      INSERT INTO rag_document_tags (project_id, document_path, tag)
      VALUES (?, ?, ?)
    ''');
    try {
      for (final tag in tags) {
        statement.execute([projectId, path, tag]);
      }
    } finally {
      statement.dispose();
    }
  }

  static MemoryTier _tierByName(Object? raw) => MemoryTier.values.firstWhere(
    (tier) => tier.name == raw?.toString(),
    orElse: () => MemoryTier.scene,
  );

  static MemoryVisibility _visibilityByName(Object? raw) =>
      MemoryVisibility.values.firstWhere(
        (visibility) => visibility.name == raw?.toString(),
        orElse: () => MemoryVisibility.publicObservable,
      );

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return {
      for (final value in raw)
        if (value != null && value.toString().trim().isNotEmpty)
          value.toString().trim(),
    }.toList()..sort();
  }

  /// Converts BM25 rank (negative) to a 0-1 score.
  double _bm25ToScore(double rank) {
    if (rank >= 0) return 0.0;
    // FTS5 orders better matches by a smaller (more negative) BM25 rank.
    // Negating the numerator preserves that ordering when callers compare
    // scores in the conventional higher-is-better direction.
    final normalized = -rank / (1.0 - rank);
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

  List<LocalRagFtsResult> _searchCjkLexical({
    required String projectId,
    required String query,
    required int limit,
    String? category,
    RagAdmission? admission,
  }) {
    final tokens = cjkSearchTokens(query, maxTokens: 32);
    if (tokens.isEmpty) return const [];
    final matchExpression = tokens.map(_quoteFtsToken).join(' OR ');
    final rows = _searchFtsRows(
      table: 'rag_cjk_fts',
      rankColumn: 'fts.rank',
      matchColumn: 'fts.rag_cjk_fts',
      matchExpr: matchExpression,
      projectId: projectId,
      category: category,
      limit: limit,
      admission: admission,
    );

    return [
      for (final row in rows)
        LocalRagFtsResult(
          rowid: row['rowid'] as int,
          path: row['path'] as String,
          content: row['content'] as String,
          score: _bm25ToScore(row['rank'] as double),
          metadata: _parseMetadata(row['metadata']),
        ),
    ];
  }

  /// Expand a single term for FTS5 matching.
  /// CJK runs are split into individual character AND clauses for reliable
  /// matching regardless of tokenizer behavior.
  String _expandTermForFts(String term) {
    final cjkChars = <String>[];
    final nonCjk = StringBuffer();
    for (final rune in term.runes) {
      if (isCjkRune(rune)) {
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

  String _quoteFtsToken(String token) => '"${token.replaceAll('"', '""')}"';

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
      CREATE TRIGGER IF NOT EXISTS rag_docs_cjk_ad
      AFTER DELETE ON rag_documents BEGIN
        DELETE FROM rag_cjk_fts WHERE rowid = old.rowid;
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

  void _backfillCjkIndex({bool force = false}) {
    if (!force && _indexMetaValue('cjk_index_version') == _cjkIndexVersion) {
      return;
    }

    db.execute('SAVEPOINT rag_cjk_backfill');
    try {
      db.execute('DELETE FROM rag_cjk_fts');
      var lastRowId = -1;
      while (true) {
        final rows = db.select(
          '''SELECT rowid, path, content FROM rag_documents
             WHERE rowid > ? ORDER BY rowid LIMIT $schemaMigrationBatchSize''',
          <Object?>[lastRowId],
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          _upsertCjkIndex(
            row['rowid'] as int,
            path: row['path'] as String,
            content: row['content'] as String,
          );
          lastRowId = row['rowid'] as int;
        }
      }
      _setIndexMeta('cjk_index_version', _cjkIndexVersion);
      db.execute('RELEASE SAVEPOINT rag_cjk_backfill');
    } on Object {
      db.execute('ROLLBACK TO SAVEPOINT rag_cjk_backfill');
      db.execute('RELEASE SAVEPOINT rag_cjk_backfill');
      rethrow;
    }
  }

  String? _indexMetaValue(String key) {
    final rows = db.select(
      'SELECT value FROM rag_index_meta WHERE key = ?',
      <Object?>[key],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  void _setIndexMeta(String key, String value) {
    db.execute(
      '''
      INSERT INTO rag_index_meta (key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      <Object?>[key, value],
    );
  }

  void _upsertCjkIndex(
    int rowid, {
    required String path,
    required String content,
  }) {
    final tokens = cjkSearchTokens(
      '$path\n$content',
      maxTokens: null,
    ).join(' ');
    db.execute('DELETE FROM rag_cjk_fts WHERE rowid = ?', [rowid]);
    if (tokens.isEmpty) return;
    db.execute('INSERT INTO rag_cjk_fts(rowid, tokens) VALUES (?, ?)', [
      rowid,
      tokens,
    ]);
  }
}

class _DocumentAdmission {
  const _DocumentAdmission({
    required this.tier,
    required this.visibility,
    required this.ownerId,
    required this.scopeId,
    required this.tags,
  });

  final MemoryTier tier;
  final MemoryVisibility visibility;
  final String ownerId;
  final String scopeId;
  final List<String> tags;
}

class _SqlClause {
  const _SqlClause(this.sql, this.parameters);

  final String sql;
  final List<Object?> parameters;
}
