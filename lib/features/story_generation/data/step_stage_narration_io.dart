import 'package:novel_writer/app/rag/rag_orchestrator.dart' show RagSceneContext;

import 'step_roleplay_io.dart';
import 'step_scene_planning_io.dart';
import 'scene_pipeline_models.dart' as pipeline show ContextCapsule;

// ---------------------------------------------------------------------------
// Step 4: Stage Narration
// ---------------------------------------------------------------------------

class StageNarrationInput {
  const StageNarrationInput({
    required this.plan,
    required this.roleplay,
    this.ragContext,
  });

  final ScenePlanningOutput plan;
  final RoleplayOutput roleplay;
  final RagSceneContext? ragContext;
}

class StageNarrationOutput {
  const StageNarrationOutput({required this.capsules, this.stageCapsule});

  final List<pipeline.ContextCapsule> capsules;
  final pipeline.ContextCapsule? stageCapsule;
}
