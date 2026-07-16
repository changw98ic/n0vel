import 'package:novel_writer/app/rag/hybrid_retriever.dart'
    show RagSceneContext;

import 'step_scene_planning_io.dart';
import 'scene_pipeline_models.dart' as pipeline show RolePlayTurnOutput;
import 'scene_roleplay_session_models.dart' show SceneRoleplaySession;
import 'scene_runtime_models.dart' show SceneBrief, DynamicRoleAgentOutput;
import '../domain/contracts/typed_artifact.dart';

// ---------------------------------------------------------------------------
// Step 3: Roleplay
// ---------------------------------------------------------------------------

class RoleplayInput extends TypedArtifact {
  const RoleplayInput({
    required this.brief,
    required this.plan,
    this.ragContext,
  });

  final SceneBrief brief;
  final ScenePlanningOutput plan;
  final RagSceneContext? ragContext;

  @override
  ArtifactType get type => ArtifactType.roleplaySession;

  @override
  Map<String, Object?> toJson() => {'type': type.name};

  @override
  int get tokenEstimate => 0;
}

class RoleplayOutput extends TypedArtifact {
  const RoleplayOutput({
    required this.roleOutputs,
    this.session,
    required this.roleTurns,
  });

  final List<DynamicRoleAgentOutput> roleOutputs;
  final SceneRoleplaySession? session;
  final List<pipeline.RolePlayTurnOutput> roleTurns;

  @override
  ArtifactType get type => ArtifactType.roleplaySession;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'resumeSafe': session == null && roleTurns.isEmpty,
    'roleOutputs': [
      for (final output in roleOutputs)
        {
          'characterId': output.characterId,
          'name': output.name,
          'text': output.text,
        },
    ],
    'roleOutputCount': roleOutputs.length,
    'roleTurnCount': roleTurns.length,
  };

  @override
  int get tokenEstimate => 0;
}
