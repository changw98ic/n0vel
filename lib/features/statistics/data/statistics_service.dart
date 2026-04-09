import 'dart:convert';

import 'package:get/get.dart';

import '../../../core/database/database.dart'
    hide
        Character,
        CharacterProfile,
        Chapter,
        Faction,
        FactionMember,
        Item,
        Location,
        StoryEvent,
        Volume,
        Work;
import '../../../core/services/ai/ai_service.dart';
import '../../editor/data/chapter_repository.dart';
import '../../editor/domain/chapter.dart' as chapter_domain;
import '../../settings/data/character_repository.dart';
import '../../settings/domain/character.dart' as character_domain;
import '../../work/data/work_repository.dart';
import '../../work/domain/work.dart' as work_domain;
import '../domain/statistics_models.dart';

class StatisticsService {
  StatisticsService(this._db);

  final AppDatabase _db;

  Future<WorkStatistics> getWorkStatistics(String workId) async {
    final work = await _loadWork(workId);
    if (work == null) {
      throw StateError('Work not found: $workId');
    }

    final chapters = await _loadChapters(workId);
    final characters = await _loadCharacters(workId);
    final recentWordCounts = await _getRecentWordCounts(
      workId,
      30,
      chapters: chapters,
    );

    final totalWords = chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.wordCount,
    );
    final publishedChapters = chapters
        .where(
          (chapter) => chapter.status == chapter_domain.ChapterStatus.published,
        )
        .length;
    final draftChapters = chapters
        .where(
          (chapter) => chapter.status != chapter_domain.ChapterStatus.published,
        )
        .length;
    final publishedWords = chapters
        .where(
          (chapter) => chapter.status == chapter_domain.ChapterStatus.published,
        )
        .fold<int>(0, (sum, chapter) => sum + chapter.wordCount);
    final wordCounts = chapters.map((chapter) => chapter.wordCount).toList();
    final maxChapterWords = wordCounts.isEmpty
        ? 0
        : wordCounts.reduce((a, b) => a > b ? a : b);
    final minChapterWords = wordCounts.isEmpty
        ? 0
        : wordCounts.reduce((a, b) => a < b ? a : b);
    final averageChapterWords = chapters.isEmpty
        ? 0.0
        : totalWords / chapters.length;
    final writingDays = recentWordCounts
        .where((day) => day.wordCount > 0)
        .length;
    final dailyAverageWords = writingDays == 0
        ? 0
        : recentWordCounts.fold<int>(0, (sum, day) => sum + day.wordCount) ~/
              writingDays;

    final targetWords = work.targetWords;
    final completionRate = (targetWords != null && targetWords > 0)
        ? totalWords / targetWords
        : 0.0;

    var estimatedDaysToComplete = 0;
    DateTime? estimatedCompletionDate;
    if (targetWords != null &&
        targetWords > 0 &&
        totalWords < targetWords &&
        dailyAverageWords > 0) {
      final remainingWords = targetWords - totalWords;
      estimatedDaysToComplete = (remainingWords / dailyAverageWords).ceil();
      estimatedCompletionDate = DateTime.now().add(
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
                status: _mapChapterStatus(chapter.status),
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
      totalVolumes: await _getTotalVolumes(workId),
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
      averageDailyWritingMinutes: writingDays == 0
          ? 0.0
          : totalWritingMinutes / writingDays,
      completionRate: completionRate,
      estimatedDaysToComplete: estimatedDaysToComplete,
      estimatedCompletionDate: estimatedCompletionDate,
      totalCharacters: characters.length,
      protagonistCount: characters
          .where((character) => character.tier.name == 'protagonist')
          .length,
      supportingCount: characters
          .where((character) => character.tier.name == 'supporting')
          .length,
      minorCount: characters
          .where((character) => character.tier.name == 'minor')
          .length,
      recentWordCounts: recentWordCounts,
      chapterProgressList: chapterProgressList,
    );
  }

  Future<List<WritingGoal>> getWritingGoals(String workId) async {
    final work = await _loadWork(workId);
    if (work == null) {
      return const [];
    }

    final stats = await getWorkStatistics(workId);
    final goals = <WritingGoal>[];
    final targetWords = work.targetWords;

    if (targetWords != null && targetWords > 0) {
      goals.add(
        WritingGoal(
          id: '$workId-total-words',
          workId: workId,
          type: GoalType.totalWords,
          targetValue: targetWords,
          currentValue: stats.totalWords,
          startDate: work.createdAt,
          endDate: null,
          isCompleted: stats.totalWords >= targetWords,
          createdAt: work.createdAt,
        ),
      );

      goals.add(
        WritingGoal(
          id: '$workId-completion-rate',
          workId: workId,
          type: GoalType.completionRate,
          targetValue: 100,
          currentValue: (stats.completionRate * 100)
              .round()
              .clamp(0, 100)
              .toInt(),
          startDate: work.createdAt,
          endDate: null,
          isCompleted: stats.completionRate >= 1.0,
          createdAt: work.createdAt,
        ),
      );
    }

    return goals;
  }

  Future<List<DailyWordCount>> _getRecentWordCounts(
    String workId,
    int days, {
    List<chapter_domain.Chapter>? chapters,
  }) async {
    final sourceChapters = chapters ?? await _loadChapters(workId);
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final dailyWordCounts = <DateTime, int>{};
    final dailyChapterCounts = <DateTime, int>{};
    for (final chapter in sourceChapters) {
      final date = _dateOnly(chapter.updatedAt);
      dailyWordCounts[date] = (dailyWordCounts[date] ?? 0) + chapter.wordCount;
      dailyChapterCounts[date] = (dailyChapterCounts[date] ?? 0) + 1;
    }

    final result = <DailyWordCount>[];
    for (var index = 0; index < days; index++) {
      final date = start.add(Duration(days: index));
      final wordCount = dailyWordCounts[date] ?? 0;
      final chapterCount = dailyChapterCounts[date] ?? 0;
      result.add(
        DailyWordCount(
          date: date,
          wordCount: wordCount,
          chapterCount: chapterCount,
          writingMinutes: (chapterCount * 30).clamp(0, 480).toInt(),
        ),
      );
    }

    return result;
  }

  Future<WordCountTrend> getWordCountTrend(
    String workId, {
    TrendPeriod period = TrendPeriod.daily,
    int periods = 30,
  }) async {
    final chapters = await _loadChapters(workId);
    final now = DateTime.now();
    final dataPoints = <TrendDataPoint>[];

    for (var index = periods - 1; index >= 0; index--) {
      late final DateTime start;
      late final DateTime end;

      switch (period) {
        case TrendPeriod.daily:
          start = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: index));
          end = start.add(const Duration(days: 1));
          break;
        case TrendPeriod.weekly:
          start = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: index * 7));
          end = start.add(const Duration(days: 7));
          break;
        case TrendPeriod.monthly:
          start = DateTime(now.year, now.month - index, 1);
          end = DateTime(now.year, now.month - index + 1, 1);
          break;
      }

      final value = chapters.fold<int>(
        0,
        (sum, chapter) => _isWithinRange(chapter.updatedAt, start, end)
            ? sum + chapter.wordCount
            : sum,
      );
      dataPoints.add(
        TrendDataPoint(date: start, value: value, cumulativeValue: 0),
      );
    }

    var cumulativeValue = 0;
    for (var i = 0; i < dataPoints.length; i++) {
      cumulativeValue += dataPoints[i].value;
      dataPoints[i] = dataPoints[i].copyWith(cumulativeValue: cumulativeValue);
    }

    final totalGrowth = dataPoints.fold<int>(
      0,
      (sum, point) => sum + point.value,
    );
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

  Future<List<CharacterAppearanceStats>> getCharacterAppearanceStats(
    String workId,
  ) async {
    final chapters = await _loadChapters(workId);
    final characters = await _loadCharacters(workId);
    final chapterIds = chapters.map((chapter) => chapter.id).toSet();

    final links = await _db.select(_db.chapterCharacters).get();
    final filteredLinks = links
        .where((link) => chapterIds.contains(link.chapterId))
        .toList();

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

  Future<WritingReport> generateReport(
    String workId, {
    ReportPeriod period = ReportPeriod.weekly,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final work = await _loadWork(workId);
    if (work == null) {
      throw StateError('Work not found: $workId');
    }

    final chapters = await _loadChapters(workId);
    final now = DateTime.now();
    final normalizedEnd = _dateOnly(endDate ?? now);
    final normalizedStart = _dateOnly(
      startDate ??
          switch (period) {
            ReportPeriod.daily => normalizedEnd.subtract(
              const Duration(days: 1),
            ),
            ReportPeriod.weekly => normalizedEnd.subtract(
              const Duration(days: 7),
            ),
            ReportPeriod.monthly => DateTime(
              normalizedEnd.year,
              normalizedEnd.month - 1,
              normalizedEnd.day,
            ),
            ReportPeriod.quarterly => normalizedEnd.subtract(
              const Duration(days: 90),
            ),
            ReportPeriod.yearly => normalizedEnd.subtract(
              const Duration(days: 365),
            ),
            ReportPeriod.custom => normalizedEnd.subtract(
              const Duration(days: 30),
            ),
          },
    );

    final selectedChapters = chapters
        .where(
          (chapter) => _isWithinRange(
            chapter.updatedAt,
            normalizedStart,
            normalizedEnd.add(const Duration(days: 1)),
          ),
        )
        .toList();

    final dayBreakdown = <DailyWordCount>[];
    final dayCount = normalizedEnd.difference(normalizedStart).inDays + 1;
    final byDate = <DateTime, List<chapter_domain.Chapter>>{};
    for (final chapter in selectedChapters) {
      byDate.putIfAbsent(_dateOnly(chapter.updatedAt), () => []).add(chapter);
    }

    for (var index = 0; index < dayCount; index++) {
      final date = normalizedStart.add(Duration(days: index));
      final chaptersForDay = byDate[date] ?? const <chapter_domain.Chapter>[];
      final wordCount = chaptersForDay.fold<int>(
        0,
        (sum, chapter) => sum + chapter.wordCount,
      );
      dayBreakdown.add(
        DailyWordCount(
          date: date,
          wordCount: wordCount,
          chapterCount: chaptersForDay.length,
          writingMinutes: (chaptersForDay.length * 30).clamp(0, 480).toInt(),
        ),
      );
    }

    final totalWords = dayBreakdown.fold<int>(
      0,
      (sum, day) => sum + day.wordCount,
    );
    final writingDays = dayBreakdown.where((day) => day.wordCount > 0).length;
    final chaptersCompleted = selectedChapters
        .where(
          (chapter) => chapter.status == chapter_domain.ChapterStatus.published,
        )
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
        'completionRate': work.targetWords == null || work.targetWords! <= 0
            ? 0.0
            : totalWords / work.targetWords!,
        'selectedChapters': selectedChapters.length,
      },
      generatedAt: now,
    );
  }

  Future<String> exportWorkStatisticsToJson(String workId) async {
    final stats = await getWorkStatistics(workId);
    return jsonEncode(stats.toJson());
  }

  Future<String> exportWorkStatisticsToCsv(String workId) async {
    final stats = await getWorkStatistics(workId);
    final buffer = StringBuffer();

    buffer.writeln('section,key,value');
    buffer.writeln('work,workTitle,${_csvValue(stats.workTitle)}');
    buffer.writeln(
      'work,createdAt,${_csvValue(stats.createdAt.toIso8601String())}',
    );
    buffer.writeln(
      'work,updatedAt,${_csvValue(stats.updatedAt.toIso8601String())}',
    );
    buffer.writeln('chapters,totalVolumes,${stats.totalVolumes}');
    buffer.writeln('chapters,totalChapters,${stats.totalChapters}');
    buffer.writeln('chapters,publishedChapters,${stats.publishedChapters}');
    buffer.writeln('chapters,draftChapters,${stats.draftChapters}');
    buffer.writeln('words,totalWords,${stats.totalWords}');
    buffer.writeln('words,publishedWords,${stats.publishedWords}');
    buffer.writeln('words,dailyAverageWords,${stats.dailyAverageWords}');
    buffer.writeln('words,maxChapterWords,${stats.maxChapterWords}');
    buffer.writeln('words,minChapterWords,${stats.minChapterWords}');
    buffer.writeln(
      'words,averageChapterWords,${stats.averageChapterWords.toStringAsFixed(1)}',
    );
    buffer.writeln('time,writingDays,${stats.writingDays}');
    buffer.writeln('time,totalWritingMinutes,${stats.totalWritingMinutes}');
    buffer.writeln(
      'time,averageDailyWritingMinutes,${stats.averageDailyWritingMinutes.toStringAsFixed(1)}',
    );
    buffer.writeln(
      'progress,completionRate,${(stats.completionRate * 100).toStringAsFixed(1)}%',
    );
    buffer.writeln(
      'progress,estimatedDaysToComplete,${stats.estimatedDaysToComplete}',
    );
    buffer.writeln(
      'progress,estimatedCompletionDate,${stats.estimatedCompletionDate?.toIso8601String() ?? 'N/A'}',
    );
    buffer.writeln('characters,totalCharacters,${stats.totalCharacters}');
    buffer.writeln('characters,protagonistCount,${stats.protagonistCount}');
    buffer.writeln('characters,supportingCount,${stats.supportingCount}');
    buffer.writeln('characters,minorCount,${stats.minorCount}');

    return buffer.toString();
  }

  Future<String> exportDailyWordCountToCsv(
    String workId, {
    int days = 30,
  }) async {
    final dailyCounts = await _getRecentWordCounts(workId, days);
    final buffer = StringBuffer();
    buffer.writeln('date,wordCount,chapterCount,writingMinutes');
    for (final daily in dailyCounts) {
      buffer.writeln(
        '${daily.date.toIso8601String()},${daily.wordCount},${daily.chapterCount},${daily.writingMinutes}',
      );
    }
    return buffer.toString();
  }

  Future<String> exportWordCountTrendToCsv(
    String workId, {
    TrendPeriod period = TrendPeriod.daily,
    int periods = 30,
  }) async {
    final trend = await getWordCountTrend(
      workId,
      period: period,
      periods: periods,
    );
    final buffer = StringBuffer();
    buffer.writeln('date,value,cumulativeValue,growthRate,totalGrowth');
    for (final point in trend.dataPoints) {
      buffer.writeln(
        '${point.date.toIso8601String()},${point.value},${point.cumulativeValue},${trend.growthRate.toStringAsFixed(2)}%,${trend.totalGrowth}',
      );
    }
    return buffer.toString();
  }

  Future<String> exportCharacterAppearanceToCsv(String workId) async {
    final stats = await getCharacterAppearanceStats(workId);
    final buffer = StringBuffer();
    buffer.writeln(
      'characterId,characterName,appearanceCount,dialogueCount,chapterIds,screenTimePercentage',
    );
    for (final stat in stats) {
      buffer.writeln(
        '${_csvValue(stat.characterId)},${_csvValue(stat.characterName)},${stat.appearanceCount},${stat.dialogueCount},${_csvValue(stat.chapterIds.join(';'))},${stat.screenTimePercentage.toStringAsFixed(2)}',
      );
    }
    return buffer.toString();
  }

  Future<String> exportWritingReportToJson(
    String workId, {
    ReportPeriod period = ReportPeriod.weekly,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final report = await generateReport(
      workId,
      period: period,
      startDate: startDate,
      endDate: endDate,
    );
    return jsonEncode(report.toJson());
  }

  Future<String> exportWritingReportToCsv(
    String workId, {
    ReportPeriod period = ReportPeriod.weekly,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final report = await generateReport(
      workId,
      period: period,
      startDate: startDate,
      endDate: endDate,
    );
    final buffer = StringBuffer();

    buffer.writeln('section,key,value');
    buffer.writeln('report,id,${_csvValue(report.id)}');
    buffer.writeln('report,period,${report.period.label}');
    buffer.writeln('report,startDate,${report.startDate.toIso8601String()}');
    buffer.writeln('report,endDate,${report.endDate.toIso8601String()}');
    buffer.writeln(
      'report,generatedAt,${report.generatedAt.toIso8601String()}',
    );
    buffer.writeln('summary,totalWords,${report.totalWords}');
    buffer.writeln('summary,averageDailyWords,${report.averageDailyWords}');
    buffer.writeln('summary,writingDays,${report.writingDays}');
    buffer.writeln('summary,chaptersCompleted,${report.chaptersCompleted}');
    buffer.writeln('summary,chaptersPublished,${report.chaptersPublished}');
    buffer.writeln('breakdown,date,wordCount,chapterCount,writingMinutes');
    for (final daily in report.dailyBreakdown) {
      buffer.writeln(
        '${daily.date.toIso8601String()},${daily.wordCount},${daily.chapterCount},${daily.writingMinutes}',
      );
    }

    return buffer.toString();
  }

  Future<String> exportCompleteStatisticsPackage(String workId) async {
    final package = <String, dynamic>{
      'exportDate': DateTime.now().toIso8601String(),
      'workId': workId,
      'statistics': jsonDecode(await exportWorkStatisticsToJson(workId)),
      'wordCountTrend': jsonDecode(
        jsonEncode(
          (await getWordCountTrend(
            workId,
            period: TrendPeriod.daily,
            periods: 30,
          )).toJson(),
        ),
      ),
      'characterAppearances': jsonDecode(
        jsonEncode(
          (await getCharacterAppearanceStats(
            workId,
          )).map((e) => e.toJson()).toList(),
        ),
      ),
      'recentWordCounts': (await _getRecentWordCounts(
        workId,
        30,
      )).map((e) => e.toJson()).toList(),
    };

    return jsonEncode(package);
  }

  Future<String> exportAIUsageStatisticsToCsv({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final aiService = Get.find<AIService>();
    final summaries = await aiService.getAIUsageSummaries(
      workId: workId,
      startDate: startDate,
      endDate: endDate,
    );

    final buffer = StringBuffer();
    buffer.writeln(
      'date,modelId,tier,functionType,requestCount,successCount,errorCount,cachedCount,totalTokens,avgResponseTimeMs,estimatedCost',
    );
    for (final summary in summaries) {
      buffer.writeln(
        '${summary.date.toIso8601String()},${_csvValue(summary.modelId)},${_csvValue(summary.tier)},${_csvValue(summary.functionType ?? 'all')},${summary.requestCount},${summary.successCount},${summary.errorCount},${summary.cachedCount},${summary.totalTokens},${summary.avgResponseTimeMs},${summary.estimatedCost.toStringAsFixed(4)}',
      );
    }
    return buffer.toString();
  }

  Future<work_domain.Work?> _loadWork(String workId) {
    final repository = Get.find<WorkRepository>();
    return repository.getById(workId);
  }

  Future<List<chapter_domain.Chapter>> _loadChapters(String workId) {
    final repository = Get.find<ChapterRepository>();
    return repository.getChaptersByWorkId(workId);
  }

  Future<List<character_domain.Character>> _loadCharacters(String workId) {
    final repository = Get.find<CharacterRepository>();
    return repository.getCharactersByWorkId(workId);
  }

  Future<int> _getTotalVolumes(String workId) async {
    final rows = await (_db.select(
      _db.volumes,
    )..where((table) => table.workId.equals(workId))).get();
    return rows.length;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isWithinRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  ChapterStatus _mapChapterStatus(chapter_domain.ChapterStatus status) {
    return switch (status) {
      chapter_domain.ChapterStatus.draft => ChapterStatus.draft,
      chapter_domain.ChapterStatus.reviewing => ChapterStatus.review,
      chapter_domain.ChapterStatus.published => ChapterStatus.published,
    };
  }

  String _csvValue(Object? value) {
    final text = value?.toString() ?? '';
    final escaped = text.replaceAll('"', '""');
    return escaped.contains(',') ||
            escaped.contains('\n') ||
            escaped.contains('"')
        ? '"$escaped"'
        : escaped;
  }
}

class _CharacterAppearanceAccumulator {
  final Set<String> chapterIds = <String>{};
  int appearanceCount = 0;
  int dialogueCount = 0;
}
