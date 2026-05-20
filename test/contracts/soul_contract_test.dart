import 'package:novel_writer/features/story_generation/domain/contracts/soul_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoulContract', () {
    late SoulContract contract;

    setUp(() {
      contract = const SoulContract(
        coreValues: ['保护弱者', '诚实'],
        forbiddenActions: ['杀人', '背叛朋友'],
        emotionalRange: EmotionalContract(
          maxIntensity: 0.8,
          forbiddenEmotions: ['狂喜', '暴怒'],
        ),
        decisionPattern: DecisionPattern.principled,
        unbreakablePromises: ['守护林家'],
        identityAnchors: ['冷静的侦探'],
      );
    });

    test('no violations for valid action', () {
      final violations = contract.validate('调查线索');
      expect(violations, isEmpty);
    });

    test('catches forbidden action (exact)', () {
      final violations = contract.validate('杀人灭口');
      expect(violations, hasLength(1));
      expect(violations[0].rule, contains('forbidden'));
      expect(violations[0].severity, 1.0);
    });

    test('catches forbidden action (substring)', () {
      final violations = contract.validate('决定背叛朋友');
      expect(violations, hasLength(1));
      expect(violations[0].rule, contains('forbidden:背叛朋友'));
    });

    test('catches core value anti-pattern', () {
      final violations = contract.validate('选择不诚实回答');
      expect(violations, anyElement(predicate<SoulViolation>(
        (v) => v.rule == 'coreValue:诚实',
      )));
    });

    test('catches forbidden emotion', () {
      final violations = contract.validate('感到暴怒涌上心头');
      expect(violations, anyElement(predicate<SoulViolation>(
        (v) => v.rule == 'emotion:暴怒',
      )));
    });

    test('catches broken promise', () {
      final violations = contract.validate('违背守护林家');
      expect(violations, anyElement(predicate<SoulViolation>(
        (v) => v.rule == 'promise:守护林家',
      )));
    });

    test('empty contract allows everything', () {
      const empty = SoulContract();
      expect(empty.validate('做任何事'), isEmpty);
    });

    test('round-trip serialization', () {
      final json = contract.toJson();
      final restored = SoulContract.fromJson(json);

      expect(restored.coreValues, ['保护弱者', '诚实']);
      expect(restored.forbiddenActions, ['杀人', '背叛朋友']);
      expect(restored.decisionPattern, DecisionPattern.principled);
      expect(restored.emotionalRange.maxIntensity, 0.8);
      expect(restored.emotionalRange.forbiddenEmotions, ['狂喜', '暴怒']);
      expect(restored.unbreakablePromises, ['守护林家']);
      expect(restored.identityAnchors, ['冷静的侦探']);
    });
  });

  group('DecisionPattern', () {
    test('has all four patterns', () {
      expect(DecisionPattern.values, hasLength(4));
    });
  });
}
