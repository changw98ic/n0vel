import 'dart:async';

typedef ScenePipelineSceneRunner<TScene, TResult> =
    Future<TResult> Function(
      TScene scene, {
      required void Function() onReviewStarted,
    });

class ScenePipelineScheduler<TScene, TResult> {
  const ScenePipelineScheduler({this.maxConcurrentScenes = 2});

  final int maxConcurrentScenes;

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

    List<TResult> orderedResults() {
      return [
        for (var index = 0; index < scenes.length; index += 1)
          if (results.containsKey(index))
            results[index] as TResult
          else
            throw StateError('Scene pipeline missing result for index $index.'),
      ];
    }

    void maybeStartNextScene() {
      if (completion.isCompleted) {
        return;
      }
      while (nextSceneIndex < scenes.length &&
          nextSceneIndex <= startAllowedThrough &&
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
          if (startAllowedThrough < sceneIndex + 1) {
            startAllowedThrough = sceneIndex + 1;
          }
          maybeStartNextScene();
        }

        unawaited(() async {
          try {
            results[sceneIndex] = await runScene(
              scenes[sceneIndex],
              onReviewStarted: releaseNextScene,
            );
            releaseNextScene();
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
              completion.complete(orderedResults());
            }
          }
        }());
      }
    }

    maybeStartNextScene();
    return completion.future;
  }
}
