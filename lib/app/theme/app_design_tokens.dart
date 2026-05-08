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
  static const double radiusMedium = 10;
  static const double radiusLarge = 14;
  static const double radiusXLarge = 20;

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
}
