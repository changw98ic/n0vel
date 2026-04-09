import 'package:freezed_annotation/freezed_annotation.dart';

part 'statistics_models.freezed.dart';
part 'statistics_models.g.dart';

/// 作品统计概览
@freezed
class WorkStatistics with _$WorkStatistics {
  const factory WorkStatistics({
    required String workId,
    required String workTitle,
    required DateTime createdAt,
    required DateTime updatedAt,

    // 基础统计
    required int totalVolumes,
    required int totalChapters,
    required int publishedChapters,
    required int draftChapters,

    // 字数统计
    required int totalWords,
    required int publishedWords,
    required int dailyAverageWords,
    required int maxChapterWords,
    required int minChapterWords,
    required double averageChapterWords,

    // 时间统计
    required int writingDays,
    required int totalWritingMinutes,
    required double averageDailyWritingMinutes,

    // 进度统计
    required double completionRate,
    required int estimatedDaysToComplete,
    required DateTime? estimatedCompletionDate,

    // 角色统计
    required int totalCharacters,
    required int protagonistCount,
    required int supportingCount,
    required int minorCount,

    // 近期活动
    required List<DailyWordCount> recentWordCounts,
    required List<ChapterProgress> chapterProgressList,
  }) = _WorkStatistics;

  factory WorkStatistics.fromJson(Map<String, dynamic> json) =>
      _$WorkStatisticsFromJson(json);
}

/// 每日字数统计
@freezed
class DailyWordCount with _$DailyWordCount {
  const factory DailyWordCount({
    required DateTime date,
    required int wordCount,
    required int chapterCount,
    required int writingMinutes,
  }) = _DailyWordCount;

  factory DailyWordCount.fromJson(Map<String, dynamic> json) =>
      _$DailyWordCountFromJson(json);
}

/// 章节进度
@freezed
class ChapterProgress with _$ChapterProgress {
  const factory ChapterProgress({
    required String chapterId,
    required String chapterTitle,
    required int order,
    required int wordCount,
    required ChapterStatus status,
    required DateTime updatedAt,
    required double? reviewScore,
  }) = _ChapterProgress;

  factory ChapterProgress.fromJson(Map<String, dynamic> json) =>
      _$ChapterProgressFromJson(json);
}

/// 章节状态
enum ChapterStatus {
  draft,      // 草稿
  writing,    // 写作中
  revision,   // 修改中
  review,     // 审核中
  published,  // 已发布
  ;

  String get label => switch (this) {
    draft => '草稿',
    writing => '写作中',
    revision => '修改中',
    review => '审核中',
    published => '已发布',
  };
}

/// 写作时段统计
@freezed
class WritingSessionStats with _$WritingSessionStats {
  const factory WritingSessionStats({
    required DateTime date,
    required int totalMinutes,
    required int totalWords,
    required int sessionCount,
    required Map<int, int> hourlyDistribution, // hour -> word count
  }) = _WritingSessionStats;

  factory WritingSessionStats.fromJson(Map<String, dynamic> json) =>
      _$WritingSessionStatsFromJson(json);
}

/// 字数趋势
@freezed
class WordCountTrend with _$WordCountTrend {
  const factory WordCountTrend({
    required TrendPeriod period,
    required List<TrendDataPoint> dataPoints,
    required double growthRate,
    required int totalGrowth,
  }) = _WordCountTrend;

  factory WordCountTrend.fromJson(Map<String, dynamic> json) =>
      _$WordCountTrendFromJson(json);
}

/// 趋势周期
enum TrendPeriod {
  daily,    // 每日
  weekly,   // 每周
  monthly,  // 每月
  ;

  String get label => switch (this) {
    daily => '每日',
    weekly => '每周',
    monthly => '每月',
  };
}

/// 趋势数据点
@freezed
class TrendDataPoint with _$TrendDataPoint {
  const factory TrendDataPoint({
    required DateTime date,
    required int value,
    required int cumulativeValue,
  }) = _TrendDataPoint;

  factory TrendDataPoint.fromJson(Map<String, dynamic> json) =>
      _$TrendDataPointFromJson(json);
}

/// 角色出场统计
@freezed
class CharacterAppearanceStats with _$CharacterAppearanceStats {
  const factory CharacterAppearanceStats({
    required String characterId,
    required String characterName,
    required int appearanceCount,
    required int dialogueCount,
    required List<String> chapterIds,
    required double screenTimePercentage,
  }) = _CharacterAppearanceStats;

  factory CharacterAppearanceStats.fromJson(Map<String, dynamic> json) =>
      _$CharacterAppearanceStatsFromJson(json);
}

/// 写作目标
@freezed
class WritingGoal with _$WritingGoal {
  const factory WritingGoal({
    required String id,
    required String workId,
    required GoalType type,
    required int targetValue,
    required int currentValue,
    required DateTime startDate,
    required DateTime? endDate,
    required bool isCompleted,
    required DateTime createdAt,
  }) = _WritingGoal;

  factory WritingGoal.fromJson(Map<String, dynamic> json) =>
      _$WritingGoalFromJson(json);
}

/// 目标类型
enum GoalType {
  dailyWords,       // 每日字数
  weeklyWords,      // 每周字数
  monthlyWords,     // 每月字数
  totalWords,       // 总字数
  chapterCount,     // 章节数量
  completionRate,   // 完成率
  ;

  String get label => switch (this) {
    dailyWords => '每日字数',
    weeklyWords => '每周字数',
    monthlyWords => '每月字数',
    totalWords => '总字数',
    chapterCount => '章节数量',
    completionRate => '完成率',
  };
}

/// 写作报告
@freezed
class WritingReport with _$WritingReport {
  const factory WritingReport({
    required String id,
    required String workId,
    required ReportPeriod period,
    required DateTime startDate,
    required DateTime endDate,
    required int totalWords,
    required int averageDailyWords,
    required int writingDays,
    required int chaptersCompleted,
    required int chaptersPublished,
    required List<DailyWordCount> dailyBreakdown,
    required Map<String, dynamic> insights,
    required DateTime generatedAt,
  }) = _WritingReport;

  factory WritingReport.fromJson(Map<String, dynamic> json) =>
      _$WritingReportFromJson(json);
}

/// 统计导出格式
enum StatisticsExportFormat {
  json,
  csv,
  pdf,
  ;

  String get label => switch (this) {
        json => 'JSON',
        csv => 'CSV',
        pdf => 'PDF',
      };

  String get extension => switch (this) {
        json => 'json',
        csv => 'csv',
        pdf => 'pdf',
      };
}

/// 统计导出选项
@freezed
class StatisticsExportOptions with _$StatisticsExportOptions {
  const factory StatisticsExportOptions({
    required StatisticsExportFormat format,
    @Default(true) bool includeWorkStatistics,
    @Default(true) bool includeWordCountTrend,
    @Default(true) bool includeCharacterAppearances,
    @Default(true) bool includeDailyBreakdown,
    @Default(false) bool includeAIUsage,
    DateTime? startDate,
    DateTime? endDate,
    int? days,
  }) = _StatisticsExportOptions;

  factory StatisticsExportOptions.fromJson(Map<String, dynamic> json) =>
      _$StatisticsExportOptionsFromJson(json);
}

/// 报告周期
enum ReportPeriod {
  daily,
  weekly,
  monthly,
  quarterly,
  yearly,
  custom,
  ;

  String get label => switch (this) {
    daily => '日报',
    weekly => '周报',
    monthly => '月报',
    quarterly => '季报',
    yearly => '年报',
    custom => '自定义',
  };
}
