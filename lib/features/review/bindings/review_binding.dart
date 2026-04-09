import 'package:get/get.dart';
import '../../../core/database/database.dart';
import '../../../core/services/ai/ai_service.dart';
import '../data/review_repository.dart';
import '../data/review_service.dart';
import '../data/review_workflow_runner.dart';

class ReviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReviewRepository>(() => ReviewRepository(Get.find<AppDatabase>()));
    Get.lazyPut<ReviewWorkflowRunner>(() => ReviewWorkflowRunner(
          reviewRepository: Get.find<ReviewRepository>(),
          workflowRepository: Get.find(),
          workflowExecutionService: Get.find(),
          chapterRepository: Get.find(),
        ));
    Get.lazyPut<ReviewService>(() => ReviewService(
          Get.find<AIService>(),
          Get.find<ReviewRepository>(),
        ));
  }
}
