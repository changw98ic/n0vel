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

/// Maximum size of a single JSONL file before rotation occurs.
const int _defaultMaxFileSizeBytes = 50 * 1024 * 1024; // 50 MB

class IoAppEventLogStorage
    implements
        AppEventLogStorage,
        AppEventLogMaintenance,
        AppEventLogStorageLifecycle {
  IoAppEventLogStorage({
    String? sqlitePath,
    Directory? logsDirectory,
    int maxFileSizeBytes = _defaultMaxFileSizeBytes,
  }) : _sqlitePath = sqlitePath ?? resolveTelemetryDbPath(),
       _logsDirectory = logsDirectory ?? resolveTelemetryLogsDirectory(),
       _maxFileSizeBytes = maxFileSizeBytes;

  final String _sqlitePath;
  final Directory _logsDirectory;
  final int _maxFileSizeBytes;
  Future<void> _pendingWrite = Future<void>.value();

  // --- Lazy SQLite connection (Step 4) ---
  Database? _database;
  bool _schemaEnsured = false;

  Database _ensureDatabase() {
    var db = _database;
    if (db != null) {
      return db;
    }
    db = openTelemetryDatabase(_sqlitePath);
    _database = db;
    return db;
  }

  /// Callers should invoke this when the storage is no longer needed
  /// (e.g. on app shutdown) to release the SQLite connection.
  @override
  void dispose() {
    _database?.dispose();
    _database = null;
  }

  @override
  Future<void> flush() => _pendingWrite;

  // --- Public write API (unchanged) ---
  @override
  Future<void> write(AppEventLogEntry entry) {
    final next = _pendingWrite
        .catchError((Object _) {})
        .then<void>((_) => _writeBestEffort(entry));
    _pendingWrite = next;
    return next;
  }

  @override
  Future<void> clear() {
    final next = _pendingWrite
        .catchError((Object _) {})
        .then<void>((_) => _clearSinks());
    _pendingWrite = next;
    return next;
  }

  Future<void> _clearSinks() async {
    final databaseFile = File(_sqlitePath);
    if (databaseFile.existsSync()) {
      final database = _ensureDatabase();
      _ensureSchema(database);
      database.execute('DELETE FROM app_event_log_entries');
      _schemaEnsured = true;
    }

    if (!await _logsDirectory.exists()) return;
    await for (final entity in _logsDirectory.list()) {
      if (entity is File && _isJsonlFile(entity.path)) {
        await entity.delete();
      }
    }
  }

  @override
  Future<void> pruneBefore(DateTime cutoff) {
    final next = _pendingWrite
        .catchError((Object _) {})
        .then<void>((_) => _pruneSinksBefore(cutoff));
    _pendingWrite = next;
    return next;
  }

  Future<void> _pruneSinksBefore(DateTime cutoff) async {
    final cutoffMs = cutoff.millisecondsSinceEpoch;
    final databaseFile = File(_sqlitePath);
    if (databaseFile.existsSync()) {
      final database = _ensureDatabase();
      _ensureSchema(database);
      database.execute(
        'DELETE FROM app_event_log_entries WHERE timestamp_ms < ?',
        [cutoffMs],
      );
      _schemaEnsured = true;
    }

    if (!await _logsDirectory.exists()) return;
    await for (final entity in _logsDirectory.list()) {
      if (entity is! File || !_isJsonlFile(entity.path)) continue;
      final day = _jsonlDay(entity.path);
      if (day != null && day.isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }

  // --- Best-effort dual write ---
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

  // --- SQLite write with lazy connection (Step 4) ---
  void _writeToSqlite(AppEventLogEntry entry) {
    final database = _ensureDatabase();
    if (!_schemaEnsured) {
      _ensureSchema(database);
      _schemaEnsured = true;
    }
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

  // --- JSONL append ---
  Future<void> _appendJsonl(AppEventLogEntry entry) async {
    await _logsDirectory.create(recursive: true);
    final fileName = _dailyFileName(entry.timestampMs);
    final file = File('${_logsDirectory.path}/$fileName');

    // Rotate if file exceeds size limit (Step 3).
    await _rotateIfNeeded(file, fileName);

    await file.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  // --- JSONL file rotation (Step 3) ---
  Future<void> _rotateIfNeeded(File file, String baseName) async {
    if (!await file.exists()) return;
    final stat = await file.stat();
    if (stat.size < _maxFileSizeBytes) return;

    // Find next available rotation suffix: .1.jsonl, .2.jsonl, ...
    var suffix = 1;
    while (true) {
      final rotatedName = baseName.replaceFirst('.jsonl', '.$suffix.jsonl');
      final rotatedFile = File('${_logsDirectory.path}/$rotatedName');
      if (!await rotatedFile.exists()) {
        await file.rename(rotatedFile.path);
        return;
      }
      suffix++;
    }
  }

  /// Manually rotate all JSONL files that exceed the size limit.
  /// Safe to call at any time (e.g. on app startup or maintenance).
  Future<void> rotateLogFiles() async {
    if (!await _logsDirectory.exists()) return;
    await for (final entity in _logsDirectory.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.jsonl')) continue;
      // Skip already-rotated files (e.g. 2025-01-01.1.jsonl).
      final baseName = entity.path.split('/').last;
      if (_isRotatedName(baseName)) continue;
      final stat = await entity.stat();
      if (stat.size >= _maxFileSizeBytes) {
        await _rotateIfNeeded(entity, baseName);
      }
    }
  }

  bool _isRotatedName(String name) {
    // Rotated names look like: 2025-01-01.1.jsonl
    final dotPattern = RegExp(r'\.\d+\.jsonl$');
    return dotPattern.hasMatch(name);
  }

  bool _isJsonlFile(String path) => path.endsWith('.jsonl');

  DateTime? _jsonlDay(String path) {
    final name = path.split('/').last;
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:\.\d+)?\.jsonl$',
    ).firstMatch(name);
    if (match == null) return null;
    return DateTime.tryParse('${match[1]}-${match[2]}-${match[3]}');
  }

  String _dailyFileName(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day.jsonl';
  }
}
