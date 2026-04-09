import 'package:get/get.dart';

import 'chapter_editor_logic.dart';

/// ChapterEditor 依赖注入
class ChapterEditorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChapterEditorLogic>(() => ChapterEditorLogic());
  }
}
