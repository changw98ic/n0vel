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
import 'statistics_service_helpers.dart';

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
    return buildWorkStatisticsModel(
      workId: workId,
      work: work,
      totalVolumes: await _getTotalVolumes(workId),
      chapters: chapters,
      characters: characters,
      recentWordCounts: recentWordCounts,
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
    return buildRecentWordCounts(sourceChapters, days);
  }

  Future<WordCountTrend> getWordCountTrend(
    String workId, {
    TrendPeriod period = TrendPeriod.daily,
    int periods = 30,
  }) async {
    final chapters = await _loadChapters(workId);
    return buildWordCountTrend(
      chapters,
      period: period,
      periods: periods,
    );
  }

  Future<List<CharacterAppearanceStats>> getCharacterAppearanceStats(
    String workId,
  ) async {
    final chapters = await _loadChapters(workId);
    final characters = await _loadCharacters(workId);
    final links = await _db.select(_db.chapterCharacters).get();
    return buildCharacterAppearanceStats(
      chapters: chapters,
      characters: characters,
      links: links,
    );
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
    return buildWritingReportModel(
      workId: workId,
      work: work,
      chapters: chapters,
      period: period,
      startDate: startDate,
      endDate: endDate,
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
    buffer.writeln('work,workTitle,${statisticsCsvValue(stats.workTitle)}');
    buffer.writeln(
      'work,createdAt,${statisticsCsvValue(stats.createdAt.toIso8601String())}',
    );
    buffer.writeln(
      'work,updatedAt,${statisticsCsvValue(stats.updatedAt.toIso8601String())}',
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
        '${statisticsCsvValue(stat.characterId)},${statisticsCsvValue(stat.characterName)},${stat.appearanceCount},${stat.dialogueCount},${statisticsCsvValue(stat.chapterIds.join(';'))},${stat.screenTimePercentage.toStringAsFixed(2)}',
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
    buffer.writeln('report,id,${statisticsCsvValue(report.id)}');
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
        '${summary.date.toIso8601String()},${statisticsCsvValue(summary.modelId)},${statisticsCsvValue(summary.tier)},${statisticsCsvValue(summary.functionType ?? 'all')},${summary.requestCount},${summary.successCount},${summary.errorCount},${summary.cachedCount},${summary.totalTokens},${summary.avgResponseTimeMs},${summary.estimatedCost.toStringAsFixed(4)}',
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
}
