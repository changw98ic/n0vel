import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import '../domain/contracts/settings_contract.dart';

import 'character_consistency_verifier.dart';
import 'pipeline_event_log.dart';
import 'dynamic_role_agent_runner.dart';
import 'generation_pipeline_config.dart';
import 'generation_evidence_fingerprints.dart';
import 'generation_evidence_receipt.dart';
import 'scene_generation_identity.dart';
import 'scene_brief_snapshot.dart';
import 'story_generation_pass_retry.dart';
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
import 'generation_ledger_digest.dart';
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

/// A formal comparison sealed its first candidate and therefore refused a
/// review-, gate-, or exception-driven second content sample.
class ContentRedrawBlocked extends StateError {
  ContentRedrawBlocked({required this.stageId, required this.reason})
    : super('content redraw disabled at $stageId: $reason');

  final String stageId;
  final String reason;
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

/// Immutable scene input constructed once by the runner before a generation
/// run is admitted.  Ledger capture, write-ahead intents, fingerprints and
/// provider execution must all use this exact value; rebuilding a superficially
/// similar [SceneBrief] in an outer store makes the evidence chain ambiguous.
final class PreparedSceneBrief {
  const PreparedSceneBrief._({
    required this.brief,
    required this.digest,
    this.materials,
  });

  final SceneBrief brief;
  final String digest;
  final ProjectMaterialSnapshot? materials;
}

final Expando<_PipelineFinalizationAdmission> _pipelineFinalizationAdmissions =
    Expando<_PipelineFinalizationAdmission>('pipeline-finalization-admission');

/// Runtime-only, burn-first admission for the exact output object returned by
/// a sealed production runner.
///
/// There is intentionally no public getter or constructible capability. The
/// candidate finalizer may only consume the admission while presenting every
/// independently captured durable identity. A value-equal reconstructed
/// [SceneRuntimeOutput] has a different identity and is rejected.
bool consumePipelineFinalizationAdmission({
  required SceneRuntimeOutput output,
  required String runId,
  required String sceneId,
  required String preparedBriefDigest,
  required String generationArmPolicy,
  required String generationBundleHash,
  required String receiptCanonicalJson,
  required String receiptHash,
  required String finalProseHash,
  required String materialDigest,
  required String inputDigest,
  required String pendingWriteSourceDigest,
}) {
  final admission = _pipelineFinalizationAdmissions[output];
  // Burn before comparing. A mismatched presentation must not become a
  // reusable oracle for discovering a valid ledger binding.
  _pipelineFinalizationAdmissions[output] = null;
  if (admission == null) return false;
  return admission.runId == runId &&
      admission.sceneId == sceneId &&
      admission.preparedBriefDigest == preparedBriefDigest &&
      admission.generationArmPolicy == generationArmPolicy &&
      admission.generationBundleHash == generationBundleHash &&
      admission.receiptCanonicalJson == receiptCanonicalJson &&
      admission.receiptHash == receiptHash &&
      admission.finalProseHash == finalProseHash &&
      admission.materialDigest == materialDigest &&
      admission.inputDigest == inputDigest &&
      admission.pendingWriteSourceDigest == pendingWriteSourceDigest &&
      admission.outputBindingHash == _pipelineOutputBindingHash(output) &&
      finalProseHash == GenerationLedgerDigest.text(output.prose.text) &&
      pendingWriteSourceDigest == pipelinePendingWriteSourceDigest(output);
}

/// Canonical source identity for every pending write derived from a pipeline
/// output. This helper grants no authority; it only keeps runner and ledger
/// finalizer on one domain-separated digest contract.
String pipelinePendingWriteSourceDigest(SceneRuntimeOutput output) =>
    AppLlmCanonicalHash.domainHash(
      'pipeline-pending-write-source-v1',
      <String, Object?>{
        'projectId': output.brief.projectId,
        'chapterId': output.brief.chapterId,
        'sceneId': output.brief.sceneId,
        'finalProseHash': GenerationLedgerDigest.text(output.prose.text),
        'finalProseUtf8': ArtifactDigest.fromUtf8String(
          output.prose.text,
        ).toCanonicalMap(),
        'roleplaySession': _roleplayPendingSource(output.roleplaySession),
      },
    );

@pragma('vm:isolate-unsendable')
final class _PipelineFinalizationAdmission {
  const _PipelineFinalizationAdmission({
    required this.runId,
    required this.sceneId,
    required this.preparedBriefDigest,
    required this.generationArmPolicy,
    required this.generationBundleHash,
    required this.receiptCanonicalJson,
    required this.receiptHash,
    required this.finalProseHash,
    required this.materialDigest,
    required this.inputDigest,
    required this.pendingWriteSourceDigest,
    required this.outputBindingHash,
  });

  final String runId;
  final String sceneId;
  final String preparedBriefDigest;
  final String generationArmPolicy;
  final String generationBundleHash;
  final String receiptCanonicalJson;
  final String receiptHash;
  final String finalProseHash;
  final String materialDigest;
  final String inputDigest;
  final String pendingWriteSourceDigest;
  final String outputBindingHash;
}

/// One-shot typed bridge from live parser-bound DTO provenance into the
/// durable generation receipt. Only the sealed runner library can construct
/// it; receipt code may consume it but cannot synthesize a manifest map.
@pragma('vm:isolate-unsendable')
final class PipelineFinalEvaluationManifestAuthority {
  PipelineFinalEvaluationManifestAuthority._({
    required this.runId,
    required this.sceneId,
    required this.preparedBriefDigest,
    required this.generationArmPolicy,
    required this.generationBundleHash,
    required this.finalArtifactDigest,
    required Map<String, Object?> manifest,
  }) : _manifest = Map<String, Object?>.unmodifiable(manifest);

  final String runId;
  final String sceneId;
  final String preparedBriefDigest;
  final String generationArmPolicy;
  final String generationBundleHash;
  final ArtifactDigest finalArtifactDigest;
  final Map<String, Object?> _manifest;
  bool _consumed = false;

  /// Burns before matching and returns immutable canonical manifest input only
  /// to the receipt construction boundary.
  Map<String, Object?>? consumeForReceipt({
    required String runId,
    required String sceneId,
    required String preparedBriefDigest,
    required String generationArmPolicy,
    required String generationBundleHash,
    required ArtifactDigest finalArtifactDigest,
  }) {
    if (_consumed) return null;
    _consumed = true;
    if (this.runId != runId ||
        this.sceneId != sceneId ||
        this.preparedBriefDigest != preparedBriefDigest ||
        this.generationArmPolicy != generationArmPolicy ||
        this.generationBundleHash != generationBundleHash ||
        !_samePipelineArtifact(finalArtifactDigest, this.finalArtifactDigest)) {
      return null;
    }
    return Map<String, Object?>.unmodifiable(_manifest);
  }
}

bool _samePipelineArtifact(ArtifactDigest left, ArtifactDigest right) =>
    left.digest == right.digest && left.byteLength == right.byteLength;

bool _pipelineArtifactMapMatches(
  Map<String, Object?> candidate,
  ArtifactDigest expected,
) =>
    candidate['digest'] == expected.digest &&
    candidate['byteLength'] == expected.byteLength;

final class _SealedMaterialBinding {
  const _SealedMaterialBinding({
    required this.materialDigest,
    required this.inputDigest,
  });

  final String materialDigest;
  final String inputDigest;
}

final class _FinalEvaluationManifestBinding {
  const _FinalEvaluationManifestBinding({
    required this.authority,
    required this.generationBundleHash,
    required this.reviewParsedOutputDigest,
    required this.qualityParsedOutputDigest,
  });

  final PipelineFinalEvaluationManifestAuthority authority;
  final String generationBundleHash;
  final String reviewParsedOutputDigest;
  final String qualityParsedOutputDigest;
}

String _pipelineOutputBindingHash(SceneRuntimeOutput output) =>
    AppLlmCanonicalHash.domainHash(
      'pipeline-finalization-output-binding-v1',
      <String, Object?>{
        'briefDigest': SceneGenerationIdentity.briefHash(output.brief),
        'prose': ArtifactDigest.fromUtf8String(
          output.prose.text,
        ).toCanonicalMap(),
        'review': canonicalSceneReviewEvaluationOutput(output.review),
        'qualityScore': output.qualityScore?.toJson(),
        'reviewAttempts': <Object?>[
          for (final attempt in output.reviewAttempts) attempt.toJson(),
        ],
        'preQuality': output.productionPreQualityEvidence,
        'polishCanon': output.polishCanonEvidence?.toJson(),
        'storyMechanics': output.storyMechanicsEvidence?.toJson(),
        'pendingWriteSourceDigest': pipelinePendingWriteSourceDigest(output),
        'receiptHash': output.generationEvidenceReceipt?.receiptHash,
        'receiptCanonicalJson': output.generationEvidenceReceipt?.canonicalJson,
      },
    );

Object? _roleplayPendingSource(Object? rawSession) {
  if (rawSession == null) return null;
  final session = rawSession as dynamic;
  return <String, Object?>{
    'chapterId': session.chapterId,
    'sceneId': session.sceneId,
    'sceneTitle': session.sceneTitle,
    'finalPublicState': session.finalPublicState,
    'rounds': <Object?>[
      for (final round in session.rounds)
        <String, Object?>{
          'round': round.round,
          'turns': <Object?>[
            for (final turn in round.turns)
              <String, Object?>{
                'characterId': turn.characterId,
                'name': turn.name,
                'intent': turn.intent,
                'visibleAction': turn.visibleAction,
                'dialogue': turn.dialogue,
                'innerState': turn.innerState,
                'proseFragment': turn.proseFragment,
                'taboo': turn.taboo,
                'rawText': turn.rawText,
                'skillId': turn.skillId,
                'skillVersion': turn.skillVersion,
                'proposedMemoryDeltas': <Object?>[
                  for (final delta in turn.proposedMemoryDeltas) delta.toJson(),
                ],
              },
          ],
          'arbitration': <String, Object?>{
            'fact': round.arbitration.fact,
            'state': round.arbitration.state,
            'pressure': round.arbitration.pressure,
            'nextPublicState': round.arbitration.nextPublicState,
            'shouldStop': round.arbitration.shouldStop,
            'rawText': round.arbitration.rawText,
            'skillId': round.arbitration.skillId,
            'skillVersion': round.arbitration.skillVersion,
            'acceptedMemoryDeltas': <Object?>[
              for (final delta in round.arbitration.acceptedMemoryDeltas)
                delta.toJson(),
            ],
            'rejectedMemoryDeltas': <Object?>[
              for (final delta in round.arbitration.rejectedMemoryDeltas)
                delta.toJson(),
            ],
          },
        },
    ],
    'committedFacts': <Object?>[
      for (final fact in session.committedFacts)
        <String, Object?>{
          'sequenceId': fact.sequenceId,
          'round': fact.round,
          'source': fact.source,
          'content': fact.content,
          'previousHash': fact.previousHash,
          'contentHash': fact.contentHash,
        },
    ],
  };
}

Map<String, Object?>? _finalEvaluationManifestCall({
  required StoryGenerationFormalOutcomeProvenance outcome,
  required String parsedOutputDigest,
  required Map<String, int> sequenceByLogicalAttemptId,
}) {
  final sequenceNo = sequenceByLogicalAttemptId[outcome.logicalAttemptId];
  if (sequenceNo == null) return null;
  return <String, Object?>{
    'sequenceNo': sequenceNo,
    'phase': outcome.evaluationPhase.name,
    'stageId': outcome.stageId,
    'callSiteId': outcome.callSiteId,
    'logicalAttemptId': outcome.logicalAttemptId,
    'providerOutcomeSealHash': outcome.providerOutcomeSealHash,
    'providerArtifactDigest': outcome.providerArtifactDigest.toCanonicalMap(),
    'promptReleaseContentHash': outcome.promptReleaseContentHash,
    'parserRelease': outcome.parserRelease,
    'evaluationFingerprintDigest': outcome.evaluationFingerprintDigest,
    'parsedOutputDigest': parsedOutputDigest,
  };
}

class PipelineStageRunnerImpl
    implements ChapterGenerationService, PipelineStageRunner {
  /// Constructs the only dependency graph eligible to mint a sealed
  /// finalization admission. Output-affecting services are intentionally not
  /// injectable here; the ordinary constructor remains available for
  /// adaptive production and focused tests but can issue receipts only.
  factory PipelineStageRunnerImpl.sealedProduction({
    required StoryGenerationSettingsContract settingsStore,
    required GenerationPipelineConfig pipelineConfig,
    PipelineEventLog? eventLog,
    StoryMemoryStorage? memoryStorage,
    RoleplaySessionStore? roleplaySessionStore,
    CharacterMemoryStore? characterMemoryStore,
    HybridRetriever? hybridRetriever,
    StoryContextCache? contextCache,
  }) {
    final runner = PipelineStageRunnerImpl(
      settingsStore: settingsStore,
      pipelineConfig: pipelineConfig,
      eventLog: eventLog,
      memoryStorage: memoryStorage,
      roleplaySessionStore: roleplaySessionStore,
      characterMemoryStore: characterMemoryStore,
      hybridRetriever: hybridRetriever,
      contextCache: contextCache,
      promptRegistry: StoryPromptRegistry.production,
    );
    runner._sealedProductionEligible = true;
    return runner;
  }

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
    final sharedEventLog =
        eventLog ?? PipelineEvidenceLogScope.current ?? PipelineEventLogImpl();
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
        materialReferenceRetriever: _materialReferenceRetrieverFrom(
          pipelineConfig.styleReferenceConfig,
        ),
        enableWritingReference: _writingReferenceRetrievalEnabled(
          pipelineConfig,
        ),
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
        materialReferenceRetriever: _materialReferenceRetrieverFrom(
          pipelineConfig.styleReferenceConfig,
        ),
        enableWritingReference: _writingReferenceRetrievalEnabled(
          pipelineConfig,
        ),
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
  bool get _contentRedrawAllowed => _pipelineConfig.contentRedrawAllowed;
  StyleReferenceConfig get styleReferenceConfig =>
      _pipelineConfig.styleReferenceConfig;

  _SealedMaterialBinding? _sealedMaterialBinding({
    required SceneRuntimeOutput output,
    required String runId,
  }) {
    final ledger = generationLedger;
    final configuredRunId = checkpointRunId?.trim();
    final projectId = output.brief.projectId?.trim();
    if (!_sealedProductionEligible ||
        ledger == null ||
        configuredRunId == null ||
        configuredRunId != runId ||
        projectId == null ||
        projectId.isEmpty) {
      return null;
    }
    final rows = ledger.db.select(
      '''SELECT project_id, scene_id, material_digest, manifest_json
         FROM story_generation_material_manifests
         WHERE run_id = ?''',
      <Object?>[runId],
    );
    if (rows.length != 1) return null;
    final row = rows.single;
    final materialDigest = row['material_digest'];
    final manifestJson = row['manifest_json'];
    if (row['project_id'] != projectId ||
        row['scene_id'] != output.brief.sceneId ||
        materialDigest is! String ||
        manifestJson is! String ||
        !RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(materialDigest) ||
        GenerationLedgerDigest.text(manifestJson) != materialDigest) {
      return null;
    }
    return _SealedMaterialBinding(
      materialDigest: materialDigest,
      inputDigest: GenerationLedgerDigest.object(<String, Object?>{
        'brief': SceneGenerationIdentity.briefObject(output.brief),
        'materialDigest': materialDigest,
      }),
    );
  }

  _FinalEvaluationManifestBinding? _takeFinalEvaluationManifestBinding({
    required SceneRuntimeOutput output,
    required String runId,
    required String preparedBriefDigest,
    required ArtifactDigest finalArtifactDigest,
    required List<VerifiedStoryGenerationAttemptAdmission> admissions,
  }) {
    final qualityScore = output.qualityScore;
    if (!_sealedProductionEligible || qualityScore == null) return null;

    final reviewProvenance = consumeVerifiedSceneReviewProvenance(
      result: output.review,
      phase: StoryGenerationEvaluationPhase.finalCouncil,
      artifactDigest: finalArtifactDigest,
    );
    // Both DTO capabilities are burn-first. Even when the review token is
    // absent, consume the exact quality identity so a failed presentation
    // cannot leave a reusable authority behind.
    final qualityProvenance = consumeVerifiedSceneQualityProvenance(
      score: qualityScore,
      phase: StoryGenerationEvaluationPhase.quality,
      artifactDigest: finalArtifactDigest,
    );
    if (reviewProvenance == null || qualityProvenance == null) return null;

    final sequenceByLogicalAttemptId = <String, int>{};
    final generationBundleHashes = <String>{};
    for (final admission in admissions) {
      final logicalAttemptId = admission.intent.logicalAttemptId;
      if (sequenceByLogicalAttemptId.putIfAbsent(
            logicalAttemptId,
            () => admission.sequenceNo,
          ) !=
          admission.sequenceNo) {
        return null;
      }
      generationBundleHashes.add(admission.intent.generationBundleHash);
    }
    if (generationBundleHashes.length != 1) return null;
    final generationBundleHash = generationBundleHashes.single;

    final calls = <Map<String, Object?>>[];
    for (final pass in reviewProvenance.orderedPasses) {
      final call = _finalEvaluationManifestCall(
        outcome: pass.outcome,
        parsedOutputDigest: pass.parsedOutputDigest,
        sequenceByLogicalAttemptId: sequenceByLogicalAttemptId,
      );
      if (call == null) return null;
      calls.add(call);
    }
    final qualityCall = _finalEvaluationManifestCall(
      outcome: qualityProvenance.outcome,
      parsedOutputDigest: qualityProvenance.parsedOutputDigest,
      sequenceByLogicalAttemptId: sequenceByLogicalAttemptId,
    );
    if (qualityCall == null) return null;
    calls.add(qualityCall);

    var previousSequenceNo = -1;
    for (final call in calls) {
      final sequenceNo = call['sequenceNo']! as int;
      if (sequenceNo <= previousSequenceNo) return null;
      previousSequenceNo = sequenceNo;
    }

    final manifest = <String, Object?>{
      'schemaVersion': 'pipeline-final-evaluation-manifest-v1',
      'finalArtifactDigest': finalArtifactDigest.toCanonicalMap(),
      'reviewParsedOutputDigest': reviewProvenance.parsedOutputDigest,
      'qualityParsedOutputDigest': qualityProvenance.parsedOutputDigest,
      'orderedCalls': <Object?>[...calls],
    };
    return _FinalEvaluationManifestBinding(
      authority: PipelineFinalEvaluationManifestAuthority._(
        runId: runId,
        sceneId: output.brief.sceneId,
        preparedBriefDigest: preparedBriefDigest,
        generationArmPolicy: _pipelineConfig.generationArmPolicy,
        generationBundleHash: generationBundleHash,
        finalArtifactDigest: finalArtifactDigest,
        manifest: manifest,
      ),
      generationBundleHash: generationBundleHash,
      reviewParsedOutputDigest: reviewProvenance.parsedOutputDigest,
      qualityParsedOutputDigest: qualityProvenance.parsedOutputDigest,
    );
  }

  Future<R> _runWithRetryPolicy<R>({
    required Future<R> Function() body,
    required String sceneId,
    required String? preparedBriefDigest,
    required bool Function(R value) runCompleted,
    required String? Function(R value) finalArtifactText,
    R Function(R value, GenerationEvidenceReceipt receipt)?
    attachVerifiedEvidenceReceipt,
    R Function(R value, List<PipelineEvent> events)? refreshResultEvents,
  }) async {
    if (_contentRedrawAllowed) {
      return body();
    }
    final evidenceLog = _eventLog;
    if (evidenceLog is! PipelineEventLogImpl ||
        !evidenceLog.canPersistAndRetrieveEvidence ||
        evidenceLog.evidenceLocator == null) {
      throw StateError(
        'no-redraw pipeline requires a persistent, retrievable evidence sink',
      );
    }
    final evidenceRunId = _pipelineConfig.evidenceRunId?.trim();
    if (evidenceRunId == null || evidenceRunId.isEmpty) {
      throw StoryGenerationEvidencePreflightFailure(
        'no-redraw pipeline requires a stable caller-owned evidenceRunId',
      );
    }
    final normalizedPreparedBriefDigest = preparedBriefDigest?.trim();
    if (normalizedPreparedBriefDigest == null ||
        !RegExp(
          r'^sha256:[0-9a-f]{64}$',
        ).hasMatch(normalizedPreparedBriefDigest)) {
      throw StoryGenerationEvidencePreflightFailure(
        'no-redraw pipeline requires a prepared SceneBrief digest',
      );
    }
    final capture = StoryGenerationAttemptEvidenceCapture();
    final evidenceJournal = await evidenceLog
        .openStoryGenerationEvidenceJournal(
          evidenceRunId: evidenceRunId,
          sceneId: sceneId,
          preparedBriefDigest: normalizedPreparedBriefDigest,
          generationArmPolicy: _pipelineConfig.generationArmPolicy,
        );

    var completed = false;
    ArtifactDigest? finalDigest;
    late R value;
    Object? bodyError;
    StackTrace? bodyStackTrace;
    try {
      value = await StoryGenerationRetryScope.run<Future<R>>(
        policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
          maxTotalAttempts: 3,
          maxNoProviderCompletionRetries: 2,
        ),
        onAttemptEvidence: capture.record,
        persistAttemptEvidence: evidenceJournal.persistAttempt,
        persistAttemptIntent: evidenceJournal.persistIntent,
        sealArtifactEvidence: evidenceJournal.sealArtifact,
        generationArmPolicy: _pipelineConfig.generationArmPolicy,
        evidenceRunId: evidenceRunId,
        evidenceSceneId: sceneId,
        preparedBriefDigest: normalizedPreparedBriefDigest,
        body: body,
      );
      completed = runCompleted(value);
      final prose = finalArtifactText(value);
      if (prose != null) {
        finalDigest = ArtifactDigest.fromUtf8String(prose);
      }
    } on Object catch (error, stackTrace) {
      bodyError = error;
      bodyStackTrace = stackTrace;
    }

    final envelope = capture.toEnvelope();
    late final bool evidenceComplete;
    try {
      evidenceComplete = await evidenceJournal.persistAndVerifyEnvelope(
        envelope: envelope,
        completed: completed,
        finalArtifactDigest: finalDigest,
      );
    } on Object {
      // The envelope pass still owns journal invalidation, but an error it
      // derives from the already-failed body (for example, the resulting
      // unclosed write-ahead intent) must not replace the first failure or its
      // stack. With no body failure, preserve the envelope error unchanged.
      if (bodyError != null) {
        Error.throwWithStackTrace(bodyError, bodyStackTrace!);
      }
      rethrow;
    }

    if (bodyError != null) {
      Error.throwWithStackTrace(bodyError, bodyStackTrace!);
    }
    if (completed && !evidenceComplete) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'no-redraw result cannot leave the pipeline with incomplete attempt, '
        'artifact-seal, or envelope evidence',
      );
    }
    if (completed && evidenceComplete && finalDigest != null) {
      final verifiedAdmissions =
          evidenceJournal.verifiedAdmissionOrderedAdmissions;
      _FinalEvaluationManifestBinding? finalEvaluationBinding;
      _SealedMaterialBinding? sealedMaterialBinding;
      if (_sealedProductionEligible && value is SceneRuntimeOutput) {
        finalEvaluationBinding = _takeFinalEvaluationManifestBinding(
          output: value,
          runId: evidenceRunId,
          preparedBriefDigest: normalizedPreparedBriefDigest,
          finalArtifactDigest: finalDigest,
          admissions: verifiedAdmissions,
        );
        sealedMaterialBinding = _sealedMaterialBinding(
          output: value,
          runId: evidenceRunId,
        );
        if (finalEvaluationBinding == null || sealedMaterialBinding == null) {
          throw StoryGenerationEvidenceIntegrityFailure(
            'sealed production result requires live final-council and quality '
            'parser provenance plus one frozen material/input binding',
          );
        }
      }
      final receipt = GenerationEvidenceReceipt.fromVerified(
        authority: evidenceJournal.issueReceiptAuthority(
          sealedArtifactDigest: finalDigest,
        ),
        evidenceRunId: evidenceRunId,
        sceneId: sceneId,
        generationArmPolicy: _pipelineConfig.generationArmPolicy,
        preparedBriefDigest: normalizedPreparedBriefDigest,
        intents: verifiedAdmissions.map(
          (admission) => GenerationEvidenceReceiptIntent(
            admissionSequenceNo: admission.sequenceNo,
            intent: admission.intent,
          ),
        ),
        envelope: envelope,
        sealedArtifactDigest: finalDigest,
        finalEvaluationManifestAuthority: finalEvaluationBinding?.authority,
      );
      final reparsedReceipt = GenerationEvidenceReceipt.fromCanonicalJson(
        receipt.canonicalJson,
      );
      if (reparsedReceipt.receiptHash != receipt.receiptHash ||
          reparsedReceipt.evidenceRunId != evidenceRunId ||
          reparsedReceipt.sceneId != sceneId ||
          !_pipelineArtifactMapMatches(
            reparsedReceipt.sealedArtifactDigest,
            finalDigest,
          )) {
        throw StoryGenerationEvidenceIntegrityFailure(
          'terminal receipt failed canonical reparse reconciliation',
        );
      }
      final attach = attachVerifiedEvidenceReceipt;
      if (attach != null) {
        value = attach(value, receipt);
      }
      if (_sealedProductionEligible && value is SceneRuntimeOutput) {
        final binding = finalEvaluationBinding;
        final materialBinding = sealedMaterialBinding;
        final qualityScore = value.qualityScore;
        if (binding == null ||
            materialBinding == null ||
            qualityScore == null ||
            !identical(value.generationEvidenceReceipt, receipt) ||
            reparsedReceipt.finalEvaluationManifest == null ||
            reparsedReceipt.finalReviewParsedOutputDigest !=
                binding.reviewParsedOutputDigest ||
            reparsedReceipt.finalQualityParsedOutputDigest !=
                binding.qualityParsedOutputDigest ||
            binding.reviewParsedOutputDigest !=
                storyGenerationParsedOutputDigest(
                  canonicalSceneReviewEvaluationOutput(value.review),
                ) ||
            binding.qualityParsedOutputDigest !=
                storyGenerationParsedOutputDigest(qualityScore.toJson())) {
          throw StoryGenerationEvidenceIntegrityFailure(
            'sealed receipt does not reconcile with the exact live review '
            'and quality parser outputs',
          );
        }
        final pendingWriteSourceDigest = pipelinePendingWriteSourceDigest(
          value,
        );
        _pipelineFinalizationAdmissions[value] = _PipelineFinalizationAdmission(
          runId: evidenceRunId,
          sceneId: sceneId,
          preparedBriefDigest: normalizedPreparedBriefDigest,
          generationArmPolicy: _pipelineConfig.generationArmPolicy,
          generationBundleHash: binding.generationBundleHash,
          receiptCanonicalJson: receipt.canonicalJson,
          receiptHash: receipt.receiptHash,
          finalProseHash: GenerationLedgerDigest.text(value.prose.text),
          materialDigest: materialBinding.materialDigest,
          inputDigest: materialBinding.inputDigest,
          pendingWriteSourceDigest: pendingWriteSourceDigest,
          outputBindingHash: _pipelineOutputBindingHash(value),
        );
      }
    }
    final refresh = refreshResultEvents;
    if (refresh != null) {
      return refresh(
        value,
        List<PipelineEvent>.unmodifiable(_eventLog.query()),
      );
    }
    return value;
  }

  Never _blockContentRedraw({
    required SceneBrief brief,
    required String stageId,
    required String reason,
  }) {
    _eventLog.emit(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: stageId,
        eventType: 'content_redraw_blocked',
        metadata: {
          'sceneId': brief.sceneId,
          'reason': reason,
          'sceneContentRedrawPolicy':
              _pipelineConfig.sceneContentRedrawPolicy.name,
        },
      ),
    );
    throw ContentRedrawBlocked(stageId: stageId, reason: reason);
  }

  static bool _writingReferenceRetrievalEnabled(
    GenerationPipelineConfig config,
  ) {
    return config.enableWritingReference &&
        config.styleReferenceConfig.enabled &&
        config.styleReferenceConfig.allowWritingReferenceRetrieval &&
        config.styleReferenceConfig.rootPath.trim().isNotEmpty;
  }

  static MaterialReferenceRetriever? _materialReferenceRetrieverFrom(
    StyleReferenceConfig config,
  ) {
    if (!config.allowWritingReferenceRetrieval ||
        config.rootPath.trim().isEmpty) {
      return null;
    }
    final approvedBundle = config.approvedBundle;
    if (approvedBundle == null) return null;
    final excerptLimit = config.approvedBundle?.sources
        .map((source) => source.excerptLimitChars)
        .whereType<int>()
        .fold<int?>(
          null,
          (min, limit) => min == null || limit < min ? limit : min,
        );
    if (excerptLimit != null) {
      return MaterialReferenceRetriever(
        rootPath: config.rootPath,
        approvedBundle: approvedBundle,
        excerptCharLimit: excerptLimit,
      );
    }
    return MaterialReferenceRetriever(
      rootPath: config.rootPath,
      approvedBundle: approvedBundle,
    );
  }

  late final PipelineEventLog _eventLog;
  late final MemoryWritebackGate _writebackGate;
  late final StoryPromptRegistry _promptRegistry;
  late final SceneQualityScorerService _qualityScorer;
  late final ProductionPreQualityGate _preQualityGate;
  bool _sealedProductionEligible = false;

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
  Future<PipelineRunResult> run(SceneBriefRef brief, PipelineContext context) {
    final sourceBrief = context.metadata['sceneBrief'];
    final sourceMaterials = context.metadata['materials'];
    final prepared = sourceBrief is SceneBrief
        ? prepareSceneBrief(
            sourceBrief,
            materials: sourceMaterials is ProjectMaterialSnapshot
                ? sourceMaterials
                : null,
          )
        : null;
    return _runWithRetryPolicy<PipelineRunResult>(
      body: () => _promptRegistry.runAsync(
        () => _runPipeline(brief, context, prepared: prepared),
      ),
      sceneId: brief.sceneId,
      preparedBriefDigest: prepared?.digest,
      runCompleted: (value) => value.success,
      finalArtifactText: (value) {
        final artifact = value.finalArtifact;
        return artifact is FinalizationOutput
            ? artifact.output.prose.text
            : null;
      },
      refreshResultEvents: (value, events) => PipelineRunResult(
        success: value.success,
        events: events,
        finalArtifact: value.finalArtifact,
        failureCode: value.failureCode,
        failedStageId: value.failedStageId,
      ),
    );
  }

  Future<PipelineRunResult> _runPipeline(
    SceneBriefRef brief,
    PipelineContext context, {
    required PreparedSceneBrief? prepared,
  }) async {
    final sceneBrief = prepared?.brief ?? context.metadata['sceneBrief'];
    if (sceneBrief is SceneBrief) {
      try {
        final output = await StoryPromptTemplates.runWithLanguage(
          _settingsStore.promptLanguage,
          () => _runSceneFinalization(
            prepared?.brief ?? _briefWithStyleReference(sceneBrief),
            materials: prepared?.materials,
            context: _runnerContextFor(brief, context),
            providerFacingBriefPrepared: prepared != null,
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
        } else if (error is ContentRedrawBlocked) {
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
    return runPreparedScene(
      prepareSceneBrief(brief, materials: materials),
      onSpeculationReady: onSpeculationReady,
    );
  }

  /// The sole construction boundary for the provider-facing scene brief.
  /// Callers which also create a ledger capture must retain this object and
  /// pass it to [runPreparedScene], rather than independently deriving a hash.
  PreparedSceneBrief prepareSceneBrief(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
  }) {
    final styled = _briefWithStyleReference(brief);
    // Capture even an empty runner arc. A null arc would otherwise let a
    // later run mutate `_narrativeArc` between admission and provider dispatch.
    final providerFacing = styled.copyWith(
      narrativeArc: styled.narrativeArc ?? _narrativeArc,
    );
    final prepared = SceneBriefSnapshot.freeze(providerFacing);
    return PreparedSceneBrief._(
      brief: prepared,
      digest: SceneGenerationIdentity.briefHash(prepared),
      materials: materials == null
          ? null
          : SceneBriefSnapshot.freezeMaterials(materials),
    );
  }

  Future<SceneRuntimeOutput> runPreparedScene(
    PreparedSceneBrief prepared, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) {
    // Legacy callers may still supply materials at execution time. Snapshot
    // them synchronously before any await; prepared callers always win so a
    // second caller-owned object cannot replace the admitted material graph.
    final executionMaterials =
        prepared.materials ??
        (materials == null
            ? null
            : SceneBriefSnapshot.freezeMaterials(materials));
    Future<SceneRuntimeOutput> execute() => _promptRegistry.runAsync(
      () => StoryPromptTemplates.runWithLanguage(
        _settingsStore.promptLanguage,
        () => _runScene(
          prepared.brief,
          materials: executionMaterials,
          onSpeculationReady: onSpeculationReady,
          providerFacingBriefPrepared: true,
        ),
      ),
    );
    return _runWithRetryPolicy<SceneRuntimeOutput>(
      body: execute,
      sceneId: prepared.brief.sceneId,
      preparedBriefDigest: prepared.digest,
      runCompleted: (_) => true,
      finalArtifactText: (value) => value.prose.text,
      attachVerifiedEvidenceReceipt: (value, receipt) =>
          value.withGenerationEvidenceReceipt(receipt),
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
    if (!styleReferenceConfig.enabled) {
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
        if (styleReferenceConfig.approvedBundle != null)
          'styleReferenceBundleHash':
              styleReferenceConfig.approvedBundle!.identityHash,
        if (styleReferenceConfig.approvedBundle != null)
          'styleReferenceUsage':
              styleReferenceConfig.approvedBundle!.referenceUsage.name,
      },
    );
  }

  Future<SceneRuntimeOutput> _runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
    bool providerFacingBriefPrepared = false,
  }) async {
    _globalRetryCount = 0;
    _throwIfCancelled('run_start');
    _resumeChain = await _prepareResumeChain(brief);
    final finalization = await _runSceneFinalization(
      brief,
      materials: materials,
      onSpeculationReady: onSpeculationReady,
      context: _defaultContextFor(brief),
      providerFacingBriefPrepared: providerFacingBriefPrepared,
    );
    return finalization.output;
  }

  Future<FinalizationOutput> _runSceneFinalization(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
    required PipelineContext context,
    bool providerFacingBriefPrepared = false,
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
    if (!providerFacingBriefPrepared) {
      brief = _briefWithNarrativeArc(brief, narrativeArcBeforeScene);
    }
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
          narrativeArc: narrativeArcBeforeScene,
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
        final reviewOutput =
            await StoryGenerationEvaluationScope.run<Future<ReviewOutput>>(
              phase: StoryGenerationEvaluationPhase.preliminaryReview,
              artifactText: editorialOutput.prose.text,
              body: () => _executeTypedStage(
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
              ),
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

        if (!_contentRedrawAllowed &&
            reviewOutput.action == SceneReviewDecision.replanScene) {
          _blockContentRedraw(
            brief: currentBrief,
            stageId: 'planning',
            reason: 'preliminary review requested scene replan',
          );
        }

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
          if (!_contentRedrawAllowed) {
            _blockContentRedraw(
              brief: currentBrief,
              stageId: 'editorial',
              reason: 'preliminary review requested prose rewrite',
            );
          }
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
            'Preliminary review did not pass after $softFailureCount prose '
            'retries: ${_reviewAttemptReason(reviewOutput)}',
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
        if (!_contentRedrawAllowed) {
          final sealArtifact =
              StoryGenerationRetryScope.currentArtifactEvidenceSealer;
          if (sealArtifact == null) {
            throw StoryGenerationEvidencePreflightFailure(
              'no-redraw pipeline requires a durable candidate artifact seal',
            );
          }
          await sealArtifact(
            stageId: 'polish_candidate_before_gates',
            artifactText: rawPolishOutput.prose.text,
            sourceLogicalAttemptId:
                rawPolishOutput.sourceLogicalAttemptId ?? '',
            sourceCallSiteId: rawPolishOutput.sourceCallSiteId ?? '',
          );
        }
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
          final repairScheduled =
              _contentRedrawAllowed && softFailureCount < maxProseRetries;
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
          if (!_contentRedrawAllowed) {
            _blockContentRedraw(
              brief: currentBrief,
              stageId: 'deterministic_gate',
              reason: 'pre-quality hard gate requested prose repair',
            );
          }
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
          final repairScheduled =
              _contentRedrawAllowed && softFailureCount < maxProseRetries;
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
          if (!_contentRedrawAllowed) {
            _blockContentRedraw(
              brief: currentBrief,
              stageId: 'deterministic_gate',
              reason: 'story mechanics gate requested prose repair',
            );
          }
          if (repairScheduled) {
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
          sourceLogicalAttemptId: rawPolishOutput.sourceLogicalAttemptId,
          sourceCallSiteId: rawPolishOutput.sourceCallSiteId,
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
        final finalReviewOutput =
            await StoryGenerationEvaluationScope.run<Future<ReviewOutput>>(
              phase: StoryGenerationEvaluationPhase.finalCouncil,
              artifactText: polishOutput.prose.text,
              body: () => _executeTypedStage(
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
              ),
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
                _contentRedrawAllowed &&
                finalReviewOutput.action != SceneReviewDecision.pass &&
                softFailureCount < maxProseRetries,
          ),
        );
        if (finalReviewOutput.action != SceneReviewDecision.pass) {
          if (!_contentRedrawAllowed) {
            _blockContentRedraw(
              brief: currentBrief,
              stageId: 'review',
              reason: 'final council review requested prose repair',
            );
          }
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
          final repairScheduled =
              _contentRedrawAllowed &&
              qualityRepairCount < maxQualityRepairRetries;
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
          if (!_contentRedrawAllowed) {
            _blockContentRedraw(
              brief: currentBrief,
              stageId: 'quality_gate',
              reason: 'quality gate requested prose repair',
            );
          }
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
      final score =
          await StoryGenerationEvaluationScope.run<Future<SceneQualityScore>>(
            phase: StoryGenerationEvaluationPhase.quality,
            artifactText: prose.text,
            body: () => _qualityScorer.score(
              brief: brief,
              director: director,
              prose: prose,
              review: review,
            ),
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
    // A checkpoint contains a public score DTO, not the private parser-bound
    // provider outcome capability. Sealed production must obtain a new live
    // quality result before it can mint finalization authority.
    if (_sealedProductionEligible) return null;
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
    // The provider helper owns classified transport retry. Replaying an
    // entire stage after an arbitrary exception can create a second content
    // sample with unknowable completion state, so frozen experiments fail
    // closed at this outer lifecycle boundary.
    final maximumAttempts = _contentRedrawAllowed ? stage.maxRetries + 1 : 1;
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
    // Ordinal 9 is the final council. Ordinal 11 is independently guarded in
    // [_restoreQualityCheckpoint]. Public checkpoint JSON can resume work, but
    // it can never substitute for either live evaluation in a sealed run.
    if (_sealedProductionEligible && (ordinal == 9 || ordinal == 11)) {
      return null;
    }
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
      if (brief != null) 'brief': SceneGenerationIdentity.briefObject(brief),
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
    if (!_contentRedrawAllowed) return false;
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
