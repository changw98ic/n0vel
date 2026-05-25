import '../../../features/story_generation/data/character_memory_store.dart';
import '../../../features/story_generation/data/generation_pipeline_config.dart';
import '../../../features/story_generation/data/pipeline_stage_runner_dependencies.dart';
import '../../../features/story_generation/data/pipeline_stage_runner_impl.dart';
import '../../../features/story_generation/data/roleplay_session_store.dart';
import '../../../features/story_generation/domain/story_pipeline_interfaces.dart';
import '../app_settings_store.dart';
import '../app_workspace_store.dart';

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

  ChapterGenerationService create(AppSettingsStore settingsStore) {
    return PipelineStageRunnerImpl(
      settingsStore: settingsStore,
      pipelineConfig: GenerationPipelineConfig.fromWorkspace(_workspaceStore),
      dependencies: PipelineStageRunnerDependencies(
        roleplay: PipelineRoleplayDependencies(
          roleplaySessionStore: _roleplaySessionStore,
          characterMemoryStore: _characterMemoryStore,
        ),
      ),
    );
  }
}
