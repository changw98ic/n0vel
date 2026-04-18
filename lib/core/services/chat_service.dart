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
import 'writer_runtime_hooks.dart';
part 'chat_prompt_helpers.dart';
part 'chat_stream_helpers.dart';

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

/// 批量章节进度
class ChatBatchProgress extends ChatStreamEvent {
  final String phase;
  final int completed;
  final int total;
  ChatBatchProgress({
    required this.phase,
    required this.completed,
    required this.total,
  });
}

/// 批量章节完成
class ChatBatchChapterDone extends ChatStreamEvent {
  final int index;
  final String title;
  final int wordCount;
  ChatBatchChapterDone({
    required this.index,
    required this.title,
    required this.wordCount,
  });
}

/// 批量章节全部完成
class ChatBatchComplete extends ChatStreamEvent {
  final int totalWords;
  final List<String> chapters;
  ChatBatchComplete({
    required this.totalWords,
    required this.chapters,
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
  final WriterRuntimeHooks _writerRuntimeHooks;

  /// 内存中的对话上下文缓存（conversationId → messages）
  final _contextCache = <String, List<cm.ChatMessage>>{};

  ChatService({
    required AIService aiService,
    required cm.ContextManager contextManager,
    required ChatRepository chatRepository,
    AgentService? agentService,
    WriterRuntimeHooks? writerRuntimeHooks,
  })  : _aiService = aiService,
        _contextManager = contextManager,
        _chatRepository = chatRepository,
        _agentService = agentService,
        _writerRuntimeHooks =
            writerRuntimeHooks ?? WriterRuntimeHooks();

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
    final conversation =
        await _chatRepository.getConversationById(conversationId);
    final scopedWorkId = conversation?.workId ?? '';

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
    final preflight = await _writerRuntimeHooks.runPreRequestChecks(
      prompt: userMessage,
      workId: scopedWorkId,
      contextContent: contextContent,
      historyCount: context.history.length,
    );
    final userPromptText = _buildUserPrompt(context, userMessage);
    final systemPromptText = _buildSystemPrompt(
      context,
      preflightPromptSection: preflight.toPromptSection(),
    );

    // 调用 AI
    final response = await _aiService.generate(
      prompt: userPromptText,
      config: AIRequestConfig(
        function: AIFunction.chat,
        systemPrompt: systemPromptText,
        userPrompt: userPromptText,
        useCache: false,
        stream: false,
      ),
    );
    final postflight = await _writerRuntimeHooks.runPostResponseChecks(
      request: userMessage,
      response: response.content,
      usedTools: false,
    );
    final finalContent = postflight.shouldBlock
        ? _buildBlockedResponse(postflight)
        : _appendPostflightWarnings(
            response.content,
            postflight.warnMessages,
          );

    // 持久化助手消息
    final assistantMsg = await _chatRepository.addMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: finalContent,
      metadata: postflight.toMetadata(),
    );

    // 更新内存缓存
    final cache = _contextCache[conversationId] ?? [];
    cache.add(cm.ChatMessage(role: 'user', content: userMessage));
    cache.add(cm.ChatMessage(role: 'assistant', content: finalContent));
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
      final conversation =
          await _chatRepository.getConversationById(conversationId);
      final scopedWorkId = conversation?.workId ?? '';

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
      final preflight = await _writerRuntimeHooks.runPreRequestChecks(
        prompt: userMessage,
        workId: scopedWorkId,
        contextContent: contextContent,
        historyCount: context.history.length,
      );
      final userPromptText = _buildUserPrompt(context, userMessage);
      final systemPromptText = _buildSystemPrompt(
        context,
        preflightPromptSection: preflight.toPromptSection(),
      );

      // 更新内存缓存
      final cache = _contextCache[conversationId] ?? [];
      cache.add(cm.ChatMessage(role: 'user', content: userMessage));

      // 流式调用 AI
      final stream = _aiService.generateStream(
        prompt: userPromptText,
        config: AIRequestConfig(
          function: AIFunction.chat,
          systemPrompt: systemPromptText,
          userPrompt: userPromptText,
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
      final postflight = await _writerRuntimeHooks.runPostResponseChecks(
        request: userMessage,
        response: fullContent,
        usedTools: false,
      );
      final postflightMessages = [
        ...postflight.blockMessages,
        ...postflight.warnMessages,
      ];
      final postflightNotes = _buildPostflightNotes(postflightMessages);
      if (postflightNotes.isNotEmpty) {
        controller.add(ChatChunk('\n\n$postflightNotes'));
      }
      final finalContent = postflightNotes.isEmpty
          ? fullContent
          : '${fullContent.trimRight()}\n\n$postflightNotes';

      // Estimate tokens from content (streaming providers may not return usage)
      final inputTokens = _estimateTokens(context.history);
      final outputTokens = _estimateTokensFromString(finalContent);

      // 持久化助手消息
      await _chatRepository.addMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: finalContent,
        metadata: postflight.toMetadata(),
      );

      // 更新内存缓存
      cache.add(cm.ChatMessage(role: 'assistant', content: finalContent));
      _contextCache[conversationId] = cache;

      controller.add(ChatComplete(
        fullContent: finalContent,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      ));

      // 检测实体创建意图
      final entityResult =
          EntityCreationService.detectEntityInResponse(finalContent);
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
      final conversation =
          await _chatRepository.getConversationById(conversationId);
      final scopedWorkId = conversation?.workId ?? workId;

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
      final preflight = await _writerRuntimeHooks.runPreRequestChecks(
        prompt: userMessage,
        workId: scopedWorkId,
        contextContent: null,
        historyCount: history.length,
      );

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
        task: preflight.toPromptSection().trim().isEmpty
            ? userMessage
            : '${preflight.toPromptSection()}\n\n$userMessage',
        workId: scopedWorkId,
        tier: ModelTier.middle,
        conversationHistory: history,
      );

      String fullContent = '';
      int totalInputTokens = 0;
      int totalOutputTokens = 0;
      String lastToolName = '';
      String effectiveWorkId = workId;

      await for (final event in agentStream) {
        switch (event) {
          case AgentPlan(:final steps):
            debugPrint('[ChatService] 计划生成: ${steps.length} 步');
            controller.add(ChatThinking(_formatAgentPlanThinking(steps)));
          case AgentPlanStepStart(:final stepIndex, :final totalSteps, :final description):
            controller.add(ChatThinking('步骤 ${stepIndex + 1}/$totalSteps: $description'));
          case AgentPlanStepComplete(:final stepIndex, :final success, :final summary):
            debugPrint('[ChatService] 步骤 ${stepIndex + 1} ${success ? "完成" : "失败"}: ${summary.substring(0, summary.length.clamp(0, 80))}');
          case AgentReflection(:final target, :final passed, :final evaluation, :final feedback):
            final status = passed ? '✓ 通过' : '✗ 需改进';
            controller.add(ChatThinking('反思 [$target]: $status — $evaluation'));
            if (!passed && feedback != null) {
              controller.add(ChatThinking('改进建议: $feedback'));
            }
          case AgentRetry(:final stepIndex, :final retryCount, :final maxRetries, :final reason):
            controller.add(ChatThinking('重试步骤 ${stepIndex + 1} ($retryCount/$maxRetries): $reason'));
          case AgentThinking(:final thought):
            controller.add(ChatThinking(thought));
          case AgentAction(:final toolName):
            lastToolName = toolName;
            controller.add(ChatToolStatus(
              toolName: toolName,
              statusMessage: _buildToolStatusMessage(toolName),
              isCompleted: false,
            ));
          case AgentObservation(:final result):
            controller.add(ChatToolResult(
              toolName: lastToolName,
              summary: _summarizeToolResult(result),
              success: result.success,
            ));
            controller.add(ChatToolStatus(
              toolName: lastToolName,
              statusMessage: _buildToolCompletedMessage(lastToolName),
              isCompleted: true,
            ));
            // Hook: create_work 成功后，将 work_id 写回 conversation
            if (lastToolName == 'create_work' &&
                result.success &&
                result.data != null) {
              final createdId = result.data!['id'] as String?;
              if (createdId != null && createdId.isNotEmpty) {
                effectiveWorkId = createdId;
                await _chatRepository.updateWorkId(
                    conversationId, createdId);
                debugPrint(
                    '[ChatService] create_work → hook work_id=$createdId into conversation $conversationId');
              }
            }
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
        final postflight = await _writerRuntimeHooks.runPostResponseChecks(
          request: userMessage,
          response: fullContent,
          usedTools: true,
        );
        final postflightMessages = [
          ...postflight.blockMessages,
          ...postflight.warnMessages,
        ];
        final postflightNotes = _buildPostflightNotes(postflightMessages);
        if (postflightNotes.isNotEmpty) {
          controller.add(ChatChunk('\n\n$postflightNotes'));
        }
        final finalContent = postflightNotes.isEmpty
            ? fullContent
            : '${fullContent.trimRight()}\n\n$postflightNotes';

        // 持久化助手消息
        await _chatRepository.addMessage(
          conversationId: conversationId,
          role: 'assistant',
          content: finalContent,
          metadata: postflight.toMetadata(),
        );

        // 更新内存缓存
        final cache = _contextCache[conversationId] ?? [];
        cache.add(cm.ChatMessage(role: 'user', content: userMessage));
        cache.add(cm.ChatMessage(role: 'assistant', content: finalContent));
        _contextCache[conversationId] = cache;

        controller.add(ChatComplete(
          fullContent: finalContent,
          inputTokens: totalInputTokens,
          outputTokens: totalOutputTokens,
        ));

        // 检测实体创建意图
        final entityResult =
            EntityCreationService.detectEntityInResponse(finalContent);
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
        prompt: _buildTitlePrompt(firstUserMsg.content),
        config: AIRequestConfig(
          function: AIFunction.chat,
          systemPrompt: _titleGeneratorSystemPrompt,
          userPrompt: firstUserMsg.content,
          useCache: false,
          stream: false,
        ),
      );

      final title = _normalizeGeneratedTitle(response.content);

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
  ) => _emitTypewriterChunks(controller, text);

  /// 工具名称到友好中文名的映射
  static String _friendlyToolName(String toolName) =>
      _friendlyChatToolName(toolName);

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

  String _buildSystemPrompt(
    _ConversationContext context, {
    String? preflightPromptSection,
  }) {
    return _buildChatSystemPrompt(
      context,
      preflightPromptSection: preflightPromptSection,
    );
  }

  String _buildUserPrompt(_ConversationContext context, String currentUserMsg) {
    return _buildChatUserPrompt(context, currentUserMsg);
  }

  /// 估算对话历史的 input token 数
  int _estimateTokens(List<cm.ChatMessage> history) {
    return _estimateChatHistoryTokens(history);
  }

  /// 估算文本的 token 数（中文约 1.5 字符/token，英文约 4 字符/token）
  int _estimateTokensFromString(String text) {
    return _estimateChatTokensFromString(text);
  }

  String _buildBlockedResponse(WriterPostflightChecks postflight) {
    final buffer = StringBuffer();
    buffer.writeln('当前结果不适合直接作为最终答复。');
    for (final message in postflight.blockMessages) {
      buffer.writeln('- $message');
    }
    final recoveryPrompt = postflight.toRecoveryPrompt().trim();
    if (recoveryPrompt.isNotEmpty) {
      buffer.writeln();
      buffer.write(recoveryPrompt);
    }
    return buffer.toString().trim();
  }

  String _appendPostflightWarnings(String content, List<String> warnings) {
    final postflightNotes = _buildPostflightNotes(warnings);
    if (postflightNotes.isEmpty) {
      return content;
    }
    return '${content.trimRight()}\n\n$postflightNotes';
  }

  String _buildPostflightNotes(List<String> messages) {
    if (messages.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    buffer.writeln('【提示】');
    for (final message in messages) {
      buffer.writeln('- $message');
    }
    return buffer.toString().trimRight();
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
