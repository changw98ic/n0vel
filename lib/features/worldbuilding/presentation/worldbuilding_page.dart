import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_list_filter.dart';
import '../../../app/widgets/desktop_shell.dart';

enum WorldbuildingUiState {
  ready,
  empty,
  filterNoResults,
  missingType,
  deleteParentConfirm,
}

class WorldbuildingPage extends StatefulWidget {
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

  final WorldbuildingUiState uiState;

  @override
  State<WorldbuildingPage> createState() => _WorldbuildingPageState();
}

class _WorldbuildingPageState extends State<WorldbuildingPage> {
  bool _isDrawerOpen = false;
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
    final store = AppWorkspaceScope.of(context);
    final nodes = _nodes(context);
    final visibleNodes = _visibleNodes(nodes);
    final selectedIndex = _resolveSelectedIndex(nodes, visibleNodes);
    final current = visibleNodes.isEmpty ? null : nodes[selectedIndex];
    final body = Row(
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
        SizedBox(
          width: 220,
          child: Container(
            decoration: appPanelDecoration(context),
            padding: const EdgeInsets.all(16),
            child: _buildTree(theme, visibleNodes, selectedIndex),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: appPanelDecoration(context),
            padding: const EdgeInsets.all(16),
            child: _buildDetail(theme, store, current),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 320,
          child: Container(
            decoration: appPanelDecoration(context),
            padding: const EdgeInsets.all(16),
            child: _buildRules(theme, store, current),
          ),
        ),
      ],
    );
    return DesktopShellFrame(
      header: DesktopHeaderBar(
        title: '世界观',
        subtitle: '维护地点、组织、规则与引用关系',
        showBackButton: true,
        actions: [
          FilledButton(
            key: WorldbuildingPage.newNodeButtonKey,
            onPressed: () => _createNode(store),
            child: const Text('新建节点'),
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
              child: _WorldDeleteOverlay(nodeTitle: current?.title ?? '当前节点'),
            ),
        ],
      ),
      statusBar: const DesktopStatusStrip(
        leftText: '规则索引已同步',
        rightText: '场景 05',
      ),
    );
  }

  Widget _buildTree(
    ThemeData theme,
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
          const _InfoBlock(title: '没有匹配节点', message: '试试更短的地名、组织名或规则关键词。'),
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
        Text('世界观树'),
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
            _ListButton(
              buttonKey: node.title == '码头风暴'
                  ? WorldbuildingPage.stormNodeKey
                  : null,
              label: node.title,
              selected: _nodes(context)[selectedIndex] == node,
              onPressed: () => setState(() {
                _selectedIndex = _nodes(context).indexOf(node);
              }),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildDetail(
    ThemeData theme,
    AppWorkspaceStore store,
    WorldNodeRecord? current,
  ) {
    if (widget.uiState == WorldbuildingUiState.empty) {
      return _CallToActionState(
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
            child: _CenteredPanelState(
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
            const _StateCard(
              title: '缺少必填类型',
              message: '当前节点尚未指定类型，因此本轮不会写入世界观索引，也不会同步规则引用。',
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
            child: _CenteredPanelState(
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
          Text('节点详情', style: theme.textTheme.titleMedium),
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

  void _createNode(AppWorkspaceStore store) {
    setState(() {
      store.createWorldNode();
      _selectedIndex = 0;
      _searchController.clear();
    });
  }

  List<WorldNodeRecord> _nodes(BuildContext context) =>
      AppWorkspaceScope.of(context).worldNodes;

  Widget _buildRules(
    ThemeData theme,
    AppWorkspaceStore store,
    WorldNodeRecord? current,
  ) {
    if (widget.uiState == WorldbuildingUiState.empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('规则与引用', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _InfoBlock(title: '引用场景', message: '创建节点后，这里会同步展示规则摘要与关联场景。'),
        ],
      );
    }
    if (_showFilterNoResults(const <WorldNodeRecord>[])) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('规则与引用', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _InfoBlock(title: '改筛建议', message: '可尝试地点名、组织名、物件名或规则关键词。'),
          const SizedBox(height: 8),
          const _InfoBlock(title: '引用场景', message: '筛选无结果时，不展示引用片段。'),
        ],
      );
    }
    if (widget.uiState == WorldbuildingUiState.missingType) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('规则与引用', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _InfoBlock(
            title: '规则摘要',
            message: '节点类型缺失时，系统不会将该节点纳入规则摘要或引用索引。',
          ),
        ],
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('规则与引用', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (current == null)
            const AppEmptyState(title: '暂无规则摘要', message: '请先搜索或新建一个节点。')
          else ...[
            _EditableTextField(
              fieldKey: ValueKey<String>(
                'worldbuilding-rule-field-${current.id}',
              ),
              label: '规则摘要',
              initialValue: current.ruleSummary,
              maxLines: 3,
              onChanged: (value) =>
                  store.updateWorldNode(nodeId: current.id, ruleSummary: value),
            ),
            const SizedBox(height: 8),
            _InfoBlock(
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
                for (final scene in store.scenes)
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

  Widget _buildNodeFields(AppWorkspaceStore store, WorldNodeRecord current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.titleFieldKey.value}-${current.id}',
          ),
          label: '节点名称',
          initialValue: current.title,
          onChanged: (value) =>
              store.updateWorldNode(nodeId: current.id, title: value),
        ),
        const SizedBox(height: 8),
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.locationFieldKey.value}-${current.id}',
          ),
          label: '所在区域',
          initialValue: current.location,
          onChanged: (value) =>
              store.updateWorldNode(nodeId: current.id, location: value),
        ),
        const SizedBox(height: 8),
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.typeFieldKey.value}-${current.id}',
          ),
          label: '类型',
          initialValue: current.type,
          onChanged: (value) =>
              store.updateWorldNode(nodeId: current.id, type: value),
        ),
        const SizedBox(height: 8),
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.detailFieldKey.value}-${current.id}',
          ),
          label: '附属信息',
          initialValue: current.detail,
          maxLines: 3,
          onChanged: (value) =>
              store.updateWorldNode(nodeId: current.id, detail: value),
        ),
        const SizedBox(height: 8),
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${WorldbuildingPage.summaryFieldKey.value}-${current.id}',
          ),
          label: '节点摘要',
          initialValue: current.summary,
          maxLines: 3,
          onChanged: (value) =>
              store.updateWorldNode(nodeId: current.id, summary: value),
        ),
      ],
    );
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return [
      DesktopMenuItemData(
        label: '书架',
        onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
      DesktopMenuItemData(
        label: '编辑工作台',
        onTap: () {
          AppNavigator.push(context, AppRoutes.workbench);
        },
      ),
      DesktopMenuItemData(
        label: '设置',
        onTap: () {
          AppNavigator.push(context, AppRoutes.settings);
        },
      ),
    ];
  }
}

class _ListButton extends StatelessWidget {
  const _ListButton({
    this.buttonKey,
    required this.label,
    this.selected = false,
    required this.onPressed,
  });

  final Key? buttonKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.message});

  final String title;
  final String message;

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
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EditableTextField extends StatelessWidget {
  const _EditableTextField({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
  });

  final Key fieldKey;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.message,
    required this.accent,
  });

  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: desktopPalette(context).elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CallToActionState extends StatelessWidget {
  const _CallToActionState({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class _CenteredPanelState extends StatelessWidget {
  const _CenteredPanelState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldDeleteOverlay extends StatelessWidget {
  const _WorldDeleteOverlay({required this.nodeTitle});

  final String nodeTitle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99F6F0E6),
      child: Center(
        child: Container(
          width: 760,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: desktopPalette(context).surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB7AA9A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('删除父节点？', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(
                '节点“$nodeTitle”仍包含子节点或关联规则。删除该父节点可能会连带影响地点树、规则摘要与引用场景。\n\n请选择先取消、或在未来版本中进入连带删除流程。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _InfoBlock(title: '当前层级', message: '$nodeTitle\n规则摘要\n引用场景'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () {}, child: const Text('取消')),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: () {}, child: const Text('查看影响后再删')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
