import '../narrative_arc_tracker.dart';
import '../../domain/memory_models.dart';
import '../../domain/scene_models.dart';
import '../../domain/story_pipeline_interfaces.dart';
import '../step_io.dart';
import '../../domain/contracts/memory_writeback_gate.dart';
import '../../domain/contracts/pipeline_role_contract.dart';
import '../../domain/contracts/typed_artifact.dart';

class FinalizationStep
    implements PipelineStage<FinalizationInput, FinalizationOutput> {
  FinalizationStep({
    SceneQualityScorerService? qualityScorer,
    ThoughtMemoryService? thoughtUpdater,
    MemoryWritebackGate writebackGate = const BasicMemoryWritebackGate(),
    required NarrativeArcTracker narrativeArcTracker,
  }) : _qualityScorer = qualityScorer,
       _thoughtUpdater = thoughtUpdater,
       _writebackGate = writebackGate,
       _narrativeArcTracker = narrativeArcTracker;

  final SceneQualityScorerService? _qualityScorer;
  final ThoughtMemoryService? _thoughtUpdater;
  final MemoryWritebackGate _writebackGate;
  final NarrativeArcTracker _narrativeArcTracker;

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
    final context = input.context;

    // 1. Build RetrievalTrace from context data.
    var retrievalTrace = RetrievalTrace(
      query: StoryMemoryQuery(
        projectId: brief.projectId ?? brief.chapterId,
        queryType: StoryMemoryQueryType.sceneContinuity,
        text: '${brief.sceneTitle} ${brief.sceneSummary}',
      ),
      selectedHitCount: context.retrievalPack?.hits.length ?? 0,
      deferredHitCount: context.retrievalPack?.deferredHitCount ?? 0,
      thoughtCreationCount: 0,
      rejectedThoughtCount: 0,
      indexedChunkCount: context.cachedAssembly?.memoryChunks.length ?? 0,
      sourceRefIds: context.retrievalPack != null
          ? [
              for (final h in context.retrievalPack!.hits)
                ...h.chunk.rootSourceIds,
            ]
          : const [],
    );

    // 2. Score quality. Failure must not block the pipeline, but should be
    // visible in downstream reports.
    SceneQualityScore? qualityScore;
    if (_qualityScorer != null) {
      try {
        qualityScore = await _qualityScorer.score(
          brief: brief,
          director: plan.director,
          prose: polish.prose,
          review: review.review,
        );
      } on Object catch (error) {
        qualityScore = SceneQualityScore(
          overall: 0,
          prose: 0,
          coherence: 0,
          character: 0,
          completeness: 0,
          summary: '未评分',
          warning: 'quality scorer failed: $error',
        );
      }
    }

    // 3. Assemble SceneRuntimeOutput.
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
      qualityScore: qualityScore,
    );

    // 4. Post-scene thought extraction (only if review passed).
    if (review.review.decision == SceneReviewDecision.pass &&
        _thoughtUpdater != null) {
      // Persistence owns the concrete write; this keeps the runner-provided
      // gate anchored at the finalization stage boundary.
      await _writebackGate.validate(const []);
      final thoughtResult = await _thoughtUpdater.extractWithLlm(
        projectId: brief.projectId ?? brief.chapterId,
        sceneOutput: output,
      );
      retrievalTrace = RetrievalTrace(
        query: retrievalTrace.query,
        selectedHitCount: retrievalTrace.selectedHitCount,
        deferredHitCount: retrievalTrace.deferredHitCount,
        thoughtCreationCount: thoughtResult.accepted.length,
        rejectedThoughtCount: thoughtResult.rejected.length,
        indexedChunkCount: retrievalTrace.indexedChunkCount,
        sourceRefIds: retrievalTrace.sourceRefIds,
      );
    }

    // 5. Update narrative arc (only if review passed).
    if (review.review.decision == SceneReviewDecision.pass) {
      _narrativeArcTracker.update(
        current: input.narrativeArcBeforeScene,
        output: output,
      );
    }

    return FinalizationOutput(output: output, retrievalTrace: retrievalTrace);
  }
}
