part of '../story_generation_run_store.dart';

/// Owns event-bus subscriptions that affect run-store scene/project scope.
///
/// Keeping subscription wiring here lets [StoryGenerationRunStore] focus on
/// visible run state transitions instead of stream lifecycle bookkeeping.
class StoryGenerationRunEventSubscriptions {
  StoryGenerationRunEventSubscriptions({
    required AppEventBus? eventBus,
    required void Function(ProjectDeletedEvent event) onProjectDeleted,
    required void Function(String sceneScopeId) onSceneScopeChanged,
  }) {
    _projectDeletedSubscription = eventBus?.listen<ProjectDeletedEvent>(
      onProjectDeleted,
    );
    _sceneChangedSubscription = eventBus?.listen<SceneChangedEvent>(
      (event) => onSceneScopeChanged(event.sceneScopeId),
    );
    _projectScopeChangedSubscription = eventBus
        ?.listen<ProjectScopeChangedEvent>(
          (event) => onSceneScopeChanged(event.sceneScopeId),
        );
  }

  StreamSubscription<ProjectDeletedEvent>? _projectDeletedSubscription;
  StreamSubscription<SceneChangedEvent>? _sceneChangedSubscription;
  StreamSubscription<ProjectScopeChangedEvent>?
  _projectScopeChangedSubscription;

  void dispose() {
    unawaited(_projectDeletedSubscription?.cancel());
    unawaited(_sceneChangedSubscription?.cancel());
    unawaited(_projectScopeChangedSubscription?.cancel());
    _projectDeletedSubscription = null;
    _sceneChangedSubscription = null;
    _projectScopeChangedSubscription = null;
  }
}
