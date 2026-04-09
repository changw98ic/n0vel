import '../domain/detection_result.dart';

/// AI 口吻检测服务
class AIStyleDetectionService {
  final List<ForbiddenPattern> _forbiddenPatterns;
  final List<PunctuationLimit> _punctuationLimits;
  final List<AIVocabulary> _aiVocabulary;

  AIStyleDetectionService({
    List<ForbiddenPattern>? forbiddenPatterns,
    List<PunctuationLimit>? punctuationLimits,
    List<AIVocabulary>? aiVocabulary,
  })  : _forbiddenPatterns = forbiddenPatterns ?? DefaultForbiddenPatterns.all,
        _punctuationLimits = punctuationLimits ?? DefaultPunctuationLimits.all,
        _aiVocabulary = aiVocabulary ?? DefaultAIVocabulary.all;

  /// 检测文本
  DetectionReport analyze(String text, String chapterId) {
    final results = <DetectionResult>[];
    final typeCounts = <String, int>{};

    // 计算字数
    final wordCount = _countWords(text);

    // 检测禁止句式
    final patternResults = _detectForbiddenPatterns(text);
    results.addAll(patternResults);
    typeCounts[DetectionType.forbiddenPattern.name] = patternResults.length;

    // 检测标点滥用
    final punctuationResults = _detectPunctuationAbuse(text, wordCount);
    results.addAll(punctuationResults);
    typeCounts[DetectionType.punctuationAbuse.name] = punctuationResults.length;

    // 检测 AI 常用词
    final vocabResults = _detectAIVocabulary(text);
    results.addAll(vocabResults);
    typeCounts[DetectionType.aiVocabulary.name] = vocabResults.length;

    // 检测视角问题
    final perspectiveResults = _detectPerspectiveIssues(text);
    results.addAll(perspectiveResults);
    typeCounts[DetectionType.perspectiveIssue.name] = perspectiveResults.length;

    // 检测标准化输出
    final standardizedResults = _detectStandardizedOutput(text);
    results.addAll(standardizedResults);
    typeCounts[DetectionType.standardizedOutput.name] = standardizedResults.length;

    return DetectionReport(
      chapterId: chapterId,
      analyzedAt: DateTime.now(),
      results: results,
      typeCounts: typeCounts,
      totalIssues: results.length,
      wordCount: wordCount,
    );
  }

  /// 检测禁止句式
  List<DetectionResult> _detectForbiddenPatterns(String text) {
    final results = <DetectionResult>[];
    var id = 0;

    for (final pattern in _forbiddenPatterns) {
      if (!pattern.isEnabled) continue;

      final regex = RegExp(pattern.pattern);
      for (final match in regex.allMatches(text)) {
        results.add(DetectionResult(
          id: 'pattern_${id++}',
          type: DetectionType.forbiddenPattern,
          matchedText: match.group(0) ?? '',
          startOffset: match.start,
          endOffset: match.end,
          description: pattern.description,
          pattern: pattern.pattern,
          suggestion: '建议改写为更自然的表达',
        ));
      }
    }

    return results;
  }

  /// 检测标点滥用
  List<DetectionResult> _detectPunctuationAbuse(String text, int wordCount) {
    final results = <DetectionResult>[];
    var id = 0;

    for (final limit in _punctuationLimits) {
      final regex = RegExp(RegExp.escape(limit.punctuation));
      final count = regex.allMatches(text).length;
      final maxAllowed = (wordCount / 1000 * limit.maxPerThousand).ceil();

      if (count > maxAllowed) {
        results.add(DetectionResult(
          id: 'punct_${id++}',
          type: DetectionType.punctuationAbuse,
          matchedText: limit.punctuation,
          startOffset: 0,
          endOffset: 0,
          description: '${limit.description}（当前：${count}次/千字，建议：<${limit.maxPerThousand}次）',
          suggestion: '减少 ${limit.punctuation} 的使用频率',
        ));
      }
    }

    return results;
  }

  /// 检测 AI 常用词
  List<DetectionResult> _detectAIVocabulary(String text) {
    final results = <DetectionResult>[];
    var id = 0;

    for (final vocab in _aiVocabulary) {
      final regex = RegExp(vocab.word);
      for (final match in regex.allMatches(text)) {
        final alternatives = vocab.alternatives.isNotEmpty
            ? '，建议使用：${vocab.alternatives.join('、')}'
            : '';

        results.add(DetectionResult(
          id: 'vocab_${id++}',
          type: DetectionType.aiVocabulary,
          matchedText: match.group(0) ?? '',
          startOffset: match.start,
          endOffset: match.end,
          description: '检测到 AI 常用词"$alternatives"',
          suggestion: '尝试用更自然的表达替代',
        ));
      }
    }

    return results;
  }

  /// 检测视角问题
  List<DetectionResult> _detectPerspectiveIssues(String text) {
    final results = <DetectionResult>[];
    var id = 0;

    // 检测上帝视角标记
    final godViewPatterns = [
      RegExp(r'(其实|事实上|实际上|客观来说)'),
      RegExp(r'(读者|观众)可能(会)?(注意|发现)'),
      RegExp(r'(从.*角度来看|站在.*角度)'),
    ];

    for (final pattern in godViewPatterns) {
      for (final match in pattern.allMatches(text)) {
        results.add(DetectionResult(
          id: 'perspective_${id++}',
          type: DetectionType.perspectiveIssue,
          matchedText: match.group(0) ?? '',
          startOffset: match.start,
          endOffset: match.end,
          description: '可能存在上帝视角问题',
          suggestion: '确保叙述在角色认知范围内',
        ));
      }
    }

    return results;
  }

  /// 检测标准化输出
  List<DetectionResult> _detectStandardizedOutput(String text) {
    final results = <DetectionResult>[];
    var id = 0;

    // 检测列表式表达
    final listPatterns = [
      RegExp(r'第一[，。].*第二[，。].*第三'),
      RegExp(r'首先[，。].*其次[，。].*最后'),
      RegExp(r'其?一[，。].*其?二[，。].*其?三'),
    ];

    for (final pattern in listPatterns) {
      for (final match in pattern.allMatches(text)) {
        results.add(DetectionResult(
          id: 'standard_${id++}',
          type: DetectionType.standardizedOutput,
          matchedText: match.group(0) ?? '',
          startOffset: match.start,
          endOffset: match.end,
          description: '检测到列表式表达，可能过于机械',
          suggestion: '尝试用更自然的叙述方式',
        ));
      }
    }

    // 检测重复句式结构
    final sentences = text.split(RegExp(r'[。！？]'));
    final structureCounts = <String, int>{};

    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;

      // 简化的句式结构检测
      final structure = _getSentenceStructure(sentence.trim());
      structureCounts[structure] = (structureCounts[structure] ?? 0) + 1;
    }

    // 如果同一种句式出现超过3次
    for (final entry in structureCounts.entries) {
      if (entry.value > 3) {
        results.add(DetectionResult(
          id: 'standard_${id++}',
          type: DetectionType.standardizedOutput,
          matchedText: '重复句式结构',
          startOffset: 0,
          endOffset: 0,
          description: '检测到重复的句式结构（${entry.value}次）',
          suggestion: '变化句式，避免单调',
        ));
      }
    }

    return results;
  }

  /// 获取句子结构（简化版）
  String _getSentenceStructure(String sentence) {
    // 简化：只检测开头和结尾的模式
    final startPattern = sentence.length > 4 ? sentence.substring(0, 4) : sentence;
    final endPattern = sentence.length > 4 ? sentence.substring(sentence.length - 4) : sentence;
    return '$startPattern...$endPattern';
  }

  /// 计算字数
  int _countWords(String text) {
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final englishCount = RegExp(r'[a-zA-Z]+').allMatches(text).length;
    return chineseCount + englishCount;
  }
}
