import 'package:flutter/material.dart';

import '../../../app/di/service_scope.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_generation_run_store.dart';
import '../../../app/state/story_generation_store.dart';
import '../../../app/state/story_outline_store.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../author_feedback/data/author_feedback_store.dart';
import '../../review_tasks/data/review_task_store.dart';
import '../domain/production_board_models.dart';

class ProductionBoardPage extends StatefulWidget {
  const ProductionBoardPage({super.key});

  static const titleKey = ValueKey<String>('production-board-title');
  static const progressKey = ValueKey<String>('production-board-progress');
  static const lanesKey = ValueKey<String>('production-board-lanes');
  static const recentRunKey = ValueKey<String>('production-board-recent-run');

  @override
  State<ProductionBoardPage> createState() => _ProductionBoardPageState();
}

class _ProductionBoardPageState extends State<ProductionBoardPage> {
  bool _isDrawerOpen = false;
  final ProductionBoardSnapshotBuilder _builder =
      const ProductionBoardSnapshotBuilder();

  @override
  Widget build(BuildContext context) {
    final workspaceStore = AppWorkspaceScope.of(context);
    final registry = ServiceScope.of(context);
    final outlineStore = registry.resolve<StoryOutlineStore>();
    final generationStore = registry.resolve<StoryGenerationStore>();
    final runStore = registry.resolve<StoryGenerationRunStore>();
    final authorFeedbackStore = AuthorFeedbackScope.of(context);
    final reviewTaskStore = ReviewTaskScope.of(context);
    final merged = Listenable.merge([
      workspaceStore,
      outlineStore,
      generationStore,
      runStore,
      authorFeedbackStore,
      reviewTaskStore,
    ]);

    return ListenableBuilder(
      listenable: merged,
      builder: (context, _) {
        final outline =
            outlineStore.snapshot.projectId == workspaceStore.currentProjectId
            ? outlineStore.snapshot
            : StoryOutlineSnapshot.empty(workspaceStore.currentProjectId);
        final generation =
            generationStore.snapshot.projectId ==
                workspaceStore.currentProjectId
            ? generationStore.snapshot
            : StoryGenerationSnapshot.empty(workspaceStore.currentProjectId);
        final snapshot = _builder.build(
          project: workspaceStore.currentProject,
          workspaceScenes: workspaceStore.scenes,
          outline: outline,
          generation: generation,
          run: runStore.snapshot,
        );

        return DesktopShellFrame(
          header: DesktopHeaderBar(
            titleKey: ProductionBoardPage.titleKey,
            title: 'Production Board',
            subtitle: '${snapshot.projectTitle} · 项目生产闭环',
            showBackButton: true,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 920;
              final main = _ProductionBoardMain(
                snapshot: snapshot,
                scrollable: !compact,
                onOpenWorkbench: () =>
                    AppNavigator.push(context, AppRoutes.workbench),
                onOpenStoryBible: () =>
                    AppNavigator.push(context, AppRoutes.storyBible),
                onOpenExport: () =>
                    AppNavigator.push(context, AppRoutes.importExport),
                onOpenReviewTasks: () =>
                    AppNavigator.push(context, AppRoutes.reviewTasks),
                activeFeedbackCount: authorFeedbackStore.items
                    .where((item) => item.isActive)
                    .length,
                activeReviewTaskCount: reviewTaskStore.openCount,
              );
              final side = _ProductionBoardSide(
                snapshot: snapshot,
                compact: compact,
              );

              return Row(
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
                  if (compact)
                    Expanded(
                      child: ListView(
                        children: [main, const SizedBox(height: 16), side],
                      ),
                    )
                  else ...[
                    Expanded(child: main),
                    const SizedBox(width: 16),
                    SizedBox(width: 340, child: side),
                  ],
                ],
              );
            },
          ),
          statusBar: DesktopStatusStrip(
            leftText:
                '进度 ${snapshot.completedScenes}/${snapshot.totalScenes} 场景',
            rightText: '最近运行：${snapshot.recentRun.statusLabel}',
          ),
        );
      },
    );
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return buildDesktopWorkspaceMenuItems(
      selected: DesktopWorkspaceSection.productionBoard,
      onShelf: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onProductionBoard: () {
        setState(() {
          _isDrawerOpen = false;
        });
      },
      onWorkbench: () => AppNavigator.push(context, AppRoutes.workbench),
      onReviewTasks: () => AppNavigator.push(context, AppRoutes.reviewTasks),
      onStyle: () => AppNavigator.push(context, AppRoutes.style),
      onScenes: () => AppNavigator.push(context, AppRoutes.scenes),
      onCharacters: () => AppNavigator.push(context, AppRoutes.characters),
      onWorldbuilding: () =>
          AppNavigator.push(context, AppRoutes.worldbuilding),
      onStoryBible: () => AppNavigator.push(context, AppRoutes.storyBible),
      onAudit: () => AppNavigator.push(context, AppRoutes.audit),
      onSettings: () => AppNavigator.push(context, AppRoutes.settings),
    );
  }
}

class _ProductionBoardMain extends StatelessWidget {
  const _ProductionBoardMain({
    required this.snapshot,
    required this.scrollable,
    required this.onOpenWorkbench,
    required this.onOpenStoryBible,
    required this.onOpenExport,
    required this.onOpenReviewTasks,
    required this.activeFeedbackCount,
    required this.activeReviewTaskCount,
  });

  final ProductionBoardSnapshot snapshot;
  final bool scrollable;
  final VoidCallback onOpenWorkbench;
  final VoidCallback onOpenStoryBible;
  final VoidCallback onOpenExport;
  final VoidCallback onOpenReviewTasks;
  final int activeFeedbackCount;
  final int activeReviewTaskCount;

  @override
  Widget build(BuildContext context) {
    final children = _children(context);

    return Container(
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: scrollable
          ? ListView(key: ProductionBoardPage.progressKey, children: children)
          : Column(
              key: ProductionBoardPage.progressKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
    );
  }

  List<Widget> _children(BuildContext context) {
    final theme = Theme.of(context);
    return [
      Text(snapshot.projectTitle, style: theme.textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(
        snapshot.projectSummary.isEmpty
            ? '当前项目还没有简介。'
            : snapshot.projectSummary,
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      _ProgressPanel(
        snapshot: snapshot,
        percent: (snapshot.completionRatio * 100).round(),
      ),
      const SizedBox(height: 16),
      _ActionStrip(
        onOpenWorkbench: onOpenWorkbench,
        onOpenStoryBible: onOpenStoryBible,
        onOpenExport: onOpenExport,
      ),
      const SizedBox(height: 16),
      _LoopHandoffPanel(
        snapshot: snapshot,
        activeFeedbackCount: activeFeedbackCount,
        activeReviewTaskCount: activeReviewTaskCount,
        onOpenWorkbench: onOpenWorkbench,
        onOpenReviewTasks: onOpenReviewTasks,
        onOpenStoryBible: onOpenStoryBible,
        onOpenExport: onOpenExport,
      ),
      const SizedBox(height: 16),
      _LaneBoard(snapshot: snapshot),
    ];
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.snapshot, required this.percent});

  final ProductionBoardSnapshot snapshot;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.subtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('生产进度', style: theme.textTheme.titleMedium)),
              Text('$percent%', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: snapshot.completionRatio),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(label: '章节', value: '${snapshot.totalChapters}'),
              _MetricChip(label: '场景', value: '${snapshot.totalScenes}'),
              _MetricChip(label: '已通过', value: '${snapshot.completedScenes}'),
              _MetricChip(label: '进行中', value: '${snapshot.inFlightScenes}'),
              _MetricChip(label: '需处理', value: '${snapshot.needsWorkScenes}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Text('$label $value', style: theme.textTheme.bodySmall),
    );
  }
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.onOpenWorkbench,
    required this.onOpenStoryBible,
    required this.onOpenExport,
  });

  final VoidCallback onOpenWorkbench;
  final VoidCallback onOpenStoryBible;
  final VoidCallback onOpenExport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onOpenWorkbench,
          icon: const Icon(Icons.play_arrow_outlined, size: 18),
          label: const Text('继续生成'),
        ),
        OutlinedButton.icon(
          onPressed: onOpenWorkbench,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('打开工作台'),
        ),
        OutlinedButton.icon(
          onPressed: onOpenStoryBible,
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: const Text('作品圣经'),
        ),
        OutlinedButton.icon(
          onPressed: onOpenExport,
          icon: const Icon(Icons.ios_share_outlined, size: 18),
          label: const Text('导出'),
        ),
      ],
    );
  }
}

class _LoopHandoffPanel extends StatelessWidget {
  const _LoopHandoffPanel({
    required this.snapshot,
    required this.activeFeedbackCount,
    required this.activeReviewTaskCount,
    required this.onOpenWorkbench,
    required this.onOpenReviewTasks,
    required this.onOpenStoryBible,
    required this.onOpenExport,
  });

  final ProductionBoardSnapshot snapshot;
  final int activeFeedbackCount;
  final int activeReviewTaskCount;
  final VoidCallback onOpenWorkbench;
  final VoidCallback onOpenReviewTasks;
  final VoidCallback onOpenStoryBible;
  final VoidCallback onOpenExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('闭环下一步', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 720 ? 1 : 2;
            return GridView.count(
              crossAxisCount: columns,
              childAspectRatio: columns == 1 ? 3.1 : 2.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _LoopHandoffCard(
                  icon: Icons.play_circle_outline,
                  title: '继续写作 / 生成',
                  countLabel: '${snapshot.notStartedScenes} 个未开始场景',
                  body: snapshot.notStartedScenes == 0
                      ? '没有未开始场景；可回到工作台继续编辑或重跑需要处理的场景。'
                      : '从工作台打开运行面板，选择场景后继续生成。',
                  actionLabel: '打开工作台',
                  onPressed: onOpenWorkbench,
                ),
                _LoopHandoffCard(
                  icon: Icons.fact_check_outlined,
                  title: 'Review Tasks',
                  countLabel:
                      '$activeReviewTaskCount 个活跃任务 · ${snapshot.reviewQueueScenes} 个看板审查项',
                  body: activeReviewTaskCount == 0
                      ? 'Review Tasks 已接入全局任务队列；可从工作台审查消息转为任务。'
                      : '打开任务队列，处理审查发现、修订项和忽略项。',
                  actionLabel: '打开审查任务',
                  onPressed: onOpenReviewTasks,
                ),
                _LoopHandoffCard(
                  icon: Icons.rate_review_outlined,
                  title: '作者反馈',
                  countLabel: '$activeFeedbackCount 条活跃反馈',
                  body: activeFeedbackCount == 0
                      ? '作者反馈已接入工作台；当前项目没有待处理反馈。'
                      : '从工作台反馈面板处理采纳、驳回或修订请求。',
                  actionLabel: '打开反馈面板',
                  onPressed: onOpenWorkbench,
                ),
                _LoopHandoffCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Story Bible',
                  countLabel:
                      '${snapshot.totalChapters} 章 / ${snapshot.totalScenes} 场景',
                  body: '核对项目素材、章节与场景上下文，再回到工作台继续生产。',
                  actionLabel: '打开作品圣经',
                  onPressed: onOpenStoryBible,
                ),
                _LoopHandoffCard(
                  icon: Icons.ios_share_outlined,
                  title: '导出',
                  countLabel:
                      '${snapshot.completedScenes}/${snapshot.totalScenes} 场景已通过',
                  body: snapshot.totalScenes == 0
                      ? '项目还没有可导出的场景；导出页可查看当前工程包状态。'
                      : '完成生成、审查和反馈处理后，导出当前项目工程包。',
                  actionLabel: '打开导出',
                  onPressed: onOpenExport,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LoopHandoffCard extends StatelessWidget {
  const _LoopHandoffCard({
    required this.icon,
    required this.title,
    required this.countLabel,
    required this.body,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String countLabel;
  final String body;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: palette.secondaryText),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 6),
          Text(countLabel, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.secondaryText,
              ),
            ),
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onPressed,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LaneBoard extends StatelessWidget {
  const _LaneBoard({required this.snapshot});

  final ProductionBoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ProductionBoardPage.lanesKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('场景状态', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 760 ? 1 : 2;
            return GridView.count(
              crossAxisCount: columns,
              childAspectRatio: columns == 1 ? 4.2 : 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final lane in ProductionBoardLane.values)
                  _LaneColumn(lane: lane, scenes: snapshot.lanes[lane] ?? []),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LaneColumn extends StatelessWidget {
  const _LaneColumn({required this.lane, required this.scenes});

  final ProductionBoardLane lane;
  final List<ProductionBoardSceneCard> scenes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _laneLabel(lane),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text('${scenes.length}', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: scenes.isEmpty
                ? Text('暂无场景', style: theme.textTheme.bodySmall)
                : ListView.separated(
                    itemCount: scenes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final scene = scenes[index];
                      return Text(
                        '${scene.title} · ${scene.statusLabel}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _laneLabel(ProductionBoardLane lane) {
    return switch (lane) {
      ProductionBoardLane.notStarted => '未开始',
      ProductionBoardLane.drafting => '草拟中',
      ProductionBoardLane.reviewing => '审查中',
      ProductionBoardLane.needsWork => '需处理',
      ProductionBoardLane.approved => '已通过',
    };
  }
}

class _ProductionBoardSide extends StatelessWidget {
  const _ProductionBoardSide({required this.snapshot, required this.compact});

  final ProductionBoardSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          SizedBox(height: 240, child: _RecentRunCard(run: snapshot.recentRun)),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: _ChapterList(chapters: snapshot.chapters),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: _RecentRunCard(run: snapshot.recentRun)),
        const SizedBox(height: 16),
        Expanded(child: _ChapterList(chapters: snapshot.chapters)),
      ],
    );
  }
}

class _RecentRunCard extends StatelessWidget {
  const _RecentRunCard({required this.run});

  final ProductionBoardRunCard run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ProductionBoardPage.recentRunKey,
      width: double.infinity,
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('最近运行', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(run.statusLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(run.headline, style: theme.textTheme.bodyMedium),
          if (run.sceneLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(run.sceneLabel, style: theme.textTheme.bodySmall),
          ],
          if (run.stageSummary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(run.stageSummary, style: theme.textTheme.bodySmall),
          ],
          if (run.summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(run.summary, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _ChapterList extends StatelessWidget {
  const _ChapterList({required this.chapters});

  final List<ProductionBoardChapterCard> chapters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: chapters.isEmpty
          ? const AppEmptyState(
              title: '暂无章节',
              message: '创建场景或导入大纲后，章节进度会显示在这里。',
            )
          : ListView.separated(
              itemCount: chapters.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text('章节进度', style: theme.textTheme.titleMedium);
                }
                final chapter = chapters[index - 1];
                return _ChapterTile(chapter: chapter);
              },
            ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter});

  final ProductionBoardChapterCard chapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.subtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chapter.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '${chapter.statusLabel} · ${chapter.completedScenes}/${chapter.totalScenes} 场景',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
