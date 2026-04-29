import 'package:flutter/material.dart';

import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/widgets/desktop_shell.dart';

class VersionHistoryPage extends StatefulWidget {
  const VersionHistoryPage({super.key});

  static const versionListKey = ValueKey<String>('version-history-list');

  @override
  State<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends State<VersionHistoryPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final versionStore = AppVersionScope.of(context);
    final entries = versionStore.entries;
    final selectedIndex = _selectedIndex.clamp(0, entries.length - 1);
    final selectedEntry = entries[selectedIndex];
    final hasRestorableHistory = entries.length > 1;

    return DesktopShellFrame(
      header: const DesktopHeaderBar(
        title: '章节版本',
        subtitle: '查看当前章节的本地版本池并恢复较早版本',
        showBackButton: true,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 280,
            child: Container(
              key: VersionHistoryPage.versionListKey,
              padding: const EdgeInsets.all(16),
              decoration: appPanelDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('版本池', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                              horizontal: 12,
                              vertical: 10,
                            ),
                            backgroundColor: isSelected
                                ? palette.subtle
                                : palette.elevated,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: appPanelDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('版本信息', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('来源', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    '来源：${selectedEntry.label}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (!hasRestorableHistory) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
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
                          const SizedBox(height: 8),
                          Text(
                            '当前只有一个章节版本，因此暂时不可恢复或对比历史版本。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: hasRestorableHistory
                        ? FilledButton(
                            onPressed: () {
                              AppDraftScope.of(
                                context,
                              ).updateText(selectedEntry.content);
                              versionStore.restoreEntry(selectedEntry);
                              setState(() {
                                _selectedIndex = 0;
                              });
                            },
                            child: const Text('恢复此版本'),
                          )
                        : OutlinedButton(
                            onPressed: null,
                            child: const Text('暂不可恢复'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      statusBar: const DesktopStatusStrip(
        leftText: '版本池保留最近 5 条记录',
        rightText: '本地恢复不会自动覆盖未保存草稿',
      ),
    );
  }
}
