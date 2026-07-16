import 'package:sqlite3/sqlite3.dart';

import '../../../app/rag/hybrid_retriever.dart';
import '../domain/contracts/memory_policy.dart';
import '../domain/memory_models.dart';
import 'generation_ledger.dart';
import 'generation_ledger_models.dart';

typedef GenerationOutboxClock = int Function();
typedef GenerationOutboxDelay = Future<void> Function(Duration duration);

/// The receipt is still recoverable, but its derived work did not finish
/// before the caller's immutable deadline. Callers may retry this same
/// receipt; they must not replay the provider request or author acceptance.
class GenerationOutboxDrainTimeoutException implements Exception {
  GenerationOutboxDrainTimeoutException({
    required this.receiptId,
    required this.deadlineAtMs,
    required Iterable<String> pendingStates,
  }) : pendingStates = List<String>.unmodifiable(pendingStates);

  final String receiptId;
  final int deadlineAtMs;
  final List<String> pendingStates;

  bool get recoverable => true;

  @override
  String toString() =>
      'GenerationOutboxDrainTimeoutException('
      'receiptId: $receiptId, deadlineAtMs: $deadlineAtMs, '
      'pendingStates: ${pendingStates.join(',')})';
}

/// Processes receipt-bound derived work without participating in author
/// acceptance. A failed index operation remains retryable and can never roll
/// back an already committed draft/receipt.
class GenerationOutboxWorker {
  GenerationOutboxWorker({
    required GenerationLedgerSqliteStore ledger,
    required Database db,
    required HybridRetriever retriever,
    this.leaseDurationMs = 60 * 1000,
    GenerationOutboxClock? clock,
    GenerationOutboxDelay? delay,
  }) : _ledger = ledger,
       _db = db,
       _retriever = retriever,
       _clock = clock ?? _systemClock,
       _delay = delay ?? _systemDelay;

  final GenerationLedgerSqliteStore _ledger;
  final Database _db;
  final HybridRetriever _retriever;
  final int leaseDurationMs;
  final GenerationOutboxClock _clock;
  final GenerationOutboxDelay _delay;

  static int _systemClock() => DateTime.now().millisecondsSinceEpoch;

  static Future<void> _systemDelay(Duration duration) =>
      Future<void>.delayed(duration);

  /// Best-effort entry point for fire-and-forget callers. Author acceptance is
  /// already durable before derived indexing starts, so shutdown or a closed
  /// database must leave the outbox row for lease recovery instead of raising
  /// an uncaught asynchronous error.
  Future<int> drainSafely({
    required String leaseOwner,
    int? nowMs,
    int maxItems = 16,
  }) async {
    try {
      return await drain(
        leaseOwner: leaseOwner,
        nowMs: nowMs,
        maxItems: maxItems,
      );
    } on Object {
      return 0;
    }
  }

  Future<int> drain({
    required String leaseOwner,
    int? nowMs,
    int maxItems = 16,
    String? sourceReceiptId,
  }) async {
    final now = nowMs ?? _clock();
    final jobs = _ledger.claimDueOutbox(
      leaseOwner: leaseOwner,
      nowMs: now,
      leaseDurationMs: leaseDurationMs,
      maxItems: maxItems,
      sourceReceiptId: sourceReceiptId,
    );
    for (final job in jobs) {
      try {
        await _dispatch(job);
        _ledger.completeOutbox(
          operationKey: job.operationKey,
          leaseOwner: leaseOwner,
          completedAtMs: _clock(),
        );
      } on Object {
        final attempt = job.attemptCount.clamp(1, 10);
        final backoffMs = 1000 * (1 << (attempt - 1));
        final failedAtMs = _clock();
        _ledger.retryOutbox(
          operationKey: job.operationKey,
          leaseOwner: leaseOwner,
          errorCode: 'derived_index_failed',
          nextAttemptAtMs: failedAtMs + backoffMs,
          updatedAtMs: failedAtMs,
        );
      }
    }
    return jobs.length;
  }

  /// Recovers only when every outbox row bound to [receiptId] is completed.
  ///
  /// The method waits through an older worker's lease and persisted retry
  /// backoff, periodically attempting a normal atomic drain. It never calls
  /// [drainSafely], so database/invariant failures remain visible. The frozen
  /// [deadlineAtMs] is never extended; reaching it throws a typed recoverable
  /// exception so the same receipt can be resumed without provider replay.
  Future<void> drainUntilCompleted({
    required String receiptId,
    required String leaseOwner,
    required int deadlineAtMs,
    int pollIntervalMs = 100,
  }) async {
    if (receiptId.trim().isEmpty || deadlineAtMs <= 0 || pollIntervalMs <= 0) {
      throw ArgumentError('outbox recovery arguments are invalid');
    }
    var rows = _receiptRows(receiptId);

    while (!_allCompleted(rows)) {
      final now = _clock();
      if (now >= deadlineAtMs) {
        throw _timeout(receiptId, deadlineAtMs, rows);
      }

      await drain(
        leaseOwner: leaseOwner,
        nowMs: now,
        sourceReceiptId: receiptId,
      );
      rows = _receiptRows(receiptId);
      if (_allCompleted(rows)) return;

      final afterDrainMs = _clock();
      if (afterDrainMs >= deadlineAtMs) {
        throw _timeout(receiptId, deadlineAtMs, rows);
      }
      final nextEligibleAtMs = _nextEligibleAtMs(rows);
      final regularPollAtMs = afterDrainMs + pollIntervalMs;
      final boundedEligibleAtMs = nextEligibleAtMs > afterDrainMs
          ? nextEligibleAtMs
          : regularPollAtMs;
      final wakeAtMs = <int>[
        deadlineAtMs,
        regularPollAtMs,
        boundedEligibleAtMs,
      ].reduce((left, right) => left < right ? left : right);
      await _delay(Duration(milliseconds: wakeAtMs - afterDrainMs));
      rows = _receiptRows(receiptId);
    }
  }

  List<Row> _receiptRows(String receiptId) {
    final rows = _db.select(
      '''SELECT operation_key, state, lease_expires_at_ms, next_attempt_at_ms,
                last_error_code
         FROM story_generation_outbox
         WHERE source_receipt_id = ?
         ORDER BY operation_key''',
      [receiptId],
    );
    if (rows.isEmpty) {
      throw const GenerationLedgerInvariantViolation(
        'outbox receipt has no derived work',
      );
    }
    return rows;
  }

  bool _allCompleted(List<Row> rows) =>
      rows.isNotEmpty && rows.every((row) => row['state'] == 'completed');

  int _nextEligibleAtMs(List<Row> rows) => rows
      .where((row) => row['state'] != 'completed')
      .map((row) {
        if (row['state'] == 'leased') {
          return row['lease_expires_at_ms'] as int;
        }
        return row['next_attempt_at_ms'] as int;
      })
      .reduce((left, right) => left < right ? left : right);

  GenerationOutboxDrainTimeoutException _timeout(
    String receiptId,
    int deadlineAtMs,
    List<Row> rows,
  ) => GenerationOutboxDrainTimeoutException(
    receiptId: receiptId,
    deadlineAtMs: deadlineAtMs,
    pendingStates: rows
        .where((row) => row['state'] != 'completed')
        .map(
          (row) =>
              '${row['operation_key']}:${row['state']}:'
              '${row['last_error_code'] ?? ''}',
        ),
  );

  Future<void> _dispatch(GenerationOutboxRecord job) async {
    if (job.operation != 'index_committed_scene') {
      throw const GenerationLedgerInvariantViolation(
        'unknown outbox operation',
      );
    }
    final receiptId = job.sourceReceiptId;
    if (receiptId == null || receiptId.isEmpty) {
      throw const GenerationLedgerInvariantViolation(
        'outbox receipt is missing',
      );
    }
    final rows = _db.select(
      '''SELECT cp.final_prose, r.candidate_revision
         FROM story_generation_commit_receipts r
         JOIN story_generation_candidate_payloads cp
           ON cp.run_id = r.run_id
          AND cp.candidate_revision = r.candidate_revision
         WHERE r.receipt_id = ? AND r.run_id = ?''',
      [receiptId, job.runId],
    );
    if (rows.length != 1) {
      throw const GenerationLedgerInvariantViolation(
        'outbox receipt does not resolve to one committed candidate',
      );
    }
    final newest = _db.select(
      '''SELECT r.receipt_id
         FROM story_generation_commit_receipts r
         JOIN story_generation_runs run ON run.run_id = r.run_id
         WHERE run.project_id = ? AND run.scene_scope_id = ?
         ORDER BY r.committed_at_ms DESC, r.receipt_id DESC LIMIT 1''',
      [job.projectId, job.entityId],
    );
    if (newest.length != 1) {
      throw const GenerationLedgerInvariantViolation(
        'outbox scene receipt is missing',
      );
    }
    // A delayed worker must not let an old receipt overwrite the searchable
    // chunk for a newer author-accepted scene revision.
    if (newest.single['receipt_id'] != receiptId) return;
    final prose = rows.single['final_prose'] as String;
    await _retriever.indexChunks([
      StoryMemoryChunk(
        id: '${job.projectId}/scenes/${job.entityId}',
        projectId: job.projectId,
        scopeId: job.entityId,
        kind: MemorySourceKind.sceneSummary,
        content: prose,
        tier: MemoryTier.scene,
        producer: 'generation-outbox',
        tags: const ['committed', 'scene'],
        priority: 5,
        createdAtMs: job.createdAtMs,
      ),
    ]);
  }
}
