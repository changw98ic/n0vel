class AiClicheKind {
  final String name;
  final String label;
  const AiClicheKind._(this.name, this.label);

  static const AiClicheKind clichedPhrase = AiClicheKind._(
    'clichedPhrase',
    '陈词滥调',
  );
  static const AiClicheKind shortSentenceRun = AiClicheKind._(
    'shortSentenceRun',
    '连续短句',
  );
  static const AiClicheKind repeatedAdjective = AiClicheKind._(
    'repeatedAdjective',
    '重复形容词',
  );
  static const AiClicheKind excessiveAdverb = AiClicheKind._(
    'excessiveAdverb',
    '过度副词',
  );
}

class AiClicheFinding {
  final AiClicheKind kind;
  final String matched;
  final int position;
  final String context;

  const AiClicheFinding({
    required this.kind,
    required this.matched,
    required this.position,
    required this.context,
  });

  @override
  String toString() => '${kind.label}：「$matched」于位置 $position';
}

class AiClicheReport {
  final List<AiClicheFinding> findings;
  final int totalWordCount;
  final double clicheDensity;

  const AiClicheReport({
    required this.findings,
    required this.totalWordCount,
    required this.clicheDensity,
  });

  bool get hasIssues => findings.isNotEmpty;

  bool get isSevere => clicheDensity > 0.02;

  List<AiClicheFinding> findingsOf(AiClicheKind kind) =>
      findings.where((f) => f.kind == kind).toList();

  String toSummaryText() {
    if (!hasIssues) return '未检测到人工智能写作痕迹。';
    final buf = StringBuffer('检测到 ${findings.length} 处问题：\n');
    for (final kind in [
      AiClicheKind.clichedPhrase,
      AiClicheKind.shortSentenceRun,
      AiClicheKind.repeatedAdjective,
      AiClicheKind.excessiveAdverb,
    ]) {
      final items = findingsOf(kind);
      if (items.isNotEmpty) {
        buf.writeln('  ${kind.label}：${items.length} 处');
      }
    }
    return buf.toString().trimRight();
  }
}

class AiClicheDetector {
  static const _clichedPhrases = [
    '不由得',
    '不由自主',
    '竟然',
    '居然',
    '心中暗想',
    '心中暗叹',
    '心中一紧',
    '心中一动',
    '心中一凛',
    '心中一震',
    '心中一阵',
    '眼眶微红',
    '眼眶一热',
    '恍然大悟',
    '此情此景',
    '一股莫名的',
    '一股说不出的',
    '一股难以言喻的',
    '不禁感慨',
    '不禁为之',
    '不禁有些',
    '莫名的感动',
    '莫名的心酸',
    '莫名的愤怒',
    '莫名的悲伤',
    '心中涌起一股',
    '喉头一紧',
    '喉间一哽',
    '眼底闪过一丝',
    '眼中闪过一丝',
    '嘴角微微上扬',
    '嘴角勾起一抹',
    '露出一抹苦笑',
    '露出一抹淡淡的',
    '轻叹一声',
    '淡淡一笑',
    '微微一笑',
    '缓缓开口',
    '缓缓说道',
    '沉声说道',
    '低沉的声音',
    '浑厚的声音',
    '清冷的声音',
    '如同...一般',
    '像是...一样',
    '宛如...般',
    '犹如...般',
    '仿佛...似的',
    '那是一种...的感觉',
    '那是一种...的情绪',
    '说不清是...还是',
    '分不清是...还是',
  ];

  static const _excessiveAdverbs = [
    '渐渐地',
    '慢慢地',
    '轻轻地',
    '默默地',
    '静静地',
    '深深地',
    '紧紧地',
    '狠狠地',
    '悄悄地',
    '偷偷地',
    '缓缓地',
    '淡淡地',
    '微微地',
    '久久地',
    '默默无闻地',
  ];

  AiClicheReport detect(String text) {
    final findings = <AiClicheFinding>[];
    final paragraphs = text.split(RegExp(r'\n+'));

    _findClichedPhrases(text, findings);
    _findShortSentenceRuns(paragraphs, findings);
    _findRepeatedAdjectives(paragraphs, findings);
    _findExcessiveAdverbs(text, findings);

    final wordCount = _countChineseChars(text);
    final density = wordCount > 0 ? findings.length / wordCount : 0.0;

    return AiClicheReport(
      findings: List.unmodifiable(findings),
      totalWordCount: wordCount,
      clicheDensity: density,
    );
  }

  void _findClichedPhrases(String text, List<AiClicheFinding> findings) {
    for (final phrase in _clichedPhrases) {
      var start = 0;
      while (true) {
        final index = text.indexOf(phrase, start);
        if (index == -1) break;
        findings.add(
          AiClicheFinding(
            kind: AiClicheKind.clichedPhrase,
            matched: phrase,
            position: index,
            context: _contextAround(text, index, phrase.length),
          ),
        );
        start = index + phrase.length;
      }
    }
  }

  void _findShortSentenceRuns(
    List<String> paragraphs,
    List<AiClicheFinding> findings,
  ) {
    for (final para in paragraphs) {
      final sentences = _splitSentences(para);
      if (sentences.length < 5) continue;
      var shortRunStart = -1;
      var shortRunCount = 0;
      for (var i = 0; i < sentences.length; i++) {
        final len = _countChineseChars(sentences[i]);
        if (len >= 3 && len <= 8) {
          if (shortRunStart == -1) shortRunStart = i;
          shortRunCount++;
          if (shortRunCount >= 5) {
            final runSentences = sentences.sublist(shortRunStart, i + 1);
            findings.add(
              AiClicheFinding(
                kind: AiClicheKind.shortSentenceRun,
                matched: runSentences.join('→'),
                position: -1,
                context: '$shortRunCount个连续短句',
              ),
            );
            break;
          }
        } else {
          shortRunStart = -1;
          shortRunCount = 0;
        }
      }
    }
  }

  void _findRepeatedAdjectives(
    List<String> paragraphs,
    List<AiClicheFinding> findings,
  ) {
    for (final para in paragraphs) {
      final adjectives = <String, int>{};
      final regex = RegExp(r'([一-鿿]{2,4}的)');
      for (final match in regex.allMatches(para)) {
        final adj = match.group(1)!;
        adjectives[adj] = (adjectives[adj] ?? 0) + 1;
      }
      for (final entry in adjectives.entries) {
        if (entry.value > 2) {
          findings.add(
            AiClicheFinding(
              kind: AiClicheKind.repeatedAdjective,
              matched: entry.key,
              position: para.indexOf(entry.key),
              context: '出现 ${entry.value} 次',
            ),
          );
        }
      }
    }
  }

  void _findExcessiveAdverbs(String text, List<AiClicheFinding> findings) {
    for (final adverb in _excessiveAdverbs) {
      var count = 0;
      var start = 0;
      while (true) {
        final index = text.indexOf(adverb, start);
        if (index == -1) break;
        count++;
        start = index + adverb.length;
      }
      if (count >= 3) {
        findings.add(
          AiClicheFinding(
            kind: AiClicheKind.excessiveAdverb,
            matched: adverb,
            position: text.indexOf(adverb),
            context: '出现 $count 次',
          ),
        );
      }
    }
  }

  List<String> _splitSentences(String text) {
    return text
        .split(RegExp(r'[。！？…；\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  int _countChineseChars(String text) {
    var count = 0;
    for (final rune in text.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) count++;
    }
    return count;
  }

  String _contextAround(String text, int pos, int len) {
    final start = pos > 10 ? pos - 10 : 0;
    final end = pos + len + 10 < text.length ? pos + len + 10 : text.length;
    return text.substring(start, end);
  }
}
