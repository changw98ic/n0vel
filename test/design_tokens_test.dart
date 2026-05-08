import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/theme/app_design_tokens.dart';

void main() {
  group('AppDesignTokens', () {
    test('spacing tokens are in ascending order', () {
      expect(AppDesignTokens.space4, lessThan(AppDesignTokens.space8));
      expect(AppDesignTokens.space8, lessThan(AppDesignTokens.space12));
      expect(AppDesignTokens.space12, lessThan(AppDesignTokens.space16));
      expect(AppDesignTokens.space16, lessThan(AppDesignTokens.space20));
      expect(AppDesignTokens.space20, lessThan(AppDesignTokens.space24));
      expect(AppDesignTokens.space24, lessThan(AppDesignTokens.space32));
      expect(AppDesignTokens.space32, lessThan(AppDesignTokens.space48));
    });

    test('border radius tokens are in ascending order', () {
      expect(
        AppDesignTokens.radiusSmall,
        lessThan(AppDesignTokens.radiusMedium),
      );
      expect(
        AppDesignTokens.radiusMedium,
        lessThan(AppDesignTokens.radiusLarge),
      );
      expect(
        AppDesignTokens.radiusLarge,
        lessThan(AppDesignTokens.radiusXLarge),
      );
    });

    test('font size tokens are in ascending order', () {
      expect(
        AppDesignTokens.fontSizeCaption,
        lessThan(AppDesignTokens.fontSizeSmall),
      );
      expect(
        AppDesignTokens.fontSizeSmall,
        lessThan(AppDesignTokens.fontSizeBody),
      );
      expect(
        AppDesignTokens.fontSizeBody,
        lessThan(AppDesignTokens.fontSizeSubheading),
      );
      expect(
        AppDesignTokens.fontSizeSubheading,
        lessThan(AppDesignTokens.fontSizeTitle),
      );
      expect(
        AppDesignTokens.fontSizeTitle,
        lessThan(AppDesignTokens.fontSizeHeadline),
      );
    });

    test('breakpoints are in ascending order', () {
      expect(
        AppDesignTokens.breakpointNarrow,
        lessThan(AppDesignTokens.breakpointMedium),
      );
      expect(
        AppDesignTokens.breakpointMedium,
        lessThan(AppDesignTokens.breakpointWide),
      );
    });

    test('border radius helpers return correct BorderRadius', () {
      expect(
        AppDesignTokens.borderRadiusSmall,
        BorderRadius.circular(AppDesignTokens.radiusSmall),
      );
      expect(
        AppDesignTokens.borderRadiusMedium,
        BorderRadius.circular(AppDesignTokens.radiusMedium),
      );
      expect(
        AppDesignTokens.borderRadiusLarge,
        BorderRadius.circular(AppDesignTokens.radiusLarge),
      );
    });

    test('all token values are positive', () {
      // Spacing
      for (final value in [
        AppDesignTokens.space4,
        AppDesignTokens.space8,
        AppDesignTokens.space12,
        AppDesignTokens.space16,
        AppDesignTokens.space20,
        AppDesignTokens.space24,
        AppDesignTokens.space32,
        AppDesignTokens.space48,
      ]) {
        expect(value, greaterThan(0));
      }
      // Radii
      for (final value in [
        AppDesignTokens.radiusSmall,
        AppDesignTokens.radiusMedium,
        AppDesignTokens.radiusLarge,
        AppDesignTokens.radiusXLarge,
      ]) {
        expect(value, greaterThan(0));
      }
    });

    test('icon size tokens are positive', () {
      expect(AppDesignTokens.iconSmall, greaterThan(0));
      expect(AppDesignTokens.iconMedium, greaterThan(AppDesignTokens.iconSmall));
      expect(AppDesignTokens.iconLarge, greaterThan(AppDesignTokens.iconMedium));
    });

    test('elevation tokens are non-negative', () {
      expect(AppDesignTokens.elevationNone, equals(0));
      expect(AppDesignTokens.elevationLow, greaterThan(0));
      expect(
        AppDesignTokens.elevationMedium,
        greaterThan(AppDesignTokens.elevationLow),
      );
      expect(
        AppDesignTokens.elevationHigh,
        greaterThan(AppDesignTokens.elevationMedium),
      );
    });
  });
}
