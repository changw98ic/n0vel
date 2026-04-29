import 'dart:convert';

import 'app_llm_client_types.dart';

abstract class AppLlmProviderAdapter {
  String get endpointPath;

  Map<String, Object?> buildHeaders(String apiKey);

  Map<String, Object?> buildBody({
    required String model,
    required List<AppLlmChatMessage> messages,
    bool stream = true,
  });

  String? decodeOutputText(String body);
}

class OpenAiCompatibleAdapter implements AppLlmProviderAdapter {
  @override
  String get endpointPath => 'chat/completions';

  @override
  Map<String, Object?> buildHeaders(String apiKey) {
    final trimmed = apiKey.trim();
    return {
      'Content-Type': 'application/json',
      if (trimmed.isNotEmpty) 'Authorization': 'Bearer $trimmed',
    };
  }

  @override
  Map<String, Object?> buildBody({
    required String model,
    required List<AppLlmChatMessage> messages,
    bool stream = true,
  }) {
    return <String, Object?>{
      'model': model,
      'messages': [for (final message in messages) message.toJson()],
      'max_tokens': 65536,
      'stream': stream,
    };
  }

  @override
  String? decodeOutputText(String body) {
    try {
      return _decodeStreamedOutputText(body) ?? _decodeOutputText(body);
    } on FormatException {
      return null;
    }
  }

  static String? _decodeOutputText(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return null;
    }

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices.first;
      if (firstChoice is Map) {
        final message = firstChoice['message'];
        if (message is Map) {
          final normalized = _normalizeContent(message['content']);
          if (normalized != null && normalized.isNotEmpty) {
            return normalized;
          }
        }
      }
    }

    final response = decoded['response'];
    if (response is String && response.trim().isNotEmpty) {
      return response;
    }

    return null;
  }

  static String? _normalizeContent(Object? content) {
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

  static String? _decodeStreamedOutputText(String body) {
    final buffer = StringBuffer();
    for (final rawLine in const LineSplitter().convert(body)) {
      final line = rawLine.trim();
      if (!line.startsWith('data:')) {
        continue;
      }
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') {
        continue;
      }

      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        continue;
      }
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        continue;
      }
      final firstChoice = choices.first;
      if (firstChoice is! Map) {
        continue;
      }
      final delta = firstChoice['delta'];
      if (delta is! Map) {
        continue;
      }
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        buffer.write(content);
      }
    }
    final normalized = buffer.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class KimiAdapter extends OpenAiCompatibleAdapter {}

class OllamaAdapter extends OpenAiCompatibleAdapter {}

class AnthropicAdapter implements AppLlmProviderAdapter {
  @override
  String get endpointPath => 'v1/messages';

  @override
  Map<String, Object?> buildHeaders(String apiKey) {
    final trimmed = apiKey.trim();
    return {
      'Content-Type': 'application/json',
      if (trimmed.isNotEmpty) 'x-api-key': trimmed,
      'anthropic-version': '2023-06-01',
    };
  }

  @override
  Map<String, Object?> buildBody({
    required String model,
    required List<AppLlmChatMessage> messages,
    bool stream = true,
  }) {
    final filteredMessages = <Map<String, Object?>>[];
    String? systemContent;
    for (final message in messages) {
      if (message.role == 'system') {
        systemContent = message.content;
      } else {
        filteredMessages.add(message.toJson());
      }
    }
    final body = <String, Object?>{
      'model': model,
      'messages': filteredMessages,
      'max_tokens': 4096,
      'stream': stream,
    };
    if (systemContent != null && systemContent.isNotEmpty) {
      body['system'] = systemContent;
    }
    return body;
  }

  @override
  String? decodeOutputText(String body) {
    final buffer = StringBuffer();
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
        if (type != 'content_block_delta') {
          continue;
        }
        final delta = decoded['delta'];
        if (delta is! Map) {
          continue;
        }
        final text = delta['text'];
        if (text is String && text.isNotEmpty) {
          buffer.write(text);
        }
      } on FormatException {
        continue;
      }
    }
    final normalized = buffer.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}

/// Strips chain-of-thought thinking from [text] that may contain both model
/// reasoning and actual structured output (e.g. from kimi-k2.6's reasoning field).
///
/// Heuristic:
/// 1. Find the first markdown header (`#`) — strong signal of structured content.
/// 2. If no header, strip leading paragraphs that match thinking patterns.
/// 3. If neither matches, return the original text.
String stripThinkingChain(String text) {
  if (text.isEmpty) return text;

  // Strategy 1: first markdown header marks the start of real content.
  final lines = text.split('\n');
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('#')) {
      return lines.sublist(i).join('\n').trim();
    }
  }

  // Strategy 2: strip leading thinking-style paragraphs.
  // Thinking lines typically start with meta-commentary in first person.
  final thinkingPattern = RegExp(
    r'^(好的[，,。.]?|让我[们来]?|我来|首先[，,]|接下来[，,]|'
    r'根据[上下以这]|基于[以这]|分析[一下]|思考[一下]|'
    r'用户[的需要]|你需要|我需要|我认为|我觉得|我打算|我应该|'
    r'我将要|现在[，,]|那么[，,]?|嗯[，,。.]?|明白[，,。.]?|'
    r'理解[，,。.]?|开始[，,吧])',
  );

  final paragraphs = text.split(RegExp(r'\n\s*\n'));
  int startParagraph = 0;
  for (int i = 0; i < paragraphs.length; i++) {
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

abstract final class AppLlmProviderAdapters {
  static AppLlmProviderAdapter of(AppLlmProvider provider) {
    return switch (provider) {
      AppLlmProvider.anthropic => AnthropicAdapter(),
      AppLlmProvider.kimi => KimiAdapter(),
      AppLlmProvider.ollama => OllamaAdapter(),
      AppLlmProvider.openaiCompatible => OpenAiCompatibleAdapter(),
    };
  }
}
