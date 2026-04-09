import 'tool_definition.dart';

/// 设定提取工具
/// 从文本中提取角色、地点、物品等设定信息
class ExtractTool extends ToolDefinition {
  final Future<Map<String, dynamic>> Function(
    String content,
    String extractType,
    Map<String, dynamic>? params,
  ) _extractFn;

  ExtractTool({required Future<Map<String, dynamic>> Function(
    String content,
    String extractType,
    Map<String, dynamic>? params,
  ) extractFn}) : _extractFn = extractFn;

  @override
  String get name => 'extract_settings';

  @override
  String get description => '从文本中提取设定信息。'
      '支持提取角色、地点、物品、时间线事件等。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description': '要提取的文本内容',
          },
          'extract_type': {
            'type': 'string',
            'enum': ['characters', 'locations', 'items', 'events', 'all'],
            'description': '提取类型',
          },
          'work_id': {
            'type': 'string',
            'description': '作品 ID（可选，用于关联已有设定）',
          },
        },
        'required': ['content', 'extract_type'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final content = input['content'] as String?;
    final extractType = input['extract_type'] as String? ?? 'all';

    if (content == null || content.isEmpty) {
      return ToolResult.fail('缺少必要参数: content');
    }

    try {
      final result = await _extractFn(content, extractType, input);

      final buffer = StringBuffer();
      buffer.writeln('提取结果（${_typeLabel(extractType)}）：');

      result.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          buffer.writeln('\n$key (${value.length} 项)：');
          for (final item in value.whereType<Map<String, dynamic>>()) {
            final name = item['name'] as String? ?? '未知';
            final description = item['description'] as String? ?? '';
            buffer.writeln('  - $name: $description');
          }
        } else if (value is List) {
          buffer.writeln('\n$key: 未找到相关内容');
        } else {
          buffer.writeln('$key: $value');
        }
      });

      return ToolResult.ok(buffer.toString(), data: result);
    } catch (e) {
      return ToolResult.fail('提取失败: $e');
    }
  }

  String _typeLabel(String type) => switch (type) {
        'characters' => '角色',
        'locations' => '地点',
        'items' => '物品',
        'events' => '时间线事件',
        'all' => '全部',
        _ => type,
      };
}
