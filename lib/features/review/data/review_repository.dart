import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../domain/review_report.dart';
import '../domain/review_result.dart';
import 'review_repository_helpers.dart';

@visibleForTesting
Map<String, dynamic>? decodeReviewJson(
  String? raw, {
  String context = 'review payload',
}) => decodeReviewRepositoryJson(raw, context: context);

@visibleForTesting
ReviewReport buildReviewReport({
  required String taskId,
  required String chapterId,
  required Map<String, dynamic> json,
  DateTime? createdAt,
}) => buildReviewRepositoryReport(
  taskId: taskId,
  chapterId: chapterId,
  json: json,
  createdAt: createdAt,
);

class ReviewRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  ReviewRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<List<ReviewResult>> getReviewResults(String workId) async {
    final chapters =
        await (_db.select(_db.chapters)
              ..where((t) => t.workId.equals(workId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

    final reviewTasks =
        await (_db.select(_db.aiTasks)
              ..where((t) => t.workId.equals(workId) & t.type.equals('review'))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    final results = <ReviewResult>[];
    for (final chapter in chapters) {
      final reviewTask = _findReviewTaskForChapter(reviewTasks, chapter.id);

      double? score;
      var issueCount = 0;
      var criticalCount = 0;
      var status = ReviewStatus.notReviewed;
      DateTime? reviewedAt;

      if (reviewTask != null) {
        final resultJson = _decodeJsonMap(reviewTask.result);
        final issues = _readIssueMaps(resultJson?['issues']);

        score = _readDouble(resultJson?['overallScore']);
        issueCount = issues.length;
        criticalCount = issues
            .where((issue) => issue['severity'] == IssueSeverity.critical.name)
            .length;
        status = _mapTaskStatus(reviewTask.status, score: score);
        reviewedAt = reviewTask.completedAt ?? reviewTask.updatedAt;
      }

      results.add(
        buildReviewRepositoryResult(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          score: score,
          issueCount: issueCount,
          criticalCount: criticalCount,
          status: status,
          reviewedAt: reviewedAt,
        ),
      );
    }

    return results;
  }

  Future<ReviewReport?> getReviewReport(String chapterId) async {
    final tasks =
        await (_db.select(_db.aiTasks)
              ..where((t) => t.type.equals('review'))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    for (final task in tasks) {
      final resultJson = _decodeJsonMap(task.result);
      if (resultJson == null || resultJson['chapterId'] != chapterId) {
        continue;
      }

      return _parseReviewReport(task.id, chapterId, resultJson);
    }

    return null;
  }

  Future<void> saveReviewReport(ReviewReport report) async {
    final reportJson = buildReviewRepositoryReportJson(report);

    final now = DateTime.now();
    final existingTasks =
        await (_db.select(_db.aiTasks)
              ..where((t) => t.type.equals('review'))
              ..limit(1))
            .get();

    if (existingTasks.isEmpty) {
      await _db
          .into(_db.aiTasks)
          .insert(
            AiTasksCompanion(
              id: Value(report.id),
              workId: Value(report.chapterId),
              name: const Value('审查章节'),
              type: const Value('review'),
              status: const Value('completed'),
              progress: const Value(1.0),
              result: Value(jsonEncode(reportJson)),
              createdAt: Value(now),
              updatedAt: Value(now),
              completedAt: Value(now),
            ),
          );
      return;
    }

    await (_db.update(_db.aiTasks)..where((t) => t.id.equals(report.id))).write(
      AiTasksCompanion(
        result: Value(jsonEncode(reportJson)),
        status: const Value('completed'),
        progress: const Value(1.0),
        updatedAt: Value(now),
        completedAt: Value(now),
      ),
    );
  }

  Future<void> updateIssueStatus(
    String issueId,
    IssueStatus status, {
    String? fixedBy,
  }) async {
    final tasks = await (_db.select(
      _db.aiTasks,
    )..where((t) => t.type.equals('review'))).get();

    for (final task in tasks) {
      final resultJson = _decodeJsonMap(task.result);
      if (resultJson == null) {
        continue;
      }

      final issues = _readIssueMaps(resultJson['issues']).toList();
      var updated = false;

      for (final issue in issues) {
        if (issue['id'] != issueId) {
          continue;
        }

        issue['status'] = status.name;
        if (fixedBy != null) {
          issue['fixedBy'] = fixedBy;
          issue['fixedAt'] = DateTime.now().toIso8601String();
        }
        updated = true;
        break;
      }

      if (!updated) {
        continue;
      }

      resultJson['issues'] = issues;
      await (_db.update(_db.aiTasks)..where((t) => t.id.equals(task.id))).write(
        AiTasksCompanion(
          result: Value(jsonEncode(resultJson)),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    throw Exception('Issue not found: $issueId');
  }

  Future<ReviewStatistics> getReviewStatistics(String workId) async {
    final results = await getReviewResults(workId);

    final totalChapters = results.length;
    final reviewedChapters = results
        .where(
          (r) =>
              r.status == ReviewStatus.passed ||
              r.status == ReviewStatus.needsFix ||
              r.status == ReviewStatus.failed,
        )
        .length;
    final passedChapters = results
        .where((r) => r.status == ReviewStatus.passed)
        .length;

    var totalIssues = 0;
    var pendingIssues = 0;
    var totalScore = 0.0;
    var scoredCount = 0;
    final dimensionScores = <ReviewDimension, List<double>>{};

    for (final result in results) {
      if (result.score != null) {
        totalScore += result.score!;
        scoredCount++;
      }

      totalIssues += result.issueCount;

      final report = await getReviewReport(result.chapterId);
      if (report == null) {
        continue;
      }

      pendingIssues += report.issues
          .where((issue) => issue.status == IssueStatus.pending)
          .length;

      for (final entry in report.dimensionScores.entries) {
        final dimension = ReviewDimension.values.firstWhere(
          (value) => value.name == entry.key,
          orElse: () => ReviewDimension.consistency,
        );
        dimensionScores.putIfAbsent(dimension, () => []).add(entry.value);
      }
    }

    final avgScore = buildReviewRepositoryAverageScore(
      totalScore: totalScore,
      scoredCount: scoredCount,
    );
    final dimensionAvgScores =
        buildReviewRepositoryDimensionAverageScores(dimensionScores);

    return ReviewStatistics(
      totalChapters: totalChapters,
      reviewedChapters: reviewedChapters,
      passedChapters: passedChapters,
      totalIssues: totalIssues,
      pendingIssues: pendingIssues,
      avgScore: avgScore,
      dimensionAvgScores: dimensionAvgScores,
    );
  }

  ReviewReport _parseReviewReport(
    String taskId,
    String chapterId,
    Map<String, dynamic> json,
  ) {
    return buildReviewReport(
      taskId: taskId,
      chapterId: chapterId,
      json: json,
      createdAt: DateTime.now(),
    );
  }

  Future<String> createReviewTask({
    required String workId,
    required List<String> chapterIds,
    required List<ReviewDimension> dimensions,
  }) async {
    final taskId = _uuid.v4();
    final now = DateTime.now();
    final chapters =
        await (_db.select(_db.chapters)
              ..where((t) => t.workId.equals(workId) & t.id.isIn(chapterIds))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

    final chapterContents = <String, String>{
      for (final chapter in chapters)
        '${chapter.title} (${chapter.id})': chapter.content ?? '',
    };

    final config = {
      'chapterIds': chapterIds,
      'dimensions': dimensions.map((d) => d.name).toList(),
      if (chapterContents.isNotEmpty) 'chapterContents': chapterContents,
      if (chapterContents.length == 1)
        'chapterContent': chapterContents.values.first,
    };

    await _db
        .into(_db.aiTasks)
        .insert(
          AiTasksCompanion(
            id: Value(taskId),
            workId: Value(workId),
            name: Value('审查 ${chapterIds.length} 个章节'),
            type: const Value('review'),
            status: const Value('pending'),
            progress: const Value(0),
            currentNodeIndex: const Value(0),
            config: Value(jsonEncode(config)),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return taskId;
  }

  Future<void> updateReviewTaskStatus({
    required String taskId,
    required String status,
    double? progress,
    String? result,
    String? errorMessage,
  }) async {
    final now = DateTime.now();

    await (_db.update(_db.aiTasks)..where((t) => t.id.equals(taskId))).write(
      AiTasksCompanion(
        status: Value(status),
        updatedAt: Value(now),
        progress: progress != null ? Value(progress) : const Value.absent(),
        result: result != null ? Value(result) : const Value.absent(),
        errorMessage: errorMessage != null
            ? Value(errorMessage)
            : const Value.absent(),
        completedAt: status == 'completed' ? Value(now) : const Value.absent(),
      ),
    );
  }

  Future<Map<String, dynamic>?> getReviewTaskConfig(String taskId) async {
    final task =
        await (_db.select(_db.aiTasks)
              ..where((t) => t.id.equals(taskId))
              ..limit(1))
            .getSingleOrNull();

    return _decodeJsonMap(task?.config);
  }

  Future<void> recordReviewTaskUsage({
    required String taskId,
    required int inputTokens,
    required int outputTokens,
  }) async {
    await (_db.update(_db.aiTasks)..where((t) => t.id.equals(taskId))).write(
      AiTasksCompanion(
        inputTokens: Value(inputTokens),
        outputTokens: Value(outputTokens),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<String> createReviewNodeRun({
    required String taskId,
    required String nodeName,
    required int nodeIndex,
    String? branchId,
  }) async {
    final nodeId = _uuid.v4();
    final now = DateTime.now();

    await _db
        .into(_db.workflowNodeRuns)
        .insert(
          WorkflowNodeRunsCompanion(
            id: Value(nodeId),
            taskId: Value(taskId),
            nodeName: Value(nodeName),
            nodeIndex: Value(nodeIndex),
            branchId: Value(branchId ?? 'main'),
            status: const Value('pending'),
            attempt: const Value(0),
            createdAt: Value(now),
          ),
        );

    return nodeId;
  }

  Future<void> updateReviewNodeRun({
    required String nodeId,
    required String status,
    String? outputSnapshot,
    String? error,
    int? inputTokens,
    int? outputTokens,
  }) async {
    final now = DateTime.now();

    await (_db.update(
      _db.workflowNodeRuns,
    )..where((t) => t.id.equals(nodeId))).write(
      WorkflowNodeRunsCompanion(
        status: Value(status),
        outputSnapshot: outputSnapshot != null
            ? Value(outputSnapshot)
            : const Value.absent(),
        error: error != null ? Value(error) : const Value.absent(),
        inputTokens: inputTokens != null
            ? Value(inputTokens)
            : const Value.absent(),
        outputTokens: outputTokens != null
            ? Value(outputTokens)
            : const Value.absent(),
        finishedAt: (status == 'completed' || status == 'failed')
            ? Value(now)
            : const Value.absent(),
        startedAt: status == 'running' ? Value(now) : const Value.absent(),
      ),
    );
  }

  AITask? _findReviewTaskForChapter(List<AITask> tasks, String chapterId) {
    for (final task in tasks) {
      final resultJson = _decodeJsonMap(task.result);
      if (resultJson != null && resultJson['chapterId'] == chapterId) {
        return task;
      }
    }
    return null;
  }

  Map<String, dynamic>? _decodeJsonMap(String? raw) {
    return decodeReviewJson(raw);
  }

  Iterable<Map<String, dynamic>> _readIssueMaps(Object? value) {
    return readReviewRepositoryIssueMaps(value);
  }

  ReviewStatus _mapTaskStatus(String taskStatus, {required double? score}) {
    return mapReviewRepositoryTaskStatus(taskStatus, score: score);
  }

  double? _readDouble(Object? value) {
    return readReviewRepositoryDouble(value);
  }
}

class ReviewStatistics {
  final int totalChapters;
  final int reviewedChapters;
  final int passedChapters;
  final int totalIssues;
  final int pendingIssues;
  final double avgScore;
  final Map<ReviewDimension, double> dimensionAvgScores;

  ReviewStatistics({
    required this.totalChapters,
    required this.reviewedChapters,
    required this.passedChapters,
    required this.totalIssues,
    required this.pendingIssues,
    required this.avgScore,
    required this.dimensionAvgScores,
  });

  double get passRate =>
      reviewedChapters > 0 ? passedChapters / reviewedChapters : 0;
}
