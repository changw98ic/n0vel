import 'package:get/get.dart';

import '../../../core/database/database.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../features/settings/data/relationship_repository.dart';
import 'character_detail_logic.dart';

class CharacterDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CharacterRepository>(() => CharacterRepository(Get.find<AppDatabase>()));
    Get.lazyPut<RelationshipRepository>(() => RelationshipRepository(Get.find<AppDatabase>()));
    Get.lazyPut<CharacterDetailLogic>(() => CharacterDetailLogic());
  }
}
