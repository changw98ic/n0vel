import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:novel_writer/features/story_generation/data/generation_stage_checkpoint_codec.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:novel_writer/features/story_generation/data/step_io.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/stage_runner.dart';
import 'package:novel_writer/features/story_generation/domain/story_pipeline_interfaces.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  group('pipeline lifecycle adversarial boundaries', () {
    test(
      'checkpoint records every completed stage without becoming proof',
      () async {
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        final checkpoints = _MemoryCheckpointStore();
        final runner = _runner(settings, _StableDirector())
          ..checkpointRunId = 'run-checkpoint'
          ..checkpointStore = checkpoints;

        await runner.runScene(_brief());

        final completed = checkpoints.values.where(
          (value) => value.isCompleted,
        );
        expect(completed, isNotEmpty);
        expect(
          completed.every((value) => value.runId == 'run-checkpoint'),
          isTrue,
        );
        expect(
          completed.every((value) => value.inputDigest.length == 64),
          isTrue,
        );
        expect(
          completed.every((value) => value.artifactDigest.length == 64),
          isTrue,
        );
        expect(
          completed.map((value) => value.ordinal),
          containsAll(List<int>.generate(13, (ordinal) => ordinal)),
        );
      },
    );

    test('corrupt checkpoint fails closed and recomputes the stage', () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final checkpoints = _MemoryCheckpointStore([
        const PipelineStageCheckpoint(
          runId: 'run-corrupt',
          ordinal: 1,
          stageId: 'director',
          stageAttempt: 1,
          schemaVersion: 999,
          inputDigest: 'not-a-digest',
          artifactDigest: 'forged',
          status: 'completed',
          createdAtMs: 1,
          completedAtMs: 2,
        ),
      ]);
      final director = _StableDirector();
      final runner = _runner(settings, director)
        ..checkpointRunId = 'run-corrupt'
        ..checkpointStore = checkpoints;

      await runner.runScene(_brief());

      expect(director.calls, 1);
      expect(
        runner.eventLog.query(
          stageId: 'director',
          eventType: 'checkpoint_discarded_incompatible',
        ),
        hasLength(1),
      );
    });

    test(
      'transient stage failures retry within the declared ceiling',
      () async {
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        final director = _FlakyDirector(failuresBeforeSuccess: 1);
        final runner = _runner(settings, director);

        await runner.runScene(_brief());

        expect(director.calls, 2);
        expect(
          runner.eventLog.query(
            stageId: 'director',
            eventType: 'stage_retry_scheduled',
          ),
          hasLength(1),
        );
      },
    );

    test(
      'outer prose rewrite advances durable checkpoint attempt identities',
      () async {
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        final checkpoints = _MemoryCheckpointStore();
        final review = _RewriteOnceReview();
        final runner = _runner(settings, _StableDirector(), review: review)
          ..checkpointRunId = 'run-outer-rewrite'
          ..checkpointStore = checkpoints;

        await runner.runScene(_brief());

        List<int> attempts(int ordinal) =>
            checkpoints.values
                .where((value) => value.ordinal == ordinal && value.isCompleted)
                .map((value) => value.stageAttempt)
                .toSet()
                .toList()
              ..sort();
        expect(review.calls, greaterThanOrEqualTo(3));
        expect(attempts(5), <int>[1, 4]);
        expect(attempts(6), <int>[1, 4]);
      },
    );

    test('cancel before the first stage prevents provider dispatch', () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final director = _StableDirector();
      final runner = _runner(settings, director)..isRunCancelled = () => true;

      await expectLater(
        runner.runScene(_brief()),
        throwsA(isA<PipelineRunCancelled>()),
      );
      expect(director.calls, 0);
    });

    test('typed run pre-cancel does not read checkpoint store', () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final runner = _runner(settings, _StableDirector())
        ..checkpointRunId = 'run-typed-cancel'
        ..checkpointStore = _FailOnLoadCheckpointStore()
        ..isRunCancelled = () => true;
      final brief = _brief();
      final context = _typedContext(runner, brief);

      final result = await runner.run(context.sceneBrief, context);

      expect(result.success, isFalse);
      expect(result.failureCode, FailureCode.blocked);
      expect(result.failedStageId, 'run_start');
    });

    test(
      'file-backed completed provider checkpoint survives reopen without replay',
      () async {
        final file = File(
          '${Directory.systemTemp.path}/generation-resume-${DateTime.now().microsecondsSinceEpoch}.db',
        );
        addTearDown(() {
          if (file.existsSync()) file.deleteSync();
        });
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        const runId = 'run-file-resume';
        const provenance = GenerationCheckpointProvenance(
          baseDraftDigest:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          materialDigest:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          promptDigest:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          modelDigest:
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        );
        final director = _StableDirector();
        final firstDb = sqlite3.sqlite3.open(file.path);
        firstDb.execute('PRAGMA foreign_keys = ON');
        final firstLedger = GenerationLedgerSqliteStore(db: firstDb)
          ..ensureTables();
        firstLedger.createRun(
          const GenerationRunRecord(
            runId: runId,
            requestId: 'request-file-resume',
            projectId: 'project',
            chapterId: 'chapter',
            sceneId: 'scene',
            sceneScopeId: 'project::scene',
            status: 'running',
            phase: 'planning',
            schemaVersion: 10,
            createdAtMs: 1,
            updatedAtMs: 1,
          ),
        );
        firstLedger.createWorkingProseRevision(
          const WorkingProseRevisionRecord(
            runId: runId,
            proseRevision: 0,
            proseHash: 'sha256:base-draft',
            proseText: '作者原稿',
            sourceKind: 'baseDraft',
            createdAtMs: 1,
          ),
        );
        final firstStore = _CrashAfterCompletedCheckpointStore(
          delegate: GenerationLedgerCheckpointStore(
            ledger: firstLedger,
            provenance: provenance,
          ),
          ordinal: 1,
        );
        final first = _runner(settings, director)
          ..checkpointRunId = runId
          ..checkpointStore = firstStore
          ..checkpointProvenance = provenance;
        await expectLater(
          first.runScene(_brief()),
          throwsA(isA<PipelineRunCancelled>()),
        );
        expect(firstStore.crashed, isTrue);
        firstDb.dispose();

        final resumedDb = sqlite3.sqlite3.open(file.path);
        addTearDown(resumedDb.dispose);
        resumedDb.execute('PRAGMA foreign_keys = ON');
        final resumedLedger = GenerationLedgerSqliteStore(db: resumedDb)
          ..ensureTables();
        final resumed = _runner(settings, director)
          ..checkpointRunId = runId
          ..checkpointStore = GenerationLedgerCheckpointStore(
            ledger: resumedLedger,
            provenance: provenance,
          )
          ..checkpointProvenance = provenance;

        await resumed.runScene(_brief());

        expect(
          director.calls,
          1,
          reason:
              'the durable director checkpoint must be restored after reopening SQLite',
        );
        expect(
          resumedDb.select(
            '''
            SELECT 1 FROM story_generation_stage_checkpoints
            WHERE run_id = ? AND ordinal = 1 AND status = 'completed'
          ''',
            [runId],
          ),
          hasLength(1),
        );
      },
    );

    test('typed run prepares and reuses its compatible resume chain', () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final checkpoints = _MemoryCheckpointStore();
      final director = _StableDirector();
      final first = _runner(settings, director)
        ..checkpointRunId = 'run-typed-resume'
        ..checkpointStore = checkpoints;

      await first.runScene(_brief());
      expect(director.calls, 1);

      final resumed = _runner(settings, director)
        ..checkpointRunId = 'run-typed-resume'
        ..checkpointStore = checkpoints;
      final brief = _brief();
      final context = _typedContext(resumed, brief);

      final result = await resumed.run(context.sceneBrief, context);

      expect(result.success, isTrue);
      expect(
        director.calls,
        1,
        reason: 'typed run() must restore the compatible director checkpoint',
      );
      expect(
        resumed.eventLog.query(stageId: 'director', eventType: 'stage_resumed'),
        hasLength(1),
      );
    });

    test(
      'stale in-memory resume chain cannot cross checkpoint namespace',
      () async {
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        final checkpoints = _MemoryCheckpointStore();
        final director = _StableDirector();
        final runner = _runner(settings, director)
          ..checkpointRunId = 'run-stale-source'
          ..checkpointStore = checkpoints;

        await runner.runScene(_brief());
        expect(director.calls, 1);

        await runner.runScene(_brief());
        expect(
          director.calls,
          1,
          reason: 'second runScene call establishes the in-memory resume chain',
        );
        final resumedBeforeNamespaceChange = runner.eventLog
            .query(stageId: 'context_enrichment', eventType: 'stage_resumed')
            .length;

        runner.checkpointRunId = 'run-stale-target';
        var brief = _brief();
        var context = _typedContext(runner, brief);

        var result = await runner.run(context.sceneBrief, context);

        expect(result.success, isTrue);
        expect(director.calls, 2);
        expect(
          runner.eventLog
              .query(stageId: 'context_enrichment', eventType: 'stage_resumed')
              .length,
          resumedBeforeNamespaceChange,
        );

        runner
          ..checkpointRunId = 'run-stale-source'
          ..checkpointProseRevision = 1;
        brief = _brief();
        context = _typedContext(runner, brief);

        result = await runner.run(context.sceneBrief, context);

        expect(result.success, isTrue);
        expect(director.calls, 3);
        expect(
          runner.eventLog
              .query(stageId: 'context_enrichment', eventType: 'stage_resumed')
              .length,
          resumedBeforeNamespaceChange,
        );
      },
    );

    test('wrong typed restored artifact is ignored and recomputed', () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final checkpoints = _MemoryCheckpointStore();
      final director = _StableDirector();
      final first = _runner(settings, director)
        ..checkpointRunId = 'run-wrong-artifact'
        ..checkpointStore = checkpoints;

      await first.runScene(_brief());
      expect(director.calls, 1);

      const defaultRestorer = GenerationStageArtifactRestorer();
      final resumed = _runner(settings, director)
        ..checkpointRunId = 'run-wrong-artifact'
        ..checkpointStore = checkpoints
        ..checkpointArtifactRestorer = (checkpoint, input) async {
          if (checkpoint.ordinal == 1) {
            return const ContextEnrichmentOutput(
              effectiveMaterials: ProjectMaterialSnapshot(),
            );
          }
          return defaultRestorer(checkpoint, input);
        };
      final brief = _brief();
      final context = _typedContext(resumed, brief);

      final result = await resumed.run(context.sceneBrief, context);

      expect(result.success, isTrue);
      expect(
        director.calls,
        2,
        reason: 'a mismatched TypedArtifact must not satisfy director output',
      );
    });
  });
}

PipelineStageRunnerImpl _runner(
  AppSettingsStore settings,
  SceneDirectorService director, {
  SceneReviewService review = const _PassReview(),
}) {
  return PipelineStageRunnerImpl(
    settingsStore: settings,
    pipelineConfig: const GenerationPipelineConfig(hardGatesEnabled: false),
    directorOrchestrator: director,
    reviewCoordinator: review,
    qualityScorer: const _PassingQuality(),
  );
}

SceneBrief _brief() => SceneBrief(
  chapterId: 'chapter',
  chapterTitle: '第一章',
  sceneId: 'scene',
  sceneTitle: '雨夜码头',
  sceneSummary: '阿岚逼问线人。',
  targetBeat: '阿岚逼问线人，得到关键线索。',
  metadata: const {
    'localStructuredRoleplayOnly': true,
    'localEditorialOnly': true,
    'localPolishOnly': true,
  },
);

PipelineContext _typedContext(
  PipelineStageRunnerImpl runner,
  SceneBrief brief,
) {
  final sceneRef = SceneBriefRef(
    projectId: brief.projectId ?? brief.chapterId,
    sceneId: brief.sceneId,
    sceneIndex: brief.sceneIndex,
    totalScenesInChapter: brief.totalScenesInChapter,
  );
  return PipelineContext(
    eventLog: runner.eventLog,
    retrievalPolicy: runner.defaultRetrievalPolicy,
    writebackGate: runner.writebackGate,
    sceneBrief: sceneRef,
    metadata: {'sceneBrief': brief},
  );
}

class _MemoryCheckpointStore implements PipelineCheckpointStore {
  _MemoryCheckpointStore([Iterable<PipelineStageCheckpoint> initial = const []])
    : values = [...initial];

  final List<PipelineStageCheckpoint> values;

  @override
  Future<List<PipelineStageCheckpoint>> load({required String runId}) async =>
      List.unmodifiable(values.where((value) => value.runId == runId));

  @override
  Future<void> save(PipelineStageCheckpoint checkpoint) async {
    values.removeWhere(
      (value) =>
          value.runId == checkpoint.runId &&
          value.ordinal == checkpoint.ordinal &&
          value.stageId == checkpoint.stageId &&
          value.stageAttempt == checkpoint.stageAttempt,
    );
    values.add(checkpoint);
  }
}

class _FailOnLoadCheckpointStore implements PipelineCheckpointStore {
  @override
  Future<List<PipelineStageCheckpoint>> load({required String runId}) async {
    throw StateError('checkpoint store must not be read after pre-cancel');
  }

  @override
  Future<void> save(PipelineStageCheckpoint checkpoint) async {
    throw StateError('checkpoint store must not be written after pre-cancel');
  }
}

class _CrashAfterCompletedCheckpointStore implements PipelineCheckpointStore {
  _CrashAfterCompletedCheckpointStore({
    required this.delegate,
    required this.ordinal,
  });

  final PipelineCheckpointStore delegate;
  final int ordinal;
  bool crashed = false;

  @override
  Future<List<PipelineStageCheckpoint>> load({required String runId}) =>
      delegate.load(runId: runId);

  @override
  Future<void> save(PipelineStageCheckpoint checkpoint) async {
    await delegate.save(checkpoint);
    if (!crashed && checkpoint.ordinal == ordinal && checkpoint.isCompleted) {
      crashed = true;
      throw PipelineRunCancelled('file-crash-after-$ordinal');
    }
  }
}

class _StableDirector implements SceneDirectorService {
  int calls = 0;

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async {
    calls += 1;
    return const SceneDirectorOutput(text: '逼问线人并取得关键线索。');
  }
}

class _FlakyDirector extends _StableDirector {
  _FlakyDirector({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async {
    calls += 1;
    if (calls <= failuresBeforeSuccess) {
      throw StateError('transient provider failure');
    }
    return const SceneDirectorOutput(text: '逼问线人并取得关键线索。');
  }
}

class _PassReview implements SceneReviewService {
  const _PassReview();

  @override
  Future<SceneReviewResult> review({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    bool enableReaderFlowReview = false,
    bool enableLexiconReview = false,
    List<StoryMemoryChunk> canonFacts = const [],
  }) async {
    const pass = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '通过。',
      rawText: 'PASS',
    );
    return const SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: SceneReviewDecision.pass,
    );
  }
}

class _RewriteOnceReview implements SceneReviewService {
  var calls = 0;

  @override
  Future<SceneReviewResult> review({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    bool enableReaderFlowReview = false,
    bool enableLexiconReview = false,
    List<StoryMemoryChunk> canonFacts = const [],
  }) async {
    calls += 1;
    const pass = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '通过。',
      rawText: 'PASS',
    );
    if (calls == 1) {
      const rewrite = SceneReviewPassResult(
        status: SceneReviewStatus.rewriteProse,
        reason: '需要一次正文重写。',
        rawText: 'REWRITE_PROSE',
      );
      return const SceneReviewResult(
        judge: rewrite,
        consistency: pass,
        decision: SceneReviewDecision.rewriteProse,
      );
    }
    return const SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: SceneReviewDecision.pass,
    );
  }
}

class _PassingQuality implements SceneQualityScorerService {
  const _PassingQuality();

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async => const SceneQualityScore(
    overall: 96,
    prose: 96,
    coherence: 96,
    character: 96,
    completeness: 96,
    summary: '通过。',
  );
}
