part of 'custom_provider.dart';

Map<String, dynamic> buildCustomProviderChatRequestBody({
  required ModelConfig model,
  required String systemPrompt,
  required String userPrompt,
  double? temperature,
  int? maxTokens,
  required bool stream,
}) {
  return {
    'model': model.modelName,
    'messages': [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ],
    'temperature': temperature ?? model.temperature,
    'max_tokens': maxTokens ?? model.maxOutputTokens,
    'stream': stream,
  };
}

Map<String, dynamic> buildCustomProviderToolRequestBody({
  required ModelConfig model,
  required String systemPrompt,
  required String userPrompt,
  required List<Map<String, dynamic>> tools,
  double? temperature,
  int? maxTokens,
}) {
  return {
    'model': model.modelName,
    'messages': [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ],
    'tools': tools,
    'temperature': temperature ?? model.temperature,
    'max_tokens': maxTokens ?? model.maxOutputTokens,
  };
}

_CustomProviderParsedCompletion parseCustomProviderCompletionResponse(
  dynamic rawData, {
  required int? statusCode,
}) {
  if (rawData is! Map<String, dynamic>) {
    throw AIException(
      'API 返回了非预期的响应格式（HTTP $statusCode）',
      statusCode: statusCode,
    );
  }

  if (rawData.containsKey('error')) {
    final error = rawData['error'];
    final errorMessage = error is Map
        ? error['message'] ?? error.toString()
        : error.toString();
    throw AIException(
      'API 错误: $errorMessage',
      statusCode: statusCode,
    );
  }

  if (statusCode != null && statusCode ~/ 100 != 2) {
    throw AIException(
      'API 请求失败（HTTP $statusCode）',
      statusCode: statusCode,
    );
  }

  final choices = rawData['choices'] as List<dynamic>?;
  if (choices == null || choices.isEmpty) {
    throw AIException(
      'API 返回了空的 choices（模型可能未加载）',
      statusCode: statusCode,
    );
  }

  final firstChoice = choices.first as Map<String, dynamic>;
  final message = firstChoice['message'] as Map<String, dynamic>?;
  if (message == null) {
    throw AIException(
      'API 返回格式异常，缺少 message 字段',
      statusCode: statusCode,
    );
  }

  final usage = rawData['usage'] as Map<String, dynamic>?;
  return _CustomProviderParsedCompletion(
    content: message['content'] as String? ?? '',
    inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
    outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
    requestId: rawData['id'] as String?,
    thinking: message['reasoning_content'] as String? ?? message['thinking'] as String?,
    finishReason: firstChoice['finish_reason'] as String?,
  );
}

_CustomProviderParsedCompletion? tryParseCustomProviderToolCompletion(
  dynamic rawData, {
  required int? statusCode,
}) {
  if (rawData is! Map<String, dynamic>) {
    return null;
  }
  if (rawData.containsKey('error')) {
    return null;
  }

  final choices = rawData['choices'] as List<dynamic>?;
  if (choices == null || choices.isEmpty) {
    return null;
  }

  final firstChoice = choices.first as Map<String, dynamic>;
  final message = firstChoice['message'] as Map<String, dynamic>?;
  if (message == null) {
    return null;
  }

  final usage = rawData['usage'] as Map<String, dynamic>?;
  final rawToolCalls = message['tool_calls'] as List<dynamic>?;

  return _CustomProviderParsedCompletion(
    content: message['content'] as String? ?? '',
    inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
    outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
    requestId: rawData['id'] as String?,
    thinking: message['reasoning_content'] as String? ?? message['thinking'] as String?,
    finishReason: firstChoice['finish_reason'] as String?,
    rawToolCalls: rawToolCalls == null
        ? const []
        : rawToolCalls
            .whereType<Map<String, dynamic>>()
            .map((toolCall) {
              final function = toolCall['function'] as Map<String, dynamic>;
              return <String, dynamic>{
                'id': toolCall['id'] as String? ?? '',
                'name': function['name'] as String? ?? '',
                'arguments': parseCustomProviderToolArguments(
                  function['arguments'],
                ),
              };
            })
            .toList(),
  );
}

bool shouldRetryCustomProviderCompletion(
  _CustomProviderParsedCompletion completion,
) {
  return completion.content.trim().isEmpty &&
      completion.thinking != null &&
      completion.thinking!.trim().isNotEmpty &&
      completion.finishReason == 'length';
}

_CustomProviderParsedStreamChunk parseCustomProviderStreamChunk(
  List<int> chunk,
) {
  final text = utf8.decode(chunk, allowMalformed: true);
  final lines = text.split('\n');
  final contents = <String>[];
  String? requestId;

  for (final line in lines) {
    if (!line.startsWith('data: ')) {
      continue;
    }

    final data = line.substring(6);
    if (data == '[DONE]') {
      continue;
    }

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      requestId ??= json['id'] as String?;

      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        continue;
      }

      final delta = choices.first['delta'] as Map<String, dynamic>?;
      final content = delta?['content'] as String?;
      if (content != null) {
        contents.add(content);
      }
    } catch (_) {
      // ignore malformed chunk
    }
  }

  return _CustomProviderParsedStreamChunk(
    requestId: requestId,
    contents: contents,
  );
}

String buildCustomProviderToolsDescription(
  List<Map<String, dynamic>> tools,
) {
  return tools.map((tool) {
    final function = tool['function'] as Map<String, dynamic>? ?? tool;
    final params = function['parameters'] as Map<String, dynamic>?;
    final properties = params?['properties'] as Map<String, dynamic>?;
    final paramText =
        properties != null ? ' 参数: ${jsonEncode(properties)}' : '';
    return '- ${function['name']}: ${function['description']}$paramText';
  }).join('\n');
}

List<Map<String, dynamic>> parseToolCallsFromText(String text) {
  try {
    final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonRegex.firstMatch(text);
    String? jsonStr;
    if (match != null) {
      jsonStr = match.group(1);
    } else {
      final directRegex = RegExp(r'\{[\s\S]*"tool_calls"[\s\S]*\}');
      final directMatch = directRegex.firstMatch(text);
      if (directMatch == null) {
        return const [];
      }
      jsonStr = directMatch.group(0);
    }

    final json = jsonDecode(jsonStr!) as Map<String, dynamic>;
    final toolCalls = json['tool_calls'] as List<dynamic>?;
    if (toolCalls == null) {
      return const [];
    }

    return toolCalls
        .whereType<Map<String, dynamic>>()
        .map(
          (toolCall) => <String, dynamic>{
            'id': toolCall['id'] as String? ?? '',
            'name': toolCall['name'] as String? ?? '',
            'arguments': toolCall['arguments'] as Map<String, dynamic>? ?? {},
          },
        )
        .toList();
  } catch (_) {
    return const [];
  }
}

String stripToolCallFromText(String text) {
  var cleaned = text;
  cleaned = cleaned.replaceAll(
    RegExp(r'```json\s*\{[\s\S]*?"tool_calls"[\s\S]*?\}\s*```'),
    '',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'\{"tool_calls"\s*:\s*\[[\s\S]*?\]\}'),
    '',
  );
  cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return cleaned.trim();
}

Map<String, dynamic> parseCustomProviderToolArguments(dynamic rawArgs) {
  if (rawArgs == null) {
    return {};
  }
  if (rawArgs is String) {
    try {
      return jsonDecode(rawArgs) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
  if (rawArgs is Map) {
    return Map<String, dynamic>.from(rawArgs);
  }
  return {};
}

class _CustomProviderParsedCompletion {
  const _CustomProviderParsedCompletion({
    required this.content,
    required this.inputTokens,
    required this.outputTokens,
    required this.requestId,
    required this.thinking,
    required this.finishReason,
    this.rawToolCalls = const [],
  });

  final String content;
  final int inputTokens;
  final int outputTokens;
  final String? requestId;
  final String? thinking;
  final String? finishReason;
  final List<Map<String, dynamic>> rawToolCalls;
}

class _CustomProviderParsedStreamChunk {
  const _CustomProviderParsedStreamChunk({
    required this.requestId,
    required this.contents,
  });

  final String? requestId;
  final List<String> contents;
}
