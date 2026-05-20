import 'step_beat_resolution_io.dart';
import 'step_editorial_io.dart';
import 'step_review_io.dart';
import 'scene_runtime_models.dart' show SceneBrief, SceneProseDraft;
import '../domain/contracts/typed_artifact.dart';

// ---------------------------------------------------------------------------
// Step 8: Polish
// ---------------------------------------------------------------------------

class PolishInput extends TypedArtifact {
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

  @override
  ArtifactType get type => ArtifactType.polishedProse;

  @override
  Map<String, Object?> toJson() => {'type': type.name};

  @override
  int get tokenEstimate => 0;
}

class PolishOutput extends TypedArtifact {
  const PolishOutput({required this.prose});

  final SceneProseDraft prose;

  @override
  ArtifactType get type => ArtifactType.polishedProse;

  @override
  Map<String, Object?> toJson() =>
      {'type': type.name, 'attempt': prose.attempt};

  @override
  int get tokenEstimate => 0;
}
