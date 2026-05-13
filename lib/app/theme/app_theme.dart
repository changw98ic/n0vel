import 'package:flutter/material.dart';

import 'app_design_tokens.dart';
import '../widgets/desktop_shell.dart';

class _ThemeColors {
  const _ThemeColors({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.onSurface,
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

  final Brightness brightness;
  final Color canvas;
  final Color surface;
  final Color onSurface;
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
}

const _lightColors = _ThemeColors(
  brightness: Brightness.light,
  canvas: appCanvasColor,
  surface: appSurfaceColor,
  onSurface: Color(0xFF1B3A28),
  elevated: appElevatedColor,
  subtle: appSubtleColor,
  border: appBorderColor,
  borderStrong: appBorderStrongColor,
  primary: appPrimaryColor,
  secondaryText: appSecondaryTextColor,
  tertiaryText: appTertiaryTextColor,
  success: appSuccessColor,
  danger: appDangerColor,
  info: appInfoColor,
  sidebar: Color(0xFFEEE6DA),
  splitHandle: Color(0xFFD8D2C6),
  glassPanel: Color(0xB8FFFFFF),
  glassCard: Color(0xCCFBFAF6),
  glassToolbar: Color(0xCCF7F2E8),
  glassBorder: Color(0x40D6DDD0), // border-subtle at low opacity
  shadowBase: Color(0xFF1F2A1D),
  darkPanel: Color(0xE6203626),
  darkPanelBorder: Color(0x26FFFFFF),
  navGlass: Color(0xA8FFFFFF),
  navBorder: Color(0x80FFFFFF),
  navActive: Color(0xFF243226),
  navInactive: Color(0xFF6E746A),
  accentPrimary: Color(0xFF2D5E3A),
  borderSubtle: Color(0xFFD6DDD0),
  surfaceInverse: Color(0xFF1B3A28),
  foregroundPrimary: Color(0xFF1B3A28),
  foregroundMuted: Color(0xFF7A9A80),
  foregroundInverse: Color(0xFFFFFFFF),
  buttonPrimaryFill: Color(0xFF243226),
  buttonSecondaryFill: Color(0xFFF3EFE6),
  buttonSecondaryBorder: Color(0xFFD8D2C6),
);

const _darkColors = _ThemeColors(
  brightness: Brightness.dark,
  canvas: Color(0xFF1B1F1C),
  surface: Color(0xFF222924),
  onSurface: Color(0xFFF1E9DE),
  elevated: Color(0xFF2A3230),
  subtle: Color(0xFF343D38),
  border: Color(0xFF4A554E),
  borderStrong: Color(0xFF6B7A72),
  primary: Color(0xFF8DAA95),
  secondaryText: Color(0xFFA3B8A0),
  tertiaryText: Color(0xFF7A897E),
  success: Color(0xFF8FB08E),
  danger: Color(0xFFC27D6D),
  info: Color(0xFF8CA0B8),
  sidebar: Color(0xFF1E2420),
  splitHandle: Color(0xFF3A433E),
  glassPanel: Color(0xBF2A3230),
  glassCard: Color(0xCC303A35),
  glassToolbar: Color(0xCC262F2A),
  glassBorder: Color(0x404A554E),
  shadowBase: Color(0xFF000000),
  darkPanel: Color(0xE6203626),
  darkPanelBorder: Color(0x26FFFFFF),
  navGlass: Color(0xA8222924),
  navBorder: Color(0x80FFFFFF),
  navActive: Color(0xFFC8D6C4),
  navInactive: Color(0xFF7A897E),
  accentPrimary: Color(0xFF8DAA95),
  borderSubtle: Color(0xFF4A554E),
  surfaceInverse: Color(0xFFF1E9DE),
  foregroundPrimary: Color(0xFFF1E9DE),
  foregroundMuted: Color(0xFFA3B8A0),
  foregroundInverse: Color(0xFF1B1F1C),
  buttonPrimaryFill: Color(0xFF8DAA95),
  buttonSecondaryFill: Color(0xFF2A3230),
  buttonSecondaryBorder: Color(0xFF4A554E),
);

class AppTheme {
  static ThemeData light() => _build(_lightColors);

  static ThemeData dark() => _build(_darkColors);

  static ThemeData _build(_ThemeColors c) {
    final colorScheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: const Color(0xFFFFFFFF),
      secondary: c.info,
      onSecondary: c.surface,
      error: c.danger,
      onError: c.surface,
      surface: c.surface,
      onSurface: c.onSurface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.canvas,
    );

    return base.copyWith(
      cardColor: c.surface,
      dividerColor: c.border,
      extensions: [
        DesktopPalette(
          canvas: c.canvas,
          surface: c.surface,
          elevated: c.elevated,
          subtle: c.subtle,
          border: c.border,
          borderStrong: c.borderStrong,
          primary: c.primary,
          secondaryText: c.secondaryText,
          tertiaryText: c.tertiaryText,
          success: c.success,
          danger: c.danger,
          info: c.info,
          sidebar: c.sidebar,
          splitHandle: c.splitHandle,
          glassPanel: c.glassPanel,
          glassCard: c.glassCard,
          glassToolbar: c.glassToolbar,
          glassBorder: c.glassBorder,
          shadowBase: c.shadowBase,
          darkPanel: c.darkPanel,
          darkPanelBorder: c.darkPanelBorder,
          navGlass: c.navGlass,
          navBorder: c.navBorder,
          navActive: c.navActive,
          navInactive: c.navInactive,
          accentPrimary: c.accentPrimary,
          borderSubtle: c.borderSubtle,
          surfaceInverse: c.surfaceInverse,
          foregroundPrimary: c.foregroundPrimary,
          foregroundMuted: c.foregroundMuted,
          foregroundInverse: c.foregroundInverse,
          buttonPrimaryFill: c.buttonPrimaryFill,
          buttonSecondaryFill: c.buttonSecondaryFill,
          buttonSecondaryBorder: c.buttonSecondaryBorder,
        ),
      ],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.space12,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
          borderSide: BorderSide(color: c.primary),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
          borderSide: BorderSide(color: c.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.buttonPrimaryFill,
          foregroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
          ),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          elevation: 0,
          textStyle: base.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.onSurface,
          backgroundColor: c.buttonSecondaryFill,
          side: BorderSide(color: c.buttonSecondaryBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
          ),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: base.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: base.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: c.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 32 / 24,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: c.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          height: 28 / 22,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: c.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 26 / 18,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          color: c.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 24 / 16,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: c.onSurface,
          fontSize: 15,
          height: 24 / 15,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: c.onSurface,
          fontSize: 14,
          height: 22 / 14,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: c.secondaryText,
          fontSize: 13,
          height: 18 / 13,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          color: c.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 18 / 13,
        ),
        labelMedium: base.textTheme.labelMedium?.copyWith(
          color: c.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 18 / 12,
        ),
        labelSmall: base.textTheme.labelSmall?.copyWith(
          color: c.tertiaryText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 18 / 12,
        ),
      ),
    );
  }
}
