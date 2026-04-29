import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../state/app_ai_history_store.dart';
import '../state/app_draft_store.dart';
import '../state/app_scene_context_store.dart';
import '../state/app_settings_store.dart';
import '../state/app_simulation_store.dart';
import '../state/app_version_store.dart';
import '../state/app_workspace_store.dart';
import '../state/story_generation_run_store.dart';
import '../state/story_generation_store.dart';
import '../state/story_outline_store.dart';
import 'service_registry.dart';
import '../../features/author_feedback/data/author_feedback_store.dart';
import '../../features/review_tasks/data/review_task_store.dart';

/// Register all application-level services into [registry].
///
/// Call this once at app startup, then use [registry.resolve] to obtain
/// instances. Dependencies are resolved lazily — factories run only on
/// first access.
void registerAppServices(ServiceRegistry registry) {
  // --- Infrastructure (no app-level deps) ---

  registry.registerFactory<AppEventLog>((_) => AppEventLog());

  // --- Core store (no app-level deps) ---

  registry.registerFactory<AppWorkspaceStore>((_) => AppWorkspaceStore());

  // --- Stores that depend on AppWorkspaceStore ---

  registry.registerFactory<AppAiHistoryStore>(
    (r) => AppAiHistoryStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );

  registry.registerFactory<AppSceneContextStore>(
    (r) => AppSceneContextStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );

  registry.registerFactory<AppSimulationStore>(
    (r) => AppSimulationStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventLog: r.resolve<AppEventLog>(),
    ),
  );

  registry.registerFactory<AppDraftStore>(
    (r) => AppDraftStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );

  registry.registerFactory<AppVersionStore>(
    (r) => AppVersionStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );

  registry.registerFactory<StoryOutlineStore>(
    (r) => StoryOutlineStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );

  registry.registerFactory<StoryGenerationStore>(
    (r) => StoryGenerationStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );

  // --- Settings (depends on infrastructure, not workspace) ---

  registry.registerFactory<AppSettingsStore>(
    (r) => AppSettingsStore(
      llmClient:
          AppSettingsStore.debugLlmClientOverride ?? createCachedAppLlmClient(),
      eventLog: r.resolve<AppEventLog>(),
    ),
  );

  registry.registerFactory<StoryGenerationRunStore>(
    (r) => StoryGenerationRunStore(
      settingsStore: r.resolve<AppSettingsStore>(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      generationStore: r.resolve<StoryGenerationStore>(),
      sceneContextStore: r.resolve<AppSceneContextStore>(),
      outlineStore: r.resolve<StoryOutlineStore>(),
      authorFeedbackStore: r.resolve<AuthorFeedbackStore>(),
    ),
  );

  registry.registerFactory<AuthorFeedbackStore>(
    (r) => AuthorFeedbackStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );

  registry.registerFactory<ReviewTaskStore>(
    (r) => ReviewTaskStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );
}
