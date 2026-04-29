import 'package:sqlite3/sqlite3.dart' as sqlite3;

class WorkspaceSchema {
  static void ensureSchema(sqlite3.Database database) {
    database.execute(
      '''
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
      ''',
    );
    database.execute(
      '''
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
      ''',
    );
    database.execute(
      '''
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
      ''',
    );
    database.execute(
      '''
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
      ''',
    );
    database.execute(
      '''
      CREATE TABLE IF NOT EXISTS workspace_audit_issues (
        scope_key TEXT NOT NULL,
        project_id TEXT NOT NULL,
        position_no INTEGER NOT NULL,
        title TEXT NOT NULL,
        evidence TEXT NOT NULL,
        target TEXT NOT NULL,
        PRIMARY KEY (scope_key, project_id, position_no)
      )
      ''',
    );
    database.execute(
      '''
      CREATE TABLE IF NOT EXISTS workspace_preferences (
        scope_key TEXT NOT NULL,
        preference_key TEXT NOT NULL,
        preference_value TEXT NOT NULL,
        PRIMARY KEY (scope_key, preference_key)
      )
      ''',
    );
    database.execute(
      '''
      CREATE TABLE IF NOT EXISTS workspace_project_preferences (
        scope_key TEXT NOT NULL,
        project_id TEXT NOT NULL,
        preference_key TEXT NOT NULL,
        preference_value TEXT NOT NULL,
        PRIMARY KEY (scope_key, project_id, preference_key)
      )
      ''',
    );
    _ensureIndexes(database);
  }

  static void _ensureIndexes(sqlite3.Database database) {
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_workspace_characters_scope_project '
      'ON workspace_characters (scope_key, project_id)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_workspace_scenes_scope_project '
      'ON workspace_scenes (scope_key, project_id)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_workspace_world_nodes_scope_project '
      'ON workspace_world_nodes (scope_key, project_id)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_workspace_audit_issues_scope_project '
      'ON workspace_audit_issues (scope_key, project_id)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_workspace_project_preferences_scope_project '
      'ON workspace_project_preferences (scope_key, project_id)',
    );
  }

  static void migrateLegacyProjectSchema(
    sqlite3.Database database,
    String scopeKey,
  ) {
    final rows = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'workspace_projects'",
    );
    if (rows.isEmpty) {
      return;
    }
    final columns = database.select('PRAGMA table_info(workspace_projects)');
    final columnNames = columns.map((row) => row['name'] as String).toSet();
    if (columnNames.contains('id') &&
        columnNames.contains('scene_id') &&
        columnNames.contains('last_opened_at_ms')) {
      return;
    }

    final legacyProjects = database.select(
      '''
      SELECT position_no, title, genre, summary, recent_location
      FROM workspace_projects
      WHERE scope_key = ?
      ORDER BY position_no ASC
      ''',
      [scopeKey],
    );

    database.execute('DROP TABLE workspace_projects');
    database.execute(
      '''
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
      ''',
    );

    final now = DateTime.now();
    for (final row in legacyProjects) {
      final position = row['position_no'] as int;
      database.execute(
        '''
        INSERT INTO workspace_projects (
          scope_key, position_no, id, scene_id, title, genre, summary, recent_location, last_opened_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          scopeKey,
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

  static void migrateLegacyScopedTables(
    sqlite3.Database database,
    String scopeKey,
  ) {
    _migrateLegacyScopedTable(
      database: database,
      scopeKey: scopeKey,
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
          'SELECT position_no, name, role, note, need_text, summary FROM workspace_characters WHERE scope_key = ? ORDER BY position_no ASC',
      insertSql: '''
        INSERT INTO workspace_characters (
          scope_key, project_id, position_no, name, role, note, need_text, summary
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      valuesBuilder: (row, projectId) => [
        scopeKey,
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
      database: database,
      scopeKey: scopeKey,
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
          'SELECT position_no, id, chapter_label, title, summary FROM workspace_scenes WHERE scope_key = ? ORDER BY position_no ASC',
      insertSql: '''
        INSERT INTO workspace_scenes (
          scope_key, project_id, position_no, id, chapter_label, title, summary
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      valuesBuilder: (row, projectId) => [
        scopeKey,
        projectId,
        row['position_no'] as int,
        row['id'] as String,
        row['chapter_label'] as String,
        row['title'] as String,
        row['summary'] as String,
      ],
    );
    _migrateLegacyScopedTable(
      database: database,
      scopeKey: scopeKey,
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
          'SELECT position_no, title, location, type, detail, summary FROM workspace_world_nodes WHERE scope_key = ? ORDER BY position_no ASC',
      insertSql: '''
        INSERT INTO workspace_world_nodes (
          scope_key, project_id, position_no, title, location, type, detail, summary
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      valuesBuilder: (row, projectId) => [
        scopeKey,
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
      database: database,
      scopeKey: scopeKey,
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
          'SELECT position_no, title, evidence, target FROM workspace_audit_issues WHERE scope_key = ? ORDER BY position_no ASC',
      insertSql: '''
        INSERT INTO workspace_audit_issues (
          scope_key, project_id, position_no, title, evidence, target
        ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      valuesBuilder: (row, projectId) => [
        scopeKey,
        projectId,
        row['position_no'] as int,
        row['title'] as String,
        row['evidence'] as String,
        row['target'] as String,
      ],
    );
  }

  static void _migrateLegacyScopedTable({
    required sqlite3.Database database,
    required String scopeKey,
    required String tableName,
    required String createSql,
    required String selectSql,
    required String insertSql,
    required List<Object?> Function(sqlite3.Row row, String projectId)
    valuesBuilder,
  }) {
    final rows = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    if (rows.isEmpty) {
      return;
    }

    final columns = database.select('PRAGMA table_info($tableName)');
    final columnNames = columns.map((row) => row['name'] as String).toSet();
    if (columnNames.contains('project_id')) {
      return;
    }

    final legacyRows = database.select(selectSql, [scopeKey]);
    final projectIds = database
        .select(
          'SELECT id FROM workspace_projects WHERE scope_key = ? ORDER BY position_no ASC',
          [scopeKey],
        )
        .map((row) => row['id'] as String)
        .toList(growable: false);

    database.execute('DROP TABLE $tableName');
    database.execute(createSql);

    for (final projectId in projectIds) {
      for (final row in legacyRows) {
        database.execute(insertSql, valuesBuilder(row, projectId));
      }
    }
  }

  static void migrateLegacyProjectPreferences(
    sqlite3.Database database,
    String scopeKey,
  ) {
    final legacyKeys = database.select(
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
      [scopeKey],
    );
    if (legacyKeys.isEmpty) {
      return;
    }

    final projectIds = database
        .select(
          'SELECT id FROM workspace_projects WHERE scope_key = ?',
          [scopeKey],
        )
        .map((row) => row['id'] as String)
        .toList(growable: false);

    for (final projectId in projectIds) {
      for (final row in legacyKeys) {
        database.execute(
          '''
          INSERT OR REPLACE INTO workspace_project_preferences (
            scope_key, project_id, preference_key, preference_value
          ) VALUES (?, ?, ?, ?)
          ''',
          [
            scopeKey,
            projectId,
            row['preference_key'] as String,
            row['preference_value'] as String,
          ],
        );
      }
    }

    database.execute(
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
      [scopeKey],
    );
  }
}

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
