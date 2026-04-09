import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/works.dart';
import 'tables/characters.dart';
import 'tables/relationships.dart';
import 'tables/items_locations.dart';
import 'tables/factions_events.dart';
import 'tables/workflow.dart';
import 'tables/reading_progress.dart';
import 'tables/ai_usage.dart';
import 'tables/pov_templates.dart';
import 'tables/agent_runs.dart';
import 'tables/story_arcs.dart';
import 'tables/writing_stats.dart';
import 'tables/chapter_versions.dart';
import 'tables/inspirations.dart';
import 'tables/chat_tables.dart';

part 'database.g.dart';

/// 应用数据库
@DriftDatabase(
  tables: [
    Works,
    Volumes,
    Chapters,
    Characters,
    CharacterProfiles,
    RelationshipHeads,
    RelationshipEvents,
    Items,
    Locations,
    LocationCharacters,
    Factions,
    FactionMembers,
    Events,
    EventCharacters,
    AiTasks,
    WorkflowNodeRuns,
    WorkflowCheckpoints,
    AgentRuns,
    AgentSteps,
    ChapterCharacters,
    ReadingProgressTable,
    Bookmarks,
    ReadingNotes,
    ReadingHighlights,
    ReadingSessions,
    AIUsageRecords,
    AIUsageSummaries,
    POVTemplateRecords,
    StoryArcs,
    ArcChapters,
    ArcCharacters,
    Foreshadows,
    WritingSessionsTable,
    DailyWritingStats,
    ChapterVersions,
    Inspirations,
    InspirationCollections,
    InspirationCollectionItems,
    ChatConversations,
    ChatMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.connect(DatabaseConnection connection) : super(connection);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // 版本 2: 添加 AI 使用统计表
        if (from < 2) {
          await m.createTable(aIUsageRecords);
          await m.createTable(aIUsageSummaries);
        }
        // 版本 3: 添加 POV 模板表
        if (from < 3) {
          await m.createTable(pOVTemplateRecords);
        }
        // 版本 4: 添加 Agent 运行记录表
        if (from < 4) {
          await m.createTable(agentRuns);
          await m.createTable(agentSteps);
        }
        // 版本 5: 添加故事弧线和伏笔追踪表
        if (from < 5) {
          await m.createTable(storyArcs);
          await m.createTable(arcChapters);
          await m.createTable(arcCharacters);
          await m.createTable(foreshadows);
        }
        // 版本 6: 添加写作统计表
        if (from < 6) {
          await m.createTable(writingSessionsTable);
          await m.createTable(dailyWritingStats);
        }
        // 版本 7: 添加章节版本和灵感素材表
        if (from < 7) {
          await m.createTable(chapterVersions);
          await m.createTable(inspirations);
          await m.createTable(inspirationCollections);
          await m.createTable(inspirationCollectionItems);
        }
        // 版本 8: 添加 AI 对话表
        if (from < 8) {
          await m.createTable(chatConversations);
          await m.createTable(chatMessages);
        }
        // 版本 9: 地点去重 + 添加唯一索引
        if (from < 9) {
          // 合并同名地点：保留最早创建的，删除重复项
          await customStatement('''
            DELETE FROM locations WHERE id NOT IN (
              SELECT MIN(id) FROM locations GROUP BY work_id, LOWER(TRIM(name))
            )
          ''');
          // 将被删除地点的子地点重定向到保留的地点
          await customStatement('''
            UPDATE locations SET parent_id = (
              SELECT keep.id FROM locations keep
              WHERE keep.work_id = locations.work_id
              AND LOWER(TRIM(keep.name)) = LOWER(TRIM((
                SELECT del.name FROM locations del WHERE del.id = locations.parent_id
              ))
            )
            AND keep.id = (
              SELECT MIN(k2.id) FROM locations k2
              WHERE k2.work_id = locations.work_id
              AND LOWER(TRIM(k2.name)) = LOWER(TRIM((
                SELECT del.name FROM locations del WHERE del.id = locations.parent_id
              ))
            )
            )
            )
            WHERE locations.parent_id IS NOT NULL
            AND locations.parent_id NOT IN (SELECT id FROM locations)
          ''');
          // 创建唯一索引
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_locations_work_name ON locations (work_id, name)',
          );
        }
      },
      beforeOpen: (details) async {
        // 启用外键约束
        await customStatement('PRAGMA foreign_keys = ON');
        // 启用 WAL 模式（更好的并发性能）
        await customStatement('PRAGMA journal_mode = WAL');
        await createFTSIndexes();
      },
    );
  }

  /// 创建全文搜索索引
  Future<void> createFTSIndexes() async {
    // 先删除旧的触发器和 FTS 表，确保 schema 一致
    await customStatement('DROP TRIGGER IF EXISTS chapters_ai');
    await customStatement('DROP TRIGGER IF EXISTS chapters_ad');
    await customStatement('DROP TRIGGER IF EXISTS chapters_au');
    await customStatement('DROP TABLE IF EXISTS chapters_fts');

    await customStatement('''
      CREATE VIRTUAL TABLE chapters_fts USING fts5(
        title,
        content,
        content_rowid=rowid,
        tokenize='unicode61'
      );
    ''');

    await customStatement('''
      CREATE TRIGGER chapters_ai AFTER INSERT ON chapters BEGIN
        INSERT INTO chapters_fts(rowid, title, content)
        VALUES (new.rowid, new.title, new.content);
      END;
    ''');

    await customStatement('''
      CREATE TRIGGER chapters_ad AFTER DELETE ON chapters BEGIN
        INSERT INTO chapters_fts(chapters_fts, rowid, title, content)
        VALUES ('delete', old.rowid, old.title, old.content);
      END;
    ''');

    await customStatement('''
      CREATE TRIGGER chapters_au AFTER UPDATE ON chapters BEGIN
        INSERT INTO chapters_fts(chapters_fts, rowid, title, content)
        VALUES ('delete', old.rowid, old.title, old.content);
        INSERT INTO chapters_fts(rowid, title, content)
        VALUES (new.rowid, new.title, new.content);
      END;
    ''');

    // 从现有数据重建 FTS 索引
    await customStatement('''
      INSERT INTO chapters_fts(rowid, title, content)
      SELECT rowid, title, content FROM chapters;
    ''');
  }

  /// 重建 FTS 索引（触发器失败时调用）
  Future<void> rebuildFTSIfNeeded() async {
    await createFTSIndexes();
  }

  /// 清理所有数据（用于测试）
  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}

/// 打开数据库连接
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'writing_assistant.db'));
    return NativeDatabase.createInBackground(file);
  });
}
