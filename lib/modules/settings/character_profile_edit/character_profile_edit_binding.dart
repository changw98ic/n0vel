import 'package:get/get.dart';
import 'character_profile_edit_logic.dart';

class CharacterProfileEditBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CharacterProfileEditLogic>(() => CharacterProfileEditLogic());
  }
}
