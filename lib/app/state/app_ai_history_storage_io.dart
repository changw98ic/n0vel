import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'app_ai_history_storage.dart';
import 'app_authoring_storage_io_support.dart';

class SqliteAppAiHistoryStorage implements AppAiHistoryStorage {
  SqliteAppAiHistoryStorage({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    final database = _openDatabase();
    try {
      final rows = database.select(
        '''
        SELECT position_no, sequence_no, mode, prompt
        FROM ai_history_entries
        WHERE project_id = ?
        ORDER BY position_no ASC
        ''',
        [projectId],
      );
      if (rows.isEmpty) {
        return null;
      }
      return {
        'entries': [
          for (final row in rows)
            {
              'sequence': row['sequence_no'] as int,
              'mode': row['mode'] as String,
              'prompt': row['prompt'] as String,
            },
        ],
      };
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
      final entries = (data['entries'] as List<Object?>?) ?? const [];
      runInTransaction(database, () {
        database.execute(
          'DELETE FROM ai_history_entries WHERE project_id = ?',
          [projectId],
        );
        final stmt = database.prepare('''
          INSERT INTO ai_history_entries (
            project_id, position_no, sequence_no, mode, prompt, updated_at_ms
          ) VALUES (?, ?, ?, ?, ?, ?)
          ''');
        try {
          final now = DateTime.now().millisecondsSinceEpoch;
          for (var index = 0; index < entries.length; index++) {
            final entry = entries[index];
            if (entry is! Map) {
              continue;
            }
            stmt.execute([
              projectId,
              index,
              int.tryParse(entry['sequence']?.toString() ?? '') ?? 0,
              entry['mode']?.toString() ?? '',
              entry['prompt']?.toString() ?? '',
              now,
            ]);
          }
        } finally {
          stmt.dispose();
        }
      });
    } finally {
      database.dispose();
    }
  }

  @override
  Future<void> clear({String? projectId}) async {
    final database = _openDatabase();
    try {
      if (projectId == null) {
        database.execute('DELETE FROM ai_history_entries');
      } else {
        database.execute(
          'DELETE FROM ai_history_entries WHERE project_id = ?',
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
    return database;
  }
}

AppAiHistoryStorage createAppAiHistoryStorage() => SqliteAppAiHistoryStorage();
