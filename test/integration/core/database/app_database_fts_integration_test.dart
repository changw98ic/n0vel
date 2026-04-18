@Tags(['integration'])
library;

import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
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

Future<({String workId, String volumeId})> _seedWorkGraph(
  AppDatabase db,
) async {
  const workId = 'work-1';
  const volumeId = 'volume-1';
  final now = DateTime.utc(2026, 1, 1);

  await db
      .into(db.works)
      .insert(
        WorksCompanion.insert(
          id: workId,
          name: 'FTS Test Work',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.volumes)
      .insert(
        VolumesCompanion.insert(
          id: volumeId,
          workId: workId,
          name: 'Volume One',
          createdAt: now,
        ),
      );

  return (workId: workId, volumeId: volumeId);
}

Future<void> _insertChapter(
  AppDatabase db, {
  required String id,
  required String workId,
  required String volumeId,
  required int sortOrder,
  required String title,
  required String content,
}) async {
  final now = DateTime.utc(2026, 1, 1, 0, 0, 0, id.codeUnitAt(id.length - 1));

  await db
      .into(db.chapters)
      .insert(
        ChaptersCompanion.insert(
          id: id,
          workId: workId,
          volumeId: volumeId,
          title: title,
          content: Value(content),
          sortOrder: Value(sortOrder),
          wordCount: Value(
            content
                .split(RegExp(r'\s+'))
                .where((part) => part.isNotEmpty)
                .length,
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<List<String>> _searchTitles(AppDatabase db, String query) async {
  final rows = await db
      .customSelect(
        '''
      SELECT title
      FROM chapters_fts
      WHERE chapters_fts MATCH ?
      ORDER BY rowid
    ''',
        variables: [Variable.withString(query)],
      )
      .get();

  return rows.map((row) => row.read<String>('title')).toList();
}

Future<int> _ftsRowCount(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS count FROM chapters_fts;')
      .getSingle();
  return row.read<int>('count');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadSqlite3WithFts5);

  group('AppDatabase FTS integration', () {
    late Directory tempDir;
    late AppDatabase database;
    late ({String workId, String volumeId}) graph;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wa_db_fts_');
      final dbPath = p.join(tempDir.path, 'fts.sqlite');
      database = _openDatabase(dbPath);
      graph = await _seedWorkGraph(database);
    });

    tearDown(() async {
      await database.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('insert trigger writes chapter content into chapters_fts', () async {
      await _insertChapter(
        database,
        id: 'chapter-1',
        workId: graph.workId,
        volumeId: graph.volumeId,
        sortOrder: 0,
        title: 'Meteor Arrival',
        content: 'meteor signal reaches the hidden observatory',
      );

      expect(await _searchTitles(database, 'meteor'), ['Meteor Arrival']);
      expect(await _searchTitles(database, 'observatory'), ['Meteor Arrival']);
      expect(await _ftsRowCount(database), 1);
    });

    test('update and delete triggers keep chapters_fts in sync', () async {
        await _insertChapter(
          database,
          id: 'chapter-1',
          workId: graph.workId,
          volumeId: graph.volumeId,
          sortOrder: 0,
          title: 'Meteor Arrival',
          content: 'meteor signal reaches the hidden observatory',
        );

        await (database.update(
          database.chapters,
        )..where((table) => table.id.equals('chapter-1'))).write(
          ChaptersCompanion(
            title: const Value('Nebula Aftermath'),
            content: const Value('nebula ember glows above the archive'),
            updatedAt: Value(DateTime.utc(2026, 1, 2)),
          ),
        );

        expect(await _searchTitles(database, 'meteor'), isEmpty);
        expect(await _searchTitles(database, 'nebula'), ['Nebula Aftermath']);
        expect(await _searchTitles(database, 'archive'), ['Nebula Aftermath']);
        expect(await _ftsRowCount(database), 1);

        await (database.delete(
          database.chapters,
        )..where((table) => table.id.equals('chapter-1'))).go();

        final remaining = await (database.select(
          database.chapters,
        )..where((table) => table.id.equals('chapter-1'))).getSingleOrNull();
        expect(remaining, isNull);
        expect(await _searchTitles(database, 'nebula'), isEmpty);
        expect(await _ftsRowCount(database), 0);
      },
    );

    test(
      'createFTSIndexes rebuilds table, backfills rows, and restores triggers',
      () async {
        await _insertChapter(
          database,
          id: 'chapter-1',
          workId: graph.workId,
          volumeId: graph.volumeId,
          sortOrder: 0,
          title: 'Signal One',
          content: 'aurora beacon lights the canyon',
        );
        await _insertChapter(
          database,
          id: 'chapter-2',
          workId: graph.workId,
          volumeId: graph.volumeId,
          sortOrder: 1,
          title: 'Signal Two',
          content: 'ember beacon wakes the harbor',
        );

        await database.customStatement('DROP TRIGGER IF EXISTS chapters_ai');
        await database.customStatement('DROP TRIGGER IF EXISTS chapters_ad');
        await database.customStatement('DROP TRIGGER IF EXISTS chapters_au');
        await database.customStatement('DROP TABLE IF EXISTS chapters_fts');

        await database.createFTSIndexes();

        expect(await _searchTitles(database, 'beacon'), [
          'Signal One',
          'Signal Two',
        ]);
        expect(await _searchTitles(database, 'canyon'), ['Signal One']);
        expect(await _searchTitles(database, 'harbor'), ['Signal Two']);
        expect(await _ftsRowCount(database), 2);

        await _insertChapter(
          database,
          id: 'chapter-3',
          workId: graph.workId,
          volumeId: graph.volumeId,
          sortOrder: 2,
          title: 'Signal Three',
          content: 'lighthouse beacon answers the storm',
        );

        expect(await _searchTitles(database, 'lighthouse'), ['Signal Three']);
        expect(await _searchTitles(database, 'beacon'), [
          'Signal One',
          'Signal Two',
          'Signal Three',
        ]);
        expect(await _ftsRowCount(database), 3);
      },
    );
  });
}
