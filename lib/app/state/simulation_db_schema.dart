import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'db_schema_manager.dart';

const List<SchemaMigration> simulationSchemaMigrations = [
  SchemaMigration(
    version: 1,
    description: 'Initial simulation schema: runs, participant_prompts, '
        'chat_messages tables + legacy state migration.',
    migrate: _migrateSimulationV1,
  ),
];

const String legacySimulationProjectId = 'project-yuechao';

void _migrateSimulationV1(Database db) {
  _createSimulationTables(db);
  _migrateLegacySimulationState(db);
}

void _createSimulationTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS simulation_runs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      scope_key TEXT NOT NULL UNIQUE,
      template_name TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS simulation_participant_prompts (
      run_id INTEGER NOT NULL,
      participant_key TEXT NOT NULL,
      prompt_text TEXT NOT NULL,
      PRIMARY KEY (run_id, participant_key),
      FOREIGN KEY (run_id) REFERENCES simulation_runs(id) ON DELETE CASCADE
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS simulation_chat_messages (
      run_id INTEGER NOT NULL,
      sequence_no INTEGER NOT NULL,
      sender TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      tone TEXT NOT NULL,
      align_end INTEGER NOT NULL,
      PRIMARY KEY (run_id, sequence_no),
      FOREIGN KEY (run_id) REFERENCES simulation_runs(id) ON DELETE CASCADE
    )
  ''');
}

void _migrateLegacySimulationState(Database db) {
  final legacyTable = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'simulation_state'",
  );
  if (legacyTable.isEmpty) return;

  final legacyRows = db.select(
    'SELECT payload_json FROM simulation_state WHERE id = 1',
  );
  if (legacyRows.isNotEmpty) {
    try {
      final payload = legacyRows.first['payload_json'] as String;
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, Object?>) {
        writeSimulationData(db, decoded, projectId: legacySimulationProjectId);
      }
    } catch (_) {
      // Ignore malformed legacy payloads and continue with a clean schema.
    }
  }
  db.execute('DROP TABLE simulation_state');
}

/// Writes normalized simulation data into the database.
///
/// This is used both during legacy migration and by the simulation storage's
/// save method. Callers are responsible for wrapping in a transaction if
/// needed.
void writeSimulationData(
  Database db,
  Map<String, Object?> data, {
  required String projectId,
}) {
  final updatedAt = DateTime.now().millisecondsSinceEpoch;
  final templateName = (data['template'] as String?) ?? 'none';
  final promptOverrides =
      (data['promptOverrides'] as Map<Object?, Object?>?) ?? const {};
  final extraMessages = (data['extraMessages'] as List<Object?>?) ?? const [];

  db.execute(
    '''
    INSERT INTO simulation_runs (scope_key, template_name, created_at_ms, updated_at_ms)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(scope_key) DO UPDATE SET
      template_name = excluded.template_name,
      updated_at_ms = excluded.updated_at_ms
    ''',
    [projectId, templateName, updatedAt, updatedAt],
  );

  final runId = db.select(
    'SELECT id FROM simulation_runs WHERE scope_key = ?',
    [projectId],
  ).first['id'] as int;

  db.execute(
    'DELETE FROM simulation_participant_prompts WHERE run_id = ?',
    [runId],
  );
  db.execute(
    'DELETE FROM simulation_chat_messages WHERE run_id = ?',
    [runId],
  );

  for (final entry in promptOverrides.entries) {
    db.execute(
      '''
      INSERT INTO simulation_participant_prompts (run_id, participant_key, prompt_text)
      VALUES (?, ?, ?)
      ''',
      [runId, entry.key.toString(), entry.value?.toString() ?? ''],
    );
  }

  for (var index = 0; index < extraMessages.length; index++) {
    final message = extraMessages[index];
    if (message is! Map) continue;
    db.execute(
      '''
      INSERT INTO simulation_chat_messages (
        run_id, sequence_no, sender, title, body, tone, align_end
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        runId,
        index,
        message['sender']?.toString() ?? '',
        message['title']?.toString() ?? '',
        message['body']?.toString() ?? '',
        message['tone']?.toString() ?? '',
        message['alignEnd'] == true ? 1 : 0,
      ],
    );
  }
}
