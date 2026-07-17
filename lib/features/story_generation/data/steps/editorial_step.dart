import '../scene_editorial_generator.dart' show SceneEditorialGenerator;
import '../scene_pipeline_models.dart' as pipeline show LightContextCapsule;
import '../scene_runtime_models.dart' show SceneProseDraft;
import '../step_io.dart';
import '../../domain/contracts/pipeline_role_contract.dart';
import '../../domain/contracts/typed_artifact.dart';

/// Step 6: generate the prose editorial draft.
class EditorialStep implements PipelineStage<EditorialInput, EditorialOutput> {
  EditorialStep({required SceneEditorialGenerator editorialGenerator})
    : _editorialGenerator = editorialGenerator;

  final SceneEditorialGenerator _editorialGenerator;

  @override
  String get roleId => 'editorial';
  @override
  ArtifactType get outputType => ArtifactType.proseDraft;
  @override
  int get maxRetries => 2;

  @override
  Future<EditorialOutput> execute(EditorialInput input, Object context) async {
    final sceneCapsules = <pipeline.LightContextCapsule>[
      ...input.stage.capsules,
      if (input.stage.stageCapsule != null) input.stage.stageCapsule!,
    ];

    final editorialDraft = await _editorialGenerator.generate(
      taskCard: input.plan.taskCard,
      resolvedBeats: input.beats.resolvedBeats,
      capsules: sceneCapsules,
      attempt: input.attempt,
      roleplaySession: input.roleplay.session,
      reviewFeedback: input.reviewFeedback,
      previousProse: input.previousProse,
    );

    final prose = SceneProseDraft(
      text: editorialDraft.text,
      attempt: editorialDraft.attempt,
    );

    return EditorialOutput(draft: editorialDraft, prose: prose);
  }
}
