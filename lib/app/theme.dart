import 'package:flutter/material.dart';

/// 设计令牌 — Apple HIG 风格
class AppTokens {
  AppTokens._();

  // ── Border radius (squircle-friendly) ────────────────────────
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  // ── Spacing ──────────────────────────────────────────────────
  static const double spaceXs = 6;
  static const double spaceSm = 10;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // ── Animation duration ───────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // ── Apple design curves ──────────────────────────────────────
  static const Curve springCurve = Curves.easeOutQuart;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // ── Apple-style color palette ─────────────────────────────────
    final colorScheme = ColorScheme(
      brightness: brightness,
      // Primary: Warm light green (浅绿色)
      primary: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
      onPrimary: isDark ? const Color(0xFF003300) : const Color(0xFFFFFFFF),
      primaryContainer: isDark ? const Color(0xFF2E7D32) : const Color(0xFFC8E6C9),
      onPrimaryContainer: isDark ? const Color(0xFFC8E6C9) : const Color(0xFF1B5E20),
      // Secondary: Warm amber (暖琥珀色)
      secondary: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE8A838),
      onSecondary: isDark ? const Color(0xFF452B00) : const Color(0xFFFFFFFF),
      secondaryContainer: isDark ? const Color(0xFF634100) : const Color(0xFFFFE0B2),
      onSecondaryContainer: isDark ? const Color(0xFFFFE0B2) : const Color(0xFF2A1800),
      // Tertiary: Warm coral (暖珊瑚色)
      tertiary: isDark ? const Color(0xFFFF8A65) : const Color(0xFFE07A5F),
      onTertiary: isDark ? const Color(0xFF5B1A00) : const Color(0xFFFFFFFF),
      tertiaryContainer: isDark ? const Color(0xFF7E3A20) : const Color(0xFFFFCCBC),
      onTertiaryContainer: isDark ? const Color(0xFFFFCCBC) : const Color(0xFF3B0E00),
      // Error: Apple red
      error: isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
      onError: const Color(0xFFFFFFFF),
      errorContainer: isDark ? const Color(0xFF8C1B15) : const Color(0xFFFFDBD8),
      onErrorContainer: isDark ? const Color(0xFFFFDBD8) : const Color(0xFF5B0000),
      // Surfaces: Warm beige/cream tones (暖色调)
      surface: isDark ? const Color(0xFF12110E) : const Color(0xFFFAF8F4),
      onSurface: isDark ? const Color(0xFFE6E2DB) : const Color(0xFF1C1B18),
      surfaceContainerLowest: isDark ? const Color(0xFF0D0C09) : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark ? const Color(0xFF1A1916) : const Color(0xFFF5F3EE),
      surfaceContainer: isDark ? const Color(0xFF252320) : const Color(0xFFF0EDE7),
      surfaceContainerHigh: isDark ? const Color(0xFF302D2B) : const Color(0xFFEAE7E1),
      surfaceContainerHighest: isDark ? const Color(0xFF3B3835) : const Color(0xFFE4E1DB),
      onSurfaceVariant: isDark ? const Color(0xFFC4C0B8) : const Color(0xFF7A756D),
      outline: isDark ? const Color(0xFF4E4A44) : const Color(0xFFCBC5BD),
      outlineVariant: isDark ? const Color(0xFF312E28) : const Color(0xFFE0DBD4),
      inverseSurface: isDark ? const Color(0xFFFAF8F4) : const Color(0xFF1C1B18),
      onInverseSurface: isDark ? const Color(0xFF1C1B18) : const Color(0xFFFAF8F4),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );

    // ── Typography: SF Pro / system font ───────────────────────────
    final baseTextTheme = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        height: 1.6,
        color: colorScheme.onSurface,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        height: 1.5,
        color: colorScheme.onSurface,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        height: 1.4,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill.toDouble()),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: colorScheme.surfaceContainerHigh,
          foregroundColor: colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill.toDouble()),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill.toDouble()),
          ),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill.toDouble()),
        ),
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        iconColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        dividerColor: colorScheme.outlineVariant,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outline),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        elevation: 0,
        width: 360,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusXl)),
        ),
      ),
    );
  }
}

class ReaderTheme {
  final Color backgroundColor;
  final Color textColor;
  final Color secondaryColor;
  final String name;

  const ReaderTheme({
    required this.backgroundColor,
    required this.textColor,
    required this.secondaryColor,
    required this.name,
  });

  static const ReaderTheme light = ReaderTheme(
    backgroundColor: Color(0xFFF5F5F7),
    textColor: Color(0xFF1D1D1F),
    secondaryColor: Color(0xFF6E6E73),
    name: '浅色',
  );

  static const ReaderTheme dark = ReaderTheme(
    backgroundColor: Color(0xFF000000),
    textColor: Color(0xFFE5E5E7),
    secondaryColor: Color(0xFF86868B),
    name: '深色',
  );

  static const ReaderTheme sepia = ReaderTheme(
    backgroundColor: Color(0xFFFBF0E0),
    textColor: Color(0xFF3D3022),
    secondaryColor: Color(0xFF8B7355),
    name: '护眼',
  );

  static const ReaderTheme green = ReaderTheme(
    backgroundColor: Color(0xFFE8F0E4),
    textColor: Color(0xFF2D4A2D),
    secondaryColor: Color(0xFF5A7A5A),
    name: '绿色',
  );

  static const List<ReaderTheme> presets = [light, dark, sepia, green];
}
