import 'package:get/get.dart';

import 'ai_chat_logic.dart';

class AIChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AIChatLogic>(() => AIChatLogic(), fenix: true);
  }
}
