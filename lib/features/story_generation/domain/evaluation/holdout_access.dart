enum HoldoutAccessStatus { granted, denied }

enum HoldoutDenialReason {
  unregisteredChallenger,
  repeatedProbe,
  budgetExhausted,
}

class HoldoutAccessDecision {
  const HoldoutAccessDecision._({
    required this.status,
    this.confirmationToken,
    this.denialReason,
  });

  const HoldoutAccessDecision.granted(String token)
    : this._(status: HoldoutAccessStatus.granted, confirmationToken: token);

  const HoldoutAccessDecision.denied(HoldoutDenialReason reason)
    : this._(status: HoldoutAccessStatus.denied, denialReason: reason);

  final HoldoutAccessStatus status;
  final String? confirmationToken;
  final HoldoutDenialReason? denialReason;
}

class HoldoutConfirmationReport {
  const HoldoutConfirmationReport({
    required this.familyId,
    required this.challengerId,
    required this.confirmationId,
    required this.passed,
  });

  final String familyId;
  final String challengerId;
  final String confirmationId;
  final bool passed;

  /// Deliberately excludes scenario, failure, transcript, and evidence detail.
  Map<String, Object?> toPublicJson() => {
    'familyId': familyId,
    'challengerId': challengerId,
    'confirmationId': confirmationId,
    'status': passed ? 'pass' : 'fail',
  };
}

/// In-memory domain contract for one frozen experiment-family holdout budget.
class ExperimentFamilyHoldoutAccess {
  ExperimentFamilyHoldoutAccess({
    required this.familyId,
    required this.preregisteredChallengerId,
    required List<String> confirmationTokens,
  }) : _confirmationTokens = List.unmodifiable(confirmationTokens) {
    if (familyId.trim().isEmpty || preregisteredChallengerId.trim().isEmpty) {
      throw ArgumentError('family and challenger identities must be non-empty');
    }
    if (_confirmationTokens.isEmpty ||
        _confirmationTokens.any((token) => token.trim().isEmpty) ||
        _confirmationTokens.toSet().length != _confirmationTokens.length) {
      throw ArgumentError('confirmation tokens must be non-empty and unique');
    }
  }

  final String familyId;
  final String preregisteredChallengerId;
  final List<String> _confirmationTokens;
  final Set<String> _queriedChallengers = {};
  final Map<String, String> _issuedTokens = {};
  final Set<String> _publishedTokens = {};
  int _nextToken = 0;

  int get remainingBudget => _confirmationTokens.length - _nextToken;

  HoldoutAccessDecision requestConfirmation(String challengerId) {
    if (challengerId != preregisteredChallengerId) {
      return const HoldoutAccessDecision.denied(
        HoldoutDenialReason.unregisteredChallenger,
      );
    }
    if (_queriedChallengers.contains(challengerId)) {
      return const HoldoutAccessDecision.denied(
        HoldoutDenialReason.repeatedProbe,
      );
    }
    if (_nextToken >= _confirmationTokens.length) {
      return const HoldoutAccessDecision.denied(
        HoldoutDenialReason.budgetExhausted,
      );
    }

    final token = _confirmationTokens[_nextToken];
    _nextToken += 1;
    _queriedChallengers.add(challengerId);
    _issuedTokens[token] = challengerId;
    return HoldoutAccessDecision.granted(token);
  }

  HoldoutConfirmationReport publishConfirmation({
    required String confirmationToken,
    required bool passed,
  }) {
    final challengerId = _issuedTokens[confirmationToken];
    if (challengerId == null) {
      throw StateError('unknown or unissued holdout confirmation token');
    }
    if (!_publishedTokens.add(confirmationToken)) {
      throw StateError('holdout confirmation token was already published');
    }
    return HoldoutConfirmationReport(
      familyId: familyId,
      challengerId: challengerId,
      confirmationId: 'confirmation-${_publishedTokens.length}',
      passed: passed,
    );
  }
}
