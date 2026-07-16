import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/pass3_evaluation.dart';

void main() {
  group('Pass3Evaluator', () {
    const evaluator = Pass3Evaluator();

    test('passes only three distinct independent hard-pass slots', () {
      final result = evaluator.evaluate([
        _slot(1, digest: 'digest-1'),
        _slot(2, digest: 'digest-2'),
        _slot(3, digest: 'digest-3'),
      ]);

      expect(result.passed, isTrue);
      expect(result.failureReasons, isEmpty);
      expect(result.declaredSlotsSeen, 3);
    });

    test('requires all three declared logical slots', () {
      final result = evaluator.evaluate([
        _slot(1, digest: 'digest-1'),
        _slot(2, digest: 'digest-2'),
      ]);

      expect(result.passed, isFalse);
      expect(result.failureReasons, contains(Pass3Failure.missingSlot));
    });

    test('rejects repeated content digests across slots', () {
      final result = evaluator.evaluate([
        _slot(1, digest: 'same-digest'),
        _slot(2, digest: 'same-digest'),
        _slot(3, digest: 'digest-3'),
      ]);

      expect(result.passed, isFalse);
      expect(result.failureReasons, contains(Pass3Failure.reusedContent));
    });

    test('rejects an explicitly non-independent slot', () {
      final result = evaluator.evaluate([
        _slot(1, digest: 'digest-1'),
        _slot(
          2,
          digest: 'digest-2',
          independence: TrialIndependence.nonIndependent,
        ),
        _slot(3, digest: 'digest-3'),
      ]);

      expect(result.passed, isFalse);
      expect(result.failureReasons, contains(Pass3Failure.nonIndependent));
    });

    test('rejects malformed content digests', () {
      final result = evaluator.evaluate([
        _slot(1, digest: 'digest-1'),
        const TrialSlotOutcome(
          trialNo: 2,
          hardPass: true,
          evidenceComplete: true,
          contentDigest: 'caller-forged',
          independence: TrialIndependence.independent,
        ),
        _slot(3, digest: 'digest-3'),
      ]);

      expect(result.passed, isFalse);
      expect(
        result.failureReasons,
        contains(Pass3Failure.invalidContentDigest),
      );
    });

    test('a replacement success cannot repair a failed logical slot', () {
      final result = evaluator.evaluate([
        _slot(1, digest: 'digest-1'),
        _slot(2, digest: 'failed-digest', hardPass: false),
        _slot(3, digest: 'digest-3'),
        _slot(4, digest: 'replacement-digest', replacementSample: true),
      ]);

      expect(result.passed, isFalse);
      expect(result.failureReasons, contains(Pass3Failure.replacementSample));
      expect(result.failureReasons, contains(Pass3Failure.failedSlot));
    });
  });

  group('TransportPerformanceAggregator', () {
    const aggregator = TransportPerformanceAggregator();

    test('charges every attempt including transport failures', () {
      const attempts = [
        TrialAttemptObservation(
          attemptId: 'timeout-1',
          kind: TrialAttemptKind.transport,
          succeeded: false,
          latencyMs: 900,
          promptTokens: 30,
          completionTokens: 0,
          costMicrousd: 120,
        ),
        TrialAttemptObservation(
          attemptId: 'timeout-2',
          kind: TrialAttemptKind.transport,
          succeeded: false,
          latencyMs: 1100,
          promptTokens: 30,
          completionTokens: 0,
          costMicrousd: 130,
        ),
        TrialAttemptObservation(
          attemptId: 'content-1',
          kind: TrialAttemptKind.content,
          succeeded: true,
          latencyMs: 600,
          promptTokens: 40,
          completionTokens: 50,
          costMicrousd: 250,
        ),
      ];

      final aggregate = aggregator.aggregate(
        attempts: attempts,
        pairedPerformanceObservations: const [],
      );

      expect(aggregate.attempted, 3);
      expect(aggregate.completed, 1);
      expect(aggregate.transportFailures, 2);
      expect(aggregate.totalLatencyMs, 2600);
      expect(aggregate.totalTokens, 150);
      expect(aggregate.totalCostMicrousd, 500);
    });

    test('fewer than twenty paired observations is insufficient evidence', () {
      final pairs = List.generate(
        19,
        (index) => PairedPerformanceObservation(
          pairId: 'pair-$index',
          championLatencyMs: 100,
          challengerLatencyMs: 95,
        ),
      );

      final aggregate = aggregator.aggregate(
        attempts: const [],
        pairedPerformanceObservations: pairs,
      );

      expect(aggregate.performanceEvidence, PerformanceEvidence.insufficient);
      expect(aggregate.performanceSampleCount, 19);
    });

    test('twenty unique paired observations meets the evidence minimum', () {
      final pairs = List.generate(
        20,
        (index) => PairedPerformanceObservation(
          pairId: 'pair-$index',
          championLatencyMs: 100,
          challengerLatencyMs: 95,
        ),
      );

      final aggregate = aggregator.aggregate(
        attempts: const [],
        pairedPerformanceObservations: pairs,
      );

      expect(aggregate.performanceEvidence, PerformanceEvidence.sufficient);
      expect(aggregate.performanceSampleCount, 20);
    });
  });
}

TrialSlotOutcome _slot(
  int trialNo, {
  required String digest,
  bool hardPass = true,
  bool replacementSample = false,
  TrialIndependence independence = TrialIndependence.independent,
}) => TrialSlotOutcome(
  trialNo: trialNo,
  hardPass: hardPass,
  evidenceComplete: true,
  contentDigest: _digest(digest),
  independence: independence,
  replacementSample: replacementSample,
);

String _digest(String value) => List<String>.generate(
  64,
  (index) => ((value.codeUnitAt(index % value.length) + index) & 0xf)
      .toRadixString(16),
).join();
