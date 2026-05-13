import 'package:flutter/material.dart';

import 'desktop_theme.dart';

/// A warm surface card suitable for popover content.
///
/// Provide [items] for a list with automatic dividers, or [child] for
/// arbitrary content. Optionally show a [title] above the content area.
class AppPopover extends StatelessWidget {
  const AppPopover({super.key, this.title, this.items, this.child})
    : assert(items != null || child != null, 'Provide either items or child');

  final String? title;
  final List<Widget>? items;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final hasItems = items != null && items!.isNotEmpty;

    return Container(
      decoration: glassPanelDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Text(title!, style: theme.textTheme.titleSmall),
            ),
          if (hasItems)
            for (var i = 0; i < items!.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: palette.border),
              items![i],
            ]
          else
            Padding(padding: const EdgeInsets.all(14), child: child!),
        ],
      ),
    );
  }
}
