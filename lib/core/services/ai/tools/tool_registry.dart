import 'tool_definition.dart';

/// 工具注册表（单例）
/// 管理所有 AI 可调用的工具
class ToolRegistry {
  static final ToolRegistry _instance = ToolRegistry._();
  factory ToolRegistry() => _instance;
  ToolRegistry._();

  final Map<String, ToolDefinition> _tools = {};

  /// 注册工具
  void register(ToolDefinition tool) => _tools[tool.name] = tool;

  /// 获取工具
  ToolDefinition? get(String name) => _tools[name];

  /// 所有已注册工具
  List<ToolDefinition> get all => _tools.values.toList();

  /// 已注册的工具名称
  List<String> get names => _tools.keys.toList();

  /// 生成 function calling schema 列表
  List<Map<String, dynamic>> toFunctionCallSchema() =>
      _tools.values.map((t) => t.toFunctionSchema()).toList();

  /// 清除所有工具（测试用）
  void clear() => _tools.clear();
}
