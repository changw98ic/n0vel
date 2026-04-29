import 'package:flutter/material.dart';

import '../../../app/di/service_scope.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_outline_store.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../domain/story_bible_models.dart';

class StoryBiblePage extends StatefulWidget {
  const StoryBiblePage({super.key});

  static const titleKey = ValueKey<String>('story-bible-title');
  static const factsKey = ValueKey<String>('story-bible-facts');
  static const statusKey = ValueKey<String>('story-bible-status');

  @override
  State<StoryBiblePage> createState() => _StoryBiblePageState();
}

class _StoryBiblePageState extends State<StoryBiblePage> {
  bool _isDrawerOpen = false;
  final StoryBibleAggregator _aggregator = const StoryBibleAggregator();

  @override
  Widget build(BuildContext context) {
    final workspaceStore = AppWorkspaceScope.of(context);
    final outlineStore = ServiceScope.of(context).resolve<StoryOutlineStore>();

    return ListenableBuilder(
      listenable: outlineStore,
      builder: (context, _) {
        final outline =
            outlineStore.snapshot.projectId == workspaceStore.currentProjectId
            ? outlineStore.snapshot
            : null;
        final bible = _aggregator.build(
          project: workspaceStore.currentProject,
          characters: workspaceStore.characters,
          worldNodes: workspaceStore.worldNodes,
          scenes: workspaceStore.scenes,
          auditIssues: workspaceStore.auditIssues,
          outline: outline,
        );

        return DesktopShellFrame(
          header: DesktopHeaderBar(
            title: '作品圣经',
            subtitle: '${bible.projectTitle} · 聚合已有项目事实',
            showBackButton: true,
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopMenuDrawerRegion(
                isOpen: _isDrawerOpen,
                onHandleTap: () {
                  setState(() {
                    _isDrawerOpen = !_isDrawerOpen;
                  });
                },
                items: _menuItems(context),
              ),
              const SizedBox(width: 16),
              Expanded(child: _StoryBibleFacts(snapshot: bible)),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: _StoryBibleStatus(snapshot: bible)),
            ],
          ),
          statusBar: DesktopStatusStrip(
            leftText: '已聚合 ${bible.factCount} 条设定事实',
            rightText: '状态区仅显示占位与已有审计计数',
          ),
        );
      },
    );
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return buildDesktopWorkspaceMenuItems(
      selected: DesktopWorkspaceSection.storyBible,
      onShelf: () => Navigator.of(context).pop(),
      onProductionBoard: () =>
          AppNavigator.push(context, AppRoutes.productionBoard),
      onWorkbench: () => AppNavigator.push(context, AppRoutes.workbench),
      onStyle: () => AppNavigator.push(context, AppRoutes.style),
      onScenes: () => AppNavigator.push(context, AppRoutes.scenes),
      onCharacters: () => AppNavigator.push(context, AppRoutes.characters),
      onWorldbuilding: () =>
          AppNavigator.push(context, AppRoutes.worldbuilding),
      onStoryBible: () {
        setState(() {
          _isDrawerOpen = false;
        });
      },
      onAudit: () => AppNavigator.push(context, AppRoutes.audit),
      onSettings: () => AppNavigator.push(context, AppRoutes.settings),
    );
  }
}

class _StoryBibleFacts extends StatelessWidget {
  const _StoryBibleFacts({required this.snapshot});

  final StoryBibleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: StoryBiblePage.factsKey,
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        itemCount: snapshot.factSections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return _StoryBibleSectionCard(section: snapshot.factSections[index]);
        },
      ),
    );
  }
}

class _StoryBibleStatus extends StatelessWidget {
  const _StoryBibleStatus({required this.snapshot});

  final StoryBibleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: StoryBiblePage.statusKey,
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        itemCount: snapshot.statusSections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _StoryBibleSectionCard(
            section: snapshot.statusSections[index],
          );
        },
      ),
    );
  }
}

class _StoryBibleSectionCard extends StatelessWidget {
  const _StoryBibleSectionCard({required this.section});

  final StoryBibleSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (section.isEmpty)
          AppEmptyState(title: section.title, message: section.emptyMessage)
        else
          for (final entry in section.entries) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: palette.subtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: theme.textTheme.titleSmall),
                  if (entry.meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(entry.meta, style: theme.textTheme.bodySmall),
                  ],
                  if (entry.body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry.body,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ],
      ],
    );
  }
}
