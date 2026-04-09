import 'package:freezed_annotation/freezed_annotation.dart';

part 'detection_result.freezed.dart';
part 'detection_result.g.dart';

/// AI 检测类型
enum DetectionType {
  forbiddenPattern('禁止句式'),
  punctuationAbuse('标点滥用'),
  aiVocabulary('AI常用词'),
  perspectiveIssue('视角问题'),
  pacingIssue('节奏问题'),
  standardizedOutput('标准化输出');

  const DetectionType(this.label);
  final String label;
}

/// 禁止句式
@freezed
class ForbiddenPattern with _$ForbiddenPattern {
  const factory ForbiddenPattern({
    required String id,
    required String pattern,
    required String description,
    @Default([]) List<String> examples,
    @Default(true) bool isEnabled,
  }) = _ForbiddenPattern;

  factory ForbiddenPattern.fromJson(Map<String, dynamic> json) =>
      _$ForbiddenPatternFromJson(json);
}

/// 默认禁止句式
class DefaultForbiddenPatterns {
  static List<ForbiddenPattern> get all => [
        ForbiddenPattern(
          id: 'is_rather_than',
          pattern: r'是.*而不是.*',
          description: '避免"是...而不是..."句式',
          examples: ['这是勇气而不是鲁莽', '这是智慧而不是狡诈'],
        ),
        ForbiddenPattern(
          id: 'not_only_but_also',
          pattern: r'不仅.*而且.*',
          description: '避免"不仅...而且..."句式',
          examples: ['不仅聪明而且勤奋'],
        ),
        ForbiddenPattern(
          id: 'on_one_hand',
          pattern: r'一方面.*另一方面.*',
          description: '避免"一方面...另一方面..."句式',
          examples: ['一方面想要前进，另一方面又害怕失败'],
        ),
        ForbiddenPattern(
          id: 'first_second_last',
          pattern: r'首先.*其次.*最后.*',
          description: '避免"首先...其次...最后..."句式',
          examples: ['首先分析问题，其次制定方案，最后执行'],
        ),
        ForbiddenPattern(
          id: 'worth_noting',
          pattern: r'值得注意的是',
          description: '避免"值得注意的是..."开头',
          examples: ['值得注意的是，这个决定并不容易'],
        ),
        ForbiddenPattern(
          id: 'have_to_admit',
          pattern: r'不得不承认',
          description: '避免"不得不承认..."',
          examples: ['不得不承认，他的实力确实很强'],
        ),
        ForbiddenPattern(
          id: 'undeniably',
          pattern: r'不可否认的是',
          description: '避免"不可否认的是..."',
          examples: ['不可否认的是，这个方案有优点'],
        ),
        ForbiddenPattern(
          id: 'in_general',
          pattern: r'(总的来说|总体而言|综上所述)',
          description: '避免总结性开头',
          examples: ['总的来说，这次行动很成功'],
        ),
        ForbiddenPattern(
          id: 'to_some_extent',
          pattern: r'从某种程度上(来说|来讲)',
          description: '避免模糊表达',
          examples: ['从某种程度上来说，这个决定是对的'],
        ),
      ];
}

/// 标点滥用配置
@freezed
class PunctuationLimit with _$PunctuationLimit {
  const factory PunctuationLimit({
    required String punctuation,
    required int maxPerThousand,
    required String description,
  }) = _PunctuationLimit;

  factory PunctuationLimit.fromJson(Map<String, dynamic> json) =>
      _$PunctuationLimitFromJson(json);
}

/// 默认标点限制
class DefaultPunctuationLimits {
  static List<PunctuationLimit> get all => [
        const PunctuationLimit(
          punctuation: '——',
          maxPerThousand: 3,
          description: '破折号使用频率过高',
        ),
        const PunctuationLimit(
          punctuation: '……',
          maxPerThousand: 5,
          description: '省略号使用频率过高',
        ),
        const PunctuationLimit(
          punctuation: '！',
          maxPerThousand: 10,
          description: '感叹号使用频率过高',
        ),
      ];
}

/// AI 常用词
@freezed
class AIVocabulary with _$AIVocabulary {
  const factory AIVocabulary({
    required String word,
    required String category,
    @Default([]) List<String> alternatives,
  }) = _AIVocabulary;

  factory AIVocabulary.fromJson(Map<String, dynamic> json) =>
      _$AIVocabularyFromJson(json);
}

/// 默认 AI 常用词
class DefaultAIVocabulary {
  static List<AIVocabulary> get all => [
        const AIVocabulary(
          word: '仿佛',
          category: '比喻词',
          alternatives: ['好像', '宛如', '如同'],
        ),
        const AIVocabulary(
          word: '逐渐',
          category: '程度词',
          alternatives: ['渐渐', '慢慢', '一点一点'],
        ),
        const AIVocabulary(
          word: '难以言喻',
          category: '描述词',
          alternatives: ['说不出', '无法描述', '无法形容'],
        ),
        const AIVocabulary(
          word: '不可名状',
          category: '描述词',
          alternatives: ['说不出是什么感觉'],
        ),
        const AIVocabulary(
          word: '意味深长',
          category: '描述词',
          alternatives: ['眼神深邃', '若有所思'],
        ),
      ];
}

/// 检测结果
@freezed
class DetectionResult with _$DetectionResult {
  const DetectionResult._();

  const factory DetectionResult({
    required String id,
    required DetectionType type,
    required String matchedText,
    required int startOffset,
    required int endOffset,
    String? suggestion,
    String? description,
    String? pattern,
  }) = _DetectionResult;

  factory DetectionResult.fromJson(Map<String, dynamic> json) =>
      _$DetectionResultFromJson(json);
}

/// 检测报告
@freezed
class DetectionReport with _$DetectionReport {
  const DetectionReport._();

  const factory DetectionReport({
    required String chapterId,
    required DateTime analyzedAt,
    required List<DetectionResult> results,
    required Map<String, int> typeCounts,
    @Default(0) int totalIssues,
    @Default(0) int wordCount,
  }) = _DetectionReport;

  factory DetectionReport.fromJson(Map<String, dynamic> json) =>
      _$DetectionReportFromJson(json);

  /// 问题密度（每千字问题数）
  double get issueDensity {
    if (wordCount == 0) return 0;
    return totalIssues / (wordCount / 1000);
  }

  /// 获取指定类型的问题
  List<DetectionResult> getResultsByType(DetectionType type) {
    return results.where((r) => r.type == type).toList();
  }
}
