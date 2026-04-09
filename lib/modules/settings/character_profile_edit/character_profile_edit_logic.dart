import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/data/base_business/base_controller.dart';
import '../../../features/settings/domain/character_profile.dart';
import '../../../features/settings/data/character_repository.dart';
import 'character_profile_edit_state.dart';

class CharacterProfileEditLogic extends BaseController {
  final CharacterProfileEditState state = CharacterProfileEditState();
  final formKey = GlobalKey<FormState>();
  late TextEditingController coreValuesController;
  late TextEditingController fearsController;
  late TextEditingController desiresController;
  late TextEditingController moralBaselineController;
  late String characterId;

  @override
  void onInit() {
    super.onInit();
    characterId = Get.parameters['characterId'] ?? '';
    coreValuesController = TextEditingController();
    fearsController = TextEditingController();
    desiresController = TextEditingController();
    moralBaselineController = TextEditingController();
    loadProfile();
  }

  @override
  void onClose() {
    coreValuesController.dispose();
    fearsController.dispose();
    desiresController.dispose();
    moralBaselineController.dispose();
    super.onClose();
  }

  Future<void> loadProfile() async {
    final repository = Get.find<CharacterRepository>();
    final profile = await repository.getProfile(characterId);
    if (profile != null) {
      state.existingProfile.value = profile;
      state.selectedMbti.value = profile.mbti;
      coreValuesController.text = profile.coreValues ?? '';
      fearsController.text = profile.fears ?? '';
      desiresController.text = profile.desires ?? '';
      moralBaselineController.text = profile.moralBaseline ?? '';
    }
  }

  void onMbtiChanged(MBTI? mbti) {
    state.selectedMbti.value = mbti;
  }

  Future<void> saveProfile() async {
    if (formKey.currentState!.validate()) {
      final repository = Get.find<CharacterRepository>();

      final profile = CharacterProfile(
        id: state.existingProfile.value?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        characterId: characterId,
        mbti: state.selectedMbti.value,
        bigFive: state.existingProfile.value?.bigFive,
        personalityKeywords: state.existingProfile.value?.personalityKeywords ?? const [],
        coreValues: coreValuesController.text.trim().isEmpty ? null : coreValuesController.text.trim(),
        fears: fearsController.text.trim().isEmpty ? null : fearsController.text.trim(),
        desires: desiresController.text.trim().isEmpty ? null : desiresController.text.trim(),
        moralBaseline: moralBaselineController.text.trim().isEmpty ? null : moralBaselineController.text.trim(),
        speechStyle: state.existingProfile.value?.speechStyle,
        behaviorPatterns: state.existingProfile.value?.behaviorPatterns ?? const [],
        createdAt: state.existingProfile.value?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveProfile(profile);
      Get.back(result: true);
    }
  }
}
