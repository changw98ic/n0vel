import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/review/domain/review_report.dart';
import '../../../features/review/domain/review_result.dart';
import 'review_center_leaf_widgets.dart';
import 'review_center_logic.dart';
import 'review_center_sections.dart';

class ReviewCenterOverviewTab extends StatelessWidget {
  final ReviewCenterLogic controller;

  const ReviewCenterOverviewTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
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
          ReviewCenterOverviewSummaryCard(
            averageScore: (stats?.avgScore ?? 0).round(),
            pendingIssues: stats?.pendingIssues ?? 0,
            passedChapters: reviewResults
                .where((result) => result.status == ReviewStatus.passed)
                .length,
            totalChapters: reviewResults.length,
          ),
          SizedBox(height: 16.h),
          ReviewCenterResultsSection(results: reviewResults),
        ],
      ),
    );
  }
}

class ReviewCenterIssueListTab extends StatefulWidget {
  final ReviewCenterLogic controller;

  const ReviewCenterIssueListTab({super.key, required this.controller});

  @override
  State<ReviewCenterIssueListTab> createState() =>
      _ReviewCenterIssueListTabState();
}

class _ReviewCenterIssueListTabState extends State<ReviewCenterIssueListTab> {
  String? _selectedDimension;
  String? _selectedSeverity;
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
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
        ReviewIssueFilters(
          selectedDimension: _selectedDimension,
          selectedSeverity: _selectedSeverity,
          selectedStatus: _selectedStatus,
          onDimensionChanged: (value) =>
              setState(() => _selectedDimension = value),
          onSeverityChanged: (value) =>
              setState(() => _selectedSeverity = value),
          onStatusChanged: (value) => setState(() => _selectedStatus = value),
        ),
        Expanded(
          child: ReviewCenterIssueListBody(
            issues: issues,
            onIgnore: (issue) => widget.controller.ignoreIssue(issue.id),
          ),
        ),
      ],
    );
  }
}

class ReviewIssueFilters extends StatelessWidget {
  final String? selectedDimension;
  final String? selectedSeverity;
  final String? selectedStatus;
  final ValueChanged<String?> onDimensionChanged;
  final ValueChanged<String?> onSeverityChanged;
  final ValueChanged<String?> onStatusChanged;

  const ReviewIssueFilters({
    super.key,
    required this.selectedDimension,
    required this.selectedSeverity,
    required this.selectedStatus,
    required this.onDimensionChanged,
    required this.onSeverityChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: selectedDimension,
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
              onChanged: onDimensionChanged,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: selectedSeverity,
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
              onChanged: onSeverityChanged,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: selectedStatus,
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
              onChanged: onStatusChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewCenterStatisticsTab extends StatelessWidget {
  final ReviewCenterLogic controller;

  const ReviewCenterStatisticsTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final stats = controller.state.statistics.value;
    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ReviewCenterStatisticsList(
      tiles: [
        ReviewMetricTile(label: '缁旂姾濡幀缁樻殶', value: '${stats.totalChapters}'),
        ReviewMetricTile(label: '瀹告彃顓哥粩鐘哄Ν', value: '${stats.reviewedChapters}'),
        ReviewMetricTile(label: '闁俺绻冪粩鐘哄Ν', value: '${stats.passedChapters}'),
        ReviewMetricTile(label: '闂傤噣顣介幀缁樻殶', value: '${stats.totalIssues}'),
        ReviewMetricTile(label: '瀵板懎顦╅悶鍡್ರಮ６妫?', value: '${stats.pendingIssues}'),
        ReviewMetricTile(
          label: '楠炲啿娼庨崚?',
          value: stats.avgScore.toStringAsFixed(1),
        ),
        ReviewMetricTile(
          label: '闁俺绻冮悳?',
          value: '${(stats.passRate * 100).toStringAsFixed(1)}%',
        ),
      ],
    );
  }
}
