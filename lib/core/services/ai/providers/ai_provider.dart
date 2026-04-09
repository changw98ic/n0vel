import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';

/// AI 供应商抽象接口
abstract class AIProvider {
  /// 供应商类型
  AIProviderType get type;

  /// 验证连接
  Future<ConnectionTestResult> validateConnection(ProviderConfig config);

  /// 执行请求
  Future<AIResponse> complete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    void Function(String)? onStreamChunk,
  });

  /// 支持 function calling 的请求
  /// 供应商应覆写此方法以支持原生 tool calling
  /// 默认实现将工具描述注入 system prompt，从文本响应中解析工具调用
  Future<AIResponse> completeWithTools({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    required List<Map<String, dynamic>> tools,
    double? temperature,
    int? maxTokens,
  }) async {
    // 默认实现：将工具描述注入 system prompt
    final toolsDescription = _buildToolsPrompt(tools);
    final enhancedSystemPrompt = '$systemPrompt\n\n$toolsDescription';

    final response = await complete(
      config: config,
      model: model,
      systemPrompt: enhancedSystemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      stream: false,
    );

    // 尝试从文本中解析工具调用
    final parsedCalls = _parseToolCallsFromText(response.content);
    if (parsedCalls.isNotEmpty) {
      // 从文本中移除原始工具调用 JSON，只保留自然语言部分
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

  /// 估算 Token 数量
  Future<int> countTokens(String text, String modelName);

  /// 获取可用模型列表（如果供应商支持）
  Future<List<String>> getAvailableModels(ProviderConfig config);

  /// 构建工具描述 prompt（默认实现用）
  static String _buildToolsPrompt(List<Map<String, dynamic>> tools) {
    final buffer = StringBuffer();
    buffer.writeln('你可以使用以下工具来完成任务。');
    buffer.writeln('如果需要调用工具，请在回复中使用以下 JSON 格式：');
    buffer.writeln('```json');
    buffer.writeln('{"tool_calls": [{"id": "唯一ID", "name": "工具名", "arguments": {参数}}]}');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('可用工具：');
    for (final tool in tools) {
      final func = tool['function'] as Map<String, dynamic>?;
      if (func != null) {
        buffer.writeln('- ${func['name']}: ${func['description']}');
        final params = func['parameters'] as Map<String, dynamic>?;
        final properties = params?['properties'];
        if (properties != null) {
          buffer.writeln('  参数: ${jsonEncode(properties)}');
        }
      }
    }
    buffer.writeln();
    buffer.writeln('如果不需要调用工具，直接回复文本内容即可。');
    return buffer.toString();
  }

  /// 从文本中解析工具调用（默认实现用）
  static List<ToolCall> _parseToolCallsFromText(String text) {
    try {
      // 尝试找到 JSON 块
      final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
      final match = jsonRegex.firstMatch(text);
      String? jsonStr;
      if (match != null) {
        jsonStr = match.group(1);
      } else {
        // 也尝试直接解析整个文本
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

  /// 从文本中移除工具调用 JSON 块，只保留自然语言内容
  static String _stripToolCallFromText(String text) {
    var cleaned = text;
    // 移除 ```json ... ``` 格式的工具调用块
    cleaned = cleaned.replaceAll(RegExp(r'```json\s*\{[\s\S]*?"tool_calls"[\s\S]*?\}\s*```'), '');
    // 移除直接嵌入的 {"tool_calls": [...]} JSON（不在代码块中的）
    cleaned = cleaned.replaceAll(RegExp(r'\{"tool_calls"\s*:\s*\[[\s\S]*?\]\}'), '');
    // 清理多余空行
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  /// 从 DioException 提取中文错误信息
  static String describeDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络或端点地址';
      case DioExceptionType.connectionError:
        return '无法连接到服务器，请检查端点地址是否正确';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401) {
          return 'API 密钥无效或已过期';
        } else if (status == 403) {
          return '无权访问该资源，请检查 API 密钥权限';
        } else if (status == 404) {
          return '端点地址不正确，请检查 URL';
        } else if (status == 429) {
          return '请求过于频繁，请稍后重试';
        } else if (status != null && status >= 500) {
          return '服务器错误 ($status)，请稍后重试';
        } else {
          return '请求失败 (HTTP $status)';
        }
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '连接失败: ${e.message ?? "未知错误"}';
    }
  }
}

/// AI 供应商注册表
class AIProviderRegistry {
  static final AIProviderRegistry _instance = AIProviderRegistry._();
  factory AIProviderRegistry() => _instance;
  AIProviderRegistry._();

  final Map<AIProviderType, AIProvider> _providers = {};

  void register(AIProvider provider) {
    _providers[provider.type] = provider;
  }

  AIProvider? get(AIProviderType type) => _providers[type];

  List<AIProviderType> get availableTypes => _providers.keys.toList();
}
