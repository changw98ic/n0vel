import 'package:novel_writer/app/rag/hybrid_retriever.dart'
    show RagSceneContext;

import 'scene_context_models.dart' show ResolvedSceneCastMember;
import 'scene_pipeline_models.dart' as pipeline show SceneTaskCard;
import 'scene_runtime_models.dart' show SceneBrief, SceneDirectorOutput;
import 'director_memory.dart' show DirectorMemory;
import 'narrative_arc_models.dart' show NarrativeArcState;
import '../domain/contracts/typed_artifact.dart';

// ---------------------------------------------------------------------------
// Step 2: Scene Planning
// ---------------------------------------------------------------------------

class ScenePlanningInput extends TypedArtifact {
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

  @override
  ArtifactType get type => ArtifactType.directorPlan;

  @override
  Map<String, Object?> toJson() => {'type': type.name};

  @override
  int get tokenEstimate => 0;
}

class ScenePlanningOutput extends TypedArtifact {
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

  @override
  ArtifactType get type => ArtifactType.directorPlan;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'resumeSafe': resolvedCast.every(
      (member) => member.profile == null && member.metadata.isEmpty,
    ),
    'consistencyConstraints': consistencyConstraints,
    'directorText': director.text,
    'directorPlan': taskCard.directorPlan,
    'cast': [
      for (final member in resolvedCast)
        {
          'characterId': member.characterId,
          'name': member.name,
          'role': member.role,
          'contributions': [for (final item in member.contributions) item.name],
        },
    ],
  };

  @override
  int get tokenEstimate => 0;
}
