import 'package:get/get.dart';
import '../../../features/settings/domain/character_profile.dart';

class CharacterProfileEditState {
  final selectedMbti = Rx<MBTI?>(null);
  final existingProfile = Rx<CharacterProfile?>(null);
}
