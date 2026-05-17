import 'package:novel_writer/app/rag/rag_orchestrator.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'character_consistency_verifier.dart';
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
import 'scene_state_resolver.dart';
import 'story_context_cache.dart';
import 'story_prompt_templates.dart';
import 'story_memory_storage.dart';
import 'style_reference_config.dart';
import '../domain/scene_models.dart';
import '../domain/memory_models.dart';
import '../domain/story_pipeline_interfaces.dart';
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

class ChapterGenerationOrchestrator implements ChapterGenerationService {
  ChapterGenerationOrchestrator({
    required AppSettingsStore settingsStore,
    GenerationPipelineConfig pipelineConfig =
        const GenerationPipelineConfig(),
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
    CharacterConsistencyVerifier? consistencyVerifier,
  }) : _settingsStore = settingsStore,
       _pipelineConfig = pipelineConfig,
       _contextEnrichmentStep = ContextEnrichmentStep(
         chapterContextBridge: chapterContextBridge,
         contextAssembler: contextAssembler ?? SceneContextAssembler(),
         memoryStorage: memoryStorage,
         memoryRetriever: memoryRetriever,
         ragOrchestrator: ragOrchestrator,
         contextCache: contextCache,
       ),
       _scenePlanningStep = ScenePlanningStep(
         castResolver: castResolver ?? SceneCastResolver(),
         consistencyVerifier: consistencyVerifier,
         directorOrchestrator: directorOrchestrator ??
             SceneDirectorOrchestrator(settingsStore: settingsStore),
         arcPromptBuilder: NarrativeArcPromptBuilder(),
       ),
       _roleplayStep = RoleplayStep(
         dynamicRoleAgentRunner: dynamicRoleAgentRunner ??
             DynamicRoleAgentRunner(
               settingsStore: settingsStore,
               characterMemoryStore: characterMemoryStore,
             ),
         roleplaySessionStore: roleplaySessionStore,
         characterMemoryStore: characterMemoryStore,
         retrievalController: RetrievalController(
           materialReferenceRetriever: MaterialReferenceRetriever(
             rootPath: pipelineConfig.styleReferenceConfig.rootPath,
           ),
           enableWritingReference:
               pipelineConfig.enableWritingReference && pipelineConfig.styleReferenceConfig.enabled,
         ),
       ),
       _stageNarrationStep = StageNarrationStep(
         stageNarrator: stageNarrator ??
             SceneStageNarrator(settingsStore: settingsStore),
         retrievalController: RetrievalController(
           materialReferenceRetriever: MaterialReferenceRetriever(
             rootPath: pipelineConfig.styleReferenceConfig.rootPath,
           ),
           enableWritingReference:
               pipelineConfig.enableWritingReference && pipelineConfig.styleReferenceConfig.enabled,
         ),
       ),
       _beatResolutionStep = BeatResolutionStep(
         stateResolver: stateResolver ??
             SceneStateResolver(settingsStore: settingsStore),
       ),
       _editorialStep = EditorialStep(
         editorialGenerator: editorialGenerator ??
             SceneEditorialGenerator(settingsStore: settingsStore),
       ),
       _reviewStep = ReviewStep(
         reviewCoordinator: reviewCoordinator ??
             SceneReviewCoordinator(
               settingsStore: settingsStore,
               hardGatesEnabled: pipelineConfig.hardGatesEnabled,
             ),
         consistencyVerifier: consistencyVerifier,
         maxProseRetries: pipelineConfig.maxProseRetries,
         hardGatesEnabled: pipelineConfig.hardGatesEnabled,
       ),
       _polishStep = PolishStep(
         polishPass: polishPass ?? ScenePolishPass(settingsStore: settingsStore),
       ),
       _finalizationStep = FinalizationStep(
         qualityScorer: qualityScorer,
         thoughtUpdater: thoughtUpdater,
         narrativeArcTracker: NarrativeArcTracker(),
       );

  final GenerationPipelineConfig _pipelineConfig;
  int get maxProseRetries => _pipelineConfig.maxProseRetries;
  int get maxSceneReplanRetries => _pipelineConfig.maxSceneReplanRetries;
  bool get enableWritingReference => _pipelineConfig.enableWritingReference;
  StyleReferenceConfig get styleReferenceConfig =>
      _pipelineConfig.styleReferenceConfig;

  final void Function(String message)? onStatus;

  bool Function()? isRunCancelled;

  final AppSettingsStore _settingsStore;
  final ContextEnrichmentStep _contextEnrichmentStep;
  final ScenePlanningStep _scenePlanningStep;
  final RoleplayStep _roleplayStep;
  final StageNarrationStep _stageNarrationStep;
  final BeatResolutionStep _beatResolutionStep;
  final EditorialStep _editorialStep;
  final ReviewStep _reviewStep;
  final PolishStep _polishStep;
  final FinalizationStep _finalizationStep;

  DirectorMemory _directorMemory = DirectorMemory();
  NarrativeArcState _narrativeArc = NarrativeArcState();
  RetrievalTrace? _lastRetrievalTrace;

  @override
  RetrievalTrace? get lastRetrievalTrace => _lastRetrievalTrace;

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function(String message)? onStatus,
    void Function()? onSpeculationReady,
  }) {
    return StoryPromptTemplates.runWithLanguage(
      _settingsStore.snapshot.promptLanguage,
      () => _runScene(
        _briefWithStyleReference(brief),
        materials: materials,
        onStatus: onStatus,
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
      if (speculationReadySent) return;
      speculationReadySent = true;
      onSpeculationReady?.call();
    }

    // Step 1: Context enrichment (runs once)
    final contextOutput = await _contextEnrichmentStep.execute(
      ContextEnrichmentInput(brief: brief, materials: materials),
    );

    // Outer loop: scene replan
    while (true) {
      // Step 2: Scene planning
      final planOutput = await _scenePlanningStep.execute(
        ScenePlanningInput(
          brief: currentBrief,
          ragContext: contextOutput.ragContext,
          directorMemory: _directorMemory,
          narrativeArc: _narrativeArc,
        ),
      );

      // Step 3: Roleplay
      final roleplayOutput = await _roleplayStep.execute(
        RoleplayInput(
          brief: currentBrief,
          plan: planOutput,
          ragContext: contextOutput.ragContext,
        ),
        isRunCancelled: isRunCancelled,
        onStatus: statusCallback,
      );

      // Step 4: Stage narration
      final stageOutput = await _stageNarrationStep.execute(
        StageNarrationInput(
          plan: planOutput,
          roleplay: roleplayOutput,
          ragContext: contextOutput.ragContext,
        ),
        onStatus: statusCallback,
      );

      // Step 5: Beat resolution
      final beatsOutput = await _beatResolutionStep.execute(
        BeatResolutionInput(
          brief: currentBrief,
          plan: planOutput,
          roleplay: roleplayOutput,
          stage: stageOutput,
        ),
        onStatus: statusCallback,
      );

      var attempt = 1;
      var softFailureCount = 0;
      String? reviewFeedback;
      String? previousProse;

      // Inner loop: editorial retry
      while (true) {
        statusCallback?.call(
          '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · editorial attempt $attempt',
        );

        // Step 6: Editorial
        final editorialOutput = await _editorialStep.execute(
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
        );

        // Step 7: Review
        final reviewOutput = await _reviewStep.execute(
          ReviewInput(
            brief: currentBrief,
            plan: planOutput,
            roleplay: roleplayOutput,
            editorial: editorialOutput,
            context: contextOutput,
            attempt: attempt,
            softFailureCount: softFailureCount,
          ),
          onStatus: statusCallback,
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
          statusCallback?.call(
            '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · review issue -> scene replan $sceneReplanCount/$maxSceneReplanRetries',
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
            statusCallback?.call(
              reviewOutput.wasLengthRetry
                  ? '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · prose length issue -> editorial retry'
                  : '场景 ${currentBrief.chapterId}/${currentBrief.sceneId} · review issue -> editorial retry',
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
          final polishOutput = await _polishStep.execute(
            PolishInput(
              brief: currentBrief,
              editorial: editorialOutput,
              beats: beatsOutput,
              review: reviewOutput,
            ),
          );
          proseForOutput = polishOutput.prose;
        } else if (reviewOutput.action == SceneReviewDecision.pass) {
          markSpeculationReady();
          final polishOutput = await _polishStep.execute(
            PolishInput(
              brief: currentBrief,
              editorial: editorialOutput,
              beats: beatsOutput,
              review: reviewOutput,
            ),
            onStatus: statusCallback,
          );
          proseForOutput = polishOutput.prose;
        }

        // Step 9: Finalization
        final finalizationOutput = await _finalizationStep.execute(
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
        );

        _lastRetrievalTrace = finalizationOutput.retrievalTrace;
        _narrativeArc = _narrativeArcTracker.update(
          current: narrativeArcBeforeScene,
          output: finalizationOutput.output,
        );

        return finalizationOutput.output;
      }
    }
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
