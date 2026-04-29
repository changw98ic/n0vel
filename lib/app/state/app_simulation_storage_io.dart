import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'app_simulation_storage.dart';

class SqliteAppSimulationStorage implements AppSimulationStorage {
  SqliteAppSimulationStorage({String? dbPath})
    : _dbPath = dbPath ?? _resolvePath();

  final String _dbPath;

  static String _resolvePath() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return '.novel_writer_simulation.db';
    }

    if (Platform.isMacOS) {
      return '$home/Library/Application Support/NovelWriter/simulation.db';
    }

    return '$home/.novel_writer/simulation.db';
  }

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    final file = File(_dbPath);
    if (!await file.exists()) {
      return null;
    }

    final database = _openDatabase();
    try {
      final runRows = database.select(
        '''
        SELECT id, template_name, run_mode
        FROM simulation_runs
        WHERE scope_key = ?
        ORDER BY updated_at_ms DESC
        LIMIT 1
        ''',
        [projectId],
      );
      if (runRows.isEmpty) {
        return null;
      }

      final runId = runRows.first['id'] as int;
      final templateName = runRows.first['template_name'] as String;
      final runMode = runRows.first['run_mode'] as String;

      final promptRows = database.select(
        '''
        SELECT participant_key, prompt_text
        FROM simulation_participant_prompts
        WHERE run_id = ?
        ORDER BY participant_key
        ''',
        [runId],
      );

      final messageRows = database.select(
        '''
        SELECT sender, title, body, tone, align_end, message_kind
        FROM simulation_chat_messages
        WHERE run_id = ?
        ORDER BY sequence_no ASC
        ''',
        [runId],
      );

      return {
        'template': templateName,
        if (runMode != 'template') 'runMode': runMode,
        'promptOverrides': {
          for (final row in promptRows)
            row['participant_key'] as String: row['prompt_text'] as String,
        },
        'extraMessages': [
          for (final row in messageRows)
          {
            'sender': row['sender'] as String,
            'title': row['title'] as String,
            'body': row['body'] as String,
            'tone': row['tone'] as String,
            'alignEnd': (row['align_end'] as int) == 1,
              'kind': row['message_kind'] as String,
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
      _writeNormalizedIntoDatabase(database, data, projectId: projectId);
    } finally {
      database.dispose();
    }
  }

  @override
  Future<void> clear({String? projectId}) async {
    final file = File(_dbPath);
    if (!await file.exists()) {
      return;
    }
    final database = _openDatabase();
    try {
      if (projectId == null) {
        database.execute('DELETE FROM simulation_chat_messages');
        database.execute('DELETE FROM simulation_participant_prompts');
        database.execute('DELETE FROM simulation_runs');
      } else {
        database.execute(
          'DELETE FROM simulation_chat_messages WHERE run_id IN (SELECT id FROM simulation_runs WHERE scope_key = ?)',
          [projectId],
        );
        database.execute(
          'DELETE FROM simulation_participant_prompts WHERE run_id IN (SELECT id FROM simulation_runs WHERE scope_key = ?)',
          [projectId],
        );
        database.execute('DELETE FROM simulation_runs WHERE scope_key = ?', [
          projectId,
        ]);
      }
    } finally {
      database.dispose();
    }
  }

  Database _openDatabase() {
    final file = File(_dbPath);
    file.parent.createSync(recursive: true);
    final database = sqlite3.open(_dbPath);
    database.execute('''
      CREATE TABLE IF NOT EXISTS simulation_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scope_key TEXT NOT NULL UNIQUE,
        template_name TEXT NOT NULL,
        run_mode TEXT NOT NULL DEFAULT 'template',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
      ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS simulation_participant_prompts (
        run_id INTEGER NOT NULL,
        participant_key TEXT NOT NULL,
        prompt_text TEXT NOT NULL,
        PRIMARY KEY (run_id, participant_key),
        FOREIGN KEY (run_id) REFERENCES simulation_runs(id) ON DELETE CASCADE
      )
      ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS simulation_chat_messages (
        run_id INTEGER NOT NULL,
        sequence_no INTEGER NOT NULL,
        sender TEXT NOT NULL,
        title TEXT NOT NULL,
            body TEXT NOT NULL,
            tone TEXT NOT NULL,
            align_end INTEGER NOT NULL,
            message_kind TEXT NOT NULL DEFAULT 'speech',
            PRIMARY KEY (run_id, sequence_no),
            FOREIGN KEY (run_id) REFERENCES simulation_runs(id) ON DELETE CASCADE
          )
      ''');
    _ensureColumn(
      database,
      tableName: 'simulation_runs',
      columnName: 'run_mode',
      definition: "run_mode TEXT NOT NULL DEFAULT 'template'",
    );
    _ensureColumn(
      database,
      tableName: 'simulation_chat_messages',
      columnName: 'message_kind',
      definition: "message_kind TEXT NOT NULL DEFAULT 'speech'",
    );
    _migrateLegacyState(database);
    return database;
  }

  void _ensureColumn(
    Database database, {
    required String tableName,
    required String columnName,
    required String definition,
  }) {
    final columns = database
        .select('PRAGMA table_info($tableName)')
        .map((row) => row['name'] as String)
        .toSet();
    if (columns.contains(columnName)) {
      return;
    }
    database.execute('ALTER TABLE $tableName ADD COLUMN $definition');
  }

  void _migrateLegacyState(Database database) {
    final legacyTable = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'simulation_state'",
    );
    if (legacyTable.isEmpty) {
      return;
    }

    final legacyRows = database.select(
      'SELECT payload_json FROM simulation_state WHERE id = 1',
    );
    if (legacyRows.isNotEmpty) {
      try {
        final payload = legacyRows.first['payload_json'] as String;
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, Object?>) {
          _writeNormalizedIntoDatabase(
            database,
            decoded,
            projectId: _legacyProjectId,
          );
        }
      } catch (_) {
        // Ignore malformed legacy payloads and continue with a clean schema.
      }
    }
    database.execute('DROP TABLE simulation_state');
  }

  void _writeNormalizedIntoDatabase(
    Database database,
    Map<String, Object?> data, {
    required String projectId,
  }) {
    final updatedAt = DateTime.now().millisecondsSinceEpoch;
    final templateName = (data['template'] as String?) ?? 'none';
    final runMode = (data['runMode'] as String?) ?? 'template';
    final promptOverrides =
        (data['promptOverrides'] as Map<Object?, Object?>?) ?? const {};
    final extraMessages = (data['extraMessages'] as List<Object?>?) ?? const [];

    database.execute('BEGIN TRANSACTION');
    try {
      database.execute(
        '''
        INSERT INTO simulation_runs (scope_key, template_name, run_mode, created_at_ms, updated_at_ms)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(scope_key) DO UPDATE SET
          template_name = excluded.template_name,
          run_mode = excluded.run_mode,
          updated_at_ms = excluded.updated_at_ms
        ''',
        [projectId, templateName, runMode, updatedAt, updatedAt],
      );

      final runId =
          database.select(
                'SELECT id FROM simulation_runs WHERE scope_key = ?',
                [projectId],
              ).first['id']
              as int;

      database.execute(
        'DELETE FROM simulation_participant_prompts WHERE run_id = ?',
        [runId],
      );
      database.execute(
        'DELETE FROM simulation_chat_messages WHERE run_id = ?',
        [runId],
      );

      for (final entry in promptOverrides.entries) {
        database.execute(
          '''
          INSERT INTO simulation_participant_prompts (run_id, participant_key, prompt_text)
          VALUES (?, ?, ?)
          ''',
          [runId, entry.key.toString(), entry.value?.toString() ?? ''],
        );
      }

      for (var index = 0; index < extraMessages.length; index++) {
        final message = extraMessages[index];
        if (message is! Map) {
          continue;
        }
        database.execute(
          '''
          INSERT INTO simulation_chat_messages (
            run_id, sequence_no, sender, title, body, tone, align_end, message_kind
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            runId,
            index,
            message['sender']?.toString() ?? '',
            message['title']?.toString() ?? '',
            message['body']?.toString() ?? '',
            message['tone']?.toString() ?? '',
            message['alignEnd'] == true ? 1 : 0,
            message['kind']?.toString() ?? 'speech',
          ],
        );
      }

      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  static const String _legacyProjectId = 'project-yuechao';
}

AppSimulationStorage createAppSimulationStorage() =>
    SqliteAppSimulationStorage();
