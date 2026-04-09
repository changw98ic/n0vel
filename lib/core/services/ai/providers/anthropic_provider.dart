import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

class AnthropicProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.anthropic;

  final Dio _dio;

  AnthropicProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<ConnectionTestResult> validateConnection(ProviderConfig config) async {
    try {
      final response = await _dio.post(
        '${config.effectiveEndpoint}/messages',
        data: {
          'model': 'claude-3-haiku-20240307',
          'max_tokens': 16,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
        },
        options: Options(
          headers: _headers(config),
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

    final body = {
      'model': model.modelName,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature ?? model.temperature,
      'max_tokens': maxTokens ?? model.maxOutputTokens,
      'stream': stream,
    };

    try {
      if (stream && onStreamChunk != null) {
        return await _streamComplete(
          config: config,
          body: body,
          model: model,
          stopwatch: stopwatch,
          onStreamChunk: onStreamChunk,
        );
      }

      final response = await _dio.post(
        '${config.effectiveEndpoint}/messages',
        data: body,
        options: Options(headers: _headers(config)),
      );

      stopwatch.stop();
      final data = response.data as Map<String, dynamic>;
      final content = _extractContent(data);
      final usage = data['usage'] as Map<String, dynamic>?;

      return AIResponse(
        content: content,
        inputTokens: (usage?['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage?['output_tokens'] as num?)?.toInt() ?? 0,
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

    // Anthropic 使用不同的 tools 格式
    final anthropicTools = tools.map((t) {
      final func = t['function'] as Map<String, dynamic>? ?? t;
      return {
        'name': func['name'],
        'description': func['description'],
        'input_schema': func['parameters'] ?? func['input_schema'] ?? {},
      };
    }).toList();

    final body = {
      'model': model.modelName,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': userPrompt},
      ],
      'tools': anthropicTools,
      'temperature': temperature ?? model.temperature,
      'max_tokens': maxTokens ?? model.maxOutputTokens,
    };

    try {
      final response = await _dio.post(
        '${config.effectiveEndpoint}/messages',
        data: body,
        options: Options(headers: _headers(config)),
      );

      stopwatch.stop();
      final data = response.data as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>? ?? [];
      final usage = data['usage'] as Map<String, dynamic>?;

      // 解析文本和 tool_use 内容块
      final textBuffer = StringBuffer();
      List<ToolCall>? toolCalls;

      for (final block in content.whereType<Map<String, dynamic>>()) {
        final type = block['type'] as String?;
        if (type == 'text') {
          textBuffer.write(block['text'] as String? ?? '');
        } else if (type == 'tool_use') {
          toolCalls ??= [];
          toolCalls.add(ToolCall(
            id: block['id'] as String? ?? '',
            name: block['name'] as String? ?? '',
            arguments: block['input'] as Map<String, dynamic>? ?? {},
          ));
        }
      }

      return AIResponse(
        content: textBuffer.toString(),
        inputTokens: (usage?['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage?['output_tokens'] as num?)?.toInt() ?? 0,
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
    required Map<String, dynamic> body,
    required ModelConfig model,
    required Stopwatch stopwatch,
    required void Function(String) onStreamChunk,
  }) async {
    final response = await _dio.post(
      '${config.effectiveEndpoint}/messages',
      data: body,
      options: Options(
        headers: _headers(config),
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    final buffer = StringBuffer();
    String? requestId;

    try {
      await for (final chunk in stream) {
        final text = utf8.decode(chunk, allowMalformed: true);
        for (final line in text.split('\n')) {
          if (!line.startsWith('data: ')) {
            continue;
          }
          final payload = line.substring(6);
          if (payload == '[DONE]' || payload.isEmpty) {
            continue;
          }
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            requestId ??= data['id'] as String?;
            final type = data['type'] as String?;
            if (type == 'content_block_delta') {
              final delta = data['delta'] as Map<String, dynamic>?;
              final textChunk = delta?['text'] as String?;
              if (textChunk != null && textChunk.isNotEmpty) {
                buffer.write(textChunk);
                onStreamChunk(textChunk);
              }
            }
          } catch (_) {
            // ignore malformed chunk
          }
        }
      }
    } catch (e) {
      rethrow;
    }

    stopwatch.stop();

    return AIResponse(
      content: buffer.toString(),
      inputTokens: await countTokens(userPromptFromBody(body), model.modelName),
      outputTokens: await countTokens(buffer.toString(), model.modelName),
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
      requestId: requestId,
    );
  }

  @override
  Future<int> countTokens(String text, String modelName) async {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final other = text.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    return const [
      'claude-3-5-sonnet-20241022',
      'claude-3-5-haiku-20241022',
      'claude-3-opus-20240229',
    ];
  }

  Map<String, String> _headers(ProviderConfig config) {
    return {
      'x-api-key': config.apiKey ?? '',
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
      ...config.headers,
    };
  }

  String _extractContent(Map<String, dynamic> data) {
    final content = data['content'] as List<dynamic>? ?? const [];
    return content
        .whereType<Map<String, dynamic>>()
        .map((entry) => entry['text'])
        .whereType<String>()
        .join();
  }

  String userPromptFromBody(Map<String, dynamic> body) {
    final messages = body['messages'] as List<dynamic>? ?? const [];
    return messages
        .whereType<Map<String, dynamic>>()
        .map((entry) => entry['content'])
        .whereType<String>()
        .join('\n');
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['message']?.toString() ?? 'Request failed';
    }
    return e.message ?? 'Request failed';
  }
}
