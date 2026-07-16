import 'dart:convert';

import 'package:cryptography/cryptography.dart';
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
import 'scene_quality_scorer.dart';
import 'quality_repair_policy.dart';
import 'scene_polish_pass.dart';
import 'polish_canon_verifier.dart';
import 'story_mechanics_verifier.dart';
import 'story_mechanics_evidence.dart';
import 'production_pre_quality_gate.dart';
import 'scene_stage_narrator.dart';
import 'roleplay_session_store.dart';
import 'character_memory_store.dart';
import 'canon_keeper.dart';
import 'scene_state_resolver.dart';
import 'soul_contract_validator.dart';
import 'story_context_cache.dart';
import 'story_prompt_templates.dart';
import 'story_prompt_registry.dart';
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
import 'generation_ledger_models.dart';
import 'generation_ledger.dart';
import 'generation_stage_checkpoint_codec.dart';

/// Cancellation is a first-class lifecycle outcome, rather than a generic
/// provider error that retry logic may accidentally replay.
class PipelineRunCancelled implements Exception {
  const PipelineRunCancelled(this.stageId);

  final String stageId;

  @override
  String toString() => 'PipelineRunCancelled(stage: $stageId)';
}

/// A failed quality gate may be repaired into a new prose revision, but the
/// failing revision itself can never reach finalization.
class QualityGateFailure extends StateError {
  QualityGateFailure(this.score)
    : super(
        'Quality gate blocked: overall=${score.overall}; '
        'critical=${[
          score.prose,
          score.coherence,
          score.character,
          score.completeness,
          if (score.hasExtendedRubric) ...[score.styleScore, score.imageryScore, score.rhythmScore, score.faithfulnessScore],
        ].join(',')}; '
        'thresholds=overall>=95,critical>=90,extended>=90; '
        'summary=${score.summary.replaceAll(RegExp(r'\\s+'), ' ').trim()}.',
      );

  final SceneQualityScore score;
}

/// Versioned, hash-bound checkpoint data. Checkpoints are resumability hints;
/// they never stand in for a finalization proof or an author commit receipt.
class PipelineStageCheckpoint {
  const PipelineStageCheckpoint({
    required this.runId,
    this.proseRevision = 0,
    required this.ordinal,
    required this.stageId,
    required this.stageAttempt,
    required this.schemaVersion,
    required this.inputDigest,
    required this.artifactDigest,
    required this.status,
    required this.createdAtMs,
    this.completedAtMs,
    this.artifactType = '',
    this.artifactJson = const {},
    this.upstreamChainDigest = _emptyDigest,
    this.provenance = const GenerationCheckpointProvenance(
      baseDraftDigest: _emptyDigest,
      materialDigest: _emptyDigest,
      promptDigest: _emptyDigest,
      modelDigest: _emptyDigest,
    ),
  });

  static const currentSchemaVersion = GenerationStageCheckpointCodec.version;
  static const _emptyDigest =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final String runId;
  final int proseRevision;
  final int ordinal;
  final String stageId;
  final int stageAttempt;
  final int schemaVersion;
  final String inputDigest;
  final String artifactDigest;
  final String status;
  final int createdAtMs;
  final int? completedAtMs;
  final String artifactType;
  final Map<String, Object?> artifactJson;
  final String upstreamChainDigest;
  final GenerationCheckpointProvenance provenance;

  bool get isCompleted => status == 'completed' && completedAtMs != null;
}

/// Persistence boundary for checkpoint envelopes. Implementations must retain
/// checkpoints under the run identity and may discard incompatible entries.
abstract class PipelineCheckpointStore {
  Future<List<PipelineStageCheckpoint>> load({required String runId});

  Future<void> save(PipelineStageCheckpoint checkpoint);
}

/// Decodes a strictly allowlisted checkpoint DTO back into the exact typed
/// stage artifact needed by the next pipeline stage. Returning null is a
/// fail-closed boundary: the runner recomputes that stage and every suffix.
typedef PipelineCheckpointArtifactRestorer =
    Future<TypedArtifact?> Function(
      PipelineStageCheckpoint checkpoint,
      TypedArtifact input,
    );

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
    PolishCanonVerifier polishCanonVerifier = PolishCanonVerifier.standard,
    StoryMechanicsVerifier storyMechanicsVerifier =
        StoryMechanicsVerifier.standard,
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
    StoryPromptRegistry? promptRegistry,
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
    _promptRegistry = promptRegistry ?? StoryPromptRegistry.production;
    _qualityScorer =
        qualityScorer ?? SceneQualityScorer(settingsStore: settingsStore);
    _preQualityGate = ProductionPreQualityGate(
      polishCanonVerifier: polishCanonVerifier,
      storyMechanicsVerifier: storyMechanicsVerifier,
    );
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
    _finalizationStep = const FinalizationStep();
  }

  late final GenerationPipelineConfig _pipelineConfig;
  int get maxProseRetries => _pipelineConfig.maxProseRetries;
  int get maxQualityRepairRetries => _pipelineConfig.maxQualityRepairRetries;
  int get maxSceneReplanRetries => _pipelineConfig.maxSceneReplanRetries;
  bool get enableWritingReference => _pipelineConfig.enableWritingReference;
  StyleReferenceConfig get styleReferenceConfig =>
      _pipelineConfig.styleReferenceConfig;

  late final PipelineEventLog _eventLog;
  late final MemoryWritebackGate _writebackGate;
  late final StoryPromptRegistry _promptRegistry;
  late final SceneQualityScorerService _qualityScorer;
  late final ProductionPreQualityGate _preQualityGate;

  bool Function()? isRunCancelled;

  /// Optional per-run persistence. Checkpoints are never accepted as a
  /// candidate proof; they only describe work that may be replayed safely.
  PipelineCheckpointStore? checkpointStore;
  String? checkpointRunId;
  int checkpointProseRevision = 0;
  GenerationCheckpointProvenance? checkpointProvenance;
  GenerationLedgerSqliteStore? generationLedger;
  PipelineCheckpointArtifactRestorer? checkpointArtifactRestorer =
      const GenerationStageArtifactRestorer().call;

  /// Production author-candidate finalization is committed by
  /// [GenerationLedgerCandidateFinalizer] together with proof/payload/run
  /// pointer. When enabled, ordinal 12 must not publish a standalone cache
  /// checkpoint first, because that would expose a completed finalization
  /// without a durable candidate.
  bool deferFinalizationCheckpointToCandidateLedger = false;
  final GenerationStageCheckpointCodec _checkpointCodec =
      const GenerationStageCheckpointCodec();
  int _globalRetryCount = 0;
  Map<int, PipelineStageCheckpoint> _resumeChain = const {};

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
  Future<PipelineRunResult> run(SceneBriefRef brief, PipelineContext context) =>
      _promptRegistry.runAsync(() => _runPipeline(brief, context));

  Future<PipelineRunResult> _runPipeline(
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
      } on Object catch (error) {
        final failureEvent = _lastFailureEvent();
        var failureCode = failureEvent?.failureCode ?? FailureCode.fatal;
        var failedStageId = failureEvent?.stageId ?? 'runner';
        if (error is PipelineRunCancelled) {
          failureCode = FailureCode.blocked;
          failedStageId = error.stageId;
        } else if (error is QualityGateFailure) {
          failureCode = FailureCode.qualityFail;
          failedStageId = 'quality_gate';
        } else if (error is PolishCanonViolation) {
          failureCode = FailureCode.canonViolation;
          failedStageId = 'deterministic_gate';
        } else if (error is StoryMechanicsViolation) {
          failureCode = FailureCode.qualityFail;
          failedStageId = 'deterministic_gate';
        } else if (error is ProductionPreQualityGateViolation) {
          failureCode = FailureCode.qualityFail;
          failedStageId = 'deterministic_gate';
        } else if (error is GenerationBudgetUnavailable) {
          failureCode = FailureCode.budgetExceeded;
          failedStageId = 'budget';
        } else if (error is GenerationLedgerInvariantViolation) {
          failureCode = FailureCode.fatal;
          failedStageId = 'ledger';
        }
        _eventLog.emit(
          PipelineEvent(
            timestampMs: DateTime.now().millisecondsSinceEpoch,
            stageId: failedStageId,
            eventType: 'pipeline_failed',
            failureCode: failureCode,
            metadata: <String, Object?>{
              'sceneId': sceneBrief.sceneId,
              'errorType': error.runtimeType.toString(),
              'error': error.toString(),
            },
          ),
        );
        return PipelineRunResult(
          success: false,
          events: _eventLog.query(),
          failureCode: failureCode,
          failedStageId: failedStageId,
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
    return _promptRegistry.runAsync(
      () => StoryPromptTemplates.runWithLanguage(
        _settingsStore.promptLanguage,
        () => _runScene(
          _briefWithStyleReference(brief),
          materials: materials,
          onSpeculationReady: onSpeculationReady,
        ),
      ),
    );
  }

  /// Runs the provider-free production boundary for an author revision.
  ///
  /// The revised prose must have a distinct predecessor. This records the
  /// same ordinal-8 payload as generated polish and stops before final
  /// council, independent quality, candidate finalization, and author commit.
  Future<ProductionPreQualityEvidence> runAuthorRevisionPreQuality({
    required SceneBrief brief,
    required ProjectMaterialSnapshot materials,
    required String predecessorProse,
    required String revisedProse,
    int stageAttempt = 1,
  }) async {
    _throwIfCancelled('deterministic_gate');
    final evidence = _preQualityGate.verifyAuthorRevision(
      brief: brief,
      materials: materials,
      predecessorProse: predecessorProse,
      revisedProse: revisedProse,
      hardGatesEnabled: _pipelineConfig.hardGatesEnabled,
    );
    await _recordEvidenceCheckpoint(
      ordinal: 8,
      brief: brief,
      artifactType: 'deterministicGateEvidence',
      payload: await _productionPreQualityCheckpointPayload(
        evidence: evidence,
        finalProse: revisedProse,
      ),
      stageAttempt: stageAttempt,
    );
    _eventLog.emit(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: 'deterministic_gate',
        eventType: evidence.passed
            ? 'author_revision_pre_quality_passed'
            : 'author_revision_pre_quality_blocked',
        failureCode: evidence.passed ? null : FailureCode.qualityFail,
        metadata: <String, Object?>{
          'sceneId': brief.sceneId,
          'boundaryReleaseHash': evidence.boundaryReleaseHash,
          'briefRequirementsHash': evidence.briefRequirementsHash,
          'evidenceHash': evidence.evidenceHash,
        },
      ),
    );
    if (!evidence.passed) {
      throw ProductionPreQualityGateViolation(evidence);
    }
    return evidence;
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
    _globalRetryCount = 0;
    _throwIfCancelled('run_start');
    _resumeChain = await _prepareResumeChain(brief);
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
    _globalRetryCount = 0;
    _throwIfCancelled('run_start');
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
    final reviewAttempts = <SceneReviewAttempt>[];

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
      var qualityRepairCount = 0;
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
          checkpointAttemptGroup: attempt,
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
          checkpointAttemptGroup: attempt,
        );
        reviewAttempts.add(
          SceneReviewAttempt.snapshot(
            round: sceneReplanCount + 1,
            proseAttempt: attempt,
            phase: SceneReviewPhase.preliminary,
            decision: reviewOutput.action,
            reason: _reviewAttemptReason(reviewOutput),
            timestamp: DateTime.now().millisecondsSinceEpoch,
            proseHash: await _digestText(editorialOutput.prose.text),
            repairScheduled: _preliminaryRepairWillRun(
              reviewOutput: reviewOutput,
              sceneReplanCount: sceneReplanCount,
              softFailureCount: softFailureCount,
            ),
          ),
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
            reviewFeedback = _reviewRevisionFeedback(reviewOutput.review);
            previousProse = editorialOutput.prose.text;
            continue;
          }
        }

        // No failed preliminary review may proceed as a candidate. Retry
        // exhaustion is a blocked run, not permission to polish/finalize it.
        if (reviewOutput.action != SceneReviewDecision.pass) {
          throw StateError(
            'Preliminary review did not pass after $softFailureCount prose retries.',
          );
        }

        // Step 8: polish. It always yields the exact prose that must undergo
        // deterministic gates and an independent final council review.
        final rawPolishOutput = await _executeTypedStage(
          _polishStep,
          PolishInput(
            brief: currentBrief,
            editorial: editorialOutput,
            beats: beatsOutput,
            review: reviewOutput,
          ),
          context,
          currentBrief,
          checkpointAttemptGroup: attempt,
        );
        final preQualityEvidence = _preQualityGate.verifyPipelinePolish(
          prePolishProse: editorialOutput.prose.text,
          finalProse: rawPolishOutput.prose.text,
          brief: currentBrief,
          materials: contextOutput.effectiveMaterials,
          hardGatesEnabled: _pipelineConfig.hardGatesEnabled,
        );
        final polishCanonEvidence = preQualityEvidence.polishCanonEvidence;
        if (!polishCanonEvidence.passed) {
          reviewAttempts.add(
            SceneReviewAttempt.snapshot(
              round: sceneReplanCount + 1,
              proseAttempt: attempt,
              phase: SceneReviewPhase.deterministic,
              decision: SceneReviewDecision.rewriteProse,
              reason:
                  'Polish canon gate blocked the candidate: '
                  '${polishCanonEvidence.failureCodes.join(', ')}.',
              failureCodes: polishCanonEvidence.failureCodes,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              proseHash: polishCanonEvidence.finalProseHash,
            ),
          );
          _eventLog.emit(
            PipelineEvent(
              timestampMs: DateTime.now().millisecondsSinceEpoch,
              stageId: 'deterministic_gate',
              eventType: 'polish_canon_blocked',
              metadata: <String, Object?>{
                'sceneId': currentBrief.sceneId,
                'verifierReleaseHash': polishCanonEvidence.verifierReleaseHash,
                'evidenceHash': polishCanonEvidence.evidenceHash,
                'failureCodes': polishCanonEvidence.failureCodes,
              },
            ),
          );
          throw PolishCanonViolation(polishCanonEvidence);
        }
        final storyMechanicsEvidence =
            preQualityEvidence.storyMechanicsEvidence;
        if (preQualityEvidence.hardGateViolations.isNotEmpty) {
          final repairScheduled = softFailureCount < maxProseRetries;
          final failureCodes = <String>['quality.pre_quality_hard_gate'];
          reviewAttempts.add(
            SceneReviewAttempt.snapshot(
              round: sceneReplanCount + 1,
              proseAttempt: attempt,
              phase: SceneReviewPhase.deterministic,
              decision: SceneReviewDecision.rewriteProse,
              reason:
                  'Production pre-quality hard gate blocked the candidate: '
                  '${preQualityEvidence.hardGateViolations.map((item) => item.text).join(' | ')}',
              failureCodes: failureCodes,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              proseHash: preQualityEvidence.finalProseHash,
              repairScheduled: repairScheduled,
            ),
          );
          if (repairScheduled) {
            softFailureCount += 1;
            attempt += 1;
            previousProse = rawPolishOutput.prose.text;
            reviewFeedback = preQualityEvidence.hardGateViolations
                .map((item) => item.text)
                .join('\n');
            _emitStatus(
              currentBrief,
              'pre-quality hard gate issue -> editorial retry '
              '$softFailureCount/$maxProseRetries',
            );
            _eventLog.emit(
              PipelineEvent(
                timestampMs: DateTime.now().millisecondsSinceEpoch,
                stageId: 'deterministic_gate',
                eventType: 'pre_quality_hard_gate_repair_scheduled',
                metadata: <String, Object?>{
                  'sceneId': currentBrief.sceneId,
                  'repairAttempt': softFailureCount,
                  'maxRepairAttempts': maxProseRetries,
                  'boundaryReleaseHash': preQualityEvidence.boundaryReleaseHash,
                  'evidenceHash': preQualityEvidence.evidenceHash,
                  'failureCodes': failureCodes,
                },
              ),
            );
            continue;
          }
          _eventLog.emit(
            PipelineEvent(
              timestampMs: DateTime.now().millisecondsSinceEpoch,
              stageId: 'deterministic_gate',
              eventType: 'pre_quality_hard_gate_blocked',
              metadata: <String, Object?>{
                'sceneId': currentBrief.sceneId,
                'boundaryReleaseHash': preQualityEvidence.boundaryReleaseHash,
                'evidenceHash': preQualityEvidence.evidenceHash,
                'failureCodes': failureCodes,
              },
            ),
          );
          throw ProductionPreQualityGateViolation(preQualityEvidence);
        }
        if (!storyMechanicsEvidence.passed) {
          final repairScheduled = softFailureCount < maxProseRetries;
          reviewAttempts.add(
            SceneReviewAttempt.snapshot(
              round: sceneReplanCount + 1,
              proseAttempt: attempt,
              phase: SceneReviewPhase.deterministic,
              decision: SceneReviewDecision.rewriteProse,
              reason:
                  'Story mechanics gate blocked the candidate: '
                  '${storyMechanicsEvidence.failureCodes.join(', ')}.',
              failureCodes: storyMechanicsEvidence.failureCodes,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              proseHash: storyMechanicsEvidence.proseHash,
              repairScheduled: repairScheduled,
            ),
          );
          if (softFailureCount < maxProseRetries) {
            softFailureCount += 1;
            attempt += 1;
            previousProse = rawPolishOutput.prose.text;
            reviewFeedback = _storyMechanicsRepairFeedback(
              storyMechanicsEvidence,
            );
            _emitStatus(
              currentBrief,
              'story mechanics issue -> editorial retry '
              '$softFailureCount/$maxProseRetries',
            );
            _eventLog.emit(
              PipelineEvent(
                timestampMs: DateTime.now().millisecondsSinceEpoch,
                stageId: 'deterministic_gate',
                eventType: 'story_mechanics_repair_scheduled',
                metadata: <String, Object?>{
                  'sceneId': currentBrief.sceneId,
                  'repairAttempt': softFailureCount,
                  'maxRepairAttempts': maxProseRetries,
                  'failureCodes': storyMechanicsEvidence.failureCodes,
                },
              ),
            );
            continue;
          }
          _eventLog.emit(
            PipelineEvent(
              timestampMs: DateTime.now().millisecondsSinceEpoch,
              stageId: 'deterministic_gate',
              eventType: 'story_mechanics_blocked',
              metadata: <String, Object?>{
                'sceneId': currentBrief.sceneId,
                'verifierReleaseHash':
                    storyMechanicsEvidence.verifierReleaseHash,
                'evidenceHash': storyMechanicsEvidence.evidenceHash,
                'failureCodes': storyMechanicsEvidence.failureCodes,
              },
            ),
          );
          throw StoryMechanicsViolation(storyMechanicsEvidence);
        }
        final polishOutput = PolishOutput(
          prose: rawPolishOutput.prose,
          canonEvidence: polishCanonEvidence,
          storyMechanicsEvidence: storyMechanicsEvidence,
          productionPreQualityEvidence: preQualityEvidence,
        );
        reviewAttempts.add(
          SceneReviewAttempt.snapshot(
            round: sceneReplanCount + 1,
            proseAttempt: attempt,
            phase: SceneReviewPhase.deterministic,
            decision: SceneReviewDecision.pass,
            reason:
                'Polish canon and story mechanics gates passed for the exact prose.',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            proseHash: storyMechanicsEvidence.proseHash,
          ),
        );

        // Ordinal 8 is intentionally provider-free. Persist the exact prose
        // identity which the final council is about to review so a restart
        // cannot mistake an editorial checkpoint for a polished revision.
        await _recordEvidenceCheckpoint(
          ordinal: 8,
          brief: currentBrief,
          artifactType: 'deterministicGateEvidence',
          payload: await _productionPreQualityCheckpointPayload(
            evidence: preQualityEvidence,
            finalProse: polishOutput.prose.text,
          ),
          stageAttempt: attempt,
        );

        // Step 9: final council review of the polished revision. Reusing the
        // preliminary review would certify a different text revision.
        final finalReviewOutput = await _executeTypedStage(
          _reviewStep,
          ReviewInput(
            brief: currentBrief,
            plan: planOutput,
            roleplay: roleplayOutput,
            editorial: EditorialOutput(
              draft: editorialOutput.draft,
              prose: polishOutput.prose,
            ),
            context: contextOutput,
            attempt: attempt,
            softFailureCount: softFailureCount,
          ),
          context,
          currentBrief,
          checkpointOrdinal: 9,
          checkpointAttemptGroup: attempt,
        );
        reviewAttempts.add(
          SceneReviewAttempt.snapshot(
            round: sceneReplanCount + 1,
            proseAttempt: attempt,
            phase: SceneReviewPhase.finalCouncil,
            decision: finalReviewOutput.action,
            reason: _reviewAttemptReason(finalReviewOutput),
            timestamp: DateTime.now().millisecondsSinceEpoch,
            proseHash: await _digestText(polishOutput.prose.text),
            repairScheduled:
                finalReviewOutput.action != SceneReviewDecision.pass &&
                softFailureCount < maxProseRetries,
          ),
        );
        if (finalReviewOutput.action != SceneReviewDecision.pass) {
          softFailureCount += 1;
          if (softFailureCount <= maxProseRetries) {
            attempt += 1;
            reviewFeedback = _reviewRevisionFeedback(finalReviewOutput.review);
            previousProse = polishOutput.prose.text;
            _emitStatus(currentBrief, 'final review issue -> editorial retry');
            continue;
          }
          throw StateError(
            'Final council review did not pass after $softFailureCount prose retries.',
          );
        }

        // Extraction writes remain staged and are materialized by the
        // provider-free finalizer. The checkpoint deliberately contains only
        // a prose-bound manifest reference, never private memory payloads.
        await _recordEvidenceCheckpoint(
          ordinal: 10,
          brief: currentBrief,
          artifactType: 'proseDerivedManifestReference',
          payload: {
            'finalProseHash': await _digestText(polishOutput.prose.text),
            'namespace': 'pending-at-finalization',
            'writeKinds': const <String>['roleplaySession'],
          },
          stageAttempt: attempt,
        );

        // Step 10/11: score the exact prose reviewed above and enforce the
        // production gate before finalization. Provider/parse failures block.
        SceneQualityScore qualityScore;
        try {
          qualityScore = await _scoreAndRequireQuality(
            brief: currentBrief,
            director: planOutput.director,
            prose: polishOutput.prose,
            review: finalReviewOutput.review,
            qualityAttempt: qualityRepairCount + 1,
          );
        } on QualityGateFailure catch (failure) {
          final repairScheduled = qualityRepairCount < maxQualityRepairRetries;
          reviewAttempts.add(
            SceneReviewAttempt.snapshot(
              round: sceneReplanCount + 1,
              proseAttempt: attempt,
              phase: SceneReviewPhase.quality,
              decision: SceneReviewDecision.rewriteProse,
              reason: _qualityRepairFeedback(failure.score, currentBrief),
              failureCodes: _qualityFailureCodes(failure.score, currentBrief),
              timestamp: DateTime.now().millisecondsSinceEpoch,
              proseHash: await _digestText(polishOutput.prose.text),
              repairScheduled: repairScheduled,
            ),
          );
          if (!repairScheduled) rethrow;
          qualityRepairCount += 1;
          attempt += 1;
          previousProse = polishOutput.prose.text;
          reviewFeedback = _qualityRepairFeedback(failure.score, currentBrief);
          _emitStatus(
            currentBrief,
            'quality ${failure.score.overall.toStringAsFixed(0)} -> editorial repair '
            '$qualityRepairCount/$maxQualityRepairRetries',
          );
          _eventLog.emit(
            PipelineEvent(
              timestampMs: DateTime.now().millisecondsSinceEpoch,
              stageId: 'quality_gate',
              eventType: 'quality_repair_scheduled',
              metadata: {
                'sceneId': currentBrief.sceneId,
                'repairAttempt': qualityRepairCount,
                'maxRepairAttempts': maxQualityRepairRetries,
                'overall': failure.score.overall,
              },
            ),
          );
          continue;
        }
        reviewAttempts.add(
          SceneReviewAttempt.snapshot(
            round: sceneReplanCount + 1,
            proseAttempt: attempt,
            phase: SceneReviewPhase.quality,
            decision: SceneReviewDecision.pass,
            reason:
                'Quality gate passed: overall '
                '${qualityScore.overall.toStringAsFixed(1)} >= 95; '
                'all critical dimensions >= 90.',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            proseHash: await _digestText(polishOutput.prose.text),
          ),
        );
        await _recordEvidenceCheckpoint(
          ordinal: 11,
          brief: currentBrief,
          artifactType: 'qualityEvidence',
          input: {
            'finalProseHash': await _digestText(polishOutput.prose.text),
            'finalCouncilHash': await _digestReview(finalReviewOutput.review),
          },
          payload: {
            'finalProseHash': await _digestText(polishOutput.prose.text),
            'finalCouncilHash': await _digestReview(finalReviewOutput.review),
            'score': qualityScore.toJson(),
            'threshold': const {'overall': 95, 'critical': 90},
          },
          stageAttempt: attempt,
        );
        markSpeculationReady();

        // Step 12: provider-free finalization.
        final finalizationOutput = await _executeTypedStage(
          _finalizationStep,
          FinalizationInput(
            brief: currentBrief,
            plan: planOutput,
            roleplay: roleplayOutput,
            beats: beatsOutput,
            editorial: EditorialOutput(
              draft: editorialOutput.draft,
              prose: polishOutput.prose,
            ),
            polish: polishOutput,
            review: finalReviewOutput,
            context: contextOutput,
            attempt: attempt,
            softFailureCount: softFailureCount,
            narrativeArcBeforeScene: narrativeArcBeforeScene,
          ),
          context.withMetadata({
            'qualityScore': qualityScore,
            'reviewAttempts': List<SceneReviewAttempt>.unmodifiable(
              reviewAttempts,
            ),
          }),
          currentBrief,
          persistCheckpoint: !deferFinalizationCheckpointToCandidateLedger,
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
    SceneBrief brief, {
    int? checkpointOrdinal,
    int checkpointAttemptGroup = 1,
    bool persistCheckpoint = true,
  }) async {
    return _executeStageWithLifecycle(
      stage: stage,
      input: input,
      brief: brief,
      checkpointOrdinal: checkpointOrdinal,
      checkpointAttemptGroup: checkpointAttemptGroup,
      persistCheckpoint: persistCheckpoint,
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

  Future<SceneQualityScore> _scoreAndRequireQuality({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
    required int qualityAttempt,
  }) async {
    _throwIfCancelled('quality_gate');
    final restored = await _restoreQualityCheckpoint(
      brief: brief,
      prose: prose,
      review: review,
    );
    if (restored != null) return restored;
    BudgetReservationRequest? reservation;
    try {
      reservation = _reserveStageBudget(
        ordinal: 11,
        stageId: 'quality_gate',
        attempt: qualityAttempt,
      );
      final score = await _qualityScorer.score(
        brief: brief,
        director: director,
        prose: prose,
        review: review,
      );
      _throwIfCancelled('quality_gate');
      _settleStageBudget(reservation: reservation, consumed: true);
      final criticalScores = [
        score.prose,
        score.coherence,
        score.character,
        score.completeness,
      ];
      final requiresExtendedRubric =
          brief.formalExecution ||
          brief.metadata['requireExtendedQualityRubric'] == true;
      final extendedScores = [
        score.styleScore,
        score.imageryScore,
        score.rhythmScore,
        score.faithfulnessScore,
      ];
      final hasInvalidScore =
          score.warning != null ||
          score.summary.trim().isEmpty ||
          (requiresExtendedRubric && !score.hasExtendedRubric) ||
          [
            score.overall,
            ...criticalScores,
            if (score.hasExtendedRubric) ...extendedScores,
          ].any((value) => !value.isFinite || value < 0 || value > 100);
      final passes =
          !hasInvalidScore &&
          score.overall >= 95 &&
          criticalScores.every((value) => value >= 90) &&
          (!score.hasExtendedRubric ||
              extendedScores.every((value) => value >= 90));
      if (!passes) {
        throw QualityGateFailure(score);
      }
      _eventLog.emit(
        PipelineEvent(
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          stageId: 'quality_gate',
          eventType: 'quality_passed',
          metadata: {
            'sceneId': brief.sceneId,
            'overall': score.overall,
            'prose': score.prose,
            'coherence': score.coherence,
            'character': score.character,
            'completeness': score.completeness,
            if (score.hasExtendedRubric) ...{
              'style': score.styleScore,
              'imagery': score.imageryScore,
              'rhythm': score.rhythmScore,
              'faithfulness': score.faithfulnessScore,
            },
          },
        ),
      );
      return score;
    } on PipelineRunCancelled {
      _settleStageBudget(reservation: reservation, consumed: false);
      rethrow;
    } on QualityGateFailure catch (failure) {
      _eventLog.emit(
        PipelineEvent(
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          stageId: 'quality_gate',
          eventType: 'quality_blocked',
          failureCode: FailureCode.qualityFail,
          metadata: {
            'sceneId': brief.sceneId,
            'overall': failure.score.overall,
            'prose': failure.score.prose,
            'coherence': failure.score.coherence,
            'character': failure.score.character,
            'completeness': failure.score.completeness,
            if (failure.score.hasExtendedRubric) ...{
              'style': failure.score.styleScore,
              'imagery': failure.score.imageryScore,
              'rhythm': failure.score.rhythmScore,
              'faithfulness': failure.score.faithfulnessScore,
            },
          },
        ),
      );
      rethrow;
    } on Object catch (error) {
      _settleStageBudget(reservation: reservation, consumed: false);
      _eventLog.emit(
        PipelineEvent(
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          stageId: 'quality_gate',
          eventType: 'quality_blocked',
          failureCode: FailureCode.qualityFail,
          metadata: {'sceneId': brief.sceneId, 'error': error.toString()},
        ),
      );
      rethrow;
    }
  }

  String _qualityRepairFeedback(SceneQualityScore score, SceneBrief brief) {
    final names = brief.cast
        .map((member) => member.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .join('、');
    final nameGuard = names.isEmpty
        ? ''
        : '\n角色姓名硬约束：正文中的角色姓名必须逐字匹配以下规范名：$names；'
              '禁止同音字、近形字、错别字或临时改名。';
    final factGuard = score.faithfulnessScore < 90
        ? '\n事实回填硬约束：本次修订只能保留并落实以下本场事实，不得用新人物、'
              '新物件或新因果替换它们。场景概要：${brief.sceneSummary}；'
              '目标节拍：${brief.targetBeat}'
        : '';
    return '${QualityRepairPolicy.feedbackFor(score)}$nameGuard$factGuard';
  }

  List<String> _qualityFailureCodes(SceneQualityScore score, SceneBrief brief) {
    final codes = <String>[];
    final values = <String, double>{
      'prose': score.prose,
      'coherence': score.coherence,
      'character': score.character,
      'completeness': score.completeness,
      if (score.hasExtendedRubric) ...{
        'style': score.styleScore,
        'imagery': score.imageryScore,
        'rhythm': score.rhythmScore,
        'faithfulness': score.faithfulnessScore,
      },
    };
    if (score.overall.isFinite && score.overall < 95) {
      codes.add('quality.overall_below_95');
    }
    for (final entry in values.entries) {
      if (entry.value.isFinite && entry.value < 90) {
        codes.add('quality.${entry.key}_below_90');
      }
    }
    final requiresExtendedRubric =
        brief.formalExecution ||
        brief.metadata['requireExtendedQualityRubric'] == true;
    if (requiresExtendedRubric && !score.hasExtendedRubric) {
      codes.add('quality.extended_rubric_missing');
    }
    if (score.warning != null) {
      codes.add('quality.evidence_warning');
    }
    if (score.summary.trim().isEmpty) {
      codes.add('quality.summary_missing');
    }
    if ([
      score.overall,
      ...values.values,
    ].any((value) => !value.isFinite || value < 0 || value > 100)) {
      codes.add('quality.invalid_score');
    }
    if (codes.isEmpty) codes.add('quality.gate_failed');
    return codes;
  }

  String _storyMechanicsRepairFeedback(StoryMechanicsEvidence evidence) {
    final directives = <String>[
      if (evidence.failureCodes.contains('quality.repetition_loop'))
        '删除重复的句子、解释或相同意象；同一事实只保留一次，每段必须新增动作、信息、选择或压力。',
      if (evidence.failureCodes.contains('quality.expository_dialogue_density'))
        '把解释性对白改为可见动作、物件变化和对方反应，禁止连续用对白讲解结论。',
      if (evidence.failureCodes.contains('quality.unpowered_device_action'))
        '补出设备继续运行的明确机制（如备用电源或机械解锁），否则删除该动作。',
      if (evidence.failureCodes.contains('quality.unearned_power_inversion'))
        '补出权力转移的可见动作和代价，禁止人物无因突然反制或发号施令。',
    ];
    return '【确定性故事机制门禁修订】上一版不得进入候选。失败码：'
        '${evidence.failureCodes.join('、')}。\n'
        '${directives.join('\n')}\n'
        '只输出完整正文，保留已通过的事实、角色姓名和场景目标。';
  }

  Future<SceneQualityScore?> _restoreQualityCheckpoint({
    required SceneBrief brief,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async {
    final store = checkpointStore;
    final runId = checkpointRunId;
    if (store == null || runId == null || runId.isEmpty) return null;
    final input = {
      'finalProseHash': await _digestText(prose.text),
      'finalCouncilHash': await _digestReview(review),
    };
    final inputDigest = await _digestJson(input);
    final expectedUpstream = await _upstreamChainDigest(11);
    final provenance = await _checkpointProvenanceFor(brief);
    final candidates =
        (await store.load(runId: runId))
            .where(
              (checkpoint) =>
                  checkpoint.ordinal == 11 &&
                  checkpoint.stageId == 'quality_gate' &&
                  checkpoint.inputDigest == inputDigest,
            )
            .toList()
          ..sort((a, b) => b.stageAttempt.compareTo(a.stageAttempt));
    for (final checkpoint in candidates) {
      if (!await _checkpointCodec.validate(
        checkpoint: checkpoint,
        provenance: provenance,
        expectedUpstreamChainDigest: expectedUpstream,
      )) {
        continue;
      }
      final payload = checkpoint.artifactJson['payload'];
      if (payload is! Map ||
          payload['finalProseHash'] != input['finalProseHash'] ||
          payload['finalCouncilHash'] != input['finalCouncilHash'] ||
          payload['score'] is! Map) {
        continue;
      }
      final score = SceneQualityScore.fromJson(payload['score'] as Map);
      final critical = [
        score.prose,
        score.coherence,
        score.character,
        score.completeness,
      ];
      final requiresExtendedRubric =
          brief.formalExecution ||
          brief.metadata['requireExtendedQualityRubric'] == true;
      final extended = [
        score.styleScore,
        score.imageryScore,
        score.rhythmScore,
        score.faithfulnessScore,
      ];
      if (score.warning != null ||
          score.summary.trim().isEmpty ||
          (requiresExtendedRubric && !score.hasExtendedRubric) ||
          score.overall < 95 ||
          critical.any((value) => value < 90) ||
          (score.hasExtendedRubric && extended.any((value) => value < 90))) {
        continue;
      }
      _eventLog.emit(
        PipelineEvent(
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          stageId: 'quality_gate',
          eventType: 'stage_resumed',
          metadata: {'sceneId': brief.sceneId, 'ordinal': 11},
        ),
      );
      return score;
    }
    return null;
  }

  Future<O>
  _executeStageWithLifecycle<I extends TypedArtifact, O extends TypedArtifact>({
    required PipelineStage<I, O> stage,
    required I input,
    required SceneBrief brief,
    int? checkpointOrdinal,
    int checkpointAttemptGroup = 1,
    bool persistCheckpoint = true,
    required Future<O> Function() execute,
  }) async {
    _throwIfCancelled(stage.roleId);
    if (checkpointAttemptGroup <= 0) {
      throw ArgumentError.value(
        checkpointAttemptGroup,
        'checkpointAttemptGroup',
        'must be positive',
      );
    }
    final ordinal = checkpointOrdinal ?? _ordinalForStage(stage.roleId);
    final checkpointStageId = _checkpointStageId(ordinal, stage.roleId);
    final inputDigest = await _checkpointInputDigest(input);
    final restored = persistCheckpoint
        ? await _restoreCompatibleArtifact<O>(
            ordinal: ordinal,
            stageId: checkpointStageId,
            inputDigest: inputDigest,
            input: input,
            brief: brief,
          )
        : null;
    if (restored != null) {
      _emitStageLifecycle(
        stage: stage,
        brief: brief,
        eventType: 'stage_resumed',
        input: input,
        output: restored,
      );
      return restored;
    }
    if (persistCheckpoint) {
      await _discardIncompatibleCheckpoints(
        stage: stage,
        ordinal: ordinal,
        inputDigest: inputDigest,
        brief: brief,
      );
    }
    final maximumAttempts = stage.maxRetries + 1;
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= maximumAttempts; attempt++) {
      final checkpointAttempt =
          (checkpointAttemptGroup - 1) * maximumAttempts + attempt;
      _throwIfCancelled(stage.roleId);
      final startedAtMs = DateTime.now().millisecondsSinceEpoch;
      if (persistCheckpoint) {
        await _saveCheckpoint(
          PipelineStageCheckpoint(
            runId: checkpointRunId ?? '',
            proseRevision: checkpointProseRevision,
            ordinal: ordinal,
            stageId: checkpointStageId,
            stageAttempt: checkpointAttempt,
            schemaVersion: PipelineStageCheckpoint.currentSchemaVersion,
            inputDigest: inputDigest,
            artifactDigest: '',
            status: 'started',
            createdAtMs: startedAtMs,
            upstreamChainDigest: await _upstreamChainDigest(ordinal),
            provenance: await _checkpointProvenanceFor(brief),
          ),
        );
      }
      _emitStageLifecycle(
        stage: stage,
        brief: brief,
        eventType: 'stage_started',
        input: input,
      );
      BudgetReservationRequest? reservation;
      try {
        reservation = _reserveStageBudget(
          ordinal: ordinal,
          stageId: checkpointStageId,
          attempt: checkpointAttempt,
        );
        final output = await execute();
        _settleStageBudget(reservation: reservation, consumed: true);
        _throwIfCancelled(stage.roleId);
        final rawArtifactJson = output.toJson();
        final artifactJson = await _checkpointCodec.encode(
          ordinal: ordinal,
          stageId: checkpointStageId,
          artifactType: output.type.name,
          payload: rawArtifactJson,
        );
        final outputDigest = await _digestJson(artifactJson);
        if (persistCheckpoint) {
          await _saveCheckpoint(
            PipelineStageCheckpoint(
              runId: checkpointRunId ?? '',
              proseRevision: checkpointProseRevision,
              ordinal: ordinal,
              stageId: checkpointStageId,
              stageAttempt: checkpointAttempt,
              schemaVersion: PipelineStageCheckpoint.currentSchemaVersion,
              inputDigest: inputDigest,
              artifactDigest: outputDigest,
              status: 'completed',
              createdAtMs: startedAtMs,
              completedAtMs: DateTime.now().millisecondsSinceEpoch,
              artifactType: output.type.name,
              artifactJson: artifactJson,
              upstreamChainDigest: await _upstreamChainDigest(ordinal),
              provenance: await _checkpointProvenanceFor(brief),
            ),
          );
        }
        _emitStageLifecycle(
          stage: stage,
          brief: brief,
          eventType: 'stage_completed',
          input: input,
          output: output,
        );
        return output;
      } on PipelineRunCancelled {
        _settleStageBudget(reservation: reservation, consumed: false);
        _emitStageLifecycle(
          stage: stage,
          brief: brief,
          eventType: 'stage_cancelled',
          input: input,
          failureCode: FailureCode.blocked,
        );
        rethrow;
      } on Object catch (error, stackTrace) {
        _settleStageBudget(reservation: reservation, consumed: false);
        if (isRunCancelled?.call() == true) {
          _emitStageLifecycle(
            stage: stage,
            brief: brief,
            eventType: 'stage_cancelled',
            input: input,
            failureCode: FailureCode.blocked,
          );
          throw PipelineRunCancelled(stage.roleId);
        }
        lastError = error;
        lastStackTrace = stackTrace;
        final shouldRetry =
            attempt < maximumAttempts && _globalRetryCount < maxGlobalRetries;
        _emitStageLifecycle(
          stage: stage,
          brief: brief,
          eventType: shouldRetry ? 'stage_retry_scheduled' : 'stage_failed',
          input: input,
          failureCode: FailureCode.recoverable,
          error: error,
        );
        if (!shouldRetry) break;
        _globalRetryCount += 1;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  BudgetReservationRequest? _reserveStageBudget({
    required int ordinal,
    required String stageId,
    required int attempt,
  }) {
    final ledger = generationLedger;
    final runId = checkpointRunId;
    if (ledger == null ||
        runId == null ||
        runId.isEmpty ||
        !_providerOrdinal(ordinal)) {
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final request = BudgetReservationRequest(
      runId: runId,
      providerRequestId: '$runId:$ordinal:$stageId:$attempt',
      reservationId: '$runId:$ordinal:$stageId:$attempt',
      reservedCalls: 1,
      reservedTokens: 4000,
      reservedCostMicrousd: 100000,
      leaseOwner: 'pipeline-stage',
      leaseExpiresAtMs: now + 5 * 60 * 1000,
      createdAtMs: now,
    );
    ledger.reserveBudget(request);
    return request;
  }

  void _settleStageBudget({
    required BudgetReservationRequest? reservation,
    required bool consumed,
  }) {
    if (reservation == null) return;
    generationLedger!.settleBudget(
      runId: reservation.runId,
      providerRequestId: reservation.providerRequestId,
      actualCalls: consumed ? 1 : 0,
      actualTokens: consumed ? reservation.reservedTokens : 0,
      actualCostMicrousd: consumed ? reservation.reservedCostMicrousd : 0,
      settledAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool _providerOrdinal(int ordinal) =>
      const {1, 2, 3, 4, 5, 6, 7, 9, 11}.contains(ordinal);

  Future<O?> _restoreCompatibleArtifact<O extends TypedArtifact>({
    required int ordinal,
    required String stageId,
    required String inputDigest,
    required TypedArtifact input,
    required SceneBrief brief,
  }) async {
    final store = checkpointStore;
    final runId = checkpointRunId;
    final restorer = checkpointArtifactRestorer;
    if (store == null || runId == null || runId.isEmpty || restorer == null) {
      return null;
    }
    final provenance = await _checkpointProvenanceFor(brief);
    final upstream = await _upstreamChainDigest(ordinal);
    // Never restore a valid-looking suffix on its own. The only candidate is
    // selected once at run start from the latest continuous, provenance-bound
    // prefix; input validation remains stage-local because retries/replans may
    // have produced a new input after that selection.
    final checkpoint = _resumeChain[ordinal];
    if (checkpoint == null ||
        checkpoint.stageId != stageId ||
        checkpoint.inputDigest != inputDigest ||
        !await _checkpointCodec.validate(
          checkpoint: checkpoint,
          provenance: provenance,
          expectedUpstreamChainDigest: upstream,
        )) {
      return null;
    }
    final artifact = await restorer(checkpoint, input);
    if (artifact is O) return artifact;
    return null;
  }

  Future<Map<int, PipelineStageCheckpoint>> _prepareResumeChain(
    SceneBrief brief,
  ) async {
    final store = checkpointStore;
    final runId = checkpointRunId;
    if (store == null || runId == null || runId.isEmpty) return const {};
    final selection = await _checkpointCodec.selectLatestCompatible(
      checkpoints: (await store.load(runId: runId))
          .where(
            (checkpoint) => checkpoint.proseRevision == checkpointProseRevision,
          )
          .toList(),
      provenance: await _checkpointProvenanceFor(brief),
    );
    return {
      for (final checkpoint in selection.reusable)
        checkpoint.ordinal: checkpoint,
    };
  }

  /// Completed checkpoints have value only when they form a contiguous
  /// version-compatible chain and the current stage input hash matches. The
  /// current artifact serializers are deliberately not used as proof-bearing
  /// deserializers, so an entry that cannot be replayed is recomputed rather
  /// than silently trusting stale data.
  Future<void> _discardIncompatibleCheckpoints<
    I extends TypedArtifact,
    O extends TypedArtifact
  >({
    required PipelineStage<I, O> stage,
    required int ordinal,
    required String inputDigest,
    required SceneBrief brief,
  }) async {
    final store = checkpointStore;
    final runId = checkpointRunId;
    if (store == null || runId == null || runId.isEmpty) return;
    final checkpoints = await store.load(runId: runId);
    final own = checkpoints.where(
      (checkpoint) =>
          checkpoint.ordinal == ordinal &&
          checkpoint.stageId == _checkpointStageId(ordinal, stage.roleId),
    );
    if (own.isEmpty) return;
    final compatible = await _hasCompatibleCheckpointChain(
      checkpoints: checkpoints,
      targetOrdinal: ordinal,
      stageId: _checkpointStageId(ordinal, stage.roleId),
      inputDigest: inputDigest,
    );
    _eventLog.emit(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: stage.roleId,
        eventType: compatible
            ? 'checkpoint_replay_required'
            : 'checkpoint_discarded_incompatible',
        metadata: {
          'sceneId': brief.sceneId,
          'ordinal': ordinal,
          'checkpointCount': own.length,
        },
      ),
    );
  }

  Future<bool> _hasCompatibleCheckpointChain({
    required List<PipelineStageCheckpoint> checkpoints,
    required int targetOrdinal,
    required String stageId,
    required String inputDigest,
  }) async {
    final completedByOrdinal = <int, PipelineStageCheckpoint>{};
    for (final checkpoint in checkpoints) {
      if (!checkpoint.isCompleted ||
          checkpoint.schemaVersion !=
              PipelineStageCheckpoint.currentSchemaVersion ||
          checkpoint.artifactDigest.isEmpty ||
          checkpoint.artifactDigest !=
              await _digestJson(checkpoint.artifactJson)) {
        continue;
      }
      final existing = completedByOrdinal[checkpoint.ordinal];
      if (existing == null || checkpoint.stageAttempt > existing.stageAttempt) {
        completedByOrdinal[checkpoint.ordinal] = checkpoint;
      }
    }
    final own = completedByOrdinal[targetOrdinal];
    if (own == null ||
        own.stageId != stageId ||
        own.inputDigest != inputDigest) {
      return false;
    }
    for (final expectedOrdinal in _checkpointOrdinals) {
      if (expectedOrdinal >= targetOrdinal) break;
      if (!completedByOrdinal.containsKey(expectedOrdinal)) return false;
    }
    return true;
  }

  static const _checkpointOrdinals = <int>[
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
  ];

  Future<void> _saveCheckpoint(PipelineStageCheckpoint checkpoint) async {
    final store = checkpointStore;
    if (store == null || checkpoint.runId.isEmpty) return;
    _throwIfCancelled(checkpoint.stageId);
    await store.save(checkpoint);
  }

  void _throwIfCancelled(String stageId) {
    if (isRunCancelled?.call() == true) {
      throw PipelineRunCancelled(stageId);
    }
  }

  int _ordinalForStage(String stageId) => switch (stageId) {
    'context_enrichment' => 0,
    'director' => 1,
    'roleplay' => 2,
    'stage_narration' => 3,
    'beat_resolution' => 4,
    'editorial' => 5,
    'review' => 6,
    'polish' => 7,
    'finalization' => 12,
    _ => 99,
  };

  String _checkpointStageId(int ordinal, String fallback) =>
      GenerationStageOrdinals.ids[ordinal] ?? fallback;

  Future<GenerationCheckpointProvenance> _checkpointProvenanceFor(
    SceneBrief brief,
  ) async {
    final configured = checkpointProvenance;
    if (configured != null) return configured;
    // Test-only/no-ledger fallback remains deterministic and cannot be used by
    // the SQLite adapter as a real run provenance value.
    final input = await _digestJson({
      'projectId': brief.projectId,
      'chapterId': brief.chapterId,
      'sceneId': brief.sceneId,
    });
    return GenerationCheckpointProvenance(
      baseDraftDigest: input,
      materialDigest: input,
      promptDigest: input,
      modelDigest: input,
    );
  }

  Future<String> _upstreamChainDigest(int ordinal) async {
    final store = checkpointStore;
    final runId = checkpointRunId;
    if (store == null || runId == null || runId.isEmpty) {
      return _digestJson(const {'root': 'stage-checkpoint-v2'});
    }
    final latestByOrdinal = <int, PipelineStageCheckpoint>{};
    for (final checkpoint in await store.load(runId: runId)) {
      if (!checkpoint.isCompleted ||
          checkpoint.ordinal >= ordinal ||
          checkpoint.proseRevision != checkpointProseRevision ||
          !GenerationStageOrdinals.matches(
            checkpoint.ordinal,
            checkpoint.stageId,
          )) {
        continue;
      }
      final current = latestByOrdinal[checkpoint.ordinal];
      if (current == null || checkpoint.stageAttempt > current.stageAttempt) {
        latestByOrdinal[checkpoint.ordinal] = checkpoint;
      }
    }
    if (latestByOrdinal.length != ordinal ||
        List<int>.generate(
          ordinal,
          (index) => index,
        ).any((expected) => !latestByOrdinal.containsKey(expected))) {
      return _digestJson({'invalid': true, 'ordinal': ordinal});
    }
    final completed = [
      for (var index = 0; index < ordinal; index++) latestByOrdinal[index]!,
    ];
    return _digestJson({
      'root': 'stage-checkpoint-v2',
      'upstream': [
        for (final checkpoint in completed)
          {
            'ordinal': checkpoint.ordinal,
            'stageId': checkpoint.stageId,
            'artifactDigest': checkpoint.artifactDigest,
          },
      ],
    });
  }

  /// Checkpoint reuse must bind the semantic stage input, not merely the
  /// artifact type. Several lightweight `toJson` implementations intentionally
  /// omit private/runtime fields, which is correct for persistence but was too
  /// weak for cache identity: a replan could otherwise reuse an earlier plan
  /// in the same run. This map is hashed only; it is never written to SQLite.
  Future<String> _checkpointInputDigest(TypedArtifact input) =>
      _digestJson(_checkpointInputObject(input));

  Map<String, Object?> _checkpointInputObject(TypedArtifact input) {
    final brief = switch (input) {
      ContextEnrichmentInput(:final brief) => brief,
      ScenePlanningInput(:final brief) => brief,
      RoleplayInput(:final brief) => brief,
      BeatResolutionInput(:final brief) => brief,
      EditorialInput(:final brief) => brief,
      ReviewInput(:final brief) => brief,
      PolishInput(:final brief) => brief,
      FinalizationInput(:final brief) => brief,
      _ => null,
    };
    final result = <String, Object?>{
      'type': input.type.name,
      if (brief != null) 'brief': _checkpointBriefObject(brief),
    };
    switch (input) {
      case ScenePlanningInput(:final directorMemory, :final narrativeArc):
        result.addAll({
          'directorMemory': directorMemory.toPromptText(),
          'narrativeArc': narrativeArc.toPromptText(),
        });
      case RoleplayInput(:final plan):
        result['plan'] = plan.toJson();
      case StageNarrationInput(:final plan, :final roleplay):
        result.addAll({'plan': plan.toJson(), 'roleplay': roleplay.toJson()});
      case BeatResolutionInput(:final plan, :final roleplay, :final stage):
        result.addAll({
          'plan': plan.toJson(),
          'roleplay': roleplay.toJson(),
          'stage': stage.toJson(),
        });
      case EditorialInput(
        :final plan,
        :final beats,
        :final roleplay,
        :final stage,
        :final attempt,
        :final reviewFeedback,
        :final previousProse,
      ):
        result.addAll({
          'plan': plan.toJson(),
          'beats': beats.toJson(),
          'roleplay': roleplay.toJson(),
          'stage': stage.toJson(),
          'attempt': attempt,
          'reviewFeedback': reviewFeedback,
          'previousProse': previousProse,
        });
      case ReviewInput(
        :final plan,
        :final roleplay,
        :final editorial,
        :final context,
        :final attempt,
        :final softFailureCount,
      ):
        result.addAll({
          'plan': plan.toJson(),
          'roleplay': roleplay.toJson(),
          'editorial': editorial.toJson(),
          'context': context.toJson(),
          'attempt': attempt,
          'softFailureCount': softFailureCount,
        });
      case PolishInput(:final editorial, :final beats, :final review):
        result.addAll({
          'editorial': editorial.toJson(),
          'beats': beats.toJson(),
          'review': review.toJson(),
        });
      case FinalizationInput(
        :final plan,
        :final roleplay,
        :final beats,
        :final editorial,
        :final polish,
        :final review,
        :final attempt,
        :final softFailureCount,
      ):
        result.addAll({
          'plan': plan.toJson(),
          'roleplay': roleplay.toJson(),
          'beats': beats.toJson(),
          'editorial': editorial.toJson(),
          'polish': polish.toJson(),
          'review': review.toJson(),
          'attempt': attempt,
          'softFailureCount': softFailureCount,
        });
      case ContextEnrichmentInput():
        break;
    }
    return result;
  }

  Map<String, Object?> _checkpointBriefObject(SceneBrief brief) => {
    'projectId': brief.projectId,
    'chapterId': brief.chapterId,
    'sceneId': brief.sceneId,
    'sceneIndex': brief.sceneIndex,
    'totalScenesInChapter': brief.totalScenesInChapter,
    'sceneTitle': brief.sceneTitle,
    'sceneSummary': brief.sceneSummary,
    'targetLength': brief.targetLength,
    'targetBeat': brief.targetBeat,
    'worldNodeIds': brief.worldNodeIds,
    'castIds': [for (final member in brief.cast) member.characterId],
  };

  Future<String> _digestText(String value) => _digestJson({'text': value});

  Future<String> _digestReview(SceneReviewResult review) => _digestJson({
    'decision': review.decision.name,
    'feedback': review.feedback,
  });

  Future<void> _recordEvidenceCheckpoint({
    required int ordinal,
    required SceneBrief brief,
    required String artifactType,
    required Map<String, Object?> payload,
    Map<String, Object?>? input,
    int stageAttempt = 1,
  }) async {
    final store = checkpointStore;
    final runId = checkpointRunId;
    if (store == null || runId == null || runId.isEmpty) return;
    final stageId = GenerationStageOrdinals.ids[ordinal];
    if (stageId == null) {
      throw const GenerationLedgerInvariantViolation(
        'unknown evidence ordinal',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final artifact = await _checkpointCodec.encode(
      ordinal: ordinal,
      stageId: stageId,
      artifactType: artifactType,
      payload: payload,
    );
    await _saveCheckpoint(
      PipelineStageCheckpoint(
        runId: runId,
        proseRevision: checkpointProseRevision,
        ordinal: ordinal,
        stageId: stageId,
        stageAttempt: stageAttempt,
        schemaVersion: PipelineStageCheckpoint.currentSchemaVersion,
        inputDigest: await _digestJson(input ?? payload),
        artifactDigest: await _digestJson(artifact),
        upstreamChainDigest: await _upstreamChainDigest(ordinal),
        provenance: await _checkpointProvenanceFor(brief),
        status: 'completed',
        createdAtMs: now,
        completedAtMs: now,
        artifactType: artifactType,
        artifactJson: artifact,
      ),
    );
  }

  Future<Map<String, Object?>> _productionPreQualityCheckpointPayload({
    required ProductionPreQualityEvidence evidence,
    required String finalProse,
  }) async => <String, Object?>{
    'finalProseHash': await _digestText(finalProse),
    'passed': evidence.passed,
    'algorithm': 'deterministic-gate-v4',
    'boundaryReleaseHash': evidence.boundaryReleaseHash,
    'briefRequirementsHash': evidence.briefRequirementsHash,
    'productionPreQualityEvidence': evidence.toJson(),
    'polishCanonEvidence': evidence.polishCanonEvidence.toJson(),
    'storyMechanicsEvidence': evidence.storyMechanicsEvidence.toJson(),
  };

  Future<String> _digestJson(Map<String, Object?> value) async {
    final canonical = jsonEncode(_canonicalize(value));
    final hash = await Sha256().hash(utf8.encode(canonical));
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries =
          value.entries
              .map((entry) => MapEntry(entry.key.toString(), entry.value))
              .toList()
            ..sort((left, right) => left.key.compareTo(right.key));
      return {
        for (final entry in entries) entry.key: _canonicalize(entry.value),
      };
    }
    if (value is Iterable) {
      return [for (final item in value) _canonicalize(item)];
    }
    return value;
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

  PipelineEvent? _lastFailureEvent() {
    for (final event in _eventLog.query().reversed) {
      if (event.failureCode != null ||
          event.eventType == 'stage_failed' ||
          event.eventType == 'stage_cancelled' ||
          event.eventType.endsWith('_blocked')) {
        return event;
      }
    }
    return null;
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
    final feedback = _reviewRevisionFeedback(review).trim();
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

  String _reviewRevisionFeedback(SceneReviewResult review) {
    final guidance = (review.refinementGuidance ?? review.synthesizeGuidance())
        .toPromptText()
        .trim();
    if (guidance.isNotEmpty) {
      return '【本轮仅修复以下已验证缺口】\n$guidance';
    }
    return review.editorialFeedback.trim();
  }

  String _reviewAttemptReason(ReviewOutput output) {
    final feedback = output.review.feedback.trim();
    if (output.action == output.review.decision) {
      return feedback.isEmpty ? output.action.name : feedback;
    }
    final overrideReason = output.wasLengthRetry
        ? 'Mechanical prose gate requested an editorial rewrite.'
        : 'Post-review consistency gate requested a scene replan.';
    return feedback.isEmpty ? overrideReason : '$overrideReason\n$feedback';
  }

  bool _preliminaryRepairWillRun({
    required ReviewOutput reviewOutput,
    required int sceneReplanCount,
    required int softFailureCount,
  }) {
    if (reviewOutput.action == SceneReviewDecision.replanScene) {
      return !reviewOutput.wasLengthRetry &&
          sceneReplanCount < maxSceneReplanRetries;
    }
    if (reviewOutput.action == SceneReviewDecision.rewriteProse) {
      return softFailureCount < maxProseRetries;
    }
    return false;
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
