import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../shared/data/base_business/base_page.dart';
import '../../../features/settings/domain/item.dart';
import '../../../l10n/app_localizations.dart';
import 'item_list_logic.dart';

class ItemListView extends GetView<ItemListLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings_itemListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => openSearch(context),
          ),
        ],
      ),
      body: Column(
        children: [
          buildFilterBar(context),
          Expanded(
            child: FutureBuilder<List<Item>>(
              future: controller.loadItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return loadingIndicator();
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return emptyState(
                    icon: Icons.inventory_2_outlined,
                    message: s.settings_noItemsCreated,
                    action: FilledButton.icon(
                      onPressed: controller.navigateToCreate,
                      icon: const Icon(Icons.add),
                      label: Text(s.settings_createItem),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ItemCard(
                      item: item,
                      onTap: () => controller.navigateToEdit(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'item_fab',
        onPressed: controller.navigateToCreate,
        icon: const Icon(Icons.add),
        label: Text(s.settings_addItem),
      ),
    );
  }

  Widget buildFilterBar(BuildContext context) {
    final s = S.of(context)!;
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Obx(() => Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: controller.state.filterType.value,
              decoration: InputDecoration(
                labelText: s.settings_type,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(s.settings_all)),
                ...ItemType.values.map((t) => DropdownMenuItem(
                      value: t.name,
                      child: Text(t.label),
                    )),
              ],
              onChanged: controller.onTypeChanged,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: controller.state.filterRarity.value,
              decoration: InputDecoration(
                labelText: s.settings_rarity,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(s.settings_all)),
                ...ItemRarity.values.map((r) => DropdownMenuItem(
                      value: r.name,
                      child: Text(r.label),
                    )),
              ],
              onChanged: controller.onRarityChanged,
            ),
          ),
        ],
      )),
    );
  }

  void openSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: ItemSearchDelegate(onQueryChanged: controller.onSearchChanged),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const ItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rarity = item.rarity != null
        ? ItemRarity.values.firstWhere((r) => r.name == item.rarity,
            orElse: () => ItemRarity.common)
        : ItemRarity.common;

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: rarity.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: rarity.color, width: 2),
          ),
          child: item.iconPath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: Image.asset(item.iconPath!, fit: BoxFit.cover),
                )
              : Icon(Icons.inventory_2, color: rarity.color),
        ),
        title: Text(
          item.name,
          style: TextStyle(color: rarity.color, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.type != null)
              Text(
                ItemType.values.firstWhere((t) => t.name == item.type,
                        orElse: () => ItemType.other)
                    .label,
                style: theme.textTheme.bodySmall,
              ),
            if (item.description != null)
              Text(
                item.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: RarityBadge(rarity: rarity),
        onTap: onTap,
      ),
    );
  }
}

class RarityBadge extends StatelessWidget {
  final ItemRarity rarity;

  const RarityBadge({required this.rarity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: rarity.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: rarity.color),
      ),
      child: Text(
        rarity.label,
        style: TextStyle(
          color: rarity.color,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class ItemSearchDelegate extends SearchDelegate<String> {
  final void Function(String) onQueryChanged;

  ItemSearchDelegate({required this.onQueryChanged});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          onQueryChanged('');
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Get.back(),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onQueryChanged(query);
    final s = S.of(context)!;
    return Center(child: Text(s.settings_search(query)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final s = S.of(context)!;
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(s.settings_recentSearches),
        ),
      ],
    );
  }
}
