import 'package:get/get.dart';
import '../../../features/settings/domain/character.dart';

class CharacterListState {
  final selectedTier = Rx<CharacterTier?>(null);
  final showArchived = false.obs;
  final searchQuery = ''.obs;
  final characters = <Character>[].obs;
  final isLoading = true.obs;
  final loadError = Rx<Object?>(null);
}
