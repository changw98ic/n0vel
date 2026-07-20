import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/imitation_intent_linter.dart';

void main() {
  group('ImitationIntentLinter', () {
    late ImitationIntentLinter linter;

    setUp(() {
      linter = ImitationIntentLinter(
        protectedCreatorTokens: const ['林岫舟'],
        protectedTitleTokens: const ['星湾纪事'],
      );
    });

    test('rejects named creator imitation targets', () {
      final result = linter.lint('请模仿林岫舟的文风写一章。');

      expect(result.disposition, ImitationIntentDisposition.rejected);
      expect(
        result.reasonCodes,
        contains(ImitationIntentReasonCode.protectedCreatorToken),
      );
      expect(result.sanitizedText, isNot(contains('林岫舟')));
    });

    test('rejects named work imitation targets', () {
      final result = linter.lint('整体要像《星湾纪事》，节奏也照着来。');

      expect(result.disposition, ImitationIntentDisposition.rejected);
      expect(
        result.reasonCodes,
        contains(ImitationIntentReasonCode.protectedTitleToken),
      );
      expect(result.sanitizedText, isNot(contains('星湾纪事')));
    });

    test('manual-reviews synonym-based style-copy requests', () {
      final result = linter.lint('不要直说模仿，按那本书的气口、顿挫、句式骨架换同义词续一段。');

      expect(result.disposition, ImitationIntentDisposition.manualReview);
      expect(
        result.reasonCodes,
        contains(ImitationIntentReasonCode.explicitContinuationIntent),
      );
    });

    test('manual-reviews continuing from a reference sentence', () {
      final result = linter.lint('以上面参考原句为开头，保持同样措辞和句式继续写。');

      expect(result.disposition, ImitationIntentDisposition.manualReview);
      expect(
        result.reasonCodes,
        contains(ImitationIntentReasonCode.explicitContinuationIntent),
      );
      expect(result.requiresHumanReview, isTrue);
    });

    test(
      'abstracts legal reference mentions and removes names from prompt text',
      () {
        final result = linter.sanitizeFields(
          fields: const {'mechanism': '参考星湾纪事的信息释放，不要照抄名字或句子。'},
        );

        expect(
          result.result.disposition,
          ImitationIntentDisposition.abstracted,
        );
        expect(result.droppedFieldKeys, contains('mechanism'));
        expect(result.result.sanitizedText, isNot(contains('星湾纪事')));
        expect(result.result.sanitizedText, isNot(contains('林岫舟')));
      },
    );

    test('allows user-owned project voice without author imitation labels', () {
      final result = ImitationIntentLinter().lintStructured(
        const StructuredImitationIntentInput(
          text: '使用我自己的样稿建立项目声纹：短句、低解释、对白留白。',
          ownership: ImitationSourceOwnership.userOwned,
        ),
      );

      expect(result.disposition, ImitationIntentDisposition.allowed);
      expect(
        result.reasonCodes,
        contains(ImitationIntentReasonCode.userOwnedVoice),
      );
      expect(result.sanitizedText, contains('项目声纹'));
    });

    test('redacts protected labels even for an admitted user-owned voice', () {
      final result = linter.lintStructured(
        const StructuredImitationIntentInput(
          text: '用星湾纪事和林岫舟标记的自有样稿建立项目声纹。',
          ownership: ImitationSourceOwnership.userOwned,
        ),
      );

      expect(result.disposition, ImitationIntentDisposition.allowed);
      expect(result.canRender, isTrue);
      expect(result.sanitizedText, isNot(contains('星湾纪事')));
      expect(result.sanitizedText, isNot(contains('林岫舟')));
      expect(result.sanitizedText, contains('[受保护来源]'));
    });
  });
}
