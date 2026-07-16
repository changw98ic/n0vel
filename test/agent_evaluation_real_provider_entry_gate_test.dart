import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_provider_entry_gate.dart';

import 'test_support/fake_app_llm_client.dart';
import 'test_support/real_agent_evaluation_harness.dart';

void main() {
  test(
    'forgeable legacy environment cannot dispatch a provider operation',
    () async {
      final decision = AgentEvaluationRealProviderEntryGate.legacyDecision(
        entryPoint: 'adversarial-forged-entry',
        environment: const <String, String>{
          'AGENT_EVAL_RELEASE_PREFLIGHTED': '1',
          'AGENT_EVAL_RELEASE_COORDINATOR_BOOTSTRAPPED': '1',
          'RUN_REAL_AGENT_EVAL': '1',
          'RUN_REAL_NOVEL_QUALITY_BENCHMARK': '1',
          'RUN_REAL_STORY_VALIDATION': '1',
          'REAL_LLM_COST_ACK': 'YES',
          'REAL_PROVIDER_COST_ACK': 'I_ACCEPT_REAL_PROVIDER_COSTS',
          'ZHIPU_API_KEY': 'forged-test-secret',
          'ANTHROPIC_AUTH_TOKEN': 'forged-test-secret',
          'AGENT_EVAL_MAX_CALLS': '999999',
          'AGENT_EVAL_MAX_TOKENS': '999999999',
          'AGENT_EVAL_MAX_COST_MICROUSD': '999999999',
        },
      );
      var providerCalls = 0;

      expect(decision.authorized, isFalse);
      await expectLater(
        AgentEvaluationRealProviderEntryGate.rejectLegacyProviderOperation<
          void
        >(
          decision: decision,
          providerOperation: () async {
            providerCalls += 1;
          },
        ),
        throwsA(isA<AgentEvaluationLegacyRealProviderEntryException>()),
      );
      expect(providerCalls, 0);
      expect(
        decision.denialReason,
        contains('tool/agent_evaluation_release_coordinator.dart'),
      );
    },
  );

  test('legacy decision is identical with or without opt-in variables', () {
    final absent = AgentEvaluationRealProviderEntryGate.legacyDecision(
      entryPoint: 'legacy-entry',
    );
    final forged = AgentEvaluationRealProviderEntryGate.legacyDecision(
      entryPoint: 'legacy-entry',
      environment: const <String, String>{
        'AGENT_EVAL_RELEASE_PREFLIGHTED': '1',
        'RUN_REAL_AGENT_EVAL': '1',
        'REAL_LLM_COST_ACK': 'YES',
      },
    );

    expect(forged.authorized, absent.authorized);
    expect(forged.denialReason, absent.denialReason);
  });

  test(
    'legacy agent-evaluation harness returns before its provider client',
    () async {
      final authorization =
          RealAgentEvaluationAuthorization.fromEnvironmentAndSettings(
            const <String, String>{
              'RUN_REAL_AGENT_EVAL': '1',
              'REAL_LLM_COST_ACK': 'YES',
              'ZHIPU_API_KEY': 'forged-test-secret',
              'ZHIPU_BASE_URL': 'https://provider.invalid/v1',
              'AGENT_EVAL_REQUIRED_MODELS': 'glm-forged',
            },
            const <String, String>{},
          );
      final provider = FakeAppLlmClient();
      final harness = RealAgentEvaluationHarness(
        authorization: authorization,
        plan: RealAgentEvaluationReleasePlan.create(
          requiredModels: const <String>['glm-forged'],
        ),
        providerClient: provider,
        executionMode: RealAgentEvaluationExecutionMode.realProvider,
      );
      addTearDown(harness.dispose);

      final result = await harness.run();

      expect(authorization.authorized, isFalse);
      expect(result.status, RealAgentEvaluationRunStatus.skipped);
      expect(result.realProviderEvidence, isFalse);
      expect(result.providerCalls, 0);
      expect(provider.requests, isEmpty);
    },
  );

  test(
    'all legacy evaluation and benchmark entry points use the closed gate',
    () {
      const entryPoints = <String>[
        'test/real_agent_evaluation_release_matrix_test.dart',
        'test/real_chapter_generation_commit_gate_test.dart',
        'test/real_llm_provider_benchmark_test.dart',
        'test/real_novel_quality_benchmark_test.dart',
        'test/real_three_chapter_generation_test.dart',
        'test/resonance_world_one_chapter_test.dart',
        'test/pipeline/pipeline_smoke_test.dart',
        'test/pipeline/quality_benchmark_test.dart',
        'test/test_support/real_agent_evaluation_harness.dart',
        'tool/agent_evaluation_smoke_runner.dart',
      ];

      for (final path in entryPoints) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains('AgentEvaluationRealProviderEntryGate'),
          reason: '$path must remain coordinator-only',
        );
      }

      final compatibilityRunner = File(
        'tool/agent_evaluation_release_runner.dart',
      ).readAsStringSync();
      expect(compatibilityRunner, contains('release_coordinator.main'));
      expect(compatibilityRunner, isNot(contains('flutter')));
      expect(
        compatibilityRunner,
        isNot(contains('AGENT_EVAL_RELEASE_PREFLIGHTED')),
      );
    },
  );
}
