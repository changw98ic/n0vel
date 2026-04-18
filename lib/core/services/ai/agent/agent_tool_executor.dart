import '../ai_service.dart';
import '../tools/tool_definition.dart';
import '../tools/tool_registry.dart';
import 'agent_tool_policy.dart';

class AgentToolExecutionResult {
  final ToolResult result;
  final String toolMessage;
  final String currentWorkId;
  final Map<String, String> keyResults;

  const AgentToolExecutionResult({
    required this.result,
    required this.toolMessage,
    required this.currentWorkId,
    this.keyResults = const {},
  });
}

class AgentToolExecutor {
  const AgentToolExecutor._();

  static Future<AgentToolExecutionResult> execute({
    required ToolRegistry toolRegistry,
    required ToolCall toolCall,
    required String currentWorkId,
  }) async {
    final tool = toolRegistry.get(toolCall.name);
    if (tool == null) {
      final result = ToolResult.fail('工具 ${toolCall.name} 未注册。');
      return AgentToolExecutionResult(
        result: result,
        toolMessage: '错误: 工具 ${toolCall.name} 未注册。',
        currentWorkId: currentWorkId,
      );
    }

    if (currentWorkId.isEmpty &&
        AgentToolPolicy.toolsRequireWorkId(toolCall.name)) {
      final result = ToolResult.fail(
        '当前缺少 work_id，请先调用 list_works 或 create_work。',
      );
      return AgentToolExecutionResult(
        result: result,
        toolMessage: '错误: 当前缺少 work_id，请先调用 list_works 或 create_work。',
        currentWorkId: currentWorkId,
      );
    }

    final args = Map<String, dynamic>.from(toolCall.arguments);
    if (currentWorkId.isNotEmpty &&
        AgentToolPolicy.toolHasWorkIdParam(toolCall.name) &&
        (args['work_id'] == null || (args['work_id'] as String).isEmpty)) {
      args['work_id'] = currentWorkId;
    }

    final result = await tool.execute(args);
    var nextWorkId = currentWorkId;
    final keyResults = <String, String>{};

    if (toolCall.name == 'create_work' && result.success && result.data != null) {
      final createdId = result.data!['id'] as String?;
      if (createdId != null && createdId.isNotEmpty) {
        nextWorkId = createdId;
        keyResults['work_id'] = createdId;
        keyResults['work_name'] = result.data!['name']?.toString() ?? '';
      }
    }

    if (result.success && result.data != null) {
      for (final entry in result.data!.entries) {
        if (entry.key == 'id') {
          keyResults['${toolCall.name}_id'] = entry.value.toString();
        }
        if (entry.key == 'name') {
          keyResults['${toolCall.name}_name'] = entry.value.toString();
        }
      }
    }

    return AgentToolExecutionResult(
      result: result,
      toolMessage: result.success ? result.output : '错误: ${result.error}',
      currentWorkId: nextWorkId,
      keyResults: keyResults,
    );
  }
}
