import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/role_agent_controller.dart';
import 'package:novel_writer/features/story_generation/domain/roleplay_models.dart';

void main() {
  // ---------------------------------------------------------------
  // toLegacyText
  // ---------------------------------------------------------------
  group('RolePromptAdapter.toLegacyText', () {
    test('empty packet returns empty string', () {
      final packet = RolePromptPacket(
        characterId: 'c1',
        characterName: 'Alice',
        characterRole: 'protagonist',
      );
      expect(RolePromptAdapter.toLegacyText(packet), isEmpty);
    });

    test('omits empty sections', () {
      final packet = RolePromptPacket(
        characterId: 'c1',
        characterName: 'Alice',
        characterRole: 'protagonist',
        currentFeeling: '焦虑不安',
        actionIntent: '寻找线索',
      );
      final text = RolePromptAdapter.toLegacyText(packet);

      expect(text, contains('【当前感受】\n焦虑不安'));
      expect(text, contains('【行动意图】\n寻找线索'));
      // Empty sections should NOT appear.
      expect(text, isNot(contains('【当前理解】')));
      expect(text, isNot(contains('【对他人的看法】')));
      expect(text, isNot(contains('【表层表现】')));
      expect(text, isNot(contains('【未出口念头】')));
      expect(text, isNot(contains('【对白倾向】')));
    });

    test('all fields populated produces all 7 sections', () {
      final packet = RolePromptPacket(
        characterId: 'c1',
        characterName: '林黛玉',
        characterRole: '女主角',
        currentUnderstanding: '理解内容',
        currentFeeling: '感受内容',
        viewOfOthers: '看法内容',
        surfaceBehavior: '表现内容',
        unspokenThoughts: '念头内容',
        actionIntent: '意图内容',
        dialogueTendency: '倾向内容',
      );
      final text = RolePromptAdapter.toLegacyText(packet);

      expect(text, contains('【当前理解】'));
      expect(text, contains('【当前感受】'));
      expect(text, contains('【对他人的看法】'));
      expect(text, contains('【表层表现】'));
      expect(text, contains('【未出口念头】'));
      expect(text, contains('【行动意图】'));
      expect(text, contains('【对白倾向】'));

      // Verify all 7 sections present by counting headers.
      final headerCount =
          RegExp(r'【[^】]+】').allMatches(text).length;
      expect(headerCount, 7);
    });

    test('sections separated by double newlines', () {
      final packet = RolePromptPacket(
        characterId: 'c1',
        characterName: 'Alice',
        characterRole: 'protagonist',
        currentUnderstanding: '第一段',
        currentFeeling: '第二段',
      );
      final text = RolePromptAdapter.toLegacyText(packet);

      // Two sections → one separator between them.
      expect(text, contains('】\n第一段\n\n【'));
      expect(text, isNot(contains('】\n第一段\n【'))); // not single newline
    });

    test('produces correctly formatted Chinese headers', () {
      final packet = RolePromptPacket(
        characterId: 'c1',
        characterName: '薛宝钗',
        characterRole: '女配角',
        currentUnderstanding: '她看到了那封信',
      );
      final text = RolePromptAdapter.toLegacyText(packet);

      // Each section must be: header line, then content on next line.
      expect(text, equals('【当前理解】\n她看到了那封信'));
    });

    test('legacy output structure preserves content integrity', () {
      const content = '这是一段包含特殊字符的内容：换行、逗号、句号。';
      final packet = RolePromptPacket(
        characterId: 'c1',
        characterName: 'Test',
        characterRole: 'test',
        surfaceBehavior: content,
      );
      final text = RolePromptAdapter.toLegacyText(packet);

      expect(text, contains(content));
      expect(text, startsWith('【表层表现】'));
    });
  });

  // ---------------------------------------------------------------
  // detectHiddenTruthLeakage
  // ---------------------------------------------------------------
  group('RolePromptAdapter.detectHiddenTruthLeakage', () {
    test('returns empty for clean text', () {
      const text = '她站在窗前，看着远方的山峦，心中充满了对未来的期待。';
      expect(RolePromptAdapter.detectHiddenTruthLeakage(text), isEmpty);
    });

    test('catches English pattern "actually"', () {
      const text = 'She actually knew the truth all along.';
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains('actually')), isTrue);
    });

    test('catches English pattern "hidden"', () {
      const text = 'He had a hidden motive for visiting.';
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains('hidden')), isTrue);
    });

    test('catches English pattern "secretly"', () {
      const text = 'She secretly watched from behind the curtain.';
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains('secretly')), isTrue);
    });

    test('catches English pattern "don\'t know"', () {
      const text = "She don't know what happened.";
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains("don'?t")), isTrue);
    });

    test('catches English pattern case-insensitively', () {
      const text = 'Actually she had no idea what was happening.';
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains('actually')), isTrue);
    });

    test('catches English pattern "unknown to"', () {
      const text = 'Unknown to her, the door was already open.';
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains('unknown')), isTrue);
    });

    test('catches Chinese pattern 其实', () {
      const text = '其实他已经知道了一切。';
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains('其实')), isTrue);
    });

    test('catches Chinese pattern 暗中', () {
      const text = '他暗中观察着一切。';
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains('暗中')), isTrue);
    });

    test('catches Chinese pattern 不知道', () {
      const text = '她不知道事情的真相。';
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains('不知道')), isTrue);
    });

    test('catches multiple violations at once', () {
      const text = '其实她 secretly 已经知道了，但 unknown to him 她不说。';
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations.length, greaterThanOrEqualTo(3));
    });

    test('returns empty for text with partial but non-matching words', () {
      // "actual" without following space, "hide" not "hidden", etc.
      const text = '实际上这件事的实际情况很复杂。暗中观察';
      // "其实" not present, "暗中" IS present — so 1 violation expected
      final violations = RolePromptAdapter.detectHiddenTruthLeakage(text);
      expect(violations.length, 1);
      expect(violations.first, contains('暗中'));
    });
  });

  // ---------------------------------------------------------------
  // Round-trip: packet → legacy text → verify structure preserved
  // ---------------------------------------------------------------
  group('RolePromptAdapter round-trip', () {
    test('packet to legacy text preserves all non-empty field content', () {
      final packet = RolePromptPacket(
        characterId: 'c1',
        characterName: '贾宝玉',
        characterRole: '主角',
        currentUnderstanding: '他看到黛玉在哭',
        currentFeeling: '心中一阵酸楚',
        viewOfOthers: '觉得宝钗太过圆滑',
        unspokenThoughts: '也许不该来这里',
        actionIntent: '想安慰黛玉',
      );
      final text = RolePromptAdapter.toLegacyText(packet);

      // Every field value must appear in the text.
      expect(text, contains('他看到黛玉在哭'));
      expect(text, contains('心中一阵酸楚'));
      expect(text, contains('觉得宝钗太过圆滑'));
      expect(text, contains('也许不该来这里'));
      expect(text, contains('想安慰黛玉'));

      // Structure: each section is header + newline + content.
      final sections = text.split('\n\n');
      expect(sections.length, 5);

      for (final section in sections) {
        final lines = section.split('\n');
        expect(lines.length, 2);
        expect(lines.first, startsWith('【'));
        expect(lines.first, endsWith('】'));
        expect(lines.last, isNotEmpty);
      }
    });

    test('legacy text is parseable — headers and values extractable', () {
      final packet = RolePromptPacket(
        characterId: 'c1',
        characterName: 'Test',
        characterRole: 'test',
        currentFeeling: '好奇',
        dialogueTendency: '谨慎措辞',
      );
      final text = RolePromptAdapter.toLegacyText(packet);

      // A downstream consumer should be able to split on \n\n,
      // then extract header and value from each section.
      final sections = text.split('\n\n');
      final parsed = <String, String>{};
      for (final section in sections) {
        final newlinePos = section.indexOf('\n');
        if (newlinePos < 0) continue;
        final header = section.substring(0, newlinePos);
        final value = section.substring(newlinePos + 1);
        parsed[header] = value;
      }

      expect(parsed['【当前感受】'], '好奇');
      expect(parsed['【对白倾向】'], '谨慎措辞');
      expect(parsed.length, 2);
    });
  });
}
