import 'package:get/get.dart';
import 'faction_list_logic.dart';

class FactionListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FactionListLogic>(() => FactionListLogic());
  }
}
