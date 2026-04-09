import 'package:get/get.dart';
import '../../../shared/data/base_business/base_controller.dart';
import '../../../features/settings/domain/location.dart';
import '../../../features/settings/data/location_repository.dart';
import 'location_list_state.dart';

class LocationListLogic extends BaseController {
  final LocationListState state = LocationListState();
  late String workId;

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id'] ?? '';
  }

  Future<List<LocationNode>> loadLocationTree() async {
    final repo = Get.find<LocationRepository>();
    return repo.getLocationTree(workId);
  }

  Future<List<Location>> loadLocations() async {
    final repo = Get.find<LocationRepository>();
    return repo.getLocationsByWorkId(workId);
  }

  /// 查找重复地点
  Future<List<List<Location>>> loadDuplicateGroups() async {
    final repo = Get.find<LocationRepository>();
    return repo.findDuplicateLocations(workId);
  }

  /// 合并重复地点
  Future<void> mergeDuplicates(
    String keepId,
    List<String> removeIds,
  ) async {
    final repo = Get.find<LocationRepository>();
    await repo.mergeLocations(keepId, removeIds);
  }

  void onViewModeChanged() {
    state.viewMode.value = state.viewMode.value == 'tree' ? 'list' : 'tree';
  }

  void navigateToCreate() {
    Get.toNamed('/work/$workId/locations/new');
  }

  void navigateToCreateChild(String parentId) {
    Get.toNamed('/work/$workId/locations/new?parentId=$parentId');
  }

  void navigateToEdit(Location location) {
    Get.toNamed('/work/$workId/locations/${location.id}');
  }
}
