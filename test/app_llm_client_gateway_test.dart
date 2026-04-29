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
  });
}

const _testRequest = AppLlmChatRequest(
  baseUrl: 'http://localhost',
  apiKey: 'key',
  model: 'm',
  timeoutMs: 1000,
  messages: [AppLlmChatMessage(role: 'user', content: 'test')],
);

class _CallCountingClient implements AppLlmClient {
  _CallCountingClient({required this.results});

  final List<AppLlmChatResult> results;
  int calls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    return results[calls++];
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    return Stream<String>.value(results[calls++].text ?? '');
  }
}
