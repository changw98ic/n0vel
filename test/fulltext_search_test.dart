import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/fulltext_search_service.dart';
import 'package:novel_writer/app/state/fulltext_search_storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('FulltextSearchStorage', () {
    late Database db;
    late FulltextSearchStorage storage;

    setUp(() {
      db = sqlite3.openInMemory();
      storage = FulltextSearchStorage(db: db);
    });

    tearDown(() {
      db.dispose();
    });

    test('索引和搜索基本英文内容', () async {
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章 开端',
          sceneId: 'scene-1',
          sceneTitle: '主角登场',
          characterNames: '刘锡',
          content: 'The ancient key was hidden in the black tower.',
        ),
      );

      final result = await storage.search(
        projectId: 'proj-1',
        query: 'ancient key',
      );

      expect(result.rows, hasLength(1));
      expect(result.rows.first.sceneId, 'scene-1');
      expect(result.rows.first.snippet, contains('<mark>'));
      expect(result.totalCount, 1);
    });

    test('搜索中文内容（CJK 回退）', () async {
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章 开端',
          sceneId: 'scene-cjk',
          sceneTitle: '黑塔之谜',
          characterNames: '刘锡,柳絮',
          content: '黑塔隐藏在深山之中，蕴含神秘力量。刘锡决定前往调查。',
        ),
      );

      final result = await storage.search(projectId: 'proj-1', query: '黑塔神秘');

      expect(result.rows, isNotEmpty);
      expect(result.rows.first.sceneId, 'scene-cjk');
      expect(result.rows.first.snippet, contains('<mark>'));
    });

    test('按角色名过滤', () async {
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-a',
          sceneTitle: '场景A',
          characterNames: '刘锡',
          content: '刘锡在黑塔中发现了古老的钥匙。',
        ),
      );
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 2,
          chapterTitle: '第二章',
          sceneId: 'scene-b',
          sceneTitle: '场景B',
          characterNames: '柳絮',
          content: '柳絮在森林中遇到了神秘的老人。',
        ),
      );

      // 搜索"黑塔"并过滤角色为"刘锡"
      final result = await storage.search(
        projectId: 'proj-1',
        query: '黑塔',
        characterFilter: '刘锡',
      );

      expect(result.rows, hasLength(1));
      expect(result.rows.first.sceneId, 'scene-a');
    });

    test('按章节范围过滤', () async {
      // 索引 5 个章节
      for (var i = 1; i <= 5; i++) {
        await storage.indexScene(
          FulltextIndexEntry(
            projectId: 'proj-1',
            chapterIndex: i,
            chapterTitle: '第$i章',
            sceneId: 'scene-$i',
            sceneTitle: '场景$i',
            characterNames: '',
            content: '这是第$i章的内容，包含秘密线索。',
          ),
        );
      }

      // 搜索第 2-4 章
      final result = await storage.search(
        projectId: 'proj-1',
        query: '秘密',
        chapterRangeStart: 2,
        chapterRangeEnd: 4,
      );

      expect(result.rows, hasLength(3));
      for (final row in result.rows) {
        expect(row.chapterIndex, inInclusiveRange(2, 4));
      }
    });

    test('分页功能', () async {
      // 索引 25 条数据（使用英文以确保 FTS5 分词正常工作）
      for (var i = 1; i <= 25; i++) {
        await storage.indexScene(
          FulltextIndexEntry(
            projectId: 'proj-1',
            chapterIndex: i,
            chapterTitle: '第$i章',
            sceneId: 'scene-$i',
            sceneTitle: '场景$i',
            characterNames: '',
            content: 'The secret clue appears in paragraph $i of the story.',
          ),
        );
      }

      // 第一页
      final page0 = await storage.search(
        projectId: 'proj-1',
        query: 'secret clue',
        offset: 0,
        limit: 10,
      );
      expect(page0.rows, hasLength(10));
      expect(page0.totalCount, 25);
      expect(page0.page, 0);
      expect(page0.totalPages, 3);
      expect(page0.hasNextPage, isTrue);
      expect(page0.hasPreviousPage, isFalse);

      // 第二页
      final page1 = await storage.search(
        projectId: 'proj-1',
        query: 'secret clue',
        offset: 10,
        limit: 10,
      );
      expect(page1.rows, hasLength(10));
      expect(page1.page, 1);

      // 最后一页
      final page2 = await storage.search(
        projectId: 'proj-1',
        query: 'secret clue',
        offset: 20,
        limit: 10,
      );
      expect(page2.rows, hasLength(5));
      expect(page2.page, 2);
      expect(page2.hasNextPage, isFalse);
      expect(page2.hasPreviousPage, isTrue);
    });

    test('项目隔离：不同项目互不影响', () async {
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '场景1',
          characterNames: '',
          content: '项目一的秘密内容。',
        ),
      );
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-2',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-2',
          sceneTitle: '场景2',
          characterNames: '',
          content: '项目二的秘密内容。',
        ),
      );

      final result = await storage.search(projectId: 'proj-1', query: '秘密');
      expect(result.rows, hasLength(1));
      expect(result.rows.first.sceneId, 'scene-1');
    });

    test('更新索引后搜索到新内容', () async {
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '场景1',
          characterNames: '',
          content: '原始内容包含古老符号。',
        ),
      );

      // 更新内容
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '场景1',
          characterNames: '',
          content: '更新后的内容包含新发现的线索。',
        ),
      );

      // 旧关键词不再匹配
      final oldResult = await storage.search(
        projectId: 'proj-1',
        query: '古老符号',
      );
      expect(oldResult.rows, isEmpty);

      // 新关键词匹配
      final newResult = await storage.search(projectId: 'proj-1', query: '新发现');
      expect(newResult.rows, hasLength(1));
    });

    test('删除场景索引', () async {
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '场景1',
          characterNames: '',
          content: '将被删除的内容。',
        ),
      );

      await storage.removeScene('proj-1', 'scene-1');

      final result = await storage.search(projectId: 'proj-1', query: '删除');
      expect(result.rows, isEmpty);
    });

    test('清空项目索引', () async {
      for (var i = 1; i <= 3; i++) {
        await storage.indexScene(
          FulltextIndexEntry(
            projectId: 'proj-1',
            chapterIndex: i,
            chapterTitle: '第$i章',
            sceneId: 'scene-$i',
            sceneTitle: '场景$i',
            characterNames: '',
            content: '第$i章的测试内容。',
          ),
        );
      }

      await storage.clearProject('proj-1');

      final result = await storage.search(projectId: 'proj-1', query: '测试');
      expect(result.rows, isEmpty);
    });

    test('indexedChapterRange 返回正确范围', () async {
      for (var i = 3; i <= 8; i++) {
        await storage.indexScene(
          FulltextIndexEntry(
            projectId: 'proj-1',
            chapterIndex: i,
            chapterTitle: '第$i章',
            sceneId: 'scene-$i',
            sceneTitle: '场景$i',
            characterNames: '',
            content: '内容$i',
          ),
        );
      }

      final range = await storage.indexedChapterRange('proj-1');
      expect(range, isNotNull);
      expect(range!.$1, 3);
      expect(range.$2, 8);
    });

    test('indexedCharacterNames 返回去重角色列表', () async {
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '场景1',
          characterNames: '刘锡,柳絮',
          content: '内容1',
        ),
      );
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 2,
          chapterTitle: '第二章',
          sceneId: 'scene-2',
          sceneTitle: '场景2',
          characterNames: '刘锡,张三',
          content: '内容2',
        ),
      );

      final names = await storage.indexedCharacterNames('proj-1');
      expect(names, containsAll(['刘锡', '柳絮', '张三']));
      expect(names.length, 3); // 去重
    });

    test('空查询返回空结果', () async {
      await storage.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '场景1',
          characterNames: '',
          content: '内容',
        ),
      );

      final result = await storage.search(projectId: 'proj-1', query: '');
      expect(result.rows, isEmpty);
      expect(result.totalCount, 0);
    });

    test('批量索引失败时回滚已写入的场景', () async {
      await storage.ensureTables();
      db.execute('''
        CREATE TRIGGER fail_fulltext_scene_insert
        BEFORE INSERT ON fulltext_chapter_contents
        WHEN new.scene_id = 'scene-fail'
        BEGIN
          SELECT RAISE(ABORT, 'forced fulltext batch failure');
        END
      ''');

      await expectLater(
        storage.indexScenes([
          const FulltextIndexEntry(
            projectId: 'proj-batch',
            chapterIndex: 1,
            chapterTitle: '第一章',
            sceneId: 'scene-ok',
            sceneTitle: '正常场景',
            characterNames: '',
            content: 'survivor token',
          ),
          const FulltextIndexEntry(
            projectId: 'proj-batch',
            chapterIndex: 2,
            chapterTitle: '第二章',
            sceneId: 'scene-fail',
            sceneTitle: '失败场景',
            characterNames: '',
            content: 'failing token',
          ),
        ]),
        throwsA(isA<SqliteException>()),
      );

      expect(
        db.select(
          'SELECT scene_id FROM fulltext_chapter_contents WHERE project_id = ?',
          ['proj-batch'],
        ),
        isEmpty,
      );
    });

    test('批量索引加入调用方持有的事务', () async {
      await storage.ensureTables();
      db.execute('BEGIN IMMEDIATE');
      try {
        await storage.indexScenes([
          const FulltextIndexEntry(
            projectId: 'proj-outer',
            chapterIndex: 1,
            chapterTitle: '第一章',
            sceneId: 'scene-1',
            sceneTitle: '外层事务场景',
            characterNames: '',
            content: 'outer transaction token',
          ),
        ]);

        expect(
          db.select(
            'SELECT COUNT(*) AS count FROM fulltext_chapter_contents '
            'WHERE project_id = ?',
            ['proj-outer'],
          ).single['count'],
          1,
        );

        db.execute('ROLLBACK');
      } finally {
        if (!db.autocommit) db.execute('ROLLBACK');
      }

      expect(
        db.select(
          'SELECT COUNT(*) AS count FROM fulltext_chapter_contents '
          'WHERE project_id = ?',
          ['proj-outer'],
        ).single['count'],
        0,
      );
    });
  });

  group('FulltextSearchService', () {
    late Database db;
    late FulltextSearchService service;

    setUp(() {
      db = sqlite3.openInMemory();
      service = FulltextSearchService(db: db);
    });

    tearDown(() {
      db.dispose();
    });

    test('indexScene 增量索引成功', () async {
      await service.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '场景1',
          characterNames: '刘锡',
          content: '刘锡在黑暗中发现了线索。',
        ),
      );

      final result = await service.search(projectId: 'proj-1', query: '线索');
      expect(result.rows, hasLength(1));
    });

    test('syncProject 全量同步', () async {
      await service.syncProject(
        projectId: 'proj-1',
        entries: [
          for (var i = 1; i <= 5; i++)
            FulltextIndexEntry(
              projectId: 'proj-1',
              chapterIndex: i,
              chapterTitle: '第$i章',
              sceneId: 'scene-$i',
              sceneTitle: '场景$i',
              characterNames: '',
              content: '第$i章的冒险故事。',
            ),
        ],
      );

      final result = await service.search(projectId: 'proj-1', query: '冒险');
      expect(result.rows, hasLength(5));
    });

    test('批量索引失败时不保留部分结果并上报错误', () async {
      await service.search(projectId: 'bootstrap', query: '');
      db.execute('''
        CREATE TRIGGER fail_service_batch_insert
        BEFORE INSERT ON fulltext_chapter_contents
        WHEN new.scene_id = 'scene-fail'
        BEGIN
          SELECT RAISE(ABORT, 'forced service batch failure');
        END
      ''');

      Object? failure;
      try {
        await service.indexScenes([
          const FulltextIndexEntry(
            projectId: 'proj-service-batch',
            chapterIndex: 1,
            chapterTitle: '第一章',
            sceneId: 'scene-ok',
            sceneTitle: '正常场景',
            characterNames: '',
            content: 'service batch survivor token',
          ),
          const FulltextIndexEntry(
            projectId: 'proj-service-batch',
            chapterIndex: 2,
            chapterTitle: '第二章',
            sceneId: 'scene-fail',
            sceneTitle: '失败场景',
            characterNames: '',
            content: 'service batch failing token',
          ),
        ]);
      } on Object catch (error) {
        failure = error;
      }

      expect(failure, isA<SqliteException>());
      expect(
        db.select(
          'SELECT scene_id FROM fulltext_chapter_contents WHERE project_id = ?',
          ['proj-service-batch'],
        ),
        isEmpty,
      );
    });

    test('syncProject 重建失败时保留原有项目索引', () async {
      await service.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-rebuild',
          chapterIndex: 1,
          chapterTitle: '旧章节',
          sceneId: 'scene-old',
          sceneTitle: '旧场景',
          characterNames: '',
          content: 'stable legacy token',
        ),
      );
      db.execute('''
        CREATE TRIGGER fail_project_rebuild_insert
        BEFORE INSERT ON fulltext_chapter_contents
        WHEN new.scene_id = 'scene-fail'
        BEGIN
          SELECT RAISE(ABORT, 'forced project rebuild failure');
        END
      ''');

      Object? failure;
      try {
        await service.syncProject(
          projectId: 'proj-rebuild',
          entries: [
            const FulltextIndexEntry(
              projectId: 'proj-rebuild',
              chapterIndex: 1,
              chapterTitle: '新章节',
              sceneId: 'scene-ok',
              sceneTitle: '新场景',
              characterNames: '',
              content: 'new replacement token',
            ),
            const FulltextIndexEntry(
              projectId: 'proj-rebuild',
              chapterIndex: 2,
              chapterTitle: '失败章节',
              sceneId: 'scene-fail',
              sceneTitle: '失败场景',
              characterNames: '',
              content: 'failing replacement token',
            ),
          ],
        );
      } on Object catch (error) {
        failure = error;
      }

      expect(failure, isA<SqliteException>());
      final result = await service.search(
        projectId: 'proj-rebuild',
        query: 'stable legacy token',
      );
      expect(result.rows, hasLength(1));
      expect(result.rows.single.sceneId, 'scene-old');
    });

    test('搜索排序：按章节升序', () async {
      // 索引不同章节，内容相同以保证相关度一致
      for (var i = 1; i <= 5; i++) {
        await service.indexScene(
          FulltextIndexEntry(
            projectId: 'proj-1',
            chapterIndex: i,
            chapterTitle: '第$i章',
            sceneId: 'scene-$i',
            sceneTitle: '场景$i',
            characterNames: '',
            content: '秘密出现在每个角落。',
          ),
        );
      }

      final result = await service.search(
        projectId: 'proj-1',
        query: '秘密',
        sortOrder: FulltextSortOrder.chapterAsc,
      );

      expect(result.rows, hasLength(5));
      // 验证升序排列
      for (var i = 0; i < result.rows.length - 1; i++) {
        expect(
          result.rows[i].chapterIndex,
          lessThanOrEqualTo(result.rows[i + 1].chapterIndex),
        );
      }
    });

    test('搜索排序：按章节降序', () async {
      for (var i = 1; i <= 5; i++) {
        await service.indexScene(
          FulltextIndexEntry(
            projectId: 'proj-1',
            chapterIndex: i,
            chapterTitle: '第$i章',
            sceneId: 'scene-$i',
            sceneTitle: '场景$i',
            characterNames: '',
            content: '线索隐藏在每一章。',
          ),
        );
      }

      final result = await service.search(
        projectId: 'proj-1',
        query: '线索',
        sortOrder: FulltextSortOrder.chapterDesc,
      );

      expect(result.rows, hasLength(5));
      for (var i = 0; i < result.rows.length - 1; i++) {
        expect(
          result.rows[i].chapterIndex,
          greaterThanOrEqualTo(result.rows[i + 1].chapterIndex),
        );
      }
    });

    test('分页搜索', () async {
      for (var i = 1; i <= 30; i++) {
        await service.indexScene(
          FulltextIndexEntry(
            projectId: 'proj-1',
            chapterIndex: i,
            chapterTitle: '第$i章',
            sceneId: 'scene-$i',
            sceneTitle: '场景$i',
            characterNames: '',
            content: '关键线索在第$i段中。',
          ),
        );
      }

      final page0 = await service.search(
        projectId: 'proj-1',
        query: '线索',
        page: 0,
        pageSize: 10,
      );
      expect(page0.rows, hasLength(10));
      expect(page0.totalCount, 30);
      expect(page0.hasNextPage, isTrue);
    });

    test('removeScene 删除单个场景索引', () async {
      await service.indexScene(
        const FulltextIndexEntry(
          projectId: 'proj-1',
          chapterIndex: 1,
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '场景1',
          characterNames: '',
          content: '将被删除的冒险。',
        ),
      );

      await service.removeScene('proj-1', 'scene-1');

      final result = await service.search(projectId: 'proj-1', query: '冒险');
      expect(result.rows, isEmpty);
    });
  });

  group('性能测试：100章 × 3000字', () {
    late Database db;
    late FulltextSearchStorage storage;

    setUp(() {
      db = sqlite3.openInMemory();
      storage = FulltextSearchStorage(db: db);
    });

    tearDown(() {
      db.dispose();
    });

    test('100章数据量下搜索在1秒内返回', () async {
      // 生成 100 章，每章 3000 字
      final stopwatch = Stopwatch()..start();

      for (var ch = 1; ch <= 100; ch++) {
        final content = StringBuffer();
        for (var p = 0; p < 30; p++) {
          content.write('第$ch章第${p + 1}段落。');
          content.write('这是一段关于古代遗迹的描述，蕴含着深邃的智慧。');
          content.write('主角刘锡在黑暗中前行，寻找失落的文明线索。');
          content.write('黑塔的秘密等待着勇敢的探索者去揭开。');
        }
        await storage.indexScene(
          FulltextIndexEntry(
            projectId: 'proj-perf',
            chapterIndex: ch,
            chapterTitle: '第$ch章 冒险之旅',
            sceneId: 'scene-$ch',
            sceneTitle: '场景$ch',
            characterNames: '刘锡,柳絮',
            content: content.toString(),
          ),
        );
      }

      stopwatch.stop();

      // 搜索
      final searchStopwatch = Stopwatch()..start();
      final result = await storage.search(
        projectId: 'proj-perf',
        query: '古代遗迹 黑塔',
      );
      searchStopwatch.stop();

      expect(result.rows, isNotEmpty);
      // 搜索应在 1 秒内完成
      expect(searchStopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
