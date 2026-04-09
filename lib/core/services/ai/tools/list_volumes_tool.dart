import 'tool_definition.dart';

/// 列出作品下的所有卷工具
class ListVolumesTool extends ToolDefinition {
  final Future<List<Map<String, String>>> Function(String workId) _listFn;

  ListVolumesTool({required listFn}) : _listFn = listFn;

  @override
  String get name => 'list_volumes';

  @override
  String get description => '列出指定作品下的所有卷。需要指定作品 ID。如果不知道作品 ID，请先调用 list_works。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'work_id': {
            'type': 'string',
            'description': '作品 ID',
          },
        },
        'required': ['work_id'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final workId = input['work_id'] as String?;
    if (workId == null || workId.isEmpty) {
      return ToolResult.fail('缺少必要参数: work_id。如果不知道作品 ID，请先调用 list_works。');
    }

    try {
      final volumes = await _listFn(workId);
      if (volumes.isEmpty) {
        return ToolResult.ok('该作品下没有任何卷。请先使用 create_volume 创建一个卷。');
      }

      final buffer = StringBuffer('卷列表：\n');
      for (final v in volumes) {
        buffer.writeln('- ${v['name']}（ID: ${v['id']}，排序: ${v['sort_order']}）');
      }
      return ToolResult.ok(buffer.toString(), data: {
        'volumes': volumes,
      });
    } catch (e) {
      return ToolResult.fail('获取卷列表失败: $e');
    }
  }
}
