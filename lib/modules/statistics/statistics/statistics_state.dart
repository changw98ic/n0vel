import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/statistics/domain/statistics_models.dart';

/// Statistics 页面响应式状态
class StatisticsState {
  final tabController = Rx<TabController?>(null);
  final selectedPeriod = TrendPeriod.daily.obs;
  final statistics = Rx<WorkStatistics?>(null);
  final isLoading = true.obs;
}
