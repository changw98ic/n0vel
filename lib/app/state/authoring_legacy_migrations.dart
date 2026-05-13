import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/domain/workspace_models.dart';
import 'authoring_table_definitions.dart';
import 'sql_identifier.dart';

// ── Scope key used by legacy workspace migrations ──────────────────────────

const String legacyScopeKey = 'workspace-default';

// ── Legacy data migrations ─────────────────────────────────────────────────

void migrateLegacyWorkspaceProjects(Database db) {
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
    [legacyScopeKey],
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
        legacyScopeKey,
        position,
        legacyProjectIdForPosition(position),
        legacySceneIdForRow(position, row['recent_location'] as String),
        row['title'] as String,
        row['genre'] as String,
        row['summary'] as String,
        row['recent_location'] as String,
        now.subtract(Duration(days: position)).millisecondsSinceEpoch,
      ],
    );
  }
}

void migrateLegacyScopedTables(Database db) {
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
      legacyScopeKey,
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
      legacyScopeKey,
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
      legacyScopeKey,
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
      legacyScopeKey,
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

  final legacyRows = db.select(selectSql, [legacyScopeKey]);
  final projectIds = db
      .select(
        'SELECT id FROM workspace_projects WHERE scope_key = ? ORDER BY position_no ASC',
        [legacyScopeKey],
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

void migrateLegacyProjectPreferences(Database db) {
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
    [legacyScopeKey],
  );
  if (legacyKeys.isEmpty) return;

  final projectIds = db
      .select('SELECT id FROM workspace_projects WHERE scope_key = ?', [
        legacyScopeKey,
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
          legacyScopeKey,
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
    [legacyScopeKey],
  );
}

void migrateLegacyVersionEntries(Database db) {
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
  createVersionTables(db);
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

void migrateLegacyDraftDocuments(Database db) {
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
  createDraftTables(db);
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

String legacyProjectIdForPosition(int position) {
  return switch (position) {
    0 => 'project-yuechao',
    1 => 'project-yangang',
    2 => 'project-huijin',
    _ => 'project-migrated-$position',
  };
}

String legacySceneIdForRow(int position, String recentLocation) {
  final sceneNumber = SceneLocationParts.firstSceneNumberIn(recentLocation);
  if (sceneNumber == null) {
    return 'scene-01-migrated-$position';
  }
  final number = sceneNumber.toString().padLeft(2, '0');
  return 'scene-$number-migrated-$position';
}
