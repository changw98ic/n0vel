import 'package:get/get.dart';
import '../../../core/database/database.dart';
import '../data/character_repository.dart';
import '../data/relationship_repository.dart';
import '../data/faction_repository.dart';
import '../data/item_repository.dart';
import '../data/location_repository.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CharacterRepository>(() => CharacterRepository(Get.find<AppDatabase>()));
    Get.lazyPut<RelationshipRepository>(() => RelationshipRepository(Get.find<AppDatabase>()));
    Get.lazyPut<FactionRepository>(() => FactionRepository(Get.find<AppDatabase>()));
    Get.lazyPut<ItemRepository>(() => ItemRepository(Get.find<AppDatabase>()));
    Get.lazyPut<LocationRepository>(() => LocationRepository(Get.find<AppDatabase>()));
  }
}
