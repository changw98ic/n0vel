import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';

void main() {
  late AppDatabase database;
  late ChapterRepository repository;

  setUp(() async {
    database = _TestAppDatabase();
    repository = ChapterRepository(database);
    await _seedWork(database);
    await _seedVolume(database);
    await _seedChapter(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'createOrGetChapterByTitle reuses existing chapter with same title',
    () async {
      final chapter = await repository.createOrGetChapterByTitle(
        workId: 'work-1',
        volumeId: 'volume-1',
        title: '第一章',
        sortOrder: 99,
      );

      final chapters = await repository.getChaptersByWorkId('work-1');

      expect(chapter.id, 'chapter-1');
      expect(chapters, hasLength(1));
    },
  );

  test('updateContent throws when chapter does not exist', () async {
    const validContent =
        '夜色沉沉，旧城门前只剩零星火把在风里摇晃。巡夜人踩着湿冷石板缓缓走过，'
        '忽然听见巷口传来极轻的一声金属碰撞。他停下脚步，屏住呼吸，才发现黑暗里'
        '有人正把一封密信塞进废弃神龛。';
    expect(
      () => repository.updateContent(
        'missing-chapter',
        validContent,
        validContent.length,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('missing-chapter'),
        ),
      ),
    );
  });

  test('deleteChapter succeeds with foreign key references', () async {
    // 创建第二个章节用于关联测试
    final now = DateTime(2026, 4, 10, 10);
    await database
        .into(database.chapters)
        .insert(
          ChaptersCompanion(
            id: const Value('chapter-2'),
            volumeId: const Value('volume-1'),
            workId: const Value('work-1'),
            title: const Value('第二章'),
            content: const Value('正文内容'),
            wordCount: const Value(4),
            sortOrder: const Value(2),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    // 创建弧线，引用 chapter-1 和 chapter-2
    await database
        .into(database.storyArcs)
        .insert(
          StoryArcsCompanion(
            id: const Value('arc-1'),
            workId: const Value('work-1'),
            name: const Value('主线'),
            arcType: const Value('main'),
            startChapterId: const Value('chapter-1'),
            endChapterId: const Value('chapter-2'),
            createdAt: Value(now),
          ),
        );

    // 创建弧线-章节关联
    await database
        .into(database.arcChapters)
        .insert(
          ArcChaptersCompanion(
            id: const Value('ac-1'),
            arcId: const Value('arc-1'),
            chapterId: const Value('chapter-1'),
          ),
        );

    // 创建伏笔，引用 chapter-1 和 chapter-2
    await database
        .into(database.foreshadows)
        .insert(
          ForeshadowsCompanion(
            id: const Value('fs-1'),
            workId: const Value('work-1'),
            description: const Value('一把神秘的钥匙'),
            plantChapterId: const Value('chapter-1'),
            payoffChapterId: const Value('chapter-2'),
            createdAt: Value(now),
          ),
        );

    // 执行删除 chapter-1（有外键关联的章节）
    await expectLater(repository.deleteChapter('chapter-1'), completes);

    // 验证章节已删除
    final chapters = await repository.getChaptersByWorkId('work-1');
    expect(chapters, hasLength(1));
    expect(chapters.first.id, 'chapter-2');

    // 验证弧线-章节关联已删除
    final arcChapters = await (database.select(
      database.arcChapters,
    )..where((t) => t.chapterId.equals('chapter-1'))).get();
    expect(arcChapters, isEmpty);

    // 验证弧线的 startChapterId 已置空
    final arcs = await (database.select(
      database.storyArcs,
    )..where((t) => t.id.equals('arc-1'))).get();
    expect(arcs.first.startChapterId, equals(null));
    expect(arcs.first.endChapterId, 'chapter-2');

    // 验证伏笔的 plantChapterId 已置空
    final foreshadows = await (database.select(
      database.foreshadows,
    )..where((t) => t.id.equals('fs-1'))).get();
    expect(foreshadows.first.plantChapterId, equals(null));
    expect(foreshadows.first.payoffChapterId, 'chapter-2');
  });
}

class _TestAppDatabase extends AppDatabase {
  _TestAppDatabase()
    : super.connect(DatabaseConnection(NativeDatabase.memory()));

  @override
  Future<void> createFTSIndexes() async {}
}

Future<void> _seedWork(AppDatabase database) {
  final now = DateTime(2026, 4, 10);
  return database
      .into(database.works)
      .insert(
        WorksCompanion(
          id: const Value('work-1'),
          name: const Value('测试作品'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> _seedVolume(AppDatabase database) {
  final now = DateTime(2026, 4, 10, 8);
  return database
      .into(database.volumes)
      .insert(
        VolumesCompanion(
          id: const Value('volume-1'),
          workId: const Value('work-1'),
          name: const Value('第一卷'),
          sortOrder: const Value(1),
          createdAt: Value(now),
        ),
      );
}

Future<void> _seedChapter(AppDatabase database) {
  final now = DateTime(2026, 4, 10, 9);
  return database
      .into(database.chapters)
      .insert(
        ChaptersCompanion(
          id: const Value('chapter-1'),
          volumeId: const Value('volume-1'),
          workId: const Value('work-1'),
          title: const Value('第一章'),
          content: const Value('旧正文'),
          wordCount: const Value(3),
          sortOrder: const Value(1),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}
