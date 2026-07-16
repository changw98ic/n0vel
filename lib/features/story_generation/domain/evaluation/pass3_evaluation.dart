enum TrialIndependence { independent, nonIndependent }

/// Sealed result for one predeclared logical trial slot.
class TrialSlotOutcome {
  const TrialSlotOutcome({
    required this.trialNo,
    required this.hardPass,
    required this.evidenceComplete,
    required this.contentDigest,
    required this.independence,
    this.replacementSample = false,
  });

  final int trialNo;
  final bool hardPass;
  final bool evidenceComplete;
  final String contentDigest;
  final TrialIndependence independence;

  /// True when this result was added after a declared slot had already failed.
  final bool replacementSample;
}

enum Pass3Failure {
  missingSlot,
  duplicateSlot,
  unexpectedSlot,
  failedSlot,
  incompleteEvidence,
  nonIndependent,
  reusedContent,
  invalidContentDigest,
  replacementSample,
}

class Pass3Result {
  const Pass3Result({
    required this.passed,
    required this.failureReasons,
    required this.declaredSlotsSeen,
  });

  final bool passed;
  final Set<Pass3Failure> failureReasons;
  final int declaredSlotsSeen;
}

/// Computes Pass³ from exactly the three predeclared logical slots.
class Pass3Evaluator {
  const Pass3Evaluator({this.requiredTrials = 3});

  final int requiredTrials;

  Pass3Result evaluate(Iterable<TrialSlotOutcome> slots) {
    final failures = <Pass3Failure>{};
    final slotsByNumber = <int, TrialSlotOutcome>{};
    for (final slot in slots) {
      if (slot.replacementSample) {
        failures.add(Pass3Failure.replacementSample);
      }
      if (slot.trialNo < 1 || slot.trialNo > requiredTrials) {
        failures.add(Pass3Failure.unexpectedSlot);
        continue;
      }
      if (slotsByNumber.containsKey(slot.trialNo)) {
        failures.add(Pass3Failure.duplicateSlot);
        continue;
      }
      slotsByNumber[slot.trialNo] = slot;
    }

    for (var trialNo = 1; trialNo <= requiredTrials; trialNo += 1) {
      if (!slotsByNumber.containsKey(trialNo)) {
        failures.add(Pass3Failure.missingSlot);
      }
    }

    final contentDigests = <String>{};
    for (final slot in slotsByNumber.values) {
      if (!slot.hardPass) failures.add(Pass3Failure.failedSlot);
      if (!slot.evidenceComplete) {
        failures.add(Pass3Failure.incompleteEvidence);
      }
      if (slot.independence != TrialIndependence.independent) {
        failures.add(Pass3Failure.nonIndependent);
      }
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(slot.contentDigest)) {
        failures.add(Pass3Failure.invalidContentDigest);
      } else if (!contentDigests.add(slot.contentDigest)) {
        failures.add(Pass3Failure.reusedContent);
      }
    }

    return Pass3Result(
      passed: failures.isEmpty,
      failureReasons: Set.unmodifiable(failures),
      declaredSlotsSeen: slotsByNumber.length,
    );
  }
}

enum TrialAttemptKind { content, transport }

class TrialAttemptObservation {
  const TrialAttemptObservation({
    required this.attemptId,
    required this.kind,
    required this.succeeded,
    required this.latencyMs,
    required this.promptTokens,
    required this.completionTokens,
    required this.costMicrousd,
  });

  final String attemptId;
  final TrialAttemptKind kind;
  final bool succeeded;
  final int latencyMs;
  final int promptTokens;
  final int completionTokens;
  final int costMicrousd;
}

class PairedPerformanceObservation {
  const PairedPerformanceObservation({
    required this.pairId,
    required this.championLatencyMs,
    required this.challengerLatencyMs,
  });

  final String pairId;
  final int championLatencyMs;
  final int challengerLatencyMs;
}

enum PerformanceEvidence { sufficient, insufficient }

class TransportPerformanceAggregate {
  const TransportPerformanceAggregate({
    required this.attempted,
    required this.completed,
    required this.transportFailures,
    required this.totalLatencyMs,
    required this.totalTokens,
    required this.totalCostMicrousd,
    required this.performanceSampleCount,
    required this.performanceEvidence,
  });

  final int attempted;
  final int completed;
  final int transportFailures;
  final int totalLatencyMs;
  final int totalTokens;
  final int totalCostMicrousd;
  final int performanceSampleCount;
  final PerformanceEvidence performanceEvidence;
}

/// Aggregates every provider attempt, including failed and abandoned work.
class TransportPerformanceAggregator {
  const TransportPerformanceAggregator({this.minimumPairedSamples = 20});

  final int minimumPairedSamples;

  TransportPerformanceAggregate aggregate({
    required Iterable<TrialAttemptObservation> attempts,
    required Iterable<PairedPerformanceObservation>
    pairedPerformanceObservations,
  }) {
    var attempted = 0;
    var completed = 0;
    var transportFailures = 0;
    var totalLatencyMs = 0;
    var totalTokens = 0;
    var totalCostMicrousd = 0;
    for (final attempt in attempts) {
      attempted += 1;
      if (attempt.succeeded) completed += 1;
      if (attempt.kind == TrialAttemptKind.transport && !attempt.succeeded) {
        transportFailures += 1;
      }
      totalLatencyMs += attempt.latencyMs;
      totalTokens += attempt.promptTokens + attempt.completionTokens;
      totalCostMicrousd += attempt.costMicrousd;
    }

    final uniquePairIds = <String>{};
    for (final pair in pairedPerformanceObservations) {
      uniquePairIds.add(pair.pairId);
    }
    final sampleCount = uniquePairIds.length;

    return TransportPerformanceAggregate(
      attempted: attempted,
      completed: completed,
      transportFailures: transportFailures,
      totalLatencyMs: totalLatencyMs,
      totalTokens: totalTokens,
      totalCostMicrousd: totalCostMicrousd,
      performanceSampleCount: sampleCount,
      performanceEvidence: sampleCount >= minimumPairedSamples
          ? PerformanceEvidence.sufficient
          : PerformanceEvidence.insufficient,
    );
  }
}
