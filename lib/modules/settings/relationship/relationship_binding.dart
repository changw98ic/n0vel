import 'package:get/get.dart';

import '../../../core/database/database.dart';
import '../../../features/settings/data/relationship_repository.dart';
import 'relationship_logic.dart';

class RelationshipBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RelationshipRepository>(() => RelationshipRepository(Get.find<AppDatabase>()));
    Get.lazyPut<RelationshipLogic>(() => RelationshipLogic());
  }
}
