import 'package:flutter/material.dart';

import '../../../app/widgets/desktop_theme.dart';

class StylePanelStrengthStepper extends StatelessWidget {
  const StylePanelStrengthStepper({
    super.key,
    required this.buttonKey,
    required this.icon,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: buttonKey,
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: appPanelDecoration(
          context,
          color: desktopPalette(context).elevated,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: desktopPalette(context).primary),
        ),
      ),
    );
  }
}
