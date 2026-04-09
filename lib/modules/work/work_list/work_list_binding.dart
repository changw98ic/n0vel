import 'package:get/get.dart';

import 'work_list_logic.dart';

/// WorkList 依赖注入
class WorkListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WorkListLogic>(() => WorkListLogic());
  }
}
