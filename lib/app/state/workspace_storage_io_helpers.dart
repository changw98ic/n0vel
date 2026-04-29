import 'package:sqlite3/sqlite3.dart' as sqlite3;

class WorkspaceStorageHelpers {
  static Map<String, List<Map<String, Object?>>> groupRowsByProject({
    required List<sqlite3.Row> rows,
    required Map<String, Object?> Function(sqlite3.Row row) rowMapper,
  }) {
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final projectId = row['project_id'] as String;
      grouped.putIfAbsent(projectId, () => <Map<String, Object?>>[]);
      grouped[projectId]!.add(rowMapper(row));
    }
    return grouped;
  }

  static Map<String, Map<String, Object?>> groupProjectPreferences({
    required List<sqlite3.Row> rows,
    required Set<String> keys,
    required Map<String, String> rename,
  }) {
    final grouped = <String, Map<String, Object?>>{};
    for (final row in rows) {
      final key = row['preference_key'] as String;
      if (!keys.contains(key)) {
        continue;
      }
      final projectId = row['project_id'] as String;
      grouped.putIfAbsent(projectId, () => <String, Object?>{});
      grouped[projectId]![rename[key]!] = row['preference_value'] as String;
    }
    return grouped;
  }

  static void insertProjectRows(
    sqlite3.Database database,
    String scopeKey,
    List<Object?> projects,
  ) {
    final stmt = database.prepare(
      '''
      INSERT INTO workspace_projects (
        scope_key, position_no, id, scene_id, title, genre, summary, recent_location, last_opened_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
    );
    try {
      for (var index = 0; index < projects.length; index++) {
        final row = projects[index];
        if (row is! Map) {
          continue;
        }
        stmt.execute([
          scopeKey,
          index,
          row['id']?.toString() ?? '',
          row['sceneId']?.toString() ?? '',
          row['title']?.toString() ?? '',
          row['genre']?.toString() ?? '',
          row['summary']?.toString() ?? '',
          row['recentLocation']?.toString() ?? '',
          int.tryParse(row['lastOpenedAtMs']?.toString() ?? '') ?? 0,
        ]);
      }
    } finally {
      stmt.dispose();
    }
  }

  static void insertProjectScopedRows({
    required sqlite3.Database database,
    required String scopeKey,
    required String tableName,
    required Map<Object?, Object?> rowsByProject,
    required List<String> columnNames,
    required List<Object?> Function(Map row) valuesBuilder,
  }) {
    final columns = ['scope_key', 'project_id', 'position_no', ...columnNames];
    final placeholders = List.filled(columns.length, '?').join(', ');
    final sql =
        'INSERT INTO $tableName (${columns.join(', ')}) VALUES ($placeholders)';
    final stmt = database.prepare(sql);
    try {
      for (final entry in rowsByProject.entries) {
        final projectId = entry.key.toString();
        final rows = entry.value;
        if (rows is! List) {
          continue;
        }
        for (var index = 0; index < rows.length; index++) {
          final row = rows[index];
          if (row is! Map) {
            continue;
          }
          stmt.execute([
            scopeKey,
            projectId,
            index,
            ...valuesBuilder(row),
          ]);
        }
      }
    } finally {
      stmt.dispose();
    }
  }

  static void insertProjectPreferences({
    required sqlite3.Database database,
    required String scopeKey,
    required Map<Object?, Object?> preferencesByProject,
    required Map<String, String> rename,
  }) {
    final stmt = database.prepare(
      '''
      INSERT INTO workspace_project_preferences (
        scope_key, project_id, preference_key, preference_value
      ) VALUES (?, ?, ?, ?)
      ''',
    );
    try {
      for (final entry in preferencesByProject.entries) {
        final projectId = entry.key.toString();
        final values = entry.value;
        if (values is! Map) {
          continue;
        }
        for (final preferenceEntry in values.entries) {
          final preferenceKey = rename[preferenceEntry.key.toString()];
          if (preferenceKey == null) {
            continue;
          }
          stmt.execute([
            scopeKey,
            projectId,
            preferenceKey,
            preferenceEntry.value?.toString() ?? '',
          ]);
        }
      }
    } finally {
      stmt.dispose();
    }
  }
}
