import 'package:novel_writer/app/rag/hybrid_retriever.dart';

import '../story_context_cache.dart';
import '../story_memory_indexer.dart';
import '../story_memory_storage.dart';
import '../story_memory_storage_io.dart';
import '../../domain/scene_models.dart';
import '../../domain/memory_models.dart';
import '../../domain/story_pipeline_interfaces.dart'
    show
        ChapterContextBridgeService,
        SceneContextAssemblerService,
        StoryMemoryRetrievalService;
import '../step_io.dart';
import '../../domain/contracts/pipeline_role_contract.dart';
import '../../domain/contracts/typed_artifact.dart';

/// Step 1: Enriches scene materials with cross-chapter context, indexes
/// materials, runs memory retrieval and RAG in parallel, and caches the
/// assembled context.
///
/// Uses [HybridRetriever] when available for fused FTS + vector retrieval.
class ContextEnrichmentStep
    implements PipelineStage<ContextEnrichmentInput, ContextEnrichmentOutput> {
  ContextEnrichmentStep({
    ChapterContextBridgeService? chapterContextBridge,
    required SceneContextAssemblerService contextAssembler,
    StoryMemoryStorage? memoryStorage,
    StoryMemoryRetrievalService? memoryRetriever,
    HybridRetriever? hybridRetriever,
    StoryContextCache? contextCache,
  }) : _chapterContextBridge = chapterContextBridge,
       _contextAssembler = contextAssembler,
       _memoryStorage = memoryStorage,
       _memoryRetriever = memoryRetriever,
       _hybridRetriever = hybridRetriever,
       _contextCache = contextCache;

  final ChapterContextBridgeService? _chapterContextBridge;
  final SceneContextAssemblerService _contextAssembler;
  final StoryMemoryStorage? _memoryStorage;
  final StoryMemoryRetrievalService? _memoryRetriever;
  final HybridRetriever? _hybridRetriever;
  final StoryContextCache? _contextCache;

  @override
  String get roleId => 'context_enrichment';
  @override
  ArtifactType get outputType => ArtifactType.contextAssembly;
  @override
  int get maxRetries => 2;

  /// Executes context enrichment for a scene.
  ///
  /// - Builds cross-chapter context via [ChapterContextBridgeService].
  /// - Assembles and caches [SceneContextAssembly].
  /// - Persists indexed chunks to [StoryMemoryStorage].
  /// - Indexes chunks into [HybridRetriever] when available.
  /// - Runs memory retrieval and derives [RagSceneContext] from the result.
  @override
  Future<ContextEnrichmentOutput> execute(
    ContextEnrichmentInput input,
    Object context,
  ) async {
    final brief = input.brief;
    final projectScopeId = brief.projectId ?? brief.chapterId;

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
    SceneContextAssembly? assembledContext;
    if (_memoryStorage != null && _memoryRetriever != null) {
      final scopeId = '$projectScopeId:${brief.sceneId}';
      cachedAssembly = _contextCache?.lookup(
        projectScopeId,
        scopeId,
        effectiveMaterials,
      );
      final assembly =
          cachedAssembly ??
          _contextAssembler.assemble(
            brief: brief,
            materials: effectiveMaterials,
          );
      assembledContext = assembly;

      if (cachedAssembly == null && _contextCache != null) {
        _contextCache.store(
          projectScopeId,
          scopeId,
          assembly,
          effectiveMaterials,
        );
      }

      // Replace this producer's complete generation, including an empty one.
      // Cache hits still execute the replace so persistent stores cannot drift.
      await _replaceOwnedGeneration(
        projectId: projectScopeId,
        scopeId: scopeId,
        chunks: assembly.memoryChunks,
      );

      // Run retrieval for scene context
      final query = StoryMemoryQuery(
        projectId: projectScopeId,
        queryType: StoryMemoryQueryType.sceneContinuity,
        text: '${brief.sceneTitle} ${brief.sceneSummary}',
        tags: [
          ...brief.worldNodeIds,
          for (final c in brief.cast) 'char-${c.characterId}',
        ],
        maxResults: 10,
        tokenBudget: 500,
        scopeId: scopeId,
      );

      // Retrieve one StoryRetrievalPack through the available retriever
      final retriever = _hybridRetriever ?? _memoryRetriever;
      retrievalPack = await retriever.retrieve(query);

      // Derive RagSceneContext from the retrieval pack
      ragContext = RagSceneContext.fromPack(retrievalPack);
    }

    return ContextEnrichmentOutput(
      effectiveMaterials: effectiveMaterials,
      retrievalPack: retrievalPack,
      ragContext: ragContext,
      cachedAssembly: assembledContext,
    );
  }

  Future<void> _replaceOwnedGeneration({
    required String projectId,
    required String scopeId,
    required List<StoryMemoryChunk> chunks,
  }) async {
    const producer = StoryMemoryIndexer.contextEnrichmentProducer;
    final storage = _memoryStorage;
    if (storage is! OwnedGenerationMemoryStorage) {
      throw StateError(
        'Context enrichment requires owned-generation memory storage',
      );
    }
    final ownedStorage = storage as OwnedGenerationMemoryStorage;

    final hybrid = _hybridRetriever;
    if (hybrid == null) {
      await ownedStorage.replaceOwnedGeneration(
        projectId: projectId,
        scopeId: scopeId,
        producer: producer,
        chunks: chunks,
        includeLegacyContextRows: true,
      );
      return;
    }

    if (storage is! StoryMemoryStorageIO || !hybrid.usesDatabase(storage.db)) {
      throw StateError(
        'Atomic context generation replacement requires memory, FTS, and '
        'vector storage to share one SQLite database',
      );
    }

    final storyWrite = await storage.prepareOwnedGeneration(
      projectId: projectId,
      scopeId: scopeId,
      producer: producer,
      chunks: chunks,
      includeLegacyContextRows: true,
    );
    final hybridWrite = await hybrid.prepareOwnedGeneration(
      projectId: projectId,
      scopeId: scopeId,
      producer: producer,
      chunks: chunks,
      includeLegacyContextRows: true,
    );
    final db = storage.db;
    await storage.writeCoordinator.synchronized<void>((lease) async {
      db.execute('SAVEPOINT context_enrichment_replace_generation');
      try {
        await storage.commitOwnedGeneration(storyWrite, lease: lease);
        await hybrid.commitOwnedGeneration(hybridWrite, lease: lease);
        db.execute('RELEASE SAVEPOINT context_enrichment_replace_generation');
      } catch (_) {
        db.execute(
          'ROLLBACK TO SAVEPOINT context_enrichment_replace_generation',
        );
        db.execute('RELEASE SAVEPOINT context_enrichment_replace_generation');
        rethrow;
      }
    });
  }
}
