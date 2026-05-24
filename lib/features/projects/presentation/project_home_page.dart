import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';

class ProjectHomePage extends ConsumerWidget {
  const ProjectHomePage({super.key});

  static const shelfEntryKey = ValueKey<String>('project-home-shelf-entry');
  static const studioEntryKey = ValueKey<String>('project-home-studio-entry');
  static const bibleEntryKey = ValueKey<String>('project-home-bible-entry');
  static const productionEntryKey =
      ValueKey<String>('project-home-production-entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(appWorkspaceStoreProvider).currentProjectOrNull;
    final currentScene =
        ref.watch(appWorkspaceStoreProvider).currentSceneOrNull;

    if (project == null) {
      return _buildNoProjectShell(context);
    }

    final sceneTitle = currentScene?.title ?? '';
    final sceneLabel = currentScene?.chapterLabel ?? '';
    final displayLocation = sceneTitle.isEmpty
        ? project.displayRecentLocation
        : '$sceneLabel · $sceneTitle';

    return DesktopShellFrame(
      header: DesktopHeaderBar(
        title: project.title,
        subtitle: displayLocation.isEmpty ? null : displayLocation,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.space48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ProjectInfoSection(project: project),
                const SizedBox(height: AppDesignTokens.space48),
                _EntryGrid(
                  onNavigateShelf: () => _navigateToShelf(context),
                  onNavigateStudio: () => _navigateToStudio(context),
                  onNavigateBible: () => _navigateToBible(context),
                  onNavigateProduction: () => _navigateToProduction(context),
                ),
              ],
            ),
          ),
        ),
      ),
      statusBar: DesktopStatusStrip(
        leftText: project.genre.isEmpty ? '未分类' : project.genre,
        rightText: '作品主页',
      ),
    );
  }

  Widget _buildNoProjectShell(BuildContext context) {
    final theme = Theme.of(context);
    return DesktopShellFrame(
      header: const DesktopHeaderBar(title: '作品主页'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: desktopPalette(context).navInactive,
            ),
            const SizedBox(height: AppDesignTokens.space16),
            Text(
              '未选择作品',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
      statusBar: const DesktopStatusStrip(
        leftText: '无作品',
        rightText: '作品主页',
      ),
    );
  }

  void _navigateToShelf(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToStudio(BuildContext context) {
    AppNavigator.push(context, AppRoutes.workbench);
  }

  void _navigateToBible(BuildContext context) {
    AppNavigator.push(context, AppRoutes.workSettingsHub);
  }

  void _navigateToProduction(BuildContext context) {
    AppNavigator.push(context, AppRoutes.productionBoard);
  }
}

class _ProjectInfoSection extends StatelessWidget {
  const _ProjectInfoSection({required this.project});

  final ProjectRecord project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final trimmedSummary = project.summary.trim();

    return Column(
      children: [
        Text(
          project.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: palette.navActive,
            fontWeight: AppDesignTokens.weightMedium,
          ),
          textAlign: TextAlign.center,
        ),
        if (trimmedSummary.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.space12),
          Text(
            trimmedSummary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.navInactive,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _EntryGrid extends StatelessWidget {
  const _EntryGrid({
    required this.onNavigateShelf,
    required this.onNavigateStudio,
    required this.onNavigateBible,
    required this.onNavigateProduction,
  });

  final VoidCallback onNavigateShelf;
  final VoidCallback onNavigateStudio;
  final VoidCallback onNavigateBible;
  final VoidCallback onNavigateProduction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final crossAxisCount = isNarrow ? 2 : 4;
        final childAspectRatio = isNarrow ? 1.2 : 1.0;
        final spacing = isNarrow
            ? AppDesignTokens.space12
            : AppDesignTokens.space16;

        return GridView(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          children: [
            _EntryTile(
              key: ProjectHomePage.shelfEntryKey,
              icon: Icons.menu_book,
              label: '书架',
              description: '切换作品',
              onTap: onNavigateShelf,
            ),
            _EntryTile(
              key: ProjectHomePage.studioEntryKey,
              icon: Icons.edit_note,
              label: '创作台',
              description: '写作工作台',
              onTap: onNavigateStudio,
            ),
            _EntryTile(
              key: ProjectHomePage.bibleEntryKey,
              icon: Icons.library_books,
              label: '设定集',
              description: '作品资料',
              onTap: onNavigateBible,
            ),
            _EntryTile(
              key: ProjectHomePage.productionEntryKey,
              icon: Icons.analytics,
              label: '进度',
              description: '统计与发布',
              onTap: onNavigateProduction,
            ),
          ],
        );
      },
    );
  }
}

class _EntryTile extends StatefulWidget {
  const _EntryTile({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDesignTokens.durationFast,
          transform: Matrix4.translationValues(0.0, _hovered ? -4.0 : 0.0, 0.0),
          decoration: BoxDecoration(
            color: palette.elevated,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            border: Border.all(
              color: _hovered ? palette.primary : palette.border,
              width: 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: palette.shadowBase.withValues(alpha: AppDesignTokens.shadowMdAlpha),
                      blurRadius: AppDesignTokens.shadowMdBlur,
                      offset: const Offset(0, AppDesignTokens.shadowMdOffsetY),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(AppDesignTokens.space20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 32,
                color: _hovered ? palette.primary : palette.navInactive,
              ),
              const SizedBox(height: AppDesignTokens.space8),
              Text(
                widget.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: palette.navActive,
                  fontWeight: AppDesignTokens.weightMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesignTokens.space4),
              Text(
                widget.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.navInactive,
                  fontSize: AppDesignTokens.fontSizeSmall,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
