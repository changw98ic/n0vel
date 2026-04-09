import 'package:get/get.dart';
import '../../../shared/data/base_business/base_controller.dart';
import '../../../features/settings/domain/faction.dart';
import '../../../features/settings/data/faction_repository.dart';
import 'faction_list_state.dart';

class FactionListLogic extends BaseController {
  final FactionListState state = FactionListState();
  late String workId;

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id'] ?? '';
  }

  Future<List<Faction>> loadFactions() async {
    final repo = Get.find<FactionRepository>();
    var factions = await repo.getFactionsByWorkId(workId);

    if (state.filterType.value != null) {
      factions = factions.where((f) => f.type == state.filterType.value).toList();
    }

    return factions;
  }

  void onFilterChanged(String? value) {
    state.filterType.value = value == 'all' ? null : value;
  }

  void navigateToCreate() {
    Get.toNamed('/work/$workId/factions/new');
  }

  void navigateToEdit(Faction faction) {
    Get.toNamed('/work/$workId/factions/${faction.id}');
  }
}
