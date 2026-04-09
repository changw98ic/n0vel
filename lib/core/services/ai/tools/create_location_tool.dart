import 'tool_definition.dart';

/// 创建地点工具
class CreateLocationTool extends ToolDefinition {
  final Future<({String id, String name})> Function({
    required String workId,
    required String name,
    String? type,
    String? parentId,
    String? description,
    List<String>? importantPlaces,
  }) _createFn;

  CreateLocationTool({required createFn}) : _createFn = createFn;

  @override
  String get name => 'create_location';

  @override
  String get description => '为作品创建新地点/场景。需要指定作品 ID 和地点名称。支持层级关系。';

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
            'description': '地点名称',
          },
          'type': {
            'type': 'string',
            'description': '地点类型，如：城市、秘境、宗门、山脉',
          },
          'parent_id': {
            'type': 'string',
            'description': '上级地点 ID（用于建立层级关系）',
          },
          'description': {
            'type': 'string',
            'description': '地点描述',
          },
          'important_places': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '重要地点/标志性建筑列表',
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
        workId: workId,
        name: name.trim(),
        type: (input['type'] as String?)?.trim(),
        parentId: (input['parent_id'] as String?)?.trim(),
        description: (input['description'] as String?)?.trim(),
        importantPlaces: (input['important_places'] as List<dynamic>?)?.cast<String>(),
      );
      return ToolResult.ok(
        '已创建地点「${result.name}」，ID: ${result.id}',
        data: {'id': result.id, 'name': result.name},
      );
    } catch (e) {
      return ToolResult.fail('创建地点失败: $e');
    }
  }
}
