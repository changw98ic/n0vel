import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UsageStatsStatCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const UsageStatsStatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class UsageStatsStatCardRow extends StatelessWidget {
  final UsageStatsStatCardData left;
  final UsageStatsStatCardData right;

  const UsageStatsStatCardRow({
    super.key,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: UsageStatsStatCard(
            title: left.title,
            value: left.value,
            icon: left.icon,
            color: left.color,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: UsageStatsStatCard(
            title: right.title,
            value: right.value,
            icon: right.icon,
            color: right.color,
          ),
        ),
      ],
    );
  }
}

class UsageStatsStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const UsageStatsStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class UsageStatsSectionTitle extends StatelessWidget {
  final String title;

  const UsageStatsSectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class UsageStatsModelDailySummaryRow extends StatelessWidget {
  final dynamic summary;
  final String Function(DateTime) formatDate;
  final String Function(int) formatNumber;

  const UsageStatsModelDailySummaryRow({
    super.key,
    required this.summary,
    required this.formatDate,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              formatDate(summary.date),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (summary.requestCount as int) > 0
                  ? (summary.successCount as int) / (summary.requestCount as int)
                  : 0,
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                (summary.errorCount as int) > 0 ? Colors.orange : Colors.green,
              ),
              minHeight: 6.h,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '${summary.requestCount} / ${formatNumber(summary.totalTokens as int)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

Color usageStatsStatusColor(String status) {
  return switch (status) {
    'success' => Colors.green,
    'error' => Colors.red,
    'cached' => Colors.purple,
    _ => Colors.grey,
  };
}

IconData usageStatsRecordIcon(bool fromCache) {
  return fromCache ? Icons.cached : Icons.api;
}
