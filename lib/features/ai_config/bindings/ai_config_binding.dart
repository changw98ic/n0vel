import 'package:get/get.dart';
import '../data/ai_config_repository.dart';

class AIConfigBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AIConfigRepository>(() => AIConfigRepository());
  }
}
