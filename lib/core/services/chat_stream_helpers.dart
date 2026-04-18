part of 'chat_service.dart';

Future<void> _emitTypewriterChunks(
  StreamController<ChatStreamEvent> controller,
  String text,
) async {
  if (text.isEmpty) return;

  const charsPerSecond = 50;
  const chunkSize = 2;
  final delayMs = (chunkSize * 1000 / charsPerSecond).round();
  final runes = text.runes.toList();

  for (var i = 0; i < runes.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, runes.length);
    controller.add(ChatChunk(String.fromCharCodes(runes.sublist(i, end))));
    if (end < runes.length) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
}

String _friendlyChatToolName(String toolName) => switch (toolName) {
      'search_content' || 'search' => '搜索',
      'generate_content' || 'generate' => '生成',
      'analyze_content' || 'analyze' => '分析',
      'check_consistency' => '一致性检查',
      'extract_settings' || 'extract' => '提取设定',
      _ => toolName,
    };

String _buildToolStatusMessage(String toolName) =>
    '正在${_friendlyChatToolName(toolName)}...';

String _buildToolCompletedMessage(String toolName) =>
    '${_friendlyChatToolName(toolName)}完成';

String _formatAgentPlanThinking(List<String> steps) =>
    '执行计划 (${steps.length} 步):\n'
    '${steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}';

String _summarizeToolResult(ToolResult result) {
  if (!result.success) {
    return '错误: ${result.error}';
  }

  if (result.output.length > 100) {
    return '${result.output.substring(0, 100)}...';
  }

  return result.output;
}
