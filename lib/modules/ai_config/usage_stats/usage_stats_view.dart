import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';
import '../../../../../shared/data/base_business/base_page.dart';
import 'usage_stats_logic.dart';
import '../../../../../features/ai_config/domain/model_config.dart';

class UsageStatsView extends GetView<UsageStatsLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return _UsageStatsPageContent(s: s);
  }
}

class _UsageStatsPageContent extends StatefulWidget {
  final S s;

  const _UsageStatsPageContent({required this.s});

  @override
  State<_UsageStatsPageContent> createState() => _UsageStatsPageContentState();
}

class _UsageStatsPageContentState extends State<_UsageStatsPageContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UsageStatsLogic controller = Get.find<UsageStatsLogic>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    controller.tabController = _tabController;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.s.usageStats_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
            tooltip: widget.s.usageStats_selectDateRange,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: widget.s.usageStats_tab_overview),
            Tab(text: widget.s.usageStats_tab_byModel),
            Tab(text: widget.s.usageStats_tab_byFunction),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _ByModelTab(),
          _ByFunctionTab(),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: controller.state.selectedRange.value ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );

    if (range != null) {
      controller.selectDateRange(
        DateTimeRange(start: range.start, end: range.end),
      );
    }
  }
}

class _OverviewTab extends GetView<UsageStatsLogic> {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Obx(() {
      if (controller.state.overviewError.value != null) {
        return Center(child: Text('${s.aiConfig_loadFailed}: ${controller.state.overviewError.value}'));
      }
      if (controller.state.overviewRecords.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final records = controller.state.overviewRecords;
      final totalRequests = records.length;
      final totalTokens = records.fold<int>(0, (sum, r) => r.totalTokens);
      final successCount = records.where((r) => r.status == 'success').length;
      final errorCount = records.where((r) => r.status == 'error').length;
      final cachedCount = records.where((r) => r.fromCache).length;
      final avgResponseTime = records.isNotEmpty
          ? records.fold<int>(0, (sum, r) => sum + r.responseTimeMs) ~/
                records.length
          : 0;

      return SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 概览卡片
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: s.usageStats_totalRequests,
                    value: totalRequests.toString(),
                    icon: Icons.api,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _StatCard(
                    title: s.usageStats_totalTokens,
                    value: controller.formatNumber(totalTokens),
                    icon: Icons.data_object,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: s.usageStats_successRate,
                    value: totalRequests > 0
                        ? '${(successCount / totalRequests * 100).toStringAsFixed(1)}%'
                        : '0%',
                    icon: Icons.check_circle,
                    color: Colors.teal,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _StatCard(
                    title: s.usageStats_avgResponse,
                    value: '${avgResponseTime}ms',
                    icon: Icons.timer,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: s.usageStats_cachedHits,
                    value: cachedCount.toString(),
                    icon: Icons.cached,
                    color: Colors.purple,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _StatCard(
                    title: s.usageStats_errorCount,
                    value: errorCount.toString(),
                    icon: Icons.error,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // 状态分布
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.usageStats_statusDistribution, style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: 16.h),
                    if (totalRequests > 0) ...[
                      _StatusBar(
                        success: successCount,
                        error: errorCount,
                        cached: cachedCount,
                      ),
                      SizedBox(height: 12.h),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatusLegend(
                          label: '成功',
                          count: successCount,
                          color: Colors.green,
                        ),
                        _StatusLegend(
                          label: '错误',
                          count: errorCount,
                          color: Colors.red,
                        ),
                        _StatusLegend(
                          label: '缓存',
                          count: cachedCount,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // 最近请求
            Text(s.usageStats_recentRequests, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8.h),
            ...records.take(10).map((record) => _RecentRequestCard(record: record)),
          ],
        ),
      );
    });
  }
}

class _ByModelTab extends GetView<UsageStatsLogic> {
  const _ByModelTab();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Obx(() {
      if (controller.state.byModelError.value != null) {
        return Center(child: Text('${s.aiConfig_loadFailed}: ${controller.state.byModelError.value}'));
      }
      if (controller.state.byModelSummaries.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final summaries = controller.state.byModelSummaries;
      final grouped = <String, List<dynamic>>{};
      for (final summary in summaries) {
        grouped.putIfAbsent(summary.modelId, () => []).add(summary);
      }

      if (grouped.isEmpty) {
        return Center(child: Text(s.usageStats_noData));
      }

      return ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.elementAt(index);
          final modelId = entry.key;
          final modelSummaries = entry.value;

          final totalRequests = modelSummaries.fold<int>(
            0,
            (sum, s) => sum + (s.requestCount as int),
          );
          final totalTokens = modelSummaries.fold<int>(
            0,
            (sum, s) => sum + (s.totalTokens as int),
          );
          final avgResponseTime = totalRequests > 0
              ? modelSummaries.fold<int>(
                      0,
                      (sum, s) => sum + (s.avgResponseTimeMs as int),
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
                            child: _MiniStat(
                              label: '请求数',
                              value: totalRequests.toString(),
                            ),
                          ),
                          Expanded(
                            child: _MiniStat(
                              label: 'Token',
                              value: controller.formatNumber(totalTokens),
                            ),
                          ),
                          Expanded(
                            child: _MiniStat(
                              label: '平均响应',
                              value: '${avgResponseTime}ms',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Text(s.usageStats_dailyDetails, style: Theme.of(context).textTheme.titleSmall),
                      SizedBox(height: 8.h),
                      ...modelSummaries.take(7).map(
                        (s) => Padding(
                          padding: EdgeInsets.only(bottom: 4.h),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80.w,
                                child: Text(
                                  controller.formatDate(s.date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: (s.requestCount as int) > 0
                                      ? (s.successCount as int) / (s.requestCount as int)
                                      : 0,
                                  backgroundColor: Colors.grey.withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation(
                                    (s.errorCount as int) > 0 ? Colors.orange : Colors.green,
                                  ),
                                  minHeight: 6.h,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                '${s.requestCount} / ${controller.formatNumber(s.totalTokens as int)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

class _ByFunctionTab extends GetView<UsageStatsLogic> {
  const _ByFunctionTab();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Obx(() {
      if (controller.state.byFunctionError.value != null) {
        return Center(child: Text('${s.aiConfig_loadFailed}: ${controller.state.byFunctionError.value}'));
      }
      if (controller.state.byFunctionRecords.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final records = controller.state.byFunctionRecords;
      final grouped = <String, List<dynamic>>{};
      for (final record in records) {
        grouped.putIfAbsent(record.functionType, () => []).add(record);
      }

      if (grouped.isEmpty) {
        return Center(child: Text(s.usageStats_noData));
      }

      final sorted = grouped.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      return ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final entry = sorted[index];
          final functionKey = entry.key;
          final funcRecords = entry.value;

          final totalRequests = funcRecords.length;
          final totalTokens = funcRecords.fold<int>(
            0,
            (sum, r) => sum + (r.totalTokens as int),
          );
          final successCount = funcRecords.where((r) => r.status == 'success').length;

          final func = AIFunction.fromKey(functionKey);
          final icon = func?.icon ?? Icons.article;
          final label = func?.label ?? functionKey;

          return Card(
            margin: EdgeInsets.only(bottom: 8.h),
            child: ListTile(
              leading: Icon(icon),
              title: Text(label),
              subtitle: Text(
                '成功率: ${totalRequests > 0 ? (successCount / totalRequests * 100).toStringAsFixed(1) : 0}%',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$totalRequests ${s.usageStats_requestCount}'),
                  Text(
                    controller.formatNumber(totalTokens),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final int success;
  final int error;
  final int cached;

  const _StatusBar({
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

class _StatusLegend extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusLegend({
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

class _RecentRequestCard extends StatelessWidget {
  final dynamic record;

  const _RecentRequestCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = switch (record.status) {
      'success' => Colors.green,
      'error' => Colors.red,
      'cached' => Colors.purple,
      _ => Colors.grey,
    };

    return Card(
      margin: EdgeInsets.only(bottom: 4.h),
      child: ListTile(
        leading: Icon(
          record.fromCache ? Icons.cached : Icons.api,
          color: color,
          size: 20.sp,
        ),
        title: Text(record.modelId),
        subtitle: Text(
          '${record.functionType} · ${Get.find<UsageStatsLogic>().formatDateTime(record.createdAt)}',
        ),
        trailing: Text(
          '${record.inputTokens}/${record.outputTokens}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
