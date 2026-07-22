import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/app_dialog.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_list_filter.dart';
import '../../../app/widgets/app_scrollbar.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../../app/theme/app_design_tokens.dart';
import 'project_list_components.dart';

enum ProjectListUiState {
  ready,
  empty,
  searchNoResults,
  databaseReadFailed,
  importFailed,
  deleteConfirm,
}

class ProjectListPage extends ConsumerStatefulWidget {
  const ProjectListPage({super.key, this.uiState = ProjectListUiState.ready});

  static const newProjectButtonKey = ValueKey<String>(
    'project-list-new-project-button',
  );
  static const searchFieldKey = ValueKey<String>('project-list-search-field');
  static const projectNameFieldKey = ValueKey<String>(
    'project-list-name-field',
  );

  final ProjectListUiState uiState;

  @override
  ConsumerState<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends ConsumerState<ProjectListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _gridScrollController = ScrollController();
  int _sortIndex = 0;
  int _filterIndex = 0;
  int _headerTabIndex = 0;
  bool _deletingProject = false;

  static const _headerTabs = ['书架', '最近编辑', '进行中'];

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
      AppListFilterOption<ProjectRecord>(label: '全部作品', test: (_) => true),
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
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uiState == ProjectListUiState.databaseReadFailed) {
      return _buildDatabaseFailureShell(context);
    }
    final projects = _visibleProjects(_projects(context));
    return DesktopShellFrame(
      header: DesktopHeaderBar(
        tabs: _headerTabs,
        activeTabIndex: _headerTabIndex,
        onTabChanged: (i) {
          setState(() {
            _headerTabIndex = i;
            if (i == 1) {
              _filterIndex = 1; // 最近打开
            } else if (i == 2) {
              _filterIndex = 2; // 进行中
            } else {
              _filterIndex = 0; // 全部作品
            }
          });
        },
        actions: [
          AppListSortDropdown<ProjectRecord>(
            options: _sortOptions,
            selectedIndex: _sortIndex,
            onChanged: (i) => setState(() => _sortIndex = i),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: ProjectListPage.newProjectButtonKey,
            onPressed: _createProject,
            child: const Text('新建作品'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => AppNavigator.push(context, AppRoutes.importExport),
            child: const Text('导入'),
          ),
        ],
      ),
      body: _buildBody(context, projects),
      statusBar: DesktopStatusStrip(
        leftText: _footerStatus(projectCount: _projects(context).length),
        rightText: '${_sortOptions[_sortIndex].label} · 本地书架',
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ProjectRecord> projects) {
    final palette = desktopPalette(context);
    if (widget.uiState == ProjectListUiState.empty) {
      return _buildEmptyShelfState(context);
    }
    if (widget.uiState == ProjectListUiState.searchNoResults ||
        projects.isEmpty) {
      return _buildSearchNoResultsState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 36, 56, 0),
          child: Row(
            children: [
              const Text(
                '我的书架',
                style: TextStyle(
                  fontFamily: AppDesignTokens.fontCaption,
                  fontSize: 13,
                  color: Color(0xFF77736A),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                height: 40,
                child: TextField(
                  key: ProjectListPage.searchFieldKey,
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索作品',
                    hintStyle: const TextStyle(
                      fontFamily: AppDesignTokens.fontCaption,
                      fontSize: AppDesignTokens.fontSizeBody,
                      color: Color(0xFF999489),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 16,
                      color: Color(0xFF999489),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: const Color(0xFFFBFAF6),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDesignTokens.radiusLarge,
                      ),
                      borderSide: const BorderSide(color: Color(0xFFD8D2C6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDesignTokens.radiusLarge,
                      ),
                      borderSide: const BorderSide(color: Color(0xFFD8D2C6)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.uiState == ProjectListUiState.importFailed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: ProjectInlineNoticeCard(
              title: '导入失败',
              message: '工程包结构不完整，当前书架内容未受影响，可修正包后重试。',
              accent: palette.danger,
            ),
          ),
        if (widget.uiState == ProjectListUiState.deleteConfirm)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: ProjectInlineNoticeCard(
              title: '删除确认',
              message: '这会移除本地书架中的项目记录，不会删除你手动导出的工程包。',
              accent: palette.danger,
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisSpacing = 16.0;
              const mainAxisSpacing = 16.0;
              const horizontalPadding = 56.0;
              final columns = (constraints.maxWidth / 280).floor().clamp(2, 6);
              final availableWidth =
                  constraints.maxWidth - horizontalPadding * 2;
              final cardWidth =
                  (availableWidth - crossAxisSpacing * (columns - 1)) / columns;
              const cardHeight = 320.0;
              final aspectRatio = cardWidth / cardHeight;
              return AppPremiumScrollbar(
                controller: _gridScrollController,
                child: GridView.builder(
                  controller: _gridScrollController,
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    20,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: mainAxisSpacing,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (context, index) => ProjectShelfCard(
                    project: projects[index],
                    onTap: () => _openEditor(context, projects[index]),
                    onSecondaryTap: (offset) =>
                        _showCardContextMenu(context, projects[index], offset),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x88FFFFFF),
                    borderRadius: BorderRadius.circular(
                      AppDesignTokens.radiusFull,
                    ),
                    border: Border.all(
                      color: const Color(0x99FFFFFF),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x181F2A1D),
                        blurRadius: 28,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Color(0xFF243226),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '卡片 hover 上浮 6px / 160ms',
                        style: TextStyle(
                          fontFamily: AppDesignTokens.fontCaption,
                          fontSize: 12,
                          color: Color(0xFF243226),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCardContextMenu(
    BuildContext context,
    ProjectRecord project,
    Offset position,
  ) {
    final palette = desktopPalette(context);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          onTap: () => _openEditor(context, project),
          child: const Text('打开作品'),
        ),
        PopupMenuItem(
          onTap: () => _openWorkSettings(context, project),
          child: const Text('作品设定'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => _confirmDeleteProject(context, project),
          child: Text('删除', style: TextStyle(color: palette.danger)),
        ),
      ],
    );
  }

  Widget _buildDatabaseFailureShell(BuildContext context) {
    final theme = Theme.of(context);
    return DesktopShellFrame(
      header: DesktopHeaderBar(
        tabs: _headerTabs,
        activeTabIndex: _headerTabIndex,
        onTabChanged: (i) {
          setState(() {
            _headerTabIndex = i;
            if (i == 1) {
              _filterIndex = 1;
            } else if (i == 2) {
              _filterIndex = 2;
            } else {
              _filterIndex = 0;
            }
          });
        },
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('书架未加载', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                '本地数据库读取失败，请重试。',
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
      statusBar: const DesktopStatusStrip(
        leftText: '数据库读取失败',
        rightText: '等待恢复本地索引',
      ),
    );
  }

  Widget _buildSearchNoResultsState(BuildContext context) {
    return AppEmptyState(
      style: AppEmptyStateStyle.prominent,
      title: '没有匹配的作品',
      message: '换个关键词试试，或直接新建一个作品。',
      actions: [
        FilledButton(
          onPressed: () => setState(() => _searchController.clear()),
          child: const Text('清空搜索'),
        ),
        OutlinedButton(onPressed: _createProject, child: const Text('新建作品')),
      ],
    );
  }

  Widget _buildEmptyShelfState(BuildContext context) {
    return AppEmptyState(
      style: AppEmptyStateStyle.prominent,
      title: '还没有作品',
      message: '点击右上角「新建作品」开始创作。',
      actions: [
        FilledButton(onPressed: _createProject, child: const Text('新建作品')),
      ],
    );
  }

  Future<void> _confirmDeleteProject(
    BuildContext context,
    ProjectRecord project,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '关闭',
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: '确认删除作品',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProjectDialogField(
                label: '删除对象',
                child: Text(
                  project.title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              ProjectDialogField(
                label: '删除说明',
                child: Text(
                  '删除后将移除本地数据库中的作品记录和相关索引，但不会删除你手动导出的工程包。',
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
    if (shouldDelete != true || !context.mounted) return;
    if (_deletingProject) return;
    setState(() => _deletingProject = true);
    final result = await ref
        .read(appWorkspaceStoreProvider)
        .deleteProjectAndWait(project);
    if (!context.mounted) return;
    setState(() => _deletingProject = false);
    if (!result.succeeded && result.status == DeleteProjectStatus.failed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：${result.error}')));
    }
  }

  void _openEditor(BuildContext context, ProjectRecord project) {
    ref.read(appWorkspaceStoreProvider).openProject(project.id);
    AppNavigator.push(context, AppRoutes.workbench);
  }

  void _openWorkSettings(BuildContext context, ProjectRecord project) {
    ref.read(appWorkspaceStoreProvider).openProject(project.id);
    AppNavigator.push(context, AppRoutes.workSettingsHub);
  }

  Future<void> _createProject() async {
    final name = await showAppTextInputDialog(
      context: context,
      title: '新建作品',
      description: '为你的新作品起个名字。',
      hintText: '输入作品名称',
      fieldKey: ProjectListPage.projectNameFieldKey,
      confirmText: '创建',
    );
    if (name == null || name.isEmpty || !mounted) return;
    final store = ref.read(appWorkspaceStoreProvider);
    if (store.projects.any((p) => p.title == name.trim())) {
      final proceed = await showDialog<bool>(
        context: context,
        barrierLabel: '关闭',
        builder: (dialogContext) => DesktopModalDialog(
          title: '作品名称重复',
          description: '已存在同名作品「${name.trim()}」，是否仍要创建？',
          body: const SizedBox.shrink(),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('继续创建'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    final project = store.createProject(projectName: name);
    setState(() {
      _searchController.clear();
    });
    if (!mounted) return;
    _openWorkSettings(context, project);
  }

  List<ProjectRecord> _visibleProjects(List<ProjectRecord> projects) {
    return applyListFilter(
      items: projects,
      searchQuery: _searchController.text.trim(),
      searchExtractor: (p) =>
          '${p.title} ${p.genre} ${p.tag} ${p.summary} ${p.displayRecentLocation}',
      activeFilter: _filterOptions(context)[_filterIndex],
      activeSort: _sortOptions[_sortIndex],
    );
  }

  List<ProjectRecord> _projects(BuildContext context) =>
      ref.watch(appWorkspaceStoreProvider).projects;

  String _footerStatus({required int projectCount}) {
    switch (widget.uiState) {
      case ProjectListUiState.ready:
        return '本地书架';
      case ProjectListUiState.empty:
        return '当前还没有本地作品';
      case ProjectListUiState.searchNoResults:
        return '当前搜索没有命中作品';
      case ProjectListUiState.databaseReadFailed:
        return '数据库读取失败';
      case ProjectListUiState.importFailed:
        return '导入失败：工程包结构不完整';
      case ProjectListUiState.deleteConfirm:
        return '等待删除确认';
    }
  }
}
