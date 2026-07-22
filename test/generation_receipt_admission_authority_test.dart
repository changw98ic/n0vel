import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_provider_outcome_seal.dart';
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
  group('sealed receipt proof admission authority', () {
    test(
      'publicly rehashed canonical receipt cannot finalize a proof and writes nothing',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final identity = _seedRun(ledger, identitySalt: 'public-rehash');
        final journalAuthorized = await _receipt(identity);

        // This reproduces every public integrity operation an offline caller
        // needs to "self-sign" receipt-shaped JSON. Integrity parsing must
        // remain useful for restart reads without granting first-write power.
        final selfSigned = GenerationEvidenceReceipt.fromCanonicalJson(
          _recomputePublicReceiptHash(journalAuthorized),
        );
        expect(selfSigned.receiptHash, journalAuthorized.receiptHash);
        expect(selfSigned.proofAdmission, isNull);

        expect(
          () => ledger.finalizeCandidate(
            proof: _proof(identity: identity, receipt: selfSigned),
            payload: _payload(identity, selfSigned),
            generationEvidenceReceiptAdmission: selfSigned.proofAdmission,
          ),
          throwsA(isA<GenerationLedgerInvariantViolation>()),
        );

        expect(
          db.select('SELECT * FROM story_generation_candidate_proofs'),
          isEmpty,
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_payloads'),
          isEmpty,
        );
        expect(
          db.select(
            'SELECT status, current_candidate_revision '
            'FROM story_generation_runs WHERE run_id = ?',
            <Object?>[identity.runId],
          ).single,
          containsPair('status', 'running'),
        );
      },
    );

    test(
      'proof-only writer rejects sealed evidence and burns genuine authority',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final identity = _seedRun(
          ledger,
          identitySalt: 'proof-only',
          candidateRevisions: const <int>[0, 1],
        );
        final receipt = await _receipt(identity);
        final admission = receipt.proofAdmission;
        expect(admission, isNotNull);

        expect(
          () => ledger.createCandidateProof(
            _proof(identity: identity, receipt: receipt),
            generationEvidenceReceiptAdmission: admission,
          ),
          throwsA(isA<GenerationLedgerInvariantViolation>()),
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_proofs'),
          isEmpty,
        );

        // The rejected proof-only presentation consumed the one-shot marker.
        expect(
          () => ledger.finalizeCandidate(
            proof: _proof(identity: identity, receipt: receipt),
            payload: _payload(identity, receipt),
            generationEvidenceReceiptAdmission: admission,
          ),
          throwsA(isA<GenerationLedgerInvariantViolation>()),
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_proofs'),
          isEmpty,
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_payloads'),
          isEmpty,
        );
      },
    );

    test(
      'fresh genuine receipt cannot use exact low-level finalize without finalizer key',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final identity = _seedRun(
          ledger,
          identitySalt: 'exact-low-level-finalize',
        );
        final receipt = await _receipt(identity);

        expect(
          () => ledger.finalizeCandidate(
            proof: _proof(identity: identity, receipt: receipt),
            payload: _payload(identity, receipt),
            generationEvidenceReceiptAdmission: receipt.proofAdmission,
          ),
          throwsA(isA<GenerationLedgerInvariantViolation>()),
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_proofs'),
          isEmpty,
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_payloads'),
          isEmpty,
        );
      },
    );

    test(
      'genuine receipt cannot authorize a different artifact and marker is burned',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final identity = _seedRun(
          ledger,
          identitySalt: 'artifact-substitution',
        );
        final receipt = await _receipt(identity);
        final admission = receipt.proofAdmission;
        const substitutedProse = '账页是干的，窗外也从未下过雨。';

        expect(
          () => ledger.finalizeCandidate(
            proof: _proof(
              identity: identity,
              receipt: receipt,
              finalProse: substitutedProse,
            ),
            // Keep the payload byte-exact to the receipt while the permanent
            // proof claims a different prose hash. This is the proof-only
            // poisoning shape that used to survive first admission.
            payload: _payload(identity, receipt),
            generationEvidenceReceiptAdmission: admission,
          ),
          throwsA(isA<GenerationLedgerInvariantViolation>()),
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_proofs'),
          isEmpty,
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_payloads'),
          isEmpty,
        );

        // Even a subsequent exact presentation cannot reuse the marker that
        // was exposed to the substituted-artifact attack.
        expect(
          () => ledger.finalizeCandidate(
            proof: _proof(identity: identity, receipt: receipt),
            payload: _payload(identity, receipt),
            generationEvidenceReceiptAdmission: admission,
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
      'true receipt and self-consistent fake gate hashes cannot move ready pointer',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final identity = _seedRun(ledger, identitySalt: 'fake-literary-gates');
        final receipt = await _receipt(identity);
        final proof = _proof(identity: identity, receipt: receipt);

        expect(
          () => ledger.finalizeAndMarkCandidateReady(
            proof: proof,
            payload: _payload(identity, receipt),
            updatedAtMs: 200,
            currentProseRevision: 0,
            generationEvidenceReceiptAdmission: receipt.proofAdmission,
          ),
          throwsA(isA<GenerationLedgerInvariantViolation>()),
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_proofs'),
          isEmpty,
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_payloads'),
          isEmpty,
        );
        expect(
          db.select('SELECT * FROM story_generation_stage_checkpoints'),
          isEmpty,
        );
        expect(
          db.select(
            'SELECT status, phase, current_candidate_revision '
            'FROM story_generation_runs WHERE run_id = ?',
            <Object?>[identity.runId],
          ).single,
          allOf(
            containsPair('status', 'running'),
            containsPair('phase', 'finalization'),
            containsPair('current_candidate_revision', isNull),
          ),
        );
      },
    );

    test(
      'genuine receipts cannot turn invalid 95/90 quality evidence into a key',
      () async {
        final attacks =
            <
              ({
                String name,
                bool formalExecution,
                SceneQualityScore qualityScore,
              })
            >[
              (
                name: 'overall below 95',
                formalExecution: false,
                qualityScore: const SceneQualityScore(
                  overall: 94,
                  prose: 96,
                  coherence: 96,
                  character: 96,
                  completeness: 96,
                  summary: '伪造高分。',
                ),
              ),
              (
                name: 'critical dimension below 90',
                formalExecution: false,
                qualityScore: const SceneQualityScore(
                  overall: 96,
                  prose: 89,
                  coherence: 96,
                  character: 96,
                  completeness: 96,
                  summary: '伪造高分。',
                ),
              ),
              (
                name: 'warning present',
                formalExecution: false,
                qualityScore: const SceneQualityScore(
                  overall: 96,
                  prose: 96,
                  coherence: 96,
                  character: 96,
                  completeness: 96,
                  summary: '伪造高分。',
                  warning: '证据不足。',
                ),
              ),
              (
                name: 'summary missing',
                formalExecution: false,
                qualityScore: const SceneQualityScore(
                  overall: 96,
                  prose: 96,
                  coherence: 96,
                  character: 96,
                  completeness: 96,
                  summary: '   ',
                ),
              ),
              (
                name: 'formal extended rubric missing',
                formalExecution: true,
                qualityScore: const SceneQualityScore(
                  overall: 96,
                  prose: 96,
                  coherence: 96,
                  character: 96,
                  completeness: 96,
                  summary: '伪造高分。',
                ),
              ),
              (
                name: 'extended dimension below 90',
                formalExecution: true,
                qualityScore: const SceneQualityScore(
                  overall: 96,
                  prose: 96,
                  coherence: 96,
                  character: 96,
                  completeness: 96,
                  style: 89,
                  imagery: 96,
                  rhythm: 96,
                  faithfulness: 96,
                  summary: '伪造高分。',
                ),
              ),
            ];

        for (var index = 0; index < attacks.length; index += 1) {
          final attack = attacks[index];
          final db = sqlite3.openInMemory();
          addTearDown(db.dispose);
          db.execute('PRAGMA foreign_keys = ON');
          final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
          final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
          final fixture = await _startHighLevelFixture(
            ledger: ledger,
            identitySalt: 'invalid-quality-$index',
            formalExecution: attack.formalExecution,
          );
          final before = _finalizationSnapshot(db, fixture.runId);

          expect(
            () => finalizer.finalize(
              runId: fixture.runId,
              output: _validatedOutput(
                brief: fixture.brief,
                materials: fixture.materials,
                qualityScore: attack.qualityScore,
              ),
              capture: fixture.capture,
              nowMs: 200,
              generationEvidenceReceipt: fixture.receipt,
            ),
            throwsA(isA<StateError>()),
            reason: attack.name,
          );
          expect(
            _finalizationSnapshot(db, fixture.runId),
            before,
            reason: attack.name,
          );
        }
      },
    );

    test(
      'genuine receipt and passing score cannot bypass sealed review history',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
        final fixture = await _startHighLevelFixture(
          ledger: ledger,
          identitySalt: 'empty-review-history',
        );
        final before = _finalizationSnapshot(db, fixture.runId);

        expect(
          () => finalizer.finalize(
            runId: fixture.runId,
            output: _validatedOutput(
              brief: fixture.brief,
              materials: fixture.materials,
              includeReviewHistory: false,
            ),
            capture: fixture.capture,
            nowMs: 200,
            generationEvidenceReceipt: fixture.receipt,
          ),
          throwsA(isA<StateError>()),
        );
        expect(_finalizationSnapshot(db, fixture.runId), before);
      },
    );

    test(
      'sealed initial finalization rejects a pre-staged poisoned namespace',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
        final fixture = await _startHighLevelFixture(
          ledger: ledger,
          identitySalt: 'initial-pending-poison',
        );
        ledger.createWorkingProseRevision(
          WorkingProseRevisionRecord(
            runId: fixture.runId,
            proseRevision: 1,
            proseHash: GenerationLedgerDigest.text('攻击者预置正文'),
            proseText: '攻击者预置正文',
            sourceKind: 'attacker-staged',
            createdAtMs: 130,
          ),
        );
        ledger.reserveCandidateNamespace(
          CandidateNamespaceRecord(
            runId: fixture.runId,
            candidateRevision: 0,
            sourceProseRevision: 1,
            reservedAtMs: 130,
          ),
        );
        ledger.upsertPendingWrite(
          _poisonPendingWrite(
            runId: fixture.runId,
            sceneId: fixture.brief.sceneId,
            candidateRevision: 0,
            writeIdSalt: 'initial',
          ),
        );
        final before = _finalizationSnapshot(db, fixture.runId);

        expect(
          () => finalizer.finalize(
            runId: fixture.runId,
            output: _validatedOutput(
              brief: fixture.brief,
              materials: fixture.materials,
            ),
            capture: fixture.capture,
            nowMs: 200,
            generationEvidenceReceipt: fixture.receipt,
          ),
          throwsA(isA<GenerationLedgerInvariantViolation>()),
        );
        expect(_finalizationSnapshot(db, fixture.runId), before);
      },
    );

    test(
      'sealed author edit rejects inherited staged writes without new effects',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
        final fixture = await _startHighLevelFixture(
          ledger: ledger,
          identitySalt: 'edited-pending-poison',
        );
        ledger.reserveCandidateNamespace(
          CandidateNamespaceRecord(
            runId: fixture.runId,
            candidateRevision: 0,
            sourceProseRevision: 0,
            reservedAtMs: 130,
          ),
        );
        ledger.upsertPendingWrite(
          _poisonPendingWrite(
            runId: fixture.runId,
            sceneId: fixture.brief.sceneId,
            candidateRevision: 0,
            writeIdSalt: 'edited-source',
            writeKind: 'roleplaySession',
            derivationClass: 'preProse',
          ),
        );
        final editedNamespace = ledger.createEditedWorkingRevision(
          runId: fixture.runId,
          sourceCandidateRevision: 0,
          prose: _finalProse,
          nowMs: 150,
        );
        final before = _finalizationSnapshot(db, fixture.runId);

        expect(
          () => finalizer.finalize(
            runId: fixture.runId,
            output: _validatedOutput(
              brief: fixture.brief,
              materials: fixture.materials,
            ),
            capture: fixture.capture,
            nowMs: 200,
            targetCandidateRevision: editedNamespace.candidateRevision,
            generationEvidenceReceipt: fixture.receipt,
          ),
          throwsA(isA<StateError>()),
        );
        expect(_finalizationSnapshot(db, fixture.runId), before);
      },
    );

    test(
      'sealed finalization rolls back every row when ready pointer update faults',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
        final fixture = await _startHighLevelFixture(
          ledger: ledger,
          identitySalt: 'atomic-proof-fault',
        );
        final before = _finalizationSnapshot(db, fixture.runId);
        db.execute('''
          CREATE TRIGGER fail_sealed_ready_pointer
          BEFORE UPDATE OF status ON story_generation_runs
          WHEN NEW.status = 'candidateReady'
          BEGIN SELECT RAISE(ABORT, 'injected sealed pointer failure'); END
        ''');

        expect(
          () => finalizer.finalize(
            runId: fixture.runId,
            output: _validatedOutput(
              brief: fixture.brief,
              materials: fixture.materials,
            ),
            capture: fixture.capture,
            nowMs: 200,
            generationEvidenceReceipt: fixture.receipt,
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(_finalizationSnapshot(db, fixture.runId), before);
      },
    );

    test(
      'validated high-level finalizer supplies both keys and survives restart commit',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
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
          requestId: 'validated-finalizer-request',
          projectId: _projectId,
          chapterId: _chapterId,
          sceneId: _sceneId,
          sceneScopeId: _sceneScopeId,
          baseDraft: _previousDraft,
          brief: brief,
          materials: materials,
          nowMs: 100,
          generationEvidenceMode:
              GenerationCandidateIdentity.sealedNoRedrawMode,
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
        expect(
          db.select('SELECT * FROM story_generation_candidate_proofs'),
          hasLength(1),
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_payloads'),
          hasLength(1),
        );
        expect(
          db.select(
            'SELECT status, current_candidate_revision '
            'FROM story_generation_runs WHERE run_id = ?',
            <Object?>[_runId],
          ).single,
          allOf(
            containsPair('status', 'candidateReady'),
            containsPair('current_candidate_revision', 0),
          ),
        );

        final restartedCoordinator = GenerationCommitCoordinator(db: db)
          ..ensureTables();
        db.execute(
          'INSERT INTO draft_documents '
          '(project_id, text_body, updated_at_ms) VALUES (?, ?, ?)',
          <Object?>[_sceneScopeId, _previousDraft, 200],
        );
        final committed = restartedCoordinator.accept(
          _commitRequestFromCandidate(candidate: candidate, capture: capture),
        );
        expect(committed, isA<GenerationCommitApplied>());
        expect(
          db.select(
            'SELECT text_body FROM draft_documents WHERE project_id = ?',
            <Object?>[_sceneScopeId],
          ).single['text_body'],
          _finalProse,
        );
      },
    );

    test(
      'receipt parser rejects outcome seal text usage model status and hash tampering',
      () async {
        final receipt = await buildGenerationEvidenceReceiptFixture(
          evidenceRunId: 'receipt-admission-seal-tamper-run',
          sceneId: _sceneId,
          generationArmPolicy: _armPolicy,
          preparedBriefDigest: _fieldDigest('seal-tamper-brief'),
          generationBundleHash: generationEvidenceReceiptFixtureBundleHash,
          artifactText: _finalProse,
        );
        final attacks =
            <
              ({
                String name,
                bool recomputeSealHash,
                void Function(
                  Map<String, Object?> seal,
                  Map<String, Object?> outcome,
                )
                mutate,
              })
            >[
              (
                name: 'text digest',
                recomputeSealHash: true,
                mutate: (seal, outcome) {
                  final textUtf8 = Map<String, Object?>.from(
                    seal['textUtf8']! as Map,
                  );
                  textUtf8['digest'] = _fieldDigest('tampered-text');
                  seal['textUtf8'] = textUtf8;
                },
              ),
              (
                name: 'usage',
                recomputeSealHash: true,
                mutate: (seal, outcome) {
                  seal['promptTokens'] = (outcome['promptTokens']! as int) + 1;
                },
              ),
              (
                name: 'provider model',
                recomputeSealHash: true,
                mutate: (seal, outcome) {
                  seal['providerModel'] = 'tampered-provider-model';
                },
              ),
              (
                name: 'success-failure substitution',
                recomputeSealHash: true,
                mutate: (seal, outcome) {
                  seal['succeeded'] = false;
                  seal['failureKind'] = 'server';
                },
              ),
              (
                name: 'seal hash',
                recomputeSealHash: false,
                mutate: (seal, outcome) {
                  outcome['providerOutcomeSealHash'] = _fieldDigest(
                    'tampered-seal-hash',
                  );
                },
              ),
              (
                name: 'unexpected seal key',
                recomputeSealHash: true,
                mutate: (seal, outcome) {
                  seal['callerVerified'] = true;
                },
              ),
            ];

        for (final attack in attacks) {
          final tampered = _tamperProviderOutcomeSeal(
            receipt,
            mutate: attack.mutate,
            recomputeSealHash: attack.recomputeSealHash,
          );
          expect(
            () => GenerationEvidenceReceipt.fromCanonicalJson(tampered),
            throwsA(isA<StateError>()),
            reason: attack.name,
          );
        }
      },
    );
  });
}

const String _runId = 'receipt-admission-run';
const String _projectId = 'receipt-admission-project';
const String _chapterId = 'receipt-admission-chapter';
const String _sceneId = 'receipt-admission-scene';
const String _sceneScopeId =
    'receipt-admission-project::receipt-admission-scene';
const String _armPolicy = 'arm-current-v1';
const String _finalProse =
    '雨水越过锈蚀窗框，落在摊开的账页上。柳溪逐项核对封口编号，指尖停在最后一栏。'
    '“编号没错，封条也没动。”'
    '“那就收好证据，从货箱后面走。”'
    '她把账页收进内袋，沿阴影离开。';
const String _previousDraft = '作者尚未采纳的旧稿。';

final class _Identity {
  const _Identity({
    required this.runId,
    required this.sceneId,
    required this.sceneScopeId,
    required this.generationBundleHash,
    required this.preparedBriefDigest,
    required this.materialDigest,
    required this.inputDigest,
  });

  final String runId;
  final String sceneId;
  final String sceneScopeId;
  final String generationBundleHash;
  final String preparedBriefDigest;
  final String materialDigest;
  final String inputDigest;
}

final class _HighLevelFixture {
  const _HighLevelFixture({
    required this.runId,
    required this.brief,
    required this.materials,
    required this.capture,
    required this.receipt,
  });

  final String runId;
  final SceneBrief brief;
  final ProjectMaterialSnapshot materials;
  final GenerationRunCapture capture;
  final GenerationEvidenceReceipt receipt;
}

Future<_HighLevelFixture> _startHighLevelFixture({
  required GenerationLedgerSqliteStore ledger,
  required String identitySalt,
  bool formalExecution = false,
}) async {
  final runId = '$_runId-$identitySalt';
  final sceneId = '$_sceneId-$identitySalt';
  final sceneScopeId = '$_projectId::$sceneId';
  const materials = ProjectMaterialSnapshot(
    worldFacts: <String>['账页封口编号是可核对的正式证据。'],
  );
  final brief = SceneBrief(
    projectId: _projectId,
    chapterId: _chapterId,
    chapterTitle: '第一章',
    sceneId: sceneId,
    sceneTitle: '账页',
    sceneSummary: '核对账页封口编号并收好证据。',
    targetBeat: '确认封口编号。',
    sceneIndex: 1,
    totalScenesInChapter: 3,
    formalExecution: formalExecution,
  );
  final capture = GenerationLedgerCandidateFinalizer(ledger: ledger).startRun(
    runId: runId,
    requestId: 'validated-finalizer-request-$identitySalt',
    projectId: _projectId,
    chapterId: _chapterId,
    sceneId: sceneId,
    sceneScopeId: sceneScopeId,
    baseDraft: _previousDraft,
    brief: brief,
    materials: materials,
    nowMs: 100,
    generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
    generationArmPolicy: _armPolicy,
  );
  final receipt = await buildGenerationEvidenceReceiptFixture(
    evidenceRunId: runId,
    sceneId: sceneId,
    generationArmPolicy: _armPolicy,
    preparedBriefDigest: capture.preparedBriefDigest,
    generationBundleHash: capture.generationBundleHash,
    artifactText: _finalProse,
  );
  return _HighLevelFixture(
    runId: runId,
    brief: brief,
    materials: materials,
    capture: capture,
    receipt: receipt,
  );
}

Map<String, Object?> _finalizationSnapshot(Database db, String runId) =>
    <String, Object?>{
      'runPointer': Map<String, Object?>.from(
        db.select(
          'SELECT status, phase, current_candidate_revision, '
          'current_prose_revision, updated_at_ms '
          'FROM story_generation_runs WHERE run_id = ?',
          <Object?>[runId],
        ).single,
      ),
      'workingRevisions': _rows(
        db.select(
          'SELECT * FROM story_generation_working_prose_revisions '
          'WHERE run_id = ? ORDER BY prose_revision',
          <Object?>[runId],
        ),
      ),
      'candidateNamespaces': _rows(
        db.select(
          'SELECT * FROM story_generation_candidate_namespaces '
          'WHERE run_id = ? ORDER BY candidate_revision',
          <Object?>[runId],
        ),
      ),
      'pendingWrites': _rows(
        db.select(
          'SELECT * FROM story_generation_pending_writes '
          'WHERE run_id = ? ORDER BY candidate_revision, write_id',
          <Object?>[runId],
        ),
      ),
      'proofs': _rows(
        db.select(
          'SELECT * FROM story_generation_candidate_proofs '
          'WHERE run_id = ? ORDER BY candidate_revision',
          <Object?>[runId],
        ),
      ),
      'payloads': _rows(
        db.select(
          'SELECT * FROM story_generation_candidate_payloads '
          'WHERE run_id = ? ORDER BY candidate_revision',
          <Object?>[runId],
        ),
      ),
      'checkpoints': _rows(
        db.select(
          'SELECT * FROM story_generation_stage_checkpoints '
          'WHERE run_id = ? ORDER BY prose_revision, ordinal, stage_attempt',
          <Object?>[runId],
        ),
      ),
      'checkpointEvidence': _rows(
        db.select(
          'SELECT * FROM story_generation_stage_evidence '
          'WHERE run_id = ? ORDER BY prose_revision, ordinal, stage_attempt',
          <Object?>[runId],
        ),
      ),
    };

List<Map<String, Object?>> _rows(ResultSet rows) => <Map<String, Object?>>[
  for (final row in rows) Map<String, Object?>.from(row),
];

PendingWriteRecord _poisonPendingWrite({
  required String runId,
  required String sceneId,
  required int candidateRevision,
  required String writeIdSalt,
  String writeKind = 'sceneSummaryContribution',
  String derivationClass = 'proseDerived',
}) {
  final payloadJson = GenerationLedgerDigest.canonicalJson(<String, Object?>{
    'kind': writeKind,
    'schemaVersion': 1,
    'projectId': _projectId,
    'chapterId': _chapterId,
    'sceneId': sceneId,
    'target': <String, Object?>{
      'projectId': _projectId,
      'chapterId': _chapterId,
      'sceneId': sceneId,
    },
    if (writeKind == 'sceneSummaryContribution')
      'contribution': <String, Object?>{
        'sceneId': sceneId,
        'prose': '攻击者预置的连续性内容。',
      }
    else
      'session': const <String, Object?>{},
  });
  return PendingWriteRecord(
    runId: runId,
    candidateRevision: candidateRevision,
    writeId: GenerationLedgerDigest.text('poison-write-$writeIdSalt'),
    projectId: _projectId,
    chapterId: _chapterId,
    sceneId: sceneId,
    logicalEntityId: sceneId,
    writeKind: writeKind,
    payloadHash: GenerationLedgerDigest.text(payloadJson),
    payloadJson: payloadJson,
    derivationClass: derivationClass,
    producer: 'attacker',
    createdAtMs: 130,
    expiresAtMs: 1000,
  );
}

_Identity _seedRun(
  GenerationLedgerSqliteStore ledger, {
  required String identitySalt,
  List<int> candidateRevisions = const <int>[0],
}) {
  final runId = '$_runId-$identitySalt';
  final sceneId = '$_sceneId-$identitySalt';
  final sceneScopeId = '$_projectId::$sceneId';
  final generationBundleHash = generationEvidenceReceiptFixtureBundleHash;
  createAgentEvaluationTables(ledger.db);
  ledger.db.execute(
    '''INSERT INTO generation_bundles
       (bundle_hash, bundle_id, releases_json, created_at_ms)
       VALUES (?, ?, ?, ?)''',
    <Object?>[
      generationBundleHash.substring('sha256:'.length),
      'receipt-admission-bundle',
      '[]',
      100,
    ],
  );
  ledger.createRunWithGenerationBundle(
    run: GenerationRunRecord(
      runId: runId,
      requestId: 'receipt-admission-request-$identitySalt',
      projectId: _projectId,
      chapterId: _chapterId,
      sceneId: sceneId,
      sceneScopeId: sceneScopeId,
      status: 'running',
      phase: 'finalization',
      schemaVersion: 9,
      createdAtMs: 100,
      updatedAtMs: 100,
    ),
    generationBundleHash: generationBundleHash,
    createdAtMs: 100,
  );
  for (final candidateRevision in candidateRevisions) {
    ledger.createWorkingProseRevision(
      WorkingProseRevisionRecord(
        runId: runId,
        proseRevision: candidateRevision,
        proseHash: GenerationLedgerDigest.text(_finalProse),
        proseText: _finalProse,
        sourceKind: candidateRevision == 0
            ? 'provider-sealed'
            : 'restart-replay-probe',
        createdAtMs: 110 + candidateRevision,
      ),
    );
    ledger.reserveCandidateNamespace(
      CandidateNamespaceRecord(
        runId: runId,
        candidateRevision: candidateRevision,
        sourceProseRevision: candidateRevision,
        reservedAtMs: 120 + candidateRevision,
      ),
    );
  }
  return _Identity(
    runId: runId,
    sceneId: sceneId,
    sceneScopeId: sceneScopeId,
    generationBundleHash: generationBundleHash,
    preparedBriefDigest: _fieldDigest('prepared-brief-$identitySalt'),
    materialDigest: _fieldDigest('material'),
    inputDigest: _fieldDigest('input'),
  );
}

Future<GenerationEvidenceReceipt> _receipt(_Identity identity) =>
    buildGenerationEvidenceReceiptFixture(
      evidenceRunId: identity.runId,
      sceneId: identity.sceneId,
      generationArmPolicy: _armPolicy,
      preparedBriefDigest: identity.preparedBriefDigest,
      generationBundleHash: identity.generationBundleHash,
      artifactText: _finalProse,
    );

CandidateProofRecord _proof({
  required _Identity identity,
  required GenerationEvidenceReceipt receipt,
  int candidateRevision = 0,
  String finalProse = _finalProse,
}) {
  final finalProseHash = GenerationLedgerDigest.text(finalProse);
  final deterministicHash = _fieldDigest('deterministic');
  final councilHash = _fieldDigest('council');
  final qualityHash = _fieldDigest('quality');
  final pendingWriteSetHash = GenerationLedgerDigest.object(const <Object?>[]);
  final candidateHash = GenerationCandidateIdentity.computeV2(
    runId: identity.runId,
    candidateRevision: candidateRevision,
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
    runId: identity.runId,
    candidateRevision: candidateRevision,
    projectId: _projectId,
    chapterId: _chapterId,
    sceneId: identity.sceneId,
    sourceProseRevision: candidateRevision,
    candidateHash: candidateHash,
    finalProseHash: finalProseHash,
    deterministicGateEvidenceHash: deterministicHash,
    finalCouncilEvidenceHash: councilHash,
    qualityEvidenceHash: qualityHash,
    pendingWriteSetHash: pendingWriteSetHash,
    materialDigest: identity.materialDigest,
    inputDigest: identity.inputDigest,
    createdAtMs: 150 + candidateRevision,
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

CandidatePayloadRecord _payload(
  _Identity identity,
  GenerationEvidenceReceipt receipt,
) => CandidatePayloadRecord(
  runId: identity.runId,
  candidateRevision: 0,
  finalProse: _finalProse,
  pendingWriteManifestJson: '[]',
  generationEvidenceReceiptJson: receipt.canonicalJson,
  createdAtMs: 150,
  expiresAtMs: 1000,
);

SceneRuntimeOutput _validatedOutput({
  required SceneBrief brief,
  required ProjectMaterialSnapshot materials,
  SceneQualityScore qualityScore = const SceneQualityScore(
    overall: 96,
    prose: 96,
    coherence: 96,
    character: 96,
    completeness: 96,
    summary: '达到发布线。',
  ),
  bool includeReviewHistory = true,
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
    reviewAttempts: includeReviewHistory
        ? <SceneReviewAttempt>[
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
          ]
        : const <SceneReviewAttempt>[],
    proseAttempts: 1,
    softFailureCount: 0,
    qualityScore: qualityScore,
    polishCanonEvidence: preQuality.polishCanonEvidence,
    storyMechanicsEvidence: preQuality.storyMechanicsEvidence,
    productionPreQualityEvidence: preQuality.toJson(),
  );
}

String _reviewProseHash(String value) => GenerationLedgerDigest.object(
  <String, Object?>{'text': value},
).substring('sha256:'.length);

GenerationCommitRequest _commitRequestFromCandidate({
  required DurableCandidateReference candidate,
  required GenerationRunCapture capture,
}) => GenerationCommitRequest(
  acceptIdempotencyKey: 'receipt-admission-accept',
  runId: _runId,
  candidateRevision: 0,
  projectId: _projectId,
  sceneScopeId: _sceneScopeId,
  candidateHash: candidate.candidateHash,
  expectedBaseDraftHash: GenerationCommitDigest.text(_previousDraft),
  expectedMaterialDigest: capture.materialDigest,
  expectedInputDigest: candidate.inputDigest,
  expectedFinalProseHash: candidate.finalProseHash,
  expectedDeterministicGateEvidenceHash:
      candidate.deterministicGateEvidenceHash,
  expectedFinalCouncilEvidenceHash: candidate.finalCouncilEvidenceHash,
  expectedQualityEvidenceHash: candidate.qualityEvidenceHash,
  expectedPendingWriteSetHash: candidate.pendingWriteSetHash,
  committedAtMs: 300,
);

String _recomputePublicReceiptHash(GenerationEvidenceReceipt receipt) {
  final payload = receipt.toJson()..remove('receiptHash');
  final recomputed = <String, Object?>{
    ...payload,
    'receiptHash': AppLlmCanonicalHash.domainHash(
      GenerationEvidenceReceipt.receiptDomainTag,
      payload,
    ),
  };
  return AppLlmCanonicalHash.canonicalJson(recomputed);
}

String _tamperProviderOutcomeSeal(
  GenerationEvidenceReceipt receipt, {
  required void Function(
    Map<String, Object?> seal,
    Map<String, Object?> outcome,
  )
  mutate,
  required bool recomputeSealHash,
}) {
  final root = Map<String, Object?>.from(
    jsonDecode(receipt.canonicalJson) as Map,
  );
  final private = Map<String, Object?>.from(root['private']! as Map);
  final outcomes = List<Object?>.from(private['outcomes']! as List);
  final outcome = Map<String, Object?>.from(outcomes.last! as Map);
  final seal = Map<String, Object?>.from(
    outcome['providerOutcomeSeal']! as Map,
  );
  mutate(seal, outcome);
  outcome['providerOutcomeSeal'] = seal;
  if (recomputeSealHash) {
    outcome['providerOutcomeSealHash'] = appLlmProviderOutcomeSealDigest(seal);
  }
  final outcomePayload = Map<String, Object?>.from(outcome)
    ..remove('sequenceNo')
    ..remove('attemptEvidenceDigest');
  outcome['attemptEvidenceDigest'] = AppLlmCanonicalHash.domainHash(
    'story-generation-attempt-evidence-record-v1',
    outcomePayload,
  );
  outcomes[outcomes.length - 1] = outcome;
  private['outcomes'] = outcomes;
  root['private'] = private;
  return AppLlmCanonicalHash.canonicalJson(root);
}

String _fieldDigest(String field) =>
    GenerationLedgerDigest.object(<String, Object?>{'field': field});
