/// 工具执行结果
class ToolResult {
  final bool success;
  final String output;
  final Map<String, dynamic>? data;
  final String? error;

  const ToolResult({
    required this.success,
    required this.output,
    this.data,
    this.error,
  });

  static ToolResult ok(String output, {Map<String, dynamic>? data}) =>
      ToolResult(success: true, output: output, data: data);

  static ToolResult fail(String error) =>
      ToolResult(success: false, output: '', error: error);
}

/// 工具定义基类
/// 每个 AI 可调用的工具都继承此类
abstract class ToolDefinition {
  /// 工具名称（唯一标识）
  String get name;

  /// 工具描述（给 AI 看的）
  String get description;

  /// 输入参数 JSON Schema
  Map<String, dynamic> get inputSchema;

  /// 执行工具
  Future<ToolResult> execute(Map<String, dynamic> input);

  /// 转换为 OpenAI function calling 格式
  Map<String, dynamic> toFunctionSchema() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': inputSchema,
        },
      };
}
