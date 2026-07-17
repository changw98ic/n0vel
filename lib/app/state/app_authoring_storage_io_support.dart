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

/// Thrown when [openAuthoringDatabase] detects database corruption.
class DatabaseCorruptedException implements Exception {
  DatabaseCorruptedException(this.details);
  final String details;
  @override
  String toString() => 'DatabaseCorruptedException: $details';
}

/// Opens the authoring database and ensures the current schema is available.
///
/// Integrity verification is enabled by default for startup, migration, and
/// recovery paths. Short-lived storage adapters can pass `false` after the
/// owning registry has already established the database; running a full
/// `PRAGMA integrity_check` for every read/write would otherwise turn a small
/// mutation into a database-wide scan.
Database openAuthoringDatabase(String dbPath, {bool verifyIntegrity = true}) {
  final file = File(dbPath);
  file.parent.createSync(recursive: true);
  Database? database;
  try {
    database = sqlite3.open(dbPath);
    _applyPerformancePragmas(database);
    if (verifyIntegrity) {
      _checkIntegrity(database);
    }
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(database);
    return database;
  } on SqliteException catch (e) {
    database?.dispose();
    throw DatabaseCorruptedException(e.message);
  } on Object {
    database?.dispose();
    rethrow;
  }
}

/// Opens a database whose schema and integrity were already established by a
/// long-lived owning connection (for example an immutable evaluation sandbox
/// clone). This path deliberately does not rerun migrations or integrity_check
/// from a secondary isolate, both of which instantiate unrelated FTS virtual
/// tables. Exact schema-version equality keeps the shortcut fail closed.
Database openExistingAuthoringDatabase(String dbPath, {bool readOnly = false}) {
  final file = File(dbPath);
  if (!file.existsSync()) {
    throw DatabaseCorruptedException('existing authoring database is missing');
  }
  final database = sqlite3.open(
    dbPath,
    mode: readOnly ? OpenMode.readOnly : OpenMode.readWrite,
  );
  try {
    database.execute('PRAGMA busy_timeout = 5000');
    database.execute('PRAGMA foreign_keys = ON');
    if (readOnly) database.execute('PRAGMA query_only = ON');
    final actualVersion =
        database.select('PRAGMA user_version').single['user_version'] as int;
    final expectedVersion = authoringSchemaMigrations.last.version;
    if (actualVersion != expectedVersion) {
      throw DatabaseCorruptedException(
        'existing authoring schema version mismatch '
        '(expected=$expectedVersion, actual=$actualVersion)',
      );
    }
    return database;
  } on Object {
    database.dispose();
    rethrow;
  }
}

T withExistingAuthoringDb<T>(
  String dbPath,
  T Function(Database) action, {
  bool readOnly = false,
}) {
  final db = openExistingAuthoringDatabase(dbPath, readOnly: readOnly);
  try {
    return action(db);
  } finally {
    db.dispose();
  }
}

/// Runs a quick integrity check and throws if the database is corrupted.
///
/// Called after pragmas but before schema migration so a corrupted DB is never
/// silently opened and used.
void _checkIntegrity(Database database) {
  final rows = database.select('PRAGMA integrity_check');
  for (final row in rows) {
    final value = row.values.first?.toString();
    if (value != null && value != 'ok') {
      throw DatabaseCorruptedException(value);
    }
  }
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

T withAuthoringDb<T>(
  String dbPath,
  T Function(Database) action, {
  bool verifyIntegrity = false,
}) {
  final db = openAuthoringDatabase(dbPath, verifyIntegrity: verifyIntegrity);
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

T withAuthoringDbInTxn<T>(
  String dbPath,
  T Function(Database) action, {
  bool verifyIntegrity = false,
}) {
  final db = openAuthoringDatabase(dbPath, verifyIntegrity: verifyIntegrity);
  try {
    return runInTransaction(db, () => action(db));
  } finally {
    db.dispose();
  }
}

void clearByProject(Database db, String tableName, {String? projectId}) {
  checkedSqlIdentifier(tableName);
  if (projectId == null) {
    db.execute('DELETE FROM $tableName');
  } else {
    db.execute('DELETE FROM $tableName WHERE project_id = ?', [projectId]);
  }
}

void clearByProjectScope(Database db, String tableName, String projectId) {
  checkedSqlIdentifier(tableName);
  db.execute(
    'DELETE FROM $tableName WHERE project_id = ? OR project_id LIKE ?',
    [projectId, '$projectId::%'],
  );
}

/// Validates that [identifier] is a safe SQL identifier (table/column name).
///
/// Only allows alphanumeric characters and underscores. Rejects empty strings
/// and any identifier containing characters outside `[a-zA-Z0-9_]`.
void checkedSqlIdentifier(String identifier) {
  if (identifier.isEmpty) {
    throw ArgumentError('SQL identifier must not be empty');
  }
  if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(identifier)) {
    throw ArgumentError(
      'SQL identifier contains invalid characters: "$identifier"',
    );
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
