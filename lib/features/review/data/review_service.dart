import 'dart:async';
import 'dart:convert';

import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/models/model_tier.dart' show AIFunction;
import '../domain/review_report.dart';
import '../domain/review_result.dart';
import 'review_repository.dart';

class ReviewService {
  final AIService _aiService;
  final ReviewRepository _repository;

  ReviewService(this._aiService, this._repository);

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

  Future<ReviewStatistics> getReviewStatistics(String workId) {
    return _repository.getReviewStatistics(workId);
  }

  Future<List<ReviewResult>> getReviewResults(String workId) {
    return _repository.getReviewResults(workId);
  }

  Future<ReviewReport?> getReviewReport(String chapterId) {
    return _repository.getReviewReport(chapterId);
  }

  Future<void> updateIssueStatus(String issueId, IssueStatus status, {String? fixedBy}) {
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

}
