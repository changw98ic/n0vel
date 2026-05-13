import 'step_beat_resolution_io.dart';
import 'step_editorial_io.dart';
import 'step_review_io.dart';
import 'scene_runtime_models.dart' show SceneBrief, SceneProseDraft;

// ---------------------------------------------------------------------------
// Step 8: Polish
// ---------------------------------------------------------------------------

class PolishInput {
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
}

class PolishOutput {
  const PolishOutput({required this.prose});

  final SceneProseDraft prose;
}
