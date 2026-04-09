import 'tool_definition.dart';

/// 创建势力工具
class CreateFactionTool extends ToolDefinition {
  final Future<({String id, String name})> Function({
    required String workId,
    required String name,
    String? type,
    String? description,
    List<String>? traits,
    String? leaderId,
  }) _createFn;

  CreateFactionTool({required createFn}) : _createFn = createFn;

  @override
  String get name => 'create_faction';

  @override
  String get description => '为作品创建新势力/组织。需要指定作品 ID 和势力名称。';

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
            'description': '势力名称',
          },
          'type': {
            'type': 'string',
            'description': '势力类型，如：宗门、家族、王朝、商会',
          },
          'description': {
            'type': 'string',
            'description': '势力描述',
          },
          'traits': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '势力特征列表',
          },
          'leader_id': {
            'type': 'string',
            'description': '首领角色 ID',
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
        description: (input['description'] as String?)?.trim(),
        traits: (input['traits'] as List<dynamic>?)?.cast<String>(),
        leaderId: (input['leader_id'] as String?)?.trim(),
      );
      return ToolResult.ok(
        '已创建势力「${result.name}」，ID: ${result.id}',
        data: {'id': result.id, 'name': result.name},
      );
    } catch (e) {
      return ToolResult.fail('创建势力失败: $e');
    }
  }
}
