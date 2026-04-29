import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';

void main() {
  test(
    'app event log generates and reuses one session id across writes',
    () async {
      final storage = _RecordingAppEventLogStorage();
      final log = AppEventLog(storage: storage);

      await log.info(
        category: AppEventLogCategory.app,
        action: 'app.started',
        message: 'boot',
      );
      await log.info(
        category: AppEventLogCategory.ui,
        action: 'ui.clicked',
        message: 'clicked',
      );

      expect(storage.entries, hasLength(2));
      expect(storage.entries.first.sessionId, isNotEmpty);
      expect(storage.entries.map((entry) => entry.sessionId).toSet(), {
        log.sessionId,
      });
    },
  );

  test('app event log reuses one session id across writes', () async {
    final storage = _RecordingAppEventLogStorage();
    final log = AppEventLog(storage: storage, sessionId: 'session-1');

    await log.info(
      category: AppEventLogCategory.app,
      action: 'app.started',
      message: 'boot',
    );
    await log.info(
      category: AppEventLogCategory.ui,
      action: 'ui.clicked',
      message: 'clicked',
      correlationId: 'corr-1',
      metadata: {'surface': 'toolbar'},
    );

    expect(storage.entries, hasLength(2));
    expect(storage.entries.map((entry) => entry.sessionId).toSet(), {
      'session-1',
    });
    expect(storage.entries.first.status, AppEventLogStatus.succeeded);
    expect(storage.entries.last.correlationId, 'corr-1');
    expect(storage.entries.last.metadata, {'surface': 'toolbar'});
  });

  test('app event log write forwards explicit entries unchanged', () async {
    final storage = _RecordingAppEventLogStorage();
    final log = AppEventLog(storage: storage, sessionId: 'session-1');
    const entry = AppEventLogEntry(
      eventId: 'evt-explicit',
      timestampMs: 42,
      level: AppEventLogLevel.warn,
      category: AppEventLogCategory.settings,
      action: 'settings.save.warning',
      status: AppEventLogStatus.warning,
      sessionId: 'session-override',
      message: 'Settings saved with warning.',
      metadata: {'issue': 'fileWriteFailed'},
    );

    await log.write(entry);

    expect(storage.entries, [entry]);
  });

  test(
    'app event log generates distinct event ids when multiple writes share one clock tick',
    () async {
      final storage = _RecordingAppEventLogStorage();
      final fixedNow = DateTime.fromMillisecondsSinceEpoch(1234567890);
      final log = AppEventLog(
        storage: storage,
        sessionId: 'session-1',
        nowProvider: () => fixedNow,
      );

      await log.info(
        category: AppEventLogCategory.ai,
        action: 'ai.chat.request',
        message: 'first',
      );
      await log.info(
        category: AppEventLogCategory.ai,
        action: 'ai.chat.request',
        message: 'second',
      );

      expect(storage.entries, hasLength(2));
      expect(
        storage.entries.map((entry) => entry.eventId).toSet(),
        hasLength(2),
      );
      expect(storage.entries.map((entry) => entry.timestampMs).toSet(), {
        fixedNow.millisecondsSinceEpoch,
      });
    },
  );
}

class _RecordingAppEventLogStorage implements AppEventLogStorage {
  final List<AppEventLogEntry> entries = <AppEventLogEntry>[];

  @override
  Future<void> write(AppEventLogEntry entry) async {
    entries.add(entry);
  }
}
