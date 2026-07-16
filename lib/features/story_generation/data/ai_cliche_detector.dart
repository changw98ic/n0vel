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
  static const AiClicheKind selfRepeat = AiClicheKind._('selfRepeat', '句内复沓');
  static const AiClicheKind crossSceneTemplate = AiClicheKind._(
    'crossSceneTemplate',
    '跨场景模板',
  );
  static const AiClicheKind crossSceneRepeatedFragment = AiClicheKind._(
    'crossSceneRepeatedFragment',
    '跨场景重复片段',
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
      AiClicheKind.selfRepeat,
      AiClicheKind.crossSceneTemplate,
      AiClicheKind.crossSceneRepeatedFragment,
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
  static const _crossSceneNgramLength = 14;

  static const _selfRepeatStopWords = <String>{
    '一个',
    '一些',
    '一种',
    '这个',
    '那个',
    '这些',
    '那些',
    '他们',
    '她们',
    '我们',
    '你们',
    '自己',
    '没有',
    '不是',
    '还是',
    '已经',
    '然后',
    '因为',
    '所以',
    '如果',
    '但是',
    '只是',
    '可以',
    '什么',
    '怎么',
    '时候',
    '一样',
    '这里',
    '那里',
    '其中',
    '起来',
    '下去',
    '过去',
    '现在',
    '这样',
    '那样',
  };

  static const _commonSurnames =
      '赵钱孙李周吴郑王冯陈褚卫蒋沈韩杨朱秦尤许何吕施张孔曹严华金魏陶姜'
      '戚谢邹喻柏水窦章云苏潘葛奚范彭郎鲁韦昌马苗凤花方俞任袁柳鲍史唐'
      '费廉岑薛雷贺倪汤滕殷罗毕郝邬安常乐于时傅皮卞齐康伍余元卜顾孟平'
      '黄和穆萧尹姚邵汪祁毛禹狄米贝明臧计伏成戴宋茅庞熊纪舒屈项祝董梁'
      '杜阮蓝闵席季麻强贾路娄危江童颜郭梅盛林钟徐邱骆高夏蔡田樊胡凌霍'
      '虞万支柯管卢莫经房裘缪干解应宗丁宣邓郁单杭洪包诸左石崔吉龚程嵇'
      '邢裴陆荣翁荀羊惠甄曲封芮储靳汲邴糜松井段富巫乌焦巴弓牧隗山谷车'
      '侯宓蓬全郗班仰秋仲伊宫宁仇栾暴甘钭厉戎祖武符刘景詹束龙叶幸司韶'
      '郜黎蓟薄印宿白怀蒲台从鄂索咸籍赖卓蔺屠蒙池乔阴胥能苍双闻莘党翟'
      '谭贡劳逄姬申扶堵冉宰郦雍却璩桑桂濮牛寿通边扈燕冀郏浦尚农温别庄晏'
      '柴瞿阎充慕连茹习宦艾鱼容向古易慎戈廖庾终暨居衡步都耿满弘匡国文寇'
      '广禄阙东欧殳沃利蔚越夔隆师巩厍聂晁勾敖融冷訾辛阚那简饶空曾毋沙乜'
      '养鞠须丰巢关蒯相查后荆红游竺权逯盖益桓公';

  static const _characterReferenceSuffixes = <String>[
    '说',
    '道',
    '问',
    '答',
    '喊',
    '叫',
    '看',
    '望',
    '盯',
    '抬',
    '低',
    '转',
    '走',
    '跑',
    '站',
    '坐',
    '伸',
    '收',
    '握',
    '抓',
    '推',
    '拉',
    '摇',
    '点',
    '笑',
    '哭',
    '皱',
    '沉',
    '把',
    '将',
    '没有',
    '仍',
    '又',
    '却',
    '也',
    '正',
    '始终',
    '手',
    '脸',
    '眼',
    '肩',
    '背',
    '脚',
    '头',
    '身',
    '心',
    '拿',
    '摸',
    '听',
    '想',
    '记',
    '咬',
    '攥',
    '靠',
    '跟',
    '向',
    '从',
    '在',
    '被',
    '让',
    '给',
    '对',
    '朝',
  ];

  static final _crossSceneTemplates = <_CrossSceneTemplate>[
    _CrossSceneTemplate(
      label: '目光…钉…',
      pattern: RegExp(r'目光[^。！？!?\n]{0,18}钉'),
    ),
    _CrossSceneTemplate(
      label: '声音…压低/极低',
      pattern: RegExp(
        r'(?:声音[^。！？!?\n]{0,12}(?:压低|极低)|'
        r'压低[^。！？!?\n]{0,6}声音)',
      ),
    ),
    _CrossSceneTemplate(
      label: '声音被风撕得发颤',
      pattern: RegExp(
        r'(?:声音|话音)[^。！？!?\n]{0,10}(?:风|夜风)'
        r'[^。！？!?\n]{0,10}撕[^。！？!?\n]{0,10}(?:发颤|颤抖)',
      ),
    ),
    _CrossSceneTemplate(
      label: '指节发白/泛白',
      pattern: RegExp(r'指节[^。！？!?\n]{0,10}(?:发白|泛白)'),
    ),
  ];

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
    _findSelfRepeats(text, findings);

    final wordCount = _countChineseChars(text);
    final density = wordCount > 0 ? findings.length / wordCount : 0.0;

    return AiClicheReport(
      findings: List.unmodifiable(findings),
      totalWordCount: wordCount,
      clicheDensity: density,
    );
  }

  AiClicheReport detectAcrossScenes(Map<String, String> orderedScenes) {
    final findings = <AiClicheFinding>[];
    var totalWordCount = 0;

    for (final entry in orderedScenes.entries) {
      final report = detect(entry.value);
      totalWordCount += report.totalWordCount;
      findings.addAll([
        for (final finding in report.findings)
          AiClicheFinding(
            kind: finding.kind,
            matched: finding.matched,
            position: finding.position,
            context: '[${entry.key}] ${finding.context}',
          ),
      ]);
    }

    for (final template in _crossSceneTemplates) {
      final hits = <_CrossSceneTemplateHit>[];
      for (final entry in orderedScenes.entries) {
        final match = template.pattern.firstMatch(entry.value);
        if (match == null) continue;
        hits.add(
          _CrossSceneTemplateHit(sceneId: entry.key, excerpt: match.group(0)!),
        );
      }
      if (hits.length < 2) continue;
      findings.add(
        AiClicheFinding(
          kind: AiClicheKind.crossSceneTemplate,
          matched: template.label,
          position: -1,
          context: hits
              .map((hit) => '${hit.sceneId}「${hit.excerpt}」')
              .join('；'),
        ),
      );
    }

    findings.addAll(_findCrossSceneRepeatedFragments(orderedScenes));

    return AiClicheReport(
      findings: List.unmodifiable(findings),
      totalWordCount: totalWordCount,
      clicheDensity: totalWordCount == 0
          ? 0.0
          : findings.length / totalWordCount,
    );
  }

  List<AiClicheFinding> _findCrossSceneRepeatedFragments(
    Map<String, String> orderedScenes,
  ) {
    final scenes = <_NormalizedScene>[
      for (final entry in orderedScenes.entries)
        _NormalizedScene.fromText(entry.key, entry.value),
    ];
    final seedsByGram = <String, List<_CrossSceneNgramSeed>>{};

    for (var sceneIndex = 0; sceneIndex < scenes.length; sceneIndex++) {
      final scene = scenes[sceneIndex];
      if (scene.normalized.length < _crossSceneNgramLength) continue;
      final seenInScene = <String>{};
      for (
        var start = 0;
        start <= scene.normalized.length - _crossSceneNgramLength;
        start++
      ) {
        final gram = scene.normalized.substring(
          start,
          start + _crossSceneNgramLength,
        );
        if (!seenInScene.add(gram)) continue;
        seedsByGram
            .putIfAbsent(gram, () => <_CrossSceneNgramSeed>[])
            .add(_CrossSceneNgramSeed(sceneIndex: sceneIndex, start: start));
      }
    }

    final candidates = <String, _CrossSceneNgramCandidate>{};
    for (final seeds in seedsByGram.values) {
      if (seeds.length < 2) continue;
      for (var leftIndex = 0; leftIndex < seeds.length - 1; leftIndex++) {
        final leftSeed = seeds[leftIndex];
        for (
          var rightIndex = leftIndex + 1;
          rightIndex < seeds.length;
          rightIndex++
        ) {
          final rightSeed = seeds[rightIndex];
          if (leftSeed.sceneIndex == rightSeed.sceneIndex) continue;
          final leftScene = scenes[leftSeed.sceneIndex];
          final rightScene = scenes[rightSeed.sceneIndex];
          final span = _extendCrossSceneMatch(
            leftScene.normalized,
            leftSeed.start,
            rightScene.normalized,
            rightSeed.start,
          );
          final fragment = leftScene.normalized.substring(
            span.leftStart,
            span.leftStart + span.length,
          );
          final candidate = candidates.putIfAbsent(
            fragment,
            () => _CrossSceneNgramCandidate(fragment),
          );
          candidate.addHit(leftScene, span.leftStart, span.length);
          candidate.addHit(rightScene, span.rightStart, span.length);
        }
      }
    }

    final orderedCandidates =
        candidates.values
            .where((candidate) => candidate.hitsByScene.length >= 2)
            .toList()
          ..sort((left, right) {
            final byLength = right.fragment.length.compareTo(
              left.fragment.length,
            );
            if (byLength != 0) return byLength;
            return left.fragment.compareTo(right.fragment);
          });
    final accepted = <_CrossSceneNgramCandidate>[];
    for (final candidate in orderedCandidates) {
      if (accepted.any((longer) => longer.covers(candidate))) continue;
      accepted.add(candidate);
    }

    return <AiClicheFinding>[
      for (final candidate in accepted)
        AiClicheFinding(
          kind: AiClicheKind.crossSceneRepeatedFragment,
          matched: candidate.fragment,
          position: -1,
          context: candidate.evidenceText,
        ),
    ];
  }

  _CrossSceneNgramSpan _extendCrossSceneMatch(
    String left,
    int leftStart,
    String right,
    int rightStart,
  ) {
    var prefixLength = 0;
    while (leftStart - prefixLength > 0 &&
        rightStart - prefixLength > 0 &&
        left.codeUnitAt(leftStart - prefixLength - 1) ==
            right.codeUnitAt(rightStart - prefixLength - 1)) {
      prefixLength++;
    }

    var suffixLength = 0;
    while (leftStart + _crossSceneNgramLength + suffixLength < left.length &&
        rightStart + _crossSceneNgramLength + suffixLength < right.length &&
        left.codeUnitAt(leftStart + _crossSceneNgramLength + suffixLength) ==
            right.codeUnitAt(
              rightStart + _crossSceneNgramLength + suffixLength,
            )) {
      suffixLength++;
    }

    return _CrossSceneNgramSpan(
      leftStart: leftStart - prefixLength,
      rightStart: rightStart - prefixLength,
      length: prefixLength + _crossSceneNgramLength + suffixLength,
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

  void _findSelfRepeats(String text, List<AiClicheFinding> findings) {
    for (final sentence in _sentenceSpans(text)) {
      final positionsByCandidate = <String, List<int>>{};
      for (final run in RegExp(r'[一-鿿]+').allMatches(sentence.text)) {
        final value = run.group(0)!;
        for (var start = 0; start < value.length; start++) {
          final maxLength = (value.length - start).clamp(0, 4);
          for (var length = 2; length <= maxLength; length++) {
            final candidate = value.substring(start, start + length);
            positionsByCandidate
                .putIfAbsent(candidate, () => <int>[])
                .add(run.start + start);
          }
        }
      }

      final matches = <_SelfRepeatMatch>[];
      for (final entry in positionsByCandidate.entries) {
        if (entry.value.length < 2 ||
            _selfRepeatStopWords.contains(entry.key)) {
          continue;
        }
        final pair = _nearestRepeatPair(entry.key, entry.value);
        if (pair == null ||
            _looksLikeRepeatedCharacterName(sentence.text, entry.key, pair)) {
          continue;
        }
        matches.add(
          _SelfRepeatMatch(
            candidate: entry.key,
            first: pair.first,
            second: pair.second,
          ),
        );
      }

      matches.sort((left, right) {
        final byLength = right.candidate.length.compareTo(
          left.candidate.length,
        );
        if (byLength != 0) return byLength;
        return left.first.compareTo(right.first);
      });

      final accepted = <_SelfRepeatMatch>[];
      for (final match in matches) {
        if (accepted.any((longer) => longer.contains(match))) continue;
        accepted.add(match);
        final globalStart = sentence.start + match.first;
        final globalEnd =
            sentence.start + match.second + match.candidate.length;
        findings.add(
          AiClicheFinding(
            kind: AiClicheKind.selfRepeat,
            matched: match.candidate,
            position: globalStart,
            context: _contextAround(text, globalStart, globalEnd - globalStart),
          ),
        );
      }
    }
  }

  _RepeatPair? _nearestRepeatPair(String candidate, List<int> positions) {
    _RepeatPair? nearest;
    var nearestGap = 1 << 30;
    var latestNonOverlapping = -1;
    for (var right = 1; right < positions.length; right++) {
      while (latestNonOverlapping + 1 < right &&
          positions[latestNonOverlapping + 1] + candidate.length <=
              positions[right]) {
        latestNonOverlapping++;
      }
      if (latestNonOverlapping < 0) continue;
      final first = positions[latestNonOverlapping];
      final second = positions[right];
      final gap = second - first - candidate.length;
      if (gap > 18 || gap >= nearestGap) continue;
      nearest = _RepeatPair(first, second);
      nearestGap = gap;
    }
    return nearest;
  }

  bool _looksLikeRepeatedCharacterName(
    String sentence,
    String candidate,
    _RepeatPair pair,
  ) {
    if (candidate.length < 2 || candidate.length > 3) return false;
    if (!_commonSurnames.contains(candidate[0])) return false;
    return _looksLikeCharacterReference(sentence, candidate, pair.first) &&
        _looksLikeCharacterReference(sentence, candidate, pair.second);
  }

  bool _looksLikeCharacterReference(
    String sentence,
    String candidate,
    int position,
  ) {
    final suffixStart = position + candidate.length;
    if (suffixStart >= sentence.length) return false;
    final suffix = sentence.substring(suffixStart);
    return _characterReferenceSuffixes.any(suffix.startsWith);
  }

  Iterable<_SentenceSpan> _sentenceSpans(String text) sync* {
    final delimiter = RegExp(r'[。！？!?；;\n]+');
    var start = 0;
    for (final match in delimiter.allMatches(text)) {
      if (match.start > start) {
        yield _SentenceSpan(start, text.substring(start, match.start));
      }
      start = match.end;
    }
    if (start < text.length) {
      yield _SentenceSpan(start, text.substring(start));
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

class _CrossSceneTemplate {
  const _CrossSceneTemplate({required this.label, required this.pattern});

  final String label;
  final RegExp pattern;
}

class _CrossSceneTemplateHit {
  const _CrossSceneTemplateHit({required this.sceneId, required this.excerpt});

  final String sceneId;
  final String excerpt;
}

class _NormalizedScene {
  const _NormalizedScene({
    required this.sceneId,
    required this.original,
    required this.normalized,
    required this.originalOffsets,
  });

  factory _NormalizedScene.fromText(String sceneId, String text) {
    final normalized = StringBuffer();
    final originalOffsets = <int>[];
    var index = 0;
    while (index < text.length) {
      final rune = text.codeUnitAt(index);
      final isSurrogatePair =
          rune >= 0xD800 &&
          rune <= 0xDBFF &&
          index + 1 < text.length &&
          text.codeUnitAt(index + 1) >= 0xDC00 &&
          text.codeUnitAt(index + 1) <= 0xDFFF;
      if (isSurrogatePair) {
        index += 2;
        continue;
      }
      final isChinese = rune >= 0x4E00 && rune <= 0x9FFF;
      final isAsciiLetter =
          (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
      final isAsciiDigit = rune >= 0x30 && rune <= 0x39;
      if (isChinese || isAsciiLetter || isAsciiDigit) {
        normalized.writeCharCode(rune);
        originalOffsets.add(index);
      }
      index++;
    }
    return _NormalizedScene(
      sceneId: sceneId,
      original: text,
      normalized: normalized.toString(),
      originalOffsets: List.unmodifiable(originalOffsets),
    );
  }

  final String sceneId;
  final String original;
  final String normalized;
  final List<int> originalOffsets;

  _CrossSceneNgramHit hitAt(int normalizedStart, int length) {
    final originalStart = originalOffsets[normalizedStart];
    final originalEnd = originalOffsets[normalizedStart + length - 1] + 1;
    return _CrossSceneNgramHit(
      sceneId: sceneId,
      normalizedStart: normalizedStart,
      excerpt: original.substring(originalStart, originalEnd),
    );
  }
}

class _CrossSceneNgramSeed {
  const _CrossSceneNgramSeed({required this.sceneIndex, required this.start});

  final int sceneIndex;
  final int start;
}

class _CrossSceneNgramSpan {
  const _CrossSceneNgramSpan({
    required this.leftStart,
    required this.rightStart,
    required this.length,
  });

  final int leftStart;
  final int rightStart;
  final int length;
}

class _CrossSceneNgramHit {
  const _CrossSceneNgramHit({
    required this.sceneId,
    required this.normalizedStart,
    required this.excerpt,
  });

  final String sceneId;
  final int normalizedStart;
  final String excerpt;
}

class _CrossSceneNgramCandidate {
  _CrossSceneNgramCandidate(this.fragment);

  final String fragment;
  final Map<String, _CrossSceneNgramHit> hitsByScene =
      <String, _CrossSceneNgramHit>{};

  void addHit(_NormalizedScene scene, int normalizedStart, int length) {
    final hit = scene.hitAt(normalizedStart, length);
    final existing = hitsByScene[scene.sceneId];
    if (existing == null || normalizedStart < existing.normalizedStart) {
      hitsByScene[scene.sceneId] = hit;
    }
  }

  bool covers(_CrossSceneNgramCandidate shorter) {
    if (!fragment.contains(shorter.fragment)) return false;
    return shorter.hitsByScene.keys.every(hitsByScene.containsKey);
  }

  String get evidenceText => hitsByScene.values
      .map((hit) => '${hit.sceneId}「${hit.excerpt}」')
      .join('；');
}

class _SentenceSpan {
  const _SentenceSpan(this.start, this.text);

  final int start;
  final String text;
}

class _RepeatPair {
  const _RepeatPair(this.first, this.second);

  final int first;
  final int second;
}

class _SelfRepeatMatch {
  const _SelfRepeatMatch({
    required this.candidate,
    required this.first,
    required this.second,
  });

  final String candidate;
  final int first;
  final int second;

  bool contains(_SelfRepeatMatch other) {
    final firstContains =
        first <= other.first &&
        first + candidate.length >= other.first + other.candidate.length;
    final secondContains =
        second <= other.second &&
        second + candidate.length >= other.second + other.candidate.length;
    return firstContains && secondContains;
  }
}
