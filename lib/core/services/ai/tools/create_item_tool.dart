import 'tool_definition.dart';

/// 创建物品工具
class CreateItemTool extends ToolDefinition {
  final Future<({String id, String name})> Function({
    required String workId,
    required String name,
    String? type,
    String? rarity,
    String? description,
    List<String>? abilities,
    String? holderId,
  }) _createFn;

  CreateItemTool({required createFn}) : _createFn = createFn;

  @override
  String get name => 'create_item';

  @override
  String get description => '为作品创建新物品/道具。需要指定作品 ID 和物品名称。';

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
            'description': '物品名称',
          },
          'type': {
            'type': 'string',
            'description': '物品类型，如：武器、防具、丹药、法宝',
          },
          'rarity': {
            'type': 'string',
            'description': '稀有度，如：普通、稀有、传说',
          },
          'description': {
            'type': 'string',
            'description': '物品描述',
          },
          'abilities': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '能力/效果列表',
          },
          'holder_id': {
            'type': 'string',
            'description': '持有者角色 ID',
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
        rarity: (input['rarity'] as String?)?.trim(),
        description: (input['description'] as String?)?.trim(),
        abilities: (input['abilities'] as List<dynamic>?)?.cast<String>(),
        holderId: (input['holder_id'] as String?)?.trim(),
      );
      return ToolResult.ok(
        '已创建物品「${result.name}」，ID: ${result.id}',
        data: {'id': result.id, 'name': result.name},
      );
    } catch (e) {
      return ToolResult.fail('创建物品失败: $e');
    }
  }
}
