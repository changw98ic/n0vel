import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/review_report.dart';
import '../domain/review_result.dart';

Map<String, dynamic>? decodeReviewRepositoryJson(
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

ReviewReport buildReviewRepositoryReport({
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

  final issues = (json['issues'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map((item) => buildReviewRepositoryIssue(item, taskId))
      .toList();

  return ReviewReport(
    id: taskId,
    chapterId: chapterId,
    createdAt: createdAt ?? DateTime.now(),
    overallScore: overallScore,
    dimensionScores: dimensionScores,
    issues: issues,
    criticalCount: issues
        .where((issue) => issue.severity == IssueSeverity.critical)
        .length,
    majorCount:
        issues.where((issue) => issue.severity == IssueSeverity.major).length,
    minorCount:
        issues.where((issue) => issue.severity == IssueSeverity.minor).length,
  );
}

ReviewIssue buildReviewRepositoryIssue(
  Map<String, dynamic> item,
  String reportId,
) {
  return ReviewIssue(
    id: item['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
    reportId: reportId,
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
  );
}

ReviewResult buildReviewRepositoryResult({
  required String chapterId,
  required String chapterTitle,
  required double? score,
  required int issueCount,
  required int criticalCount,
  required ReviewStatus status,
  required DateTime? reviewedAt,
}) {
  return ReviewResult(
    chapterId: chapterId,
    chapterTitle: chapterTitle,
    score: score,
    issueCount: issueCount,
    criticalCount: criticalCount,
    status: status,
    reviewedAt: reviewedAt,
  );
}

Map<String, dynamic> buildReviewRepositoryReportJson(ReviewReport report) {
  return {
    'chapterId': report.chapterId,
    'overallScore': report.overallScore,
    'dimensionScores': report.dimensionScores,
    'issues': report.issues.map(buildReviewRepositoryIssueJson).toList(),
    'criticalCount': report.criticalCount,
    'majorCount': report.majorCount,
    'minorCount': report.minorCount,
  };
}

Map<String, dynamic> buildReviewRepositoryIssueJson(ReviewIssue issue) {
  return {
    'id': issue.id,
    'dimension': issue.dimension.name,
    'severity': issue.severity.name,
    'status': issue.status.name,
    'description': issue.description,
    'originalText': issue.originalText,
    'location': issue.location,
    'suggestion': issue.suggestion,
  };
}

Iterable<Map<String, dynamic>> readReviewRepositoryIssueMaps(Object? value) {
  final rawList = value is List ? value : const [];
  return rawList.whereType<Map<String, dynamic>>();
}

ReviewStatus mapReviewRepositoryTaskStatus(
  String taskStatus, {
  required double? score,
}) {
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

double? readReviewRepositoryDouble(Object? value) {
  return value is num ? value.toDouble() : null;
}

double buildReviewRepositoryAverageScore({
  required double totalScore,
  required int scoredCount,
}) {
  return scoredCount > 0 ? totalScore / scoredCount : 0.0;
}

Map<ReviewDimension, double> buildReviewRepositoryDimensionAverageScores(
  Map<ReviewDimension, List<double>> dimensionScores,
) {
  final averages = <ReviewDimension, double>{};
  for (final entry in dimensionScores.entries) {
    final scores = entry.value;
    averages[entry.key] = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
  }
  return averages;
}
