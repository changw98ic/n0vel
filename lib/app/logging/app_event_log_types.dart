enum AppEventLogLevel { debug, info, warn, error }

enum AppEventLogCategory {
  app,
  settings,
  ai,
  persistence,
  importExport,
  ui,
  simulation,
  storyMemory,
}

enum AppEventLogStatus { started, succeeded, failed, cancelled, warning }

class AppEventLogEntry {
  const AppEventLogEntry({
    required this.eventId,
    required this.timestampMs,
    required this.level,
    required this.category,
    required this.action,
    required this.status,
    required this.sessionId,
    required this.message,
    this.correlationId,
    this.projectId,
    this.sceneId,
    this.errorCode,
    this.errorDetail,
    this.metadata = const <String, Object?>{},
  });

  final String eventId;
  final int timestampMs;
  final AppEventLogLevel level;
  final AppEventLogCategory category;
  final String action;
  final AppEventLogStatus status;
  final String sessionId;
  final String? correlationId;
  final String? projectId;
  final String? sceneId;
  final String message;
  final String? errorCode;
  final String? errorDetail;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'eventId': eventId,
      'timestampMs': timestampMs,
      'level': level.name,
      'category': _categoryName(category),
      'action': action,
      'status': status.name,
      'sessionId': sessionId,
      'correlationId': correlationId,
      'projectId': projectId,
      'sceneId': sceneId,
      'message': message,
      'errorCode': errorCode,
      'errorDetail': errorDetail,
      'metadata': metadata,
    };
  }
}

String appEventLogCategoryName(AppEventLogCategory category) {
  return _categoryName(category);
}

String _categoryName(AppEventLogCategory category) {
  switch (category) {
    case AppEventLogCategory.app:
      return 'app';
    case AppEventLogCategory.settings:
      return 'settings';
    case AppEventLogCategory.ai:
      return 'ai';
    case AppEventLogCategory.persistence:
      return 'persistence';
    case AppEventLogCategory.importExport:
      return 'import_export';
    case AppEventLogCategory.ui:
      return 'ui';
    case AppEventLogCategory.simulation:
      return 'simulation';
    case AppEventLogCategory.storyMemory:
      return 'story_memory';
  }
}
