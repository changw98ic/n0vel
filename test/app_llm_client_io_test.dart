import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';

void main() {
  group('real IO app llm client', () {
    test('posts chat completions and trims text responses', () async {
      late final Uri requestUri;
      late final Map<String, Object?> requestJson;
      late final String? authorization;
      final server = await _startServer((request) async {
        requestUri = request.uri;
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        requestJson =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('text', 'event-stream')
          ..write(
            'data: {"choices":[{"delta":{"content":"  reply  "},"index":0}]}\n\n',
          )
          ..write(
            'data: {"choices":[{"delta":{},"finish_reason":"stop","index":0}]}\n\n',
          )
          ..write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final client = createDefaultAppLlmClient();
      final result = await client.chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server, suffix: '/v1'),
          apiKey: '  sk-real-key  ',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(1000),
          messages: const [
            AppLlmChatMessage(role: 'system', content: '你是写作助手'),
            AppLlmChatMessage(role: 'user', content: '请给我一句建议'),
          ],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'reply');
      expect(result.latencyMs, isNotNull);
      expect(requestUri.path, '/v1/chat/completions');
      expect(authorization, 'Bearer sk-real-key');
      expect(requestJson['model'], 'gpt-5.4');
      expect(requestJson['stream'], isTrue);
      expect(requestJson['messages'], [
        {'role': 'system', 'content': '你是写作助手'},
        {'role': 'user', 'content': '请给我一句建议'},
      ]);
    });

    test(
      'joins text segments from structured content without auth header',
    () async {
      late final String? authorization;
      late final Map<String, Object?> requestJson;
      final server = await _startServer((request) async {
          authorization = request.headers.value(
            HttpHeaders.authorizationHeader,
          );
          requestJson =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, Object?>;
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': [
                        {'type': 'text', 'text': 'first part'},
                        {'type': 'image', 'text': '忽略图片'},
                        {'type': 'text', 'text': 'second part'},
                      ],
                    },
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
            apiKey: '   ',
            model: 'gpt-5.4-mini',
            timeout: AppLlmTimeoutConfig.uniform(1000),
            messages: const [
              AppLlmChatMessage(role: 'user', content: '拼接返回文本'),
            ],
          ),
        );

        expect(result.succeeded, isTrue);
        expect(result.text, 'first part\nsecond part');
        expect(authorization, isNull);
        expect(requestJson['stream'], isTrue);
      },
    );

    test('supports response string payloads', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'response': '直接返回正文'}));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server, withTrailingSlash: true),
          apiKey: 'sk-response',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(1000),
          messages: const [
            AppLlmChatMessage(role: 'user', content: '走 response 分支'),
          ],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, '直接返回正文');
    });

    test('parses usage tokens from non-streaming json response', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': 'hello tokens',
                  },
                },
              ],
              'usage': {
                'prompt_tokens': 42,
                'completion_tokens': 18,
                'total_tokens': 60,
              },
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
          timeoutMs: 1000,
          messages: const [
            AppLlmChatMessage(role: 'user', content: 'token test'),
          ],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'hello tokens');
      expect(result.promptTokens, 42);
      expect(result.completionTokens, 18);
      expect(result.totalTokens, 60);
    });

    test('parses usage tokens from streamed sse response', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"first part"},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":" second part"},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{},"finish_reason":"stop","index":0}],'
          '"usage":{"prompt_tokens":100,"completion_tokens":25,"total_tokens":125}}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeoutMs: 1000,
          messages: const [
            AppLlmChatMessage(role: 'user', content: 'streamed token test'),
          ],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'first part second part');
      expect(result.promptTokens, 100);
      expect(result.completionTokens, 25);
      expect(result.totalTokens, 125);
    });

    test(
      'maps unauthorized and model-not-found responses to dedicated failures',
      () async {
        final unauthorizedServer = await _startServer((request) async {
          await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'error': {'message': 'API Key 无效'},
              }),
            );
          await request.response.close();
        });
        addTearDown(() => unauthorizedServer.close(force: true));

        final unauthorized = await createDefaultAppLlmClient().chat(
          AppLlmChatRequest(
            baseUrl: _baseUrl(unauthorizedServer),
            apiKey: 'sk-bad',
            model: 'gpt-5.4',
            timeout: AppLlmTimeoutConfig.uniform(1000),
            messages: const [AppLlmChatMessage(role: 'user', content: '鉴权失败')],
          ),
        );

        expect(unauthorized.succeeded, isFalse);
        expect(unauthorized.failureKind, AppLlmFailureKind.unauthorized);
        expect(unauthorized.statusCode, HttpStatus.unauthorized);
        expect(unauthorized.detail, 'API Key 无效');

        final missingModelServer = await _startServer((request) async {
          await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = HttpStatus.notFound
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'message': '模型不存在'}));
          await request.response.close();
        });
        addTearDown(() => missingModelServer.close(force: true));

        final missingModel = await createDefaultAppLlmClient().chat(
          AppLlmChatRequest(
            baseUrl: _baseUrl(missingModelServer),
            apiKey: 'sk-ok',
            model: 'missing-model',
            timeout: AppLlmTimeoutConfig.uniform(1000),
            messages: const [AppLlmChatMessage(role: 'user', content: '模型不存在')],
          ),
        );

        expect(missingModel.succeeded, isFalse);
        expect(missingModel.failureKind, AppLlmFailureKind.modelNotFound);
        expect(missingModel.statusCode, HttpStatus.notFound);
        expect(missingModel.detail, '模型不存在');
      },
    );

    test(
      'treats malformed and empty success payloads as invalid responses',
      () async {
        final malformedServer = await _startServer((request) async {
          await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write('{bad json');
          await request.response.close();
        });
        addTearDown(() => malformedServer.close(force: true));

        final malformed = await createDefaultAppLlmClient().chat(
          AppLlmChatRequest(
            baseUrl: _baseUrl(malformedServer),
            apiKey: 'sk-ok',
            model: 'gpt-5.4',
            timeout: AppLlmTimeoutConfig.uniform(1000),
            messages: const [
              AppLlmChatMessage(role: 'user', content: '坏 json'),
            ],
          ),
        );

        expect(malformed.succeeded, isFalse);
        expect(malformed.failureKind, AppLlmFailureKind.invalidResponse);
        expect(malformed.detail, isNotNull);

        final emptyBodyServer = await _startServer((request) async {
          await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': '   '},
                  },
                ],
              }),
            );
          await request.response.close();
        });
        addTearDown(() => emptyBodyServer.close(force: true));

        final emptyBody = await createDefaultAppLlmClient().chat(
          AppLlmChatRequest(
            baseUrl: _baseUrl(emptyBodyServer),
            apiKey: 'sk-ok',
            model: 'gpt-5.4',
            timeout: AppLlmTimeoutConfig.uniform(1000),
            messages: const [AppLlmChatMessage(role: 'user', content: '空响应')],
          ),
        );

        expect(emptyBody.succeeded, isFalse);
        expect(emptyBody.failureKind, AppLlmFailureKind.invalidResponse);
        expect(emptyBody.detail, '模型返回成功，但响应体里没有可用文本。');
      },
    );

    test('reads streamed assistant text in a single streamed request', () async {
      late final Map<String, Object?> requestPayload;
      final server = await _startServer((request) async {
        requestPayload =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"","role":"assistant"},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"pong"},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{},"finish_reason":"stop","index":0}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4-mini',
          timeout: AppLlmTimeoutConfig.uniform(1000),
          messages: const [
            AppLlmChatMessage(role: 'user', content: '请只回复 pong'),
          ],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'pong');
      expect(requestPayload['stream'], isTrue);
    });

    test(
      'returns timeout and invalid-url network failures without mocks',
      () async {
        final slowServer = await _startServer((request) async {
          await utf8.decoder.bind(request).join();
          await Future<void>.delayed(const Duration(milliseconds: 200));
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': '太慢了'},
                  },
                ],
              }),
            );
          await request.response.close();
        });
        addTearDown(() => slowServer.close(force: true));

        final timeout = await createDefaultAppLlmClient().chat(
          AppLlmChatRequest(
            baseUrl: _baseUrl(slowServer),
            apiKey: 'sk-ok',
            model: 'gpt-5.4',
            timeout: AppLlmTimeoutConfig.uniform(20),
            messages: const [AppLlmChatMessage(role: 'user', content: '超时')],
          ),
        );

        expect(timeout.succeeded, isFalse);
        expect(timeout.failureKind, AppLlmFailureKind.timeout);
        expect(timeout.detail, '请求在超时时间内未完成。');

        final invalidUrl = await createDefaultAppLlmClient().chat(
          const AppLlmChatRequest(
            baseUrl: '   ',
            apiKey: 'sk-ok',
            model: 'gpt-5.4',
            timeout: AppLlmTimeoutConfig.uniform(1000),
            messages: [AppLlmChatMessage(role: 'user', content: '坏地址')],
          ),
        );

        expect(invalidUrl.succeeded, isFalse);
        expect(invalidUrl.failureKind, AppLlmFailureKind.network);
        expect(invalidUrl.detail, 'base_url 无法解析为有效地址。');
      },
    );

    test('maps 429 rate-limited responses to rateLimited failures', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.tooManyRequests
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': {'message': 'You are sending requests too quickly.'},
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
          timeoutMs: 1000,
          messages: const [AppLlmChatMessage(role: 'user', content: '触发限速')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.rateLimited);
      expect(result.statusCode, HttpStatus.tooManyRequests);
      expect(result.detail, 'You are sending requests too quickly.');
    });

    test('maps plain-text 500 responses to server failures', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('plain upstream failure');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(1000),
          messages: const [AppLlmChatMessage(role: 'user', content: '服务端错误')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(result.statusCode, HttpStatus.internalServerError);
      expect(result.detail, 'plain upstream failure');
    });

    test('maps closed-port requests to socket network failures', () async {
      final reserved = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = reserved.port;
      await reserved.close();

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: 'http://127.0.0.1:$port/v1',
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(1000),
          messages: const [AppLlmChatMessage(role: 'user', content: '关闭端口')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.network);
      expect(result.detail, isNotNull);
    });

    test('maps unsupported uri schemes to generic server failures', () async {
      final result = await createDefaultAppLlmClient().chat(
        const AppLlmChatRequest(
          baseUrl: 'file:///tmp',
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(1000),
          messages: [AppLlmChatMessage(role: 'user', content: '非 http scheme')],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.network);
      expect(result.detail, isNotNull);
    });

    test('skips malformed SSE lines and extracts good ones', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"Hello"},"index":0}]}\n\n',
        );
        // Malformed JSON line
        request.response.write('data: {bad json\n\n');
        // Valid line after bad one
        request.response.write(
          'data: {"choices":[{"delta":{"content":" World"},"index":0}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeoutMs: 1000,
          messages: const [
            AppLlmChatMessage(role: 'user', content: '容错测试'),
          ],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'Hello World');
    });

    test('ignores SSE comments and non-data fields', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(': this is a comment\n');
        request.response.write('event: message\n');
        request.response.write('id: 42\n');
        request.response.write('retry: 5000\n');
        request.response.write(
          'data: {"choices":[{"delta":{"content":"ok"},"index":0}]}\n\n',
        );
        request.response.write(': another comment\n');
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeoutMs: 1000,
          messages: const [
            AppLlmChatMessage(role: 'user', content: '注释测试'),
          ],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'ok');
    });

    test('handles structured content in SSE delta', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":[{"type":"text","text":"Part1"},{"type":"text","text":"Part2"}]},"index":0}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeoutMs: 1000,
          messages: const [
            AppLlmChatMessage(role: 'user', content: '结构化内容'),
          ],
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'Part1\nPart2');
    });

    test('returns invalid response when all SSE lines are malformed', () async {
      final server = await _startServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write('data: not-json-at-all\n\n');
        request.response.write('data: also{broken\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeoutMs: 1000,
          messages: const [
            AppLlmChatMessage(role: 'user', content: '全部坏数据'),
          ],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.invalidResponse);
    });

    test('maps malformed http responses to network failures', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close();
      });
      unawaited(() async {
        final socket = await server.first;
        socket.listen((_) {});
        socket.write(
          'HTTP/1.1 200 OK\r\n'
          'Content-Length: 20\r\n'
          'Content-Type: application/json\r\n'
          '\r\n'
          '{"broken":true',
        );
        await socket.flush();
        await socket.close();
      }());

      final result = await createDefaultAppLlmClient().chat(
        AppLlmChatRequest(
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(1000),
          messages: const [
            AppLlmChatMessage(role: 'user', content: '坏 http 响应'),
          ],
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(result.detail, isNotNull);
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

String _baseUrl(
  HttpServer server, {
  String suffix = '',
  bool withTrailingSlash = false,
}) {
  final trailingSlash = withTrailingSlash ? '/' : '';
  return 'http://${server.address.host}:${server.port}$suffix$trailingSlash';
}
