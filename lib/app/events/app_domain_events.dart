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
  const SettingsSavedEvent({
    required this.providerName,
    required this.model,
  });

  final String providerName;
  final String model;
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
enum AppNoticeSeverity {
  error,
  warning,
  info,
  success,
}
