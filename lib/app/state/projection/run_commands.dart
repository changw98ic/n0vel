import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/app_providers.dart';
import '../story_generation_run_store.dart';

/// Minimal target API used by [StoryGenerationRunCommands].
///
/// Keeping this boundary small lets tests verify command delegation without
/// starting the real generation pipeline.
abstract interface class RunCommandTarget {
  String get activeSceneScopeId;

  Future<void> runCurrentScene();
  Future<Map<String, Object?>> exportProjectJson();
  Future<void> importProjectJson(Map<String, Object?> data);
  Future<bool> cancelCurrentRun();
}

/// [RunCommandTarget] adapter backed by [StoryGenerationRunStore].
class StoryGenerationRunCommandTarget implements RunCommandTarget {
  const StoryGenerationRunCommandTarget(this._store);

  final StoryGenerationRunStore _store;

  @override
  String get activeSceneScopeId => _store.activeSceneScopeId;

  @override
  Future<void> runCurrentScene() => _store.runCurrentScene();

  @override
  Future<Map<String, Object?>> exportProjectJson() =>
      _store.exportProjectJson();

  @override
  Future<void> importProjectJson(Map<String, Object?> data) =>
      _store.importProjectJson(data);

  @override
  Future<bool> cancelCurrentRun() => _store.cancelCurrentRun();
}

/// Command facade for run workflow operations.
///
/// Provides a limited, stable interface for UI to trigger run workflows
/// without depending on the full mutable [StoryGenerationRunStore] API.
/// This is a thin facade that delegates to the existing store behavior.
abstract interface class RunCommands {
  /// Starts a new run for the current scene.
  Future<void> runCurrentScene();

  /// Retries a recovered run by starting a new run for the current scene.
  Future<void> retryRecoveredRun();

  /// Discards the recovered run for the active scene scope.
  ///
  /// Exports run snapshots, removes only the active scene-scope snapshot,
  /// then imports the remaining run snapshot map. This preserves the
  /// existing Workbench behavior.
  Future<void> discardRecoveredRun();

  /// Cancels the currently active run.
  ///
  /// Returns `true` if cancellation occurred, `false` if there was no
  /// active run to cancel.
  Future<bool> cancelCurrentRun();
}

/// Implementation of [RunCommands] that delegates to [RunCommandTarget].
class StoryGenerationRunCommands implements RunCommands {
  const StoryGenerationRunCommands(this._target);

  final RunCommandTarget _target;

  @override
  Future<void> runCurrentScene() => _target.runCurrentScene();

  @override
  Future<void> retryRecoveredRun() => _target.runCurrentScene();

  @override
  Future<void> discardRecoveredRun() async {
    // Preserve the existing Workbench discard logic from
    // WorkbenchOrchestrator.discardRecoveredRun():
    // 1. Export all run snapshots
    final exported = await _target.exportProjectJson();
    final rawRunsByScope = exported['sceneRunsByScope'];
    final sceneRunsByScope = <String, Object?>{};

    // 2. Filter out the active scene scope
    if (rawRunsByScope is Map) {
      for (final entry in rawRunsByScope.entries) {
        final sceneScopeId = entry.key.toString();
        if (sceneScopeId != _target.activeSceneScopeId) {
          sceneRunsByScope[sceneScopeId] = entry.value;
        }
      }
    }

    // 3. Import the filtered snapshot map (active run is cleared)
    await _target.importProjectJson({
      'projectId': exported['projectId'],
      'sceneRunsByScope': sceneRunsByScope,
    });
  }

  @override
  Future<bool> cancelCurrentRun() => _target.cancelCurrentRun();
}

/// Provider for [RunCommands] that reads the native run store.
///
/// Uses `ref.read` because the command facade itself has no state
/// to rebuild. Commands are invoked for their side effects, not
/// for returning state.
final runCommandsProvider = Provider<RunCommands>((ref) {
  final runStore = ref.read(storyGenerationRunStoreProvider);
  return StoryGenerationRunCommands(StoryGenerationRunCommandTarget(runStore));
});
