import 'package:flutter/material.dart';

import '../state/app_simulation_store.dart';

abstract final class AppRoutes {
  static const String shelf = 'shelf';
  static const String workbench = 'workbench';
  static const String settings = 'settings';
  static const String characters = 'characters';
  static const String worldbuilding = 'worldbuilding';
  static const String scenes = 'scenes';
  static const String style = 'style';
  static const String storyBible = 'story_bible';
  static const String audit = 'audit';
  static const String importExport = 'import_export';
  static const String productionBoard = 'production_board';
  static const String reviewTasks = 'review_tasks';
  static const String versions = 'versions';
  static const String reading = 'reading';
  static const String sandbox = 'sandbox';
}

class SandboxRouteArgs {
  const SandboxRouteArgs({this.failureMode = false, this.previewStatus});

  final bool failureMode;
  final SimulationStatus? previewStatus;
}

typedef AppRouteBuilder =
    Widget Function(BuildContext context, Object? arguments);

class AppNavigator {
  static final Map<String, AppRouteBuilder> _routes = {};

  static void register(String name, AppRouteBuilder builder) {
    _routes[name] = builder;
  }

  static Future<void> push(
    BuildContext context,
    String name, {
    Object? arguments,
  }) {
    final builder = _routes[name];
    assert(builder != null, 'No route registered for "$name"');
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (ctx) => builder!(ctx, arguments)),
    );
  }
}
