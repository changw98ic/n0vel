import '../../../core/database/database.dart' show ChapterCharacter;
import '../../editor/domain/chapter.dart' as chapter_domain;
import '../../settings/domain/character.dart' as character_domain;
import '../../work/domain/work.dart' as work_domain;
import '../domain/statistics_models.dart';

WorkStatistics buildWorkStatisticsModel({
  required String workId,
  required work_domain.Work work,
  required int totalVolumes,
  required List<chapter_domain.Chapter> chapters,
  required List<character_domain.Character> characters,
  required List<DailyWordCount> recentWordCounts,
  DateTime? now,
}) {
  final referenceTime = now ?? DateTime.now();
  final totalWords = chapters.fold<int>(
    0,
    (sum, chapter) => sum + chapter.wordCount,
  );
  final publishedChapters = chapters
      .where((chapter) => chapter.status == chapter_domain.ChapterStatus.published)
      .length;
  final draftChapters = chapters
      .where((chapter) => chapter.status != chapter_domain.ChapterStatus.published)
      .length;
  final publishedWords = chapters
      .where((chapter) => chapter.status == chapter_domain.ChapterStatus.published)
      .fold<int>(0, (sum, chapter) => sum + chapter.wordCount);
  final wordCounts = chapters.map((chapter) => chapter.wordCount).toList();
  final maxChapterWords = wordCounts.isEmpty
      ? 0
      : wordCounts.reduce((a, b) => a > b ? a : b);
  final minChapterWords = wordCounts.isEmpty
      ? 0
      : wordCounts.reduce((a, b) => a < b ? a : b);
  final averageChapterWords = chapters.isEmpty ? 0.0 : totalWords / chapters.length;
  final writingDays = recentWordCounts.where((day) => day.wordCount > 0).length;
  final dailyAverageWords = writingDays == 0
      ? 0
      : recentWordCounts.fold<int>(0, (sum, day) => sum + day.wordCount) ~/
            writingDays;

  final targetWords = work.targetWords;
  final completionRate =
      (targetWords != null && targetWords > 0) ? totalWords / targetWords : 0.0;

  var estimatedDaysToComplete = 0;
  DateTime? estimatedCompletionDate;
  if (targetWords != null &&
      targetWords > 0 &&
      totalWords < targetWords &&
      dailyAverageWords > 0) {
    final remainingWords = targetWords - totalWords;
    estimatedDaysToComplete = (remainingWords / dailyAverageWords).ceil();
    estimatedCompletionDate = referenceTime.add(
      Duration(days: estimatedDaysToComplete),
    );
  }

  final chapterProgressList =
      chapters
          .map(
            (chapter) => ChapterProgress(
              chapterId: chapter.id,
              chapterTitle: chapter.title,
              order: chapter.sortOrder,
              wordCount: chapter.wordCount,
              status: mapStatisticsChapterStatus(chapter.status),
              updatedAt: chapter.updatedAt,
              reviewScore: chapter.reviewScore,
            ),
          )
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  final totalWritingMinutes = recentWordCounts.fold<int>(
    0,
    (sum, day) => sum + day.writingMinutes,
  );

  return WorkStatistics(
    workId: workId,
    workTitle: work.name,
    createdAt: work.createdAt,
    updatedAt: work.updatedAt,
    totalVolumes: totalVolumes,
    totalChapters: chapters.length,
    publishedChapters: publishedChapters,
    draftChapters: draftChapters,
    totalWords: totalWords,
    publishedWords: publishedWords,
    dailyAverageWords: dailyAverageWords,
    maxChapterWords: maxChapterWords,
    minChapterWords: minChapterWords,
    averageChapterWords: averageChapterWords,
    writingDays: writingDays,
    totalWritingMinutes: totalWritingMinutes,
    averageDailyWritingMinutes:
        writingDays == 0 ? 0.0 : totalWritingMinutes / writingDays,
    completionRate: completionRate,
    estimatedDaysToComplete: estimatedDaysToComplete,
    estimatedCompletionDate: estimatedCompletionDate,
    totalCharacters: characters.length,
    protagonistCount:
        characters.where((character) => character.tier.name == 'protagonist').length,
    supportingCount:
        characters.where((character) => character.tier.name == 'supporting').length,
    minorCount: characters.where((character) => character.tier.name == 'minor').length,
    recentWordCounts: recentWordCounts,
    chapterProgressList: chapterProgressList,
  );
}

List<DailyWordCount> buildRecentWordCounts(
  List<chapter_domain.Chapter> chapters,
  int days, {
  DateTime? now,
}) {
  final referenceTime = now ?? DateTime.now();
  final start = DateTime(
    referenceTime.year,
    referenceTime.month,
    referenceTime.day,
  ).subtract(Duration(days: days - 1));

  final dailyWordCounts = <DateTime, int>{};
  final dailyChapterCounts = <DateTime, int>{};
  for (final chapter in chapters) {
    final date = statisticsDateOnly(chapter.updatedAt);
    dailyWordCounts[date] = (dailyWordCounts[date] ?? 0) + chapter.wordCount;
    dailyChapterCounts[date] = (dailyChapterCounts[date] ?? 0) + 1;
  }

  final result = <DailyWordCount>[];
  for (var index = 0; index < days; index++) {
    final date = start.add(Duration(days: index));
    final chapterCount = dailyChapterCounts[date] ?? 0;
    result.add(
      DailyWordCount(
        date: date,
        wordCount: dailyWordCounts[date] ?? 0,
        chapterCount: chapterCount,
        writingMinutes: statisticsWritingMinutesForChapterCount(chapterCount),
      ),
    );
  }

  return result;
}

WordCountTrend buildWordCountTrend(
  List<chapter_domain.Chapter> chapters, {
  required TrendPeriod period,
  required int periods,
  DateTime? now,
}) {
  final referenceTime = now ?? DateTime.now();
  final dataPoints = <TrendDataPoint>[];

  for (var index = periods - 1; index >= 0; index--) {
    final range = _trendRangeForIndex(
      period: period,
      index: index,
      now: referenceTime,
    );
    final value = chapters.fold<int>(
      0,
      (sum, chapter) => statisticsIsWithinRange(
            chapter.updatedAt,
            range.start,
            range.end,
          )
          ? sum + chapter.wordCount
          : sum,
    );
    dataPoints.add(
      TrendDataPoint(date: range.start, value: value, cumulativeValue: 0),
    );
  }

  var cumulativeValue = 0;
  for (var i = 0; i < dataPoints.length; i++) {
    cumulativeValue += dataPoints[i].value;
    dataPoints[i] = dataPoints[i].copyWith(cumulativeValue: cumulativeValue);
  }

  final totalGrowth = dataPoints.fold<int>(0, (sum, point) => sum + point.value);
  var growthRate = 0.0;
  if (dataPoints.length >= 2) {
    final firstValue = dataPoints.first.value.toDouble();
    final lastValue = dataPoints.last.value.toDouble();
    if (firstValue > 0) {
      growthRate = ((lastValue - firstValue) / firstValue) * 100;
    }
  }

  return WordCountTrend(
    period: period,
    dataPoints: dataPoints,
    growthRate: growthRate,
    totalGrowth: totalGrowth,
  );
}

List<CharacterAppearanceStats> buildCharacterAppearanceStats({
  required List<chapter_domain.Chapter> chapters,
  required List<character_domain.Character> characters,
  required List<ChapterCharacter> links,
}) {
  final chapterIds = chapters.map((chapter) => chapter.id).toSet();
  final filteredLinks =
      links.where((link) => chapterIds.contains(link.chapterId)).toList();

  final grouped = <String, _CharacterAppearanceAccumulator>{};
  for (final link in filteredLinks) {
    final accumulator = grouped.putIfAbsent(
      link.characterId,
      () => _CharacterAppearanceAccumulator(),
    );
    accumulator.chapterIds.add(link.chapterId);
    accumulator.dialogueCount += link.dialogueCount;
    accumulator.appearanceCount += 1;
  }

  final totalAppearances = grouped.values.fold<int>(
    0,
    (sum, item) => sum + item.appearanceCount,
  );

  final result = <CharacterAppearanceStats>[];
  for (final character in characters) {
    final stats = grouped[character.id];
    final chapterIds = <String>[...?stats?.chapterIds]..sort();
    final appearanceCount = stats?.appearanceCount ?? 0;
    result.add(
      CharacterAppearanceStats(
        characterId: character.id,
        characterName: character.name,
        appearanceCount: appearanceCount,
        dialogueCount: stats?.dialogueCount ?? 0,
        chapterIds: chapterIds,
        screenTimePercentage: totalAppearances == 0
            ? 0.0
            : (appearanceCount / totalAppearances) * 100,
      ),
    );
  }

  result.sort((a, b) => b.appearanceCount.compareTo(a.appearanceCount));
  return result;
}

WritingReport buildWritingReportModel({
  required String workId,
  required work_domain.Work work,
  required List<chapter_domain.Chapter> chapters,
  required ReportPeriod period,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? now,
}) {
  final generatedAt = now ?? DateTime.now();
  final normalizedEnd = statisticsDateOnly(endDate ?? generatedAt);
  final normalizedStart = statisticsDateOnly(
    startDate ?? _defaultReportStartDate(period, normalizedEnd),
  );

  final selectedChapters =
      chapters
          .where(
            (chapter) => statisticsIsWithinRange(
              chapter.updatedAt,
              normalizedStart,
              normalizedEnd.add(const Duration(days: 1)),
            ),
          )
          .toList();

  final dayBreakdown = <DailyWordCount>[];
  final dayCount = normalizedEnd.difference(normalizedStart).inDays + 1;
  final chaptersByDate = <DateTime, List<chapter_domain.Chapter>>{};
  for (final chapter in selectedChapters) {
    chaptersByDate
        .putIfAbsent(statisticsDateOnly(chapter.updatedAt), () => [])
        .add(chapter);
  }

  for (var index = 0; index < dayCount; index++) {
    final date = normalizedStart.add(Duration(days: index));
    final chaptersForDay = chaptersByDate[date] ?? const <chapter_domain.Chapter>[];
    final wordCount = chaptersForDay.fold<int>(
      0,
      (sum, chapter) => sum + chapter.wordCount,
    );
    dayBreakdown.add(
      DailyWordCount(
        date: date,
        wordCount: wordCount,
        chapterCount: chaptersForDay.length,
        writingMinutes: statisticsWritingMinutesForChapterCount(
          chaptersForDay.length,
        ),
      ),
    );
  }

  final totalWords = dayBreakdown.fold<int>(0, (sum, day) => sum + day.wordCount);
  final writingDays = dayBreakdown.where((day) => day.wordCount > 0).length;
  final chaptersCompleted = selectedChapters
      .where((chapter) => chapter.status == chapter_domain.ChapterStatus.published)
      .length;
  final chaptersPublished = chaptersCompleted;
  final averageDailyWords = writingDays == 0 ? 0 : totalWords ~/ writingDays;

  return WritingReport(
    id: '${workId}_${normalizedStart.toIso8601String()}_${normalizedEnd.toIso8601String()}',
    workId: workId,
    period: period,
    startDate: normalizedStart,
    endDate: normalizedEnd,
    totalWords: totalWords,
    averageDailyWords: averageDailyWords,
    writingDays: writingDays,
    chaptersCompleted: chaptersCompleted,
    chaptersPublished: chaptersPublished,
    dailyBreakdown: dayBreakdown,
    insights: <String, dynamic>{
      'workTitle': work.name,
      'targetWords': work.targetWords,
      'completionRate':
          work.targetWords == null || work.targetWords! <= 0
              ? 0.0
              : totalWords / work.targetWords!,
      'selectedChapters': selectedChapters.length,
    },
    generatedAt: generatedAt,
  );
}

DateTime statisticsDateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool statisticsIsWithinRange(DateTime value, DateTime start, DateTime end) {
  return !value.isBefore(start) && value.isBefore(end);
}

ChapterStatus mapStatisticsChapterStatus(chapter_domain.ChapterStatus status) {
  return switch (status) {
    chapter_domain.ChapterStatus.draft => ChapterStatus.draft,
    chapter_domain.ChapterStatus.reviewing => ChapterStatus.review,
    chapter_domain.ChapterStatus.published => ChapterStatus.published,
  };
}

String statisticsCsvValue(Object? value) {
  final text = value?.toString() ?? '';
  final escaped = text.replaceAll('"', '""');
  return escaped.contains(',') || escaped.contains('\n') || escaped.contains('"')
      ? '"$escaped"'
      : escaped;
}

int statisticsWritingMinutesForChapterCount(int chapterCount) {
  return (chapterCount * 30).clamp(0, 480).toInt();
}

DateTime _defaultReportStartDate(ReportPeriod period, DateTime normalizedEnd) {
  return switch (period) {
    ReportPeriod.daily => normalizedEnd.subtract(const Duration(days: 1)),
    ReportPeriod.weekly => normalizedEnd.subtract(const Duration(days: 7)),
    ReportPeriod.monthly => DateTime(
      normalizedEnd.year,
      normalizedEnd.month - 1,
      normalizedEnd.day,
    ),
    ReportPeriod.quarterly => normalizedEnd.subtract(const Duration(days: 90)),
    ReportPeriod.yearly => normalizedEnd.subtract(const Duration(days: 365)),
    ReportPeriod.custom => normalizedEnd.subtract(const Duration(days: 30)),
  };
}

_DateTimeRange _trendRangeForIndex({
  required TrendPeriod period,
  required int index,
  required DateTime now,
}) {
  late final DateTime start;
  late final DateTime end;

  switch (period) {
    case TrendPeriod.daily:
      start = DateTime(now.year, now.month, now.day).subtract(
        Duration(days: index),
      );
      end = start.add(const Duration(days: 1));
      break;
    case TrendPeriod.weekly:
      start = DateTime(now.year, now.month, now.day).subtract(
        Duration(days: index * 7),
      );
      end = start.add(const Duration(days: 7));
      break;
    case TrendPeriod.monthly:
      start = DateTime(now.year, now.month - index, 1);
      end = DateTime(now.year, now.month - index + 1, 1);
      break;
  }

  return _DateTimeRange(start: start, end: end);
}

class _DateTimeRange {
  const _DateTimeRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

class _CharacterAppearanceAccumulator {
  final Set<String> chapterIds = <String>{};
  int appearanceCount = 0;
  int dialogueCount = 0;
}
