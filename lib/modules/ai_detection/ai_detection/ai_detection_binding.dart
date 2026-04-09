import 'package:get/get.dart';
import 'ai_detection_logic.dart';

class AIDetectionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AIDetectionLogic>(() => AIDetectionLogic());
  }
}
