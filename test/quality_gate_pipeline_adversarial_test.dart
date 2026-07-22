import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/domain/story_pipeline_interfaces.dart';

void main() {
  test(
    'polished prose is independently reviewed again before quality passes',
    () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final review = _CountingPassReview();
      final runner = PipelineStageRunnerImpl(
        settingsStore: settings,
        pipelineConfig: const GenerationPipelineConfig(hardGatesEnabled: false),
        directorOrchestrator: const _LocalDirector(),
        reviewCoordinator: review,
        qualityScorer: const _FixedQualityScorer(
          SceneQualityScore(
            overall: 96,
            prose: 95,
            coherence: 95,
            character: 95,
            completeness: 95,
            summary: '通过。',
          ),
        ),
      );

      final output = await runner.runScene(_brief());

      expect(review.proseRevisions, hasLength(2));
      expect(review.proseRevisions.last, output.prose.text);
      expect(output.qualityScore!.overall, 96);
      expect(
        runner.eventLog.query(
          stageId: 'quality_gate',
          eventType: 'quality_passed',
        ),
        hasLength(1),
      );
    },
  );

  test('a sub-95 quality score blocks before finalization', () async {
    final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
    addTearDown(settings.dispose);
    final runner = PipelineStageRunnerImpl(
      settingsStore: settings,
      pipelineConfig: const GenerationPipelineConfig(
        hardGatesEnabled: false,
        maxQualityRepairRetries: 1,
      ),
      directorOrchestrator: const _LocalDirector(),
      reviewCoordinator: _CountingPassReview(),
      qualityScorer: const _FixedQualityScorer(
        SceneQualityScore(
          overall: 94,
          prose: 100,
          coherence: 100,
          character: 100,
          completeness: 100,
          summary: '总分不足。',
        ),
      ),
    );

    await expectLater(runner.runScene(_brief()), throwsA(isA<StateError>()));
    expect(
      runner.eventLog.query(
        stageId: 'quality_gate',
        eventType: 'quality_blocked',
      ),
      hasLength(2),
    );
    expect(
      runner.eventLog.query(
        stageId: 'finalization',
        eventType: 'stage_completed',
      ),
      isEmpty,
    );
  });

  test(
    'a below-90 critical dimension blocks even when overall is 95',
    () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final runner = PipelineStageRunnerImpl(
        settingsStore: settings,
        pipelineConfig: const GenerationPipelineConfig(hardGatesEnabled: false),
        directorOrchestrator: const _LocalDirector(),
        reviewCoordinator: _CountingPassReview(),
        qualityScorer: const _FixedQualityScorer(
          SceneQualityScore(
            overall: 95,
            prose: 100,
            coherence: 89.9,
            character: 100,
            completeness: 100,
            summary: '关键维度不足。',
          ),
        ),
      );

      await expectLater(runner.runScene(_brief()), throwsA(isA<StateError>()));
      expect(
        runner.eventLog.query(
          stageId: 'finalization',
          eventType: 'stage_completed',
        ),
        isEmpty,
      );
    },
  );

  test(
    'one failed quality score can repair a new prose revision before pass',
    () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final review = _CountingPassReview();
      final runner = PipelineStageRunnerImpl(
        settingsStore: settings,
        pipelineConfig: const GenerationPipelineConfig(
          hardGatesEnabled: false,
          maxQualityRepairRetries: 1,
        ),
        directorOrchestrator: const _LocalDirector(),
        reviewCoordinator: review,
        qualityScorer: _SequenceQualityScorer([
          const SceneQualityScore(
            overall: 87,
            prose: 86,
            coherence: 90,
            character: 85,
            completeness: 88,
            summary: '需要更具体的动作、对白和因果。',
          ),
          const SceneQualityScore(
            overall: 96,
            prose: 96,
            coherence: 95,
            character: 95,
            completeness: 96,
            summary: '修订后通过。',
          ),
        ]),
      );

      final output = await runner.runScene(_brief());
      expect(output.qualityScore!.overall, 96);
      expect(review.proseRevisions, hasLength(4));
      expect(
        runner.eventLog.query(
          stageId: 'quality_gate',
          eventType: 'quality_passed',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'no-content-redraw records quality failure without a second prose draw',
    () async {
      final settings = await _noRedrawSettings();
      final review = _CountingPassReview();
      final scorer = _SequenceQualityScorer([
        const SceneQualityScore(
          overall: 87,
          prose: 86,
          coherence: 90,
          character: 85,
          completeness: 88,
          summary: '首个候选质量不足，但实验不允许重抽。',
        ),
        const SceneQualityScore(
          overall: 96,
          prose: 96,
          coherence: 96,
          character: 96,
          completeness: 96,
          summary: '这份第二候选不应被请求。',
        ),
      ]);
      final evidenceLog = await _durableEvidenceLog();
      final runner = PipelineStageRunnerImpl(
        settingsStore: settings,
        eventLog: evidenceLog,
        pipelineConfig: const GenerationPipelineConfig(
          hardGatesEnabled: false,
          maxQualityRepairRetries: 2,
          sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
          evidenceRunId: 'quality-gate-no-redraw-quality-repair-v1',
        ),
        directorOrchestrator: const _LocalDirector(),
        reviewCoordinator: review,
        qualityScorer: scorer,
      );

      await expectLater(
        runner.runScene(_noRedrawBrief()),
        throwsA(isA<ContentRedrawBlocked>()),
      );

      expect(scorer.calls, 1);
      expect(review.proseRevisions, hasLength(2));
      expect(review.proseRevisions.toSet(), hasLength(1));
      expect(
        runner.eventLog.query(
          stageId: 'quality_gate',
          eventType: 'quality_repair_scheduled',
        ),
        isEmpty,
      );
      expect(
        runner.eventLog.query(eventType: 'content_redraw_blocked'),
        hasLength(1),
      );
    },
  );

  test(
    'no-content-redraw blocks a preliminary review rewrite immediately',
    () async {
      final settings = await _noRedrawSettings();
      final review = _FixedDecisionReview(SceneReviewDecision.rewriteProse);
      final evidenceLog = await _durableEvidenceLog();
      final runner = PipelineStageRunnerImpl(
        settingsStore: settings,
        eventLog: evidenceLog,
        pipelineConfig: const GenerationPipelineConfig(
          hardGatesEnabled: false,
          maxProseRetries: 2,
          sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
          evidenceRunId: 'quality-gate-no-redraw-prose-retry-v1',
        ),
        directorOrchestrator: const _LocalDirector(),
        reviewCoordinator: review,
        qualityScorer: const _FixedQualityScorer(
          SceneQualityScore(
            overall: 96,
            prose: 96,
            coherence: 96,
            character: 96,
            completeness: 96,
            summary: '不会执行。',
          ),
        ),
      );

      await expectLater(
        runner.runScene(_noRedrawBrief()),
        throwsA(isA<ContentRedrawBlocked>()),
      );

      expect(review.calls, 1);
      expect(
        runner.eventLog.query(eventType: 'content_redraw_blocked'),
        hasLength(1),
      );
    },
  );

  test(
    'no-content-redraw blocks a preliminary scene replan immediately',
    () async {
      final settings = await _noRedrawSettings();
      final review = _FixedDecisionReview(SceneReviewDecision.replanScene);
      final evidenceLog = await _durableEvidenceLog();
      final runner = PipelineStageRunnerImpl(
        settingsStore: settings,
        eventLog: evidenceLog,
        pipelineConfig: const GenerationPipelineConfig(
          hardGatesEnabled: false,
          maxSceneReplanRetries: 2,
          sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
          evidenceRunId: 'quality-gate-no-redraw-scene-replan-v1',
        ),
        directorOrchestrator: const _LocalDirector(),
        reviewCoordinator: review,
      );

      await expectLater(
        runner.runScene(_noRedrawBrief()),
        throwsA(isA<ContentRedrawBlocked>()),
      );

      expect(review.calls, 1);
      expect(
        runner.eventLog.query(
          stageId: 'planning',
          eventType: 'content_redraw_blocked',
        ),
        hasLength(1),
      );
      expect(
        runner.eventLog.query(
          stageId: 'planning',
          eventType: 'stage_retry_scheduled',
        ),
        isEmpty,
      );
    },
  );

  test(
    'no-content-redraw blocks final council repair without another prose draw',
    () async {
      final settings = await _noRedrawSettings();
      final review = _SequenceDecisionReview([
        SceneReviewDecision.pass,
        SceneReviewDecision.rewriteProse,
      ]);
      final evidenceLog = await _durableEvidenceLog();
      final runner = PipelineStageRunnerImpl(
        settingsStore: settings,
        eventLog: evidenceLog,
        pipelineConfig: const GenerationPipelineConfig(
          hardGatesEnabled: false,
          maxProseRetries: 2,
          sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
          evidenceRunId: 'quality-gate-no-redraw-review-rewrite-v1',
        ),
        directorOrchestrator: const _LocalDirector(),
        reviewCoordinator: review,
      );

      await expectLater(
        runner.runScene(
          _noRedrawBrief(sceneSummary: '阿岚按住线人的袖口。“说。”线人低声答：“账册在旧仓。”雨声压住脚步。'),
        ),
        throwsA(isA<ContentRedrawBlocked>()),
      );

      expect(review.calls, 2);
      expect(review.proseRevisions, hasLength(2));
      expect(review.proseRevisions.toSet(), hasLength(1));
      expect(
        runner.eventLog.query(
          stageId: 'review',
          eventType: 'content_redraw_blocked',
        ),
        hasLength(1),
      );
      expect(
        runner.eventLog.query(eventType: 'quality_repair_scheduled'),
        isEmpty,
      );
    },
  );

  test('no-content-redraw does not replay a failed provider stage', () async {
    final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
    addTearDown(settings.dispose);
    final director = _ThrowingDirector();
    final evidenceLog = await _durableEvidenceLog();
    final runner = PipelineStageRunnerImpl(
      settingsStore: settings,
      eventLog: evidenceLog,
      pipelineConfig: const GenerationPipelineConfig(
        hardGatesEnabled: false,
        sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
        evidenceRunId: 'quality-gate-no-redraw-provider-call-v1',
      ),
      directorOrchestrator: director,
      reviewCoordinator: _CountingPassReview(),
    );

    await expectLater(runner.runScene(_brief()), throwsA(isA<StateError>()));

    expect(director.calls, 1);
    expect(
      director.retryPolicy?.scope,
      StoryGenerationRetryPolicyScope.experimentNoContentRedraw,
    );
    expect(
      runner.eventLog.query(
        stageId: 'planning',
        eventType: 'stage_retry_scheduled',
      ),
      isEmpty,
    );
  });

  test('a scorer exception blocks before finalization', () async {
    final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
    addTearDown(settings.dispose);
    final runner = PipelineStageRunnerImpl(
      settingsStore: settings,
      pipelineConfig: const GenerationPipelineConfig(hardGatesEnabled: false),
      directorOrchestrator: const _LocalDirector(),
      reviewCoordinator: _CountingPassReview(),
      qualityScorer: const _ThrowingQualityScorer(),
    );

    await expectLater(runner.runScene(_brief()), throwsA(isA<StateError>()));
    expect(
      runner.eventLog.query(
        stageId: 'quality_gate',
        eventType: 'quality_blocked',
      ),
      hasLength(1),
    );
    expect(
      runner.eventLog.query(
        stageId: 'finalization',
        eventType: 'stage_completed',
      ),
      isEmpty,
    );
  });
}

Future<PipelineEventLogImpl> _durableEvidenceLog() async {
  final directory = await Directory.systemTemp.createTemp(
    'quality-gate-evidence-',
  );
  final eventLog = PipelineEventLogImpl(
    jsonlPath: '${directory.path}/pipeline.jsonl',
  );
  addTearDown(() async {
    await eventLog.dispose();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return eventLog;
}

Future<AppSettingsStore> _noRedrawSettings() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var responseOrdinal = 0;
  server.listen((request) async {
    await utf8.decoder.bind(request).join();
    responseOrdinal += 1;
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode(<String, Object?>{
          'id': 'quality-gate-response-$responseOrdinal',
          'model': 'quality-gate-model',
          'choices': <Object?>[
            <String, Object?>{
              'message': <String, Object?>{
                'content':
                    '[动作] @narrator 阿岚封住线人的退路\n'
                    '[事实] @narrator 线人交出仓库编号',
              },
            },
          ],
          'usage': const <String, Object?>{
            'prompt_tokens': 10,
            'completion_tokens': 10,
            'total_tokens': 20,
          },
        }),
      );
    await request.response.close();
  });
  final settings = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: createDefaultAppLlmClient(),
  );
  await settings.save(
    providerName: 'quality-gate-test',
    baseUrl: 'http://${server.address.host}:${server.port}/v1',
    model: 'quality-gate-model',
    apiKey: '',
    timeout: const AppLlmTimeoutConfig.uniform(5000),
  );
  addTearDown(() async {
    settings.dispose();
    await server.close(force: true);
  });
  return settings;
}

SceneBrief _brief({
  String sceneSummary = '阿岚逼问线人。',
  String targetBeat = '阿岚逼问线人，得到关键线索。',
  Map<String, Object?> metadata = const {
    'localStructuredRoleplayOnly': true,
    'localEditorialOnly': true,
    'localPolishOnly': true,
  },
}) => SceneBrief(
  chapterId: 'chapter',
  chapterTitle: '第一章',
  sceneId: 'scene',
  sceneTitle: '雨夜码头',
  sceneSummary: sceneSummary,
  targetBeat: targetBeat,
  metadata: metadata,
);

SceneBrief _noRedrawBrief({
  String sceneSummary = '阿岚逼问线人。',
  String targetBeat = '阿岚逼问线人，得到关键线索。',
}) => _brief(
  sceneSummary: sceneSummary,
  targetBeat: targetBeat,
  metadata: const {'localEditorialOnly': true, 'localPolishOnly': true},
);

class _LocalDirector implements SceneDirectorService {
  const _LocalDirector();

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async => const SceneDirectorOutput(text: '逼问线人并取得关键线索。');
}

class _ThrowingDirector implements SceneDirectorService {
  int calls = 0;
  StoryGenerationRetryPolicy? retryPolicy;

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async {
    calls += 1;
    retryPolicy = StoryGenerationRetryScope.current;
    throw StateError('indeterminate director failure');
  }
}

class _CountingPassReview implements SceneReviewService {
  final List<String> proseRevisions = [];

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
    proseRevisions.add(prose.text);
    const pass = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '独立评审通过。',
      rawText: '决定：PASS\n原因：独立评审通过。',
    );
    return const SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: SceneReviewDecision.pass,
    );
  }
}

class _FixedDecisionReview implements SceneReviewService {
  _FixedDecisionReview(this.decision);

  final SceneReviewDecision decision;
  int calls = 0;

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
    final pass = SceneReviewPassResult(
      status: decision == SceneReviewDecision.pass
          ? SceneReviewStatus.pass
          : SceneReviewStatus.rewriteProse,
      reason: decision.name,
      rawText: decision.name,
    );
    return SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: decision,
    );
  }
}

class _SequenceDecisionReview implements SceneReviewService {
  _SequenceDecisionReview(this.decisions);

  final List<SceneReviewDecision> decisions;
  final List<String> proseRevisions = [];
  int calls = 0;

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
    proseRevisions.add(prose.text);
    final decision = decisions[calls++];
    final pass = SceneReviewPassResult(
      status: decision == SceneReviewDecision.pass
          ? SceneReviewStatus.pass
          : SceneReviewStatus.rewriteProse,
      reason: decision.name,
      rawText: decision.name,
    );
    return SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: decision,
    );
  }
}

class _FixedQualityScorer implements SceneQualityScorerService {
  const _FixedQualityScorer(this.value);

  final SceneQualityScore value;

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async => value;
}

class _SequenceQualityScorer implements SceneQualityScorerService {
  _SequenceQualityScorer(this.values);

  final List<SceneQualityScore> values;
  var _index = 0;
  int get calls => _index;

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async => values[_index++];
}

class _ThrowingQualityScorer implements SceneQualityScorerService {
  const _ThrowingQualityScorer();

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) => Future<SceneQualityScore>.error(StateError('provider unavailable'));
}
