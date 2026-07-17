import 'package:flutter/material.dart';

import '../../../app/widgets/desktop_theme.dart';

class ReadingHotzone extends StatelessWidget {
  const ReadingHotzone({
    super.key,
    required this.zoneKey,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final Key zoneKey;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  bool get _isPrevious {
    final k = zoneKey is ValueKey<String>
        ? (zoneKey as ValueKey<String>).value
        : '';
    return k.contains('previous');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 36,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          key: zoneKey,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.0,
            child: Tooltip(
              message: label,
              child: Icon(
                _isPrevious
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 28,
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReadingInlineNoticeCard extends StatelessWidget {
  const ReadingInlineNoticeCard({super.key, required this.data});

  final ReadingInlineNoticeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBE2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.message,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class ReadingDocumentPages {
  const ReadingDocumentPages({
    required this.sceneId,
    required this.locationLabel,
    required this.pages,
  });

  final String sceneId;
  final String locationLabel;
  final List<String> pages;
}

class ReadingInlineNoticeData {
  const ReadingInlineNoticeData({required this.title, required this.message});

  final String title;
  final String message;
}
