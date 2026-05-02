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
import 'scene_stage_narrator.dart';
import 'roleplay_session_store.dart';
import 'character_memory_store.dart';
import 'scene_roleplay_session_models.dart';
import 'scene_runtime_models.dart'
    show ResolvedBeat, SceneState, SceneStateDelta, SceneStateDeltaKind;
import 'scene_state_resolver.dart';
import 'story_context_cache.dart';
import 'story_prompt_templates.dart';
import '../domain/scene_models.dart';
import '../domain/memory_models.dart';
import 'story_memory_storage.dart';
import '../domain/story_pipeline_interfaces.dart';

class ChapterGenerationOrchestrator implements ChapterGenerationService {
  ChapterGenerationOrchestrator({
    required AppSettingsStore settingsStore,
    this.maxProseRetries = 1,
    this.maxSceneReplanRetries = 1,
    this.onStatus,
    SceneCastResolverService? castResolver,
    SceneDirectorService? directorOrchestrator,
    DynamicRoleAgentService? dynamicRoleAgentRunner,
    SceneStateResolver? stateResolver,
    SceneEditorialGenerator? editorialGenerator,
    SceneStageNarrator? stageNarrator,
    SceneReviewService? reviewCoordinator,
    ScenePolishPass? polishPass,
    SceneQualityScorerService? qualityScorer,
    SceneContextAssemblerService? contextAssembler,
    StoryMemoryStorage? memoryStorage,
    StoryMemoryRetrieverService? memoryRetriever,
    ThoughtMemoryService? thoughtUpdater,
    RoleplaySessionStore? roleplaySessionStore,
    CharacterMemoryStore? characterMemoryStore,
    RagOrchestrator? ragOrchestrator,
    StoryContextCache? contextCache,
    ChapterContextBridgeService? chapterContextBridge,
  }) : _settingsStore = settingsStore,
       _castResolver = castResolver ?? SceneCastResolver(),
       _directorOrchestrator =
           directorOrchestrator ??
           SceneDirectorOrchestrator(settingsStore: settingsStore),
       _dynamicRoleAgentRunner =
           dynamicRoleAgentRunner ??
           DynamicRoleAgentRunner(
             settingsStore: settingsStore,
             characterMemoryStore: characterMemoryStore,
           ),
       _stateResolver =
           stateResolver ?? SceneStateResolver(settingsStore: settingsStore),
       _editorialGenerator =
           editorialGenerator ??
           SceneEditorialGenerator(settingsStore: settingsStore),
       _stageNarrator =
           stageNarrator ?? SceneStageNarrator(settingsStore: settingsStore),
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
       _roleplaySessionStore = roleplaySessionStore,
       _characterMemoryStore = characterMemoryStore,
       _ragOrchestrator = ragOrchestrator,
       _contextCache = contextCache,
       _chapterContextBridge = chapterContextBridge,
       _retrievalController = const RetrievalController();

  final int maxProseRetries;
  final int maxSceneReplanRetries;
  final void Function(String message)? onStatus;

  /// When set, the orchestrator checks this before persisting character memory
  /// deltas. If it returns `true`, side-effect writes are skipped.
  bool Function()? isRunCancelled;

  final AppSettingsStore _settingsStore;
  final SceneCastResolverService _castResolver;
  final SceneDirectorService _directorOrchestrator;
  final DynamicRoleAgentService _dynamicRoleAgentRunner;
  final SceneStateResolver _stateResolver;
  final SceneEditorialGenerator _editorialGenerator;
  final SceneStageNarrator _stageNarrator;
  final SceneReviewService _reviewCoordinator;
  final ScenePolishPass _polishPass;
  final SceneQualityScorerService? _qualityScorer;
  final SceneContextAssemblerService _contextAssembler;
  final StoryMemoryStorage? _memoryStorage;
  final StoryMemoryRetrieverService? _memoryRetriever;
  final ThoughtMemoryService? _thoughtUpdater;
  final RoleplaySessionStore? _roleplaySessionStore;
  final CharacterMemoryStore? _characterMemoryStore;
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
    void Function()? onSpeculationReady,
  }) async {
    return StoryPromptTemplates.runWithLanguage(
      _settingsStore.snapshot.promptLanguage,
      () => _runScene(
        brief,
        materials: materials,
        onStatus: onStatus,
        onSpeculationReady: onSpeculationReady,
      ),
    );
  }

  Future<SceneRuntimeOutput> _runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function(String message)? onStatus,
    void Function()? onSpeculationReady,
  }) async {
    final statusCallback = onStatus ?? this.onStatus;
    _directorMemory = _directorMemory.withActiveRoundState(
      DirectorRoundState(
        sceneId: brief.sceneId,
        maxRounds: maxSceneReplanRetries + 1,
      ),
    );
    final narrativeArcBeforeScene = brief.narrativeArc ?? _narrativeArc;
    brief = _briefWithNarrativeArc(brief, narrativeArcBeforeScene);
    var currentBrief = brief;
    var sceneReplanCount = 0;
    var speculationReadySent = false;

    void markSpeculationReady() {
      if (speculationReadySent) {
        return;
      }
      speculationReadySent = true;
      onSpeculationReady?.call();
    }

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

    while (true) {
      final resolvedCast = _castResolver.resolve(currentBrief);
      statusCallback?.call(
        '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · director',
      );
      final directorContext = _composeDirectorContext(
        memoryContext: _directorMemory.toPromptText(),
        ragContext: ragContext?.formattedContext,
      );
      final director = await _directorOrchestrator.run(
        brief: currentBrief,
        cast: resolvedCast,
        ragContext: directorContext,
      );
      final taskCard = _buildTaskCard(
        brief: currentBrief,
        cast: resolvedCast,
        director: director,
      );
      final roleOutputs = await _dynamicRoleAgentRunner.run(
        brief: currentBrief,
        cast: resolvedCast,
        director: director,
        taskCard: taskCard,
        ragContext: ragContext?.formattedContext,
        onStatus: statusCallback,
      );
      final roleplaySession = _dynamicRoleAgentRunner is DynamicRoleAgentRunner
          ? _dynamicRoleAgentRunner.lastRoleplaySession
          : null;
      await _persistRoleplaySession(
        projectId: currentBrief.projectId ?? currentBrief.chapterId,
        brief: currentBrief,
        session: roleplaySession,
      );
      final roleTurns = [
        for (final output in roleOutputs)
          pipeline.RolePlayTurnOutput.fromDynamicAgentOutput(output),
      ];
      final capsules = _retrievalController.resolve(
        taskCard: taskCard,
        turns: roleTurns,
      );
      final stageCapsule = await _stageNarrator.generate(
        taskCard: taskCard,
        director: director,
        roleOutputs: roleOutputs,
        roleTurns: roleTurns,
        retrievalCapsules: capsules,
        roleplaySession: roleplaySession,
        ragContext: ragContext?.formattedContext,
        onStatus: statusCallback,
      );
      final sceneCapsules = [
        ...capsules,
        if (stageCapsule != null) stageCapsule,
      ];
      statusCallback?.call(
        '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · resolve beats',
      );
      final resolvedBeats = await _stateResolver.resolve(
        taskCard: taskCard,
        roleTurns: roleTurns,
        capsules: sceneCapsules,
        roleplaySession: roleplaySession,
        onStatus: statusCallback,
      );
      final runtimeBeats = _runtimeBeatsFromResolved(resolvedBeats);
      final sceneState = _sceneStateFromRuntimeBeats(
        brief: currentBrief,
        runtimeBeats: runtimeBeats,
      );

      var attempt = 1;
      var softFailureCount = 0;
      String? reviewFeedback;

      while (true) {
        statusCallback?.call(
          '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · editorial attempt $attempt',
        );
        final editorialDraft = await _editorialGenerator.generate(
          taskCard: taskCard,
          resolvedBeats: resolvedBeats,
          capsules: sceneCapsules,
          attempt: attempt,
          roleplaySession: roleplaySession,
          reviewFeedback: reviewFeedback,
        );
        final prose = SceneProseDraft(
          text: editorialDraft.text,
          attempt: editorialDraft.attempt,
        );
        final lengthReview = _reviewOverlongProse(
          brief: currentBrief,
          prose: prose,
        );
        if (lengthReview != null) {
          softFailureCount += 1;
          if (softFailureCount <= maxProseRetries) {
            statusCallback?.call(
              '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · editorial length retry',
            );
            attempt += 1;
            reviewFeedback = lengthReview.editorialFeedback;
            continue;
          }
        }
        final review =
            lengthReview ??
            await _reviewCoordinator.review(
              brief: currentBrief,
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
                sceneId: currentBrief.sceneId,
                decision: review.decision,
                issues: review.extractIssues(),
                strengths: review.extractStrengths(),
                proseAttempts: attempt,
              ),
            )
            .withActiveRoundState(
              DirectorRoundState(
                sceneId: currentBrief.sceneId,
                round: sceneReplanCount,
                maxRounds: maxSceneReplanRetries + 1,
                outcome: review.decision.toString(),
              ),
            );

        if (lengthReview == null &&
            review.decision == SceneReviewDecision.replanScene &&
            sceneReplanCount < maxSceneReplanRetries) {
          sceneReplanCount += 1;
          statusCallback?.call(
            '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · review issue -> scene replan $sceneReplanCount/$maxSceneReplanRetries',
          );
          currentBrief = _briefWithReplanFeedback(
            brief: currentBrief,
            review: review,
            replanRound: sceneReplanCount,
          );
          break;
        }

        var outputProse = prose;
        if (lengthReview == null &&
            review.decision == SceneReviewDecision.rewriteProse &&
            softFailureCount + 1 > maxProseRetries) {
          final refinedDraft = await _refineDraftIfNeeded(
            brief: currentBrief,
            draft: editorialDraft,
            resolvedBeats: runtimeBeats,
            review: review,
          );
          outputProse = SceneProseDraft(
            text: refinedDraft.text,
            attempt: refinedDraft.attempt,
          );
        }

        if (lengthReview == null &&
            review.decision == SceneReviewDecision.rewriteProse) {
          softFailureCount += 1;
          if (softFailureCount <= maxProseRetries) {
            statusCallback?.call(
              '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · review issue -> editorial retry',
            );
            attempt += 1;
            reviewFeedback = review.editorialFeedback;
            continue;
          }
        }

        if (lengthReview == null &&
            review.decision == SceneReviewDecision.pass &&
            _shouldRunFinalPolish(currentBrief)) {
          statusCallback?.call(
            '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · reader polish',
          );
          final polishResult = await _polishPass.polish(
            brief: currentBrief,
            editorialDraft: pipeline.SceneEditorialDraft(
              text: outputProse.text,
              beatCount: editorialDraft.beatCount,
              attempt: outputProse.attempt,
            ),
            resolvedBeats: runtimeBeats,
            reviewFeedback: review.editorialFeedback,
            refinementGuidance: review.refinementGuidance,
          );
          final polishedText = polishResult.text.trim();
          if (!polishResult.usedLocalFallback && polishedText.isNotEmpty) {
            outputProse = SceneProseDraft(
              text: polishedText,
              attempt: outputProse.attempt,
            );
          }
        }

        // Build retrieval trace
        _lastRetrievalTrace = RetrievalTrace(
          query: StoryMemoryQuery(
            projectId: currentBrief.chapterId,
            queryType: StoryMemoryQueryType.sceneContinuity,
            text: '${currentBrief.sceneTitle} ${currentBrief.sceneSummary}',
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

        SceneQualityScore? qualityScore;
        if (_qualityScorer != null) {
          try {
            qualityScore = await _qualityScorer.score(
              brief: currentBrief,
              director: director,
              prose: outputProse,
              review: review,
            );
          } on Object {
            // Quality scoring failure must not block the pipeline
          }
        }

        final output = SceneRuntimeOutput(
          brief: currentBrief,
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
            projectId: currentBrief.chapterId,
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

        markSpeculationReady();
        return output;
      }
    }
  }

  SceneReviewResult? _reviewOverlongProse({
    required SceneBrief brief,
    required SceneProseDraft prose,
  }) {
    final hardLimit = _sceneProseHardLimit(brief.targetLength);
    final actualLength = prose.text.trim().length;
    if (actualLength <= hardLimit) {
      return null;
    }

    final reason =
        '正文长度$actualLength字超过场景硬上限$hardLimit字（目标${brief.targetLength}字），'
        '需要压缩到目标附近，聚焦既有情节。';
    final judge = SceneReviewPassResult(
      status: SceneReviewStatus.rewriteProse,
      reason: reason,
      rawText: '决定：REWRITE_PROSE\n原因：$reason',
      categories: const [SceneReviewCategory.prose],
    );
    final consistency = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '',
      rawText: '决定：PASS\n原因：长度检查前未进入一致性审查。',
      categories: const [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
        SceneReviewCategory.characterState,
        SceneReviewCategory.worldState,
      ],
    );
    final review = SceneReviewResult(
      judge: judge,
      consistency: consistency,
      decision: SceneReviewDecision.rewriteProse,
    );
    return SceneReviewResult(
      judge: review.judge,
      consistency: review.consistency,
      decision: review.decision,
      refinementGuidance: review.synthesizeGuidance(),
    );
  }

  int _sceneProseHardLimit(int targetLength) {
    final normalizedTarget = targetLength < 1 ? 400 : targetLength;
    final doubled = normalizedTarget * 2;
    final floor = normalizedTarget + 400;
    return doubled > floor ? doubled : floor;
  }

  Future<void> _persistRoleplaySession({
    required String projectId,
    required SceneBrief brief,
    required SceneRoleplaySession? session,
  }) async {
    if (session == null || session.isEmpty) {
      return;
    }
    await _roleplaySessionStore?.saveSession(
      projectId: projectId,
      session: session,
    );
    if (isRunCancelled?.call() == true) {
      return;
    }
    final acceptedDeltas = session.acceptedMemoryDeltas
        .where((delta) => delta.accepted)
        .toList(growable: false);
    if (acceptedDeltas.isEmpty) {
      return;
    }
    await _characterMemoryStore?.saveAcceptedDeltas(
      projectId: projectId,
      chapterId: brief.chapterId,
      sceneId: brief.sceneId,
      deltas: acceptedDeltas,
    );
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
      reviewFeedback: review.editorialFeedback,
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

  bool _shouldRunFinalPolish(SceneBrief brief) {
    final value =
        brief.metadata['enableFinalPolish'] ??
        brief.metadata['readerPolish'] ??
        brief.metadata['finalPolish'];
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return const {
      'true',
      '1',
      'yes',
      'on',
      'always',
      'reader',
    }.contains(normalized);
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

  SceneBrief _briefWithReplanFeedback({
    required SceneBrief brief,
    required SceneReviewResult review,
    required int replanRound,
  }) {
    final feedback = review.editorialFeedback.trim();
    if (feedback.isEmpty) {
      return brief;
    }
    final existing = _stringListFromMetadata(
      brief.metadata['authorRevisionRequests'],
    );
    return brief.copyWith(
      metadata: {
        ...brief.metadata,
        'authorRevisionRequests': [...existing, '结构重排第$replanRound轮：$feedback'],
      },
    );
  }

  List<String> _stringListFromMetadata(Object? raw) {
    if (raw is List) {
      return [
        for (final item in raw)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString().trim(),
      ];
    }
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? const [] : [value];
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
    for (final delta in _narrativeDeltasFromBrief(brief)) {
      final key = '${delta.kind.name}:${delta.value}';
      if (seen.add(key)) {
        acceptedDeltas.add(delta);
        acceptedChanges.add(delta.value);
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

  List<SceneStateDelta> _narrativeDeltasFromBrief(SceneBrief brief) {
    final deltas = <SceneStateDelta>[];
    for (final value in [brief.targetBeat, brief.sceneSummary]) {
      deltas.addAll(_stateDeltasFromText(value));
    }
    return deltas;
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
