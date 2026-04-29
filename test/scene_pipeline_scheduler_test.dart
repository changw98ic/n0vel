import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_scheduler.dart';

void main() {
  test(
    'starts the next scene only after the previous scene enters review',
    () async {
      final scheduler = ScenePipelineScheduler<String, String>(
        maxConcurrentScenes: 2,
      );
      final started = <String>[];
      final firstReviewStarted = Completer<void>();
      final firstFinished = Completer<void>();
      final secondFinished = Completer<void>();

      final future = scheduler.run(
        scenes: const ['scene-01', 'scene-02'],
        runScene: (scene, {required onReviewStarted}) async {
          started.add(scene);
          if (scene == 'scene-01') {
            onReviewStarted();
            firstReviewStarted.complete();
            await firstFinished.future;
            return 'result-01';
          }
          await secondFinished.future;
          return 'result-02';
        },
      );

      await firstReviewStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(started, const ['scene-01', 'scene-02']);

      secondFinished.complete();
      firstFinished.complete();

      expect(await future, const ['result-01', 'result-02']);
    },
  );

  test('respects the active scene concurrency limit', () async {
    final scheduler = ScenePipelineScheduler<String, String>(
      maxConcurrentScenes: 2,
    );
    final started = <String>[];
    final firstFinished = Completer<void>();
    final secondFinished = Completer<void>();
    final thirdFinished = Completer<void>();

    final future = scheduler.run(
      scenes: const ['scene-01', 'scene-02', 'scene-03'],
      runScene: (scene, {required onReviewStarted}) async {
        started.add(scene);
        onReviewStarted();
        if (scene == 'scene-01') {
          await firstFinished.future;
          return 'result-01';
        }
        if (scene == 'scene-02') {
          await secondFinished.future;
          return 'result-02';
        }
        await thirdFinished.future;
        return 'result-03';
      },
    );

    await Future<void>.delayed(Duration.zero);

    expect(started, const ['scene-01', 'scene-02']);

    firstFinished.complete();
    await Future<void>.delayed(Duration.zero);

    expect(started, const ['scene-01', 'scene-02', 'scene-03']);

    secondFinished.complete();
    thirdFinished.complete();

    expect(await future, const ['result-01', 'result-02', 'result-03']);
  });
}
