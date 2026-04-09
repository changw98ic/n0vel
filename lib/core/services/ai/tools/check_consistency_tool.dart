import 'tool_definition.dart';

/// 一致性检查工具
/// 检查角色行为、时间线、设定等的一致性
class CheckConsistencyTool extends ToolDefinition {
  final Future<Map<String, dynamic>> Function(
    String workId,
    String checkType,
    Map<String, dynamic>? params,
  ) _checkFn;

  CheckConsistencyTool({required Future<Map<String, dynamic>> Function(
    String workId,
    String checkType,
    Map<String, dynamic>? params,
  ) checkFn}) : _checkFn = checkFn;

  @override
  String get name => 'check_consistency';

  @override
  String get description => '检查作品中的设定一致性。'
      '支持角色一致性、时间线一致性、设定冲突检测等。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'work_id': {
            'type': 'string',
            'description': '作品 ID',
          },
          'check_type': {
            'type': 'string',
            'enum': ['character', 'timeline', 'setting', 'all'],
            'description': '检查类型',
          },
          'content': {
            'type': 'string',
            'description': '要检查的文本内容（可选，不提供则检查整部作品）',
          },
          'chapter_id': {
            'type': 'string',
            'description': '章节 ID（可选，检查特定章节）',
          },
        },
        'required': ['work_id'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final workId = input['work_id'] as String?;
    final checkType = input['check_type'] as String? ?? 'all';

    if (workId == null) {
      return ToolResult.fail('缺少必要参数: work_id');
    }

    try {
      final result = await _checkFn(workId, checkType, input);

      final issues = result['issues'] as List<dynamic>? ?? [];
      final score = result['score'] as num?;

      final buffer = StringBuffer();
      buffer.writeln('一致性检查结果（${_typeLabel(checkType)}）：');
      if (score != null) {
        buffer.writeln('一致性评分: ${score.toStringAsFixed(1)}/10');
      }

      if (issues.isEmpty) {
        buffer.writeln('未发现一致性问题。');
      } else {
        buffer.writeln('发现 ${issues.length} 个问题：');
        for (final issue in issues.whereType<Map<String, dynamic>>()) {
          final severity = issue['severity'] as String? ?? 'info';
          final description = issue['description'] as String? ?? '';
          final emoji = severity == 'critical'
              ? '❗'
              : severity == 'warning'
                  ? '⚠️'
                  : 'ℹ️';
          buffer.writeln('$emoji [$severity] $description');
        }
      }

      return ToolResult.ok(buffer.toString(), data: result);
    } catch (e) {
      return ToolResult.fail('一致性检查失败: $e');
    }
  }

  String _typeLabel(String type) => switch (type) {
        'character' => '角色一致性',
        'timeline' => '时间线一致性',
        'setting' => '设定一致性',
        'all' => '全部',
        _ => type,
      };
}
