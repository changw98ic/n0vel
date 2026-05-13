import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/state/story_arc_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'story_arc_timeline_components.dart';

/// 故事弧线时间线页面
///
/// 提供：
/// - 时间线视图（章节 + 场景按序排列）
/// - 张力曲线可视化
/// - 悬空伏笔告警面板
/// - 拖拽排序场景并回写
/// - 撤销支持
class StoryArcTimelinePage extends ConsumerStatefulWidget {
  const StoryArcTimelinePage({super.key});

  static const titleKey = ValueKey<String>('story-arc-timeline-title');

  @override
  ConsumerState<StoryArcTimelinePage> createState() =>
      _StoryArcTimelinePageState();
}

class _StoryArcTimelinePageState extends ConsumerState<StoryArcTimelinePage> {
  @override
  Widget build(BuildContext context) {
    final arcStore = ref.watch(storyArcStoreProvider);
    final workspaceStore = ref.watch(appWorkspaceStoreProvider);
    final snapshot = arcStore.snapshot;

    return DesktopShellFrame(
      header: DesktopHeaderBar(
        titleKey: StoryArcTimelinePage.titleKey,
        title: '故事弧线',
        subtitle: '${workspaceStore.currentProject.title} · 情节线与伏笔追踪',
        showBackButton: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: AppDesignTokens.space16),
              // 左侧：时间线 + 拖拽排序
              Expanded(
                child: _TimelineMainArea(
                  snapshot: snapshot,
                  arcStore: arcStore,
                  compact: compact,
                ),
              ),
              const SizedBox(width: AppDesignTokens.space16),
              // 右侧：伏笔告警面板
              if (!compact)
                SizedBox(
                  width: 340,
                  child: _ForeshadowingSidePanel(
                    snapshot: snapshot,
                    arcStore: arcStore,
                  ),
                ),
              const SizedBox(width: AppDesignTokens.space16),
            ],
          );
        },
      ),
      statusBar: DesktopStatusStrip(
        leftText: _buildStatusLeft(snapshot),
        rightText: arcStore.canUndo ? '可撤销' : '',
      ),
    );
  }

  String _buildStatusLeft(StoryArcSnapshot snapshot) {
    final active = snapshot.narrativeArcState.activeThreads.length;
    final dangling = snapshot.danglingForeshadowing.length;
    final parts = <String>['活跃情节线 $active'];
    if (dangling > 0) {
      parts.add('悬空伏笔 $dangling');
    }
    return parts.join(' · ');
  }
}

// ============================================================================
// 时间线主区域
// ============================================================================

class _TimelineMainArea extends StatelessWidget {
  const _TimelineMainArea({
    required this.snapshot,
    required this.arcStore,
    required this.compact,
  });

  final StoryArcSnapshot snapshot;
  final StoryArcStore arcStore;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部工具栏
        _buildToolbar(context),
        const SizedBox(height: AppDesignTokens.space8),
        // 张力曲线
        TensionCurveChart(
          threads: snapshot.narrativeArcState.activeThreads,
          foreshadowing: snapshot.narrativeArcState.pendingForeshadowing,
        ),
        const SizedBox(height: AppDesignTokens.space16),
        // 时间线主体（可拖拽）
        Expanded(
          child: _DraggableTimeline(
            snapshot: snapshot,
            arcStore: arcStore,
          ),
        ),
        // 紧凑模式下的伏笔面板
        if (compact) ...[
          const SizedBox(height: AppDesignTokens.space16),
          SizedBox(
            height: 200,
            child: _ForeshadowingSidePanel(
              snapshot: snapshot,
              arcStore: arcStore,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        Text(
          '时间线',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (arcStore.canUndo)
          TextButton.icon(
            onPressed: arcStore.undo,
            icon: const Icon(Icons.undo, size: AppDesignTokens.iconSmall),
            label: const Text('撤销'),
          ),
      ],
    );
  }
}

// ============================================================================
// 可拖拽时间线
// ============================================================================

class _DraggableTimeline extends StatefulWidget {
  const _DraggableTimeline({
    required this.snapshot,
    required this.arcStore,
  });

  final StoryArcSnapshot snapshot;
  final StoryArcStore arcStore;

  @override
  State<_DraggableTimeline> createState() => _DraggableTimelineState();
}

class _DraggableTimelineState extends State<_DraggableTimeline> {
  late List<String> _sceneOrder;

  @override
  void initState() {
    super.initState();
    _sceneOrder = List.from(widget.snapshot.sceneOrder);
  }

  @override
  void didUpdateWidget(_DraggableTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅在外部更新时同步（非拖拽期间）
    final external = widget.snapshot.sceneOrder;
    if (!_listEquals(_sceneOrder, external)) {
      _sceneOrder = List.from(external);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sceneOrder.isEmpty) {
      return _buildEmptyState(context);
    }

    return ReorderableListView.builder(
      itemCount: _sceneOrder.length,
      onReorder: _handleReorder,
      itemBuilder: (context, index) {
        final sceneId = _sceneOrder[index];
        final threads = widget.snapshot.narrativeArcState.activeThreads
            .where((t) => t.introducedInScene.contains(sceneId))
            .toList();
        final foreshadowing = widget.snapshot.narrativeArcState
            .pendingForeshadowing
            .where(
              (f) =>
                  f.plantedInScene.contains(sceneId) &&
                  f.resolvedInScene == null,
            )
            .toList();

        return TimelineSceneCard(
          key: ValueKey('timeline-scene-$sceneId-$index'),
          sceneId: sceneId,
          index: index,
          threads: threads,
          foreshadowing: foreshadowing,
        );
      },
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _sceneOrder.removeAt(oldIndex);
      _sceneOrder.insert(newIndex, item);
    });
    // 回写到 store
    widget.arcStore.reorderScenes(List.unmodifiable(_sceneOrder));
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline,
            size: 48,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: AppDesignTokens.space16),
          Text(
            '暂无场景数据',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppDesignTokens.space8),
          Text(
            '开始创作后，场景会自动出现在时间线中',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ============================================================================
// 伏笔告警侧面板
// ============================================================================

class _ForeshadowingSidePanel extends StatelessWidget {
  const _ForeshadowingSidePanel({
    required this.snapshot,
    required this.arcStore,
  });

  final StoryArcSnapshot snapshot;
  final StoryArcStore arcStore;

  @override
  Widget build(BuildContext context) {
    final dangling = snapshot.danglingForeshadowing;
    final resolved = [
      for (final f in snapshot.narrativeArcState.pendingForeshadowing)
        if (f.resolvedInScene != null) f,
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(AppDesignTokens.space12),
            color: dangling.isNotEmpty
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  dangling.isNotEmpty
                      ? Icons.warning_amber
                      : Icons.check_circle_outline,
                  size: AppDesignTokens.iconMedium,
                  color: dangling.isNotEmpty
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppDesignTokens.space8),
                Text(
                  '伏笔追踪',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (dangling.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesignTokens.space8,
                      vertical: AppDesignTokens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: AppDesignTokens.borderRadiusSmall,
                    ),
                    child: Text(
                      '${dangling.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: AppDesignTokens.fontSizeSmall,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 列表
          Expanded(
            child: dangling.isEmpty && resolved.isEmpty
                ? Center(
                    child: Text(
                      '暂无伏笔记录',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppDesignTokens.space8),
                    children: [
                      if (dangling.isNotEmpty) ...[
                        _SectionHeader(label: '待回收 (${dangling.length})'),
                        for (final f in dangling)
                          ForeshadowingCard(
                            foreshadowing: f,
                            isResolved: false,
                            onResolve: () => _showResolveDialog(
                              context,
                              f.id,
                              f.hint,
                            ),
                            onUrgencyChanged: (urgency) =>
                                arcStore.updateForeshadowingUrgency(
                                  f.id,
                                  urgency,
                                ),
                          ),
                      ],
                      if (resolved.isNotEmpty) ...[
                        const SizedBox(height: AppDesignTokens.space12),
                        _SectionHeader(label: '已回收 (${resolved.length})'),
                        for (final f in resolved)
                          ForeshadowingCard(
                            foreshadowing: f,
                            isResolved: true,
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showResolveDialog(
    BuildContext context,
    String foreshadowingId,
    String hint,
  ) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('标记伏笔已回收'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('伏笔: $hint'),
            const SizedBox(height: AppDesignTokens.space12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '回收场景 ID',
                hintText: '输入回收该伏笔的场景 ID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final sceneId = controller.text.trim();
              if (sceneId.isNotEmpty) {
                arcStore.resolveForeshadowing(foreshadowingId, sceneId);
              }
              Navigator.of(context).pop();
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.space8,
        vertical: AppDesignTokens.space4,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
