import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';

void main() {
  group('AppLlmClientGateway', () {
    test('returns success immediately without retry', () async {
      final delegate = _CallCountingClient(
        results: [const AppLlmChatResult.success(text: 'hello')],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isTrue);
      expect(result.text, 'hello');
      expect(delegate.calls, 1);
    });

    test('retries on timeout and returns first success', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'timeout 1',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'timeout 2',
          ),
          const AppLlmChatResult.success(text: 'recovered'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isTrue);
      expect(result.text, 'recovered');
      expect(delegate.calls, 3);
    });

    test('retries on rateLimited failure', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.rateLimited,
            statusCode: 429,
            detail: 'slow down',
          ),
          const AppLlmChatResult.success(text: 'ok after 429'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isTrue);
      expect(result.text, 'ok after 429');
      expect(delegate.calls, 2);
    });

    test('retries on server 5xx failure', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            statusCode: 500,
            detail: 'internal error',
          ),
          const AppLlmChatResult.success(text: 'ok after 500'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isTrue);
      expect(result.text, 'ok after 500');
      expect(delegate.calls, 2);
    });

    test('retries on network failure', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'connection refused',
          ),
          const AppLlmChatResult.success(text: 'ok after network'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isTrue);
      expect(result.text, 'ok after network');
      expect(delegate.calls, 2);
    });

    test('does not retry on unauthorized failure', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.unauthorized,
            statusCode: 401,
            detail: 'bad key',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.unauthorized);
      expect(delegate.calls, 1);
    });

    test('does not retry on modelNotFound failure', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.modelNotFound,
            statusCode: 404,
            detail: 'no model',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.modelNotFound);
      expect(delegate.calls, 1);
    });

    test('does not retry on invalidResponse failure', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.invalidResponse,
            detail: 'bad json',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.invalidResponse);
      expect(delegate.calls, 1);
    });

    test('does not retry on unsupportedPlatform failure', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.unsupportedPlatform,
            detail: 'no io',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.unsupportedPlatform);
      expect(delegate.calls, 1);
    });

    test('returns last failure after exhausting retries', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'timeout 1',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'timeout 2',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'timeout 3',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.timeout);
      expect(result.detail, 'timeout 3');
      expect(delegate.calls, 3);
      gateway.dispose();
    });

    test('with maxRetries 1 does not retry', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            statusCode: 500,
            detail: 'fail',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 1,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(delegate.calls, 1);
    });

    test(
      'single physical dispatch policy does not retry or start reconnect probes',
      () async {
        final delegate = _CallCountingClient(
          results: [
            const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.network,
              detail: 'first physical dispatch failed',
            ),
            const AppLlmChatResult.success(text: 'must not be requested'),
          ],
        );
        final gateway = AppLlmClientGateway(
          delegate: delegate,
          maxRetries: 3,
          baseDelayMs: 1,
        );

        final result = await gateway.chat(_singlePhysicalDispatchRequest);

        expect(result.succeeded, isFalse);
        expect(result.failureKind, AppLlmFailureKind.network);
        expect(delegate.calls, 1);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(delegate.calls, 1);
        gateway.dispose();
      },
    );

    test('single physical dispatch bypasses an already open circuit', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            detail: 'open the adaptive circuit',
          ),
          const AppLlmChatResult.success(text: 'fresh experiment response'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 1,
        baseDelayMs: 1,
        circuitBreaker: AppLlmCircuitBreaker(failureThreshold: 1),
      );

      final adaptive = await gateway.chat(_testRequest);
      final single = await gateway.chat(_singlePhysicalDispatchRequest);

      expect(adaptive.succeeded, isFalse);
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.open);
      expect(single.succeeded, isTrue);
      expect(delegate.calls, 2);
      gateway.dispose();
    });

    test('single dispatch waits for an in-flight reconnect probe', () async {
      final delegate = _ReconnectBarrierClient();
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 1,
        baseDelayMs: 0,
      );

      final adaptive = await gateway.chat(_testRequest);
      expect(adaptive.succeeded, isFalse);
      await delegate.probeStarted.future.timeout(const Duration(seconds: 1));

      final singleFuture = gateway.chat(_singlePhysicalDispatchRequest);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(delegate.ordinaryCalls, 1);
      expect(delegate.probeCalls, 1);

      delegate.completeProbe();
      final single = await singleFuture;

      expect(single.succeeded, isTrue);
      expect(delegate.ordinaryCalls, 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(delegate.probeCalls, 1);
      gateway.dispose();
    });

    test('createResilientAppLlmClient returns a gateway', () {
      final client = createResilientAppLlmClient();
      expect(client, isA<AppLlmClientGateway>());
    });
  });

  group('AppLlmClientGateway connection state', () {
    test('initial state is connected', () {
      final delegate = _CallCountingClient(
        results: [const AppLlmChatResult.success(text: 'ok')],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      expect(gateway.connectionState, AppLlmConnectionState.connected);
      gateway.dispose();
    });

    test('stays connected on success', () async {
      final delegate = _CallCountingClient(
        results: [const AppLlmChatResult.success(text: 'ok')],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      await gateway.chat(_testRequest);

      expect(gateway.connectionState, AppLlmConnectionState.connected);
      gateway.dispose();
    });

    test('transitions to disconnected on network failure', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'connection refused',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 1,
        baseDelayMs: 1,
      );

      await gateway.chat(_testRequest);

      expect(gateway.connectionState, AppLlmConnectionState.disconnected);
      gateway.dispose();
    });

    test('transitions to disconnected on timeout failure', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'timed out',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 1,
        baseDelayMs: 1,
      );

      await gateway.chat(_testRequest);

      expect(gateway.connectionState, AppLlmConnectionState.disconnected);
      gateway.dispose();
    });

    test('stays connected on server error', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            statusCode: 500,
            detail: 'internal error',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 1,
        baseDelayMs: 1,
      );

      await gateway.chat(_testRequest);

      expect(gateway.connectionState, AppLlmConnectionState.connected);
      gateway.dispose();
    });

    test('stays connected on unauthorized error', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.unauthorized,
            statusCode: 401,
            detail: 'bad key',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 1,
        baseDelayMs: 1,
      );

      await gateway.chat(_testRequest);

      expect(gateway.connectionState, AppLlmConnectionState.connected);
      gateway.dispose();
    });

    test('reconnects: disconnected -> connected on retry success', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'connection refused',
          ),
          const AppLlmChatResult.success(text: 'recovered'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);

      expect(result.succeeded, isTrue);
      expect(gateway.connectionState, AppLlmConnectionState.connected);
      gateway.dispose();
    });

    test('stays disconnected when all retries exhausted', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 1',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 2',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 3',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      await gateway.chat(_testRequest);

      expect(gateway.connectionState, AppLlmConnectionState.disconnected);
      gateway.dispose();
    });

    test('emits state changes via stream', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'down',
          ),
          const AppLlmChatResult.success(text: 'back'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final states = <AppLlmConnectionState>[];
      final subscription = gateway.onConnectionStateChanged.listen(states.add);

      await gateway.chat(_testRequest);

      // Allow stream to deliver events.
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        AppLlmConnectionState.disconnected,
        AppLlmConnectionState.connected,
      ]);

      await subscription.cancel();
      gateway.dispose();
    });

    test('does not emit duplicate state for same value', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.success(text: 'ok1'),
          const AppLlmChatResult.success(text: 'ok2'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final states = <AppLlmConnectionState>[];
      final subscription = gateway.onConnectionStateChanged.listen(states.add);

      await gateway.chat(_testRequest);
      await gateway.chat(_testRequest);
      await Future<void>.delayed(Duration.zero);

      expect(states, isEmpty);

      await subscription.cancel();
      gateway.dispose();
    });

    test('dispose closes stream', () async {
      final delegate = _CallCountingClient(
        results: [const AppLlmChatResult.success(text: 'ok')],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      gateway.dispose();

      await expectLater(gateway.onConnectionStateChanged, emitsDone);
    });
  });

  group('background reconnect', () {
    test('reconnects in background after retries exhausted', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 1',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 2',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 3',
          ),
          const AppLlmChatResult.success(text: 'ping ok'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final result = await gateway.chat(_testRequest);
      expect(result.succeeded, isFalse);
      expect(gateway.connectionState, AppLlmConnectionState.disconnected);
      expect(delegate.calls, 3);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gateway.connectionState, AppLlmConnectionState.connected);
      expect(delegate.calls, 4);

      gateway.dispose();
    });

    test('reconnect probe emits state via stream', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 1',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 2',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 3',
          ),
          const AppLlmChatResult.success(text: 'ping ok'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final states = <AppLlmConnectionState>[];
      final subscription = gateway.onConnectionStateChanged.listen(states.add);

      await gateway.chat(_testRequest);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, [
        AppLlmConnectionState.disconnected,
        AppLlmConnectionState.connected,
      ]);

      await subscription.cancel();
      gateway.dispose();
    });

    test('reconnect probe fails then succeeds on next attempt', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 1',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 2',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 3',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'probe fail',
          ),
          const AppLlmChatResult.success(text: 'ping ok'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 30,
      );

      await gateway.chat(_testRequest);
      expect(gateway.connectionState, AppLlmConnectionState.disconnected);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(delegate.calls, 4);
      expect(gateway.connectionState, AppLlmConnectionState.disconnected);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(delegate.calls, 5);
      expect(gateway.connectionState, AppLlmConnectionState.connected);

      gateway.dispose();
    });

    test('reconnect loop stops when next chat succeeds', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 1',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 2',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 3',
          ),
          const AppLlmChatResult.success(text: 'back online'),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      final first = await gateway.chat(_testRequest);
      expect(first.succeeded, isFalse);
      expect(gateway.connectionState, AppLlmConnectionState.disconnected);

      final second = await gateway.chat(_testRequest);
      expect(second.succeeded, isTrue);
      expect(gateway.connectionState, AppLlmConnectionState.connected);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(delegate.calls, 4);

      gateway.dispose();
    });

    test('dispose cancels reconnect timer', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 1',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 2',
          ),
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'fail 3',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 3,
        baseDelayMs: 1,
      );

      await gateway.chat(_testRequest);
      expect(gateway.connectionState, AppLlmConnectionState.disconnected);

      gateway.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(delegate.calls, 3);
    });

    test('does not start reconnect on non-connection failures', () async {
      final delegate = _CallCountingClient(
        results: [
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            statusCode: 500,
            detail: 'internal error',
          ),
        ],
      );
      final gateway = AppLlmClientGateway(
        delegate: delegate,
        maxRetries: 1,
        baseDelayMs: 1,
      );

      await gateway.chat(_testRequest);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(delegate.calls, 1);
      expect(gateway.connectionState, AppLlmConnectionState.connected);

      gateway.dispose();
    });

    test(
      'shutdown recursively awaits a nested delegate lifecycle once',
      () async {
        final leaf = _LifecycleBarrierClient();
        final inner = AppLlmClientGateway(delegate: leaf);
        final outer = AppLlmClientGateway(delegate: inner);

        var completed = false;
        final firstShutdown = outer.shutdownPhysicalDispatches().then((_) {
          completed = true;
        });
        await leaf.shutdownStarted.future.timeout(const Duration(seconds: 1));

        expect(leaf.shutdownCalls, 1);
        expect(completed, isFalse);

        final secondShutdown = outer.shutdownPhysicalDispatches();
        await Future<void>.delayed(Duration.zero);
        expect(leaf.shutdownCalls, 1);

        leaf.completeShutdown();
        await Future.wait<void>(<Future<void>>[firstShutdown, secondShutdown]);
        expect(completed, isTrue);
        expect(leaf.shutdownCalls, 1);

        await expectLater(
          outer.chat(_testRequest),
          throwsA(
            isA<AppLlmPhysicalDispatchPreflightException>().having(
              (error) => error.code,
              'code',
              'client-shutdown',
            ),
          ),
        );
      },
    );
  });
}

const _testRequest = AppLlmChatRequest(
  baseUrl: 'http://localhost',
  apiKey: 'key',
  model: 'm',
  timeoutMs: 1000,
  messages: [AppLlmChatMessage(role: 'user', content: 'test')],
);

const _singlePhysicalDispatchRequest = AppLlmChatRequest(
  baseUrl: 'http://localhost',
  apiKey: 'key',
  model: 'm',
  timeoutMs: 1000,
  messages: [AppLlmChatMessage(role: 'user', content: 'test')],
  physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
  dispatchEvidenceNonce:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
);

class _CallCountingClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  _CallCountingClient({required this.results});

  final List<AppLlmChatResult> results;
  int calls = 0;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    return results[calls++];
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    return Stream<String>.value(results[calls++].text ?? '');
  }
}

class _ReconnectBarrierClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  final Completer<void> probeStarted = Completer<void>();
  final Completer<AppLlmChatResult> _probeResult =
      Completer<AppLlmChatResult>();
  int ordinaryCalls = 0;
  int probeCalls = 0;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  void completeProbe() {
    _probeResult.complete(
      const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'stale reconnect probe failed',
      ),
    );
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final isProbe =
        request.messages.length == 1 &&
        request.messages.single.content == 'ping';
    if (isProbe) {
      probeCalls += 1;
      if (!probeStarted.isCompleted) probeStarted.complete();
      return _probeResult.future;
    }
    ordinaryCalls += 1;
    if (ordinaryCalls == 1) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'start reconnect automation',
      );
    }
    return const AppLlmChatResult.success(text: 'isolated single response');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnsupportedError('streaming is outside this regression');
  }
}

class _LifecycleBarrierClient
    implements
        AppLlmClient,
        AppLlmSinglePhysicalDispatchCapability,
        AppLlmPhysicalDispatchLifecycle {
  final Completer<void> shutdownStarted = Completer<void>();
  final Completer<void> _shutdownCompleted = Completer<void>();
  int shutdownCalls = 0;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  void completeShutdown() => _shutdownCompleted.complete();

  @override
  Future<void> shutdownPhysicalDispatches() async {
    shutdownCalls += 1;
    if (!shutdownStarted.isCompleted) shutdownStarted.complete();
    await _shutdownCompleted.future;
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async =>
      const AppLlmChatResult.success(text: 'unused');

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      const Stream<String>.empty();
}
