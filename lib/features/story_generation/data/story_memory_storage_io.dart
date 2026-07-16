import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../app/state/authoring_db_schema.dart';
import '../../../app/state/db_schema_manager.dart';
import '../../../app/state/sqlite_write_coordinator.dart';
import '../domain/memory_models.dart';
import 'story_memory_indexer.dart';
import 'story_memory_storage.dart';

/// SQLite implementation of [StoryMemoryStorage].
///
/// Fresh standalone databases keep the historical JSON-row layout. The shared
/// authoring database uses normalized columns; both layouts are detected at
/// runtime so existing standalone databases remain readable.
class StoryMemoryStorageIO
    implements StoryMemoryStorage, OwnedGenerationMemoryStorage {
  StoryMemoryStorageIO({
    required this.db,
    SqliteWriteCoordinator? writeCoordinator,
  }) : writeCoordinator =
           writeCoordinator ?? SqliteWriteCoordinator.forDatabase(db);

  final Database db;
  final SqliteWriteCoordinator writeCoordinator;

  bool _migrated = false;
  bool _sourcesUseJsonRows = true;
  bool _chunksUseJsonRows = true;
  bool _thoughtsUseJsonRows = true;

  Future<void> ensureTables({SqliteWriteLease? lease}) {
    if (_migrated && lease == null) return Future<void>.value();
    return writeCoordinator.synchronized<void>((_) {
      _ensureTablesNow();
    }, lease: lease);
  }

  void _ensureTablesNow() {
    if (_migrated) return;
    if (_usesNormalizedAuthoringSchema()) {
      // The normalized tables belong to AuthoringDbSchema. In particular,
      // owner_id is a V27 column and must never be installed independently of
      // PRAGMA user_version and the matching compatibility contract.
      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);
      _validateNormalizedAuthoringSchema();
      _sourcesUseJsonRows = false;
      _chunksUseJsonRows = false;
      _thoughtsUseJsonRows = false;
      _migrated = true;
      return;
    }
    db.execute('''
      CREATE TABLE IF NOT EXISTS story_memory_sources (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_memory_sources_project
      ON story_memory_sources (project_id)
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS story_memory_chunks (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        tier TEXT NOT NULL DEFAULT 'scene',
        producer TEXT NOT NULL DEFAULT '',
        data TEXT NOT NULL
      )
    ''');
    _migrateChunksColumns();
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_memory_chunks_project
      ON story_memory_chunks (project_id)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_memory_tier
      ON story_memory_chunks (project_id, tier)
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS story_thought_atoms (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    _migrateThoughtColumns();
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_thought_atoms_project
      ON story_thought_atoms (project_id)
    ''');

    _sourcesUseJsonRows = _tableColumns(
      'story_memory_sources',
    ).contains('data');
    _chunksUseJsonRows = _tableColumns('story_memory_chunks').contains('data');
    _thoughtsUseJsonRows = _tableColumns(
      'story_thought_atoms',
    ).contains('data');
    _migrated = true;
  }

  Set<String> _tableColumns(String tableName) {
    final rows = db.select("SELECT name FROM pragma_table_info('$tableName')");
    return {for (final row in rows) row['name'] as String};
  }

  void _migrateChunksColumns() {
    final names = _tableColumns('story_memory_chunks');
    if (!names.contains('tier')) {
      db.execute(
        "ALTER TABLE story_memory_chunks ADD COLUMN tier TEXT NOT NULL DEFAULT 'scene'",
      );
    }
    if (!names.contains('producer')) {
      db.execute(
        "ALTER TABLE story_memory_chunks ADD COLUMN producer TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  bool _usesNormalizedAuthoringSchema() {
    final columns = _tableColumns('story_memory_chunks');
    return columns.isNotEmpty && !columns.contains('data');
  }

  void _validateNormalizedAuthoringSchema() {
    final version =
        db.select('PRAGMA user_version').single['user_version'] as int;
    final expectedVersion = authoringSchemaMigrations.last.version;
    final chunkColumns = _tableColumns('story_memory_chunks');
    final sourceColumns = _tableColumns('story_memory_sources');
    final thoughtColumns = _tableColumns('story_thought_atoms');
    if (version != expectedVersion ||
        !chunkColumns.containsAll(<String>{'tier', 'producer', 'owner_id'}) ||
        !sourceColumns.contains('raw_content') ||
        !thoughtColumns.contains('tier')) {
      throw StateError(
        'normalized story memory schema is not a complete authoring '
        'schema V$expectedVersion',
      );
    }
  }

  void _migrateThoughtColumns() {
    final names = _tableColumns('story_thought_atoms');
    if (!names.contains('data') && !names.contains('tier')) {
      db.execute(
        "ALTER TABLE story_thought_atoms ADD COLUMN tier TEXT NOT NULL DEFAULT 'scene'",
      );
    }
  }

  @override
  Future<void> saveSources(
    String projectId,
    List<StoryMemorySource> sources,
  ) async {
    await ensureTables();
    await writeCoordinator.synchronized<void>((_) {
      for (final source in sources) {
        if (_sourcesUseJsonRows) {
          db.execute(
            'INSERT INTO story_memory_sources (id, project_id, data) '
            'VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
            'project_id = excluded.project_id, data = excluded.data',
            [source.id, projectId, jsonEncode(source.toJson())],
          );
          continue;
        }
        db.execute(
          'INSERT INTO story_memory_sources '
          '(id, project_id, scope_id, source_kind, raw_content, metadata_json, '
          'created_at_ms) VALUES (?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET '
          'project_id = excluded.project_id, scope_id = excluded.scope_id, '
          'source_kind = excluded.source_kind, '
          'raw_content = excluded.raw_content, '
          'metadata_json = excluded.metadata_json, '
          'created_at_ms = excluded.created_at_ms',
          [
            source.id,
            projectId,
            source.scopeId,
            source.kind.name,
            source.content,
            jsonEncode({
              'sourceRefs': [for (final ref in source.sourceRefs) ref.toJson()],
              'rootSourceIds': source.rootSourceIds,
              'visibility': source.visibility.name,
              'ownerId': source.ownerId,
              'tags': source.tags,
              'priority': source.priority,
              'tokenCostEstimate': source.tokenCostEstimate,
            }),
            source.createdAtMs,
          ],
        );
      }
    });
  }

  @override
  Future<List<StoryMemorySource>> loadSources(String projectId) async {
    await ensureTables();
    if (_sourcesUseJsonRows) {
      final rows = db.select(
        'SELECT data FROM story_memory_sources '
        'WHERE project_id = ? ORDER BY id',
        [projectId],
      );
      return [
        for (final row in rows)
          StoryMemorySource.fromJson(_decodeMap(row['data'])),
      ];
    }
    final rows = db.select(
      'SELECT * FROM story_memory_sources '
      'WHERE project_id = ? ORDER BY id',
      [projectId],
    );
    return [
      for (final row in rows)
        StoryMemorySource.fromJson({
          ..._decodeMap(row['metadata_json']),
          'id': row['id'],
          'projectId': row['project_id'],
          'scopeId': row['scope_id'],
          'kind': row['source_kind'],
          'content': row['raw_content'],
          'createdAtMs': row['created_at_ms'],
        }),
    ];
  }

  @override
  Future<void> saveChunks(String projectId, List<StoryMemoryChunk> chunks) =>
      saveChunksCoordinated(projectId, chunks);

  /// [saveChunks] with an optional lease for a wider atomic write.
  Future<void> saveChunksCoordinated(
    String projectId,
    List<StoryMemoryChunk> chunks, {
    SqliteWriteLease? lease,
  }) async {
    await ensureTables(lease: lease);
    await writeCoordinator.synchronized<void>((_) {
      for (final chunk in chunks) {
        if (_chunksUseJsonRows) {
          db.execute(
            'INSERT INTO story_memory_chunks '
            '(id, project_id, tier, producer, data) VALUES (?, ?, ?, ?, ?) '
            'ON CONFLICT(id) DO UPDATE SET '
            'project_id = excluded.project_id, tier = excluded.tier, '
            'producer = excluded.producer, data = excluded.data',
            [
              chunk.id,
              projectId,
              chunk.tier.name,
              chunk.producer,
              jsonEncode(chunk.toJson()),
            ],
          );
          continue;
        }
        db.execute(
          'INSERT INTO story_memory_chunks '
          '(id, project_id, scope_id, chunk_kind, content, tier, producer, '
          'source_refs_json, root_source_ids_json, visibility, owner_id, '
          'tags_json, priority, token_cost_estimate, created_at_ms) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET '
          'project_id = excluded.project_id, scope_id = excluded.scope_id, '
          'chunk_kind = excluded.chunk_kind, content = excluded.content, '
          'tier = excluded.tier, producer = excluded.producer, '
          'source_refs_json = excluded.source_refs_json, '
          'root_source_ids_json = excluded.root_source_ids_json, '
          'visibility = excluded.visibility, owner_id = excluded.owner_id, '
          'tags_json = excluded.tags_json, '
          'priority = excluded.priority, '
          'token_cost_estimate = excluded.token_cost_estimate, '
          'created_at_ms = excluded.created_at_ms',
          [
            chunk.id,
            projectId,
            chunk.scopeId,
            chunk.kind.name,
            chunk.content,
            chunk.tier.name,
            chunk.producer,
            jsonEncode([for (final ref in chunk.sourceRefs) ref.toJson()]),
            jsonEncode(chunk.rootSourceIds),
            chunk.visibility.name,
            chunk.ownerId,
            jsonEncode(chunk.tags),
            chunk.priority,
            chunk.tokenCostEstimate,
            chunk.createdAtMs,
          ],
        );
      }
    }, lease: lease);
  }

  @override
  Future<List<StoryMemoryChunk>> loadChunks(
    String projectId, {
    SqliteWriteLease? lease,
  }) async {
    await ensureTables(lease: lease);
    if (_chunksUseJsonRows) {
      final rows = db.select(
        'SELECT data, tier, producer FROM story_memory_chunks '
        'WHERE project_id = ? ORDER BY id',
        [projectId],
      );
      return [
        for (final row in rows)
          StoryMemoryChunk.fromJson(
            _decodeLegacyChunk(
              row['data'],
              tier: row['tier'],
              producer: row['producer'],
            ),
          ),
      ];
    }
    final rows = db.select(
      'SELECT * FROM story_memory_chunks '
      'WHERE project_id = ? ORDER BY id',
      [projectId],
    );
    return [
      for (final row in rows)
        StoryMemoryChunk.fromJson({
          'id': row['id'],
          'projectId': row['project_id'],
          'scopeId': row['scope_id'],
          'kind': row['chunk_kind'],
          'content': row['content'],
          'tier': row['tier'],
          'producer': row['producer'],
          'sourceRefs': _decodeList(row['source_refs_json']),
          'rootSourceIds': _decodeList(row['root_source_ids_json']),
          'visibility': row['visibility'],
          'ownerId': row['owner_id'],
          'tags': _decodeList(row['tags_json']),
          'priority': row['priority'],
          'tokenCostEstimate': row['token_cost_estimate'],
          'createdAtMs': row['created_at_ms'],
        }),
    ];
  }

  @override
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

  /// Validates and snapshots an owned generation before acquiring a write lock.
  Future<StoryMemoryOwnedGenerationWrite> prepareOwnedGeneration({
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

    await ensureTables();
    return StoryMemoryOwnedGenerationWrite._(
      projectId: projectId,
      scopeId: scopeId,
      producer: normalizedProducer,
      chunks: List<StoryMemoryChunk>.unmodifiable(chunks),
      includeLegacyContextRows: includeLegacyContextRows,
    );
  }

  /// Commits a prepared generation while holding [lease].
  Future<void> commitOwnedGeneration(
    StoryMemoryOwnedGenerationWrite prepared, {
    required SqliteWriteLease lease,
  }) => writeCoordinator.synchronized<void>((_) async {
    await ensureTables(lease: lease);
    for (final chunk in prepared.chunks) {
      final collision = _ownedGenerationCollision(chunk.id);
      if (collision != null &&
          (collision.projectId != prepared.projectId ||
              collision.scopeId != prepared.scopeId ||
              collision.producer.trim() != prepared.producer)) {
        throw StateError(
          'Owned generation chunk ID ${chunk.id} is already used by another '
          'project, scope, or producer',
        );
      }
    }
    db.execute('SAVEPOINT story_memory_replace_owned_generation');
    try {
      final existing = await loadChunks(prepared.projectId, lease: lease);
      final ownedIds = <String>{
        for (final chunk in existing)
          if (_ownsGenerationChunk(
            chunk,
            projectId: prepared.projectId,
            scopeId: prepared.scopeId,
            producer: prepared.producer,
            includeLegacyContextRows: prepared.includeLegacyContextRows,
          ))
            chunk.id,
      };
      for (final id in ownedIds) {
        db.execute(
          'DELETE FROM story_memory_chunks WHERE project_id = ? AND id = ?',
          [prepared.projectId, id],
        );
      }
      await saveChunksCoordinated(
        prepared.projectId,
        prepared.chunks,
        lease: lease,
      );
      db.execute('RELEASE SAVEPOINT story_memory_replace_owned_generation');
    } catch (_) {
      db.execute('ROLLBACK TO SAVEPOINT story_memory_replace_owned_generation');
      db.execute('RELEASE SAVEPOINT story_memory_replace_owned_generation');
      rethrow;
    }
  }, lease: lease);

  StoryMemoryChunk? _ownedGenerationCollision(String id) {
    if (_chunksUseJsonRows) {
      final rows = db.select(
        'SELECT data, tier, producer FROM story_memory_chunks WHERE id = ?',
        [id],
      );
      if (rows.isEmpty) return null;
      final row = rows.single;
      return StoryMemoryChunk.fromJson(
        _decodeLegacyChunk(
          row['data'],
          tier: row['tier'],
          producer: row['producer'],
        ),
      );
    }
    final rows = db.select(
      'SELECT project_id, scope_id, producer FROM story_memory_chunks '
      'WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return StoryMemoryChunk(
      id: id,
      projectId: row['project_id']?.toString() ?? '',
      scopeId: row['scope_id']?.toString() ?? '',
      producer: row['producer']?.toString() ?? '',
      content: '',
      kind: MemorySourceKind.draft,
    );
  }

  @override
  Future<void> saveThoughts(
    String projectId,
    List<ThoughtAtom> thoughts,
  ) async {
    await ensureTables();
    await writeCoordinator.synchronized<void>((_) {
      for (final thought in thoughts) {
        if (_thoughtsUseJsonRows) {
          db.execute(
            'INSERT INTO story_thought_atoms (id, project_id, data) '
            'VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
            'project_id = excluded.project_id, data = excluded.data',
            [thought.id, projectId, jsonEncode(thought.toJson())],
          );
          continue;
        }
        db.execute(
          'INSERT INTO story_thought_atoms '
          '(id, project_id, scope_id, thought_type, content, tier, confidence, '
          'abstraction_level, source_refs_json, root_source_ids_json, tags_json, '
          'priority, token_cost_estimate, created_at_ms) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET '
          'project_id = excluded.project_id, scope_id = excluded.scope_id, '
          'thought_type = excluded.thought_type, content = excluded.content, '
          'tier = excluded.tier, confidence = excluded.confidence, '
          'abstraction_level = excluded.abstraction_level, '
          'source_refs_json = excluded.source_refs_json, '
          'root_source_ids_json = excluded.root_source_ids_json, '
          'tags_json = excluded.tags_json, priority = excluded.priority, '
          'token_cost_estimate = excluded.token_cost_estimate, '
          'created_at_ms = excluded.created_at_ms',
          [
            thought.id,
            projectId,
            thought.scopeId,
            thought.thoughtType.name,
            thought.content,
            thought.tier.name,
            thought.confidence,
            thought.abstractionLevel,
            jsonEncode([for (final ref in thought.sourceRefs) ref.toJson()]),
            jsonEncode(thought.rootSourceIds),
            jsonEncode(thought.tags),
            thought.priority,
            thought.tokenCostEstimate,
            thought.createdAtMs,
          ],
        );
      }
    });
  }

  @override
  Future<List<ThoughtAtom>> loadThoughts(String projectId) async {
    await ensureTables();
    if (_thoughtsUseJsonRows) {
      final rows = db.select(
        'SELECT data FROM story_thought_atoms '
        'WHERE project_id = ? ORDER BY id',
        [projectId],
      );
      return [
        for (final row in rows) ThoughtAtom.fromJson(_decodeMap(row['data'])),
      ];
    }
    final rows = db.select(
      'SELECT * FROM story_thought_atoms '
      'WHERE project_id = ? ORDER BY id',
      [projectId],
    );
    return [
      for (final row in rows)
        ThoughtAtom.fromJson({
          'id': row['id'],
          'projectId': row['project_id'],
          'scopeId': row['scope_id'],
          'thoughtType': row['thought_type'],
          'content': row['content'],
          'tier': row['tier'],
          'confidence': row['confidence'],
          'abstractionLevel': row['abstraction_level'],
          'sourceRefs': _decodeList(row['source_refs_json']),
          'rootSourceIds': _decodeList(row['root_source_ids_json']),
          'tags': _decodeList(row['tags_json']),
          'priority': row['priority'],
          'tokenCostEstimate': row['token_cost_estimate'],
          'createdAtMs': row['created_at_ms'],
        }),
    ];
  }

  @override
  Future<void> clearProject(String projectId) async {
    await ensureTables();
    await writeCoordinator.synchronized<void>((_) {
      db.execute('DELETE FROM story_memory_sources WHERE project_id = ?', [
        projectId,
      ]);
      db.execute('DELETE FROM story_memory_chunks WHERE project_id = ?', [
        projectId,
      ]);
      db.execute('DELETE FROM story_thought_atoms WHERE project_id = ?', [
        projectId,
      ]);
    });
  }
}

/// Immutable DB-ready owned-generation write prepared outside the write queue.
class StoryMemoryOwnedGenerationWrite {
  const StoryMemoryOwnedGenerationWrite._({
    required this.projectId,
    required this.scopeId,
    required this.producer,
    required this.chunks,
    required this.includeLegacyContextRows,
  });

  final String projectId;
  final String scopeId;
  final String producer;
  final List<StoryMemoryChunk> chunks;
  final bool includeLegacyContextRows;
}

bool _ownsGenerationChunk(
  StoryMemoryChunk chunk, {
  required String projectId,
  required String scopeId,
  required String producer,
  required bool includeLegacyContextRows,
}) {
  if (chunk.projectId != projectId || chunk.scopeId != scopeId) return false;
  if (chunk.producer.trim() == producer) return true;
  if (!includeLegacyContextRows || chunk.producer.trim().isNotEmpty) {
    return false;
  }
  return _isLegacyContextChunkId(chunk.id, projectId, chunk.kind);
}

bool _isLegacyContextChunkId(
  String id,
  String projectId,
  MemorySourceKind kind,
) {
  final code = switch (kind) {
    MemorySourceKind.worldFact => 'wf',
    MemorySourceKind.characterProfile => 'cp',
    MemorySourceKind.relationshipHint => 'rh',
    MemorySourceKind.outlineBeat => 'ob',
    MemorySourceKind.sceneSummary => 'ss',
    MemorySourceKind.acceptedState => 'as',
    MemorySourceKind.reviewFinding => 'rf',
    MemorySourceKind.draft => null,
  };
  if (code == null) return false;
  return RegExp('^${RegExp.escape(projectId)}_${code}_[0-9]+\$').hasMatch(id);
}

Map<String, Object?> _decodeMap(Object? value) {
  final decoded = _decodeJson(value, const <String, Object?>{});
  if (decoded is! Map) return const {};
  return {
    for (final entry in decoded.entries) entry.key.toString(): entry.value,
  };
}

List<Object?> _decodeList(Object? value) {
  final decoded = _decodeJson(value, const <Object?>[]);
  return decoded is List ? List<Object?>.from(decoded) : const [];
}

Map<String, Object?> _decodeLegacyChunk(
  Object? data, {
  Object? tier,
  Object? producer,
}) {
  final decoded = _decodeMap(data);
  decoded.putIfAbsent('tier', () => tier);
  decoded.putIfAbsent('producer', () => producer);
  return decoded;
}

Object? _decodeJson(Object? value, Object? fallback) {
  if (value is! String || value.isEmpty) return fallback;
  try {
    return jsonDecode(value);
  } on FormatException {
    return fallback;
  }
}
