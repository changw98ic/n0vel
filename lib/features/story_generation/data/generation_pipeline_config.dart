import '../../../app/state/app_workspace_store.dart';
import 'style_reference_config.dart';

class GenerationPipelineConfig {
  const GenerationPipelineConfig({
    this.maxProseRetries = 1,
    this.maxSceneReplanRetries = 1,
    this.enableWritingReference = true,
    this.styleReferenceConfig =
        const StyleReferenceConfig.defaultEnabled(),
  });

  final int maxProseRetries;
  final int maxSceneReplanRetries;
  final bool enableWritingReference;
  final StyleReferenceConfig styleReferenceConfig;

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
