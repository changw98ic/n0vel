import '../../../features/editor/data/chapter_repository.dart';
import '../../workflow/data/workflow_execution_service.dart';
import '../../workflow/data/workflow_repository.dart';
import '../../workflow/domain/workflow_models.dart';
import '../domain/review_result.dart';
import 'review_repository.dart';

class ReviewWorkflowRunner {
  final ReviewRepository _reviewRepository;
  final WorkflowRepository _workflowRepository;
  final WorkflowExecutionService _workflowExecutionService;
  final ChapterRepository _chapterRepository;

  ReviewWorkflowRunner({
    required ReviewRepository reviewRepository,
    required WorkflowRepository workflowRepository,
    required WorkflowExecutionService workflowExecutionService,
    required ChapterRepository chapterRepository,
  }) : _reviewRepository = reviewRepository,
       _workflowRepository = workflowRepository,
       _workflowExecutionService = workflowExecutionService,
       _chapterRepository = chapterRepository;

  Future<String> start({
    required String workId,
    required String scope,
    required List<String> dimensionNames,
    String? chapterId,
    String? volumeId,
  }) async {
    final chapterIds = await _resolveChapterIds(
      workId: workId,
      scope: scope,
      chapterId: chapterId,
      volumeId: volumeId,
    );
    if (chapterIds.isEmpty) {
      throw StateError('No chapters available for review');
    }

    final dimensions = _parseDimensions(dimensionNames);
    final taskId = await _reviewRepository.createReviewTask(
      workId: workId,
      chapterIds: chapterIds,
      dimensions: dimensions,
    );

    await _workflowExecutionService.executeTask(taskId);
    return taskId;
  }

  Future<WorkflowTaskSummary?> getStatus(String taskId) {
    return _workflowRepository.getTaskById(taskId);
  }

  Future<List<String>> _resolveChapterIds({
    required String workId,
    required String scope,
    String? chapterId,
    String? volumeId,
  }) async {
    if (scope == 'chapter' && chapterId != null && chapterId.isNotEmpty) {
      final chapter = await _chapterRepository.getChapterById(chapterId);
      return chapter == null ? const <String>[] : <String>[chapter.id];
    }

    final chapters = await _chapterRepository.getChaptersByWorkId(workId);
    if (scope == 'volume' && volumeId != null && volumeId.isNotEmpty) {
      return chapters
          .where((chapter) => chapter.volumeId == volumeId)
          .map((chapter) => chapter.id)
          .toList();
    }

    return chapters.map((chapter) => chapter.id).toList();
  }

  List<ReviewDimension> _parseDimensions(List<String> rawNames) {
    if (rawNames.isEmpty) {
      return ReviewDimension.values;
    }

    final parsed = rawNames
        .map(_normalizeDimensionName)
        .map(
          (name) => ReviewDimension.values.firstWhere(
            (dimension) => _normalizeDimensionName(dimension.name) == name,
            orElse: () => ReviewDimension.consistency,
          ),
        )
        .toSet()
        .toList();

    return parsed.isEmpty ? ReviewDimension.values : parsed;
  }

  String _normalizeDimensionName(String value) {
    return value.toLowerCase().replaceAll('_', '');
  }
}
