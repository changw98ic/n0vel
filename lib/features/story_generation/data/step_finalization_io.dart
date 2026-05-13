import 'step_beat_resolution_io.dart';
import 'step_context_enrichment_io.dart';
import 'step_editorial_io.dart';
import 'step_polish_io.dart';
import 'step_review_io.dart';
import 'step_roleplay_io.dart';
import 'step_scene_planning_io.dart';
import 'scene_review_models.dart' show SceneRuntimeOutput;
import 'scene_runtime_models.dart' show SceneBrief;
import 'narrative_arc_models.dart' show NarrativeArcState;
import '../domain/memory_models.dart' show RetrievalTrace;

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
