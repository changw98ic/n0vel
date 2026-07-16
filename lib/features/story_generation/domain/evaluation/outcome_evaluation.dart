/// Terminal state observed by the experiment harness for one logical trial.
enum TrialTerminalState { accepted, blocked, rejected, conflict, failed }

/// Frozen success contract attached to a versioned evaluation scenario.
class ExpectedTrialOutcome {
  const ExpectedTrialOutcome({
    required this.terminalState,
    this.requiredFailureCodes = const {},
    this.allowedAdditionalFailureCodes = const {},
    this.forbiddenFailureCodes = const {},
    required this.acceptExpected,
    this.forbiddenSideEffects = const {},
  });

  final TrialTerminalState terminalState;
  final Set<String> requiredFailureCodes;
  final Set<String> allowedAdditionalFailureCodes;
  final Set<String> forbiddenFailureCodes;
  final bool acceptExpected;
  final Set<String> forbiddenSideEffects;
}

/// Evidence reported by the production path for one logical trial.
class ActualTrialOutcome {
  const ActualTrialOutcome({
    required this.terminalState,
    this.failureCodes = const {},
    required this.accepted,
    this.sideEffectCounts = const {},
    required this.evidenceComplete,
  });

  final TrialTerminalState terminalState;
  final Set<String> failureCodes;
  final bool accepted;
  final Map<String, int> sideEffectCounts;
  final bool evidenceComplete;
}

enum OutcomeViolation {
  terminalStateMismatch,
  missingRequiredFailureCode,
  unexpectedFailureCode,
  forbiddenFailureCode,
  acceptMismatch,
  forbiddenSideEffect,
  incompleteEvidence,
}

class OutcomeComparison {
  const OutcomeComparison({
    required this.violations,
    required this.missingRequiredFailureCodes,
    required this.unexpectedFailureCodes,
    required this.presentForbiddenFailureCodes,
    required this.observedForbiddenSideEffects,
  });

  final Set<OutcomeViolation> violations;
  final Set<String> missingRequiredFailureCodes;
  final Set<String> unexpectedFailureCodes;
  final Set<String> presentForbiddenFailureCodes;
  final Map<String, int> observedForbiddenSideEffects;

  bool get isHardPass => violations.isEmpty;
}

/// Deterministic, fail-closed comparison of actual and expected trial outcome.
class ExpectedOutcomeComparator {
  const ExpectedOutcomeComparator();

  /// Frozen identity for the fail-closed expected/actual outcome contract.
  ///
  /// Evaluation bundles include this release alongside the safety and
  /// transaction authorities so a report cannot silently change what
  /// "expected blocked" means without changing its release membership.
  static const releaseHash =
      '2c84f3bb9c63e5e73121c57dc0f5c0ce892ec99fd463f9b1ffcad0b4ae267972';

  OutcomeComparison compare({
    required ExpectedTrialOutcome expected,
    required ActualTrialOutcome actual,
  }) {
    final violations = <OutcomeViolation>{};
    if (actual.terminalState != expected.terminalState) {
      violations.add(OutcomeViolation.terminalStateMismatch);
    }

    final missingRequired = expected.requiredFailureCodes.difference(
      actual.failureCodes,
    );
    if (missingRequired.isNotEmpty) {
      violations.add(OutcomeViolation.missingRequiredFailureCode);
    }

    final permittedFailureCodes = <String>{
      ...expected.requiredFailureCodes,
      ...expected.allowedAdditionalFailureCodes,
    };
    final unexpected = actual.failureCodes.difference(permittedFailureCodes);
    if (unexpected.isNotEmpty) {
      violations.add(OutcomeViolation.unexpectedFailureCode);
    }

    final forbidden = actual.failureCodes.intersection(
      expected.forbiddenFailureCodes,
    );
    if (forbidden.isNotEmpty) {
      violations.add(OutcomeViolation.forbiddenFailureCode);
    }

    if (actual.accepted != expected.acceptExpected) {
      violations.add(OutcomeViolation.acceptMismatch);
    }

    final observedForbiddenSideEffects = <String, int>{};
    for (final sideEffect in expected.forbiddenSideEffects) {
      final count = actual.sideEffectCounts[sideEffect] ?? 0;
      if (count != 0) {
        observedForbiddenSideEffects[sideEffect] = count;
      }
    }
    if (observedForbiddenSideEffects.isNotEmpty) {
      violations.add(OutcomeViolation.forbiddenSideEffect);
    }

    if (!actual.evidenceComplete) {
      violations.add(OutcomeViolation.incompleteEvidence);
    }

    return OutcomeComparison(
      violations: Set.unmodifiable(violations),
      missingRequiredFailureCodes: Set.unmodifiable(missingRequired),
      unexpectedFailureCodes: Set.unmodifiable(unexpected),
      presentForbiddenFailureCodes: Set.unmodifiable(forbidden),
      observedForbiddenSideEffects: Map.unmodifiable(
        observedForbiddenSideEffects,
      ),
    );
  }
}
