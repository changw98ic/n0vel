import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../shared/data/base_business/base_controller.dart';
import '../../../features/settings/domain/character.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../l10n/app_localizations.dart';
import 'character_form_state.dart';

class CharacterFormLogic extends BaseController {
  final CharacterFormState state = CharacterFormState();
  final formKey = GlobalKey<FormState>();
  final ImagePicker imagePicker = ImagePicker();
  late TextEditingController nameController;
  late TextEditingController aliasesController;
  late TextEditingController ageController;
  late TextEditingController identityController;
  late TextEditingController bioController;
  late String workId;
  Character? existingCharacter;

  bool get isEditing => existingCharacter != null;

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id'] ?? '';
    final characterId = Get.parameters['characterId'];

    nameController = TextEditingController();
    aliasesController = TextEditingController();
    ageController = TextEditingController();
    identityController = TextEditingController();
    bioController = TextEditingController();

    if (characterId != null && characterId.isNotEmpty) {
      loadExistingCharacter(characterId);
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    aliasesController.dispose();
    ageController.dispose();
    identityController.dispose();
    bioController.dispose();
    super.onClose();
  }

  Future<void> loadExistingCharacter(String characterId) async {
    try {
      final repo = Get.find<CharacterRepository>();
      existingCharacter = await repo.getCharacterById(characterId);
      if (existingCharacter != null) {
        state.isExistingCharacter.value = true;
        nameController.text = existingCharacter!.name;
        aliasesController.text = existingCharacter!.aliases.join(', ');
        ageController.text = existingCharacter!.age ?? '';
        identityController.text = existingCharacter!.identity ?? '';
        bioController.text = existingCharacter!.bio ?? '';
        state.selectedTier.value = existingCharacter!.tier;
        state.avatarPath.value = existingCharacter!.avatarPath;
        state.selectedGender.value = existingCharacter!.gender ?? '男';
      }
    } catch (e) {
      showErrorSnackbar(e.toString());
    }
  }

  void onTierChanged(CharacterTier tier) {
    state.selectedTier.value = tier;
  }

  void onGenderChanged(String gender) {
    state.selectedGender.value = gender;
  }

  Future<void> pickAvatar() async {
    final XFile? image = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: '裁剪头像',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (cropped != null) {
        state.avatarPath.value = cropped.path;
      }
    }
  }

  Future<void> submit() async {
    final s = Get.context != null ? S.of(Get.context!)! : null;
    if (formKey.currentState!.validate()) {
      final aliases = aliasesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final repo = Get.find<CharacterRepository>();

      try {
        if (isEditing) {
          final updatedCharacter = existingCharacter!.copyWith(
            name: nameController.text.trim(),
            aliases: aliases,
            tier: state.selectedTier.value,
            avatarPath: state.avatarPath.value,
            gender: state.selectedGender.value,
            age: ageController.text.trim(),
            identity: identityController.text.trim(),
            bio: bioController.text.trim(),
            updatedAt: DateTime.now(),
          );
          await repo.updateCharacter(updatedCharacter);
        } else {
          final params = CreateCharacterParams(
            workId: workId,
            name: nameController.text.trim(),
            aliases: aliases,
            tier: state.selectedTier.value,
            avatarPath: state.avatarPath.value,
            gender: state.selectedGender.value,
            age: ageController.text.trim(),
            identity: identityController.text.trim(),
            bio: bioController.text.trim(),
          );
          await repo.createCharacter(params);
        }

        Get.back(result: true);
      } catch (e) {
        final message = s?.settings_saveFailed(e.toString()) ?? e.toString();
        showErrorSnackbar(message);
      }
    }
  }

  Color getTierColor(CharacterTier tier) {
    return switch (tier) {
      CharacterTier.protagonist => Colors.amber,
      CharacterTier.majorAntagonist => Colors.red,
      CharacterTier.antagonist => Colors.orange,
      CharacterTier.supporting => Colors.blue,
      CharacterTier.minor => Colors.grey,
    };
  }

  IconData getTierIcon(CharacterTier tier) {
    return switch (tier) {
      CharacterTier.protagonist => Icons.star,
      CharacterTier.majorAntagonist => Icons.dangerous,
      CharacterTier.antagonist => Icons.warning,
      CharacterTier.supporting => Icons.person,
      CharacterTier.minor => Icons.person_outline,
    };
  }
}
