import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/narrative_arc_models.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart'
    as pipeline;
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart'
    show SceneState;
import 'package:novel_writer/features/story_generation/data/step_io.dart';
import 'package:novel_writer/features/story_generation/data/steps/finalization_step.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_writeback_gate.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/stage_runner.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  test(
    'finalization accepts only a precomputed passing quality gate',
    () async {
      const step = FinalizationStep();
      final input = _input();

      final output = await step.execute(
        input,
        _context(
          const SceneQualityScore(
            overall: 95,
            prose: 90,
            coherence: 90,
            character: 90,
            completeness: 90,
            summary: '满足门槛。',
          ),
        ),
      );

      expect(output.output.qualityScore!.overall, 95);
      expect(output.retrievalTrace.thoughtCreationCount, 0);
    },
  );

  test(
    'finalization fails closed without precomputed quality evidence',
    () async {
      const step = FinalizationStep();

      await expectLater(
        step.execute(_input(), _context(null)),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'finalization rejects below-threshold evidence even when called directly',
    () async {
      const step = FinalizationStep();

      await expectLater(
        step.execute(
          _input(),
          _context(
            const SceneQualityScore(
              overall: 94.9,
              prose: 100,
              coherence: 100,
              character: 100,
              completeness: 100,
              summary: '看似不错。',
            ),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
  test(
    'finalization rejects an extended rubric faithfulness failure',
    () async {
      const step = FinalizationStep();

      await expectLater(
        step.execute(
          _input(),
          _context(
            const SceneQualityScore(
              overall: 98,
              prose: 98,
              coherence: 98,
              character: 98,
              completeness: 98,
              style: 98,
              imagery: 98,
              rhythm: 98,
              faithfulness: 89,
              summary: '事实边界存在阻断问题。',
            ),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('formal finalization requires the extended rubric', () async {
    const step = FinalizationStep();

    await expectLater(
      step.execute(
        _input(formalExecution: true),
        _context(
          const SceneQualityScore(
            overall: 98,
            prose: 98,
            coherence: 98,
            character: 98,
            completeness: 98,
            summary: '旧版评分卡。',
          ),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

PipelineContext _context(SceneQualityScore? qualityScore) {
  return PipelineContext(
    eventLog: PipelineEventLogImpl(),
    retrievalPolicy: RagRetrievalPolicy.director(),
    writebackGate: const BasicMemoryWritebackGate(),
    sceneBrief: const SceneBriefRef(projectId: 'project', sceneId: 'scene'),
    metadata: qualityScore == null ? const {} : {'qualityScore': qualityScore},
  );
}

FinalizationInput _input({bool formalExecution = false}) {
  final brief = SceneBrief(
    chapterId: 'chapter',
    chapterTitle: '第一章',
    sceneId: 'scene',
    sceneTitle: '雨夜',
    sceneSummary: '冲突升级。',
    formalExecution: formalExecution,
  );
  const prose = SceneProseDraft(text: '「停下。」她挡住了门。', attempt: 1);
  const pass = SceneReviewPassResult(
    status: SceneReviewStatus.pass,
    reason: '通过。',
    rawText: '决定：PASS\n原因：通过。',
  );
  const review = SceneReviewResult(
    judge: pass,
    consistency: pass,
    decision: SceneReviewDecision.pass,
  );
  final plan = ScenePlanningOutput(
    resolvedCast: const [],
    director: const SceneDirectorOutput(text: '推进冲突。'),
    taskCard: pipeline.SceneTaskCard(brief: brief, cast: const []),
  );
  const editorial = EditorialOutput(
    draft: pipeline.SceneEditorialDraft(
      text: '「停下。」她挡住了门。',
      beatCount: 1,
      attempt: 1,
    ),
    prose: prose,
  );
  const reviewOutput = ReviewOutput(
    review: review,
    wasLengthRetry: false,
    action: SceneReviewDecision.pass,
  );
  return FinalizationInput(
    brief: brief,
    plan: plan,
    roleplay: const RoleplayOutput(roleOutputs: [], roleTurns: []),
    beats: BeatResolutionOutput(
      resolvedBeats: const [],
      runtimeBeats: const [],
      sceneState: SceneState.initial(sceneId: 'scene'),
    ),
    editorial: editorial,
    polish: const PolishOutput(prose: prose),
    review: reviewOutput,
    context: const ContextEnrichmentOutput(
      effectiveMaterials: ProjectMaterialSnapshot(),
    ),
    attempt: 1,
    softFailureCount: 0,
    narrativeArcBeforeScene: NarrativeArcState(),
  );
}
