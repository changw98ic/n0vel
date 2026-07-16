import '../../../app/llm/app_llm_prompt_release_store.dart';
import '../domain/scene_models.dart';
import 'generation_ledger.dart';
import 'generation_ledger_digest.dart';
import 'generation_ledger_models.dart';
import 'generation_stage_checkpoint_codec.dart';
import 'generation_material_manifest_repository.dart';
import 'narrative_continuity_verifier.dart';
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
  });

  final String baseDraftHash;
  final String materialDigest;
  final String inputDigest;
  final String generationBundleHash;
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
}

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
      'brief': _briefObject(brief),
      'materialDigest': materialDigest,
    });
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
    );
  }

  DurableCandidateReference finalize({
    required String runId,
    required SceneRuntimeOutput output,
    required GenerationRunCapture capture,
    required int nowMs,
    int? targetCandidateRevision,
  }) {
    final finalProse = output.prose.text.trim();
    if (finalProse.isEmpty ||
        output.review.decision != SceneReviewDecision.pass ||
        output.qualityScore == null) {
      throw StateError(
        'candidate finalization requires passed prose, review, and quality',
      );
    }
    final quality = output.qualityScore!;
    final finalProseHash = GenerationLedgerDigest.text(finalProse);
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
    _requireCompleteReviewHistory(output, finalProse: finalProse);
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
    final proseRevision = _prepareTargetNamespace(
      runId: runId,
      candidateRevision: candidateRevision,
      finalProse: finalProse,
      finalProseHash: finalProseHash,
      nowMs: nowMs,
      isInitial: targetCandidateRevision == null,
    );

    // An author-edited namespace already contains newly materialized,
    // deterministic pre-prose clones. They remain part of N+1's evidence set;
    // omitting them would leave staged rows outside the proof manifest and
    // make acceptance correctly fail closed.
    final writes = _existingNamespaceWriteReferences(
      runId: runId,
      candidateRevision: candidateRevision,
    );
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
      _ledger.upsertPendingWrite(
        PendingWriteRecord(
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
        ),
      );
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
        _ledger.upsertPendingWrite(
          PendingWriteRecord(
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
          ),
        );
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
    _ledger.upsertPendingWrite(
      PendingWriteRecord(
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
      ),
    );
    writes.add({
      'writeId': contributionWriteId,
      'payloadHash': contributionPayloadHash,
    });
    final manifestJson = GenerationLedgerDigest.canonicalJson(writes);
    final pendingWriteSetHash = GenerationLedgerDigest.object(writes);
    final candidateHash = GenerationLedgerDigest.object({
      'runId': runId,
      'candidateRevision': candidateRevision,
      'finalProseHash': finalProseHash,
      'deterministicGateEvidenceHash': gateHash,
      'finalCouncilEvidenceHash': councilHash,
      'qualityEvidenceHash': qualityHash,
      'pendingWriteSetHash': pendingWriteSetHash,
      'materialDigest': capture.materialDigest,
      'inputDigest': capture.inputDigest,
      'generationBundleHash': capture.generationBundleHash,
    });
    _ledger.finalizeAndMarkCandidateReady(
      proof: CandidateProofRecord(
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
        inputDigest: capture.inputDigest,
        createdAtMs: nowMs,
      ),
      payload: CandidatePayloadRecord(
        runId: runId,
        candidateRevision: candidateRevision,
        finalProse: finalProse,
        pendingWriteManifestJson: manifestJson,
        reviewPayloadJson: GenerationLedgerDigest.canonicalJson({
          'schemaVersion': 'candidate-review-payload-v2',
          'decision': output.review.decision.name,
          'feedback': output.review.feedback,
          'reviewAttempts': reviewAttempts,
        }),
        qualityPayloadJson: GenerationLedgerDigest.canonicalJson({
          'schemaVersion': 'candidate-quality-payload-v3',
          'qualityScore': quality.toJson(),
          'deterministicGate': gatePayload,
        }),
        createdAtMs: nowMs,
        expiresAtMs: nowMs + _candidatePayloadRetentionMs,
      ),
      updatedAtMs: nowMs,
      currentProseRevision: proseRevision,
      finalizationCheckpoint: _finalizationCheckpoint(
        runId: runId,
        capture: capture,
        candidateRevision: candidateRevision,
        proseRevision: proseRevision,
        candidateHash: candidateHash,
        finalProseHash: finalProseHash,
        pendingWriteSetHash: pendingWriteSetHash,
        nowMs: nowMs,
      ),
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
      inputDigest: capture.inputDigest,
      baseDraftHash: capture.baseDraftHash,
      generationBundleHash: capture.generationBundleHash,
    );
  }

  void _requireCompleteReviewHistory(
    SceneRuntimeOutput output, {
    required String finalProse,
  }) {
    final attempts = output.reviewAttempts;
    if (attempts.isEmpty) {
      if (output.brief.formalExecution) {
        throw StateError(
          'formal candidate finalization requires a complete review history',
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

  /// Mirrors PipelineStageRunnerImpl._digestText for review-attempt records.
  ///
  /// Pipeline review records hash the canonical one-field JSON object and
  /// omit the ledger utility's `sha256:` prefix.
  String _pipelineReviewProseHash(String value) =>
      GenerationLedgerDigest.object(<String, Object?>{
        'text': value,
      }).substring('sha256:'.length);

  int _prepareTargetNamespace({
    required String runId,
    required int candidateRevision,
    required String finalProse,
    required String finalProseHash,
    required int nowMs,
    required bool isInitial,
  }) {
    if (isInitial) {
      final nextRevision =
          _ledger.db
                  .select(
                    '''SELECT COALESCE(MAX(prose_revision), -1) + 1 AS next_revision
                       FROM story_generation_working_prose_revisions
                       WHERE run_id = ?''',
                    [runId],
                  )
                  .single['next_revision']
              as int;
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

  Map<String, Object?> _briefObject(SceneBrief brief) => {
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
    'castIds': [for (final cast in brief.cast) cast.characterId],
    'formalExecution': brief.formalExecution,
    if (brief.metadata.containsKey('requiredOutlineBeats'))
      'requiredOutlineBeats': brief.metadata['requiredOutlineBeats'],
    if (brief.metadata['requireOutlineFidelity'] == true)
      'requireOutlineFidelity': true,
    if (brief.metadata.containsKey('continuityLedger'))
      'continuityLedger': brief.metadata['continuityLedger'],
    if (brief.metadata['requireContinuityLedger'] == true)
      'requireContinuityLedger': true,
  };

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
