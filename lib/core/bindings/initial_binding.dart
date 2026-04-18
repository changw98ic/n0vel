import 'package:get/get.dart';

import '../../features/ai_config/data/ai_config_repository.dart';
import '../database/database.dart';
import '../services/ai/ai_service.dart';
import 'initial_binding_registrations.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppDatabase>(() => AppDatabase(), fenix: true);
    Get.lazyPut<AIConfigRepository>(() => AIConfigRepository(), fenix: true);
    Get.lazyPut<AIService>(() => AIService(), fenix: true);

    final db = Get.find<AppDatabase>();
    registerInitialRepositories(db);
    registerInitialServices(db);
  }
}
