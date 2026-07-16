import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_digest.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:novel_writer/features/story_generation/data/generation_outbox_worker.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;
  late GenerationLedgerSqliteStore store;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    store = GenerationLedgerSqliteStore(db: db)..ensureTables();
  });

  tearDown(() => db.dispose());

  group('GenerationLedgerSqliteStore', () {
    test('keeps the canonical digest wire contract byte-for-byte stable', () {
      final first = <String, Object?>{
        'z': <Object?>[
          '汉字\r\n第二行',
          <String, Object?>{'β': true, 'a': 1},
        ],
        'a': <String, Object?>{'last': null, 'first': '值'},
      };
      final reordered = <String, Object?>{
        'a': <String, Object?>{'first': '值', 'last': null},
        'z': <Object?>[
          '汉字\r\n第二行',
          <String, Object?>{'a': 1, 'β': true},
        ],
      };

      const wire =
          '{"a":{"first":"值","last":null},'
          '"z":["汉字\\r\\n第二行",{"a":1,"β":true}]}';
      const wireHash =
          'sha256:60031179890f1d9c5b9cd1efaa5e75482cbab396a5ba078a5389c540b60423e6';
      const normalizedTextHash =
          'sha256:61f8655a9b219b9ce122c6c7cd59ad09feac38240699cfec8d0c9b1e81a748ab';

      expect(GenerationLedgerDigest.canonicalJson(first), wire);
      expect(GenerationLedgerDigest.canonicalJson(reordered), wire);
      expect(GenerationLedgerDigest.object(first), wireHash);
      expect(GenerationLedgerDigest.object(reordered), wireHash);
      expect(GenerationPendingWritePayloadIntegrity.canonicalJson(first), wire);
      expect(
        GenerationPendingWritePayloadIntegrity.hashCanonicalJson(wire),
        wireHash,
      );
      expect(
        GenerationPendingWritePayloadIntegrity.hashValue(reordered),
        wireHash,
      );
      expect(
        () => GenerationPendingWritePayloadIntegrity.hashCanonicalJson('[]'),
        throwsFormatException,
      );
      expect(GenerationLedgerDigest.text('第一行\r\n第二行'), normalizedTextHash);
      expect(GenerationLedgerDigest.text('第一行\n第二行'), normalizedTextHash);
    });

    test(
      'retains permanent proof and receipt when its TTL payload is removed',
      () {
        _seedCandidate(store);
        store.saveCandidatePayload(_payload());
        final receipt = _receipt();
        store.createCommitReceipt(receipt);

        expect(store.deleteExpiredCandidatePayloads(nowMs: 201), 1);
        expect(
          db.select('SELECT * FROM story_generation_candidate_proofs'),
          hasLength(1),
        );
        expect(
          db.select('SELECT * FROM story_generation_commit_receipts'),
          hasLength(1),
        );
        expect(
          () => db.execute(
            'UPDATE story_generation_candidate_proofs '
            "SET candidate_hash = 'changed'",
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(
          () => db.execute('DELETE FROM story_generation_candidate_proofs'),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      'retention sweep preserves proof and receipt while charging abandoned budget',
      () {
        _seedCandidate(store);
        store.saveCandidatePayload(_payload());
        store.upsertPendingWrite(_pendingWrite());
        store.createCommitReceipt(_receipt());
        store.initializeBudget(
          const RunBudgetRecord(
            runId: 'run-1',
            maxCalls: 2,
            maxTokens: 200,
            maxCostMicrousd: 2000,
            updatedAtMs: 100,
          ),
        );
        store.reserveBudget(
          _reservation(
            providerRequestId: 'crashed-provider-request',
            reservationId: 'crashed-reservation',
          ),
        );

        final report = store.sweepRetention(nowMs: 201);

        expect(report.deletedCandidatePayloads, 1);
        expect(report.deletedPendingWrites, 1);
        expect(report.abandonedReservations, 1);
        expect(
          db.select('SELECT * FROM story_generation_candidate_proofs'),
          hasLength(1),
        );
        expect(
          db.select('SELECT * FROM story_generation_commit_receipts'),
          hasLength(1),
        );
        expect(
          db.select('SELECT * FROM story_generation_candidate_payloads'),
          isEmpty,
        );
        expect(
          db.select('SELECT * FROM story_generation_pending_writes'),
          isEmpty,
        );
        final reservation = db.select('''
          SELECT state, actual_calls, actual_tokens, actual_cost_microusd
          FROM story_generation_budget_reservations
        ''').single;
        expect(reservation['state'], 'abandonedCharged');
        expect(reservation['actual_calls'], 1);
        expect(reservation['actual_tokens'], 100);
        expect(reservation['actual_cost_microusd'], 1000);
        final budget = db.select('''
          SELECT reserved_calls, used_calls, reserved_tokens, used_tokens,
                 reserved_cost_microusd, used_cost_microusd
          FROM story_generation_run_budgets
        ''').single;
        expect(budget['reserved_calls'], 0);
        expect(budget['used_calls'], 1);
        expect(budget['reserved_tokens'], 0);
        expect(budget['used_tokens'], 100);
        expect(budget['reserved_cost_microusd'], 0);
        expect(budget['used_cost_microusd'], 1000);
      },
    );

    test(
      'rolls proof creation back if finalization payload validation fails',
      () {
        _seedRunAndNamespace(store);

        expect(
          () => store.finalizeCandidate(
            proof: _proof(),
            payload: const CandidatePayloadRecord(
              runId: 'run-1',
              candidateRevision: 0,
              finalProse: '',
              pendingWriteManifestJson: '[]',
              createdAtMs: 100,
              expiresAtMs: 200,
            ),
          ),
          throwsA(isA<SqliteException>()),
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

    test('keeps pending writes namespace-local and rejects payload drift', () {
      _seedRunAndNamespace(store);
      final write = _pendingWrite();
      store.upsertPendingWrite(write);
      store.upsertPendingWrite(write);

      expect(
        db.select('SELECT * FROM story_generation_pending_writes'),
        hasLength(1),
      );
      expect(
        () => store.upsertPendingWrite(
          PendingWriteRecord(
            runId: write.runId,
            candidateRevision: write.candidateRevision,
            writeId: write.writeId,
            projectId: write.projectId,
            chapterId: write.chapterId,
            sceneId: write.sceneId,
            logicalEntityId: write.logicalEntityId,
            writeKind: write.writeKind,
            payloadHash: 'hash-different',
            payloadJson: write.payloadJson,
            derivationClass: write.derivationClass,
            createdAtMs: write.createdAtMs,
            expiresAtMs: write.expiresAtMs,
          ),
        ),
        throwsA(isA<GenerationLedgerInvariantViolation>()),
      );
      expect(
        () => store.upsertPendingWrite(
          PendingWriteRecord(
            runId: write.runId,
            candidateRevision: write.candidateRevision,
            writeId: 'write-foreign-project',
            projectId: 'project-other',
            chapterId: write.chapterId,
            sceneId: write.sceneId,
            logicalEntityId: 'entity-foreign',
            writeKind: write.writeKind,
            payloadHash: 'hash-foreign',
            payloadJson: '{}',
            derivationClass: write.derivationClass,
            createdAtMs: write.createdAtMs,
            expiresAtMs: write.expiresAtMs,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rolls back budget counters when reservation insert faults', () {
      _seedRunAndNamespace(store);
      store.initializeBudget(
        const RunBudgetRecord(
          runId: 'run-1',
          maxCalls: 3,
          maxTokens: 300,
          maxCostMicrousd: 3000,
          updatedAtMs: 100,
        ),
      );
      final first = _reservation(
        providerRequestId: 'request-1',
        reservationId: 'reservation-1',
      );
      store.reserveBudget(first);

      expect(
        () => store.reserveBudget(
          _reservation(
            providerRequestId: 'request-2',
            reservationId: 'reservation-1',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
      final counters = db.select('''
            SELECT reserved_calls, reserved_tokens, reserved_cost_microusd
            FROM story_generation_run_budgets WHERE run_id = 'run-1'
          ''').single;
      expect(counters['reserved_calls'], 1);
      expect(counters['reserved_tokens'], 100);
      expect(counters['reserved_cost_microusd'], 1000);

      final settled = store.settleBudget(
        runId: 'run-1',
        providerRequestId: 'request-1',
        actualCalls: 1,
        actualTokens: 80,
        actualCostMicrousd: 800,
        settledAtMs: 200,
      );
      expect(settled.state, 'settled');
      final usage = db.select('''
            SELECT reserved_calls, used_calls, reserved_tokens, used_tokens,
              reserved_cost_microusd, used_cost_microusd
            FROM story_generation_run_budgets WHERE run_id = 'run-1'
          ''').single;
      expect(usage['reserved_calls'], 0);
      expect(usage['used_calls'], 1);
      expect(usage['reserved_tokens'], 0);
      expect(usage['used_tokens'], 80);
      expect(usage['reserved_cost_microusd'], 0);
      expect(usage['used_cost_microusd'], 800);
    });

    test(
      'enforces run budget caps and makes repeated reservation idempotent',
      () {
        _seedRunAndNamespace(store);
        store.initializeBudget(
          const RunBudgetRecord(
            runId: 'run-1',
            maxCalls: 1,
            maxTokens: 100,
            maxCostMicrousd: 1000,
            updatedAtMs: 100,
          ),
        );
        final request = _reservation(
          providerRequestId: 'request-1',
          reservationId: 'reservation-1',
        );
        expect(store.reserveBudget(request).state, 'reserved');
        expect(store.reserveBudget(request).state, 'reserved');
        expect(
          () => store.reserveBudget(
            _reservation(
              providerRequestId: 'request-2',
              reservationId: 'reservation-2',
            ),
          ),
          throwsA(isA<GenerationBudgetUnavailable>()),
        );
      },
    );

    test('keeps event ordering and outbox operations idempotent', () {
      _seedRunAndNamespace(store);
      store.appendEvent(
        const GenerationEventRecord(
          eventId: 'event-1',
          runId: 'run-1',
          sequenceNo: 0,
          eventType: 'run_started',
          createdAtMs: 100,
        ),
      );
      expect(
        () => store.appendEvent(
          const GenerationEventRecord(
            eventId: 'event-2',
            runId: 'run-1',
            sequenceNo: 0,
            eventType: 'duplicate',
            createdAtMs: 101,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => store.appendEvent(
          const GenerationEventRecord(
            eventId: 'event-3',
            runId: 'run-1',
            sequenceNo: 1,
            eventType: 'unsafe',
            metadataJson: '{"authorization":"secret"}',
            createdAtMs: 102,
          ),
        ),
        throwsA(isA<GenerationLedgerInvariantViolation>()),
      );
      const outbox = GenerationOutboxRecord(
        operationKey: 'outbox-1',
        runId: 'run-1',
        projectId: 'project-1',
        entityId: 'memory-1',
        operation: 'index_memory',
        payloadJson: '{}',
        createdAtMs: 100,
        updatedAtMs: 100,
      );
      store.enqueueOutbox(outbox);
      store.enqueueOutbox(outbox);
      expect(db.select('SELECT * FROM story_generation_outbox'), hasLength(1));
    });

    test('outbox lease is exclusive and expired lease is recoverable', () {
      _seedRunAndNamespace(store);
      const job = GenerationOutboxRecord(
        operationKey: 'lease-job',
        runId: 'run-1',
        projectId: 'project-1',
        entityId: 'project-1::scene-1',
        operation: 'index_committed_scene',
        payloadJson: '{}',
        createdAtMs: 1,
        updatedAtMs: 1,
      );
      store.enqueueOutbox(job);
      expect(
        store.claimDueOutbox(
          leaseOwner: 'worker-a',
          nowMs: 10,
          leaseDurationMs: 50,
        ),
        hasLength(1),
      );
      expect(
        store.claimDueOutbox(
          leaseOwner: 'worker-b',
          nowMs: 10,
          leaseDurationMs: 50,
        ),
        isEmpty,
      );
      final recovered = store.claimDueOutbox(
        leaseOwner: 'worker-b',
        nowMs: 60,
        leaseDurationMs: 50,
      );
      expect(recovered, hasLength(1));
      expect(recovered.single.leaseOwner, 'worker-b');
      expect(recovered.single.attemptCount, 2);
    });

    test(
      'receipt-bound outbox indexes once and completes after durable ack',
      () async {
        _seedCandidate(store);
        store.saveCandidatePayload(
          const CandidatePayloadRecord(
            runId: 'run-1',
            candidateRevision: 0,
            finalProse: '作者采纳后的索引正文',
            pendingWriteManifestJson: '[]',
            createdAtMs: 100,
            expiresAtMs: 999999,
          ),
        );
        store.createCommitReceipt(_receipt());
        db.execute("UPDATE story_generation_runs SET status = 'committed'");
        store.enqueueOutbox(
          const GenerationOutboxRecord(
            operationKey: 'index:receipt-1',
            runId: 'run-1',
            projectId: 'project-1',
            entityId: 'project-1::scene-1',
            operation: 'index_committed_scene',
            payloadJson: '{}',
            sourceReceiptId: 'receipt-1',
            createdAtMs: 100,
            updatedAtMs: 100,
          ),
        );
        final retriever = HybridRetriever.local(db: db);
        await retriever.ftsStorage.ensureTables();
        final worker = GenerationOutboxWorker(
          ledger: store,
          db: db,
          retriever: retriever,
        );

        expect(await worker.drain(leaseOwner: 'indexer', nowMs: 200), 1);
        expect(
          db.select('''
          SELECT state FROM story_generation_outbox
          WHERE operation_key = 'index:receipt-1'
        ''').single['state'],
          'completed',
        );
        expect(
          db.select('''
          SELECT content FROM rag_documents
          WHERE project_id = 'project-1'
            AND path = 'project-1/scenes/project-1::scene-1'
        ''').single['content'],
          '作者采纳后的索引正文',
        );
        expect(await worker.drain(leaseOwner: 'indexer', nowMs: 201), 0);
      },
    );

    test(
      'background outbox shutdown never raises after database close',
      () async {
        final retriever = HybridRetriever.local(db: db);
        final worker = GenerationOutboxWorker(
          ledger: store,
          db: db,
          retriever: retriever,
        );
        db.dispose();

        expect(await worker.drainSafely(leaseOwner: 'shutdown-race'), 0);
      },
    );

    test('author edit creates N+1 and clones only allowlisted pre-prose', () {
      _seedRunAndNamespace(store);
      store.upsertPendingWrite(
        const PendingWriteRecord(
          runId: 'run-1',
          candidateRevision: 0,
          writeId: 'roleplay-0',
          projectId: 'project-1',
          chapterId: 'chapter-1',
          sceneId: 'scene-1',
          logicalEntityId: 'scene-1',
          writeKind: 'roleplaySession',
          payloadHash: 'roleplay-hash',
          payloadJson: '{}',
          derivationClass: 'preProse',
          createdAtMs: 1,
          expiresAtMs: 999,
        ),
      );
      store.upsertPendingWrite(_pendingWrite());
      final namespace = store.createEditedWorkingRevision(
        runId: 'run-1',
        sourceCandidateRevision: 0,
        prose: '作者改稿',
        nowMs: 2,
      );
      expect(namespace.candidateRevision, 1);
      expect(namespace.sourceProseRevision, 1);
      // This lookup is what a restarted UI uses instead of an in-memory edit
      // flag; the reserved N+1 namespace must survive process loss.
      expect(
        store
            .loadUnfinalizedCandidateNamespace(runId: 'run-1')
            ?.candidateRevision,
        1,
      );
      final rows = db.select(
        '''SELECT candidate_revision, write_id, write_kind
        FROM story_generation_pending_writes ORDER BY candidate_revision, write_id''',
      );
      expect(rows, hasLength(3));
      expect(rows.last['candidate_revision'], 1);
      expect(rows.last['write_id'], 'preprose-v2:run-1:1:roleplay-0');
      expect(rows.last['write_kind'], 'roleplaySession');
    });

    test('unknown pre-prose kind fails closed without an N+1 namespace', () {
      _seedRunAndNamespace(store);
      store.upsertPendingWrite(
        const PendingWriteRecord(
          runId: 'run-1',
          candidateRevision: 0,
          writeId: 'unknown-0',
          projectId: 'project-1',
          chapterId: 'chapter-1',
          sceneId: 'scene-1',
          logicalEntityId: 'scene-1',
          writeKind: 'unknown',
          payloadHash: 'x',
          payloadJson: '{}',
          derivationClass: 'preProse',
          createdAtMs: 1,
          expiresAtMs: 999,
        ),
      );
      expect(
        () => store.createEditedWorkingRevision(
          runId: 'run-1',
          sourceCandidateRevision: 0,
          prose: '作者改稿',
          nowMs: 2,
        ),
        throwsA(isA<GenerationLedgerInvariantViolation>()),
      );
      expect(
        db.select('SELECT * FROM story_generation_candidate_namespaces'),
        hasLength(1),
      );
    });

    test('completed checkpoint replay is exact-idempotent and immutable', () {
      _seedRunAndNamespace(store);
      final checkpoint = _completedCheckpoint();
      store.saveStageCheckpoint(checkpoint);
      store.saveStageCheckpoint(checkpoint);

      expect(
        () => store.saveStageCheckpoint(
          _completedCheckpoint(
            artifactDigest: List<String>.filled(64, '9').join(),
            artifactJson: '{"ordinal":0,"value":"rewritten"}',
          ),
        ),
        throwsA(isA<GenerationLedgerInvariantViolation>()),
      );
      final rows = db.select(
        'SELECT artifact_digest, artifact_json FROM story_generation_stage_checkpoints',
      );
      expect(rows, hasLength(1));
      expect(rows.single['artifact_digest'], checkpoint.artifactDigest);
      expect(rows.single['artifact_json'], checkpoint.artifactJson);
      expect(
        db.select('SELECT * FROM story_generation_stage_evidence'),
        hasLength(1),
      );
    });
  });
}

GenerationStageCheckpointRecord _completedCheckpoint({
  String? artifactDigest,
  String artifactJson = '{"ordinal":0,"value":"episode-n"}',
}) => GenerationStageCheckpointRecord(
  runId: 'run-1',
  ordinal: 0,
  stageId: 'editorial',
  stageAttempt: 1,
  codecVersion: 1,
  status: 'completed',
  inputDigest: List<String>.filled(64, '1').join(),
  artifactDigest: artifactDigest ?? List<String>.filled(64, '2').join(),
  upstreamChainDigest: List<String>.filled(64, '3').join(),
  provenance: GenerationCheckpointProvenance(
    baseDraftDigest: List<String>.filled(64, '4').join(),
    materialDigest: List<String>.filled(64, '5').join(),
    promptDigest: List<String>.filled(64, '6').join(),
    modelDigest: List<String>.filled(64, '7').join(),
  ),
  artifactType: 'episode-state',
  artifactJson: artifactJson,
  createdAtMs: 10,
  completedAtMs: 11,
);

void _seedRunAndNamespace(GenerationLedgerSqliteStore store) {
  store.createRun(
    const GenerationRunRecord(
      runId: 'run-1',
      requestId: 'request-1',
      projectId: 'project-1',
      chapterId: 'chapter-1',
      sceneId: 'scene-1',
      sceneScopeId: 'project-1::scene-1',
      status: 'running',
      phase: 'editorial',
      schemaVersion: 9,
      createdAtMs: 100,
      updatedAtMs: 100,
    ),
  );
  store.createWorkingProseRevision(
    const WorkingProseRevisionRecord(
      runId: 'run-1',
      proseRevision: 0,
      proseHash: 'prose-hash-0',
      proseText: '正文',
      sourceKind: 'editorial',
      createdAtMs: 100,
    ),
  );
  store.reserveCandidateNamespace(
    const CandidateNamespaceRecord(
      runId: 'run-1',
      candidateRevision: 0,
      sourceProseRevision: 0,
      reservedAtMs: 100,
    ),
  );
}

void _seedCandidate(GenerationLedgerSqliteStore store) {
  _seedRunAndNamespace(store);
  store.createCandidateProof(_proof());
}

CandidateProofRecord _proof() => const CandidateProofRecord(
  runId: 'run-1',
  candidateRevision: 0,
  projectId: 'project-1',
  chapterId: 'chapter-1',
  sceneId: 'scene-1',
  sourceProseRevision: 0,
  candidateHash: 'candidate-hash',
  finalProseHash: 'prose-hash-0',
  deterministicGateEvidenceHash: 'gate-hash',
  finalCouncilEvidenceHash: 'council-hash',
  qualityEvidenceHash: 'quality-hash',
  pendingWriteSetHash: 'writes-hash',
  materialDigest: 'material-hash',
  inputDigest: 'input-hash',
  createdAtMs: 100,
);

CandidatePayloadRecord _payload() => const CandidatePayloadRecord(
  runId: 'run-1',
  candidateRevision: 0,
  finalProse: '最终正文',
  pendingWriteManifestJson: '[]',
  createdAtMs: 100,
  expiresAtMs: 200,
);

PendingWriteRecord _pendingWrite() => const PendingWriteRecord(
  runId: 'run-1',
  candidateRevision: 0,
  writeId: 'write-1',
  projectId: 'project-1',
  chapterId: 'chapter-1',
  sceneId: 'scene-1',
  logicalEntityId: 'entity-1',
  writeKind: 'thoughtAtom',
  payloadHash: 'payload-hash',
  payloadJson: '{"kind":"thought"}',
  derivationClass: 'proseDerived',
  createdAtMs: 100,
  expiresAtMs: 200,
);

CommitReceiptRecord _receipt() => const CommitReceiptRecord(
  receiptId: 'receipt-1',
  acceptIdempotencyKey: 'accept-1',
  runId: 'run-1',
  candidateRevision: 0,
  sceneScopeId: 'project-1::scene-1',
  committedCandidateHash: 'candidate-hash',
  previousDraftHash: 'draft-old',
  committedDraftHash: 'draft-new',
  versionId: 'version-1',
  versionContentHash: 'version-hash',
  pendingWriteSetHash: 'writes-hash',
  committedAtMs: 200,
);

BudgetReservationRequest _reservation({
  required String providerRequestId,
  required String reservationId,
}) => BudgetReservationRequest(
  runId: 'run-1',
  providerRequestId: providerRequestId,
  reservationId: reservationId,
  reservedCalls: 1,
  reservedTokens: 100,
  reservedCostMicrousd: 1000,
  leaseOwner: 'worker-1',
  leaseExpiresAtMs: 200,
  createdAtMs: 100,
);
