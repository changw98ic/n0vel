import 'package:get/get.dart';

import 'reader_logic.dart';

/// Reader 依赖注入
class ReaderBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReaderLogic>(() => ReaderLogic());
  }
}
