import 'package:get/get.dart';
import 'usage_stats_logic.dart';

class UsageStatsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UsageStatsLogic>(() => UsageStatsLogic());
  }
}
