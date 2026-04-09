import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../shared/data/base_business/base_controller.dart';
import 'usage_stats_state.dart';
import '../../../../../core/services/ai/ai_service.dart';

class UsageStatsLogic extends BaseController {
  final UsageStatsState state = UsageStatsState();
  late final TabController tabController;

  @override
  void onInit() {
    super.onInit();
    state.workId.value = Get.parameters['id'] ?? '';
    // TabController will be created in the view with TickerProvider
    loadOverviewData();
    loadByModelData();
    loadByFunctionData();
  }

  Future<void> loadOverviewData() async {
    try {
      final aiService = Get.find<AIService>();
      final records = await aiService.getAIUsageStatistics(
        workId: state.workId.isEmpty ? null : state.workId.value,
        startDate: state.selectedRange.value?.start,
        endDate: state.selectedRange.value?.end,
        limit: 500,
      );
      state.overviewRecords.value = records;
      state.overviewError.value = null;
    } catch (e) {
      state.overviewError.value = e;
    }
  }

  Future<void> loadByModelData() async {
    try {
      final aiService = Get.find<AIService>();
      final summaries = await aiService.getAIUsageSummaries(
        workId: state.workId.isEmpty ? null : state.workId.value,
        startDate: state.selectedRange.value?.start,
        endDate: state.selectedRange.value?.end,
      );
      state.byModelSummaries.value = summaries;
      state.byModelError.value = null;
    } catch (e) {
      state.byModelError.value = e;
    }
  }

  Future<void> loadByFunctionData() async {
    try {
      final aiService = Get.find<AIService>();
      final records = await aiService.getAIUsageStatistics(
        workId: state.workId.isEmpty ? null : state.workId.value,
        startDate: state.selectedRange.value?.start,
        endDate: state.selectedRange.value?.end,
        limit: 500,
      );
      state.byFunctionRecords.value = records;
      state.byFunctionError.value = null;
    } catch (e) {
      state.byFunctionError.value = e;
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadOverviewData(),
      loadByModelData(),
      loadByFunctionData(),
    ]);
  }

  void selectDateRange(DateTimeRange range) {
    state.selectedRange.value = range;
    refreshAll();
  }

  String formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String formatDateTime(DateTime date) {
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
