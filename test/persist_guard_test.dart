import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/events/app_domain_events.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/state/persist_guard.dart';

void main() {
  group('safePersist', () {
    test('succeeds when persistFn completes without error', () async {
      var callCount = 0;
      await safePersist(() async {
        callCount++;
      });

      expect(callCount, 1);
    });

    test('retries once on FileSystemException then succeeds', () async {
      var callCount = 0;
      await safePersist(() async {
        callCount++;
        if (callCount == 1) throw const FileSystemException('transient');
      });

      expect(callCount, 2);
    });

    test('notifies via event bus after second I/O failure', () async {
      final bus = AppEventBus();
      NotificationRequestedEvent? notification;
      final sub = bus.on<NotificationRequestedEvent>().listen((e) {
        notification = e;
      });

      var callCount = 0;
      await safePersist(() async {
        callCount++;
        throw const FileSystemException('persistent');
      }, eventBus: bus);

      expect(callCount, 2);
      expect(notification, isNotNull);
      expect(notification!.title, '数据保存失败');
      expect(notification!.severity, AppNoticeSeverity.error);

      await sub.cancel();
      bus.dispose();
    });

    test('does not retry non-I/O failures and notifies', () async {
      final bus = AppEventBus();
      NotificationRequestedEvent? notification;
      final sub = bus.on<NotificationRequestedEvent>().listen((event) {
        notification = event;
      });

      var callCount = 0;
      await safePersist(() async {
        callCount++;
        throw StateError('programming failure');
      }, eventBus: bus);

      expect(callCount, 1);
      expect(notification, isNotNull);

      await sub.cancel();
      bus.dispose();
    });

    test('does not notify when event bus is null', () async {
      // Should complete without throwing.
      await safePersist(
        () async => throw Exception('persistent'),
        eventBus: null,
      );
    });

    test('does not notify when event bus is disposed', () async {
      final bus = AppEventBus();
      bus.dispose();

      // Should complete without throwing despite disposed bus.
      await safePersist(
        () async => throw Exception('persistent'),
        eventBus: bus,
      );
    });

    test(
      'does not notify when first I/O attempt fails but retry succeeds',
      () async {
        final bus = AppEventBus();
        var notified = false;
        final sub = bus.on<NotificationRequestedEvent>().listen((_) {
          notified = true;
        });

        var callCount = 0;
        await safePersist(() async {
          callCount++;
          if (callCount == 1) {
            throw const FileSystemException('transient');
          }
        }, eventBus: bus);

        expect(callCount, 2);
        expect(notified, isFalse);

        await sub.cancel();
        bus.dispose();
      },
    );
  });
}
