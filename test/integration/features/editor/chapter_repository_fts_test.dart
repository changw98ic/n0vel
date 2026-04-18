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
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';

const _workId = 'work-1';
const _volumeId = 'volume-1';
const _chapterOneId = 'chapter-1';
const _chapterTwoId = 'chapter-2';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadSqlite3WithFts5);

  group('ChapterRepository FTS integration', () {
    late Directory tempDir;
    late AppDatabase database;
    late ChapterRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'chapter_repository_fts_test_',
      );
      database = AppDatabase.connect(
        DatabaseConnection(
          NativeDatabase(
            File(p.join(tempDir.path, 'chapter_repository_fts.db')),
          ),
        ),
      );
      repository = ChapterRepository(database);
      await _seedStory(database);
    });

    tearDown(() async {
      await database.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('searchChapters matches title via LIKE and content via FTS', () async {
      final titleResults = await repository.searchChapters(_workId, 'harbor');
      final contentResults = await repository.searchChapters(
        _workId,
        'phoenix',
      );

      expect(titleResults.map((chapter) => chapter.id), [_chapterOneId]);
      expect(contentResults.map((chapter) => chapter.id), [_chapterOneId]);
      expect(contentResults.single.title, 'Silent Harbor');
    });

    test(
      'updateContent refreshes content search and syncs work word count',
      () async {
        await repository.updateContent(
          _chapterOneId,
          'meteor signal returns at dawn',
          5,
        );

        final updatedChapter = await _chapterById(database, _chapterOneId);
        final updatedWork = await _workById(database, _workId);
        final updatedSearch = await repository.searchChapters(
          _workId,
          'meteor',
        );
        final staleSearch = await repository.searchChapters(_workId, 'phoenix');

        expect(updatedChapter.content, 'meteor signal returns at dawn');
        expect(updatedChapter.wordCount, 5);
        expect(updatedWork.currentWords, 8);
        expect(updatedSearch.map((chapter) => chapter.id), [_chapterOneId]);
        expect(staleSearch, isEmpty);
      },
    );

    test(
      'deleteChapter removes title/content hits and syncs work word count',
      () async {
        expect(
          (await repository.searchChapters(
            _workId,
            'harbor',
          )).map((chapter) => chapter.id),
          [_chapterOneId],
        );
        expect(
          (await repository.searchChapters(
            _workId,
            'phoenix',
          )).map((chapter) => chapter.id),
          [_chapterOneId],
        );

        await repository.deleteChapter(_chapterOneId);

        final deletedChapter = await repository.getChapterById(_chapterOneId);
        final updatedWork = await _workById(database, _workId);

        expect(deletedChapter, isNull);
        expect(await repository.searchChapters(_workId, 'harbor'), isEmpty);
        expect(await repository.searchChapters(_workId, 'phoenix'), isEmpty);
        expect(updatedWork.currentWords, 3);
      },
    );

    test(
      'updateContent survives broken FTS trigger and rebuild restores content search',
      () async {
        await database.customStatement('DROP TRIGGER IF EXISTS chapters_au');
        await database.customStatement('''
          CREATE TRIGGER chapters_au AFTER UPDATE ON chapters BEGIN
            SELECT RAISE(ABORT, 'broken update trigger');
          END;
        ''');

        await repository.updateContent(
          _chapterOneId,
          'afterglow signal recovered',
          3,
        );

        final updatedChapter = await _chapterById(database, _chapterOneId);
        final updatedWork = await _workById(database, _workId);
        final titleSearch = await repository.searchChapters(_workId, 'harbor');
        final preRebuildContentSearch = await repository.searchChapters(
          _workId,
          'afterglow',
        );

        expect(updatedChapter.content, 'afterglow signal recovered');
        expect(updatedChapter.wordCount, 3);
        expect(updatedWork.currentWords, 6);
        expect(titleSearch.map((chapter) => chapter.id), [_chapterOneId]);
        expect(preRebuildContentSearch, isEmpty);

        await database.rebuildFTSIfNeeded();

        final rebuiltSearch = await repository.searchChapters(
          _workId,
          'afterglow',
        );
        final staleSearch = await repository.searchChapters(_workId, 'phoenix');

        expect(rebuiltSearch.map((chapter) => chapter.id), [_chapterOneId]);
        expect(staleSearch, isEmpty);
      },
    );
  });
}

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

  throw StateError('Unable to find sqlite3.dll with FTS5 support');
}

Future<void> _seedStory(AppDatabase database) async {
  final workNow = DateTime(2026, 4, 14, 8);
  final volumeNow = DateTime(2026, 4, 14, 9);
  final chapterOneNow = DateTime(2026, 4, 14, 10);
  final chapterTwoNow = DateTime(2026, 4, 14, 11);

  await database
      .into(database.works)
      .insert(
        WorksCompanion(
          id: const Value(_workId),
          name: const Value('FTS Work'),
          currentWords: const Value(999),
          createdAt: Value(workNow),
          updatedAt: Value(workNow),
        ),
      );

  await database
      .into(database.volumes)
      .insert(
        VolumesCompanion(
          id: const Value(_volumeId),
          workId: const Value(_workId),
          name: const Value('Volume One'),
          sortOrder: const Value(1),
          createdAt: Value(volumeNow),
        ),
      );

  await database
      .into(database.chapters)
      .insert(
        ChaptersCompanion(
          id: const Value(_chapterOneId),
          volumeId: const Value(_volumeId),
          workId: const Value(_workId),
          title: const Value('Silent Harbor'),
          content: const Value('phoenix ember charted course'),
          wordCount: const Value(4),
          sortOrder: const Value(1),
          createdAt: Value(chapterOneNow),
          updatedAt: Value(chapterOneNow),
        ),
      );

  await database
      .into(database.chapters)
      .insert(
        ChaptersCompanion(
          id: const Value(_chapterTwoId),
          volumeId: const Value(_volumeId),
          workId: const Value(_workId),
          title: const Value('Clockwork Orchard'),
          content: const Value('violet sparrow north'),
          wordCount: const Value(3),
          sortOrder: const Value(2),
          createdAt: Value(chapterTwoNow),
          updatedAt: Value(chapterTwoNow),
        ),
      );
}

Future<Chapter> _chapterById(AppDatabase database, String chapterId) {
  return (database.select(
    database.chapters,
  )..where((table) => table.id.equals(chapterId))).getSingle();
}

Future<Work> _workById(AppDatabase database, String workId) {
  return (database.select(
    database.works,
  )..where((table) => table.id.equals(workId))).getSingle();
}
