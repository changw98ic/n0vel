import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../../../shared/data/base_business/base_page.dart';
import 'usage_stats_logic.dart';
import 'usage_stats_sections.dart';

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
        return Center(
          child: Text(
            '${s.aiConfig_loadFailed}: ${controller.state.overviewError.value}',
          ),
        );
      }
      if (controller.state.overviewRecords.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final records = controller.state.overviewRecords;
      final totalRequests = records.length;
      final totalTokens = records.fold<int>(0, (sum, record) => record.totalTokens);
      final successCount =
          records.where((record) => record.status == 'success').length;
      final errorCount =
          records.where((record) => record.status == 'error').length;
      final cachedCount = records.where((record) => record.fromCache).length;
      final avgResponseTime = records.isNotEmpty
          ? records.fold<int>(0, (sum, record) => sum + record.responseTimeMs) ~/
              records.length
          : 0;

      return UsageStatsOverviewSection(
        s: s,
        records: records,
        totalRequests: totalRequests,
        totalTokens: totalTokens,
        successCount: successCount,
        errorCount: errorCount,
        cachedCount: cachedCount,
        avgResponseTime: avgResponseTime,
        formatNumber: controller.formatNumber,
        formatDateTime: controller.formatDateTime,
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
        return Center(
          child: Text(
            '${s.aiConfig_loadFailed}: ${controller.state.byModelError.value}',
          ),
        );
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
        padding: const EdgeInsets.all(16),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.elementAt(index);
          return UsageStatsModelSummaryCard(
            modelId: entry.key,
            modelSummaries: entry.value,
            s: s,
            formatNumber: controller.formatNumber,
            formatDate: controller.formatDate,
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
        return Center(
          child: Text(
            '${s.aiConfig_loadFailed}: ${controller.state.byFunctionError.value}',
          ),
        );
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
        padding: const EdgeInsets.all(16),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final entry = sorted[index];
          return UsageStatsFunctionSummaryCard(
            s: s,
            functionKey: entry.key,
            records: entry.value,
            formatNumber: controller.formatNumber,
          );
        },
      );
    });
  }
}
