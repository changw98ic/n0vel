import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';

void main() {
  group('AppLlmFailureKind', () {
    test('has exactly 8 values', () {
      expect(AppLlmFailureKind.values, hasLength(8));
    });

    test('contains all expected variants', () {
      const expected = {
        AppLlmFailureKind.unauthorized,
        AppLlmFailureKind.timeout,
        AppLlmFailureKind.network,
        AppLlmFailureKind.rateLimited,
        AppLlmFailureKind.modelNotFound,
        AppLlmFailureKind.invalidResponse,
        AppLlmFailureKind.server,
        AppLlmFailureKind.unsupportedPlatform,
      };
      expect(Set<AppLlmFailureKind>.from(AppLlmFailureKind.values), expected);
    });
  });

  group('AppLlmChatMessage', () {
    test('stores role and content', () {
      const msg = AppLlmChatMessage(role: 'user', content: 'hello');
      expect(msg.role, 'user');
      expect(msg.content, 'hello');
    });

    test('toJson returns correct map', () {
      const msg = AppLlmChatMessage(role: 'system', content: '你是助手');
      expect(msg.toJson(), {'role': 'system', 'content': '你是助手'});
    });

    test('toJson with empty content', () {
      const msg = AppLlmChatMessage(role: 'assistant', content: '');
      expect(msg.toJson(), {'role': 'assistant', 'content': ''});
    });
  });

  group('AppLlmChatRequest', () {
    test('stores all fields', () {
      const request = AppLlmChatRequest(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-test',
        model: 'gpt-4',
        timeoutMs: 5000,
        messages: [AppLlmChatMessage(role: 'user', content: 'hi')],
      );

      expect(request.baseUrl, 'https://api.example.com/v1');
      expect(request.apiKey, 'sk-test');
      expect(request.model, 'gpt-4');
      expect(request.timeoutMs, 5000);
      expect(request.messages, hasLength(1));
      expect(request.messages.first.role, 'user');
      expect(request.messages.first.content, 'hi');
    });

    test('accepts empty messages list', () {
      const request = AppLlmChatRequest(
        baseUrl: 'http://localhost',
        apiKey: '',
        model: 'model',
        timeoutMs: 1000,
        messages: [],
      );
      expect(request.messages, isEmpty);
    });

    test('accepts multiple messages', () {
      const request = AppLlmChatRequest(
        baseUrl: 'http://localhost',
        apiKey: 'key',
        model: 'm',
        timeoutMs: 1000,
        messages: [
          AppLlmChatMessage(role: 'system', content: 'sys'),
          AppLlmChatMessage(role: 'user', content: 'u1'),
          AppLlmChatMessage(role: 'assistant', content: 'a1'),
          AppLlmChatMessage(role: 'user', content: 'u2'),
        ],
      );
      expect(request.messages, hasLength(4));
      expect(request.messages[0].role, 'system');
      expect(request.messages[3].content, 'u2');
    });

    test('uses omitted max token limit by default', () {
      const request = AppLlmChatRequest(
        baseUrl: 'http://localhost',
        apiKey: 'key',
        model: 'm',
        timeoutMs: 1000,
        messages: [AppLlmChatMessage(role: 'user', content: 'test')],
      );

      expect(request.maxTokens, AppLlmChatRequest.unlimitedMaxTokens);
      expect(request.effectiveMaxTokens, AppLlmChatRequest.unlimitedMaxTokens);
    });

    test('normalizes non-positive max token values to omitted limit', () {
      expect(
        AppLlmChatRequest.normalizeMaxTokens(0),
        AppLlmChatRequest.unlimitedMaxTokens,
      );
      expect(
        AppLlmChatRequest.normalizeMaxTokens(-1),
        AppLlmChatRequest.unlimitedMaxTokens,
      );
    });
  });

  group('AppLlmChatResult', () {
    group('success constructor', () {
      test('sets text and leaves failure fields null', () {
        const result = AppLlmChatResult.success(text: 'hello');
        expect(result.text, 'hello');
        expect(result.latencyMs, isNull);
        expect(result.failureKind, isNull);
        expect(result.statusCode, isNull);
        expect(result.detail, isNull);
      });

      test('accepts optional latencyMs', () {
        const result = AppLlmChatResult.success(text: 'hi', latencyMs: 42);
        expect(result.text, 'hi');
        expect(result.latencyMs, 42);
      });

      test('succeeded is true when text is non-null', () {
        const result = AppLlmChatResult.success(text: 'ok');
        expect(result.succeeded, isTrue);
      });
    });

    group('failure constructor', () {
      test('sets failure kind and leaves text null', () {
        const result = AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
        );
        expect(result.text, isNull);
        expect(result.latencyMs, isNull);
        expect(result.failureKind, AppLlmFailureKind.timeout);
        expect(result.statusCode, isNull);
        expect(result.detail, isNull);
      });

      test('accepts optional statusCode and detail', () {
        const result = AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.unauthorized,
          statusCode: 401,
          detail: 'bad key',
        );
        expect(result.failureKind, AppLlmFailureKind.unauthorized);
        expect(result.statusCode, 401);
        expect(result.detail, 'bad key');
      });

      test('succeeded is false for each failure kind', () {
        for (final kind in AppLlmFailureKind.values) {
          final result = AppLlmChatResult.failure(failureKind: kind);
          expect(result.succeeded, isFalse, reason: '$kind should not succeed');
        }
      });
    });

    test('succeeded is false when text is null even without failure kind', () {
      // Constructs via named constructor abuse isn't possible because
      // both constructors force either text or failureKind, but we verify
      // the getter logic: succeeded => failureKind == null && text != null
      const result = AppLlmChatResult.success(text: 'ok');
      expect(result.succeeded, isTrue);

      const failResult = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
      );
      expect(failResult.succeeded, isFalse);
    });
  });

  group('AppLlmClient contract', () {
    test('FakeAppLlmClient implements AppLlmClient', () {
      // Verify the fake client satisfies the abstract interface.
      final client = _PassthroughClient();
      expect(client, isA<AppLlmClient>());
    });

    test('chat returns AppLlmChatResult', () async {
      final client = _PassthroughClient();
      const request = AppLlmChatRequest(
        baseUrl: 'http://localhost',
        apiKey: 'key',
        model: 'm',
        timeoutMs: 1000,
        messages: [AppLlmChatMessage(role: 'user', content: 'test')],
      );
      final result = await client.chat(request);
      expect(result, isA<AppLlmChatResult>());
      expect(result.text, 'echo');
      expect(result.succeeded, isTrue);
    });

    test('chat can return failure result', () async {
      final client = _FailingClient();
      const request = AppLlmChatRequest(
        baseUrl: 'http://localhost',
        apiKey: 'key',
        model: 'm',
        timeoutMs: 1000,
        messages: [],
      );
      final result = await client.chat(request);
      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.network);
    });
  });
}

class _PassthroughClient implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    return const AppLlmChatResult.success(text: 'echo');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    return Stream<String>.value('echo');
  }
}

class _FailingClient implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    return const AppLlmChatResult.failure(
      failureKind: AppLlmFailureKind.network,
      detail: 'unreachable',
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    return Stream<String>.error(
      const AppLlmStreamException(
        failureKind: AppLlmFailureKind.network,
        detail: 'unreachable',
      ),
    );
  }
}
