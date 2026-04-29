import 'app_event_log_storage.dart';
import 'app_event_log_types.dart';

AppEventLogStorage createAppEventLogStorage({
  String? sqlitePath,
  Object? logsDirectory,
}) {
  return _NoopAppEventLogStorage();
}

class _NoopAppEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) async {}
}
