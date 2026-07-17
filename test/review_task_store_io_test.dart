import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/review_tasks/domain/review_task_models.dart';

void main() {
  // =========================================================================
  // ReviewTask model JSON round-trip
  // =========================================================================

  group('ReviewTask JSON round-trip', () {
    test('toJson and fromJson produce identical task', () {
      final reference = ReviewTaskReference(
        projectId: 'project-1',
        chapterId: 'chapter-1',
        chapterTitle: '第一章',
        sceneId: 'scene-1',
        sceneTitle: '雨夜码头',
      );
      final source = ReviewTaskSource(
        kind: 'scene_review',
        reviewId: 'review-1',
        runId: 'run-1',
        passName: 'judge',
        metadata: {'decision': 'rewriteProse', 'category': 'dialog'},
      );
      final createdAt = DateTime.utc(2026, 3, 15, 10, 30);
      final updatedAt = DateTime.utc(2026, 3, 15, 11, 0);
      final original = ReviewTask(
        id: 'task-abc',
        severity: ReviewTaskSeverity.warning,
        status: ReviewTaskStatus.inProgress,
        title: 'Fix dialog pressure',
        body: '对话缺少压迫感，需要更强的冲突张力。',
        reference: reference,
        source: source,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final json = original.toJson();
      final restored = ReviewTask.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.severity, original.severity);
      expect(restored.status, original.status);
      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(restored.reference.projectId, 'project-1');
      expect(restored.reference.chapterTitle, '第一章');
      expect(restored.reference.sceneTitle, '雨夜码头');
      expect(restored.source.kind, 'scene_review');
      expect(restored.source.runId, 'run-1');
      expect(restored.source.passName, 'judge');
      expect(restored.source.metadata['decision'], 'rewriteProse');
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);
    });

    test('fromJson falls back to defaults for missing fields', () {
      final restored = ReviewTask.fromJson(const {});

      expect(restored.id, '');
      expect(restored.severity, ReviewTaskSeverity.warning);
      expect(restored.status, ReviewTaskStatus.open);
      expect(restored.title, '');
      expect(restored.body, '');
      expect(restored.reference.chapterTitle, '');
      expect(restored.source.kind, '');
    });

    test('copyWith preserves unmodified fields', () {
      final original = ReviewTask(
        id: 'task-1',
        severity: ReviewTaskSeverity.critical,
        status: ReviewTaskStatus.open,
        title: 'Original title',
        body: 'Original body',
        reference: ReviewTaskReference(sceneTitle: 'Scene A'),
        source: ReviewTaskSource(kind: 'test'),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final modified = original.copyWith(
        status: ReviewTaskStatus.resolved,
        title: 'Updated title',
      );

      expect(modified.id, 'task-1');
      expect(modified.status, ReviewTaskStatus.resolved);
      expect(modified.title, 'Updated title');
      expect(modified.body, 'Original body');
      expect(modified.severity, ReviewTaskSeverity.critical);
      expect(modified.reference.sceneTitle, 'Scene A');
    });

    test('ReviewTaskReference round-trips through JSON', () {
      final ref = ReviewTaskReference(
        projectId: 'p1',
        chapterId: 'ch1',
        chapterTitle: '第一章',
        sceneId: 's1',
        sceneTitle: '码头',
      );
      final json = ref.toJson();
      final restored = ReviewTaskReference.fromJson(json);

      expect(restored.projectId, 'p1');
      expect(restored.chapterId, 'ch1');
      expect(restored.chapterTitle, '第一章');
      expect(restored.sceneId, 's1');
      expect(restored.sceneTitle, '码头');
    });

    test('ReviewTaskSource round-trips through JSON with metadata', () {
      final source = ReviewTaskSource(
        kind: 'auto_review',
        reviewId: 'r1',
        runId: 'run-1',
        passName: 'consistency',
        metadata: {'key': 'value'},
      );
      final json = source.toJson();
      final restored = ReviewTaskSource.fromJson(json);

      expect(restored.kind, 'auto_review');
      expect(restored.reviewId, 'r1');
      expect(restored.runId, 'run-1');
      expect(restored.passName, 'consistency');
      expect(restored.metadata['key'], 'value');
    });
  });

  // =========================================================================
  // ReviewTaskStore state management
  // =========================================================================

  group('ReviewTaskStore state management', () {
    test('replaceAll overwrites all tasks', () {
      final store = ReviewTaskStore(
        initialTasks: [
          _task(id: 'task-1'),
          _task(id: 'task-2'),
        ],
      );

      store.replaceAll([_task(id: 'task-3')]);

      expect(store.tasks, hasLength(1));
      expect(store.tasks.single.id, 'task-3');
    });

    test('upsertAll inserts new tasks and preserves existing status', () {
      final store = ReviewTaskStore(
        initialTasks: [_task(id: 'task-1', status: ReviewTaskStatus.resolved)],
      );

      store.upsertAll([
        _task(id: 'task-1', status: ReviewTaskStatus.open),
        _task(id: 'task-2', status: ReviewTaskStatus.open),
      ]);

      expect(store.tasks, hasLength(2));
      final task1 = store.tasks.firstWhere((t) => t.id == 'task-1');
      expect(task1.status, ReviewTaskStatus.resolved);
      expect(store.tasks.any((t) => t.id == 'task-2'), isTrue);
    });

    test('upsertAll is a no-op for empty input', () {
      final store = ReviewTaskStore(initialTasks: [_task(id: 'task-1')]);

      store.upsertAll([]);

      expect(store.tasks, hasLength(1));
    });

    test('updateStatus returns false for unknown task id', () {
      final store = ReviewTaskStore(initialTasks: [_task(id: 'task-1')]);

      final result = store.updateStatus(
        'nonexistent',
        ReviewTaskStatus.resolved,
      );

      expect(result, isFalse);
      expect(store.tasks.first.status, ReviewTaskStatus.open);
    });

    test('updateStatus updates timestamp', () {
      final store = ReviewTaskStore(
        initialTasks: [
          _task(id: 'task-1', createdAt: DateTime.utc(2026, 1, 1)),
        ],
      );
      final newTime = DateTime.utc(2026, 6, 15);

      store.updateStatus(
        'task-1',
        ReviewTaskStatus.inProgress,
        updatedAt: newTime,
      );

      expect(store.tasks.first.status, ReviewTaskStatus.inProgress);
      expect(store.tasks.first.updatedAt, newTime);
    });

    test('openCount counts open and in-progress tasks', () {
      final store = ReviewTaskStore(
        initialTasks: [
          _task(id: 'task-1', status: ReviewTaskStatus.open),
          _task(id: 'task-2', status: ReviewTaskStatus.inProgress),
          _task(id: 'task-3', status: ReviewTaskStatus.resolved),
          _task(id: 'task-4', status: ReviewTaskStatus.ignored),
        ],
      );

      expect(store.openCount, 2);
    });

    test('openCount is zero when no open tasks', () {
      final store = ReviewTaskStore(
        initialTasks: [_task(id: 'task-1', status: ReviewTaskStatus.resolved)],
      );

      expect(store.openCount, 0);
    });

    test('groupedByStatus returns all statuses with correct assignments', () {
      final store = ReviewTaskStore(
        initialTasks: [
          _task(id: 'task-1', status: ReviewTaskStatus.open),
          _task(id: 'task-2', status: ReviewTaskStatus.open),
          _task(id: 'task-3', status: ReviewTaskStatus.resolved),
        ],
      );

      final grouped = store.groupedByStatus();

      expect(grouped[ReviewTaskStatus.open], hasLength(2));
      expect(grouped[ReviewTaskStatus.resolved], hasLength(1));
      expect(grouped[ReviewTaskStatus.inProgress], isEmpty);
      expect(grouped[ReviewTaskStatus.ignored], isEmpty);
    });

    test('tasksForStatus returns filtered list', () {
      final store = ReviewTaskStore(
        initialTasks: [
          _task(id: 'task-1', status: ReviewTaskStatus.resolved),
          _task(id: 'task-2', status: ReviewTaskStatus.open),
          _task(id: 'task-3', status: ReviewTaskStatus.resolved),
        ],
      );

      final resolved = store.tasksForStatus(ReviewTaskStatus.resolved);

      expect(resolved, hasLength(2));
      expect(
        resolved.every((t) => t.status == ReviewTaskStatus.resolved),
        isTrue,
      );
    });
  });

  // =========================================================================
  // ReviewTaskStore export/import round-trip
  // =========================================================================

  group('ReviewTaskStore export/import', () {
    test('exportJson and importJson round-trip preserves all tasks', () {
      final store = ReviewTaskStore(
        initialTasks: [
          _task(id: 'task-1', status: ReviewTaskStatus.open),
          _task(id: 'task-2', status: ReviewTaskStatus.resolved),
        ],
      );

      final exported = store.exportJson();
      final restored = ReviewTaskStore();
      restored.importJson(exported);

      expect(restored.tasks, hasLength(2));
      expect(
        restored.tasks.any(
          (t) => t.id == 'task-1' && t.status == ReviewTaskStatus.open,
        ),
        isTrue,
      );
      expect(
        restored.tasks.any(
          (t) => t.id == 'task-2' && t.status == ReviewTaskStatus.resolved,
        ),
        isTrue,
      );
    });

    test('importJson ignores data without tasks list', () {
      final store = ReviewTaskStore(initialTasks: [_task(id: 'task-1')]);

      store.importJson({
        'items': [
          {'id': 'wrong'},
        ],
      });

      expect(store.tasks, hasLength(1));
      expect(store.tasks.single.id, 'task-1');
    });

    test('fromJson static constructor restores tasks from JSON list', () {
      final store = ReviewTaskStore(
        initialTasks: [
          _task(id: 'task-1'),
          _task(id: 'task-2', severity: ReviewTaskSeverity.critical),
        ],
      );

      final json = store.toJson();
      final restored = ReviewTaskStore.fromJson(json);

      expect(restored.tasks, hasLength(2));
      expect(restored.tasks.first.id, 'task-1');
      expect(restored.tasks.last.severity, ReviewTaskSeverity.critical);
    });
  });
}

ReviewTask _task({
  required String id,
  ReviewTaskStatus status = ReviewTaskStatus.open,
  ReviewTaskSeverity severity = ReviewTaskSeverity.warning,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 1, 2);
  return ReviewTask(
    id: id,
    severity: severity,
    status: status,
    title: 'Fix issue',
    body: '对话需要更自然。',
    reference: ReviewTaskReference(
      chapterId: 'chapter-1',
      chapterTitle: '第一章',
      sceneId: 'scene-1',
      sceneTitle: '雨夜码头',
    ),
    source: ReviewTaskSource(kind: 'test'),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
