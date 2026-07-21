import 'dart:convert';

class AppLlmDecodedResponse {
  const AppLlmDecodedResponse({
    required this.text,
    this.providerModel,
    this.providerResponseId,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final String text;
  final String? providerModel;
  final String? providerResponseId;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
}

String? normalizeLlmContent(Object? content) {
  if (content is String) {
    return content;
  }
  if (content is List) {
    final buffer = StringBuffer();
    for (final item in content) {
      if (item is Map && item['type']?.toString() == 'text') {
        final text = item['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) {
            buffer.write('\n');
          }
          buffer.write(text);
        }
      }
    }
    final normalized = buffer.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
  return null;
}

AppLlmDecodedResponse? decodeOpenAiChatResponseBody(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    return null;
  }

  String? text;
  final choices = decoded['choices'];
  if (choices is List && choices.isNotEmpty) {
    final firstChoice = choices.first;
    if (firstChoice is Map) {
      final message = firstChoice['message'];
      if (message is Map) {
        final normalized = normalizeLlmContent(message['content']);
        if (normalized != null && normalized.isNotEmpty) {
          text = normalized;
        }
      }
    }
  }

  final response = decoded['response'];
  if (response is String && response.trim().isNotEmpty) {
    text = response;
  }

  if (text == null) {
    return null;
  }

  final usage = decoded['usage'];
  return AppLlmDecodedResponse(
    text: text,
    providerModel: _nonEmptyString(decoded['model']),
    providerResponseId: _nonEmptyString(decoded['id']),
    promptTokens: _usageToken(usage, 'prompt_tokens'),
    completionTokens: _usageToken(usage, 'completion_tokens'),
    totalTokens: _usageToken(usage, 'total_tokens'),
  );
}

AppLlmDecodedResponse? decodeOpenAiChatStreamBody(
  String body, {
  bool stripThinking = true,
}) {
  final buffer = StringBuffer();
  int? promptTokens;
  int? completionTokens;
  int? totalTokens;
  String? providerModel;
  String? providerResponseId;

  for (final rawLine in const LineSplitter().convert(body)) {
    final line = rawLine.trim();
    if (!line.startsWith('data:')) {
      continue;
    }
    final payload = line.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') {
      continue;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        continue;
      }

      providerModel = _nonEmptyString(decoded['model']) ?? providerModel;
      providerResponseId = _nonEmptyString(decoded['id']) ?? providerResponseId;

      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final firstChoice = choices.first;
        if (firstChoice is Map) {
          final delta = firstChoice['delta'];
          if (delta is Map) {
            final content = normalizeLlmContent(delta['content']);
            if (content != null && content.isNotEmpty) {
              buffer.write(content);
            }
          }
        }
      }

      final usage = decoded['usage'];
      promptTokens = _usageToken(usage, 'prompt_tokens') ?? promptTokens;
      completionTokens =
          _usageToken(usage, 'completion_tokens') ?? completionTokens;
      totalTokens = _usageToken(usage, 'total_tokens') ?? totalTokens;
    } on FormatException {
      continue;
    }
  }

  final normalized = buffer.toString().trim();
  if (normalized.isEmpty) {
    return null;
  }

  final filtered = stripThinking ? stripThinkingChain(normalized) : normalized;
  return AppLlmDecodedResponse(
    text: filtered.isNotEmpty ? filtered : normalized,
    providerModel: providerModel,
    providerResponseId: providerResponseId,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    totalTokens: totalTokens,
  );
}

/// Decodes a non-streaming Anthropic Messages response.
///
/// Anthropic names the usage fields `input_tokens` and `output_tokens`, so
/// treating this body as OpenAI-compatible would lose the exact usage needed
/// by the canary budget gate.
AppLlmDecodedResponse? decodeAnthropicMessageResponseBody(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    return null;
  }
  final content = decoded['content'];
  if (content is! List) {
    return null;
  }
  final text = StringBuffer();
  for (final block in content) {
    if (block is Map &&
        block['type'] == 'text' &&
        block['text'] is String &&
        (block['text'] as String).isNotEmpty) {
      text.write(block['text'] as String);
    }
  }
  final normalized = text.toString().trim();
  if (normalized.isEmpty) {
    return null;
  }
  final usage = decoded['usage'];
  final promptTokens = _usageToken(usage, 'input_tokens');
  final completionTokens = _usageToken(usage, 'output_tokens');
  return AppLlmDecodedResponse(
    text: normalized,
    providerModel: _nonEmptyString(decoded['model']),
    providerResponseId: _nonEmptyString(decoded['id']),
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    totalTokens: _anthropicTotalTokens(
      usage,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    ),
  );
}

/// Decodes Anthropic Messages SSE events, including model and split usage.
AppLlmDecodedResponse? decodeAnthropicMessageStreamBody(String body) {
  final text = StringBuffer();
  String? providerModel;
  String? providerResponseId;
  int? promptTokens;
  int? completionTokens;

  for (final rawLine in const LineSplitter().convert(body)) {
    final line = rawLine.trim();
    if (!line.startsWith('data:')) {
      continue;
    }
    final payload = line.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') {
      continue;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        continue;
      }
      final type = decoded['type'];
      if (type == 'message_start') {
        final message = decoded['message'];
        if (message is Map) {
          providerModel = _nonEmptyString(message['model']) ?? providerModel;
          providerResponseId =
              _nonEmptyString(message['id']) ?? providerResponseId;
          final usage = message['usage'];
          promptTokens = _usageToken(usage, 'input_tokens') ?? promptTokens;
          completionTokens =
              _usageToken(usage, 'output_tokens') ?? completionTokens;
        }
      } else if (type == 'content_block_delta') {
        final delta = decoded['delta'];
        if (delta is Map && delta['text'] is String) {
          text.write(delta['text'] as String);
        }
      } else if (type == 'message_delta') {
        final usage = decoded['usage'];
        completionTokens =
            _usageToken(usage, 'output_tokens') ?? completionTokens;
      }
    } on FormatException {
      continue;
    }
  }

  final normalized = text.toString().trim();
  if (normalized.isEmpty) {
    return null;
  }
  return AppLlmDecodedResponse(
    text: normalized,
    providerModel: providerModel,
    providerResponseId: providerResponseId,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    totalTokens: _anthropicTotalTokens(
      null,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    ),
  );
}

String? _nonEmptyString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

/// Strips chain-of-thought thinking from [text] that may contain both model
/// reasoning and actual structured output.
String stripThinkingChain(String text) {
  if (text.isEmpty) return text;

  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('#')) {
      return lines.sublist(i).join('\n').trim();
    }
  }

  final thinkingPattern = RegExp(
    r'^(好的[，,。.]?|让我[们来]?|我来|首先[，,]|接下来[，,]|'
    r'根据[上下以这]|基于[以这]|分析[一下]|思考[一下]|'
    r'用户[的需要]|你需要|我需要|我认为|我觉得|我打算|我应该|'
    r'我将要|现在[，,]|那么[，,]?|嗯[，,。.]?|明白[，,。.]?|'
    r'理解[，,。.]?|开始[，,吧])',
  );

  final paragraphs = text.split(RegExp(r'\n\s*\n'));
  var startParagraph = 0;
  for (var i = 0; i < paragraphs.length; i++) {
    final firstLine = paragraphs[i].trim().split('\n').first.trim();
    if (firstLine.isEmpty) continue;
    if (!thinkingPattern.hasMatch(firstLine)) {
      startParagraph = i;
      break;
    }
    startParagraph = i + 1;
  }

  if (startParagraph > 0 && startParagraph < paragraphs.length) {
    return paragraphs.sublist(startParagraph).join('\n\n').trim();
  }

  return text;
}

int? _usageToken(Object? usage, String key) {
  if (usage is! Map) {
    return null;
  }
  return _toInt(usage[key]);
}

int? _anthropicTotalTokens(
  Object? usage, {
  required int? promptTokens,
  required int? completionTokens,
}) {
  final explicit = _usageToken(usage, 'total_tokens');
  if (explicit != null) {
    return explicit;
  }
  if (promptTokens == null || completionTokens == null) {
    return null;
  }
  return promptTokens + completionTokens;
}

int? _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
