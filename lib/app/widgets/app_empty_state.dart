import 'package:flutter/material.dart';

enum AppEmptyStateStyle {
  compact,
  prominent,
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.actions,
    this.style = AppEmptyStateStyle.compact,
  });

  final String title;
  final String message;
  final Widget? icon;
  final List<Widget>? actions;
  final AppEmptyStateStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = style == AppEmptyStateStyle.compact;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(height: 16),
          ],
          Text(
            title,
            style: isCompact
                ? theme.textTheme.titleMedium
                : theme.textTheme.headlineSmall,
          ),
          SizedBox(height: isCompact ? 8 : 12),
          Text(
            message,
            style: isCompact
                ? theme.textTheme.bodySmall
                : theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}
