part of 'chat_service.dart';

const _defaultChatSystemPrompt = '你是一位专业的小说写作助手，请与用户进行友好的对话交流。';
const _entityFormatInstructions = [
  '当用户要求创建角色、地点、物品或势力时，请在回复中使用以下格式输出实体数据：',
  '```entity',
  '{"type":"character/location/item/faction","name":"名称","fields":{具体属性}}',
  '```',
  '然后再用自然语言补充说明。',
];
const _summaryPrefix = '以下是之前对话的摘要';
const _titleGeneratorSystemPrompt =
    '你是一个标题生成器。根据用户消息生成一个简短、概括性的对话标题。只输出标题本身，不要加引号或其他格式。';

String _buildChatSystemPrompt(
  _ConversationContext context, {
  String? preflightPromptSection,
}) {
  final buffer = StringBuffer();
  buffer.writeln(context.systemPrompt ?? _defaultChatSystemPrompt);
  if (preflightPromptSection != null && preflightPromptSection.trim().isNotEmpty) {
    buffer.writeln();
    buffer.writeln(preflightPromptSection.trim());
  }
  buffer.writeln();
  for (final line in _entityFormatInstructions) {
    buffer.writeln(line);
  }

  final referenceContent = context.contextContent;
  if (referenceContent != null && referenceContent.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('---参考资料---');
    buffer.writeln(referenceContent);
    buffer.writeln('---参考资料结束---');
  }

  for (final msg in context.history) {
    if (msg.role == 'system' && msg.content.startsWith(_summaryPrefix)) {
      buffer.writeln();
      buffer.write(msg.content);
    }
  }

  return buffer.toString();
}

String _buildChatUserPrompt(
  _ConversationContext context,
  String currentUserMsg,
) {
  final buffer = StringBuffer();
  final historyMessages = context.history.where(_shouldIncludeInUserPrompt);

  if (historyMessages.isNotEmpty) {
    buffer.writeln('---对话历史---');
    for (final msg in historyMessages) {
      buffer.writeln('[${_chatRoleLabel(msg.role)}]: ${msg.content}');
    }
    buffer.writeln('---对话历史结束---');
    buffer.writeln();
  }

  buffer.writeln(currentUserMsg);
  return buffer.toString();
}

bool _shouldIncludeInUserPrompt(cm.ChatMessage message) =>
    message.role != 'system' || !message.content.startsWith(_summaryPrefix);

String _chatRoleLabel(String role) => switch (role) {
      'user' => '用户',
      'assistant' => '助手',
      'tool' => '工具',
      _ => role,
    };

String _buildTitlePrompt(String firstUserMessage) =>
    '请为以下对话生成一个简短的标题（不超过10个字）：\n\n$firstUserMessage';

String _normalizeGeneratedTitle(String rawTitle) {
  final title = rawTitle.trim();
  if (title.length <= 30) return title;
  return '${title.substring(0, 30)}...';
}

int _estimateChatHistoryTokens(List<cm.ChatMessage> history) =>
    _estimateChatTokensFromString(history.map((m) => m.content).join('\n'));

int _estimateChatTokensFromString(String text) {
  final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
  final other = text.length - chinese;
  return (chinese * 0.67 + other * 0.25).ceil();
}
