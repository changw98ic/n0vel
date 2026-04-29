import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';

void main() {
  group('isRetryableStoryGenerationTransportFailure', () {
    test('returns false for successful results', () {
      final result = AppLlmChatResult.success(text: 'hello');
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns true for network failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'connection refused',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for timeout failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.timeout,
        detail: 'timed out',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns false for unauthorized failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.unauthorized,
        statusCode: 401,
        detail: 'bad key',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns false for model-not-found failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.modelNotFound,
        statusCode: 404,
        detail: 'model missing',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns true for server failures with retryable detail', () {
      final retryableDetails = [
        'Connection closed before full header was received',
        'Connection reset by peer',
        'Broken pipe',
        'Software caused connection abort',
        'Connection terminated',
        'Temporarily unavailable',
        'Timed out',
      ];
      for (final detail in retryableDetails) {
        final result = AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          statusCode: 500,
          detail: detail,
        );
        expect(
          isRetryableStoryGenerationTransportFailure(result),
          isTrue,
          reason: 'should be retryable: "$detail"',
        );
      }
    });

    test('returns false for server failures with non-retryable detail', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        statusCode: 500,
        detail: 'internal server error',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns true for invalid-response with retryable detail', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.invalidResponse,
        detail: 'Connection reset by peer',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns false for invalid-response with non-retryable detail', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.invalidResponse,
        detail: 'empty body',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('retryable detail matching is case-insensitive', () {
      final result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        statusCode: 502,
        detail: 'BROKEN PIPE',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });
  });

  group('requestStoryGenerationPassWithRetry', () {
    late _SequencedFakeLlmClient fakeLlm;
    late AppSettingsStore settingsStore;

    setUp(() {
      fakeLlm = _SequencedFakeLlmClient();
      AppSettingsStore.debugLlmClientOverride = fakeLlm;
      settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        eventLog: AppEventLog(
          storage: _DiscardingAppEventLogStorage(),
        ),
      );
    });

    tearDown(() {
      AppSettingsStore.debugLlmClientOverride = null;
    });

    test('returns successful result immediately without retry', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.success(text: 'good result'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: settingsStore,
        messages: const [AppLlmChatMessage(role: 'user', content: 'test')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'good result');
      expect(fakeLlm.callCount, 1);
    });

    test('retries on retryable failure and succeeds on second attempt',
        () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'connection refused',
        ),
        const AppLlmChatResult.success(text: 'recovered'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: settingsStore,
        messages: const [AppLlmChatMessage(role: 'user', content: 'test')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'recovered');
      expect(fakeLlm.callCount, 2);
    });

    test('retries up to max retries then returns last failure', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timed out',
        ),
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'connection reset',
        ),
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timed out again',
        ),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: settingsStore,
        messages: const [AppLlmChatMessage(role: 'user', content: 'test')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.timeout);
      expect(result.detail, 'timed out again');
      expect(fakeLlm.callCount, 3);
    });

    test('does not retry on non-retryable failure', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.unauthorized,
          statusCode: 401,
          detail: 'bad key',
        ),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: settingsStore,
        messages: const [AppLlmChatMessage(role: 'user', content: 'test')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.unauthorized);
      expect(fakeLlm.callCount, 1);
    });

    test('does not retry on model-not-found failure', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.modelNotFound,
          statusCode: 404,
          detail: 'model missing',
        ),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: settingsStore,
        messages: const [AppLlmChatMessage(role: 'user', content: 'test')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.modelNotFound);
      expect(fakeLlm.callCount, 1);
    });

    test('retries on server failure with retryable detail', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          statusCode: 502,
          detail: 'Connection reset by peer',
        ),
        const AppLlmChatResult.success(text: 'ok after retry'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: settingsStore,
        messages: const [AppLlmChatMessage(role: 'user', content: 'test')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'ok after retry');
      expect(fakeLlm.callCount, 2);
    });

    test('does not retry on server failure with non-retryable detail',
        () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          statusCode: 500,
          detail: 'internal server error',
        ),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: settingsStore,
        messages: const [AppLlmChatMessage(role: 'user', content: 'test')],
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(fakeLlm.callCount, 1);
    });

    test('respects maxConcurrentRequests from settings', () async {
      final completers = <Completer<AppLlmChatResult>>[
        Completer(),
        Completer(),
      ];
      var callIndex = 0;

      final blockingClient = _BlockingFakeLlmClient(() {
        final index = callIndex++;
        return completers[index].future;
      });

      final gateSettingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: blockingClient,
        eventLog: AppEventLog(
          storage: _DiscardingAppEventLogStorage(),
        ),
      );
      await gateSettingsStore.save(
        providerName: 'test',
        baseUrl: 'http://localhost',
        model: 'test-model',
        apiKey: 'sk-test',
        timeout: AppLlmTimeoutConfig.uniform(5000),
        maxConcurrentRequests: 1,
      );

      final future1 = requestStoryGenerationPassWithRetry(
        settingsStore: gateSettingsStore,
        messages: const [AppLlmChatMessage(role: 'user', content: 'first')],
        maxTransientRetries: 0,
      );
      final future2 = requestStoryGenerationPassWithRetry(
        settingsStore: gateSettingsStore,
        messages: const [AppLlmChatMessage(role: 'user', content: 'second')],
        maxTransientRetries: 0,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(blockingClient.activeCalls, 1);

      completers[0].complete(
        const AppLlmChatResult.success(text: 'first done'),
      );
      final result1 = await future1;
      expect(result1.text, 'first done');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(blockingClient.activeCalls, 1);

      completers[1].complete(
        const AppLlmChatResult.success(text: 'second done'),
      );
      final result2 = await future2;
      expect(result2.text, 'second done');
    });
  });
}

class _SequencedFakeLlmClient implements AppLlmClient {
  final List<AppLlmChatResult> _results = [];
  int callCount = 0;

  void enqueue(List<AppLlmChatResult> results) {
    _results.addAll(results);
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    callCount += 1;
    if (_results.isEmpty) {
      throw StateError('no more results enqueued');
    }
    return _results.removeAt(0);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnimplementedError('chatStream');
  }
}

class _BlockingFakeLlmClient implements AppLlmClient {
  _BlockingFakeLlmClient(this._onChat);
  final Future<AppLlmChatResult> Function() _onChat;
  int activeCalls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    activeCalls += 1;
    try {
      return await _onChat();
    } finally {
      activeCalls -= 1;
    }
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnimplementedError('chatStream');
  }
}

class _DiscardingAppEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) async {}
}
