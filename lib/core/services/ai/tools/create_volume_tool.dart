import 'tool_definition.dart';

/// 创建卷工具
class CreateVolumeTool extends ToolDefinition {
  final Future<({String id, String name})> Function(
    String workId,
    String name, {
    int sortOrder,
  }) _createFn;

  CreateVolumeTool({required createFn}) : _createFn = createFn;

  @override
  String get name => 'create_volume';

  @override
  String get description => '为作品创建新卷。需要指定作品 ID 和卷名称。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'work_id': {
            'type': 'string',
            'description': '作品 ID',
          },
          'name': {
            'type': 'string',
            'description': '卷名称',
          },
          'sort_order': {
            'type': 'integer',
            'description': '排序序号，默认为 0',
          },
        },
        'required': ['work_id', 'name'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final workId = input['work_id'] as String?;
    final name = input['name'] as String?;
    if (workId == null || workId.isEmpty) {
      return ToolResult.fail('缺少必要参数: work_id');
    }
    if (name == null || name.trim().isEmpty) {
      return ToolResult.fail('缺少必要参数: name');
    }

    try {
      final result = await _createFn(
        workId,
        name.trim(),
        sortOrder: input['sort_order'] as int? ?? 0,
      );
      return ToolResult.ok(
        '已创建卷「${result.name}」，ID: ${result.id}',
        data: {'id': result.id, 'name': result.name},
      );
    } catch (e) {
      return ToolResult.fail('创建卷失败: $e');
    }
  }
}
