import 'app_event_log_storage.dart';
import 'app_event_log_types.dart';

AppEventLogStorage createAppEventLogStorage({
  String? sqlitePath,
  Object? logsDirectory,
}) {
  return _NoopAppEventLogStorage();
}

class _NoopAppEventLogStorage
    implements
        AppEventLogStorage,
        AppEventLogMaintenance,
        AppEventLogStorageLifecycle {
  @override
  Future<void> write(AppEventLogEntry entry) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> pruneBefore(DateTime cutoff) async {}

  @override
  Future<void> flush() => Future<void>.value();

  @override
  void dispose() {}
}
