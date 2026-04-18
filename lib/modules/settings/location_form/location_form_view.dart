import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../features/settings/domain/location.dart';
import '../../../l10n/app_localizations.dart';
import 'location_form_logic.dart';

class LocationFormView extends GetView<LocationFormLogic> {
  const LocationFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.isEditing ? '编辑地点' : s.settings_createLocation,
        ),
        actions: [
          TextButton(
            onPressed: controller.submit,
            child: Text(s.settings_save),
          ),
        ],
      ),
      body: Form(
        key: controller.formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _buildNameField(),
            SizedBox(height: 16.h),
            _buildTypeDropdown(),
            SizedBox(height: 16.h),
            _buildParentDropdown(),
            SizedBox(height: 16.h),
            _buildDescriptionField(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: controller.nameController,
      decoration: const InputDecoration(
        labelText: '地点名称 *',
        hintText: '输入地点名称',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入地点名称';
        }
        return null;
      },
    );
  }

  Widget _buildTypeDropdown() {
    return Obx(() => DropdownButtonFormField<LocationType>(
          value: controller.state.selectedType.value,
          decoration: const InputDecoration(
            labelText: '地点类型',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<LocationType>(
              value: null,
              child: Text('未指定'),
            ),
            ...LocationType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                )),
          ],
          onChanged: controller.onTypeChanged,
        ));
  }

  Widget _buildParentDropdown() {
    return Obx(() {
      final locations = controller.state.parentLocations;
      // When editing, exclude self from parent options
      final editableLocations = controller.isEditing
          ? locations
              .where((loc) => loc.id != controller.existingLocation?.id)
              .toList()
          : locations;

      return DropdownButtonFormField<String>(
        value: controller.state.selectedParentId.value,
        decoration: const InputDecoration(
          labelText: '上级地点',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('顶级地点'),
          ),
          ...editableLocations.map((loc) => DropdownMenuItem(
                value: loc.id,
                child: Text(loc.name),
              )),
        ],
        onChanged: controller.onParentChanged,
      );
    });
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: controller.descriptionController,
      decoration: const InputDecoration(
        labelText: '描述',
        hintText: '输入地点描述（可选）',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 5,
      maxLength: 500,
    );
  }
}
