import 'dart:async';

typedef ScenePipelineSceneRunner<TScene, TResult> =
    Future<TResult> Function(
      TScene scene, {
      required void Function() onSpeculationReady,
    });

typedef ScenePipelineResultGate<TResult> = bool Function(TResult result);

class ScenePipelineScheduler<TScene, TResult> {
  const ScenePipelineScheduler({
    this.maxConcurrentScenes = 2,
    this.canCommitResult,
  });

  final int maxConcurrentScenes;
  final ScenePipelineResultGate<TResult>? canCommitResult;

  Future<List<TResult>> run({
    required List<TScene> scenes,
    required ScenePipelineSceneRunner<TScene, TResult> runScene,
  }) async {
    if (scenes.isEmpty) {
      return <TResult>[];
    }

    final sceneConcurrencyLimit = maxConcurrentScenes
        .clamp(1, scenes.length)
        .toInt();
    final results = <int, TResult>{};
    final completion = Completer<List<TResult>>();
    var nextSceneIndex = 0;
    var startAllowedThrough = 0;
    var activeScenes = 0;
    var completedScenes = 0;
    var committedThrough = -1;
    int? blockedAtIndex;
    final releaseRequests = <int>{};
    late void Function() maybeStartNextScene;

    bool resultCanCommit(TResult result) {
      return canCommitResult?.call(result) ?? true;
    }

    bool hasResultsThrough(int index) {
      for (var i = 0; i <= index; i += 1) {
        if (!results.containsKey(i)) {
          return false;
        }
      }
      return true;
    }

    List<TResult> orderedResults({int? throughIndex}) {
      final endExclusive = throughIndex == null
          ? scenes.length
          : (throughIndex + 1).clamp(0, scenes.length).toInt();
      return [
        for (var index = 0; index < endExclusive; index += 1)
          if (results.containsKey(index))
            results[index] as TResult
          else
            throw StateError('Scene pipeline missing result for index $index.'),
      ];
    }

    void maybeCompleteBlockedPrefix() {
      final blockedIndex = blockedAtIndex;
      if (blockedIndex == null || completion.isCompleted) {
        return;
      }
      if (hasResultsThrough(blockedIndex)) {
        completion.complete(orderedResults(throughIndex: blockedIndex));
      }
    }

    void advanceCommittedThrough() {
      while (true) {
        final nextIndex = committedThrough + 1;
        final result = results[nextIndex];
        if (result == null || !resultCanCommit(result)) {
          return;
        }
        committedThrough = nextIndex;
      }
    }

    bool canApplyReleaseRequest(int sceneIndex) {
      return blockedAtIndex == null || sceneIndex < blockedAtIndex!;
    }

    void applyReleaseRequests() {
      var advanced = false;
      while (releaseRequests.contains(startAllowedThrough) &&
          canApplyReleaseRequest(startAllowedThrough)) {
        releaseRequests.remove(startAllowedThrough);
        startAllowedThrough += 1;
        advanced = true;
      }
      if (advanced && !completion.isCompleted) {
        maybeStartNextScene();
      }
    }

    void requestReleaseNextScene(int sceneIndex) {
      releaseRequests.add(sceneIndex);
      applyReleaseRequests();
    }

    maybeStartNextScene = () {
      if (completion.isCompleted) {
        return;
      }
      while (nextSceneIndex < scenes.length &&
          nextSceneIndex <= startAllowedThrough &&
          (blockedAtIndex == null || nextSceneIndex <= blockedAtIndex!) &&
          activeScenes < sceneConcurrencyLimit) {
        final sceneIndex = nextSceneIndex;
        nextSceneIndex += 1;
        activeScenes += 1;
        var releasedNextScene = false;

        void releaseNextScene() {
          if (releasedNextScene) {
            return;
          }
          releasedNextScene = true;
          requestReleaseNextScene(sceneIndex);
        }

        unawaited(() async {
          try {
            final result = await runScene(
              scenes[sceneIndex],
              onSpeculationReady: releaseNextScene,
            );
            results[sceneIndex] = result;
            if (resultCanCommit(result)) {
              advanceCommittedThrough();
              requestReleaseNextScene(sceneIndex);
            } else if (blockedAtIndex == null || sceneIndex < blockedAtIndex!) {
              blockedAtIndex = sceneIndex;
            }
            maybeCompleteBlockedPrefix();
          } catch (error, stackTrace) {
            if (!completion.isCompleted) {
              completion.completeError(error, stackTrace);
            }
            return;
          } finally {
            activeScenes -= 1;
            completedScenes += 1;
            if (!completion.isCompleted) {
              maybeStartNextScene();
            }
            if (completedScenes == scenes.length && !completion.isCompleted) {
              final blockedIndex = blockedAtIndex;
              completion.complete(
                blockedIndex == null
                    ? orderedResults()
                    : orderedResults(throughIndex: blockedIndex),
              );
            }
          }
        }());
      }
    };

    maybeStartNextScene();
    return completion.future;
  }
}
