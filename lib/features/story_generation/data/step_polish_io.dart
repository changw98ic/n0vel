import 'step_beat_resolution_io.dart';
import 'step_editorial_io.dart';
import 'step_review_io.dart';
import 'scene_runtime_models.dart' show SceneBrief, SceneProseDraft;
import '../domain/contracts/typed_artifact.dart';
import 'polish_canon_evidence.dart';
import 'story_mechanics_evidence.dart';
import 'production_pre_quality_gate.dart';

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
  const PolishOutput({
    required this.prose,
    this.canonEvidence,
    this.storyMechanicsEvidence,
    this.productionPreQualityEvidence,
  });

  final SceneProseDraft prose;
  final PolishCanonEvidence? canonEvidence;
  final StoryMechanicsEvidence? storyMechanicsEvidence;
  final ProductionPreQualityEvidence? productionPreQualityEvidence;

  @override
  ArtifactType get type => ArtifactType.polishedProse;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'proseText': prose.text,
    'attempt': prose.attempt,
    if (canonEvidence != null) 'canonEvidence': canonEvidence!.toJson(),
    if (storyMechanicsEvidence != null)
      'storyMechanicsEvidence': storyMechanicsEvidence!.toJson(),
    if (productionPreQualityEvidence != null)
      'productionPreQualityEvidence': productionPreQualityEvidence!.toJson(),
  };

  @override
  int get tokenEstimate => 0;
}
