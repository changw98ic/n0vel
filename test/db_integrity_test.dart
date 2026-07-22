import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_authoring_storage_io_support.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novel_writer_integrity_test',
    );
    dbPath = '${tempDir.path}/authoring.db';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('openAuthoringDatabase', () {
    test('opens a valid database without error', () {
      final db = openAuthoringDatabase(dbPath);
      expect(db, isNotNull);
      db.dispose();
    });

    test('throws DatabaseCorruptedException for corrupted file', () {
      // Write garbage bytes to simulate corruption.
      File(dbPath)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync([0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA]);

      expect(
        () => openAuthoringDatabase(dbPath),
        throwsA(isA<DatabaseCorruptedException>()),
      );
    });

    test('creates parent directory if missing', () {
      final nestedPath = '${tempDir.path}/nested/dir/authoring.db';
      final db = openAuthoringDatabase(nestedPath);
      expect(db, isNotNull);
      db.dispose();
    });

    test('disposes the connection when a future database is rejected', () {
      final unsupportedVersion = authoringSchemaMigrations.last.version + 1;
      final raw = sqlite3.open(dbPath);
      raw.execute('PRAGMA user_version = $unsupportedVersion');
      raw.dispose();

      expect(
        () => openAuthoringDatabase(dbPath),
        throwsA(isA<UnsupportedDatabaseSchemaVersion>()),
      );

      final reopened = sqlite3.open(dbPath);
      expect(
        reopened.select('PRAGMA user_version').single['user_version'],
        unsupportedVersion,
      );
      reopened.dispose();
      File(dbPath).deleteSync();
      expect(File(dbPath).existsSync(), isFalse);
    });

    test('existing-schema mismatch disposes before returning failure', () {
      final raw = sqlite3.open(dbPath);
      raw.execute('PRAGMA user_version = 26');
      raw.dispose();

      expect(
        () => openExistingAuthoringDatabase(dbPath),
        throwsA(isA<DatabaseCorruptedException>()),
      );

      final reopened = sqlite3.open(dbPath);
      expect(reopened.select('PRAGMA user_version').single['user_version'], 26);
      reopened.dispose();
      File(dbPath).deleteSync();
      expect(File(dbPath).existsSync(), isFalse);
    });
  });

  group('DatabaseCorruptedException', () {
    test('carries details message', () {
      final e = DatabaseCorruptedException('row 3 missing');
      expect(e.details, 'row 3 missing');
      expect(e.toString(), contains('row 3 missing'));
    });
  });
}
