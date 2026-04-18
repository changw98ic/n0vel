import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/chat_context_builder.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/entity_creation_service.dart';
import '../../../core/services/writer_intent_resolver.dart';
import '../../../features/chat/domain/chat_message_entity.dart';
import '../../../features/chat/data/chat_repository.dart';
import '../../../features/editor/data/chapter_repository.dart';
import '../../../features/inspiration/data/inspiration_repository.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../features/settings/data/relationship_repository.dart';
import '../../../features/work/data/work_repository.dart';
import '../../../features/work/data/volume_repository.dart';
import '../../../features/work/domain/work.dart' as domain;
import '../../../features/workflow/data/workflow_task_runner.dart';
import '../../../features/workflow/domain/workflow_models.dart';
import '../../../shared/data/base_business/base_controller.dart';

class AIChatState {
  final conversations = RxList<ChatConversationEntity>([]);
  final currentConversation = Rx<ChatConversationEntity?>(null);
  final messages = RxList<ChatMessageEntity>([]);
  final isGenerating = false.obs;
  final streamingContent = ''.obs;
  final selectedWorkId = Rx<String?>(null);
  final works = RxList<domain.Work>([]);
  final isSidebarVisible = true.obs;
  final searchQuery = ''.obs;
  final pendingEntity = Rx<EntityCreationResult?>(null);
  final toolStatus = Rx<ChatToolStatus?>(null);
  final toolResults = RxList<ChatToolResult>([]);
  final thinkingContent = ''.obs;
  final isThinkingExpanded = false.obs;
}

class AIChatWorkflowDispatch {
  final String taskId;
  final WorkflowTaskStatus status;
  final String displayText;

  const AIChatWorkflowDispatch({
    required this.taskId,
    required this.status,
    required this.displayText,
  });
}

class _WorkflowTaskSpec {
  final String name;
  final String type;
  final Map<String, dynamic> config;
  final String assistantPrompt;

  const _WorkflowTaskSpec({
    required this.name,
    required this.type,
    required this.config,
    required this.assistantPrompt,
  });
}

class AIChatLogic extends BaseController {
  final AIChatState state = AIChatState();
  final ChatService _chatService = Get.find<ChatService>();
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  final WorkRepository _workRepository = Get.find<WorkRepository>();
  final WorkflowTaskRunner _workflowTaskRunner = Get.find<WorkflowTaskRunner>();
  final WriterIntentResolver _intentResolver = WriterIntentResolver();
  late final PersistedNovelSnapshotLoader _snapshotLoader =
      PersistedNovelSnapshotLoader(
        workRepository: Get.find<WorkRepository>(),
        volumeRepository: Get.find<VolumeRepository>(),
        chapterRepository: Get.find<ChapterRepository>(),
        characterRepository: Get.find<CharacterRepository>(),
        relationshipRepository: Get.find<RelationshipRepository>(),
        inspirationRepository: Get.find<InspirationRepository>(),
      );

  @override
  void onInit() {
    super.onInit();
    loadConversations();
    loadWorks();
  }

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  Future<void> loadConversations() async {
    try {
      final convs = await _chatService.getRecentConversations();
      state.conversations.value = convs;
    } catch (e) {
      showErrorSnackbar('加载对话失败: $e');
    }
  }

  Future<void> createNewConversation() async {
    try {
      final conv = await _chatService.createConversation(
        title: '新对话',
        workId: state.selectedWorkId.value,
        source: 'standalone',
      );
      state.conversations.insert(0, conv);
      await selectConversation(conv.id);
    } catch (e) {
      showErrorSnackbar('创建对话失败: $e');
    }
  }

  Future<void> selectConversation(String id) async {
    try {
      final conv = await _chatService.getRecentConversations();
      final target = conv.firstWhere(
        (c) => c.id == id,
        orElse: () => state.conversations.firstWhere((c) => c.id == id),
      );
      state.currentConversation.value = target;

      final messages = await _chatService.loadMessages(id);
      state.messages.value = messages;
      state.streamingContent.value = '';
    } catch (e) {
      showErrorSnackbar('加载消息失败: $e');
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _chatService.deleteConversation(id);
      state.conversations.removeWhere((c) => c.id == id);
      if (state.currentConversation.value?.id == id) {
        state.currentConversation.value = null;
        state.messages.clear();
      }
    } catch (e) {
      showErrorSnackbar('删除对话失败: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  Future<AIChatWorkflowDispatch?> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isGenerating.value) return;

    // 如果没有当前对话，先创建一个
    if (!await _ensureConversation()) {
      return null;
    }

    final convId = state.currentConversation.value!.id;
    final workId = _resolvedWorkId;

    final workflowDispatch = await _tryWorkflowRoute(
      text: text,
      workId: workId,
    );
    if (workflowDispatch != null) {
      return workflowDispatch;
    }

    state.isGenerating.value = true;
    state.streamingContent.value = '';
    state.pendingEntity.value = null;
    state.toolStatus.value = null;
    state.toolResults.clear();
    state.thinkingContent.value = '';
    state.isThinkingExpanded.value = false;

    // 立即显示用户消息
    state.messages.add(ChatMessageEntity(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: convId,
      role: 'user',
      content: text,
      sortOrder: state.messages.length,
      createdAt: DateTime.now(),
    ));

    try {
      // 始终使用 Agent 工具模式，让 AI 自主判断是否需要调用工具
      debugPrint('[AIChat] 发送消息 (workId: ${workId ?? "无"})');
      final stream = _chatService.sendMessageStreamWithTools(
        conversationId: convId,
        userMessage: text,
        workId: workId ?? '',
      );

      final buffer = StringBuffer();

      await for (final event in stream) {
        switch (event) {
          case ChatChunk():
            buffer.write(event.chunk);
            state.streamingContent.value = buffer.toString();
            // 文本开始流动时清除工具状态
            if (state.toolStatus.value != null &&
                !state.toolStatus.value!.isCompleted) {
              state.toolStatus.value = null;
            }
          case ChatComplete():
            state.streamingContent.value = '';
            state.thinkingContent.value = '';
            // 重新加载消息
            final messages = await _chatService.loadMessages(convId);
            state.messages.value = messages;

            // 第一条消息后自动生成标题
            if (state.messages.length <= 2) {
              unawaited(_chatService.generateTitle(convId));
              unawaited(loadConversations());
            }
          case ChatError():
            showErrorSnackbar('生成失败: ${event.error}');
            state.streamingContent.value = '';
          case ChatEntityProposal():
            state.pendingEntity.value = EntityCreationResult(
              type: switch (event.entityType) {
                'character' => EntityType.character,
                'location' => EntityType.location,
                'item' => EntityType.item,
                'faction' => EntityType.faction,
                _ => EntityType.character,
              },
              name: event.name,
              fields: event.fields,
            );
          case ChatToolStatus():
            state.toolStatus.value = event;
          case ChatToolResult():
            state.toolResults.add(event);
          case ChatThinking():
            state.thinkingContent.value = event.thought;
            state.isThinkingExpanded.value = true;
          case ChatBatchProgress():
            break;
          case ChatBatchChapterDone():
            break;
          case ChatBatchComplete():
            break;
        }
      }
    } catch (e) {
      showErrorSnackbar('发送失败: $e');
    } finally {
      state.isGenerating.value = false;
      state.toolStatus.value = null;
    }
    return null;
  }

  Future<void> syncWorkflowTaskMessage(String taskId) async {
    final task = await _workflowTaskRunner.getStatus(taskId);
    if (task == null) {
      return;
    }
    final displayText = await _workflowTaskRunner.getDisplayText(taskId);
    final content = displayText.trim().isNotEmpty
        ? displayText
        : switch (task.status) {
            WorkflowTaskStatus.waitingUserInput => '任务需要补充信息后才能继续执行。',
            WorkflowTaskStatus.waitingReview => '任务已生成结果，当前等待审核确认。',
            WorkflowTaskStatus.failed => task.errorMessage ?? '任务执行失败。',
            _ => '任务状态：${task.status.name}',
          };
    await _appendAssistantMessage(
      content,
      metadata: <String, dynamic>{
        'workflowTaskId': taskId,
        'workflowStatus': task.status.name,
      },
    );
  }

  Future<void> refreshMessages() async {
    final conversation = state.currentConversation.value;
    if (conversation == null) {
      return;
    }
    final messages = await _chatService.loadMessages(conversation.id);
    state.messages.value = messages;
  }

  Future<bool> _ensureConversation() async {
    if (state.currentConversation.value == null) {
      await createNewConversation();
    }
    return state.currentConversation.value != null;
  }

  String? get _resolvedWorkId =>
      state.selectedWorkId.value ?? state.currentConversation.value?.workId;

  Future<AIChatWorkflowDispatch?> _tryWorkflowRoute({
    required String text,
    required String? workId,
  }) async {
    if (workId == null || workId.trim().isEmpty) {
      return null;
    }

    final snapshot = await _snapshotLoader.load(workId);
    final snapshotContent = snapshot?.content ?? '';
    final spec = _buildWorkflowTaskSpec(
      prompt: text,
      snapshotContent: snapshotContent,
    );
    if (spec == null) {
      return null;
    }

    state.isGenerating.value = true;
    state.streamingContent.value = '';
    state.pendingEntity.value = null;
    state.toolStatus.value = null;
    state.toolResults.clear();
    state.thinkingContent.value = '';
    state.isThinkingExpanded.value = false;

    await _appendUserMessage(text);
    final taskId = await _workflowTaskRunner.startTask(
      workId: workId,
      name: spec.name,
      type: spec.type,
      config: spec.config,
    );
    final status = await _workflowTaskRunner.getStatus(taskId);
    final displayText = await _workflowTaskRunner.getDisplayText(taskId);
    await _appendAssistantMessage(
      displayText.trim().isNotEmpty ? displayText : spec.assistantPrompt,
      metadata: <String, dynamic>{
        'workflowTaskId': taskId,
        'workflowStatus': status?.status.name ?? 'pending',
      },
    );
    state.isGenerating.value = false;

    return AIChatWorkflowDispatch(
      taskId: taskId,
      status: status?.status ?? WorkflowTaskStatus.pending,
      displayText: displayText,
    );
  }

  _WorkflowTaskSpec? _buildWorkflowTaskSpec({
    required String prompt,
    required String snapshotContent,
  }) {
    final resolved = _intentResolver.resolve(prompt);
    switch (resolved.intent) {
      case WriterIntent.chapterWriting:
        return _WorkflowTaskSpec(
          name: 'AI 对话续写',
          type: 'generate',
          config: <String, dynamic>{
            'previousContent': snapshotContent,
            'continuationRequest': prompt,
          },
          assistantPrompt: '已创建续写任务，正在生成结果。',
        );
      case WriterIntent.dialogueGeneration:
        return _WorkflowTaskSpec(
          name: 'AI 对话对白',
          type: 'dialogue',
          config: <String, dynamic>{
            'sceneDescription': prompt,
            'contextContent': snapshotContent,
          },
          assistantPrompt: '已创建对白任务，正在生成结果。',
        );
      case WriterIntent.planning:
        return _WorkflowTaskSpec(
          name: 'AI 对话剧情规划',
          type: 'plot',
          config: <String, dynamic>{
            'chapterContent': snapshotContent,
            'promptText': prompt,
          },
          assistantPrompt: '已创建剧情规划任务，正在生成结果。',
        );
      case WriterIntent.contentGeneration:
        if (_containsAny(prompt, const ['提取', 'extract'])) {
          return _WorkflowTaskSpec(
            name: 'AI 对话设定提取',
            type: 'extract',
            config: <String, dynamic>{
              'textContent': snapshotContent,
            },
            assistantPrompt: '已创建设定提取任务，正在生成结果。',
          );
        }
        return _WorkflowTaskSpec(
          name: 'AI 对话自定义任务',
          type: 'custom_prompt',
          config: <String, dynamic>{
            'promptText': prompt,
            'chapterContent': snapshotContent,
          },
          assistantPrompt: '已创建自定义任务，正在生成结果。',
        );
      case WriterIntent.review:
      case WriterIntent.consistencyCheck:
        return _WorkflowTaskSpec(
          name: 'AI 对话审查任务',
          type: 'review',
          config: <String, dynamic>{
            'chapterContent': snapshotContent,
          },
          assistantPrompt: '已创建审查任务，正在生成结果。',
        );
      case WriterIntent.worldbuilding:
        return _WorkflowTaskSpec(
          name: 'AI 对话世界观任务',
          type: 'custom_prompt',
          config: <String, dynamic>{
            'promptText': prompt,
            'chapterContent': snapshotContent,
          },
          assistantPrompt: '已创建世界观任务，正在生成结果。',
        );
      case WriterIntent.generalChat:
      case WriterIntent.entityCreation:
      case WriterIntent.contentSearch:
        return null;
    }
  }

  bool _containsAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords.any(lower.contains);
  }

  Future<void> _appendUserMessage(String text) async {
    final conversation = state.currentConversation.value;
    if (conversation == null) {
      return;
    }
    await _chatRepository.addMessage(
      conversationId: conversation.id,
      role: 'user',
      content: text,
    );
    await refreshMessages();
  }

  Future<void> _appendAssistantMessage(
    String text, {
    Map<String, dynamic>? metadata,
  }) async {
    final conversation = state.currentConversation.value;
    if (conversation == null) {
      return;
    }
    await _chatRepository.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: text,
      metadata: metadata,
    );
    await refreshMessages();
    if (state.messages.length <= 2) {
      unawaited(_chatService.generateTitle(conversation.id));
      unawaited(loadConversations());
    }
  }

  void toggleSidebar() {
    state.isSidebarVisible.value = !state.isSidebarVisible.value;
  }

  void setSelectedWork(String? workId) {
    state.selectedWorkId.value = workId;
  }

  // ---------------------------------------------------------------------------
  // Works
  // ---------------------------------------------------------------------------

  Future<void> loadWorks() async {
    try {
      final works = await _workRepository.getAllWorks();
      state.works.value = works;
    } catch (e) {
      // 静默失败 — 不影响聊天功能
    }
  }

  /// 获取当前选中作品名称
  String? get selectedWorkName {
    final workId = state.selectedWorkId.value;
    if (workId == null) return null;
    try {
      return state.works.firstWhere((w) => w.id == workId).name;
    } catch (_) {
      return null;
    }
  }
}

/// Helper to allow unawaited futures without lint warnings
void unawaited(Future<void>? future) {
  // intentionally not awaited
}
