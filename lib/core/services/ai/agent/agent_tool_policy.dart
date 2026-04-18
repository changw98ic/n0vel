import '../tools/tool_definition.dart';
import '../tools/tool_registry.dart';

class AgentToolPolicy {
  const AgentToolPolicy._();

  static const _workIdFreeTools = {
    'create_work',
    'list_works',
    'generate_text',
    'analyze_content',
    'update_chapter_content',
  };

  static List<ToolDefinition> getAvailableTools(
    ToolRegistry toolRegistry,
    List<String>? allowedTools,
  ) {
    if (allowedTools != null) {
      return allowedTools
          .map((name) => toolRegistry.get(name))
          .whereType<ToolDefinition>()
          .toList();
    }
    return toolRegistry.all;
  }

  static bool isSimpleTask(String step, String originalTask) {
    final normalized = step.replaceAll(RegExp(r'[，。！？\s]'), '');
    final normalizedTask =
        originalTask.replaceAll(RegExp(r'[，。！？\s]'), '');
    return normalized == normalizedTask || normalized.contains(normalizedTask);
  }

  static bool toolsRequireWorkId(String toolName) =>
      !_workIdFreeTools.contains(toolName);

  static bool toolHasWorkIdParam(String toolName) =>
      !_workIdFreeTools.contains(toolName);
}
