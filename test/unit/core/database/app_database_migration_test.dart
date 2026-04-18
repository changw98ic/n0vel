import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:writing_assistant/core/database/database.dart';

void main() {
  setUpAll(_loadSqliteForWindows);

  group('AppDatabase migration', () {
    test('migrates version 8 databases by deduping locations', () async {
      final tempDir = await Directory.systemTemp.createTemp('wa_migration_');
      final dbFile = File(p.join(tempDir.path, 'migration_v8.db'));
      AppDatabase? database;

      try {
        await _createVersion8Database(dbFile);

        database = AppDatabase.connect(
          DatabaseConnection(NativeDatabase(dbFile)),
        );
        final db = database;

        final locations = await (db.select(
          db.locations,
        )..where((table) => table.workId.equals('work-1'))).get();

        final keep = locations.singleWhere((location) => location.id == 'loc-1');
        final child = locations.singleWhere((location) => location.id == 'loc-3');

        expect(
          locations.map((location) => location.id),
          unorderedEquals(['loc-1', 'loc-3', 'loc-4']),
        );
        expect(keep.name, 'Harbor');
        expect(child.parentId, 'loc-1');

        final duplicateCount = await db.customSelect(
          '''
          SELECT COUNT(*) AS count
          FROM locations
          WHERE work_id = ? AND LOWER(TRIM(name)) = LOWER(TRIM(?))
          ''',
          variables: const [
            Variable<String>('work-1'),
            Variable<String>(' harbor '),
          ],
          readsFrom: {db.locations},
        ).getSingle();
        expect(duplicateCount.read<int>('count'), 1);

        final insertDuplicate = () => db.customStatement(
          '''
          INSERT INTO locations (
            id, work_id, name, type, parent_id, description, important_places,
            is_archived, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            'loc-new',
            'work-1',
            'Harbor',
            null,
            null,
            null,
            null,
            0,
            DateTime(2026, 4, 1).millisecondsSinceEpoch,
            DateTime(2026, 4, 1).millisecondsSinceEpoch,
          ],
        );
        expect(insertDuplicate, throwsA(isA<sqlite.SqliteException>()));

        final chapterIds = await (db.select(
          db.chapters,
        )..where((table) => table.workId.equals('work-1'))).get();
        expect(chapterIds.map((chapter) => chapter.id), ['chapter-1']);
      } finally {
        await database?.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}

void _loadSqliteForWindows() {
  if (!Platform.isWindows) {
    return;
  }

  final candidates = <String>[
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
}

Future<void> _createVersion8Database(File dbFile) async {
  final database = sqlite.sqlite3.open(dbFile.path);

  try {
    database.execute('PRAGMA user_version = 8;');
    database.execute('PRAGMA foreign_keys = OFF;');

    database.execute('''
      CREATE TABLE works (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT,
        description TEXT,
        cover_path TEXT,
        target_words INTEGER,
        current_words INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'draft',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    database.execute('''
      CREATE TABLE volumes (
        id TEXT NOT NULL PRIMARY KEY,
        work_id TEXT NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');

    database.execute('''
      CREATE TABLE chapters (
        id TEXT NOT NULL PRIMARY KEY,
        volume_id TEXT NOT NULL,
        work_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        word_count INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'draft',
        review_score REAL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    database.execute('''
      CREATE TABLE locations (
        id TEXT NOT NULL PRIMARY KEY,
        work_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT,
        parent_id TEXT,
        description TEXT,
        important_places TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    final workTimestamp = DateTime(2026, 4, 1).millisecondsSinceEpoch;
    final chapterTimestamp = DateTime(2026, 4, 2).millisecondsSinceEpoch;

    database.execute(
      '''
      INSERT INTO works (id, name, created_at, updated_at)
      VALUES ('work-1', 'Migration Work', ?, ?);
      ''',
      [workTimestamp, workTimestamp],
    );
    database.execute(
      '''
      INSERT INTO volumes (id, work_id, name, sort_order, created_at)
      VALUES ('volume-1', 'work-1', 'Volume 1', 0, ?);
      ''',
      [workTimestamp],
    );
    database.execute(
      '''
      INSERT INTO chapters (
        id, volume_id, work_id, title, content, word_count, sort_order,
        status, created_at, updated_at
      ) VALUES (
        'chapter-1', 'volume-1', 'work-1', 'Opening', 'Legacy content',
        2, 0, 'draft', ?, ?
      );
      ''',
      [chapterTimestamp, chapterTimestamp],
    );

    final locationRows = <List<Object?>>[
      [
        'loc-1',
        'work-1',
        'Harbor',
        null,
        null,
        'Primary record',
        null,
        0,
        workTimestamp,
        workTimestamp,
      ],
      [
        'loc-2',
        'work-1',
        ' harbor ',
        null,
        null,
        'Duplicate spacing/case',
        null,
        0,
        workTimestamp + 1,
        workTimestamp + 1,
      ],
      [
        'loc-3',
        'work-1',
        'Warehouse',
        null,
        'loc-2',
        'Child of duplicate',
        null,
        0,
        workTimestamp + 2,
        workTimestamp + 2,
      ],
      [
        'loc-4',
        'work-1',
        'Cliff',
        null,
        null,
        'Unaffected record',
        null,
        0,
        workTimestamp + 3,
        workTimestamp + 3,
      ],
    ];

    final statement = database.prepare('''
      INSERT INTO locations (
        id, work_id, name, type, parent_id, description, important_places,
        is_archived, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    try {
      for (final row in locationRows) {
        statement.execute(row);
      }
    } finally {
      statement.dispose();
    }
  } finally {
    database.dispose();
  }
}
