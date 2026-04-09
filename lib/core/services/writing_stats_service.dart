import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// 写作统计概览
class WritingStatsOverview {
  final int totalWords;
  final int totalChapters;
  final int totalSessions;
  final int totalDurationMinutes;
  final double avgWordsPerSession;
  final double avgWordsPerHour;
  final int currentStreak;
  final int longestStreak;

  const WritingStatsOverview({
    required this.totalWords,
    required this.totalChapters,
    required this.totalSessions,
    required this.totalDurationMinutes,
    required this.avgWordsPerSession,
    required this.avgWordsPerHour,
    required this.currentStreak,
    required this.longestStreak,
  });
}

/// 每日写作趋势数据点
class DailyStatsPoint {
  final DateTime date;
  final int wordsWritten;
  final int durationMinutes;
  final int sessionCount;

  const DailyStatsPoint({
    required this.date,
    required this.wordsWritten,
    required this.durationMinutes,
    required this.sessionCount,
  });
}

/// 章节统计
class ChapterStats {
  final String chapterId;
  final String chapterTitle;
  final int wordCount;
  final double dialogueRatio;
  final DateTime? lastEdited;

  const ChapterStats({
    required this.chapterId,
    required this.chapterTitle,
    required this.wordCount,
    required this.dialogueRatio,
    this.lastEdited,
  });
}

/// 写作统计服务
class WritingStatsService {
  final AppDatabase _db;
  final _uuid = const Uuid();

  WritingStatsService(this._db);

  /// 开始写作会话
  Future<WritingSession> startSession({
    required String workId,
    String? chapterId,
    required int currentWordCount,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.into(_db.writingSessionsTable).insert(
          WritingSessionsTableCompanion.insert(
            id: id,
            workId: workId,
            startTime: now,
            startWordCount: currentWordCount,
            createdAt: now,
            chapterId: Value(chapterId),
          ),
        );

    return WritingSession(
      id: id,
      workId: workId,
      chapterId: chapterId,
      startTime: now,
      endTime: null,
      startWordCount: currentWordCount,
      endWordCount: 0,
      wordsWritten: 0,
      durationSeconds: 0,
      createdAt: now,
    );
  }

  /// 结束写作会话
  Future<void> endSession(
    String sessionId, {
    required int finalWordCount,
  }) async {
    // Fetch the existing session
    final sessionQuery = _db.select(_db.writingSessionsTable)
      ..where((t) => t.id.equals(sessionId));
    final session = await sessionQuery.getSingleOrNull();
    if (session == null) return;

    final now = DateTime.now();
    final wordsWritten =
        finalWordCount > session.startWordCount
            ? finalWordCount - session.startWordCount
            : 0;
    final durationSeconds = now.difference(session.startTime).inSeconds;

    // Update the session row
    await (_db.update(_db.writingSessionsTable)
          ..where((t) => t.id.equals(sessionId)))
        .write(
      WritingSessionsTableCompanion(
        endTime: Value(now),
        endWordCount: Value(finalWordCount),
        wordsWritten: Value(wordsWritten),
        durationSeconds: Value(durationSeconds),
      ),
    );

    // Update or insert the daily writing stat
    final dayStart = _startOfDay(now);
    final dayEnd = _endOfDay(now);

    // Check if a daily stat already exists for this work and date
    final existingStatQuery = _db.select(_db.dailyWritingStats)
      ..where((t) =>
          t.workId.equals(session.workId) &
          t.date.isBiggerOrEqualValue(dayStart) &
          t.date.isSmallerOrEqualValue(dayEnd));
    final existingStat = await existingStatQuery.getSingleOrNull();

    if (existingStat != null) {
      // Update existing daily stat
      final newTotalWords =
          existingStat.totalWordsWritten + wordsWritten;
      final newTotalDuration =
          existingStat.totalDurationSeconds + durationSeconds;
      final newSessionCount = existingStat.sessionCount + 1;

      // Count distinct chapters worked on today
      final chaptersWorkedOn =
          await _countDistinctChaptersForDay(session.workId, dayStart, dayEnd);

      await (_db.update(_db.dailyWritingStats)
            ..where((t) => t.id.equals(existingStat.id)))
          .write(
        DailyWritingStatsCompanion(
          totalWordsWritten: Value(newTotalWords),
          totalDurationSeconds: Value(newTotalDuration),
          sessionCount: Value(newSessionCount),
          chaptersWorkedOn: Value(chaptersWorkedOn),
          updatedAt: Value(now),
        ),
      );
    } else {
      // Insert new daily stat
      final chaptersWorkedOn =
          await _countDistinctChaptersForDay(session.workId, dayStart, dayEnd);

      await _db.into(_db.dailyWritingStats).insert(
            DailyWritingStatsCompanion.insert(
              id: _uuid.v4(),
              workId: session.workId,
              date: dayStart,
              totalWordsWritten: Value(wordsWritten),
              totalDurationSeconds: Value(durationSeconds),
              sessionCount: const Value(1),
              chaptersWorkedOn: Value(chaptersWorkedOn),
              createdAt: now,
            ),
          );
    }
  }

  /// 获取作品的写作统计概览
  Future<WritingStatsOverview> getOverview(String workId) async {
    // Aggregate all sessions for this work
    final sessions = await (_db.select(_db.writingSessionsTable)
          ..where((t) => t.workId.equals(workId)))
        .get();

    // Count completed sessions (those with endTime set)
    final completedSessions =
        sessions.where((s) => s.endTime != null).toList();

    final totalWords = completedSessions.fold<int>(
        0, (sum, s) => sum + s.wordsWritten.toInt());
    final totalDurationSeconds = completedSessions.fold<int>(
        0, (sum, s) => sum + s.durationSeconds.toInt());
    final totalDurationMinutes = totalDurationSeconds ~/ 60;
    final totalSessions = completedSessions.length;

    final avgWordsPerSession =
        totalSessions > 0 ? totalWords / totalSessions : 0.0;
    final avgWordsPerHour = totalDurationMinutes > 0
        ? totalWords / (totalDurationMinutes / 60)
        : 0.0;

    // Count total chapters for this work
    final chapters =
        await (_db.select(_db.chapters)..where((t) => t.workId.equals(workId)))
            .get();
    final totalChapters = chapters.length;

    // Calculate streaks
    final currentStreak = await getCurrentStreak(workId);
    final longestStreak = await _getLongestStreak(workId);

    return WritingStatsOverview(
      totalWords: totalWords,
      totalChapters: totalChapters,
      totalSessions: totalSessions,
      totalDurationMinutes: totalDurationMinutes,
      avgWordsPerSession: avgWordsPerSession,
      avgWordsPerHour: avgWordsPerHour,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
  }

  /// 获取每日写作趋势（最近 N 天）
  Future<List<DailyStatsPoint>> getDailyTrend(
    String workId, {
    int days = 30,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    final dailyStats = await (_db.select(_db.dailyWritingStats)
          ..where((t) =>
              t.workId.equals(workId) & t.date.isBiggerOrEqualValue(startDate)))
        .get();

    // Build a map for quick lookup (date-only key)
    final statsByDate = <String, DailyWritingStat>{};
    for (final stat in dailyStats) {
      final key = _dateKey(stat.date);
      statsByDate[key] = stat;
    }

    // Fill all days in the range, defaulting to zero
    final result = <DailyStatsPoint>[];
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final key = _dateKey(date);
      final stat = statsByDate[key];

      result.add(DailyStatsPoint(
        date: date,
        wordsWritten: stat?.totalWordsWritten ?? 0,
        durationMinutes:
            (stat?.totalDurationSeconds ?? 0) ~/ 60,
        sessionCount: stat?.sessionCount ?? 0,
      ));
    }

    return result;
  }

  /// 获取章节统计列表
  Future<List<ChapterStats>> getChapterStats(String workId) async {
    final chapters =
        await (_db.select(_db.chapters)..where((t) => t.workId.equals(workId)))
            .get();

    if (chapters.isEmpty) return [];

    final result = <ChapterStats>[];
    for (final chapter in chapters) {
      final dialogueRatio = _computeDialogueRatio(chapter.content);
      result.add(ChapterStats(
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        wordCount: chapter.wordCount,
        dialogueRatio: dialogueRatio,
        lastEdited: chapter.updatedAt,
      ));
    }

    return result;
  }

  /// 获取写作热力图数据（过去 N 个月，每天是否写作）
  Future<Map<DateTime, int>> getWritingHeatmap(
    String workId, {
    int months = 12,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1)
        .subtract(Duration(days: 30 * (months - 1)));

    final dailyStats = await (_db.select(_db.dailyWritingStats)
          ..where((t) =>
              t.workId.equals(workId) & t.date.isBiggerOrEqualValue(startDate)))
        .get();

    final result = <DateTime, int>{};
    for (final stat in dailyStats) {
      final dateOnly = DateTime(
        stat.date.year,
        stat.date.month,
        stat.date.day,
      );
      result[dateOnly] = stat.totalWordsWritten;
    }

    return result;
  }

  /// 计算连续写作天数
  Future<int> getCurrentStreak(String workId) async {
    final activeDates = await _getActiveDates(workId);
    if (activeDates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var checkDate = today;
    if (!activeDates.contains(_dateKey(checkDate))) {
      final yesterday = today.subtract(const Duration(days: 1));
      if (!activeDates.contains(_dateKey(yesterday))) return 0;
      checkDate = yesterday;
    }

    int streak = 0;
    while (activeDates.contains(_dateKey(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 获取今日写作统计
  Future<DailyStatsPoint?> getTodayStats(String workId) async {
    final now = DateTime.now();
    final dayStart = _startOfDay(now);
    final dayEnd = _endOfDay(now);

    final stat = await (_db.select(_db.dailyWritingStats)
          ..where((t) =>
              t.workId.equals(workId) &
              t.date.isBiggerOrEqualValue(dayStart) &
              t.date.isSmallerOrEqualValue(dayEnd)))
        .getSingleOrNull();

    if (stat == null) return null;

    return DailyStatsPoint(
      date: stat.date,
      wordsWritten: stat.totalWordsWritten,
      durationMinutes: stat.totalDurationSeconds ~/ 60,
      sessionCount: stat.sessionCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Count distinct chapters that had writing sessions within a day range.
  Future<int> _countDistinctChaptersForDay(
    String workId,
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    final sessions = await (_db.select(_db.writingSessionsTable)
          ..where((t) =>
              t.workId.equals(workId) &
              t.startTime.isBiggerOrEqualValue(dayStart) &
              t.startTime.isSmallerOrEqualValue(dayEnd)))
        .get();

    final chapterIds = <String?>{};
    for (final s in sessions) {
      chapterIds.add(s.chapterId);
    }
    // Exclude null entries (sessions not tied to a specific chapter)
    chapterIds.remove(null);
    return chapterIds.length;
  }

  /// Get the set of active date keys for a work.
  Future<Set<String>> _getActiveDates(String workId) async {
    final dailyStats = await (_db.select(_db.dailyWritingStats)
          ..where((t) => t.workId.equals(workId)))
        .get();
    return {
      for (final s in dailyStats)
        if (s.totalWordsWritten > 0 || s.sessionCount > 0) _dateKey(s.date),
    };
  }

  /// Calculate the longest writing streak for a work.
  Future<int> _getLongestStreak(String workId) async {
    final activeDates = await _getActiveDates(workId);
    if (activeDates.isEmpty) return 0;

    final sortedKeys = activeDates.toList()..sort();
    final firstDate = _parseDateKey(sortedKeys.first);
    final lastDate = _parseDateKey(sortedKeys.last);

    int longest = 0, current = 0;
    var checkDate = firstDate;
    while (!checkDate.isAfter(lastDate)) {
      if (activeDates.contains(_dateKey(checkDate))) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
      checkDate = checkDate.add(const Duration(days: 1));
    }
    return longest;
  }

  /// Compute the ratio of dialogue text in chapter content.
  /// Dialogue is detected by common Chinese quotation marks ("…" and 「…」)
  /// and English quotation marks ("…" and '…').
  double _computeDialogueRatio(String? content) {
    if (content == null || content.isEmpty) return 0.0;

    // Match Chinese dialogue: 「…」and "…"
    final dialogueRegex = RegExp(r'[「"][^」"]*[」"]');
    final matches = dialogueRegex.allMatches(content);

    int dialogueChars = 0;
    for (final match in matches) {
      dialogueChars += match.group(0)!.length;
    }

    // Remove whitespace for a fair ratio
    final contentWithoutWhitespace =
        content.replaceAll(RegExp(r'\s'), '');
    if (contentWithoutWhitespace.isEmpty) return 0.0;

    return dialogueChars / contentWithoutWhitespace.length;
  }

  /// Return the start of the day (midnight) for a given datetime.
  DateTime _startOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Return the end of the day (23:59:59.999) for a given datetime.
  DateTime _endOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);
  }

  /// Create a string key from a DateTime for date-based lookups.
  String _dateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Parse a date key string back into a DateTime.
  DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
