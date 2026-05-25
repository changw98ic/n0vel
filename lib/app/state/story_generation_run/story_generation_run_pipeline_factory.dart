part of '../story_generation_run_store.dart';

class StoryGenerationRunPipelineFactory {
  const StoryGenerationRunPipelineFactory({
    required AppWorkspaceStore workspaceStore,
    RoleplaySessionStore? roleplaySessionStore,
    CharacterMemoryStore? characterMemoryStore,
  }) : _workspaceStore = workspaceStore,
       _roleplaySessionStore = roleplaySessionStore,
       _characterMemoryStore = characterMemoryStore;

  final AppWorkspaceStore _workspaceStore;
  final RoleplaySessionStore? _roleplaySessionStore;
  final CharacterMemoryStore? _characterMemoryStore;

  PipelineStageRunnerImpl create(AppSettingsStore settingsStore) {
    return PipelineStageRunnerImpl(
      settingsStore: settingsStore,
      pipelineConfig: GenerationPipelineConfig.fromWorkspace(_workspaceStore),
      roleplaySessionStore: _roleplaySessionStore,
      characterMemoryStore: _characterMemoryStore,
    );
  }
}
