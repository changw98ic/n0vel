import 'package:flutter/material.dart';

import 'desktop_theme.dart';

class DesktopHandleBar extends StatelessWidget {
  const DesktopHandleBar({super.key, this.handleKey, this.onTap});

  final Key? handleKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final handle = SizedBox(
      key: handleKey,
      width: 20,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 72,
          decoration: BoxDecoration(
            color: palette.subtle,
            border: Border.all(color: palette.border),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(10),
            ),
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 36,
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.drag_indicator,
                size: 14,
                color: palette.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );

    if (onTap == null) {
      return ExcludeSemantics(child: handle);
    }

    return Semantics(
      button: true,
      label: '切换侧边菜单',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ExcludeSemantics(child: handle),
        ),
      ),
    );
  }
}

class DesktopMenuItemData {
  const DesktopMenuItemData({
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.buttonKey,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final Key? buttonKey;
}

enum DesktopWorkspaceSection {
  shelf,
  importExport,
  productionBoard,
  workbench,
  reviewTasks,
  style,
  scenes,
  characters,
  worldbuilding,
  storyBible,
  audit,
  settings,
}

List<DesktopMenuItemData> buildDesktopWorkspaceMenuItems({
  required DesktopWorkspaceSection selected,
  required VoidCallback onShelf,
  required VoidCallback onWorkbench,
  required VoidCallback onStyle,
  required VoidCallback onScenes,
  required VoidCallback onCharacters,
  required VoidCallback onWorldbuilding,
  required VoidCallback onAudit,
  required VoidCallback onSettings,
  VoidCallback? onImportExport,
  VoidCallback? onProductionBoard,
  VoidCallback? onReviewTasks,
  VoidCallback? onStoryBible,
  Key? importButtonKey,
  Key? workbenchButtonKey,
  Key? styleButtonKey,
  Key? sceneButtonKey,
  Key? characterButtonKey,
  Key? worldButtonKey,
  Key? storyBibleButtonKey,
  Key? auditButtonKey,
}) {
  return [
    DesktopMenuItemData(
      label: '书架',
      isSelected: selected == DesktopWorkspaceSection.shelf,
      onTap: onShelf,
    ),
    if (onImportExport != null)
      DesktopMenuItemData(
        label: '导入工程',
        buttonKey: importButtonKey,
        isSelected: selected == DesktopWorkspaceSection.importExport,
        onTap: onImportExport,
      ),
    DesktopMenuItemData(
      label: '编辑工作台',
      buttonKey: workbenchButtonKey,
      isSelected: selected == DesktopWorkspaceSection.workbench,
      onTap: onWorkbench,
    ),
    DesktopMenuItemData(
      label: '风格面板',
      buttonKey: styleButtonKey,
      isSelected: selected == DesktopWorkspaceSection.style,
      onTap: onStyle,
    ),
    DesktopMenuItemData(
      label: '场景管理',
      buttonKey: sceneButtonKey,
      isSelected: selected == DesktopWorkspaceSection.scenes,
      onTap: onScenes,
    ),
    DesktopMenuItemData(
      label: '角色库',
      buttonKey: characterButtonKey,
      isSelected: selected == DesktopWorkspaceSection.characters,
      onTap: onCharacters,
    ),
    DesktopMenuItemData(
      label: '世界观',
      buttonKey: worldButtonKey,
      isSelected: selected == DesktopWorkspaceSection.worldbuilding,
      onTap: onWorldbuilding,
    ),
    if (onStoryBible != null)
      DesktopMenuItemData(
        label: '作品圣经',
        buttonKey: storyBibleButtonKey,
        isSelected: selected == DesktopWorkspaceSection.storyBible,
        onTap: onStoryBible,
      ),
    DesktopMenuItemData(
      label: '审计中心',
      buttonKey: auditButtonKey,
      isSelected: selected == DesktopWorkspaceSection.audit,
      onTap: onAudit,
    ),
    if (onProductionBoard != null)
      DesktopMenuItemData(
        label: '生产看板',
        isSelected: selected == DesktopWorkspaceSection.productionBoard,
        onTap: onProductionBoard,
      ),
    if (onReviewTasks != null)
      DesktopMenuItemData(
        label: '审查任务',
        isSelected: selected == DesktopWorkspaceSection.reviewTasks,
        onTap: onReviewTasks,
      ),
    DesktopMenuItemData(
      label: '设置',
      isSelected: selected == DesktopWorkspaceSection.settings,
      onTap: onSettings,
    ),
  ];
}

class DesktopMenuDrawer extends StatelessWidget {
  const DesktopMenuDrawer({super.key, this.title = '菜单', required this.items});

  final String title;
  final List<DesktopMenuItemData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Semantics(
      label: '$title 导航菜单',
      explicitChildNodes: true,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: appPanelDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Semantics(
                    button: true,
                    selected: item.isSelected,
                    label: item.label,
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          key: item.buttonKey,
                          onPressed: item.onTap,
                          style: ButtonStyle(
                            minimumSize: WidgetStateProperty.all(Size.zero),
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: WidgetStateProperty.all(
                              item.isSelected
                                  ? palette.subtle
                                  : palette.elevated,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              item.isSelected
                                  ? theme.colorScheme.onSurface
                                  : theme.textTheme.bodySmall?.color,
                            ),
                            overlayColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.pressed)) {
                                return palette.subtle;
                              }
                              if (states.contains(WidgetState.hovered)) {
                                return palette.elevated;
                              }
                              return null;
                            }),
                            textStyle: WidgetStateProperty.all(
                              theme.textTheme.bodySmall?.copyWith(
                                fontWeight: item.isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            side: WidgetStateProperty.all(
                              BorderSide(color: palette.border),
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          child: Text(item.label),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DesktopMenuDrawerRegion extends StatelessWidget {
  const DesktopMenuDrawerRegion({
    super.key,
    required this.items,
    this.title = '菜单',
    this.isOpen = false,
    this.handleKey,
    this.drawerKey,
    this.onHandleTap,
  });

  final List<DesktopMenuItemData> items;
  final String title;
  final bool isOpen;
  final Key? handleKey;
  final Key? drawerKey;
  final VoidCallback? onHandleTap;

  @override
  Widget build(BuildContext context) {
    final handle = DesktopHandleBar(handleKey: handleKey, onTap: onHandleTap);

    if (!isOpen) {
      return handle;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: drawerKey,
          child: DesktopMenuDrawer(title: title, items: items),
        ),
        const SizedBox(width: 12),
        handle,
      ],
    );
  }
}
