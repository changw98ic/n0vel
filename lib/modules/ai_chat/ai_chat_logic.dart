import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/chat_service.dart';
import '../../../core/services/entity_creation_service.dart';
import '../../../features/chat/domain/chat_message_entity.dart';
import '../../../features/work/data/work_repository.dart';
import '../../../features/work/domain/work.dart' as domain;
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

class AIChatLogic extends BaseController {
  final AIChatState state = AIChatState();
  final ChatService _chatService = Get.find<ChatService>();
  final WorkRepository _workRepository = Get.find<WorkRepository>();

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

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isGenerating.value) return;

    // 如果没有当前对话，先创建一个
    if (state.currentConversation.value == null) {
      await createNewConversation();
      if (state.currentConversation.value == null) return;
    }

    final convId = state.currentConversation.value!.id;
    final workId = state.selectedWorkId.value;
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
        }
      }
    } catch (e) {
      showErrorSnackbar('发送失败: $e');
    } finally {
      state.isGenerating.value = false;
      state.toolStatus.value = null;
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
