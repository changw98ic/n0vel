import 'dart:convert';

import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../../../app/state/app_authoring_storage_io_support.dart';
import 'author_feedback_storage.dart';

class SqliteAuthorFeedbackStorage implements AuthorFeedbackStorage {
  SqliteAuthorFeedbackStorage({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    final database = _openDatabase();
    try {
      final rows = database.select(
        '''
        SELECT payload_json
        FROM author_feedback_projects
        WHERE project_id = ?
        ''',
        [projectId],
      );
      if (rows.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(rows.first['payload_json'] as String);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
      return null;
    } finally {
      database.dispose();
    }
  }

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    final database = _openDatabase();
    try {
      database.execute(
        '''
        INSERT OR REPLACE INTO author_feedback_projects (
          project_id, payload_json, updated_at_ms
        ) VALUES (?, ?, ?)
        ''',
        [projectId, jsonEncode(data), DateTime.now().millisecondsSinceEpoch],
      );
    } finally {
      database.dispose();
    }
  }

  @override
  Future<void> clear({String? projectId}) async {
    final database = _openDatabase();
    try {
      if (projectId == null) {
        database.execute('DELETE FROM author_feedback_projects');
      } else {
        database.execute(
          'DELETE FROM author_feedback_projects WHERE project_id = ?',
          [projectId],
        );
      }
    } finally {
      database.dispose();
    }
  }

  sqlite3.Database _openDatabase() {
    final database = openAuthoringDatabase(_dbPath);
    database.execute('''
      CREATE TABLE IF NOT EXISTS author_feedback_projects (
        project_id TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
      ''');
    return database;
  }
}

AuthorFeedbackStorage createAuthorFeedbackStorage() =>
    SqliteAuthorFeedbackStorage();
