import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/pass3_evaluation.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/release_gate.dart';

void main() {
  group('ChampionChallengerReleaseGate', () {
    const gate = ChampionChallengerReleaseGate();

    test('rejects a 99 to 95 quality regression despite absolute pass', () {
      final result = gate.evaluate(
        champion: _arm(),
        challenger: _arm(),
        qualityComparison: _quality(championMean: 99, challengerMean: 95),
        performancePairs: _pairs(20),
      );

      expect(result.status, ReleaseGateStatus.reject);
      expect(result.reasons, contains(ReleaseGateReason.qualityInferiority));
    });

    test('rejects three successes selected from one hundred attempts', () {
      final challengerAttempts = <TrialAttemptObservation>[
        for (var index = 0; index < 97; index += 1)
          _attempt(
            'failed-$index',
            kind: TrialAttemptKind.transport,
            succeeded: false,
          ),
        for (var index = 0; index < 3; index += 1) _attempt('success-$index'),
      ];
      final result = gate.evaluate(
        champion: _arm(),
        challenger: _arm(
          expectedAttemptCount: 100,
          attempts: challengerAttempts,
        ),
        qualityComparison: _quality(),
        performancePairs: _pairs(20),
      );

      expect(result.status, ReleaseGateStatus.reject);
      expect(
        result.reasons,
        contains(ReleaseGateReason.completionRateRegression),
      );
      expect(
        result.reasons,
        contains(ReleaseGateReason.transportReliabilityRegression),
      );
    });

    test('failed-attempt costs cannot be hidden from the cost gate', () {
      final challengerAttempts = <TrialAttemptObservation>[
        _attempt(
          'failed-expensive',
          kind: TrialAttemptKind.transport,
          succeeded: false,
          costMicrousd: 1000,
        ),
        _attempt('success-cheap', costMicrousd: 100),
      ];
      final result = gate.evaluate(
        champion: _arm(
          expectedAttemptCount: 2,
          attempts: [
            _attempt('champion-1', costMicrousd: 100),
            _attempt('champion-2', costMicrousd: 100),
          ],
        ),
        challenger: _arm(expectedAttemptCount: 2, attempts: challengerAttempts),
        qualityComparison: _quality(),
        performancePairs: _pairs(20),
      );

      expect(result.status, ReleaseGateStatus.reject);
      expect(result.reasons, contains(ReleaseGateReason.costRegression));
      expect(result.challengerTotalCostMicrousd, 1100);
    });

    test('fewer than twenty paired samples is insufficient evidence', () {
      final result = gate.evaluate(
        champion: _arm(),
        challenger: _arm(),
        qualityComparison: _quality(),
        performancePairs: _pairs(19),
      );

      expect(result.status, ReleaseGateStatus.insufficientEvidence);
      expect(
        result.reasons,
        contains(ReleaseGateReason.performanceEvidenceInsufficient),
      );
    });

    test('rejects any failed Pass3, safety, or transaction hard gate', () {
      final cases = <ReleaseArmEvidence>[
        _arm(pass3Passed: false),
        _arm(safetyPassed: false),
        _arm(transactionPassed: false),
      ];
      final expectedReasons = [
        ReleaseGateReason.pass3Failed,
        ReleaseGateReason.safetyFailed,
        ReleaseGateReason.transactionFailed,
      ];

      for (var index = 0; index < cases.length; index += 1) {
        final result = gate.evaluate(
          champion: _arm(),
          challenger: cases[index],
          qualityComparison: _quality(),
          performancePairs: _pairs(20),
        );
        expect(result.status, ReleaseGateStatus.reject);
        expect(result.reasons, contains(expectedReasons[index]));
      }
    });

    test('rejects a p95 latency regression above ten percent', () {
      final result = gate.evaluate(
        champion: _arm(),
        challenger: _arm(),
        qualityComparison: _quality(),
        performancePairs: _pairs(20, challengerLatencyMs: 111),
      );

      expect(result.status, ReleaseGateStatus.reject);
      expect(result.reasons, contains(ReleaseGateReason.latencyRegression));
    });

    test('promotes only when every mechanical gate passes', () {
      final result = gate.evaluate(
        champion: _arm(),
        challenger: _arm(),
        qualityComparison: _quality(challengerMean: 99.2),
        performancePairs: _pairs(20, challengerLatencyMs: 95),
      );

      expect(result.status, ReleaseGateStatus.promote);
      expect(result.reasons, isEmpty);
    });

    test('checks every required quality dimension', () {
      final result = gate.evaluate(
        champion: _arm(),
        challenger: _arm(),
        qualityComparison: QualityComparisonEvidence(
          policy: _policy(requiredDimensions: const {'prose', 'character'}),
          dimensions: const [
            QualityDimensionComparison(
              dimensionId: 'prose',
              pairCount: 30,
              championMean: 98,
              challengerMean: 98,
              championP10: 96,
              challengerP10: 96,
              championMin: 95,
              challengerMin: 95,
              nonInferiorityLowerConfidenceBound: 0,
            ),
            QualityDimensionComparison(
              dimensionId: 'character',
              pairCount: 30,
              championMean: 99,
              challengerMean: 94,
              championP10: 96,
              challengerP10: 96,
              championMin: 95,
              challengerMin: 95,
              nonInferiorityLowerConfidenceBound: 0,
            ),
          ],
        ),
        performancePairs: _pairs(20),
      );

      expect(result.status, ReleaseGateStatus.reject);
      expect(result.reasons, contains(ReleaseGateReason.qualityInferiority));
      expect(
        result.reasons,
        contains(ReleaseGateReason.qualityMeanInferiority),
      );
    });

    test('rejects p10 or minimum regression hidden by an equal mean', () {
      final cases = [
        _quality(championP10: 97, challengerP10: 96),
        _quality(championMin: 96, challengerMin: 95),
      ];
      final expectedReasons = [
        ReleaseGateReason.qualityP10Inferiority,
        ReleaseGateReason.qualityMinimumInferiority,
      ];

      for (var index = 0; index < cases.length; index += 1) {
        final result = gate.evaluate(
          champion: _arm(),
          challenger: _arm(),
          qualityComparison: cases[index],
          performancePairs: _pairs(20),
        );
        expect(result.status, ReleaseGateStatus.reject);
        expect(result.reasons, contains(expectedReasons[index]));
      }
    });

    test('rejects a confidence lower bound beyond the frozen margin', () {
      final result = gate.evaluate(
        champion: _arm(),
        challenger: _arm(),
        qualityComparison: _quality(lowerConfidenceBound: -0.01),
        performancePairs: _pairs(20),
      );

      expect(result.status, ReleaseGateStatus.reject);
      expect(
        result.reasons,
        contains(ReleaseGateReason.qualityConfidenceInferiority),
      );
    });

    test('quality sample shortage or missing CI is insufficient evidence', () {
      final cases = [
        _quality(pairCount: 19),
        _quality(lowerConfidenceBound: null),
      ];

      for (final qualityComparison in cases) {
        final result = gate.evaluate(
          champion: _arm(),
          challenger: _arm(),
          qualityComparison: qualityComparison,
          performancePairs: _pairs(20),
        );
        expect(result.status, ReleaseGateStatus.insufficientEvidence);
        expect(
          result.reasons,
          contains(ReleaseGateReason.qualityEvidenceInsufficient),
        );
      }
    });

    test('missing multiplicity identity is insufficient evidence', () {
      final invalidPolicy = QualityComparisonPolicy(
        requiredDimensions: const {'overall'},
        minimumPairCounts: const {'overall': 20},
        nonInferiorityMargins: const {'overall': 0},
        familyWiseAlpha: 0.05,
        multiplicityMethodIdentity: '',
      );
      final result = gate.evaluate(
        champion: _arm(),
        challenger: _arm(),
        qualityComparison: QualityComparisonEvidence(
          policy: invalidPolicy,
          dimensions: _quality().dimensions,
        ),
        performancePairs: _pairs(20),
      );

      expect(result.status, ReleaseGateStatus.insufficientEvidence);
      expect(
        result.reasons,
        contains(ReleaseGateReason.qualityEvidenceInsufficient),
      );
    });
  });
}

ReleaseArmEvidence _arm({
  bool pass3Passed = true,
  bool safetyPassed = true,
  bool transactionPassed = true,
  int expectedAttemptCount = 3,
  List<TrialAttemptObservation>? attempts,
}) => ReleaseArmEvidence(
  pass3Passed: pass3Passed,
  safetyPassed: safetyPassed,
  transactionPassed: transactionPassed,
  expectedAttemptCount: expectedAttemptCount,
  attempts:
      attempts ??
      [_attempt('attempt-1'), _attempt('attempt-2'), _attempt('attempt-3')],
);

QualityComparisonPolicy _policy({
  Set<String> requiredDimensions = const {'overall'},
}) => QualityComparisonPolicy(
  requiredDimensions: requiredDimensions,
  minimumPairCounts: {
    for (final dimension in requiredDimensions) dimension: 20,
  },
  nonInferiorityMargins: {
    for (final dimension in requiredDimensions) dimension: 0,
  },
  familyWiseAlpha: 0.05,
  multiplicityMethodIdentity: 'holm-bonferroni-v1',
);

QualityComparisonEvidence _quality({
  double championMean = 99,
  double challengerMean = 99,
  double championP10 = 97,
  double challengerP10 = 97,
  double championMin = 96,
  double challengerMin = 96,
  int pairCount = 30,
  double? lowerConfidenceBound = 0,
}) => QualityComparisonEvidence(
  policy: _policy(),
  dimensions: [
    QualityDimensionComparison(
      dimensionId: 'overall',
      pairCount: pairCount,
      championMean: championMean,
      challengerMean: challengerMean,
      championP10: championP10,
      challengerP10: challengerP10,
      championMin: championMin,
      challengerMin: challengerMin,
      nonInferiorityLowerConfidenceBound: lowerConfidenceBound,
    ),
  ],
);

TrialAttemptObservation _attempt(
  String id, {
  TrialAttemptKind kind = TrialAttemptKind.content,
  bool succeeded = true,
  int costMicrousd = 100,
}) => TrialAttemptObservation(
  attemptId: id,
  kind: kind,
  succeeded: succeeded,
  latencyMs: 100,
  promptTokens: 10,
  completionTokens: succeeded ? 10 : 0,
  costMicrousd: costMicrousd,
);

List<PairedPerformanceObservation> _pairs(
  int count, {
  int challengerLatencyMs = 100,
}) => [
  for (var index = 0; index < count; index += 1)
    PairedPerformanceObservation(
      pairId: 'pair-$index',
      championLatencyMs: 100,
      challengerLatencyMs: challengerLatencyMs,
    ),
];
