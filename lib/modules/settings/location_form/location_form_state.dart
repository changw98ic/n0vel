import 'package:get/get.dart';
import '../../../features/settings/domain/location.dart';

class LocationFormState {
  final selectedType = Rx<LocationType?>(null);
  final parentLocations = <Location>[].obs;
  final selectedParentId = Rx<String?>(null);
  final isExistingLocation = false.obs;
}
