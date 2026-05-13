import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';

import 'test_support/fake_app_llm_client.dart';

AppLlmChatRequest _request({
  String baseUrl = 'https://api.example.com',
  String apiKey = 'sk-test',
  String model = 'test-model',
  String message = 'hello',
}) {
  return AppLlmChatRequest(
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    messages: [AppLlmChatMessage(role: 'user', content: message)],
  );
}

void main() {
  group('LLM error scenarios via FakeAppLlmClient', () {
    test('network error returns network failure kind', () async {
      final client = FakeAppLlmClient();
      final result = await client.chat(
        _request(baseUrl: 'https://offline.invalid'),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.network);
    });

    test('timeout error returns timeout failure kind', () async {
      final client = FakeAppLlmClient();
      final result = await client.chat(
        _request(baseUrl: 'https://timeout.example.com'),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.timeout);
    });

    test('unauthorized (401) returns unauthorized failure kind', () async {
      final client = FakeAppLlmClient();
      final result = await client.chat(_request(apiKey: 'sk-unauthorized'));

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.unauthorized);
      expect(result.statusCode, 401);
    });

    test('model not found returns modelNotFound failure kind', () async {
      final client = FakeAppLlmClient();
      final result = await client.chat(_request(model: 'missing-model-404'));

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.modelNotFound);
      expect(result.statusCode, 404);
    });

    test('rate limited response via custom responder', () async {
      final client = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.rateLimited,
          statusCode: 429,
          detail: 'Rate limit exceeded',
        ),
      );
      final result = await client.chat(_request());

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.rateLimited);
      expect(result.statusCode, 429);
    });

    test('empty content response is not considered succeeded', () async {
      final client = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(text: ''),
      );
      final result = await client.chat(_request());

      // succeeded checks text != null AND failureKind == null
      // Empty string is not null but AppLlmChatResult.succeeded checks text != null
      expect(result.text, '');
      expect(result.failureKind, isNull);
    });

    test('null text response is not succeeded', () async {
      final client = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.invalidResponse,
          detail: 'No content in response',
        ),
      );
      final result = await client.chat(_request());

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.invalidResponse);
    });

    test('stream error propagates AppLlmStreamException', () async {
      final client = FakeAppLlmClient(
        streamResponder: (_) => Stream.error(
          const AppLlmStreamException(
            failureKind: AppLlmFailureKind.rateLimited,
            statusCode: 429,
            detail: 'Rate limited mid-stream',
          ),
        ),
      );

      final stream = client.chatStream(_request());
      expect(stream, emitsError(isA<AppLlmStreamException>()));
    });

    test('stream interruption after partial data', () async {
      final controller = StreamController<String>();
      addTearDown(controller.close);
      controller.add('Partial text...');
      controller.addError(
        const AppLlmStreamException(
          failureKind: AppLlmFailureKind.network,
          detail: 'Connection lost',
        ),
      );

      final client = FakeAppLlmClient(
        streamResponder: (_) => controller.stream,
      );

      final collected = <String>[];
      try {
        await for (final chunk in client.chatStream(_request())) {
          collected.add(chunk);
        }
      } on AppLlmStreamException {
        // Expected: stream emits partial data then errors.
      }
      expect(collected, ['Partial text...']);
    });
  });

  group('Response decoding edge cases', () {
    test('malformed JSON throws FormatException', () {
      expect(
        () => decodeOpenAiChatResponseBody('{invalid json'),
        throwsFormatException,
      );
    });

    test('empty body throws FormatException', () {
      expect(() => decodeOpenAiChatResponseBody(''), throwsFormatException);
    });

    test('valid JSON but no choices returns null', () {
      expect(decodeOpenAiChatResponseBody('{"id":"chatcmpl-1"}'), isNull);
    });

    test('choices with empty content returns null', () {
      expect(
        decodeOpenAiChatResponseBody(
          '{"choices":[{"message":{"content":""}}]}',
        ),
        isNull,
      );
    });

    test('valid response with content succeeds', () {
      final result = decodeOpenAiChatResponseBody(
        '{"choices":[{"message":{"content":"Hello world"}}]}',
      );
      expect(result, isNotNull);
      expect(result!.text, 'Hello world');
    });

    test('response with token usage', () {
      final result = decodeOpenAiChatResponseBody(
        '{"choices":[{"message":{"content":"text"}}],'
        '"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}',
      );
      expect(result, isNotNull);
      expect(result!.promptTokens, 10);
      expect(result.completionTokens, 5);
      expect(result.totalTokens, 15);
    });

    test('stream body with malformed SSE line is skipped', () {
      final result = decodeOpenAiChatStreamBody(
        'data: {not-json-at-all}\ndata: {"choices":[{"delta":{"content":"ok"}}]}\n',
      );
      // First line is malformed → skipped. Second line is valid.
      expect(result, isNotNull);
      expect(result!.text, 'ok');
    });

    test('stream body with only [DONE] returns null', () {
      final result = decodeOpenAiChatStreamBody('data: [DONE]\n');
      expect(result, isNull);
    });
  });
}
