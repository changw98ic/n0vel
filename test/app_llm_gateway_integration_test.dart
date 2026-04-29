import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';

void main() {
  group('LLM gateway integration', () {
    test('maps 403 forbidden to unauthorized failure', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.forbidden
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': {'message': '您没有访问此模型的权限'},
            }),
          );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-no-perm',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '测试403')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.unauthorized);
      expect(result.statusCode, HttpStatus.forbidden);
      expect(result.detail, '您没有访问此模型的权限');
    });

    test('maps 429 rate-limited response to rateLimited failure', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = 429
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': {'message': '请求过于频繁，请稍后重试'},
            }),
          );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-rate-limited',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '触发限流')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.rateLimited);
      expect(result.statusCode, 429);
      expect(result.detail, '请求过于频繁，请稍后重试');
    });

    test('maps 503 service unavailable to server failure', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': {'message': '模型服务暂时不可用'},
            }),
          );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '服务不可用')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(result.statusCode, HttpStatus.serviceUnavailable);
      expect(result.detail, '模型服务暂时不可用');
    });

    test('extracts error detail from top-level message field', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.badGateway
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'message': '上游网关异常'}));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '网关异常')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(result.statusCode, HttpStatus.badGateway);
      expect(result.detail, '上游网关异常');
    });

    test('handles large SSE streams with many delta chunks', () async {
      const chunkCount = 60;
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          'Content-Type',
          'text/event-stream; charset=utf-8',
        );
        for (var i = 0; i < chunkCount; i++) {
          request.response.add(
            utf8.encode(
              'data: {"choices":[{"delta":{"content":"第${i + 1}段。"},'
              '"index":0}]}\n\n',
            ),
          );
        }
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(5000),
          messages: const [AppLlmChatMessage(role: 'user', content: '长文本测试')],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, isNotNull);
      expect(result.text!.startsWith('第1段。'), isTrue);
      expect(result.text!.contains('第$chunkCount段。'), isTrue);
      expect(result.latencyMs, isNotNull);
    });

    test('decodes CJK characters correctly in streamed responses', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          'Content-Type',
          'text/event-stream; charset=utf-8',
        );
        request.response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"在那遥远的山谷中"},'
            '"index":0}]}\n\n',
          ),
        );
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '中文流式测试')],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, '在那遥远的山谷中');
    });

    test('ignores non-data lines in SSE stream', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          'Content-Type',
          'text/event-stream; charset=utf-8',
        );
        request.response.add(
          utf8.encode(
            ': this is a comment\n\n'
            '\n'
            'data: {"choices":[{"delta":{"content":"有效"},"index":0}]}\n\n'
            ': another comment\n'
            '\n'
            'data: {"choices":[{"delta":{"content":"文本"},"index":0}]}\n\n'
            'data: [DONE]\n\n',
          ),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '噪音行测试')],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, '有效文本');
    });

    test('handles concurrent requests to same server', () async {
      var requestCount = 0;
      final server = await _startServer((request) async {
        requestCount++;
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('text', 'event-stream')
          ..write(
            'data: {"choices":[{"delta":{"content":"reply-$requestCount"},'
            '"index":0}]}\n\n',
          )
          ..write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      const concurrency = 5;
      final results = await Future.wait(
        List.generate(concurrency, (i) {
          return createDefaultAppLlmClient().chat(
            AppLlmChatRequest(
              baseUrl: _baseUrl(server),
              apiKey: 'sk-ok',
              model: 'gpt-5.4',
              timeout: AppLlmTimeoutConfig.uniform(5000),
              messages: [AppLlmChatMessage(role: 'user', content: '并发请求 $i')],
            ),
          );
        }),
      );

      for (final result in results) {
        expect(result.succeeded, isTrue);
        expect(result.text, isNotNull);
        expect(result.text!, startsWith('reply-'));
      }
    });

    test('handles sequential requests on same client instance', () async {
      final server = await _startServer((request) async {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>;
        final lastMessage =
            (body['messages'] as List).last as Map<String, Object?>;
        final content = lastMessage['content'].toString();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          'Content-Type',
          'text/event-stream; charset=utf-8',
        );
        request.response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"回复：$content"},'
            '"index":0}]}\n\n',
          ),
        );
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final client = createDefaultAppLlmClient();

      final first = await client.chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '第一条')],
        ),
      );
      expect(first.succeeded, isTrue);
      expect(first.text, '回复：第一条');

      final second = await client.chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '第二条')],
        ),
      );
      expect(second.succeeded, isTrue);
      expect(second.text, '回复：第二条');

      final third = await client.chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '第三条')],
        ),
      );
      expect(third.succeeded, isTrue);
      expect(third.text, '回复：第三条');
    });

    test('times out during response body streaming', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          'Content-Type',
          'text/event-stream; charset=utf-8',
        );
        request.response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"start"},"index":0}]}\n\n',
          ),
        );
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        request.response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"too late"},"index":0}]}\n\n',
          ),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(150),
          messages: const [AppLlmChatMessage(role: 'user', content: '流式超时')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.timeout);
    });

    test('normalizes base URL paths for chat completions endpoint', () async {
      final capturedUris = <Uri>[];
      final server = await _startServer((request) async {
        capturedUris.add(request.uri);
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('text', 'event-stream')
          ..write(
            'data: {"choices":[{"delta":{"content":"ok"},"index":0}]}\n\n',
          )
          ..write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final withoutSlash = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: 'http://${server.address.host}:${server.port}/v1',
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '无斜杠')],
        ),
      );
      expect(withoutSlash.succeeded, isTrue);
      expect(capturedUris.last.path, '/v1/chat/completions');

      final withSlash = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: 'http://${server.address.host}:${server.port}/v1/',
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: '有斜杠')],
        ),
      );
      expect(withSlash.succeeded, isTrue);
      expect(capturedUris.last.path, '/v1/chat/completions');
    });

    test('handles connection refused when server is down', () async {
      final reserved = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = reserved.port;
      await reserved.close();

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: 'http://127.0.0.1:$port/v1',
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(3000),
          messages: const [AppLlmChatMessage(role: 'user', content: '服务器关闭')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.network);
    });

    test('handles multi-turn conversation with system message', () async {
      late final List<Map<String, Object?>> capturedMessages;
      final server = await _startServer((request) async {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>;
        capturedMessages = (body['messages'] as List)
            .cast<Map<String, Object?>>();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          'Content-Type',
          'text/event-stream; charset=utf-8',
        );
        request.response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"好的，我明白了。"},'
            '"index":0}]}\n\n',
          ),
        );
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [
            AppLlmChatMessage(role: 'system', content: '你是一位专业的小说写作助手。'),
            AppLlmChatMessage(role: 'user', content: '请帮我构思一个场景'),
            AppLlmChatMessage(role: 'assistant', content: '好的，以下是场景构思：...'),
            AppLlmChatMessage(role: 'user', content: '请继续扩展'),
          ],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, '好的，我明白了。');
      expect(capturedMessages.length, 4);
      expect(capturedMessages[0]['role'], 'system');
      expect(capturedMessages[1]['role'], 'user');
      expect(capturedMessages[2]['role'], 'assistant');
      expect(capturedMessages[3]['role'], 'user');
    });

    test('handles server returning HTML error page', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.html
          ..write('<html><body><h1>502 Bad Gateway</h1></body></html>');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [AppLlmChatMessage(role: 'user', content: 'HTML错误')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(result.statusCode, HttpStatus.internalServerError);
      expect(result.detail, contains('502'));
    });

    test('records latency for successful requests', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '延迟测试'},
                },
              ],
            }),
          );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(5000),
          messages: const [AppLlmChatMessage(role: 'user', content: '延迟测试')],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, '延迟测试');
      expect(result.latencyMs, isNotNull);
      expect(result.latencyMs!, greaterThanOrEqualTo(40));
    });
  });
}

Future<HttpServer> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(server.forEach(handler));
  return server;
}

String _baseUrl(HttpServer server) {
  return 'http://${server.address.host}:${server.port}';
}
