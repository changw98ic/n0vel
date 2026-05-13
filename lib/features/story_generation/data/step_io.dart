import 'package:novel_writer/app/rag/rag_orchestrator.dart' show RagSceneContext;

import 'scene_context_models.dart' show ResolvedSceneCastMember;
import 'scene_pipeline_models.dart' as pipeline
    show
        SceneTaskCard,
        SceneBeat,
        SceneEditorialDraft,
        RolePlayTurnOutput,
        ContextCapsule;
import 'scene_review_models.dart'
    show SceneReviewResult, SceneReviewDecision, SceneRuntimeOutput;
import 'scene_roleplay_session_models.dart' show SceneRoleplaySession;
import 'scene_runtime_models.dart'
    show
        SceneBrief,
        SceneDirectorOutput,
        DynamicRoleAgentOutput,
        SceneProseDraft,
        ResolvedBeat,
        SceneState;
import 'director_memory.dart' show DirectorMemory;
import 'narrative_arc_models.dart' show NarrativeArcState;
import '../domain/memory_models.dart' show StoryRetrievalPack, RetrievalTrace;
import '../domain/scene_models.dart'
    show ProjectMaterialSnapshot, SceneContextAssembly;

// ---------------------------------------------------------------------------
// Step 1: Context Enrichment
// ---------------------------------------------------------------------------

class ContextEnrichmentInput {
  const ContextEnrichmentInput({required this.brief, this.materials});

  final SceneBrief brief;
  final ProjectMaterialSnapshot? materials;
}

class ContextEnrichmentOutput {
  const ContextEnrichmentOutput({
    required this.effectiveMaterials,
    this.retrievalPack,
    this.ragContext,
    this.cachedAssembly,
  });

  final ProjectMaterialSnapshot effectiveMaterials;
  final StoryRetrievalPack? retrievalPack;
  final RagSceneContext? ragContext;
  final SceneContextAssembly? cachedAssembly;
}

// ---------------------------------------------------------------------------
// Step 2: Scene Planning
// ---------------------------------------------------------------------------

class ScenePlanningInput {
  const ScenePlanningInput({
    required this.brief,
    this.ragContext,
    required this.directorMemory,
    required this.narrativeArc,
  });

  final SceneBrief brief;
  final RagSceneContext? ragContext;
  final DirectorMemory directorMemory;
  final NarrativeArcState narrativeArc;
}

class ScenePlanningOutput {
  const ScenePlanningOutput({
    required this.resolvedCast,
    this.consistencyConstraints,
    required this.director,
    required this.taskCard,
  });

  final List<ResolvedSceneCastMember> resolvedCast;
  final String? consistencyConstraints;
  final SceneDirectorOutput director;
  final pipeline.SceneTaskCard taskCard;
}

// ---------------------------------------------------------------------------
// Step 3: Roleplay
// ---------------------------------------------------------------------------

class RoleplayInput {
  const RoleplayInput({
    required this.brief,
    required this.plan,
    this.ragContext,
  });

  final SceneBrief brief;
  final ScenePlanningOutput plan;
  final RagSceneContext? ragContext;
}

class RoleplayOutput {
  const RoleplayOutput({
    required this.roleOutputs,
    this.session,
    required this.roleTurns,
  });

  final List<DynamicRoleAgentOutput> roleOutputs;
  final SceneRoleplaySession? session;
  final List<pipeline.RolePlayTurnOutput> roleTurns;
}

// ---------------------------------------------------------------------------
// Step 4: Stage Narration
// ---------------------------------------------------------------------------

class StageNarrationInput {
  const StageNarrationInput({
    required this.plan,
    required this.roleplay,
    this.ragContext,
  });

  final ScenePlanningOutput plan;
  final RoleplayOutput roleplay;
  final RagSceneContext? ragContext;
}

class StageNarrationOutput {
  const StageNarrationOutput({required this.capsules, this.stageCapsule});

  final List<pipeline.ContextCapsule> capsules;
  final pipeline.ContextCapsule? stageCapsule;
}

// ---------------------------------------------------------------------------
// Step 5: Beat Resolution
// ---------------------------------------------------------------------------

class BeatResolutionInput {
  const BeatResolutionInput({
    required this.brief,
    required this.plan,
    required this.roleplay,
    required this.stage,
  });

  final SceneBrief brief;
  final ScenePlanningOutput plan;
  final RoleplayOutput roleplay;
  final StageNarrationOutput stage;
}

class BeatResolutionOutput {
  const BeatResolutionOutput({
    required this.resolvedBeats,
    required this.runtimeBeats,
    required this.sceneState,
  });

  final List<pipeline.SceneBeat> resolvedBeats;
  final List<ResolvedBeat> runtimeBeats;
  final SceneState sceneState;
}

// ---------------------------------------------------------------------------
// Step 6: Editorial
// ---------------------------------------------------------------------------

class EditorialInput {
  const EditorialInput({
    required this.brief,
    required this.plan,
    required this.beats,
    required this.roleplay,
    required this.stage,
    required this.attempt,
    this.reviewFeedback,
  });

  final SceneBrief brief;
  final ScenePlanningOutput plan;
  final BeatResolutionOutput beats;
  final RoleplayOutput roleplay;
  final StageNarrationOutput stage;
  final int attempt;
  final String? reviewFeedback;
}

class EditorialOutput {
  const EditorialOutput({required this.draft, required this.prose});

  final pipeline.SceneEditorialDraft draft;
  final SceneProseDraft prose;
}

// ---------------------------------------------------------------------------
// Step 7: Review
// ---------------------------------------------------------------------------

class ReviewInput {
  const ReviewInput({
    required this.brief,
    required this.plan,
    required this.roleplay,
    required this.editorial,
    required this.context,
    required this.attempt,
    required this.softFailureCount,
  });

  final SceneBrief brief;
  final ScenePlanningOutput plan;
  final RoleplayOutput roleplay;
  final EditorialOutput editorial;
  final ContextEnrichmentOutput context;
  final int attempt;
  final int softFailureCount;
}

class ReviewOutput {
  const ReviewOutput({
    required this.review,
    required this.wasLengthRetry,
    required this.action,
  });

  final SceneReviewResult review;
  final bool wasLengthRetry;
  final SceneReviewDecision action;
}

// ---------------------------------------------------------------------------
// Step 8: Polish
// ---------------------------------------------------------------------------

class PolishInput {
  const PolishInput({
    required this.brief,
    required this.editorial,
    required this.beats,
    required this.review,
  });

  final SceneBrief brief;
  final EditorialOutput editorial;
  final BeatResolutionOutput beats;
  final ReviewOutput review;
}

class PolishOutput {
  const PolishOutput({required this.prose});

  final SceneProseDraft prose;
}

// ---------------------------------------------------------------------------
// Step 9: Finalization
// ---------------------------------------------------------------------------

class FinalizationInput {
  const FinalizationInput({
    required this.brief,
    required this.plan,
    required this.roleplay,
    required this.beats,
    required this.editorial,
    required this.polish,
    required this.review,
    required this.context,
    required this.attempt,
    required this.softFailureCount,
    required this.narrativeArcBeforeScene,
  });

  final SceneBrief brief;
  final ScenePlanningOutput plan;
  final RoleplayOutput roleplay;
  final BeatResolutionOutput beats;
  final EditorialOutput editorial;
  final PolishOutput polish;
  final ReviewOutput review;
  final ContextEnrichmentOutput context;
  final int attempt;
  final int softFailureCount;
  final NarrativeArcState narrativeArcBeforeScene;
}

class FinalizationOutput {
  const FinalizationOutput({required this.output, required this.retrievalTrace});

  final SceneRuntimeOutput output;
  final RetrievalTrace retrievalTrace;
}
