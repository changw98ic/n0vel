import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_list_filter.dart';
import '../../../app/widgets/desktop_shell.dart';

enum ProjectListUiState {
  ready,
  empty,
  searchNoResults,
  databaseReadFailed,
  importFailed,
  deleteConfirm,
}

class ProjectListPage extends StatefulWidget {
  const ProjectListPage({super.key, this.uiState = ProjectListUiState.ready});

  static const pageTitleKey = ValueKey<String>('project-list-title');
  static const shelfKey = ValueKey<String>('project-list-shelf');
  static const detailKey = ValueKey<String>('project-list-selected-card');
  static const footerKey = ValueKey<String>('project-list-footer');
  static const importButtonKey = ValueKey<String>('project-list-import-button');
  static const newProjectButtonKey = ValueKey<String>(
    'project-list-new-project-button',
  );
  static const searchFieldKey = ValueKey<String>('project-list-search-field');
  static const continueProjectButtonKey = ValueKey<String>(
    'project-list-continue-project-button',
  );
  static const openProjectButtonKey = ValueKey<String>(
    'project-list-open-project-button',
  );
  static const workbenchShortcutKey = ValueKey<String>(
    'project-list-shortcut-workbench',
  );
  static const styleShortcutKey = ValueKey<String>(
    'project-list-shortcut-style',
  );
  static const characterShortcutKey = ValueKey<String>(
    'project-list-shortcut-character',
  );
  static const worldShortcutKey = ValueKey<String>(
    'project-list-shortcut-world',
  );
  static const storyBibleShortcutKey = ValueKey<String>(
    'project-list-shortcut-story-bible',
  );
  static const storyBibleButtonKey = ValueKey<String>(
    'project-list-story-bible-button',
  );
  static const auditShortcutKey = ValueKey<String>(
    'project-list-shortcut-audit',
  );
  static const sceneShortcutKey = ValueKey<String>(
    'project-list-shortcut-scene',
  );
  static const menuDrawerHandleKey = ValueKey<String>(
    'project-list-menu-drawer-handle',
  );
  static const menuDrawerPanelKey = ValueKey<String>(
    'project-list-menu-drawer-panel',
  );

  final ProjectListUiState uiState;

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isDrawerOpen = false;
  String? _selectedProjectId;
  int _sortIndex = 0;
  int _filterIndex = 0;

  static const _sortOptions = <AppListSortOption<ProjectRecord>>[
    AppListSortOption(label: '打开时间', compare: _compareByRecent),
    AppListSortOption(label: '按标题', compare: _compareByTitle),
    AppListSortOption(label: '按类型', compare: _compareByGenre),
  ];

  static int _compareByRecent(ProjectRecord a, ProjectRecord b) =>
      b.lastOpenedAtMs.compareTo(a.lastOpenedAtMs);

  static int _compareByTitle(ProjectRecord a, ProjectRecord b) =>
      a.title.compareTo(b.title);

  static int _compareByGenre(ProjectRecord a, ProjectRecord b) =>
      a.genre.compareTo(b.genre);

  List<AppListFilterOption<ProjectRecord>> _filterOptions(
    BuildContext context,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const dayMs = 24 * 60 * 60 * 1000;
    return [
      AppListFilterOption<ProjectRecord>(label: '全部项目', test: (_) => true),
      AppListFilterOption<ProjectRecord>(
        label: '最近打开',
        test: (p) => now - p.lastOpenedAtMs < dayMs,
      ),
      AppListFilterOption<ProjectRecord>(
        label: '进行中',
        test: (p) => p.lastOpenedAtMs > 0,
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uiState == ProjectListUiState.databaseReadFailed) {
      return _buildDatabaseFailureShell(context);
    }

    final projects = _visibleProjects(_projects(context));
    final selectedProject = _resolveSelectedProject(projects);

    return DesktopShellFrame(
      header: _ProjectShelfHeader(
        titleKey: ProjectListPage.pageTitleKey,
        searchController: _searchController,
        onCreateProject: _createProject,
        onImportProject: () => _openImportExport(context),
        onSearchChanged: (_) {
          setState(() {});
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = panelSpacingFor(constraints.maxWidth);
          final hideSidebar =
              constraints.maxWidth < DesktopLayoutTokens.narrowBreakpoint;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopMenuDrawerRegion(
                handleKey: ProjectListPage.menuDrawerHandleKey,
                drawerKey: ProjectListPage.menuDrawerPanelKey,
                isOpen: _isDrawerOpen,
                onHandleTap: () {
                  setState(() {
                    _isDrawerOpen = !_isDrawerOpen;
                  });
                },
                items: _menuItems(context),
              ),
              SizedBox(width: spacing),
              if (!hideSidebar)
                SizedBox(
                  width: DesktopLayoutTokens.standardSidebarWidth,
                  child: _ProjectFilterPanel(
                    filterIndex: _filterIndex,
                    sortIndex: _sortIndex,
                    onFilterChanged: (i) => setState(() => _filterIndex = i),
                    onSortChanged: (i) => setState(() => _sortIndex = i),
                  ),
                ),
              if (!hideSidebar) SizedBox(width: spacing + 8),
              Expanded(
                child: Container(
                  key: ProjectListPage.shelfKey,
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildShelfContent(context, projects, selectedProject),
                ),
              ),
            ],
          );
        },
      ),
      statusBar: DesktopStatusStrip(
        stripKey: ProjectListPage.footerKey,
        leftText: _footerStatus(projectCount: _projects(context).length),
        rightText: '${_sortOptions[_sortIndex].label} · 本地书架',
      ),
    );
  }

  Widget _buildDatabaseFailureShell(BuildContext context) {
    final theme = Theme.of(context);
    return DesktopShellFrame(
      header: _ProjectShelfHeader(
        titleKey: ProjectListPage.pageTitleKey,
        searchController: _searchController,
        onCreateProject: _createProject,
        onImportProject: () => _openImportExport(context),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = panelSpacingFor(constraints.maxWidth);
          final hideSidebar =
              constraints.maxWidth < DesktopLayoutTokens.narrowBreakpoint;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopMenuDrawerRegion(
                handleKey: ProjectListPage.menuDrawerHandleKey,
                drawerKey: ProjectListPage.menuDrawerPanelKey,
                isOpen: _isDrawerOpen,
                onHandleTap: () {
                  setState(() {
                    _isDrawerOpen = !_isDrawerOpen;
                  });
                },
                items: _menuItems(context),
              ),
              SizedBox(width: spacing),
              if (!hideSidebar)
                SizedBox(
                  width: DesktopLayoutTokens.standardSidebarWidth,
                  child: _ProjectFilterPanel(
                    filterIndex: _filterIndex,
                    sortIndex: _sortIndex,
                    onFilterChanged: (i) => setState(() => _filterIndex = i),
                    onSortChanged: (i) => setState(() => _sortIndex = i),
                  ),
                ),
              if (!hideSidebar) SizedBox(width: spacing + 8),
              Expanded(
                child: Container(
                  decoration: appPanelDecoration(context),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('书架未加载', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Text(
                        '本地数据库读取失败，请重试或从菜单进入导入工程。',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const ProjectListPage(),
                          ),
                        ),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      statusBar: const DesktopStatusStrip(
        leftText: '数据库读取失败',
        rightText: '等待恢复本地索引',
      ),
    );
  }

  Widget _buildShelfContent(
    BuildContext context,
    List<ProjectRecord> visibleProjects,
    ProjectRecord? selectedProject,
  ) {
    final palette = desktopPalette(context);
    if (widget.uiState == ProjectListUiState.empty) {
      return AppEmptyState(
        style: AppEmptyStateStyle.prominent,
        title: '当前还没有项目',
        message: '可以直接从书架里新建一个项目，或从左侧菜单导入工程。',
        actions: [
          FilledButton(onPressed: _createProject, child: const Text('新建项目')),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _isDrawerOpen = true;
              });
            },
            child: const Text('打开菜单'),
          ),
        ],
      );
    }

    if (widget.uiState == ProjectListUiState.searchNoResults ||
        visibleProjects.isEmpty) {
      return AppEmptyState(
        style: AppEmptyStateStyle.prominent,
        title: '没有匹配的项目',
        message: '换个关键词试试，或直接从书架里新建一个项目。',
        actions: [
          FilledButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
              });
            },
            child: const Text('清空搜索'),
          ),
          OutlinedButton(onPressed: _createProject, child: const Text('新建项目')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近打开的项目会自动排在前面；点击卡片时，在卡片上直接浮出操作。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (widget.uiState == ProjectListUiState.importFailed) ...[
          const SizedBox(height: 16),
          _InlineNoticeCard(
            title: '导入失败',
            message: '工程包结构不完整，当前书架内容未受影响，可修正包后重试。',
            accent: palette.danger,
          ),
        ],
        if (widget.uiState == ProjectListUiState.deleteConfirm) ...[
          const SizedBox(height: 16),
          _InlineNoticeCard(
            title: '删除确认',
            message: '这会移除本地书架中的项目记录，不会删除你已经手动导出的工程包。',
            accent: palette.danger,
          ),
        ],
        const SizedBox(height: 20),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth <
                  DesktopLayoutTokens.compactPageBreakpoint;
              final currentProject = selectedProject ?? visibleProjects.first;
              final shelf = _ProjectShelfPanel(
                projects: visibleProjects,
                selectedProject: currentProject,
                compact: compact,
                onCreateProject: _createProject,
                onSelectProject: _selectProject,
              );
              final detailPanel = _ProjectDetailPanel(
                key: ProjectListPage.detailKey,
                project: currentProject,
                compact: compact,
                onOpen: () => _openWorkbench(context, currentProject),
                onEdit: () => _openWorkbench(context, currentProject),
                onStoryBible: () => _openStoryBible(context, currentProject),
                onDelete: () => _confirmDeleteProject(context, currentProject),
              );

              if (compact) {
                return ListView(
                  children: [
                    SizedBox(height: 304, child: detailPanel),
                    const SizedBox(height: 16),
                    shelf,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: shelf),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: DesktopLayoutTokens.projectDetailWidth,
                    child: detailPanel,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _selectProject(ProjectRecord project) {
    final store = AppWorkspaceScope.of(context);
    setState(() {
      store.selectProject(project.id);
      _selectedProjectId = project.id;
    });
  }

  Future<void> _confirmDeleteProject(
    BuildContext context,
    ProjectRecord project,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: '确认删除项目',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProjectDialogField(
                label: '删除对象',
                child: Text(
                  project.title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              _ProjectDialogField(
                label: '删除说明',
                child: Text(
                  '删除后将移除本地数据库中的项目记录、最近写作位置和相关索引，但不会删除你手动导出的工程包。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final store = AppWorkspaceScope.of(context);
    setState(() {
      store.deleteProject(project);
      if (_selectedProjectId == project.id) {
        _selectedProjectId = store.currentProjectId.isEmpty
            ? null
            : store.currentProjectId;
      }
    });
  }

  void _openImportExport(BuildContext context) {
    setState(() {
      _isDrawerOpen = false;
    });
    AppNavigator.push(context, AppRoutes.importExport);
  }

  void _openWorkbench(BuildContext context, ProjectRecord project) {
    final store = AppWorkspaceScope.of(context);
    store.openProject(project.id);
    setState(() {
      _selectedProjectId = project.id;
    });
    AppNavigator.push(context, AppRoutes.workbench);
  }

  void _openStoryBible(BuildContext context, ProjectRecord project) {
    final store = AppWorkspaceScope.of(context);
    store.openProject(project.id);
    setState(() {
      _selectedProjectId = project.id;
      _isDrawerOpen = false;
    });
    AppNavigator.push(context, AppRoutes.storyBible);
  }

  void _createProject() {
    final store = AppWorkspaceScope.of(context);
    setState(() {
      store.createProject();
      _selectedProjectId = store.currentProjectId;
      _searchController.clear();
    });
  }

  List<ProjectRecord> _visibleProjects(List<ProjectRecord> projects) {
    final filters = _filterOptions(context);
    return applyListFilter(
      items: projects,
      searchQuery: _searchController.text.trim(),
      searchExtractor: (p) =>
          '${p.title} ${p.genre} ${p.tag} ${p.summary} ${p.recentLocation}',
      activeFilter: filters[_filterIndex],
      activeSort: _sortOptions[_sortIndex],
    );
  }

  ProjectRecord? _resolveSelectedProject(List<ProjectRecord> visibleProjects) {
    if (visibleProjects.isEmpty) {
      return null;
    }
    final store = AppWorkspaceScope.of(context);
    final resolvedProjectId = _selectedProjectId ?? store.currentProjectId;
    if (resolvedProjectId.isEmpty) {
      return visibleProjects.first;
    }
    return visibleProjects.cast<ProjectRecord?>().firstWhere(
      (project) => project?.id == resolvedProjectId,
      orElse: () => visibleProjects.first,
    );
  }

  List<ProjectRecord> _projects(BuildContext context) =>
      AppWorkspaceScope.of(context).projects;

  String _footerStatus({required int projectCount}) {
    switch (widget.uiState) {
      case ProjectListUiState.ready:
        return '本地数据库正常 · 书架共 $projectCount 部作品';
      case ProjectListUiState.empty:
        return '当前还没有本地项目';
      case ProjectListUiState.searchNoResults:
        return '当前搜索没有命中项目';
      case ProjectListUiState.databaseReadFailed:
        return '数据库读取失败';
      case ProjectListUiState.importFailed:
        return '导入失败：工程包结构不完整';
      case ProjectListUiState.deleteConfirm:
        return '等待删除确认';
    }
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return buildDesktopWorkspaceMenuItems(
      selected: DesktopWorkspaceSection.shelf,
      onShelf: () {
        setState(() {
          _isDrawerOpen = false;
        });
      },
      onImportExport: () => _openImportExport(context),
      onProductionBoard: () {
        AppNavigator.push(context, AppRoutes.productionBoard);
      },
      onWorkbench: () => _openWorkbench(
        context,
        _resolveSelectedProject(_visibleProjects(_projects(context))) ??
            _projects(context).first,
      ),
      onStyle: () {
        AppNavigator.push(context, AppRoutes.style);
      },
      onScenes: () {
        AppNavigator.push(context, AppRoutes.scenes);
      },
      onCharacters: () {
        AppNavigator.push(context, AppRoutes.characters);
      },
      onWorldbuilding: () {
        AppNavigator.push(context, AppRoutes.worldbuilding);
      },
      onStoryBible: () => _openStoryBible(
        context,
        _resolveSelectedProject(_visibleProjects(_projects(context))) ??
            _projects(context).first,
      ),
      onAudit: () {
        AppNavigator.push(context, AppRoutes.audit);
      },
      onSettings: () {
        AppNavigator.push(context, AppRoutes.settings);
      },
      importButtonKey: ProjectListPage.importButtonKey,
      workbenchButtonKey: ProjectListPage.workbenchShortcutKey,
      styleButtonKey: ProjectListPage.styleShortcutKey,
      sceneButtonKey: ProjectListPage.sceneShortcutKey,
      characterButtonKey: ProjectListPage.characterShortcutKey,
      worldButtonKey: ProjectListPage.worldShortcutKey,
      storyBibleButtonKey: ProjectListPage.storyBibleShortcutKey,
      auditButtonKey: ProjectListPage.auditShortcutKey,
    );
  }
}

class _ProjectShelfHeader extends StatelessWidget {
  const _ProjectShelfHeader({
    this.titleKey,
    required this.searchController,
    this.onCreateProject,
    this.onImportProject,
    this.onSearchChanged,
  });

  final Key? titleKey;
  final TextEditingController searchController;
  final VoidCallback? onCreateProject;
  final VoidCallback? onImportProject;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('项目', key: titleKey, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('本地优先的长篇小说创作工作区', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        FilledButton(
          key: ProjectListPage.newProjectButtonKey,
          onPressed: onCreateProject,
          child: const Text('新建项目'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: onImportProject, child: const Text('导入工程')),
        const SizedBox(width: 12),
        DesktopSearchField(
          width: 220,
          hintText: '搜索项目',
          fieldKey: ProjectListPage.searchFieldKey,
          controller: searchController,
          onChanged: onSearchChanged,
        ),
      ],
    );
  }
}

class _ProjectShelfCard extends StatelessWidget {
  const _ProjectShelfCard({
    required this.project,
    required this.isSelected,
    this.compact = false,
    required this.onTap,
  });

  final ProjectRecord project;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final theme = Theme.of(context);

    final featured = isSelected && !compact;
    final width = featured ? 360.0 : 240.0;
    final height = featured ? 236.0 : 196.0;
    final radius = featured ? 18.0 : 14.0;
    final background = isSelected ? palette.subtle : palette.surface;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(featured ? 20 : 16),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isSelected ? palette.borderStrong : palette.border,
              ),
            ),
            child: _CompactProjectCardContent(
              project: project,
              featured: featured,
              theme: theme,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactProjectCardContent extends StatelessWidget {
  const _CompactProjectCardContent({
    required this.project,
    required this.featured,
    required this.theme,
  });

  final ProjectRecord project;
  final bool featured;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          featured ? '${project.tag} · ${project.genre}' : project.genre,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          project.title,
          style: featured
              ? theme.textTheme.headlineSmall
              : theme.textTheme.titleMedium,
        ),
        if (featured) ...[
          const SizedBox(height: 12),
          Text(
            project.summary,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(project.tag, style: theme.textTheme.bodySmall),
        ],
        const Spacer(),
        Text(
          featured
              ? '最近位置：${project.recentLocation}'
              : '最近：${project.recentLocation}',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ProjectDetailPanel extends StatelessWidget {
  const _ProjectDetailPanel({
    super.key,
    required this.project,
    this.compact = false,
    required this.onOpen,
    required this.onEdit,
    required this.onStoryBible,
    required this.onDelete,
  });

  final ProjectRecord project;
  final bool compact;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onStoryBible;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appPanelDecoration(context),
      child: compact
          ? _CompactProjectDetailContent(
              project: project,
              onOpen: onOpen,
              onEdit: onEdit,
              onStoryBible: onStoryBible,
              onDelete: onDelete,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '项目概览',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _ProjectDetailSection(
                  title: project.title,
                  body: '${project.genre}\n${project.summary}',
                  bodyMaxLines: 3,
                ),
                const SizedBox(height: 12),
                _ProjectDetailSection(
                  title: '最近内容',
                  body: '${project.tag}\n${project.recentLocation}',
                  bodyMaxLines: 2,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: ProjectListPage.openProjectButtonKey,
                    onPressed: onOpen,
                    child: const Text('打开'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: ProjectListPage.continueProjectButtonKey,
                    onPressed: onEdit,
                    child: const Text('编辑'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: ProjectListPage.storyBibleButtonKey,
                    onPressed: onStoryBible,
                    child: const Text('作品圣经'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.danger,
                      side: BorderSide(
                        color: palette.danger.withValues(alpha: 0.45),
                      ),
                      backgroundColor: palette.danger.withValues(alpha: 0.08),
                    ),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CompactProjectDetailContent extends StatelessWidget {
  const _CompactProjectDetailContent({
    required this.project,
    required this.onOpen,
    required this.onEdit,
    required this.onStoryBible,
    required this.onDelete,
  });

  final ProjectRecord project;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onStoryBible;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '项目概览',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          project.title,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${project.genre} · ${project.tag}',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Text(
          '最近内容',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          project.recentLocation,
          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: ProjectListPage.openProjectButtonKey,
            onPressed: onOpen,
            child: const Text('打开'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: ProjectListPage.continueProjectButtonKey,
                onPressed: onEdit,
                child: const Text('编辑'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: ProjectListPage.storyBibleButtonKey,
                onPressed: onStoryBible,
                child: const Text('圣经'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.danger,
                  side: BorderSide(
                    color: palette.danger.withValues(alpha: 0.45),
                  ),
                  backgroundColor: palette.danger.withValues(alpha: 0.08),
                ),
                child: const Text('删除'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NewProjectShelfCard extends StatelessWidget {
  const _NewProjectShelfCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final theme = Theme.of(context);

    return SizedBox(
      width: 220,
      height: 196,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.subtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '＋',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: palette.primary,
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: 18),
                Text('新建项目', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                Text(
                  '从空白书架里直接开始，不再额外占一整块区域。',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineNoticeCard extends StatelessWidget {
  const _InlineNoticeCard({
    required this.title,
    required this.message,
    required this.accent,
  });

  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ProjectShelfPanel extends StatelessWidget {
  const _ProjectShelfPanel({
    required this.projects,
    required this.selectedProject,
    required this.compact,
    required this.onCreateProject,
    required this.onSelectProject,
  });

  final List<ProjectRecord> projects;
  final ProjectRecord selectedProject;
  final bool compact;
  final VoidCallback onCreateProject;
  final ValueChanged<ProjectRecord> onSelectProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shelfChildren = <Widget>[
      for (final project in projects)
        _ProjectShelfCard(
          project: project,
          isSelected: project == selectedProject,
          compact: compact,
          onTap: () => onSelectProject(project),
        ),
      _NewProjectShelfCard(onTap: onCreateProject),
    ];

    return Container(
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('进行中的小说项目', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '书架中共有 ${projects.length} 部作品，按最近写作进度排列。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < shelfChildren.length; index++) ...[
                  shelfChildren[index],
                  if (index != shelfChildren.length - 1)
                    const SizedBox(height: 16),
                ],
              ],
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (
                      var index = 0;
                      index < shelfChildren.length;
                      index++
                    ) ...[
                      shelfChildren[index],
                      if (index != shelfChildren.length - 1)
                        const SizedBox(width: 16),
                    ],
                  ],
                ),
              ),
            ),
          if (!compact) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: desktopPalette(context).elevated,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectDetailSection extends StatelessWidget {
  const _ProjectDetailSection({
    required this.title,
    required this.body,
    this.bodyMaxLines,
  });

  final String title;
  final String body;
  final int? bodyMaxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
            maxLines: bodyMaxLines,
            overflow: bodyMaxLines == null ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ProjectDialogField extends StatelessWidget {
  const _ProjectDialogField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _ProjectFilterPanel extends StatelessWidget {
  const _ProjectFilterPanel({
    required this.filterIndex,
    required this.sortIndex,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final int filterIndex;
  final int sortIndex;
  final ValueChanged<int> onFilterChanged;
  final ValueChanged<int> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = <AppListFilterOption<ProjectRecord>>[
      AppListFilterOption(label: '全部项目', test: (_) => true),
      AppListFilterOption(
        label: '最近打开',
        test: (p) {
          final delta =
              DateTime.now().millisecondsSinceEpoch - p.lastOpenedAtMs;
          return delta < 24 * 60 * 60 * 1000;
        },
      ),
      AppListFilterOption(label: '进行中', test: (p) => p.lastOpenedAtMs > 0),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('视图', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          AppListFilterChipBar<ProjectRecord>(
            options: filters,
            selectedIndex: filterIndex,
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: 16),
          Text('排序', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          AppListSortDropdown<ProjectRecord>(
            options: _ProjectListPageState._sortOptions,
            selectedIndex: sortIndex,
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }
}
