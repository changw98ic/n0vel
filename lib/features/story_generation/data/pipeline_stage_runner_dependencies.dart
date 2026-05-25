import 'package:novel_writer/app/rag/hybrid_retriever.dart';

import '../domain/contracts/memory_writeback_gate.dart'
    hide CanonKeeper, SoulContractValidator;
import '../domain/contracts/stage_runner.dart';
import '../domain/story_pipeline_interfaces.dart';
import 'canon_keeper.dart';
import 'character_consistency_verifier.dart';
import 'character_memory_store.dart';
import 'scene_editorial_generator.dart';
import 'scene_polish_pass.dart';
import 'scene_stage_narrator.dart';
import 'scene_state_resolver.dart';
import 'soul_contract_validator.dart';
import 'story_context_cache.dart';
import 'story_memory_storage.dart';
import 'roleplay_session_store.dart';

/// Role-oriented dependency bundle for [PipelineStageRunnerImpl].
///
/// The runner owns stage orchestration. This object keeps collaborator
/// overrides grouped by the pipeline role they support, so tests and
/// registration code can override one responsibility without growing the
/// runner constructor surface.
class PipelineStageRunnerDependencies {
  const PipelineStageRunnerDependencies({
    this.runtime = const PipelineRuntimeDependencies(),
    this.context = const PipelineContextDependencies(),
    this.planning = const PipelinePlanningDependencies(),
    this.roleplay = const PipelineRoleplayDependencies(),
    this.drafting = const PipelineDraftingDependencies(),
    this.review = const PipelineReviewDependencies(),
    this.finalization = const PipelineFinalizationDependencies(),
  });

  final PipelineRuntimeDependencies runtime;
  final PipelineContextDependencies context;
  final PipelinePlanningDependencies planning;
  final PipelineRoleplayDependencies roleplay;
  final PipelineDraftingDependencies drafting;
  final PipelineReviewDependencies review;
  final PipelineFinalizationDependencies finalization;
}

class PipelineRuntimeDependencies {
  const PipelineRuntimeDependencies({this.eventLog});

  final PipelineEventLog? eventLog;
}

class PipelineContextDependencies {
  const PipelineContextDependencies({
    this.contextAssembler,
    this.memoryStorage,
    this.memoryRetriever,
    this.hybridRetriever,
    this.contextCache,
    this.chapterContextBridge,
  });

  final SceneContextAssemblerService? contextAssembler;
  final StoryMemoryStorage? memoryStorage;
  final StoryMemoryRetrievalService? memoryRetriever;
  final HybridRetriever? hybridRetriever;
  final StoryContextCache? contextCache;
  final ChapterContextBridgeService? chapterContextBridge;
}

class PipelinePlanningDependencies {
  const PipelinePlanningDependencies({
    this.castResolver,
    this.directorOrchestrator,
  });

  final SceneCastResolverService? castResolver;
  final SceneDirectorService? directorOrchestrator;
}

class PipelineRoleplayDependencies {
  const PipelineRoleplayDependencies({
    this.dynamicRoleAgentRunner,
    this.roleplaySessionStore,
    this.characterMemoryStore,
  });

  final DynamicRoleAgentService? dynamicRoleAgentRunner;
  final RoleplaySessionStore? roleplaySessionStore;
  final CharacterMemoryStore? characterMemoryStore;
}

class PipelineDraftingDependencies {
  const PipelineDraftingDependencies({
    this.stateResolver,
    this.stageNarrator,
    this.editorialGenerator,
  });

  final SceneStateResolver? stateResolver;
  final SceneStageNarrator? stageNarrator;
  final SceneEditorialGenerator? editorialGenerator;
}

class PipelineReviewDependencies {
  const PipelineReviewDependencies({
    this.reviewCoordinator,
    this.polishPass,
    this.consistencyVerifier,
    this.canonKeeper,
  });

  final SceneReviewService? reviewCoordinator;
  final ScenePolishPass? polishPass;
  final CharacterConsistencyVerifier? consistencyVerifier;
  final CanonKeeper? canonKeeper;
}

class PipelineFinalizationDependencies {
  const PipelineFinalizationDependencies({
    this.qualityScorer,
    this.thoughtUpdater,
    this.soulValidator,
    this.writebackGate,
  });

  final SceneQualityScorerService? qualityScorer;
  final ThoughtMemoryService? thoughtUpdater;
  final SoulContractValidator? soulValidator;
  final MemoryWritebackGate? writebackGate;
}
