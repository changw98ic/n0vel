import 'dart:math' as math;

import 'pass3_evaluation.dart';

class ReleaseArmEvidence {
  const ReleaseArmEvidence({
    required this.pass3Passed,
    required this.safetyPassed,
    required this.transactionPassed,
    required this.expectedAttemptCount,
    required this.attempts,
  });

  final bool pass3Passed;
  final bool safetyPassed;
  final bool transactionPassed;
  final int expectedAttemptCount;
  final List<TrialAttemptObservation> attempts;

  bool get hasCompleteAttemptEvidence {
    if (expectedAttemptCount <= 0 || attempts.length != expectedAttemptCount) {
      return false;
    }
    final ids = <String>{};
    return attempts.every(
      (attempt) =>
          attempt.attemptId.trim().isNotEmpty && ids.add(attempt.attemptId),
    );
  }

  int get completedContentAttempts => attempts
      .where(
        (attempt) =>
            attempt.kind == TrialAttemptKind.content && attempt.succeeded,
      )
      .length;

  int get failedTransportAttempts => attempts
      .where(
        (attempt) =>
            attempt.kind == TrialAttemptKind.transport && !attempt.succeeded,
      )
      .length;

  int get totalCostMicrousd =>
      attempts.fold(0, (total, attempt) => total + attempt.costMicrousd);

  double get completionRate => completedContentAttempts / expectedAttemptCount;

  double get transportReliability =>
      1 - (failedTransportAttempts / expectedAttemptCount);

  double get averageCostMicrousd => totalCostMicrousd / expectedAttemptCount;
}

/// Frozen statistical contract shared by every arm in one release decision.
class QualityComparisonPolicy {
  QualityComparisonPolicy({
    required Set<String> requiredDimensions,
    required Map<String, int> minimumPairCounts,
    required Map<String, double> nonInferiorityMargins,
    required this.familyWiseAlpha,
    required this.multiplicityMethodIdentity,
  }) : requiredDimensions = Set.unmodifiable(requiredDimensions),
       minimumPairCounts = Map.unmodifiable(minimumPairCounts),
       nonInferiorityMargins = Map.unmodifiable(nonInferiorityMargins);

  final Set<String> requiredDimensions;
  final Map<String, int> minimumPairCounts;
  final Map<String, double> nonInferiorityMargins;
  final double familyWiseAlpha;
  final String multiplicityMethodIdentity;

  bool get isWellFormed {
    if (requiredDimensions.isEmpty ||
        requiredDimensions.any((dimension) => dimension.trim().isEmpty) ||
        !_sameStringSet(minimumPairCounts.keys, requiredDimensions) ||
        !_sameStringSet(nonInferiorityMargins.keys, requiredDimensions) ||
        minimumPairCounts.values.any((count) => count <= 0) ||
        nonInferiorityMargins.values.any(
          (margin) => !margin.isFinite || margin < 0,
        ) ||
        !familyWiseAlpha.isFinite ||
        familyWiseAlpha <= 0 ||
        familyWiseAlpha >= 1 ||
        multiplicityMethodIdentity.trim().isEmpty) {
      return false;
    }
    return true;
  }
}

class QualityDimensionComparison {
  const QualityDimensionComparison({
    required this.dimensionId,
    required this.pairCount,
    required this.championMean,
    required this.challengerMean,
    required this.championP10,
    required this.challengerP10,
    required this.championMin,
    required this.challengerMin,
    required this.nonInferiorityLowerConfidenceBound,
  });

  final String dimensionId;
  final int pairCount;
  final double championMean;
  final double challengerMean;
  final double championP10;
  final double challengerP10;
  final double championMin;
  final double challengerMin;

  /// Lower confidence bound for `challenger - champion` under the policy.
  final double? nonInferiorityLowerConfidenceBound;

  bool get hasFiniteStatistics =>
      championMean.isFinite &&
      challengerMean.isFinite &&
      championP10.isFinite &&
      challengerP10.isFinite &&
      championMin.isFinite &&
      challengerMin.isFinite;
}

class QualityComparisonEvidence {
  QualityComparisonEvidence({
    required this.policy,
    required List<QualityDimensionComparison> dimensions,
  }) : dimensions = List.unmodifiable(dimensions);

  final QualityComparisonPolicy policy;
  final List<QualityDimensionComparison> dimensions;
}

enum ReleaseGateStatus { promote, reject, insufficientEvidence }

enum ReleaseGateReason {
  armEvidenceIncomplete,
  pass3Failed,
  safetyFailed,
  transactionFailed,
  qualityEvidenceInsufficient,
  qualityInferiority,
  qualityMeanInferiority,
  qualityP10Inferiority,
  qualityMinimumInferiority,
  qualityConfidenceInferiority,
  completionRateRegression,
  transportReliabilityRegression,
  costRegression,
  performanceEvidenceInsufficient,
  latencyRegression,
}

class ReleaseGateResult {
  const ReleaseGateResult({
    required this.status,
    required this.reasons,
    required this.championTotalCostMicrousd,
    required this.challengerTotalCostMicrousd,
    required this.performanceSampleCount,
  });

  final ReleaseGateStatus status;
  final Set<ReleaseGateReason> reasons;
  final int championTotalCostMicrousd;
  final int challengerTotalCostMicrousd;
  final int performanceSampleCount;
}

/// Mechanical promotion gate over frozen champion/challenger evidence.
class ChampionChallengerReleaseGate {
  const ChampionChallengerReleaseGate({
    this.maximumCostRegression = 0.15,
    this.maximumP95LatencyRegression = 0.10,
    this.minimumPairedPerformanceSamples = 20,
  });

  final double maximumCostRegression;
  final double maximumP95LatencyRegression;
  final int minimumPairedPerformanceSamples;

  ReleaseGateResult evaluate({
    required ReleaseArmEvidence champion,
    required ReleaseArmEvidence challenger,
    required QualityComparisonEvidence qualityComparison,
    required Iterable<PairedPerformanceObservation> performancePairs,
  }) {
    final reasons = <ReleaseGateReason>{};
    var insufficient = false;

    if (!champion.hasCompleteAttemptEvidence ||
        !challenger.hasCompleteAttemptEvidence) {
      reasons.add(ReleaseGateReason.armEvidenceIncomplete);
      insufficient = true;
    }

    if (!_evaluateQualityComparison(qualityComparison, reasons)) {
      insufficient = true;
    }

    final pairsById = <String, PairedPerformanceObservation>{};
    for (final pair in performancePairs) {
      if (pair.pairId.trim().isNotEmpty) {
        pairsById.putIfAbsent(pair.pairId, () => pair);
      }
    }
    if (pairsById.length < minimumPairedPerformanceSamples) {
      reasons.add(ReleaseGateReason.performanceEvidenceInsufficient);
      insufficient = true;
    }

    if (!challenger.pass3Passed) {
      reasons.add(ReleaseGateReason.pass3Failed);
    }
    if (!challenger.safetyPassed) {
      reasons.add(ReleaseGateReason.safetyFailed);
    }
    if (!challenger.transactionPassed) {
      reasons.add(ReleaseGateReason.transactionFailed);
    }
    if (champion.hasCompleteAttemptEvidence &&
        challenger.hasCompleteAttemptEvidence) {
      if (challenger.completionRate < champion.completionRate) {
        reasons.add(ReleaseGateReason.completionRateRegression);
      }
      if (challenger.transportReliability < champion.transportReliability) {
        reasons.add(ReleaseGateReason.transportReliabilityRegression);
      }
      final maximumAllowedAverageCost =
          champion.averageCostMicrousd * (1 + maximumCostRegression);
      if (challenger.averageCostMicrousd > maximumAllowedAverageCost) {
        reasons.add(ReleaseGateReason.costRegression);
      }
    }

    if (pairsById.length >= minimumPairedPerformanceSamples) {
      final championP95 = _nearestRankP95(
        pairsById.values.map((pair) => pair.championLatencyMs),
      );
      final challengerP95 = _nearestRankP95(
        pairsById.values.map((pair) => pair.challengerLatencyMs),
      );
      final maximumAllowedP95 = championP95 * (1 + maximumP95LatencyRegression);
      if (challengerP95 > maximumAllowedP95) {
        reasons.add(ReleaseGateReason.latencyRegression);
      }
    }

    final status = insufficient
        ? ReleaseGateStatus.insufficientEvidence
        : reasons.isEmpty
        ? ReleaseGateStatus.promote
        : ReleaseGateStatus.reject;
    return ReleaseGateResult(
      status: status,
      reasons: Set.unmodifiable(reasons),
      championTotalCostMicrousd: champion.totalCostMicrousd,
      challengerTotalCostMicrousd: challenger.totalCostMicrousd,
      performanceSampleCount: pairsById.length,
    );
  }

  double _nearestRankP95(Iterable<int> values) {
    final sorted = values.toList(growable: false)..sort();
    final rank = math.max(1, (sorted.length * 0.95).ceil());
    return sorted[rank - 1].toDouble();
  }

  bool _evaluateQualityComparison(
    QualityComparisonEvidence evidence,
    Set<ReleaseGateReason> reasons,
  ) {
    final policy = evidence.policy;
    if (!policy.isWellFormed) {
      reasons.add(ReleaseGateReason.qualityEvidenceInsufficient);
      return false;
    }

    final dimensionsById = <String, QualityDimensionComparison>{};
    var duplicateDimension = false;
    for (final dimension in evidence.dimensions) {
      if (dimensionsById.containsKey(dimension.dimensionId)) {
        duplicateDimension = true;
      } else {
        dimensionsById[dimension.dimensionId] = dimension;
      }
    }
    if (duplicateDimension ||
        !_sameStringSet(dimensionsById.keys, policy.requiredDimensions)) {
      reasons.add(ReleaseGateReason.qualityEvidenceInsufficient);
      return false;
    }

    var sufficient = true;
    var inferior = false;
    for (final dimensionId in policy.requiredDimensions) {
      final dimension = dimensionsById[dimensionId]!;
      final lowerBound = dimension.nonInferiorityLowerConfidenceBound;
      if (dimension.pairCount < policy.minimumPairCounts[dimensionId]! ||
          !dimension.hasFiniteStatistics ||
          lowerBound == null ||
          !lowerBound.isFinite) {
        reasons.add(ReleaseGateReason.qualityEvidenceInsufficient);
        sufficient = false;
        continue;
      }

      final margin = policy.nonInferiorityMargins[dimensionId]!;
      if (dimension.challengerMean - dimension.championMean < -margin) {
        reasons.add(ReleaseGateReason.qualityMeanInferiority);
        inferior = true;
      }
      if (dimension.challengerP10 - dimension.championP10 < -margin) {
        reasons.add(ReleaseGateReason.qualityP10Inferiority);
        inferior = true;
      }
      if (dimension.challengerMin - dimension.championMin < -margin) {
        reasons.add(ReleaseGateReason.qualityMinimumInferiority);
        inferior = true;
      }
      if (lowerBound < -margin) {
        reasons.add(ReleaseGateReason.qualityConfidenceInferiority);
        inferior = true;
      }
    }
    if (inferior) {
      reasons.add(ReleaseGateReason.qualityInferiority);
    }
    return sufficient;
  }
}

bool _sameStringSet(Iterable<String> left, Set<String> right) {
  final leftSet = left.toSet();
  return leftSet.length == right.length && leftSet.containsAll(right);
}
