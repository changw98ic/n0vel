import 'package:get/get.dart';
import 'work_form_logic.dart';

class WorkFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WorkFormLogic>(() => WorkFormLogic());
  }
}
