import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/rag/rag_orchestrator.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'chapter_context_bridge.dart';
import 'chapter_generation_orchestrator.dart';
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
import 'story_embedding_provider.dart';
import 'story_memory_retriever.dart';
import 'story_memory_storage.dart';
import 'thought_memory_updater.dart';

import '../domain/story_pipeline_interfaces.dart';

/// Registers all story generation pipeline services into [registry].
///
/// Pre-conditions:
/// - [AppSettingsStore] must already be registered.
/// - [StoryMemoryStorage] must already be registered (IO or stub).
///
/// Optional pre-registrations:
/// - [StoryEmbeddingProvider] for semantic retrieval.
/// - [RagOrchestrator] for broad RAG context.
void registerStoryGenerationServices(ServiceRegistry registry) {
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
    ),
  );

  registry.registerFactory<SceneContextAssemblerService>(
    (_) => SceneContextAssembler(),
  );

  registry.registerFactory<StoryMemoryRetrieverService>(
    (r) => StoryMemoryRetriever(
      storage: r.resolve(),
      embeddingProvider: registry.isRegistered<StoryEmbeddingProvider>()
          ? r.resolve()
          : null,
    ),
  );

  registry.registerFactory<ThoughtMemoryService>(
    (r) => ThoughtMemoryUpdater(storage: r.resolve()),
  );

  registry.registerFactory<StoryContextCache>((_) => StoryContextCache());

  registry.registerFactory<ChapterContextBridgeService>(
    (r) => ChapterContextBridge(storage: r.resolve()),
  );

  registry.registerFactory<SceneQualityScorerService>(
    (r) => SceneQualityScorer(settingsStore: r.resolve()),
  );

  registry.registerFactory<ChapterGenerationService>(
    (r) => ChapterGenerationOrchestrator(
      settingsStore: r.resolve(),
      castResolver: r.resolve(),
      directorOrchestrator: r.resolve(),
      dynamicRoleAgentRunner: r.resolve(),
      reviewCoordinator: r.resolve(),
      qualityScorer: r.resolve(),
      contextAssembler: r.resolve(),
      memoryStorage: r.resolve(),
      memoryRetriever: r.resolve(),
      thoughtUpdater: r.resolve(),
      roleplaySessionStore: registry.isRegistered<RoleplaySessionStore>()
          ? r.resolve()
          : null,
      characterMemoryStore: registry.isRegistered<CharacterMemoryStore>()
          ? r.resolve()
          : null,
      ragOrchestrator: registry.isRegistered<RagOrchestrator>()
          ? r.resolve()
          : null,
      contextCache: r.resolve(),
      chapterContextBridge: r.resolve(),
    ),
  );
}
