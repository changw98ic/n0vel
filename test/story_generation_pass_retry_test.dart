import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';

void main() {
  group('isRetryableStoryGenerationTransportFailure', () {
    test('returns false for successful results', () {
      const result = AppLlmChatResult.success(text: 'hello');
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

    test('returns true for rate limited failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.rateLimited,
        statusCode: 429,
        detail: 'too many requests',
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
        'Server overloaded, please retry shortly',
        'Server error. Please try again in 30 seconds.',
        'Too many requests',
        'Rate limit exceeded',
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
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        statusCode: 502,
        detail: 'BROKEN PIPE',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });
  });

  group('requestStoryGenerationPassWithRetry', () {
    late _SequencedFakeLlmClient fakeLlm;
    late StoryGenerationAttemptDispatcher dispatch;

    setUp(() {
      fakeLlm = _SequencedFakeLlmClient();
      dispatch = _retryDispatcher(fakeLlm, const <AppLlmChatMessage>[
        AppLlmChatMessage(role: 'user', content: 'test'),
      ]);
    });

    test('returns successful result immediately without retry', () async {
      fakeLlm.enqueue([const AppLlmChatResult.success(text: 'good result')]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'good result');
      expect(fakeLlm.callCount, 1);
      expect(fakeLlm.maxTokensSeen, [AppLlmChatRequest.unlimitedMaxTokens]);
    });

    test(
      'escalates empty output but retries semantic output at the same token budget',
      () async {
        fakeLlm.enqueue([
          const AppLlmChatResult.success(text: ''),
          const AppLlmChatResult.success(text: 'still malformed'),
          const AppLlmChatResult.success(text: 'usable result'),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          initialMaxTokens: storyGenerationEditorialMaxTokens,
          shouldRetryOutput: (text) => text.contains('malformed'),
        );

        expect(result.text, 'usable result');
        expect(fakeLlm.maxTokensSeen, [4096, 8192, 8192]);
      },
    );

    test('stops semantic output retries at maxOutputRetries', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.success(text: 'still malformed 1'),
        const AppLlmChatResult.success(text: 'still malformed 2'),
        const AppLlmChatResult.success(text: 'still malformed 3'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        shouldRetryOutput: (text) => text.contains('malformed'),
        maxOutputRetries: 2,
      );

      expect(result.text, 'still malformed 3');
      expect(fakeLlm.maxTokensSeen, [0, 0, 0]);
    });

    test('starts editorial retries at 4096 and can escalate to 8192', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.success(text: 'draft truncated，'),
        const AppLlmChatResult.success(text: 'complete draft'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        initialMaxTokens: storyGenerationEditorialMaxTokens,
      );

      expect(result.text, 'complete draft');
      expect(fakeLlm.maxTokensSeen, [4096, 8192]);
    });

    test(
      'retries on retryable failure and succeeds on second attempt',
      () async {
        fakeLlm.enqueue([
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'connection refused',
          ),
          const AppLlmChatResult.success(text: 'recovered'),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          maxTransientRetries: 2,
        );

        expect(result.succeeded, isTrue);
        expect(result.text, 'recovered');
        expect(fakeLlm.callCount, 2);
      },
    );

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
        dispatch: dispatch,
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
        dispatch: dispatch,
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
        dispatch: dispatch,
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
        dispatch: dispatch,
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'ok after retry');
      expect(fakeLlm.callCount, 2);
    });

    test(
      'does not retry on server failure with non-retryable detail',
      () async {
        fakeLlm.enqueue([
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            statusCode: 500,
            detail: 'internal server error',
          ),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          maxTransientRetries: 2,
        );

        expect(result.succeeded, isFalse);
        expect(result.failureKind, AppLlmFailureKind.server);
        expect(fakeLlm.callCount, 1);
      },
    );

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
        eventLog: AppEventLog(storage: _DiscardingAppEventLogStorage()),
      );
      addTearDown(gateSettingsStore.dispose);
      await gateSettingsStore.save(
        providerName: 'test',
        baseUrl: 'http://localhost',
        model: 'test-model',
        apiKey: 'sk-test',
        timeout: const AppLlmTimeoutConfig.uniform(5000),
        maxConcurrentRequests: 1,
      );
      final invocation = StoryPromptRegistry.production.invocation(
        stageId: 'quality-gate',
        callSiteId: 'quality-scorer',
      );
      final resolvedVariables = _resolvedVariables(invocation.release);
      final messages = invocation.render(resolvedVariables).messages;
      final invocationEvidence = invocation.evidence(
        messages,
        resolvedVariables: resolvedVariables,
      );

      final future1 = requestFormalStoryGenerationPassWithRetry(
        settingsStore: gateSettingsStore,
        messages: messages,
        maxTransientRetries: 0,
        promptInvocation: invocation,
        promptInvocationEvidence: invocationEvidence,
      );
      final future2 = requestFormalStoryGenerationPassWithRetry(
        settingsStore: gateSettingsStore,
        messages: messages,
        maxTransientRetries: 0,
        promptInvocation: invocation,
        promptInvocationEvidence: invocationEvidence,
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

StoryGenerationAttemptDispatcher _retryDispatcher(
  AppLlmClient client,
  List<AppLlmChatMessage> messages,
) =>
    ({
      required int maxTokens,
      required int attempt,
      required int transientRetryCount,
      required int outputRetryCount,
    }) => client.chat(
      AppLlmChatRequest(
        baseUrl: 'https://retry-policy.test',
        apiKey: 'test-credential',
        model: 'test-model',
        maxTokens: maxTokens,
        messages: messages,
      ),
    );

Map<String, Object?> _resolvedVariables(PromptRelease release) {
  final schema = release.variablesSchemaSnapshot as Map<String, Object?>;
  final properties = schema['properties']! as Map<String, Object?>;
  return <String, Object?>{
    for (final entry in properties.entries)
      entry.key: switch ((entry.value as Map<String, Object?>)['type']) {
        'string' => 'fixture=${entry.key}',
        'integer' => 1,
        'number' => 1.0,
        'boolean' => true,
        _ => throw StateError('unsupported fixture variable: ${entry.key}'),
      },
  };
}

class _SequencedFakeLlmClient implements AppLlmClient {
  final List<AppLlmChatResult> _results = [];
  final List<int> maxTokensSeen = [];
  int callCount = 0;

  void enqueue(List<AppLlmChatResult> results) {
    _results.addAll(results);
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    callCount += 1;
    maxTokensSeen.add(request.maxTokens);
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
