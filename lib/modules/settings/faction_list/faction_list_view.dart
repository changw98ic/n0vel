import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../shared/data/base_business/base_page.dart';
import '../../../features/settings/domain/faction.dart';
import '../../../l10n/app_localizations.dart';
import 'faction_list_logic.dart';

class FactionListView extends GetView<FactionListLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings_factionListTitle),
        actions: [
          Obx(() => PopupMenuButton<String>(
            initialValue: controller.state.filterType.value,
            onSelected: controller.onFilterChanged,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text(s.settings_allTypes)),
              ...FactionType.values.map((t) => PopupMenuItem(
                    value: t.name,
                    child: Text(t.label),
                  )),
            ],
            icon: const Icon(Icons.filter_list),
          )),
        ],
      ),
      body: FutureBuilder<List<Faction>>(
        future: controller.loadFactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return loadingIndicator();
          }

          final factions = snapshot.data ?? [];

          if (factions.isEmpty) {
            return emptyState(
              icon: Icons.groups_outlined,
              message: s.settings_noFactionsCreated,
              action: FilledButton.icon(
                onPressed: controller.navigateToCreate,
                icon: const Icon(Icons.add),
                label: Text(s.settings_createFaction),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: factions.length,
            itemBuilder: (context, index) {
              final faction = factions[index];
              return FactionCard(
                faction: faction,
                onTap: () => controller.navigateToEdit(faction),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'faction_fab',
        onPressed: controller.navigateToCreate,
        icon: const Icon(Icons.add),
        label: Text(s.settings_addFaction),
      ),
    );
  }
}

class FactionCard extends StatelessWidget {
  final Faction faction;
  final VoidCallback onTap;

  const FactionCard({required this.faction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = faction.type != null
        ? FactionType.values.firstWhere((t) => t.name == faction.type,
            orElse: () => FactionType.other)
        : FactionType.other;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: faction.emblemPath != null
                        ? Image.asset(faction.emblemPath!, fit: BoxFit.cover)
                        : Icon(Icons.groups, size: 32.sp, color: theme.colorScheme.primary),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          faction.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer),
                ],
              ),
            ),
            if (faction.description != null)
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  faction.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            if (faction.traits.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 16.h),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: faction.traits.take(5).map((trait) {
                    return Chip(
                      label: Text(trait, style: TextStyle(fontSize: 12.sp)),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
