import '../retrieval_controller.dart' show RetrievalController;
import '../scene_stage_narrator.dart' show SceneStageNarrator;
import '../step_io.dart';

/// Step 4: resolve retrieval capsules and generate stage narration.
class StageNarrationStep {
  StageNarrationStep({
    required SceneStageNarrator stageNarrator,
    required RetrievalController retrievalController,
  })  : _stageNarrator = stageNarrator,
        _retrievalController = retrievalController;

  final SceneStageNarrator _stageNarrator;
  final RetrievalController _retrievalController;

  Future<StageNarrationOutput> execute(
    StageNarrationInput input, {
    void Function(String)? onStatus,
  }) async {
    final taskCard = input.plan.taskCard;
    final director = input.plan.director;
    final roleOutputs = input.roleplay.roleOutputs;
    final roleTurns = input.roleplay.roleTurns;

    final capsules = _retrievalController.resolve(
      taskCard: taskCard,
      turns: roleTurns,
    );

    final stageCapsule = await _stageNarrator.generate(
      taskCard: taskCard,
      director: director,
      roleOutputs: roleOutputs,
      roleTurns: roleTurns,
      retrievalCapsules: capsules,
      roleplaySession: input.roleplay.session,
      ragContext: input.ragContext?.formattedContext,
      onStatus: onStatus,
    );

    return StageNarrationOutput(
      capsules: capsules,
      stageCapsule: stageCapsule,
    );
  }
}
