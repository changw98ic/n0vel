import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

import 'chapter_context_bridge.dart';
import 'chapter_summarizer.dart';
import 'canon_keeper.dart';
import 'pipeline_stage_runner_dependencies.dart';
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

import '../domain/contracts/memory_writeback_gate.dart'
    hide CanonKeeper, SoulContractValidator;
import '../domain/contracts/soul_contract.dart';
import '../domain/story_pipeline_interfaces.dart';

/// Registers all story generation pipeline services into [registry].
///
/// Pre-conditions:
/// - [AppSettingsStore] must already be registered.
/// - [StoryMemoryStorage] must already be registered (IO or stub).
///
/// Optional pre-registrations:
/// - [HybridRetriever] for fused FTS + vector retrieval.
///
/// When no [HybridRetriever] is pre-registered, one is created from the
/// same SQLite database used by [StoryMemoryStorage], if available.
void registerStoryGenerationServices(ServiceRegistry registry) {
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
    (r) => SceneDirectorOrchestrator(settingsStore: r.resolve()),
  );

  registry.registerFactory<DynamicRoleAgentService>(
    (r) => DynamicRoleAgentRunner(
      settingsStore: r.resolve(),
      characterMemoryStore: registry.isRegistered<CharacterMemoryStore>()
          ? r.resolve()
          : null,
    ),
  );

  registry.registerFactory<SceneProseService>(
    (r) => SceneProseGenerator(settingsStore: r.resolve()),
  );

  registry.registerFactory<SceneReviewService>(
    (r) => SceneReviewCoordinator(
      settingsStore: r.resolve(),
      formatterTraceSink:
          registry.isRegistered<StoryGenerationFormatterTraceSink>()
          ? r.resolve()
          : null,
      canonKeeper: r.resolve(),
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
        (_) => HybridRetriever.local(db: db),
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
      storage: r.resolve(),
      gate: r.resolve(),
    ),
  );

  registry.registerFactory<StoryContextCache>((_) => StoryContextCache());

  registry.registerFactory<ChapterContextBridgeService>(
    (r) => ChapterContextBridge(
      storage: r.resolve(),
      summarizer: ChapterSummarizer(settingsStore: r.resolve()),
    ),
  );

  registry.registerFactory<SceneQualityScorerService>(
    (r) => SceneQualityScorer(settingsStore: r.resolve()),
  );

  registry.registerFactory<ChapterGenerationService>((r) {
    final pipelineConfig = registry.isRegistered<AppWorkspaceStore>()
        ? GenerationPipelineConfig.fromWorkspace(r.resolve<AppWorkspaceStore>())
        : const GenerationPipelineConfig();
    return PipelineStageRunnerImpl(
      settingsStore: r.resolve(),
      pipelineConfig: pipelineConfig,
      dependencies: PipelineStageRunnerDependencies(
        context: PipelineContextDependencies(
          contextAssembler: r.resolve(),
          memoryStorage: r.resolve(),
          memoryRetriever: registry.isRegistered<StoryMemoryRetrievalService>()
              ? r.resolve()
              : null,
          hybridRetriever: registry.isRegistered<HybridRetriever>()
              ? r.resolve()
              : null,
          contextCache: r.resolve(),
          chapterContextBridge: r.resolve(),
        ),
        planning: PipelinePlanningDependencies(
          castResolver: r.resolve(),
          directorOrchestrator: r.resolve(),
        ),
        roleplay: PipelineRoleplayDependencies(
          dynamicRoleAgentRunner: r.resolve(),
          roleplaySessionStore: registry.isRegistered<RoleplaySessionStore>()
              ? r.resolve()
              : null,
          characterMemoryStore: registry.isRegistered<CharacterMemoryStore>()
              ? r.resolve()
              : null,
        ),
        review: PipelineReviewDependencies(
          reviewCoordinator: r.resolve(),
          consistencyVerifier: CharacterConsistencyVerifier(
            settingsStore: r.resolve(),
            soulValidator: r.resolve(),
          ),
          canonKeeper: r.resolve(),
        ),
        finalization: PipelineFinalizationDependencies(
          qualityScorer: r.resolve(),
          thoughtUpdater: r.resolve(),
          soulValidator: r.resolve(),
          writebackGate: r.resolve(),
        ),
      ),
    );
  });
}
