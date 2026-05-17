import 'dart:convert';
import 'dart:io';

class ProseStyleFingerprint {
  const ProseStyleFingerprint({
    required this.avgSentenceLength,
    required this.sentenceLengthVariance,
    required this.dialogueRatio,
    required this.avgParagraphLength,
    required this.punctuationRatios,
    required this.statementRatio,
    required this.questionRatio,
    required this.exclamationRatio,
    required this.ellipsisRatio,
    required this.topAdjectives,
    required this.totalChineseChars,
    required this.sentenceCount,
    required this.paragraphCount,
  });

  final double avgSentenceLength;
  final double sentenceLengthVariance;
  final double dialogueRatio;
  final double avgParagraphLength;
  final Map<String, double> punctuationRatios;
  final double statementRatio;
  final double questionRatio;
  final double exclamationRatio;
  final double ellipsisRatio;
  final Map<String, int> topAdjectives;
  final int totalChineseChars;
  final int sentenceCount;
  final int paragraphCount;

  @override
  String toString() => 'ProseStyleFingerprint('
      'sentLen=$avgSentenceLength, '
      'sentVar=$sentenceLengthVariance, '
      'dialogue=$dialogueRatio, '
      'paraLen=$avgParagraphLength, '
      'stmt=$statementRatio, '
      'q=$questionRatio, '
      'excl=$exclamationRatio, '
      'ellip=$ellipsisRatio, '
      'chars=$totalChineseChars, '
      'sentences=$sentenceCount, '
      'paragraphs=$paragraphCount)';
}

class ProseStyleDivergencePoint {
  const ProseStyleDivergencePoint({
    required this.metric,
    required this.generatedValue,
    required this.referenceValue,
    required this.description,
  });

  final String metric;
  final double generatedValue;
  final double referenceValue;
  final String description;

  @override
  String toString() => '$metric: 生成=$generatedValue, 参考=$referenceValue — $description';
}

class ProseStyleDivergenceReport {
  const ProseStyleDivergenceReport({
    required this.similarityScore,
    required this.generatedFingerprint,
    required this.referenceFingerprint,
    required this.divergencePoints,
    this.referenceLabel = '',
  });

  final double similarityScore;
  final ProseStyleFingerprint generatedFingerprint;
  final ProseStyleFingerprint referenceFingerprint;
  final List<ProseStyleDivergencePoint> divergencePoints;
  final String referenceLabel;

  String toSummaryText() {
    final buf = StringBuffer()
      ..writeln('风格相似度：${(similarityScore * 100).toStringAsFixed(1)}%')
      ..writeln('参考文本：$referenceLabel');
    if (divergencePoints.isNotEmpty) {
      buf.writeln('差异点：');
      for (final point in divergencePoints) {
        buf.writeln('  - ${point.metric}：生成 ${point.generatedValue.toStringAsFixed(2)} vs 参考 ${point.referenceValue.toStringAsFixed(2)}');
      }
    }
    return buf.toString().trimRight();
  }
}

class ProseStyleAnalyzer {
  static final _sentenceSplitter = RegExp(r'[。！？…；\n]');

  static final _dialogueQuotePattern = RegExp(r'[「」""'']');

  static final _adjectivePattern = RegExp(r'([一-鿿]{2,4}的)');

  static const _maxTopItems = 20;

  ProseStyleFingerprint analyze(String text) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final sentences = _splitSentences(text);
    final chineseChars = _countChineseChars(text);

    final sentenceLengths = sentences
        .map((s) => _countChineseChars(s).toDouble())
        .toList();

    final avgSentLen = sentenceLengths.isEmpty
        ? 0.0
        : sentenceLengths.reduce((a, b) => a + b) / sentenceLengths.length;
    final sentVar = sentenceLengths.length <= 1
        ? 0.0
        : sentenceLengths
                .map((l) => (l - avgSentLen) * (l - avgSentLen))
                .reduce((a, b) => a + b) /
            sentenceLengths.length;

    final dialogueChars = _countDialogueChars(text);
    final dialogueRatio =
        chineseChars > 0 ? dialogueChars / chineseChars : 0.0;

    final avgParaLen = paragraphs.isEmpty
        ? 0.0
        : paragraphs
                .map((p) => _countChineseChars(p).toDouble())
                .reduce((a, b) => a + b) /
            paragraphs.length;

    final punctCounts = _countPunctuation(text);
    final totalPunct = punctCounts.values.fold(0, (a, b) => a + b);
    final punctRatios = <String, double>{};
    if (totalPunct > 0) {
      for (final entry in punctCounts.entries) {
        punctRatios[entry.key] = entry.value / totalPunct;
      }
    }

    final totalSentences = sentences.length;
    final stmtRatio = totalSentences > 0
        ? sentences.where((s) => _extractSentenceTerminator(s) == '。').length /
            totalSentences
        : 0.0;
    final qRatio = totalSentences > 0
        ? sentences.where((s) {
            final t = _extractSentenceTerminator(s);
            return t == '？' || t == '?';
          }).length /
            totalSentences
        : 0.0;
    final exclRatio = totalSentences > 0
        ? sentences.where((s) {
            final t = _extractSentenceTerminator(s);
            return t == '！' || t == '!';
          }).length /
            totalSentences
        : 0.0;
    final ellipRatio = totalSentences > 0
        ? sentences.where((s) {
            final t = _extractSentenceTerminator(s);
            return t == '…' || t == '……';
          }).length /
            totalSentences
        : 0.0;

    final adjectives = _extractTopPatterns(text, _adjectivePattern);

    return ProseStyleFingerprint(
      avgSentenceLength: avgSentLen,
      sentenceLengthVariance: sentVar,
      dialogueRatio: dialogueRatio,
      avgParagraphLength: avgParaLen,
      punctuationRatios: Map.unmodifiable(punctRatios),
      statementRatio: stmtRatio,
      questionRatio: qRatio,
      exclamationRatio: exclRatio,
      ellipsisRatio: ellipRatio,
      topAdjectives: Map.unmodifiable(adjectives),
      totalChineseChars: chineseChars,
      sentenceCount: totalSentences,
      paragraphCount: paragraphs.length,
    );
  }

  double similarityTo(
    ProseStyleFingerprint a,
    ProseStyleFingerprint b,
  ) {
    final sentLenDiff = (a.avgSentenceLength - b.avgSentenceLength).abs();
    final sentLenScore = 1.0 - (sentLenDiff / 30.0).clamp(0.0, 1.0);

    final dialogueDiff = (a.dialogueRatio - b.dialogueRatio).abs();
    final dialogueScore = 1.0 - (dialogueDiff / 0.5).clamp(0.0, 1.0);

    final varDiff =
        (a.sentenceLengthVariance - b.sentenceLengthVariance).abs();
    final varScore = 1.0 - (varDiff / 200.0).clamp(0.0, 1.0);

    final stmtDiff = (a.statementRatio - b.statementRatio).abs();
    final qDiff = (a.questionRatio - b.questionRatio).abs();
    final exclDiff = (a.exclamationRatio - b.exclamationRatio).abs();
    final ellipDiff = (a.ellipsisRatio - b.ellipsisRatio).abs();
    final patternDist =
        (stmtDiff + qDiff + exclDiff + ellipDiff) / 4.0;
    final patternScore = 1.0 - (patternDist / 0.5).clamp(0.0, 1.0);

    final punctKeys = <String>{...a.punctuationRatios.keys, ...b.punctuationRatios.keys};
    var punctDist = 0.0;
    for (final key in punctKeys) {
      final av = a.punctuationRatios[key] ?? 0.0;
      final bv = b.punctuationRatios[key] ?? 0.0;
      punctDist += (av - bv).abs();
    }
    final punctScore = 1.0 - (punctDist / 1.0).clamp(0.0, 1.0);

    return sentLenScore * 0.25 +
        dialogueScore * 0.20 +
        punctScore * 0.20 +
        varScore * 0.15 +
        patternScore * 0.20;
  }

  ProseStyleDivergenceReport compare({
    required String generatedText,
    required String referenceText,
    String referenceLabel = '',
  }) {
    final genFp = analyze(generatedText);
    final refFp = analyze(referenceText);
    final score = similarityTo(genFp, refFp);
    final divergences = <ProseStyleDivergencePoint>[];

    void check(String name, double gen, double ref, double threshold) {
      if ((gen - ref).abs() > threshold) {
        divergences.add(ProseStyleDivergencePoint(
          metric: name,
          generatedValue: gen,
          referenceValue: ref,
          description: gen > ref ? '生成偏高' : '生成偏低',
        ));
      }
    }

    check('平均句长', genFp.avgSentenceLength, refFp.avgSentenceLength, 8.0);
    check('对话比率', genFp.dialogueRatio, refFp.dialogueRatio, 0.15);
    check('句长方差', genFp.sentenceLengthVariance,
        refFp.sentenceLengthVariance, 50.0);
    check('陈述句占比', genFp.statementRatio, refFp.statementRatio, 0.2);
    check('疑问句占比', genFp.questionRatio, refFp.questionRatio, 0.1);
    check('感叹句占比', genFp.exclamationRatio, refFp.exclamationRatio, 0.1);
    check('省略号占比', genFp.ellipsisRatio, refFp.ellipsisRatio, 0.05);

    return ProseStyleDivergenceReport(
      similarityScore: score,
      generatedFingerprint: genFp,
      referenceFingerprint: refFp,
      divergencePoints: List.unmodifiable(divergences),
      referenceLabel: referenceLabel,
    );
  }

  ProseStyleFingerprint referenceFingerprintFromJsonl(String jsonlPath) {
    final file = File(jsonlPath);
    if (!file.existsSync()) {
      return analyze('');
    }

    final buffer = StringBuffer();
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<Object?, Object?>;
        final text = json['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.write(text);
        }
      } catch (_) {
        continue;
      }
    }

    return analyze(buffer.toString());
  }

  // ---------------------------------------------------------------------------

  List<String> _splitSentences(String text) {
    final sentences = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      buffer.write(ch);
      if (_sentenceSplitter.hasMatch(ch)) {
        final s = buffer.toString().trim();
        if (s.isNotEmpty && _countChineseChars(s) > 0) {
          sentences.add(s);
        }
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) {
      final s = buffer.toString().trim();
      if (s.isNotEmpty && _countChineseChars(s) > 0) {
        sentences.add(s);
      }
    }
    return sentences;
  }

  String _extractSentenceTerminator(String sentence) {
    var trimmed = sentence.trimRight();
    // Strip trailing quote characters to find the real terminator
    while (trimmed.isNotEmpty &&
        (trimmed.endsWith('」') ||
            trimmed.endsWith('"') ||
            trimmed.endsWith("'") ||
            trimmed.endsWith('”') ||
            trimmed.endsWith('’'))) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.isEmpty) return '';
    final lastChar = trimmed[trimmed.length - 1];
    if ('。！？…'.contains(lastChar)) return lastChar;
    if (lastChar == '?' || lastChar == '!') return lastChar;
    if (trimmed.length >= 2) {
      final lastTwo = trimmed.substring(trimmed.length - 2);
      if (lastTwo == '……') return '……';
    }
    return '';
  }

  int _countChineseChars(String text) {
    var count = 0;
    for (final rune in text.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) count++;
    }
    return count;
  }

  int _countDialogueChars(String text) {
    var count = 0;
    var inQuote = false;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      if (_dialogueQuotePattern.hasMatch(ch) ||
          ch == '“' || ch == '”' ||
          ch == '‘' || ch == '’') {
        inQuote = !inQuote;
        continue;
      }
      if (inQuote && rune >= 0x4E00 && rune <= 0x9FFF) {
        count++;
      }
    }
    return count;
  }

  Map<String, int> _countPunctuation(String text) {
    const targets = {'。': 0, '！': 0, '？': 0, '…': 0, '；': 0};
    final counts = <String, int>{...targets};
    for (final ch in text.runes) {
      final s = String.fromCharCode(ch);
      if (counts.containsKey(s)) {
        counts[s] = counts[s]! + 1;
      }
    }
    // Normalize ellipsis: …… counts as 1
    final ellipsisPairCount = '……'.allMatches(text).length;
    if (ellipsisPairCount > 0 && counts.containsKey('…')) {
      counts['…'] = counts['…']! - ellipsisPairCount;
      if (counts['…']! < 0) counts['…'] = 0;
    }
    return counts;
  }

  Map<String, int> _extractTopPatterns(String text, RegExp pattern) {
    final freq = <String, int>{};
    for (final match in pattern.allMatches(text)) {
      final value = match.group(1)!;
      freq[value] = (freq[value] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(_maxTopItems));
  }
}
