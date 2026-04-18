import 'package:get/get.dart';
import 'location_form_logic.dart';

class LocationFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LocationFormLogic>(() => LocationFormLogic());
  }
}
