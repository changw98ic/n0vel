import 'dart:async';
import 'dart:io';

import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';

/// Wraps a persistence operation with one retry and failure notification.
///
/// Use instead of raw `unawaited(_persist())` to ensure failed writes are
/// retried once (for transient I/O errors) and the user is notified when
/// persistence fails.
Future<void> safePersist(
  Future<void> Function() persistFn, {
  AppEventBus? eventBus,
}) async {
  try {
    await persistFn();
  } on FileSystemException catch (_) {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await persistFn();
    } catch (_) {
      _notifyFailure(eventBus);
    }
  } catch (_) {
    _notifyFailure(eventBus);
  }
}

void _notifyFailure(AppEventBus? eventBus) {
  try {
    eventBus?.publish(const NotificationRequestedEvent(
      title: '数据保存失败',
      message: '部分更改未能保存，请尝试重新操作。',
      severity: AppNoticeSeverity.error,
    ));
  } on StateError {
    // Event bus may be disposed.
  }
}
