import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../data/writing_stats_store.dart';
import '../domain/writing_stats_models.dart';
import 'writing_stats_components.dart';

/// 写作统计与目标管理看板。
class WritingStatsPage extends ConsumerWidget {
  const WritingStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(writingStatsStoreProvider);
    final snapshot = store.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('写作统计'),
        actions: [
          IconButton(
            icon: Icon(
              store.reminderEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
            ),
            tooltip: store.reminderEnabled ? '关闭目标提醒' : '开启目标提醒',
            onPressed: () => store.reminderEnabled = !store.reminderEnabled,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TodaySummarySection(snapshot: snapshot),
          const SizedBox(height: 16),
          _TrendSection(store: store, snapshot: snapshot),
          const SizedBox(height: 16),
          _ProjectStatsSection(snapshot: snapshot),
          const SizedBox(height: 16),
          _GoalsSection(store: store, snapshot: snapshot),
        ],
      ),
    );
  }
}

// ============================================================================
// 今日摘要
// ============================================================================

class _TodaySummarySection extends StatelessWidget {
  const _TodaySummarySection({required this.snapshot});

  final WritingStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: '今日字数',
            value: snapshot.todayCharCount,
            unit: '字',
            icon: Icons.edit_note,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: '今日新增',
            value: snapshot.todayDeltaChars,
            unit: '字',
            icon: Icons.trending_up,
            color: snapshot.todayDeltaChars >= 0 ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: '本周新增',
            value: snapshot.weekCharCount,
            unit: '字',
            icon: Icons.date_range,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 趋势图
// ============================================================================

class _TrendSection extends StatefulWidget {
  const _TrendSection({required this.store, required this.snapshot});

  final WritingStatsStore store;
  final WritingStatsSnapshot snapshot;

  @override
  State<_TrendSection> createState() => _TrendSectionState();
}

class _TrendSectionState extends State<_TrendSection> {
  List<WritingDailyStat> _weekStats = [];

  @override
  void initState() {
    super.initState();
    _weekStats = widget.snapshot.dailyStats;
    _loadWeekStats();
  }

  @override
  void didUpdateWidget(_TrendSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.dailyStats != widget.snapshot.dailyStats) {
      _weekStats = widget.snapshot.dailyStats;
    }
  }

  Future<void> _loadWeekStats() async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 6));
    final fromStr =
        '${from.year.toString().padLeft(4, '0')}-'
        '${from.month.toString().padLeft(2, '0')}-'
        '${from.day.toString().padLeft(2, '0')}';
    final stats = await widget.store.loadDailyStats(fromDate: fromStr);
    if (mounted) {
      setState(() => _weekStats = stats);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('近 7 天趋势', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            DailyTrendChart(dailyStats: _weekStats),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 项目累计统计
// ============================================================================

class _ProjectStatsSection extends StatelessWidget {
  const _ProjectStatsSection({required this.snapshot});

  final WritingStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ps = snapshot.projectStat;
    if (ps.totalDeltaChars == 0 && ps.totalChapters == 0) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('项目累计', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InfoChip(label: '总字数', value: '${ps.totalDeltaChars}'),
                _InfoChip(label: '总章节', value: '${ps.totalChapters}'),
                _InfoChip(label: '写作次数', value: '${ps.totalSessions}'),
                _InfoChip(label: '日均产出', value: '${ps.averageDailyChars}'),
                if (ps.bestDayChars > 0)
                  _InfoChip(
                    label: '最佳单日',
                    value: '${ps.bestDayChars} (${ps.bestDayDate})',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 目标管理
// ============================================================================

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({required this.store, required this.snapshot});

  final WritingStatsStore store;
  final WritingStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('写作目标', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '添加目标',
                  onPressed: () => _addGoal(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (store.goals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '暂无写作目标，点击右上角 + 添加',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...store.goals.map((goal) {
                final progress = snapshot.goalProgress(goal);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GoalProgressIndicator(
                    goal: goal,
                    progress: progress,
                    onToggle: () => store.toggleGoal(goal.id),
                    onDelete: () => store.deleteGoal(goal.id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _addGoal(BuildContext context) async {
    final goal = await showDialog<WritingGoal>(
      context: context,
      builder: (_) => AddGoalDialog(projectId: store.activeProjectId),
    );
    if (goal != null) {
      await store.saveGoal(goal);
    }
  }
}
