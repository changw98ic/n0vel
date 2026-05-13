/// Typed domain events for cross-module communication.
///
/// Modules publish these events through [AppEventBus] to decouple
/// direct store-to-store references. Each event carries only the
/// minimal data consumers need — no store references.
sealed class AppDomainEvent {
  const AppDomainEvent();
}

// ---------------------------------------------------------------------------
// Workspace / project lifecycle
// ---------------------------------------------------------------------------

/// Fired after the active project changes (user selects, creates, or opens).
class ProjectScopeChangedEvent extends AppDomainEvent {
  const ProjectScopeChangedEvent({
    required this.projectId,
    required this.sceneScopeId,
  });

  final String projectId;
  final String sceneScopeId;
}

/// Fired when a new project is created.
class ProjectCreatedEvent extends AppDomainEvent {
  const ProjectCreatedEvent({required this.projectId});

  final String projectId;
}

/// Fired when a project is deleted.
class ProjectDeletedEvent extends AppDomainEvent {
  const ProjectDeletedEvent({required this.projectId});

  final String projectId;
}

// ---------------------------------------------------------------------------
// Scene navigation
// ---------------------------------------------------------------------------

/// Fired when the active scene changes within a project.
class SceneChangedEvent extends AppDomainEvent {
  const SceneChangedEvent({
    required this.projectId,
    required this.sceneId,
    required this.sceneScopeId,
  });

  final String projectId;
  final String sceneId;
  final String sceneScopeId;
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

/// Fired after LLM settings are successfully saved.
class SettingsSavedEvent extends AppDomainEvent {
  const SettingsSavedEvent({required this.providerName, required this.model});

  final String providerName;
  final String model;
}

// ---------------------------------------------------------------------------
// Draft editing
// ---------------------------------------------------------------------------

/// 草稿文本更新事件，用于驱动写作统计增量更新。
class DraftUpdatedEvent extends AppDomainEvent {
  const DraftUpdatedEvent({
    required this.projectId,
    required this.sceneScopeId,
    required this.previousText,
    required this.currentText,
  });

  final String projectId;
  final String sceneScopeId;
  final String previousText;
  final String currentText;

  /// 去除空白后的字符增量（正数 = 新增，负数 = 删除）。
  int get charDelta {
    final prevLen = _countNonWhitespace(previousText);
    final currLen = _countNonWhitespace(currentText);
    return currLen - prevLen;
  }

  static int _countNonWhitespace(String value) {
    var count = 0;
    for (final codeUnit in value.codeUnits) {
      if (codeUnit != 0x20 &&
          codeUnit != 0x09 &&
          codeUnit != 0x0A &&
          codeUnit != 0x0D &&
          codeUnit != 0x0B &&
          codeUnit != 0x0C) {
        count++;
      }
    }
    return count;
  }
}

// ---------------------------------------------------------------------------
// Story generation
// ---------------------------------------------------------------------------

/// Fired when a story generation session starts.
class StoryGenerationStartedEvent extends AppDomainEvent {
  const StoryGenerationStartedEvent({
    required this.projectId,
    required this.sceneId,
  });

  final String projectId;
  final String sceneId;
}

/// Fired when a story generation session completes.
class StoryGenerationCompletedEvent extends AppDomainEvent {
  const StoryGenerationCompletedEvent({
    required this.projectId,
    required this.sceneId,
  });

  final String projectId;
  final String sceneId;
}

/// Fired when a story generation session fails.
class StoryGenerationFailedEvent extends AppDomainEvent {
  const StoryGenerationFailedEvent({
    required this.projectId,
    required this.sceneId,
    required this.error,
  });

  final String projectId;
  final String sceneId;
  final String error;
}

/// Fired when a story generation session is cancelled by the author.
class StoryGenerationCancelledEvent extends AppDomainEvent {
  const StoryGenerationCancelledEvent({
    required this.projectId,
    required this.sceneId,
  });

  final String projectId;
  final String sceneId;
}

// ---------------------------------------------------------------------------
// User feedback notifications
// ---------------------------------------------------------------------------

/// Fired to request a transient toast-style notification shown to the user.
class NotificationRequestedEvent extends AppDomainEvent {
  const NotificationRequestedEvent({
    required this.title,
    this.message,
    this.severity = AppNoticeSeverity.info,
    this.duration = const Duration(seconds: 4),
  });

  final String title;
  final String? message;
  final AppNoticeSeverity severity;
  final Duration duration;
}

/// Severity levels for notifications, shared with [AppNoticeBanner].
enum AppNoticeSeverity { error, warning, info, success }
