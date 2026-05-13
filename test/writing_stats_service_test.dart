import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_authoring_storage_io_support.dart';
import 'package:novel_writer/app/events/app_domain_events.dart';
import 'package:novel_writer/features/writing_stats/data/writing_stats_service.dart';
import 'package:novel_writer/features/writing_stats/data/writing_stats_storage_io.dart';
import 'package:novel_writer/features/writing_stats/domain/writing_stats_models.dart';

void main() {
  late Directory tempDir;
  late String dbPath;
  late SqliteWritingStatsStorage storage;
  late WritingStatsService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('writing_stats_test_');
    dbPath = '${tempDir.path}/test_authoring.db';
    storage = SqliteWritingStatsStorage(dbPath: dbPath);
    service = WritingStatsService(storage: storage);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ── helper: 确保 DB schema 已迁移 ─────────────────────────────────────────

  void ensureSchema() {
    final db = openAuthoringDatabase(dbPath);
    db.dispose();
  }

  // =========================================================================
  // DB migration V6: writing stats tables
  // =========================================================================

  group('DB migration V6', () {
    test('writing_daily_stats table is created by migration', () {
      ensureSchema();
      final db = openAuthoringDatabase(dbPath);
      try {
        final rows = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='writing_daily_stats'",
        );
        expect(rows, isNotEmpty);
      } finally {
        db.dispose();
      }
    });

    test('writing_project_stats table is created by migration', () {
      ensureSchema();
      final db = openAuthoringDatabase(dbPath);
      try {
        final rows = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='writing_project_stats'",
        );
        expect(rows, isNotEmpty);
      } finally {
        db.dispose();
      }
    });

    test('writing_goals table is created by migration', () {
      ensureSchema();
      final db = openAuthoringDatabase(dbPath);
      try {
        final rows = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='writing_goals'",
        );
        expect(rows, isNotEmpty);
      } finally {
        db.dispose();
      }
    });

    test('schema version is at least 6', () {
      ensureSchema();
      final db = openAuthoringDatabase(dbPath);
      try {
        final version =
            db.select('PRAGMA user_version').first['user_version'] as int;
        expect(version, greaterThanOrEqualTo(6));
      } finally {
        db.dispose();
      }
    });
  });

  // =========================================================================
  // WritingStatsService: 增量更新
  // =========================================================================

  group('WritingStatsService', () {
    setUp(() => ensureSchema());

    test('handleDraftUpdated creates daily stat with correct delta', () async {
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '',
        currentText: '你好世界', // 4 个非空白字符
      ));

      final stats = await storage.loadDailyStats(projectId: 'proj-1');
      expect(stats, hasLength(1));
      expect(stats.first['deltaChars'], 4);
      expect(stats.first['charCount'], 4);
      expect(stats.first['sceneScopeId'], 'proj-1::scene-01');
    });

    test('handleDraftUpdated accumulates delta for same day', () async {
      // 第一次写入
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '',
        currentText: '你好', // +2
      ));
      // 第二次写入
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '你好',
        currentText: '你好世界测试', // +4
      ));

      final stats = await storage.loadDailyStats(projectId: 'proj-1');
      expect(stats, hasLength(1));
      expect(stats.first['deltaChars'], 6); // 2 + 4
      expect(stats.first['charCount'], 6); // 最终字数
    });

    test('handleDraftUpdated skips when delta is zero', () async {
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '你好',
        currentText: '你好',
      ));

      final stats = await storage.loadDailyStats(projectId: 'proj-1');
      expect(stats, isEmpty);
    });

    test('handleDraftUpdated creates project stat on first write', () async {
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '',
        currentText: '测试内容',
      ));

      final projectStat = await storage.loadProjectStat(projectId: 'proj-1');
      expect(projectStat, isNotNull);
      expect(projectStat!['totalDeltaChars'], 4);
      expect(projectStat['totalSessions'], 1);
      expect(projectStat['firstWriteAtMs'], greaterThan(0));
    });

    test('handleDraftUpdated tracks best day', () async {
      // 第一天大量写作
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '',
        currentText: 'a' * 5000,
      ));

      final projectStat = await storage.loadProjectStat(projectId: 'proj-1');
      expect(projectStat, isNotNull);
      expect(projectStat!['bestDayChars'], 5000);
    });

    test('handleChapterCompleted increments chapter count', () async {
      // 先创建日级记录
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '',
        currentText: '内容',
      ));
      await service.handleChapterCompleted(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
      );

      final stats = await storage.loadDailyStats(projectId: 'proj-1');
      expect(stats.first['chaptersCompleted'], 1);

      final projectStat = await storage.loadProjectStat(projectId: 'proj-1');
      expect(projectStat!['totalChapters'], 1);
    });

    test('multiple scene scopes tracked separately', () async {
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '',
        currentText: '场景一',
      ));
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-02',
        previousText: '',
        currentText: '场景二内容',
      ));

      final stats = await storage.loadDailyStats(projectId: 'proj-1');
      expect(stats, hasLength(2));
      final scene1 = stats.firstWhere(
        (s) => s['sceneScopeId'] == 'proj-1::scene-01',
      );
      final scene2 = stats.firstWhere(
        (s) => s['sceneScopeId'] == 'proj-1::scene-02',
      );
      expect(scene1['deltaChars'], 3);
      expect(scene2['deltaChars'], 5); // '场景二内容' = 5 个字
    });

    test('negative delta (deletion) is tracked correctly', () async {
      // 先写入
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '',
        currentText: '你好世界测试内容',
      ));
      // 删除部分内容
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '你好世界测试内容',
        currentText: '你好',
      ));

      final stats = await storage.loadDailyStats(projectId: 'proj-1');
      expect(stats.first['deltaChars'], 2); // 6 + (-4) = 2 净增
      expect(stats.first['charCount'], 2); // 最终字数
    });
  });

  // =========================================================================
  // WritingStatsService: 快照查询
  // =========================================================================

  group('WritingStatsService snapshot', () {
    setUp(() => ensureSchema());

    test('loadSnapshot returns correct aggregated values', () async {
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '',
        currentText: '你好世界',
      ));

      final snapshot = await service.loadSnapshot(projectId: 'proj-1');
      expect(snapshot.todayDeltaChars, 4);
      expect(snapshot.todayCharCount, 4);
      expect(snapshot.weekCharCount, 4);
      expect(snapshot.projectStat.totalDeltaChars, 4);
    });

    test('loadSnapshot returns empty for unknown project', () async {
      final snapshot = await service.loadSnapshot(projectId: 'unknown');
      expect(snapshot.todayDeltaChars, 0);
      expect(snapshot.dailyStats, isEmpty);
    });
  });

  // =========================================================================
  // 目标管理
  // =========================================================================

  group('WritingGoals', () {
    setUp(() => ensureSchema());

    test('save and load goal round-trip', () async {
      final goal = WritingGoal(
        id: 'goal-1',
        projectId: 'proj-1',
        goalType: WritingGoalType.dailyChars,
        targetValue: 2000,
        period: WritingGoalPeriod.daily,
        enabled: true,
        createdAtMs: 1000,
      );
      await service.saveGoal(goal);

      final goals = await service.loadGoals(projectId: 'proj-1');
      expect(goals, hasLength(1));
      expect(goals.first.id, 'goal-1');
      expect(goals.first.targetValue, 2000);
      expect(goals.first.goalType, WritingGoalType.dailyChars);
      expect(goals.first.enabled, isTrue);
    });

    test('update existing goal', () async {
      final goal = WritingGoal(
        id: 'goal-1',
        projectId: 'proj-1',
        goalType: WritingGoalType.dailyChars,
        targetValue: 2000,
        period: WritingGoalPeriod.daily,
        enabled: true,
        createdAtMs: 1000,
      );
      await service.saveGoal(goal);

      final updated = goal.copyWith(targetValue: 3000, enabled: false);
      await service.saveGoal(updated);

      final goals = await service.loadGoals(projectId: 'proj-1');
      expect(goals, hasLength(1));
      expect(goals.first.targetValue, 3000);
      expect(goals.first.enabled, isFalse);
    });

    test('delete goal', () async {
      await service.saveGoal(WritingGoal(
        id: 'goal-1',
        projectId: 'proj-1',
        goalType: WritingGoalType.dailyChars,
        targetValue: 2000,
        period: WritingGoalPeriod.daily,
        enabled: true,
        createdAtMs: 1000,
      ));
      await service.deleteGoal('goal-1');

      final goals = await service.loadGoals(projectId: 'proj-1');
      expect(goals, isEmpty);
    });

    test('global goal (empty projectId) visible for all projects', () async {
      await service.saveGoal(WritingGoal(
        id: 'global-goal',
        projectId: '',
        goalType: WritingGoalType.dailyChars,
        targetValue: 1000,
        period: WritingGoalPeriod.daily,
        enabled: true,
        createdAtMs: 1000,
      ));

      final goals = await service.loadGoals(projectId: 'proj-1');
      expect(goals, hasLength(1));
      expect(goals.first.id, 'global-goal');
    });

    test('clearProject removes all stats and goals', () async {
      await service.handleDraftUpdated(DraftUpdatedEvent(
        projectId: 'proj-1',
        sceneScopeId: 'proj-1::scene-01',
        previousText: '',
        currentText: '内容',
      ));
      await service.saveGoal(WritingGoal(
        id: 'goal-1',
        projectId: 'proj-1',
        goalType: WritingGoalType.dailyChars,
        targetValue: 1000,
        period: WritingGoalPeriod.daily,
        enabled: true,
        createdAtMs: 1000,
      ));

      await service.clearProject('proj-1');

      final stats = await storage.loadDailyStats(projectId: 'proj-1');
      expect(stats, isEmpty);
      final projectStat = await storage.loadProjectStat(projectId: 'proj-1');
      expect(projectStat, isNull);
      final goals = await service.loadGoals(projectId: 'proj-1');
      expect(goals, isEmpty);
    });
  });

  // =========================================================================
  // WritingGoal model
  // =========================================================================

  group('WritingGoal model', () {
    test('toJson and fromJson round-trip', () {
      final goal = WritingGoal(
        id: 'g1',
        projectId: 'p1',
        goalType: WritingGoalType.weeklyChars,
        targetValue: 10000,
        period: WritingGoalPeriod.weekly,
        enabled: false,
        createdAtMs: 12345,
      );
      final json = goal.toJson();
      final restored = WritingGoal.fromJson(json);
      expect(restored.id, goal.id);
      expect(restored.projectId, goal.projectId);
      expect(restored.goalType, goal.goalType);
      expect(restored.targetValue, goal.targetValue);
      expect(restored.period, goal.period);
      expect(restored.enabled, goal.enabled);
      expect(restored.createdAtMs, goal.createdAtMs);
    });

    test('copyWith preserves unmodified fields', () {
      final goal = WritingGoal(
        id: 'g1',
        projectId: 'p1',
        goalType: WritingGoalType.dailyChars,
        targetValue: 2000,
        period: WritingGoalPeriod.daily,
        enabled: true,
        createdAtMs: 100,
      );
      final updated = goal.copyWith(targetValue: 5000);
      expect(updated.id, 'g1');
      expect(updated.targetValue, 5000);
      expect(updated.enabled, isTrue);
    });
  });

  // =========================================================================
  // WritingDailyStat / WritingProjectStat model
  // =========================================================================

  group('WritingDailyStat model', () {
    test('fromJson with defaults', () {
      final stat = WritingDailyStat.fromJson(const {});
      expect(stat.date, '');
      expect(stat.charCount, 0);
      expect(stat.deltaChars, 0);
      expect(stat.goalReached, isFalse);
    });
  });

  group('WritingProjectStat model', () {
    test('averageDailyChars calculates correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final dayAgo = now - 86400000;
      final stat = WritingProjectStat(
        projectId: 'p1',
        totalCharCount: 1000,
        totalDeltaChars: 1000,
        totalChapters: 2,
        totalSessions: 5,
        firstWriteAtMs: dayAgo,
        lastWriteAtMs: now,
        bestDayChars: 600,
        bestDayDate: '2026-05-13',
      );
      expect(stat.averageDailyChars, 500); // 1000 / 2 days
    });

    test('averageDailyChars returns 0 when no writes', () {
      expect(WritingProjectStat.empty.averageDailyChars, 0);
    });
  });

  // =========================================================================
  // countNonWhitespace consistency
  // =========================================================================

  group('countNonWhitespace', () {
    test('strips all whitespace types', () {
      expect(countNonWhitespace('hello world'), 10);
      expect(countNonWhitespace('a\tb\nc\rd'), 4);
      expect(countNonWhitespace('  '), 0);
      expect(countNonWhitespace(''), 0);
    });

    test('CJK characters counted individually', () {
      expect(countNonWhitespace('你好世界'), 4);
      expect(countNonWhitespace('你好 世界'), 4);
    });
  });

  // =========================================================================
  // DraftUpdatedEvent.charDelta
  // =========================================================================

  group('DraftUpdatedEvent.charDelta', () {
    test('positive delta for new text', () {
      final event = DraftUpdatedEvent(
        projectId: 'p1',
        sceneScopeId: 'p1::s1',
        previousText: '',
        currentText: '你好世界',
      );
      expect(event.charDelta, 4);
    });

    test('negative delta for deletion', () {
      final event = DraftUpdatedEvent(
        projectId: 'p1',
        sceneScopeId: 'p1::s1',
        previousText: '你好世界',
        currentText: '你好',
      );
      expect(event.charDelta, -2);
    });

    test('zero delta for unchanged text', () {
      final event = DraftUpdatedEvent(
        projectId: 'p1',
        sceneScopeId: 'p1::s1',
        previousText: '你好',
        currentText: '你好',
      );
      expect(event.charDelta, 0);
    });

    test('whitespace-only changes produce zero delta', () {
      final event = DraftUpdatedEvent(
        projectId: 'p1',
        sceneScopeId: 'p1::s1',
        previousText: '你好',
        currentText: '  你  好  ',
      );
      expect(event.charDelta, 0);
    });
  });

  // =========================================================================
  // WritingStatsSnapshot goalProgress
  // =========================================================================

  group('WritingStatsSnapshot goalProgress', () {
    test('reports progress for daily char goal', () {
      final goal = WritingGoal(
        id: 'g1',
        projectId: 'p1',
        goalType: WritingGoalType.dailyChars,
        targetValue: 2000,
        period: WritingGoalPeriod.daily,
        enabled: true,
        createdAtMs: 0,
      );
      final snapshot = WritingStatsSnapshot(
        dailyStats: const [],
        projectStat: WritingProjectStat.empty,
        goals: [goal],
        todayCharCount: 1000,
        todayDeltaChars: 1000,
        weekCharCount: 5000,
      );
      expect(snapshot.goalProgress(goal), 0.5);
      expect(snapshot.todayGoalsReached, isFalse);
    });

    test('reports reached when progress >= 1.0', () {
      final goal = WritingGoal(
        id: 'g1',
        projectId: 'p1',
        goalType: WritingGoalType.dailyChars,
        targetValue: 2000,
        period: WritingGoalPeriod.daily,
        enabled: true,
        createdAtMs: 0,
      );
      final snapshot = WritingStatsSnapshot(
        dailyStats: const [],
        projectStat: WritingProjectStat.empty,
        goals: [goal],
        todayCharCount: 2500,
        todayDeltaChars: 2500,
        weekCharCount: 10000,
      );
      expect(snapshot.goalProgress(goal), 1.25);
      expect(snapshot.todayGoalsReached, isTrue);
    });

    test('weekly goal uses weekCharCount', () {
      final goal = WritingGoal(
        id: 'g2',
        projectId: 'p1',
        goalType: WritingGoalType.weeklyChars,
        targetValue: 10000,
        period: WritingGoalPeriod.weekly,
        enabled: true,
        createdAtMs: 0,
      );
      final snapshot = WritingStatsSnapshot(
        dailyStats: const [],
        projectStat: WritingProjectStat.empty,
        goals: [goal],
        todayCharCount: 1000,
        todayDeltaChars: 1000,
        weekCharCount: 7000,
      );
      expect(snapshot.goalProgress(goal), 0.7);
    });
  });
}
