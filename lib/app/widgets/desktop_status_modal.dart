import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
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
    final palette = desktopPalette(context);
    return Semantics(
      label: rightText == null
          ? '状态栏: $leftText'
          : '状态栏: $leftText · $rightText',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              key: stripKey,
              height: 30,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDesignTokens.space16,
              ),
              decoration: BoxDecoration(
                color: palette.navGlass,
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
                border: Border.all(color: palette.navBorder),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadowBase.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
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
                    Text(
                      rightText!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BottomSpecBar extends StatelessWidget {
  const BottomSpecBar({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.navGlass,
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
              border: Border.all(color: palette.navBorder),
              boxShadow: [
                BoxShadow(
                  color: palette.shadowBase.withValues(alpha: 0.09),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_outlined, size: 14, color: palette.navActive),
                const SizedBox(width: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: palette.navActive,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DesignActionButton extends StatelessWidget {
  const DesignActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: palette.buttonPrimaryFill,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
        ),
        elevation: 0,
      ).copyWith(
        shadowColor: WidgetStateProperty.all(palette.darkPanelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.foregroundInverse),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.foregroundInverse,
            ),
          ),
        ],
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
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.space24,
        vertical: AppDesignTokens.space24,
      ),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(AppDesignTokens.space20),
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
              const SizedBox(height: AppDesignTokens.space12),
              Text(description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: AppDesignTokens.space16),
            Flexible(child: body),
            const SizedBox(height: AppDesignTokens.space16),
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
