import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../../app/llm/app_llm_canonical_hash.dart';
import '../../../../app/llm/app_llm_response_cache.dart';

final class AgentEvaluationCacheReceiptStore {
  AgentEvaluationCacheReceiptStore({required this.db});

  final Database db;

  static String get releaseHash => AppLlmResponseCache.releaseHash;

  void ensureTables() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS eval_cache_receipts (
        receipt_hash TEXT PRIMARY KEY,
        current_execution_id TEXT NOT NULL,
        current_trial_slot_id TEXT NOT NULL,
        current_attempt_no INTEGER NOT NULL,
        current_run_id TEXT NOT NULL,
        source_execution_id TEXT,
        source_trial_slot_id TEXT,
        source_attempt_no INTEGER,
        source_run_id TEXT,
        disposition TEXT NOT NULL CHECK (disposition IN ('hit','miss')),
        request_hash TEXT NOT NULL,
        response_hash TEXT NOT NULL,
        receipt_json TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        expires_at_ms INTEGER NOT NULL
      )
    ''');
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS eval_cache_receipts_no_update
      BEFORE UPDATE ON eval_cache_receipts
      BEGIN SELECT RAISE(ABORT, 'eval cache receipts are immutable'); END
    ''');
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS eval_cache_receipts_no_delete
      BEFORE DELETE ON eval_cache_receipts
      BEGIN SELECT RAISE(ABORT, 'eval cache receipts are immutable'); END
    ''');
  }

  void append(AppLlmCacheReceipt receipt) {
    ensureTables();
    final value = receipt.toJson();
    final decoded = AppLlmCacheReceipt.fromJson(value);
    final existing = db.select(
      'SELECT receipt_json FROM eval_cache_receipts WHERE receipt_hash = ?',
      <Object?>[decoded.receiptHash],
    );
    final canonical = AppLlmCanonicalHash.canonicalJson(value);
    if (existing.isNotEmpty) {
      if (existing.length == 1 &&
          existing.single['receipt_json'] == canonical) {
        return;
      }
      throw StateError('cache receipt hash already has different evidence');
    }
    db.execute(
      '''INSERT INTO eval_cache_receipts (
           receipt_hash, current_execution_id, current_trial_slot_id,
           current_attempt_no, current_run_id, source_execution_id,
           source_trial_slot_id, source_attempt_no, source_run_id, disposition,
           request_hash, response_hash, receipt_json, created_at_ms, expires_at_ms
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      <Object?>[
        decoded.receiptHash,
        value['currentExecutionId'],
        value['currentTrialSlotId'],
        value['currentAttemptNo'],
        value['currentRunId'],
        value['sourceExecutionId'],
        value['sourceTrialSlotId'],
        value['sourceAttemptNo'],
        value['sourceRunId'],
        value['disposition'],
        value['requestHash'],
        value['responseHash'],
        canonical,
        value['createdAtMs'],
        value['expiresAtMs'],
      ],
    );
  }

  List<AppLlmCacheReceipt> forAttempt({
    required String executionId,
    required String trialSlotId,
    required int attemptNo,
    required String runId,
  }) {
    ensureTables();
    return <AppLlmCacheReceipt>[
      for (final row in db.select(
        '''SELECT receipt_json FROM eval_cache_receipts
           WHERE current_execution_id = ? AND current_trial_slot_id = ?
             AND current_attempt_no = ? AND current_run_id = ?
           ORDER BY rowid''',
        <Object?>[executionId, trialSlotId, attemptNo, runId],
      ))
        AppLlmCacheReceipt.fromJson(
          jsonDecode(row['receipt_json']! as String) as Map<String, Object?>,
        ),
    ];
  }
}
