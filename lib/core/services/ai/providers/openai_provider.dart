import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

/// OpenAI 供应商实现
class OpenAIProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.openai;

  final Dio _dio;

  OpenAIProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<ConnectionTestResult> validateConnection(ProviderConfig config) async {
    try {
      final response = await _dio.get(
        '${config.effectiveEndpoint}/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            ...config.headers,
          },
        ),
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
  }) async {
    final endpointError = config.endpointValidationError;
    if (endpointError != null) {
      throw AIException(endpointError);
    }
    final stopwatch = Stopwatch()..start();

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    final requestBody = {
      'model': model.modelName,
      'messages': messages,
      'temperature': temperature ?? model.temperature,
      'max_tokens': maxTokens ?? model.maxOutputTokens,
      'top_p': model.topP,
      'frequency_penalty': model.frequencyPenalty,
      'presence_penalty': model.presencePenalty,
      'stream': stream,
    };

    try {
      if (stream && onStreamChunk != null) {
        return await _streamComplete(
          config: config,
          requestBody: requestBody,
          model: model,
          stopwatch: stopwatch,
          onStreamChunk: onStreamChunk,
        );
      }

      final response = await _dio.post(
        '${config.effectiveEndpoint}/chat/completions',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
            ...config.headers,
          },
        ),
      );

      stopwatch.stop();

      final data = response.data as Map<String, dynamic>;
      final choices = _asList(data['choices']) ?? const [];
      final firstChoice = choices.isEmpty ? null : _asMap(choices.first);
      final content = _extractMessageContent(firstChoice?['message']);
      final usage = _asMap(data['usage']);

      return AIResponse(
        content: content,
        inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
        requestId: data['id'] as String?,
      );
    } on DioException catch (e) {
      throw AIException(
        _extractErrorMessage(e),
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
  }) async {
    final stopwatch = Stopwatch()..start();

    final requestBody = {
      'model': model.modelName,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'tools': tools,
      'temperature': temperature ?? model.temperature,
      'max_tokens': maxTokens ?? model.maxOutputTokens,
    };

    try {
      final response = await _dio.post(
        '${config.effectiveEndpoint}/chat/completions',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
            ...config.headers,
          },
        ),
      );

      stopwatch.stop();
      final data = response.data as Map<String, dynamic>;
      final choices = _asList(data['choices']) ?? const [];
      final firstChoice = choices.isEmpty ? null : _asMap(choices.first);
      final message = _asMap(firstChoice?['message']);
      final usage = _asMap(data['usage']);

      // 解析原生 tool_calls
      List<ToolCall> toolCalls = [];
      final rawToolCalls = _asList(message?['tool_calls']);
      if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
        toolCalls = rawToolCalls
            .map(_asMap)
            .whereType<Map<String, dynamic>>()
            .map((tc) {
          final function = _asMap(tc['function']) ?? const <String, dynamic>{};
          return ToolCall(
            id: tc['id'] as String? ?? '',
            name: function['name'] as String? ?? '',
            arguments: _parseToolArguments(function['arguments']),
          );
        }).toList();
      }

      var content = _extractMessageContent(message);

      // 如果原生 tool_calls 为空，尝试从文本中解析（兼容非原生 function calling 端点）
      if (toolCalls.isEmpty && content.isNotEmpty) {
        toolCalls = _parseToolCallsFromText(content);
      }

      if (toolCalls.isNotEmpty) {
        content = _stripToolCallFromText(content);
      }

      return AIResponse(
        content: content,
        inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
        requestId: data['id'] as String?,
        toolCalls: toolCalls,
      );
    } on DioException catch (e) {
      throw AIException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  Future<AIResponse> _streamComplete({
    required ProviderConfig config,
    required Map<String, dynamic> requestBody,
    required ModelConfig model,
    required Stopwatch stopwatch,
    required void Function(String) onStreamChunk,
  }) async {
    final response = await _dio.post(
      '${config.effectiveEndpoint}/chat/completions',
      data: requestBody,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
          ...config.headers,
        },
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    final buffer = StringBuffer();
    int inputTokens = 0;
    int outputTokens = 0;
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

            final choices = _asList(json['choices']);
            if (choices != null && choices.isNotEmpty) {
              final delta = _asMap(_asMap(choices.first)?['delta']);
              final content = delta?['content'] as String?;
              if (content != null) {
                buffer.write(content);
                onStreamChunk(content);
              }
            }
          } catch (_) {
            // 忽略解析错误
          }
        }
      }
    }

    stopwatch.stop();

    // 估算 token（流式响应通常不返回 usage）
    inputTokens = await countTokens(requestBody['messages'].toString(), model.modelName);
    outputTokens = await countTokens(buffer.toString(), model.modelName);

    return AIResponse(
      content: buffer.toString(),
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
      requestId: requestId,
    );
  }

  /// 安全解析 tool call arguments
  static Map<String, dynamic> _parseToolArguments(dynamic rawArgs) {
    if (rawArgs == null) return {};
    if (rawArgs is String) {
      try {
        return _asMap(jsonDecode(rawArgs)) ?? {};
      } catch (_) {
        return {};
      }
    }
    if (rawArgs is Map) return Map<String, dynamic>.from(rawArgs);
    return {};
  }

  @override
  Future<int> countTokens(String text, String modelName) async {
    // 简化估算：中文约 1.5 字符/token，英文约 4 字符/token
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final otherCount = text.length - chineseCount;
    return (chineseCount * 0.67 + otherCount * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    try {
      final response = await _dio.get(
        '${config.effectiveEndpoint}/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            ...config.headers,
          },
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final models = data['data'] as List;
      return models.map((m) => m['id'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data['error'] != null) {
        final error = data['error'];
        if (error is Map) {
          final message = error['message'];
          if (message != null) {
            return message.toString();
          }
          return error.toString();
        }
        return error.toString();
      }
      return data.toString();
    }
    return e.message ?? 'Request failed';
  }

  /// 从文本中解析工具调用（兼容非原生 function calling 端点）
  static List<ToolCall> _parseToolCallsFromText(String text) {
    try {
      final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
      final match = jsonRegex.firstMatch(text);
      String? jsonStr;
      if (match != null) {
        jsonStr = match.group(1);
      } else {
        final directRegex = RegExp(r'\{[\s\S]*"tool_calls"[\s\S]*\}');
        final directMatch = directRegex.firstMatch(text);
        if (directMatch == null) return const [];
        jsonStr = directMatch.group(0);
      }
      final json = jsonDecode(jsonStr!) as Map<String, dynamic>;
      final toolCalls = _asList(json['tool_calls']);
      if (toolCalls == null) return const [];
      return toolCalls
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .map((tc) => ToolCall(
                id: tc['id'] as String? ?? '',
                name: tc['name'] as String? ?? '',
                arguments: _parseToolArguments(tc['arguments']),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  static List<dynamic>? _asList(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return List<dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  static String _extractMessageContent(dynamic message) {
    if (message is String) {
      return message;
    }

    final map = _asMap(message);
    if (map == null) {
      return '';
    }

    final content = map['content'];
    if (content is String) {
      return content;
    }
    if (content is List) {
      return content
          .map(
            (part) => _asMap(part)?['text'] as String? ?? part?.toString() ?? '',
          )
          .join();
    }

    return content?.toString() ?? '';
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
}
