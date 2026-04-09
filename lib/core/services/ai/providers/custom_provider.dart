import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

class CustomProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.custom;

  final Dio _dio;

  CustomProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<ConnectionTestResult> validateConnection(ProviderConfig config) async {
    final endpointError = config.endpointValidationError;
    if (endpointError != null) {
      return ConnectionTestResult.fail(endpointError);
    }
    try {
      final response = await _dio.get(
        '${config.effectiveEndpoint}/models',
        options: Options(headers: _headers(config)),
      );
      return response.statusCode == 200
          ? ConnectionTestResult.ok()
          : ConnectionTestResult.fail('服务器返回 HTTP ${response.statusCode}');
    } on DioException catch (e) {
      return ConnectionTestResult.fail(AIProvider.describeDioError(e));
    } catch (e) {
      return ConnectionTestResult.fail('连接失败: $e');
    }
  }

  @override
  Future<AIResponse> complete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    void Function(String)? onStreamChunk,
  }) {
    return _doComplete(
      config: config,
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      stream: stream,
      onStreamChunk: onStreamChunk,
    );
  }

  Future<AIResponse> _doComplete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    void Function(String)? onStreamChunk,
    bool isRetry = false,
  }) async {
    final endpointError = config.endpointValidationError;
    if (endpointError != null) {
      throw AIException(endpointError);
    }

    if (stream && onStreamChunk != null) {
      return _streamComplete(
        config: config,
        model: model,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        onStreamChunk: onStreamChunk,
        isRetry: isRetry,
      );
    }

    final stopwatch = Stopwatch()..start();
    final response = await _dio.post(
      '${config.effectiveEndpoint}/chat/completions',
      data: {
        'model': model.modelName,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature ?? model.temperature,
        'max_tokens': maxTokens ?? model.maxOutputTokens,
        'stream': false,
      },
      options: Options(
        headers: _headers(config),
        validateStatus: (_) => true,
      ),
    );
    stopwatch.stop();

    final data = response.data;

    // Handle non-JSON responses
    if (data is! Map<String, dynamic>) {
      throw AIException(
        'API 返回了非预期的响应格式（HTTP ${response.statusCode}）',
        statusCode: response.statusCode,
      );
    }

    // Handle API error responses
    if (data.containsKey('error')) {
      final error = data['error'];
      final errorMessage = error is Map
          ? error['message'] ?? error.toString()
          : error.toString();
      throw AIException(
        'API 错误: $errorMessage',
        statusCode: response.statusCode,
      );
    }

    // Handle non-200 status without error field
    if (response.statusCode != null && response.statusCode! ~/ 100 != 2) {
      throw AIException(
        'API 请求失败（HTTP ${response.statusCode}）',
        statusCode: response.statusCode,
      );
    }

    // Validate response structure
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw AIException(
        'API 返回了空的 choices（模型可能未加载）',
        statusCode: response.statusCode,
      );
    }

    final firstChoice = choices.first as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>?;
    if (message == null) {
      throw AIException(
        'API 返回格式异常，缺少 message 字段',
        statusCode: response.statusCode,
      );
    }

    final usage = data['usage'] as Map<String, dynamic>?;
    final content = message['content'] as String? ?? '';
    // 提取思维链（LM Studio reasoning_content / DeepSeek reasoning_content）
    final thinking = message['reasoning_content'] as String? ??
        message['thinking'] as String?;
    final finishReason = firstChoice['finish_reason'] as String?;

    // 推理耗尽 token 预算：模型把所有 token 都花在了 reasoning 上，
    // 没有剩余给实际内容。自动以双倍 token 预算重试一次。
    if (!isRetry &&
        content.trim().isEmpty &&
        thinking != null &&
        thinking.trim().isNotEmpty &&
        finishReason == 'length') {
      final newMaxTokens = (maxTokens ?? model.maxOutputTokens) * 2;
      return _doComplete(
        config: config,
        model: model,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: temperature,
        maxTokens: newMaxTokens,
        stream: stream,
        onStreamChunk: onStreamChunk,
        isRetry: true,
      );
    }

    return AIResponse(
      content: content,
      inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
      requestId: data['id'] as String?,
      thinking: thinking,
    );
  }

  Future<AIResponse> _streamComplete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    required void Function(String) onStreamChunk,
    bool isRetry = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    final requestBody = {
      'model': model.modelName,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature ?? model.temperature,
      'max_tokens': maxTokens ?? model.maxOutputTokens,
      'stream': true,
    };

    try {
      final response = await _dio.post(
        '${config.effectiveEndpoint}/chat/completions',
        data: requestBody,
        options: Options(
          headers: _headers(config),
          responseType: ResponseType.stream,
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      final buffer = StringBuffer();
      String? requestId;

      await for (final chunk in stream) {
        final text = utf8.decode(chunk, allowMalformed: true);
        final lines = text.split('\n');

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') continue;

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              requestId ??= json['id'] as String?;

              final choices = json['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices.first['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                if (content != null) {
                  buffer.write(content);
                  onStreamChunk(content);
                }
              }
            } catch (_) {
              // ignore malformed chunk
            }
          }
        }
      }

      stopwatch.stop();

      return AIResponse(
        content: buffer.toString(),
        inputTokens: await countTokens(
          requestBody['messages'].toString(), model.modelName,
        ),
        outputTokens: await countTokens(buffer.toString(), model.modelName),
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
        requestId: requestId,
      );
    } on DioException catch (e) {
      throw AIException(
        AIProvider.describeDioError(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  @override
  Future<AIResponse> completeWithTools({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    required List<Map<String, dynamic>> tools,
    double? temperature,
    int? maxTokens,
  }) {
    return _doCompleteWithTools(
      config: config,
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  Future<AIResponse> _doCompleteWithTools({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    required List<Map<String, dynamic>> tools,
    double? temperature,
    int? maxTokens,
    bool isRetry = false,
  }) async {
    final endpointError = config.endpointValidationError;
    if (endpointError != null) {
      throw AIException(endpointError);
    }

    final stopwatch = Stopwatch()..start();

    try {
      // 尝试原生 function calling（LM Studio 等 OpenAI 兼容 API 支持）
      final response = await _dio.post(
        '${config.effectiveEndpoint}/chat/completions',
        data: {
          'model': model.modelName,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'tools': tools,
          'temperature': temperature ?? model.temperature,
          'max_tokens': maxTokens ?? model.maxOutputTokens,
        },
        options: Options(
          headers: _headers(config),
          validateStatus: (_) => true,
        ),
      );
      stopwatch.stop();

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        // 原生 tool calling 失败，降级到 prompt-based
        return _fallbackPromptBased(
          config: config,
          model: model,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          tools: tools,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      }

      if (data.containsKey('error')) {
        // 原生 tool calling 不支持，降级到 prompt-based
        return _fallbackPromptBased(
          config: config,
          model: model,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          tools: tools,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      }

      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return _fallbackPromptBased(
          config: config,
          model: model,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          tools: tools,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      }

      final firstChoice = choices.first as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      if (message == null) {
        return _fallbackPromptBased(
          config: config,
          model: model,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          tools: tools,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      }

      final usage = data['usage'] as Map<String, dynamic>?;
      final content = message['content'] as String? ?? '';
      // 提取思维链
      final thinking = message['reasoning_content'] as String? ??
          message['thinking'] as String?;
      final finishReason = firstChoice['finish_reason'] as String?;

      // 推理耗尽 token 预算：自动以双倍预算重试一次
      if (!isRetry &&
          content.trim().isEmpty &&
          thinking != null &&
          thinking.trim().isNotEmpty &&
          finishReason == 'length') {
        final newMaxTokens = (maxTokens ?? model.maxOutputTokens) * 2;
        return _doCompleteWithTools(
          config: config,
          model: model,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          tools: tools,
          temperature: temperature,
          maxTokens: newMaxTokens,
          isRetry: true,
        );
      }

      // 解析原生 tool_calls
      List<ToolCall> toolCalls = [];
      final rawToolCalls = message['tool_calls'] as List<dynamic>?;
      if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
        toolCalls = rawToolCalls
            .whereType<Map<String, dynamic>>()
            .map((tc) {
          final function = tc['function'] as Map<String, dynamic>;
          return ToolCall(
            id: tc['id'] as String? ?? '',
            name: function['name'] as String? ?? '',
            arguments: _parseToolArguments(function['arguments']),
          );
        }).toList();
      }

      // 如果原生 tool_calls 为空，尝试从文本中解析（降级）
      if (toolCalls.isEmpty && content.isNotEmpty) {
        toolCalls = _parseToolCallsFromText(content);
      }

      final cleanedContent = toolCalls.isNotEmpty
          ? _stripToolCallFromText(content)
          : content;

      return AIResponse(
        content: cleanedContent,
        inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
        requestId: data['id'] as String?,
        toolCalls: toolCalls,
        thinking: thinking,
      );
    } on DioException catch (e) {
      // 网络错误等不降级，直接抛出
      throw AIException(
        AIProvider.describeDioError(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  /// Prompt-based 降级：将工具描述注入 system prompt，从文本响应中解析
  Future<AIResponse> _fallbackPromptBased({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    required List<Map<String, dynamic>> tools,
    double? temperature,
    int? maxTokens,
  }) async {
    final toolsDescription = tools.map((t) {
      final func = t['function'] as Map<String, dynamic>? ?? t;
      final params = func['parameters'] as Map<String, dynamic>?;
      final properties = params?['properties'] as Map<String, dynamic>?;
      final paramStr = properties != null
          ? ' 参数: ${jsonEncode(properties)}'
          : '';
      return '- ${func['name']}: ${func['description']}$paramStr';
    }).join('\n');
    final enhancedSystem =
        '$systemPrompt\n\n你可以使用以下工具来完成任务。\n'
        '如果需要调用工具，请在回复中使用以下 JSON 格式：\n'
        '```json\n{"tool_calls": [{"id": "唯一ID", "name": "工具名", "arguments": {参数}}]}\n```\n\n'
        '可用工具：\n$toolsDescription\n\n'
        '如果不需要调用工具，直接回复文本内容即可。';

    final response = await complete(
      config: config,
      model: model,
      systemPrompt: enhancedSystem,
      userPrompt: userPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      stream: false,
    );

    // 从文本中解析 tool calls
    final parsedCalls = _parseToolCallsFromText(response.content);
    if (parsedCalls.isNotEmpty) {
      final cleanedContent = _stripToolCallFromText(response.content);
      return AIResponse(
        content: cleanedContent,
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
        modelId: response.modelId,
        responseTime: response.responseTime,
        fromCache: response.fromCache,
        requestId: response.requestId,
        metadata: response.metadata,
        toolCalls: parsedCalls,
      );
    }

    return response;
  }

  /// 从文本中解析工具调用
  static List<ToolCall> _parseToolCallsFromText(String text) {
    try {
      // 尝试找到 ```json ... ``` 代码块
      final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
      final match = jsonRegex.firstMatch(text);
      String? jsonStr;
      if (match != null) {
        jsonStr = match.group(1);
      } else {
        // 尝试直接匹配 {"tool_calls": [...]}
        final directRegex = RegExp(r'\{[\s\S]*"tool_calls"[\s\S]*\}');
        final directMatch = directRegex.firstMatch(text);
        if (directMatch == null) return const [];
        jsonStr = directMatch.group(0);
      }
      final json = jsonDecode(jsonStr!) as Map<String, dynamic>;
      final toolCalls = json['tool_calls'] as List<dynamic>?;
      if (toolCalls == null) return const [];
      return toolCalls
          .whereType<Map<String, dynamic>>()
          .map((tc) => ToolCall(
                id: tc['id'] as String? ?? '',
                name: tc['name'] as String? ?? '',
                arguments: tc['arguments'] as Map<String, dynamic>? ?? {},
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 从文本中移除工具调用 JSON，只保留自然语言内容
  static String _stripToolCallFromText(String text) {
    var cleaned = text;
    cleaned = cleaned.replaceAll(
        RegExp(r'```json\s*\{[\s\S]*?"tool_calls"[\s\S]*?\}\s*```'), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'\{"tool_calls"\s*:\s*\[[\s\S]*?\]\}'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  /// 安全解析 tool call arguments
  static Map<String, dynamic> _parseToolArguments(dynamic rawArgs) {
    if (rawArgs == null) return {};
    if (rawArgs is String) {
      try {
        return jsonDecode(rawArgs) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    if (rawArgs is Map) return Map<String, dynamic>.from(rawArgs);
    return {};
  }

  @override
  Future<int> countTokens(String text, String modelName) async {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final other = text.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    final endpointError = config.endpointValidationError;
    if (endpointError != null) return const [];
    try {
      final response = await _dio.get(
        '${config.effectiveEndpoint}/models',
        options: Options(headers: _headers(config)),
      );
      final data = response.data as Map<String, dynamic>;
      final models = data['data'] as List<dynamic>? ?? const [];
      return models
          .whereType<Map<String, dynamic>>()
          .map((model) => model['id'])
          .whereType<String>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, String> _headers(ProviderConfig config) {
    return {
      if (config.apiKey != null && config.apiKey!.isNotEmpty)
        'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
      ...config.headers,
    };
  }
}
