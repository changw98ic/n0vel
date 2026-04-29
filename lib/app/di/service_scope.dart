import 'package:flutter/widgets.dart';

import 'service_registry.dart';

/// InheritedWidget that provides a [ServiceRegistry] to the widget tree.
///
/// Usage:
/// ```dart
/// ServiceScope(
///   registry: myRegistry,
///   child: MaterialApp(...),
/// )
/// ```
///
/// Then in any descendant:
/// ```dart
/// final store = ServiceScope.of(context).resolve<AppWorkspaceStore>();
/// ```
class ServiceScope extends InheritedWidget {
  const ServiceScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final ServiceRegistry registry;

  static ServiceRegistry of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ServiceScope>();
    assert(scope != null, 'ServiceScope is missing in the widget tree.');
    return scope!.registry;
  }

  @override
  bool updateShouldNotify(ServiceScope oldWidget) =>
      registry != oldWidget.registry;
}
