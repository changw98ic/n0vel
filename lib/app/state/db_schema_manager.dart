import 'package:sqlite3/sqlite3.dart';

/// A single named migration step targeting schema [version].
class SchemaMigration {
  const SchemaMigration({
    required this.version,
    required this.description,
    required this.migrate,
  });

  final int version;
  final String description;
  final void Function(Database db) migrate;
}

/// Runs pending [SchemaMigration]s in order, tracking progress via
/// SQLite's built-in `PRAGMA user_version`.
///
/// Usage:
/// ```dart
/// final manager = DatabaseSchemaManager(migrations: authoringSchemaMigrations);
/// manager.ensureSchema(db);
/// ```
class DatabaseSchemaManager {
  DatabaseSchemaManager({required this.migrations});

  final List<SchemaMigration> migrations;

  /// Executes all migrations whose version exceeds the stored `user_version`.
  ///
  /// Migrations run inside a single transaction. On failure the transaction is
  /// rolled back and the `user_version` is left unchanged.
  void ensureSchema(Database db) {
    final current = _readVersion(db);
    final sorted = List<SchemaMigration>.from(migrations)
      ..sort((a, b) => a.version.compareTo(b.version));
    if (sorted.isEmpty) {
      if (current != 0) {
        throw UnsupportedDatabaseSchemaVersion(
          databaseVersion: current,
          maximumSupportedVersion: 0,
        );
      }
      return;
    }
    final maximumSupported = sorted.last.version;
    if (current > maximumSupported) {
      throw UnsupportedDatabaseSchemaVersion(
        databaseVersion: current,
        maximumSupportedVersion: maximumSupported,
      );
    }
    final pending = sorted.where((m) => m.version > current).toList();
    if (pending.isEmpty) return;

    db.execute('BEGIN TRANSACTION');
    try {
      for (final m in pending) {
        m.migrate(db);
      }
      db.execute('PRAGMA user_version = ${pending.last.version}');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  int _readVersion(Database db) =>
      db.select('PRAGMA user_version').first['user_version'] as int;
}

/// Raised before any write when an older binary opens a newer database.
///
/// Silently accepting this case lets an N-1 writer bypass schema-era fencing
/// and corrupt data it cannot understand. Recovery is restore-from-backup or a
/// newer binary; in-place downgrade is deliberately unsupported.
class UnsupportedDatabaseSchemaVersion implements Exception {
  const UnsupportedDatabaseSchemaVersion({
    required this.databaseVersion,
    required this.maximumSupportedVersion,
  });

  final int databaseVersion;
  final int maximumSupportedVersion;

  @override
  String toString() =>
      'UnsupportedDatabaseSchemaVersion: database v$databaseVersion is newer '
      'than this binary\'s maximum v$maximumSupportedVersion';
}
