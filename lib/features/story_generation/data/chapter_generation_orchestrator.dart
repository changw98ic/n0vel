import 'package:novel_writer/app/rag/rag_orchestrator.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'dynamic_role_agent_runner.dart';
import 'retrieval_controller.dart';
import 'scene_cast_resolver.dart';
import 'scene_context_assembler.dart';
import 'scene_director_orchestrator.dart';
import 'scene_editorial_generator.dart';
import 'director_memory.dart';
import 'narrative_arc_models.dart';
import 'narrative_arc_tracker.dart';
import 'scene_pipeline_models.dart' as pipeline;
import 'scene_review_coordinator.dart';
import 'scene_polish_pass.dart';
import 'scene_runtime_models.dart'
    show ResolvedBeat, SceneState, SceneStateDelta, SceneStateDeltaKind;
import 'scene_state_resolver.dart';
import 'story_context_cache.dart';
import '../domain/scene_models.dart';
import '../domain/memory_models.dart';
import 'story_memory_storage.dart';
import '../domain/story_pipeline_interfaces.dart';

class ChapterGenerationOrchestrator implements ChapterGenerationService {
  ChapterGenerationOrchestrator({
    required AppSettingsStore settingsStore,
    this.maxProseRetries = 1,
    this.onStatus,
    SceneCastResolverService? castResolver,
    SceneDirectorService? directorOrchestrator,
    DynamicRoleAgentService? dynamicRoleAgentRunner,
    SceneStateResolver? stateResolver,
    SceneEditorialGenerator? editorialGenerator,
    SceneReviewService? reviewCoordinator,
    ScenePolishPass? polishPass,
    SceneQualityScorerService? qualityScorer,
    SceneContextAssemblerService? contextAssembler,
    StoryMemoryStorage? memoryStorage,
    StoryMemoryRetrieverService? memoryRetriever,
    ThoughtMemoryService? thoughtUpdater,
    RagOrchestrator? ragOrchestrator,
    StoryContextCache? contextCache,
    ChapterContextBridgeService? chapterContextBridge,
  }) : _castResolver = castResolver ?? SceneCastResolver(),
       _directorOrchestrator =
           directorOrchestrator ??
           SceneDirectorOrchestrator(settingsStore: settingsStore),
       _dynamicRoleAgentRunner =
           dynamicRoleAgentRunner ??
           DynamicRoleAgentRunner(settingsStore: settingsStore),
       _stateResolver =
           stateResolver ?? SceneStateResolver(settingsStore: settingsStore),
       _editorialGenerator =
           editorialGenerator ??
           SceneEditorialGenerator(settingsStore: settingsStore),
       _reviewCoordinator =
           reviewCoordinator ??
           SceneReviewCoordinator(settingsStore: settingsStore),
       _polishPass =
           polishPass ?? ScenePolishPass(settingsStore: settingsStore),
       _qualityScorer = qualityScorer,
       _contextAssembler = contextAssembler ?? SceneContextAssembler(),
       _memoryStorage = memoryStorage,
       _memoryRetriever = memoryRetriever,
       _thoughtUpdater = thoughtUpdater,
       _ragOrchestrator = ragOrchestrator,
       _contextCache = contextCache,
       _chapterContextBridge = chapterContextBridge,
       _retrievalController = const RetrievalController();

  final int maxProseRetries;
  final void Function(String message)? onStatus;
  final SceneCastResolverService _castResolver;
  final SceneDirectorService _directorOrchestrator;
  final DynamicRoleAgentService _dynamicRoleAgentRunner;
  final SceneStateResolver _stateResolver;
  final SceneEditorialGenerator _editorialGenerator;
  final SceneReviewService _reviewCoordinator;
  final ScenePolishPass _polishPass;
  final SceneQualityScorerService? _qualityScorer;
  final SceneContextAssemblerService _contextAssembler;
  final StoryMemoryStorage? _memoryStorage;
  final StoryMemoryRetrieverService? _memoryRetriever;
  final ThoughtMemoryService? _thoughtUpdater;
  final RagOrchestrator? _ragOrchestrator;
  final StoryContextCache? _contextCache;
  final ChapterContextBridgeService? _chapterContextBridge;
  final RetrievalController _retrievalController;
  final NarrativeArcTracker _narrativeArcTracker = NarrativeArcTracker();
  NarrativeArcState _narrativeArc = NarrativeArcState();
  DirectorMemory _directorMemory = DirectorMemory();

  /// Pre-scene retrieval result for pipeline use.
  RetrievalTrace? _lastRetrievalTrace;

  /// The most recent retrieval trace, if any.
  @override
  RetrievalTrace? get lastRetrievalTrace => _lastRetrievalTrace;

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function(String message)? onStatus,
  }) async {
    final statusCallback = onStatus ?? this.onStatus;
    _directorMemory = _directorMemory.withActiveRoundState(
      DirectorRoundState(
        sceneId: brief.sceneId,
        maxRounds: maxProseRetries + 1,
      ),
    );
    final narrativeArcBeforeScene = brief.narrativeArc ?? _narrativeArc;
    brief = _briefWithNarrativeArc(brief, narrativeArcBeforeScene);

    // Cross-chapter context: enrich materials with previous chapter data
    ProjectMaterialSnapshot effectiveMaterials =
        materials ?? const ProjectMaterialSnapshot();
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
        await _memoryStorage.saveChunks(brief.chapterId, assembly.memoryChunks);
      }

      // Run retrieval for scene context
      final query = StoryMemoryQuery(
        projectId: brief.chapterId,
        queryType: StoryMemoryQueryType.sceneContinuity,
        text: '${brief.sceneTitle} ${brief.sceneSummary}',
        tags: [
          ...brief.worldNodeIds,
          for (final c in brief.cast) 'char-${c.characterId}',
        ],
        maxResults: 10,
        tokenBudget: 500,
        scopeId: '${brief.chapterId}:${brief.sceneId}',
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
      try {
        ragContext = await _ragOrchestrator.retrieveForScene(
          projectId: brief.chapterId,
          sceneTitle: brief.sceneTitle,
          sceneSummary: brief.sceneSummary,
          castNames: [for (final c in brief.cast) c.name],
          worldNodeIds: brief.worldNodeIds,
        );
      } on Object {
        // RAG failure must not block generation
      }
    }

    final resolvedCast = _castResolver.resolve(brief);
    statusCallback?.call('场景 ${brief.chapterId}/${brief.sceneId} · director');
    final directorContext = _composeDirectorContext(
      memoryContext: _directorMemory.toPromptText(),
      ragContext: ragContext?.formattedContext,
    );
    final director = await _directorOrchestrator.run(
      brief: brief,
      cast: resolvedCast,
      ragContext: directorContext,
    );
    final taskCard = _buildTaskCard(
      brief: brief,
      cast: resolvedCast,
      director: director,
    );
    final roleOutputs = await _dynamicRoleAgentRunner.run(
      brief: brief,
      cast: resolvedCast,
      director: director,
      taskCard: taskCard,
      ragContext: ragContext?.formattedContext,
      onStatus: statusCallback,
    );
    final roleplaySession = _dynamicRoleAgentRunner is DynamicRoleAgentRunner
        ? (_dynamicRoleAgentRunner as DynamicRoleAgentRunner)
              .lastRoleplaySession
        : null;
    final roleTurns = [
      for (final output in roleOutputs)
        pipeline.RolePlayTurnOutput.fromDynamicAgentOutput(output),
    ];
    final capsules = _retrievalController.resolve(
      taskCard: taskCard,
      turns: roleTurns,
    );
    statusCallback?.call(
      '场景 ${brief.chapterId}/${brief.sceneId} · resolve beats',
    );
    final resolvedBeats = await _stateResolver.resolve(
      taskCard: taskCard,
      roleTurns: roleTurns,
      capsules: capsules,
      onStatus: statusCallback,
    );
    final runtimeBeats = _runtimeBeatsFromResolved(resolvedBeats);
    final sceneState = _sceneStateFromRuntimeBeats(
      brief: brief,
      runtimeBeats: runtimeBeats,
    );

    var attempt = 1;
    var softFailureCount = 0;
    String? reviewFeedback;

    while (true) {
      statusCallback?.call(
        '场景 ${brief.chapterId}/${brief.sceneId} · editorial attempt $attempt',
      );
      final editorialDraft = await _editorialGenerator.generate(
        taskCard: taskCard,
        resolvedBeats: resolvedBeats,
        capsules: capsules,
        attempt: attempt,
        roleplaySession: roleplaySession,
        reviewFeedback: reviewFeedback,
      );
      final prose = SceneProseDraft(
        text: editorialDraft.text,
        attempt: editorialDraft.attempt,
      );
      final review = await _reviewCoordinator.review(
        brief: brief,
        director: director,
        roleOutputs: roleOutputs,
        prose: prose,
        roleplaySession: roleplaySession,
        retrievalPack: retrievalPack,
        onStatus: statusCallback,
      );

      _directorMemory = _directorMemory
          .incorporate(
            SceneReviewDigest(
              sceneId: brief.sceneId,
              decision: review.decision,
              issues: review.extractIssues(),
              strengths: review.extractStrengths(),
              proseAttempts: attempt,
            ),
          )
          .withActiveRoundState(
            DirectorRoundState(
              sceneId: brief.sceneId,
              round: attempt,
              maxRounds: maxProseRetries + 1,
              outcome: review.decision.toString(),
            ),
          );

      var outputProse = prose;
      if (review.decision == SceneReviewDecision.rewriteProse &&
          softFailureCount + 1 > maxProseRetries) {
        final refinedDraft = await _refineDraftIfNeeded(
          brief: brief,
          draft: editorialDraft,
          resolvedBeats: runtimeBeats,
          review: review,
        );
        outputProse = SceneProseDraft(
          text: refinedDraft.text,
          attempt: refinedDraft.attempt,
        );
      }

      if (review.decision == SceneReviewDecision.rewriteProse) {
        softFailureCount += 1;
        if (softFailureCount <= maxProseRetries) {
          attempt += 1;
          reviewFeedback = review.feedback;
          continue;
        }
      }

      // Build retrieval trace
      _lastRetrievalTrace = RetrievalTrace(
        query: StoryMemoryQuery(
          projectId: brief.chapterId,
          queryType: StoryMemoryQueryType.sceneContinuity,
          text: '${brief.sceneTitle} ${brief.sceneSummary}',
        ),
        selectedHitCount: retrievalPack?.hits.length ?? 0,
        deferredHitCount: retrievalPack?.deferredHitCount ?? 0,
        thoughtCreationCount: 0,
        rejectedThoughtCount: 0,
        indexedChunkCount: cachedAssembly?.memoryChunks.length ?? 0,
        sourceRefIds: retrievalPack != null
            ? [for (final h in retrievalPack.hits) ...h.chunk.rootSourceIds]
            : const [],
      );

      // Quality scoring runs in parallel with thought extraction when scene passes
      SceneQualityScore? qualityScore;
      if (_qualityScorer != null) {
        try {
          qualityScore = await _qualityScorer.score(
            brief: brief,
            director: director,
            prose: outputProse,
            review: review,
          );
        } on Object {
          // Quality scoring failure must not block the pipeline
        }
      }

      final output = SceneRuntimeOutput(
        brief: brief,
        resolvedCast: resolvedCast,
        director: director,
        roleOutputs: roleOutputs,
        resolvedBeats: runtimeBeats,
        sceneState: sceneState,
        roleplaySession: roleplaySession,
        prose: outputProse,
        review: review,
        proseAttempts: attempt,
        softFailureCount: softFailureCount,
        qualityScore: qualityScore,
      );

      // Post-scene: extract thoughts if scene passed and updater available
      if (review.decision == SceneReviewDecision.pass &&
          _thoughtUpdater != null) {
        final thoughtResult = await _thoughtUpdater.extractWithLlm(
          projectId: brief.chapterId,
          sceneOutput: output,
        );
        final prev = _lastRetrievalTrace!;
        _lastRetrievalTrace = RetrievalTrace(
          query: prev.query,
          selectedHitCount: prev.selectedHitCount,
          deferredHitCount: prev.deferredHitCount,
          thoughtCreationCount: thoughtResult.accepted.length,
          rejectedThoughtCount: thoughtResult.rejected.length,
          indexedChunkCount: prev.indexedChunkCount,
          sourceRefIds: prev.sourceRefIds,
        );
      }

      if (review.decision == SceneReviewDecision.pass) {
        _narrativeArc = _narrativeArcTracker.update(
          current: narrativeArcBeforeScene,
          output: output,
        );
      }

      return output;
    }
  }

  String? _composeDirectorContext({String? memoryContext, String? ragContext}) {
    final parts = <String>[];
    if (memoryContext != null && memoryContext.isNotEmpty) {
      parts.add(memoryContext);
    }
    if (ragContext != null && ragContext.isNotEmpty) {
      parts.add(ragContext);
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  Future<pipeline.SceneEditorialDraft> _refineDraftIfNeeded({
    required SceneBrief brief,
    required pipeline.SceneEditorialDraft draft,
    required List<ResolvedBeat> resolvedBeats,
    required SceneReviewResult review,
  }) async {
    if (review.decision != SceneReviewDecision.rewriteProse) {
      return draft;
    }
    final polishResult = await _polishPass.polish(
      brief: brief,
      editorialDraft: draft,
      resolvedBeats: resolvedBeats,
      reviewFeedback: review.feedback,
      refinementGuidance:
          review.refinementGuidance ?? review.synthesizeGuidance(),
    );
    if (polishResult.text.trim().isEmpty) {
      return draft;
    }
    return pipeline.SceneEditorialDraft(
      text: polishResult.text,
      beatCount: draft.beatCount,
      attempt: draft.attempt,
    );
  }

  SceneBrief _briefWithNarrativeArc(
    SceneBrief brief,
    NarrativeArcState narrativeArc,
  ) {
    if (brief.narrativeArc != null || !_hasNarrativeArcContent(narrativeArc)) {
      return brief;
    }
    return brief.copyWith(narrativeArc: narrativeArc);
  }

  bool _hasNarrativeArcContent(NarrativeArcState narrativeArc) {
    return narrativeArc.activeThreads.isNotEmpty ||
        narrativeArc.closedThreads.isNotEmpty ||
        narrativeArc.pendingForeshadowing.isNotEmpty ||
        narrativeArc.thematicArcs.isNotEmpty;
  }

  pipeline.SceneTaskCard _buildTaskCard({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required SceneDirectorOutput director,
  }) {
    return pipeline.SceneTaskCard(
      brief: brief,
      cast: cast,
      directorPlan: director.text,
      directorPlanParsed: director.plan,
      beliefs: _beliefsFromBrief(brief),
      relationships: _relationshipsFromBrief(brief),
      socialPositions: _socialPositionsFromBrief(brief),
      knowledge: _knowledgeFromBrief(brief),
      metadata: brief.metadata,
    );
  }

  List<pipeline.CharacterBelief> _beliefsFromBrief(SceneBrief brief) {
    final beliefs = <pipeline.CharacterBelief>[];
    void add({
      required String holderId,
      required String targetId,
      required String aspect,
      required String value,
    }) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      beliefs.add(
        pipeline.CharacterBelief(
          holderId: holderId,
          targetId: targetId,
          aspect: aspect,
          value: trimmed,
        ),
      );
    }

    for (final belief in brief.beliefStates) {
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知目标',
        value: belief.perceivedGoal,
      );
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知立场',
        value: belief.perceivedLoyalty,
      );
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知能力',
        value: belief.perceivedCompetence,
      );
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知风险',
        value: belief.perceivedRisk,
      );
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知情绪',
        value: belief.perceivedEmotionalState,
      );
      for (final item in belief.perceivedKnowledge) {
        add(
          holderId: belief.ownerCharacterId,
          targetId: belief.aboutCharacterId,
          aspect: '已形成认知',
          value: item,
        );
      }
      for (final item in belief.suspectedSecrets) {
        add(
          holderId: belief.ownerCharacterId,
          targetId: belief.aboutCharacterId,
          aspect: '怀疑内容',
          value: item,
        );
      }
    }
    return List<pipeline.CharacterBelief>.unmodifiable(beliefs);
  }

  List<pipeline.RelationshipSlice> _relationshipsFromBrief(SceneBrief brief) {
    return [
      for (final relationship in brief.relationshipStates)
        pipeline.RelationshipSlice(
          characterA: relationship.sourceCharacterId,
          characterB: relationship.targetCharacterId,
          label: relationship.privateAlignment.trim().isNotEmpty
              ? relationship.privateAlignment.trim()
              : relationship.publicAlignment.trim(),
          tension: ((relationship.fear + relationship.resentment) * 5)
              .round()
              .clamp(0, 10),
          trust: (relationship.trust * 10).round().clamp(0, 10),
        ),
    ];
  }

  List<pipeline.SocialPositionSlice> _socialPositionsFromBrief(
    SceneBrief brief,
  ) {
    return [
      for (final position in brief.socialPositions)
        pipeline.SocialPositionSlice(
          characterId: position.characterId,
          role: position.institution,
          formalRank: position.publicStatus,
          actualInfluence: [
            ...position.currentLeverage,
            ...position.resources,
            if (position.legalExposure.trim().isNotEmpty)
              position.legalExposure.trim(),
          ].join('；'),
        ),
    ];
  }

  List<pipeline.KnowledgeAtom> _knowledgeFromBrief(SceneBrief brief) {
    return [
      for (final atom in brief.knowledgeAtoms)
        if (atom.visibility.name == 'publicObservable' ||
            atom.visibility.name == 'agentPrivate')
          pipeline.KnowledgeAtom(
            id: atom.id,
            category: atom.type,
            content: atom.content,
            sourceId: atom.ownerScope,
          ),
    ];
  }

  List<ResolvedBeat> _runtimeBeatsFromResolved(
    List<pipeline.SceneBeat> resolvedBeats,
  ) {
    return [
      for (var i = 0; i < resolvedBeats.length; i++)
        _runtimeBeatFromResolved(resolvedBeats[i], i),
    ];
  }

  ResolvedBeat _runtimeBeatFromResolved(pipeline.SceneBeat beat, int index) {
    final typedDeltas = _stateDeltasFromText(beat.content);
    return ResolvedBeat(
      beatIndex: index,
      actorId: beat.sourceCharacterId,
      actionAccepted: true,
      acceptedSpeech: beat.kind == pipeline.SceneBeatKind.dialogue
          ? beat.content
          : '',
      acceptedAction: beat.kind == pipeline.SceneBeatKind.dialogue
          ? ''
          : beat.content,
      typedStateDeltas: typedDeltas,
      stateDelta: [for (final delta in typedDeltas) delta.value],
      newPublicFacts: beat.kind == pipeline.SceneBeatKind.fact
          ? [beat.content]
          : const [],
    );
  }

  SceneState _sceneStateFromRuntimeBeats({
    required SceneBrief brief,
    required List<ResolvedBeat> runtimeBeats,
  }) {
    final acceptedChanges = <String>[];
    final acceptedDeltas = <SceneStateDelta>[];
    final seen = <String>{};
    for (final beat in runtimeBeats) {
      for (final delta in beat.typedStateDeltas) {
        final key = '${delta.kind.name}:${delta.value}';
        if (seen.add(key)) {
          acceptedDeltas.add(delta);
          acceptedChanges.add(delta.value);
        }
      }
    }
    return SceneState(
      sceneId: brief.sceneId,
      beatIndex: runtimeBeats.length,
      acceptedStateChanges: acceptedChanges,
      acceptedStateDeltas: acceptedDeltas,
      lastResolvedBeat: runtimeBeats.isEmpty ? null : runtimeBeats.last,
    );
  }

  List<SceneStateDelta> _stateDeltasFromText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final delta = SceneStateDelta.inferKind(trimmed);
    if (delta.kind == SceneStateDeltaKind.generic) {
      return const [];
    }
    return [delta];
  }

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
