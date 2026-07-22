import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/state/app_draft_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'workbench_shell_page.dart';

class WorkbenchEditorPane extends StatelessWidget {
  const WorkbenchEditorPane({
    required this.hasScenes,
    required this.sceneTitle,
    required this.draftText,
    required this.persistenceStatus,
    required this.draftController,
    required this.focusNode,
    required this.scrollController,
    required this.isToolPanelOpen,
    required this.onToggleToolPanel,
    required this.onCreateFirstChapter,
    this.isDirty = false,
    super.key,
  });

  final bool hasScenes;
  final String sceneTitle;
  final String draftText;
  final DraftPersistenceStatus persistenceStatus;
  final TextEditingController? draftController;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final bool isToolPanelOpen;
  final VoidCallback onToggleToolPanel;
  final VoidCallback onCreateFirstChapter;
  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Expanded(
      child: ClipRRect(
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
                    onToggleToolPanel: onToggleToolPanel,
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
                                _draftPersistenceLabel(
                                  persistenceStatus,
                                  isDirty: isDirty,
                                ),
                                key: WorkbenchShellPage.editorSurfaceMetaKey,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _draftPersistenceColor(
                                    persistenceStatus,
                                    isDirty: isDirty,
                                  ),
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
      ),
    );
  }
}

String _draftPersistenceLabel(
  DraftPersistenceStatus status, {
  required bool isDirty,
}) {
  if (status == DraftPersistenceStatus.saved && isDirty) {
    return '有未保存的修改';
  }
  switch (status) {
    case DraftPersistenceStatus.saved:
      return '已保存';
    case DraftPersistenceStatus.saving:
      return '保存中…';
    case DraftPersistenceStatus.failed:
      return '保存失败';
  }
}

Color _draftPersistenceColor(
  DraftPersistenceStatus status, {
  required bool isDirty,
}) {
  if (status == DraftPersistenceStatus.saved && isDirty) {
    return const Color(0xFFB6813B);
  }
  switch (status) {
    case DraftPersistenceStatus.saved:
      return const Color(0xFF77736A);
    case DraftPersistenceStatus.saving:
      return const Color(0xFF8A6A2D);
    case DraftPersistenceStatus.failed:
      return const Color(0xFFB14A3B);
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.sceneTitle,
    required this.isToolPanelOpen,
    required this.onToggleToolPanel,
  });

  final String sceneTitle;
  final bool isToolPanelOpen;
  final VoidCallback onToggleToolPanel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      decoration: const BoxDecoration(color: Color(0xFFFBFAF6)),
      child: Row(
        children: [
          Column(
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
          const Spacer(),
          const EditorToolbarIconButton(
            icon: Icons.undo,
            tooltip: '撤销',
            onTap: null,
          ),
          const SizedBox(width: 14),
          const EditorToolbarIconButton(
            icon: Icons.format_bold,
            tooltip: '加粗',
            onTap: null,
          ),
          const SizedBox(width: 14),
          const EditorToolbarIconButton(
            icon: Icons.message_outlined,
            tooltip: '批注',
            onTap: null,
          ),
          const SizedBox(width: 14),
          const EditorToolbarIconButton(
            icon: Icons.highlight,
            tooltip: '高亮',
            onTap: null,
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
