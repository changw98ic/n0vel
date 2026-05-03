import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';

void main() {
  group('AppLlmProviderAdapters', () {
    test('of returns correct adapter for each provider', () {
      expect(
        AppLlmProviderAdapters.of(AppLlmProvider.openaiCompatible),
        isA<OpenAiCompatibleAdapter>(),
      );
      expect(
        AppLlmProviderAdapters.of(AppLlmProvider.kimi),
        isA<KimiAdapter>(),
      );
      expect(
        AppLlmProviderAdapters.of(AppLlmProvider.ollama),
        isA<OllamaAdapter>(),
      );
      expect(
        AppLlmProviderAdapters.of(AppLlmProvider.anthropic),
        isA<AnthropicAdapter>(),
      );
      expect(
        AppLlmProviderAdapters.of(AppLlmProvider.mimo),
        isA<MimoAdapter>(),
      );
      expect(
        AppLlmProviderAdapters.of(AppLlmProvider.zhipu),
        isA<ZhipuAdapter>(),
      );
    });
  });

  group('OpenAiCompatibleAdapter', () {
    final adapter = OpenAiCompatibleAdapter();

    test('endpointPath is chat/completions', () {
      expect(adapter.endpointPath, 'chat/completions');
    });

    test('buildHeaders includes Bearer token when apiKey is present', () {
      final headers = adapter.buildHeaders('sk-test');
      expect(headers['Content-Type'], 'application/json');
      expect(headers['Authorization'], 'Bearer sk-test');
    });

    test('buildHeaders omits auth when apiKey is empty', () {
      final headers = adapter.buildHeaders('  ');
      expect(headers['Content-Type'], 'application/json');
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('buildBody includes model, messages, and stream flag', () {
      final body = adapter.buildBody(
        model: 'gpt-5.4',
        messages: const [
          AppLlmChatMessage(role: 'system', content: 'sys'),
          AppLlmChatMessage(role: 'user', content: 'hello'),
        ],
        stream: true,
      );
      expect(body['model'], 'gpt-5.4');
      expect(body['stream'], isTrue);
      expect(body['messages'], [
        {'role': 'system', 'content': 'sys'},
        {'role': 'user', 'content': 'hello'},
      ]);
    });

    test('buildBody omits max_tokens when token limit is unlimited', () {
      final body = adapter.buildBody(
        model: 'gpt-5.4',
        messages: const [AppLlmChatMessage(role: 'user', content: 'hello')],
        maxTokens: AppLlmChatRequest.unlimitedMaxTokens,
      );

      expect(body.containsKey('max_tokens'), isFalse);
      expect(body.containsKey('max_completion_tokens'), isFalse);
    });

    test('decodeOutputText extracts text from streamed SSE payload', () {
      const sse =
          'data: {"choices":[{"delta":{"content":" hello "},"index":0}]}\n\n'
          'data: {"choices":[{"delta":{"content":"world"},"index":0}]}\n\n'
          'data: [DONE]\n\n';
      expect(adapter.decodeOutputText(sse), 'hello world');
    });

    test('decodeOutputText ignores streamed reasoning-only deltas', () {
      const sse =
          'data: {"choices":[{"delta":{"reasoning":"internal plan","reasoning_content":"hidden chain","reason":"hidden reason"},"index":0}]}\n\n'
          'data: {"choices":[{"delta":{"content":" visible "},"index":0}]}\n\n'
          'data: [DONE]\n\n';
      expect(adapter.decodeOutputText(sse), 'visible');
    });

    test('decodeOutputText extracts text from non-streamed JSON payload', () {
      final json = jsonEncode({
        'choices': [
          {
            'message': {'content': 'direct reply'},
          },
        ],
      });
      expect(adapter.decodeOutputText(json), 'direct reply');
    });

    test('decodeOutputText handles structured content array', () {
      final json = jsonEncode({
        'choices': [
          {
            'message': {
              'content': [
                {'type': 'text', 'text': '第一段'},
                {'type': 'image', 'text': '忽略'},
                {'type': 'text', 'text': '第二段'},
              ],
            },
          },
        ],
      });
      expect(adapter.decodeOutputText(json), '第一段\n第二段');
    });

    test('decodeOutputText does not treat message reasoning as output', () {
      final json = jsonEncode({
        'choices': [
          {
            'message': {
              'reasoning': 'internal plan',
              'reasoning_content': 'hidden chain',
              'reason': 'hidden reason',
            },
          },
        ],
      });
      expect(adapter.decodeOutputText(json), isNull);
    });

    test('decodeOutputText handles response string fallback', () {
      final json = jsonEncode({'response': 'fallback text'});
      expect(adapter.decodeOutputText(json), 'fallback text');
    });

    test('decodeOutputText returns whitespace content without trimming', () {
      final json = jsonEncode({
        'choices': [
          {
            'message': {'content': '   '},
          },
        ],
      });
      expect(adapter.decodeOutputText(json), '   ');
    });

    test('decodeOutputText returns null for malformed JSON', () {
      expect(adapter.decodeOutputText('{bad'), isNull);
    });
  });

  group('KimiAdapter', () {
    final adapter = KimiAdapter();

    test('inherits OpenAiCompatible behavior', () {
      expect(adapter.endpointPath, 'chat/completions');
      final headers = adapter.buildHeaders('sk-kimi');
      expect(headers['Authorization'], 'Bearer sk-kimi');
    });
  });

  group('OllamaAdapter', () {
    final adapter = OllamaAdapter();

    test('inherits OpenAiCompatible behavior', () {
      expect(adapter.endpointPath, 'chat/completions');
      final headers = adapter.buildHeaders('sk-ollama');
      expect(headers['Authorization'], 'Bearer sk-ollama');
    });
  });

  group('AnthropicAdapter', () {
    final adapter = AnthropicAdapter();

    test('endpointPath is v1/messages', () {
      expect(adapter.endpointPath, 'v1/messages');
    });

    test('buildHeaders uses x-api-key and anthropic-version', () {
      final headers = adapter.buildHeaders('sk-ant');
      expect(headers['Content-Type'], 'application/json');
      expect(headers['x-api-key'], 'sk-ant');
      expect(headers['anthropic-version'], '2023-06-01');
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('buildHeaders omits x-api-key when empty', () {
      final headers = adapter.buildHeaders('  ');
      expect(headers.containsKey('x-api-key'), isFalse);
    });

    test('buildBody separates system message into top-level field', () {
      final body = adapter.buildBody(
        model: 'claude-3',
        messages: const [
          AppLlmChatMessage(role: 'system', content: 'sys prompt'),
          AppLlmChatMessage(role: 'user', content: 'hello'),
        ],
        stream: true,
      );
      expect(body['model'], 'claude-3');
      expect(body['stream'], isTrue);
      expect(body.containsKey('max_tokens'), isFalse);
      expect(body['system'], 'sys prompt');
      expect(body['messages'], [
        {'role': 'user', 'content': 'hello'},
      ]);
    });

    test('buildBody includes positive max_tokens', () {
      final body = adapter.buildBody(
        model: 'claude-3',
        messages: const [AppLlmChatMessage(role: 'user', content: 'hello')],
        maxTokens: 8192,
      );

      expect(body['max_tokens'], 8192);
    });

    test('buildBody omits system field when no system message', () {
      final body = adapter.buildBody(
        model: 'claude-3',
        messages: const [AppLlmChatMessage(role: 'user', content: 'hello')],
      );
      expect(body.containsKey('system'), isFalse);
    });

    test('decodeOutputText extracts text from anthropic SSE format', () {
      const sse =
          'data: {"type":"content_block_delta","delta":{"text":" hello "}}\n\n'
          'data: {"type":"content_block_delta","delta":{"text":"world"}}\n\n'
          'data: [DONE]\n\n';
      expect(adapter.decodeOutputText(sse), 'hello world');
    });

    test('decodeOutputText ignores non-content_block_delta events', () {
      const sse =
          'data: {"type":"message_start"}\n\n'
          'data: {"type":"content_block_delta","delta":{"text":"only this"}}\n\n'
          'data: {"type":"message_stop"}\n\n';
      expect(adapter.decodeOutputText(sse), 'only this');
    });

    test('decodeOutputText returns null for empty text', () {
      const sse =
          'data: {"type":"content_block_delta","delta":{"text":""}}\n\n';
      expect(adapter.decodeOutputText(sse), isNull);
    });
  });

  group('MimoAdapter', () {
    final adapter = MimoAdapter();

    test('uses Xiaomi MiMo auth header and max_completion_tokens', () {
      final headers = adapter.buildHeaders('tp-test');
      expect(headers['Content-Type'], 'application/json');
      expect(headers['api-key'], 'tp-test');
      expect(headers.containsKey('Authorization'), isFalse);

      final body = adapter.buildBody(
        model: 'mimo-v2.5-pro',
        messages: const [AppLlmChatMessage(role: 'user', content: 'hello')],
        maxTokens: 8192,
      );
      expect(body['max_completion_tokens'], 8192);
      expect(body.containsKey('max_tokens'), isFalse);
    });

    test('omits MiMo max_completion_tokens when token limit is unlimited', () {
      final body = adapter.buildBody(
        model: 'mimo-v2.5-pro',
        messages: const [AppLlmChatMessage(role: 'user', content: 'hello')],
        maxTokens: AppLlmChatRequest.unlimitedMaxTokens,
      );

      expect(body.containsKey('max_completion_tokens'), isFalse);
      expect(body.containsKey('max_tokens'), isFalse);
    });
  });

  group('ZhipuAdapter', () {
    final adapter = ZhipuAdapter();

    test('uses BigModel bearer auth and max_tokens', () {
      expect(adapter.endpointPath, 'chat/completions');

      final headers = adapter.buildHeaders('zhipu-key');
      expect(headers['Content-Type'], 'application/json');
      expect(headers['Authorization'], 'Bearer zhipu-key');
      expect(headers.containsKey('api-key'), isFalse);

      final body = adapter.buildBody(
        model: 'glm-5.1',
        messages: const [AppLlmChatMessage(role: 'user', content: 'hello')],
        maxTokens: 8192,
      );
      expect(body['model'], 'glm-5.1');
      expect(body['max_tokens'], 8192);
      expect(body.containsKey('max_completion_tokens'), isFalse);
    });

    test('omits BigModel max_tokens when token limit is unlimited', () {
      final body = adapter.buildBody(
        model: 'glm-5.1',
        messages: const [AppLlmChatMessage(role: 'user', content: 'hello')],
        maxTokens: AppLlmChatRequest.unlimitedMaxTokens,
      );

      expect(body.containsKey('max_tokens'), isFalse);
      expect(body.containsKey('max_completion_tokens'), isFalse);
    });
  });
}
