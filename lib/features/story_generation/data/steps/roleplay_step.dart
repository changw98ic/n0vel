import '../dynamic_role_agent_runner.dart';
import '../retrieval_controller.dart';
import '../roleplay_session_store.dart';
import '../character_memory_store.dart';
import '../scene_roleplay_session_models.dart';
import '../scene_pipeline_models.dart' as pipeline;
import '../scene_runtime_models.dart' show SceneBrief, DynamicRoleAgentOutput;
import '../../domain/story_pipeline_interfaces.dart'
    show DynamicRoleAgentService;
import '../step_io.dart';

/// Step 3: Runs dynamic role agents, persists roleplay session and character
/// memory deltas, converts outputs to pipeline format, and resolves retrieval
/// capsules.
///
/// Extracted from [ChapterGenerationOrchestrator] lines 305-328 plus helper
/// method 659-686.
class RoleplayStep {
  RoleplayStep({
    required DynamicRoleAgentService dynamicRoleAgentRunner,
    RoleplaySessionStore? roleplaySessionStore,
    CharacterMemoryStore? characterMemoryStore,
    required RetrievalController retrievalController,
  }) : _dynamicRoleAgentRunner = dynamicRoleAgentRunner,
       _roleplaySessionStore = roleplaySessionStore,
       _characterMemoryStore = characterMemoryStore,
       _retrievalController = retrievalController;

  final DynamicRoleAgentService _dynamicRoleAgentRunner;
  final RoleplaySessionStore? _roleplaySessionStore;
  final CharacterMemoryStore? _characterMemoryStore;
  final RetrievalController _retrievalController;

  /// Executes the roleplay step.
  ///
  /// - Runs dynamic role agents via [DynamicRoleAgentService].
  /// - Extracts and persists the roleplay session (only when runner is a
  ///   [DynamicRoleAgentRunner] concrete type).
  /// - Converts [DynamicRoleAgentOutput]s to pipeline [RolePlayTurnOutput]s.
  /// - Resolves retrieval capsules via [RetrievalController].
  Future<RoleplayOutput> execute(
    RoleplayInput input, {
    bool Function()? isRunCancelled,
    void Function(String)? onStatus,
  }) async {
    final brief = input.brief;
    final plan = input.plan;

    final agentResult = await _dynamicRoleAgentRunner.run(
      brief: brief,
      cast: plan.resolvedCast,
      director: plan.director,
      taskCard: plan.taskCard,
      ragContext: input.ragContext?.formattedContext,
      onStatus: onStatus,
    );

    final roleOutputs = agentResult.outputs;
    final roleplaySession = agentResult.session;

    await _persistRoleplaySession(
      projectId: brief.projectId ?? brief.chapterId,
      brief: brief,
      session: roleplaySession,
      isRunCancelled: isRunCancelled,
    );

    // Convert to pipeline format
    final roleTurns = [
      for (final output in roleOutputs)
        pipeline.RolePlayTurnOutput.fromDynamicAgentOutput(output),
    ];

    // Resolve retrieval capsules (consumed by downstream stages)
    _retrievalController.resolve(taskCard: plan.taskCard, turns: roleTurns);

    return RoleplayOutput(
      roleOutputs: roleOutputs,
      session: roleplaySession,
      roleTurns: roleTurns,
    );
  }

  /// Persists the roleplay session and its accepted character memory deltas.
  ///
  /// Skips when [session] is null or empty. Also skips character memory writes
  /// when [isRunCancelled] returns true.
  Future<void> _persistRoleplaySession({
    required String projectId,
    required SceneBrief brief,
    required SceneRoleplaySession? session,
    bool Function()? isRunCancelled,
  }) async {
    if (session == null || session.isEmpty) {
      return;
    }
    await _roleplaySessionStore?.saveSession(
      projectId: projectId,
      session: session,
    );
    if (isRunCancelled?.call() == true) {
      return;
    }
    final acceptedDeltas = session.acceptedMemoryDeltas
        .where((delta) => delta.accepted)
        .toList(growable: false);
    if (acceptedDeltas.isEmpty) {
      return;
    }
    await _characterMemoryStore?.saveAcceptedDeltas(
      projectId: projectId,
      chapterId: brief.chapterId,
      sceneId: brief.sceneId,
      deltas: acceptedDeltas,
    );
  }
}
