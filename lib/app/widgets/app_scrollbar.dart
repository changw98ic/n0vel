import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:novel_writer/app/theme/app_design_tokens.dart';
import 'package:novel_writer/app/widgets/desktop_theme.dart';

/// A premium scrollbar that automatically supports mouse, touch, and trackpad
/// drag-scrolling, ensuring clean desktop interaction.
class AppPremiumScrollbar extends StatelessWidget {
  const AppPremiumScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.thumbVisibility = true,
    this.thickness = 6.0,
    this.interactive = true,
  });

  /// The dedicated ScrollController bound to both the Scrollbar and the scrollable child.
  final ScrollController controller;

  /// The scrollable child (ListView, GridView, SingleChildScrollView, etc.)
  final Widget child;

  /// Enforces whether the scrollbar thumb remains visible when idle.
  final bool thumbVisibility;

  /// Customize scrollbar thickness (defaults to a sleek 6.0px).
  final double thickness;

  /// Toggle interactivity.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: RawScrollbar(
        controller: controller,
        thumbVisibility: thumbVisibility,
        thickness: thickness,
        radius: const Radius.circular(AppDesignTokens.radiusFull),
        interactive: interactive,
        thumbColor: palette.primary.withValues(alpha: 0.35),
        pressDuration: AppDesignTokens.durationFast,
        child: child,
      ),
    );
  }
}
