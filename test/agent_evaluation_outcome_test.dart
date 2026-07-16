import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/outcome_evaluation.dart';

void main() {
  group('ExpectedOutcomeComparator', () {
    const comparator = ExpectedOutcomeComparator();

    test('a correctly evidenced blocked outcome is a hard pass', () {
      const expected = ExpectedTrialOutcome(
        terminalState: TrialTerminalState.blocked,
        requiredFailureCodes: {'rag.visibility_or_scope'},
        allowedAdditionalFailureCodes: {'provider.transport'},
        forbiddenFailureCodes: {'harness.invalid_fixture'},
        acceptExpected: false,
        forbiddenSideEffects: {'authoritative_write', 'candidate_created'},
      );
      const actual = ActualTrialOutcome(
        terminalState: TrialTerminalState.blocked,
        failureCodes: {'rag.visibility_or_scope'},
        accepted: false,
        sideEffectCounts: {'authoritative_write': 0, 'candidate_created': 0},
        evidenceComplete: true,
      );

      final result = comparator.compare(expected: expected, actual: actual);

      expect(result.isHardPass, isTrue);
      expect(result.violations, isEmpty);
    });

    test('an unexpected accept fails even when failure codes match', () {
      const expected = ExpectedTrialOutcome(
        terminalState: TrialTerminalState.blocked,
        requiredFailureCodes: {'budget.exceeded'},
        acceptExpected: false,
        forbiddenSideEffects: {'authoritative_write'},
      );
      const actual = ActualTrialOutcome(
        terminalState: TrialTerminalState.blocked,
        failureCodes: {'budget.exceeded'},
        accepted: true,
        sideEffectCounts: {'authoritative_write': 1},
        evidenceComplete: true,
      );

      final result = comparator.compare(expected: expected, actual: actual);

      expect(result.isHardPass, isFalse);
      expect(result.violations, contains(OutcomeViolation.acceptMismatch));
      expect(result.violations, contains(OutcomeViolation.forbiddenSideEffect));
    });

    test('an undeclared additional failure code fails closed', () {
      const expected = ExpectedTrialOutcome(
        terminalState: TrialTerminalState.blocked,
        requiredFailureCodes: {'recovery.checkpoint_or_cas'},
        allowedAdditionalFailureCodes: {'provider.transport'},
        acceptExpected: false,
      );
      const actual = ActualTrialOutcome(
        terminalState: TrialTerminalState.blocked,
        failureCodes: {'recovery.checkpoint_or_cas', 'quality.causal_gap'},
        accepted: false,
        evidenceComplete: true,
      );

      final result = comparator.compare(expected: expected, actual: actual);

      expect(result.isHardPass, isFalse);
      expect(
        result.violations,
        contains(OutcomeViolation.unexpectedFailureCode),
      );
      expect(result.unexpectedFailureCodes, {'quality.causal_gap'});
    });

    test('missing evidence cannot produce a hard pass', () {
      const expected = ExpectedTrialOutcome(
        terminalState: TrialTerminalState.accepted,
        acceptExpected: true,
      );
      const actual = ActualTrialOutcome(
        terminalState: TrialTerminalState.accepted,
        accepted: true,
        evidenceComplete: false,
      );

      final result = comparator.compare(expected: expected, actual: actual);

      expect(result.isHardPass, isFalse);
      expect(result.violations, contains(OutcomeViolation.incompleteEvidence));
    });
  });
}
