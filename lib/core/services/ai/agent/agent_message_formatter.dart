import '../ai_service.dart';

class AgentMessageBundle {
  final String systemMessage;
  final List<ChatMessage> nonSystemMessages;
  final String userMessage;
  final bool isSingleUserMessage;

  const AgentMessageBundle({
    required this.systemMessage,
    required this.nonSystemMessages,
    required this.userMessage,
    required this.isSingleUserMessage,
  });
}

class AgentMessageFormatter {
  const AgentMessageFormatter._();

  static AgentMessageBundle bundle(List<ChatMessage> messages) {
    final systemMessage = messages
        .where((message) => message.role == 'system')
        .map((message) => message.content)
        .join('\n\n');

    final nonSystemMessages =
        messages.where((message) => message.role != 'system').toList();

    final isSingleUserMessage =
        nonSystemMessages.length == 1 &&
        nonSystemMessages.first.role == 'user';

    final userMessage = isSingleUserMessage
        ? nonSystemMessages.first.content
        : nonSystemMessages
              .map((message) => '[${message.role}]: ${message.content}')
              .join('\n\n');

    return AgentMessageBundle(
      systemMessage: systemMessage,
      nonSystemMessages: nonSystemMessages,
      userMessage: userMessage,
      isSingleUserMessage: isSingleUserMessage,
    );
  }
}
