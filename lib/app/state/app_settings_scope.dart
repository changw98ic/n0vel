import 'package:flutter/material.dart';

import 'app_settings_store.dart';

class AppSettingsScope extends InheritedNotifier<AppSettingsStore> {
  const AppSettingsScope({
    super.key,
    required AppSettingsStore store,
    required super.child,
  }) : super(notifier: store);

  static AppSettingsStore? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    return scope?.notifier;
  }

  static AppSettingsStore of(BuildContext context) {
    final store = maybeOf(context);
    assert(store != null, 'AppSettingsScope is missing in the widget tree.');
    return store!;
  }
}
