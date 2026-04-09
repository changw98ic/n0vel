import 'package:get/get.dart';
import '../../../core/database/database.dart';
import '../data/chapter_repository.dart';

class EditorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChapterRepository>(() => ChapterRepository(Get.find<AppDatabase>()));
  }
}
