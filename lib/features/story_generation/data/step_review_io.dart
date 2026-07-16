import 'step_context_enrichment_io.dart';
import 'step_editorial_io.dart';
import 'step_roleplay_io.dart';
import 'step_scene_planning_io.dart';
import 'scene_review_models.dart'
    show SceneReviewResult, SceneReviewDecision, SceneReviewPassResult;
import 'scene_runtime_models.dart' show SceneBrief;
import '../domain/contracts/typed_artifact.dart';

// ---------------------------------------------------------------------------
// Step 7: Review
// ---------------------------------------------------------------------------

class ReviewInput extends TypedArtifact {
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

  @override
  ArtifactType get type => ArtifactType.reviewResult;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'attempt': attempt,
    'softFailureCount': softFailureCount,
  };

  @override
  int get tokenEstimate => 0;
}

class ReviewOutput extends TypedArtifact {
  const ReviewOutput({
    required this.review,
    required this.wasLengthRetry,
    required this.action,
  });

  final SceneReviewResult review;
  final bool wasLengthRetry;
  final SceneReviewDecision action;

  @override
  ArtifactType get type => ArtifactType.reviewResult;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'wasLengthRetry': wasLengthRetry,
    'action': action.name,
    'decision': review.decision.name,
    'judge': _passJson(review.judge),
    'consistency': _passJson(review.consistency),
  };

  @override
  int get tokenEstimate => 0;
}

Map<String, Object?> _passJson(SceneReviewPassResult value) => {
  'status': value.status.name,
  'reason': value.reason,
  'categories': [for (final category in value.categories) category.name],
};
