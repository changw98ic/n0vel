import 'package:novel_writer/app/rag/rag_orchestrator.dart' show RagSceneContext;

import 'scene_context_models.dart' show ResolvedSceneCastMember;
import 'scene_pipeline_models.dart' as pipeline show SceneTaskCard;
import 'scene_runtime_models.dart' show SceneBrief, SceneDirectorOutput;
import 'director_memory.dart' show DirectorMemory;
import 'narrative_arc_models.dart' show NarrativeArcState;

// ---------------------------------------------------------------------------
// Step 2: Scene Planning
// ---------------------------------------------------------------------------

class ScenePlanningInput {
  const ScenePlanningInput({
    required this.brief,
    this.ragContext,
    required this.directorMemory,
    required this.narrativeArc,
  });

  final SceneBrief brief;
  final RagSceneContext? ragContext;
  final DirectorMemory directorMemory;
  final NarrativeArcState narrativeArc;
}

class ScenePlanningOutput {
  const ScenePlanningOutput({
    required this.resolvedCast,
    this.consistencyConstraints,
    required this.director,
    required this.taskCard,
  });

  final List<ResolvedSceneCastMember> resolvedCast;
  final String? consistencyConstraints;
  final SceneDirectorOutput director;
  final pipeline.SceneTaskCard taskCard;
}
