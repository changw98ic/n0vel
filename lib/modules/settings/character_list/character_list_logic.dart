import 'package:get/get.dart';
import '../../../shared/data/base_business/base_controller.dart';
import '../../../core/utils/debounce.dart';
import '../../../features/settings/domain/character.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../l10n/app_localizations.dart';
import 'character_list_state.dart';

class CharacterListLogic extends BaseController {
  final CharacterListState state = CharacterListState();
  final Debounce searchDebounce = Debounce();
  late String workId;

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id'] ?? '';
    loadCharacters();
  }

  @override
  void onClose() {
    searchDebounce.dispose();
    super.onClose();
  }

  Future<void> loadCharacters() async {
    state.isLoading.value = true;
    state.loadError.value = null;

    try {
      final repo = Get.find<CharacterRepository>();
      final tiers = state.selectedTier.value != null
          ? [state.selectedTier.value!]
          : null;
      final characters = await repo.getCharactersByWorkId(
        workId,
        includeArchived: state.showArchived.value,
        tiers: tiers,
      );

      List<Character> filtered = characters;
      if (state.searchQuery.value.isNotEmpty) {
        filtered = characters.where((c) {
          final query = state.searchQuery.value.toLowerCase();
          return c.name.toLowerCase().contains(query) ||
              c.aliases.any((a) => a.toLowerCase().contains(query)) ||
              (c.identity?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      state.characters.value = filtered;
      state.isLoading.value = false;
    } catch (e) {
      state.loadError.value = e;
      state.isLoading.value = false;
    }
  }

  void onTierSelected(CharacterTier? tier) {
    state.selectedTier.value = tier;
    loadCharacters();
  }

  void onArchiveToggle() {
    state.showArchived.value = !state.showArchived.value;
    loadCharacters();
  }

  void onSearchChanged(String value) {
    searchDebounce(() {
      state.searchQuery.value = value;
    });
  }

  void navigateToCreate() {
    Get.toNamed('/work/$workId/characters/new')?.then((result) {
      if (result == true) loadCharacters();
    });
  }

  void navigateToDetail(Character character) {
    Get.toNamed('/work/$workId/characters/${character.id}');
  }

  void navigateToEdit(Character character) {
    Get.toNamed('/work/$workId/characters/${character.id}/edit')?.then((result) {
      if (result == true) loadCharacters();
    });
  }

  Future<void> updateLifeStatus(Character character, LifeStatus status) async {
    try {
      final repository = Get.find<CharacterRepository>();
      await repository.updateLifeStatus(
        id: character.id,
        status: status,
      );

      final s = Get.context != null ? S.of(Get.context!)! : null;
      if (s != null) {
        showSuccessSnackbar(s.settings_markAsStatus(character.name, status.label));
      }
      loadCharacters();
    } catch (e) {
      showErrorSnackbar(e.toString());
    }
  }

  Future<void> toggleArchive(Character character) async {
    try {
      final repository = Get.find<CharacterRepository>();
      if (character.isArchived) {
        await repository.updateCharacter(
          character.copyWith(isArchived: false, updatedAt: DateTime.now()),
        );
      } else {
        await repository.archiveCharacter(character.id);
      }

      final s = Get.context != null ? S.of(Get.context!)! : null;
      if (s != null) {
        showSuccessSnackbar(character.isArchived
            ? s.settings_unarchived
            : s.settings_archived);
      }
      loadCharacters();
    } catch (e) {
      showErrorSnackbar(e.toString());
    }
  }
}
