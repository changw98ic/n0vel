import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'chapter_context_bridge.dart';
import 'chapter_summarizer.dart';
import 'canon_keeper.dart';
import 'pipeline_stage_runner_impl.dart';
import 'character_consistency_verifier.dart';
import 'dynamic_role_agent_runner.dart';
import 'scene_cast_resolver.dart';
import 'scene_context_assembler.dart';
import 'scene_director_orchestrator.dart';
import 'scene_prose_generator.dart';
import 'scene_quality_scorer.dart';
import 'scene_review_coordinator.dart';
import 'story_generation_formatter_trace.dart';
import 'roleplay_session_store.dart';
import 'character_memory_store.dart';
import 'story_context_cache.dart';
import 'story_memory_storage.dart';
import 'story_memory_storage_io.dart';
import 'generation_pipeline_config.dart';
import 'soul_contract_validator.dart';
import 'thought_memory_updater.dart';
import 'story_pipeline_factory.dart';
import 'story_prompt_registry.dart';

import '../domain/contracts/memory_writeback_gate.dart'
    hide CanonKeeper, SoulContractValidator;
import '../domain/contracts/stage_runner.dart';
import '../domain/contracts/soul_contract.dart';
import '../domain/contracts/settings_contract.dart';
import '../domain/story_pipeline_interfaces.dart';

/// Registers all story generation pipeline services into [registry].
///
/// Pre-conditions:
/// - [AppSettingsStore] must already be registered.
/// - [StoryMemoryStorage] must already be registered (IO or stub).
///
/// Optional pre-registrations:
/// - [HybridRetriever] for fused FTS + vector retrieval.
/// - [PipelineEventLog] for shared durable no-redraw evidence persistence.
///
/// When no [HybridRetriever] is pre-registered, one is created from the
/// same SQLite database used by [StoryMemoryStorage], if available.
void registerStoryGenerationServices(ServiceRegistry registry) {
  if (!registry.isRegistered<StoryPromptRegistry>()) {
    registry.registerFactory<StoryPromptRegistry>(
      (_) => StoryPromptRegistry.production,
    );
  }
  if (!registry.isRegistered<StoryGenerationSettingsContract>()) {
    registry.registerFactory<StoryGenerationSettingsContract>(
      (r) => r.resolve<AppSettingsStore>(),
    );
  }

  if (!registry.isRegistered<CanonKeeper>()) {
    registry.registerFactory<CanonKeeper>((_) => const CanonKeeper());
  }

  if (!registry.isRegistered<SoulContractValidator>()) {
    registry.registerFactory<SoulContractValidator>(
      (_) => const SoulContractValidator(SoulContract()),
    );
  }

  if (!registry.isRegistered<MemoryWritebackGate>()) {
    registry.registerFactory<MemoryWritebackGate>(
      (r) => BasicMemoryWritebackGate(
        soulValidator: r
            .resolve<SoulContractValidator>()
            .asWritebackValidator(),
        canonKeeper: r.resolve<CanonKeeper>().asWritebackCanonKeeper(const []),
      ),
    );
  }

  registry.registerFactory<SceneCastResolverService>(
    (_) => SceneCastResolver(),
  );

  registry.registerFactory<SceneDirectorService>(
    (r) => SceneDirectorOrchestrator(
      settingsStore: r.resolve<StoryGenerationSettingsContract>(),
    ),
  );

  registry.registerFactory<DynamicRoleAgentService>(
    (r) => DynamicRoleAgentRunner(
      settingsStore: r.resolve<StoryGenerationSettingsContract>(),
      characterMemoryStore: registry.isRegistered<CharacterMemoryStore>()
          ? r.resolve<CharacterMemoryStore>()
          : null,
    ),
  );

  registry.registerFactory<SceneProseService>(
    (r) => SceneProseGenerator(
      settingsStore: r.resolve<StoryGenerationSettingsContract>(),
    ),
  );

  registry.registerFactory<SceneReviewService>(
    (r) => SceneReviewCoordinator(
      settingsStore: r.resolve<StoryGenerationSettingsContract>(),
      formatterTraceSink:
          registry.isRegistered<StoryGenerationFormatterTraceSink>()
          ? r.resolve<StoryGenerationFormatterTraceSink>()
          : null,
      canonKeeper: r.resolve<CanonKeeper>(),
    ),
  );

  registry.registerFactory<SceneContextAssemblerService>(
    (_) => SceneContextAssembler(),
  );

  // Register HybridRetriever when not already pre-registered.
  if (!registry.isRegistered<HybridRetriever>()) {
    final storage = registry.resolve<StoryMemoryStorage>();
    final db = storage is StoryMemoryStorageIO ? storage.db : null;
    if (db != null) {
      registry.registerFactory<HybridRetriever>(
        (_) => HybridRetriever.local(
          db: db,
          writeCoordinator: storage is StoryMemoryStorageIO
              ? storage.writeCoordinator
              : null,
        ),
      );
    }
  }

  // StoryMemoryRetrievalService resolves to HybridRetriever when available.
  if (registry.isRegistered<HybridRetriever>()) {
    registry.registerFactory<StoryMemoryRetrievalService>(
      (r) => r.resolve<HybridRetriever>(),
    );
  }

  registry.registerFactory<ThoughtMemoryService>(
    (r) => ThoughtMemoryUpdater /* MemoryWritebackGate */ (
      storage: r.resolve<StoryMemoryStorage>(),
      gate: r.resolve<MemoryWritebackGate>(),
    ),
  );

  registry.registerFactory<StoryContextCache>((_) => StoryContextCache());

  registry.registerFactory<ChapterContextBridgeService>(
    (r) => ChapterContextBridge(
      storage: r.resolve<StoryMemoryStorage>(),
      summarizer: ChapterSummarizer(
        settingsStore: r.resolve<StoryGenerationSettingsContract>(),
      ),
      authorityDb: r.resolve<sqlite3.Database>(),
    ),
  );

  registry.registerFactory<SceneQualityScorerService>(
    (r) => SceneQualityScorer(
      settingsStore: r.resolve<StoryGenerationSettingsContract>(),
    ),
  );

  registry.registerFactory<StoryPipelineFactory>(
    (r) => StoryPipelineFactory(() => _createPipelineRunner(r)),
  );

  // Compatibility alias for callers that resolve the interface directly.
  // Stateful app runs use StoryPipelineFactory instead, so each run is fresh.
  registry.registerFactory<ChapterGenerationService>(
    (r) => r.resolve<StoryPipelineFactory>().create(),
  );
}

PipelineStageRunnerImpl _createPipelineRunner(ServiceRegistry registry) {
  final pipelineConfig = registry.isRegistered<GenerationPipelineConfig>()
      ? registry.resolve<GenerationPipelineConfig>()
      : registry.isRegistered<AppWorkspaceStore>()
      ? GenerationPipelineConfig.fromWorkspace(
          registry.resolve<AppWorkspaceStore>(),
        )
      : const GenerationPipelineConfig();
  if (!pipelineConfig.contentRedrawAllowed) {
    return PipelineStageRunnerImpl.sealedProduction(
      settingsStore: registry.resolve<StoryGenerationSettingsContract>(),
      pipelineConfig: pipelineConfig,
      eventLog: registry.isRegistered<PipelineEventLog>()
          ? registry.resolve<PipelineEventLog>()
          : null,
      memoryStorage: registry.resolve<StoryMemoryStorage>(),
      roleplaySessionStore: registry.isRegistered<RoleplaySessionStore>()
          ? registry.resolve<RoleplaySessionStore>()
          : null,
      characterMemoryStore: registry.isRegistered<CharacterMemoryStore>()
          ? registry.resolve<CharacterMemoryStore>()
          : null,
      hybridRetriever: registry.isRegistered<HybridRetriever>()
          ? registry.resolve<HybridRetriever>()
          : null,
      contextCache: registry.resolve<StoryContextCache>(),
    );
  }
  return PipelineStageRunnerImpl(
    settingsStore: registry.resolve<StoryGenerationSettingsContract>(),
    pipelineConfig: pipelineConfig,
    eventLog: registry.isRegistered<PipelineEventLog>()
        ? registry.resolve<PipelineEventLog>()
        : null,
    castResolver: registry.resolve<SceneCastResolverService>(),
    directorOrchestrator: registry.resolve<SceneDirectorService>(),
    dynamicRoleAgentRunner: registry.resolve<DynamicRoleAgentService>(),
    reviewCoordinator: registry.resolve<SceneReviewService>(),
    qualityScorer: registry.resolve<SceneQualityScorerService>(),
    contextAssembler: registry.resolve<SceneContextAssemblerService>(),
    memoryStorage: registry.resolve<StoryMemoryStorage>(),
    memoryRetriever: registry.isRegistered<StoryMemoryRetrievalService>()
        ? registry.resolve<StoryMemoryRetrievalService>()
        : null,
    thoughtUpdater: registry.resolve<ThoughtMemoryService>(),
    roleplaySessionStore: registry.isRegistered<RoleplaySessionStore>()
        ? registry.resolve<RoleplaySessionStore>()
        : null,
    characterMemoryStore: registry.isRegistered<CharacterMemoryStore>()
        ? registry.resolve<CharacterMemoryStore>()
        : null,
    hybridRetriever: registry.isRegistered<HybridRetriever>()
        ? registry.resolve<HybridRetriever>()
        : null,
    contextCache: registry.resolve<StoryContextCache>(),
    chapterContextBridge: registry.resolve<ChapterContextBridgeService>(),
    consistencyVerifier: CharacterConsistencyVerifier(
      settingsStore: registry.resolve<StoryGenerationSettingsContract>(),
      soulValidator: registry.resolve<SoulContractValidator>(),
    ),
    canonKeeper: registry.resolve<CanonKeeper>(),
    soulValidator: registry.resolve<SoulContractValidator>(),
    writebackGate: registry.resolve<MemoryWritebackGate>(),
    promptRegistry: registry.resolve<StoryPromptRegistry>(),
  );
}
