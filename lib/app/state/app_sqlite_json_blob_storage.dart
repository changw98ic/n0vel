import 'dart:convert';
import 'dart:isolate';

import 'app_authoring_storage_io_support.dart';
import 'storage_write_verification.dart';

/// Generic SQLite storage that persists a single JSON blob per project.
///
/// Used by [StoryGenerationStorage] and [StoryOutlineStorage] which share
/// identical load/save/clear logic differing only in table/column names.
class SqliteJsonBlobStorage {
  SqliteJsonBlobStorage({
    required String dbPath,
    required String tableName,
    required String jsonColumn,
  }) : _dbPath = dbPath,
       _tableName = tableName,
       _jsonColumn = jsonColumn {
    checkedSqlIdentifier(tableName);
    checkedSqlIdentifier(jsonColumn);
  }

  final String _dbPath;
  final String _tableName;
  final String _jsonColumn;

  Future<Map<String, Object?>?> load({required String projectId}) async {
    return Isolate.run(() {
      return withAuthoringDb(_dbPath, (db) {
        final rows = db.select(
          'SELECT $_jsonColumn FROM $_tableName WHERE project_id = ? LIMIT 1',
          [projectId],
        );
        if (rows.isEmpty) return null;

        final decoded = jsonDecode(rows.first[_jsonColumn] as String);
        if (decoded is! Map) return null;

        return {
          for (final entry in decoded.entries)
            entry.key.toString(): entry.value as Object?,
          'projectId': decoded['projectId']?.toString() ?? projectId,
        };
      });
    });
  }

  Future<void> save(Map<String, Object?> data, {required String projectId}) {
    return verifyAfterWrite(
      label: '$_tableName:$projectId',
      save: (d) async => _writeToDb(d, projectId: projectId),
      reload: () => load(projectId: projectId),
      data: data,
    );
  }

  /// Writes [data] to the database without verification.
  Future<void> _writeToDb(Map<String, Object?> data, {required String projectId}) {
    return Isolate.run(() {
      withAuthoringDb(_dbPath, (db) {
        db.execute(
          '''
          INSERT INTO $_tableName (project_id, $_jsonColumn, updated_at_ms)
          VALUES (?, ?, ?)
          ON CONFLICT(project_id) DO UPDATE SET
            $_jsonColumn = excluded.$_jsonColumn,
            updated_at_ms = excluded.updated_at_ms
          ''',
          [
            projectId,
            jsonEncode({
              for (final entry in data.entries) entry.key: entry.value,
              'projectId': data['projectId']?.toString() ?? projectId,
            }),
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
      });
    });
  }

  Future<void> clear({String? projectId}) async {
    await Isolate.run(() {
      withAuthoringDb(_dbPath, (db) {
        clearByProject(db, _tableName, projectId: projectId);
      });
    });
  }

  Future<void> clearProject(String projectId) async {
    await Isolate.run(() {
      withAuthoringDb(_dbPath, (db) {
        clearByProjectScope(db, _tableName, projectId);
      });
    });
  }
}
