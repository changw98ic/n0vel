import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import '../domain/contracts/settings_contract.dart';

import 'character_consistency_verifier.dart';
import 'pipeline_event_log.dart';
import 'dynamic_role_agent_runner.dart';
import 'generation_pipeline_config.dart';
import 'material_reference_retriever.dart';
import 'retrieval_controller.dart';
import 'scene_cast_resolver.dart';
import 'scene_context_assembler.dart';
import 'scene_director_orchestrator.dart';
import 'scene_editorial_generator.dart';
import 'director_memory.dart';
import 'narrative_arc_models.dart';
import 'narrative_arc_tracker.dart';
import 'narrative_arc_prompt_builder.dart';
import 'scene_review_coordinator.dart';
import 'scene_polish_pass.dart';
import 'scene_stage_narrator.dart';
import 'roleplay_session_store.dart';
import 'character_memory_store.dart';
import 'canon_keeper.dart';
import 'scene_state_resolver.dart';
import 'soul_contract_validator.dart';
import 'story_context_cache.dart';
import 'story_prompt_templates.dart';
import 'story_memory_storage.dart';
import 'style_reference_config.dart';
import '../domain/scene_models.dart';
import '../domain/memory_models.dart';
import '../domain/story_pipeline_interfaces.dart';
import '../domain/contracts/event_log.dart';
import '../domain/contracts/memory_writeback_gate.dart'
    hide CanonKeeper, SoulContractValidator;
import '../domain/contracts/pipeline_role_contract.dart';
import '../domain/contracts/rag_retrieval_policy.dart';
import '../domain/contracts/stage_runner.dart';
import '../domain/contracts/typed_artifact.dart';
import 'step_io.dart';
import 'steps/context_enrichment_step.dart';
import 'steps/scene_planning_step.dart';
import 'steps/roleplay_step.dart';
import 'steps/stage_narration_step.dart';
import 'steps/beat_resolution_step.dart';
import 'steps/editorial_step.dart';
import 'steps/review_step.dart';
import 'steps/polish_step.dart';
import 'steps/finalization_step.dart';

class PipelineStageRunnerImpl
    implements ChapterGenerationService, PipelineStageRunner {
  PipelineStageRunnerImpl({
    required StoryGenerationSettingsContract settingsStore,
    GenerationPipelineConfig pipelineConfig = const GenerationPipelineConfig(),
    PipelineEventLog? eventLog,
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
    StoryMemoryRetrievalService? memoryRetriever,
    ThoughtMemoryService? thoughtUpdater,
    RoleplaySessionStore? roleplaySessionStore,
    CharacterMemoryStore? characterMemoryStore,
    HybridRetriever? hybridRetriever,
    StoryContextCache? contextCache,
    ChapterContextBridgeService? chapterContextBridge,
    CharacterConsistencyVerifier? consistencyVerifier,
    CanonKeeper? canonKeeper,
    SoulContractValidator? soulValidator,
    MemoryWritebackGate? writebackGate,
  }) {
    final sharedEventLog = eventLog ?? PipelineEventLogImpl();
    final sharedWritebackGate =
        writebackGate ??
        BasicMemoryWritebackGate(
          soulValidator: soulValidator?.asWritebackValidator(),
        );

    _settingsStore = settingsStore;
    _pipelineConfig = pipelineConfig;
    _eventLog = sharedEventLog;
    _writebackGate = sharedWritebackGate;
    _contextEnrichmentStep = ContextEnrichmentStep(
      chapterContextBridge: chapterContextBridge,
      contextAssembler: contextAssembler ?? SceneContextAssembler(),
      memoryStorage: memoryStorage,
      memoryRetriever: memoryRetriever,
      hybridRetriever: hybridRetriever,
      contextCache: contextCache,
    );
    _scenePlanningStep = ScenePlanningStep(
      castResolver: castResolver ?? SceneCastResolver(),
      consistencyVerifier: consistencyVerifier,
      directorOrchestrator:
          directorOrchestrator ??
          SceneDirectorOrchestrator(settingsStore: settingsStore),
      arcPromptBuilder: NarrativeArcPromptBuilder(),
    );
    _roleplayStep = RoleplayStep(
      dynamicRoleAgentRunner:
          dynamicRoleAgentRunner ??
          DynamicRoleAgentRunner(
            settingsStore: settingsStore,
            characterMemoryStore: characterMemoryStore,
            eventLog: sharedEventLog,
          ),
      roleplaySessionStore: roleplaySessionStore,
      characterMemoryStore: characterMemoryStore,
      retrievalController: RetrievalController(
        materialReferenceRetriever: MaterialReferenceRetriever(
          rootPath: pipelineConfig.styleReferenceConfig.rootPath,
        ),
        enableWritingReference:
            pipelineConfig.enableWritingReference &&
            pipelineConfig.styleReferenceConfig.enabled,
      ),
    );
    _stageNarrationStep = StageNarrationStep(
      stageNarrator:
          stageNarrator ??
          SceneStageNarrator(
            settingsStore: settingsStore,
            eventLog: sharedEventLog,
          ),
      retrievalController: RetrievalController(
        materialReferenceRetriever: MaterialReferenceRetriever(
          rootPath: pipelineConfig.styleReferenceConfig.rootPath,
        ),
        enableWritingReference:
            pipelineConfig.enableWritingReference &&
            pipelineConfig.styleReferenceConfig.enabled,
      ),
    );
    _beatResolutionStep = BeatResolutionStep(
      stateResolver:
          stateResolver ??
          SceneStateResolver(
            settingsStore: settingsStore,
            eventLog: sharedEventLog,
          ),
    );
    _editorialStep = EditorialStep(
      editorialGenerator:
          editorialGenerator ??
          SceneEditorialGenerator(settingsStore: settingsStore),
    );
    _reviewStep = ReviewStep(
      reviewCoordinator:
          reviewCoordinator ??
          SceneReviewCoordinator(
            settingsStore: settingsStore,
            hardGatesEnabled: pipelineConfig.hardGatesEnabled,
            canonKeeper: canonKeeper,
          ),
      consistencyVerifier: consistencyVerifier,
      maxProseRetries: pipelineConfig.maxProseRetries,
      hardGatesEnabled: pipelineConfig.hardGatesEnabled,
      eventLog: sharedEventLog,
    );
    _polishStep = PolishStep(
      polishPass: polishPass ?? ScenePolishPass(settingsStore: settingsStore),
      eventLog: sharedEventLog,
    );
    _finalizationStep = FinalizationStep(
      qualityScorer: qualityScorer,
      thoughtUpdater: thoughtUpdater,
      writebackGate: sharedWritebackGate,
      narrativeArcTracker: NarrativeArcTracker(),
    );
  }

  late final GenerationPipelineConfig _pipelineConfig;
  int get maxProseRetries => _pipelineConfig.maxProseRetries;
  int get maxSceneReplanRetries => _pipelineConfig.maxSceneReplanRetries;
  bool get enableWritingReference => _pipelineConfig.enableWritingReference;
  StyleReferenceConfig get styleReferenceConfig =>
      _pipelineConfig.styleReferenceConfig;

  late final PipelineEventLog _eventLog;
  late final MemoryWritebackGate _writebackGate;

  bool Function()? isRunCancelled;

  late final StoryGenerationSettingsContract _settingsStore;
  late final ContextEnrichmentStep _contextEnrichmentStep;
  late final ScenePlanningStep _scenePlanningStep;
  late final RoleplayStep _roleplayStep;
  late final StageNarrationStep _stageNarrationStep;
  late final BeatResolutionStep _beatResolutionStep;
  late final EditorialStep _editorialStep;
  late final ReviewStep _reviewStep;
  late final PolishStep _polishStep;
  late final FinalizationStep _finalizationStep;

  DirectorMemory _directorMemory = DirectorMemory();
  NarrativeArcState _narrativeArc = NarrativeArcState();
  RetrievalTrace? _lastRetrievalTrace;

  // -- PipelineStageRunner contract members --

  @override
  List<PipelineStage<TypedArtifact, TypedArtifact>> get stages => [
    _contextEnrichmentStep,
    _scenePlanningStep,
    _roleplayStep,
    _stageNarrationStep,
    _beatResolutionStep,
    _editorialStep,
    _reviewStep,
    _polishStep,
    _finalizationStep,
  ].cast<PipelineStage<TypedArtifact, TypedArtifact>>();

  @override
  PipelineEventLog get eventLog => _eventLog;

  @override
  int get maxGlobalRetries => 3;

  @override
  RagRetrievalPolicy get defaultRetrievalPolicy =>
      RagRetrievalPolicy.director();

  @override
  MemoryWritebackGate get writebackGate => _writebackGate;

  @override
  Future<PipelineRunResult> run(
    SceneBriefRef brief,
    PipelineContext context,
  ) async {
    final sceneBrief = context.metadata['sceneBrief'];
    if (sceneBrief is SceneBrief) {
      final materials = context.metadata['materials'];
      try {
        final output = await StoryPromptTemplates.runWithLanguage(
          _settingsStore.promptLanguage,
          () => _runSceneFinalization(
            _briefWithStyleReference(sceneBrief),
            materials: materials is ProjectMaterialSnapshot ? materials : null,
            context: _runnerContextFor(brief, context),
          ),
        );
        return PipelineRunResult(
          success: true,
          events: _eventLog.query(),
          finalArtifact: output,
        );
      } on Object catch (_) {
        return PipelineRunResult(
          success: false,
          events: _eventLog.query(),
          failureCode: FailureCode.recoverable,
          failedStageId: _lastFailedStageId(),
        );
      }
    }
    return PipelineRunResult(
      success: false,
      events: _eventLog.query(),
      failureCode: FailureCode.blocked,
      failedStageId: 'runner',
    );
  }

  // -- ChapterGenerationService contract members --

  @override
  RetrievalTrace? get lastRetrievalTrace => _lastRetrievalTrace;

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) {
    return StoryPromptTemplates.runWithLanguage(
      _settingsStore.promptLanguage,
      () => _runScene(
        _briefWithStyleReference(brief),
        materials: materials,
        onSpeculationReady: onSpeculationReady,
      ),
    );
  }

  SceneBrief _briefWithStyleReference(SceneBrief brief) {
    if (!enableWritingReference || !styleReferenceConfig.enabled) {
      return brief;
    }
    final styleSummary = styleReferenceConfig.promptSummary;
    if (styleSummary.isEmpty ||
        brief.sceneSummary.contains('风格约束：$styleSummary')) {
      return brief;
    }
    return brief.copyWith(
      sceneSummary: [
        '风格约束：$styleSummary',
        if (brief.sceneSummary.trim().isNotEmpty) brief.sceneSummary.trim(),
      ].join('\n'),
      metadata: {
        ...brief.metadata,
        'styleReferenceProfileId': styleReferenceConfig.profileId,
        'styleReferenceProfileName': styleReferenceConfig.profileName,
        'styleReferenceRootPath': styleReferenceConfig.rootPath,
      },
    );
  }

  Future<SceneRuntimeOutput> _runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) async {
    final finalization = await _runSceneFinalization(
      brief,
      materials: materials,
      onSpeculationReady: onSpeculationReady,
      context: _defaultContextFor(brief),
    );
    return finalization.output;
  }

  Future<FinalizationOutput> _runSceneFinalization(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
    required PipelineContext context,
  }) async {
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
      if (speculationReadySent) return;
      speculationReadySent = true;
      onSpeculationReady?.call();
    }

    // Step 1: Context enrichment (runs once)
    final contextOutput = await _executeTypedStage(
      _contextEnrichmentStep,
      ContextEnrichmentInput(brief: brief, materials: materials),
      context,
      brief,
    );

    // Outer loop: scene replan
    while (true) {
      // Step 2: Scene planning
      final planOutput = await _executeTypedStage(
        _scenePlanningStep,
        ScenePlanningInput(
          brief: currentBrief,
          ragContext: contextOutput.ragContext,
          directorMemory: _directorMemory,
          narrativeArc: _narrativeArc,
        ),
        context,
        currentBrief,
      );

      // Step 3: Roleplay
      final roleplayOutput = await _executeRoleplayStage(
        RoleplayInput(
          brief: currentBrief,
          plan: planOutput,
          ragContext: contextOutput.ragContext,
        ),
        context,
        currentBrief,
        isRunCancelled: isRunCancelled,
      );

      // Step 4: Stage narration
      final stageOutput = await _executeTypedStage(
        _stageNarrationStep,
        StageNarrationInput(
          plan: planOutput,
          roleplay: roleplayOutput,
          ragContext: contextOutput.ragContext,
        ),
        context,
        currentBrief,
      );

      // Step 5: Beat resolution
      final beatsOutput = await _executeTypedStage(
        _beatResolutionStep,
        BeatResolutionInput(
          brief: currentBrief,
          plan: planOutput,
          roleplay: roleplayOutput,
          stage: stageOutput,
        ),
        context,
        currentBrief,
      );

      var attempt = 1;
      var softFailureCount = 0;
      String? reviewFeedback;
      String? previousProse;

      // Inner loop: editorial retry
      while (true) {
        _emitStatus(currentBrief, 'editorial attempt $attempt');

        // Step 6: Editorial
        final editorialOutput = await _executeTypedStage(
          _editorialStep,
          EditorialInput(
            brief: currentBrief,
            plan: planOutput,
            beats: beatsOutput,
            roleplay: roleplayOutput,
            stage: stageOutput,
            attempt: attempt,
            reviewFeedback: reviewFeedback,
            previousProse: previousProse,
          ),
          context,
          currentBrief,
        );

        // Step 7: Review
        final reviewOutput = await _executeTypedStage(
          _reviewStep,
          ReviewInput(
            brief: currentBrief,
            plan: planOutput,
            roleplay: roleplayOutput,
            editorial: editorialOutput,
            context: contextOutput,
            attempt: attempt,
            softFailureCount: softFailureCount,
          ),
          context,
          currentBrief,
        );

        // Update director memory with review digest
        _directorMemory = _directorMemory
            .incorporate(
              SceneReviewDigest(
                sceneId: currentBrief.sceneId,
                decision: reviewOutput.review.decision,
                issues: reviewOutput.review.extractIssues(),
                strengths: reviewOutput.review.extractStrengths(),
                proseAttempts: attempt,
              ),
            )
            .withActiveRoundState(
              DirectorRoundState(
                sceneId: currentBrief.sceneId,
                round: sceneReplanCount,
                maxRounds: maxSceneReplanRetries + 1,
                outcome: reviewOutput.review.decision.toString(),
              ),
            );

        // Replan: break inner, continue outer
        if (!reviewOutput.wasLengthRetry &&
            reviewOutput.action == SceneReviewDecision.replanScene &&
            sceneReplanCount < maxSceneReplanRetries) {
          sceneReplanCount += 1;
          _emitStatus(
            currentBrief,
            'review issue -> scene replan $sceneReplanCount/$maxSceneReplanRetries',
          );
          currentBrief = _briefWithReplanFeedback(
            brief: currentBrief,
            review: reviewOutput.review,
            replanRound: sceneReplanCount,
          );
          break;
        }

        // Rewrite prose: continue inner loop
        if (reviewOutput.action == SceneReviewDecision.rewriteProse) {
          softFailureCount += 1;
          if (softFailureCount <= maxProseRetries) {
            _emitStatus(
              currentBrief,
              reviewOutput.wasLengthRetry
                  ? 'prose length issue -> editorial retry'
                  : 'review issue -> editorial retry',
            );
            attempt += 1;
            reviewFeedback = reviewOutput.review.editorialFeedback;
            previousProse = editorialOutput.prose.text;
            continue;
          }
        }

        // Step 8: Polish (only on pass or exhausted retries)
        var proseForOutput = editorialOutput.prose;
        if (!reviewOutput.wasLengthRetry &&
            reviewOutput.action == SceneReviewDecision.rewriteProse &&
            softFailureCount + 1 > maxProseRetries) {
          final polishOutput = await _executeTypedStage(
            _polishStep,
            PolishInput(
              brief: currentBrief,
              editorial: editorialOutput,
              beats: beatsOutput,
              review: reviewOutput,
            ),
            context,
            currentBrief,
          );
          proseForOutput = polishOutput.prose;
        } else if (reviewOutput.action == SceneReviewDecision.pass) {
          markSpeculationReady();
          final polishOutput = await _executeTypedStage(
            _polishStep,
            PolishInput(
              brief: currentBrief,
              editorial: editorialOutput,
              beats: beatsOutput,
              review: reviewOutput,
            ),
            context,
            currentBrief,
          );
          proseForOutput = polishOutput.prose;
        }

        // Step 9: Finalization
        final finalizationOutput = await _executeTypedStage(
          _finalizationStep,
          FinalizationInput(
            brief: currentBrief,
            plan: planOutput,
            roleplay: roleplayOutput,
            beats: beatsOutput,
            editorial: EditorialOutput(
              draft: editorialOutput.draft,
              prose: proseForOutput,
            ),
            polish: PolishOutput(prose: proseForOutput),
            review: reviewOutput,
            context: contextOutput,
            attempt: attempt,
            softFailureCount: softFailureCount,
            narrativeArcBeforeScene: narrativeArcBeforeScene,
          ),
          context,
          currentBrief,
        );

        _lastRetrievalTrace = finalizationOutput.retrievalTrace;
        _narrativeArc = _narrativeArcTracker.update(
          current: narrativeArcBeforeScene,
          output: finalizationOutput.output,
        );

        return finalizationOutput;
      }
    }
  }

  PipelineContext _defaultContextFor(SceneBrief brief) {
    final sceneRef = SceneBriefRef(
      projectId: brief.projectId ?? brief.chapterId,
      sceneId: brief.sceneId,
      sceneIndex: brief.sceneIndex,
      totalScenesInChapter: brief.totalScenesInChapter,
    );
    return PipelineContext(
      eventLog: _eventLog,
      retrievalPolicy: defaultRetrievalPolicy,
      writebackGate: _writebackGate,
      sceneBrief: sceneRef,
      metadata: {'sceneBrief': brief},
    );
  }

  PipelineContext _runnerContextFor(
    SceneBriefRef brief,
    PipelineContext context,
  ) {
    return PipelineContext(
      eventLog: _eventLog,
      retrievalPolicy: context.retrievalPolicy,
      writebackGate: _writebackGate,
      sceneBrief: brief,
      metadata: context.metadata,
    );
  }

  Future<O>
  _executeTypedStage<I extends TypedArtifact, O extends TypedArtifact>(
    PipelineStage<I, O> stage,
    I input,
    PipelineContext context,
    SceneBrief brief,
  ) async {
    return _executeStageWithLifecycle(
      stage: stage,
      input: input,
      brief: brief,
      execute: () => stage.execute(input, context),
    );
  }

  Future<RoleplayOutput> _executeRoleplayStage(
    RoleplayInput input,
    PipelineContext context,
    SceneBrief brief, {
    bool Function()? isRunCancelled,
  }) async {
    return _executeStageWithLifecycle(
      stage: _roleplayStep,
      input: input,
      brief: brief,
      execute: () =>
          _roleplayStep.execute(input, context, isRunCancelled: isRunCancelled),
    );
  }

  Future<O>
  _executeStageWithLifecycle<I extends TypedArtifact, O extends TypedArtifact>({
    required PipelineStage<I, O> stage,
    required I input,
    required SceneBrief brief,
    required Future<O> Function() execute,
  }) async {
    _emitStageLifecycle(
      stage: stage,
      brief: brief,
      eventType: 'stage_started',
      input: input,
    );
    try {
      final output = await execute();
      _emitStageLifecycle(
        stage: stage,
        brief: brief,
        eventType: 'stage_completed',
        input: input,
        output: output,
      );
      return output;
    } on Object catch (error) {
      _emitStageLifecycle(
        stage: stage,
        brief: brief,
        eventType: 'stage_failed',
        input: input,
        failureCode: FailureCode.recoverable,
        error: error,
      );
      rethrow;
    }
  }

  void _emitStageLifecycle<I extends TypedArtifact, O extends TypedArtifact>({
    required PipelineStage<I, O> stage,
    required SceneBrief brief,
    required String eventType,
    required TypedArtifact input,
    TypedArtifact? output,
    FailureCode? failureCode,
    Object? error,
  }) {
    final metadata = <String, Object?>{
      'projectId': brief.projectId ?? brief.chapterId,
      'sceneId': brief.sceneId,
      'inputType': input.type.name,
      if (output != null) 'outputType': output.type.name,
      if (error != null) 'error': error.toString(),
    };
    _eventLog.emit(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: stage.roleId,
        eventType: eventType,
        artifactType: output?.type ?? stage.outputType,
        failureCode: failureCode,
        metadata: metadata,
      ),
    );
  }

  String? _lastFailedStageId() {
    final failedEvents = _eventLog.query(eventType: 'stage_failed');
    if (failedEvents.isEmpty) return 'runner';
    return failedEvents.last.stageId;
  }

  void _emitStatus(SceneBrief brief, String message) {
    _eventLog.emit(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: 'orchestrator',
        eventType: 'status',
        metadata: {
          'sceneId': '${brief.chapterId}/${brief.sceneId}',
          'message': message,
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loop control helpers
  // ---------------------------------------------------------------------------

  final NarrativeArcTracker _narrativeArcTracker = NarrativeArcTracker();

  SceneBrief _briefWithNarrativeArc(SceneBrief brief, NarrativeArcState arc) {
    if (brief.narrativeArc != null || !_hasNarrativeArcContent(arc)) {
      return brief;
    }
    return brief.copyWith(narrativeArc: arc);
  }

  bool _hasNarrativeArcContent(NarrativeArcState arc) {
    return arc.activeThreads.isNotEmpty ||
        arc.closedThreads.isNotEmpty ||
        arc.pendingForeshadowing.isNotEmpty ||
        arc.thematicArcs.isNotEmpty;
  }

  SceneBrief _briefWithReplanFeedback({
    required SceneBrief brief,
    required SceneReviewResult review,
    required int replanRound,
  }) {
    final feedback = review.editorialFeedback.trim();
    if (feedback.isEmpty) return brief;
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
}
