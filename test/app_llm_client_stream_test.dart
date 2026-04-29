import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';

void main() {
  group('chatStream', () {
    test('yields incremental text deltas from SSE stream', () async {
      final server = await _startStreamServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"Hel"},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"lo "},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"Wor"},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"ld"},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{},"finish_reason":"stop","index":0}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final client = createDefaultAppLlmClient();
      final deltas = await client
          .chatStream(
            AppLlmChatRequest(
              baseUrl: _baseUrl(server),
              apiKey: 'sk-test',
              model: 'gpt-5.4',
              timeout: AppLlmTimeoutConfig.uniform(2000),
              messages: const [
                AppLlmChatMessage(role: 'user', content: 'stream test'),
              ],
            ),
          )
          .toList();

      expect(deltas, ['Hel', 'lo ', 'Wor', 'ld']);
    });

    test('skips empty delta content and role-only deltas', () async {
      final server = await _startStreamServer((request) async {
        await utf8.decoder.bind(request).join();
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

      final deltas = await createDefaultAppLlmClient()
          .chatStream(
            AppLlmChatRequest(
              baseUrl: _baseUrl(server),
              apiKey: 'sk-test',
              model: 'gpt-5.4',
              timeout: AppLlmTimeoutConfig.uniform(2000),
              messages: const [
                AppLlmChatMessage(role: 'user', content: 'skip empty'),
              ],
            ),
          )
          .toList();

      expect(deltas, ['pong']);
    });

    test('skips reasoning-only deltas instead of exposing them', () async {
      final server = await _startStreamServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning":"internal plan","reasoning_content":"hidden chain","reason":"hidden reason"},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"visible"},"index":0}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{},"finish_reason":"stop","index":0}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final deltas = await createDefaultAppLlmClient()
          .chatStream(
            AppLlmChatRequest(
              baseUrl: _baseUrl(server),
              apiKey: 'sk-test',
              model: 'gpt-5.4',
              timeout: AppLlmTimeoutConfig.uniform(2000),
              messages: const [
                AppLlmChatMessage(role: 'user', content: 'skip reasoning'),
              ],
            ),
          )
          .toList();

      expect(deltas, ['visible']);
    });

    test('handles single-chunk response', () async {
      final server = await _startStreamServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"instant"},"index":0}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final deltas = await createDefaultAppLlmClient()
          .chatStream(
            AppLlmChatRequest(
              baseUrl: _baseUrl(server),
              apiKey: 'sk-test',
              model: 'gpt-5.4',
              timeout: AppLlmTimeoutConfig.uniform(2000),
              messages: const [
                AppLlmChatMessage(role: 'user', content: 'single'),
              ],
            ),
          )
          .toList();

      expect(deltas, ['instant']);
    });

    test('throws AppLlmStreamException for 401 unauthorized', () async {
      final server = await _startStreamServer((request) async {
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
      addTearDown(() => server.close(force: true));

      final stream = createDefaultAppLlmClient().chatStream(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-bad',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [
            AppLlmChatMessage(role: 'user', content: 'auth fail'),
          ],
        ),
      );

      expect(
        stream.toList(),
        throwsA(
          isA<AppLlmStreamException>().having(
            (e) => e.failureKind,
            'failureKind',
            AppLlmFailureKind.unauthorized,
          ),
        ),
      );
    });

    test('throws AppLlmStreamException for 404 model not found', () async {
      final server = await _startStreamServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'message': '模型不存在'}));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final stream = createDefaultAppLlmClient().chatStream(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'missing-model',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [
            AppLlmChatMessage(role: 'user', content: 'model missing'),
          ],
        ),
      );

      expect(
        stream.toList(),
        throwsA(
          isA<AppLlmStreamException>().having(
            (e) => e.failureKind,
            'failureKind',
            AppLlmFailureKind.modelNotFound,
          ),
        ),
      );
    });

    test('throws AppLlmStreamException for 500 server error', () async {
      final server = await _startStreamServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('upstream failure');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final stream = createDefaultAppLlmClient().chatStream(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(2000),
          messages: const [
            AppLlmChatMessage(role: 'user', content: 'server error'),
          ],
        ),
      );

      expect(
        stream.toList(),
        throwsA(
          isA<AppLlmStreamException>().having(
            (e) => e.failureKind,
            'failureKind',
            AppLlmFailureKind.server,
          ),
        ),
      );
    });

    test('throws AppLlmStreamException for invalid base URL', () async {
      final stream = createDefaultAppLlmClient().chatStream(
        const AppLlmChatRequest(
          baseUrl: '   ',
          apiKey: 'sk-ok',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(1000),
          messages: [AppLlmChatMessage(role: 'user', content: 'bad url')],
        ),
      );

      expect(
        stream.toList(),
        throwsA(
          isA<AppLlmStreamException>().having(
            (e) => e.failureKind,
            'failureKind',
            AppLlmFailureKind.network,
          ),
        ),
      );
    });

    test('sends stream=true in request body', () async {
      late final Map<String, Object?> requestPayload;
      final server = await _startStreamServer((request) async {
        requestPayload =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"ok"},"index":0}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await createDefaultAppLlmClient()
          .chatStream(
            AppLlmChatRequest(
              baseUrl: _baseUrl(server),
              apiKey: 'sk-test',
              model: 'gpt-5.4',
              timeout: AppLlmTimeoutConfig.uniform(2000),
              messages: const [
                AppLlmChatMessage(role: 'user', content: 'check stream flag'),
              ],
            ),
          )
          .toList();

      expect(requestPayload['stream'], isTrue);
      expect(requestPayload['model'], 'gpt-5.4');
    });

    test('produces empty stream for SSE with no text deltas', () async {
      final server = await _startStreamServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{},"finish_reason":"stop","index":0}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final deltas = await createDefaultAppLlmClient()
          .chatStream(
            AppLlmChatRequest(
              baseUrl: _baseUrl(server),
              apiKey: 'sk-test',
              model: 'gpt-5.4',
              timeout: AppLlmTimeoutConfig.uniform(2000),
              messages: const [
                AppLlmChatMessage(role: 'user', content: 'no text'),
              ],
            ),
          )
          .toList();

      expect(deltas, isEmpty);
    });

    test(
      'throws on idle timeout when server stalls between SSE chunks',
      () async {
        final server = await _startStreamServer((request) async {
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"first"},"index":0}]}\n\n',
          );
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          request.response.write(
            'data: {"choices":[{"delta":{"content":"late"},"index":0}]}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        final stream = createDefaultAppLlmClient().chatStream(
          AppLlmChatRequest(
            baseUrl: _baseUrl(server),
            apiKey: 'sk-test',
            model: 'gpt-5.4',
            timeout: const AppLlmTimeoutConfig(
              connectTimeoutMs: 2000,
              sendTimeoutMs: 2000,
              receiveTimeoutMs: 5000,
              idleTimeoutMs: 50,
            ),
            messages: const [
              AppLlmChatMessage(role: 'user', content: 'idle timeout test'),
            ],
          ),
        );

        expect(
          stream.toList(),
          throwsA(
            isA<AppLlmStreamException>().having(
              (e) => e.failureKind,
              'failureKind',
              AppLlmFailureKind.timeout,
            ),
          ),
        );
      },
    );

    test('yields deltas progressively as SSE chunks arrive', () async {
      final chunkDelays = <int>[];
      final server = await _startStreamServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );

        for (final word in ['first', ' second', ' third']) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          request.response.write(
            'data: {"choices":[{"delta":{"content":"$word"},"index":0}]}\n\n',
          );
          await request.response.flush();
          chunkDelays.add(DateTime.now().millisecondsSinceEpoch);
        }

        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final receiveTimes = <int>[];
      await for (final _ in createDefaultAppLlmClient().chatStream(
        AppLlmChatRequest(
          baseUrl: _baseUrl(server),
          apiKey: 'sk-test',
          model: 'gpt-5.4',
          timeout: AppLlmTimeoutConfig.uniform(5000),
          messages: const [
            AppLlmChatMessage(role: 'user', content: 'progressive'),
          ],
        ),
      )) {
        receiveTimes.add(DateTime.now().millisecondsSinceEpoch);
      }

      expect(receiveTimes.length, 3);
    });
  });
}

Future<HttpServer> _startStreamServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(server.forEach(handler));
  return server;
}

String _baseUrl(HttpServer server) {
  return 'http://${server.address.host}:${server.port}/v1';
}
