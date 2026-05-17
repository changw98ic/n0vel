import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/prose_style_analyzer.dart';

void main() {
  late ProseStyleAnalyzer analyzer;

  setUp(() => analyzer = ProseStyleAnalyzer());

  group('analyze', () {
    test('empty string returns zeroed fingerprint', () {
      final fp = analyzer.analyze('');
      expect(fp.totalChineseChars, 0);
      expect(fp.sentenceCount, 0);
      expect(fp.paragraphCount, 0);
      expect(fp.dialogueRatio, 0.0);
      expect(fp.avgSentenceLength, 0.0);
    });

    test('pure non-Chinese text has zero chinese chars', () {
      final fp = analyzer.analyze('Hello world! This is a test.');
      expect(fp.totalChineseChars, 0);
      expect(fp.sentenceCount, 0);
    });

    test('counts Chinese characters correctly', () {
      final fp = analyzer.analyze('这是三个汉字');
      expect(fp.totalChineseChars, 6);
    });

    test('splits sentences on Chinese punctuation', () {
      final fp = analyzer.analyze('第一句话。第二句话！第三句话？');
      expect(fp.sentenceCount, 3);
    });

    test('counts dialogue characters inside 「」', () {
      final text = '他说：「你好世界」然后走了。';
      final fp = analyzer.analyze(text);
      expect(fp.dialogueRatio, greaterThan(0));
      expect(fp.dialogueRatio, lessThan(1));
    });

    test('counts dialogue characters inside ""', () {
      final text = '她说"今天天气不错"就离开了。';
      final fp = analyzer.analyze(text);
      expect(fp.dialogueRatio, greaterThan(0));
    });

    test('punctuation ratios include 。！？…；', () {
      final text = '陈述句。感叹句！疑问句？省略号……分号；';
      final fp = analyzer.analyze(text);
      expect(fp.punctuationRatios, isNotEmpty);
      expect(fp.statementRatio, greaterThan(0));
      expect(fp.exclamationRatio, greaterThan(0));
      expect(fp.questionRatio, greaterThan(0));
      expect(fp.ellipsisRatio, greaterThan(0));
    });

    test('ellipsis …… counts as one not two', () {
      final text = '他说了一句话……';
      final fp = analyzer.analyze(text);
      expect(fp.ellipsisRatio, greaterThan(0));
    });

    test('splits paragraphs on double newline', () {
      final text = '第一段内容。\n\n第二段内容。\n\n第三段内容。';
      final fp = analyzer.analyze(text);
      expect(fp.paragraphCount, 3);
    });

    test('avgSentenceLength for mixed text', () {
      final text = '短句。这是一句比较长的话，包含了更多汉字。';
      final fp = analyzer.analyze(text);
      expect(fp.avgSentenceLength, greaterThan(0));
      expect(fp.sentenceLengthVariance, greaterThan(0));
    });

    test('single Chinese character', () {
      final fp = analyzer.analyze('好');
      expect(fp.totalChineseChars, 1);
      expect(fp.sentenceCount, 1);
    });

    test('extracts adjective patterns X的', () {
      final text = '美丽的花朵在灿烂的阳光下。';
      final fp = analyzer.analyze(text);
      expect(fp.topAdjectives, isNotEmpty);
    });

    test('exclamation with half-width ! detected', () {
      final text = '他大喊stop!';
      final fp = analyzer.analyze(text);
      expect(fp.exclamationRatio, greaterThan(0));
    });

    test('question with half-width ? detected', () {
      final text = '他在想what?';
      final fp = analyzer.analyze(text);
      expect(fp.questionRatio, greaterThan(0));
    });
  });

  group('similarityTo', () {
    test('identical texts score 1.0', () {
      const text = '这是一段测试文本。包含对话「你好」和叙述。';
      final fp = analyzer.analyze(text);
      expect(analyzer.similarityTo(fp, fp), closeTo(1.0, 0.01));
    });

    test('different texts score below 1.0', () {
      const textA = '短文。短文。短文。';
      const textB = '这是一段非常长的文本，包含了许多汉字和标点符号，用于测试相似度计算功能的准确性。对话：「你好世界」';
      final fpA = analyzer.analyze(textA);
      final fpB = analyzer.analyze(textB);
      expect(analyzer.similarityTo(fpA, fpB), lessThan(1.0));
    });

    test('score is symmetric', () {
      const textA = '他说：「走吧」。她回答：「好的」。';
      const textB = '叙述段落。没有对话。只有描写。';
      final fpA = analyzer.analyze(textA);
      final fpB = analyzer.analyze(textB);
      expect(
        analyzer.similarityTo(fpA, fpB),
        closeTo(analyzer.similarityTo(fpB, fpA), 0.001),
      );
    });

    test('empty fingerprints score high on similarity', () {
      final fpA = analyzer.analyze('');
      final fpB = analyzer.analyze('');
      expect(analyzer.similarityTo(fpA, fpB), closeTo(1.0, 0.01));
    });
  });

  group('compare', () {
    test('identical texts have no divergence points', () {
      const text = '这是一段测试文本。';
      final report = analyzer.compare(
        generatedText: text,
        referenceText: text,
        referenceLabel: 'self',
      );
      expect(report.divergencePoints, isEmpty);
      expect(report.similarityScore, closeTo(1.0, 0.01));
    });

    test('different dialogue ratios produce divergence', () {
      const generated = '纯叙述文本没有对话。只有描述。';
      const reference = '「你好」「再见」纯对话文本。';
      final report = analyzer.compare(
        generatedText: generated,
        referenceText: reference,
      );
      final dialogueDiv = report.divergencePoints
          .where((d) => d.metric == '对话比率')
          .toList();
      expect(dialogueDiv, isNotEmpty);
    });

    test('report contains reference label', () {
      final report = analyzer.compare(
        generatedText: '测试文本。',
        referenceText: '参考文本。',
        referenceLabel: '经典文学',
      );
      expect(report.referenceLabel, '经典文学');
    });

    test('toSummaryText is non-empty for divergent texts', () {
      final report = analyzer.compare(
        generatedText: '短。',
        referenceText: '这是一段非常长的参考文本，包含大量汉字和多种句式。',
        referenceLabel: '参考',
      );
      expect(report.toSummaryText(), isNotEmpty);
    });
  });

  group('referenceFingerprintFromJsonl', () {
    test('missing file returns zeroed fingerprint', () {
      final fp = analyzer.referenceFingerprintFromJsonl(
        '/tmp/cpb_test_nonexistent_${DateTime.now().millisecondsSinceEpoch}.jsonl',
      );
      expect(fp.totalChineseChars, 0);
    });

    test('valid jsonl produces fingerprint', () async {
      final dir = await Directory.systemTemp.createTemp('cpb_prose_test_');
      final file = File('${dir.path}/ref.jsonl');
      await file.writeAsString(
        '{"text":"这是一段参考文本。包含对话「你好」。"}\n'
        '{"text":"第二段参考文本。"}\n',
      );
      addTearDown(() => dir.delete(recursive: true));

      final fp = analyzer.referenceFingerprintFromJsonl(file.path);
      expect(fp.totalChineseChars, greaterThan(0));
      expect(fp.sentenceCount, greaterThan(0));
    });

    test('empty lines in jsonl are skipped', () async {
      final dir = await Directory.systemTemp.createTemp('cpb_prose_test_');
      final file = File('${dir.path}/ref.jsonl');
      await file.writeAsString(
        '\n{"text":"有效文本。"}\n\n\n{"text":"更多文本。"}\n',
      );
      addTearDown(() => dir.delete(recursive: true));

      final fp = analyzer.referenceFingerprintFromJsonl(file.path);
      expect(fp.totalChineseChars, greaterThan(0));
    });

    test('invalid json lines are skipped', () async {
      final dir = await Directory.systemTemp.createTemp('cpb_prose_test_');
      final file = File('${dir.path}/ref.jsonl');
      await file.writeAsString(
        'not json\n{"text":"有效文本。"}\n{"bad": true}\n',
      );
      addTearDown(() => dir.delete(recursive: true));

      final fp = analyzer.referenceFingerprintFromJsonl(file.path);
      expect(fp.totalChineseChars, greaterThan(0));
    });
  });
}
