import 'package:get/get.dart';
import '../../../features/settings/domain/character.dart';

class CharacterFormState {
  final selectedTier = CharacterTier.supporting.obs;
  final avatarPath = Rx<String?>(null);
  final selectedGender = '男'.obs;
  final isExistingCharacter = false.obs;
}
