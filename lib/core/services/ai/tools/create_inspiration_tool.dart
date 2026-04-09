import 'tool_definition.dart';

/// 创建素材/片段工具
class CreateInspirationTool extends ToolDefinition {
  static const _validCategories = [
    'idea',
    'reference',
    'character_sketch',
    'scene_fragment',
    'worldbuilding',
    'dialogue_snippet',
  ];

  static const _categoryLabels = {
    'idea': '灵感',
    'reference': '参考资料',
    'character_sketch': '人物速写',
    'scene_fragment': '场景片段',
    'worldbuilding': '世界观设定',
    'dialogue_snippet': '对白片段',
  };

  final Future<({String id, String title})> Function({
    required String title,
    required String content,
    String? workId,
    required String category,
    List<String>? tags,
    String? source,
  }) _createFn;

  CreateInspirationTool({required createFn}) : _createFn = createFn;

  @override
  String get name => 'create_inspiration';

  @override
  String get description => '创建灵感素材或写作片段。'
      '分类: idea=灵感, reference=参考资料, character_sketch=人物速写, '
      'scene_fragment=场景片段, worldbuilding=世界观设定, dialogue_snippet=对白片段';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '素材标题',
          },
          'content': {
            'type': 'string',
            'description': '素材内容',
          },
          'work_id': {
            'type': 'string',
            'description': '关联的作品 ID（可选）',
          },
          'category': {
            'type': 'string',
            'enum': _validCategories,
            'description': '分类: idea=灵感, reference=参考资料, character_sketch=人物速写, scene_fragment=场景片段, worldbuilding=世界观设定, dialogue_snippet=对白片段',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '标签列表',
          },
          'source': {
            'type': 'string',
            'description': '来源说明',
          },
        },
        'required': ['title', 'content', 'category'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final title = input['title'] as String?;
    final content = input['content'] as String?;
    final category = input['category'] as String?;

    if (title == null || title.trim().isEmpty) {
      return ToolResult.fail('缺少必要参数: title');
    }
    if (content == null || content.trim().isEmpty) {
      return ToolResult.fail('缺少必要参数: content');
    }
    if (category == null || category.isEmpty) {
      return ToolResult.fail('缺少必要参数: category');
    }

    final normalizedCategory = _validCategories.firstWhere(
      (c) => c.toLowerCase() == category.toLowerCase(),
      orElse: () => '',
    );
    if (normalizedCategory.isEmpty) {
      return ToolResult.fail('无效的 category 值: "$category"。可选值: ${_validCategories.join(", ")}');
    }

    try {
      final result = await _createFn(
        title: title.trim(),
        content: content,
        workId: (input['work_id'] as String?)?.trim(),
        category: normalizedCategory,
        tags: (input['tags'] as List<dynamic>?)?.cast<String>(),
        source: (input['source'] as String?)?.trim(),
      );
      return ToolResult.ok(
        '已创建${_categoryLabels[normalizedCategory] ?? normalizedCategory}「${result.title}」，ID: ${result.id}',
        data: {'id': result.id, 'title': result.title, 'category': normalizedCategory},
      );
    } catch (e) {
      return ToolResult.fail('创建素材失败: $e');
    }
  }
}
