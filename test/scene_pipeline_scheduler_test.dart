import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_scheduler.dart';

void main() {
  test(
    'starts the initial director window without waiting for release',
    () async {
      final scheduler = ScenePipelineScheduler<String, String>(
        maxConcurrentScenes: 2,
      );
      final started = <String>[];
      final secondStarted = Completer<void>();
      final firstCanRelease = Completer<void>();
      final firstFinished = Completer<void>();
      final secondFinished = Completer<void>();

      final future = scheduler.run(
        scenes: const ['scene-01', 'scene-02'],
        runScene: (scene, {required onSpeculationReady}) async {
          started.add(scene);
          if (scene == 'scene-01') {
            await firstCanRelease.future;
            onSpeculationReady();
            await firstFinished.future;
            return 'result-01';
          }
          secondStarted.complete();
          await secondFinished.future;
          return 'result-02';
        },
      );

      await secondStarted.future;

      expect(started, const ['scene-01', 'scene-02']);

      firstCanRelease.complete();
      secondFinished.complete();
      firstFinished.complete();

      expect(await future, const ['result-01', 'result-02']);
    },
  );

  test(
    'chains speculative releases without waiting for earlier scene commit',
    () async {
      final scheduler = ScenePipelineScheduler<String, String>(
        maxConcurrentScenes: 3,
      );
      final started = <String>[];
      final thirdStarted = Completer<void>();
      final finishers = <String, Completer<void>>{
        'scene-01': Completer<void>(),
        'scene-02': Completer<void>(),
        'scene-03': Completer<void>(),
      };

      final future = scheduler.run(
        scenes: const ['scene-01', 'scene-02', 'scene-03'],
        runScene: (scene, {required onSpeculationReady}) async {
          started.add(scene);
          if (scene == 'scene-03') {
            thirdStarted.complete();
          }
          if (scene == 'scene-01') {
            onSpeculationReady();
          }
          if (scene == 'scene-02') {
            onSpeculationReady();
          }
          await finishers[scene]!.future;
          return 'result-${scene.substring(scene.length - 2)}';
        },
      );

      await thirdStarted.future;

      expect(started, const ['scene-01', 'scene-02', 'scene-03']);

      for (final finisher in finishers.values) {
        finisher.complete();
      }

      expect(await future, const ['result-01', 'result-02', 'result-03']);
    },
  );

  test('respects the active scene concurrency limit', () async {
    final scheduler = ScenePipelineScheduler<String, String>(
      maxConcurrentScenes: 2,
    );
    final started = <String>[];
    final thirdStarted = Completer<void>();
    final firstCanRelease = Completer<void>();
    final firstFinished = Completer<void>();
    final secondFinished = Completer<void>();
    final thirdFinished = Completer<void>();

    final future = scheduler.run(
      scenes: const ['scene-01', 'scene-02', 'scene-03'],
      runScene: (scene, {required onSpeculationReady}) async {
        started.add(scene);
        if (scene == 'scene-03') {
          thirdStarted.complete();
        }
        if (scene == 'scene-01') {
          await firstCanRelease.future;
          onSpeculationReady();
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

    firstCanRelease.complete();
    await thirdStarted.future;

    expect(started, const ['scene-01', 'scene-02', 'scene-03']);

    firstFinished.complete();
    secondFinished.complete();
    thirdFinished.complete();

    expect(await future, const ['result-01', 'result-02', 'result-03']);
  });

  test(
    'discards already-started speculative scene results after an earlier scene fails the commit gate',
    () async {
      final scheduler = ScenePipelineScheduler<String, String>(
        maxConcurrentScenes: 2,
        canCommitResult: (result) => !result.startsWith('blocked'),
      );
      final started = <String>[];
      final thirdStarted = Completer<void>();
      final firstFinished = Completer<void>();
      final secondFinished = Completer<void>();

      final future = scheduler.run(
        scenes: const ['scene-01', 'scene-02', 'scene-03'],
        runScene: (scene, {required onSpeculationReady}) async {
          started.add(scene);
          if (scene == 'scene-03') {
            thirdStarted.complete();
          }
          if (scene == 'scene-01') {
            onSpeculationReady();
            await firstFinished.future;
            return 'blocked-01';
          }
          if (scene == 'scene-02') {
            await secondFinished.future;
            return 'result-02';
          }
          return 'result-03';
        },
      );

      await thirdStarted.future;
      expect(started, const ['scene-01', 'scene-02', 'scene-03']);

      secondFinished.complete();
      firstFinished.complete();

      expect(await future, const ['blocked-01']);
      expect(started, const ['scene-01', 'scene-02', 'scene-03']);
    },
  );
}
