import '../../../app/state/app_workspace_store.dart';
import 'style_reference_config.dart';

class GenerationPipelineConfig {
  const GenerationPipelineConfig({
    this.maxProseRetries = 1,
    this.maxSceneReplanRetries = 1,
    this.enableWritingReference = true,
    this.styleReferenceConfig =
        const StyleReferenceConfig.defaultEnabled(),
    this.maxConcurrentScenes = 2,
    this.maxSceneRetries = 2,
  });

  final int maxProseRetries;
  final int maxSceneReplanRetries;
  final bool enableWritingReference;
  final StyleReferenceConfig styleReferenceConfig;
  final int maxConcurrentScenes;
  final int maxSceneRetries;

  factory GenerationPipelineConfig.fromWorkspace(
    AppWorkspaceStore workspaceStore,
  ) {
    final config = _styleReferenceConfigFromWorkspace(workspaceStore);
    return GenerationPipelineConfig(
      enableWritingReference: config.enabled,
      styleReferenceConfig: config,
    );
  }
}

StyleReferenceConfig _styleReferenceConfigFromWorkspace(
  AppWorkspaceStore workspaceStore,
) {
  final profile = workspaceStore.selectedStyleProfile;
  if (profile == null) {
    return const StyleReferenceConfig(enabled: false);
  }
  return StyleReferenceConfig.fromProfile(
    intensity: workspaceStore.styleIntensity,
    profileId: profile.id,
    profileName: profile.name,
    profileSource: profile.source,
    profileJson: profile.jsonData,
  );
}
