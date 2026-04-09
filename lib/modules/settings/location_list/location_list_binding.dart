import 'package:get/get.dart';
import 'location_list_logic.dart';

class LocationListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LocationListLogic>(() => LocationListLogic());
  }
}
