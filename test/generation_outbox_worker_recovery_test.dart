import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:novel_writer/features/story_generation/data/generation_outbox_worker.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;
  late GenerationLedgerSqliteStore ledger;
  late _FakeTime time;
  late GenerationOutboxWorker worker;

  setUp(() async {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
    _seedReceiptOutbox(ledger, db);
    final retriever = HybridRetriever.local(db: db);
    await retriever.ftsStorage.ensureTables();
    time = _FakeTime(100);
    worker = GenerationOutboxWorker(
      ledger: ledger,
      db: db,
      retriever: retriever,
      leaseDurationMs: 20,
      clock: time.now,
      delay: time.delay,
    );
  });

  tearDown(() => db.dispose());

  test('waits for an old lease then completes the same receipt', () async {
    expect(
      ledger.claimDueOutbox(
        leaseOwner: 'old-worker',
        nowMs: 100,
        leaseDurationMs: 30,
      ),
      hasLength(1),
    );
    ledger.enqueueOutbox(
      const GenerationOutboxRecord(
        operationKey: 'unrelated',
        runId: 'run-1',
        projectId: 'project-1',
        entityId: 'project-1::scene-1',
        operation: 'unknown_operation',
        payloadJson: '{}',
        createdAtMs: 1,
        updatedAtMs: 1,
      ),
    );

    await worker.drainUntilCompleted(
      receiptId: 'receipt-1',
      leaseOwner: 'recovery-worker',
      deadlineAtMs: 200,
      pollIntervalMs: 10,
    );

    final row = _outboxRow(db);
    expect(row['state'], 'completed');
    expect(row['attempt_count'], 2);
    expect(time.value, 130);
    expect(
      db
          .select(
            'SELECT state FROM story_generation_outbox '
            "WHERE operation_key = 'unrelated'",
          )
          .single['state'],
      'pending',
    );
  });

  test('waits through persisted failed backoff then retries', () async {
    db.execute('''UPDATE story_generation_outbox
         SET state = 'failed', attempt_count = 1,
             next_attempt_at_ms = 145,
             last_error_code = 'derived_index_failed' ''');

    await worker.drainUntilCompleted(
      receiptId: 'receipt-1',
      leaseOwner: 'recovery-worker',
      deadlineAtMs: 200,
      pollIntervalMs: 10,
    );

    final row = _outboxRow(db);
    expect(row['state'], 'completed');
    expect(row['attempt_count'], 2);
    expect(row['last_error_code'], isNull);
    expect(time.value, 145);
  });

  test('frozen deadline throws typed recoverable timeout', () async {
    expect(
      ledger.claimDueOutbox(
        leaseOwner: 'old-worker',
        nowMs: 100,
        leaseDurationMs: 100,
      ),
      hasLength(1),
    );

    await expectLater(
      worker.drainUntilCompleted(
        receiptId: 'receipt-1',
        leaseOwner: 'recovery-worker',
        deadlineAtMs: 125,
        pollIntervalMs: 10,
      ),
      throwsA(
        isA<GenerationOutboxDrainTimeoutException>()
            .having((error) => error.recoverable, 'recoverable', isTrue)
            .having((error) => error.receiptId, 'receiptId', 'receipt-1')
            .having((error) => error.deadlineAtMs, 'deadlineAtMs', 125),
      ),
    );

    expect(_outboxRow(db)['state'], 'leased');
    expect(time.value, 125);
    expect(db.select('SELECT * FROM rag_documents'), isEmpty);
  });
}

Row _outboxRow(Database db) =>
    db.select('''SELECT state, attempt_count, last_error_code
     FROM story_generation_outbox
     WHERE operation_key = 'index:receipt-1' ''').single;

void _seedReceiptOutbox(GenerationLedgerSqliteStore ledger, Database db) {
  ledger.createRun(
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
      createdAtMs: 1,
      updatedAtMs: 1,
    ),
  );
  ledger.createWorkingProseRevision(
    const WorkingProseRevisionRecord(
      runId: 'run-1',
      proseRevision: 0,
      proseHash: 'prose-hash',
      proseText: '作者采纳后的索引正文',
      sourceKind: 'editorial',
      createdAtMs: 1,
    ),
  );
  ledger.reserveCandidateNamespace(
    const CandidateNamespaceRecord(
      runId: 'run-1',
      candidateRevision: 0,
      sourceProseRevision: 0,
      reservedAtMs: 1,
    ),
  );
  ledger.createCandidateProof(
    const CandidateProofRecord(
      runId: 'run-1',
      candidateRevision: 0,
      projectId: 'project-1',
      chapterId: 'chapter-1',
      sceneId: 'scene-1',
      sourceProseRevision: 0,
      candidateHash: 'candidate-hash',
      finalProseHash: 'prose-hash',
      deterministicGateEvidenceHash: 'gate-hash',
      finalCouncilEvidenceHash: 'council-hash',
      qualityEvidenceHash: 'quality-hash',
      pendingWriteSetHash: 'pending-hash',
      materialDigest: 'material-digest',
      inputDigest: 'input-digest',
      createdAtMs: 2,
    ),
  );
  ledger.saveCandidatePayload(
    const CandidatePayloadRecord(
      runId: 'run-1',
      candidateRevision: 0,
      finalProse: '作者采纳后的索引正文',
      pendingWriteManifestJson: '[]',
      createdAtMs: 2,
      expiresAtMs: 999999,
    ),
  );
  ledger.createCommitReceipt(
    const CommitReceiptRecord(
      receiptId: 'receipt-1',
      acceptIdempotencyKey: 'accept-1',
      runId: 'run-1',
      candidateRevision: 0,
      sceneScopeId: 'project-1::scene-1',
      committedCandidateHash: 'candidate-hash',
      previousDraftHash: 'draft-old',
      committedDraftHash: 'draft-new',
      pendingWriteSetHash: 'pending-hash',
      versionId: 'version-1',
      versionContentHash: 'version-hash',
      committedAtMs: 3,
    ),
  );
  db.execute("UPDATE story_generation_runs SET status = 'committed'");
  ledger.enqueueOutbox(
    const GenerationOutboxRecord(
      operationKey: 'index:receipt-1',
      runId: 'run-1',
      projectId: 'project-1',
      entityId: 'project-1::scene-1',
      operation: 'index_committed_scene',
      payloadJson: '{}',
      sourceReceiptId: 'receipt-1',
      createdAtMs: 3,
      updatedAtMs: 3,
    ),
  );
}

class _FakeTime {
  _FakeTime(this.value);

  int value;

  int now() => value;

  Future<void> delay(Duration duration) async {
    value += duration.inMilliseconds;
  }
}
