import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_mapper.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/review_tasks/domain/review_task_models.dart';
import 'package:novel_writer/features/review_tasks/presentation/review_task_panel.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';

void main() {
  group('ReviewTaskMapper', () {
    test('creates actionable tasks from failed scene review passes', () {
      final tasks = const ReviewTaskMapper().fromSceneReviewResult(
        result: const SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.rewriteProse,
            reason: '对话缺少压迫感。',
            rawText: '',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.replanScene,
            reason: '角色动机与前文矛盾。',
            rawText: '',
          ),
          decision: SceneReviewDecision.replanScene,
        ),
        brief: SceneBrief(
          projectId: 'project-1',
          chapterId: 'chapter-1',
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '雨夜码头',
          sceneSummary: '柳溪逼问岳刃。',
        ),
        timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
        reviewId: 'review-1',
        runId: 'run-1',
      );

      expect(tasks, hasLength(2));
      expect(tasks.first.status, ReviewTaskStatus.open);
      expect(tasks.first.severity, ReviewTaskSeverity.warning);
      expect(tasks.first.reference.sceneTitle, '雨夜码头');
      expect(tasks.first.source.kind, 'scene_review');
      expect(tasks.first.source.runId, 'run-1');
      expect(tasks.last.severity, ReviewTaskSeverity.critical);
      expect(tasks.last.body, '角色动机与前文矛盾。');
    });

    test('does not create tasks for passing scene review passes', () {
      final tasks = const ReviewTaskMapper().fromSceneReviewResult(
        result: const SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '冲突成立。',
            rawText: '',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '连续性成立。',
            rawText: '',
          ),
          decision: SceneReviewDecision.pass,
        ),
        brief: SceneBrief(
          chapterId: 'chapter-1',
          chapterTitle: '第一章',
          sceneId: 'scene-1',
          sceneTitle: '雨夜码头',
          sceneSummary: '柳溪逼问岳刃。',
        ),
      );

      expect(tasks, isEmpty);
    });

    test('splits comparable review messages into independent tasks', () {
      final tasks = const ReviewTaskMapper().fromReviewMessages(
        messages: [
          ReviewMessageInput(
            title: '审查结果',
            body: '- 角色动机与前文矛盾。\n- 对话需要更自然。',
            source: ReviewTaskSource(kind: 'run_message', runId: 'run-2'),
          ),
        ],
        timestamp: DateTime.utc(2026, 1, 2),
      );

      expect(tasks, hasLength(2));
      expect(tasks.first.body, '角色动机与前文矛盾。');
      expect(tasks.first.severity, ReviewTaskSeverity.critical);
      expect(tasks.last.body, '对话需要更自然。');
    });
  });

  group('ReviewTaskStore', () {
    test('updates status and preserves timestamps on upsert', () {
      final createdAt = DateTime.utc(2026, 1, 2);
      final incoming = _task(
        id: 'task-1',
        status: ReviewTaskStatus.open,
        createdAt: createdAt,
      );
      final store = ReviewTaskStore(initialTasks: [incoming]);

      final updated = store.updateStatus(
        'task-1',
        ReviewTaskStatus.resolved,
        updatedAt: DateTime.utc(2026, 1, 3),
      );
      store.upsertAll([
        _task(
          id: 'task-1',
          status: ReviewTaskStatus.open,
          createdAt: DateTime.utc(2026, 1, 4),
        ),
      ]);

      expect(updated, isTrue);
      expect(store.tasks.single.status, ReviewTaskStatus.resolved);
      expect(store.tasks.single.createdAt, createdAt);
    });

    test('round trips through json', () {
      final store = ReviewTaskStore(initialTasks: [_task(id: 'task-1')]);
      final restored = ReviewTaskStore.fromJson(store.toJson());

      expect(restored.tasks.single.id, 'task-1');
      expect(restored.tasks.single.status, ReviewTaskStatus.open);
    });
  });

  group('ReviewTaskPanel', () {
    testWidgets('groups tasks and changes status from the menu', (
      tester,
    ) async {
      final store = ReviewTaskStore(
        initialTasks: [
          _task(id: 'task-1', status: ReviewTaskStatus.open),
          _task(id: 'task-2', status: ReviewTaskStatus.resolved),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(height: 500, child: ReviewTaskPanel(store: store)),
          ),
        ),
      );

      expect(find.text('Open (1)'), findsOneWidget);
      expect(find.text('Resolved (1)'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<ReviewTaskStatus>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('In progress').last);
      await tester.pumpAndSettle();

      expect(store.tasks.first.status, ReviewTaskStatus.inProgress);
      expect(find.text('In progress (1)'), findsOneWidget);
    });
  });
}

ReviewTask _task({
  required String id,
  ReviewTaskStatus status = ReviewTaskStatus.open,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 1, 2);
  return ReviewTask(
    id: id,
    severity: ReviewTaskSeverity.warning,
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
