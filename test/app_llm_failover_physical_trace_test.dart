import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_call_site_inventory.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';
import 'package:novel_writer/app/llm/app_llm_trace_summary.dart';
import 'package:novel_writer/app/llm/app_product_prompt_registry.dart';
import 'package:novel_writer/app/state/ai_request_service.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/llm_provider_service.dart';

void main() {
  test(
    'production failover path traces every gateway retry and fallback dispatch once',
    () async {
      final client = _RetryThenFallbackClient();
      final traceSink = _RecordingTraceSink();
      final primaryPool = _RecordingRequestPool(maxConcurrent: 1);
      final fallbackPool = _RecordingRequestPool(maxConcurrent: 1);
      final service = AiRequestService(
        llmClient: client,
        llmTraceSink: traceSink,
        failoverGatewayProvider: (_) => AppLlmClientGateway(
          delegate: client,
          maxRetries: 2,
          baseDelayMs: 0,
        ),
      );
      final invocation = _authorizedInvocation();

      final result = await service.requestCompletion(
        snapshot: _snapshot,
        route: _primaryRoute,
        requestPool: primaryPool,
        requestPoolForProvider: (providerProfileId) =>
            providerProfileId == 'fallback' ? fallbackPool : primaryPool,
        messages: invocation.messages,
        traceName: 'scene_roleplay_turn',
        traceMetadata: const <String, Object?>{
          'agentId': 'character-liuxi',
          'agentRole': 'protagonist',
          'round': 2,
        },
        failoverEndpoints: const <FailoverEndpoint>[_fallbackEndpoint],
        promptReleaseRef: invocation.prompt.promptReleaseRef,
        promptInvocationEvidence: invocation.evidence,
        stageId: invocation.prompt.stageId,
        callSiteId: invocation.prompt.callSiteId,
        variantId: invocation.prompt.variantId,
        generationBundleHash: invocation.prompt.generationBundleHash,
        callSiteAuthority: invocation.authority,
      );

      expect(result.succeeded, isTrue);
      expect(client.models, <String>[
        'primary-model',
        'primary-model',
        'fallback-model',
      ]);
      expect(traceSink.entries, hasLength(client.models.length));
      expect(primaryPool.runCount, 2);
      expect(fallbackPool.runCount, 1);

      final metadata = traceSink.entries
          .map((entry) => entry.metadata)
          .toList(growable: false);
      expect(metadata.map((value) => value['endpointId']), <Object?>[
        'primary',
        'primary',
        'fallback',
      ]);
      expect(metadata.map((value) => value['endpointIndex']), <Object?>[
        0,
        0,
        1,
      ]);
      expect(metadata.map((value) => value['gatewayRetryIndex']), <Object?>[
        0,
        1,
        0,
      ]);
      expect(metadata.map((value) => value['wasFallback']), <Object?>[
        false,
        false,
        true,
      ]);
      expect(
        metadata.map((value) => value['poolActiveAtDispatch']),
        everyElement(1),
      );
      expect(
        metadata.map((value) => value['poolLimitAtDispatch']),
        everyElement(1),
      );
      for (final entry in traceSink.entries) {
        expect(entry.startedAtMs, isNotNull);
        expect(entry.completedAtMs, greaterThan(entry.startedAtMs!));
        expect(entry.metadata['agentId'], 'character-liuxi');
        expect(entry.metadata['agentRole'], 'protagonist');
        expect(entry.metadata['round'], 2);
      }

      final summary = AppLlmTraceSummary.fromJsonEntries(
        traceSink.entries.map((entry) => entry.toJson()),
        configuredSceneConcurrency: 1,
        configuredRequestConcurrency: 1,
      );
      expect(summary.totalCalls, client.models.length);
      expect(summary.physicalDispatchCalls, 3);
      expect(summary.gatewayRetryCalls, 1);
      expect(summary.fallbackCalls, 1);
      expect(summary.retryCalls, 1);
      expect(summary.agentCounts, <String, int>{'character-liuxi': 3});
    },
  );

  test(
    'required trace sink failure aborts a physical failover dispatch',
    () async {
      final client = _RetryThenFallbackClient();
      final sink = _ThrowingRequiredTraceSink();
      final pool = AppLlmRequestPool(maxConcurrent: 1);
      final service = AiRequestService(
        llmClient: client,
        llmTraceSink: sink,
        failoverGatewayProvider: (_) => AppLlmClientGateway(
          delegate: client,
          maxRetries: 1,
          baseDelayMs: 0,
        ),
      );
      final invocation = _authorizedInvocation();

      await expectLater(
        service.requestCompletion(
          snapshot: _snapshot,
          route: _primaryRoute,
          requestPool: pool,
          requestPoolForProvider: (_) => pool,
          messages: invocation.messages,
          failoverEndpoints: const <FailoverEndpoint>[_fallbackEndpoint],
          promptReleaseRef: invocation.prompt.promptReleaseRef,
          promptInvocationEvidence: invocation.evidence,
          stageId: invocation.prompt.stageId,
          callSiteId: invocation.prompt.callSiteId,
          variantId: invocation.prompt.variantId,
          generationBundleHash: invocation.prompt.generationBundleHash,
          callSiteAuthority: invocation.authority,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'required trace unavailable',
          ),
        ),
      );

      expect(sink.recordAttempts, 1);
      expect(client.models, <String>['primary-model']);
      expect(pool.active, 0);
    },
  );

  test(
    'optional trace sink failure preserves retries and fallback success',
    () async {
      final client = _RetryThenFallbackClient();
      final sink = _ThrowingOptionalTraceSink();
      final pool = AppLlmRequestPool(maxConcurrent: 1);
      final service = AiRequestService(
        llmClient: client,
        llmTraceSink: sink,
        failoverGatewayProvider: (_) => AppLlmClientGateway(
          delegate: client,
          maxRetries: 2,
          baseDelayMs: 0,
        ),
      );
      final invocation = _authorizedInvocation();

      final result = await service.requestCompletion(
        snapshot: _snapshot,
        route: _primaryRoute,
        requestPool: pool,
        requestPoolForProvider: (_) => pool,
        messages: invocation.messages,
        failoverEndpoints: const <FailoverEndpoint>[
          _fallbackEndpoint,
          _fallbackEndpoint,
        ],
        promptReleaseRef: invocation.prompt.promptReleaseRef,
        promptInvocationEvidence: invocation.evidence,
        stageId: invocation.prompt.stageId,
        callSiteId: invocation.prompt.callSiteId,
        variantId: invocation.prompt.variantId,
        generationBundleHash: invocation.prompt.generationBundleHash,
        callSiteAuthority: invocation.authority,
      );

      expect(result.succeeded, isTrue);
      expect(client.models, <String>[
        'primary-model',
        'primary-model',
        'fallback-model',
      ]);
      expect(sink.recordAttempts, 3);
      expect(pool.active, 0);
    },
  );
}

const AppSettingsSnapshot _snapshot = AppSettingsSnapshot(
  providerName: 'Primary Cloud',
  baseUrl: 'https://primary.example.com/v1',
  model: 'primary-model',
  apiKey: 'primary-key',
  maxConcurrentRequests: 1,
  maxTokens: AppLlmChatRequest.unlimitedMaxTokens,
  hasApiKey: true,
  themePreference: AppThemePreference.light,
);

const ResolvedProviderRoute _primaryRoute = ResolvedProviderRoute(
  providerName: 'Primary Cloud',
  baseUrl: 'https://primary.example.com/v1',
  model: 'primary-model',
  apiKey: 'primary-key',
  providerProfileId: 'primary',
);

const FailoverEndpoint _fallbackEndpoint = FailoverEndpoint(
  id: 'fallback',
  baseUrl: 'https://fallback.example.com/v1',
  apiKey: 'fallback-key',
  model: 'fallback-model',
  provider: AppLlmProvider.openaiCompatible,
  isLocal: false,
  providerProfileId: 'fallback',
);

({
  List<AppLlmChatMessage> messages,
  AppProductPromptInvocation prompt,
  PromptInvocationEvidence evidence,
  AppLlmRegisteredPromptAuthority authority,
})
_authorizedInvocation() {
  final prompt = AppProductPromptRegistry.current.invocation(
    stageId: 'workbench',
    callSiteId: 'rewrite',
  );
  const variables = <String, Object?>{
    'taskType': 'scene_roleplay_turn',
    'effectivePrompt': 'verify physical failover traces',
    'providerSummary': 'primary with fallback',
    'endpointLabel': 'test endpoint',
    'styleSummary': 'none',
    'sceneSummary': 'test scene',
    'characterSummary': '柳溪',
    'worldSummary': '',
    'simulationSummary': 'none',
    'previousText': '',
    'originalText': 'test prose',
    'nextText': '',
  };
  final messages = prompt.render(variables).messages;
  final evidence = prompt.evidence(
    messages: messages,
    resolvedVariables: variables,
  );
  final authority = AppLlmCallSiteAuthority.registeredPrompt(
    promptReleaseRef: prompt.promptReleaseRef,
    promptInvocationEvidence: evidence,
    stageId: prompt.stageId,
    callSiteId: prompt.callSiteId,
    variantId: prompt.variantId,
    generationBundleHash: prompt.generationBundleHash,
  );
  return (
    messages: messages,
    prompt: prompt,
    evidence: evidence,
    authority: authority as AppLlmRegisteredPromptAuthority,
  );
}

class _RetryThenFallbackClient implements AppLlmClient {
  final List<String> models = <String>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    models.add(request.model);
    if (request.model == 'primary-model') {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'provider unavailable',
      );
    }
    return const AppLlmChatResult.success(text: 'fallback result');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnsupportedError('streaming is outside this regression');
  }
}

class _RecordingRequestPool extends AppLlmRequestPool {
  _RecordingRequestPool({required super.maxConcurrent});

  int runCount = 0;

  @override
  Future<T> run<T>(Future<T> Function() operation) {
    runCount += 1;
    return super.run(operation);
  }
}

class _RecordingTraceSink implements AppLlmCallTraceSink {
  final List<AppLlmCallTraceEntry> entries = <AppLlmCallTraceEntry>[];

  @override
  Future<void> record(AppLlmCallTraceEntry entry) async {
    entries.add(entry);
  }
}

class _ThrowingRequiredTraceSink implements AppLlmRequiredCallTraceSink {
  int recordAttempts = 0;

  @override
  Future<void> record(AppLlmCallTraceEntry entry) async {
    recordAttempts += 1;
    throw StateError('required trace unavailable');
  }
}

class _ThrowingOptionalTraceSink implements AppLlmCallTraceSink {
  int recordAttempts = 0;

  @override
  Future<void> record(AppLlmCallTraceEntry entry) async {
    recordAttempts += 1;
    throw StateError('optional trace unavailable');
  }
}
