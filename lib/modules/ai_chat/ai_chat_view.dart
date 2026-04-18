import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../../../features/chat/domain/chat_message_entity.dart';
import '../../../features/work/domain/work.dart';
import '../../../features/workflow/data/workflow_task_runner.dart';
import '../../../features/workflow/domain/workflow_models.dart';
import '../workflow/view/workflow_task_list_page.dart';
import '../workflow/view/workflow_task_page.dart';
import 'ai_chat_logic.dart';
import '../workflow/view/workflow_clarification_dialog.dart';
import 'view/entity_preview_card.dart';

/// 独立 AI 对话页面
class AIChatView extends StatelessWidget {
  const AIChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(AIChatLogic());

    return Scaffold(
      body: Obx(() {
        final isSidebarVisible = logic.state.isSidebarVisible.value;
        return Row(
          children: [
            // Sidebar
            if (isSidebarVisible) _Sidebar(logic: logic),
            // Main chat area
            Expanded(child: _ChatArea(logic: logic)),
          ],
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar — conversation list
// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  final AIChatLogic logic;

  const _Sidebar({required this.logic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 260.w,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.3),
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          _SidebarHeader(logic: logic),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _ConversationList(logic: logic),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final AIChatLogic logic;

  const _SidebarHeader({required this.logic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 8.w, 8.h),
      child: Row(
        children: [
          Text(
            'AI 助手',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '新建对话',
            icon: const Icon(Icons.add_rounded, size: 20),
            onPressed: logic.createNewConversation,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: '隐藏侧栏',
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: logic.toggleSidebar,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  final AIChatLogic logic;

  const _ConversationList({required this.logic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Obx(() {
      final conversations = logic.state.conversations;
      if (conversations.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Text(
              '暂无对话\n点击 + 开始新对话',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conv = conversations[index];
          final isSelected = logic.state.currentConversation.value?.id == conv.id;

          return _ConversationTile(
            title: conv.title,
            updatedAt: conv.updatedAt,
            isSelected: isSelected,
            onTap: () => logic.selectConversation(conv.id),
            onDelete: () => logic.deleteConversation(conv.id),
          );
        },
      );
    });
  }
}

class _ConversationTile extends StatelessWidget {
  final String title;
  final DateTime updatedAt;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.title,
    required this.updatedAt,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final relativeTime = _formatRelativeTime(updatedAt);

    return Material(
      color: isSelected
          ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16.sp,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      relativeTime,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 16.sp, color: colorScheme.error),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  tooltip: '删除对话',
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}

// ---------------------------------------------------------------------------
// Chat area — messages + input
// ---------------------------------------------------------------------------

class _ChatArea extends StatefulWidget {
  final AIChatLogic logic;

  const _ChatArea({required this.logic});

  @override
  State<_ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<_ChatArea> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 监听状态变化，自动滚动到底部
    ever(widget.logic.state.streamingContent, (_) => _scrollToBottom());
    ever(widget.logic.state.messages, (_) => _scrollToBottom());
    ever(widget.logic.state.toolStatus, (_) => _scrollToBottom());
    ever(widget.logic.state.currentConversation, (_) => _scrollToBottom());
    ever(widget.logic.state.thinkingContent, (_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logic = widget.logic;

    return Column(
      children: [
        _ChatHeader(logic: logic),
        Expanded(
          child: _ChatMessagePane(
            logic: logic,
            scrollController: _scrollController,
          ),
        ),
        _ChatInputBar(logic: logic),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final AIChatLogic logic;

  const _ChatHeader({required this.logic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          if (!logic.state.isSidebarVisible.value)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              onPressed: logic.toggleSidebar,
              visualDensity: VisualDensity.compact,
            ),
          Expanded(
            child: Obx(() {
              final title = logic.state.currentConversation.value?.title ?? 'AI 助手';
              return Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              );
            }),
          ),
          Obx(() {
            final works = logic.state.works;
            final selectedId = logic.state.selectedWorkId.value;
            return _WorkSelector(
              works: works,
              selectedWorkId: selectedId,
              onSelected: logic.setSelectedWork,
            );
          }),
          Obx(() {
            final workId = logic.state.selectedWorkId.value ??
                logic.state.currentConversation.value?.workId;
            if (workId == null || workId.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.list_alt_rounded, size: 20),
              tooltip: '查看任务',
              onPressed: () => Get.to(
                () => WorkflowTaskListPage(workId: workId),
              ),
              visualDensity: VisualDensity.compact,
            );
          }),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 20),
            tooltip: '新建对话',
            onPressed: logic.createNewConversation,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ChatMessagePane extends StatelessWidget {
  final AIChatLogic logic;
  final ScrollController scrollController;

  const _ChatMessagePane({
    required this.logic,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final messages = logic.state.messages;
      final streaming = logic.state.streamingContent.value;
      final hasMessages = messages.isNotEmpty || streaming.isNotEmpty;

      if (!hasMessages) {
        return const _EmptyChatState();
      }

      return ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.all(16.w),
        itemCount: _itemCount(messages.length, streaming),
        itemBuilder: (context, index) => _buildItem(
          context: context,
          index: index,
          messages: messages,
          streaming: streaming,
        ),
      );
    });
  }

  int _itemCount(int messageCount, String streaming) {
    return messageCount +
        (logic.state.toolStatus.value != null || logic.state.toolResults.isNotEmpty
            ? 1
            : 0) +
        (logic.state.thinkingContent.value.isNotEmpty ? 1 : 0) +
        (streaming.isNotEmpty ? 1 : 0) +
        (logic.state.pendingEntity.value != null ? 1 : 0);
  }

  Widget _buildItem({
    required BuildContext context,
    required int index,
    required List<ChatMessageEntity> messages,
    required String streaming,
  }) {
    if (index < messages.length) {
      return _ChatBubble(
        message: messages[index],
        onInsert: (_) {},
      );
    }

    var extraIndex = index - messages.length;
    final toolItem = _buildToolStatusItem(extraIndex);
    if (toolItem != null) {
      return toolItem;
    }
    if (logic.state.toolStatus.value != null || logic.state.toolResults.isNotEmpty) {
      extraIndex--;
    }

    final thinkingItem = _buildThinkingItem(extraIndex);
    if (thinkingItem != null) {
      return thinkingItem;
    }
    if (logic.state.thinkingContent.value.isNotEmpty) {
      extraIndex--;
    }

    if (streaming.isNotEmpty && extraIndex == 0) {
      return _StreamingBubble(content: streaming);
    }
    if (streaming.isNotEmpty) {
      extraIndex--;
    }

    final entityItem = _buildPendingEntityItem();
    if (entityItem != null) {
      return entityItem;
    }

    return const SizedBox.shrink();
  }

  Widget? _buildToolStatusItem(int extraIndex) {
    final toolStatus = logic.state.toolStatus.value;
    final toolResults = logic.state.toolResults;
    if ((toolStatus != null || toolResults.isNotEmpty) && extraIndex == 0) {
      return _ToolStatusIndicator(
        status: toolStatus,
        results: toolResults.toList(),
      );
    }
    return null;
  }

  Widget? _buildThinkingItem(int extraIndex) {
    final thinking = logic.state.thinkingContent.value;
    if (thinking.isNotEmpty && extraIndex == 0) {
      return _ThinkingBubble(
        content: thinking,
        isExpanded: logic.state.isThinkingExpanded.value,
        onToggle: () {
          logic.state.isThinkingExpanded.value =
              !logic.state.isThinkingExpanded.value;
        },
      );
    }
    return null;
  }

  Widget? _buildPendingEntityItem() {
    final entity = logic.state.pendingEntity.value;
    if (entity == null) {
      return null;
    }

    final workId = logic.state.selectedWorkId.value ??
        logic.state.currentConversation.value?.workId ??
        '';
    return EntityPreviewCard(
      entity: entity,
      workId: workId,
      onSaved: (createdWorkId) {
        logic.state.pendingEntity.value = null;
        if (createdWorkId != null) {
          logic.setSelectedWork(createdWorkId);
          logic.loadWorks();
        }
      },
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_outlined,
            size: 48.sp,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16.h),
          Text(
            '开始一段新对话',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '输入消息或描述你的创作需求',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat bubble
// ---------------------------------------------------------------------------

class _ChatBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final void Function(String) onInsert;

  const _ChatBubble({required this.message, required this.onInsert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = message.role == 'user';
    final workflowTaskId = message.metadata?['workflowTaskId']?.toString();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        margin: EdgeInsets.symmetric(vertical: 4.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: isUser
              ? null
              : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.content,
              style: theme.textTheme.bodyMedium,
            ),
            if (!isUser) ...[
              SizedBox(height: 6.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BubbleAction(
                    icon: Icons.copy_rounded,
                    tooltip: '复制',
                    onTap: () {},
                  ),
                  if (workflowTaskId != null && workflowTaskId.isNotEmpty)
                    _BubbleAction(
                      icon: Icons.account_tree_outlined,
                      tooltip: '打开任务',
                      onTap: () => Get.to(
                        () => WorkflowTaskPage(taskId: workflowTaskId),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  final String content;

  const _StreamingBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        margin: EdgeInsets.symmetric(vertical: 4.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                content,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            SizedBox(width: 8.w),
            _TypingIndicator(colorScheme: colorScheme),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  final String content;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ThinkingBubble({
    required this.content,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayText = isExpanded || content.length <= 150
        ? content
        : '${content.substring(0, 150)}...';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        margin: EdgeInsets.symmetric(vertical: 4.h),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: colorScheme.tertiary.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          onTap: content.length > 150 ? onToggle : null,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: Padding(
            padding: EdgeInsets.all(10.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 14.sp,
                      color: colorScheme.tertiary,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '思考中',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (content.length > 150) ...[
                      SizedBox(width: 4.w),
                      Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 14.sp,
                        color: colorScheme.tertiary,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  displayText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final ColorScheme colorScheme;

  const _TypingIndicator({required this.colorScheme});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + 0.6 * (_controller.value),
          child: Icon(
            Icons.more_horiz_rounded,
            size: 16.sp,
            color: widget.colorScheme.primary,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Work selector
// ---------------------------------------------------------------------------

class _WorkSelector extends StatelessWidget {
  final List<Work> works;
  final String? selectedWorkId;
  final ValueChanged<String?> onSelected;

  const _WorkSelector({
    required this.works,
    required this.selectedWorkId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedName = selectedWorkId != null
        ? works.where((w) => w.id == selectedWorkId).firstOrNull?.name
        : null;

    return PopupMenuButton<String?>(
      tooltip: '选择作品',
      position: PopupMenuPosition.under,
      initialValue: selectedWorkId,
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Text('不关联作品'),
        ),
        const PopupMenuDivider(),
        ...works.map((w) => PopupMenuItem<String?>(
              value: w.id,
              child: Text(w.name),
            )),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: selectedWorkId != null
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(
            color: selectedWorkId != null
                ? colorScheme.primary.withValues(alpha: 0.4)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 14.sp,
              color: selectedWorkId != null
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 4.w),
            Text(
              selectedName ?? '选择作品',
              style: theme.textTheme.labelSmall?.copyWith(
                color: selectedWorkId != null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 14.sp,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tool status indicator
// ---------------------------------------------------------------------------

class _ToolStatusIndicator extends StatelessWidget {
  final ChatToolStatus? status;
  final List<ChatToolResult> results;

  const _ToolStatusIndicator({
    required this.status,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        margin: EdgeInsets.symmetric(vertical: 4.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Completed tool results
            for (final result in results)
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      result.success
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 14.sp,
                      color: result.success
                          ? colorScheme.primary
                          : colorScheme.error,
                    ),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        result.summary,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            // Current status
            if (status != null && !status!.isCompleted)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14.sp,
                    height: 14.sp,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    status!.statusMessage,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

class _ChatInputBar extends StatefulWidget {
  final AIChatLogic logic;

  const _ChatInputBar({required this.logic});

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKeyEvent;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      if (!isShift) {
        _handleSend();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _ChatTextField(
              controller: _controller,
              focusNode: _focusNode,
            ),
          ),
          SizedBox(width: 8.w),
          _SendMessageButton(
            logic: widget.logic,
            colorScheme: colorScheme,
            onPressed: _handleSend,
          ),
        ],
      ),
    );
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    unawaited(_sendWithWorkflowFollowup(text));
  }

  Future<void> _sendWithWorkflowFollowup(String text) async {
    final dispatch = await widget.logic.sendMessage(text);
    if (dispatch == null || !mounted) {
      return;
    }

    final runner = Get.find<WorkflowTaskRunner>();
    var status = dispatch.status;
    while (mounted && status == WorkflowTaskStatus.waitingUserInput) {
      final submitted = await WorkflowClarificationDialog.show(
        context,
        taskId: dispatch.taskId,
      );
      if (submitted != true) {
        return;
      }
      await widget.logic.syncWorkflowTaskMessage(dispatch.taskId);
      status = (await runner.getStatus(dispatch.taskId))?.status ??
          WorkflowTaskStatus.pending;
    }

    if (!mounted) {
      return;
    }
    if (status == WorkflowTaskStatus.waitingReview) {
      await Get.to(() => WorkflowTaskPage(taskId: dispatch.taskId));
    }
  }
}

class _ChatTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _ChatTextField({
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: 4,
      minLines: 1,
      decoration: InputDecoration(
        hintText: '输入消息... (Enter 发送, Shift+Enter 换行)',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
    );
  }
}

class _SendMessageButton extends StatelessWidget {
  final AIChatLogic logic;
  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  const _SendMessageButton({
    required this.logic,
    required this.colorScheme,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isGenerating = logic.state.isGenerating.value;
      return IconButton.filled(
        onPressed: isGenerating ? null : onPressed,
        icon: isGenerating
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.send_rounded, size: 20),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Bubble action button
// ---------------------------------------------------------------------------

class _BubbleAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BubbleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Icon(icon, size: 14.sp, color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}
