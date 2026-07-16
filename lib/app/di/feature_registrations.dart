import '../events/app_event_bus.dart';
import '../state/app_scene_context_store.dart';
import '../state/app_settings_store.dart';
import '../state/app_workspace_store.dart';
import '../state/story_generation_store.dart';
import '../state/story_outline_store.dart';
import '../../features/author_feedback/data/author_feedback_store.dart';
import '../../features/review_tasks/data/review_task_store.dart';
import '../../features/story_generation/data/character_memory_store.dart';
import '../../features/story_generation/data/roleplay_session_store.dart';
import '../../features/story_generation/data/story_pipeline_factory.dart';
import '../../features/story_generation/data/generation_commit_coordinator.dart';
import '../../features/story_generation/data/generation_ledger.dart';
import '../../features/story_generation/data/generation_ledger_candidate_finalizer.dart';
import '../../features/story_generation/data/generation_outbox_worker.dart';
import '../../features/story_generation/data/story_prompt_registry.dart';
import '../state/app_draft_store.dart';
import '../state/story_generation_run_store.dart';
import 'service_registry.dart';

void registerFeatureServices(ServiceRegistry registry) {
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
      reviewTaskStore: r.resolve<ReviewTaskStore>(),
      draftStore: r.resolve<AppDraftStore>(),
      generationLedger: r.resolve<GenerationLedgerSqliteStore>(),
      generationCandidateFinalizer: GenerationLedgerCandidateFinalizer(
        ledger: r.resolve<GenerationLedgerSqliteStore>(),
        promptRegistry: r.resolve<StoryPromptRegistry>(),
      ),
      generationCommitCoordinator: r.resolve<GenerationCommitCoordinator>(),
      generationOutboxWorker: r.resolve<GenerationOutboxWorker>(),
      eventBus: r.resolve<AppEventBus>(),
      lifecycleRunIdFactory:
          r.isRegistered<StoryGenerationLifecycleRunIdFactory>()
          ? r.resolve<StoryGenerationLifecycleRunIdFactory>()
          : null,
      orchestratorFactory: (_) => r.resolve<StoryPipelineFactory>().create(),
    ),
  );

  registry.registerFactory<AuthorFeedbackStore>(
    (r) => AuthorFeedbackStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  registry.registerFactory<ReviewTaskStore>(
    (r) => ReviewTaskStore(
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
}
