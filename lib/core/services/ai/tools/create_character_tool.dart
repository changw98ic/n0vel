import 'tool_definition.dart';

/// 创建角色工具
class CreateCharacterTool extends ToolDefinition {
  static const _validTiers = [
    'protagonist',
    'majorAntagonist',
    'antagonist',
    'supporting',
    'minor',
  ];

  static const _tierLabels = {
    'protagonist': '主角',
    'majorAntagonist': '主要反派',
    'antagonist': '反派',
    'supporting': '配角',
    'minor': '龙套',
  };

  final Future<({String id, String name, String tier})> Function(
    String workId,
    String name,
    String tier, {
    List<String>? aliases,
    String? gender,
    String? age,
    String? identity,
    String? bio,
  }) _createFn;

  CreateCharacterTool({required createFn}) : _createFn = createFn;

  @override
  String get name => 'create_character';

  @override
  String get description => '为作品创建新角色。需要指定作品 ID、名称和角色等级（tier）。'
      'tier 可选值: protagonist=主角, majorAntagonist=主要反派, antagonist=反派, supporting=配角, minor=龙套';

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
            'description': '角色名称',
          },
          'tier': {
            'type': 'string',
            'enum': _validTiers,
            'description': '角色等级: protagonist=主角, majorAntagonist=主要反派, antagonist=反派, supporting=配角, minor=龙套',
          },
          'aliases': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '别名/曾用名列表',
          },
          'gender': {
            'type': 'string',
            'description': '性别',
          },
          'age': {
            'type': 'string',
            'description': '年龄',
          },
          'identity': {
            'type': 'string',
            'description': '身份，如：剑宗宗主、隐世高手',
          },
          'bio': {
            'type': 'string',
            'description': '人物简介',
          },
        },
        'required': ['work_id', 'name', 'tier'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final workId = input['work_id'] as String?;
    final name = input['name'] as String?;
    final tier = input['tier'] as String?;

    if (workId == null || workId.isEmpty) {
      return ToolResult.fail('缺少必要参数: work_id');
    }
    if (name == null || name.trim().isEmpty) {
      return ToolResult.fail('缺少必要参数: name');
    }
    if (tier == null || tier.isEmpty) {
      return ToolResult.fail('缺少必要参数: tier');
    }

    // 不区分大小写匹配
    final normalizedTier = _validTiers.firstWhere(
      (t) => t.toLowerCase() == tier.toLowerCase(),
      orElse: () => '',
    );
    if (normalizedTier.isEmpty) {
      return ToolResult.fail('无效的 tier 值: "$tier"。可选值: ${_validTiers.join(", ")}');
    }

    try {
      final result = await _createFn(
        workId,
        name.trim(),
        normalizedTier,
        aliases: (input['aliases'] as List<dynamic>?)?.cast<String>(),
        gender: (input['gender'] as String?)?.trim(),
        age: (input['age'] as String?)?.trim(),
        identity: (input['identity'] as String?)?.trim(),
        bio: (input['bio'] as String?)?.trim(),
      );
      return ToolResult.ok(
        '已创建角色「${result.name}」（${_tierLabels[result.tier] ?? result.tier}），ID: ${result.id}',
        data: {'id': result.id, 'name': result.name, 'tier': result.tier},
      );
    } catch (e) {
      return ToolResult.fail('创建角色失败: $e');
    }
  }
}
