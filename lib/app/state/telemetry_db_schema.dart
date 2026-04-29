import 'package:sqlite3/sqlite3.dart';

import 'db_schema_manager.dart';

const List<SchemaMigration> telemetrySchemaMigrations = [
  SchemaMigration(
    version: 1,
    description: 'Initial telemetry schema: event log table with indexes.',
    migrate: _migrateTelemetryV1,
  ),
];

void _migrateTelemetryV1(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS app_event_log_entries (
      event_id TEXT PRIMARY KEY,
      timestamp_ms INTEGER NOT NULL,
      level TEXT NOT NULL,
      category TEXT NOT NULL,
      action TEXT NOT NULL,
      status TEXT NOT NULL,
      session_id TEXT NOT NULL,
      correlation_id TEXT,
      project_id TEXT,
      scene_id TEXT,
      message TEXT NOT NULL,
      error_code TEXT,
      error_detail TEXT,
      metadata_json TEXT NOT NULL
    )
  ''');
  db.execute(
    'CREATE INDEX IF NOT EXISTS idx_app_event_log_entries_timestamp '
    'ON app_event_log_entries (timestamp_ms DESC)',
  );
  db.execute(
    'CREATE INDEX IF NOT EXISTS idx_app_event_log_entries_category_action_time '
    'ON app_event_log_entries (category, action, timestamp_ms DESC)',
  );
  db.execute(
    'CREATE INDEX IF NOT EXISTS idx_app_event_log_entries_correlation '
    'ON app_event_log_entries (correlation_id)',
  );
  db.execute(
    'CREATE INDEX IF NOT EXISTS idx_app_event_log_entries_project_scene_time '
    'ON app_event_log_entries (project_id, scene_id, timestamp_ms DESC)',
  );
}
