import 'package:get/get.dart';
import '../../../core/database/database.dart';
import '../../editor/data/chapter_repository.dart';
import '../data/work_repository.dart';
import '../data/volume_repository.dart';

class WorkBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WorkRepository>(() => WorkRepository(Get.find<AppDatabase>()));
    Get.lazyPut<VolumeRepository>(() => VolumeRepository(Get.find<AppDatabase>()));
    Get.lazyPut<ChapterRepository>(() => ChapterRepository(Get.find<AppDatabase>()));
  }
}
