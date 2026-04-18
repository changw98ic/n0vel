// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkStatisticsImpl _$$WorkStatisticsImplFromJson(Map<String, dynamic> json) =>
    _$WorkStatisticsImpl(
      workId: json['workId'] as String,
      workTitle: json['workTitle'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      totalVolumes: (json['totalVolumes'] as num).toInt(),
      totalChapters: (json['totalChapters'] as num).toInt(),
      publishedChapters: (json['publishedChapters'] as num).toInt(),
      draftChapters: (json['draftChapters'] as num).toInt(),
      totalWords: (json['totalWords'] as num).toInt(),
      publishedWords: (json['publishedWords'] as num).toInt(),
      dailyAverageWords: (json['dailyAverageWords'] as num).toInt(),
      maxChapterWords: (json['maxChapterWords'] as num).toInt(),
      minChapterWords: (json['minChapterWords'] as num).toInt(),
      averageChapterWords: (json['averageChapterWords'] as num).toDouble(),
      writingDays: (json['writingDays'] as num).toInt(),
      totalWritingMinutes: (json['totalWritingMinutes'] as num).toInt(),
      averageDailyWritingMinutes: (json['averageDailyWritingMinutes'] as num)
          .toDouble(),
      completionRate: (json['completionRate'] as num).toDouble(),
      estimatedDaysToComplete: (json['estimatedDaysToComplete'] as num).toInt(),
      estimatedCompletionDate: json['estimatedCompletionDate'] == null
          ? null
          : DateTime.parse(json['estimatedCompletionDate'] as String),
      totalCharacters: (json['totalCharacters'] as num).toInt(),
      protagonistCount: (json['protagonistCount'] as num).toInt(),
      supportingCount: (json['supportingCount'] as num).toInt(),
      minorCount: (json['minorCount'] as num).toInt(),
      recentWordCounts: (json['recentWordCounts'] as List<dynamic>)
          .map((e) => DailyWordCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      chapterProgressList: (json['chapterProgressList'] as List<dynamic>)
          .map((e) => ChapterProgress.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$WorkStatisticsImplToJson(
  _$WorkStatisticsImpl instance,
) => <String, dynamic>{
  'workId': instance.workId,
  'workTitle': instance.workTitle,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'totalVolumes': instance.totalVolumes,
  'totalChapters': instance.totalChapters,
  'publishedChapters': instance.publishedChapters,
  'draftChapters': instance.draftChapters,
  'totalWords': instance.totalWords,
  'publishedWords': instance.publishedWords,
  'dailyAverageWords': instance.dailyAverageWords,
  'maxChapterWords': instance.maxChapterWords,
  'minChapterWords': instance.minChapterWords,
  'averageChapterWords': instance.averageChapterWords,
  'writingDays': instance.writingDays,
  'totalWritingMinutes': instance.totalWritingMinutes,
  'averageDailyWritingMinutes': instance.averageDailyWritingMinutes,
  'completionRate': instance.completionRate,
  'estimatedDaysToComplete': instance.estimatedDaysToComplete,
  'estimatedCompletionDate': instance.estimatedCompletionDate
      ?.toIso8601String(),
  'totalCharacters': instance.totalCharacters,
  'protagonistCount': instance.protagonistCount,
  'supportingCount': instance.supportingCount,
  'minorCount': instance.minorCount,
  'recentWordCounts': instance.recentWordCounts,
  'chapterProgressList': instance.chapterProgressList,
};

_$DailyWordCountImpl _$$DailyWordCountImplFromJson(Map<String, dynamic> json) =>
    _$DailyWordCountImpl(
      date: DateTime.parse(json['date'] as String),
      wordCount: (json['wordCount'] as num).toInt(),
      chapterCount: (json['chapterCount'] as num).toInt(),
      writingMinutes: (json['writingMinutes'] as num).toInt(),
    );

Map<String, dynamic> _$$DailyWordCountImplToJson(
  _$DailyWordCountImpl instance,
) => <String, dynamic>{
  'date': instance.date.toIso8601String(),
  'wordCount': instance.wordCount,
  'chapterCount': instance.chapterCount,
  'writingMinutes': instance.writingMinutes,
};

_$ChapterProgressImpl _$$ChapterProgressImplFromJson(
  Map<String, dynamic> json,
) => _$ChapterProgressImpl(
  chapterId: json['chapterId'] as String,
  chapterTitle: json['chapterTitle'] as String,
  order: (json['order'] as num).toInt(),
  wordCount: (json['wordCount'] as num).toInt(),
  status: $enumDecode(_$ChapterStatusEnumMap, json['status']),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  reviewScore: (json['reviewScore'] as num?)?.toDouble(),
);

Map<String, dynamic> _$$ChapterProgressImplToJson(
  _$ChapterProgressImpl instance,
) => <String, dynamic>{
  'chapterId': instance.chapterId,
  'chapterTitle': instance.chapterTitle,
  'order': instance.order,
  'wordCount': instance.wordCount,
  'status': _$ChapterStatusEnumMap[instance.status]!,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'reviewScore': instance.reviewScore,
};

const _$ChapterStatusEnumMap = {
  ChapterStatus.draft: 'draft',
  ChapterStatus.writing: 'writing',
  ChapterStatus.revision: 'revision',
  ChapterStatus.review: 'review',
  ChapterStatus.published: 'published',
};

_$WritingSessionStatsImpl _$$WritingSessionStatsImplFromJson(
  Map<String, dynamic> json,
) => _$WritingSessionStatsImpl(
  date: DateTime.parse(json['date'] as String),
  totalMinutes: (json['totalMinutes'] as num).toInt(),
  totalWords: (json['totalWords'] as num).toInt(),
  sessionCount: (json['sessionCount'] as num).toInt(),
  hourlyDistribution: (json['hourlyDistribution'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(int.parse(k), (e as num).toInt()),
  ),
);

Map<String, dynamic> _$$WritingSessionStatsImplToJson(
  _$WritingSessionStatsImpl instance,
) => <String, dynamic>{
  'date': instance.date.toIso8601String(),
  'totalMinutes': instance.totalMinutes,
  'totalWords': instance.totalWords,
  'sessionCount': instance.sessionCount,
  'hourlyDistribution': instance.hourlyDistribution.map(
    (k, e) => MapEntry(k.toString(), e),
  ),
};

_$WordCountTrendImpl _$$WordCountTrendImplFromJson(Map<String, dynamic> json) =>
    _$WordCountTrendImpl(
      period: $enumDecode(_$TrendPeriodEnumMap, json['period']),
      dataPoints: (json['dataPoints'] as List<dynamic>)
          .map((e) => TrendDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      growthRate: (json['growthRate'] as num).toDouble(),
      totalGrowth: (json['totalGrowth'] as num).toInt(),
    );

Map<String, dynamic> _$$WordCountTrendImplToJson(
  _$WordCountTrendImpl instance,
) => <String, dynamic>{
  'period': _$TrendPeriodEnumMap[instance.period]!,
  'dataPoints': instance.dataPoints,
  'growthRate': instance.growthRate,
  'totalGrowth': instance.totalGrowth,
};

const _$TrendPeriodEnumMap = {
  TrendPeriod.daily: 'daily',
  TrendPeriod.weekly: 'weekly',
  TrendPeriod.monthly: 'monthly',
};

_$TrendDataPointImpl _$$TrendDataPointImplFromJson(Map<String, dynamic> json) =>
    _$TrendDataPointImpl(
      date: DateTime.parse(json['date'] as String),
      value: (json['value'] as num).toInt(),
      cumulativeValue: (json['cumulativeValue'] as num).toInt(),
    );

Map<String, dynamic> _$$TrendDataPointImplToJson(
  _$TrendDataPointImpl instance,
) => <String, dynamic>{
  'date': instance.date.toIso8601String(),
  'value': instance.value,
  'cumulativeValue': instance.cumulativeValue,
};

_$CharacterAppearanceStatsImpl _$$CharacterAppearanceStatsImplFromJson(
  Map<String, dynamic> json,
) => _$CharacterAppearanceStatsImpl(
  characterId: json['characterId'] as String,
  characterName: json['characterName'] as String,
  appearanceCount: (json['appearanceCount'] as num).toInt(),
  dialogueCount: (json['dialogueCount'] as num).toInt(),
  chapterIds: (json['chapterIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  screenTimePercentage: (json['screenTimePercentage'] as num).toDouble(),
);

Map<String, dynamic> _$$CharacterAppearanceStatsImplToJson(
  _$CharacterAppearanceStatsImpl instance,
) => <String, dynamic>{
  'characterId': instance.characterId,
  'characterName': instance.characterName,
  'appearanceCount': instance.appearanceCount,
  'dialogueCount': instance.dialogueCount,
  'chapterIds': instance.chapterIds,
  'screenTimePercentage': instance.screenTimePercentage,
};

_$WritingGoalImpl _$$WritingGoalImplFromJson(Map<String, dynamic> json) =>
    _$WritingGoalImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      type: $enumDecode(_$GoalTypeEnumMap, json['type']),
      targetValue: (json['targetValue'] as num).toInt(),
      currentValue: (json['currentValue'] as num).toInt(),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      isCompleted: json['isCompleted'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$WritingGoalImplToJson(_$WritingGoalImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'type': _$GoalTypeEnumMap[instance.type]!,
      'targetValue': instance.targetValue,
      'currentValue': instance.currentValue,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'isCompleted': instance.isCompleted,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$GoalTypeEnumMap = {
  GoalType.dailyWords: 'dailyWords',
  GoalType.weeklyWords: 'weeklyWords',
  GoalType.monthlyWords: 'monthlyWords',
  GoalType.totalWords: 'totalWords',
  GoalType.chapterCount: 'chapterCount',
  GoalType.completionRate: 'completionRate',
};

_$WritingReportImpl _$$WritingReportImplFromJson(Map<String, dynamic> json) =>
    _$WritingReportImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      period: $enumDecode(_$ReportPeriodEnumMap, json['period']),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      totalWords: (json['totalWords'] as num).toInt(),
      averageDailyWords: (json['averageDailyWords'] as num).toInt(),
      writingDays: (json['writingDays'] as num).toInt(),
      chaptersCompleted: (json['chaptersCompleted'] as num).toInt(),
      chaptersPublished: (json['chaptersPublished'] as num).toInt(),
      dailyBreakdown: (json['dailyBreakdown'] as List<dynamic>)
          .map((e) => DailyWordCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      insights: json['insights'] as Map<String, dynamic>,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );

Map<String, dynamic> _$$WritingReportImplToJson(_$WritingReportImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'period': _$ReportPeriodEnumMap[instance.period]!,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'totalWords': instance.totalWords,
      'averageDailyWords': instance.averageDailyWords,
      'writingDays': instance.writingDays,
      'chaptersCompleted': instance.chaptersCompleted,
      'chaptersPublished': instance.chaptersPublished,
      'dailyBreakdown': instance.dailyBreakdown,
      'insights': instance.insights,
      'generatedAt': instance.generatedAt.toIso8601String(),
    };

const _$ReportPeriodEnumMap = {
  ReportPeriod.daily: 'daily',
  ReportPeriod.weekly: 'weekly',
  ReportPeriod.monthly: 'monthly',
  ReportPeriod.quarterly: 'quarterly',
  ReportPeriod.yearly: 'yearly',
  ReportPeriod.custom: 'custom',
};

_$StatisticsExportOptionsImpl _$$StatisticsExportOptionsImplFromJson(
  Map<String, dynamic> json,
) => _$StatisticsExportOptionsImpl(
  format: $enumDecode(_$StatisticsExportFormatEnumMap, json['format']),
  includeWorkStatistics: json['includeWorkStatistics'] as bool? ?? true,
  includeWordCountTrend: json['includeWordCountTrend'] as bool? ?? true,
  includeCharacterAppearances:
      json['includeCharacterAppearances'] as bool? ?? true,
  includeDailyBreakdown: json['includeDailyBreakdown'] as bool? ?? true,
  includeAIUsage: json['includeAIUsage'] as bool? ?? false,
  startDate: json['startDate'] == null
      ? null
      : DateTime.parse(json['startDate'] as String),
  endDate: json['endDate'] == null
      ? null
      : DateTime.parse(json['endDate'] as String),
  days: (json['days'] as num?)?.toInt(),
);

Map<String, dynamic> _$$StatisticsExportOptionsImplToJson(
  _$StatisticsExportOptionsImpl instance,
) => <String, dynamic>{
  'format': _$StatisticsExportFormatEnumMap[instance.format]!,
  'includeWorkStatistics': instance.includeWorkStatistics,
  'includeWordCountTrend': instance.includeWordCountTrend,
  'includeCharacterAppearances': instance.includeCharacterAppearances,
  'includeDailyBreakdown': instance.includeDailyBreakdown,
  'includeAIUsage': instance.includeAIUsage,
  'startDate': instance.startDate?.toIso8601String(),
  'endDate': instance.endDate?.toIso8601String(),
  'days': instance.days,
};

const _$StatisticsExportFormatEnumMap = {
  StatisticsExportFormat.json: 'json',
  StatisticsExportFormat.csv: 'csv',
  StatisticsExportFormat.pdf: 'pdf',
};
