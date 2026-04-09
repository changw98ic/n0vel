import 'package:get/get.dart';

import 'dashboard_logic.dart';

/// Dashboard 依赖注入
class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardLogic>(() => DashboardLogic());
  }
}
