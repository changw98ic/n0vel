import 'step_beat_resolution_io.dart';
import 'step_roleplay_io.dart';
import 'step_scene_planning_io.dart';
import 'step_stage_narration_io.dart';
import 'scene_pipeline_models.dart' as pipeline show SceneEditorialDraft;
import 'scene_runtime_models.dart' show SceneBrief, SceneProseDraft;
import '../domain/contracts/typed_artifact.dart';

// ---------------------------------------------------------------------------
// Step 6: Editorial
// ---------------------------------------------------------------------------

class EditorialInput extends TypedArtifact {
  const EditorialInput({
    required this.brief,
    required this.plan,
    required this.beats,
    required this.roleplay,
    required this.stage,
    required this.attempt,
    this.reviewFeedback,
    this.previousProse,
  });

  final SceneBrief brief;
  final ScenePlanningOutput plan;
  final BeatResolutionOutput beats;
  final RoleplayOutput roleplay;
  final StageNarrationOutput stage;
  final int attempt;
  final String? reviewFeedback;
  final String? previousProse;

  @override
  ArtifactType get type => ArtifactType.proseDraft;

  @override
  Map<String, Object?> toJson() =>
      {'type': type.name, 'attempt': attempt};

  @override
  int get tokenEstimate => 0;
}

class EditorialOutput extends TypedArtifact {
  const EditorialOutput({required this.draft, required this.prose});

  final pipeline.SceneEditorialDraft draft;
  final SceneProseDraft prose;

  @override
  ArtifactType get type => ArtifactType.proseDraft;

  @override
  Map<String, Object?> toJson() =>
      {'type': type.name, 'attempt': prose.attempt};

  @override
  int get tokenEstimate => 0;
}
