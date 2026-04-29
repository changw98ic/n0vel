import 'package:flutter/material.dart';

import 'package:novel_writer/domain/settings.dart';
export 'package:novel_writer/domain/settings.dart';

extension AppSettingsSnapshotTheme on AppSettingsSnapshot {
  ThemeMode get themeMode => switch (themePreference) {
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
}
