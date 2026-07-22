import '../../../app/state/app_workspace_store.dart';
import '../domain/literary_quality_models.dart';
import 'style_reference_config.dart';

enum SceneContentRedrawPolicy { allowContentRedraw, noContentRedraw }

class GenerationPipelineConfig {
  const GenerationPipelineConfig({
    // Two bounded rewrites let an independently reviewed polished draft
    // address a deterministic hard-gate finding without weakening the gate.
    // The review stage itself still limits any one provider call to two tries.
    this.maxProseRetries = 2,
    // Quality failure is judged after an independently reviewed polished
    // draft. Keep two bounded repair chances so a one-point miss can receive
    // a substantive revision without lowering the 95/90 admission gate.
    this.maxQualityRepairRetries = 2,
    this.maxSceneReplanRetries = 1,
    this.enableWritingReference = false,
    this.styleReferenceConfig = const StyleReferenceConfig.disabled(),
    this.maxConcurrentScenes = 2,
    this.maxSceneRetries = 2,
    this.hardGatesEnabled = true,
    this.literaryQualityGateMode = LiteraryQualityGateMode.legacy95,
    this.sceneContentRedrawPolicy = SceneContentRedrawPolicy.allowContentRedraw,
    this.generationArmPolicy = 'current-pipeline-v1',
    this.evidenceRunId,
  });

  final int maxProseRetries;

  /// A failed independent quality score may request one fresh prose revision;
  /// it never permits finalization of the failed revision.
  final int maxQualityRepairRetries;
  final int maxSceneReplanRetries;
  final bool enableWritingReference;
  final StyleReferenceConfig styleReferenceConfig;
  final int maxConcurrentScenes;
  final int maxSceneRetries;
  final bool hardGatesEnabled;
  final LiteraryQualityGateMode literaryQualityGateMode;
  final SceneContentRedrawPolicy sceneContentRedrawPolicy;
  final String generationArmPolicy;

  /// Stable caller-owned identity for one formal experiment run.
  ///
  /// Adaptive production runs do not need this value. A no-redraw run must
  /// provide it so a restart can detect an already-started or indeterminate
  /// scene before another provider request is dispatched.
  final String? evidenceRunId;

  bool get contentRedrawAllowed =>
      sceneContentRedrawPolicy == SceneContentRedrawPolicy.allowContentRedraw;

  factory GenerationPipelineConfig.fromWorkspace(
    AppWorkspaceStore workspaceStore,
  ) {
    final config = _styleReferenceConfigFromWorkspace(workspaceStore);
    return GenerationPipelineConfig(
      enableWritingReference: config.allowWritingReferenceRetrieval,
      styleReferenceConfig: config,
    );
  }
}

StyleReferenceConfig _styleReferenceConfigFromWorkspace(
  AppWorkspaceStore workspaceStore,
) {
  final profile = workspaceStore.selectedStyleProfile;
  if (profile == null) {
    return const StyleReferenceConfig.disabled();
  }
  return StyleReferenceConfig.fromProfile(
    intensity: workspaceStore.styleIntensity,
    profileId: profile.id,
    profileName: profile.name,
    profileSource: profile.source,
    profileJson: profile.jsonData,
  );
}
