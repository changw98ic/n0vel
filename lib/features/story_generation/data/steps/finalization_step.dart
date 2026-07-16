import '../../domain/memory_models.dart';
import '../../domain/scene_models.dart';
import '../step_io.dart';
import '../../domain/contracts/pipeline_role_contract.dart';
import '../../domain/contracts/typed_artifact.dart';
import '../../domain/contracts/stage_runner.dart';

class FinalizationStep
    implements PipelineStage<FinalizationInput, FinalizationOutput> {
  const FinalizationStep();

  @override
  String get roleId => 'finalization';
  @override
  ArtifactType get outputType => ArtifactType.sceneOutput;
  @override
  int get maxRetries => 2;

  @override
  Future<FinalizationOutput> execute(
    FinalizationInput input,
    Object context,
  ) async {
    final brief = input.brief;
    final plan = input.plan;
    final roleplay = input.roleplay;
    final beats = input.beats;
    final polish = input.polish;
    final review = input.review;
    final enrichment = input.context;
    final pipelineContext = context is PipelineContext ? context : null;
    final qualityScore = pipelineContext?.metadata['qualityScore'];
    final reviewAttempts = _reviewAttemptsFrom(pipelineContext);
    if (qualityScore is! SceneQualityScore) {
      throw StateError(
        'Finalization requires a precomputed, passing quality score. '
        'It must never call a provider itself.',
      );
    }
    if (review.review.decision != SceneReviewDecision.pass) {
      throw StateError(
        'Finalization requires a passing final council review for the exact prose revision.',
      );
    }
    final scoreValues = [
      qualityScore.overall,
      qualityScore.prose,
      qualityScore.coherence,
      qualityScore.character,
      qualityScore.completeness,
      if (qualityScore.hasExtendedRubric) ...[
        qualityScore.styleScore,
        qualityScore.imageryScore,
        qualityScore.rhythmScore,
        qualityScore.faithfulnessScore,
      ],
    ];
    final requiresExtendedRubric =
        brief.formalExecution ||
        brief.metadata['requireExtendedQualityRubric'] == true;
    if (qualityScore.warning != null ||
        qualityScore.summary.trim().isEmpty ||
        scoreValues.any(
          (value) => !value.isFinite || value < 0 || value > 100,
        ) ||
        (requiresExtendedRubric && !qualityScore.hasExtendedRubric) ||
        qualityScore.overall < 95 ||
        scoreValues.skip(1).any((value) => value < 90)) {
      throw StateError(
        'Finalization requires overall>=95, all critical dimensions>=90, '
        'and the extended formal rubric when required.',
      );
    }

    // 1. Build RetrievalTrace from context data.
    final retrievalTrace = RetrievalTrace(
      query: StoryMemoryQuery(
        projectId: brief.projectId ?? brief.chapterId,
        queryType: StoryMemoryQueryType.sceneContinuity,
        text: '${brief.sceneTitle} ${brief.sceneSummary}',
      ),
      selectedHitCount: enrichment.retrievalPack?.hits.length ?? 0,
      deferredHitCount: enrichment.retrievalPack?.deferredHitCount ?? 0,
      thoughtCreationCount: 0,
      rejectedThoughtCount: 0,
      indexedChunkCount: enrichment.cachedAssembly?.memoryChunks.length ?? 0,
      sourceRefIds: enrichment.retrievalPack != null
          ? [
              for (final h in enrichment.retrievalPack!.hits)
                ...h.chunk.rootSourceIds,
            ]
          : const [],
    );

    // Finalization is deliberately provider-free. It only assembles evidence
    // produced by the preceding final-review and quality-gate stages.
    final output = SceneRuntimeOutput(
      brief: brief,
      resolvedCast: plan.resolvedCast,
      director: plan.director,
      roleOutputs: roleplay.roleOutputs,
      resolvedBeats: beats.runtimeBeats,
      sceneState: beats.sceneState,
      roleplaySession: roleplay.session,
      prose: polish.prose,
      review: review.review,
      proseAttempts: input.attempt,
      softFailureCount: input.softFailureCount,
      reviewAttempts: reviewAttempts,
      qualityScore: qualityScore,
      polishCanonEvidence: polish.canonEvidence,
      storyMechanicsEvidence: polish.storyMechanicsEvidence,
      productionPreQualityEvidence: polish.productionPreQualityEvidence
          ?.toJson(),
    );

    return FinalizationOutput(output: output, retrievalTrace: retrievalTrace);
  }
}

List<SceneReviewAttempt> _reviewAttemptsFrom(PipelineContext? context) {
  final raw = context?.metadata['reviewAttempts'];
  if (raw == null) return const <SceneReviewAttempt>[];
  if (raw is! List || raw.any((item) => item is! SceneReviewAttempt)) {
    throw StateError(
      'Finalization reviewAttempts metadata must contain only '
      'SceneReviewAttempt values.',
    );
  }
  return List<SceneReviewAttempt>.unmodifiable(raw.cast<SceneReviewAttempt>());
}
