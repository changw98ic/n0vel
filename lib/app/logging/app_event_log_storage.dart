import 'app_event_log_storage_stub.dart'
    if (dart.library.io) 'app_event_log_storage_io.dart';
import 'app_event_log_types.dart';

abstract class AppEventLogStorage {
  Future<void> write(AppEventLogEntry entry);
}

/// Optional maintenance operations for durable event-log sinks.
///
/// Kept separate from [AppEventLogStorage] so existing lightweight test and
/// Web fakes that only implement `write` remain source-compatible.
abstract interface class AppEventLogMaintenance {
  Future<void> clear();

  Future<void> pruneBefore(DateTime cutoff);
}

/// Optional lifecycle operations for durable event-log sinks.
abstract interface class AppEventLogStorageLifecycle {
  Future<void> flush();

  void dispose();
}

/// Compatibility helpers for callers that have only the base storage type.
/// Implementations without the optional maintenance capability remain no-op.
extension AppEventLogStorageMaintenance on AppEventLogStorage {
  Future<void> clear() {
    final maintenance = this;
    if (maintenance case final AppEventLogMaintenance sink) {
      return sink.clear();
    }
    return Future<void>.value();
  }

  Future<void> pruneBefore(DateTime cutoff) {
    final maintenance = this;
    if (maintenance case final AppEventLogMaintenance sink) {
      return sink.pruneBefore(cutoff);
    }
    return Future<void>.value();
  }
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
