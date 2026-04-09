import 'package:get/get.dart';
import 'ai_config_logic.dart';

class AIConfigBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AIConfigLogic>(() => AIConfigLogic());
  }
}
