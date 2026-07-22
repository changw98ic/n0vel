import '../../../app/llm/app_llm_canonical_hash.dart';
import '../../../app/llm/app_llm_prompt_release_store.dart';
import '../domain/scene_models.dart';
import 'generation_candidate_identity.dart';
import 'generation_evidence_receipt.dart';
import 'generation_ledger.dart';
import 'generation_ledger_digest.dart';
import 'generation_ledger_models.dart';
import 'generation_stage_checkpoint_codec.dart';
import 'generation_material_manifest_repository.dart';
import 'narrative_continuity_verifier.dart';
import 'pipeline_stage_runner_impl.dart'
    show consumePipelineFinalizationAdmission, pipelinePendingWriteSourceDigest;
import 'scene_generation_identity.dart';
import 'scene_review_coordinator.dart'
    show canonicalSceneReviewEvaluationOutput;
import 'story_generation_pass_retry.dart'
    show storyGenerationParsedOutputDigest;
import 'story_prompt_registry.dart';
import 'polish_canon_verifier.dart';
import 'story_mechanics_verifier.dart';
import 'production_pre_quality_gate.dart';

/// Captures the immutable values an author sees while a run is in flight.
///
/// The snapshot may mirror these values for presentation, but acceptance only
/// trusts the proof/payload rows created from this capture.
class GenerationRunCapture {
  const GenerationRunCapture({
    required this.baseDraftHash,
    required this.materialDigest,
    required this.inputDigest,
    required this.generationBundleHash,
    required this.preparedBriefDigest,
    this.generationEvidenceMode =
        GenerationCandidateIdentity.adaptiveUnsealedMode,
    this.generationArmPolicy,
  });

  final String baseDraftHash;
  final String materialDigest;
  final String inputDigest;
  final String generationBundleHash;
  final String preparedBriefDigest;
  final String generationEvidenceMode;
  final String? generationArmPolicy;
}

/// The proof identity required to invoke [GenerationCommitCoordinator].
class DurableCandidateReference {
  const DurableCandidateReference({
    required this.runId,
    required this.candidateRevision,
    required this.candidateHash,
    required this.finalProseHash,
    required this.deterministicGateEvidenceHash,
    required this.finalCouncilEvidenceHash,
    required this.qualityEvidenceHash,
    required this.pendingWriteSetHash,
    required this.materialDigest,
    required this.inputDigest,
    required this.baseDraftHash,
    required this.generationBundleHash,
    this.preparedBriefDigest = '',
    this.effectiveBriefDigest = '',
    this.generationEvidenceMode =
        GenerationCandidateIdentity.legacyUnsealedMode,
    this.generationEvidenceReceiptHash,
    this.attemptEvidenceEnvelopeDigest,
    this.generationFingerprintSetDigest,
  });

  final String runId;
  final int candidateRevision;
  final String candidateHash;
  final String finalProseHash;
  final String deterministicGateEvidenceHash;
  final String finalCouncilEvidenceHash;
  final String qualityEvidenceHash;
  final String pendingWriteSetHash;
  final String materialDigest;
  final String inputDigest;
  final String baseDraftHash;
  final String generationBundleHash;
  final String preparedBriefDigest;
  final String effectiveBriefDigest;
  final String generationEvidenceMode;
  final String? generationEvidenceReceiptHash;
  final String? attemptEvidenceEnvelopeDigest;
  final String? generationFingerprintSetDigest;
}

/// Runtime-only second key proving that the high-level candidate finalizer
/// completed every typed literary and deterministic validation before a
/// sealed candidate crossed the durable ledger boundary.
///
/// The constructor is library-private. A real provider receipt proves where
/// prose came from; this independent capability proves that the exact proof,
/// payload, run pointer, and finalization checkpoint were assembled only
/// after the finalizer validated gates, council history, quality, continuity,
/// and pending writes.
@pragma('vm:isolate-unsendable')
final class GenerationLedgerSealedFinalizationAuthority {
  GenerationLedgerSealedFinalizationAuthority._({
    required CandidateProofRecord proof,
    required CandidatePayloadRecord payload,
    required WorkingProseRevisionRecord workingProseRevision,
    required CandidateNamespaceRecord candidateNamespace,
    required List<PendingWriteRecord> pendingWrites,
    required int updatedAtMs,
    required int currentProseRevision,
    required GenerationStageCheckpointRecord finalizationCheckpoint,
  }) : _bindingHash = _sealedFinalizationBindingHash(
         operation: markCandidateReadyOperation,
         proof: proof,
         payload: payload,
         workingProseRevision: workingProseRevision,
         candidateNamespace: candidateNamespace,
         pendingWrites: pendingWrites,
         updatedAtMs: updatedAtMs,
         currentProseRevision: currentProseRevision,
         finalizationCheckpoint: finalizationCheckpoint,
       );

  static const String finalizeCandidateOperation = 'finalize-candidate-v1';
  static const String markCandidateReadyOperation =
      'finalize-and-mark-candidate-ready-v1';

  final String _bindingHash;
  bool _consumed = false;

  bool consumeForLedger({
    required String operation,
    required CandidateProofRecord proof,
    required CandidatePayloadRecord payload,
    required WorkingProseRevisionRecord? workingProseRevision,
    required CandidateNamespaceRecord? candidateNamespace,
    required List<PendingWriteRecord> pendingWrites,
    required int? updatedAtMs,
    required int? currentProseRevision,
    required GenerationStageCheckpointRecord? finalizationCheckpoint,
  }) {
    if (_consumed) return false;
    // Burn every presentation, including a mismatched low-level operation.
    _consumed = true;
    return _bindingHash ==
        _sealedFinalizationBindingHash(
          operation: operation,
          proof: proof,
          payload: payload,
          workingProseRevision: workingProseRevision,
          candidateNamespace: candidateNamespace,
          pendingWrites: pendingWrites,
          updatedAtMs: updatedAtMs,
          currentProseRevision: currentProseRevision,
          finalizationCheckpoint: finalizationCheckpoint,
        );
  }
}

String _sealedFinalizationBindingHash({
  required String operation,
  required CandidateProofRecord proof,
  required CandidatePayloadRecord payload,
  required WorkingProseRevisionRecord? workingProseRevision,
  required CandidateNamespaceRecord? candidateNamespace,
  required List<PendingWriteRecord> pendingWrites,
  required int? updatedAtMs,
  required int? currentProseRevision,
  required GenerationStageCheckpointRecord? finalizationCheckpoint,
}) => AppLlmCanonicalHash.domainHash(
  'story-generation-sealed-finalizer-authority-v2',
  <String, Object?>{
    'operation': operation,
    'proof': <String, Object?>{
      'runId': proof.runId,
      'candidateRevision': proof.candidateRevision,
      'projectId': proof.projectId,
      'chapterId': proof.chapterId,
      'sceneId': proof.sceneId,
      'sourceProseRevision': proof.sourceProseRevision,
      'candidateHash': proof.candidateHash,
      'finalProseHash': proof.finalProseHash,
      'deterministicGateEvidenceHash': proof.deterministicGateEvidenceHash,
      'finalCouncilEvidenceHash': proof.finalCouncilEvidenceHash,
      'qualityEvidenceHash': proof.qualityEvidenceHash,
      'pendingWriteSetHash': proof.pendingWriteSetHash,
      'materialDigest': proof.materialDigest,
      'inputDigest': proof.inputDigest,
      'createdAtMs': proof.createdAtMs,
      'proofIdentityVersion': proof.proofIdentityVersion,
      'preparedBriefDigest': proof.preparedBriefDigest,
      'effectiveBriefDigest': proof.effectiveBriefDigest,
      'generationEvidenceMode': proof.generationEvidenceMode,
      'generationEvidenceReceiptHash': proof.generationEvidenceReceiptHash,
      'attemptEvidenceEnvelopeDigest': proof.attemptEvidenceEnvelopeDigest,
      'generationFingerprintSetDigest': proof.generationFingerprintSetDigest,
      'generationEvidenceReceiptJson': proof.generationEvidenceReceiptJson,
    },
    'payload': <String, Object?>{
      'runId': payload.runId,
      'candidateRevision': payload.candidateRevision,
      'finalProse': payload.finalProse,
      'pendingWriteManifestJson': payload.pendingWriteManifestJson,
      'retrievalTraceJson': payload.retrievalTraceJson,
      'reviewPayloadJson': payload.reviewPayloadJson,
      'qualityPayloadJson': payload.qualityPayloadJson,
      'generationEvidenceReceiptJson': payload.generationEvidenceReceiptJson,
      'createdAtMs': payload.createdAtMs,
      'expiresAtMs': payload.expiresAtMs,
    },
    'workingProseRevision': workingProseRevision == null
        ? null
        : <String, Object?>{
            'runId': workingProseRevision.runId,
            'proseRevision': workingProseRevision.proseRevision,
            'proseHash': workingProseRevision.proseHash,
            'proseText': workingProseRevision.proseText,
            'sourceKind': workingProseRevision.sourceKind,
            'createdAtMs': workingProseRevision.createdAtMs,
          },
    'candidateNamespace': candidateNamespace == null
        ? null
        : <String, Object?>{
            'runId': candidateNamespace.runId,
            'candidateRevision': candidateNamespace.candidateRevision,
            'sourceProseRevision': candidateNamespace.sourceProseRevision,
            'reservedAtMs': candidateNamespace.reservedAtMs,
          },
    'pendingWrites': <Object?>[
      for (final write in pendingWrites)
        <String, Object?>{
          'runId': write.runId,
          'candidateRevision': write.candidateRevision,
          'writeId': write.writeId,
          'projectId': write.projectId,
          'chapterId': write.chapterId,
          'sceneId': write.sceneId,
          'logicalEntityId': write.logicalEntityId,
          'writeKind': write.writeKind,
          'payloadHash': write.payloadHash,
          'payloadJson': write.payloadJson,
          'derivationClass': write.derivationClass,
          'state': write.state,
          'tier': write.tier,
          'producer': write.producer,
          'visibility': write.visibility,
          'ownerId': write.ownerId,
          'createdAtMs': write.createdAtMs,
          'expiresAtMs': write.expiresAtMs,
          'committedAtMs': write.committedAtMs,
          'discardedAtMs': write.discardedAtMs,
        },
    ],
    'runPointer': <String, Object?>{
      'updatedAtMs': updatedAtMs,
      'currentProseRevision': currentProseRevision,
    },
    'finalizationCheckpoint': finalizationCheckpoint == null
        ? null
        : <String, Object?>{
            'runId': finalizationCheckpoint.runId,
            'proseRevision': finalizationCheckpoint.proseRevision,
            'ordinal': finalizationCheckpoint.ordinal,
            'stageId': finalizationCheckpoint.stageId,
            'stageAttempt': finalizationCheckpoint.stageAttempt,
            'codecVersion': finalizationCheckpoint.codecVersion,
            'status': finalizationCheckpoint.status,
            'inputDigest': finalizationCheckpoint.inputDigest,
            'artifactDigest': finalizationCheckpoint.artifactDigest,
            'upstreamChainDigest': finalizationCheckpoint.upstreamChainDigest,
            'provenance': <String, Object?>{
              'baseDraftDigest':
                  finalizationCheckpoint.provenance.baseDraftDigest,
              'materialDigest':
                  finalizationCheckpoint.provenance.materialDigest,
              'promptDigest': finalizationCheckpoint.provenance.promptDigest,
              'modelDigest': finalizationCheckpoint.provenance.modelDigest,
            },
            'createdAtMs': finalizationCheckpoint.createdAtMs,
            'completedAtMs': finalizationCheckpoint.completedAtMs,
            'artifactType': finalizationCheckpoint.artifactType,
            'artifactJson': finalizationCheckpoint.artifactJson,
          },
  },
);

/// Turns a completed provider pipeline result into the durable local author
/// candidate.  It performs no provider calls and deliberately stages rather
/// than commits generated memory-related artifacts.
class GenerationLedgerCandidateFinalizer {
  GenerationLedgerCandidateFinalizer({
    required GenerationLedgerSqliteStore ledger,
    StoryPromptRegistry? promptRegistry,
  }) : _ledger = ledger,
       _promptRegistry = promptRegistry ?? StoryPromptRegistry.production;

  static const int _candidatePayloadRetentionMs = 90 * 24 * 60 * 60 * 1000;

  final GenerationLedgerSqliteStore _ledger;
  final StoryPromptRegistry _promptRegistry;

  GenerationRunCapture startRun({
    required String runId,
    required String requestId,
    required String projectId,
    required String chapterId,
    required String sceneId,
    required String sceneScopeId,
    required String baseDraft,
    required SceneBrief brief,
    required ProjectMaterialSnapshot materials,
    required int nowMs,
    String? preparedBriefDigest,
    String generationEvidenceMode =
        GenerationCandidateIdentity.adaptiveUnsealedMode,
    String? generationArmPolicy,
  }) {
    final promptStore = AppLlmPromptReleaseStore(db: _ledger.db);
    _promptRegistry.publishTo(promptStore);
    final generationBundleHash = _promptRegistry.generationBundle.bundleHash;
    _ledger.createRunWithGenerationBundle(
      run: GenerationRunRecord(
        runId: runId,
        requestId: requestId,
        projectId: projectId,
        chapterId: chapterId,
        sceneId: sceneId,
        sceneScopeId: sceneScopeId,
        status: 'running',
        phase: 'preparing',
        schemaVersion: 9,
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
      generationBundleHash: generationBundleHash,
      createdAtMs: nowMs,
    );
    // Checkpoints are revision-scoped from the first provider call. Revision
    // zero is the immutable base draft, while the first generated candidate
    // receives its own revision at finalization.
    final hasBaseRevision = _ledger.db
        .select(
          '''SELECT 1 FROM story_generation_working_prose_revisions
         WHERE run_id = ? AND prose_revision = 0''',
          [runId],
        )
        .isNotEmpty;
    if (!hasBaseRevision) {
      _ledger.createWorkingProseRevision(
        WorkingProseRevisionRecord(
          runId: runId,
          proseRevision: 0,
          proseHash: GenerationLedgerDigest.text(baseDraft),
          proseText: baseDraft,
          sourceKind: 'baseDraft',
          createdAtMs: nowMs,
        ),
      );
    }
    final materialManifest =
        GenerationMaterialManifestRepository(db: _ledger.db).freezeSnapshot(
          runId: runId,
          projectId: projectId,
          sceneId: sceneId,
          materials: materials,
          nowMs: nowMs,
        );
    final materialDigest = materialManifest.materialDigest;
    final inputDigest = GenerationLedgerDigest.object({
      'brief': SceneGenerationIdentity.briefObject(brief),
      'materialDigest': materialDigest,
    });
    final computedPreparedBriefDigest = SceneGenerationIdentity.briefHash(
      brief,
    );
    if (preparedBriefDigest != null &&
        preparedBriefDigest != computedPreparedBriefDigest) {
      throw StateError(
        'prepared brief digest does not match the captured model-visible brief',
      );
    }
    if (generationEvidenceMode !=
            GenerationCandidateIdentity.adaptiveUnsealedMode &&
        generationEvidenceMode !=
            GenerationCandidateIdentity.sealedNoRedrawMode) {
      throw ArgumentError.value(
        generationEvidenceMode,
        'generationEvidenceMode',
        'must be an explicit V2 evidence mode',
      );
    }
    final normalizedArmPolicy = generationArmPolicy?.trim();
    if (generationEvidenceMode ==
            GenerationCandidateIdentity.sealedNoRedrawMode &&
        (normalizedArmPolicy == null || normalizedArmPolicy.isEmpty)) {
      throw ArgumentError.value(
        generationArmPolicy,
        'generationArmPolicy',
        'sealed no-redraw capture requires the frozen arm policy',
      );
    }
    _ledger.initializeBudget(
      RunBudgetRecord(
        runId: runId,
        maxCalls: 48,
        maxTokens: 160000,
        maxCostMicrousd: 5000000,
        updatedAtMs: nowMs,
      ),
    );
    return GenerationRunCapture(
      baseDraftHash: GenerationLedgerDigest.text(baseDraft),
      materialDigest: materialDigest,
      inputDigest: inputDigest,
      generationBundleHash: generationBundleHash,
      preparedBriefDigest: computedPreparedBriefDigest,
      generationEvidenceMode: generationEvidenceMode,
      generationArmPolicy: normalizedArmPolicy,
    );
  }

  DurableCandidateReference finalize({
    required String runId,
    required SceneRuntimeOutput output,
    required GenerationRunCapture capture,
    required int nowMs,
    int? targetCandidateRevision,
    GenerationEvidenceReceipt? generationEvidenceReceipt,
  }) {
    final finalProse = output.prose.text;
    if (finalProse.trim().isEmpty ||
        output.review.decision != SceneReviewDecision.pass ||
        output.qualityScore == null) {
      throw StateError(
        'candidate finalization requires passed prose, review, and quality',
      );
    }
    final quality = output.qualityScore!;
    _requirePassingQualityScore(output.brief, quality);
    final finalProseHash = GenerationLedgerDigest.text(finalProse);
    final effectiveBriefDigest = SceneGenerationIdentity.briefHash(
      output.brief,
    );
    final effectiveInputDigest = GenerationLedgerDigest.object({
      'brief': SceneGenerationIdentity.briefObject(output.brief),
      'materialDigest': capture.materialDigest,
    });
    final evidenceBinding = _validateGenerationEvidence(
      runId: runId,
      output: output,
      capture: capture,
      finalProse: finalProse,
      effectiveBriefDigest: effectiveBriefDigest,
      effectiveInputDigest: effectiveInputDigest,
      receipt: generationEvidenceReceipt,
    );
    // Provider-free finalization assembles evidence produced upstream; it
    // must never manufacture a no-op polish proof without the frozen material
    // snapshot. Author edits therefore rerun polish and deterministic gates
    // before they can enter a new durable candidate namespace.
    final polishCanonEvidence = output.polishCanonEvidence;
    if (polishCanonEvidence == null) {
      throw StateError(
        'candidate finalization requires supplied polish-canon evidence',
      );
    }
    if (!polishCanonEvidence.passed ||
        polishCanonEvidence.finalProseHash !=
            PolishCanonVerifier.proseHash(finalProse)) {
      throw StateError(
        'candidate finalization requires passing polish-canon evidence for the exact prose',
      );
    }
    final storyMechanicsEvidence = output.storyMechanicsEvidence;
    if (storyMechanicsEvidence == null) {
      throw StateError(
        'candidate finalization requires supplied story-mechanics evidence',
      );
    }
    if (!storyMechanicsEvidence.passed ||
        storyMechanicsEvidence.proseHash !=
            StoryMechanicsVerifier.proseHash(finalProse)) {
      throw StateError(
        'candidate finalization requires passing story-mechanics evidence for the exact prose',
      );
    }
    final rawPreQualityEvidence = output.productionPreQualityEvidence;
    if (rawPreQualityEvidence == null) {
      throw StateError(
        'candidate finalization requires complete production pre-quality evidence',
      );
    }
    late final ProductionPreQualityEvidence preQualityEvidence;
    try {
      preQualityEvidence = ProductionPreQualityEvidence.fromJson(
        rawPreQualityEvidence,
      );
    } on Object catch (error) {
      throw StateError('candidate pre-quality evidence is invalid: $error');
    }
    final preQualityMismatches = <String>[
      if (!preQualityEvidence.passed) 'not-passed',
      if (!preQualityEvidence.hardGatesEnabled) 'hard-gates-disabled',
      if (preQualityEvidence.sourceMode !=
          ProductionPreQualitySourceMode.pipelinePolish)
        'author-revision-pre-quality-only',
      if (!preQualityEvidence.candidateFinalizationEligible)
        'candidate-finalization-ineligible',
      if (preQualityEvidence.boundaryReleaseHash !=
          ProductionPreQualityGate.releaseHash)
        'stale-boundary-release',
      if (preQualityEvidence.finalProseHash !=
          ProductionPreQualityGate.finalProseHash(finalProse))
        'final-prose',
      if (preQualityEvidence.briefRequirementsHash !=
          ProductionPreQualityGate.briefRequirementsHash(output.brief))
        'brief-requirements',
      if (preQualityEvidence.polishCanonEvidence.evidenceHash !=
          polishCanonEvidence.evidenceHash)
        'polish-canon',
      if (preQualityEvidence.storyMechanicsEvidence.evidenceHash !=
          storyMechanicsEvidence.evidenceHash)
        'story-mechanics',
    ];
    if (preQualityMismatches.isNotEmpty) {
      throw StateError(
        'candidate finalization requires current, enabled pre-quality evidence '
        'for the exact prose and brief: ${preQualityMismatches.join(', ')}',
      );
    }
    _requireCompleteReviewHistory(
      output,
      finalProse: finalProse,
      sealedEvidenceRequired:
          capture.generationEvidenceMode ==
          GenerationCandidateIdentity.sealedNoRedrawMode,
    );
    final continuityEvidence = const NarrativeContinuityVerifier().verify(
      brief: output.brief,
      prose: finalProse,
    );
    if (!continuityEvidence.passed) {
      throw StateError(
        'candidate finalization requires passing narrative continuity '
        'evidence for the exact prose',
      );
    }
    final gatePayload = <String, Object?>{
      'algorithm': 'deterministic-gate-v4',
      'finalProseHash': finalProseHash,
      'passed':
          polishCanonEvidence.passed &&
          storyMechanicsEvidence.passed &&
          continuityEvidence.passed,
      'boundaryReleaseHash': preQualityEvidence.boundaryReleaseHash,
      'briefRequirementsHash': preQualityEvidence.briefRequirementsHash,
      'productionPreQualityEvidence': preQualityEvidence.toJson(),
      'polishCanonEvidence': polishCanonEvidence.toJson(),
      'storyMechanicsEvidence': storyMechanicsEvidence.toJson(),
      if (output.brief.metadata.containsKey('continuityLedger') ||
          output.brief.metadata['requireContinuityLedger'] == true ||
          output.brief.formalExecution)
        'narrativeContinuityEvidence': <String, Object?>{
          'passed': continuityEvidence.passed,
          'ledgerIgnored': continuityEvidence.ledgerIgnored,
          'resultingLedger': continuityEvidence.resultingLedgerJson,
        },
    };
    final gateHash = GenerationLedgerDigest.object(gatePayload);
    final reviewAttempts = <Object?>[
      for (final attempt in output.reviewAttempts) attempt.toJson(),
    ];
    final reviewEvaluationOutput = canonicalSceneReviewEvaluationOutput(
      output.review,
    );
    final reviewEvaluationOutputDigest = storyGenerationParsedOutputDigest(
      reviewEvaluationOutput,
    );
    final qualityEvaluationOutput = quality.toJson();
    final qualityEvaluationOutputDigest = storyGenerationParsedOutputDigest(
      qualityEvaluationOutput,
    );
    final councilHash = GenerationLedgerDigest.object({
      'finalProseHash': finalProseHash,
      'decision': output.review.decision.name,
      'feedback': output.review.feedback,
      'reviewAttempts': reviewAttempts,
    });
    final qualityHash = GenerationLedgerDigest.object({
      'finalProseHash': finalProseHash,
      'score': quality.toJson(),
    });
    final candidateRevision = targetCandidateRevision ?? 0;
    final sealedFinalization =
        capture.generationEvidenceMode ==
        GenerationCandidateIdentity.sealedNoRedrawMode;
    if (sealedFinalization &&
        (generationEvidenceReceipt!.finalReviewParsedOutputDigest !=
                reviewEvaluationOutputDigest ||
            generationEvidenceReceipt.finalQualityParsedOutputDigest !=
                qualityEvaluationOutputDigest)) {
      throw StateError(
        'sealed candidate receipt does not certify the exact final review and quality outputs',
      );
    }
    if (sealedFinalization && targetCandidateRevision != null) {
      // A no-redraw receipt authorizes one exact provider artifact. Existing
      // author-edit namespaces may contain cloned staged state whose issuance
      // is outside this receipt. Keep that path closed until it has its own
      // runtime authority instead of silently inheriting those rows.
      throw StateError(
        'sealed no-redraw finalization does not accept an existing author-edit namespace',
      );
    }
    late final int proseRevision;
    WorkingProseRevisionRecord? atomicWorkingProseRevision;
    CandidateNamespaceRecord? atomicCandidateNamespace;
    final atomicPendingWrites = <PendingWriteRecord>[];
    final writes = <Map<String, Object?>>[];
    if (sealedFinalization) {
      _requireFreshSealedNamespace(
        runId: runId,
        candidateRevision: candidateRevision,
      );
      proseRevision = _nextWorkingProseRevision(runId);
      atomicWorkingProseRevision = WorkingProseRevisionRecord(
        runId: runId,
        proseRevision: proseRevision,
        proseHash: finalProseHash,
        proseText: finalProse,
        sourceKind: 'finalization',
        createdAtMs: nowMs,
      );
      atomicCandidateNamespace = CandidateNamespaceRecord(
        runId: runId,
        candidateRevision: candidateRevision,
        sourceProseRevision: proseRevision,
        reservedAtMs: nowMs,
      );
    } else {
      proseRevision = _prepareTargetNamespace(
        runId: runId,
        candidateRevision: candidateRevision,
        finalProse: finalProse,
        finalProseHash: finalProseHash,
        nowMs: nowMs,
        isInitial: targetCandidateRevision == null,
      );
      // Adaptive author-edit namespaces retain their existing, deterministic
      // pre-prose clone behavior. Sealed finalization never enters this path.
      writes.addAll(
        _existingNamespaceWriteReferences(
          runId: runId,
          candidateRevision: candidateRevision,
        ),
      );
    }
    final session = output.roleplaySession;
    if (session != null) {
      final payload = <String, Object?>{
        'kind': 'roleplaySession',
        'schemaVersion': 1,
        'projectId': output.brief.projectId,
        'chapterId': output.brief.chapterId,
        'sceneId': output.brief.sceneId,
        'target': {
          'projectId': output.brief.projectId,
          'chapterId': output.brief.chapterId,
          'sceneId': output.brief.sceneId,
        },
        'session': _encodeRoleplaySession(session),
        'finalProseHash': finalProseHash,
      };
      final payloadJson = GenerationLedgerDigest.canonicalJson(payload);
      final writeId = GenerationLedgerDigest.text(
        'write-v1|$runId|$candidateRevision|roleplaySession|${output.brief.sceneId}',
      );
      final payloadHash = GenerationLedgerDigest.text(payloadJson);
      final pendingWrite = PendingWriteRecord(
        runId: runId,
        candidateRevision: candidateRevision,
        writeId: writeId,
        projectId: output.brief.projectId!,
        chapterId: output.brief.chapterId,
        sceneId: output.brief.sceneId,
        logicalEntityId: output.brief.sceneId,
        writeKind: 'roleplaySession',
        payloadHash: payloadHash,
        payloadJson: payloadJson,
        derivationClass: 'preProse',
        createdAtMs: nowMs,
        expiresAtMs: nowMs + _candidatePayloadRetentionMs,
        producer: 'story-pipeline',
      );
      if (sealedFinalization) {
        atomicPendingWrites.add(pendingWrite);
      } else {
        _ledger.upsertPendingWrite(pendingWrite);
      }
      writes.add({'writeId': writeId, 'payloadHash': payloadHash});

      for (final delta in session.acceptedMemoryDeltas) {
        final deltaPayload = <String, Object?>{
          'kind': 'characterDelta',
          'schemaVersion': 1,
          'projectId': output.brief.projectId,
          'chapterId': output.brief.chapterId,
          'sceneId': output.brief.sceneId,
          'target': {
            'projectId': output.brief.projectId,
            'chapterId': output.brief.chapterId,
            'sceneId': output.brief.sceneId,
            'characterId': delta.characterId,
          },
          'delta': delta.toJson(),
          'finalProseHash': finalProseHash,
        };
        final deltaPayloadJson = GenerationLedgerDigest.canonicalJson(
          deltaPayload,
        );
        final deltaWriteId = GenerationLedgerDigest.text(
          'write-v1|$runId|$candidateRevision|characterDelta|${delta.deltaId}',
        );
        final deltaPayloadHash = GenerationLedgerDigest.text(deltaPayloadJson);
        final pendingDelta = PendingWriteRecord(
          runId: runId,
          candidateRevision: candidateRevision,
          writeId: deltaWriteId,
          projectId: output.brief.projectId!,
          chapterId: output.brief.chapterId,
          sceneId: output.brief.sceneId,
          logicalEntityId: delta.deltaId,
          writeKind: 'characterDelta',
          payloadHash: deltaPayloadHash,
          payloadJson: deltaPayloadJson,
          derivationClass: 'preProse',
          createdAtMs: nowMs,
          expiresAtMs: nowMs + _candidatePayloadRetentionMs,
          producer: 'story-pipeline',
        );
        if (sealedFinalization) {
          atomicPendingWrites.add(pendingDelta);
        } else {
          _ledger.upsertPendingWrite(pendingDelta);
        }
        writes.add({'writeId': deltaWriteId, 'payloadHash': deltaPayloadHash});
      }
    }
    // This is deliberately prose-derived, rather than a copied roleplay
    // artifact: every candidate revision (especially N+1) gets a fresh,
    // hash-bound continuity contribution from its exact final prose.
    final contributionPayload = <String, Object?>{
      'kind': 'sceneSummaryContribution',
      'schemaVersion': 1,
      'projectId': output.brief.projectId,
      'chapterId': output.brief.chapterId,
      'sceneId': output.brief.sceneId,
      'target': {
        'projectId': output.brief.projectId,
        'chapterId': output.brief.chapterId,
        'sceneId': output.brief.sceneId,
      },
      'contribution': {
        'sceneId': output.brief.sceneId,
        'finalProseHash': finalProseHash,
        'prose': finalProse,
        if (continuityEvidence.resultingLedgerEntries.isNotEmpty)
          'continuityLedger': continuityEvidence.resultingLedgerJson,
      },
    };
    final contributionPayloadJson = GenerationLedgerDigest.canonicalJson(
      contributionPayload,
    );
    final contributionWriteId = GenerationLedgerDigest.text(
      'write-v1|$runId|$candidateRevision|sceneSummaryContribution|${output.brief.sceneId}',
    );
    final contributionPayloadHash = GenerationLedgerDigest.text(
      contributionPayloadJson,
    );
    final contributionWrite = PendingWriteRecord(
      runId: runId,
      candidateRevision: candidateRevision,
      writeId: contributionWriteId,
      projectId: output.brief.projectId!,
      chapterId: output.brief.chapterId,
      sceneId: output.brief.sceneId,
      logicalEntityId: output.brief.sceneId,
      writeKind: 'sceneSummaryContribution',
      payloadHash: contributionPayloadHash,
      payloadJson: contributionPayloadJson,
      derivationClass: 'proseDerived',
      createdAtMs: nowMs,
      expiresAtMs: nowMs + _candidatePayloadRetentionMs,
      producer: 'story-pipeline',
    );
    if (sealedFinalization) {
      atomicPendingWrites.add(contributionWrite);
    } else {
      _ledger.upsertPendingWrite(contributionWrite);
    }
    writes.add({
      'writeId': contributionWriteId,
      'payloadHash': contributionPayloadHash,
    });
    final manifestJson = GenerationLedgerDigest.canonicalJson(writes);
    final pendingWriteSetHash = GenerationLedgerDigest.object(writes);
    final candidateHash = GenerationCandidateIdentity.computeV2(
      runId: runId,
      candidateRevision: candidateRevision,
      finalProseHash: finalProseHash,
      deterministicGateEvidenceHash: gateHash,
      finalCouncilEvidenceHash: councilHash,
      qualityEvidenceHash: qualityHash,
      pendingWriteSetHash: pendingWriteSetHash,
      materialDigest: capture.materialDigest,
      effectiveInputDigest: effectiveInputDigest,
      preparedBriefDigest: capture.preparedBriefDigest,
      effectiveBriefDigest: effectiveBriefDigest,
      generationBundleHash: capture.generationBundleHash,
      generationEvidenceMode: capture.generationEvidenceMode,
      generationEvidenceReceiptHash: evidenceBinding.receiptHash,
      attemptEvidenceEnvelopeDigest: evidenceBinding.attemptEnvelopeDigest,
      generationFingerprintSetDigest: evidenceBinding.fingerprintSetDigest,
    );
    final proof = CandidateProofRecord(
      runId: runId,
      candidateRevision: candidateRevision,
      projectId: output.brief.projectId!,
      chapterId: output.brief.chapterId,
      sceneId: output.brief.sceneId,
      sourceProseRevision: proseRevision,
      candidateHash: candidateHash,
      finalProseHash: finalProseHash,
      deterministicGateEvidenceHash: gateHash,
      finalCouncilEvidenceHash: councilHash,
      qualityEvidenceHash: qualityHash,
      pendingWriteSetHash: pendingWriteSetHash,
      materialDigest: capture.materialDigest,
      inputDigest: effectiveInputDigest,
      createdAtMs: nowMs,
      proofIdentityVersion: GenerationCandidateIdentity.v2,
      preparedBriefDigest: capture.preparedBriefDigest,
      effectiveBriefDigest: effectiveBriefDigest,
      generationEvidenceMode: capture.generationEvidenceMode,
      generationEvidenceReceiptHash: evidenceBinding.receiptHash,
      attemptEvidenceEnvelopeDigest: evidenceBinding.attemptEnvelopeDigest,
      generationFingerprintSetDigest: evidenceBinding.fingerprintSetDigest,
      generationEvidenceReceiptJson: generationEvidenceReceipt?.canonicalJson,
    );
    final payload = CandidatePayloadRecord(
      runId: runId,
      candidateRevision: candidateRevision,
      finalProse: finalProse,
      pendingWriteManifestJson: manifestJson,
      reviewPayloadJson: GenerationLedgerDigest.canonicalJson(
        sealedFinalization
            ? <String, Object?>{
                'schemaVersion': GenerationCandidateEvaluationPayloadIntegrity
                    .reviewSchemaVersion,
                'reviewEvaluationOutput': reviewEvaluationOutput,
                'reviewEvaluationOutputDigest': reviewEvaluationOutputDigest,
                'feedback': output.review.feedback,
                'reviewAttempts': reviewAttempts,
              }
            : <String, Object?>{
                'schemaVersion': 'candidate-review-payload-v2',
                'decision': output.review.decision.name,
                'feedback': output.review.feedback,
                'reviewAttempts': reviewAttempts,
              },
      ),
      qualityPayloadJson: GenerationLedgerDigest.canonicalJson(
        sealedFinalization
            ? <String, Object?>{
                'schemaVersion': GenerationCandidateEvaluationPayloadIntegrity
                    .qualitySchemaVersion,
                'qualityEvaluationOutput': qualityEvaluationOutput,
                'qualityEvaluationOutputDigest': qualityEvaluationOutputDigest,
                'deterministicGate': gatePayload,
              }
            : <String, Object?>{
                'schemaVersion': 'candidate-quality-payload-v3',
                'qualityScore': qualityEvaluationOutput,
                'deterministicGate': gatePayload,
              },
      ),
      generationEvidenceReceiptJson:
          generationEvidenceReceipt?.canonicalJson ?? '{}',
      createdAtMs: nowMs,
      expiresAtMs: nowMs + _candidatePayloadRetentionMs,
    );
    final finalizationCheckpoint = _finalizationCheckpoint(
      runId: runId,
      capture: capture,
      candidateRevision: candidateRevision,
      proseRevision: proseRevision,
      candidateHash: candidateHash,
      finalProseHash: finalProseHash,
      pendingWriteSetHash: pendingWriteSetHash,
      nowMs: nowMs,
    );
    if (sealedFinalization &&
        !consumePipelineFinalizationAdmission(
          output: output,
          runId: runId,
          sceneId: output.brief.sceneId,
          preparedBriefDigest: capture.preparedBriefDigest,
          generationArmPolicy: capture.generationArmPolicy!,
          generationBundleHash: capture.generationBundleHash,
          receiptCanonicalJson: generationEvidenceReceipt!.canonicalJson,
          receiptHash: generationEvidenceReceipt.receiptHash,
          finalProseHash: finalProseHash,
          materialDigest: capture.materialDigest,
          inputDigest: effectiveInputDigest,
          pendingWriteSourceDigest: pipelinePendingWriteSourceDigest(output),
        )) {
      throw StateError(
        'sealed candidate finalization requires one exact production runner admission',
      );
    }
    final sealedFinalizationAuthority = sealedFinalization
        ? GenerationLedgerSealedFinalizationAuthority._(
            proof: proof,
            payload: payload,
            workingProseRevision: atomicWorkingProseRevision!,
            candidateNamespace: atomicCandidateNamespace!,
            pendingWrites: atomicPendingWrites,
            updatedAtMs: nowMs,
            currentProseRevision: proseRevision,
            finalizationCheckpoint: finalizationCheckpoint,
          )
        : null;
    _ledger.finalizeAndMarkCandidateReady(
      proof: proof,
      payload: payload,
      updatedAtMs: nowMs,
      currentProseRevision: proseRevision,
      generationEvidenceReceiptAdmission:
          generationEvidenceReceipt?.proofAdmission,
      sealedFinalizationAuthority: sealedFinalizationAuthority,
      finalizationCheckpoint: finalizationCheckpoint,
      workingProseRevision: atomicWorkingProseRevision,
      candidateNamespace: atomicCandidateNamespace,
      pendingWrites: atomicPendingWrites,
    );
    return DurableCandidateReference(
      runId: runId,
      candidateRevision: candidateRevision,
      candidateHash: candidateHash,
      finalProseHash: finalProseHash,
      deterministicGateEvidenceHash: gateHash,
      finalCouncilEvidenceHash: councilHash,
      qualityEvidenceHash: qualityHash,
      pendingWriteSetHash: pendingWriteSetHash,
      materialDigest: capture.materialDigest,
      inputDigest: effectiveInputDigest,
      baseDraftHash: capture.baseDraftHash,
      generationBundleHash: capture.generationBundleHash,
      preparedBriefDigest: capture.preparedBriefDigest,
      effectiveBriefDigest: effectiveBriefDigest,
      generationEvidenceMode: capture.generationEvidenceMode,
      generationEvidenceReceiptHash: evidenceBinding.receiptHash,
      attemptEvidenceEnvelopeDigest: evidenceBinding.attemptEnvelopeDigest,
      generationFingerprintSetDigest: evidenceBinding.fingerprintSetDigest,
    );
  }

  _CandidateEvidenceBinding _validateGenerationEvidence({
    required String runId,
    required SceneRuntimeOutput output,
    required GenerationRunCapture capture,
    required String finalProse,
    required String effectiveBriefDigest,
    required String effectiveInputDigest,
    required GenerationEvidenceReceipt? receipt,
  }) {
    if (capture.generationEvidenceMode ==
        GenerationCandidateIdentity.adaptiveUnsealedMode) {
      if (receipt != null) {
        throw StateError(
          'adaptive-unsealed candidate cannot claim a sealed no-redraw receipt',
        );
      }
      return const _CandidateEvidenceBinding();
    }
    if (capture.generationEvidenceMode !=
        GenerationCandidateIdentity.sealedNoRedrawMode) {
      throw StateError('candidate generation evidence mode is unsupported');
    }
    if (receipt == null) {
      throw StateError(
        'sealed no-redraw candidate requires a verified generation receipt',
      );
    }
    final runRows = _ledger.db.select(
      'SELECT scene_id FROM story_generation_runs WHERE run_id = ?',
      <Object?>[runId],
    );
    if (runRows.length != 1 ||
        runRows.single['scene_id'] != output.brief.sceneId ||
        receipt.evidenceRunId != runId ||
        receipt.sceneId != runRows.single['scene_id']) {
      throw StateError(
        'generation receipt does not belong to the candidate run and scene',
      );
    }
    if (effectiveBriefDigest != capture.preparedBriefDigest ||
        effectiveInputDigest != capture.inputDigest) {
      throw StateError(
        'no-redraw candidate effective brief or input differs from its prepared capture',
      );
    }
    if (receipt.preparedBriefDigest != capture.preparedBriefDigest ||
        receipt.sceneId != output.brief.sceneId ||
        receipt.generationArmPolicy != capture.generationArmPolicy ||
        !receipt.matchesArtifactText(finalProse) ||
        receipt.generationBundleHashes.length != 1 ||
        !receipt.generationBundleHashes.contains(
          capture.generationBundleHash,
        )) {
      throw StateError(
        'generation receipt does not match brief, scene, arm, prose, or bundle',
      );
    }
    return _CandidateEvidenceBinding(
      receiptHash: receipt.receiptHash,
      attemptEnvelopeDigest: receipt.attemptEvidenceEnvelopeDigest,
      fingerprintSetDigest: receipt.generationFingerprintSetDigest,
    );
  }

  void _requireCompleteReviewHistory(
    SceneRuntimeOutput output, {
    required String finalProse,
    required bool sealedEvidenceRequired,
  }) {
    final attempts = output.reviewAttempts;
    if (attempts.isEmpty) {
      if (output.brief.formalExecution || sealedEvidenceRequired) {
        throw StateError(
          'formal or sealed candidate finalization requires a complete '
          'review history',
        );
      }
      return;
    }
    const requiredPhases = <SceneReviewPhase>[
      SceneReviewPhase.preliminary,
      SceneReviewPhase.deterministic,
      SceneReviewPhase.finalCouncil,
      SceneReviewPhase.quality,
    ];
    var hasCompleteTail = attempts.length >= requiredPhases.length;
    if (hasCompleteTail) {
      final last = attempts.last;
      final tailStart = attempts.length - requiredPhases.length;
      for (var index = 0; index < requiredPhases.length; index += 1) {
        final attempt = attempts[tailStart + index];
        if (last.round <= 0 ||
            last.proseAttempt <= 0 ||
            attempt.round != last.round ||
            attempt.proseAttempt != last.proseAttempt ||
            attempt.decision != SceneReviewDecision.pass ||
            attempt.phase != requiredPhases[index]) {
          hasCompleteTail = false;
          break;
        }
      }
    }
    if (hasCompleteTail) {
      final tail = attempts.sublist(attempts.length - requiredPhases.length);
      // Preliminary review intentionally covers the pre-polish revision. It
      // must identify that revision, but it cannot be required to equal the
      // polished final prose. The three later gates all certify final prose.
      final preliminaryHash = tail[0].proseHash?.trim() ?? '';
      final deterministicHash = tail[1].proseHash?.trim() ?? '';
      final finalCouncilHash = tail[2].proseHash?.trim() ?? '';
      final qualityHash = tail[3].proseHash?.trim() ?? '';
      final expectedDeterministicHash = StoryMechanicsVerifier.proseHash(
        finalProse,
      );
      final expectedCouncilAndQualityHash = _pipelineReviewProseHash(
        finalProse,
      );
      hasCompleteTail =
          RegExp(r'^[0-9a-f]{64}$').hasMatch(preliminaryHash) &&
          deterministicHash == expectedDeterministicHash &&
          finalCouncilHash == expectedCouncilAndQualityHash &&
          qualityHash == expectedCouncilAndQualityHash;
    }
    if (!hasCompleteTail) {
      throw StateError(
        'candidate finalization requires preliminary, deterministic, final '
        'council, and quality passes from the same prose attempt in the '
        'complete ordered review history, with each final-prose gate bound '
        'to the exact candidate prose',
      );
    }
  }

  void _requirePassingQualityScore(SceneBrief brief, SceneQualityScore score) {
    final criticalScores = <double>[
      score.prose,
      score.coherence,
      score.character,
      score.completeness,
    ];
    final extendedScores = <double>[
      score.styleScore,
      score.imageryScore,
      score.rhythmScore,
      score.faithfulnessScore,
    ];
    final requiresExtendedRubric =
        brief.formalExecution ||
        brief.metadata['requireExtendedQualityRubric'] == true;
    final evaluatedScores = <double>[
      score.overall,
      ...criticalScores,
      if (score.hasExtendedRubric) ...extendedScores,
    ];
    final invalid =
        score.warning != null ||
        score.summary.trim().isEmpty ||
        evaluatedScores.any(
          (value) => !value.isFinite || value < 0 || value > 100,
        ) ||
        (requiresExtendedRubric && !score.hasExtendedRubric) ||
        score.overall < 95 ||
        criticalScores.any((value) => value < 90) ||
        (score.hasExtendedRubric && extendedScores.any((value) => value < 90));
    if (invalid) {
      throw StateError(
        'candidate finalization requires overall>=95, every critical '
        'dimension>=90, no warning, a non-empty summary, finite 0..100 '
        'scores, and the complete extended rubric when required',
      );
    }
  }

  /// Mirrors PipelineStageRunnerImpl._digestText for review-attempt records.
  ///
  /// Pipeline review records hash the canonical one-field JSON object and
  /// omit the ledger utility's `sha256:` prefix.
  String _pipelineReviewProseHash(String value) =>
      GenerationLedgerDigest.object(<String, Object?>{
        'text': value,
      }).substring('sha256:'.length);

  int _nextWorkingProseRevision(String runId) =>
      _ledger.db
              .select(
                '''SELECT COALESCE(MAX(prose_revision), -1) + 1 AS next_revision
                   FROM story_generation_working_prose_revisions
                   WHERE run_id = ?''',
                <Object?>[runId],
              )
              .single['next_revision']
          as int;

  void _requireFreshSealedNamespace({
    required String runId,
    required int candidateRevision,
  }) {
    for (final table in const <String>[
      'story_generation_candidate_namespaces',
      'story_generation_pending_writes',
      'story_generation_candidate_proofs',
      'story_generation_candidate_payloads',
    ]) {
      final occupied = _ledger.db.select(
        'SELECT 1 FROM $table WHERE run_id = ? AND candidate_revision = ? LIMIT 1',
        <Object?>[runId, candidateRevision],
      );
      if (occupied.isNotEmpty) {
        throw const GenerationLedgerInvariantViolation(
          'sealed finalization requires a fresh candidate namespace',
        );
      }
    }
  }

  int _prepareTargetNamespace({
    required String runId,
    required int candidateRevision,
    required String finalProse,
    required String finalProseHash,
    required int nowMs,
    required bool isInitial,
  }) {
    if (isInitial) {
      final nextRevision = _nextWorkingProseRevision(runId);
      _ledger.createWorkingProseRevision(
        WorkingProseRevisionRecord(
          runId: runId,
          proseRevision: nextRevision,
          proseHash: finalProseHash,
          proseText: finalProse,
          sourceKind: 'finalization',
          createdAtMs: nowMs,
        ),
      );
      _ledger.reserveCandidateNamespace(
        CandidateNamespaceRecord(
          runId: runId,
          candidateRevision: candidateRevision,
          sourceProseRevision: nextRevision,
          reservedAtMs: nowMs,
        ),
      );
      return nextRevision;
    }
    final rows = _ledger.db.select(
      '''
      SELECT n.source_prose_revision, w.prose_hash, w.prose_text
      FROM story_generation_candidate_namespaces n
      JOIN story_generation_working_prose_revisions w
        ON w.run_id = n.run_id AND w.prose_revision = n.source_prose_revision
      WHERE n.run_id = ? AND n.candidate_revision = ?
    ''',
      [runId, candidateRevision],
    );
    if (rows.length != 1 ||
        rows.single['prose_hash'] != finalProseHash ||
        rows.single['prose_text'] != finalProse) {
      throw const GenerationLedgerInvariantViolation(
        'finalization must bind the exact author-edited prose in its namespace',
      );
    }
    return rows.single['source_prose_revision'] as int;
  }

  List<Map<String, Object?>> _existingNamespaceWriteReferences({
    required String runId,
    required int candidateRevision,
  }) {
    final rows = _ledger.db.select(
      '''SELECT write_id, payload_hash
         FROM story_generation_pending_writes
         WHERE run_id = ? AND candidate_revision = ? AND state = 'staged'
         ORDER BY write_id''',
      [runId, candidateRevision],
    );
    return [
      for (final row in rows)
        {
          'writeId': row['write_id'] as String,
          'payloadHash': row['payload_hash'] as String,
        },
    ];
  }

  GenerationStageCheckpointRecord _finalizationCheckpoint({
    required String runId,
    required GenerationRunCapture capture,
    required int candidateRevision,
    required int proseRevision,
    required String candidateHash,
    required String finalProseHash,
    required String pendingWriteSetHash,
    required int nowMs,
  }) {
    final payload = <String, Object?>{
      'candidateHash': candidateHash,
      'finalProseHash': finalProseHash,
      'pendingWriteSetHash': pendingWriteSetHash,
      'candidateRevision': candidateRevision,
    };
    final envelope = <String, Object?>{
      'codec': 'generation-stage-artifact',
      'version': GenerationStageCheckpointCodec.version,
      'ordinal': 12,
      'stageId': 'finalization',
      'artifactType': 'candidateReadyReceipt',
      'payload': payload,
    };
    final rawBase = _rawDigest(capture.baseDraftHash);
    final rawMaterial = _rawDigest(capture.materialDigest);
    final rawInput = _rawDigest(capture.inputDigest);
    return GenerationStageCheckpointRecord(
      runId: runId,
      proseRevision: proseRevision,
      ordinal: 12,
      stageId: 'finalization',
      // A candidate revision is a distinct finalization attempt.  Reusing
      // attempt 1 would make N+1 finalization collide with proof 0.
      stageAttempt: candidateRevision + 1,
      codecVersion: GenerationStageCheckpointCodec.version,
      status: 'completed',
      inputDigest: _rawDigest(GenerationLedgerDigest.object(payload)),
      artifactDigest: _rawDigest(GenerationLedgerDigest.object(envelope)),
      upstreamChainDigest: _rawDigest(
        GenerationLedgerDigest.object({'finalProseHash': finalProseHash}),
      ),
      provenance: GenerationCheckpointProvenance(
        baseDraftDigest: rawBase,
        materialDigest: rawMaterial,
        promptDigest: rawInput,
        modelDigest: _rawDigest(GenerationLedgerDigest.text('pipeline-v10')),
      ),
      artifactType: 'candidateReadyReceipt',
      artifactJson: GenerationLedgerDigest.canonicalJson(envelope),
      createdAtMs: nowMs,
      completedAtMs: nowMs,
    );
  }

  String _rawDigest(String value) =>
      value.startsWith('sha256:') ? value.substring('sha256:'.length) : value;
}

Map<String, Object?> _encodeRoleplaySession(Object session) {
  // The concrete roleplay models deliberately do not expose a broad JSON
  // persistence API. Keep the staged contract explicit and versioned.
  final value = session as dynamic;
  return {
    'chapterId': value.chapterId,
    'sceneId': value.sceneId,
    'sceneTitle': value.sceneTitle,
    'finalPublicState': value.finalPublicState,
    'rounds': [
      for (final round in value.rounds)
        {
          'round': round.round,
          'turns': [
            for (final turn in round.turns)
              {
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
                'proposedMemoryDeltas': [
                  for (final delta in turn.proposedMemoryDeltas) delta.toJson(),
                ],
              },
          ],
          'arbitration': {
            'fact': round.arbitration.fact,
            'state': round.arbitration.state,
            'pressure': round.arbitration.pressure,
            'nextPublicState': round.arbitration.nextPublicState,
            'shouldStop': round.arbitration.shouldStop,
            'rawText': round.arbitration.rawText,
            'skillId': round.arbitration.skillId,
            'skillVersion': round.arbitration.skillVersion,
            'acceptedMemoryDeltas': [
              for (final delta in round.arbitration.acceptedMemoryDeltas)
                delta.toJson(),
            ],
            'rejectedMemoryDeltas': [
              for (final delta in round.arbitration.rejectedMemoryDeltas)
                delta.toJson(),
            ],
          },
        },
    ],
    'committedFacts': [
      for (final fact in value.committedFacts)
        {
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

final class _CandidateEvidenceBinding {
  const _CandidateEvidenceBinding({
    this.receiptHash,
    this.attemptEnvelopeDigest,
    this.fingerprintSetDigest,
  });

  final String? receiptHash;
  final String? attemptEnvelopeDigest;
  final String? fingerprintSetDigest;
}
