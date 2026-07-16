import '../logging/app_event_log.dart';
import '../events/app_event_bus.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import '../state/app_ai_history_store.dart';
import '../state/app_draft_store.dart';
import '../state/app_scene_context_store.dart';
import '../state/app_settings_store.dart';
import '../state/app_simulation_store.dart';
import '../state/app_version_store.dart';
import '../state/app_workspace_store.dart';
import '../state/story_generation_store.dart';
import '../state/story_outline_store.dart';
import '../state/story_arc_store.dart';
import '../../features/writing_stats/data/writing_stats_store.dart';
import '../../features/story_generation/data/character_memory_store.dart';
import '../../features/story_generation/data/roleplay_session_store.dart';
import '../../features/story_generation/data/story_memory_storage.dart';
import '../../features/story_generation/data/story_context_cache.dart';
import '../rag/hybrid_retriever.dart';
import 'service_registry.dart';

void registerCoreServices(ServiceRegistry registry) {
  registry.registerFactory<AppWorkspaceStore>(
    (r) => AppWorkspaceStore(
      eventBus: r.resolve<AppEventBus>(),
      projectDeletionCleaners: [
        (projectId) =>
            r.resolve<RoleplaySessionStore>().clearProject(projectId),
        (projectId) =>
            r.resolve<CharacterMemoryStore>().clearProject(projectId),
        (projectId) => r.resolve<StoryMemoryStorage>().clearProject(projectId),
        (projectId) async {
          r.resolve<StoryContextCache>().invalidateProject(projectId);
        },
        (projectId) async {
          final retriever = r.resolve<HybridRetriever>();
          await Future.wait([
            retriever.ftsStorage.clearProject(projectId),
            retriever.vectorStore.clearProject(projectId),
          ]);
        },
      ],
    ),
  );

  registry.registerFactory<AppAiHistoryStore>(
    (r) => AppAiHistoryStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  registry.registerFactory<AppSceneContextStore>(
    (r) => AppSceneContextStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  registry.registerFactory<AppSimulationStore>(
    (r) => AppSimulationStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventLog: r.resolve<AppEventLog>(),
    ),
  );

  registry.registerFactory<AppDraftStore>(
    (r) => AppDraftStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  registry.registerFactory<AppVersionStore>(
    (r) => AppVersionStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  registry.registerFactory<StoryOutlineStore>(
    (r) => StoryOutlineStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  registry.registerFactory<StoryGenerationStore>(
    (r) => StoryGenerationStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  registry.registerFactory<StoryArcStore>(
    (r) => StoryArcStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  registry.registerFactory<AppSettingsStore>(
    (r) => AppSettingsStore(
      llmClient: r.resolve<AppLlmClient>(),
      requestPool: r.resolve<AppLlmRequestPool>(),
      eventLog: r.resolve<AppEventLog>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  registry.registerFactory<WritingStatsStore>(
    (r) => WritingStatsStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
}
