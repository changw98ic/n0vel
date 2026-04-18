// 集成测试：直接使用真实数据库测试章节删除
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:writing_assistant/core/config/app_env.dart';
import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';

class _TestAppDatabase extends AppDatabase {
  _TestAppDatabase(String path)
    : super.connect(
        DatabaseConnection(NativeDatabase.createInBackground(File(path))),
      );

  @override
  Future<void> createFTSIndexes() async {
    // 测试环境可能没有 FTS5，先清理旧触发器避免触发
    try {
      await customStatement('DROP TRIGGER IF EXISTS chapters_ai');
      await customStatement('DROP TRIGGER IF EXISTS chapters_ad');
      await customStatement('DROP TRIGGER IF EXISTS chapters_au');
      await customStatement('DROP TABLE IF EXISTS chapters_fts');
    } catch (_) {}
  }
}

void main() {
  late AppDatabase database;
  late ChapterRepository repository;
  late String dbPath;

  setUp(() async {
    dbPath = AppEnv.testDbPath;

    // 复制数据库到临时文件，避免破坏真实数据
    final tempDir = Directory.systemTemp.createTempSync('wa_test_');
    final tempDbPath = p.join(tempDir.path, 'test.db');
    await File(dbPath).copy(tempDbPath);

    database = _TestAppDatabase(tempDbPath);
    repository = ChapterRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('删除真实数据库中的章节', () async {
    // 1. 查看真实数据库中有多少章节
    final chapters = await (
      database.select(database.chapters)
        ..limit(10)
    ).get();

    print('=== 真实数据库章节列表 ===');
    for (final ch in chapters) {
      print('  ID: ${ch.id} | 作品: ${ch.workId} | 标题: ${ch.title}');
    }
    print('共 ${chapters.length} 个章节（显示前10个）');

    if (chapters.isEmpty) {
      print('没有章节可测试');
      return;
    }

    // 2. 检查关联数据
    final arcChapters = await database.select(database.arcChapters).get();
    final storyArcs = await database.select(database.storyArcs).get();
    final foreshadows = await database.select(database.foreshadows).get();

    print('\n=== 关联数据 ===');
    print('弧线-章节关联: ${arcChapters.length} 条');
    print('故事弧线: ${storyArcs.length} 条');
    print('伏笔: ${foreshadows.length} 条');

    for (final ac in arcChapters) {
      print('  arc_chapter: arcId=${ac.arcId}, chapterId=${ac.chapterId}');
    }
    for (final sa in storyArcs) {
      print('  story_arc: id=${sa.id}, start=${sa.startChapterId}, end=${sa.endChapterId}');
    }
    for (final fs in foreshadows) {
      print('  foreshadow: id=${fs.id}, plant=${fs.plantChapterId}, payoff=${fs.payoffChapterId}');
    }

    // 3. 选择一个有外键关联的章节来测试删除
    // 优先选择被 arc_chapters 引用的章节
    String? targetChapterId;
    if (arcChapters.isNotEmpty) {
      targetChapterId = arcChapters.first.chapterId;
    }
    // 如果没有被关联的，直接选第一个
    targetChapterId ??= chapters.first.id;

    final targetChapter = chapters.firstWhere(
      (c) => c.id == targetChapterId,
      orElse: () => chapters.first,
    );

    print('\n=== 测试删除章节 ===');
    print('目标章节: ID=${targetChapter.id}, 标题=${targetChapter.title}');

    // 4. 执行删除
    try {
      await repository.deleteChapter(targetChapter.id);
      print('删除成功!');

      // 5. 验证章节已删除
      final remaining = await (
        database.select(database.chapters)
          ..where((t) => t.id.equals(targetChapter.id))
      ).get();
      expect(remaining, isEmpty, reason: '章节应该已被删除');
      print('验证通过: 章节已从数据库中移除');

    } catch (e) {
      print('删除失败: $e');
      fail('删除章节失败: $e');
    }
  });
}
