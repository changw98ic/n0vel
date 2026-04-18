import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/review/domain/review_report.dart';
import '../../../features/review/domain/review_result.dart';
import 'review_center_dialogs.dart';

class ReviewResultCard extends StatelessWidget {
  final ReviewResult result;

  const ReviewResultCard({super.key, required this.result});

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
          '闂傤噣顣?${result.issueCount} 娑擃亷绱濇稉銉╁櫢 ${result.criticalCount} 娑?',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(result.status.label, style: TextStyle(color: statusColor)),
            if (result.score != null) Text(result.score!.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }
}

class ReviewIssueCard extends StatelessWidget {
  final ReviewIssue issue;
  final VoidCallback? onIgnore;

  const ReviewIssueCard({
    super.key,
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
                ReviewSeverityBadge(
                  label: issue.severity.label,
                  color: severityColor,
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
              Text('瀵ら缚顔呴敍?{issue.suggestion!}', style: theme.textTheme.bodySmall),
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
                  onPressed: () => ReviewIssueDetailDialog.show(context, issue),
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

class ReviewSeverityBadge extends StatelessWidget {
  final String label;
  final Color color;

  const ReviewSeverityBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.sp, color: color),
      ),
    );
  }
}

class ReviewScoreCircle extends StatelessWidget {
  final int score;
  final String label;

  const ReviewScoreCircle({
    super.key,
    required this.score,
    required this.label,
  });

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

class ReviewStatBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const ReviewStatBadge({
    super.key,
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

class ReviewMetricTile extends StatelessWidget {
  final String label;
  final String value;

  const ReviewMetricTile({
    super.key,
    required this.label,
    required this.value,
  });

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
