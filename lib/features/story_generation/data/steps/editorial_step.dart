import '../scene_editorial_generator.dart' show SceneEditorialGenerator;
import '../scene_pipeline_models.dart' as pipeline show LightContextCapsule;
import '../scene_runtime_models.dart' show SceneProseDraft;
import '../step_io.dart';

/// Step 6: generate the prose editorial draft.
class EditorialStep {
  EditorialStep({required SceneEditorialGenerator editorialGenerator})
      : _editorialGenerator = editorialGenerator;

  final SceneEditorialGenerator _editorialGenerator;

  Future<EditorialOutput> execute(
    EditorialInput input, {
    void Function(String)? onStatus,
  }) async {
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
