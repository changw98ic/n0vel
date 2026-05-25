import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/model_router.dart';

void main() {
  group('DefaultModelRouter', () {
    test('routes review gates to the highest quality valid profile', () {
      final decision = const DefaultModelRouter().choose(
        ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.reviewGate,
          estimatedInputTokens: 1500,
          estimatedOutputTokens: 700,
          profiles: [
            _profile(
              id: 'cheap-summary',
              qualityScore: 0.76,
              inputCostPerMillionTokens: 0.2,
              outputCostPerMillionTokens: 0.4,
            ),
            _profile(
              id: 'quality-review',
              qualityScore: 0.96,
              inputCostPerMillionTokens: 8,
              outputCostPerMillionTokens: 24,
            ),
          ],
        ),
      );

      expect(decision.status, ModelRouteDecisionStatus.selected);
      expect(decision.selectedProfileId, 'quality-review');
      expect(decision.reasonCodes, contains('quality_floor_passed'));
      expect(decision.fallbackProfileIds, isEmpty);
    });

    test(
      'routes summaries to the cheapest profile above the quality floor',
      () {
        final decision = const DefaultModelRouter().choose(
          ModelRouteRequest(
            taskKind: ModelRoutingTaskKind.summary,
            estimatedInputTokens: 3000,
            estimatedOutputTokens: 800,
            profiles: [
              _profile(
                id: 'quality-review',
                qualityScore: 0.96,
                inputCostPerMillionTokens: 8,
                outputCostPerMillionTokens: 24,
              ),
              _profile(
                id: 'cheap-summary',
                qualityScore: 0.74,
                inputCostPerMillionTokens: 0.1,
                outputCostPerMillionTokens: 0.2,
              ),
            ],
          ),
        );

        expect(decision.status, ModelRouteDecisionStatus.selected);
        expect(decision.selectedProfileId, 'cheap-summary');
        expect(decision.reasonCodes, contains('cost_sensitive_task'));
        expect(decision.fallbackProfileIds, isEmpty);
        expect(decision.rejectedProfileIds, contains('quality-review'));
        expect(
          decision.rejectionReasons['quality-review'],
          contains('cost_hard_target_exceeded'),
        );
      },
    );

    test('uses configurable quality thresholds', () {
      const policy = ModelRoutingPolicy(
        thresholdsByTask: {
          ModelRoutingTaskKind.sceneDraft: ModelQualityThreshold(
            minimum: 0.9,
            preferred: 0.95,
          ),
        },
      );

      final decision = const DefaultModelRouter(policy: policy).choose(
        ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.sceneDraft,
          estimatedInputTokens: 2000,
          estimatedOutputTokens: 2000,
          profiles: [
            _profile(id: 'mid', qualityScore: 0.89),
            _profile(id: 'strong', qualityScore: 0.91),
          ],
        ),
      );

      expect(decision.status, ModelRouteDecisionStatus.selected);
      expect(decision.selectedProfileId, 'strong');
      expect(decision.rejectedProfileIds, contains('mid'));
      expect(
        decision.rejectionReasons['mid'],
        contains('quality_floor_failed'),
      );
    });

    test('estimates costs from input and output token prices', () {
      final profile = _profile(
        id: 'metered',
        qualityScore: 0.93,
        inputCostPerMillionTokens: 2,
        outputCostPerMillionTokens: 6,
      );

      final decision = const DefaultModelRouter().choose(
        ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.polish,
          estimatedInputTokens: 1000000,
          estimatedOutputTokens: 500000,
          profiles: [profile],
        ),
      );

      expect(decision.status, ModelRouteDecisionStatus.selected);
      expect(decision.estimatedCostUsd, 5.0);
      expect(
        const DefaultModelRouter().estimateCostUsd(
          profile,
          estimatedInputTokens: 1000000,
          estimatedOutputTokens: 500000,
        ),
        5.0,
      );
    });

    test(
      'respects manual profile selection without bypassing safety filters',
      () {
        final insecure = _profile(
          id: 'insecure',
          baseUrl: 'http://api.example.test/v1',
          qualityScore: 0.98,
        );

        final decision = const DefaultModelRouter().choose(
          ModelRouteRequest(
            taskKind: ModelRoutingTaskKind.sceneDraft,
            estimatedInputTokens: 100,
            estimatedOutputTokens: 100,
            manualProfileId: insecure.id,
            profiles: [
              insecure,
              _profile(id: 'safe', qualityScore: 0.92),
            ],
          ),
        );

        expect(decision.status, ModelRouteDecisionStatus.needsUserAction);
        expect(decision.selectedProfileId, isNull);
        expect(decision.reasonCodes, contains('manual_profile_rejected'));
        expect(
          decision.rejectionReasons['insecure'],
          contains('insecure_scheme'),
        );
      },
    );

    test('rejects a manual profile below the task quality floor', () {
      final decision = const DefaultModelRouter().choose(
        ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.reviewGate,
          estimatedInputTokens: 100,
          estimatedOutputTokens: 100,
          manualProfileId: 'weak-manual',
          profiles: [
            _profile(id: 'weak-manual', qualityScore: 0.7),
            _profile(id: 'strong-auto', qualityScore: 0.96),
          ],
        ),
      );

      expect(decision.status, ModelRouteDecisionStatus.needsUserAction);
      expect(decision.selectedProfileId, isNull);
      expect(decision.reasonCodes, contains('manual_profile_rejected'));
      expect(
        decision.rejectionReasons['weak-manual'],
        contains('quality_floor_failed'),
      );
    });

    test('treats blank manual profile ids as automatic routing', () {
      final decision = const DefaultModelRouter().choose(
        ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.reviewGate,
          estimatedInputTokens: 100,
          estimatedOutputTokens: 100,
          manualProfileId: '   ',
          profiles: [
            _profile(id: 'weak', qualityScore: 0.7),
            _profile(id: 'strong', qualityScore: 0.95),
          ],
        ),
      );

      expect(decision.status, ModelRouteDecisionStatus.selected);
      expect(decision.selectedProfileId, 'strong');
      expect(decision.reasonCodes, isNot(contains('manual_profile_selected')));
      expect(decision.rejectedProfileIds, contains('weak'));
      expect(
        decision.rejectionReasons['weak'],
        contains('quality_floor_failed'),
      );
    });

    test('filters cost-sensitive profiles above the hard target', () {
      final decision = const DefaultModelRouter().choose(
        ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.summary,
          estimatedInputTokens: 1000000,
          estimatedOutputTokens: 0,
          profiles: [
            _profile(
              id: 'expensive-summary',
              qualityScore: 0.95,
              inputCostPerMillionTokens: 0.06,
            ),
            _profile(
              id: 'within-budget-summary',
              qualityScore: 0.8,
              inputCostPerMillionTokens: 0.02,
            ),
          ],
        ),
      );

      expect(decision.status, ModelRouteDecisionStatus.selected);
      expect(decision.selectedProfileId, 'within-budget-summary');
      expect(decision.reasonCodes, contains('cost_hard_target_passed'));
      expect(decision.rejectedProfileIds, contains('expensive-summary'));
      expect(
        decision.rejectionReasons['expensive-summary'],
        contains('cost_hard_target_exceeded'),
      );
    });

    test(
      'does not cross privacy boundaries when local-only routing is used',
      () {
        final decision = const DefaultModelRouter().choose(
          ModelRouteRequest(
            taskKind: ModelRoutingTaskKind.utility,
            privacyMode: ModelRoutePrivacyMode.localOnly,
            estimatedInputTokens: 500,
            estimatedOutputTokens: 100,
            profiles: [
              _profile(id: 'remote', qualityScore: 0.95),
              _profile(
                id: 'local',
                baseUrl: 'http://127.0.0.1:11434/v1',
                hasApiKey: false,
                qualityScore: 0.7,
                inputCostPerMillionTokens: 0,
                outputCostPerMillionTokens: 0,
              ),
            ],
          ),
        );

        expect(decision.status, ModelRouteDecisionStatus.selected);
        expect(decision.selectedProfileId, 'local');
        expect(decision.fallbackProfileIds, isEmpty);
        expect(decision.rejectedProfileIds, contains('remote'));
        expect(
          decision.rejectionReasons['remote'],
          contains('privacy_local_only'),
        );
      },
    );

    test('prefers lower-latency fallback after timeouts', () {
      final decision = const DefaultModelRouter().choose(
        ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.sceneDraft,
          previousFailureKind: AppLlmFailureKind.timeout,
          excludedProfileIds: {'slow-quality'},
          estimatedInputTokens: 1000,
          estimatedOutputTokens: 1000,
          profiles: [
            _profile(
              id: 'slow-quality',
              qualityScore: 0.95,
              latencyP95Ms: 4000,
            ),
            _profile(id: 'fast-valid', qualityScore: 0.89, latencyP95Ms: 700),
            _profile(id: 'slow-valid', qualityScore: 0.9, latencyP95Ms: 2200),
          ],
        ),
      );

      expect(decision.status, ModelRouteDecisionStatus.selected);
      expect(decision.selectedProfileId, 'fast-valid');
      expect(decision.reasonCodes, contains('timeout_fallback'));
      expect(decision.fallbackProfileIds, contains('slow-valid'));
      expect(decision.rejectedProfileIds, contains('slow-quality'));
    });

    test('emits a redacted decision trace', () {
      final decision = const DefaultModelRouter().choose(
        ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.summary,
          estimatedInputTokens: 20,
          estimatedOutputTokens: 10,
          profiles: [_profile(id: 'safe-summary', qualityScore: 0.8)],
        ),
      );

      final trace = decision.toTraceJson();
      final traceText = trace.toString();

      expect(trace['kind'], 'model_route_decision');
      expect(trace['selectedProfileId'], 'safe-summary');
      expect(trace.containsKey('estimatedCostUsd'), isTrue);
      expect(traceText, isNot(contains('apiKey')));
      expect(traceText, isNot(contains('Authorization')));
      expect(traceText, isNot(contains('messages')));
      expect(traceText, isNot(contains('prompt')));
      expect(traceText, isNot(contains('https://')));
    });
  });
}

ModelRouteProfile _profile({
  required String id,
  String baseUrl = 'https://api.example.test/v1',
  bool hasApiKey = true,
  double qualityScore = 0.9,
  double inputCostPerMillionTokens = 1,
  double outputCostPerMillionTokens = 3,
  int latencyP95Ms = 1000,
  Set<ModelRouteCapability> capabilities = const {
    ModelRouteCapability.chat,
    ModelRouteCapability.streaming,
    ModelRouteCapability.jsonMode,
  },
}) {
  return ModelRouteProfile(
    id: id,
    providerName: 'test',
    baseUrl: baseUrl,
    model: id,
    hasApiKey: hasApiKey,
    qualityScore: qualityScore,
    inputCostPerMillionTokens: inputCostPerMillionTokens,
    outputCostPerMillionTokens: outputCostPerMillionTokens,
    latencyP95Ms: latencyP95Ms,
    capabilities: capabilities,
  );
}
