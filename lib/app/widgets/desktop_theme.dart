import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

const Color appCanvasColor = Color(0xFFF7F2E8);
const Color appSurfaceColor = Color(0xFFF5F3EE); // surface-primary
const Color appElevatedColor = Color(0xFFFBFAF6);
const Color appSubtleColor = Color(0xFFEEE6DA);
const Color appBorderColor = Color(0xFFD6DDD0);
const Color appBorderStrongColor = Color(0xFF8DAA95);
const Color appPrimaryColor = Color(0xFF2D5E3A);
const Color appSecondaryTextColor = Color(0xFF7A9A80);
const Color appTertiaryTextColor = Color(0xFF6E746A);
const Color appSuccessColor = Color(0xFF5B7A5A);
const Color appDangerColor = Color(0xFF9A5444);
const Color appInfoColor = Color(0xFF5C6E85);
const Color appForegroundPrimary = Color(0xFF1B3A28);
const Color appSurfaceInverse = Color(0xFF1B3A28);
const Color appForegroundInverse = Color(0xFFFFFFFF);
const Color appButtonPrimaryFill = Color(0xFF243226);
const Color appButtonSecondaryFill = Color(0xFFF3EFE6);
const Color appButtonSecondaryBorder = Color(0xFFD8D2C6);

abstract final class DesktopLayoutTokens {
  static const double compactPageBreakpoint = 860;
  static const double wideThreePaneBreakpoint = 980;
  static const double standardSidebarWidth = 220;
  static const double projectDetailWidth = 320;
  static const double styleInputWidth = 360;
  static const double styleSideWidth = 300;
  static const double settingsFormWidth = 420;
  static const double settingsSideWidth = 300;
  static const double workbenchChapterSidebarWidth = 300;
  static const double workbenchToolWindowWidth = 360;

  static const double narrowBreakpoint = AppDesignTokens.breakpointNarrow;
  static const double mediumBreakpoint = AppDesignTokens.breakpointMedium;
  static const double wideBreakpoint = AppDesignTokens.breakpointWide;

  static const double shellPaddingWide = AppDesignTokens.space24;
  static const double shellPaddingMedium = AppDesignTokens.space16;
  static const double shellPaddingNarrow = AppDesignTokens.space12;
  static const double panelSpacingWide = AppDesignTokens.space16;
  static const double panelSpacingNarrow = AppDesignTokens.space8;
  static const double splitHandleWidth = 6.0;
  static const double splitHandleHitArea = AppDesignTokens.space12 + 2;
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
    required this.sidebar,
    required this.splitHandle,
    required this.glassPanel,
    required this.glassCard,
    required this.glassToolbar,
    required this.glassBorder,
    required this.shadowBase,
    required this.darkPanel,
    required this.darkPanelBorder,
    required this.navGlass,
    required this.navBorder,
    required this.navActive,
    required this.navInactive,
    required this.accentPrimary,
    required this.borderSubtle,
    required this.surfaceInverse,
    required this.foregroundPrimary,
    required this.foregroundMuted,
    required this.foregroundInverse,
    required this.buttonPrimaryFill,
    required this.buttonSecondaryFill,
    required this.buttonSecondaryBorder,
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
  final Color sidebar;
  final Color splitHandle;
  final Color glassPanel;
  final Color glassCard;
  final Color glassToolbar;
  final Color glassBorder;
  final Color shadowBase;

  final Color darkPanel;
  final Color darkPanelBorder;
  final Color navGlass;
  final Color navBorder;
  final Color navActive;
  final Color navInactive;

  final Color accentPrimary;
  final Color borderSubtle;
  final Color surfaceInverse;
  final Color foregroundPrimary;
  final Color foregroundMuted;
  final Color foregroundInverse;
  final Color buttonPrimaryFill;
  final Color buttonSecondaryFill;
  final Color buttonSecondaryBorder;

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
    Color? sidebar,
    Color? splitHandle,
    Color? glassPanel,
    Color? glassCard,
    Color? glassToolbar,
    Color? glassBorder,
    Color? shadowBase,
    Color? darkPanel,
    Color? darkPanelBorder,
    Color? navGlass,
    Color? navBorder,
    Color? navActive,
    Color? navInactive,
    Color? accentPrimary,
    Color? borderSubtle,
    Color? surfaceInverse,
    Color? foregroundPrimary,
    Color? foregroundMuted,
    Color? foregroundInverse,
    Color? buttonPrimaryFill,
    Color? buttonSecondaryFill,
    Color? buttonSecondaryBorder,
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
      sidebar: sidebar ?? this.sidebar,
      splitHandle: splitHandle ?? this.splitHandle,
      glassPanel: glassPanel ?? this.glassPanel,
      glassCard: glassCard ?? this.glassCard,
      glassToolbar: glassToolbar ?? this.glassToolbar,
      glassBorder: glassBorder ?? this.glassBorder,
      shadowBase: shadowBase ?? this.shadowBase,
      darkPanel: darkPanel ?? this.darkPanel,
      darkPanelBorder: darkPanelBorder ?? this.darkPanelBorder,
      navGlass: navGlass ?? this.navGlass,
      navBorder: navBorder ?? this.navBorder,
      navActive: navActive ?? this.navActive,
      navInactive: navInactive ?? this.navInactive,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      surfaceInverse: surfaceInverse ?? this.surfaceInverse,
      foregroundPrimary: foregroundPrimary ?? this.foregroundPrimary,
      foregroundMuted: foregroundMuted ?? this.foregroundMuted,
      foregroundInverse: foregroundInverse ?? this.foregroundInverse,
      buttonPrimaryFill: buttonPrimaryFill ?? this.buttonPrimaryFill,
      buttonSecondaryFill: buttonSecondaryFill ?? this.buttonSecondaryFill,
      buttonSecondaryBorder:
          buttonSecondaryBorder ?? this.buttonSecondaryBorder,
    );
  }

  @override
  DesktopPalette lerp(ThemeExtension<DesktopPalette>? other, double t) {
    if (other is! DesktopPalette) return this;
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
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      splitHandle: Color.lerp(splitHandle, other.splitHandle, t)!,
      glassPanel: Color.lerp(glassPanel, other.glassPanel, t)!,
      glassCard: Color.lerp(glassCard, other.glassCard, t)!,
      glassToolbar: Color.lerp(glassToolbar, other.glassToolbar, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      shadowBase: Color.lerp(shadowBase, other.shadowBase, t)!,
      darkPanel: Color.lerp(darkPanel, other.darkPanel, t)!,
      darkPanelBorder: Color.lerp(darkPanelBorder, other.darkPanelBorder, t)!,
      navGlass: Color.lerp(navGlass, other.navGlass, t)!,
      navBorder: Color.lerp(navBorder, other.navBorder, t)!,
      navActive: Color.lerp(navActive, other.navActive, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      surfaceInverse: Color.lerp(surfaceInverse, other.surfaceInverse, t)!,
      foregroundPrimary: Color.lerp(
        foregroundPrimary,
        other.foregroundPrimary,
        t,
      )!,
      foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
      foregroundInverse: Color.lerp(
        foregroundInverse,
        other.foregroundInverse,
        t,
      )!,
      buttonPrimaryFill: Color.lerp(
        buttonPrimaryFill,
        other.buttonPrimaryFill,
        t,
      )!,
      buttonSecondaryFill: Color.lerp(
        buttonSecondaryFill,
        other.buttonSecondaryFill,
        t,
      )!,
      buttonSecondaryBorder: Color.lerp(
        buttonSecondaryBorder,
        other.buttonSecondaryBorder,
        t,
      )!,
    );
  }
}

DesktopPalette desktopPalette(BuildContext context) =>
    Theme.of(context).extension<DesktopPalette>()!;

List<BoxShadow> _dualShadow(Color base, {double alphaScale = 1.0}) => [
  BoxShadow(
    color: base.withValues(alpha: 0.10 * alphaScale),
    blurRadius: 28,
    offset: const Offset(0, 12),
  ),
  BoxShadow(
    color: base.withValues(alpha: 0.06 * alphaScale),
    blurRadius: 12,
    offset: const Offset(0, 4),
  ),
];

BoxDecoration appPanelDecoration(BuildContext context, {Color? color}) {
  final palette = desktopPalette(context);
  return BoxDecoration(
    color: color ?? palette.surface,
    border: Border.all(color: palette.glassBorder),
    borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
    boxShadow: _dualShadow(palette.shadowBase, alphaScale: 0.6),
  );
}

BoxDecoration appModalDecoration(BuildContext context, {Color? color}) {
  final palette = desktopPalette(context);
  return BoxDecoration(
    color: color ?? palette.glassPanel,
    border: Border.all(color: palette.glassBorder),
    borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
    boxShadow: _dualShadow(palette.shadowBase),
  );
}

BoxDecoration glassPanelDecoration(BuildContext context, {Color? color}) {
  final palette = desktopPalette(context);
  return BoxDecoration(
    color: color ?? palette.glassPanel,
    border: Border.all(color: palette.navBorder),
    borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
    boxShadow: _dualShadow(palette.shadowBase),
  );
}

BoxDecoration glassCardDecoration(BuildContext context, {Color? color}) {
  final palette = desktopPalette(context);
  return BoxDecoration(
    color: color ?? palette.glassCard,
    border: Border.all(color: palette.glassBorder),
    borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
    boxShadow: [
      BoxShadow(
        color: palette.shadowBase.withValues(alpha: 0.08),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

BoxDecoration darkPanelDecoration(BuildContext context, {Color? color}) {
  final palette = desktopPalette(context);
  return BoxDecoration(
    color: color ?? palette.darkPanel,
    border: Border.all(color: palette.darkPanelBorder),
    borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
    boxShadow: _dualShadow(palette.shadowBase),
  );
}

BoxDecoration navBarDecoration(BuildContext context) {
  final palette = desktopPalette(context);
  return BoxDecoration(
    color: palette.navGlass,
    border: Border(bottom: BorderSide(color: palette.navBorder)),
    boxShadow: [
      BoxShadow(
        color: palette.shadowBase.withValues(alpha: 0.08),
        blurRadius: 30,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

BoxDecoration frostedSidebarDecoration(BuildContext context) {
  return BoxDecoration(
    color: const Color(0x7AFFFFFF),
    borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
    border: Border.all(color: const Color(0x99FFFFFF)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x181F2A1D),
        blurRadius: 40,
        offset: Offset(0, 18),
      ),
    ],
  );
}

BoxDecoration frostedEditorDecoration(BuildContext context) {
  return BoxDecoration(
    color: const Color(0xB8FFFFFF),
    borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
    border: Border.all(color: const Color(0x99FFFFFF)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x181F2A1D),
        blurRadius: 40,
        offset: Offset(0, 18),
      ),
    ],
  );
}

BoxDecoration darkAiPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: const Color(0xE6203626),
    borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
    border: Border.all(color: const Color(0x26FFFFFF)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x241F2A1D),
        blurRadius: 44,
        offset: Offset(0, 20),
      ),
    ],
  );
}
