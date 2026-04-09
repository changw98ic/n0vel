import 'package:get/get.dart';
import '../../../core/database/database.dart';
import '../data/timeline_repository.dart';

class TimelineBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TimelineRepository>(() => TimelineRepository(Get.find<AppDatabase>()));
  }
}
