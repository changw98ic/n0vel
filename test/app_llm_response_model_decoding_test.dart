import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';

void main() {
  test('normal OpenAI response preserves provider model identity', () {
    final decoded = decodeOpenAiChatResponseBody('''
      {
        "id": "chatcmpl-root-1",
        "model": "glm-4.7-flash",
        "choices": [{"message": {"content": "pong"}}],
        "usage": {
          "prompt_tokens": 3,
          "completion_tokens": 1,
          "total_tokens": 4
        }
      }
    ''');

    expect(decoded, isNotNull);
    expect(decoded!.providerResponseId, 'chatcmpl-root-1');
    expect(decoded.providerModel, 'glm-4.7-flash');
    expect(decoded.promptTokens, 3);
    expect(decoded.completionTokens, 1);
  });

  test('stream response preserves the last echoed provider model', () {
    final decoded = decodeOpenAiChatStreamBody('''
data: {"id":"chatcmpl-stream-1","model":"glm-4.7-flash","choices":[{"delta":{"content":"po"}}]}

data: {"id":"chatcmpl-stream-1","model":"glm-4.7-flash","choices":[{"delta":{"content":"ng"}}],"usage":{"prompt_tokens":3,"completion_tokens":1,"total_tokens":4}}

data: [DONE]
''');

    expect(decoded, isNotNull);
    expect(decoded!.providerResponseId, 'chatcmpl-stream-1');
    expect(decoded.providerModel, 'glm-4.7-flash');
    expect(decoded.text, 'pong');
    expect(decoded.totalTokens, 4);
  });

  test('normal Anthropic response preserves model and split usage', () {
    final decoded = decodeAnthropicMessageResponseBody('''
      {
        "id": "msg-root-1",
        "model": "glm-5.2",
        "content": [{"type":"text","text":"pong"}],
        "usage": {"input_tokens": 7, "output_tokens": 2}
      }
    ''');

    expect(decoded, isNotNull);
    expect(decoded!.providerResponseId, 'msg-root-1');
    expect(decoded.providerModel, 'glm-5.2');
    expect(decoded.promptTokens, 7);
    expect(decoded.completionTokens, 2);
    expect(decoded.totalTokens, 9);
  });

  test('Anthropic SSE response preserves message model and split usage', () {
    final decoded = decodeAnthropicMessageStreamBody('''
data: {"type":"message_start","message":{"id":"msg-stream-1","model":"glm-5.2","usage":{"input_tokens":7}}}

data: {"type":"content_block_delta","delta":{"text":"pong"}}

data: {"type":"message_delta","usage":{"output_tokens":2}}

data: {"type":"message_stop"}
''');

    expect(decoded, isNotNull);
    expect(decoded!.providerResponseId, 'msg-stream-1');
    expect(decoded.providerModel, 'glm-5.2');
    expect(decoded.text, 'pong');
    expect(decoded.promptTokens, 7);
    expect(decoded.completionTokens, 2);
    expect(decoded.totalTokens, 9);
  });

  test('Anthropic client uses v1/messages and exact usage once', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var dispatches = 0;
    server.listen((request) async {
      dispatches += 1;
      expect(request.uri.path, '/api/anthropic/v1/messages');
      expect(request.headers.value('x-api-key'), 'test-only');
      expect(request.headers.value('authorization'), isNull);
      final body = await utf8.decoder.bind(request).join();
      final decodedRequest = jsonDecode(body) as Map<String, Object?>;
      expect(decodedRequest['stream'], isFalse);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'id': 'msg-client-1',
          'model': 'glm-5.2',
          'content': [
            <String, Object?>{'type': 'text', 'text': 'pong'},
          ],
          'usage': <String, Object?>{'input_tokens': 7, 'output_tokens': 2},
        }),
      );
      await request.response.close();
    });

    final result = await createDefaultAppLlmClient().chat(
      AppLlmChatRequest(
        baseUrl: 'http://127.0.0.1:${server.port}/api/anthropic',
        apiKey: 'test-only',
        model: 'glm-5.2',
        provider: AppLlmProvider.anthropic,
        maxTokens: 4096,
        preferStreaming: false,
        messages: const [AppLlmChatMessage(role: 'user', content: 'ping')],
      ),
    );

    expect(result.succeeded, isTrue);
    expect(result.providerResponseId, 'msg-client-1');
    expect(result.providerModel, 'glm-5.2');
    expect(result.promptTokens, 7);
    expect(result.completionTokens, 2);
    expect(result.totalTokens, 9);
    expect(dispatches, 1);
  });

  test(
    'preferStreaming false performs exactly one physical HTTP dispatch',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var dispatches = 0;
      server.listen((request) async {
        dispatches += 1;
        final body = await utf8.decoder.bind(request).join();
        final decodedRequest = jsonDecode(body) as Map<String, Object?>;
        expect(decodedRequest['stream'], isFalse);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'id': 'chatcmpl-client-1',
            'model': 'glm-4.7-flash',
            'choices': [
              <String, Object?>{
                'message': <String, Object?>{'content': 'pong'},
              },
            ],
            'usage': <String, Object?>{
              'prompt_tokens': 3,
              'completion_tokens': 1,
              'total_tokens': 4,
            },
          }),
        );
        await request.response.close();
      });

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          apiKey: 'test-only',
          model: 'glm-4.7-flash',
          maxTokens: 4096,
          preferStreaming: false,
          messages: const [AppLlmChatMessage(role: 'user', content: 'ping')],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.providerResponseId, 'chatcmpl-client-1');
      expect(result.providerModel, 'glm-4.7-flash');
      expect(result.totalTokens, 4);
      expect(dispatches, 1);
    },
  );
}
