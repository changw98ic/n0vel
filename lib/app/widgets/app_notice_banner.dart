import 'package:flutter/material.dart';

import '../events/app_domain_events.dart';
import 'desktop_shell.dart';

export '../events/app_domain_events.dart' show AppNoticeSeverity;

class AppNoticeBanner extends StatelessWidget {
  const AppNoticeBanner({
    super.key,
    required this.title,
    this.message,
    this.severity = AppNoticeSeverity.error,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    this.secondaryActionLabel,
    this.secondaryActionKey,
    this.onSecondaryAction,
  });

  final String title;
  final String? message;
  final AppNoticeSeverity severity;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final Key? secondaryActionKey;
  final VoidCallback? onSecondaryAction;

  static const Color _warningColor = Color(0xFFB6813B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final accent = _resolveAccentColor(palette);

    return Semantics(
      liveRegion: true,
      label: '$title${message != null && message!.isNotEmpty ? '：$message' : ''}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(_resolveIcon(), color: accent, size: 18),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (_hasActions) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (actionLabel != null && onAction != null)
                  TextButton(
                    key: actionKey,
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                if (secondaryActionLabel != null && onSecondaryAction != null)
                  TextButton(
                    key: secondaryActionKey,
                    onPressed: onSecondaryAction,
                    child: Text(secondaryActionLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  bool get _hasActions =>
      (actionLabel != null && onAction != null) ||
      (secondaryActionLabel != null && onSecondaryAction != null);

  Color _resolveAccentColor(DesktopPalette palette) => switch (severity) {
    AppNoticeSeverity.error => palette.danger,
    AppNoticeSeverity.warning => _warningColor,
    AppNoticeSeverity.info => palette.info,
    AppNoticeSeverity.success => palette.success,
  };

  IconData _resolveIcon() => switch (severity) {
    AppNoticeSeverity.error => Icons.error_outline,
    AppNoticeSeverity.warning => Icons.warning_amber_rounded,
    AppNoticeSeverity.info => Icons.info_outline,
    AppNoticeSeverity.success => Icons.check_circle_outline,
  };
}
