import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';
import 'package:writing_assistant/features/editor/domain/chapter.dart'
    as chapter_domain;
import 'package:writing_assistant/features/review/data/review_repository.dart';
import 'package:writing_assistant/features/review/data/review_workflow_runner.dart';
import 'package:writing_assistant/features/review/domain/review_result.dart';
import 'package:writing_assistant/features/workflow/data/workflow_execution_service.dart';
import 'package:writing_assistant/features/workflow/data/workflow_repository.dart';
import 'package:writing_assistant/features/workflow/domain/workflow_models.dart';

class MockReviewRepository extends Mock implements ReviewRepository {}

class MockWorkflowRepository extends Mock implements WorkflowRepository {}

class MockWorkflowExecutionService extends Mock
    implements WorkflowExecutionService {}

class MockChapterRepository extends Mock implements ChapterRepository {}

void main() {
  late ReviewWorkflowRunner runner;
  late MockReviewRepository reviewRepository;
  late MockWorkflowRepository workflowRepository;
  late MockWorkflowExecutionService workflowExecutionService;
  late MockChapterRepository chapterRepository;

  setUp(() {
    reviewRepository = MockReviewRepository();
    workflowRepository = MockWorkflowRepository();
    workflowExecutionService = MockWorkflowExecutionService();
    chapterRepository = MockChapterRepository();

    runner = ReviewWorkflowRunner(
      reviewRepository: reviewRepository,
      workflowRepository: workflowRepository,
      workflowExecutionService: workflowExecutionService,
      chapterRepository: chapterRepository,
    );
  });

  group('ReviewWorkflowRunner', () {
    test('start resolves chapters and runs workflow task', () async {
      when(() => chapterRepository.getChaptersByWorkId('work-1')).thenAnswer(
        (_) async => [
          chapter_domain.Chapter(
            id: 'c1',
            volumeId: 'v1',
            workId: 'work-1',
            title: 'Chapter 1',
            sortOrder: 0,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ],
      );
      when(
        () => reviewRepository.createReviewTask(
          workId: any(named: 'workId'),
          chapterIds: any(named: 'chapterIds'),
          dimensions: any(named: 'dimensions'),
        ),
      ).thenAnswer((_) async => 'task-1');
      when(
        () => workflowExecutionService.executeTask('task-1'),
      ).thenAnswer((_) async {});

      final taskId = await runner.start(
        workId: 'work-1',
        scope: 'all',
        dimensionNames: const ['consistency', 'characterOOC'],
      );

      expect(taskId, 'task-1');
      verify(
        () => reviewRepository.createReviewTask(
          workId: 'work-1',
          chapterIds: ['c1'],
          dimensions: [
            ReviewDimension.consistency,
            ReviewDimension.characterOoc,
          ],
        ),
      ).called(1);
      verify(() => workflowExecutionService.executeTask('task-1')).called(1);
    });

    test('getStatus delegates to workflow repository', () async {
      final summary = WorkflowTaskSummary(
        id: 'task-1',
        workId: 'work-1',
        name: 'Review',
        type: 'review',
        status: WorkflowTaskStatus.running,
        progress: 0.4,
        currentNodeIndex: 1,
        inputTokens: 0,
        outputTokens: 0,
        errorMessage: null,
        startedAt: null,
        completedAt: null,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      when(() => workflowRepository.getTaskById('task-1')).thenAnswer(
        (_) async => summary,
      );

      final result = await runner.getStatus('task-1');

      expect(result, same(summary));
    });
  });
}
