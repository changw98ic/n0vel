import 'tool_definition.dart';

/// 文本生成工具
/// 续写、对话生成、自定义文本生成
class GenerateTool extends ToolDefinition {
  final Future<String> Function(
    String prompt,
    String mode,
    Map<String, dynamic>? params,
  ) _generateFn;

  GenerateTool({required Future<String> Function(
    String prompt,
    String mode,
    Map<String, dynamic>? params,
  ) generateFn}) : _generateFn = generateFn;

  @override
  String get name => 'generate_text';

  @override
  String get description => '生成小说文本。支持续写、对话生成、场景描写等模式。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'prompt': {
            'type': 'string',
            'description': '生成提示（如上下文、场景描述等）',
          },
          'mode': {
            'type': 'string',
            'enum': ['continuation', 'dialogue', 'scene', 'custom'],
            'description': '生成模式：continuation=续写，dialogue=对话，scene=场景描写，custom=自定义',
          },
          'style': {
            'type': 'string',
            'description': '风格要求（可选）',
          },
          'length': {
            'type': 'integer',
            'description': '目标字数（可选，默认500-1000字）',
          },
        },
        'required': ['prompt', 'mode'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final prompt = input['prompt'] as String?;
    final mode = input['mode'] as String? ?? 'custom';

    if (prompt == null || prompt.isEmpty) {
      return ToolResult.fail('缺少必要参数: prompt');
    }

    try {
      final result = await _generateFn(prompt, mode, input);
      return ToolResult.ok(result);
    } catch (e) {
      return ToolResult.fail('生成失败: $e');
    }
  }
}
