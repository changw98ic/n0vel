import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
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

class _LocalDirector implements SceneDirectorService {
  const _LocalDirector();

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async => const SceneDirectorOutput(text: '逼问线人并取得关键线索。');
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
