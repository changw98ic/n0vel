import 'step_beat_resolution_io.dart';
import 'step_roleplay_io.dart';
import 'step_scene_planning_io.dart';
import 'step_stage_narration_io.dart';
import 'scene_pipeline_models.dart' as pipeline show SceneEditorialDraft;
import 'scene_runtime_models.dart' show SceneBrief, SceneProseDraft;

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
