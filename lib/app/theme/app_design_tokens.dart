import 'package:flutter/material.dart';

/// Centralized design tokens for consistent UI styling.
///
/// All spacing, colors, shapes, and typography values should reference
/// these tokens instead of hardcoded magic numbers.
class AppDesignTokens {
  AppDesignTokens._();

  // ── Spacing ──
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ── Border Radius ──
  static const double radiusSmall = 6;
  static const double radiusMedium = 8;
  static const double radiusLarge = 12;
  static const double radiusXLarge = 18;
  static const double radiusFull = 9999;

  static final BorderRadius borderRadiusSmall =
      BorderRadius.circular(radiusSmall);
  static final BorderRadius borderRadiusMedium =
      BorderRadius.circular(radiusMedium);
  static final BorderRadius borderRadiusLarge =
      BorderRadius.circular(radiusLarge);
  static final BorderRadius borderRadiusXLarge =
      BorderRadius.circular(radiusXLarge);

  // ── Icon Sizes ──
  static const double iconSmall = 16;
  static const double iconMedium = 20;
  static const double iconLarge = 24;

  // ── Font Sizes ──
  static const double fontSizeCaption = 11;
  static const double fontSizeSmall = 12;
  static const double fontSizeBody = 14;
  static const double fontSizeSubheading = 16;
  static const double fontSizeTitle = 20;
  static const double fontSizeHeadline = 24;

  // ── Font Weights ──
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // ── Line Heights (multiplier) ──
  static const double lineHeightTight = 1.25;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.75;

  // ── Duration ──
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // ── Elevation ──
  static const double elevationNone = 0;
  static const double elevationLow = 1;
  static const double elevationMedium = 4;
  static const double elevationHigh = 8;

  // ── Breakpoints ──
  static const double breakpointNarrow = 600;
  static const double breakpointMedium = 860;
  static const double breakpointWide = 1200;

  static const Color gradientStart = Color(0xFFF7F2E8);
  static const Color gradientMid = Color(0xFFE6EFE9);
  static const Color gradientEnd = Color(0xFFDDD7CA);
  static const List<double> gradientStops = [0.0, 0.52, 1.0];

  static const double glassBlurRadius = 20;
  static const double glassNavBlurRadius = 18;
  static const double glassPanelOpacity = 0.88;
  static const double glassCardOpacity = 0.90;
  static const double glassToolbarOpacity = 0.92;
  static const double glassBorderOpacity = 0.25;
  static const double glassNavOpacity = 0.66;
  static const double glassNavBorderOpacity = 0.50;

  // Navigation bar shadow: 0 10 30 #1F2A1D14
  static const double shadowNavBlur = 30;
  static const double shadowNavOffsetY = 10;
  static const double shadowNavAlpha = 0.08;

  // Primary button shadow: 0 10 26 #1F2A1D26
  static const double shadowButtonBlur = 26;
  static const double shadowButtonOffsetY = 10;
  static const double shadowButtonAlpha = 0.15;

  // Dual-layer shadows
  static const double shadowSmBlur = 6;
  static const double shadowSmOffsetY = 2;
  static const double shadowSmAlpha = 0.05;
  static const double shadowMdBlur = 16;
  static const double shadowMdOffsetY = 6;
  static const double shadowMdAlpha = 0.08;
  static const double shadowLgBlur = 28;
  static const double shadowLgOffsetY = 14;
  static const double shadowLgAlpha = 0.12;

  static const String fontBody = 'Noto Serif SC';
  static const String fontHeading = 'Noto Sans SC';
  static const String fontCaption = 'Noto Sans SC';
}
