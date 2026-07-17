// ============================================================================
// 写作统计与目标管理 — 领域模型
// ============================================================================

/// 字数统计口径：去除空白字符后的字符数（与导出模块一致）。
int countNonWhitespace(String value) {
  var count = 0;
  for (final codeUnit in value.codeUnits) {
    if (codeUnit != 0x20 &&
        codeUnit != 0x09 &&
        codeUnit != 0x0A &&
        codeUnit != 0x0D &&
        codeUnit != 0x0B &&
        codeUnit != 0x0C) {
      count++;
    }
  }
  return count;
}

// ============================================================================
// 日级统计
// ============================================================================

class WritingDailyStat {
  const WritingDailyStat({
    required this.date,
    required this.sceneScopeId,
    required this.projectId,
    required this.charCount,
    required this.deltaChars,
    required this.chaptersCompleted,
    required this.goalReached,
    required this.updatedAtMs,
  });

  final String date; // YYYY-MM-DD
  final String sceneScopeId;
  final String projectId;
  final int charCount; // 当日最终字数
  final int deltaChars; // 当日净增字数
  final int chaptersCompleted;
  final bool goalReached;
  final int updatedAtMs;

  Map<String, Object?> toJson() => {
    'date': date,
    'sceneScopeId': sceneScopeId,
    'projectId': projectId,
    'charCount': charCount,
    'deltaChars': deltaChars,
    'chaptersCompleted': chaptersCompleted,
    'goalReached': goalReached ? 1 : 0,
    'updatedAtMs': updatedAtMs,
  };

  static WritingDailyStat fromJson(Map<String, Object?> json) =>
      WritingDailyStat(
        date: json['date'] as String? ?? '',
        sceneScopeId: json['sceneScopeId'] as String? ?? '',
        projectId: json['projectId'] as String? ?? '',
        charCount: json['charCount'] as int? ?? 0,
        deltaChars: json['deltaChars'] as int? ?? 0,
        chaptersCompleted: json['chaptersCompleted'] as int? ?? 0,
        goalReached: (json['goalReached'] as int? ?? 0) != 0,
        updatedAtMs: json['updatedAtMs'] as int? ?? 0,
      );
}

// ============================================================================
// 项目级累计统计
// ============================================================================

class WritingProjectStat {
  const WritingProjectStat({
    required this.projectId,
    required this.totalCharCount,
    required this.totalDeltaChars,
    required this.totalChapters,
    required this.totalSessions,
    required this.firstWriteAtMs,
    required this.lastWriteAtMs,
    required this.bestDayChars,
    required this.bestDayDate,
  });

  final String projectId;
  final int totalCharCount;
  final int totalDeltaChars;
  final int totalChapters;
  final int totalSessions;
  final int firstWriteAtMs;
  final int lastWriteAtMs;
  final int bestDayChars;
  final String bestDayDate;

  /// 日均产出（基于写作天数）。
  int get averageDailyChars {
    if (firstWriteAtMs == 0 || lastWriteAtMs == 0) return 0;
    final days =
        DateTime.fromMillisecondsSinceEpoch(lastWriteAtMs)
            .difference(DateTime.fromMillisecondsSinceEpoch(firstWriteAtMs))
            .inDays +
        1;
    return days > 0 ? totalDeltaChars ~/ days : 0;
  }

  Map<String, Object?> toJson() => {
    'projectId': projectId,
    'totalCharCount': totalCharCount,
    'totalDeltaChars': totalDeltaChars,
    'totalChapters': totalChapters,
    'totalSessions': totalSessions,
    'firstWriteAtMs': firstWriteAtMs,
    'lastWriteAtMs': lastWriteAtMs,
    'bestDayChars': bestDayChars,
    'bestDayDate': bestDayDate,
  };

  static WritingProjectStat fromJson(Map<String, Object?> json) =>
      WritingProjectStat(
        projectId: json['projectId'] as String? ?? '',
        totalCharCount: json['totalCharCount'] as int? ?? 0,
        totalDeltaChars: json['totalDeltaChars'] as int? ?? 0,
        totalChapters: json['totalChapters'] as int? ?? 0,
        totalSessions: json['totalSessions'] as int? ?? 0,
        firstWriteAtMs: json['firstWriteAtMs'] as int? ?? 0,
        lastWriteAtMs: json['lastWriteAtMs'] as int? ?? 0,
        bestDayChars: json['bestDayChars'] as int? ?? 0,
        bestDayDate: json['bestDayDate'] as String? ?? '',
      );

  static const empty = WritingProjectStat(
    projectId: '',
    totalCharCount: 0,
    totalDeltaChars: 0,
    totalChapters: 0,
    totalSessions: 0,
    firstWriteAtMs: 0,
    lastWriteAtMs: 0,
    bestDayChars: 0,
    bestDayDate: '',
  );
}

// ============================================================================
// 写作目标
// ============================================================================

/// 目标类型。
enum WritingGoalType {
  /// 每日字数目标。
  dailyChars,

  /// 每周字数目标。
  weeklyChars,

  /// 项目总字数目标。
  projectTotalChars,

  /// 每日完成章节数。
  dailyChapters,
}

/// 目标周期。
enum WritingGoalPeriod { daily, weekly, project }

class WritingGoal {
  const WritingGoal({
    required this.id,
    required this.projectId,
    required this.goalType,
    required this.targetValue,
    required this.period,
    required this.enabled,
    required this.createdAtMs,
  });

  final String id;
  final String projectId; // 空字符串 = 全局目标
  final WritingGoalType goalType;
  final int targetValue;
  final WritingGoalPeriod period;
  final bool enabled;
  final int createdAtMs;

  WritingGoal copyWith({
    String? id,
    String? projectId,
    WritingGoalType? goalType,
    int? targetValue,
    WritingGoalPeriod? period,
    bool? enabled,
    int? createdAtMs,
  }) => WritingGoal(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    goalType: goalType ?? this.goalType,
    targetValue: targetValue ?? this.targetValue,
    period: period ?? this.period,
    enabled: enabled ?? this.enabled,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'goalType': goalType.name,
    'targetValue': targetValue,
    'period': period.name,
    'enabled': enabled ? 1 : 0,
    'createdAtMs': createdAtMs,
  };

  static WritingGoal fromJson(Map<String, Object?> json) => WritingGoal(
    id: json['id'] as String? ?? '',
    projectId: json['projectId'] as String? ?? '',
    goalType: WritingGoalType.values.firstWhere(
      (e) => e.name == json['goalType'],
      orElse: () => WritingGoalType.dailyChars,
    ),
    targetValue: json['targetValue'] as int? ?? 0,
    period: WritingGoalPeriod.values.firstWhere(
      (e) => e.name == json['period'],
      orElse: () => WritingGoalPeriod.daily,
    ),
    enabled: (json['enabled'] as int? ?? 1) != 0,
    createdAtMs: json['createdAtMs'] as int? ?? 0,
  );
}

// ============================================================================
// 统一聚合模型
// ============================================================================

/// 聚合日/周/项目级统计 + 目标进度的统一快照。
class WritingStatsSnapshot {
  const WritingStatsSnapshot({
    required this.dailyStats,
    required this.projectStat,
    required this.goals,
    required this.todayCharCount,
    required this.todayDeltaChars,
    required this.weekCharCount,
  });

  final List<WritingDailyStat> dailyStats;
  final WritingProjectStat projectStat;
  final List<WritingGoal> goals;

  /// 今日字数（所有 scene scope 合计）。
  final int todayCharCount;

  /// 今日净增字数。
  final int todayDeltaChars;

  /// 本周净增字数。
  final int weekCharCount;

  /// 今日是否达成所有 daily 目标。
  bool get todayGoalsReached {
    final dailyGoals = goals
        .where((g) => g.enabled && g.period == WritingGoalPeriod.daily)
        .toList();
    if (dailyGoals.isEmpty) return false;
    return dailyGoals.every((g) => _isGoalMet(g));
  }

  /// 计算单个目标的完成进度 (0.0 ~ 1.0+)。
  double goalProgress(WritingGoal goal) {
    final actual = _currentValueForGoal(goal);
    if (goal.targetValue <= 0) return 0;
    return actual / goal.targetValue;
  }

  bool _isGoalMet(WritingGoal goal) =>
      _currentValueForGoal(goal) >= goal.targetValue;

  int _currentValueForGoal(WritingGoal goal) {
    return switch (goal.goalType) {
      WritingGoalType.dailyChars => todayDeltaChars,
      WritingGoalType.weeklyChars => weekCharCount,
      WritingGoalType.projectTotalChars => projectStat.totalDeltaChars,
      WritingGoalType.dailyChapters =>
        dailyStats
            .where((s) => s.date == _todayString())
            .fold(0, (sum, s) => sum + s.chaptersCompleted),
    };
  }

  static const empty = WritingStatsSnapshot(
    dailyStats: [],
    projectStat: WritingProjectStat.empty,
    goals: [],
    todayCharCount: 0,
    todayDeltaChars: 0,
    weekCharCount: 0,
  );
}

/// 获取当天日期字符串 YYYY-MM-DD。
String _todayString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// 获取指定日期所在周的周一日期字符串。
String weekStartDateString(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year.toString().padLeft(4, '0')}-'
      '${monday.month.toString().padLeft(2, '0')}-'
      '${monday.day.toString().padLeft(2, '0')}';
}
