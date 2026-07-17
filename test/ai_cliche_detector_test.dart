import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/ai_cliche_detector.dart';

void main() {
  late AiClicheDetector detector;

  setUp(() => detector = AiClicheDetector());

  group('detect', () {
    test('clean text has no findings', () {
      final report = detector.detect('苏薇走进房间，环顾四周。桌上放着一份文件。');
      expect(report.findings, isEmpty);
      expect(report.hasIssues, isFalse);
      expect(report.isSevere, isFalse);
    });

    test('empty text has no findings', () {
      final report = detector.detect('');
      expect(report.findings, isEmpty);
      expect(report.totalWordCount, 0);
      expect(report.clicheDensity, 0.0);
    });

    test('detects cliched phrase 心中一凛', () {
      final report = detector.detect('他心中一凛，感觉事情不对。');
      expect(report.findings, isNotEmpty);
      expect(report.findings.any((f) => f.matched == '心中一凛'), isTrue);
    });

    test('detects multiple cliched phrases', () {
      final report = detector.detect('她心中一凛。他恍然大悟。此情此景令人不禁感慨。');
      final phrases = report.findingsOf(AiClicheKind.clichedPhrase);
      expect(phrases.length, greaterThanOrEqualTo(3));
    });

    test('detects cliched phrase with position and context', () {
      final report = detector.detect('这段文字在中间出现不由自主的表述。');
      final finding = report.findings.firstWhere((f) => f.matched == '不由自主');
      expect(finding.position, greaterThanOrEqualTo(0));
      expect(finding.context, contains('不由自主'));
    });

    test('detects repeated adjectives (same X的 appearing >2 times)', () {
      final report = detector.detect('美丽的花。美丽的树。美丽的人。美丽的风景。');
      final adjs = report.findingsOf(AiClicheKind.repeatedAdjective);
      expect(adjs, isNotEmpty);
      expect(adjs.any((f) => f.matched.contains('美丽的')), isTrue);
    });

    test('no repeated adjective finding when count <= 2', () {
      final report = detector.detect('美丽的花。美丽的树。其他内容。');
      final adjs = report.findingsOf(AiClicheKind.repeatedAdjective);
      expect(adjs, isEmpty);
    });

    test('detects short sentence run (5+ consecutive short sentences)', () {
      const shortPara = '下雨了。起风了。天黑了。人走了。灯灭了。路远了。';
      final report = detector.detect(shortPara);
      final runs = report.findingsOf(AiClicheKind.shortSentenceRun);
      expect(runs, isNotEmpty);
    });

    test('no short sentence run when sentences are varied', () {
      const varied = '这是第一句比较长的句子，有十几个汉字。短句。这也是一段中等长度的句子，包含一些内容。';
      final report = detector.detect(varied);
      final runs = report.findingsOf(AiClicheKind.shortSentenceRun);
      expect(runs, isEmpty);
    });

    test('detects excessive adverb (>=3 occurrences)', () {
      final report = detector.detect('他渐渐地走近。她渐渐地放松。天空渐渐地亮了。一切渐渐地恢复。');
      final adverbs = report.findingsOf(AiClicheKind.excessiveAdverb);
      expect(adverbs, isNotEmpty);
      expect(adverbs.any((f) => f.matched == '渐渐地'), isTrue);
    });

    test('no excessive adverb finding when count < 3', () {
      final report = detector.detect('他渐渐地走近了。然后她渐渐地放松了。');
      final adverbs = report.findingsOf(AiClicheKind.excessiveAdverb);
      expect(adverbs, isEmpty);
    });

    test('clicheDensity is findings per Chinese char', () {
      final report = detector.detect('他心中一凛，感觉不对。');
      if (report.findings.isNotEmpty) {
        expect(report.clicheDensity, greaterThan(0));
        expect(
          report.clicheDensity,
          closeTo(report.findings.length / report.totalWordCount, 0.001),
        );
      }
    });

    test('isSevere when density > 0.02', () {
      final buf = StringBuffer();
      for (var i = 0; i < 20; i++) {
        buf.write('他心中一凛，不由自主地感到害怕。');
      }
      final report = detector.detect(buf.toString());
      expect(report.isSevere, isTrue);
    });

    test('toSummaryText returns clean message when no issues', () {
      final report = detector.detect('正常的文字内容。没有问题。');
      expect(report.toSummaryText(), contains('未检测到'));
    });

    test('toSummaryText lists finding categories when issues exist', () {
      final report = detector.detect('他心中一凛，不由自主地害怕。');
      if (report.hasIssues) {
        final text = report.toSummaryText();
        expect(text, contains('检测到'));
      }
    });

    test('findingsOf filters by kind correctly', () {
      final report = detector.detect('他心中一凛。她恍然大悟。');
      final phrases = report.findingsOf(AiClicheKind.clichedPhrase);
      final adjs = report.findingsOf(AiClicheKind.repeatedAdjective);
      expect(phrases, isNotEmpty);
      expect(
        phrases.every((f) => f.kind == AiClicheKind.clichedPhrase),
        isTrue,
      );
      expect(
        adjs.every((f) => f.kind == AiClicheKind.repeatedAdjective),
        isTrue,
      );
    });
  });
}
