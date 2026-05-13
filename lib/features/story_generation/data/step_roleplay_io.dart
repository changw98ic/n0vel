import 'package:novel_writer/app/rag/rag_orchestrator.dart' show RagSceneContext;

import 'step_scene_planning_io.dart';
import 'scene_pipeline_models.dart' as pipeline show RolePlayTurnOutput;
import 'scene_roleplay_session_models.dart' show SceneRoleplaySession;
import 'scene_runtime_models.dart' show SceneBrief, DynamicRoleAgentOutput;

// ---------------------------------------------------------------------------
// Step 3: Roleplay
// ---------------------------------------------------------------------------

class RoleplayInput {
  const RoleplayInput({
    required this.brief,
    required this.plan,
    this.ragContext,
  });

  final SceneBrief brief;
  final ScenePlanningOutput plan;
  final RagSceneContext? ragContext;
}

class RoleplayOutput {
  const RoleplayOutput({
    required this.roleOutputs,
    this.session,
    required this.roleTurns,
  });

  final List<DynamicRoleAgentOutput> roleOutputs;
  final SceneRoleplaySession? session;
  final List<pipeline.RolePlayTurnOutput> roleTurns;
}
