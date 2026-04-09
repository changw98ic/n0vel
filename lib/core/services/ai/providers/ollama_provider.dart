import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

class OllamaProvider extends AIProvider {
  @override
  AIProviderType get type => AIProviderType.ollama;

  final Dio _dio;

  OllamaProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<ConnectionTestResult> validateConnection(ProviderConfig config) async {
    try {
      final response = await _dio.get('${config.effectiveEndpoint}/tags');
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
      'stream': stream,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'options': {
        'temperature': temperature ?? model.temperature,
        'num_predict': maxTokens ?? model.maxOutputTokens,
      },
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
        '${config.effectiveEndpoint}/chat',
        data: body,
      );
      stopwatch.stop();

      final data = response.data as Map<String, dynamic>;
      final message = data['message'] as Map<String, dynamic>? ?? const {};
      final content = message['content'] as String? ?? '';

      return AIResponse(
        content: content,
        inputTokens: await countTokens(userPrompt, model.modelName),
        outputTokens: await countTokens(content, model.modelName),
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
      );
    } on DioException catch (e) {
      throw AIException(
        e.message ?? 'Request failed',
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
      '${config.effectiveEndpoint}/chat',
      data: body,
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data.stream as Stream<List<int>>;
    final buffer = StringBuffer();
    final lineBuffer = StringBuffer();

    await for (final chunk in stream) {
      final text = utf8.decode(chunk, allowMalformed: true);
      lineBuffer.write(text);

      final allText = lineBuffer.toString();
      final lines = allText.split('\n');
      lineBuffer.clear();
      // 保留最后一个可能不完整的行
      if (lines.isNotEmpty && !allText.endsWith('\n')) {
        lineBuffer.write(lines.last);
        lines.removeLast();
      }

      for (final line in lines) {
        if (line.trim().isEmpty) {
          continue;
        }
        try {
          final data = jsonDecode(line) as Map<String, dynamic>;
          final message = data['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            buffer.write(content);
            onStreamChunk(content);
          }
        } catch (_) {
          // ignore malformed chunk
        }
      }
    }

    stopwatch.stop();

    return AIResponse(
      content: buffer.toString(),
      inputTokens: await countTokens(body['messages'].toString(), model.modelName),
      outputTokens: await countTokens(buffer.toString(), model.modelName),
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
    );
  }

  // completeWithTools 使用基类默认实现：
  // 将工具描述注入 system prompt + 从文本响应中解析 tool_calls
  // Ollama 不支持原生 function calling，prompt-based 回退由基类处理

  @override
  Future<int> countTokens(String text, String modelName) async {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final other = text.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    try {
      final response = await _dio.get('${config.effectiveEndpoint}/tags');
      final data = response.data as Map<String, dynamic>;
      final models = data['models'] as List<dynamic>? ?? const [];
      return models
          .whereType<Map<String, dynamic>>()
          .map((model) => model['name'])
          .whereType<String>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
