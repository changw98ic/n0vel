import 'package:flutter/material.dart';

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
}

const _lightColors = _ThemeColors(
  brightness: Brightness.light,
  canvas: appCanvasColor,
  surface: appSurfaceColor,
  onSurface: Color(0xFF2E2925),
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
);

const _darkColors = _ThemeColors(
  brightness: Brightness.dark,
  canvas: Color(0xFF221D1A),
  surface: Color(0xFF2B2521),
  onSurface: Color(0xFFF1E9DE),
  elevated: Color(0xFF342D28),
  subtle: Color(0xFF403730),
  border: Color(0xFF564A41),
  borderStrong: Color(0xFF77695D),
  primary: Color(0xFF91A78A),
  secondaryText: Color(0xFFD2C6B7),
  tertiaryText: Color(0xFFA99C8E),
  success: Color(0xFF8FB08E),
  danger: Color(0xFFC27D6D),
  info: Color(0xFF8CA0B8),
);

class AppTheme {
  static ThemeData light() => _build(_lightColors);

  static ThemeData dark() => _build(_darkColors);

  static ThemeData _build(_ThemeColors c) {
    final colorScheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.surface,
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
        ),
      ],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.elevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.primary),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: base.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.onSurface,
          backgroundColor: c.elevated,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: base.textTheme.labelMedium?.copyWith(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: base.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: c.onSurface,
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 32 / 24,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: c.onSurface,
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 26 / 18,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          color: c.onSurface,
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 24 / 16,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: c.onSurface,
          fontFamily: 'Geist',
          fontSize: 15,
          height: 24 / 15,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: c.secondaryText,
          fontFamily: 'Inter',
          fontSize: 13,
          height: 18 / 13,
        ),
        labelMedium: base.textTheme.labelMedium?.copyWith(
          color: c.onSurface,
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 18 / 13,
        ),
        labelSmall: base.textTheme.labelSmall?.copyWith(
          color: c.tertiaryText,
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 18 / 12,
        ),
      ),
    );
  }
}
