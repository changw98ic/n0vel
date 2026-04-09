import 'package:get/get.dart';

import 'pov_generation_logic.dart';

/// POVGeneration 依赖注入
class POVGenerationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<POVGenerationLogic>(() => POVGenerationLogic());
  }
}
