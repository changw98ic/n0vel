import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_execution_budget.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_non_release_canary_client.dart';

void main() {
  test('single-dispatch canary records exact identity and usage', () async {
    final inner = _RecordingClient(
      const AppLlmChatResult.success(
        text: 'ok',
        providerModel: 'glm-5.2',
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15,
        latencyMs: 7,
      ),
    );
    final client = _client(inner: inner, maxCalls: 2);

    final result = await client.chat(_request());

    expect(result.succeeded, isTrue);
    expect(inner.dispatches, 1);
    expect(inner.lastRequest!.preferStreaming, isFalse);
    expect(client.calls, hasLength(1));
    expect(client.calls.single.providerModel, 'glm-5.2');
    expect(client.calls.single.accounting, 'exact');
    expect(client.budgetSnapshot.calls, 1);
    expect(client.budgetSnapshot.totalTokens, 15);
  });

  test('provider model substitution aborts the canary permanently', () async {
    final inner = _RecordingClient(
      const AppLlmChatResult.success(
        text: 'ok',
        providerModel: 'glm-auto-substitute',
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15,
      ),
    );
    final client = _client(inner: inner, maxCalls: 3);

    await expectLater(
      client.chat(_request()),
      throwsA(
        isA<AgentEvaluationNonReleaseCanaryException>().having(
          (error) => error.code,
          'code',
          'provider-model-mismatch',
        ),
      ),
    );
    await expectLater(
      client.chat(_request()),
      throwsA(
        isA<AgentEvaluationNonReleaseCanaryException>().having(
          (error) => error.code,
          'code',
          'canary-already-aborted',
        ),
      ),
    );
    expect(inner.dispatches, 1);
    expect(client.calls.single.accounting, 'reserved-upper-bound');
  });

  test('missing provider model identity aborts after one dispatch', () async {
    final inner = _RecordingClient(
      const AppLlmChatResult.success(
        text: 'ok',
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15,
      ),
    );
    final client = _client(inner: inner, maxCalls: 3);

    await expectLater(
      client.chat(_request()),
      throwsA(
        isA<AgentEvaluationNonReleaseCanaryException>().having(
          (error) => error.code,
          'code',
          'provider-model-missing',
        ),
      ),
    );
    expect(inner.dispatches, 1);
    expect(client.calls.single.failureCode, 'provider-model-missing');
  });

  test('missing exact usage aborts after the first response', () async {
    final inner = _RecordingClient(
      const AppLlmChatResult.success(text: 'ok', providerModel: 'glm-5.2'),
    );
    final client = _client(inner: inner, maxCalls: 3);

    await expectLater(
      client.chat(_request()),
      throwsA(
        isA<AgentEvaluationNonReleaseCanaryException>().having(
          (error) => error.code,
          'code',
          'provider-usage-indeterminate',
        ),
      ),
    );
    expect(inner.dispatches, 1);
    expect(client.budgetSnapshot.failedCalls, 1);
  });

  test(
    'global call cap denies dispatch before crossing the provider',
    () async {
      final inner = _RecordingClient(
        const AppLlmChatResult.success(
          text: 'ok',
          providerModel: 'glm-5.2',
          promptTokens: 10,
          completionTokens: 5,
          totalTokens: 15,
        ),
      );
      final client = _client(inner: inner, maxCalls: 1);

      await client.chat(_request());
      await expectLater(
        client.chat(_request()),
        throwsA(
          isA<AgentEvaluationBudgetException>().having(
            (error) => error.code,
            'code',
            'budget-reservation-exhausted',
          ),
        ),
      );
      expect(inner.dispatches, 1);
    },
  );

  test('unbounded completion is clamped before provider dispatch', () async {
    final inner = _RecordingClient(
      const AppLlmChatResult.success(
        text: 'ok',
        providerModel: 'glm-5.2',
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15,
      ),
    );
    final client = _client(inner: inner, maxCalls: 1);
    final normal = _request();
    final request = AppLlmChatRequest(
      baseUrl: normal.baseUrl,
      apiKey: normal.apiKey,
      model: normal.model,
      provider: normal.provider,
      messages: normal.messages,
    );

    final result = await client.chat(request);
    expect(result.succeeded, isTrue);
    expect(inner.dispatches, 1);
    expect(inner.lastRequest!.maxTokens, AppLlmChatRequest.defaultMaxTokens);
    expect(client.budgetSnapshot.totalTokens, 15);
  });

  test(
    'worst-case token reservation is denied before provider dispatch',
    () async {
      final inner = _RecordingClient(
        const AppLlmChatResult.success(text: 'unused'),
      );
      final client = _client(inner: inner, maxCalls: 1, maxTotalTokens: 5000);

      await expectLater(
        client.chat(_request()),
        throwsA(
          isA<AgentEvaluationBudgetException>().having(
            (error) => error.code,
            'code',
            'budget-reservation-exhausted',
          ),
        ),
      );
      expect(inner.dispatches, 0);
    },
  );

  test('expired deadline denies dispatch before provider use', () async {
    var nowMs = 1000;
    final inner = _RecordingClient(
      const AppLlmChatResult.success(text: 'unused'),
    );
    final client = _client(
      inner: inner,
      maxCalls: 1,
      deadlineAtMs: 1100,
      nowMs: () => nowMs,
    );
    nowMs = 1100;

    await expectLater(
      client.chat(_request()),
      throwsA(
        isA<AgentEvaluationBudgetException>().having(
          (error) => error.code,
          'code',
          'deadline-exhausted',
        ),
      ),
    );
    expect(inner.dispatches, 0);
  });

  test('nonzero frozen price policy is rejected before use', () {
    final routeHash = _routeHash;
    final budget = AgentEvaluationExecutionBudgetGuard(
      policy: AgentEvaluationExecutionBudgetPolicy(
        budgetId: 'non-release-canary-test',
        maxCalls: 1,
        maxPromptTokens: 100000,
        maxCompletionTokens: 100000,
        maxTotalTokens: 100000,
        maxCostMicrousd: 100000,
        deadlineAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
        routes: [
          AgentEvaluationBudgetRoute(
            modelRouteHash: routeHash,
            model: 'glm-5.2',
            maxPromptTokensPerCall: 100000,
            promptMicrousdPerMillionTokens: 1,
            completionMicrousdPerMillionTokens: 0,
          ),
        ],
      ),
    );

    expect(
      () => AgentEvaluationNonReleaseCanaryClient(
        inner: _RecordingClient(const AppLlmChatResult.success(text: 'unused')),
        budget: budget,
        expectedModel: 'glm-5.2',
        expectedProvider: AppLlmProvider.zhipu,
        expectedBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        frozenApiKey: 'secret',
        modelRouteHash: routeHash,
      ),
      throwsA(
        isA<AgentEvaluationNonReleaseCanaryException>().having(
          (error) => error.code,
          'code',
          'nonzero-price-policy',
        ),
      ),
    );
  });

  test('explicit cost-unbounded mode retains non-cost hard gates', () async {
    final routeHash = _routeHash;
    final inner = _RecordingClient(
      const AppLlmChatResult.success(
        text: 'ok',
        providerModel: 'glm-5.2',
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15,
      ),
    );
    final budget = AgentEvaluationExecutionBudgetGuard(
      policy: AgentEvaluationExecutionBudgetPolicy(
        budgetId: 'cost-unbounded-canary-test',
        maxCalls: 1,
        maxPromptTokens: 100000,
        maxCompletionTokens: 100000,
        maxTotalTokens: 100000,
        maxCostMicrousd: 0,
        deadlineAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
        costEnforcement: AgentEvaluationCostEnforcement.disabled,
        routes: [
          AgentEvaluationBudgetRoute(
            modelRouteHash: routeHash,
            model: 'glm-5.2',
            maxPromptTokensPerCall: 100000,
            promptMicrousdPerMillionTokens: 0,
            completionMicrousdPerMillionTokens: 0,
          ),
        ],
      ),
    );
    expect(
      budget.policy.costEnforcement,
      AgentEvaluationCostEnforcement.disabled,
    );
    final client = AgentEvaluationNonReleaseCanaryClient(
      inner: inner,
      budget: budget,
      expectedModel: 'glm-5.2',
      expectedProvider: AppLlmProvider.zhipu,
      expectedBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      frozenApiKey: 'secret',
      modelRouteHash: routeHash,
      enforceZeroCost: false,
    );

    await client.chat(_request());
    await expectLater(
      client.chat(_request()),
      throwsA(
        isA<AgentEvaluationBudgetException>().having(
          (error) => error.code,
          'code',
          'budget-reservation-exhausted',
        ),
      ),
    );
    expect(inner.dispatches, 1);
  });
}

final String _routeHash = AgentEvaluationHashes.domainHash(
  'non-release-canary-route-v1',
  const <String, Object?>{
    'provider': 'zhipu',
    'baseUrl': 'https://open.bigmodel.cn/api/paas/v4',
    'model': 'glm-5.2',
  },
);

AgentEvaluationNonReleaseCanaryClient _client({
  required AppLlmClient inner,
  required int maxCalls,
  int maxTotalTokens = 100000,
  int? deadlineAtMs,
  int Function()? nowMs,
}) {
  final budget = AgentEvaluationExecutionBudgetGuard(
    policy: AgentEvaluationExecutionBudgetPolicy(
      budgetId: 'non-release-canary-test',
      maxCalls: maxCalls,
      maxPromptTokens: maxTotalTokens,
      maxCompletionTokens: maxTotalTokens,
      maxTotalTokens: maxTotalTokens,
      maxCostMicrousd: 0,
      deadlineAtMs:
          deadlineAtMs ?? DateTime.now().millisecondsSinceEpoch + 60000,
      routes: [
        AgentEvaluationBudgetRoute(
          modelRouteHash: _routeHash,
          model: 'glm-5.2',
          maxPromptTokensPerCall: maxTotalTokens,
          promptMicrousdPerMillionTokens: 0,
          completionMicrousdPerMillionTokens: 0,
        ),
      ],
    ),
    nowMs: nowMs,
  );
  return AgentEvaluationNonReleaseCanaryClient(
    inner: inner,
    budget: budget,
    expectedModel: 'glm-5.2',
    expectedProvider: AppLlmProvider.zhipu,
    expectedBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    frozenApiKey: 'secret',
    modelRouteHash: _routeHash,
  );
}

AppLlmChatRequest _request() => const AppLlmChatRequest(
  baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
  apiKey: 'secret',
  model: 'glm-5.2',
  provider: AppLlmProvider.zhipu,
  maxTokens: 4096,
  messages: [AppLlmChatMessage(role: 'user', content: 'ping')],
);

final class _RecordingClient implements AppLlmClient {
  _RecordingClient(this.result);

  final AppLlmChatResult result;
  int dispatches = 0;
  AppLlmChatRequest? lastRequest;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    dispatches += 1;
    lastRequest = request;
    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      const Stream<String>.empty();
}
