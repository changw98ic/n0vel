import 'dart:convert';

import 'app_llm_client_types.dart';
import 'app_llm_response_decoding.dart';

abstract class AppLlmProviderAdapter {
  String get endpointPath;

  Map<String, Object?> buildHeaders(String apiKey);

  Map<String, Object?> buildBody({
    required String model,
    required List<AppLlmChatMessage> messages,
    bool stream = true,
    int maxTokens = AppLlmChatRequest.unlimitedMaxTokens,
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
    int maxTokens = AppLlmChatRequest.unlimitedMaxTokens,
  }) {
    final body = <String, Object?>{
      'model': model,
      'messages': [for (final message in messages) message.toJson()],
      'stream': stream,
    };
    if (!AppLlmChatRequest.shouldOmitMaxTokens(maxTokens)) {
      body['max_tokens'] = AppLlmChatRequest.normalizeMaxTokens(maxTokens);
    }
    return body;
  }

  @override
  String? decodeOutputText(String body) {
    try {
      return decodeOpenAiChatStreamBody(body, stripThinking: false)?.text ??
          decodeOpenAiChatResponseBody(body)?.text;
    } on FormatException {
      return null;
    }
  }
}

class KimiAdapter extends OpenAiCompatibleAdapter {}

class OllamaAdapter extends OpenAiCompatibleAdapter {}

class MimoAdapter extends OpenAiCompatibleAdapter {
  @override
  Map<String, Object?> buildHeaders(String apiKey) {
    final trimmed = apiKey.trim();
    return {
      'Content-Type': 'application/json',
      if (trimmed.isNotEmpty) 'api-key': trimmed,
    };
  }

  @override
  Map<String, Object?> buildBody({
    required String model,
    required List<AppLlmChatMessage> messages,
    bool stream = true,
    int maxTokens = AppLlmChatRequest.unlimitedMaxTokens,
  }) {
    final body = <String, Object?>{
      'model': model,
      'messages': [for (final message in messages) message.toJson()],
      'stream': stream,
    };
    if (!AppLlmChatRequest.shouldOmitMaxTokens(maxTokens)) {
      body['max_completion_tokens'] = AppLlmChatRequest.normalizeMaxTokens(
        maxTokens,
      );
    }
    return body;
  }
}

class ZhipuAdapter extends OpenAiCompatibleAdapter {}

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
    int maxTokens = AppLlmChatRequest.unlimitedMaxTokens,
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
      'stream': stream,
    };
    if (!AppLlmChatRequest.shouldOmitMaxTokens(maxTokens)) {
      body['max_tokens'] = AppLlmChatRequest.normalizeMaxTokens(maxTokens);
    }
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

abstract final class AppLlmProviderAdapters {
  static AppLlmProviderAdapter of(AppLlmProvider provider) {
    return switch (provider) {
      AppLlmProvider.anthropic => AnthropicAdapter(),
      AppLlmProvider.mimo => MimoAdapter(),
      AppLlmProvider.zhipu => ZhipuAdapter(),
      AppLlmProvider.kimi => KimiAdapter(),
      AppLlmProvider.ollama => OllamaAdapter(),
      AppLlmProvider.openaiCompatible => OpenAiCompatibleAdapter(),
    };
  }
}
