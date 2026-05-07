import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';

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
  group('Communication security', () {
    test('HTTP scheme is rejected with insecureScheme', () async {
      final client = FakeAppLlmClient();
      final result = await client.chat(
        _request(baseUrl: 'http://api.example.com'),
      );
      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.insecureScheme);
    });

    test('HTTPS scheme is accepted', () async {
      final client = FakeAppLlmClient();
      final result = await client.chat(
        _request(baseUrl: 'https://api.example.com'),
      );
      expect(result.succeeded, isTrue);
    });

    test('localhost HTTP is allowed for development', () async {
      final client = FakeAppLlmClient();
      final result = await client.chat(
        _request(baseUrl: 'http://localhost:11434', apiKey: ''),
      );
      // Should NOT be insecureScheme - localhost is allowed
      expect(
        result.failureKind,
        isNot(equals(AppLlmFailureKind.insecureScheme)),
      );
    });

    test('127.0.0.1 HTTP is allowed for development', () async {
      final client = FakeAppLlmClient();
      final result = await client.chat(
        _request(baseUrl: 'http://127.0.0.1:11434', apiKey: ''),
      );
      expect(
        result.failureKind,
        isNot(equals(AppLlmFailureKind.insecureScheme)),
      );
    });

    test('stream rejects HTTP scheme with insecureScheme', () async {
      final client = FakeAppLlmClient();
      final stream = client.chatStream(
        _request(baseUrl: 'http://api.example.com'),
      );
      expect(
        stream,
        emitsError(
          isA<AppLlmStreamException>().having(
            (e) => e.failureKind,
            'failureKind',
            AppLlmFailureKind.insecureScheme,
          ),
        ),
      );
    });
  });
}
