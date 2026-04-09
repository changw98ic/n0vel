import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../domain/review_report.dart';
import '../domain/review_result.dart';

@visibleForTesting
Map<String, dynamic>? decodeReviewJson(
  String? raw, {
  String context = 'review payload',
}) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    debugPrint('ReviewRepository: expected JSON object for $context.');
  } catch (error) {
    debugPrint('ReviewRepository: failed to decode $context: $error');
  }

  return null;
}

@visibleForTesting
ReviewReport buildReviewReport({
  required String taskId,
  required String chapterId,
  required Map<String, dynamic> json,
  DateTime? createdAt,
}) {
  final overallScore = (json['overallScore'] as num?)?.toDouble() ?? 0.0;
  final rawDimensionScores =
      json['dimensionScores'] as Map<String, dynamic>? ?? const {};
  final dimensionScores = rawDimensionScores.map(
    (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0.0),
  );

  final rawIssues = json['issues'] as List<dynamic>? ?? const [];
  final issues = rawIssues
      .whereType<Map<String, dynamic>>()
      .map(
        (item) => ReviewIssue(
          id:
              item['id'] as String? ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          reportId: taskId,
          dimension: ReviewDimension.values.firstWhere(
            (value) => value.name == item['dimension'],
            orElse: () => ReviewDimension.consistency,
          ),
          severity: IssueSeverity.values.firstWhere(
            (value) => value.name == item['severity'],
            orElse: () => IssueSeverity.minor,
          ),
          status: IssueStatus.values.firstWhere(
            (value) => value.name == (item['status'] as String? ?? 'pending'),
            orElse: () => IssueStatus.pending,
          ),
          description: item['description'] as String? ?? '未提供描述',
          originalText: item['originalText'] as String?,
          location: item['location'] as String?,
          suggestion: item['suggestion'] as String?,
        ),
      )
      .toList();

  final criticalCount = issues
      .where((issue) => issue.severity == IssueSeverity.critical)
      .length;
  final majorCount = issues
      .where((issue) => issue.severity == IssueSeverity.major)
      .length;
  final minorCount = issues
      .where((issue) => issue.severity == IssueSeverity.minor)
      .length;

  return ReviewReport(
    id: taskId,
    chapterId: chapterId,
    createdAt: createdAt ?? DateTime.now(),
    overallScore: overallScore,
    dimensionScores: dimensionScores,
    issues: issues,
    criticalCount: criticalCount,
    majorCount: majorCount,
    minorCount: minorCount,
  );
}

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
        ReviewResult(
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
    final reportJson = {
      'chapterId': report.chapterId,
      'overallScore': report.overallScore,
      'dimensionScores': report.dimensionScores,
      'issues': report.issues
          .map(
            (issue) => {
              'id': issue.id,
              'dimension': issue.dimension.name,
              'severity': issue.severity.name,
              'status': issue.status.name,
              'description': issue.description,
              'originalText': issue.originalText,
              'location': issue.location,
              'suggestion': issue.suggestion,
            },
          )
          .toList(),
      'criticalCount': report.criticalCount,
      'majorCount': report.majorCount,
      'minorCount': report.minorCount,
    };

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

    final avgScore = scoredCount > 0 ? totalScore / scoredCount : 0.0;
    final dimensionAvgScores = <ReviewDimension, double>{};
    for (final entry in dimensionScores.entries) {
      final scores = entry.value;
      dimensionAvgScores[entry.key] = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;
    }

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
    final rawList = value is List ? value : const [];
    return rawList.whereType<Map<String, dynamic>>();
  }

  ReviewStatus _mapTaskStatus(String taskStatus, {required double? score}) {
    switch (taskStatus) {
      case 'completed':
        return score != null && score >= 70
            ? ReviewStatus.passed
            : ReviewStatus.needsFix;
      case 'running':
        return ReviewStatus.reviewing;
      case 'failed':
        return ReviewStatus.failed;
      default:
        return ReviewStatus.notReviewed;
    }
  }

  double? _readDouble(Object? value) {
    return value is num ? value.toDouble() : null;
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
