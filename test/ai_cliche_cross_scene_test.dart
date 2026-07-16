import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/ai_cliche_detector.dart';

void main() {
  late AiClicheDetector detector;

  setUp(() => detector = AiClicheDetector());

  group('self repeat', () {
    test('detects a nearby repeated Chinese word in one sentence', () {
      final report = detector.detect('水痕蜿蜒如线，蜿蜒出几寸。');

      final findings = report.findingsOf(AiClicheKind.selfRepeat);
      expect(findings, hasLength(1));
      expect(findings.single.matched, '蜿蜒');
      expect(findings.single.position, greaterThanOrEqualTo(0));
      expect(findings.single.context, contains('蜿蜒如线，蜿蜒'));
    });

    test('ignores common function phrases and repeated character names', () {
      final report = detector.detect('苏薇抬头看向窗外，苏薇没有回答，因为没有足够证据。');

      expect(report.findingsOf(AiClicheKind.selfRepeat), isEmpty);
    });

    test('ignores a character name repeated away from clause boundaries', () {
      final report = detector.detect('陈安看着陈安手里的旧照片，陈安始终没有开口。');

      expect(report.findingsOf(AiClicheKind.selfRepeat), isEmpty);
    });

    test('summary includes the self-repeat category', () {
      final report = detector.detect('水痕蜿蜒如线，蜿蜒出几寸。');

      expect(report.toSummaryText(), contains(AiClicheKind.selfRepeat.label));
    });
  });

  group('cross-scene templates', () {
    test('detects approximate reuse in at least two different scenes', () {
      final report = detector.detectAcrossScenes({
        'scene-a': '他的目光越过桌面，钉在门锁上。她把声音压低，只留一线气息。',
        'scene-b': '她的目光像冷针一样钉住屏幕。他回答时声音极低，几乎听不见。',
        'scene-c': '声音被风撕得发颤。握绳的指节已经发白。',
        'scene-d': '话音被夜风撕扯得微微发颤，攥刀的指节一点点泛白。',
      });

      final findings = report.findingsOf(AiClicheKind.crossSceneTemplate);
      expect(
        findings.map((finding) => finding.matched),
        containsAll(<String>['目光…钉…', '声音…压低/极低', '声音被风撕得发颤', '指节发白/泛白']),
      );
      for (final finding in findings) {
        final mentionedSceneIds = <String>[
          'scene-a',
          'scene-b',
          'scene-c',
          'scene-d',
        ].where(finding.context.contains).length;
        expect(mentionedSceneIds, greaterThanOrEqualTo(2));
      }
    });

    test('does not flag a template repeated only inside one scene', () {
      final report = detector.detectAcrossScenes({
        'scene-a': '声音被风撕得发颤。过了片刻，声音又被风撕得发颤。',
        'scene-b': '她关上门，沿着楼梯走了下去。',
      });

      expect(report.findingsOf(AiClicheKind.crossSceneTemplate), isEmpty);
    });

    test('summary includes the cross-scene template category', () {
      final report = detector.detectAcrossScenes({
        'scene-a': '她把声音压低，只说了两个字。',
        'scene-b': '他压低声音，不让门外的人听见。',
      });

      expect(
        report.toSummaryText(),
        contains(AiClicheKind.crossSceneTemplate.label),
      );
    });
  });

  group('cross-scene repeated fragments', () {
    test('detects the same long fragment across punctuation differences', () {
      final report = detector.detectAcrossScenes({
        'scene-a': '雨水顺着破旧窗框流下来，像一条细线，切开桌上的灰尘。',
        'scene-b': '雨水顺着破旧窗框流下来 像一条细线——切开桌上的灰尘！',
        'scene-c': '她合上记录本，独自走进没有灯的楼梯间。',
      });

      final findings = report.findingsOf(
        AiClicheKind.crossSceneRepeatedFragment,
      );
      expect(findings, hasLength(1));
      expect(findings.single.matched, '雨水顺着破旧窗框流下来像一条细线切开桌上的灰尘');
      expect(
        findings.single.context,
        contains('scene-a「雨水顺着破旧窗框流下来，像一条细线，切开桌上的灰尘」'),
      );
      expect(
        findings.single.context,
        contains('scene-b「雨水顺着破旧窗框流下来 像一条细线——切开桌上的灰尘」'),
      );
    });

    test('ignores short common fragments shared by different scenes', () {
      final report = detector.detectAcrossScenes({
        'scene-a': '他没有说话，只把门轻轻关上。',
        'scene-b': '他没有说话，转身走进倾盆大雨。',
      });

      expect(
        report.findingsOf(AiClicheKind.crossSceneRepeatedFragment),
        isEmpty,
      );
    });

    test('ignores a long fragment repeated only inside one scene', () {
      const fragment = '潮湿的风从破窗灌进来，把桌上的旧报纸一页页掀起。';
      final report = detector.detectAcrossScenes({
        'scene-a': '$fragment灯灭了。过了一会儿，$fragment',
        'scene-b': '她听见电梯停在楼下，便收起钥匙离开房间。',
      });

      expect(
        report.findingsOf(AiClicheKind.crossSceneRepeatedFragment),
        isEmpty,
      );
    });

    test('merges overlapping n-grams from one reused sentence', () {
      final report = detector.detectAcrossScenes({
        'scene-a': '门外传来脚步。潮湿的风从破窗灌进来，把桌上的旧报纸一页页掀起。灯忽然灭了。',
        'scene-b': '她没有回头。潮湿的风，从破窗灌进来；把桌上的旧报纸一页页掀起！走廊随即安静。',
      });

      final findings = report.findingsOf(
        AiClicheKind.crossSceneRepeatedFragment,
      );
      expect(findings, hasLength(1));
      expect(findings.single.matched, '潮湿的风从破窗灌进来把桌上的旧报纸一页页掀起');
      expect(findings.single.context, contains('scene-a'));
      expect(findings.single.context, contains('scene-b'));
    });
  });
}
