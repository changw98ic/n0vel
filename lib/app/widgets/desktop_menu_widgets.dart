import 'package:flutter/material.dart';

import 'app_split_handle.dart';
import 'desktop_theme.dart';

class DesktopHandleBar extends StatelessWidget {
  const DesktopHandleBar({super.key, this.handleKey, this.onTap});

  final Key? handleKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final handle = AppSplitHandle(
      key: handleKey,
      onTap: onTap,
      height: 48,
      semanticLabel: onTap != null ? '切换侧边导航' : null,
    );

    if (onTap == null) {
      return ExcludeSemantics(child: handle);
    }
    return handle;
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

  audit,
  settings,
  workSettingsHub,
  revisionHub,
}

List<DesktopMenuItemData> buildDesktopWorkspaceMenuItems({
  required DesktopWorkspaceSection selected,
  required VoidCallback onShelf,
  required VoidCallback onWorkbench,
  required VoidCallback onWorkSettings,
  required VoidCallback onRevision,
  required VoidCallback onReading,
  required VoidCallback onSettings,
  Key? workbenchButtonKey,
  Key? readingButtonKey,
}) {
  final workSettingsSelected =
      selected == DesktopWorkspaceSection.workSettingsHub ||
      selected == DesktopWorkspaceSection.characters ||
      selected == DesktopWorkspaceSection.worldbuilding ||
      selected == DesktopWorkspaceSection.style;

  final revisionSelected =
      selected == DesktopWorkspaceSection.revisionHub ||
      selected == DesktopWorkspaceSection.audit ||
      selected == DesktopWorkspaceSection.reviewTasks ||
      selected == DesktopWorkspaceSection.productionBoard;

  return [
    DesktopMenuItemData(
      label: '书架',
      isSelected: selected == DesktopWorkspaceSection.shelf,
      onTap: onShelf,
    ),
    DesktopMenuItemData(
      label: '写作',
      buttonKey: workbenchButtonKey,
      isSelected: selected == DesktopWorkspaceSection.workbench,
      onTap: onWorkbench,
    ),
    DesktopMenuItemData(
      label: '作品设定',
      isSelected: workSettingsSelected,
      onTap: onWorkSettings,
    ),
    DesktopMenuItemData(
      label: '改稿',
      isSelected: revisionSelected,
      onTap: onRevision,
    ),
    DesktopMenuItemData(
      label: '阅读',
      buttonKey: readingButtonKey,
      isSelected: selected == DesktopWorkspaceSection.scenes,
      onTap: onReading,
    ),
    DesktopMenuItemData(
      label: '设置',
      isSelected: selected == DesktopWorkspaceSection.settings,
      onTap: onSettings,
    ),
  ];
}

class DesktopMenuDrawer extends StatelessWidget {
  const DesktopMenuDrawer({super.key, this.title = '导航', required this.items});

  final String title;
  final List<DesktopMenuItemData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Semantics(
      label: '$title 侧边导航',
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
                            alignment: Alignment.centerLeft,
                            minimumSize: WidgetStateProperty.all(Size.zero),
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (item.isSelected) {
                                return palette.subtle;
                              }
                              if (states.contains(WidgetState.pressed)) {
                                return palette.subtle.withValues(alpha: 0.76);
                              }
                              if (states.contains(WidgetState.hovered)) {
                                return palette.subtle.withValues(alpha: 0.42);
                              }
                              return Colors.transparent;
                            }),
                            foregroundColor: WidgetStateProperty.all(
                              item.isSelected
                                  ? theme.colorScheme.onSurface
                                  : palette.secondaryText,
                            ),
                            overlayColor: WidgetStateProperty.all(
                              Colors.transparent,
                            ),
                            textStyle: WidgetStateProperty.all(
                              theme.textTheme.bodySmall?.copyWith(
                                fontWeight: item.isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            side: WidgetStateProperty.resolveWith((states) {
                              if (item.isSelected) {
                                return BorderSide(color: palette.border);
                              }
                              return const BorderSide(
                                color: Colors.transparent,
                              );
                            }),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
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
    this.title = '导航',
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
