import '../retrieval_controller.dart' show RetrievalController;
import '../scene_stage_narrator.dart' show SceneStageNarrator;
import '../step_io.dart';
import '../../domain/contracts/pipeline_role_contract.dart';
import '../../domain/contracts/typed_artifact.dart';

/// Step 4: resolve retrieval capsules and generate stage narration.
class StageNarrationStep
    implements PipelineStage<StageNarrationInput, StageNarrationOutput> {
  StageNarrationStep({
    required SceneStageNarrator stageNarrator,
    required RetrievalController retrievalController,
  }) : _stageNarrator = stageNarrator,
       _retrievalController = retrievalController;

  final SceneStageNarrator _stageNarrator;
  final RetrievalController _retrievalController;

  @override
  String get roleId => 'stage_narration';
  @override
  ArtifactType get outputType => ArtifactType.stageNarration;
  @override
  int get maxRetries => 2;

  @override
  Future<StageNarrationOutput> execute(
    StageNarrationInput input,
    Object context,
  ) async {
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
    );

    return StageNarrationOutput(capsules: capsules, stageCapsule: stageCapsule);
  }
}
