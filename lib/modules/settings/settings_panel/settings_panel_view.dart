import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../l10n/app_localizations.dart';
import 'settings_panel_logic.dart';

/// 世界设定工作台
class SettingsPanelView extends GetView<SettingsPanelLogic> {
  const SettingsPanelView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final theme = Theme.of(context);
    final workId = controller.workId;

    final tiles = [
      _Tile(Icons.groups_rounded, s.settings_characterList, '/work/$workId/characters'),
      _Tile(Icons.people_alt_rounded, s.settings_relationshipManagement, '/work/$workId/relationships'),
      _Tile(Icons.inventory_2_rounded, s.settings_itemManagement, '/work/$workId/items'),
      _Tile(Icons.location_on_rounded, s.settings_locationManagement, '/work/$workId/locations'),
      _Tile(Icons.flag_rounded, s.settings_factionManagement, '/work/$workId/factions'),
      _Tile(Icons.bar_chart_rounded, s.settings_workStatistics, '/work/$workId/stats'),
      _Tile(Icons.timeline_rounded, s.settings_timeline, '/work/$workId/timeline'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.settings_worldWorkbench)),
      body: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final tile = tiles[index];
          return ListTile(
            leading: Icon(tile.icon, color: theme.colorScheme.primary),
            title: Text(tile.title, style: theme.textTheme.bodyLarge),
            trailing: Icon(Icons.arrow_forward_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            onTap: () => Get.toNamed(tile.route),
          );
        },
      ),
    );
  }
}

class _Tile {
  final IconData icon;
  final String title;
  final String route;
  const _Tile(this.icon, this.title, this.route);
}
