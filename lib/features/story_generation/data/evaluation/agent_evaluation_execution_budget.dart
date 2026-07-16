import 'dart:convert';
import 'dart:io';

import 'agent_evaluation_manifest.dart';

/// Whether provider billing is part of the execution budget authority.
enum AgentEvaluationCostEnforcement {
  /// Cost is reserved and enforced from the frozen per-model token rates.
  metered,

  /// Cost is deliberately outside this budget; other ceilings still apply.
  disabled,
}

/// A frozen price and prompt-reservation ceiling for one provider route.
///
/// Prompt tokens are not known until the provider responds, so release calls
/// reserve this conservative ceiling before crossing the provider boundary.
final class AgentEvaluationBudgetRoute {
  AgentEvaluationBudgetRoute({
    required this.modelRouteHash,
    required this.model,
    required this.maxPromptTokensPerCall,
    required this.promptMicrousdPerMillionTokens,
    required this.completionMicrousdPerMillionTokens,
  }) {
    AgentEvaluationHashes.requireDigest(modelRouteHash, 'modelRouteHash');
    if (model.trim().isEmpty ||
        maxPromptTokensPerCall <= 0 ||
        promptMicrousdPerMillionTokens < 0 ||
        completionMicrousdPerMillionTokens < 0) {
      throw ArgumentError('execution budget route is invalid');
    }
  }

  final String modelRouteHash;
  final String model;
  final int maxPromptTokensPerCall;
  final int promptMicrousdPerMillionTokens;
  final int completionMicrousdPerMillionTokens;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'modelRouteHash': modelRouteHash,
    'model': model.trim(),
    'maxPromptTokensPerCall': maxPromptTokensPerCall,
    'promptMicrousdPerMillionTokens': promptMicrousdPerMillionTokens,
    'completionMicrousdPerMillionTokens': completionMicrousdPerMillionTokens,
  };
}

/// Immutable, execution-wide budget policy suitable for manifest binding.
final class AgentEvaluationExecutionBudgetPolicy {
  factory AgentEvaluationExecutionBudgetPolicy({
    required String budgetId,
    required int maxCalls,
    required int maxPromptTokens,
    required int maxCompletionTokens,
    required int maxTotalTokens,
    required int maxCostMicrousd,
    required int deadlineAtMs,
    required Iterable<AgentEvaluationBudgetRoute> routes,
    AgentEvaluationCostEnforcement costEnforcement =
        AgentEvaluationCostEnforcement.metered,
  }) {
    final normalizedId = budgetId.trim();
    final frozenRoutes = routes.toList()
      ..sort(
        (left, right) => left.modelRouteHash.compareTo(right.modelRouteHash),
      );
    if (normalizedId.isEmpty ||
        maxCalls <= 0 ||
        maxPromptTokens <= 0 ||
        maxCompletionTokens <= 0 ||
        maxTotalTokens <= 0 ||
        maxCostMicrousd < 0 ||
        deadlineAtMs < 0 ||
        frozenRoutes.isEmpty ||
        frozenRoutes.map((route) => route.modelRouteHash).toSet().length !=
            frozenRoutes.length) {
      throw ArgumentError('execution budget policy is invalid');
    }
    final canonical = <String, Object?>{
      'budgetId': normalizedId,
      'maxCalls': maxCalls,
      'maxPromptTokens': maxPromptTokens,
      'maxCompletionTokens': maxCompletionTokens,
      'maxTotalTokens': maxTotalTokens,
      'maxCostMicrousd': maxCostMicrousd,
      'deadlineAtMs': deadlineAtMs,
      if (costEnforcement != AgentEvaluationCostEnforcement.metered)
        'costEnforcement': costEnforcement.name,
      'routes': <Object?>[
        for (final route in frozenRoutes) route.toCanonicalMap(),
      ],
    };
    return AgentEvaluationExecutionBudgetPolicy._(
      budgetId: normalizedId,
      maxCalls: maxCalls,
      maxPromptTokens: maxPromptTokens,
      maxCompletionTokens: maxCompletionTokens,
      maxTotalTokens: maxTotalTokens,
      maxCostMicrousd: maxCostMicrousd,
      deadlineAtMs: deadlineAtMs,
      costEnforcement: costEnforcement,
      routes: List<AgentEvaluationBudgetRoute>.unmodifiable(frozenRoutes),
      policyHash: AgentEvaluationHashes.domainHash(
        'eval-execution-budget-policy-v1',
        canonical,
      ),
    );
  }

  const AgentEvaluationExecutionBudgetPolicy._({
    required this.budgetId,
    required this.maxCalls,
    required this.maxPromptTokens,
    required this.maxCompletionTokens,
    required this.maxTotalTokens,
    required this.maxCostMicrousd,
    required this.deadlineAtMs,
    required this.costEnforcement,
    required this.routes,
    required this.policyHash,
  });

  final String budgetId;
  final int maxCalls;
  final int maxPromptTokens;
  final int maxCompletionTokens;
  final int maxTotalTokens;
  final int maxCostMicrousd;
  final int deadlineAtMs;
  final AgentEvaluationCostEnforcement costEnforcement;
  final List<AgentEvaluationBudgetRoute> routes;
  final String policyHash;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'budgetId': budgetId,
    'maxCalls': maxCalls,
    'maxPromptTokens': maxPromptTokens,
    'maxCompletionTokens': maxCompletionTokens,
    'maxTotalTokens': maxTotalTokens,
    'maxCostMicrousd': maxCostMicrousd,
    'deadlineAtMs': deadlineAtMs,
    if (costEnforcement != AgentEvaluationCostEnforcement.metered)
      'costEnforcement': costEnforcement.name,
    'routes': <Object?>[for (final route in routes) route.toCanonicalMap()],
  };
}

final class AgentEvaluationBudgetException implements Exception {
  const AgentEvaluationBudgetException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AgentEvaluationBudgetException($code, $message)';
}

/// Immutable accounting view. It contains no provider credential or prompt.
final class AgentEvaluationExecutionBudgetSnapshot {
  AgentEvaluationExecutionBudgetSnapshot._({
    required this.policyHash,
    required this.calls,
    required this.promptTokens,
    required this.completionTokens,
    required this.costMicrousd,
    required this.succeededCalls,
    required this.failedCalls,
    required this.activeReservations,
    required this.breached,
  }) : totalTokens = promptTokens + completionTokens {
    snapshotHash = AgentEvaluationHashes.domainHash(
      'eval-execution-budget-snapshot-v1',
      toCanonicalMap(),
    );
  }

  final String policyHash;
  final int calls;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int costMicrousd;
  final int succeededCalls;
  final int failedCalls;
  final int activeReservations;
  final bool breached;
  late final String snapshotHash;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'policyHash': policyHash,
    'calls': calls,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
    'costMicrousd': costMicrousd,
    'succeededCalls': succeededCalls,
    'failedCalls': failedCalls,
    'activeReservations': activeReservations,
    'breached': breached,
  };
}

/// Opaque ownership token for exactly one provider-bound reservation.
final class AgentEvaluationBudgetReservation {
  AgentEvaluationBudgetReservation._({
    required Object guardIdentity,
    required String reservationId,
    required AgentEvaluationBudgetRoute route,
    required int promptTokens,
    required int completionTokens,
    required int costMicrousd,
  }) : _guardIdentity = guardIdentity,
       _reservationId = reservationId,
       _route = route,
       _promptTokens = promptTokens,
       _completionTokens = completionTokens,
       _costMicrousd = costMicrousd;

  final Object _guardIdentity;
  final String _reservationId;
  final AgentEvaluationBudgetRoute _route;
  final int _promptTokens;
  final int _completionTokens;
  final int _costMicrousd;
  bool _finished = false;
}

/// Shared fail-closed budget guard for every SUT and judge client in one run.
///
/// Every state transition is synchronous and contains no `await`, making the
/// check-and-reserve operation atomic for concurrent Futures in one Dart
/// isolate. A reservation is charged before the provider is called. Only a
/// successful response with exact, bounded usage can reconcile unused tokens;
/// failed or indeterminate calls keep the complete reservation permanently.
final class AgentEvaluationExecutionBudgetGuard {
  AgentEvaluationExecutionBudgetGuard({
    required this.policy,
    int Function()? nowMs,
    File? journalFile,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _journalFile = journalFile {
    if (journalFile != null) {
      _withJournalLock(() {
        if (journalFile.existsSync()) {
          _loadJournal(recoverAbandoned: true);
        } else {
          journalFile.parent.createSync(recursive: true);
          _persistJournal();
        }
      });
    }
  }

  final AgentEvaluationExecutionBudgetPolicy policy;
  final int Function() _nowMs;
  final File? _journalFile;
  final Object _identity = Object();
  int _reservationSequence = 0;
  int _lastObservedNowMs = -1;
  int _calls = 0;
  int _promptTokens = 0;
  int _completionTokens = 0;
  int _costMicrousd = 0;
  int _succeededCalls = 0;
  int _failedCalls = 0;
  int _activeReservations = 0;
  bool _breached = false;
  final Map<String, _DurableReservation> _durableReservations =
      <String, _DurableReservation>{};

  String get policyHash => policy.policyHash;

  AgentEvaluationBudgetRoute requireRoute({
    required String modelRouteHash,
    required String model,
  }) {
    final matches = policy.routes.where(
      (route) => route.modelRouteHash == modelRouteHash,
    );
    if (matches.length != 1 || matches.single.model.trim() != model.trim()) {
      throw const AgentEvaluationBudgetException(
        'price-route-mismatch',
        'frozen execution budget does not contain the provider model route',
      );
    }
    return matches.single;
  }

  AgentEvaluationBudgetReservation reserve({
    required String modelRouteHash,
    required String model,
    required int maxCompletionTokens,
    int? promptTokensUpperBound,
  }) {
    if (_journalFile != null) {
      return _withJournalLock(() {
        _loadJournal(recoverAbandoned: true);
        try {
          return _reserveInMemory(
            modelRouteHash: modelRouteHash,
            model: model,
            maxCompletionTokens: maxCompletionTokens,
            promptTokensUpperBound: promptTokensUpperBound,
          );
        } finally {
          _persistJournal();
        }
      });
    }
    return _reserveInMemory(
      modelRouteHash: modelRouteHash,
      model: model,
      maxCompletionTokens: maxCompletionTokens,
      promptTokensUpperBound: promptTokensUpperBound,
    );
  }

  AgentEvaluationBudgetReservation _reserveInMemory({
    required String modelRouteHash,
    required String model,
    required int maxCompletionTokens,
    required int? promptTokensUpperBound,
  }) {
    final now = _observeNow();
    if (_breached) {
      throw const AgentEvaluationBudgetException(
        'budget-already-breached',
        'execution budget is already breached',
      );
    }
    if (now >= policy.deadlineAtMs) {
      _breached = true;
      throw const AgentEvaluationBudgetException(
        'deadline-exhausted',
        'execution deadline was reached before provider dispatch',
      );
    }
    if (maxCompletionTokens <= 0) {
      throw const AgentEvaluationBudgetException(
        'unbounded-completion-reservation',
        'provider maxTokens must be finite and positive',
      );
    }
    final route = requireRoute(modelRouteHash: modelRouteHash, model: model);
    final reservedPrompt =
        promptTokensUpperBound ?? route.maxPromptTokensPerCall;
    if (reservedPrompt <= 0 || reservedPrompt > route.maxPromptTokensPerCall) {
      throw const AgentEvaluationBudgetException(
        'prompt-reservation-exceeded',
        'canonical prompt upper bound exceeds the frozen route ceiling',
      );
    }
    final reservedCompletion = maxCompletionTokens;
    final reservedCost =
        policy.costEnforcement == AgentEvaluationCostEnforcement.disabled
        ? 0
        : _costMicrousdFor(
            route,
            promptTokens: reservedPrompt,
            completionTokens: reservedCompletion,
          );
    final prospectiveCalls = _calls + 1;
    final prospectivePrompt = _promptTokens + reservedPrompt;
    final prospectiveCompletion = _completionTokens + reservedCompletion;
    final prospectiveCost = _costMicrousd + reservedCost;
    if (prospectiveCalls > policy.maxCalls ||
        prospectivePrompt > policy.maxPromptTokens ||
        prospectiveCompletion > policy.maxCompletionTokens ||
        prospectivePrompt + prospectiveCompletion > policy.maxTotalTokens ||
        (policy.costEnforcement == AgentEvaluationCostEnforcement.metered &&
            prospectiveCost > policy.maxCostMicrousd)) {
      throw const AgentEvaluationBudgetException(
        'budget-reservation-exhausted',
        'worst-case provider reservation exceeds the execution budget',
      );
    }
    _calls = prospectiveCalls;
    _promptTokens = prospectivePrompt;
    _completionTokens = prospectiveCompletion;
    _costMicrousd = prospectiveCost;
    _activeReservations += 1;
    final reservationId = AgentEvaluationHashes.domainHash(
      'eval-execution-budget-reservation-v1',
      <String, Object?>{
        'policyHash': policy.policyHash,
        'pid': pid,
        'sequence': ++_reservationSequence,
        'nowMs': now,
        'calls': _calls,
      },
    );
    _durableReservations[reservationId] = _DurableReservation(
      reservationId: reservationId,
      ownerPid: pid,
      routeHash: route.modelRouteHash,
      promptTokens: reservedPrompt,
      completionTokens: reservedCompletion,
      costMicrousd: reservedCost,
    );
    return AgentEvaluationBudgetReservation._(
      guardIdentity: _identity,
      reservationId: reservationId,
      route: route,
      promptTokens: reservedPrompt,
      completionTokens: reservedCompletion,
      costMicrousd: reservedCost,
    );
  }

  void reconcileSuccess(
    AgentEvaluationBudgetReservation reservation, {
    required int promptTokens,
    required int completionTokens,
  }) {
    if (_journalFile != null) {
      _withJournalLock(() {
        _loadJournal(recoverAbandoned: true);
        try {
          _reconcileSuccessInMemory(
            reservation,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
          );
        } finally {
          _persistJournal();
        }
      });
      return;
    }
    _reconcileSuccessInMemory(
      reservation,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  void _reconcileSuccessInMemory(
    AgentEvaluationBudgetReservation reservation, {
    required int promptTokens,
    required int completionTokens,
  }) {
    _requireOpenReservation(reservation);
    late final int now;
    try {
      now = _observeNow();
    } on Object {
      _finishAsFailure(reservation);
      rethrow;
    }
    if (promptTokens < 0 || completionTokens < 0) {
      _finishAsFailure(reservation);
      _breached = true;
      throw const AgentEvaluationBudgetException(
        'invalid-provider-usage',
        'provider usage must be exact and non-negative',
      );
    }
    final actualCost =
        policy.costEnforcement == AgentEvaluationCostEnforcement.disabled
        ? 0
        : _costMicrousdFor(
            reservation._route,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
          );
    final overReservation =
        promptTokens > reservation._promptTokens ||
        completionTokens > reservation._completionTokens ||
        actualCost > reservation._costMicrousd;
    final deadlineExceeded = now >= policy.deadlineAtMs;
    reservation._finished = true;
    _activeReservations -= 1;
    _durableReservations.remove(reservation._reservationId);
    if (overReservation) {
      if (promptTokens > reservation._promptTokens) {
        _promptTokens += promptTokens - reservation._promptTokens;
      }
      if (completionTokens > reservation._completionTokens) {
        _completionTokens += completionTokens - reservation._completionTokens;
      }
      if (actualCost > reservation._costMicrousd) {
        _costMicrousd += actualCost - reservation._costMicrousd;
      }
      _failedCalls += 1;
      _breached = true;
      throw const AgentEvaluationBudgetException(
        'provider-usage-exceeded-reservation',
        'provider usage exceeded the pre-dispatch reservation',
      );
    }
    if (deadlineExceeded) {
      _failedCalls += 1;
      _breached = true;
      throw const AgentEvaluationBudgetException(
        'deadline-exhausted',
        'execution deadline was reached while the provider call was active',
      );
    }
    _promptTokens -= reservation._promptTokens - promptTokens;
    _completionTokens -= reservation._completionTokens - completionTokens;
    _costMicrousd -= reservation._costMicrousd - actualCost;
    _succeededCalls += 1;
  }

  /// Permanently charges the complete reservation for an indeterminate call.
  void finishFailure(AgentEvaluationBudgetReservation reservation) {
    if (_journalFile != null) {
      _withJournalLock(() {
        _loadJournal(recoverAbandoned: true);
        try {
          _finishFailureInMemory(reservation);
        } finally {
          _persistJournal();
        }
      });
      return;
    }
    _finishFailureInMemory(reservation);
  }

  void _finishFailureInMemory(AgentEvaluationBudgetReservation reservation) {
    _requireOpenReservation(reservation);
    try {
      if (_observeNow(throwOnRollback: false) >= policy.deadlineAtMs) {
        _breached = true;
      }
    } on AgentEvaluationBudgetException {
      // Accounting a provider-bound failure must not be bypassed or mask the
      // original provider error because the injected clock is also invalid.
    }
    _finishAsFailure(reservation);
  }

  AgentEvaluationExecutionBudgetSnapshot snapshot() {
    if (_journalFile != null) {
      return _withJournalLock(() {
        _loadJournal(recoverAbandoned: true);
        _persistJournal();
        return _snapshotInMemory();
      });
    }
    return _snapshotInMemory();
  }

  AgentEvaluationExecutionBudgetSnapshot _snapshotInMemory() =>
      AgentEvaluationExecutionBudgetSnapshot._(
        policyHash: policy.policyHash,
        calls: _calls,
        promptTokens: _promptTokens,
        completionTokens: _completionTokens,
        costMicrousd: _costMicrousd,
        succeededCalls: _succeededCalls,
        failedCalls: _failedCalls,
        activeReservations: _activeReservations,
        breached: _breached,
      );

  void _finishAsFailure(AgentEvaluationBudgetReservation reservation) {
    reservation._finished = true;
    _activeReservations -= 1;
    _failedCalls += 1;
    _durableReservations.remove(reservation._reservationId);
  }

  void _requireOpenReservation(AgentEvaluationBudgetReservation reservation) {
    if (!identical(reservation._guardIdentity, _identity)) {
      throw const AgentEvaluationBudgetException(
        'foreign-reservation',
        'reservation belongs to another execution budget',
      );
    }
    if (reservation._finished) {
      throw const AgentEvaluationBudgetException(
        'reservation-already-finished',
        'reservation can be finished exactly once',
      );
    }
    if (!_durableReservations.containsKey(reservation._reservationId)) {
      throw const AgentEvaluationBudgetException(
        'reservation-not-active',
        'reservation is not active in the durable execution budget',
      );
    }
  }

  /// The hard time remaining for a provider-bound Future. This is observed
  /// from the same monotonic-rollback-detecting clock as reservations.
  Duration remainingDuration() {
    if (_journalFile != null) {
      return _withJournalLock(() {
        _loadJournal(recoverAbandoned: true);
        try {
          return _remainingDurationInMemory();
        } finally {
          _persistJournal();
        }
      });
    }
    return _remainingDurationInMemory();
  }

  Duration _remainingDurationInMemory() {
    final remaining = policy.deadlineAtMs - _observeNow();
    if (remaining <= 0) {
      _breached = true;
      throw const AgentEvaluationBudgetException(
        'deadline-exhausted',
        'execution deadline was reached before provider dispatch',
      );
    }
    return Duration(milliseconds: remaining);
  }

  int _observeNow({bool throwOnRollback = true}) {
    final now = _nowMs();
    if (now < 0) {
      _breached = true;
      throw const AgentEvaluationBudgetException(
        'invalid-clock',
        'execution budget clock returned a negative timestamp',
      );
    }
    if (_lastObservedNowMs >= 0 && now < _lastObservedNowMs) {
      _breached = true;
      if (throwOnRollback) {
        throw const AgentEvaluationBudgetException(
          'clock-rollback',
          'execution budget clock moved backwards',
        );
      }
    } else {
      _lastObservedNowMs = now;
    }
    return now;
  }

  T _withJournalLock<T>(T Function() action) {
    final journal = _journalFile!;
    journal.parent.createSync(recursive: true);
    final lock = File('${journal.path}.lock')..createSync(recursive: true);
    _chmod0600(lock.path);
    final handle = lock.openSync(mode: FileMode.append);
    try {
      handle.lockSync(FileLock.exclusive);
      return action();
    } finally {
      handle.unlockSync();
      handle.closeSync();
    }
  }

  void _loadJournal({required bool recoverAbandoned}) {
    final journal = _journalFile!;
    final decoded = jsonDecode(journal.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const AgentEvaluationBudgetException(
        'budget-journal-corrupt',
        'execution budget journal is not a JSON object',
      );
    }
    final payload = Map<String, Object?>.from(decoded)..remove('stateHash');
    final expectedHash = AgentEvaluationHashes.domainHash(
      'eval-execution-budget-journal-v1',
      payload,
    );
    if (decoded['version'] != 1 ||
        decoded['policyHash'] != policy.policyHash ||
        AgentEvaluationHashes.domainHash(
              'eval-execution-budget-policy-v1',
              decoded['policy'],
            ) !=
            policy.policyHash ||
        decoded['stateHash'] != expectedHash) {
      throw const AgentEvaluationBudgetException(
        'budget-journal-policy-mismatch',
        'execution budget journal policy or state hash does not match',
      );
    }
    int number(String key) {
      final value = decoded[key];
      if (value is! int || value < 0) {
        throw const AgentEvaluationBudgetException(
          'budget-journal-corrupt',
          'execution budget journal contains invalid counters',
        );
      }
      return value;
    }

    _calls = number('calls');
    _promptTokens = number('promptTokens');
    _completionTokens = number('completionTokens');
    _costMicrousd = number('costMicrousd');
    _succeededCalls = number('succeededCalls');
    _failedCalls = number('failedCalls');
    _reservationSequence = number('reservationSequence');
    _lastObservedNowMs = decoded['lastObservedNowMs'] as int? ?? -1;
    _breached = decoded['breached'] == true;
    _durableReservations.clear();
    final reservations = decoded['reservations'];
    if (reservations is! List<Object?>) {
      throw const AgentEvaluationBudgetException(
        'budget-journal-corrupt',
        'execution budget journal reservation set is invalid',
      );
    }
    for (final entry in reservations) {
      if (entry is! Map<String, Object?>) {
        throw const AgentEvaluationBudgetException(
          'budget-journal-corrupt',
          'execution budget journal reservation is invalid',
        );
      }
      final reservation = _DurableReservation.fromJson(entry);
      _durableReservations[reservation.reservationId] = reservation;
    }
    if (recoverAbandoned) {
      final abandoned = _durableReservations.values
          .where((reservation) => !_isProcessAlive(reservation.ownerPid))
          .map((reservation) => reservation.reservationId)
          .toList(growable: false);
      for (final id in abandoned) {
        _durableReservations.remove(id);
        _failedCalls += 1;
      }
    }
    _activeReservations = _durableReservations.length;
  }

  void _persistJournal() {
    final journal = _journalFile!;
    final reservations = _durableReservations.values.toList()
      ..sort(
        (left, right) => left.reservationId.compareTo(right.reservationId),
      );
    final payload = <String, Object?>{
      'version': 1,
      'policyHash': policy.policyHash,
      'policy': policy.toCanonicalMap(),
      'calls': _calls,
      'promptTokens': _promptTokens,
      'completionTokens': _completionTokens,
      'costMicrousd': _costMicrousd,
      'succeededCalls': _succeededCalls,
      'failedCalls': _failedCalls,
      'breached': _breached,
      'lastObservedNowMs': _lastObservedNowMs,
      'reservationSequence': _reservationSequence,
      'reservations': <Object?>[
        for (final reservation in reservations) reservation.toCanonicalMap(),
      ],
    };
    final stateHash = AgentEvaluationHashes.domainHash(
      'eval-execution-budget-journal-v1',
      payload,
    );
    final temporary = File(
      '${journal.path}.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}',
    );
    temporary.writeAsStringSync(
      jsonEncode(<String, Object?>{...payload, 'stateHash': stateHash}),
      flush: true,
    );
    _chmod0600(temporary.path);
    temporary.renameSync(journal.path);
    _chmod0600(journal.path);
  }
}

/// Reads only the frozen absolute deadline needed to reconstruct the exact
/// policy on process restart. The complete journal and embedded policy are
/// hash-verified before the value is returned.
int readAgentEvaluationBudgetJournalDeadlineAtMs(
  File journal, {
  required String expectedBudgetId,
}) {
  final decoded = jsonDecode(journal.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw const AgentEvaluationBudgetException(
      'budget-journal-corrupt',
      'execution budget journal is not a JSON object',
    );
  }
  final payload = Map<String, Object?>.from(decoded)..remove('stateHash');
  if (decoded['stateHash'] !=
      AgentEvaluationHashes.domainHash(
        'eval-execution-budget-journal-v1',
        payload,
      )) {
    throw const AgentEvaluationBudgetException(
      'budget-journal-corrupt',
      'execution budget journal state hash does not match',
    );
  }
  final embedded = decoded['policy'];
  if (embedded is! Map<String, Object?> ||
      embedded['budgetId'] != expectedBudgetId ||
      decoded['policyHash'] !=
          AgentEvaluationHashes.domainHash(
            'eval-execution-budget-policy-v1',
            embedded,
          )) {
    throw const AgentEvaluationBudgetException(
      'budget-journal-policy-mismatch',
      'execution budget journal embedded policy does not match',
    );
  }
  final deadlineAtMs = embedded['deadlineAtMs'];
  if (deadlineAtMs is! int || deadlineAtMs < 0) {
    throw const AgentEvaluationBudgetException(
      'budget-journal-corrupt',
      'execution budget journal deadline is invalid',
    );
  }
  return deadlineAtMs;
}

final class _DurableReservation {
  const _DurableReservation({
    required this.reservationId,
    required this.ownerPid,
    required this.routeHash,
    required this.promptTokens,
    required this.completionTokens,
    required this.costMicrousd,
  });

  factory _DurableReservation.fromJson(Map<String, Object?> json) {
    final reservation = _DurableReservation(
      reservationId: json['reservationId'] as String? ?? '',
      ownerPid: json['ownerPid'] as int? ?? -1,
      routeHash: json['routeHash'] as String? ?? '',
      promptTokens: json['promptTokens'] as int? ?? -1,
      completionTokens: json['completionTokens'] as int? ?? -1,
      costMicrousd: json['costMicrousd'] as int? ?? -1,
    );
    if (reservation.reservationId.isEmpty ||
        reservation.ownerPid <= 0 ||
        reservation.promptTokens <= 0 ||
        reservation.completionTokens <= 0 ||
        reservation.costMicrousd < 0) {
      throw const AgentEvaluationBudgetException(
        'budget-journal-corrupt',
        'execution budget journal reservation fields are invalid',
      );
    }
    AgentEvaluationHashes.requireDigest(reservation.routeHash, 'routeHash');
    return reservation;
  }

  final String reservationId;
  final int ownerPid;
  final String routeHash;
  final int promptTokens;
  final int completionTokens;
  final int costMicrousd;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'reservationId': reservationId,
    'ownerPid': ownerPid,
    'routeHash': routeHash,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'costMicrousd': costMicrousd,
  };
}

bool _isProcessAlive(int candidatePid) {
  if (candidatePid == pid) return true;
  if (Platform.isLinux && Directory('/proc/$candidatePid').existsSync()) {
    return true;
  }
  if (Platform.isLinux) return false;
  try {
    return Process.runSync('/bin/kill', <String>[
          '-0',
          '$candidatePid',
        ]).exitCode ==
        0;
  } on ProcessException {
    // Unknown liveness must fail closed: retain the full reservation.
    return true;
  }
}

void _chmod0600(String path) {
  if (Platform.isWindows) return;
  final result = Process.runSync('/bin/chmod', <String>['600', path]);
  if (result.exitCode != 0) {
    throw const AgentEvaluationBudgetException(
      'budget-journal-permission-failed',
      'execution budget journal could not be restricted to mode 0600',
    );
  }
}

int _costMicrousdFor(
  AgentEvaluationBudgetRoute route, {
  required int promptTokens,
  required int completionTokens,
}) =>
    _ceilPerMillion(promptTokens, route.promptMicrousdPerMillionTokens) +
    _ceilPerMillion(completionTokens, route.completionMicrousdPerMillionTokens);

int _ceilPerMillion(int tokens, int microusdPerMillionTokens) {
  if (tokens == 0 || microusdPerMillionTokens == 0) {
    return 0;
  }
  return ((tokens * microusdPerMillionTokens) + 999999) ~/ 1000000;
}
