import 'package:get/get.dart';
import 'character_form_logic.dart';

class CharacterFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CharacterFormLogic>(() => CharacterFormLogic());
  }
}
