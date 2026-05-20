import 'package:novel_writer/app/rag/hybrid_retriever.dart' show RagSceneContext;

import 'step_roleplay_io.dart';
import 'step_scene_planning_io.dart';
import 'scene_pipeline_models.dart' as pipeline show LightContextCapsule;
import '../domain/contracts/typed_artifact.dart';

// ---------------------------------------------------------------------------
// Step 4: Stage Narration
// ---------------------------------------------------------------------------

class StageNarrationInput extends TypedArtifact {
  const StageNarrationInput({
    required this.plan,
    required this.roleplay,
    this.ragContext,
  });

  final ScenePlanningOutput plan;
  final RoleplayOutput roleplay;
  final RagSceneContext? ragContext;

  @override
  ArtifactType get type => ArtifactType.stageNarration;

  @override
  Map<String, Object?> toJson() => {'type': type.name};

  @override
  int get tokenEstimate => 0;
}

class StageNarrationOutput extends TypedArtifact {
  const StageNarrationOutput({required this.capsules, this.stageCapsule});

  final List<pipeline.LightContextCapsule> capsules;
  final pipeline.LightContextCapsule? stageCapsule;

  @override
  ArtifactType get type => ArtifactType.stageNarration;

  @override
  Map<String, Object?> toJson() =>
      {'type': type.name, 'capsuleCount': capsules.length};

  @override
  int get tokenEstimate => 0;
}
