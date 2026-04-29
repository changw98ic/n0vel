import 'package:flutter/material.dart';

const Color appCanvasColor = Color(0xFFF6F0E6);
const Color appSurfaceColor = Color(0xFFFBF7F1);
const Color appElevatedColor = Color(0xFFFFFDFC);
const Color appSubtleColor = Color(0xFFEEE6DA);
const Color appBorderColor = Color(0xFFD8CDC0);
const Color appBorderStrongColor = Color(0xFFB7AA9A);
const Color appPrimaryColor = Color(0xFF51624D);
const Color appSecondaryTextColor = Color(0xFF6E665E);
const Color appTertiaryTextColor = Color(0xFF91887D);
const Color appSuccessColor = Color(0xFF5B7A5A);
const Color appDangerColor = Color(0xFF9A5444);
const Color appInfoColor = Color(0xFF5C6E85);

abstract final class DesktopLayoutTokens {
  static const double compactPageBreakpoint = 860;
  static const double wideThreePaneBreakpoint = 980;
  static const double standardSidebarWidth = 220;
  static const double projectDetailWidth = 320;
  static const double styleInputWidth = 360;
  static const double styleSideWidth = 300;
  static const double settingsFormWidth = 420;
  static const double settingsSideWidth = 300;
  static const double workbenchToolWindowWidth = 296;
  static const double workbenchRailWidth = 60;

  static const double narrowBreakpoint = 600;
  static const double mediumBreakpoint = 860;
  static const double wideBreakpoint = 1200;

  static const double shellPaddingWide = 24.0;
  static const double shellPaddingMedium = 16.0;
  static const double shellPaddingNarrow = 12.0;
  static const double panelSpacingWide = 16.0;
  static const double panelSpacingNarrow = 8.0;
}

enum LayoutSize { narrow, medium, wide }

LayoutSize layoutSizeOf(double width) {
  if (width < DesktopLayoutTokens.narrowBreakpoint) return LayoutSize.narrow;
  if (width < DesktopLayoutTokens.wideBreakpoint) return LayoutSize.medium;
  return LayoutSize.wide;
}

double shellPaddingFor(double width) {
  if (width < DesktopLayoutTokens.narrowBreakpoint) {
    return DesktopLayoutTokens.shellPaddingNarrow;
  }
  if (width < DesktopLayoutTokens.wideBreakpoint) {
    return DesktopLayoutTokens.shellPaddingMedium;
  }
  return DesktopLayoutTokens.shellPaddingWide;
}

double panelSpacingFor(double width) {
  if (width < DesktopLayoutTokens.mediumBreakpoint) {
    return DesktopLayoutTokens.panelSpacingNarrow;
  }
  return DesktopLayoutTokens.panelSpacingWide;
}

class DesktopPalette extends ThemeExtension<DesktopPalette> {
  const DesktopPalette({
    required this.canvas,
    required this.surface,
    required this.elevated,
    required this.subtle,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.secondaryText,
    required this.tertiaryText,
    required this.success,
    required this.danger,
    required this.info,
  });

  final Color canvas;
  final Color surface;
  final Color elevated;
  final Color subtle;
  final Color border;
  final Color borderStrong;
  final Color primary;
  final Color secondaryText;
  final Color tertiaryText;
  final Color success;
  final Color danger;
  final Color info;

  Color get panel => elevated;

  Color get surfaceRaised => elevated;

  @override
  DesktopPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? elevated,
    Color? subtle,
    Color? border,
    Color? borderStrong,
    Color? primary,
    Color? secondaryText,
    Color? tertiaryText,
    Color? success,
    Color? danger,
    Color? info,
  }) {
    return DesktopPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      subtle: subtle ?? this.subtle,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      primary: primary ?? this.primary,
      secondaryText: secondaryText ?? this.secondaryText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  DesktopPalette lerp(ThemeExtension<DesktopPalette>? other, double t) {
    if (other is! DesktopPalette) {
      return this;
    }

    return DesktopPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

DesktopPalette desktopPalette(BuildContext context) =>
    Theme.of(context).extension<DesktopPalette>()!;

BoxDecoration appPanelDecoration(BuildContext context, {Color? color}) {
  final palette = desktopPalette(context);
  return BoxDecoration(
    color: color ?? palette.surface,
    border: Border.all(color: palette.border),
    borderRadius: BorderRadius.circular(12),
  );
}

BoxDecoration appModalDecoration(BuildContext context, {Color? color}) {
  final palette = desktopPalette(context);
  return BoxDecoration(
    color: color ?? palette.elevated,
    border: Border.all(color: palette.borderStrong),
    borderRadius: BorderRadius.circular(16),
  );
}
