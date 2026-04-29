import 'app_event_log_storage_stub.dart'
    if (dart.library.io) 'app_event_log_storage_io.dart';
import 'app_event_log_types.dart';

abstract class AppEventLogStorage {
  Future<void> write(AppEventLogEntry entry);
}

AppEventLogStorage createDefaultAppEventLogStorage() =>
    createAppEventLogStorage();

AppEventLogStorage createTestAppEventLogStorage({
  String? sqlitePath,
  Object? logsDirectory,
}) {
  return createAppEventLogStorage(
    sqlitePath: sqlitePath,
    logsDirectory: logsDirectory,
  );
}
