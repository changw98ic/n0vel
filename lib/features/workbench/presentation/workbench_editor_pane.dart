import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'workbench_shell_page.dart';

class WorkbenchEditorPane extends StatelessWidget {
  const WorkbenchEditorPane({
    required this.hasScenes,
    required this.sceneTitle,
    required this.draftText,
    required this.draftController,
    required this.focusNode,
    required this.scrollController,
    required this.isToolPanelOpen,
    required this.isRunCenterOpen,
    required this.onToggleToolPanel,
    required this.onOpenRunCenter,
    required this.onOpenBible,
    required this.onCreateFirstChapter,
    super.key,
  });

  final bool hasScenes;
  final String sceneTitle;
  final String draftText;
  final TextEditingController? draftController;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final bool isToolPanelOpen;
  final bool isRunCenterOpen;
  final VoidCallback onToggleToolPanel;
  final VoidCallback onOpenRunCenter;
  final VoidCallback onOpenBible;
  final VoidCallback onCreateFirstChapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          key: WorkbenchShellPage.editorPaneKey,
          decoration: frostedEditorDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasScenes)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 48,
                          color: palette.tertiaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '还没有章节',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: palette.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '创建第一章后即可开始写作。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.tertiaryText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: onCreateFirstChapter,
                          child: const Text('创建第一章'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _EditorToolbar(
                  sceneTitle: sceneTitle,
                  isToolPanelOpen: isToolPanelOpen,
                  isRunCenterOpen: isRunCenterOpen,
                  onToggleToolPanel: onToggleToolPanel,
                  onOpenRunCenter: onOpenRunCenter,
                  onOpenBible: onOpenBible,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: TextField(
                          key: WorkbenchShellPage.editorTextFieldKey,
                          controller: draftController,
                          focusNode: focusNode,
                          scrollController: scrollController,
                          maxLines: null,
                          expands: true,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 18,
                            height: 1.75,
                          ),
                          decoration: InputDecoration(
                            hintText: '开始书写当前章节正文…',
                            hintStyle: TextStyle(color: palette.tertiaryText),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.fromLTRB(
                              90,
                              54,
                              90,
                              16,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(90, 0, 90, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${draftText.length} 字',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF77736A),
                              ),
                            ),
                            Text(
                              '已保存',
                              key: WorkbenchShellPage.editorSurfaceMetaKey,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF77736A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.sceneTitle,
    required this.isToolPanelOpen,
    required this.isRunCenterOpen,
    required this.onToggleToolPanel,
    required this.onOpenRunCenter,
    required this.onOpenBible,
  });

  final String sceneTitle;
  final bool isToolPanelOpen;
  final bool isRunCenterOpen;
  final VoidCallback onToggleToolPanel;
  final VoidCallback onOpenRunCenter;
  final VoidCallback onOpenBible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      decoration: const BoxDecoration(color: Color(0xFFFBFAF6)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '正文写作',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF77736A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sceneTitle,
                  key: WorkbenchShellPage.editorSurfaceHeaderKey,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF243226),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          EditorToolbarIconButton(
            icon: Icons.undo,
            tooltip: '撤销',
            onTap: () {},
          ),
          const SizedBox(width: 14),
          EditorToolbarIconButton(
            icon: Icons.format_bold,
            tooltip: '加粗',
            onTap: () {},
          ),
          const SizedBox(width: 14),
          EditorToolbarIconButton(
            icon: Icons.message_outlined,
            tooltip: '批注',
            onTap: () {},
          ),
          const SizedBox(width: 14),
          EditorToolbarIconButton(
            icon: Icons.highlight,
            tooltip: '高亮',
            onTap: () {},
          ),
          const SizedBox(width: 14),
          EditorToolbarIconButton(
            key: WorkbenchShellPage.bibleToolButtonKey,
            icon: Icons.library_books_outlined,
            tooltip: '设定集',
            onTap: onOpenBible,
          ),
          const SizedBox(width: 14),
          EditorToolbarIconButton(
            key: WorkbenchShellPage.runCenterToolButtonKey,
            icon: Icons.play_circle_outline,
            tooltip: '运行中心',
            onTap: onOpenRunCenter,
            isActive: isRunCenterOpen,
          ),
          const SizedBox(width: 14),
          EditorToolbarIconButton(
            icon: isToolPanelOpen
                ? Icons.view_sidebar_outlined
                : Icons.view_sidebar,
            tooltip: isToolPanelOpen ? '关闭面板' : '打开助手',
            onTap: onToggleToolPanel,
            isActive: isToolPanelOpen,
          ),
        ],
      ),
    );
  }
}
