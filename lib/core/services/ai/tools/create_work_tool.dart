import 'tool_definition.dart';

/// 创建作品工具
class CreateWorkTool extends ToolDefinition {
  final Future<({String id, String name})> Function(
    String name, {
    String? type,
    String? description,
    int? targetWords,
  }) _createFn;

  CreateWorkTool({required createFn}) : _createFn = createFn;

  @override
  String get name => 'create_work';

  @override
  String get description => '创建新作品。指定作品名称即可创建一部新小说。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': '作品名称',
          },
          'type': {
            'type': 'string',
            'description': '作品类型，如：玄幻、都市、科幻、历史等',
          },
          'description': {
            'type': 'string',
            'description': '作品简介',
          },
          'target_words': {
            'type': 'integer',
            'description': '目标字数',
          },
        },
        'required': ['name'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final name = input['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return ToolResult.fail('缺少必要参数: name');
    }

    try {
      final result = await _createFn(
        name.trim(),
        type: (input['type'] as String?)?.trim(),
        description: (input['description'] as String?)?.trim(),
        targetWords: input['target_words'] as int?,
      );
      return ToolResult.ok(
        '已创建作品「${result.name}」，ID: ${result.id}',
        data: {'id': result.id, 'name': result.name},
      );
    } catch (e) {
      return ToolResult.fail('创建作品失败: $e');
    }
  }
}
