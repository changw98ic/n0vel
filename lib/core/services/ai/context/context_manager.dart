import '../ai_service.dart';
import '../models/model_tier.dart';

/// 聊天消息
class ChatMessage {
  final String role; // system / user / assistant / tool
  final String content;
  final String? toolCallId;
  final Map<String, dynamic>? toolCall;

  const ChatMessage({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolCall,
  });

  ChatMessage copyWith({String? content}) => ChatMessage(
        role: role,
        content: content ?? this.content,
        toolCallId: toolCallId,
        toolCall: toolCall,
      );

  /// 估算 token 数量
  int get estimatedTokens {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(content).length;
    final other = content.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }
}

/// 压缩后的上下文
class CompactedContext {
  /// 早期对话摘要
  final String summary;

  /// 保留的最近消息
  final List<ChatMessage> recent;

  /// 估算总 token 数
  final int estimatedTokens;

  /// 是否进行了压缩
  final bool wasCompacted;

  const CompactedContext({
    required this.summary,
    required this.recent,
    required this.estimatedTokens,
    required this.wasCompacted,
  });
}

/// 模型上下文窗口大小配置
const Map<String, int> modelContextWindows = {
  'gpt-4-turbo': 128000,
  'gpt-4': 8192,
  'gpt-3.5-turbo': 16385,
  'claude-3-opus': 200000,
  'claude-3-sonnet': 200000,
  'claude-3-haiku': 200000,
  'claude-3-5-sonnet': 200000,
};

/// 上下文管理器
/// 负责管理对话历史的 token 预算和自动压缩
class ContextManager {
  final AIService _aiService;

  /// 保留最近 N 轮对话不压缩
  final int keepRecentTurns;

  /// 默认保留的轮数
  static const int defaultKeepRecentTurns = 6;

  ContextManager({
    required AIService aiService,
    this.keepRecentTurns = defaultKeepRecentTurns,
  }) : _aiService = aiService;

  /// 估算消息列表总 token 数
  int estimateTotalTokens(List<ChatMessage> messages) {
    return messages.fold(0, (sum, m) => sum + m.estimatedTokens);
  }

  /// 获取模型的上下文窗口大小
  int getContextWindow(String modelName) {
    // 精确匹配或模糊匹配
    if (modelContextWindows.containsKey(modelName)) {
      return modelContextWindows[modelName]!;
    }
    // 模糊匹配
    for (final entry in modelContextWindows.entries) {
      if (modelName.contains(entry.key) || entry.key.contains(modelName)) {
        return entry.value;
      }
    }
    // 默认 8K
    return 8192;
  }

  /// 检查是否需要压缩
  bool needsCompact(
    List<ChatMessage> messages,
    String modelName, {
    int reserveTokens = 4096,
  }) {
    final window = getContextWindow(modelName);
    final used = estimateTotalTokens(messages);
    return used > (window - reserveTokens);
  }

  /// 压缩对话历史
  /// 策略：保留最近 N 轮 + 用 AI 生成早期内容的摘要
  Future<CompactedContext> compact({
    required List<ChatMessage> messages,
    required String modelName,
    int reserveTokens = 4096,
  }) async {
    // 如果消息数不超过保留轮数，不需要压缩
    if (messages.length <= keepRecentTurns) {
      return CompactedContext(
        summary: '',
        recent: messages,
        estimatedTokens: estimateTotalTokens(messages),
        wasCompacted: false,
      );
    }

    // 分割：早期消息 vs 最近消息
    final splitIndex = messages.length - keepRecentTurns;
    final earlyMessages = messages.sublist(0, splitIndex);
    final recentMessages = messages.sublist(splitIndex);

    // 生成早期消息的摘要
    final summary = await _generateSummary(earlyMessages);
    final summaryMessage = ChatMessage(
      role: 'system',
      content: '以下是之前对话的摘要：\n$summary',
    );

    final compactedMessages = [summaryMessage, ...recentMessages];

    return CompactedContext(
      summary: summary,
      recent: compactedMessages,
      estimatedTokens: estimateTotalTokens(compactedMessages),
      wasCompacted: true,
    );
  }

  /// 使用 AI 生成对话摘要
  Future<String> _generateSummary(List<ChatMessage> messages) async {
    final buffer = StringBuffer();
    for (final m in messages) {
      buffer.writeln('[${m.role}]: ${m.content}');
      if (buffer.length > 8000) break; // 限制输入长度
    }

    try {
      final response = await _aiService.generate(
        prompt: buffer.toString(),
        config: AIRequestConfig(
          function: AIFunction.review,
          systemPrompt: _compactPrompt,
          userPrompt: buffer.toString(),
          useCache: false,
          stream: false,
        ),
      );
      return response.content;
    } catch (_) {
      // 如果 AI 摘要失败，返回简单的拼接摘要
      return messages
          .map((m) => '[${m.role}]: ${m.content.substring(0, m.content.length.clamp(0, 100))}...')
          .join('\n');
    }
  }

  /// 压缩提示模板
  static const _compactPrompt = '请将以下对话历史压缩为简洁摘要。'
      '必须保留以下关键信息：\n'
      '1. 角色设定和性格特征\n'
      '2. 重要情节点和决策\n'
      '3. 已确认的世界观设定\n'
      '4. 用户明确表达的偏好\n\n'
      '摘要应简洁但完整，不超过 500 字。';
}
