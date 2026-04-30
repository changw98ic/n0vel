import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_response_decoding.dart';

void main() {
  test('shared OpenAI decoder normalizes structured text and token usage', () {
    final body = jsonEncode({
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
      'usage': {
        'prompt_tokens': '9',
        'completion_tokens': 3,
        'total_tokens': 12.0,
      },
    });

    final decoded = decodeOpenAiChatResponseBody(body);

    expect(decoded?.text, '第一段\n第二段');
    expect(decoded?.promptTokens, 9);
    expect(decoded?.completionTokens, 3);
    expect(decoded?.totalTokens, 12);
  });

  test('shared OpenAI stream decoder skips malformed SSE chunks', () {
    const body =
        'data: {"choices":[{"delta":{"content":"hello"},"index":0}]}\n\n'
        'data: {bad\n\n'
        'data: {"choices":[{"delta":{"content":" world"},"index":0}],'
        '"usage":{"prompt_tokens":5,"completion_tokens":2,"total_tokens":7}}\n\n'
        'data: [DONE]\n\n';

    final decoded = decodeOpenAiChatStreamBody(body);

    expect(decoded?.text, 'hello world');
    expect(decoded?.promptTokens, 5);
    expect(decoded?.completionTokens, 2);
    expect(decoded?.totalTokens, 7);
  });
}
