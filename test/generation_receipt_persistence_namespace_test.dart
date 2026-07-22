import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/authoring_table_definitions.dart';
import 'package:novel_writer/features/story_generation/data/generation_candidate_identity.dart';
import 'package:novel_writer/features/story_generation/data/generation_commit_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_receipt.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_candidate_finalizer.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_digest.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:novel_writer/features/story_generation/data/production_pre_quality_gate.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support/generation_evidence_receipt_fixture.dart';

void main() {
  group('sealed receipt persistence namespace binding', () {
    for (final replay in <({String name, bool changesRun})>[
      (name: 'another run', changesRun: true),
      (name: 'another scene', changesRun: false),
    ]) {
      test(
        'low-level proof writer rejects a receipt from ${replay.name}',
        () async {
          _selectFreshNamespace('low-${replay.name}');
          final db = sqlite3.openInMemory();
          addTearDown(db.dispose);
          db.execute('PRAGMA foreign_keys = ON');
          final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
          final identity = _seedRunAndNamespace(ledger);
          final replayedReceipt = await buildGenerationEvidenceReceiptFixture(
            evidenceRunId: replay.changesRun ? '$_runId-source' : _runId,
            sceneId: replay.changesRun ? _sceneId : '$_sceneId-source',
            generationArmPolicy: _armPolicy,
            preparedBriefDigest: identity.preparedBriefDigest,
            generationBundleHash: identity.generationBundleHash,
            artifactText: _finalProse,
          );

          expect(
            () => ledger.createCandidateProof(
              _sealedProof(identity: identity, receipt: replayedReceipt),
              generationEvidenceReceiptAdmission:
                  replayedReceipt.proofAdmission,
            ),
            throwsA(isA<GenerationLedgerInvariantViolation>()),
          );
          expect(
            db.select('SELECT * FROM story_generation_candidate_proofs'),
            isEmpty,
          );
        },
      );

      test(
        'commit revalidation rejects coordinated ${replay.name} receipt tampering without effects',
        () async {
          _selectFreshNamespace('commit-${replay.name}');
          final db = sqlite3.openInMemory();
          addTearDown(db.dispose);
          db.execute('PRAGMA foreign_keys = ON');
          final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
          final coordinator = GenerationCommitCoordinator(db: db)
            ..ensureTables();
          final finalized = await _finalizeRealCandidate(ledger);
          db.execute(
            'INSERT INTO draft_documents '
            '(project_id, text_body, updated_at_ms) VALUES (?, ?, ?)',
            <Object?>[_sceneScopeId, _previousDraft, 200],
          );

          final replayedReceipt = await buildGenerationEvidenceReceiptFixture(
            evidenceRunId: replay.changesRun ? '$_runId-source' : _runId,
            sceneId: replay.changesRun ? _sceneId : '$_sceneId-source',
            generationArmPolicy: _armPolicy,
            preparedBriefDigest: finalized.candidate.preparedBriefDigest,
            generationBundleHash: finalized.candidate.generationBundleHash,
            artifactText: _finalProse,
          );
          final replayedCandidateHash = _candidateHashForReceipt(
            candidate: finalized.candidate,
            receipt: replayedReceipt,
          );
          // Simulate coordinated offline persistence corruption. The normal
          // immutable-proof trigger prevents this update; commit must still
          // independently reject it when reading a compromised database.
          db.execute('DROP TRIGGER prevent_generation_proof_update');
          db.execute(
            '''UPDATE story_generation_candidate_proofs
               SET candidate_hash = ?, generation_evidence_receipt_hash = ?,
                   attempt_evidence_envelope_digest = ?,
                   generation_fingerprint_set_digest = ?,
                   generation_evidence_receipt_json = ?
               WHERE run_id = ? AND candidate_revision = 0''',
            <Object?>[
              replayedCandidateHash,
              replayedReceipt.receiptHash,
              replayedReceipt.attemptEvidenceEnvelopeDigest,
              replayedReceipt.generationFingerprintSetDigest,
              replayedReceipt.canonicalJson,
              _runId,
            ],
          );
          db.execute(
            '''UPDATE story_generation_candidate_payloads
               SET generation_evidence_receipt_json = ?
               WHERE run_id = ? AND candidate_revision = 0''',
            <Object?>[replayedReceipt.canonicalJson, _runId],
          );

          expect(
            () => coordinator.accept(
              _commitRequestFromCandidate(
                candidateHash: replayedCandidateHash,
                candidate: finalized.candidate,
              ),
            ),
            throwsA(isA<GenerationCandidateEvidenceConflict>()),
          );
          expect(
            db.select(
              'SELECT text_body FROM draft_documents WHERE project_id = ?',
              <Object?>[_sceneScopeId],
            ).single['text_body'],
            _previousDraft,
          );
          expect(db.select('SELECT * FROM version_entries'), isEmpty);
          expect(
            db.select('SELECT * FROM story_generation_commit_receipts'),
            isEmpty,
          );
          expect(db.select('SELECT * FROM story_generation_outbox'), isEmpty);
          expect(
            db.select(
              'SELECT status FROM story_generation_runs WHERE run_id = ?',
              <Object?>[_runId],
            ).single['status'],
            'candidateReady',
          );
        },
      );
    }

    test(
      'author commit rejects matching non-canonical proof and payload receipts',
      () async {
        _selectFreshNamespace('non-canonical');
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final coordinator = GenerationCommitCoordinator(db: db)..ensureTables();
        final finalized = await _finalizeRealCandidate(ledger);
        final receipt = finalized.receipt;
        db.execute(
          'INSERT INTO draft_documents '
          '(project_id, text_body, updated_at_ms) VALUES (?, ?, ?)',
          <Object?>[_sceneScopeId, _previousDraft, 200],
        );

        final nonCanonicalReceiptJson = ' ${receipt.canonicalJson}';
        db.execute('DROP TRIGGER prevent_generation_proof_update');
        db.execute(
          '''UPDATE story_generation_candidate_proofs
             SET generation_evidence_receipt_json = ?
             WHERE run_id = ? AND candidate_revision = 0''',
          <Object?>[nonCanonicalReceiptJson, _runId],
        );
        db.execute(
          '''UPDATE story_generation_candidate_payloads
             SET generation_evidence_receipt_json = ?
             WHERE run_id = ? AND candidate_revision = 0''',
          <Object?>[nonCanonicalReceiptJson, _runId],
        );

        expect(
          () => coordinator.accept(
            _commitRequestFromCandidate(
              candidateHash: finalized.candidate.candidateHash,
              candidate: finalized.candidate,
            ),
          ),
          throwsA(isA<GenerationCandidateEvidenceConflict>()),
        );
        expect(
          db.select(
            'SELECT text_body FROM draft_documents WHERE project_id = ?',
            <Object?>[_sceneScopeId],
          ).single['text_body'],
          _previousDraft,
        );
        expect(db.select('SELECT * FROM version_entries'), isEmpty);
        expect(
          db.select('SELECT * FROM story_generation_commit_receipts'),
          isEmpty,
        );
        expect(db.select('SELECT * FROM story_generation_outbox'), isEmpty);
        expect(
          db.select(
            'SELECT status FROM story_generation_runs WHERE run_id = ?',
            <Object?>[_runId],
          ).single['status'],
          'candidateReady',
        );
      },
    );
  });
}

const _projectId = 'project-1';
const _chapterId = 'chapter-1';
const _armPolicy = 'arm-current-v1';
const _finalProse =
    '雨水越过锈蚀窗框，落在摊开的账页上。柳溪逐项核对封口编号，指尖停在最后一栏。'
    '“编号没错，封条也没动。”'
    '“那就收好证据，从货箱后面走。”'
    '她把账页收进内袋，沿阴影离开。';
const _previousDraft = '作者尚未采纳的旧稿。';
var _namespaceSerial = 0;
var _runId = 'receipt-persistence-unselected-run';
var _sceneId = 'receipt-persistence-unselected-scene';
var _sceneScopeId = 'project-1::receipt-persistence-unselected-scene';

void _selectFreshNamespace(String label) {
  final serial = _namespaceSerial += 1;
  final safeLabel = label.replaceAll(' ', '-');
  _runId = 'receipt-persistence-$safeLabel-run-$serial';
  _sceneId = 'receipt-persistence-$safeLabel-scene-$serial';
  _sceneScopeId = '$_projectId::$_sceneId';
}

final class _SealedCandidateIdentity {
  const _SealedCandidateIdentity({
    required this.generationBundleHash,
    required this.preparedBriefDigest,
    required this.materialDigest,
    required this.inputDigest,
  });

  final String generationBundleHash;
  final String preparedBriefDigest;
  final String materialDigest;
  final String inputDigest;
}

_SealedCandidateIdentity _seedRunAndNamespace(
  GenerationLedgerSqliteStore ledger,
) {
  final generationBundleHash = generationEvidenceReceiptFixtureBundleHash;
  createAgentEvaluationTables(ledger.db);
  ledger.db.execute(
    '''INSERT INTO generation_bundles
       (bundle_hash, bundle_id, releases_json, created_at_ms)
       VALUES (?, ?, ?, ?)''',
    <Object?>[
      generationBundleHash.substring('sha256:'.length),
      'bundle-fixture',
      '[]',
      100,
    ],
  );
  ledger.createRunWithGenerationBundle(
    run: GenerationRunRecord(
      runId: _runId,
      requestId: 'request-target',
      projectId: _projectId,
      chapterId: _chapterId,
      sceneId: _sceneId,
      sceneScopeId: _sceneScopeId,
      status: 'running',
      phase: 'finalization',
      schemaVersion: 9,
      createdAtMs: 100,
      updatedAtMs: 100,
    ),
    generationBundleHash: generationBundleHash,
    createdAtMs: 100,
  );
  ledger.createWorkingProseRevision(
    WorkingProseRevisionRecord(
      runId: _runId,
      proseRevision: 0,
      proseHash: GenerationLedgerDigest.text(_finalProse),
      proseText: _finalProse,
      sourceKind: 'provider-sealed',
      createdAtMs: 125,
    ),
  );
  ledger.reserveCandidateNamespace(
    CandidateNamespaceRecord(
      runId: _runId,
      candidateRevision: 0,
      sourceProseRevision: 0,
      reservedAtMs: 150,
    ),
  );
  return _SealedCandidateIdentity(
    generationBundleHash: generationBundleHash,
    preparedBriefDigest: _fieldDigest('prepared-brief'),
    materialDigest: _fieldDigest('material'),
    inputDigest: _fieldDigest('input'),
  );
}

CandidateProofRecord _sealedProof({
  required _SealedCandidateIdentity identity,
  required GenerationEvidenceReceipt receipt,
}) {
  final finalProseHash = GenerationLedgerDigest.text(_finalProse);
  final deterministicHash = _fieldDigest('deterministic');
  final councilHash = _fieldDigest('council');
  final qualityHash = _fieldDigest('quality');
  final pendingWriteSetHash = GenerationLedgerDigest.object(const <Object?>[]);
  final candidateHash = GenerationCandidateIdentity.computeV2(
    runId: _runId,
    candidateRevision: 0,
    finalProseHash: finalProseHash,
    deterministicGateEvidenceHash: deterministicHash,
    finalCouncilEvidenceHash: councilHash,
    qualityEvidenceHash: qualityHash,
    pendingWriteSetHash: pendingWriteSetHash,
    materialDigest: identity.materialDigest,
    effectiveInputDigest: identity.inputDigest,
    preparedBriefDigest: identity.preparedBriefDigest,
    effectiveBriefDigest: identity.preparedBriefDigest,
    generationBundleHash: identity.generationBundleHash,
    generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
    generationEvidenceReceiptHash: receipt.receiptHash,
    attemptEvidenceEnvelopeDigest: receipt.attemptEvidenceEnvelopeDigest,
    generationFingerprintSetDigest: receipt.generationFingerprintSetDigest,
  );
  return CandidateProofRecord(
    runId: _runId,
    candidateRevision: 0,
    projectId: _projectId,
    chapterId: _chapterId,
    sceneId: _sceneId,
    sourceProseRevision: 0,
    candidateHash: candidateHash,
    finalProseHash: finalProseHash,
    deterministicGateEvidenceHash: deterministicHash,
    finalCouncilEvidenceHash: councilHash,
    qualityEvidenceHash: qualityHash,
    pendingWriteSetHash: pendingWriteSetHash,
    materialDigest: identity.materialDigest,
    inputDigest: identity.inputDigest,
    createdAtMs: 175,
    proofIdentityVersion: GenerationCandidateIdentity.v2,
    preparedBriefDigest: identity.preparedBriefDigest,
    effectiveBriefDigest: identity.preparedBriefDigest,
    generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
    generationEvidenceReceiptHash: receipt.receiptHash,
    attemptEvidenceEnvelopeDigest: receipt.attemptEvidenceEnvelopeDigest,
    generationFingerprintSetDigest: receipt.generationFingerprintSetDigest,
    generationEvidenceReceiptJson: receipt.canonicalJson,
  );
}

Future<
  ({DurableCandidateReference candidate, GenerationEvidenceReceipt receipt})
>
_finalizeRealCandidate(GenerationLedgerSqliteStore ledger) async {
  final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
  const materials = ProjectMaterialSnapshot(
    worldFacts: <String>['账页封口编号是可核对的正式证据。'],
  );
  final brief = SceneBrief(
    projectId: _projectId,
    chapterId: _chapterId,
    chapterTitle: '第一章',
    sceneId: _sceneId,
    sceneTitle: '账页',
    sceneSummary: '核对账页封口编号并收好证据。',
    targetBeat: '确认封口编号。',
    sceneIndex: 1,
    totalScenesInChapter: 3,
  );
  final capture = finalizer.startRun(
    runId: _runId,
    requestId: 'receipt-persistence-request',
    projectId: _projectId,
    chapterId: _chapterId,
    sceneId: _sceneId,
    sceneScopeId: _sceneScopeId,
    baseDraft: _previousDraft,
    brief: brief,
    materials: materials,
    nowMs: 100,
    generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
    generationArmPolicy: _armPolicy,
  );
  final receipt = await buildGenerationEvidenceReceiptFixture(
    evidenceRunId: _runId,
    sceneId: _sceneId,
    generationArmPolicy: _armPolicy,
    preparedBriefDigest: capture.preparedBriefDigest,
    generationBundleHash: capture.generationBundleHash,
    artifactText: _finalProse,
  );
  final output = _validatedOutput(brief: brief, materials: materials);
  final candidate = finalizer.finalize(
    runId: _runId,
    output: output,
    capture: capture,
    nowMs: 200,
    generationEvidenceReceipt: receipt,
  );
  return (candidate: candidate, receipt: receipt);
}

SceneRuntimeOutput _validatedOutput({
  required SceneBrief brief,
  required ProjectMaterialSnapshot materials,
}) {
  final preQuality = ProductionPreQualityGate.standard.verifyPipelinePolish(
    brief: brief,
    materials: materials,
    prePolishProse: _finalProse,
    finalProse: _finalProse,
    hardGatesEnabled: true,
  );
  const pass = SceneReviewPassResult(
    status: SceneReviewStatus.pass,
    reason: '通过。',
    rawText: '决定：PASS\n原因：通过。',
  );
  return SceneRuntimeOutput(
    brief: brief,
    resolvedCast: const [],
    director: const SceneDirectorOutput(text: '核对证据后撤离。'),
    roleOutputs: const [],
    prose: const SceneProseDraft(text: _finalProse, attempt: 1),
    review: const SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: SceneReviewDecision.pass,
    ),
    reviewAttempts: <SceneReviewAttempt>[
      SceneReviewAttempt.snapshot(
        round: 1,
        proseAttempt: 1,
        phase: SceneReviewPhase.preliminary,
        decision: SceneReviewDecision.pass,
        reason: '初审通过。',
        proseHash: _reviewProseHash('pre-polish candidate'),
      ),
      SceneReviewAttempt.snapshot(
        round: 1,
        proseAttempt: 1,
        phase: SceneReviewPhase.deterministic,
        decision: SceneReviewDecision.pass,
        reason: '确定性门通过。',
        proseHash: preQuality.storyMechanicsEvidence.proseHash,
      ),
      SceneReviewAttempt.snapshot(
        round: 1,
        proseAttempt: 1,
        phase: SceneReviewPhase.finalCouncil,
        decision: SceneReviewDecision.pass,
        reason: '终审通过。',
        proseHash: _reviewProseHash(_finalProse),
      ),
      SceneReviewAttempt.snapshot(
        round: 1,
        proseAttempt: 1,
        phase: SceneReviewPhase.quality,
        decision: SceneReviewDecision.pass,
        reason: '质量门通过。',
        proseHash: _reviewProseHash(_finalProse),
      ),
    ],
    proseAttempts: 1,
    softFailureCount: 0,
    qualityScore: const SceneQualityScore(
      overall: 96,
      prose: 96,
      coherence: 96,
      character: 96,
      completeness: 96,
      summary: '达到发布线。',
    ),
    polishCanonEvidence: preQuality.polishCanonEvidence,
    storyMechanicsEvidence: preQuality.storyMechanicsEvidence,
    productionPreQualityEvidence: preQuality.toJson(),
  );
}

String _reviewProseHash(String value) => GenerationLedgerDigest.object(
  <String, Object?>{'text': value},
).substring('sha256:'.length);

String _candidateHashForReceipt({
  required DurableCandidateReference candidate,
  required GenerationEvidenceReceipt receipt,
}) => GenerationCandidateIdentity.computeV2(
  runId: candidate.runId,
  candidateRevision: candidate.candidateRevision,
  finalProseHash: candidate.finalProseHash,
  deterministicGateEvidenceHash: candidate.deterministicGateEvidenceHash,
  finalCouncilEvidenceHash: candidate.finalCouncilEvidenceHash,
  qualityEvidenceHash: candidate.qualityEvidenceHash,
  pendingWriteSetHash: candidate.pendingWriteSetHash,
  materialDigest: candidate.materialDigest,
  effectiveInputDigest: candidate.inputDigest,
  preparedBriefDigest: candidate.preparedBriefDigest,
  effectiveBriefDigest: candidate.effectiveBriefDigest,
  generationBundleHash: candidate.generationBundleHash,
  generationEvidenceMode: candidate.generationEvidenceMode,
  generationEvidenceReceiptHash: receipt.receiptHash,
  attemptEvidenceEnvelopeDigest: receipt.attemptEvidenceEnvelopeDigest,
  generationFingerprintSetDigest: receipt.generationFingerprintSetDigest,
);

GenerationCommitRequest _commitRequestFromCandidate({
  required String candidateHash,
  required DurableCandidateReference candidate,
}) => GenerationCommitRequest(
  acceptIdempotencyKey: 'accept-target',
  runId: _runId,
  candidateRevision: candidate.candidateRevision,
  projectId: _projectId,
  sceneScopeId: _sceneScopeId,
  candidateHash: candidateHash,
  expectedBaseDraftHash: candidate.baseDraftHash,
  expectedMaterialDigest: candidate.materialDigest,
  expectedInputDigest: candidate.inputDigest,
  expectedFinalProseHash: candidate.finalProseHash,
  expectedDeterministicGateEvidenceHash:
      candidate.deterministicGateEvidenceHash,
  expectedFinalCouncilEvidenceHash: candidate.finalCouncilEvidenceHash,
  expectedQualityEvidenceHash: candidate.qualityEvidenceHash,
  expectedPendingWriteSetHash: candidate.pendingWriteSetHash,
  committedAtMs: 300,
);

String _fieldDigest(String field) =>
    GenerationLedgerDigest.object(<String, Object?>{'field': field});
