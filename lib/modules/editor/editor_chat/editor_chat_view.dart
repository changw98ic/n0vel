import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../../../core/services/ai/context/context_manager.dart' as cm;
import 'editor_chat_logic.dart';

/// 编辑器内多轮对话面板
/// 替代原有的 AssistantPanel，支持多轮上下文连续对话
class EditorChatPanel extends StatefulWidget {
  /// 获取最新章节内容的回调
  final ValueGetter<String> chapterContent;

  /// 插入文本到编辑器的回调
  final void Function(String) onInsert;

  const EditorChatPanel({
    super.key,
    required this.chapterContent,
    required this.onInsert,
  });

  @override
  State<EditorChatPanel> createState() => _EditorChatPanelState();
}

class _EditorChatPanelState extends State<EditorChatPanel> {
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();
  late final EditorChatLogic _logic;

  @override
  void initState() {
    super.initState();
    _logic = EditorChatLogic();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _logic.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Quick actions bar
        _buildQuickActions(theme, colorScheme),
        SizedBox(height: 8.h),

        // Message thread
        Expanded(
          child: Obx(() {
            final msgs = _logic.messages;
            if (msgs.isEmpty) {
              return Center(
                child: Text(
                  '输入消息或使用快捷操作开始对话',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            _scrollToBottom();
            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              itemCount: msgs.length,
              itemBuilder: (context, index) =>
                  _buildMessageBubble(msgs[index], theme, colorScheme),
            );
          }),
        ),

        // Input bar
        _buildInputBar(theme, colorScheme),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Quick actions
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(ThemeData theme, ColorScheme colorScheme) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: [
        _QuickChip(
          icon: Icons.auto_awesome_rounded,
          label: '续写',
          color: colorScheme.primary,
          onTap: () => _logic.continuation(widget.chapterContent()),
        ),
        _QuickChip(
          icon: Icons.chat_bubble_outline_rounded,
          label: '对白',
          color: colorScheme.secondary,
          onTap: () => _logic.dialogue(widget.chapterContent()),
        ),
        _QuickChip(
          icon: Icons.lightbulb_outline_rounded,
          label: '剧情灵感',
          color: colorScheme.tertiary,
          onTap: () => _logic.plotInspiration(widget.chapterContent()),
        ),
        _QuickChip(
          icon: Icons.psychology_alt_rounded,
          label: '角色模拟',
          color: colorScheme.primary,
          onTap: () => _logic.characterSimulation(widget.chapterContent()),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Message bubble
  // ---------------------------------------------------------------------------

  Widget _buildMessageBubble(
      cm.ChatMessage message, ThemeData theme, ColorScheme colorScheme) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 0.85.sw),
        margin: EdgeInsets.symmetric(vertical: 4.h),
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : colorScheme.surfaceContainerLowest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppTokens.radiusMd),
            topRight: Radius.circular(AppTokens.radiusMd),
            bottomLeft: isUser
                ? Radius.circular(AppTokens.radiusMd)
                : Radius.circular(4),
            bottomRight: isUser
                ? Radius.circular(4)
                : Radius.circular(AppTokens.radiusMd),
          ),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(
              message.content,
              style: theme.textTheme.bodySmall,
            ),
            if (!isUser) ...[
              SizedBox(height: 6.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallAction(
                    icon: Icons.copy_rounded,
                    tooltip: '复制',
                    onTap: () {
                      // ignore: unnecessary_lambdas
                      Get.snackbar('已复制', '内容已复制到剪贴板',
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 1));
                    },
                  ),
                  SizedBox(width: 4.w),
                  _SmallAction(
                    icon: Icons.add_circle_outline_rounded,
                    tooltip: '插入到编辑器',
                    onTap: () => widget.onInsert(message.content),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input bar
  // ---------------------------------------------------------------------------

  Widget _buildInputBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 6.h),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promptController,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: '输入消息...',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              onSubmitted: _handleSend,
            ),
          ),
          SizedBox(width: 6.w),
          Obx(() => IconButton.filled(
                onPressed: _logic.isGenerating.value
                    ? null
                    : () => _handleSend(_promptController.text),
                icon: _logic.isGenerating.value
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              )),
          IconButton(
            tooltip: '清空对话',
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: _logic.clearHistory,
          ),
        ],
      ),
    );
  }

  void _handleSend(String text) {
    if (text.trim().isEmpty || _logic.isGenerating.value) return;
    _promptController.clear();
    _logic.sendMessage(text, widget.chapterContent());
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14.sp, color: color),
              SizedBox(width: 4.w),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallAction({
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
          padding: EdgeInsets.all(2.w),
          child: Icon(icon, size: 14.sp),
        ),
      ),
    );
  }
}
