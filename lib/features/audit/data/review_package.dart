// ============================================================================
// Review Package Export
// ============================================================================
//
// Stable, shareable review package format for M8-05. This module is export-only:
// import/merge support belongs to a later task.

import 'dart:convert';

import '../../../app/state/workspace_types.dart';
import '../../review_tasks/domain/review_task_models.dart';

const int reviewPackageSchemaVersion = 1;
const String reviewPackageKind = 'n0vel.reviewPackage';

class ReviewPackageMetadata {
  const ReviewPackageMetadata({
    required this.packageId,
    required this.projectId,
    required this.projectTitle,
    required this.exportedAt,
    this.sourceBranch,
    this.sourceCommit,
    this.appVersion,
  });

  final String packageId;
  final String projectId;
  final String projectTitle;
  final DateTime exportedAt;
  final String? sourceBranch;
  final String? sourceCommit;
  final String? appVersion;

  Map<String, Object?> toJson() {
    return {
      'packageId': packageId,
      'projectId': projectId,
      'projectTitle': projectTitle,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      if (sourceBranch != null) 'sourceBranch': sourceBranch,
      if (sourceCommit != null) 'sourceCommit': sourceCommit,
      if (appVersion != null) 'appVersion': appVersion,
    };
  }
}

class ReviewPackageSource {
  const ReviewPackageSource({
    required this.kind,
    this.reviewId = '',
    this.runId = '',
    this.passName = '',
    this.reference = const {},
    this.metadata = const {},
  });

  final String kind;
  final String reviewId;
  final String runId;
  final String passName;
  final Map<String, Object?> reference;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      if (reviewId.isNotEmpty) 'reviewId': reviewId,
      if (runId.isNotEmpty) 'runId': runId,
      if (passName.isNotEmpty) 'passName': passName,
      if (reference.isNotEmpty) 'reference': reference,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class ReviewPackageIssue {
  const ReviewPackageIssue({
    required this.id,
    required this.title,
    required this.evidence,
    required this.target,
    required this.status,
    required this.lastAction,
    required this.ignoreReason,
    required this.source,
  });

  final String id;
  final String title;
  final String evidence;
  final String target;
  final String status;
  final String lastAction;
  final String ignoreReason;
  final ReviewPackageSource source;

  bool get isOpen => status == AuditIssueStatus.open.name;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'evidence': evidence,
      'target': target,
      'status': status,
      if (lastAction.isNotEmpty) 'lastAction': lastAction,
      if (ignoreReason.isNotEmpty) 'ignoreReason': ignoreReason,
      'source': source.toJson(),
    };
  }
}

class ReviewPackageSuggestion {
  const ReviewPackageSuggestion({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.status,
    required this.reference,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String severity;
  final String status;
  final Map<String, Object?> reference;
  final ReviewPackageSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen =>
      status == ReviewTaskStatus.open.name ||
      status == ReviewTaskStatus.inProgress.name;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'severity': severity,
      'status': status,
      'reference': reference,
      'source': source.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class ReviewPackageSummary {
  const ReviewPackageSummary({
    required this.issueCount,
    required this.suggestionCount,
    required this.openCount,
  });

  final int issueCount;
  final int suggestionCount;
  final int openCount;

  Map<String, Object?> toJson() {
    return {
      'issueCount': issueCount,
      'suggestionCount': suggestionCount,
      'openCount': openCount,
    };
  }
}

class ReviewPackage {
  const ReviewPackage({
    required this.schemaVersion,
    required this.kind,
    required this.metadata,
    required this.summary,
    required this.issues,
    required this.suggestions,
  });

  final int schemaVersion;
  final String kind;
  final ReviewPackageMetadata metadata;
  final ReviewPackageSummary summary;
  final List<ReviewPackageIssue> issues;
  final List<ReviewPackageSuggestion> suggestions;

  Map<String, Object?> get format => const {
    'description':
        'Review package export for sharing audit issues and review suggestions.',
    'compatibility': 'export-only',
    'issueSource': 'workspace audit issue',
    'suggestionSource': 'review task',
  };

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'kind': kind,
      'format': format,
      'metadata': metadata.toJson(),
      'summary': summary.toJson(),
      'issues': [for (final issue in issues) issue.toJson()],
      'suggestions': [
        for (final suggestion in suggestions) suggestion.toJson(),
      ],
    };
  }

  String toShareableJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class ReviewPackageExporter {
  const ReviewPackageExporter();

  ReviewPackage exportPackage({
    required ReviewPackageMetadata metadata,
    Iterable<AuditIssueRecord> auditIssues = const [],
    Iterable<ReviewTask> reviewTasks = const [],
  }) {
    final issues = auditIssues.map(_issueFromAuditRecord).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final suggestions = reviewTasks.map(_suggestionFromReviewTask).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final openCount =
        issues.where((issue) => issue.isOpen).length +
        suggestions.where((suggestion) => suggestion.isOpen).length;

    return ReviewPackage(
      schemaVersion: reviewPackageSchemaVersion,
      kind: reviewPackageKind,
      metadata: metadata,
      summary: ReviewPackageSummary(
        issueCount: issues.length,
        suggestionCount: suggestions.length,
        openCount: openCount,
      ),
      issues: List.unmodifiable(issues),
      suggestions: List.unmodifiable(suggestions),
    );
  }

  ReviewPackageIssue _issueFromAuditRecord(AuditIssueRecord issue) {
    return ReviewPackageIssue(
      id: issue.id,
      title: issue.title,
      evidence: issue.evidence,
      target: issue.target,
      status: issue.status.name,
      lastAction: issue.lastAction,
      ignoreReason: issue.ignoreReason,
      source: ReviewPackageSource(
        kind: 'audit_issue',
        reference: {'target': issue.target},
      ),
    );
  }

  ReviewPackageSuggestion _suggestionFromReviewTask(ReviewTask task) {
    return ReviewPackageSuggestion(
      id: task.id,
      title: task.title,
      body: task.body,
      severity: task.severity.name,
      status: task.status.name,
      reference: task.reference.toJson(),
      source: ReviewPackageSource(
        kind: task.source.kind.isEmpty ? 'review_task' : task.source.kind,
        reviewId: task.source.reviewId,
        runId: task.source.runId,
        passName: task.source.passName,
        reference: task.reference.toJson(),
        metadata: task.source.metadata,
      ),
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );
  }
}
