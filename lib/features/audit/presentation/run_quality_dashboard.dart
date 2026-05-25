import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/llm/app_llm_call_trace.dart';
import '../../../app/state/story_generation_run_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'audit_center_components.dart';

enum RunQualityStatusFilter { all, successful, failed }

class RunQualityHistoryEntry {
  const RunQualityHistoryEntry({
    required this.runId,
    required this.sceneId,
    required this.sceneLabel,
    required this.status,
    required this.startedAtMs,
    required this.durationMs,
    required this.model,
    required this.stageCount,
    required this.failedStageCount,
    required this.summary,
  });

  factory RunQualityHistoryEntry.fromSnapshot(
    StoryGenerationRunSnapshot snapshot, {
    String? runId,
    int? startedAtMs,
    int? durationMs,
    String model = '',
  }) {
    final failedStages = snapshot.stageTimeline
        .where((stage) => stage.status == StoryGenerationRunStageStatus.failed)
        .length;
    return RunQualityHistoryEntry(
      runId: runId ?? 'current-${snapshot.sceneId}-${snapshot.status.name}',
      sceneId: snapshot.sceneId,
      sceneLabel: snapshot.sceneLabel,
      status: snapshot.status,
      startedAtMs: startedAtMs ?? 0,
      durationMs: durationMs,
      model: model.trim().isEmpty ? '未记录模型' : model.trim(),
      stageCount: snapshot.stageTimeline.length,
      failedStageCount: failedStages,
      summary: snapshot.errorDetail.trim().isNotEmpty
          ? snapshot.errorDetail.trim()
          : snapshot.summary.trim(),
    );
  }

  final String runId;
  final String sceneId;
  final String sceneLabel;
  final StoryGenerationRunStatus status;
  final int startedAtMs;
  final int? durationMs;
  final String model;
  final int stageCount;
  final int failedStageCount;
  final String summary;

  bool get isSuccess => status == StoryGenerationRunStatus.completed;

  bool get isFailure =>
      status == StoryGenerationRunStatus.failed ||
      status == StoryGenerationRunStatus.cancelled;

  String get statusLabel {
    return switch (status) {
      StoryGenerationRunStatus.idle => '未运行',
      StoryGenerationRunStatus.running => '运行中',
      StoryGenerationRunStatus.completed => '成功',
      StoryGenerationRunStatus.failed => '失败',
      StoryGenerationRunStatus.cancelled => '已取消',
    };
  }

  String get startedLabel {
    if (startedAtMs <= 0) {
      return '时间未记录';
    }
    final started = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
    return '${started.year.toString().padLeft(4, '0')}-'
        '${started.month.toString().padLeft(2, '0')}-'
        '${started.day.toString().padLeft(2, '0')} '
        '${started.hour.toString().padLeft(2, '0')}:'
        '${started.minute.toString().padLeft(2, '0')}';
  }
}

class RunQualityMetricSummary {
  const RunQualityMetricSummary({
    required this.totalRuns,
    required this.successCount,
    required this.failureCount,
    required this.averageDurationMs,
  });

  final int totalRuns;
  final int successCount;
  final int failureCount;
  final int averageDurationMs;

  String get successRateLabel {
    if (totalRuns == 0) {
      return '0%';
    }
    return '${((successCount / totalRuns) * 100).round()}%';
  }
}

class RunQualityModelUsage {
  const RunQualityModelUsage({
    required this.model,
    required this.callCount,
    required this.successCount,
    required this.failureCount,
    required this.totalTokens,
    required this.averageLatencyMs,
  });

  final String model;
  final int callCount;
  final int successCount;
  final int failureCount;
  final int totalTokens;
  final int averageLatencyMs;

  String get successRateLabel {
    if (callCount == 0) {
      return '0%';
    }
    return '${((successCount / callCount) * 100).round()}%';
  }
}

class RunQualityDashboardSnapshot {
  const RunQualityDashboardSnapshot({
    required this.metrics,
    required this.runs,
    required this.visibleRuns,
    required this.modelUsage,
    required this.filter,
  });

  final RunQualityMetricSummary metrics;
  final List<RunQualityHistoryEntry> runs;
  final List<RunQualityHistoryEntry> visibleRuns;
  final List<RunQualityModelUsage> modelUsage;
  final RunQualityStatusFilter filter;

  String exportMarkdown() {
    final buffer = StringBuffer()
      ..writeln('## Run Quality Export')
      ..writeln()
      ..writeln('- total runs: ${metrics.totalRuns}')
      ..writeln('- successful runs: ${metrics.successCount}')
      ..writeln('- failed runs: ${metrics.failureCount}')
      ..writeln('- success rate: ${metrics.successRateLabel}')
      ..writeln('- average duration: ${_formatDuration(averageDurationMs)}')
      ..writeln()
      ..writeln('### Visible runs');
    for (final run in visibleRuns) {
      buffer.writeln(
        '- ${run.sceneLabel}: ${run.statusLabel}, '
        '${_formatDuration(run.durationMs)}, ${run.model}',
      );
    }
    buffer
      ..writeln()
      ..writeln('### Model usage');
    for (final usage in modelUsage) {
      buffer.writeln(
        '- ${usage.model}: ${usage.callCount} calls, '
        '${usage.totalTokens} tokens, avg ${_formatDuration(usage.averageLatencyMs)}',
      );
    }
    return buffer.toString();
  }

  int get averageDurationMs => metrics.averageDurationMs;
}

class RunQualityDashboardSnapshotBuilder {
  const RunQualityDashboardSnapshotBuilder();

  RunQualityDashboardSnapshot build({
    List<RunQualityHistoryEntry> history = const [],
    StoryGenerationRunSnapshot? currentRun,
    List<AppLlmCallTraceEntry> modelTraces = const [],
    RunQualityStatusFilter filter = RunQualityStatusFilter.all,
  }) {
    final runs = <RunQualityHistoryEntry>[...history];
    if (currentRun != null && currentRun.hasRun) {
      final currentEntry = RunQualityHistoryEntry.fromSnapshot(currentRun);
      final alreadyListed = runs.any((run) => run.runId == currentEntry.runId);
      if (!alreadyListed) {
        runs.insert(0, currentEntry);
      }
    }
    runs.sort((a, b) => b.startedAtMs.compareTo(a.startedAtMs));

    final visibleRuns = [
      for (final run in runs)
        if (_matchesFilter(run, filter)) run,
    ];
    final durations = [
      for (final run in runs)
        if (run.durationMs != null) run.durationMs!,
    ];
    final metrics = RunQualityMetricSummary(
      totalRuns: runs.length,
      successCount: runs.where((run) => run.isSuccess).length,
      failureCount: runs.where((run) => run.isFailure).length,
      averageDurationMs: _average(durations),
    );
    return RunQualityDashboardSnapshot(
      metrics: metrics,
      runs: List<RunQualityHistoryEntry>.unmodifiable(runs),
      visibleRuns: List<RunQualityHistoryEntry>.unmodifiable(visibleRuns),
      modelUsage: _modelUsage(modelTraces),
      filter: filter,
    );
  }

  bool _matchesFilter(
    RunQualityHistoryEntry run,
    RunQualityStatusFilter filter,
  ) {
    return switch (filter) {
      RunQualityStatusFilter.all => true,
      RunQualityStatusFilter.successful => run.isSuccess,
      RunQualityStatusFilter.failed => run.isFailure,
    };
  }

  List<RunQualityModelUsage> _modelUsage(List<AppLlmCallTraceEntry> traces) {
    final buckets = <String, List<AppLlmCallTraceEntry>>{};
    for (final trace in traces) {
      final model = trace.model.trim().isEmpty ? '未记录模型' : trace.model.trim();
      buckets.putIfAbsent(model, () => <AppLlmCallTraceEntry>[]).add(trace);
    }
    final usage = [
      for (final entry in buckets.entries)
        RunQualityModelUsage(
          model: entry.key,
          callCount: entry.value.length,
          successCount: entry.value.where((trace) => trace.succeeded).length,
          failureCount: entry.value.where((trace) => !trace.succeeded).length,
          totalTokens: entry.value.fold<int>(
            0,
            (total, trace) =>
                total +
                (trace.totalTokens ??
                    trace.estimatedPromptTokens +
                        trace.estimatedCompletionTokens),
          ),
          averageLatencyMs: _average([
            for (final trace in entry.value)
              if (trace.latencyMs != null) trace.latencyMs!,
          ]),
        ),
    ];
    usage.sort((a, b) {
      final calls = b.callCount.compareTo(a.callCount);
      if (calls != 0) {
        return calls;
      }
      return a.model.compareTo(b.model);
    });
    return List<RunQualityModelUsage>.unmodifiable(usage);
  }
}

class RunQualityDashboardPage extends ConsumerStatefulWidget {
  const RunQualityDashboardPage({
    super.key,
    this.history = const [],
    this.modelTraces = const [],
    this.currentSnapshot,
  });

  static const titleKey = ValueKey<String>('run-quality-dashboard-title');
  static const metricsKey = ValueKey<String>('run-quality-dashboard-metrics');
  static const historyKey = ValueKey<String>('run-quality-dashboard-history');
  static const modelUsageKey = ValueKey<String>(
    'run-quality-dashboard-model-usage',
  );
  static const allFilterKey = ValueKey<String>('run-quality-filter-all');
  static const successFilterKey = ValueKey<String>(
    'run-quality-filter-success',
  );
  static const failedFilterKey = ValueKey<String>('run-quality-filter-failed');
  static const exportButtonKey = ValueKey<String>('run-quality-export-button');
  static const exportPreviewKey = ValueKey<String>(
    'run-quality-export-preview',
  );

  final List<RunQualityHistoryEntry> history;
  final List<AppLlmCallTraceEntry> modelTraces;
  final StoryGenerationRunSnapshot? currentSnapshot;

  @override
  ConsumerState<RunQualityDashboardPage> createState() =>
      _RunQualityDashboardPageState();
}

class _RunQualityDashboardPageState
    extends ConsumerState<RunQualityDashboardPage> {
  final RunQualityDashboardSnapshotBuilder _builder =
      const RunQualityDashboardSnapshotBuilder();
  RunQualityStatusFilter _filter = RunQualityStatusFilter.all;
  bool _showExport = false;

  @override
  Widget build(BuildContext context) {
    final currentRun =
        widget.currentSnapshot ??
        ref.watch(storyGenerationRunStoreProvider).snapshot;
    final snapshot = _builder.build(
      history: widget.history,
      currentRun: currentRun,
      modelTraces: widget.modelTraces,
      filter: _filter,
    );

    return DesktopShellFrame(
      header: DesktopHeaderBar(
        titleKey: RunQualityDashboardPage.titleKey,
        title: '运行质量',
        subtitle: 'Pipeline run 历史、质量指标与模型调用概览',
        showBackButton: true,
        actions: [
          OutlinedButton.icon(
            key: RunQualityDashboardPage.exportButtonKey,
            onPressed: () => setState(() => _showExport = !_showExport),
            icon: const Icon(Icons.ios_share_outlined, size: 18),
            label: const Text('导出'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 960;
          final filters = _RunQualityFilterPanel(
            snapshot: snapshot,
            selectedFilter: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
          );
          final history = _RunQualityHistoryPanel(
            snapshot: snapshot,
            fillAvailable: !compact,
          );
          final usage = _RunQualityModelUsagePanel(
            snapshot: snapshot,
            showExport: _showExport,
            fillAvailable: !compact,
          );
          if (compact) {
            return ListView(
              children: [
                filters,
                const SizedBox(height: AppDesignTokens.space16),
                history,
                const SizedBox(height: AppDesignTokens.space16),
                usage,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 264, child: filters),
              const SizedBox(width: AppDesignTokens.space16),
              Expanded(child: history),
              const SizedBox(width: AppDesignTokens.space16),
              SizedBox(width: 340, child: usage),
            ],
          );
        },
      ),
      statusBar: DesktopStatusStrip(
        leftText:
            '运行 ${snapshot.metrics.totalRuns} 次 · 成功率 ${snapshot.metrics.successRateLabel}',
        rightText: '当前筛选：${_filterLabel(snapshot.filter)}',
      ),
    );
  }
}

class _RunQualityFilterPanel extends StatelessWidget {
  const _RunQualityFilterPanel({
    required this.snapshot,
    required this.selectedFilter,
    required this.onChanged,
  });

  final RunQualityDashboardSnapshot snapshot;
  final RunQualityStatusFilter selectedFilter;
  final ValueChanged<RunQualityStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        key: RunQualityDashboardPage.metricsKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('质量概览', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _MetricLine(
            icon: Icons.playlist_add_check_rounded,
            label: '总运行',
            value: '${snapshot.metrics.totalRuns}',
          ),
          _MetricLine(
            icon: Icons.check_circle_outline,
            label: '成功',
            value: '${snapshot.metrics.successCount}',
          ),
          _MetricLine(
            icon: Icons.error_outline,
            label: '失败',
            value: '${snapshot.metrics.failureCount}',
          ),
          _MetricLine(
            icon: Icons.timer_outlined,
            label: '平均耗时',
            value: _formatDuration(snapshot.metrics.averageDurationMs),
          ),
          const SizedBox(height: 12),
          AuditInfoBlock(
            title: '当前摘要',
            message:
                '成功 ${snapshot.metrics.successCount}\n'
                '失败 ${snapshot.metrics.failureCount}\n'
                '平均耗时 ${_formatDuration(snapshot.metrics.averageDurationMs)}',
          ),
          const SizedBox(height: 16),
          Text('筛选', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: RunQualityDashboardPage.allFilterKey,
                label: const Text('全部'),
                selected: selectedFilter == RunQualityStatusFilter.all,
                onSelected: (_) => onChanged(RunQualityStatusFilter.all),
              ),
              ChoiceChip(
                key: RunQualityDashboardPage.successFilterKey,
                label: const Text('成功'),
                selected: selectedFilter == RunQualityStatusFilter.successful,
                onSelected: (_) => onChanged(RunQualityStatusFilter.successful),
              ),
              ChoiceChip(
                key: RunQualityDashboardPage.failedFilterKey,
                label: const Text('失败'),
                selected: selectedFilter == RunQualityStatusFilter.failed,
                onSelected: (_) => onChanged(RunQualityStatusFilter.failed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunQualityHistoryPanel extends StatelessWidget {
  const _RunQualityHistoryPanel({
    required this.snapshot,
    required this.fillAvailable,
  });

  final RunQualityDashboardSnapshot snapshot;
  final bool fillAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: RunQualityDashboardPage.historyKey,
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Run 历史', style: theme.textTheme.titleMedium),
              ),
              Text(
                '${snapshot.visibleRuns.length}/${snapshot.runs.length}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (snapshot.visibleRuns.isEmpty)
            _emptyHistoryState()
          else
            _historyList(),
        ],
      ),
    );
  }

  Widget _emptyHistoryState() {
    const empty = AuditCenteredPanelState(
      title: '暂无运行记录',
      message: '完成一次场景试写后，运行状态与 stage 结果会在这里显示。',
    );
    if (fillAvailable) {
      return const Expanded(child: empty);
    }
    return const SizedBox(height: 220, child: empty);
  }

  Widget _historyList() {
    if (fillAvailable) {
      return Expanded(
        child: ListView.separated(
          itemCount: snapshot.visibleRuns.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _RunHistoryTile(entry: snapshot.visibleRuns[index]),
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < snapshot.visibleRuns.length; index++) ...[
          _RunHistoryTile(entry: snapshot.visibleRuns[index]),
          if (index < snapshot.visibleRuns.length - 1)
            const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RunQualityModelUsagePanel extends StatelessWidget {
  const _RunQualityModelUsagePanel({
    required this.snapshot,
    required this.showExport,
    required this.fillAvailable,
  });

  final RunQualityDashboardSnapshot snapshot;
  final bool showExport;
  final bool fillAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = [
      Text('模型调用', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      if (snapshot.modelUsage.isEmpty)
        const AuditInfoBlock(
          title: '暂无模型统计',
          message: '接入 LLM trace 后，这里会展示调用量、成功率、token 与平均延迟。',
        )
      else
        for (final usage in snapshot.modelUsage) ...[
          _ModelUsageTile(usage: usage),
          const SizedBox(height: 10),
        ],
      if (showExport) ...[
        const SizedBox(height: 12),
        Text('导出预览', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          key: RunQualityDashboardPage.exportPreviewKey,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: appPanelDecoration(
            context,
            color: desktopPalette(context).subtle,
          ),
          child: Text(
            snapshot.exportMarkdown(),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    ];
    return Container(
      key: RunQualityDashboardPage.modelUsageKey,
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: fillAvailable
          ? ListView(children: children)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
    );
  }
}

class _RunHistoryTile extends StatelessWidget {
  const _RunHistoryTile({required this.entry});

  final RunQualityHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final statusColor = entry.isSuccess
        ? palette.success
        : entry.isFailure
        ? palette.danger
        : palette.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_tree_outlined, size: 18, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.sceneLabel,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                entry.statusLabel,
                style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.summary.isEmpty ? '未记录摘要' : entry.summary,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RunBadge(text: _formatDuration(entry.durationMs)),
              _RunBadge(text: entry.model),
              _RunBadge(text: '${entry.stageCount} stages'),
              if (entry.failedStageCount > 0)
                _RunBadge(text: '${entry.failedStageCount} failed'),
              _RunBadge(text: entry.startedLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelUsageTile extends StatelessWidget {
  const _ModelUsageTile({required this.usage});

  final RunQualityModelUsage usage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(usage.model, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '${usage.callCount} calls · 成功率 ${usage.successRateLabel}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${usage.totalTokens} tokens · 平均延迟 ${_formatDuration(usage.averageLatencyMs)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _RunBadge extends StatelessWidget {
  const _RunBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: desktopPalette(context).elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: desktopPalette(context).border),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}

int _average(List<int> values) {
  if (values.isEmpty) {
    return 0;
  }
  return (values.fold<int>(0, (sum, value) => sum + value) / values.length)
      .round();
}

String _formatDuration(int? durationMs) {
  if (durationMs == null || durationMs <= 0) {
    return '暂无';
  }
  if (durationMs < 1000) {
    return '${durationMs}ms';
  }
  final seconds = durationMs / 1000;
  if (seconds < 60) {
    return '${seconds.toStringAsFixed(1)}s';
  }
  final minutes = seconds / 60;
  return '${minutes.toStringAsFixed(1)}m';
}

String _filterLabel(RunQualityStatusFilter filter) {
  return switch (filter) {
    RunQualityStatusFilter.all => '全部',
    RunQualityStatusFilter.successful => '成功',
    RunQualityStatusFilter.failed => '失败',
  };
}
