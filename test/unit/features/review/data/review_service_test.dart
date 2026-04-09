import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';
import 'package:writing_assistant/features/editor/domain/chapter.dart' as chapter_domain;
import 'package:writing_assistant/features/review/data/review_repository.dart';
import 'package:writing_assistant/features/review/data/review_service.dart';
import 'package:writing_assistant/features/review/domain/review_result.dart';
import 'package:writing_assistant/features/workflow/data/workflow_execution_service.dart';
import 'package:writing_assistant/features/workflow/data/workflow_repository.dart';

class MockAIService extends Mock implements AIService {}

class MockReviewRepository extends Mock implements ReviewRepository {}

class MockWorkflowRepository extends Mock implements WorkflowRepository {}

class MockWorkflowExecutionService extends Mock
    implements WorkflowExecutionService {}

class MockChapterRepository extends Mock implements ChapterRepository {}

void main() {
  late ReviewService service;
  late MockAIService aiService;
  late MockReviewRepository reviewRepository;
  late MockWorkflowRepository workflowRepository;
  late MockWorkflowExecutionService workflowExecutionService;
  late MockChapterRepository chapterRepository;

  setUp(() {
    aiService = MockAIService();
    reviewRepository = MockReviewRepository();
    workflowRepository = MockWorkflowRepository();
    workflowExecutionService = MockWorkflowExecutionService();
    chapterRepository = MockChapterRepository();

    service = ReviewService(
      aiService,
      reviewRepository,
      workflowRepository: workflowRepository,
      workflowExecutionService: workflowExecutionService,
      chapterRepository: chapterRepository,
    );
  });

  group('ReviewService workflow integration', () {
    test('startReviewWorkflow resolves chapters and runs task', () async {
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

      final taskId = await service.startReviewWorkflow(
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

  });
}
