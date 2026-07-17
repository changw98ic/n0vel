import 'package:novel_writer/app/events/app_domain_events.dart';

import '../domain/writing_stats_models.dart';
import 'writing_stats_storage.dart';

/// 写作统计聚合服务。
///
/// 负责在写作事件发生时增量更新日/周/项目级统计，
/// 避免全量重算。所有写操作通过 [WritingStatsStorage] 持久化。
class WritingStatsService {
  WritingStatsService({required WritingStatsStorage storage})
    : _storage = storage;

  final WritingStatsStorage _storage;

  // ── 增量更新 ──────────────────────────────────────────────────────────────

  /// 处理一次草稿更新事件，增量更新相关统计记录。
  ///
  /// 调用方应确保在 < 3s 内完成（单次 DB 操作级别）。
  Future<void> handleDraftUpdated(DraftUpdatedEvent event) async {
    final delta = event.charDelta;
    if (delta == 0) return;

    final now = DateTime.now();
    final today = _dateString(now);
    final nowMs = now.millisecondsSinceEpoch;
    final currentLen = countNonWhitespace(event.currentText);

    // 1. 更新日级统计
    await _upsertDailyStat(
      date: today,
      sceneScopeId: event.sceneScopeId,
      projectId: event.projectId,
      currentCharCount: currentLen,
      delta: delta,
      nowMs: nowMs,
    );

    // 2. 更新项目级统计
    await _upsertProjectStat(
      projectId: event.projectId,
      delta: delta,
      nowMs: nowMs,
      today: today,
    );
  }

  /// 记录一个章节完成事件。
  Future<void> handleChapterCompleted({
    required String projectId,
    required String sceneScopeId,
  }) async {
    final now = DateTime.now();
    final today = _dateString(now);
    final nowMs = now.millisecondsSinceEpoch;

    // 更新日级章节计数
    final existing = await _storage.loadDailyStats(
      projectId: projectId,
      fromDate: today,
      toDate: today,
    );
    final match = existing.where((r) => r['sceneScopeId'] == sceneScopeId);
    if (match.isNotEmpty) {
      final row = match.first;
      await _storage.upsertDailyStat({
        ...row,
        'chaptersCompleted': (row['chaptersCompleted'] as int? ?? 0) + 1,
        'updatedAtMs': nowMs,
      });
    }

    // 更新项目级章节计数
    final projectStat = await _loadOrCreateProjectStat(projectId, nowMs);
    await _storage.upsertProjectStat({
      ...projectStat.toJson(),
      'totalChapters': projectStat.totalChapters + 1,
    });
  }

  // ── 查询 ─────────────────────────────────────────────────────────────────

  /// 加载指定项目在日期范围内的日级统计（供趋势图使用）。
  Future<List<WritingDailyStat>> loadDailyStats({
    required String projectId,
    String? fromDate,
    String? toDate,
  }) async {
    final rows = await _storage.loadDailyStats(
      projectId: projectId,
      fromDate: fromDate,
      toDate: toDate,
    );
    return rows.map(WritingDailyStat.fromJson).toList();
  }

  /// 加载指定项目的统计快照。
  Future<WritingStatsSnapshot> loadSnapshot({required String projectId}) async {
    final now = DateTime.now();
    final today = _dateString(now);
    final weekStart = weekStartDateString(now);

    final dailyStats = await _storage.loadDailyStats(
      projectId: projectId,
      fromDate: weekStart,
    );
    final projectRow = await _storage.loadProjectStat(projectId: projectId);
    final projectStat = projectRow != null
        ? WritingProjectStat.fromJson(projectRow)
        : WritingProjectStat.empty;
    final goalRows = await _storage.loadGoals(projectId: projectId);
    final goals = goalRows.map(WritingGoal.fromJson).toList();

    // 今日合计
    final todayStats = dailyStats.where((s) => s['date'] == today);
    final todayCharCount = todayStats.fold<int>(
      0,
      (sum, s) => sum + ((s['charCount'] as int?) ?? 0),
    );
    final todayDeltaChars = todayStats.fold<int>(
      0,
      (sum, s) => sum + ((s['deltaChars'] as int?) ?? 0),
    );

    // 本周合计
    final weekCharCount = dailyStats.fold<int>(
      0,
      (sum, s) => sum + ((s['deltaChars'] as int?) ?? 0),
    );

    return WritingStatsSnapshot(
      dailyStats: dailyStats.map(WritingDailyStat.fromJson).toList(),
      projectStat: projectStat,
      goals: goals,
      todayCharCount: todayCharCount,
      todayDeltaChars: todayDeltaChars,
      weekCharCount: weekCharCount,
    );
  }

  // ── 目标管理 ──────────────────────────────────────────────────────────────

  /// 保存（创建或更新）一个写作目标。
  Future<void> saveGoal(WritingGoal goal) => _storage.upsertGoal(goal.toJson());

  /// 删除一个写作目标。
  Future<void> deleteGoal(String goalId) => _storage.deleteGoal(goalId: goalId);

  /// 加载所有目标。
  Future<List<WritingGoal>> loadGoals({String? projectId}) async {
    final rows = await _storage.loadGoals(projectId: projectId);
    return rows.map(WritingGoal.fromJson).toList();
  }

  /// 删除指定项目的所有统计数据。
  Future<void> clearProject(String projectId) =>
      _storage.clearProject(projectId);

  // ── 内部方法 ──────────────────────────────────────────────────────────────

  Future<void> _upsertDailyStat({
    required String date,
    required String sceneScopeId,
    required String projectId,
    required int currentCharCount,
    required int delta,
    required int nowMs,
  }) async {
    final existing = await _storage.loadDailyStats(
      projectId: projectId,
      fromDate: date,
      toDate: date,
    );
    final match = existing.where((r) => r['sceneScopeId'] == sceneScopeId);

    if (match.isNotEmpty) {
      final row = match.first;
      await _storage.upsertDailyStat({
        'date': date,
        'sceneScopeId': sceneScopeId,
        'projectId': projectId,
        'charCount': currentCharCount,
        'deltaChars': (row['deltaChars'] as int? ?? 0) + delta,
        'chaptersCompleted': row['chaptersCompleted'] ?? 0,
        'goalReached': row['goalReached'] ?? 0,
        'updatedAtMs': nowMs,
      });
    } else {
      await _storage.upsertDailyStat({
        'date': date,
        'sceneScopeId': sceneScopeId,
        'projectId': projectId,
        'charCount': currentCharCount,
        'deltaChars': delta,
        'chaptersCompleted': 0,
        'goalReached': 0,
        'updatedAtMs': nowMs,
      });
    }
  }

  Future<void> _upsertProjectStat({
    required String projectId,
    required int delta,
    required int nowMs,
    required String today,
  }) async {
    final projectStat = await _loadOrCreateProjectStat(projectId, nowMs);
    final newTotalDelta = projectStat.totalDeltaChars + delta;

    // 更新最佳日
    var bestDayChars = projectStat.bestDayChars;
    var bestDayDate = projectStat.bestDayDate;
    final todayStats = await _storage.loadDailyStats(
      projectId: projectId,
      fromDate: today,
      toDate: today,
    );
    final todayTotalDelta = todayStats.fold<int>(
      0,
      (sum, r) => sum + ((r['deltaChars'] as int?) ?? 0),
    );
    if (todayTotalDelta > bestDayChars) {
      bestDayChars = todayTotalDelta;
      bestDayDate = today;
    }

    await _storage.upsertProjectStat({
      'projectId': projectId,
      'totalCharCount': projectStat.totalCharCount + delta,
      'totalDeltaChars': newTotalDelta,
      'totalChapters': projectStat.totalChapters,
      'totalSessions': projectStat.totalSessions + (delta > 0 ? 1 : 0),
      'firstWriteAtMs': projectStat.firstWriteAtMs == 0
          ? nowMs
          : projectStat.firstWriteAtMs,
      'lastWriteAtMs': nowMs,
      'bestDayChars': bestDayChars,
      'bestDayDate': bestDayDate,
    });
  }

  Future<WritingProjectStat> _loadOrCreateProjectStat(
    String projectId,
    int nowMs,
  ) async {
    final row = await _storage.loadProjectStat(projectId: projectId);
    if (row != null) return WritingProjectStat.fromJson(row);
    return WritingProjectStat(
      projectId: projectId,
      totalCharCount: 0,
      totalDeltaChars: 0,
      totalChapters: 0,
      totalSessions: 0,
      firstWriteAtMs: nowMs,
      lastWriteAtMs: nowMs,
      bestDayChars: 0,
      bestDayDate: '',
    );
  }

  static String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
