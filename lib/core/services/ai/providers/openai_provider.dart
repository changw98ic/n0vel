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
      final choices = data['choices'] as List;
      final content = choices.first['message']['content'] as String;
      final usage = data['usage'] as Map<String, dynamic>;

      return AIResponse(
        content: content,
        inputTokens: usage['prompt_tokens'] as int,
        outputTokens: usage['completion_tokens'] as int,
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
      final choices = data['choices'] as List;
      final firstChoice = choices.first as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>;
      final usage = data['usage'] as Map<String, dynamic>?;

      // 解析 tool_calls
      List<ToolCall>? toolCalls;
      final rawToolCalls = message['tool_calls'] as List<dynamic>?;
      if (rawToolCalls != null) {
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

      final content = message['content'] as String? ?? '';

      return AIResponse(
        content: content,
        inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
        requestId: data['id'] as String?,
        toolCalls: toolCalls ?? const [],
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
        return data['error']['message'] ?? 'Unknown error';
      }
    }
    return e.message ?? 'Request failed';
  }
}
