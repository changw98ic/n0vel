import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'review_result.dart' show ReviewDimension;

part 'review_report.freezed.dart';
part 'review_report.g.dart';

/// 问题严重程度
enum IssueSeverity {
  critical('严重', Colors.red),
  major('中等', Colors.orange),
  minor('轻微', Colors.yellow);

  const IssueSeverity(this.label, this.color);
  final String label;
  // Note: color is just for reference, actual Color object will be created in UI
  final dynamic color;
}

/// 问题状态
enum IssueStatus {
  pending('待处理'),
  ignored('已忽略'),
  fixed('已修复'),
  falsePositive('误报');

  const IssueStatus(this.label);
  final String label;
}

/// 审查报告
@freezed
class ReviewReport with _$ReviewReport {
  const ReviewReport._();

  const factory ReviewReport({
    required String id,
    required String chapterId,
    required DateTime createdAt,
    @Default(0) double overallScore,
    required Map<String, double> dimensionScores,
    required List<ReviewIssue> issues,
    @Default(0) int criticalCount,
    @Default(0) int majorCount,
    @Default(0) int minorCount,
  }) = _ReviewReport;

  factory ReviewReport.fromJson(Map<String, dynamic> json) =>
      _$ReviewReportFromJson(json);

  /// 获取指定维度的问题
  List<ReviewIssue> getIssuesByDimension(ReviewDimension dimension) {
    return issues.where((i) => i.dimension == dimension).toList();
  }

  /// 获取待处理问题
  List<ReviewIssue> get pendingIssues =>
      issues.where((i) => i.status == IssueStatus.pending).toList();

  /// 获取评分等级
  String get scoreGrade {
    if (overallScore >= 90) return '优秀';
    if (overallScore >= 80) return '良好';
    if (overallScore >= 70) return '合格';
    if (overallScore >= 60) return '待改进';
    return '需重写';
  }
}

/// 审查问题
@freezed
class ReviewIssue with _$ReviewIssue {
  const ReviewIssue._();

  const factory ReviewIssue({
    required String id,
    required String reportId,
    required ReviewDimension dimension,
    required IssueSeverity severity,
    @Default(IssueStatus.pending) IssueStatus status,
    required String description,
    String? originalText,
    String? location,
    int? startOffset,
    int? endOffset,
    String? suggestion,
    String? relatedCharacterId,
    String? relatedSettingId,
    DateTime? fixedAt,
    String? fixedBy,
  }) = _ReviewIssue;

  factory ReviewIssue.fromJson(Map<String, dynamic> json) =>
      _$ReviewIssueFromJson(json);
}

/// 审查配置
@freezed
class ReviewConfig with _$ReviewConfig {
  const factory ReviewConfig({
    @Default(true) bool autoReview,
    @Default({}) Map<String, int> dimensionStrictness, // 0-100
    @Default(false) bool checkAiStyle,
    @Default(false) bool checkPerspective,
    @Default(false) bool checkPacing,
    required String aiModelId,
  }) = _ReviewConfig;

  factory ReviewConfig.fromJson(Map<String, dynamic> json) =>
      _$ReviewConfigFromJson(json);
}
