import 'package:flutter/material.dart';

import 'desktop_shell.dart';

BoxDecoration prototypePanelDecoration(
  BuildContext context, {
  Color? color,
}) {
  final palette = desktopPalette(context);
  return BoxDecoration(
    color: color ?? palette.surface,
    border: Border.all(color: palette.border),
    borderRadius: BorderRadius.circular(12),
  );
}

class PrototypeHeaderBar extends StatelessWidget {
  const PrototypeHeaderBar({
    super.key,
    required this.title,
    this.titleKey,
  });

  final String title;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      width: double.infinity,
      decoration: prototypePanelDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const BackButton(),
          const SizedBox(width: 8),
          Text(title, key: titleKey, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class PrototypeHandleBar extends StatelessWidget {
  const PrototypeHandleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      decoration: prototypePanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      child: Center(
        child: Icon(
          Icons.drag_indicator,
          size: 18,
          color: desktopPalette(context).secondaryText,
        ),
      ),
    );
  }
}

class PrototypeStateCard extends StatelessWidget {
  const PrototypeStateCard({
    super.key,
    required this.title,
    required this.message,
    required this.accent,
  });

  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: desktopPalette(context).elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
