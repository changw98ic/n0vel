import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/review/domain/review_report.dart';
import '../../../features/review/domain/review_result.dart';
import 'review_center_leaf_widgets.dart';

class ReviewCenterOverviewSummaryCard extends StatelessWidget {
  final int averageScore;
  final int pendingIssues;
  final int passedChapters;
  final int totalChapters;

  const ReviewCenterOverviewSummaryCard({
    super.key,
    required this.averageScore,
    required this.pendingIssues,
    required this.passedChapters,
    required this.totalChapters,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ReviewScoreCircle(
              score: averageScore,
              label: s.review_overallScore,
            ),
            ReviewStatBadge(
              count: pendingIssues,
              label: s.review_filter_pending,
              color: theme.colorScheme.error,
            ),
            ReviewStatBadge(
              count: passedChapters,
              label: s.review_passedChapters,
              color: theme.colorScheme.primary,
            ),
            ReviewStatBadge(
              count: totalChapters,
              label: s.review_allChapters,
              color: theme.colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewCenterResultsSection extends StatelessWidget {
  final List<ReviewResult> results;

  const ReviewCenterResultsSection({
    super.key,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.review_passedChapters, style: theme.textTheme.titleMedium),
        SizedBox(height: 8.h),
        ...results.map((result) => ReviewResultCard(result: result)),
      ],
    );
  }
}

class ReviewCenterIssueListBody extends StatelessWidget {
  final List<ReviewIssue> issues;
  final ValueChanged<ReviewIssue> onIgnore;

  const ReviewCenterIssueListBody({
    super.key,
    required this.issues,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    return issues.isEmpty
        ? Center(child: Text('濞屸剝婀侀崠褰掑帳閻ㄥ嫰妫舵０妯糕偓?'))
        : ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: issues.length,
            itemBuilder: (context, index) => ReviewIssueCard(
              issue: issues[index],
              onIgnore: issues[index].status == IssueStatus.pending
                  ? () => onIgnore(issues[index])
                  : null,
            ),
          );
  }
}

class ReviewCenterStatisticsList extends StatelessWidget {
  final List<ReviewMetricTile> tiles;

  const ReviewCenterStatisticsList({
    super.key,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: tiles,
    );
  }
}
