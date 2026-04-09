import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../features/settings/domain/character.dart';
import '../../../l10n/app_localizations.dart';
import 'character_form_logic.dart';

class CharacterFormView extends GetView<CharacterFormLogic> {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? s.settings_editCharacter : s.settings_newCharacter),
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
            buildBasicInfoSection(context),
            SizedBox(height: 24.h),
            buildTierSection(context),
            SizedBox(height: 24.h),
            buildDetailSection(context),
          ],
        ),
      ),
    );
  }

  Widget buildBasicInfoSection(BuildContext context) {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.settings_basicInfo, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 16.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: controller.pickAvatar,
              child: Obx(() => Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: controller.state.avatarPath.value != null
                        ? NetworkImage(controller.state.avatarPath.value!)
                        : null,
                    child: controller.state.avatarPath.value == null
                        ? Icon(Icons.person, size: 40.sp)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 16.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                children: [
                  TextFormField(
                    controller: controller.nameController,
                    decoration: InputDecoration(
                      labelText: '${s.settings_characterName} *',
                      hintText: s.settings_enterCharacterName,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return s.settings_pleaseEnterCharacterName;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: controller.aliasesController,
                    decoration: InputDecoration(
                      labelText: s.settings_aliases,
                      hintText: s.settings_aliasesHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildTierSection(BuildContext context) {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.settings_characterTier, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 8.h),
        Text(
          s.settings_tierDescription,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        SizedBox(height: 12.h),
        Obx(() => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CharacterTier.values.map((tier) {
            final isSelected = controller.state.selectedTier.value == tier;
            return ChoiceChip(
              label: Text(tier.label),
              selected: isSelected,
              onSelected: (_) => controller.onTierChanged(tier),
              selectedColor: controller.getTierColor(tier).withValues(alpha: 0.2),
              avatar: isSelected ? Icon(controller.getTierIcon(tier), size: 16.sp) : null,
            );
          }).toList(),
        )),
      ],
    );
  }

  Widget buildDetailSection(BuildContext context) {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.settings_detailInfo, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: Obx(() => DropdownButtonFormField<String>(
                initialValue: controller.state.selectedGender.value,
                decoration: InputDecoration(
                  labelText: s.settings_gender,
                  border: const OutlineInputBorder(),
                ),
                items: ['男', '女', '其他', '未知'].map((g) {
                  return DropdownMenuItem(value: g, child: Text(g));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.onGenderChanged(value);
                  }
                },
              )),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: TextFormField(
                controller: controller.ageController,
                decoration: InputDecoration(
                  labelText: s.settings_age,
                  hintText: s.settings_ageHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        TextFormField(
          controller: controller.identityController,
          decoration: InputDecoration(
            labelText: s.settings_identity,
            hintText: s.settings_identityHint,
            border: const OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 16.h),
        TextFormField(
          controller: controller.bioController,
          decoration: InputDecoration(
            labelText: s.settings_characterBio,
            hintText: s.settings_characterBioHint,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 5,
          maxLength: 500,
        ),
        Obx(() {
          if (controller.state.selectedTier.value.requiresProfile) {
            return Column(
              children: [
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          s.settings_profileRequired,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }
}
