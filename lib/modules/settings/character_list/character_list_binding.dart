import 'package:get/get.dart';
import 'character_list_logic.dart';

class CharacterListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CharacterListLogic>(() => CharacterListLogic());
  }
}
