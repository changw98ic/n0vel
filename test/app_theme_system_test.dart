import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/app/widgets/desktop_shell.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses Material 3 and correct brightness', () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('dark theme uses Material 3 and correct brightness', () {
      final theme = AppTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('light theme has DesktopPalette extension', () {
      final theme = AppTheme.light();
      final palette = theme.extension<DesktopPalette>();
      expect(palette, isNotNull);
      expect(palette!.primary, appPrimaryColor);
      expect(palette.canvas, appCanvasColor);
      expect(palette.success, appSuccessColor);
      expect(palette.danger, appDangerColor);
      expect(palette.info, appInfoColor);
    });

    test('dark theme has DesktopPalette extension', () {
      final theme = AppTheme.dark();
      final palette = theme.extension<DesktopPalette>();
      expect(palette, isNotNull);
      expect(palette!.primary, const Color(0xFF91A78A));
      expect(palette.canvas, const Color(0xFF221D1A));
    });

    test('light and dark themes have different primary colors', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();
      expect(
        light.colorScheme.primary,
        isNot(equals(dark.colorScheme.primary)),
      );
    });

    test('light theme scaffold background matches canvas', () {
      final theme = AppTheme.light();
      final palette = theme.extension<DesktopPalette>()!;
      expect(theme.scaffoldBackgroundColor, palette.canvas);
    });

    test('dark theme scaffold background matches canvas', () {
      final theme = AppTheme.dark();
      final palette = theme.extension<DesktopPalette>()!;
      expect(theme.scaffoldBackgroundColor, palette.canvas);
    });

    test('typography uses Inter and Geist font families', () {
      final theme = AppTheme.light();
      expect(theme.textTheme.headlineSmall?.fontFamily, 'Inter');
      expect(theme.textTheme.titleMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.titleSmall?.fontFamily, 'Inter');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Geist');
      expect(theme.textTheme.bodySmall?.fontFamily, 'Inter');
      expect(theme.textTheme.labelMedium?.fontFamily, 'Inter');
    });

    test('input decoration uses palette border and elevated colors', () {
      final theme = AppTheme.light();
      final palette = theme.extension<DesktopPalette>()!;
      final input = theme.inputDecorationTheme;
      expect(input.filled, isTrue);
      expect(input.fillColor, palette.elevated);
    });
  });

  group('DesktopPalette lerp', () {
    test('lerp interpolates all colors between light and dark', () {
      final light = AppTheme.light().extension<DesktopPalette>()!;
      final dark = AppTheme.dark().extension<DesktopPalette>()!;

      final mid = light.lerp(dark, 0.5);

      expect(mid.canvas, Color.lerp(light.canvas, dark.canvas, 0.5));
      expect(mid.primary, Color.lerp(light.primary, dark.primary, 0.5));
      expect(mid.danger, Color.lerp(light.danger, dark.danger, 0.5));
      expect(mid.info, Color.lerp(light.info, dark.info, 0.5));
    });

    test('lerp returns self when other is null', () {
      final palette = AppTheme.light().extension<DesktopPalette>()!;
      final result = palette.lerp(null, 0.5);
      expect(identical(result, palette), isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final palette = AppTheme.light().extension<DesktopPalette>()!;
      final copied = palette.copyWith(primary: const Color(0xFF000000));
      expect(copied.primary, const Color(0xFF000000));
      expect(copied.canvas, palette.canvas);
      expect(copied.danger, palette.danger);
    });
  });

  group('AppThemePreference', () {
    test('light maps to ThemeMode.light', () {
      const snapshot = AppSettingsSnapshot(
        providerName: '',
        baseUrl: '',
        model: '',
        apiKey: '',
        timeoutMs: 0,
        maxConcurrentRequests: 0,
        hasApiKey: false,
        themePreference: AppThemePreference.light,
      );
      expect(snapshot.themeMode, ThemeMode.light);
    });

    test('dark maps to ThemeMode.dark', () {
      const snapshot = AppSettingsSnapshot(
        providerName: '',
        baseUrl: '',
        model: '',
        apiKey: '',
        timeoutMs: 0,
        maxConcurrentRequests: 0,
        hasApiKey: false,
        themePreference: AppThemePreference.dark,
      );
      expect(snapshot.themeMode, ThemeMode.dark);
    });

    test('system maps to ThemeMode.system', () {
      const snapshot = AppSettingsSnapshot(
        providerName: '',
        baseUrl: '',
        model: '',
        apiKey: '',
        timeoutMs: 0,
        maxConcurrentRequests: 0,
        hasApiKey: false,
        themePreference: AppThemePreference.system,
      );
      expect(snapshot.themeMode, ThemeMode.system);
    });

    test('fromJson parses system preference', () {
      final json = {'themePreference': 'system'};
      final snapshot = AppSettingsSnapshot.fromJson(json);
      expect(snapshot.themePreference, AppThemePreference.system);
    });

    test('fromJson defaults to light for unknown preference', () {
      final json = {'themePreference': 'unknown'};
      final snapshot = AppSettingsSnapshot.fromJson(json);
      expect(snapshot.themePreference, AppThemePreference.light);
    });

    test('toJson serializes system preference', () {
      const snapshot = AppSettingsSnapshot(
        providerName: '',
        baseUrl: '',
        model: '',
        apiKey: '',
        timeoutMs: 0,
        maxConcurrentRequests: 0,
        hasApiKey: false,
        themePreference: AppThemePreference.system,
      );
      expect(snapshot.toJson()['themePreference'], 'system');
    });
  });

  group('desktopPalette', () {
    testWidgets('retrieves palette from theme context', (tester) async {
      late DesktopPalette captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              captured = desktopPalette(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured.primary, appPrimaryColor);
    });
  });
}
