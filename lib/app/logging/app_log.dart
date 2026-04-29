import 'package:flutter/foundation.dart';

/// Lightweight debug-only logger.
///
/// All calls compile to no-ops in release builds.
class AppLog {
  AppLog._();

  static void d(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint(_format('DEBUG', tag, message));
    }
  }

  static void w(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint(_format('WARN', tag, message));
    }
  }

  static void e(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      final suffix = error != null ? ': $error' : '';
      debugPrint(_format('ERROR', tag, '$message$suffix'));
    }
  }

  static String _format(String level, String? tag, String message) {
    final prefix = tag != null ? '$level [$tag]' : level;
    return '$prefix $message';
  }
}
