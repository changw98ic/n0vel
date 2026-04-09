import 'tool_definition.dart';

/// 更新章节内容工具
class UpdateChapterContentTool extends ToolDefinition {
  final Future<void> Function(String chapterId, String content, int wordCount)
      _updateFn;

  UpdateChapterContentTool({required updateFn}) : _updateFn = updateFn;

  @override
  String get name => 'update_chapter_content';

  @override
  String get description =>
      '将内容写入章节。创建章节后使用此工具写入正文内容。参数：chapter_id（章节 ID），content（正文内容）。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'chapter_id': {
            'type': 'string',
            'description': '章节 ID（create_chapter 返回的 ID）',
          },
          'content': {
            'type': 'string',
            'description': '章节正文内容',
          },
        },
        'required': ['chapter_id', 'content'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final chapterId = input['chapter_id'] as String?;
    final content = input['content'] as String?;
    if (chapterId == null || chapterId.isEmpty) {
      return ToolResult.fail('缺少必要参数: chapter_id');
    }
    if (content == null || content.trim().isEmpty) {
      return ToolResult.fail('缺少必要参数: content（章节内容不能为空）');
    }

    try {
      // 统计字数（中文按字符计算，英文按空格分词）
      final wordCount = content.trim().length;
      await _updateFn(chapterId, content.trim(), wordCount);
      return ToolResult.ok('已写入章节内容，共 $wordCount 字');
    } catch (e) {
      return ToolResult.fail('写入章节内容失败: $e');
    }
  }
}
