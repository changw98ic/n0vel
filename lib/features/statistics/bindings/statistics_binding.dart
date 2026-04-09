import 'package:get/get.dart';
import '../../../core/database/database.dart';
import '../data/statistics_service.dart';

class StatisticsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StatisticsService>(() => StatisticsService(Get.find<AppDatabase>()));
  }
}
