import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../features/review/domain/review_report.dart';
import '../../../features/review/domain/review_result.dart';
import '../../../shared/data/base_business/base_page.dart';
import '../view/quick_review_dialog.dart';
import '../view/review_config_dialog.dart';
import '../view/review_progress_dialog.dart';
import 'review_center_logic.dart';

class ReviewCenterView extends GetView<ReviewCenterLogic> with BasePage {
  const ReviewCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AppPageScaffold(
      title: s.review_center_title,
      bodyPadding: EdgeInsets.zero,
      bottom: Obx(
        () => TabBar(
          controller: controller.state.tabController.value,
          tabs: [
            Tab(text: s.review_tab_overview),
            Tab(text: s.review_tab_issues),
            Tab(text: s.review_tab_statistics),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: controller.loadData,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => showDialog(
            context: context,
            builder: (context) => const ReviewConfigDialog(),
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'review_fab',
        onPressed: () => controller.startQuickReview(context),
        icon: const Icon(Icons.play_arrow),
        label: Text(s.review_quickReview),
      ),
      child: Obx(() {
        final tabController = controller.state.tabController.value;
        if (tabController == null) {
          return const SizedBox.shrink();
        }

        if (controller.isLoading.value &&
            controller.state.reviewResults.isEmpty &&
            controller.state.statistics.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return TabBarView(
          controller: tabController,
          children: [
            _OverviewTab(controller: controller),
            _IssueListTab(controller: controller),
            _StatisticsTab(controller: controller),
          ],
        );
      }),
    );
  }
}

extension ReviewCenterLogicMethods on ReviewCenterLogic {
  Future<void> startQuickReview(BuildContext context) async {
    final result = await showDialog<QuickReviewRequest>(
      context: context,
      builder: (context) => QuickReviewDialog(
        workId: workId,
        volumes: state.volumes,
        chapters: state.chapters,
      ),
    );

    if (result != null && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ReviewProgressDialog(
          workId: workId,
          scope: result.scope,
          dimensions: result.dimensions,
          volumeId: result.volumeId,
          chapterId: result.chapterId,
        ),
      );
      await loadData();
    }
  }
}

class _OverviewTab extends StatelessWidget {
  final ReviewCenterLogic controller;

  const _OverviewTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final theme = Theme.of(context);
    final stats = controller.state.statistics.value;
    final reviewResults = controller.state.reviewResults;

    return RefreshIndicator(
      onRefresh: controller.loadData,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          if (controller.hasError)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Text(controller.errorMessage.value),
              ),
            ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ScoreCircle(
                    score: (stats?.avgScore ?? 0).round(),
                    label: s.review_overallScore,
                  ),
                  _StatBadge(
                    count: stats?.pendingIssues ?? 0,
                    label: s.review_filter_pending,
                    color: theme.colorScheme.error,
                  ),
                  _StatBadge(
                    count: reviewResults
                        .where((result) => result.status == ReviewStatus.passed)
                        .length,
                    label: s.review_passedChapters,
                    color: theme.colorScheme.primary,
                  ),
                  _StatBadge(
                    count: reviewResults.length,
                    label: s.review_allChapters,
                    color: theme.colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(s.review_passedChapters, style: theme.textTheme.titleMedium),
          SizedBox(height: 8.h),
          ...reviewResults.map((result) => _ResultCard(result: result)),
        ],
      ),
    );
  }
}

class _IssueListTab extends StatefulWidget {
  final ReviewCenterLogic controller;

  const _IssueListTab({required this.controller});

  @override
  State<_IssueListTab> createState() => _IssueListTabState();
}

class _IssueListTabState extends State<_IssueListTab> {
  String? _selectedDimension;
  String? _selectedSeverity;
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final issues = widget.controller.aggregatedIssues.where((issue) {
      if (_selectedDimension != null &&
          issue.dimension.name != _selectedDimension) {
        return false;
      }
      if (_selectedSeverity != null &&
          issue.severity.name != _selectedSeverity) {
        return false;
      }
      if (_selectedStatus != null && issue.status.name != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedDimension,
                  decoration: InputDecoration(
                    labelText: s.review_filter_dimension,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(s.review_filter_all),
                    ),
                    ...ReviewDimension.values.map(
                      (dimension) => DropdownMenuItem(
                        value: dimension.name,
                        child: Text(dimension.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedDimension = value),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedSeverity,
                  decoration: InputDecoration(
                    labelText: s.review_filter_severity,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(s.review_filter_all),
                    ),
                    DropdownMenuItem(
                      value: IssueSeverity.critical.name,
                      child: Text(s.review_severity_critical),
                    ),
                    DropdownMenuItem(
                      value: IssueSeverity.major.name,
                      child: Text(s.review_severity_major),
                    ),
                    DropdownMenuItem(
                      value: IssueSeverity.minor.name,
                      child: Text(s.review_severity_minor),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedSeverity = value),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: s.review_filter_status,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(s.review_filter_all),
                    ),
                    DropdownMenuItem(
                      value: IssueStatus.pending.name,
                      child: Text(s.review_filter_pending),
                    ),
                    DropdownMenuItem(
                      value: IssueStatus.ignored.name,
                      child: Text(s.review_filter_ignored),
                    ),
                    DropdownMenuItem(
                      value: IssueStatus.fixed.name,
                      child: Text(s.review_filter_fixed),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedStatus = value),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: issues.isEmpty
              ? Center(child: Text('没有匹配的问题。'))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: issues.length,
                  itemBuilder: (context, index) => _IssueCard(
                    issue: issues[index],
                    onIgnore: issues[index].status == IssueStatus.pending
                        ? () => widget.controller.ignoreIssue(issues[index].id)
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatisticsTab extends StatelessWidget {
  final ReviewCenterLogic controller;

  const _StatisticsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final stats = controller.state.statistics.value;
    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        _MetricTile(label: '章节总数', value: '${stats.totalChapters}'),
        _MetricTile(label: '已审章节', value: '${stats.reviewedChapters}'),
        _MetricTile(label: '通过章节', value: '${stats.passedChapters}'),
        _MetricTile(label: '问题总数', value: '${stats.totalIssues}'),
        _MetricTile(label: '待处理问题', value: '${stats.pendingIssues}'),
        _MetricTile(label: '平均分', value: stats.avgScore.toStringAsFixed(1)),
        _MetricTile(
          label: '通过率',
          value: '${(stats.passRate * 100).toStringAsFixed(1)}%',
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ReviewResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (result.status) {
      ReviewStatus.passed => theme.colorScheme.primary,
      ReviewStatus.needsFix => theme.colorScheme.tertiary,
      ReviewStatus.failed => theme.colorScheme.error,
      ReviewStatus.reviewing => theme.colorScheme.secondary,
      ReviewStatus.notReviewed => theme.colorScheme.outline,
    };

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        title: Text(result.chapterTitle),
        subtitle: Text(
          '问题 ${result.issueCount} 个，严重 ${result.criticalCount} 个',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              result.status.label,
              style: TextStyle(color: statusColor),
            ),
            if (result.score != null)
              Text(result.score!.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final ReviewIssue issue;
  final VoidCallback? onIgnore;

  const _IssueCard({
    required this.issue,
    this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final theme = Theme.of(context);
    final severityColor = switch (issue.severity) {
      IssueSeverity.critical => theme.colorScheme.error,
      IssueSeverity.major => theme.colorScheme.tertiary,
      IssueSeverity.minor => theme.colorScheme.secondary,
    };

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    issue.severity.label,
                    style: TextStyle(fontSize: 12.sp, color: severityColor),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  issue.dimension.label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(issue.status.label, style: theme.textTheme.bodySmall),
              ],
            ),
            SizedBox(height: 8.h),
            Text(issue.description),
            if (issue.location != null) ...[
              SizedBox(height: 6.h),
              Text(issue.location!, style: theme.textTheme.bodySmall),
            ],
            if (issue.suggestion != null) ...[
              SizedBox(height: 6.h),
              Text(
                '建议：${issue.suggestion!}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onIgnore != null)
                  TextButton(
                    onPressed: onIgnore,
                    child: Text(s.review_issueCard_ignore),
                  ),
                SizedBox(width: 8.w),
                FilledButton.tonal(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(issue.dimension.label),
                        content: SingleChildScrollView(
                          child: Text([
                            issue.description,
                            if (issue.originalText != null)
                              '\n原文：${issue.originalText!}',
                            if (issue.location != null)
                              '\n位置：${issue.location!}',
                            if (issue.suggestion != null)
                              '\n建议：${issue.suggestion!}',
                          ].join('\n')),
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(s.editor_close),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(s.review_issueCard_view),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  final int score;
  final String label;

  const _ScoreCircle({required this.score, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80.w,
              height: 80.h,
              child: CircularProgressIndicator(
                value: score.clamp(0, 100) / 100,
                strokeWidth: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            Text(
              '$score',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$count',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        SizedBox(height: 4.h),
        Text(label),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
