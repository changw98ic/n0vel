import 'dart:async';
import 'dart:convert';

import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/models/model_tier.dart' show AIFunction;
import '../../../features/editor/data/chapter_repository.dart';
import '../../workflow/data/workflow_execution_service.dart';
import '../../workflow/data/workflow_repository.dart';
import '../../workflow/domain/workflow_models.dart';
import '../domain/review_report.dart';
import '../domain/review_result.dart';
import 'review_repository.dart';

class ReviewService {
  final AIService _aiService;
  final ReviewRepository _repository;
  final WorkflowRepository? _workflowRepository;
  final WorkflowExecutionService? _workflowExecutionService;
  final ChapterRepository? _chapterRepository;

  ReviewService(
    this._aiService,
    this._repository, {
    WorkflowRepository? workflowRepository,
    WorkflowExecutionService? workflowExecutionService,
    ChapterRepository? chapterRepository,
  }) : _workflowRepository = workflowRepository,
       _workflowExecutionService = workflowExecutionService,
       _chapterRepository = chapterRepository;

  Future<ReviewReport> reviewChapter(
    String chapterId, {
    List<ReviewDimension>? dimensions,
    void Function(double progress)? onProgress,
  }) async {
    final systemPrompt = _buildSystemPrompt(dimensions);
    final userPrompt = _buildUserPrompt(
      chapterContent: '',
      relatedSettings: const [],
      characters: const [],
    );

    onProgress?.call(0.3);

    final response = await _aiService.generate(
      prompt: '$systemPrompt\n\n$userPrompt',
      config: AIRequestConfig(
        function: AIFunction.review,
        userPrompt: '$systemPrompt\n\n$userPrompt',
        stream: false,
      ),
    );

    onProgress?.call(0.8);

    final report = _parseResponse(chapterId, response.content);
    await _repository.saveReviewReport(report);

    onProgress?.call(1.0);
    return report;
  }

  Future<List<ReviewReport>> reviewChapters(
    List<String> chapterIds, {
    List<ReviewDimension>? dimensions,
    void Function(int current, int total)? onProgress,
  }) async {
    final reports = <ReviewReport>[];

    for (var i = 0; i < chapterIds.length; i++) {
      final report = await reviewChapter(
        chapterIds[i],
        dimensions: dimensions,
      );
      reports.add(report);
      onProgress?.call(i + 1, chapterIds.length);
    }

    return reports;
  }

  Future<String> startReviewWorkflow({
    required String workId,
    required String scope,
    required List<String> dimensionNames,
    String? chapterId,
    String? volumeId,
  }) async {
    _ensureWorkflowSupport();
    final workflowExecutionService = _workflowExecutionService!;

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
    final taskId = await _repository.createReviewTask(
      workId: workId,
      chapterIds: chapterIds,
      dimensions: dimensions,
    );

    await workflowExecutionService.executeTask(taskId);
    return taskId;
  }

  Future<WorkflowTaskSummary?> getWorkflowStatus(String taskId) async {
    _ensureWorkflowSupport();
    final workflowRepository = _workflowRepository!;
    return workflowRepository.getTaskById(taskId);
  }

  Future<ReviewStatistics> getReviewStatistics(String workId) {
    return _repository.getReviewStatistics(workId);
  }

  Future<List<ReviewResult>> getReviewResults(String workId) {
    return _repository.getReviewResults(workId);
  }

  Future<ReviewReport?> getReviewReport(String chapterId) {
    return _repository.getReviewReport(chapterId);
  }

  Future<void> updateIssueStatus(
    String issueId,
    IssueStatus status, {
    String? fixedBy,
  }) {
    return _repository.updateIssueStatus(
      issueId,
      status,
      fixedBy: fixedBy,
    );
  }

  String _buildSystemPrompt(List<ReviewDimension>? dimensions) {
    final dims = dimensions ?? ReviewDimension.values;
    final dimLines = dims.map((d) => '- ${d.label}').join('\n');

    return '''
浣犳槸涓€浣嶄笓涓氱殑灏忚缂栬緫锛岃浠庝互涓嬬淮搴﹀鏌ョ珷鑺傚唴瀹癸細

$dimLines

璇蜂互 JSON 鏍煎紡杩斿洖瀹℃煡缁撴灉锛屾牸寮忓涓嬶細
{
  "overallScore": 0,
  "dimensionScores": {
    "consistency": 0
  },
  "issues": [
    {
      "dimension": "consistency",
      "severity": "critical",
      "description": "闂鎻忚堪",
      "originalText": "鍘熸枃鐗囨",
      "location": "浣嶇疆鎻忚堪",
      "suggestion": "淇敼寤鸿"
    }
  ]
}
''';
  }

  String _buildUserPrompt({
    required String chapterContent,
    required List<dynamic> relatedSettings,
    required List<dynamic> characters,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('璇峰鏌ヤ互涓嬬珷鑺傚唴瀹癸細');
    buffer.writeln();

    if (characters.isNotEmpty) {
      buffer.writeln('## 鐩稿叧瑙掕壊璁惧畾');
      for (final character in characters) {
        buffer.writeln('- ${character.name}: ${character.bio ?? ""}');
      }
      buffer.writeln();
    }

    if (relatedSettings.isNotEmpty) {
      buffer.writeln('## 鐩稿叧璁惧畾');
      for (final setting in relatedSettings) {
        buffer.writeln('- ${setting.name}: ${setting.description ?? ""}');
      }
      buffer.writeln();
    }

    buffer.writeln('## 绔犺妭鍐呭');
    buffer.writeln(chapterContent);

    return buffer.toString();
  }

  ReviewReport _parseResponse(String chapterId, String response) {
    try {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (match != null) {
        final decoded = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        final overallScore =
            (decoded['overallScore'] as num?)?.toDouble() ?? 0;
        final rawDimensionScores =
            decoded['dimensionScores'] as Map<String, dynamic>? ?? const {};
        final dimensionScores = rawDimensionScores.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );

        final rawIssues = decoded['issues'] as List<dynamic>? ?? const [];
        final issues = rawIssues
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => ReviewIssue(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                reportId: '',
                dimension: ReviewDimension.values.firstWhere(
                  (value) => value.name == item['dimension'],
                  orElse: () => ReviewDimension.consistency,
                ),
                severity: IssueSeverity.values.firstWhere(
                  (value) => value.name == item['severity'],
                  orElse: () => IssueSeverity.minor,
                ),
                description: item['description'] as String? ?? '鏈彁渚涙弿杩?',
                originalText: item['originalText'] as String?,
                location: item['location'] as String?,
                suggestion: item['suggestion'] as String?,
              ),
            )
            .toList();

        return ReviewReport(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chapterId: chapterId,
          createdAt: DateTime.now(),
          overallScore: overallScore,
          dimensionScores: dimensionScores,
          issues: issues,
          criticalCount:
              issues.where((issue) => issue.severity == IssueSeverity.critical).length,
          majorCount:
              issues.where((issue) => issue.severity == IssueSeverity.major).length,
          minorCount:
              issues.where((issue) => issue.severity == IssueSeverity.minor).length,
        );
      }
    } catch (_) {}

    return ReviewReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chapterId: chapterId,
      createdAt: DateTime.now(),
      overallScore: 0,
      dimensionScores: const {},
      issues: const [],
      criticalCount: 0,
      majorCount: 0,
      minorCount: 0,
    );
  }

  Future<List<String>> _resolveChapterIds({
    required String workId,
    required String scope,
    String? chapterId,
    String? volumeId,
  }) async {
    final chapterRepository = _chapterRepository;
    if (chapterRepository == null) {
      throw StateError('ChapterRepository is not available');
    }

    if (scope == 'chapter' && chapterId != null && chapterId.isNotEmpty) {
      final chapter = await chapterRepository.getChapterById(chapterId);
      return chapter == null ? const <String>[] : <String>[chapter.id];
    }

    final chapters = await chapterRepository.getChaptersByWorkId(workId);
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

  void _ensureWorkflowSupport() {
    if (_workflowRepository == null ||
        _workflowExecutionService == null ||
        _chapterRepository == null) {
      throw StateError('Workflow review support is not configured');
    }
  }
}
