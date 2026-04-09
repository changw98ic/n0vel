import 'package:get/get.dart';
import '../../../core/database/database.dart';
import '../../../core/services/ai/ai_service.dart';
import '../data/pov_repository.dart';
import '../data/pov_generation_service.dart';

class POVGenerationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<POVRepository>(() => POVRepository(Get.find<AppDatabase>()));
    Get.lazyPut<POVGenerationService>(() => POVGenerationService(Get.find<AIService>()));
  }
}
