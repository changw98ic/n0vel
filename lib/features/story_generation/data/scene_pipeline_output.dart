part of 'scene_pipeline_models.dart';

// ---------------------------------------------------------------------------
// Pipeline runtime output (extends SceneRuntimeOutput concept)
// ---------------------------------------------------------------------------

class ScenePipelineOutput {
  ScenePipelineOutput({
    required this.taskCard,
    required List<RolePlayTurnOutput> roleTurns,
    required List<LightContextCapsule> capsules,
    required List<SceneBeat> resolvedBeats,
    required this.editorialDraft,
    required this.review,
    required this.proseAttempts,
    required this.softFailureCount,
  }) : roleTurns = _immutableList(roleTurns),
       capsules = _immutableList(capsules),
       resolvedBeats = _immutableList(resolvedBeats);

  final SceneTaskCard taskCard;
  final List<RolePlayTurnOutput> roleTurns;
  final List<LightContextCapsule> capsules;
  final List<SceneBeat> resolvedBeats;
  final SceneEditorialDraft editorialDraft;
  final SceneReviewResult review;
  final int proseAttempts;
  final int softFailureCount;
}
