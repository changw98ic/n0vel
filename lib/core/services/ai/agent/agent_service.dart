import 'dart:async';

import '../ai_service.dart';
import '../context/context_manager.dart';
import '../models/model_tier.dart';
import '../tools/tool_definition.dart';
import '../tools/tool_registry.dart';

/// Agent 事件流
sealed class AgentEvent {}

/// Agent 思考中
class AgentThinking extends AgentEvent {
  final String thought;
  AgentThinking(this.thought);
}

/// Agent 执行工具
class AgentAction extends AgentEvent {
  final String toolName;
  final Map<String, dynamic> input;
  AgentAction(this.toolName, this.input);
}

/// Agent 观察工具结果
class AgentObservation extends AgentEvent {
  final ToolResult result;
  AgentObservation(this.result);
}

/// Agent 最终响应（流式文本块）
class AgentResponseChunk extends AgentEvent {
  final String chunk;
  AgentResponseChunk(this.chunk);
}

/// Agent 最终响应（完成）
class AgentResponse extends AgentEvent {
  final String content;
  final int iterations;
  final int totalInputTokens;
  final int totalOutputTokens;
  AgentResponse({
    required this.content,
    required this.iterations,
    required this.totalInputTokens,
    required this.totalOutputTokens,
  });
}

/// Agent 错误
class AgentError extends AgentEvent {
  final String error;
  AgentError(this.error);
}

/// Agent 服务
/// 实现 ReAct (Reason-Act-Observe) 循环
class AgentService {
  final AIService _aiService;
  final ToolRegistry _toolRegistry;
  final ContextManager _contextManager;

  /// 最大迭代次数
  static const int defaultMaxIterations = 10;

  AgentService({
    required AIService aiService,
    required ToolRegistry toolRegistry,
    required ContextManager contextManager,
  })  : _aiService = aiService,
        _toolRegistry = toolRegistry,
        _contextManager = contextManager;

  /// 执行 Agent 任务
  /// 返回事件流，调用方可以监听实时进度
  Stream<AgentEvent> run({
    required String task,
    required String workId,
    List<String>? allowedTools,
    int? maxIterations,
    ModelTier tier = ModelTier.middle,
    List<ChatMessage>? conversationHistory,
  }) {
    final controller = StreamController<AgentEvent>();
    final maxIter = maxIterations ?? defaultMaxIterations;

    // 异步执行 ReAct 循环
    _executeReActLoop(
      controller: controller,
      task: task,
      workId: workId,
      allowedTools: allowedTools,
      maxIterations: maxIter,
      tier: tier,
      conversationHistory: conversationHistory,
    );

    return controller.stream;
  }

  Future<void> _executeReActLoop({
    required StreamController<AgentEvent> controller,
    required String task,
    required String workId,
    required List<String>? allowedTools,
    required int maxIterations,
    required ModelTier tier,
    required List<ChatMessage>? conversationHistory,
  }) async {
    try {
      // 获取可用工具
      final tools = _getAvailableTools(allowedTools);
      if (tools.isEmpty) {
        controller.add(AgentError('没有可用的工具'));
        await controller.close();
        return;
      }

      // 构造工具 schema
      final toolSchemas = tools.map((t) => t.toFunctionSchema()).toList();

      // 对话历史
      final messages = <ChatMessage>[];
      messages.add(ChatMessage(
        role: 'system',
        content: _buildSystemPrompt(tools, workId),
      ));

      // 如果有对话历史，加入上下文
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        for (final msg in conversationHistory) {
          if (msg.role != 'system') {
            messages.add(msg);
          }
        }
      }

      messages.add(ChatMessage(role: 'user', content: task));

      int totalInputTokens = 0;
      int totalOutputTokens = 0;

      for (var i = 0; i < maxIterations; i++) {
        // Compact 检查
        if (messages.length > 4 &&
            _contextManager.needsCompact(messages, '')) {
          final compacted = await _contextManager.compact(
            messages: messages,
            modelName: '',
          );
          messages.clear();
          messages.addAll(compacted.recent);
        }

        // 调用 AI（使用原生 tool calling）
        final response = await _callAI(messages, toolSchemas, tier);
        totalInputTokens += response.inputTokens;
        totalOutputTokens += response.outputTokens;

        // 添加助手回复到历史
        messages.add(ChatMessage(role: 'assistant', content: response.content));

        // 输出思维链（LM Studio / DeepSeek reasoning_content）
        if (response.thinking != null && response.thinking!.trim().isNotEmpty) {
          controller.add(AgentThinking(response.thinking!.trim()));
        }

        // 检查是否有工具调用
        if (response.toolCalls.isNotEmpty) {
          // 如果 AI 在调用工具前有推理文本，将其作为思考过程输出
          if (response.content.trim().isNotEmpty) {
            controller.add(AgentThinking(response.content.trim()));
          }
          for (final toolCall in response.toolCalls) {
            controller.add(AgentAction(toolCall.name, toolCall.arguments));
            controller.add(AgentThinking('调用工具: ${toolCall.name}'));

            // 执行工具
            final tool = _toolRegistry.get(toolCall.name);
            if (tool == null) {
              controller.add(AgentObservation(
                ToolResult.fail('工具 ${toolCall.name} 不存在'),
              ));
              messages.add(ChatMessage(
                role: 'tool',
                content: '错误: 工具 ${toolCall.name} 不存在',
                toolCallId: toolCall.id,
              ));
              continue;
            }

            final result = await tool.execute(toolCall.arguments);
            controller.add(AgentObservation(result));

            // 将工具结果添加到历史
            messages.add(ChatMessage(
              role: 'tool',
              content: result.success ? result.output : '错误: ${result.error}',
              toolCallId: toolCall.id,
            ));
          }
        } else {
          // 没有工具调用 → 最终响应，流式输出
          controller.add(AgentResponse(
            content: response.content,
            iterations: i + 1,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
          ));
          await controller.close();
          return;
        }
      }

      // 超过最大迭代次数
      controller.add(AgentError('达到最大迭代次数 ($maxIterations)，任务可能未完成'));
      await controller.close();
    } catch (e) {
      controller.add(AgentError('Agent 执行错误: $e'));
      await controller.close();
    }
  }

  /// 获取可用工具列表
  List<ToolDefinition> _getAvailableTools(List<String>? allowedTools) {
    if (allowedTools != null) {
      return allowedTools
          .map((name) => _toolRegistry.get(name))
          .whereType<ToolDefinition>()
          .toList();
    }
    return _toolRegistry.all;
  }

  /// 调用 AI（使用原生 tool calling）
  Future<AIResponse> _callAI(
    List<ChatMessage> messages,
    List<Map<String, dynamic>> toolSchemas,
    ModelTier tier,
  ) async {
    // 构造 system prompt 和 user prompt
    final systemMessage = messages
        .where((m) => m.role == 'system')
        .map((m) => m.content)
        .join('\n\n');
    final userMessage = messages
        .where((m) => m.role != 'system')
        .map((m) => '[${m.role}]: ${m.content}')
        .join('\n\n');

    // 使用原生 tool calling（Provider 自动处理 prompt 注入 / 原生 API）
    return _aiService.generateWithTools(
      prompt: userMessage,
      config: AIRequestConfig(
        function: AIFunction.chat,
        systemPrompt: systemMessage,
        userPrompt: userMessage,
        useCache: false,
        stream: false,
      ),
      tools: toolSchemas,
    );
  }

  /// 构建 Agent 系统提示
  String _buildSystemPrompt(List<ToolDefinition> tools, String workId) {
    final buffer = StringBuffer();
    buffer.writeln('你是一位专业的小说写作助手 Agent。');
    buffer.writeln('你可以使用工具来完成任务，也可以直接回复用户。');
    if (workId.isNotEmpty) {
      buffer.writeln('当前作品 ID: $workId');
    } else {
      buffer.writeln('当前没有选中作品。如果用户需要操作特定作品（如创建章节、角色等），请先调用 list_works 查看所有作品并获取其 ID。');
    }
    buffer.writeln();
    buffer.writeln('工作流程：');
    buffer.writeln('1. 分析用户需求');
    buffer.writeln('2. 如果需要信息，调用搜索工具');
    buffer.writeln('3. 如果需要生成内容，调用生成工具');
    buffer.writeln('4. 如果需要检查问题，调用分析/一致性检查工具');
    buffer.writeln('5. 综合结果，给出最终回复');
    buffer.writeln();
    buffer.writeln('注意事项：');
    buffer.writeln('- 每次只调用一个工具');
    buffer.writeln('- 如果不知道作品 ID 或卷 ID，先调用 list_works / list_volumes 获取');
    buffer.writeln('- 如果信息不足，先搜索再行动');
    buffer.writeln('- 最终回复必须是完整的中文内容');
    buffer.writeln();
    buffer.writeln('当用户要求创建角色、地点、物品、势力、关系、作品、卷、章节或素材时，请直接调用对应的 create_* 工具。');
    buffer.writeln('创建实体后，用自然语言向用户确认创建结果。');
    buffer.writeln();
    buffer.writeln('## 创建章节的完整流程');
    buffer.writeln('调用 create_chapter 时，必须在 content 参数中传入完整的章节正文内容。');
    buffer.writeln('不要创建空章节！content 参数是必填的。');
    buffer.writeln('你需要在调用工具前先构思好章节内容，然后一次性传入。');
    buffer.writeln();
    buffer.writeln('## 创建章节前的评估规则');
    buffer.writeln('在调用 create_chapter 之前，你必须先评估用户是否提供了足够的信息：');
    buffer.writeln('1. **剧情内容**：用户是否描述了本章要发生什么事？如果只说"写第一章"而没给任何剧情方向，应追问');
    buffer.writeln('2. **节奏定位**：本章处于故事的什么位置？（开篇/铺垫/高潮/过渡/结尾）是否需要提醒用户注意节奏');
    buffer.writeln('3. **钩子/悬念**：本章结尾是否需要留下悬念或钩子引导读者继续阅读？');
    buffer.writeln('4. **前文衔接**：如果不是第一章，是否有前文上下文可以衔接？如有，先搜索前文内容');
    buffer.writeln('5. **事件丰富度**：用户提供的剧情是否足够展开为一整章？是否只有一句话概括而缺少具体事件、冲突、转折？');
    buffer.writeln('6. **读者看点**：站在读者角度审视——这一章有没有让人想继续读下去的亮点？是否有情感冲击、意外转折、悬念揭示、角色魅力展示等阅读驱动力？');
    buffer.writeln();
    buffer.writeln('如果用户信息不足（如只说"帮我写一章"或剧情过于单薄），不要盲目创建。');
    buffer.writeln('你应该礼貌地追问关键信息，例如：本章主要事件、涉及角色、情感基调、是否需要结尾钩子等。');
    buffer.writeln('如果用户给了一句话剧情但缺少细节，你可以主动建议补充冲突点、情感转折、悬念钩子等，让章节更丰满。');
    buffer.writeln('但如果用户已经提供了足够的信息（有明确的剧情走向和关键事件），就可以直接创建。');
    buffer.writeln();
    buffer.writeln('## 创建作品时的主题/世界观处理规则');
    buffer.writeln('当用户创建作品并附带「主题」「题材」「类型」「世界观」「风格」等描述时，你必须执行以下步骤：');
    buffer.writeln('1. 先调用 create_work 创建作品（name 为作品名称，将主题关键词写入 type 字段）');
    buffer.writeln('2. 紧接着调用 create_inspiration，参数如下：');
    buffer.writeln('   - title: 「{作品名} 世界观设定」');
    buffer.writeln('   - category: "worldbuilding"');
    buffer.writeln('   - work_id: 上一步 create_work 返回的作品 ID');
    buffer.writeln('   - content: 根据用户提供的主题，自动生成详细的世界观设定内容，包括但不限于：');
    buffer.writeln('     • 核心设定与规则体系');
    buffer.writeln('     • 力量体系/等级划分');
    buffer.writeln('     • 世界背景与历史概述');
    buffer.writeln('     • 典型场景与氛围描述');
    buffer.writeln('     • 常见剧情模式与套路');
    buffer.writeln('   - tags: 提取 3-5 个相关标签');
    buffer.writeln('3. 用自然语言向用户确认：作品已创建，并已根据主题自动生成世界观设定');
    return buffer.toString();
  }
}
