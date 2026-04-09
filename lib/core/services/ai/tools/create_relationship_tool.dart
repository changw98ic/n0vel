import 'tool_definition.dart';

/// 创建角色关系工具
class CreateRelationshipTool extends ToolDefinition {
  static const _validRelationTypes = [
    'enemy',
    'hostile',
    'neutral',
    'acquaintance',
    'friendly',
    'friend',
    'closeFriend',
    'lover',
    'family',
    'mentor',
    'rival',
  ];

  static const _relationLabels = {
    'enemy': '敌对',
    'hostile': '敌意',
    'neutral': '中立',
    'acquaintance': '相识',
    'friendly': '友好',
    'friend': '朋友',
    'closeFriend': '挚友',
    'lover': '恋人',
    'family': '亲人',
    'mentor': '师徒',
    'rival': '对手',
  };

  final Future<({String id, String relationType})> Function(
    String workId,
    String characterAId,
    String characterBId,
    String relationType,
  ) _createFn;

  CreateRelationshipTool({required createFn}) : _createFn = createFn;

  @override
  String get name => 'create_relationship';

  @override
  String get description => '创建两个角色之间的关系。需要指定作品 ID、两个角色 ID 和关系类型。'
      '关系类型: enemy=敌对, hostile=敌意, neutral=中立, acquaintance=相识, friendly=友好, '
      'friend=朋友, closeFriend=挚友, lover=恋人, family=亲人, mentor=师徒, rival=对手';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'work_id': {
            'type': 'string',
            'description': '作品 ID',
          },
          'character_a_id': {
            'type': 'string',
            'description': '角色 A 的 ID',
          },
          'character_b_id': {
            'type': 'string',
            'description': '角色 B 的 ID',
          },
          'relation_type': {
            'type': 'string',
            'enum': _validRelationTypes,
            'description': '关系类型',
          },
        },
        'required': ['work_id', 'character_a_id', 'character_b_id', 'relation_type'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final workId = input['work_id'] as String?;
    final characterAId = input['character_a_id'] as String?;
    final characterBId = input['character_b_id'] as String?;
    final relationType = input['relation_type'] as String?;

    if (workId == null || workId.isEmpty) {
      return ToolResult.fail('缺少必要参数: work_id');
    }
    if (characterAId == null || characterAId.isEmpty) {
      return ToolResult.fail('缺少必要参数: character_a_id');
    }
    if (characterBId == null || characterBId.isEmpty) {
      return ToolResult.fail('缺少必要参数: character_b_id');
    }
    if (relationType == null || relationType.isEmpty) {
      return ToolResult.fail('缺少必要参数: relation_type');
    }

    final normalizedType = _validRelationTypes.firstWhere(
      (t) => t.toLowerCase() == relationType.toLowerCase(),
      orElse: () => '',
    );
    if (normalizedType.isEmpty) {
      return ToolResult.fail('无效的 relation_type 值: "$relationType"。可选值: ${_validRelationTypes.join(", ")}');
    }

    try {
      final result = await _createFn(workId, characterAId, characterBId, normalizedType);
      return ToolResult.ok(
        '已创建关系（${_relationLabels[normalizedType] ?? normalizedType}），ID: ${result.id}',
        data: {'id': result.id, 'relation_type': normalizedType},
      );
    } catch (e) {
      return ToolResult.fail('创建关系失败: $e');
    }
  }
}
