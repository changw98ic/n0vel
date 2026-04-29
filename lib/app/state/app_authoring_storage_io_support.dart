import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'authoring_db_schema.dart';
import 'db_schema_manager.dart';
import 'telemetry_db_schema.dart';

String resolvePlatformDbPath(String name) {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return '.novel_writer_$name.db';
  }

  if (Platform.isMacOS) {
    return '$home/Library/Application Support/NovelWriter/$name.db';
  }

  return '$home/.novel_writer/$name.db';
}

String resolveAuthoringDbPath() {
  return resolvePlatformDbPath('authoring');
}

String resolveTelemetryDbPath({String? homeOverride}) {
  final home = homeOverride ?? Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return '.telemetry.db';
  }

  if (Platform.isMacOS) {
    return '$home/Library/Application Support/NovelWriter/telemetry.db';
  }

  return '$home/.novel_writer/telemetry.db';
}

Directory resolveTelemetryLogsDirectory({String? homeOverride}) {
  final home = homeOverride ?? Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return Directory('./logs');
  }

  if (Platform.isMacOS) {
    return Directory('$home/Library/Application Support/NovelWriter/logs');
  }

  return Directory('$home/.novel_writer/logs');
}

Database openAuthoringDatabase(String dbPath) {
  final file = File(dbPath);
  file.parent.createSync(recursive: true);
  final database = sqlite3.open(dbPath);
  _applyPerformancePragmas(database);
  DatabaseSchemaManager(
    migrations: authoringSchemaMigrations,
  ).ensureSchema(database);
  return database;
}

Database openTelemetryDatabase(String dbPath) {
  final file = File(dbPath);
  file.parent.createSync(recursive: true);
  final database = sqlite3.open(dbPath);
  _applyPerformancePragmas(database);
  DatabaseSchemaManager(
    migrations: telemetrySchemaMigrations,
  ).ensureSchema(database);
  return database;
}

T withAuthoringDb<T>(String dbPath, T Function(Database) action) {
  final db = openAuthoringDatabase(dbPath);
  try {
    return action(db);
  } finally {
    db.dispose();
  }
}

T runInTransaction<T>(Database db, T Function() action) {
  db.execute('BEGIN TRANSACTION');
  try {
    final result = action();
    db.execute('COMMIT');
    return result;
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

T withAuthoringDbInTxn<T>(String dbPath, T Function(Database) action) {
  final db = openAuthoringDatabase(dbPath);
  try {
    return runInTransaction(db, () => action(db));
  } finally {
    db.dispose();
  }
}

void clearByProject(Database db, String tableName, {String? projectId}) {
  if (projectId == null) {
    db.execute('DELETE FROM $tableName');
  } else {
    db.execute('DELETE FROM $tableName WHERE project_id = ?', [projectId]);
  }
}

void _applyPerformancePragmas(Database database) {
  database.execute('PRAGMA busy_timeout = 5000');
  database.execute('PRAGMA foreign_keys = ON');
  _executeBestEffortLockedPragma(database, 'PRAGMA journal_mode = WAL');
  database.execute('PRAGMA synchronous = NORMAL');
  database.execute('PRAGMA cache_size = -64000');
  database.execute('PRAGMA temp_store = MEMORY');
  database.execute('PRAGMA mmap_size = 268435456');
}

void _executeBestEffortLockedPragma(Database database, String statement) {
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      database.execute(statement);
      return;
    } on SqliteException catch (error) {
      if (!_isDatabaseLocked(error)) {
        rethrow;
      }
      sleep(Duration(milliseconds: 25 * (attempt + 1)));
    }
  }
}

bool _isDatabaseLocked(SqliteException error) {
  return error.toString().contains('database is locked');
}
