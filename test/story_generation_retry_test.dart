import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  // ===========================================================================
  // isRetryableStoryGenerationTransportFailure
  // ===========================================================================
  group('isRetryableStoryGenerationTransportFailure', () {
    test('returns false for successful result', () {
      const result = AppLlmChatResult.success(text: 'ok');
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns true for network failure', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'Connection refused',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for timeout failure', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.timeout,
        detail: 'Request timed out',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns false for unauthorized failure', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.unauthorized,
        detail: 'Invalid API key',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns false for modelNotFound failure', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.modelNotFound,
        detail: 'Model not found',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns false for unsupportedPlatform failure', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.unsupportedPlatform,
        detail: 'Platform not supported',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns false for server failure without transient detail', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'Internal server error',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns true for server failure with "connection reset by peer"', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'Connection reset by peer',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for server failure with "broken pipe"', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'Broken pipe',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for server failure with "connection closed before full header was received"', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'Connection closed before full header was received',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for server failure with "software caused connection abort"', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'Software caused connection abort',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for server failure with "connection terminated"', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'Connection terminated unexpectedly',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for server failure with "temporarily unavailable"', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'Service temporarily unavailable',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for server failure with "timed out"', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'Server timed out processing request',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('transient detail matching is case-insensitive', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'CONNECTION RESET BY PEER',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns false for invalidResponse without transient detail', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.invalidResponse,
        detail: 'JSON parse error',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns true for invalidResponse with transient detail', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.invalidResponse,
        detail: 'Connection reset by peer',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('handles null detail gracefully for server failure', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });
  });

  // ===========================================================================
  // requestStoryGenerationPassWithRetry
  // ===========================================================================
  group('requestStoryGenerationPassWithRetry', () {
    AppSettingsStore setupStore(FakeAppLlmClient fakeClient) {
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(store.dispose);
      return store;
    }

    test('returns success immediately on first attempt', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(text: 'scene prose'),
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'scene prose');
      expect(fakeClient.requests, hasLength(1));
    });

    test('retries network failure and succeeds on second attempt', () async {
      var attempt = 0;
      final fakeClient = FakeAppLlmClient(
        responder: (_) {
          attempt += 1;
          if (attempt == 1) {
            return const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.network,
              detail: 'Connection reset by peer',
            );
          }
          return const AppLlmChatResult.success(text: 'recovered prose');
        },
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'recovered prose');
      expect(fakeClient.requests, hasLength(2));
    });

    test('retries timeout failure and succeeds on second attempt', () async {
      var attempt = 0;
      final fakeClient = FakeAppLlmClient(
        responder: (_) {
          attempt += 1;
          if (attempt == 1) {
            return const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.timeout,
              detail: 'Request timed out',
            );
          }
          return const AppLlmChatResult.success(text: 'timeout recovered');
        },
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'timeout recovered');
      expect(fakeClient.requests, hasLength(2));
    });

    test('retries transient server failure and succeeds', () async {
      var attempt = 0;
      final fakeClient = FakeAppLlmClient(
        responder: (_) {
          attempt += 1;
          if (attempt == 1) {
            return const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.server,
              detail: 'Connection closed before full header was received',
            );
          }
          return const AppLlmChatResult.success(text: 'server recovered');
        },
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'server recovered');
      expect(fakeClient.requests, hasLength(2));
    });

    test('does not retry unauthorized failure', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.unauthorized,
          detail: 'Invalid API key',
        ),
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
        maxTransientRetries: 3,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.unauthorized);
      expect(fakeClient.requests, hasLength(1));
    });

    test('does not retry non-transient server failure', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          detail: 'Internal server error: rate limit exceeded',
        ),
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
        maxTransientRetries: 3,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(fakeClient.requests, hasLength(1));
    });

    test('does not retry modelNotFound failure', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.modelNotFound,
          detail: 'Model not found',
        ),
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
        maxTransientRetries: 3,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.modelNotFound);
      expect(fakeClient.requests, hasLength(1));
    });

    test('returns last failure when retries are exhausted', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'Connection refused',
        ),
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.network);
      // 1 initial + 2 retries = 3 total
      expect(fakeClient.requests, hasLength(3));
    });

    test('maxTransientRetries=0 means no retry on transient failure', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'Connection refused',
        ),
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
        maxTransientRetries: 0,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.network);
      expect(fakeClient.requests, hasLength(1));
    });

    test('retries multiple times then succeeds on final attempt', () async {
      var attempt = 0;
      final fakeClient = FakeAppLlmClient(
        responder: (_) {
          attempt += 1;
          if (attempt <= 2) {
            return const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.network,
              detail: 'Connection reset by peer',
            );
          }
          return const AppLlmChatResult.success(text: 'final success');
        },
      );
      final store = setupStore(fakeClient);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'generate')],
        maxTransientRetries: 3,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'final success');
      expect(fakeClient.requests, hasLength(3));
    });

    test('preserves original messages in each request', () async {
      final messages = [
        const AppLlmChatMessage(role: 'system', content: 'You are a novelist.'),
        const AppLlmChatMessage(role: 'user', content: 'Write the scene.'),
      ];
      var attempt = 0;
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          attempt += 1;
          if (attempt == 1) {
            return const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.timeout,
              detail: 'Timed out',
            );
          }
          return const AppLlmChatResult.success(text: 'prose');
        },
      );
      final store = setupStore(fakeClient);

      await requestStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: messages,
        maxTransientRetries: 2,
      );

      for (final request in fakeClient.requests) {
        expect(request.messages, hasLength(2));
        expect(request.messages[0].role, 'system');
        expect(request.messages[0].content, 'You are a novelist.');
        expect(request.messages[1].role, 'user');
        expect(request.messages[1].content, 'Write the scene.');
      }
    });
  });
}
