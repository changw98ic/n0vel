import 'tool_definition.dart';

/// 内容分析工具
/// 分析文风、情绪、节奏、视角等
class AnalyzeTool extends ToolDefinition {
  final Future<Map<String, dynamic>> Function(
    String content,
    String analysisType,
    Map<String, dynamic>? params,
  ) _analyzeFn;

  AnalyzeTool({required Future<Map<String, dynamic>> Function(
    String content,
    String analysisType,
    Map<String, dynamic>? params,
  ) analyzeFn}) : _analyzeFn = analyzeFn;

  @override
  String get name => 'analyze_content';

  @override
  String get description => '分析文本内容。支持文风分析、情绪分析、节奏分析、视角分析等。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description': '要分析的文本内容',
          },
          'analysis_type': {
            'type': 'string',
            'enum': ['style', 'emotion', 'pacing', 'perspective', 'comprehensive'],
            'description': '分析类型',
          },
          'chapter_id': {
            'type': 'string',
            'description': '章节 ID（可选，用于获取完整内容）',
          },
        },
        'required': ['content', 'analysis_type'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final content = input['content'] as String?;
    final analysisType = input['analysis_type'] as String? ?? 'comprehensive';

    if (content == null || content.isEmpty) {
      return ToolResult.fail('缺少必要参数: content');
    }

    try {
      final result = await _analyzeFn(content, analysisType, input);
      return ToolResult.ok(
        _formatAnalysis(result, analysisType),
        data: result,
      );
    } catch (e) {
      return ToolResult.fail('分析失败: $e');
    }
  }

  String _formatAnalysis(Map<String, dynamic> result, String type) {
    final buffer = StringBuffer();
    buffer.writeln('分析结果（${_typeLabel(type)}）：');

    result.forEach((key, value) {
      if (value is Map) {
        buffer.writeln('\n$key:');
        value.forEach((k, v) => buffer.writeln('  $k: $v'));
      } else {
        buffer.writeln('$key: $value');
      }
    });

    return buffer.toString();
  }

  String _typeLabel(String type) => switch (type) {
        'style' => '文风分析',
        'emotion' => '情绪分析',
        'pacing' => '节奏分析',
        'perspective' => '视角分析',
        'comprehensive' => '综合分析',
        _ => type,
      };
}
