@Tags(['integration'])
library;

import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:writing_assistant/core/database/database.dart';

void _loadSqlite3WithFts5() {
  if (!Platform.isWindows) {
    return;
  }

  final candidates = [
    p.join(
      Directory.current.path,
      'build',
      'native_assets',
      'windows',
      'sqlite3.dll',
    ),
    p.join(
      Directory.current.path,
      'build',
      'windows',
      'x64',
      'runner',
      'Debug',
      'sqlite3.dll',
    ),
  ];

  for (final dllPath in candidates) {
    if (File(dllPath).existsSync()) {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open(dllPath),
      );
      return;
    }
  }

  throw StateError('Unable to find sqlite3.dll with FTS5 support.');
}

AppDatabase _openDatabase(String dbPath) {
  return AppDatabase.connect(DatabaseConnection(NativeDatabase(File(dbPath))));
}

Future<int> _readPragmaInt(AppDatabase db, String pragmaName) async {
  final row = await db.customSelect('PRAGMA $pragmaName;').getSingle();
  return row.data.values.single as int;
}

Future<String> _readPragmaString(AppDatabase db, String pragmaName) async {
  final row = await db.customSelect('PRAGMA $pragmaName;').getSingle();
  return row.data.values.single as String;
}

Future<bool> _sqliteObjectExists(
  AppDatabase db, {
  required String type,
  required String name,
}) async {
  final row = await db
      .customSelect(
        '''
      SELECT COUNT(*) AS count
      FROM sqlite_master
      WHERE type = ? AND name = ?
    ''',
        variables: [Variable.withString(type), Variable.withString(name)],
      )
      .getSingle();

  return (row.read<int>('count')) == 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadSqlite3WithFts5);

  group('AppDatabase bootstrap', () {
    late Directory tempDir;
    late AppDatabase database;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wa_db_bootstrap_');
      final dbPath = p.join(tempDir.path, 'bootstrap.sqlite');
      database = _openDatabase(dbPath);
    });

    tearDown(() async {
      await database.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('beforeOpen enables pragmas and creates FTS artifacts', () async {
      expect(await _readPragmaInt(database, 'foreign_keys'), 1);
      expect(await _readPragmaString(database, 'journal_mode'), 'wal');

      expect(
        await _sqliteObjectExists(
          database,
          type: 'table',
          name: 'chapters_fts',
        ),
        isTrue,
      );
      expect(
        await _sqliteObjectExists(
          database,
          type: 'trigger',
          name: 'chapters_ai',
        ),
        isTrue,
      );
      expect(
        await _sqliteObjectExists(
          database,
          type: 'trigger',
          name: 'chapters_ad',
        ),
        isTrue,
      );
      expect(
        await _sqliteObjectExists(
          database,
          type: 'trigger',
          name: 'chapters_au',
        ),
        isTrue,
      );

      final countRow = await database
          .customSelect('SELECT COUNT(*) AS count FROM chapters_fts;')
          .getSingle();
      expect(countRow.read<int>('count'), 0);
    });
  });
}
