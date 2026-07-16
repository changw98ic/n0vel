import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_trace_summary.dart';

void main() {
  group('AppLlmTraceSummary', () {
    test('reports configured and observed concurrency separately', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'startedAtMs': 100,
            'completedAtMs': 300,
            'timestampMs': 300,
            'traceName': 'scene_roleplay',
            'stageId': 'roleplay',
            'succeeded': true,
            'promptTokens': 10,
            'completionTokens': 20,
          },
          <String, Object?>{
            'startedAtMs': 200,
            'completedAtMs': 400,
            'timestampMs': 400,
            'traceName': 'scene_review',
            'stageId': 'review',
            'succeeded': true,
            'promptTokens': 30,
            'completionTokens': 40,
          },
          <String, Object?>{
            'startedAtMs': 400,
            'completedAtMs': 450,
            'timestampMs': 450,
            'traceName': 'scene_review',
            'stageId': 'review',
            'succeeded': false,
          },
        ],
        configuredSceneConcurrency: 3,
        configuredRequestConcurrency: 8,
      );

      expect(summary.configuredSceneConcurrency, 3);
      expect(summary.configuredRequestConcurrency, 8);
      expect(summary.observedMaxConcurrency, 2);
      expect(summary.timingEvidence, AppLlmTraceTimingEvidence.exact);
      expect(summary.totalCalls, 3);
      expect(summary.succeededCalls, 2);
      expect(summary.failedCalls, 1);
      expect(summary.promptTokens, 40);
      expect(summary.completionTokens, 60);
      expect(summary.stageCounts, <String, int>{'roleplay': 1, 'review': 2});
    });

    test('labels timestamp minus latency reconstruction as inferred', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'timestampMs': 200,
            'latencyMs': 100,
            'traceName': 'scene_review',
            'succeeded': true,
          },
          <String, Object?>{
            'timestampMs': 300,
            'latencyMs': 100,
            'traceName': 'scene_review',
            'succeeded': true,
          },
        ],
        configuredSceneConcurrency: 3,
        configuredRequestConcurrency: 1,
      );

      expect(summary.observedMaxConcurrency, 1);
      expect(summary.timingEvidence, AppLlmTraceTimingEvidence.inferred);
      expect(summary.toJson()['observedConcurrencyIsInferred'], isTrue);
    });

    test('counts explicit retry and replan metadata without guessing', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'timestampMs': 100,
            'latencyMs': 50,
            'traceName': 'scene_review',
            'succeeded': true,
            'metadata': <String, Object?>{
              'reviewDecision': 'replanScene',
              'retryAttempt': 1,
            },
          },
          <String, Object?>{
            'timestampMs': 200,
            'latencyMs': 50,
            'traceName': 'scene_review',
            'succeeded': true,
            'metadata': <String, Object?>{
              'reviewDecision': 'pass',
              'retryAttempt': 2,
            },
          },
        ],
        configuredSceneConcurrency: 1,
        configuredRequestConcurrency: 1,
      );

      expect(summary.replanDecisions, 1);
      expect(summary.retryCalls, 1);
      expect(summary.traceNameCounts, <String, int>{'scene_review': 2});
    });

    test('counts the production zero-based retry metadata contract', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'traceName': 'editorial',
            'succeeded': false,
            'metadata': <String, Object?>{
              'attempt': 0,
              'transientRetryCount': 0,
              'outputRetryCount': 0,
              'stageId': 'editorial',
            },
          },
          <String, Object?>{
            'traceName': 'editorial',
            'succeeded': true,
            'metadata': <String, Object?>{
              'attempt': 1,
              'transientRetryCount': 1,
              'outputRetryCount': 0,
              'stageId': 'editorial',
            },
          },
        ],
        configuredSceneConcurrency: 3,
        configuredRequestConcurrency: 1,
      );

      expect(summary.retryCalls, 1);
      expect(summary.retryMetadataCalls, 2);
      expect(summary.stageCounts, <String, int>{'editorial': 2});
    });

    test('does not infer retry or replan from names and loose metadata', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'traceName': 'retry_replan_scene',
            'succeeded': true,
            'metadata': <String, Object?>{
              'retryAttempt': '2',
              'reviewDecision': 'replanScene ',
            },
          },
          <String, Object?>{
            'traceName': 'scene_retry',
            'succeeded': false,
            'metadata': <String, Object?>{
              'retryAttempt': 1,
              'reviewDecision': 'rewriteProse',
            },
          },
        ],
        configuredSceneConcurrency: 1,
        configuredRequestConcurrency: 1,
      );

      expect(summary.retryCalls, 0);
      expect(summary.replanDecisions, 0);
    });

    test('audits physical gateway retries and fallback dispatches', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'traceName': 'scene_roleplay_turn',
            'succeeded': false,
            'metadata': <String, Object?>{
              'endpointId': 'primary',
              'endpointIndex': 0,
              'gatewayRetryIndex': 0,
              'wasFallback': false,
            },
          },
          <String, Object?>{
            'traceName': 'scene_roleplay_turn',
            'succeeded': false,
            'metadata': <String, Object?>{
              'endpointId': 'primary',
              'endpointIndex': 0,
              'gatewayRetryIndex': 1,
              'wasFallback': false,
            },
          },
          <String, Object?>{
            'traceName': 'scene_roleplay_turn',
            'succeeded': true,
            'metadata': <String, Object?>{
              'endpointId': 'fallback',
              'endpointIndex': 1,
              'gatewayRetryIndex': 0,
              'wasFallback': true,
            },
          },
        ],
        configuredSceneConcurrency: 1,
        configuredRequestConcurrency: 1,
      );

      expect(summary.physicalDispatchCalls, 3);
      expect(summary.gatewayRetryCalls, 1);
      expect(summary.fallbackCalls, 1);
      expect(summary.retryCalls, 1);
      expect(summary.retryMetadataCalls, 3);
      expect(summary.totalCalls, 3);
      expect(summary.toJson()['physicalDispatchCalls'], 3);
      expect(summary.toJson()['gatewayRetryCalls'], 1);
      expect(summary.toJson()['fallbackCalls'], 1);
    });

    test(
      'ends an interval before starting another at the same millisecond',
      () {
        final summary = AppLlmTraceSummary.fromJsonEntries(
          const <Map<String, Object?>>[
            <String, Object?>{
              'startedAtMs': 100,
              'completedAtMs': 200,
              'timestampMs': 200,
              'traceName': 'first',
              'succeeded': true,
            },
            <String, Object?>{
              'startedAtMs': 200,
              'completedAtMs': 300,
              'timestampMs': 300,
              'traceName': 'second',
              'succeeded': true,
            },
          ],
          configuredSceneConcurrency: 2,
          configuredRequestConcurrency: 2,
        );

        expect(summary.observedMaxConcurrency, 1);
        expect(summary.timingEvidence, AppLlmTraceTimingEvidence.exact);
      },
    );

    test('marks mixed exact and reconstructed timing evidence', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'startedAtMs': 100,
            'completedAtMs': 300,
            'timestampMs': 300,
            'latencyMs': 200,
            'traceName': 'exact',
            'succeeded': true,
          },
          <String, Object?>{
            'timestampMs': 250,
            'latencyMs': 100,
            'traceName': 'legacy',
            'succeeded': true,
          },
        ],
        configuredSceneConcurrency: 2,
        configuredRequestConcurrency: 2,
      );

      expect(summary.observedMaxConcurrency, 2);
      expect(summary.timingEvidence, AppLlmTraceTimingEvidence.mixed);
      expect(summary.toJson()['observedConcurrencyIsInferred'], isTrue);
      expect(summary.toJson()['exactTimingCalls'], 1);
      expect(summary.toJson()['inferredTimingCalls'], 1);
    });

    test('does not fabricate intervals from malformed timing evidence', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'startedAtMs': 300,
            'completedAtMs': 200,
            'timestampMs': 300,
            'latencyMs': 100,
            'traceName': 'contradictory-exact',
            'succeeded': false,
          },
          <String, Object?>{
            'timestampMs': 100,
            'latencyMs': -5,
            'traceName': 'negative-latency',
            'succeeded': false,
          },
          <String, Object?>{'traceName': 'untimed', 'succeeded': true},
        ],
        configuredSceneConcurrency: 4,
        configuredRequestConcurrency: 8,
      );

      expect(summary.observedMaxConcurrency, 0);
      expect(summary.timingEvidence, AppLlmTraceTimingEvidence.none);
      expect(summary.toJson()['malformedTimingCalls'], 2);
      expect(summary.toJson()['untimedCalls'], 1);
    });

    test('reports evidence coverage instead of treating unknown as zero', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'traceName': 'roleplay',
            'succeeded': true,
            'metadata': <String, Object?>{
              'attempt': 0,
              'stageId': 'roleplay',
              'agentId': 'character-liuxi',
            },
          },
          <String, Object?>{'traceName': 'review', 'succeeded': true},
        ],
        configuredSceneConcurrency: 2,
        configuredRequestConcurrency: 3,
      );

      expect(summary.retryCalls, 0);
      expect(summary.retryMetadataCalls, 1);
      expect(summary.replanDecisions, 0);
      expect(summary.reviewDecisionMetadataCalls, 0);
      expect(summary.stageTaggedCalls, 1);
      expect(summary.agentCounts, <String, int>{'character-liuxi': 1});
      expect(summary.toJson()['stageUntaggedCalls'], 1);
      expect(summary.toJson()['agentUntaggedCalls'], 1);
    });

    test('empty input has no complete or exact concurrency evidence', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[],
        configuredSceneConcurrency: 1,
        configuredRequestConcurrency: 1,
      );

      expect(summary.toJson()['timingCoverageComplete'], isFalse);
      expect(summary.toJson()['observedConcurrencyIsExact'], isFalse);
    });

    test('audits tokens by stage and trace name', () {
      final summary = AppLlmTraceSummary.fromJsonEntries(
        const <Map<String, Object?>>[
          <String, Object?>{
            'traceName': 'review-call',
            'stageId': 'review',
            'succeeded': true,
            'promptTokens': 10,
            'completionTokens': 5,
          },
          <String, Object?>{
            'traceName': 'review-call',
            'stageId': 'review',
            'succeeded': false,
            'promptTokens': 7,
            'completionTokens': 3,
            'totalTokens': 12,
          },
          <String, Object?>{
            'traceName': 'prose-call',
            'stageId': 'prose',
            'succeeded': true,
            'totalTokens': 20,
          },
        ],
        configuredSceneConcurrency: 1,
        configuredRequestConcurrency: 1,
      );

      expect(summary.totalTokens, 47);
      expect(summary.stageTokenTotals, <String, int>{
        'prose': 20,
        'review': 27,
      });
      expect(summary.traceNameTokenTotals, <String, int>{
        'prose-call': 20,
        'review-call': 27,
      });
    });
  });
}
