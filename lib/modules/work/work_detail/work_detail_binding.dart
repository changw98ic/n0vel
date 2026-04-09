import 'package:get/get.dart';
import 'work_detail_logic.dart';

class WorkDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WorkDetailLogic>(() => WorkDetailLogic());
  }
}
