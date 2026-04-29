import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_review_models.dart';

import '../domain/review_task_models.dart';

class ReviewMessageInput {
  const ReviewMessageInput({
    required this.title,
    required this.body,
    this.severity,
    this.reference,
    this.source,
  });

  final String title;
  final String body;
  final ReviewTaskSeverity? severity;
  final ReviewTaskReference? reference;
  final ReviewTaskSource? source;
}

class ReviewTaskMapper {
  const ReviewTaskMapper();

  List<ReviewTask> fromSceneReviewResult({
    required SceneReviewResult result,
    required SceneBrief brief,
    DateTime? timestamp,
    String reviewId = '',
    String runId = '',
  }) {
    final createdAt = timestamp ?? DateTime.now();
    final reference = ReviewTaskReference(
      projectId: brief.projectId,
      chapterId: brief.chapterId,
      chapterTitle: brief.chapterTitle,
      sceneId: brief.sceneId,
      sceneTitle: brief.sceneTitle,
    );
    final passes = <_ReviewPassIssue>[
      _ReviewPassIssue('judge', result.judge),
      _ReviewPassIssue('consistency', result.consistency),
      if (result.readerFlow != null)
        _ReviewPassIssue('readerFlow', result.readerFlow!),
      if (result.lexicon != null) _ReviewPassIssue('lexicon', result.lexicon!),
    ];

    return [
      for (final pass in passes)
        if (pass.result.status != SceneReviewStatus.pass &&
            pass.result.reason.trim().isNotEmpty)
          ReviewTask(
            id: _stableId([
              'scene-review',
              brief.projectId ?? '',
              brief.chapterId,
              brief.sceneId,
              reviewId,
              runId,
              pass.name,
              pass.result.status.name,
              pass.result.reason,
            ]),
            severity: _severityFromStatus(pass.result.status),
            status: ReviewTaskStatus.open,
            title: _titleForPass(pass.name, pass.result.status),
            body: pass.result.reason.trim(),
            reference: reference,
            source: ReviewTaskSource(
              kind: 'scene_review',
              reviewId: reviewId,
              runId: runId,
              passName: pass.name,
              metadata: {
                'decision': result.decision.name,
                'reviewStatus': pass.result.status.name,
                if (pass.result.categories.isNotEmpty)
                  'categories': [
                    for (final category in pass.result.categories)
                      category.name,
                  ],
              },
            ),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
    ];
  }

  List<ReviewTask> fromReviewMessages({
    required Iterable<ReviewMessageInput> messages,
    DateTime? timestamp,
    String sourceKind = 'review_message',
  }) {
    final createdAt = timestamp ?? DateTime.now();
    final tasks = <ReviewTask>[];
    var index = 0;
    for (final message in messages) {
      final lines = _messageLines(message.body);
      for (final line in lines) {
        final title = message.title.trim().isEmpty
            ? 'Review issue'
            : message.title.trim();
        tasks.add(
          ReviewTask(
            id: _stableId([
              sourceKind,
              message.source?.runId ?? '',
              message.source?.reviewId ?? '',
              message.source?.passName ?? '',
              message.reference?.chapterId ?? '',
              message.reference?.sceneId ?? '',
              '$index',
              title,
              line,
            ]),
            severity: message.severity ?? _severityFromText('$title\n$line'),
            status: ReviewTaskStatus.open,
            title: title,
            body: line,
            reference: message.reference ?? ReviewTaskReference(),
            source:
                message.source ??
                ReviewTaskSource(kind: sourceKind, passName: title),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
        index++;
      }
    }
    return tasks;
  }

  ReviewTaskSeverity _severityFromStatus(SceneReviewStatus status) {
    return switch (status) {
      SceneReviewStatus.pass => ReviewTaskSeverity.info,
      SceneReviewStatus.rewriteProse => ReviewTaskSeverity.warning,
      SceneReviewStatus.replanScene => ReviewTaskSeverity.critical,
    };
  }

  ReviewTaskSeverity _severityFromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('replan') ||
        lower.contains('critical') ||
        lower.contains('阻塞') ||
        lower.contains('矛盾')) {
      return ReviewTaskSeverity.critical;
    }
    if (lower.contains('pass') || lower.contains('通过')) {
      return ReviewTaskSeverity.info;
    }
    return ReviewTaskSeverity.warning;
  }

  String _titleForPass(String passName, SceneReviewStatus status) {
    final label = switch (passName) {
      'judge' => 'Fix scene judgment issue',
      'consistency' => 'Fix continuity issue',
      'readerFlow' => 'Fix reader-flow issue',
      'lexicon' => 'Fix wording issue',
      _ => 'Fix review issue',
    };
    return status == SceneReviewStatus.replanScene
        ? '$label before drafting'
        : label;
  }

  List<String> _messageLines(String body) {
    return body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^[-*]\s+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  String _stableId(List<String> parts) {
    final normalized = parts.map((part) => part.trim()).join('|');
    var hash = 0x811c9dc5;
    for (final codeUnit in normalized.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'review-task-${hash.toRadixString(16).padLeft(8, '0')}';
  }
}

class _ReviewPassIssue {
  const _ReviewPassIssue(this.name, this.result);

  final String name;
  final SceneReviewPassResult result;
}
