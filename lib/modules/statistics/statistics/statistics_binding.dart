import 'package:get/get.dart';

import 'statistics_logic.dart';

/// Statistics 依赖注入
class StatisticsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StatisticsLogic>(() => StatisticsLogic());
  }
}
