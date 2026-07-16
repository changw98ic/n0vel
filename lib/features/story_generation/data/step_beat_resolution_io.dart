import 'step_roleplay_io.dart';
import 'step_scene_planning_io.dart';
import 'step_stage_narration_io.dart';
import 'scene_pipeline_models.dart' as pipeline show SceneBeat;
import 'scene_runtime_models.dart' show SceneBrief, ResolvedBeat, SceneState;
import '../domain/contracts/typed_artifact.dart';

// ---------------------------------------------------------------------------
// Step 5: Beat Resolution
// ---------------------------------------------------------------------------

class BeatResolutionInput extends TypedArtifact {
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

  @override
  ArtifactType get type => ArtifactType.beatResolution;

  @override
  Map<String, Object?> toJson() => {'type': type.name};

  @override
  int get tokenEstimate => 0;
}

class BeatResolutionOutput extends TypedArtifact {
  const BeatResolutionOutput({
    required this.resolvedBeats,
    required this.runtimeBeats,
    required this.sceneState,
  });

  final List<pipeline.SceneBeat> resolvedBeats;
  final List<ResolvedBeat> runtimeBeats;
  final SceneState sceneState;

  @override
  ArtifactType get type => ArtifactType.beatResolution;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'resumeSafe':
        runtimeBeats.isEmpty &&
        resolvedBeats.isEmpty &&
        sceneState.turnIndex == 0 &&
        sceneState.beatIndex == 0 &&
        sceneState.locationState.isEmpty &&
        sceneState.openThreats.isEmpty,
    'beatCount': runtimeBeats.length,
  };

  @override
  int get tokenEstimate => 0;
}
