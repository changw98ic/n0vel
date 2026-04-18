import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';
import '../../../../../features/ai_config/domain/model_config.dart';
import 'usage_stats_leaf_widgets.dart';

class UsageStatsOverviewSection extends StatelessWidget {
  final S s;
  final List<dynamic> records;
  final int totalRequests;
  final int totalTokens;
  final int successCount;
  final int errorCount;
  final int cachedCount;
  final int avgResponseTime;
  final String Function(int) formatNumber;
  final String Function(DateTime) formatDateTime;

  const UsageStatsOverviewSection({
    super.key,
    required this.s,
    required this.records,
    required this.totalRequests,
    required this.totalTokens,
    required this.successCount,
    required this.errorCount,
    required this.cachedCount,
    required this.avgResponseTime,
    required this.formatNumber,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UsageStatsMetricRows(
            s: s,
            totalRequests: totalRequests,
            totalTokens: totalTokens,
            successCount: successCount,
            cachedCount: cachedCount,
            errorCount: errorCount,
            avgResponseTime: avgResponseTime,
            formatNumber: formatNumber,
          ),
          SizedBox(height: 24.h),
          UsageStatsStatusSection(
            s: s,
            totalRequests: totalRequests,
            successCount: successCount,
            errorCount: errorCount,
            cachedCount: cachedCount,
          ),
          SizedBox(height: 24.h),
          UsageStatsSectionTitle(title: s.usageStats_recentRequests),
          SizedBox(height: 8.h),
          ...records.take(10).map(
                (record) => UsageStatsRecentRequestCard(
                  record: record,
                  formatDateTime: formatDateTime,
                ),
              ),
        ],
      ),
    );
  }
}

class UsageStatsMetricRows extends StatelessWidget {
  final S s;
  final int totalRequests;
  final int totalTokens;
  final int successCount;
  final int cachedCount;
  final int errorCount;
  final int avgResponseTime;
  final String Function(int) formatNumber;

  const UsageStatsMetricRows({
    super.key,
    required this.s,
    required this.totalRequests,
    required this.totalTokens,
    required this.successCount,
    required this.cachedCount,
    required this.errorCount,
    required this.avgResponseTime,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UsageStatsStatCardRow(
          left: UsageStatsStatCardData(
            title: s.usageStats_totalRequests,
            value: totalRequests.toString(),
            icon: Icons.api,
            color: Colors.blue,
          ),
          right: UsageStatsStatCardData(
            title: s.usageStats_totalTokens,
            value: formatNumber(totalTokens),
            icon: Icons.data_object,
            color: Colors.green,
          ),
        ),
        SizedBox(height: 12.h),
        UsageStatsStatCardRow(
          left: UsageStatsStatCardData(
            title: s.usageStats_successRate,
            value: totalRequests > 0
                ? '${(successCount / totalRequests * 100).toStringAsFixed(1)}%'
                : '0%',
            icon: Icons.check_circle,
            color: Colors.teal,
          ),
          right: UsageStatsStatCardData(
            title: s.usageStats_avgResponse,
            value: '${avgResponseTime}ms',
            icon: Icons.timer,
            color: Colors.orange,
          ),
        ),
        SizedBox(height: 12.h),
        UsageStatsStatCardRow(
          left: UsageStatsStatCardData(
            title: s.usageStats_cachedHits,
            value: cachedCount.toString(),
            icon: Icons.cached,
            color: Colors.purple,
          ),
          right: UsageStatsStatCardData(
            title: s.usageStats_errorCount,
            value: errorCount.toString(),
            icon: Icons.error,
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}

class UsageStatsStatusSection extends StatelessWidget {
  final S s;
  final int totalRequests;
  final int successCount;
  final int errorCount;
  final int cachedCount;

  const UsageStatsStatusSection({
    super.key,
    required this.s,
    required this.totalRequests,
    required this.successCount,
    required this.errorCount,
    required this.cachedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.usageStats_statusDistribution,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16.h),
            if (totalRequests > 0) ...[
              UsageStatsStatusBar(
                success: successCount,
                error: errorCount,
                cached: cachedCount,
              ),
              SizedBox(height: 12.h),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                UsageStatsStatusLegend(
                  label: '鎴愬姛',
                  count: successCount,
                  color: Colors.green,
                ),
                UsageStatsStatusLegend(
                  label: '閿欒',
                  count: errorCount,
                  color: Colors.red,
                ),
                UsageStatsStatusLegend(
                  label: '缂撳瓨',
                  count: cachedCount,
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UsageStatsModelSummaryCard extends StatelessWidget {
  final String modelId;
  final List<dynamic> modelSummaries;
  final S s;
  final String Function(int) formatNumber;
  final String Function(DateTime) formatDate;

  const UsageStatsModelSummaryCard({
    super.key,
    required this.modelId,
    required this.modelSummaries,
    required this.s,
    required this.formatNumber,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final totalRequests = modelSummaries.fold<int>(
      0,
      (sum, summary) => sum + (summary.requestCount as int),
    );
    final totalTokens = modelSummaries.fold<int>(
      0,
      (sum, summary) => sum + (summary.totalTokens as int),
    );
    final avgResponseTime = totalRequests > 0
        ? modelSummaries.fold<int>(
                0,
                (sum, summary) => sum + (summary.avgResponseTimeMs as int),
              ) ~/
            modelSummaries.length
        : 0;
    final tier = modelSummaries.first.tier;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text(modelId.substring(0, 1).toUpperCase()),
        ),
        title: Text(modelId),
        subtitle: Text('${s.usageStats_tier}: $tier'),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: UsageStatsMiniStat(
                        label: '璇锋眰鏁?',
                        value: totalRequests.toString(),
                      ),
                    ),
                    Expanded(
                      child: UsageStatsMiniStat(
                        label: 'Token',
                        value: formatNumber(totalTokens),
                      ),
                    ),
                    Expanded(
                      child: UsageStatsMiniStat(
                        label: '骞冲潎鍝嶅簲',
                        value: '${avgResponseTime}ms',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  s.usageStats_dailyDetails,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: 8.h),
                ...modelSummaries.take(7).map(
                      (summary) => UsageStatsModelDailySummaryRow(
                        summary: summary,
                        formatDate: formatDate,
                        formatNumber: formatNumber,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UsageStatsFunctionSummaryCard extends StatelessWidget {
  final S s;
  final String functionKey;
  final List<dynamic> records;
  final String Function(int) formatNumber;

  const UsageStatsFunctionSummaryCard({
    super.key,
    required this.s,
    required this.functionKey,
    required this.records,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    final totalRequests = records.length;
    final totalTokens = records.fold<int>(
      0,
      (sum, record) => sum + (record.totalTokens as int),
    );
    final successCount = records.where((record) => record.status == 'success').length;
    final func = AIFunction.fromKey(functionKey);
    final icon = func?.icon ?? Icons.article;
    final label = func?.label ?? functionKey;

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(
          '鎴愬姛鐜? ${totalRequests > 0 ? (successCount / totalRequests * 100).toStringAsFixed(1) : 0}%',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$totalRequests ${s.usageStats_requestCount}'),
            Text(
              formatNumber(totalTokens),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class UsageStatsStatusBar extends StatelessWidget {
  final int success;
  final int error;
  final int cached;

  const UsageStatsStatusBar({
    super.key,
    required this.success,
    required this.error,
    required this.cached,
  });

  @override
  Widget build(BuildContext context) {
    final total = success + error + cached;
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Row(
        children: [
          if (success > 0)
            Expanded(
              flex: success,
              child: Container(height: 12.h, color: Colors.green),
            ),
          if (error > 0)
            Expanded(
              flex: error,
              child: Container(height: 12.h, color: Colors.red),
            ),
          if (cached > 0)
            Expanded(
              flex: cached,
              child: Container(height: 12.h, color: Colors.purple),
            ),
        ],
      ),
    );
  }
}

class UsageStatsStatusLegend extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const UsageStatsStatusLegend({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 12.h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(width: 4.w),
            Text(label),
          ],
        ),
        SizedBox(height: 4.h),
        Text(count.toString(), style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class UsageStatsRecentRequestCard extends StatelessWidget {
  final dynamic record;
  final String Function(DateTime) formatDateTime;

  const UsageStatsRecentRequestCard({
    super.key,
    required this.record,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final color = usageStatsStatusColor(record.status);

    return Card(
      margin: EdgeInsets.only(bottom: 4.h),
      child: ListTile(
        leading: Icon(
          usageStatsRecordIcon(record.fromCache),
          color: color,
          size: 20.sp,
        ),
        title: Text(record.modelId),
        subtitle: Text(
          '${record.functionType} 路 ${formatDateTime(record.createdAt)}',
        ),
        trailing: Text(
          '${record.inputTokens}/${record.outputTokens}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class UsageStatsMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const UsageStatsMiniStat({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
