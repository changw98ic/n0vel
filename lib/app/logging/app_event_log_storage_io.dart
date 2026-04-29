import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../state/app_authoring_storage_io_support.dart';
import 'app_event_log_storage.dart';
import 'app_event_log_types.dart';
import 'app_log.dart';

AppEventLogStorage createAppEventLogStorage({
  String? sqlitePath,
  Object? logsDirectory,
}) {
  return IoAppEventLogStorage(
    sqlitePath: sqlitePath,
    logsDirectory: logsDirectory is Directory
        ? logsDirectory
        : resolveTelemetryLogsDirectory(),
  );
}

class IoAppEventLogStorage implements AppEventLogStorage {
  IoAppEventLogStorage({String? sqlitePath, Directory? logsDirectory})
    : _sqlitePath = sqlitePath ?? resolveTelemetryDbPath(),
      _logsDirectory = logsDirectory ?? resolveTelemetryLogsDirectory();

  final String _sqlitePath;
  final Directory _logsDirectory;
  Future<void> _pendingWrite = Future<void>.value();

  @override
  Future<void> write(AppEventLogEntry entry) {
    final next = _pendingWrite
        .catchError((Object _) {})
        .then<void>((_) => _writeBestEffort(entry));
    _pendingWrite = next;
    return next;
  }

  Future<void> _writeBestEffort(AppEventLogEntry entry) async {
    Object? writeError;

    try {
      _writeToSqlite(entry);
    } catch (error) {
      writeError = error;
    }

    try {
      await _appendJsonl(entry);
    } catch (error) {
      writeError ??= error;
    }

    if (writeError != null) {
      AppLog.e('write failed', tag: 'EventLog', error: writeError);
    }
  }

  void _writeToSqlite(AppEventLogEntry entry) {
    final database = openTelemetryDatabase(_sqlitePath);
    try {
      _ensureSchema(database);
      database.execute(
        '''
        INSERT INTO app_event_log_entries (
          event_id,
          timestamp_ms,
          level,
          category,
          action,
          status,
          session_id,
          correlation_id,
          project_id,
          scene_id,
          message,
          error_code,
          error_detail,
          metadata_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        <Object?>[
          entry.eventId,
          entry.timestampMs,
          entry.level.name,
          appEventLogCategoryName(entry.category),
          entry.action,
          entry.status.name,
          entry.sessionId,
          entry.correlationId,
          entry.projectId,
          entry.sceneId,
          entry.message,
          entry.errorCode,
          entry.errorDetail,
          jsonEncode(entry.metadata),
        ],
      );
    } finally {
      database.dispose();
    }
  }

  void _ensureSchema(Database database) {
    database.execute('''
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
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_event_log_entries_timestamp ON app_event_log_entries (timestamp_ms DESC)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_event_log_entries_category_action_time ON app_event_log_entries (category, action, timestamp_ms DESC)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_event_log_entries_correlation ON app_event_log_entries (correlation_id)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_event_log_entries_project_scene_time ON app_event_log_entries (project_id, scene_id, timestamp_ms DESC)',
    );
  }

  Future<void> _appendJsonl(AppEventLogEntry entry) async {
    await _logsDirectory.create(recursive: true);
    final file = File(
      '${_logsDirectory.path}/${_dailyFileName(entry.timestampMs)}',
    );
    await file.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
    );
  }

  String _dailyFileName(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day.jsonl';
  }
}
