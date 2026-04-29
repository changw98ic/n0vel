import 'package:flutter/widgets.dart';

import 'app_event_bus.dart';

/// InheritedWidget that provides an [AppEventBus] down the widget tree.
///
/// Usage:
/// ```dart
/// AppEventBusScope(
///   bus: myEventBus,
///   child: MaterialApp(...),
/// )
/// ```
///
/// Descendants access the bus via:
/// ```dart
/// final bus = AppEventBusScope.of(context);
/// ```
class AppEventBusScope extends InheritedWidget {
  const AppEventBusScope({
    super.key,
    required this.bus,
    required super.child,
  });

  final AppEventBus bus;

  static AppEventBus of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppEventBusScope>();
    assert(scope != null, 'AppEventBusScope is missing in the widget tree.');
    return scope!.bus;
  }

  static AppEventBus? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppEventBusScope>()
        ?.bus;
  }

  @override
  bool updateShouldNotify(AppEventBusScope oldWidget) => bus != oldWidget.bus;
}
