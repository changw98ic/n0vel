import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_authoring_storage_io_support.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novel_writer_integrity_test');
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
  });

  group('DatabaseCorruptedException', () {
    test('carries details message', () {
      final e = DatabaseCorruptedException('row 3 missing');
      expect(e.details, 'row 3 missing');
      expect(e.toString(), contains('row 3 missing'));
    });
  });
}
