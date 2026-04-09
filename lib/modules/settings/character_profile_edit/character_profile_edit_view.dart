import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../features/settings/domain/character_profile.dart';
import 'character_profile_edit_logic.dart';

class CharacterProfileEditView extends GetView<CharacterProfileEditLogic> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑深度档案'),
        actions: [
          TextButton(
            onPressed: controller.saveProfile,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: controller.formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            buildMbtiSection(context),
            SizedBox(height: 24.h),
            buildPersonalitySection(context),
            SizedBox(height: 24.h),
            buildMoralSection(context),
          ],
        ),
      ),
    );
  }

  Widget buildMbtiSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MBTI 类型',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 12.h),
        Obx(() => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MBTI.values.map((mbti) {
            final isSelected = controller.state.selectedMbti.value == mbti;
            return ChoiceChip(
              label: Text(mbti.name.toUpperCase()),
              selected: isSelected,
              onSelected: (_) => controller.onMbtiChanged(mbti),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        )),
      ],
    );
  }

  Widget buildPersonalitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '性格特质',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: controller.coreValuesController,
          decoration: const InputDecoration(
            labelText: '核心价值观',
            hintText: '例如：正义、忠诚、自由...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        SizedBox(height: 16.h),
        TextFormField(
          controller: controller.fearsController,
          decoration: const InputDecoration(
            labelText: '恐惧',
            hintText: '角色最害怕的是什么？',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        SizedBox(height: 16.h),
        TextFormField(
          controller: controller.desiresController,
          decoration: const InputDecoration(
            labelText: '渴望',
            hintText: '角色最渴望的是什么？',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget buildMoralSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '道德基准',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: controller.moralBaselineController,
          decoration: const InputDecoration(
            hintText: '描述角色的道德底线和行为准则',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
      ],
    );
  }
}
