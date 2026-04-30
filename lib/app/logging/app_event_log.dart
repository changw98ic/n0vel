import 'package:flutter/widgets.dart';

import 'app_event_log_storage.dart';
import 'app_event_log_types.dart';
import 'app_log.dart';

export 'app_event_log_types.dart';

typedef AppEventLogNowProvider = DateTime Function();

class AppEventLog {
  AppEventLog({
    AppEventLogStorage? storage,
    String? sessionId,
    AppEventLogNowProvider? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now,
       _storage =
           storage ?? debugStorageOverride ?? createDefaultAppEventLogStorage(),
       sessionId =
           sessionId ?? _generateId('session', (nowProvider ?? DateTime.now)());

  @visibleForTesting
  static AppEventLogStorage? debugStorageOverride;

  final AppEventLogNowProvider _nowProvider;
  final AppEventLogStorage _storage;
  final String sessionId;

  Future<void> write(AppEventLogEntry entry) {
    return _storage.write(entry);
  }

  Future<void> logBestEffort({
    required AppEventLogLevel level,
    required AppEventLogCategory category,
    required String action,
    required AppEventLogStatus status,
    required String message,
    String? correlationId,
    String? projectId,
    String? sceneId,
    String? errorCode,
    String? errorDetail,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    try {
      await log(
        level: level,
        category: category,
        action: action,
        status: status,
        message: message,
        correlationId: correlationId,
        projectId: projectId,
        sceneId: sceneId,
        errorCode: errorCode,
        errorDetail: errorDetail,
        metadata: metadata,
      );
    } catch (error) {
      AppLog.e('logBestEffort swallowed error', tag: 'EventLog', error: error);
    }
  }

  String newCorrelationId([String prefix = 'corr']) {
    return _generateId(prefix, _nowProvider());
  }

  Future<void> log({
    required AppEventLogLevel level,
    required AppEventLogCategory category,
    required String action,
    required AppEventLogStatus status,
    required String message,
    String? correlationId,
    String? projectId,
    String? sceneId,
    String? errorCode,
    String? errorDetail,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    final now = _nowProvider();
    return write(
      AppEventLogEntry(
        eventId: _generateId('evt', now),
        timestampMs: now.millisecondsSinceEpoch,
        level: level,
        category: category,
        action: action,
        status: status,
        sessionId: sessionId,
        correlationId: correlationId,
        projectId: projectId,
        sceneId: sceneId,
        message: message,
        errorCode: errorCode,
        errorDetail: errorDetail,
        metadata: metadata,
      ),
    );
  }

  Future<void> info({
    required AppEventLogCategory category,
    required String action,
    required String message,
    String? correlationId,
    String? projectId,
    String? sceneId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return log(
      level: AppEventLogLevel.info,
      category: category,
      action: action,
      status: AppEventLogStatus.succeeded,
      message: message,
      correlationId: correlationId,
      projectId: projectId,
      sceneId: sceneId,
      metadata: metadata,
    );
  }
}

class AppEventLogScope extends InheritedWidget {
  const AppEventLogScope({super.key, required this.log, required super.child});

  final AppEventLog log;

  static AppEventLog? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppEventLogScope>();
    return scope?.log;
  }

  static AppEventLog of(BuildContext context) {
    final log = maybeOf(context);
    assert(log != null, 'AppEventLogScope is missing in the widget tree.');
    return log!;
  }

  @override
  bool updateShouldNotify(AppEventLogScope oldWidget) {
    return log != oldWidget.log;
  }
}

int _lastGeneratedIdMicros = -1;
int _lastGeneratedIdSequence = -1;

String _generateId(String prefix, DateTime now) {
  final micros = now.microsecondsSinceEpoch;
  if (micros == _lastGeneratedIdMicros) {
    _lastGeneratedIdSequence += 1;
  } else {
    _lastGeneratedIdMicros = micros;
    _lastGeneratedIdSequence = 0;
  }

  return '$prefix-$micros-${_lastGeneratedIdSequence.toRadixString(36)}';
}
