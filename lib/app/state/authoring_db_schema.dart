import 'package:sqlite3/sqlite3.dart';

import 'db_schema_manager.dart';
import 'sql_identifier.dart';

const List<SchemaMigration> authoringSchemaMigrations = [
  SchemaMigration(
    version: 1,
    description:
        'Initial authoring schema: workspace, version, draft, '
        'ai_history, scene_context, json_blobs, story_memory tables. '
        'Includes legacy data migration from pre-versioned databases.',
    migrate: _migrateAuthoringV1,
  ),
  SchemaMigration(
    version: 2,
    description: 'Add roleplay session and character memory artifact tables.',
    migrate: _migrateAuthoringV2,
  ),
];

// ── Scope key used by legacy workspace migrations ──────────────────────────

const String _scopeKey = 'workspace-default';

// ── Version 1 migration ────────────────────────────────────────────────────

void _migrateAuthoringV1(Database db) {
  // 1. Legacy data migrations that DROP/recreate tables.
  //    They detect old column structures and only act if found.
  _migrateLegacyWorkspaceProjects(db);
  _migrateLegacyScopedTables(db);

  // 2. Ensure all workspace tables exist (IF NOT EXISTS).
  //    Required before the preference migration below which INSERTs into
  //    workspace_project_preferences.
  _createWorkspaceTables(db);

  // 3. Legacy preference migration (needs workspace_project_preferences).
  _migrateLegacyProjectPreferences(db);

  // 4. Legacy version/draft migrations (each recreates its own table).
  _migrateLegacyVersionEntries(db);
  _migrateLegacyDraftDocuments(db);

  // 5. Create all remaining tables (IF NOT EXISTS).
  _createVersionTables(db);
  _createDraftTables(db);
  _createAiHistoryTables(db);
  _createSceneContextTables(db);
  _createStoryOutlineSnapshotTable(db);
  _createStoryGenerationStateTable(db);
  _createStoryMemoryTables(db);
}

void _migrateAuthoringV2(Database db) {
  _createRoleplayArtifactTables(db);
}

// ── Table creation ─────────────────────────────────────────────────────────

void _createWorkspaceTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_projects (
      scope_key TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      title TEXT NOT NULL,
      genre TEXT NOT NULL,
      summary TEXT NOT NULL,
      recent_location TEXT NOT NULL,
      last_opened_at_ms INTEGER NOT NULL,
      PRIMARY KEY (scope_key, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_characters (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      name TEXT NOT NULL,
      role TEXT NOT NULL,
      note TEXT NOT NULL,
      need_text TEXT NOT NULL,
      summary TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_scenes (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      id TEXT NOT NULL,
      chapter_label TEXT NOT NULL,
      title TEXT NOT NULL,
      summary TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_world_nodes (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      title TEXT NOT NULL,
      location TEXT NOT NULL,
      type TEXT NOT NULL,
      detail TEXT NOT NULL,
      summary TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_audit_issues (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      title TEXT NOT NULL,
      evidence TEXT NOT NULL,
      target TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_preferences (
      scope_key TEXT NOT NULL,
      preference_key TEXT NOT NULL,
      preference_value TEXT NOT NULL,
      PRIMARY KEY (scope_key, preference_key)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_project_preferences (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      preference_key TEXT NOT NULL,
      preference_value TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, preference_key)
    )
  ''');
}

void _createVersionTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS version_entries (
      project_id TEXT NOT NULL,
      sequence_no INTEGER NOT NULL,
      label TEXT NOT NULL,
      content TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL,
      PRIMARY KEY (project_id, sequence_no)
    )
  ''');
}

void _createDraftTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS draft_documents (
      project_id TEXT PRIMARY KEY,
      text_body TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
}

void _createAiHistoryTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS ai_history_entries (
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      sequence_no INTEGER NOT NULL,
      mode TEXT NOT NULL,
      prompt TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL,
      PRIMARY KEY (project_id, position_no)
    )
  ''');
}

void _createSceneContextTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS scene_context_snapshots (
      project_id TEXT PRIMARY KEY,
      scene_summary TEXT NOT NULL,
      character_summary TEXT NOT NULL,
      world_summary TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
}

void _createStoryOutlineSnapshotTable(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_outline_snapshots (
      project_id TEXT PRIMARY KEY,
      snapshot_json TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
}

void _createStoryGenerationStateTable(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_state (
      project_id TEXT PRIMARY KEY,
      payload_json TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
}

void _createStoryMemoryTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_memory_sources (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      source_kind TEXT NOT NULL,
      raw_content TEXT NOT NULL,
      metadata_json TEXT NOT NULL DEFAULT '{}',
      created_at_ms INTEGER NOT NULL DEFAULT 0
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_memory_chunks (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      chunk_kind TEXT NOT NULL,
      content TEXT NOT NULL,
      source_refs_json TEXT NOT NULL DEFAULT '[]',
      root_source_ids_json TEXT NOT NULL DEFAULT '[]',
      visibility TEXT NOT NULL DEFAULT 'publicObservable',
      tags_json TEXT NOT NULL DEFAULT '[]',
      priority INTEGER NOT NULL DEFAULT 0,
      token_cost_estimate INTEGER NOT NULL DEFAULT 0,
      created_at_ms INTEGER NOT NULL DEFAULT 0
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_thought_atoms (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      thought_type TEXT NOT NULL,
      content TEXT NOT NULL,
      confidence REAL NOT NULL DEFAULT 0.0,
      abstraction_level REAL NOT NULL DEFAULT 1.0,
      source_refs_json TEXT NOT NULL DEFAULT '[]',
      root_source_ids_json TEXT NOT NULL DEFAULT '[]',
      tags_json TEXT NOT NULL DEFAULT '[]',
      priority INTEGER NOT NULL DEFAULT 0,
      token_cost_estimate INTEGER NOT NULL DEFAULT 0,
      created_at_ms INTEGER NOT NULL DEFAULT 0
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_memory_sources_project
    ON story_memory_sources(project_id)
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_memory_chunks_project
    ON story_memory_chunks(project_id)
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_thought_atoms_project
    ON story_thought_atoms(project_id)
  ''');
}

void _createRoleplayArtifactTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS character_memories (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      character_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      content TEXT NOT NULL,
      source_round INTEGER NOT NULL,
      source_turn_id TEXT NOT NULL,
      confidence REAL NOT NULL,
      data TEXT NOT NULL
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_character_memories_project_character
    ON character_memories (project_id, character_id)
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_character_memories_project
    ON character_memories (project_id)
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_sessions (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      scene_title TEXT NOT NULL,
      final_public_state TEXT NOT NULL
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_roleplay_sessions_project_chapter
    ON roleplay_sessions (project_id, chapter_id)
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_rounds (
      session_id TEXT NOT NULL,
      round INTEGER NOT NULL,
      PRIMARY KEY (session_id, round)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_turns (
      session_id TEXT NOT NULL,
      round INTEGER NOT NULL,
      turn_order INTEGER NOT NULL,
      character_id TEXT NOT NULL,
      name TEXT NOT NULL,
      intent TEXT NOT NULL,
      visible_action TEXT NOT NULL,
      dialogue TEXT NOT NULL,
      inner_state TEXT NOT NULL,
      prose_fragment TEXT NOT NULL DEFAULT '',
      taboo TEXT NOT NULL,
      raw_text TEXT NOT NULL,
      skill_id TEXT NOT NULL,
      skill_version TEXT NOT NULL,
      proposed_memory_deltas TEXT NOT NULL,
      PRIMARY KEY (session_id, round, turn_order)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_arbitrations (
      session_id TEXT NOT NULL,
      round INTEGER NOT NULL,
      fact TEXT NOT NULL,
      state TEXT NOT NULL,
      pressure TEXT NOT NULL,
      next_public_state TEXT NOT NULL,
      should_stop INTEGER NOT NULL,
      raw_text TEXT NOT NULL,
      skill_id TEXT NOT NULL,
      skill_version TEXT NOT NULL,
      accepted_memory_deltas TEXT NOT NULL,
      rejected_memory_deltas TEXT NOT NULL,
      PRIMARY KEY (session_id, round)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_committed_facts (
      session_id TEXT NOT NULL,
      sequence_id INTEGER NOT NULL,
      round INTEGER NOT NULL,
      source TEXT NOT NULL,
      content TEXT NOT NULL,
      previous_hash TEXT NOT NULL,
      content_hash TEXT NOT NULL,
      PRIMARY KEY (session_id, sequence_id)
    )
  ''');
}

// ── Legacy data migrations ─────────────────────────────────────────────────

void _migrateLegacyWorkspaceProjects(Database db) {
  final rows = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'workspace_projects'",
  );
  if (rows.isEmpty) return;

  final columns = db.select('PRAGMA table_info(workspace_projects)');
  final columnNames = columns.map((r) => r['name'] as String).toSet();
  if (columnNames.contains('id') &&
      columnNames.contains('scene_id') &&
      columnNames.contains('last_opened_at_ms')) {
    return;
  }

  final legacyProjects = db.select(
    '''
    SELECT position_no, title, genre, summary, recent_location
    FROM workspace_projects
    WHERE scope_key = ?
    ORDER BY position_no ASC
    ''',
    [_scopeKey],
  );

  db.execute('DROP TABLE workspace_projects');
  db.execute('''
    CREATE TABLE workspace_projects (
      scope_key TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      title TEXT NOT NULL,
      genre TEXT NOT NULL,
      summary TEXT NOT NULL,
      recent_location TEXT NOT NULL,
      last_opened_at_ms INTEGER NOT NULL,
      PRIMARY KEY (scope_key, position_no)
    )
  ''');

  final now = DateTime.now();
  for (final row in legacyProjects) {
    final position = row['position_no'] as int;
    db.execute(
      '''
      INSERT INTO workspace_projects (
        scope_key, position_no, id, scene_id, title, genre, summary,
        recent_location, last_opened_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        _scopeKey,
        position,
        _legacyProjectIdForPosition(position),
        _legacySceneIdForRow(position, row['recent_location'] as String),
        row['title'] as String,
        row['genre'] as String,
        row['summary'] as String,
        row['recent_location'] as String,
        now.subtract(Duration(days: position)).millisecondsSinceEpoch,
      ],
    );
  }
}

void _migrateLegacyScopedTables(Database db) {
  _migrateLegacyScopedTable(
    db: db,
    tableName: 'workspace_characters',
    createSql: '''
      CREATE TABLE workspace_characters (
        scope_key TEXT NOT NULL,
        project_id TEXT NOT NULL,
        position_no INTEGER NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        note TEXT NOT NULL,
        need_text TEXT NOT NULL,
        summary TEXT NOT NULL,
        PRIMARY KEY (scope_key, project_id, position_no)
      )
    ''',
    selectSql:
        'SELECT position_no, name, role, note, need_text, summary '
        'FROM workspace_characters WHERE scope_key = ? ORDER BY position_no ASC',
    insertSql: '''
      INSERT INTO workspace_characters (
        scope_key, project_id, position_no, name, role, note, need_text, summary
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    valuesBuilder: (row, projectId) => [
      _scopeKey,
      projectId,
      row['position_no'] as int,
      row['name'] as String,
      row['role'] as String,
      row['note'] as String,
      row['need_text'] as String,
      row['summary'] as String,
    ],
  );
  _migrateLegacyScopedTable(
    db: db,
    tableName: 'workspace_scenes',
    createSql: '''
      CREATE TABLE workspace_scenes (
        scope_key TEXT NOT NULL,
        project_id TEXT NOT NULL,
        position_no INTEGER NOT NULL,
        id TEXT NOT NULL,
        chapter_label TEXT NOT NULL,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        PRIMARY KEY (scope_key, project_id, position_no)
      )
    ''',
    selectSql:
        'SELECT position_no, id, chapter_label, title, summary '
        'FROM workspace_scenes WHERE scope_key = ? ORDER BY position_no ASC',
    insertSql: '''
      INSERT INTO workspace_scenes (
        scope_key, project_id, position_no, id, chapter_label, title, summary
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
    valuesBuilder: (row, projectId) => [
      _scopeKey,
      projectId,
      row['position_no'] as int,
      row['id'] as String,
      row['chapter_label'] as String,
      row['title'] as String,
      row['summary'] as String,
    ],
  );
  _migrateLegacyScopedTable(
    db: db,
    tableName: 'workspace_world_nodes',
    createSql: '''
      CREATE TABLE workspace_world_nodes (
        scope_key TEXT NOT NULL,
        project_id TEXT NOT NULL,
        position_no INTEGER NOT NULL,
        title TEXT NOT NULL,
        location TEXT NOT NULL,
        type TEXT NOT NULL,
        detail TEXT NOT NULL,
        summary TEXT NOT NULL,
        PRIMARY KEY (scope_key, project_id, position_no)
      )
    ''',
    selectSql:
        'SELECT position_no, title, location, type, detail, summary '
        'FROM workspace_world_nodes WHERE scope_key = ? ORDER BY position_no ASC',
    insertSql: '''
      INSERT INTO workspace_world_nodes (
        scope_key, project_id, position_no, title, location, type, detail, summary
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    valuesBuilder: (row, projectId) => [
      _scopeKey,
      projectId,
      row['position_no'] as int,
      row['title'] as String,
      row['location'] as String,
      row['type'] as String,
      row['detail'] as String,
      row['summary'] as String,
    ],
  );
  _migrateLegacyScopedTable(
    db: db,
    tableName: 'workspace_audit_issues',
    createSql: '''
      CREATE TABLE workspace_audit_issues (
        scope_key TEXT NOT NULL,
        project_id TEXT NOT NULL,
        position_no INTEGER NOT NULL,
        title TEXT NOT NULL,
        evidence TEXT NOT NULL,
        target TEXT NOT NULL,
        PRIMARY KEY (scope_key, project_id, position_no)
      )
    ''',
    selectSql:
        'SELECT position_no, title, evidence, target '
        'FROM workspace_audit_issues WHERE scope_key = ? ORDER BY position_no ASC',
    insertSql: '''
      INSERT INTO workspace_audit_issues (
        scope_key, project_id, position_no, title, evidence, target
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''',
    valuesBuilder: (row, projectId) => [
      _scopeKey,
      projectId,
      row['position_no'] as int,
      row['title'] as String,
      row['evidence'] as String,
      row['target'] as String,
    ],
  );
}

void _migrateLegacyScopedTable({
  required Database db,
  required String tableName,
  required String createSql,
  required String selectSql,
  required String insertSql,
  required List<Object?> Function(Row row, String projectId) valuesBuilder,
}) {
  final safeTableName = checkedSqlIdentifier(tableName);
  final rows = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [safeTableName],
  );
  if (rows.isEmpty) return;

  final columns = db.select(
    'PRAGMA table_info(${quotedSqlIdentifier(safeTableName)})',
  );
  final columnNames = columns.map((r) => r['name'] as String).toSet();
  if (columnNames.contains('project_id')) return;

  final legacyRows = db.select(selectSql, [_scopeKey]);
  final projectIds = db
      .select(
        'SELECT id FROM workspace_projects WHERE scope_key = ? ORDER BY position_no ASC',
        [_scopeKey],
      )
      .map((r) => r['id'] as String)
      .toList(growable: false);

  db.execute('DROP TABLE ${quotedSqlIdentifier(safeTableName)}');
  db.execute(createSql);

  for (final projectId in projectIds) {
    for (final row in legacyRows) {
      db.execute(insertSql, valuesBuilder(row, projectId));
    }
  }
}

void _migrateLegacyProjectPreferences(Database db) {
  final legacyKeys = db.select(
    '''
    SELECT preference_key, preference_value
    FROM workspace_preferences
    WHERE scope_key = ?
      AND preference_key IN (
        'style_input_mode',
        'style_intensity',
        'style_binding_feedback',
        'selected_audit_issue_index',
        'audit_action_feedback'
      )
    ''',
    [_scopeKey],
  );
  if (legacyKeys.isEmpty) return;

  final projectIds = db
      .select('SELECT id FROM workspace_projects WHERE scope_key = ?', [
        _scopeKey,
      ])
      .map((r) => r['id'] as String)
      .toList(growable: false);

  for (final projectId in projectIds) {
    for (final row in legacyKeys) {
      db.execute(
        '''
        INSERT OR REPLACE INTO workspace_project_preferences (
          scope_key, project_id, preference_key, preference_value
        ) VALUES (?, ?, ?, ?)
        ''',
        [
          _scopeKey,
          projectId,
          row['preference_key'] as String,
          row['preference_value'] as String,
        ],
      );
    }
  }

  db.execute(
    '''
    DELETE FROM workspace_preferences
    WHERE scope_key = ?
      AND preference_key IN (
        'style_input_mode',
        'style_intensity',
        'style_binding_feedback',
        'selected_audit_issue_index',
        'audit_action_feedback'
      )
    ''',
    [_scopeKey],
  );
}

void _migrateLegacyVersionEntries(Database db) {
  final rows = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'version_entries'",
  );
  if (rows.isEmpty) return;

  final columns = db.select('PRAGMA table_info(version_entries)');
  final columnNames = columns.map((r) => r['name'] as String).toSet();
  if (columnNames.contains('project_id')) return;

  final legacyRows = db.select(
    'SELECT sequence_no, label, content, updated_at_ms FROM version_entries ORDER BY sequence_no ASC',
  );
  db.execute('DROP TABLE version_entries');
  _createVersionTables(db);
  for (final row in legacyRows) {
    db.execute(
      '''
      INSERT INTO version_entries (
        project_id, sequence_no, label, content, updated_at_ms
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      [
        'project-yuechao',
        row['sequence_no'] as int,
        row['label'] as String,
        row['content'] as String,
        row['updated_at_ms'] as int,
      ],
    );
  }
}

void _migrateLegacyDraftDocuments(Database db) {
  final rows = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'draft_documents'",
  );
  if (rows.isEmpty) return;

  final columns = db.select('PRAGMA table_info(draft_documents)');
  final columnNames = columns.map((r) => r['name'] as String).toSet();
  if (columnNames.contains('project_id')) return;

  final legacyRows = db.select(
    'SELECT text_body, updated_at_ms FROM draft_documents',
  );
  db.execute('DROP TABLE draft_documents');
  _createDraftTables(db);
  if (legacyRows.isNotEmpty) {
    db.execute(
      '''
      INSERT INTO draft_documents (project_id, text_body, updated_at_ms)
      VALUES (?, ?, ?)
      ''',
      [
        'project-yuechao',
        legacyRows.first['text_body'] as String,
        legacyRows.first['updated_at_ms'] as int,
      ],
    );
  }
}

// ── Legacy helpers ──────────────────────────────────────────────────────────

String _legacyProjectIdForPosition(int position) {
  return switch (position) {
    0 => 'project-yuechao',
    1 => 'project-yangang',
    2 => 'project-huijin',
    _ => 'project-migrated-$position',
  };
}

String _legacySceneIdForRow(int position, String recentLocation) {
  final match = RegExp(r'场景\s*(\d+)').firstMatch(recentLocation);
  if (match == null) {
    return 'scene-01-migrated-$position';
  }
  final number = match.group(1)!.padLeft(2, '0');
  return 'scene-$number-migrated-$position';
}
