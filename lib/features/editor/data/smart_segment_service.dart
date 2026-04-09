import '../domain/editor_state.dart';

// Registered via GetX binding

/// 智能分段服务
class SmartSegmentService {
  /// 对话引号配对 (开放引号, 关闭引号)
  static const List<(String, String)> _quotePairs = [
    ('\u201C', '\u201D'), // " "
    ('\u2018', '\u2019'), // ' '
    ('\u300C', '\u300D'), // 「 」
    ('\u300E', '\u300F'), // 『 』
  ];


  /// 心理活动标记
  static final _innerThoughtMarkers = [
    '心想',
    '暗道',
    '心道',
    '心中',
    '暗自',
    '不禁',
    '忍不住想',
  ];

  /// 对文本进行智能分段
  SmartSegmentResult segment(String text) {
    final segments = <Segment>[];
    final detectedSpeakers = <String>[];
    var dialogueCount = 0;
    var innerThoughtCount = 0;

    // 先按换行分割
    final lines = text.split(RegExp(r'\n+'));

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;

      // 检测是否包含对话
      final dialogueSegments = _extractDialogue(line, i);
      if (dialogueSegments.isNotEmpty) {
        for (final seg in dialogueSegments) {
          segments.add(seg);
          if (seg.type == SegmentType.dialogue) {
            dialogueCount++;
            if (seg.speakerId != null) {
              detectedSpeakers.add(seg.speakerId!);
            }
          }
        }
        continue;
      }

      // 检测心理活动
      if (_isInnerThought(line)) {
        segments.add(Segment(
          id: 'seg_$i',
          text: line,
          type: SegmentType.innerThought,
          needsIndent: true,
        ));
        innerThoughtCount++;
        continue;
      }

      // 检测过渡段落（短句）
      if (line.length < 10 && !RegExp(r'[。！？]$').hasMatch(line)) {
        segments.add(Segment(
          id: 'seg_$i',
          text: line,
          type: SegmentType.transition,
          needsIndent: false,
        ));
        continue;
      }

      // 默认为叙述
      segments.add(Segment(
        id: 'seg_$i',
        text: line,
        type: SegmentType.narration,
        needsIndent: true,
      ));
    }

    return SmartSegmentResult(
      segments: segments,
      detectedSpeakers: detectedSpeakers.toSet().toList(),
      dialogueCount: dialogueCount,
      innerThoughtCount: innerThoughtCount,
    );
  }

  /// 提取对话
  List<Segment> _extractDialogue(String line, int baseIndex) {
    final segments = <Segment>[];
    var offset = 0;

    // 在原始文本上搜索所有引号对的匹配位置
    final ranges = <_QuoteMatch>[];

    for (final pair in _quotePairs) {
      var searchStart = 0;
      while (searchStart < line.length) {
        final s = line.indexOf(pair.$1, searchStart);
        if (s == -1) break;
        final e = line.indexOf(pair.$2, s + pair.$1.length);
        if (e == -1) break;
        ranges.add(_QuoteMatch(s, e, pair.$1, pair.$2));
        searchStart = e + pair.$2.length;
      }
    }

    if (ranges.isEmpty) return [];

    // 按起始位置排序
    ranges.sort((a, b) => a.start.compareTo(b.start));

    // 处理匹配的引号范围，跳过重叠
    var lastEnd = 0;
    for (final range in ranges) {
      if (range.start < lastEnd) continue;

      final beforeQuote = line.substring(lastEnd, range.start);
      final dialogueContent =
          line.substring(range.start + range.open.length, range.end);

      if (beforeQuote.trim().isNotEmpty) {
        segments.add(Segment(
          id: 'seg_${baseIndex}_${offset++}',
          text: beforeQuote.trim(),
          type: SegmentType.narration,
          needsIndent: false,
        ));
      }

      segments.add(Segment(
        id: 'seg_${baseIndex}_${offset++}',
        text: '${range.open}$dialogueContent${range.close}',
        type: SegmentType.dialogue,
        needsIndent: true,
        speakerId: _extractSpeaker(beforeQuote),
      ));

      lastEnd = range.end + range.close.length;
    }

    // 如果最后还有剩余内容
    if (lastEnd < line.length && segments.isNotEmpty) {
      final remaining = line.substring(lastEnd);
      if (remaining.trim().isNotEmpty) {
        segments.add(Segment(
          id: 'seg_${baseIndex}_${offset++}',
          text: remaining.trim(),
          type: SegmentType.narration,
          needsIndent: false,
        ));
      }
    }

    return segments;
  }

  /// 检测是否是心理活动
  bool _isInnerThought(String line) {
    for (final marker in _innerThoughtMarkers) {
      if (line.contains(marker)) {
        return true;
      }
    }
    return false;
  }

  /// 提取说话人
  String? _extractSpeaker(String text) {
    // 简单实现：提取"说"字前面的词
    final match = RegExp(r'(\S+)(说|道|问|答)').firstMatch(text);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  /// 自动添加对话引号
  String addDialogueQuotes(String text, int cursorPosition) {
    // 检测触发词
    final triggers = ['说', '道', '问', '答', '笑道', '叹道'];

    for (final trigger in triggers) {
      final triggerIndex = text.lastIndexOf(trigger, cursorPosition);
      if (triggerIndex != -1 && triggerIndex > cursorPosition - 10) {
        // 在触发词附近，添加引号
        final afterTrigger = text.substring(triggerIndex + trigger.length);

        // 如果后面没有引号，添加
        if (afterTrigger.isNotEmpty && !afterTrigger.startsWith(RegExp(r'["「『]'))) {
          return '${text.substring(0, cursorPosition)}"${text.substring(cursorPosition)}"';
        }
      }
    }

    return text;
  }

  /// 格式化文本（添加首行缩进）
  String formatWithIndent(String text, {int indentSpaces = 2}) {
    final indent = '　' * indentSpaces; // 使用全角空格
    final lines = text.split(RegExp(r'\n+'));

    return lines.map((line) {
      line = line.trim();
      if (line.isEmpty) return '';

      // 对话已经有引号开头，不需要额外缩进
      if (line.startsWith(RegExp(r'["「『]'))) {
        return indent + line;
      }

      return indent + line;
    }).join('\n');
  }

  /// 清理多余空行
  String cleanupEmptyLines(String text) {
    // 移除连续的空行，最多保留一个
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  /// 统一标点符号
  String unifyPunctuation(String text) {
    return text
        .replaceAll('。。', '。')
        .replaceAll('，，', '，')
        .replaceAll('！！', '！')
        .replaceAll('？？', '？')
        .replaceAll('……', '……')
        .replaceAll(RegExp(r'\.{3,}'), '……');
  }
}

class _QuoteMatch {
  final int start;
  final int end;
  final String open;
  final String close;
  _QuoteMatch(this.start, this.end, this.open, this.close);
}
