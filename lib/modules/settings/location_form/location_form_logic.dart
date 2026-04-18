import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/settings/data/location_repository.dart';
import '../../../features/settings/domain/location.dart';
import '../../../shared/data/base_business/base_controller.dart';
import 'location_form_state.dart';

class LocationFormLogic extends BaseController {
  final LocationFormState state = LocationFormState();
  final formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController descriptionController;

  late String workId;
  Location? existingLocation;

  bool get isEditing => existingLocation != null;

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['workId'] ?? '';
    final locationId = Get.parameters['locationId'];
    final parentIdParam = Get.parameters['parentId'];

    nameController = TextEditingController();
    descriptionController = TextEditingController();

    if (parentIdParam != null) {
      state.selectedParentId.value = parentIdParam;
    }

    _loadParentLocations();

    if (locationId != null && locationId.isNotEmpty) {
      _loadExistingLocation(locationId);
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  Future<void> _loadParentLocations() async {
    try {
      final repo = Get.find<LocationRepository>();
      final locations = await repo.getLocationsByWorkId(workId);
      state.parentLocations.value = locations;
    } catch (_) {}
  }

  Future<void> _loadExistingLocation(String locationId) async {
    try {
      final repo = Get.find<LocationRepository>();
      existingLocation = await repo.getLocationById(locationId);
      if (existingLocation != null) {
        state.isExistingLocation.value = true;
        nameController.text = existingLocation!.name;
        descriptionController.text = existingLocation!.description ?? '';
        state.selectedParentId.value = existingLocation!.parentId;
        if (existingLocation!.type != null) {
          state.selectedType.value = LocationType.values.firstWhere(
            (t) => t.name == existingLocation!.type,
            orElse: () => LocationType.other,
          );
        }
      }
    } catch (e) {
      showErrorSnackbar(e.toString());
    }
  }

  void onTypeChanged(LocationType? type) {
    state.selectedType.value = type;
  }

  void onParentChanged(String? parentId) {
    state.selectedParentId.value = parentId;
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    final repo = Get.find<LocationRepository>();

    try {
      final typeName = state.selectedType.value?.name;

      if (isEditing) {
        await repo.updateLocation(
          existingLocation!.id,
          name: nameController.text.trim(),
          type: typeName,
          parentId: state.selectedParentId.value,
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
      } else {
        await repo.createLocation(
          workId: workId,
          name: nameController.text.trim(),
          type: typeName,
          parentId: state.selectedParentId.value,
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
      }

      Get.back(result: true);
    } catch (e) {
      showErrorSnackbar('保存失败: $e');
    }
  }
}
