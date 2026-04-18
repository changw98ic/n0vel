import 'tool_definition.dart';

/// 创建章节工具
/// 支持同时写入正文内容，一步完成创建+写入
class CreateChapterTool extends ToolDefinition {
  final Future<({String id, String title})> Function(
    String workId,
    String volumeId,
    String title, {
    int sortOrder,
    String? content,
  }) _createFn;

  CreateChapterTool({required createFn}) : _createFn = createFn;

  @override
  String get name => 'create_chapter';

  @override
  String get description =>
      '为作品创建新章节并写入正文内容。需要指定作品 ID、卷 ID、章节标题和正文内容。'
      '请在 content 参数中直接传入完整的章节正文。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'work_id': {
            'type': 'string',
            'description': '作品 ID',
          },
          'volume_id': {
            'type': 'string',
            'description': '卷 ID',
          },
          'title': {
            'type': 'string',
            'description': '章节标题',
          },
          'content': {
            'type': 'string',
            'description': '章节正文内容（必须填写，不能为空）',
          },
          'sort_order': {
            'type': 'integer',
            'description': '排序序号，默认自动追加到末尾',
          },
        },
        'required': ['work_id', 'volume_id', 'title', 'content'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final workId = input['work_id'] as String?;
    final volumeId = input['volume_id'] as String?;
    final title = input['title'] as String?;
    final content = input['content'] as String?;
    if (workId == null || workId.isEmpty) {
      return ToolResult.fail('缺少必要参数: work_id');
    }
    if (volumeId == null || volumeId.isEmpty) {
      return ToolResult.fail('缺少必要参数: volume_id');
    }
    if (title == null || title.trim().isEmpty) {
      return ToolResult.fail('缺少必要参数: title');
    }
    if (content == null || content.trim().isEmpty) {
      return ToolResult.fail(
          '缺少必要参数: content。创建章节时必须同时提供正文内容，不要创建空章节。');
    }

    try {
      final result = await _createFn(
        workId,
        volumeId,
        title.trim(),
        sortOrder: _coerceInt(input['sort_order']) ?? 0,
        content: content.trim(),
      );
      final wordCount = content.trim().length;
      return ToolResult.ok(
        '已创建章节「${result.title}」并写入正文，共 $wordCount 字',
        data: {'id': result.id, 'title': result.title},
      );
    } catch (e) {
      return ToolResult.fail('创建章节失败: $e');
    }
  }

  int? _coerceInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
