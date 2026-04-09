import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../shared/data/base_business/base_page.dart';
import '../../../features/settings/domain/location.dart';
import '../../../features/settings/data/location_repository.dart';
import '../../../l10n/app_localizations.dart';
import 'location_list_logic.dart';

class LocationListView extends GetView<LocationListLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings_locationListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.merge),
            onPressed: () => _showMergeDialog(context),
            tooltip: s.settings_mergeDuplicates,
          ),
          Obx(() => IconButton(
            icon: Icon(controller.state.viewMode.value == 'tree' ? Icons.list : Icons.account_tree),
            onPressed: controller.onViewModeChanged,
            tooltip: controller.state.viewMode.value == 'tree' ? s.settings_listView : s.settings_treeView,
          )),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => openSearch(context),
          ),
        ],
      ),
      body: FutureBuilder<List<LocationNode>>(
        future: controller.loadLocationTree(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return loadingIndicator();
          }

          final nodes = snapshot.data ?? [];

          if (nodes.isEmpty) {
            return emptyState(
              icon: Icons.place_outlined,
              message: s.settings_noLocationsCreated,
              action: FilledButton.icon(
                onPressed: controller.navigateToCreate,
                icon: const Icon(Icons.add),
                label: Text(s.settings_createLocation),
              ),
            );
          }

          return Obx(() {
            if (controller.state.viewMode.value == 'tree') {
              return TreeView(
                nodes: nodes,
                onLocationTap: controller.navigateToEdit,
                onAddChild: controller.navigateToCreateChild,
              );
            } else {
              return LocationListViewWidget(
                workId: controller.workId,
                onLocationTap: controller.navigateToEdit,
              );
            }
          });
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'location_fab',
        onPressed: controller.navigateToCreate,
        icon: const Icon(Icons.add),
        label: Text(s.settings_addLocation),
      ),
    );
  }

  void openSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: LocationSearchDelegate(workId: controller.workId),
    );
  }

  void _showMergeDialog(BuildContext context) async {
    final s = S.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => _MergeDuplicatesDialog(
        controller: controller,
        localizations: s,
      ),
    );
  }
}

class TreeView extends StatelessWidget {
  final List<LocationNode> nodes;
  final void Function(Location) onLocationTap;
  final void Function(String parentId) onAddChild;

  const TreeView({
    required this.nodes,
    required this.onLocationTap,
    required this.onAddChild,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        return LocationTreeNode(
          node: nodes[index],
          level: 0,
          onLocationTap: onLocationTap,
          onAddChild: onAddChild,
        );
      },
    );
  }
}

class LocationTreeNode extends StatefulWidget {
  final LocationNode node;
  final int level;
  final void Function(Location) onLocationTap;
  final void Function(String parentId) onAddChild;

  const LocationTreeNode({
    required this.node,
    required this.level,
    required this.onLocationTap,
    required this.onAddChild,
  });

  @override
  State<LocationTreeNode> createState() => LocationTreeNodeState();
}

class LocationTreeNodeState extends State<LocationTreeNode> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = widget.node.location;
    final hasChildren = widget.node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onLocationTap(location),
          child: Padding(
            padding: EdgeInsets.only(left: widget.level * 24.0.w),
            child: Row(
              children: [
                if (hasChildren)
                  IconButton(
                    icon: Icon(_isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  )
                else
                  SizedBox(width: 48.w),
                Icon(Icons.place, color: theme.colorScheme.primary),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (location.type != null)
                        Text(
                          LocationType.values
                              .firstWhere((t) => t.name == location.type,
                                  orElse: () => LocationType.other)
                              .label,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, size: 20.sp),
                  onPressed: () => widget.onAddChild(location.id),
                  tooltip: S.of(context)!.settings_addChildLocation,
                ),
              ],
            ),
          ),
        ),
        if (hasChildren && _isExpanded)
          ...widget.node.children.map((child) => LocationTreeNode(
                node: child,
                level: widget.level + 1,
                onLocationTap: widget.onLocationTap,
                onAddChild: widget.onAddChild,
              )),
      ],
    );
  }
}

class LocationListViewWidget extends StatefulWidget {
  final String workId;
  final void Function(Location) onLocationTap;

  const LocationListViewWidget({
    required this.workId,
    required this.onLocationTap,
  });

  @override
  State<LocationListViewWidget> createState() => LocationListViewWidgetState();
}

class LocationListViewWidgetState extends State<LocationListViewWidget> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Location>>(
      future: Get.find<LocationRepository>().getLocationsByWorkId(widget.workId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final locations = snapshot.data!;

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: locations.length,
          itemBuilder: (context, index) {
            final location = locations[index];
            return Card(
              margin: EdgeInsets.only(bottom: 8.h),
              child: ListTile(
                leading: const Icon(Icons.place),
                title: Text(location.name),
                subtitle: location.type != null
                    ? Text(LocationType.values
                        .firstWhere((t) => t.name == location.type,
                            orElse: () => LocationType.other)
                        .label)
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onLocationTap(location),
              ),
            );
          },
        );
      },
    );
  }
}

class LocationSearchDelegate extends SearchDelegate<String> {
  final String workId;

  LocationSearchDelegate({required this.workId});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Get.back(),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final s = S.of(context)!;
    return Center(child: Text(s.settings_search(query)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final s = S.of(context)!;
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(s.settings_recentSearches),
        ),
      ],
    );
  }
}

/// 合并重复地点对话框
class _MergeDuplicatesDialog extends StatefulWidget {
  final LocationListLogic controller;
  final S localizations;

  const _MergeDuplicatesDialog({
    required this.controller,
    required this.localizations,
  });

  @override
  State<_MergeDuplicatesDialog> createState() => _MergeDuplicatesDialogState();
}

class _MergeDuplicatesDialogState extends State<_MergeDuplicatesDialog> {
  bool _loading = true;
  List<List<Location>> _groups = [];
  final Map<int, String> _selectedKeep = {}; // groupIndex -> keepId

  @override
  void initState() {
    super.initState();
    _loadDuplicates();
  }

  Future<void> _loadDuplicates() async {
    final groups = await widget.controller.loadDuplicateGroups();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      // 默认选择每组中第一个（最早的）作为保留项
      for (var i = 0; i < groups.length; i++) {
        if (groups[i].isNotEmpty) {
          _selectedKeep[i] = groups[i].first.id;
        }
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.localizations;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(s.settings_mergeDuplicates),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 400.h, maxWidth: double.maxFinite),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _groups.isEmpty
                ? Center(
                    child: Text(
                      s.settings_noDuplicatesFound,
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _groups.length,
                    itemBuilder: (context, groupIndex) {
                      final group = _groups[groupIndex];
                      return _buildGroupCard(group, groupIndex, theme, s);
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        if (_groups.isNotEmpty)
          FilledButton(
            onPressed: _mergeAll,
            child: Text(s.settings_mergeConfirm),
          ),
      ],
    );
  }

  Widget _buildGroupCard(
    List<Location> group,
    int groupIndex,
    ThemeData theme,
    S s,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${group.first.name} (${group.length})',
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: 4.h),
            Text(
              s.settings_selectKeepLocation,
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: 8.h),
            ...group.map((loc) => RadioListTile<String>(
                  title: Text(loc.name),
                  subtitle: loc.description != null && loc.description!.isNotEmpty
                      ? Text(
                          loc.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  value: loc.id,
                  groupValue: _selectedKeep[groupIndex],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedKeep[groupIndex] = val);
                    }
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _mergeAll() async {
    final s = widget.localizations;
    for (var i = 0; i < _groups.length; i++) {
      final keepId = _selectedKeep[i];
      if (keepId == null) continue;
      final removeIds = _groups[i]
          .where((loc) => loc.id != keepId)
          .map((loc) => loc.id)
          .toList();
      if (removeIds.isNotEmpty) {
        await widget.controller.mergeDuplicates(keepId, removeIds);
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.settings_mergeConfirm)),
      );
    }
  }
}
