import 'package:get/get.dart';
import '../../../shared/data/base_business/base_controller.dart';
import '../../../features/settings/domain/item.dart';
import '../../../features/settings/data/item_repository.dart';
import 'item_list_state.dart';

class ItemListLogic extends BaseController {
  final ItemListState state = ItemListState();
  late String workId;

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id'] ?? '';
  }

  Future<List<Item>> loadItems() async {
    final repo = Get.find<ItemRepository>();
    var items = await repo.getItemsByWorkId(workId);

    if (state.searchQuery.value.isNotEmpty) {
      items = items.where((i) =>
          i.name.contains(state.searchQuery.value) ||
          (i.description?.contains(state.searchQuery.value) ?? false)).toList();
    }

    if (state.filterType.value != null) {
      items = items.where((i) => i.type == state.filterType.value).toList();
    }

    if (state.filterRarity.value != null) {
      items = items.where((i) => i.rarity == state.filterRarity.value).toList();
    }

    return items;
  }

  void onSearchChanged(String value) {
    state.searchQuery.value = value;
  }

  void onTypeChanged(String? value) {
    state.filterType.value = value;
  }

  void onRarityChanged(String? value) {
    state.filterRarity.value = value;
  }

  void navigateToCreate() {
    Get.toNamed('/work/$workId/items/new');
  }

  void navigateToEdit(Item item) {
    Get.toNamed('/work/$workId/items/${item.id}');
  }
}
