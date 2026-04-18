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

/// 搴旂敤鏁版嵁搴?
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
        // 鐗堟湰 2: 娣诲姞 AI 浣跨敤缁熻琛?
        if (from < 2) {
          await m.createTable(aIUsageRecords);
          await m.createTable(aIUsageSummaries);
        }
        // 鐗堟湰 3: 娣诲姞 POV 妯℃澘琛?
        if (from < 3) {
          await m.createTable(pOVTemplateRecords);
        }
        // 鐗堟湰 4: 娣诲姞 Agent 杩愯璁板綍琛?
        if (from < 4) {
          await m.createTable(agentRuns);
          await m.createTable(agentSteps);
        }
        // 鐗堟湰 5: 娣诲姞鏁呬簨寮х嚎鍜屼紡绗旇拷韪〃
        if (from < 5) {
          await m.createTable(storyArcs);
          await m.createTable(arcChapters);
          await m.createTable(arcCharacters);
          await m.createTable(foreshadows);
        }
        // 鐗堟湰 6: 娣诲姞鍐欎綔缁熻琛?
        if (from < 6) {
          await m.createTable(writingSessionsTable);
          await m.createTable(dailyWritingStats);
        }
        // 鐗堟湰 7: 娣诲姞绔犺妭鐗堟湰鍜岀伒鎰熺礌鏉愯〃
        if (from < 7) {
          await m.createTable(chapterVersions);
          await m.createTable(inspirations);
          await m.createTable(inspirationCollections);
          await m.createTable(inspirationCollectionItems);
        }
        // 鐗堟湰 8: 娣诲姞 AI 瀵硅瘽琛?
        if (from < 8) {
          await m.createTable(chatConversations);
          await m.createTable(chatMessages);
        }
        // 鐗堟湰 9: 鍦扮偣鍘婚噸 + 娣诲姞鍞竴绱㈠紩
        if (from < 9) {
          await customStatement('DROP TABLE IF EXISTS _location_dedupe_map');
          await customStatement('''
            CREATE TEMP TABLE _location_dedupe_map AS
            SELECT
              duplicate_location.id AS duplicate_id,
              (
                SELECT MIN(keep_location.id)
                FROM locations AS keep_location
                WHERE keep_location.work_id = duplicate_location.work_id
                  AND LOWER(TRIM(keep_location.name)) =
                      LOWER(TRIM(duplicate_location.name))
              ) AS keep_id
            FROM locations AS duplicate_location
            WHERE duplicate_location.id != (
              SELECT MIN(keep_location.id)
              FROM locations AS keep_location
              WHERE keep_location.work_id = duplicate_location.work_id
                AND LOWER(TRIM(keep_location.name)) =
                    LOWER(TRIM(duplicate_location.name))
            )
          ''');
          await customStatement('''
            UPDATE locations
            SET parent_id = (
              SELECT keep_id
              FROM _location_dedupe_map
              WHERE duplicate_id = locations.parent_id
            )
            WHERE parent_id IN (
              SELECT duplicate_id FROM _location_dedupe_map
            )
          ''');          // 鍚堝苟鍚屽悕鍦扮偣锛氫繚鐣欐渶鏃╁垱寤虹殑锛屽垹闄ら噸澶嶉」
          await customStatement('''
            DELETE FROM locations WHERE id NOT IN (
              SELECT MIN(id) FROM locations GROUP BY work_id, LOWER(TRIM(name))
            )
          ''');
          // 灏嗚鍒犻櫎鍦扮偣鐨勫瓙鍦扮偣閲嶅畾鍚戝埌淇濈暀鐨勫湴鐐?
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
          // 鍒涘缓鍞竴绱㈠紩
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_locations_work_name ON locations (work_id, name)',
          );
          await customStatement('DROP TABLE IF EXISTS _location_dedupe_map');
        }
      },
      beforeOpen: (details) async {
        // 鍚敤澶栭敭绾︽潫
        await customStatement('PRAGMA foreign_keys = ON');
        // 鍚敤 WAL 妯″紡锛堟洿濂界殑骞跺彂鎬ц兘锛?
        await customStatement('PRAGMA journal_mode = WAL');
        await createFTSIndexes();
      },
    );
  }

  /// 鍒涘缓鍏ㄦ枃鎼滅储绱㈠紩
  Future<void> createFTSIndexes() async {
    // 鍏堝垹闄ゆ棫鐨勮Е鍙戝櫒鍜?FTS 琛紝纭繚 schema 涓€鑷?
    await customStatement('DROP TRIGGER IF EXISTS chapters_ai');
    await customStatement('DROP TRIGGER IF EXISTS chapters_ad');
    await customStatement('DROP TRIGGER IF EXISTS chapters_au');
    await customStatement('DROP TABLE IF EXISTS chapters_fts');

    await customStatement('''
      CREATE VIRTUAL TABLE chapters_fts USING fts5(
        title,
        content,
        content='chapters',
        content_rowid='rowid',
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

    // 浠庣幇鏈夋暟鎹噸寤?FTS 绱㈠紩
    await customStatement(
      "INSERT INTO chapters_fts(chapters_fts) VALUES ('rebuild');",
    );
  }

  /// 閲嶅缓 FTS 绱㈠紩锛堣Е鍙戝櫒澶辫触鏃惰皟鐢級
  Future<void> rebuildFTSIfNeeded() async {
    await createFTSIndexes();
  }

  /// 娓呯悊鎵€鏈夋暟鎹紙鐢ㄤ簬娴嬭瘯锛?
  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}

/// 鎵撳紑鏁版嵁搴撹繛鎺?
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'writing_assistant.db'));
    return NativeDatabase.createInBackground(file);
  });
}

