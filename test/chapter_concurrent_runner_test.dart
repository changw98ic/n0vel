import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/chapter_concurrent_runner.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/domain/story_pipeline_interfaces.dart';

void main() {
  group('ChapterConcurrentRunner retry boundary', () {
    for (final failureCase in <String, Object Function()>{
      'content redraw blocked': () => ContentRedrawBlocked(
        stageId: 'review',
        reason: 'valid completion cannot be redrawn',
      ),
      'indeterminate provider failure': () =>
          TimeoutException('provider completion state is unknown'),
      'evidence sink failure': () =>
          StateError('attempt evidence envelope was not durable'),
    }.entries) {
      test(
        'no-content-redraw does not construct a second runner after ${failureCase.key}',
        () async {
          final settingsStore = AppSettingsStore(
            storage: InMemoryAppSettingsStorage(),
          );
          addTearDown(settingsStore.dispose);
          final evidenceDirectory = await Directory.systemTemp.createTemp(
            'chapter-no-redraw-evidence-',
          );
          final evidenceLog = PipelineEventLogImpl(
            jsonlPath: '${evidenceDirectory.path}/pipeline.jsonl',
          );
          addTearDown(() async {
            await evidenceLog.dispose();
            if (await evidenceDirectory.exists()) {
              await evidenceDirectory.delete(recursive: true);
            }
          });
          final brief = _brief();
          final failure = failureCase.value();
          final firstRunner = _StubSceneRunner(error: failure);
          final secondRunner = _StubSceneRunner(
            output: _output(brief, decision: SceneReviewDecision.pass),
          );
          final queuedRunners = <ChapterGenerationService>[
            firstRunner,
            secondRunner,
          ];
          var factoryCalls = 0;
          final runner = ChapterConcurrentRunner(
            settingsStore: settingsStore,
            pipelineConfig: const GenerationPipelineConfig(
              hardGatesEnabled: false,
              maxConcurrentScenes: 1,
              maxSceneRetries: 2,
              sceneContentRedrawPolicy:
                  SceneContentRedrawPolicy.noContentRedraw,
              evidenceRunId: 'chapter-concurrent-shared-evidence-v1',
            ),
            evidenceLog: evidenceLog,
            sceneRunnerFactory: () {
              expect(PipelineEvidenceLogScope.current, same(evidenceLog));
              final next = queuedRunners[factoryCalls];
              factoryCalls += 1;
              return next;
            },
          );

          await expectLater(runner.runAll([brief]), throwsA(same(failure)));

          expect(factoryCalls, 1);
          expect(firstRunner.calls, 1);
          expect(secondRunner.calls, 0);
        },
      );
    }

    test(
      'no-content-redraw fails before runner creation without evidence sink',
      () async {
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settingsStore.dispose);
        var factoryCalls = 0;
        final runner = ChapterConcurrentRunner(
          settingsStore: settingsStore,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            maxConcurrentScenes: 1,
            maxSceneRetries: 2,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            evidenceRunId: 'chapter-concurrent-missing-log-v1',
          ),
          sceneRunnerFactory: () {
            factoryCalls += 1;
            return _StubSceneRunner(
              output: _output(_brief(), decision: SceneReviewDecision.pass),
            );
          },
        );

        await expectLater(runner.runAll([_brief()]), throwsStateError);

        expect(factoryCalls, 0);
      },
    );

    test(
      'no-content-redraw preserves a temporary runner evidence envelope in JSONL',
      () async {
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settingsStore.dispose);
        final evidenceDirectory = await Directory.systemTemp.createTemp(
          'chapter-no-redraw-persisted-evidence-',
        );
        final jsonlPath = '${evidenceDirectory.path}/pipeline.jsonl';
        final evidenceLog = PipelineEventLogImpl(jsonlPath: jsonlPath);
        PipelineEventLogImpl? reopenedLog;
        addTearDown(() async {
          await reopenedLog?.dispose();
          await evidenceLog.dispose();
          if (await evidenceDirectory.exists()) {
            await evidenceDirectory.delete(recursive: true);
          }
        });
        final brief = _brief();
        var factoryCalls = 0;

        final outputs = await ChapterConcurrentRunner(
          settingsStore: settingsStore,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            maxConcurrentScenes: 1,
            maxSceneRetries: 2,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            evidenceRunId: 'chapter-concurrent-no-redraw-v1',
          ),
          evidenceLog: evidenceLog,
          sceneRunnerFactory: () {
            factoryCalls += 1;
            return _ScopedEvidenceSceneRunner(
              output: _output(brief, decision: SceneReviewDecision.pass),
            );
          },
        ).runAll([brief]);

        expect(outputs.single.brief.sceneId, brief.sceneId);
        expect(factoryCalls, 1);
        await evidenceLog.dispose();

        reopenedLog = PipelineEventLogImpl(jsonlPath: jsonlPath);
        final persistedEvents = await reopenedLog.readPersistedEvents();
        final envelope = persistedEvents.single;
        expect(envelope.stageId, 'experiment_evidence');
        expect(
          envelope.eventType,
          'story_generation_attempt_evidence_envelope_recorded',
        );
        expect(
          envelope.metadata,
          containsPair(
            'schemaVersion',
            'story-generation-attempt-evidence-envelope-v1',
          ),
        );
        expect(envelope.metadata['sceneId'], brief.sceneId);
        expect(envelope.metadata['evidenceComplete'], isTrue);
      },
    );

    test(
      'default production retries a non-passing scene with a fresh runner',
      () async {
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settingsStore.dispose);
        final brief = _brief();
        final firstRunner = _StubSceneRunner(
          output: _output(brief, decision: SceneReviewDecision.rewriteProse),
        );
        final secondOutput = _output(
          brief,
          decision: SceneReviewDecision.pass,
          prose: 'second production completion',
        );
        final secondRunner = _StubSceneRunner(output: secondOutput);
        final queuedRunners = <ChapterGenerationService>[
          firstRunner,
          secondRunner,
        ];
        var factoryCalls = 0;
        final runner = ChapterConcurrentRunner(
          settingsStore: settingsStore,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            maxConcurrentScenes: 1,
            maxSceneRetries: 2,
          ),
          sceneRunnerFactory: () {
            final next = queuedRunners[factoryCalls];
            factoryCalls += 1;
            return next;
          },
        );

        final outputs = await runner.runAll([brief]);

        expect(outputs.single, same(secondOutput));
        expect(factoryCalls, 2);
        expect(firstRunner.calls, 1);
        expect(secondRunner.calls, 1);
      },
    );

    test('default production retries an outer runner exception', () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
      );
      addTearDown(settingsStore.dispose);
      final brief = _brief();
      final firstRunner = _StubSceneRunner(
        error: TimeoutException('retryable production failure'),
      );
      final secondOutput = _output(brief, decision: SceneReviewDecision.pass);
      final secondRunner = _StubSceneRunner(output: secondOutput);
      final queuedRunners = <ChapterGenerationService>[
        firstRunner,
        secondRunner,
      ];
      var factoryCalls = 0;
      final runner = ChapterConcurrentRunner(
        settingsStore: settingsStore,
        pipelineConfig: const GenerationPipelineConfig(
          hardGatesEnabled: false,
          maxConcurrentScenes: 1,
          maxSceneRetries: 2,
        ),
        sceneRunnerFactory: () {
          final next = queuedRunners[factoryCalls];
          factoryCalls += 1;
          return next;
        },
      );

      final outputs = await runner.runAll([brief]);

      expect(outputs.single, same(secondOutput));
      expect(factoryCalls, 2);
      expect(firstRunner.calls, 1);
      expect(secondRunner.calls, 1);
    });
  });
}

SceneBrief _brief() => SceneBrief(
  chapterId: 'chapter-1',
  chapterTitle: 'Chapter One',
  sceneId: 'scene-1',
  sceneTitle: 'One Sample Only',
  sceneSummary: 'Freeze the first provider outcome.',
);

SceneRuntimeOutput _output(
  SceneBrief brief, {
  required SceneReviewDecision decision,
  String prose = 'first production completion',
}) {
  return SceneRuntimeOutput(
    brief: brief,
    resolvedCast: const [],
    director: const SceneDirectorOutput(text: 'director plan'),
    roleOutputs: const [],
    prose: SceneProseDraft(text: prose, attempt: 1),
    review: SceneReviewResult(
      judge: const SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: 'reviewed',
        rawText: '',
      ),
      consistency: const SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: 'consistent',
        rawText: '',
      ),
      decision: decision,
    ),
    proseAttempts: 1,
    softFailureCount: 0,
  );
}

final class _StubSceneRunner implements ChapterGenerationService {
  _StubSceneRunner({this.output, this.error})
    : assert((output == null) != (error == null));

  final SceneRuntimeOutput? output;
  final Object? error;
  int calls = 0;

  @override
  RetrievalTrace? get lastRetrievalTrace => null;

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) async {
    calls += 1;
    final failure = error;
    if (failure != null) {
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    return output!;
  }
}

final class _ScopedEvidenceSceneRunner implements ChapterGenerationService {
  _ScopedEvidenceSceneRunner({required this.output});

  final SceneRuntimeOutput output;

  @override
  RetrievalTrace? get lastRetrievalTrace => null;

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) async {
    await Future<void>.value();
    final eventLog = PipelineEvidenceLogScope.current;
    if (eventLog == null) {
      throw StateError('temporary runner did not inherit the evidence sink');
    }
    eventLog.emit(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: 'experiment_evidence',
        eventType: 'story_generation_attempt_evidence_envelope_recorded',
        metadata: <String, Object?>{
          'schemaVersion': 'story-generation-attempt-evidence-envelope-v1',
          'sceneId': brief.sceneId,
          'runStatus': 'completed',
          'evidenceComplete': true,
          'private': const <String, Object?>{
            'visibility': 'private',
            'evidenceComplete': true,
          },
          'blind': const <String, Object?>{
            'visibility': 'blind',
            'evidenceComplete': true,
          },
        },
      ),
    );
    await eventLog.flush();
    return output;
  }
}
