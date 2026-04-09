import 'package:get/get.dart';

import 'review_center_logic.dart';

/// ReviewCenter 依赖注入
class ReviewCenterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReviewCenterLogic>(() => ReviewCenterLogic());
  }
}
