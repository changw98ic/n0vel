import 'tool_definition.dart';

/// 列出所有作品工具
class ListWorksTool extends ToolDefinition {
  final Future<List<Map<String, String>>> Function() _listFn;

  ListWorksTool({required listFn}) : _listFn = listFn;

  @override
  String get name => 'list_works';

  @override
  String get description => '列出所有作品。当不知道作品 ID 时，先调用此工具查看所有作品及其 ID。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    try {
      final works = await _listFn();
      if (works.isEmpty) {
        return ToolResult.ok('当前没有任何作品。请先使用 create_work 创建一个作品。');
      }

      final buffer = StringBuffer('作品列表：\n');
      for (final w in works) {
        final type = w['type'];
        buffer.writeln('- ${w['name']}（ID: ${w['id']}${type != null && type.isNotEmpty ? '，类型: $type' : ''}）');
      }
      return ToolResult.ok(buffer.toString(), data: {
        'works': works,
      });
    } catch (e) {
      return ToolResult.fail('获取作品列表失败: $e');
    }
  }
}
