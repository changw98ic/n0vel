import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

part 'custom_provider_helpers.dart';

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
      data: buildCustomProviderChatRequestBody(
        model: model,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        stream: false,
      ),
      options: Options(
        headers: _headers(config),
        validateStatus: (_) => true,
      ),
    );
    stopwatch.stop();

    final completion = parseCustomProviderCompletionResponse(
      response.data,
      statusCode: response.statusCode,
    );

    // 推理耗尽 token 预算：模型把所有 token 都花在了 reasoning 上，
    // 没有剩余给实际内容。自动以双倍 token 预算重试一次。
    if (!isRetry &&
        shouldRetryCustomProviderCompletion(completion)) {
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
      content: completion.content,
      inputTokens: completion.inputTokens,
      outputTokens: completion.outputTokens,
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
      requestId: completion.requestId,
      thinking: completion.thinking,
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

    final requestBody = buildCustomProviderChatRequestBody(
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      stream: true,
    );

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
        final parsedChunk = parseCustomProviderStreamChunk(chunk);
        requestId ??= parsedChunk.requestId;
        for (final content in parsedChunk.contents) {
          buffer.write(content);
          onStreamChunk(content);
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
        data: buildCustomProviderToolRequestBody(
          model: model,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          tools: tools,
          temperature: temperature,
          maxTokens: maxTokens,
        ),
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

      final toolCompletion = tryParseCustomProviderToolCompletion(
        data,
        statusCode: response.statusCode,
      );
      if (toolCompletion == null) {
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

      // 推理耗尽 token 预算：自动以双倍预算重试一次
      if (!isRetry &&
          shouldRetryCustomProviderCompletion(toolCompletion)) {
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
      var rawToolCalls = toolCompletion.rawToolCalls;

      // 如果原生 tool_calls 为空，尝试从文本中解析（降级）
      if (rawToolCalls.isEmpty && toolCompletion.content.isNotEmpty) {
        rawToolCalls = parseToolCallsFromText(toolCompletion.content);
      }

      final cleanedContent = rawToolCalls.isNotEmpty
          ? stripToolCallFromText(toolCompletion.content)
          : toolCompletion.content;

      return AIResponse(
        content: cleanedContent,
        inputTokens: toolCompletion.inputTokens,
        outputTokens: toolCompletion.outputTokens,
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
        requestId: toolCompletion.requestId,
        metadata: rawToolCalls.isEmpty
            ? null
            : {
                'rawToolCalls': rawToolCalls,
              },
        thinking: toolCompletion.thinking,
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
    final toolsDescription = buildCustomProviderToolsDescription(tools);
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
    final parsedCalls = parseToolCallsFromText(response.content);
    if (parsedCalls.isNotEmpty) {
      final cleanedContent = stripToolCallFromText(response.content);
      return AIResponse(
        content: cleanedContent,
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
        modelId: response.modelId,
        responseTime: response.responseTime,
        fromCache: response.fromCache,
        requestId: response.requestId,
        metadata: {
          ...?response.metadata,
          'rawToolCalls': parsedCalls,
        },
      );
    }

    return response;
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
