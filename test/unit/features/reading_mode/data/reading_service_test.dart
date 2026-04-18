import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/features/reading_mode/data/reading_service.dart';
import 'package:writing_assistant/features/reading_mode/domain/reading_models.dart';

void main() {
  late AppDatabase database;
  late ReadingService service;

  setUp(() async {
    database = _TestAppDatabase();
    service = ReadingService(database);
    await _seedWork(database);
    await _seedVolume(database);
    await _seedChapter(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('getWorkBookmarks returns bookmarks in reverse created order', () async {
    await database
        .into(database.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: 'bm-1',
            chapterId: 'chapter-1',
            workId: 'work-1',
            position: 10,
            note: const Value('早一点的书签'),
            createdAt: DateTime(2026, 4, 6, 8),
          ),
        );
    await database
        .into(database.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: 'bm-2',
            chapterId: 'chapter-1',
            workId: 'work-1',
            position: 20,
            note: const Value('更晚的书签'),
            createdAt: DateTime(2026, 4, 6, 9),
          ),
        );

    final bookmarks = await service.getWorkBookmarks('work-1');

    expect(bookmarks.map((item) => item.id), ['bm-2', 'bm-1']);
    expect(bookmarks.first.note, '更晚的书签');
  });

  test('getWorkNotes decodes tags for the whole work', () async {
    await database
        .into(database.readingNotes)
        .insert(
          ReadingNotesCompanion.insert(
            id: 'note-1',
            chapterId: 'chapter-1',
            workId: 'work-1',
            startPosition: 3,
            endPosition: 12,
            selectedText: '片段',
            content: '这段要重写',
            tags: const Value('["情绪","伏笔"]'),
            createdAt: DateTime(2026, 4, 6, 10),
            updatedAt: DateTime(2026, 4, 6, 11),
          ),
        );

    final notes = await service.getWorkNotes('work-1');

    expect(notes, hasLength(1));
    expect(notes.single.tags, ['情绪', '伏笔']);
    expect(notes.single.content, '这段要重写');
  });

  test('getWorkHighlights maps persisted colors back to enum values', () async {
    await database
        .into(database.readingHighlights)
        .insert(
          ReadingHighlightsCompanion.insert(
            id: 'hl-1',
            chapterId: 'chapter-1',
            workId: 'work-1',
            startPosition: 5,
            endPosition: 15,
            selectedText: '高亮段落',
            color: HighlightColor.blue.name,
            createdAt: DateTime(2026, 4, 6, 12),
          ),
        );

    final highlights = await service.getWorkHighlights('work-1');

    expect(highlights, hasLength(1));
    expect(highlights.single.color, HighlightColor.blue);
    expect(highlights.single.selectedText, '高亮段落');
  });
}

class _TestAppDatabase extends AppDatabase {
  _TestAppDatabase()
    : super.connect(DatabaseConnection(NativeDatabase.memory()));

  @override
  Future<void> createFTSIndexes() async {}
}

Future<void> _seedWork(AppDatabase database) {
  final now = DateTime(2026, 4, 6);
  return database
      .into(database.works)
      .insert(
        WorksCompanion(
          id: const Value('work-1'),
          name: const Value('作品一'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}
Future<void> _seedVolume(AppDatabase database) {
  final now = DateTime(2026, 4, 6);
  return database
      .into(database.volumes)
      .insert(
        VolumesCompanion(
          id: const Value('volume-1'),
          workId: const Value('work-1'),
          name: const Value('Volume One'),
          createdAt: Value(now),
        ),
      );
}

Future<void> _seedChapter(AppDatabase database) {
  final now = DateTime(2026, 4, 6, 8);
  return database
      .into(database.chapters)
      .insert(
        ChaptersCompanion(
          id: const Value('chapter-1'),
          volumeId: const Value('volume-1'),
          workId: const Value('work-1'),
          title: const Value('第一章'),
          sortOrder: const Value(1),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}
