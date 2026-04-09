import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../shared/data/base_business/base_page.dart';
import '../../../features/settings/domain/character.dart';
import '../view/character_card.dart';
import '../../../l10n/app_localizations.dart';
import 'character_list_logic.dart';

class CharacterListView extends GetView<CharacterListLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings_characterManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(),
          ),
          PopupMenuButton<CharacterTier?>(
            onSelected: controller.onTierSelected,
            itemBuilder: (context) => [
              PopupMenuItem(value: null, child: Text(s.settings_all)),
              ...CharacterTier.values.map(
                (tier) => PopupMenuItem(value: tier, child: Text(tier.label)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          buildFilterBar(context),
          Expanded(
            child: Obx(() {
              if (controller.state.isLoading.value) {
                return loadingIndicator();
              }
              if (controller.state.loadError.value != null) {
                return errorState(
                  s.settings_loadFailed(
                    controller.state.loadError.value.toString(),
                  ),
                  onRetry: controller.loadCharacters,
                );
              }
              return buildCharacterList(context);
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'character_fab',
        onPressed: controller.navigateToCreate,
        icon: const Icon(Icons.add),
        label: Text(s.settings_newCharacter),
      ),
    );
  }

  Widget buildFilterBar(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Obx(() => Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: CharacterTier.values.map((tier) {
                  final isSelected = controller.state.selectedTier.value == tier;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: FilterChip(
                      label: Text(tier.label),
                      selected: isSelected,
                      onSelected: (_) {
                        controller.onTierSelected(
                          isSelected ? null : tier,
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              controller.state.showArchived.value
                  ? Icons.unarchive
                  : Icons.archive_outlined,
            ),
            tooltip: controller.state.showArchived.value
                ? s.settings_hideArchived
                : s.settings_showArchived,
            onPressed: controller.onArchiveToggle,
          ),
        ],
      )),
    );
  }

  Widget buildCharacterList(BuildContext context) {
    final s = S.of(context)!;
    return Obx(() {
      final characters = controller.state.characters;

      if (characters.isEmpty) {
        return emptyState(
          icon: Icons.person_outline,
          message: controller.state.searchQuery.value.isNotEmpty
              ? s.settings_noMatchingCharacters
              : s.settings_noCharactersCreated,
        );
      }

      final grouped = <CharacterTier, List<Character>>{};
      for (final char in characters) {
        grouped.putIfAbsent(char.tier, () => []).add(char);
      }

      return ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final tier = grouped.keys.elementAt(index);
          final chars = grouped[tier]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  children: [
                    TierBadge(tier: tier),
                    SizedBox(width: 8.w),
                    Text(
                      s.settings_peopleCount(chars.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ...chars.map(
                (char) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: CharacterCard(
                    character: char,
                    onTap: () => controller.navigateToDetail(char),
                    onLongPress: () => showCharacterOptions(context, char),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          );
        },
      );
    });
  }

  void showSearch() {
    final s = S.of(Get.context!)!;
    showModalBottomSheet(
      context: Get.context!,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16.w,
          16.h,
          16.w,
          MediaQuery.of(context).viewInsets.bottom + 16.h,
        ),
        child: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: s.settings_searchCharacters,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
          onChanged: controller.onSearchChanged,
        ),
      ),
    );
  }

  void showCharacterOptions(BuildContext context, Character character) {
    final s = S.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(s.settings_edit),
              onTap: () {
                Get.back();
                controller.navigateToEdit(character);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: Text(s.settings_lifeStatus),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(character.lifeStatus.label),
                  SizedBox(width: 4.w),
                  Icon(Icons.chevron_right, size: 20.sp),
                ],
              ),
              onTap: () {
                Get.back();
                showLifeStatusOptions(context, character);
              },
            ),
            ListTile(
              leading: Icon(
                character.isArchived ? Icons.unarchive : Icons.archive,
              ),
              title: Text(
                character.isArchived ? s.settings_unarchive : s.settings_archive,
              ),
              onTap: () async {
                Get.back();
                await controller.toggleArchive(character);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showLifeStatusOptions(
    BuildContext context,
    Character character,
  ) async {
    final s = S.of(context)!;
    final selectedStatus = await showDialog<LifeStatus>(
      context: context,
      builder: (context) {
        LifeStatus? tempSelection = character.lifeStatus;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(s.settings_changeLifeStatus),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: LifeStatus.values.map((status) {
                return RadioListTile<LifeStatus>(
                  title: Text(status.label),
                  value: status,
                  groupValue: tempSelection,
                  onChanged: (value) {
                    setState(() => tempSelection = value);
                    Get.back(result: value);
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text(s.settings_cancel),
              ),
            ],
          ),
        );
      },
    );

    if (selectedStatus != null && selectedStatus != character.lifeStatus) {
      controller.updateLifeStatus(character, selectedStatus);
    }
  }
}

class TierBadge extends StatelessWidget {
  final CharacterTier tier;

  const TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tier) {
      CharacterTier.protagonist => (Colors.amber, Icons.star),
      CharacterTier.majorAntagonist => (Colors.red, Icons.dangerous),
      CharacterTier.antagonist => (Colors.orange, Icons.warning),
      CharacterTier.supporting => (Colors.blue, Icons.person),
      CharacterTier.minor => (Colors.grey, Icons.person_outline),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            tier.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
