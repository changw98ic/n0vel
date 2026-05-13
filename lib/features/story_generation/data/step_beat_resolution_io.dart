import 'step_roleplay_io.dart';
import 'step_scene_planning_io.dart';
import 'step_stage_narration_io.dart';
import 'scene_pipeline_models.dart' as pipeline show SceneBeat;
import 'scene_runtime_models.dart' show SceneBrief, ResolvedBeat, SceneState;

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
