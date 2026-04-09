import 'package:get/get.dart';

import 'inspiration_logic.dart';

/// Inspiration 依赖注入
class InspirationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InspirationLogic>(() => InspirationLogic());
  }
}
