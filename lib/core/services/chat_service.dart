import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/chat/data/chat_repository.dart';
import '../../features/chat/domain/chat_message_entity.dart';
import 'ai/agent/agent_service.dart';
import 'entity_creation_service.dart';
import 'ai/ai_service.dart';
import 'ai/context/context_manager.dart' as cm;
import 'ai/models/model_tier.dart';

// ---------------------------------------------------------------------------
// Stream events
// ---------------------------------------------------------------------------

/// ChatService 事件流基类
sealed class ChatStreamEvent {}

/// 流式文本块
class ChatChunk extends ChatStreamEvent {
  final String chunk;
  ChatChunk(this.chunk);
}

/// 生成完成
class ChatComplete extends ChatStreamEvent {
  final String fullContent;
  final int inputTokens;
  final int outputTokens;
  ChatComplete({
    required this.fullContent,
    required this.inputTokens,
    required this.outputTokens,
  });
}

/// 生成错误
class ChatError extends ChatStreamEvent {
  final String error;
  ChatError(this.error);
}

/// AI 提议创建实体（Phase 4 使用）
class ChatEntityProposal extends ChatStreamEvent {
  final String entityType;
  final String name;
  final Map<String, dynamic> fields;
  ChatEntityProposal({
    required this.entityType,
    required this.name,
    required this.fields,
  });
}

/// 工具调用状态
class ChatToolStatus extends ChatStreamEvent {
  final String toolName;
  final String statusMessage;
  final bool isCompleted;
  ChatToolStatus({
    required this.toolName,
    required this.statusMessage,
    this.isCompleted = false,
  });
}

/// AI 思考过程
class ChatThinking extends ChatStreamEvent {
  final String thought;
  ChatThinking(this.thought);
}

/// 工具执行结果摘要
class ChatToolResult extends ChatStreamEvent {
  final String toolName;
  final String summary;
  final bool success;
  ChatToolResult({
    required this.toolName,
    required this.summary,
    required this.success,
  });
}

// ---------------------------------------------------------------------------
// ChatService
// ---------------------------------------------------------------------------

/// 对话服务
/// 桥接 AIService + ContextManager + ChatRepository + AgentService
class ChatService extends GetxService {
  final AIService _aiService;
  final cm.ContextManager _contextManager;
  final ChatRepository _chatRepository;
  final AgentService? _agentService;

  /// 内存中的对话上下文缓存（conversationId → messages）
  final _contextCache = <String, List<cm.ChatMessage>>{};

  ChatService({
    required AIService aiService,
    required cm.ContextManager contextManager,
    required ChatRepository chatRepository,
    AgentService? agentService,
  })  : _aiService = aiService,
        _contextManager = contextManager,
        _chatRepository = chatRepository,
        _agentService = agentService;

  // ---------------------------------------------------------------------------
  // Conversation CRUD
  // ---------------------------------------------------------------------------

  /// 获取最近对话列表
  Future<List<ChatConversationEntity>> getRecentConversations({
    String? workId,
    int limit = 50,
  }) async {
    final conversations = await _chatRepository.getConversations(workId: workId);
    return conversations.take(limit).toList();
  }

  /// 创建新对话
  Future<ChatConversationEntity> createConversation({
    String? workId,
    required String title,
    String source = 'standalone',
  }) async {
    final conv = await _chatRepository.createConversation(
      workId: workId,
      title: title,
      source: source,
    );
    _contextCache[conv.id] = [];
    return conv;
  }

  /// 删除对话
  Future<void> deleteConversation(String id) async {
    _contextCache.remove(id);
    await _chatRepository.deleteConversation(id);
  }

  /// 更新对话标题
  Future<void> updateTitle(String id, String title) async {
    await _chatRepository.updateTitle(id, title);
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// 获取对话消息（优先从缓存，否则从 DB 加载）
  Future<List<ChatMessageEntity>> loadMessages(String conversationId) async {
    final messages = await _chatRepository.getMessages(conversationId);

    // 同步到内存缓存
    _contextCache[conversationId] =
        messages.map((m) => m.toContextMessage()).toList();

    return messages;
  }

  // ---------------------------------------------------------------------------
  // Send message (non-streaming, for editor chat)
  // ---------------------------------------------------------------------------

  /// 发送消息并等待完整响应
  Future<ChatMessageEntity> sendMessageSync({
    required String conversationId,
    required String userMessage,
    String? systemPrompt,
    String? contextContent,
  }) async {
    // 持久化用户消息
    await _chatRepository.addMessage(
      conversationId: conversationId,
      role: 'user',
      content: userMessage,
    );

    // 构建上下文
    final context = await _buildContext(
      conversationId: conversationId,
      systemPrompt: systemPrompt,
      contextContent: contextContent,
    );

    // 调用 AI
    final response = await _aiService.generate(
      prompt: _buildUserPrompt(context, userMessage),
      config: AIRequestConfig(
        function: AIFunction.chat,
        systemPrompt: _buildSystemPrompt(context),
        userPrompt: _buildUserPrompt(context, userMessage),
        useCache: false,
        stream: false,
      ),
    );

    // 持久化助手消息
    final assistantMsg = await _chatRepository.addMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: response.content,
    );

    // 更新内存缓存
    final cache = _contextCache[conversationId] ?? [];
    cache.add(cm.ChatMessage(role: 'user', content: userMessage));
    cache.add(cm.ChatMessage(role: 'assistant', content: response.content));
    _contextCache[conversationId] = cache;

    return assistantMsg;
  }

  // ---------------------------------------------------------------------------
  // Send message (streaming, for standalone chat)
  // ---------------------------------------------------------------------------

  /// 发送消息并返回流式响应
  Stream<ChatStreamEvent> sendMessageStream({
    required String conversationId,
    required String userMessage,
    String? systemPrompt,
    String? contextContent,
  }) {
    final controller = StreamController<ChatStreamEvent>();

    _executeStream(
      controller: controller,
      conversationId: conversationId,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      contextContent: contextContent,
    );

    return controller.stream;
  }

  Future<void> _executeStream({
    required StreamController<ChatStreamEvent> controller,
    required String conversationId,
    required String userMessage,
    String? systemPrompt,
    String? contextContent,
  }) async {
    try {
      debugPrint('[ChatService] 普通流式模式开始 (convId: $conversationId)');

      // 持久化用户消息
      await _chatRepository.addMessage(
        conversationId: conversationId,
        role: 'user',
        content: userMessage,
      );

      // 构建上下文
      final context = await _buildContext(
        conversationId: conversationId,
        systemPrompt: systemPrompt,
        contextContent: contextContent,
      );

      // 更新内存缓存
      final cache = _contextCache[conversationId] ?? [];
      cache.add(cm.ChatMessage(role: 'user', content: userMessage));

      // 流式调用 AI
      final stream = _aiService.generateStream(
        prompt: _buildUserPrompt(context, userMessage),
        config: AIRequestConfig(
          function: AIFunction.chat,
          systemPrompt: _buildSystemPrompt(context),
          userPrompt: _buildUserPrompt(context, userMessage),
          useCache: false,
          stream: true,
        ),
      );

      final buffer = StringBuffer();

      await for (final chunk in stream) {
        buffer.write(chunk);
        controller.add(ChatChunk(chunk));
      }

      final fullContent = buffer.toString();

      // Estimate tokens from content (streaming providers may not return usage)
      final inputTokens = _estimateTokens(context.history);
      final outputTokens = _estimateTokensFromString(fullContent);

      // 持久化助手消息
      await _chatRepository.addMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: fullContent,
      );

      // 更新内存缓存
      cache.add(cm.ChatMessage(role: 'assistant', content: fullContent));
      _contextCache[conversationId] = cache;

      controller.add(ChatComplete(
        fullContent: fullContent,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      ));

      // 检测实体创建意图
      final entityResult =
          EntityCreationService.detectEntityInResponse(fullContent);
      if (entityResult != null) {
        controller.add(ChatEntityProposal(
          entityType: entityResult.type.name,
          name: entityResult.name,
          fields: entityResult.fields,
        ));
      }
    } catch (e) {
      controller.add(ChatError(e.toString()));
    } finally {
      await controller.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Send message with tool calling (streaming)
  // ---------------------------------------------------------------------------

  /// 发送消息并使用 Agent 工具调用
  /// 当 AgentService 可用且有 workId 时使用此方法
  Stream<ChatStreamEvent> sendMessageStreamWithTools({
    required String conversationId,
    required String userMessage,
    required String workId,
    String? systemPrompt,
  }) {
    final controller = StreamController<ChatStreamEvent>();

    _executeToolStream(
      controller: controller,
      conversationId: conversationId,
      userMessage: userMessage,
      workId: workId,
      systemPrompt: systemPrompt,
    );

    return controller.stream;
  }

  Future<void> _executeToolStream({
    required StreamController<ChatStreamEvent> controller,
    required String conversationId,
    required String userMessage,
    required String workId,
    String? systemPrompt,
  }) async {
    try {
      // 持久化用户消息
      await _chatRepository.addMessage(
        conversationId: conversationId,
        role: 'user',
        content: userMessage,
      );

      // 构建对话历史（用于 Agent 上下文）
      final dbMessages =
          await _chatRepository.getMessages(conversationId);
      final history = dbMessages.map((m) => m.toContextMessage()).toList();

      // 更新内存缓存
      _contextCache[conversationId] = history;

      if (_agentService == null) {
        // 没有 AgentService，降级为普通流式
        debugPrint('[ChatService] AgentService 不可用，降级为普通流式');
        await _executeStream(
          controller: controller,
          conversationId: conversationId,
          userMessage: userMessage,
          systemPrompt: systemPrompt,
        );
        return;
      }

      // 使用 AgentService 执行工具调用
      debugPrint('[ChatService] 使用 Agent 工具模式 (workId: $workId)');
      final agentStream = _agentService.run(
        task: userMessage,
        workId: workId,
        tier: ModelTier.middle,
        conversationHistory: history,
      );

      String fullContent = '';
      int totalInputTokens = 0;
      int totalOutputTokens = 0;
      String lastToolName = '';

      await for (final event in agentStream) {
        switch (event) {
          case AgentThinking(:final thought):
            controller.add(ChatThinking(thought));
          case AgentAction(:final toolName):
            lastToolName = toolName;
            controller.add(ChatToolStatus(
              toolName: toolName,
              statusMessage: '正在${_friendlyToolName(toolName)}...',
              isCompleted: false,
            ));
          case AgentObservation(:final result):
            controller.add(ChatToolResult(
              toolName: lastToolName,
              summary: result.success
                  ? (result.output.length > 100
                      ? '${result.output.substring(0, 100)}...'
                      : result.output)
                  : '错误: ${result.error}',
              success: result.success,
            ));
            controller.add(ChatToolStatus(
              toolName: lastToolName,
              statusMessage: '${_friendlyToolName(lastToolName)}完成',
              isCompleted: true,
            ));
          case AgentResponseChunk():
            fullContent += event.chunk;
            controller.add(ChatChunk(event.chunk));
          case AgentResponse():
            fullContent = event.content;
            totalInputTokens = event.totalInputTokens;
            totalOutputTokens = event.totalOutputTokens;
            // 打字机效果：每秒 ~50 字
            await _emitTypewriter(controller, event.content);
          case AgentError(:final error):
            controller.add(ChatError(error));
        }
      }

      if (fullContent.isNotEmpty) {
        // 持久化助手消息
        await _chatRepository.addMessage(
          conversationId: conversationId,
          role: 'assistant',
          content: fullContent,
        );

        // 更新内存缓存
        final cache = _contextCache[conversationId] ?? [];
        cache.add(cm.ChatMessage(role: 'user', content: userMessage));
        cache.add(cm.ChatMessage(role: 'assistant', content: fullContent));
        _contextCache[conversationId] = cache;

        controller.add(ChatComplete(
          fullContent: fullContent,
          inputTokens: totalInputTokens,
          outputTokens: totalOutputTokens,
        ));

        // 检测实体创建意图
        final entityResult =
            EntityCreationService.detectEntityInResponse(fullContent);
        if (entityResult != null) {
          controller.add(ChatEntityProposal(
            entityType: entityResult.type.name,
            name: entityResult.name,
            fields: entityResult.fields,
          ));
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ChatService] Agent 工具模式失败: $e');
      debugPrint('[ChatService] $stackTrace');
      controller.add(ChatError(e.toString()));
    } finally {
      await controller.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Title generation
  // ---------------------------------------------------------------------------

  /// 根据第一条消息自动生成对话标题
  Future<void> generateTitle(String conversationId) async {
    try {
      final messages = await _chatRepository.getMessages(conversationId);
      if (messages.isEmpty) return;

      final firstUserMsg = messages.firstWhere(
        (m) => m.role == 'user',
        orElse: () => messages.first,
      );

      final response = await _aiService.generate(
        prompt: '请为以下对话生成一个简短的标题（不超过10个字）：\n\n${firstUserMsg.content}',
        config: AIRequestConfig(
          function: AIFunction.chat,
          systemPrompt: '你是一个标题生成器。根据用户消息生成一个简短、概括性的对话标题。只输出标题本身，不要加引号或其他格式。',
          userPrompt: firstUserMsg.content,
          useCache: false,
          stream: false,
        ),
      );

      var title = response.content.trim();
      if (title.length > 30) title = '${title.substring(0, 30)}...';

      await _chatRepository.updateTitle(conversationId, title);
    } catch (e) {
      debugPrint('[ChatService] 生成标题失败: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Context management
  // ---------------------------------------------------------------------------

  /// 清除内存缓存
  void clearCache(String conversationId) {
    _contextCache.remove(conversationId);
  }

  /// 清除所有缓存
  void clearAllCache() {
    _contextCache.clear();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// 以打字机效果逐块发送文本（~50 字/秒）
  /// 使用 runes 避免在 UTF-16 代理对中间切割
  Future<void> _emitTypewriter(
    StreamController<ChatStreamEvent> controller,
    String text,
  ) async {
    if (text.isEmpty) return;
    const charsPerSecond = 50;
    const chunkSize = 2; // 每次 2 个 Unicode 码点
    final delayMs = (chunkSize * 1000 / charsPerSecond).round(); // 40ms

    final runes = text.runes.toList();
    for (var i = 0; i < runes.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, runes.length);
      final chunk = String.fromCharCodes(runes.sublist(i, end));
      controller.add(ChatChunk(chunk));
      if (end < runes.length) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  /// 工具名称到友好中文名的映射
  static String _friendlyToolName(String toolName) => switch (toolName) {
        'search_content' || 'search' => '搜索',
        'generate_content' || 'generate' => '生成',
        'analyze_content' || 'analyze' => '分析',
        'check_consistency' => '一致性检查',
        'extract_settings' || 'extract' => '提取设定',
        _ => toolName,
      };

  /// 构建对话上下文（从 DB 加载历史消息，执行压缩）
  Future<_ConversationContext> _buildContext({
    required String conversationId,
    String? systemPrompt,
    String? contextContent,
  }) async {
    // 从 DB 加载消息
    final dbMessages =
        await _chatRepository.getMessages(conversationId);
    var contextMessages =
        dbMessages.map((m) => m.toContextMessage()).toList();

    // 同步到缓存
    _contextCache[conversationId] = contextMessages;

    // 上下文压缩检查
    if (contextMessages.length > 6) {
      final needsCompact =
          _contextManager.needsCompact(contextMessages, '');
      if (needsCompact) {
        final compacted = await _contextManager.compact(
          messages: contextMessages,
          modelName: '',
        );
        contextMessages = compacted.recent;
        _contextCache[conversationId] = contextMessages;
      }
    }

    return _ConversationContext(
      systemPrompt: systemPrompt,
      contextContent: contextContent,
      history: contextMessages,
    );
  }

  String _buildSystemPrompt(_ConversationContext context) {
    final buffer = StringBuffer();
    buffer.writeln(context.systemPrompt ??
        '你是一位专业的小说写作助手，请与用户进行友好的对话交流。');
    buffer.writeln();
    buffer.writeln(
        '当用户要求创建角色、地点、物品或势力时，请在回复中使用以下格式输出实体数据：');
    buffer.writeln('```entity');
    buffer.writeln(
        '{"type":"character/location/item/faction","name":"名称","fields":{具体属性}}');
    buffer.writeln('```');
    buffer.writeln('然后再用自然语言补充说明。');

    if (context.contextContent != null &&
        context.contextContent!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('---参考资料---');
      buffer.writeln(context.contextContent);
      buffer.writeln('---参考资料结束---');
    }

    // 添加历史摘要
    for (final msg in context.history) {
      if (msg.role == 'system' &&
          msg.content.startsWith('以下是之前对话的摘要')) {
        buffer.writeln();
        buffer.write(msg.content);
      }
    }

    return buffer.toString();
  }

  String _buildUserPrompt(_ConversationContext context, String currentUserMsg) {
    final buffer = StringBuffer();

    // 添加对话历史（排除 system 消息和压缩摘要）
    final historyMessages = context.history
        .where((m) =>
            m.role != 'system' ||
            !m.content.startsWith('以下是之前对话的摘要'))
        .toList();

    if (historyMessages.isNotEmpty) {
      buffer.writeln('---对话历史---');
      for (final msg in historyMessages) {
        final label = switch (msg.role) {
          'user' => '用户',
          'assistant' => '助手',
          'tool' => '工具',
          _ => msg.role,
        };
        buffer.writeln('[$label]: ${msg.content}');
      }
      buffer.writeln('---对话历史结束---');
      buffer.writeln();
    }

    buffer.writeln(currentUserMsg);
    return buffer.toString();
  }

  /// 估算对话历史的 input token 数
  int _estimateTokens(List<cm.ChatMessage> history) {
    final text = history.map((m) => m.content).join('\n');
    return _estimateTokensFromString(text);
  }

  /// 估算文本的 token 数（中文约 1.5 字符/token，英文约 4 字符/token）
  int _estimateTokensFromString(String text) {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final other = text.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }
}

/// 内部上下文包装
class _ConversationContext {
  final String? systemPrompt;
  final String? contextContent;
  final List<cm.ChatMessage> history;

  const _ConversationContext({
    this.systemPrompt,
    this.contextContent,
    required this.history,
  });
}
