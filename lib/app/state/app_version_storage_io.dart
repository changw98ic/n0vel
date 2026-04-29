import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'app_authoring_storage_io_support.dart';
import 'app_version_storage.dart';

class SqliteAppVersionStorage implements AppVersionStorage {
  SqliteAppVersionStorage({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    final database = _openDatabase();
    try {
      final rows = database.select(
        '''
        SELECT label, content
        FROM version_entries
        WHERE project_id = ?
        ORDER BY sequence_no ASC
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
              'label': row['label'] as String,
              'content': row['content'] as String,
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
        database.execute('DELETE FROM version_entries WHERE project_id = ?', [
          projectId,
        ]);
        final stmt = database.prepare('''
          INSERT INTO version_entries (
            project_id, sequence_no, label, content, updated_at_ms
          ) VALUES (?, ?, ?, ?, ?)
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
              entry['label']?.toString() ?? '',
              entry['content']?.toString() ?? '',
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
        database.execute('DELETE FROM version_entries');
      } else {
        database.execute('DELETE FROM version_entries WHERE project_id = ?', [
          projectId,
        ]);
      }
    } finally {
      database.dispose();
    }
  }

  sqlite3.Database _openDatabase() {
    final database = openAuthoringDatabase(_dbPath);
    _migrateLegacySchema(database);
    database.execute('''
      CREATE TABLE IF NOT EXISTS version_entries (
        project_id TEXT NOT NULL,
        sequence_no INTEGER NOT NULL,
        label TEXT NOT NULL,
        content TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        PRIMARY KEY (project_id, sequence_no)
      )
      ''');
    return database;
  }

  void _migrateLegacySchema(sqlite3.Database database) {
    final rows = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'version_entries'",
    );
    if (rows.isEmpty) {
      return;
    }
    final columns = database.select('PRAGMA table_info(version_entries)');
    final columnNames = columns.map((row) => row['name'] as String).toSet();
    if (columnNames.contains('project_id')) {
      return;
    }

    final legacyRows = database.select(
      'SELECT sequence_no, label, content, updated_at_ms FROM version_entries ORDER BY sequence_no ASC',
    );
    database.execute('DROP TABLE version_entries');
    database.execute('''
      CREATE TABLE version_entries (
        project_id TEXT NOT NULL,
        sequence_no INTEGER NOT NULL,
        label TEXT NOT NULL,
        content TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        PRIMARY KEY (project_id, sequence_no)
      )
      ''');
    for (final row in legacyRows) {
      database.execute(
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
}

AppVersionStorage createAppVersionStorage() => SqliteAppVersionStorage();
