import 'package:get/get.dart';
import 'item_list_logic.dart';

class ItemListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ItemListLogic>(() => ItemListLogic());
  }
}
