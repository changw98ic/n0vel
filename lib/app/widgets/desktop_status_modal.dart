import 'package:flutter/material.dart';

import 'desktop_theme.dart';

class DesktopStatusStrip extends StatelessWidget {
  const DesktopStatusStrip({
    super.key,
    this.stripKey,
    required this.leftText,
    this.rightText,
  });

  final Key? stripKey;
  final String leftText;
  final String? rightText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: rightText == null
          ? '状态栏: $leftText'
          : '状态栏: $leftText · $rightText',
      child: ExcludeSemantics(
        child: Container(
          key: stripKey,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: appPanelDecoration(context),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  leftText,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (rightText != null)
                Text(rightText!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopModalDialog extends StatelessWidget {
  const DesktopModalDialog({
    super.key,
    required this.title,
    this.description,
    required this.body,
    required this.actions,
    this.width = 720,
  });

  final String title;
  final String? description;
  final Widget body;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: appModalDecoration(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
            ),
            if (description != null) ...[
              const SizedBox(height: 12),
              Text(description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            body,
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [Wrap(spacing: 10, runSpacing: 10, children: actions)],
            ),
          ],
        ),
      ),
    );
  }
}
