import 'package:flutter/material.dart';

import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../domain/production_board_models.dart';
import 'production_board_page.dart';

// ---------------------------------------------------------------------------
// Main content area
// ---------------------------------------------------------------------------

class ProductionBoardMain extends StatelessWidget {
  const ProductionBoardMain({
    super.key,
    required this.snapshot,
    required this.scrollable,
    required this.onOpenWorkbench,
    required this.onOpenExport,
    required this.onOpenReviewTasks,
    required this.activeFeedbackCount,
    required this.activeReviewTaskCount,
  });

  final ProductionBoardSnapshot snapshot;
  final bool scrollable;
  final VoidCallback onOpenWorkbench;
  final VoidCallback onOpenExport;
  final VoidCallback onOpenReviewTasks;
  final int activeFeedbackCount;
  final int activeReviewTaskCount;

  @override
  Widget build(BuildContext context) {
    final children = _children(context);

    return Container(
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(AppDesignTokens.space16),
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
      const SizedBox(height: AppDesignTokens.space16),
      ProductionProgressPanel(
        snapshot: snapshot,
        percent: (snapshot.completionRatio * 100).round(),
      ),
      const SizedBox(height: AppDesignTokens.space16),
      ProductionDailyTrendPanel(snapshot: snapshot),
      const SizedBox(height: AppDesignTokens.space16),
      ProductionActionStrip(
        onOpenWorkbench: onOpenWorkbench,
        onOpenExport: onOpenExport,
      ),
      const SizedBox(height: AppDesignTokens.space16),
      ProductionLoopHandoffPanel(
        snapshot: snapshot,
        activeFeedbackCount: activeFeedbackCount,
        activeReviewTaskCount: activeReviewTaskCount,
        onOpenWorkbench: onOpenWorkbench,
        onOpenReviewTasks: onOpenReviewTasks,
        onOpenExport: onOpenExport,
      ),
      const SizedBox(height: AppDesignTokens.space16),
      ProductionLaneBoard(snapshot: snapshot),
    ];
  }
}

// ---------------------------------------------------------------------------
// Progress panel
// ---------------------------------------------------------------------------

class ProductionProgressPanel extends StatelessWidget {
  const ProductionProgressPanel({
    super.key,
    required this.snapshot,
    required this.percent,
  });

  final ProductionBoardSnapshot snapshot;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignTokens.space12),
      decoration: BoxDecoration(
        color: palette.subtle,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('写作进度', style: theme.textTheme.titleMedium)),
              Text('$percent%', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppDesignTokens.space8),
          LinearProgressIndicator(value: snapshot.completionRatio),
          const SizedBox(height: AppDesignTokens.space12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ProductionMetricChip(
                label: '总字数',
                value: _formatProductionNumber(snapshot.totalWordCount),
              ),
              ProductionMetricChip(
                label: '章节数',
                value: '${snapshot.totalChapters}',
              ),
              ProductionMetricChip(
                label: '章节块',
                value: '${snapshot.totalScenes}',
              ),
              ProductionMetricChip(
                label: '已通过',
                value: '${snapshot.completedScenes}',
              ),
              ProductionMetricChip(
                label: '进行中',
                value: '${snapshot.inFlightScenes}',
              ),
              ProductionMetricChip(
                label: '需处理',
                value: '${snapshot.needsWorkScenes}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric chip
// ---------------------------------------------------------------------------

class ProductionMetricChip extends StatelessWidget {
  const ProductionMetricChip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.space8,
        vertical: AppDesignTokens.space8,
      ),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        border: Border.all(color: palette.border),
      ),
      child: Text('$label $value', style: theme.textTheme.bodySmall),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily trend panel
// ---------------------------------------------------------------------------

class ProductionDailyTrendPanel extends StatelessWidget {
  const ProductionDailyTrendPanel({super.key, required this.snapshot});

  final ProductionBoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final trend = snapshot.dailyWordTrend;
    final maxDelta = trend.fold<int>(
      0,
      (max, item) => item.deltaChars > max ? item.deltaChars : max,
    );
    return Container(
      key: ProductionBoardPage.dailyTrendKey,
      padding: const EdgeInsets.all(AppDesignTokens.space12),
      decoration: BoxDecoration(
        color: palette.subtle,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('每日字数趋势', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space8),
          if (trend.isEmpty)
            Text(
              '暂无写作趋势',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.secondaryText,
              ),
            )
          else
            Column(
              children: [
                for (final item in trend) ...[
                  ProductionDailyTrendRow(item: item, maxDelta: maxDelta),
                  if (item != trend.last)
                    const SizedBox(height: AppDesignTokens.space8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class ProductionDailyTrendRow extends StatelessWidget {
  const ProductionDailyTrendRow({
    super.key,
    required this.item,
    required this.maxDelta,
  });

  final ProductionDailyWordStat item;
  final int maxDelta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final ratio = maxDelta <= 0 ? 0.0 : item.deltaChars / maxDelta;
    final valueLabel = item.deltaChars >= 0
        ? '+${_formatProductionNumber(item.deltaChars)}'
        : '-${_formatProductionNumber(item.deltaChars.abs())}';
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(item.date, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: palette.elevated,
            ),
          ),
        ),
        const SizedBox(width: AppDesignTokens.space8),
        SizedBox(
          width: 56,
          child: Text(
            valueLabel,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action strip
// ---------------------------------------------------------------------------

class ProductionActionStrip extends StatelessWidget {
  const ProductionActionStrip({
    super.key,
    required this.onOpenWorkbench,
    required this.onOpenExport,
  });

  final VoidCallback onOpenWorkbench;
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
          onPressed: onOpenExport,
          icon: const Icon(Icons.ios_share_outlined, size: 18),
          label: const Text('导出'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loop handoff panel
// ---------------------------------------------------------------------------

class ProductionLoopHandoffPanel extends StatelessWidget {
  const ProductionLoopHandoffPanel({
    super.key,
    required this.snapshot,
    required this.activeFeedbackCount,
    required this.activeReviewTaskCount,
    required this.onOpenWorkbench,
    required this.onOpenReviewTasks,
    required this.onOpenExport,
  });

  final ProductionBoardSnapshot snapshot;
  final int activeFeedbackCount;
  final int activeReviewTaskCount;
  final VoidCallback onOpenWorkbench;
  final VoidCallback onOpenReviewTasks;
  final VoidCallback onOpenExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('闭环下一步', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppDesignTokens.space8),
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
                ProductionLoopHandoffCard(
                  icon: Icons.play_circle_outline,
                  title: '继续写作',
                  countLabel: '${snapshot.notStartedScenes} 个未开始章节',
                  body: snapshot.notStartedScenes == 0
                      ? '没有未开始章节；可回到工作台继续编辑或重跑需要处理的章节。'
                      : '从工作台选择章节，继续生成或手工修订。',
                  actionLabel: '打开工作台',
                  onPressed: onOpenWorkbench,
                ),
                ProductionLoopHandoffCard(
                  icon: Icons.fact_check_outlined,
                  title: '改稿清单',
                  countLabel:
                      '$activeReviewTaskCount 个待处理事项 · ${snapshot.reviewQueueScenes} 个待核对章节',
                  body: activeReviewTaskCount == 0
                      ? '改稿清单会收纳工作台里的审查消息和修订提醒。'
                      : '打开改稿清单，处理问题检查结果、修订项和忽略项。',
                  actionLabel: '打开改稿清单',
                  onPressed: onOpenReviewTasks,
                ),
                ProductionLoopHandoffCard(
                  icon: Icons.rate_review_outlined,
                  title: '作者反馈',
                  countLabel: '$activeFeedbackCount 条活跃反馈',
                  body: activeFeedbackCount == 0
                      ? '作者反馈已接入工作台；当前项目没有待处理反馈。'
                      : '从工作台反馈面板处理采纳、驳回或修订请求。',
                  actionLabel: '打开作者反馈',
                  onPressed: onOpenWorkbench,
                ),
                ProductionLoopHandoffCard(
                  icon: Icons.ios_share_outlined,
                  title: '导出',
                  countLabel:
                      '${snapshot.completedScenes}/${snapshot.totalScenes} 章节已通过',
                  body: snapshot.totalScenes == 0
                      ? '项目还没有可导出的章节；导出页可查看当前作品资料。'
                      : '完成草稿、问题检查和反馈处理后，导出当前作品资料。',
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

// ---------------------------------------------------------------------------
// Loop handoff card
// ---------------------------------------------------------------------------

class ProductionLoopHandoffCard extends StatelessWidget {
  const ProductionLoopHandoffCard({
    super.key,
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
      padding: const EdgeInsets.all(AppDesignTokens.space12),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
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
          const SizedBox(height: AppDesignTokens.space4),
          Text(countLabel, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppDesignTokens.space4),
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
            const SizedBox(height: AppDesignTokens.space8),
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

// ---------------------------------------------------------------------------
// Lane board
// ---------------------------------------------------------------------------

class ProductionLaneBoard extends StatelessWidget {
  const ProductionLaneBoard({super.key, required this.snapshot});

  final ProductionBoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ProductionBoardPage.lanesKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('章节状态', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppDesignTokens.space8),
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
                  ProductionLaneColumn(
                    lane: lane,
                    scenes: snapshot.lanes[lane] ?? [],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Lane column
// ---------------------------------------------------------------------------

class ProductionLaneColumn extends StatelessWidget {
  const ProductionLaneColumn({
    super.key,
    required this.lane,
    required this.scenes,
  });

  final ProductionBoardLane lane;
  final List<ProductionBoardSceneCard> scenes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignTokens.space12),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
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
          const SizedBox(height: AppDesignTokens.space8),
          Expanded(
            child: scenes.isEmpty
                ? Text('暂无章节', style: theme.textTheme.bodySmall)
                : ListView.separated(
                    itemCount: scenes.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDesignTokens.space4),
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

// ---------------------------------------------------------------------------
// Side panel
// ---------------------------------------------------------------------------

class ProductionBoardSide extends StatelessWidget {
  const ProductionBoardSide({
    super.key,
    required this.snapshot,
    required this.compact,
    required this.onOpenChapter,
  });

  final ProductionBoardSnapshot snapshot;
  final bool compact;
  final ValueChanged<ProductionBoardChapterCard> onOpenChapter;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          SizedBox(
            height: 240,
            child: ProductionRecentRunCard(run: snapshot.recentRun),
          ),
          const SizedBox(height: AppDesignTokens.space16),
          SizedBox(
            height: 320,
            child: ProductionChapterList(
              chapters: snapshot.chapters,
              onOpenChapter: onOpenChapter,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: ProductionRecentRunCard(run: snapshot.recentRun)),
        const SizedBox(height: AppDesignTokens.space16),
        Expanded(
          child: ProductionChapterList(
            chapters: snapshot.chapters,
            onOpenChapter: onOpenChapter,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent run card
// ---------------------------------------------------------------------------

class ProductionRecentRunCard extends StatelessWidget {
  const ProductionRecentRunCard({super.key, required this.run});

  final ProductionBoardRunCard run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ProductionBoardPage.recentRunKey,
      width: double.infinity,
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(AppDesignTokens.space16),
      child: ListView(
        children: [
          Text('最近写作', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space8),
          Text(run.statusLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppDesignTokens.space8),
          Text(run.headline, style: theme.textTheme.bodyMedium),
          if (run.sceneLabel.isNotEmpty) ...[
            const SizedBox(height: AppDesignTokens.space4),
            Text(run.sceneLabel, style: theme.textTheme.bodySmall),
          ],
          if (run.stageSummary.isNotEmpty) ...[
            const SizedBox(height: AppDesignTokens.space4),
            Text(run.stageSummary, style: theme.textTheme.bodySmall),
          ],
          if (run.summary.isNotEmpty) ...[
            const SizedBox(height: AppDesignTokens.space8),
            Text(run.summary, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter list
// ---------------------------------------------------------------------------

class ProductionChapterList extends StatelessWidget {
  const ProductionChapterList({
    super.key,
    required this.chapters,
    required this.onOpenChapter,
  });

  final List<ProductionBoardChapterCard> chapters;
  final ValueChanged<ProductionBoardChapterCard> onOpenChapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ProductionBoardPage.chapterListKey,
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(AppDesignTokens.space16),
      child: chapters.isEmpty
          ? const AppEmptyState(
              title: '暂无章节',
              message: '创建章节或导入大纲后，章节进度会显示在这里。',
            )
          : ListView.separated(
              itemCount: chapters.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppDesignTokens.space8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text('章节进度', style: theme.textTheme.titleMedium);
                }
                final chapter = chapters[index - 1];
                return ProductionChapterTile(
                  chapter: chapter,
                  onOpenChapter: onOpenChapter,
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter tile
// ---------------------------------------------------------------------------

class ProductionChapterTile extends StatelessWidget {
  const ProductionChapterTile({
    super.key,
    required this.chapter,
    required this.onOpenChapter,
  });

  final ProductionBoardChapterCard chapter;
  final ValueChanged<ProductionBoardChapterCard> onOpenChapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return InkWell(
      key: ProductionBoardPage.chapterTileKey(chapter.id),
      onTap: chapter.canOpen ? () => onOpenChapter(chapter) : null,
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.all(AppDesignTokens.space12),
        decoration: BoxDecoration(
          color: palette.subtle,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(chapter.title, style: theme.textTheme.titleSmall),
                ),
                if (chapter.canOpen)
                  Icon(
                    Icons.open_in_new_outlined,
                    size: 14,
                    color: palette.secondaryText,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${chapter.statusLabel} · ${chapter.completedScenes}/${chapter.totalScenes} 章节',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatProductionNumber(int value) {
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(1)}万';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return value.toString();
}
