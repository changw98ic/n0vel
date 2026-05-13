import 'step_context_enrichment_io.dart';
import 'step_editorial_io.dart';
import 'step_roleplay_io.dart';
import 'step_scene_planning_io.dart';
import 'scene_review_models.dart'
    show SceneReviewResult, SceneReviewDecision;
import 'scene_runtime_models.dart' show SceneBrief;

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
