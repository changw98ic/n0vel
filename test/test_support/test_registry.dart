import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';

import 'fake_app_llm_client.dart';

/// Creates a [ServiceRegistry] with in-memory storages and a fake LLM client.
///
/// Use in widget tests that pump [NovelWriterApp]:
/// ```dart
/// setUp(() {
///   NovelWriterApp.debugRegistryOverride = createTestRegistry();
/// });
/// tearDown(() {
///   NovelWriterApp.debugRegistryOverride = null;
/// });
/// ```
ServiceRegistry createTestRegistry({AppLlmClient? llmClient}) {
  final registry = ServiceRegistry();

  // Infrastructure
  registry.registerFactory<AppEventBus>((_) => AppEventBus());
  registry.registerFactory<AppEventLog>((_) => AppEventLog());
  registry.registerFactory<AppLlmClient>(
    (_) => llmClient ?? FakeAppLlmClient(),
  );
  registry.registerFactory<AppLlmRequestPool>(
    (_) => AppLlmRequestPool(maxConcurrent: 3),
  );

  // Core stores with in-memory storages
  registry.registerFactory<AppWorkspaceStore>(
    (r) => AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppAiHistoryStore>(
    (r) => AppAiHistoryStore(
      storage: InMemoryAppAiHistoryStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppSceneContextStore>(
    (r) => AppSceneContextStore(
      storage: InMemoryAppSceneContextStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppSimulationStore>(
    (r) => AppSimulationStore(
      storage: InMemoryAppSimulationStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppDraftStore>(
    (r) => AppDraftStore(
      storage: InMemoryAppDraftStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppVersionStore>(
    (r) => AppVersionStore(
      storage: InMemoryAppVersionStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<StoryOutlineStore>(
    (r) => StoryOutlineStore(
      storage: InMemoryStoryOutlineStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<StoryGenerationStore>(
    (r) => StoryGenerationStore(
      storage: InMemoryStoryGenerationStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppSettingsStore>(
    (r) => AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: r.resolve<AppLlmClient>(),
      requestPool: r.resolve<AppLlmRequestPool>(),
      eventLog: r.resolve<AppEventLog>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  // Feature stores with in-memory storages
  registry.registerFactory<AuthorFeedbackStore>(
    (r) => AuthorFeedbackStore(
      storage: InMemoryAuthorFeedbackStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<ReviewTaskStore>(
    (r) => ReviewTaskStore(
      storage: InMemoryReviewTaskStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
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
      eventBus: r.resolve<AppEventBus>(),
      storage: InMemoryStoryGenerationRunStorage(),
    ),
  );

  return registry;
}
