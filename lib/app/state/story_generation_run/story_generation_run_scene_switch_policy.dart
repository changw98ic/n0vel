part of '../story_generation_run_store.dart';

enum StoryGenerationRunSceneSwitchAction { ignore, switchScene, cancelRun }

class StoryGenerationRunSceneSwitchDecision {
  const StoryGenerationRunSceneSwitchDecision({
    required this.action,
    required this.nextSceneScopeId,
  });

  final StoryGenerationRunSceneSwitchAction action;
  final String nextSceneScopeId;

  bool get shouldSwitchScene =>
      action != StoryGenerationRunSceneSwitchAction.ignore;
}

/// Decides whether a visible scene-scope change should cancel an active run.
class StoryGenerationRunSceneSwitchPolicy {
  const StoryGenerationRunSceneSwitchPolicy();

  StoryGenerationRunSceneSwitchDecision decide({
    required String currentSceneScopeId,
    required String nextSceneScopeId,
    required StoryGenerationRunStatus currentStatus,
    required bool hasActiveRunForCurrentScene,
  }) {
    if (nextSceneScopeId == currentSceneScopeId) {
      return StoryGenerationRunSceneSwitchDecision(
        action: StoryGenerationRunSceneSwitchAction.ignore,
        nextSceneScopeId: nextSceneScopeId,
      );
    }
    if (currentStatus == StoryGenerationRunStatus.running &&
        hasActiveRunForCurrentScene) {
      return StoryGenerationRunSceneSwitchDecision(
        action: StoryGenerationRunSceneSwitchAction.cancelRun,
        nextSceneScopeId: nextSceneScopeId,
      );
    }
    return StoryGenerationRunSceneSwitchDecision(
      action: StoryGenerationRunSceneSwitchAction.switchScene,
      nextSceneScopeId: nextSceneScopeId,
    );
  }
}
