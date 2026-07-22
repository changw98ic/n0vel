import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_call_site_inventory.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';
import 'package:novel_writer/app/llm/app_llm_trace_summary.dart';
import 'package:novel_writer/app/llm/app_product_prompt_registry.dart';
import 'package:novel_writer/app/state/ai_request_service.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/llm_provider_service.dart';

import 'test_support/app_llm_authorized_request.dart';

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
    'single physical dispatch policy disables gateway retry and failover',
    () async {
      final primary = await _TraceTestServer.start(
        statusCode: HttpStatus.serviceUnavailable,
        payload: const <String, Object?>{
          'error': <String, Object?>{'message': 'provider unavailable'},
        },
      );
      final fallback = await _TraceTestServer.start(
        payload: _traceSuccessPayload('fallback-must-not-run'),
      );
      addTearDown(primary.close);
      addTearDown(fallback.close);
      final client = _RetryThenFallbackClient();
      final traceSink = _RecordingTraceSink();
      final pool = _RecordingRequestPool(maxConcurrent: 1);
      final store = await _configuredFormalTraceStore(
        llmClient: client,
        llmTraceSink: traceSink,
        requestPool: pool,
        primary: primary,
        fallback: fallback,
      );
      addTearDown(store.dispose);

      final result = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'formal single failure'),
        ],
        traceName: 'scene_roleplay_turn',
        singlePhysicalDispatch: true,
        dispatchEvidenceNonce: _nextFormalNonce('no-failover'),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(result.dispatchResolution, isNotNull);
      expect(result.providerBoundaryReceipt, isNotNull);
      expect(primary.calls, 1);
      expect(fallback.calls, 0);
      expect(client.models, isEmpty);
      expect(traceSink.entries, hasLength(1));
      expect(
        traceSink.entries.single.metadata,
        containsPair('endpointId', 'primary'),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('primaryEndpointId', 'primary'),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('endpointIndex', 0),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('gatewayRetryIndex', 0),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('wasFallback', false),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('failoverEndpointCount', 1),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('physicalDispatchPolicy', 'single'),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('physicalDispatchCount', 1),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('physicalDispatchCountStatus', 'verified'),
      );
      final summary = AppLlmTraceSummary.fromJsonEntries(
        traceSink.entries.map((entry) => entry.toJson()),
        configuredSceneConcurrency: 1,
        configuredRequestConcurrency: 1,
      );
      expect(summary.physicalDispatchCalls, 1);
      expect(summary.gatewayRetryCalls, 0);
      expect(summary.fallbackCalls, 0);
    },
  );

  test(
    'single dispatch success with configured fallback is bound to primary',
    () async {
      final primary = await _TraceTestServer.start(
        payload: _traceSuccessPayload('primary result'),
      );
      final fallback = await _TraceTestServer.start(
        payload: _traceSuccessPayload('fallback-must-not-run'),
      );
      addTearDown(primary.close);
      addTearDown(fallback.close);
      final client = _SuccessfulPrimaryClient();
      final traceSink = _RecordingTraceSink();
      final pool = _RecordingRequestPool(maxConcurrent: 1);
      final store = await _configuredFormalTraceStore(
        llmClient: client,
        llmTraceSink: traceSink,
        requestPool: pool,
        primary: primary,
        fallback: fallback,
      );
      addTearDown(store.dispose);

      final result = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'formal primary success'),
        ],
        singlePhysicalDispatch: true,
        dispatchEvidenceNonce: _nextFormalNonce('primary-success'),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'primary result');
      expect(result.dispatchResolution?.endpointId, 'primary');
      expect(result.providerBoundaryReceipt, isNotNull);
      expect(primary.calls, 1);
      expect(fallback.calls, 0);
      expect(client.models, isEmpty);
      expect(traceSink.entries, hasLength(1));
    },
  );

  test(
    'single admission quiesces in-flight primary and fallback probes',
    () async {
      final primary = await _TraceTestServer.start(
        payload: _traceSuccessPayload('isolated primary result'),
      );
      final fallback = await _TraceTestServer.start(
        payload: _traceSuccessPayload('fallback-must-not-run'),
      );
      addTearDown(primary.close);
      addTearDown(fallback.close);
      final client = _StaleReconnectIsolationClient();
      final traceSink = _RecordingTraceSink();
      final pool = _RecordingRequestPool(maxConcurrent: 2);
      final store = await _configuredFormalTraceStore(
        llmClient: client,
        llmTraceSink: traceSink,
        requestPool: pool,
        primary: primary,
        fallback: fallback,
        failoverGatewayProvider: (_) => AppLlmClientGateway(
          delegate: client,
          maxRetries: 1,
          baseDelayMs: 0,
        ),
      );
      addTearDown(store.dispose);

      final adaptive = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'seed reconnect probes'),
        ],
      );
      expect(adaptive.succeeded, isFalse);
      await client.allProbesStarted.future.timeout(const Duration(seconds: 1));

      final singleFuture = requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'formal after quiesce'),
        ],
        singlePhysicalDispatch: true,
        dispatchEvidenceNonce: _nextFormalNonce('quiesce-reconnect'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(client.ordinaryModels, <String>[
        'primary-model',
        'fallback-model',
      ]);
      expect(client.probeModels.toSet(), <String>{
        'primary-model',
        'fallback-model',
      });

      client.completeProbes();
      final single = await singleFuture;

      expect(single.succeeded, isTrue);
      expect(single.text, 'isolated primary result');
      expect(single.dispatchResolution, isNotNull);
      expect(primary.calls, 1);
      expect(fallback.calls, 0);
      expect(client.ordinaryModels, <String>[
        'primary-model',
        'fallback-model',
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(client.probeModels, hasLength(2));
    },
  );

  test('invalid single route fails before physical admission', () async {
    final client = _SuccessfulPrimaryClient();
    final traceSink = _RecordingTraceSink();
    final service = AiRequestService(
      llmClient: client,
      llmTraceSink: traceSink,
    );
    final invocation = _authorizedInvocation();

    await expectLater(
      service.requestCompletion(
        snapshot: _snapshot,
        route: const ResolvedProviderRoute(
          providerName: 'Invalid Remote',
          baseUrl: 'http://remote.example.com/v1',
          model: 'primary-model',
          apiKey: 'primary-key',
          providerProfileId: 'invalid',
        ),
        requestPool: AppLlmRequestPool(maxConcurrent: 1),
        messages: invocation.messages,
        physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
        dispatchEvidenceNonce: _testDispatchEvidenceNonce,
        promptReleaseRef: invocation.prompt.promptReleaseRef,
        promptInvocationEvidence: invocation.evidence,
        stageId: invocation.prompt.stageId,
        callSiteId: invocation.prompt.callSiteId,
        variantId: invocation.prompt.variantId,
        generationBundleHash: invocation.prompt.generationBundleHash,
        callSiteAuthority: invocation.authority,
      ),
      throwsA(
        isA<AppLlmPhysicalDispatchPreflightException>().having(
          (error) => error.code,
          'code',
          'insecure-remote-url',
        ),
      ),
    );
    expect(client.models, isEmpty);
    expect(traceSink.entries, isEmpty);
  });

  for (final routeCase in const <Map<String, String>>[
    <String, String>{
      'label': 'empty host',
      'baseUrl': 'https:///v1',
      'code': 'missing-url-host',
    },
    <String, String>{
      'label': 'embedded user info',
      'baseUrl': 'https://user:secret@primary.example.com/v1',
      'code': 'embedded-url-credentials',
    },
    <String, String>{
      'label': 'query routing',
      'baseUrl': 'https://primary.example.com/v1?tenant=secret',
      'code': 'url-query-not-allowed',
    },
    <String, String>{
      'label': 'fragment routing',
      'baseUrl': 'https://primary.example.com/v1#alternate',
      'code': 'url-fragment-not-allowed',
    },
  ]) {
    test(
      'single route rejects ${routeCase['label']} before admission',
      () async {
        final client = _SuccessfulPrimaryClient();
        final traceSink = _RecordingTraceSink();
        final service = AiRequestService(
          llmClient: client,
          llmTraceSink: traceSink,
        );
        final invocation = _authorizedInvocation();

        await expectLater(
          service.requestCompletion(
            snapshot: _snapshot,
            route: ResolvedProviderRoute(
              providerName: 'Invalid Remote',
              baseUrl: routeCase['baseUrl']!,
              model: 'primary-model',
              apiKey: 'primary-key',
              providerProfileId: 'invalid',
            ),
            requestPool: AppLlmRequestPool(maxConcurrent: 1),
            messages: invocation.messages,
            physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
            dispatchEvidenceNonce: _testDispatchEvidenceNonce,
            promptReleaseRef: invocation.prompt.promptReleaseRef,
            promptInvocationEvidence: invocation.evidence,
            stageId: invocation.prompt.stageId,
            callSiteId: invocation.prompt.callSiteId,
            variantId: invocation.prompt.variantId,
            generationBundleHash: invocation.prompt.generationBundleHash,
            callSiteAuthority: invocation.authority,
          ),
          throwsA(
            isA<AppLlmPhysicalDispatchPreflightException>().having(
              (error) => error.code,
              'code',
              routeCase['code'],
            ),
          ),
        );
        expect(client.models, isEmpty);
        expect(traceSink.entries, isEmpty);
      },
    );
  }

  test(
    'formal platform capability ignores unsupported adaptive wrapper',
    () async {
      final primary = await _TraceTestServer.start(
        payload: _traceSuccessPayload('platform direct'),
      );
      addTearDown(primary.close);
      final unsupported = _UnsupportedSingleDispatchClient();
      final client = AppLlmLoggingMiddleware(
        delegate: AppLlmResponseCache(delegate: unsupported),
      );
      final traceSink = _RecordingTraceSink();
      final store = await _configuredFormalTraceStore(
        llmClient: client,
        llmTraceSink: traceSink,
        primary: primary,
      );
      addTearDown(store.dispose);

      final result = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(
            role: 'user',
            content: 'formal platform capability',
          ),
        ],
        singlePhysicalDispatch: true,
        dispatchEvidenceNonce: _nextFormalNonce('unsupported-wrapper'),
      );
      expect(result.succeeded, isTrue);
      expect(primary.calls, 1);
      expect(unsupported.calls, 0);
      expect(traceSink.entries, hasLength(1));
    },
  );

  test(
    'formal platform capability ignores unmarked adaptive wrapper',
    () async {
      final primary = await _TraceTestServer.start(
        payload: _traceSuccessPayload('platform direct'),
      );
      addTearDown(primary.close);
      final client = _UnmarkedSingleDispatchClient();
      final traceSink = _RecordingTraceSink();
      final store = await _configuredFormalTraceStore(
        llmClient: client,
        llmTraceSink: traceSink,
        primary: primary,
      );
      addTearDown(store.dispose);

      final result = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'formal unmarked wrapper'),
        ],
        singlePhysicalDispatch: true,
        dispatchEvidenceNonce: _nextFormalNonce('unmarked-wrapper'),
      );
      expect(result.succeeded, isTrue);
      expect(primary.calls, 1);
      expect(client.calls, 0);
      expect(traceSink.entries, hasLength(1));
    },
  );

  test('single admission waits for an in-flight adaptive request', () async {
    final primary = await _TraceTestServer.start(
      payload: _traceSuccessPayload('single complete'),
    );
    addTearDown(primary.close);
    final client = _AdaptiveAdmissionBarrierClient();
    final pool = AppLlmRequestPool(maxConcurrent: 2);
    final store = await _configuredFormalTraceStore(
      llmClient: client,
      requestPool: pool,
      primary: primary,
    );
    addTearDown(store.dispose);

    final adaptiveFuture = requestAuthorizedAiCompletionForTest(
      store,
      messages: const <AppLlmChatMessage>[
        AppLlmChatMessage(role: 'user', content: 'blocking adaptive'),
      ],
    );
    await client.adaptiveStarted.future.timeout(const Duration(seconds: 1));

    final singleFuture = requestAuthorizedAiCompletionForTest(
      store,
      messages: const <AppLlmChatMessage>[
        AppLlmChatMessage(role: 'user', content: 'waiting formal'),
      ],
      singlePhysicalDispatch: true,
      dispatchEvidenceNonce: _nextFormalNonce('adaptive-barrier'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(client.policies, <AppLlmPhysicalDispatchPolicy>[
      AppLlmPhysicalDispatchPolicy.adaptive,
    ]);

    client.completeAdaptive();
    expect((await adaptiveFuture).succeeded, isTrue);
    final single = await singleFuture;
    expect(single.succeeded, isTrue);
    expect(single.text, 'single complete');
    expect(primary.calls, 1);
    expect(client.policies, <AppLlmPhysicalDispatchPolicy>[
      AppLlmPhysicalDispatchPolicy.adaptive,
    ]);
  });

  test(
    'single dispatch accepts only a receipt issued by real local IO',
    () async {
      final primary = await _TraceTestServer.start(
        payload: _traceSuccessPayload('trusted local output'),
      );
      addTearDown(primary.close);

      final traceSink = _RecordingTraceSink();
      final store = await _configuredFormalTraceStore(
        llmClient: createDefaultAppLlmClient(),
        llmTraceSink: traceSink,
        primary: primary,
      );
      addTearDown(store.dispose);
      final result = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'trusted local output'),
        ],
        singlePhysicalDispatch: true,
        dispatchEvidenceNonce: _nextFormalNonce('trusted-receipt'),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'trusted local output');
      expect(primary.calls, 1);
      expect(result.providerBoundaryReceipt, isNotNull);
      expect(result.dispatchResolution?.endpointId, 'primary');
      expect(
        traceSink.entries.single.metadata,
        containsPair('providerBoundaryVerified', true),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('physicalDispatchCount', 1),
      );
      expect(
        traceSink.entries.single.metadata,
        containsPair('physicalDispatchCountStatus', 'verified'),
      );
    },
  );

  test(
    'single dispatch bypasses throwing wrapper and keeps genuine IO receipt',
    () async {
      final primary = await _TraceTestServer.start(
        payload: _traceSuccessPayload('direct despite wrapper'),
      );
      addTearDown(primary.close);
      final client = _ThrowingClient();
      final traceSink = _RecordingTraceSink();
      final pool = _RecordingRequestPool(maxConcurrent: 1);
      final store = await _configuredFormalTraceStore(
        llmClient: client,
        llmTraceSink: traceSink,
        requestPool: pool,
        primary: primary,
      );
      addTearDown(store.dispose);

      final result = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'throwing wrapper bypass'),
        ],
        singlePhysicalDispatch: true,
        dispatchEvidenceNonce: _nextFormalNonce('throwing-wrapper'),
      );

      expect(result.succeeded, isTrue);
      expect(result.dispatchFailureDisposition, isNull);
      expect(result.dispatchResolution, isNotNull);
      expect(result.providerBoundaryReceipt, isNotNull);
      expect(primary.calls, 1);
      expect(client.calls, 0);
      expect(traceSink.entries, hasLength(1));
    },
  );

  test(
    'single dispatch never converts required trace failure to a result',
    () async {
      final primary = await _TraceTestServer.start(
        payload: _traceSuccessPayload(
          'provider-completed-before-trace-failure',
        ),
      );
      addTearDown(primary.close);
      final client = _ThrowingClient();
      final sink = _ThrowingRequiredTraceSink();
      final pool = AppLlmRequestPool(maxConcurrent: 1);
      final store = await _configuredFormalTraceStore(
        llmClient: client,
        llmTraceSink: sink,
        requestPool: pool,
        primary: primary,
      );
      addTearDown(store.dispose);

      await expectLater(
        requestAuthorizedAiCompletionForTest(
          store,
          messages: const <AppLlmChatMessage>[
            AppLlmChatMessage(role: 'user', content: 'required trace failure'),
          ],
          singlePhysicalDispatch: true,
          dispatchEvidenceNonce: _nextFormalNonce('required-trace-failure'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'required trace unavailable',
          ),
        ),
      );
      expect(primary.calls, 1);
      expect(client.calls, 0);
      expect(sink.recordAttempts, 1);
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

Future<AppSettingsStore> _configuredFormalTraceStore({
  required AppLlmClient llmClient,
  required _TraceTestServer primary,
  AppLlmCallTraceSink? llmTraceSink,
  AppLlmRequestPool? requestPool,
  _TraceTestServer? fallback,
  FailoverEndpointGatewayProvider? failoverGatewayProvider,
}) async {
  final store = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: llmClient,
    llmTraceSink: llmTraceSink,
    requestPool: requestPool,
    failoverGatewayProvider: failoverGatewayProvider,
  );
  final saved = await store.save(
    providerName: 'Local Primary',
    baseUrl: primary.baseUrl,
    model: 'primary-model',
    apiKey: '',
    timeout: const AppLlmTimeoutConfig.uniform(2000),
    maxConcurrentRequests: requestPool?.maxConcurrent ?? 1,
    maxTokens: 4096,
    providerProfiles: fallback == null
        ? const <AppLlmProviderProfile>[]
        : <AppLlmProviderProfile>[
            AppLlmProviderProfile(
              id: 'fallback',
              providerName: 'Local Fallback',
              baseUrl: fallback.baseUrl,
              model: 'fallback-model',
              apiKey: '',
            ),
          ],
  );
  if (!saved.succeededWithoutWarnings) {
    store.dispose();
    throw StateError('could not configure formal trace test route');
  }
  return store;
}

final class _TraceTestServer {
  _TraceTestServer._(this._server, this.statusCode, this.payload);

  final HttpServer _server;
  final int statusCode;
  final Map<String, Object?> payload;
  int calls = 0;

  String get baseUrl => 'http://${_server.address.host}:${_server.port}/v1';

  static Future<_TraceTestServer> start({
    int statusCode = HttpStatus.ok,
    required Map<String, Object?> payload,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _TraceTestServer._(server, statusCode, payload);
    unawaited(
      server.forEach((request) async {
        fixture.calls += 1;
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = fixture.statusCode
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(fixture.payload));
        await request.response.close();
      }),
    );
    return fixture;
  }

  Future<void> close() => _server.close(force: true);
}

Map<String, Object?> _traceSuccessPayload(String text) => <String, Object?>{
  'id': 'trace-$text',
  'model': 'primary-model',
  'choices': <Object?>[
    <String, Object?>{
      'message': <String, Object?>{'content': text},
    },
  ],
  'usage': const <String, Object?>{
    'prompt_tokens': 12,
    'completion_tokens': 4,
    'total_tokens': 16,
  },
};

int _formalNonceSequence = 0;

String _nextFormalNonce(String label) => AppLlmCanonicalHash.domainHash(
  'app-llm-failover-physical-trace-formal-v1',
  <String, Object?>{'label': label, 'sequence': ++_formalNonceSequence},
);

const _testDispatchEvidenceNonce =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

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

class _RetryThenFallbackClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  final List<String> models = <String>[];

  @override
  bool get supportsSinglePhysicalDispatch => true;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    models.add(request.model);
    if (request.model == 'primary-model') {
      return _observedResult(
        request,
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          detail: 'provider unavailable',
        ),
      );
    }
    return _observedResult(
      request,
      const AppLlmChatResult.success(text: 'fallback result'),
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnsupportedError('streaming is outside this regression');
  }
}

class _SuccessfulPrimaryClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  final List<String> models = <String>[];

  @override
  bool get supportsSinglePhysicalDispatch => true;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    models.add(request.model);
    return _observedResult(
      request,
      const AppLlmChatResult.success(text: 'primary result'),
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnsupportedError('streaming is outside this regression');
  }
}

class _UnsupportedSingleDispatchClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  int calls = 0;

  @override
  bool get supportsSinglePhysicalDispatch => false;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    return const AppLlmChatResult.failure(
      failureKind: AppLlmFailureKind.unsupportedPlatform,
      detail: 'unsupported runtime',
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnsupportedError('streaming is outside this regression');
  }
}

class _UnmarkedSingleDispatchClient implements AppLlmClient {
  int calls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    return const AppLlmChatResult.success(text: 'must not be called');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnsupportedError('streaming is outside this regression');
  }
}

class _AdaptiveAdmissionBarrierClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  final Completer<void> adaptiveStarted = Completer<void>();
  final Completer<AppLlmChatResult> _adaptiveResult =
      Completer<AppLlmChatResult>();
  final List<AppLlmPhysicalDispatchPolicy> policies =
      <AppLlmPhysicalDispatchPolicy>[];

  @override
  bool get supportsSinglePhysicalDispatch => true;

  void completeAdaptive() {
    _adaptiveResult.complete(
      const AppLlmChatResult.success(text: 'adaptive complete'),
    );
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    policies.add(request.physicalDispatchPolicy);
    if (request.physicalDispatchPolicy ==
        AppLlmPhysicalDispatchPolicy.adaptive) {
      if (!adaptiveStarted.isCompleted) adaptiveStarted.complete();
      return _adaptiveResult.future;
    }
    return _observedResult(
      request,
      const AppLlmChatResult.success(text: 'single complete'),
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnsupportedError('streaming is outside this regression');
  }
}

class _StaleReconnectIsolationClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  final List<String> ordinaryModels = <String>[];
  final List<String> probeModels = <String>[];
  final List<Completer<AppLlmChatResult>> _probeResults =
      <Completer<AppLlmChatResult>>[];
  final Completer<void> allProbesStarted = Completer<void>();
  bool allowSingleSuccess = false;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  void completeProbes() {
    for (final completer in _probeResults) {
      if (!completer.isCompleted) {
        completer.complete(
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'stale probe completed',
          ),
        );
      }
    }
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final isProbe =
        request.messages.length == 1 &&
        request.messages.single.content == 'ping';
    if (isProbe) {
      probeModels.add(request.model);
      final completer = Completer<AppLlmChatResult>();
      _probeResults.add(completer);
      if (probeModels.length == 2 && !allProbesStarted.isCompleted) {
        allProbesStarted.complete();
      }
      return completer.future;
    }
    ordinaryModels.add(request.model);
    if (allowSingleSuccess && request.model == 'primary-model') {
      return _observedResult(
        request,
        const AppLlmChatResult.success(text: 'isolated primary result'),
      );
    }
    return _observedResult(
      request,
      const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'seed reconnect automation',
      ),
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnsupportedError('streaming is outside this regression');
  }
}

class _ThrowingClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  int calls = 0;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    throw StateError('provider outcome is unknown');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnsupportedError('streaming is outside this regression');
  }
}

AppLlmChatResult _observedResult(
  AppLlmChatRequest request,
  AppLlmChatResult result,
) => request.physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single
    ? result.withProviderBoundaryReceipt(_TraceProviderBoundaryReceipt(request))
    : result;

final class _TraceProviderBoundaryReceipt
    implements AppLlmProviderBoundaryReceipt {
  const _TraceProviderBoundaryReceipt(this.request);

  final AppLlmChatRequest request;

  @override
  String get contract => 'app-llm-provider-boundary-receipt-v1';
  @override
  int get physicalDispatchCount => 1;
  @override
  String get requestedBaseUrl => request.baseUrl;
  @override
  String get requestedModel => request.model;
  @override
  AppLlmProvider get requestedProvider => request.provider;
  @override
  String get transportEndpoint => '${request.baseUrl}/chat/completions';
  @override
  String get dispatchEvidenceNonce =>
      request.dispatchEvidenceNonce ??
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  @override
  Map<String, Object?> toCredentialFreeJson() => <String, Object?>{
    'contract': contract,
    'physicalDispatchCount': physicalDispatchCount,
    'requestedBaseUrl': requestedBaseUrl,
    'requestedModel': requestedModel,
    'requestedProvider': requestedProvider.name,
    'transportEndpoint': transportEndpoint,
    'dispatchEvidenceNonce': dispatchEvidenceNonce,
  };
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
