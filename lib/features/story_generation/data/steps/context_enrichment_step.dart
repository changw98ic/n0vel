import 'package:novel_writer/app/rag/rag_orchestrator.dart';

import '../story_context_cache.dart';
import '../story_memory_storage.dart';
import '../../domain/scene_models.dart';
import '../../domain/memory_models.dart';
import '../../domain/story_pipeline_interfaces.dart'
    show
        ChapterContextBridgeService,
        SceneContextAssemblerService,
        StoryMemoryRetrieverService;
import '../step_io.dart';

/// Step 1: Enriches scene materials with cross-chapter context, indexes
/// materials, runs memory retrieval and RAG in parallel, and caches the
/// assembled context.
///
/// Extracted from [ChapterGenerationOrchestrator] lines 182-268.
class ContextEnrichmentStep {
  ContextEnrichmentStep({
    ChapterContextBridgeService? chapterContextBridge,
    required SceneContextAssemblerService contextAssembler,
    StoryMemoryStorage? memoryStorage,
    StoryMemoryRetrieverService? memoryRetriever,
    RagOrchestrator? ragOrchestrator,
    StoryContextCache? contextCache,
  })  : _chapterContextBridge = chapterContextBridge,
        _contextAssembler = contextAssembler,
        _memoryStorage = memoryStorage,
        _memoryRetriever = memoryRetriever,
        _ragOrchestrator = ragOrchestrator,
        _contextCache = contextCache;

  final ChapterContextBridgeService? _chapterContextBridge;
  final SceneContextAssemblerService _contextAssembler;
  final StoryMemoryStorage? _memoryStorage;
  final StoryMemoryRetrieverService? _memoryRetriever;
  final RagOrchestrator? _ragOrchestrator;
  final StoryContextCache? _contextCache;

  /// Executes context enrichment for a scene.
  ///
  /// - Builds cross-chapter context via [ChapterContextBridgeService].
  /// - Assembles and caches [SceneContextAssembly].
  /// - Persists indexed chunks to [StoryMemoryStorage].
  /// - Runs memory retrieval and RAG in parallel.
  Future<ContextEnrichmentOutput> execute(ContextEnrichmentInput input) async {
    final brief = input.brief;

    // Cross-chapter context: enrich materials with previous chapter data
    ProjectMaterialSnapshot effectiveMaterials =
        input.materials ?? const ProjectMaterialSnapshot();
    if (_chapterContextBridge != null && brief.projectId != null) {
      final crossChapter = await _chapterContextBridge.buildCrossChapterContext(
        projectId: brief.projectId!,
        currentChapterId: brief.chapterId,
      );
      if (!crossChapter.isEmpty) {
        effectiveMaterials = _chapterContextBridge.enrichMaterialSnapshot(
          effectiveMaterials,
          crossChapter,
        );
      }
    }

    // Pre-scene: index materials and run retrieval
    StoryRetrievalPack? retrievalPack;
    RagSceneContext? ragContext;
    SceneContextAssembly? cachedAssembly;
    if (!effectiveMaterials.isEmpty &&
        _memoryStorage != null &&
        _memoryRetriever != null) {
      final scopeId = '${brief.chapterId}:${brief.sceneId}';
      cachedAssembly = _contextCache?.lookup(
        brief.chapterId,
        scopeId,
        effectiveMaterials,
      );
      final assembly =
          cachedAssembly ??
          _contextAssembler.assemble(
            brief: brief,
            materials: effectiveMaterials,
          );

      if (cachedAssembly == null && _contextCache != null) {
        _contextCache.store(
          brief.chapterId,
          scopeId,
          assembly,
          effectiveMaterials,
        );
      }

      // Persist indexed chunks
      if (assembly.memoryChunks.isNotEmpty) {
        await _memoryStorage.saveChunks(
          brief.projectId ?? brief.chapterId,
          assembly.memoryChunks,
        );
      }

      // Run retrieval for scene context
      final query = StoryMemoryQuery(
        projectId: brief.projectId ?? brief.chapterId,
        queryType: StoryMemoryQueryType.sceneContinuity,
        text: '${brief.sceneTitle} ${brief.sceneSummary}',
        tags: [
          ...brief.worldNodeIds,
          for (final c in brief.cast) 'char-${c.characterId}',
        ],
        maxResults: 10,
        tokenBudget: 500,
        scopeId: '${brief.projectId ?? brief.chapterId}:${brief.sceneId}',
      );

      // Memory retrieval and RAG retrieval are independent — run in parallel
      if (_ragOrchestrator != null) {
        final results = await (
          _memoryRetriever.retrieve(query),
          _retrieveRagSafe(brief),
        ).wait;
        retrievalPack = results.$1;
        ragContext = results.$2;
      } else {
        retrievalPack = await _memoryRetriever.retrieve(query);
      }
    } else if (_ragOrchestrator != null) {
      ragContext = await _retrieveRagSafe(brief);
    }

    return ContextEnrichmentOutput(
      effectiveMaterials: effectiveMaterials,
      retrievalPack: retrievalPack,
      ragContext: ragContext,
      cachedAssembly: cachedAssembly,
    );
  }

  /// Retrieves RAG context, catching any failure so generation is not blocked.
  Future<RagSceneContext?> _retrieveRagSafe(SceneBrief brief) async {
    try {
      return await _ragOrchestrator!.retrieveForScene(
        projectId: brief.chapterId,
        sceneTitle: brief.sceneTitle,
        sceneSummary: brief.sceneSummary,
        castNames: [for (final c in brief.cast) c.name],
        worldNodeIds: brief.worldNodeIds,
      );
    } on Object {
      return null;
    }
  }
}
