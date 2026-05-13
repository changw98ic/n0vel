import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/app_dialog.dart';
import '../../../app/widgets/desktop_shell.dart';

class VersionHistoryPage extends ConsumerStatefulWidget {
  const VersionHistoryPage({super.key});

  static const versionListKey = ValueKey<String>('version-history-list');

  @override
  ConsumerState<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends ConsumerState<VersionHistoryPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final versionStore = ref.watch(appVersionStoreProvider);
    final entries = versionStore.entries;
    if (entries.isEmpty) {
      return const DesktopShellFrame(
        header: DesktopHeaderBar(
          title: '章节版本',
          subtitle: '查看当前章节的本地版本池并恢复较早版本',
          showBackButton: true,
        ),
        body: Center(child: Text('暂无版本记录')),
      );
    }
    final selectedIndex = _selectedIndex.clamp(0, entries.length - 1);
    final selectedEntry = entries[selectedIndex];
    final hasRestorableHistory = entries.length > 1;

    return DesktopShellFrame(
      header: const DesktopHeaderBar(
        title: '章节版本',
        subtitle: '查看当前章节的本地版本池并恢复较早版本',
        showBackButton: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < AppDesignTokens.breakpointMedium;
          final listPanel = Container(
            key: VersionHistoryPage.versionListKey,
            padding: const EdgeInsets.all(AppDesignTokens.space16),
            decoration: appPanelDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('版本池', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppDesignTokens.space12),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDesignTokens.space8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isSelected = index == selectedIndex;
                      final palette = desktopPalette(context);
                      return TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDesignTokens.space12,
                            vertical: 10,
                          ),
                          backgroundColor: isSelected
                              ? palette.subtle
                              : palette.elevated,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignTokens.radiusMedium,
                            ),
                            side: BorderSide(color: palette.border),
                          ),
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(
                          entry.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );

          final detailPanel = Container(
            padding: const EdgeInsets.all(AppDesignTokens.space16),
            decoration: appPanelDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('版本信息', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppDesignTokens.space12),
                Text('来源', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppDesignTokens.space4),
                Text(
                  '来源：${selectedEntry.label}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppDesignTokens.space12),
                if (!hasRestorableHistory) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDesignTokens.space16),
                    decoration: appPanelDecoration(
                      context,
                      color: desktopPalette(context).elevated,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前章节只有 1 个版本',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppDesignTokens.space8),
                        Text(
                          '当前只有一个章节版本，因此暂时不可恢复或对比历史版本。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppDesignTokens.space12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDesignTokens.space16),
                    decoration: appPanelDecoration(
                      context,
                      color: desktopPalette(context).elevated,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        selectedEntry.content,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesignTokens.space12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: hasRestorableHistory
                      ? FilledButton(
                          onPressed: () async {
                            final confirmed = await showAppConfirmDialog(
                              context: context,
                              title: '恢复版本',
                              description: '确定要恢复到此版本吗？当前草稿内容会被替换。',
                              body: const SizedBox.shrink(),
                              confirmText: '恢复',
                            );
                            if (!confirmed || !context.mounted) {
                              return;
                            }
                            ref
                                .read(appDraftStoreProvider)
                                .updateText(selectedEntry.content);
                            versionStore.restoreEntry(selectedEntry);
                            setState(() {
                              _selectedIndex = 0;
                            });
                          },
                          child: const Text('恢复此版本'),
                        )
                      : const OutlinedButton(
                          onPressed: null,
                          child: Text('暂不可恢复'),
                        ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight * 0.35,
                  child: listPanel,
                ),
                const SizedBox(height: AppDesignTokens.space16),
                Expanded(child: detailPanel),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: listPanel),
              const SizedBox(width: AppDesignTokens.space16),
              Expanded(child: detailPanel),
            ],
          );
        },
      ),
      statusBar: const DesktopStatusStrip(
        leftText: '版本池保留最近 5 条记录',
        rightText: '本地恢复不会自动覆盖未保存草稿',
      ),
    );
  }
}
