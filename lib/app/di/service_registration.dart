import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import '../state/app_authoring_storage_io_support.dart';
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
import '../../features/story_generation/data/character_memory_store.dart';
import '../../features/story_generation/data/character_memory_store_io.dart';
import '../../features/story_generation/data/roleplay_session_store.dart';
import '../../features/story_generation/data/roleplay_session_store_io.dart';

/// Register all application-level services into [registry].
///
/// Call this once at app startup, then use [registry.resolve] to obtain
/// instances. Dependencies are resolved lazily — factories run only on
/// first access.
void registerAppServices(ServiceRegistry registry) {
  // --- Infrastructure (no app-level deps) ---

  registry.registerFactory<AppEventLog>((_) => AppEventLog());
  registry.registerFactory<AppLlmClient>(
    (_) => AppSettingsStore.createSettingsLlmClient(),
  );
  registry.registerFactory<AppLlmRequestPool>(
    (_) => AppLlmRequestPool(maxConcurrent: 3),
  );
  registry.registerFactory<sqlite3.Database>(
    (_) => openAuthoringDatabase(resolveAuthoringDbPath()),
  );
  registry.registerFactory<RoleplaySessionStore>(
    (r) => RoleplaySessionStoreIO(db: r.resolve<sqlite3.Database>()),
  );
  registry.registerFactory<CharacterMemoryStore>(
    (r) => CharacterMemoryStoreIO(db: r.resolve<sqlite3.Database>()),
  );

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
      llmClient: r.resolve<AppLlmClient>(),
      requestPool: r.resolve<AppLlmRequestPool>(),
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
      roleplaySessionStore: r.resolve<RoleplaySessionStore>(),
      characterMemoryStore: r.resolve<CharacterMemoryStore>(),
    ),
  );

  registry.registerFactory<AuthorFeedbackStore>(
    (r) => AuthorFeedbackStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );

  registry.registerFactory<ReviewTaskStore>(
    (r) => ReviewTaskStore(workspaceStore: r.resolve<AppWorkspaceStore>()),
  );
}
