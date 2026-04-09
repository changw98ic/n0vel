import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/statistics/data/statistics_service.dart';
import '../../../features/statistics/domain/statistics_models.dart';
import '../../../shared/data/base_business/base_controller.dart';
import 'statistics_state.dart';

/// Statistics 业务逻辑
class StatisticsLogic extends BaseController with GetTickerProviderStateMixin {
  final StatisticsState state = StatisticsState();
  late TabController tabController;

  final StatisticsService _service = Get.find<StatisticsService>();

  late final String workId;

  StatisticsLogic();

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id'] ?? '';
    tabController = TabController(length: 4, vsync: this);
    state.tabController.value = tabController;
    loadStatistics();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  Future<void> loadStatistics() async {
    state.isLoading.value = true;
    try {
      final stats = await _service.getWorkStatistics(workId);
      state.statistics.value = stats;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      state.isLoading.value = false;
    }
  }

  void setSelectedPeriod(TrendPeriod period) {
    state.selectedPeriod.value = period;
  }

  Future<String> exportReportJson() async {
    return await _service.exportWorkStatisticsToJson(workId);
  }

  Future<String> exportReportCsv() async {
    return await _service.exportWorkStatisticsToCsv(workId);
  }
}
