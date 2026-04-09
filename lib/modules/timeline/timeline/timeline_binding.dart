import 'package:get/get.dart';

import 'timeline_logic.dart';

/// Timeline 依赖注入
class TimelineBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TimelineLogic>(() => TimelineLogic());
  }
}
