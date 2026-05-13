import 'dart:convert';

import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../logging/app_log.dart';
import 'app_authoring_storage_io_support.dart';
import 'story_generation_run_storage.dart';

class SqliteStoryGenerationRunStorage implements StoryGenerationRunStorage {
  SqliteStoryGenerationRunStorage({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;
  sqlite3.Database? _database;

  sqlite3.Database _getDatabase() {
    final existing = _database;
    if (existing != null) {
      try {
        existing.select('SELECT 1');
        return existing;
      } catch (error) {
        AppLog.w(
          'Reopening stale story generation run database after health check failure: $error',
          tag: 'StoryGenerationRunStorage',
        );
        _database = null;
        try {
          existing.dispose();
        } catch (disposeError) {
          AppLog.w(
            'Failed to dispose stale story generation run database: $disposeError',
            tag: 'StoryGenerationRunStorage',
          );
        }
      }
    }
    final database = openAuthoringDatabase(_dbPath);
    database.execute('''
      CREATE TABLE IF NOT EXISTS story_generation_run_state (
        scene_scope_id TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    _database = database;
    return database;
  }

  @override
  Future<Map<String, Object?>?> load({required String sceneScopeId}) async {
    final database = _getDatabase();
    final rows = database.select(
      '''
      SELECT payload_json
      FROM story_generation_run_state
      WHERE scene_scope_id = ?
      LIMIT 1
      ''',
      [sceneScopeId],
    );
    if (rows.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rows.first['payload_json'] as String);
    if (decoded is! Map) {
      return null;
    }

    return {
      for (final entry in decoded.entries)
        entry.key.toString(): entry.value as Object?,
      'sceneScopeId': decoded['sceneScopeId']?.toString() ?? sceneScopeId,
    };
  }

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String sceneScopeId,
  }) async {
    final database = _getDatabase();
    database.execute(
      '''
      INSERT INTO story_generation_run_state (
        scene_scope_id, payload_json, updated_at_ms
      ) VALUES (?, ?, ?)
      ON CONFLICT(scene_scope_id) DO UPDATE SET
        payload_json = excluded.payload_json,
        updated_at_ms = excluded.updated_at_ms
      ''',
      [
        sceneScopeId,
        jsonEncode({
          for (final entry in data.entries) entry.key: entry.value,
          'sceneScopeId': data['sceneScopeId']?.toString() ?? sceneScopeId,
        }),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> clear({String? sceneScopeId}) async {
    final database = _getDatabase();
    if (sceneScopeId == null) {
      database.execute('DELETE FROM story_generation_run_state');
    } else {
      database.execute(
        'DELETE FROM story_generation_run_state WHERE scene_scope_id = ?',
        [sceneScopeId],
      );
    }
  }

  @override
  Future<void> clearProject(String projectId) async {
    final database = _getDatabase();
    database.execute(
      'DELETE FROM story_generation_run_state WHERE scene_scope_id = ? OR scene_scope_id LIKE ?',
      [projectId, '$projectId::%'],
    );
  }

  void dispose() {
    _database?.dispose();
    _database = null;
  }
}

StoryGenerationRunStorage createStoryGenerationRunStorage() =>
    SqliteStoryGenerationRunStorage();
