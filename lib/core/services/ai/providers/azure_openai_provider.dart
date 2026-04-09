import 'dart:convert';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

class AzureOpenAIProvider extends AIProvider {
  @override
  AIProviderType get type => AIProviderType.azure;

  final Dio _dio;

  AzureOpenAIProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<ConnectionTestResult> validateConnection(ProviderConfig config) async {
    try {
      final response = await _dio.post(
        _chatUrl(config, 'gpt-4.1-mini'),
        data: {
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 1,
        },
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
  }) async {
    final stopwatch = Stopwatch()..start();

    if (stream && onStreamChunk != null) {
      return _streamComplete(
        config: config,
        model: model,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        stopwatch: stopwatch,
        onStreamChunk: onStreamChunk,
      );
    }

    try {
      final response = await _dio.post(
        _chatUrl(config, model.modelName),
        data: {
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
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

      // Handle non-2xx status
      if (response.statusCode != null && response.statusCode! ~/ 100 != 2) {
        throw AIException(
          'API 请求失败（HTTP ${response.statusCode}）',
          statusCode: response.statusCode,
        );
      }

      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw AIException(
          'API 返回了空的 choices',
          statusCode: response.statusCode,
        );
      }

      final first = choices.first as Map<String, dynamic>;
      final message = first['message'] as Map<String, dynamic>;
      final usage = data['usage'] as Map<String, dynamic>?;

      return AIResponse(
        content: message['content'] as String? ?? '',
        inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
        requestId: data['id'] as String?,
      );
    } on AIException {
      rethrow;
    } on DioException catch (e) {
      throw AIException(
        AIProvider.describeDioError(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  Future<AIResponse> _streamComplete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    required Stopwatch stopwatch,
    required void Function(String) onStreamChunk,
  }) async {
    try {
      final response = await _dio.post(
        _chatUrl(config, model.modelName),
        data: {
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': temperature ?? model.temperature,
          'max_tokens': maxTokens ?? model.maxOutputTokens,
          'stream': true,
        },
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
          '$systemPrompt\n$userPrompt', model.modelName,
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
  Future<int> countTokens(String text, String modelName) async {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final other = text.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    return const [];
  }

  Map<String, String> _headers(ProviderConfig config) {
    return {
      'api-key': config.apiKey ?? '',
      'Content-Type': 'application/json',
      ...config.headers,
    };
  }

  String _chatUrl(ProviderConfig config, String deploymentName) {
    final base = config.effectiveEndpoint;
    final suffix = base.contains('?') ? '&' : '?';
    return '$base/openai/deployments/$deploymentName/chat/completions${suffix}api-version=2024-02-15-preview';
  }
}
