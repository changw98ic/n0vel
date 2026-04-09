import 'package:get/get.dart';
import '../../../core/database/database.dart';
import '../data/reading_service.dart';

class ReadingModeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReadingService>(() => ReadingService(Get.find<AppDatabase>()));
  }
}
