import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_list_filter.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'worldbuilding_components.dart';

enum WorldbuildingUiState {
  ready,
  empty,
  filterNoResults,
  missingType,
  deleteParentConfirm,
}

class WorldbuildingPage extends ConsumerStatefulWidget {
  const WorldbuildingPage({
    super.key,
    this.uiState = WorldbuildingUiState.ready,
  });

  static const newNodeButtonKey = ValueKey<String>('worldbuilding-new-node');
  static const searchFieldKey = ValueKey<String>('worldbuilding-search');
  static const stormNodeKey = ValueKey<String>('worldbuilding-storm-node');
  static const titleFieldKey = ValueKey<String>('worldbuilding-title-field');
  static const locationFieldKey = ValueKey<String>(
    'worldbuilding-location-field',
  );
  static const typeFieldKey = ValueKey<String>('worldbuilding-type-field');
  static const detailFieldKey = ValueKey<String>('worldbuilding-detail-field');
  static const summaryFieldKey = ValueKey<String>(
    'worldbuilding-summary-field',
  );
  static const deleteButtonKey = ValueKey<String>(
    'worldbuilding-delete-button',
  );

  final WorldbuildingUiState uiState;

  @override
  ConsumerState<WorldbuildingPage> createState() => _WorldbuildingPageState();
}

class _WorldbuildingPageState extends ConsumerState<WorldbuildingPage> {
  int _selectedIndex = 0;
  int _sortIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  static const _sortOptions = <AppListSortOption<WorldNodeRecord>>[
    AppListSortOption(label: '按名称', compare: _compareByTitle),
    AppListSortOption(label: '按区域', compare: _compareByLocation),
    AppListSortOption(label: '按类型', compare: _compareByType),
  ];

  static int _compareByTitle(WorldNodeRecord a, WorldNodeRecord b) =>
      a.title.compareTo(b.title);

  static int _compareByLocation(WorldNodeRecord a, WorldNodeRecord b) =>
      a.location.compareTo(b.location);

  static int _compareByType(WorldNodeRecord a, WorldNodeRecord b) =>
      a.type.compareTo(b.type);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = ref.watch(appWorkspaceStoreProvider);
    final resources = workspace.resourceLibraryFacade;
    final projectScenes = workspace.projectSceneFacade;
    final nodes = resources.worldNodes;
    final visibleNodes = _visibleNodes(nodes);
    final selectedIndex = _resolveSelectedIndex(nodes, visibleNodes);
    final current = visibleNodes.isEmpty ? null : nodes[selectedIndex];
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.space24,
        vertical: AppDesignTokens.space20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Category tree (260px glass)
          SizedBox(
            width: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppDesignTokens.glassBlurRadius,
                  sigmaY: AppDesignTokens.glassBlurRadius,
                ),
                child: Container(
                  decoration: frostedSidebarDecoration(context),
                  padding: const EdgeInsets.all(18),
                  child: _buildTree(theme, nodes, visibleNodes, selectedIndex),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Center: Detail (fill)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppDesignTokens.glassBlurRadius,
                  sigmaY: AppDesignTokens.glassBlurRadius,
                ),
                child: Container(
                  decoration: glassCardDecoration(context),
                  padding: const EdgeInsets.all(20),
                  child: _buildDetail(theme, resources, current),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Right: Rules panel (320px)
          SizedBox(
            width: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppDesignTokens.glassBlurRadius,
                  sigmaY: AppDesignTokens.glassBlurRadius,
                ),
                child: Container(
                  decoration: glassCardDecoration(context),
                  padding: const EdgeInsets.all(20),
                  child: _buildRules(theme, resources, projectScenes, current),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return DesktopShellFrame(
      header: DesktopHeaderBar(
        tabs: const ['作品资料', '设定资料', '编辑'],
        activeTabIndex: 1,
        onTabChanged: (i) async {
          if (i == 0) {
            final canNavigate = await AppNavTabs.confirmIfBlocked(context);
            if (!canNavigate) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            AppNavigator.push(context, AppRoutes.workSettingsHub);
          } else if (i == 2) {
            final canNavigate = await AppNavTabs.confirmIfBlocked(context);
            if (!canNavigate) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            AppNavigator.push(context, AppRoutes.workbench);
          }
        },
        actions: [
          OutlinedButton(
            onPressed: current == null
                ? null
                : () => _appendRulePrompt(resources, current),
            child: const Text('新增规则'),
          ),
          DesignActionButton(
            key: WorldbuildingPage.newNodeButtonKey,
            icon: Icons.add,
            label: '新增设定',
            onPressed: () => _createNode(resources),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.uiState == WorldbuildingUiState.deleteParentConfirm)
            Opacity(opacity: 0.55, child: body)
          else
            body,
          if (widget.uiState == WorldbuildingUiState.deleteParentConfirm)
            Positioned.fill(
              child: WorldbuildingDeleteOverlay(nodeTitle: current?.title ?? '当前节点'),
            ),
        ],
      ),
      statusBar: const BottomSpecBar(
        description: '作品设定 · 世界观资料已保存',
      ),
    );
  }

  Widget _buildTree(
    ThemeData theme,
    List<WorldNodeRecord> nodes,
    List<WorldNodeRecord> visibleNodes,
    int selectedIndex,
  ) {
    if (widget.uiState == WorldbuildingUiState.empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('世界观树', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('当前项目没有世界观节点', style: theme.textTheme.bodySmall),
        ],
      );
    }
    if (_showFilterNoResults(visibleNodes)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('世界观树', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('0 个匹配', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          const WorldbuildingInfoBlock(title: '没有匹配节点', message: '试试更短的地名、组织名或规则关键词。'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _searchController.clear();
              }),
              child: const Text('清空筛选'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('世界观树'),
        const SizedBox(height: 8),
        DesktopSearchField(
          fieldKey: WorldbuildingPage.searchFieldKey,
          controller: _searchController,
          hintText: '搜索节点',
          onChanged: (_) => setState(() {}),
          width: double.infinity,
        ),
        const SizedBox(height: 8),
        AppListSortDropdown<WorldNodeRecord>(
          options: _sortOptions,
          selectedIndex: _sortIndex,
          onChanged: (i) => setState(() => _sortIndex = i),
        ),
        const SizedBox(height: 12),
        if (visibleNodes.isEmpty)
          const Expanded(
            child: AppEmptyState(title: '没有匹配节点', message: '换个关键词，或新建一个节点。'),
          )
        else
          for (final node in visibleNodes) ...[
            WorldbuildingListButton(
              buttonKey: node.title == '码头风暴'
                  ? WorldbuildingPage.stormNodeKey
                  : null,
              label: node.title,
              selected: nodes[selectedIndex] == node,
              onPressed: () => setState(() {
                _selectedIndex = nodes.indexOf(node);
              }),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildDetail(
    ThemeData theme,
    WorkspaceResourceLibraryFacade store,
    WorldNodeRecord? current,
  ) {
    if (widget.uiState == WorldbuildingUiState.empty) {
      return WorldbuildingCallToActionState(
        title: '创建第一个世界观节点',
        message: '先建立地点、组织或关键物件，再补限制条件与引用场景。',
        buttonLabel: '新建节点',
        onPressed: () => _createNode(store),
      );
    }
    if (_showFilterNoResults(const <WorldNodeRecord>[])) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('节点详情', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const Expanded(
            child: WorldbuildingCenteredPanelState(
              title: '未选中节点',
              message: '当前筛选没有结果，因此这里不显示节点详情。',
            ),
          ),
        ],
      );
    }
    if (widget.uiState == WorldbuildingUiState.missingType) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('节点详情', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const WorldbuildingStateCard(
              title: '缺少必填类型',
              message: '当前素材尚未指定类型，因此本轮暂不写入世界观索引，也不会同步规则引用。',
              accent: Color(0xFF51624D),
            ),
            if (current != null) ...[
              const SizedBox(height: 12),
              _buildNodeFields(store, current),
            ],
          ],
        ),
      );
    }

    if (current == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('节点详情', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const Expanded(
            child: WorldbuildingCenteredPanelState(
              title: '没有可展示的节点',
              message: '请先搜索或新建一个世界观节点。',
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('节点详情', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                key: WorldbuildingPage.deleteButtonKey,
                onPressed: () => _confirmDeleteNode(context, store, current),
                tooltip: '删除节点',
                color: appDangerColor,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNodeFields(store, current),
        ],
      ),
    );
  }

  List<WorldNodeRecord> _visibleNodes(List<WorldNodeRecord> nodes) {
    return applyListFilter(
      items: nodes,
      searchQuery: _searchController.text.trim(),
      searchExtractor: (n) => '${n.title} ${n.location} ${n.type} ${n.summary}',
      activeSort: _sortOptions[_sortIndex],
    );
  }

  int _resolveSelectedIndex(
    List<WorldNodeRecord> nodes,
    List<WorldNodeRecord> visibleNodes,
  ) {
    if (nodes.isEmpty || visibleNodes.isEmpty) {
      return 0;
    }
    if (_selectedIndex < nodes.length &&
        visibleNodes.contains(nodes[_selectedIndex])) {
      return _selectedIndex;
    }
    return nodes.indexOf(visibleNodes.first);
  }

  void _createNode(WorkspaceResourceLibraryFacade store) {
    setState(() {
      store.createWorldNode();
      _selectedIndex = 0;
      _searchController.clear();
    });
  }

  void _appendRulePrompt(
    WorkspaceResourceLibraryFacade store,
    WorldNodeRecord current,
  ) {
    final nextRule = current.ruleSummary.trim().isEmpty
        ? '新增规则：'
        : '${current.ruleSummary.trim()}\n新增规则：';
    setState(() {
      store.updateWorldNode(nodeId: current.id, ruleSummary: nextRule);
      ref.read(appSceneContextStoreProvider).syncContext();
    });
  }

  Future<void> _confirmDeleteNode(
    BuildContext context,
    WorkspaceResourceLibraryFacade store,
    WorldNodeRecord node,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierLabel: '关闭',
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: '删除节点',
          description: '删除后，世界观资料和场景引用关系都会被移除。',
          body: Text(node.title, style: Theme.of(context).textTheme.bodyMedium),
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
    if (shouldDelete == true) {
      setState(() {
        store.deleteWorldNode(node.id);
        final visible = _visibleNodes(store.worldNodes);
        _selectedIndex = visible.isEmpty
            ? 0
            : store.worldNodes
                  .indexOf(visible.first)
                  .clamp(0, store.worldNodes.length - 1);
      });
      if (context.mounted) {
        ref.read(appSceneContextStoreProvider).syncContext();
      }
    }
  }

  Widget _buildRules(
    ThemeData theme,
    WorkspaceResourceLibraryFacade store,
    WorkspaceProjectSceneFacade projectScenes,
    WorldNodeRecord? current,
  ) {
    if (widget.uiState == WorldbuildingUiState.empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('规则与引用', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const WorldbuildingInfoBlock(title: '引用场景', message: '创建节点后，这里会同步展示规则摘要与关联场景。'),
        ],
      );
    }
    if (_showFilterNoResults(const <WorldNodeRecord>[])) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('规则与引用', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const WorldbuildingInfoBlock(title: '改筛建议', message: '可尝试地点名、组织名、物件名或规则关键词。'),
          const SizedBox(height: 8),
          const WorldbuildingInfoBlock(title: '引用场景', message: '筛选无结果时，不展示引用片段。'),
        ],
      );
    }
    if (widget.uiState == WorldbuildingUiState.missingType) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('规则与引用', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const WorldbuildingInfoBlock(title: '规则摘要', message: '类型缺失时，暂不把这条素材纳入规则摘要或引用索引。'),
        ],
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('规则与引用', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '把地点、组织和规则绑定回具体场景，写作时就能直接看到限制条件。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (current == null)
            const AppEmptyState(title: '暂无规则摘要', message: '请先搜索或新建一个节点。')
          else ...[
            WorldbuildingInfoBlock(
              title: '引用场景',
              message: current.linkedSceneIds.isEmpty
                  ? '暂未绑定场景，可在下方选择相关场景。'
                  : '已绑定 ${current.linkedSceneIds.length} 个场景，规则会同步到写作工作台。',
            ),
            const SizedBox(height: 8),
            WorldbuildingEditableTextField(
              fieldKey: ValueKey<String>(
                'worldbuilding-rule-field-${current.id}',
              ),
              label: '规则摘要',
              initialValue: current.ruleSummary,
              maxLines: 3,
              onChanged: (value) {
                store.updateWorldNode(nodeId: current.id, ruleSummary: value);
                ref.read(appSceneContextStoreProvider).syncContext();
              },
            ),
            const SizedBox(height: 8),
            WorldbuildingInfoBlock(
              title: '引用摘要',
              message: current.referenceSummary.isEmpty
                  ? current.summary
                  : current.referenceSummary,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final scene in projectScenes.scenes)
                  FilterChip(
                    label: Text(scene.title),
                    selected: current.linkedSceneIds.contains(scene.id),
                    onSelected: (linked) => store.setWorldNodeSceneLinked(
                      nodeId: current.id,
                      sceneId: scene.id,
                      linked: linked,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _showFilterNoResults(List<WorldNodeRecord> visibleNodes) {
    if (widget.uiState == WorldbuildingUiState.filterNoResults) {
      return true;
    }
    return _searchController.text.trim().isNotEmpty && visibleNodes.isEmpty;
  }

  Widget _buildNodeFields(
    WorkspaceResourceLibraryFacade store,
    WorldNodeRecord current,
  ) {
    void onFieldChanged(
      String nodeId, {
      String? title,
      String? location,
      String? type,
      String? detail,
      String? summary,
      String? ruleSummary,
    }) {
      store.updateWorldNode(
        nodeId: nodeId,
        title: title,
        location: location,
        type: type,
        detail: detail,
        summary: summary,
        ruleSummary: ruleSummary,
      );
      ref.read(appSceneContextStoreProvider).syncContext();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorldbuildingEditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.titleFieldKey.value}-${current.id}',
          ),
          label: '节点名称',
          initialValue: current.title,
          onChanged: (value) => onFieldChanged(current.id, title: value),
        ),
        const SizedBox(height: 8),
        WorldbuildingEditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.locationFieldKey.value}-${current.id}',
          ),
          label: '所在区域',
          initialValue: current.location,
          onChanged: (value) => onFieldChanged(current.id, location: value),
        ),
        const SizedBox(height: 8),
        WorldbuildingEditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.typeFieldKey.value}-${current.id}',
          ),
          label: '类型',
          initialValue: current.type,
          onChanged: (value) => onFieldChanged(current.id, type: value),
        ),
        const SizedBox(height: 8),
        WorldbuildingEditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.detailFieldKey.value}-${current.id}',
          ),
          label: '附属信息',
          initialValue: current.detail,
          maxLines: 3,
          onChanged: (value) => onFieldChanged(current.id, detail: value),
        ),
        const SizedBox(height: 8),
        WorldbuildingEditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.summaryFieldKey.value}-${current.id}',
          ),
          label: '节点摘要',
          initialValue: current.summary,
          maxLines: 3,
          onChanged: (value) => onFieldChanged(current.id, summary: value),
        ),
      ],
    );
  }

}

