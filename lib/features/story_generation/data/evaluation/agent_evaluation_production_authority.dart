import 'dart:convert';

import '../generation_commit_coordinator.dart';
import '../generation_ledger_digest.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_production_evidence.dart';
import 'agent_evaluation_runner.dart';

/// Result of a runner-owned verification against the borrowed production DB.
///
/// This is intentionally separate from the executor result. A trial executor
/// cannot make a release-capable receipt merely by returning digest-shaped
/// strings; the runner must reconstruct the normal commit transaction first.
final class AgentEvaluationVerifiedProductionReceipt {
  const AgentEvaluationVerifiedProductionReceipt({
    required this.authorityReceiptHash,
    required this.sandboxDatabasePath,
    required this.attemptRunId,
    required this.candidateHash,
    required this.commitReceiptId,
    required this.transactionEvidenceHash,
    required this.proseHash,
    required this.generationBundleHash,
    required this.executorReleaseHash,
  });

  final String authorityReceiptHash;
  final String sandboxDatabasePath;
  final String attemptRunId;
  final String candidateHash;
  final String commitReceiptId;
  final String transactionEvidenceHash;
  final String proseHash;
  final String generationBundleHash;
  final String executorReleaseHash;
}

abstract final class AgentEvaluationProductionDatabaseAuthority {
  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'eval-production-database-authority-release-v1',
    const <String, Object?>{
      'source': 'borrowed-sandbox-sqlite',
      'candidate': 'recomputed-v1',
      'commit': 'receipt-write-set-draft-version-outbox-v1',
      'callerFields': 'comparison-only',
    },
  );

  static AgentEvaluationVerifiedProductionReceipt verify({
    required AgentEvaluationTrialContext context,
    required AgentEvaluationTrialExecutionResult result,
  }) {
    final path = context.sandboxDatabasePath?.trim() ?? '';
    final storyRunId = result.productionStoryRunId;
    final callerCandidateHash = result.productionCandidateHash;
    final callerReceiptId = result.productionReceiptId;
    final callerTransactionHash = result.productionTransactionEvidenceHash;
    final executorReleaseHash = result.productionExecutorReleaseHash;
    if (path.isEmpty ||
        storyRunId != context.runId ||
        callerCandidateHash == null ||
        callerReceiptId == null ||
        callerTransactionHash == null ||
        executorReleaseHash == null) {
      throw const AgentEvaluationProductionEvidenceException(
        'production result cannot be verified without complete DB identity',
      );
    }

    final rows = context.database.select(
      '''SELECT run.status AS run_status, run.committed_at_ms,
           p.candidate_revision, p.candidate_hash, p.final_prose_hash,
           p.deterministic_gate_evidence_hash,
           p.final_council_evidence_hash, p.quality_evidence_hash,
           p.pending_write_set_hash, p.material_digest, p.input_digest,
           prose.prose_text AS final_prose,
           prose.prose_hash AS working_prose_hash,
           receipt.receipt_id, receipt.committed_candidate_hash,
           receipt.committed_draft_hash, receipt.version_content_hash,
           receipt.pending_write_set_hash AS receipt_pending_write_set_hash,
           receipt.outbox_set_hash, receipt.scene_scope_id,
           receipt.committed_at_ms AS receipt_committed_at_ms,
           payload.final_prose AS payload_final_prose,
           payload.pending_write_manifest_json,
           binding.bundle_hash AS run_bundle_hash
         FROM story_generation_runs run
         JOIN story_generation_candidate_proofs p
           ON p.run_id = run.run_id
          AND p.candidate_revision = run.current_candidate_revision
         JOIN story_generation_working_prose_revisions prose
           ON prose.run_id = p.run_id
          AND prose.prose_revision = p.source_prose_revision
         JOIN story_generation_commit_receipts receipt
           ON receipt.run_id = p.run_id
          AND receipt.candidate_revision = p.candidate_revision
         JOIN story_generation_candidate_payloads payload
           ON payload.run_id = p.run_id
          AND payload.candidate_revision = p.candidate_revision
         JOIN story_generation_run_bundles binding ON binding.run_id = p.run_id
         WHERE run.run_id = ?''',
      <Object?>[storyRunId],
    );
    if (rows.length != 1) {
      throw const AgentEvaluationProductionEvidenceException(
        'runner authority could not join one committed production proof',
      );
    }
    final row = rows.single;
    final prose = row['final_prose'];
    final manifest = _pendingWriteManifest(row['pending_write_manifest_json']);
    final pendingWriteSetHash = GenerationLedgerDigest.object(manifest);
    final prefixedBundleHash = 'sha256:${row['run_bundle_hash']}';
    final candidateHash = GenerationLedgerDigest.object(<String, Object?>{
      'runId': storyRunId,
      'candidateRevision': row['candidate_revision'],
      'finalProseHash': row['final_prose_hash'],
      'deterministicGateEvidenceHash': row['deterministic_gate_evidence_hash'],
      'finalCouncilEvidenceHash': row['final_council_evidence_hash'],
      'qualityEvidenceHash': row['quality_evidence_hash'],
      'pendingWriteSetHash': pendingWriteSetHash,
      'materialDigest': row['material_digest'],
      'inputDigest': row['input_digest'],
      'generationBundleHash': prefixedBundleHash,
    });
    if (prose is! String ||
        prose.trim().isEmpty ||
        row['run_status'] != 'committed' ||
        GenerationCommitDigest.text(prose) != row['final_prose_hash'] ||
        row['working_prose_hash'] != row['final_prose_hash'] ||
        row['payload_final_prose'] != prose ||
        row['pending_write_set_hash'] != pendingWriteSetHash ||
        row['candidate_hash'] != candidateHash ||
        _rawDigest(prefixedBundleHash) != context.cell.generationBundleHash ||
        callerCandidateHash != candidateHash ||
        callerReceiptId != row['receipt_id']) {
      throw const AgentEvaluationProductionEvidenceException(
        'caller production receipt contradicts recomputed candidate proof',
      );
    }

    final manifestByWriteId = <String, String>{
      for (final item in manifest)
        item['writeId']! as String: item['payloadHash']! as String,
    };
    final pending = context.database.select(
      '''SELECT write_id, payload_hash, payload_json, state, committed_at_ms
         FROM story_generation_pending_writes
         WHERE run_id = ? AND candidate_revision = ? ORDER BY write_id''',
      <Object?>[storyRunId, row['candidate_revision']],
    );
    final pendingById = <String, dynamic>{
      for (final item in pending) item['write_id'] as String: item,
    };
    final writesMatch =
        manifest.isNotEmpty &&
        pending.length == manifest.length &&
        pendingById.keys.toSet().containsAll(manifestByWriteId.keys) &&
        pending.every(
          (item) =>
              item['state'] == 'committed' &&
              item['committed_at_ms'] == row['receipt_committed_at_ms'] &&
              item['payload_hash'] == manifestByWriteId[item['write_id']] &&
              GenerationCommitDigest.text(item['payload_json'] as String) ==
                  item['payload_hash'],
        );
    final sceneScopeId = row['scene_scope_id'];
    final drafts = context.database.select(
      'SELECT text_body FROM draft_documents WHERE project_id = ?',
      <Object?>[sceneScopeId],
    );
    final versions = context.database.select(
      '''SELECT content FROM version_entries
         WHERE project_id = ? AND sequence_no = 0''',
      <Object?>[sceneScopeId],
    );
    final outbox = context.database.select(
      '''SELECT operation_key, run_id, payload_json, source_receipt_id, state
         FROM story_generation_outbox WHERE source_receipt_id = ?''',
      <Object?>[row['receipt_id']],
    );
    final outboxMatches =
        outbox.length == 1 &&
        outbox.single['operation_key'] == 'index:${row['receipt_id']}' &&
        outbox.single['run_id'] == storyRunId &&
        outbox.single['state'] == 'completed' &&
        _outboxPayloadMatches(
          outbox.single['payload_json'],
          runId: storyRunId!,
          candidateRevision: row['candidate_revision'] as int,
          receiptId: row['receipt_id'] as String,
          writeIds: manifestByWriteId.keys,
        );
    final transactionMatches =
        row['committed_at_ms'] == row['receipt_committed_at_ms'] &&
        row['committed_candidate_hash'] == candidateHash &&
        row['receipt_pending_write_set_hash'] == pendingWriteSetHash &&
        row['committed_draft_hash'] == row['final_prose_hash'] &&
        row['version_content_hash'] == row['final_prose_hash'] &&
        row['outbox_set_hash'] ==
            'outbox:$storyRunId:${row['candidate_revision']}' &&
        writesMatch &&
        drafts.length == 1 &&
        versions.length == 1 &&
        GenerationCommitDigest.text(drafts.single['text_body'] as String) ==
            row['final_prose_hash'] &&
        GenerationCommitDigest.text(versions.single['content'] as String) ==
            row['final_prose_hash'] &&
        outboxMatches;
    if (!transactionMatches) {
      throw const AgentEvaluationProductionEvidenceException(
        'runner authority rejected the production commit transaction',
      );
    }

    final proofSnapshot = <String, Object?>{
      'evaluationAttemptRunId': context.runId,
      'trialSlotId': context.lease.trialSlotId,
      'productionStoryRunId': storyRunId,
      'candidateRevision': row['candidate_revision'],
      'candidateHash': candidateHash,
      'finalProseHash': row['final_prose_hash'],
      'generationBundleHash': row['run_bundle_hash'],
      'receiptId': row['receipt_id'],
      'committedAtMs': row['receipt_committed_at_ms'],
      'pendingWriteSetHash': pendingWriteSetHash,
      'outboxSetHash': row['outbox_set_hash'],
      'draftContentHash': GenerationCommitDigest.text(
        drafts.single['text_body'] as String,
      ),
      'versionContentHash': GenerationCommitDigest.text(
        versions.single['content'] as String,
      ),
      'outboxPayloadHash': GenerationCommitDigest.text(
        outbox.single['payload_json'] as String,
      ),
    };
    final transactionEvidenceHash = AgentEvaluationHashes.domainHash(
      'eval-production-transaction-evidence-v1',
      proofSnapshot,
    );
    final proseHash = AgentEvaluationHashes.domainHash(
      'eval-trial-content-v1',
      prose,
    );
    if (callerTransactionHash != transactionEvidenceHash ||
        result.evaluatedContent != prose) {
      throw const AgentEvaluationProductionEvidenceException(
        'caller result contradicts runner-owned production evidence',
      );
    }
    final authorityReceiptHash = AgentEvaluationHashes.domainHash(
      'eval-production-authority-receipt-v1',
      <String, Object?>{
        'authorityReleaseHash': releaseHash,
        'executionId': context.lease.executionId,
        'trialSlotId': context.lease.trialSlotId,
        'attemptNo': context.attemptNo,
        'attemptRunId': storyRunId,
        'sandboxDatabasePath': path,
        'candidateHash': candidateHash,
        'commitReceiptId': row['receipt_id'],
        'transactionEvidenceHash': transactionEvidenceHash,
        'proseHash': proseHash,
        'generationBundleHash': context.cell.generationBundleHash,
        'executorReleaseHash': executorReleaseHash,
      },
    );
    return AgentEvaluationVerifiedProductionReceipt(
      authorityReceiptHash: authorityReceiptHash,
      sandboxDatabasePath: path,
      attemptRunId: storyRunId,
      candidateHash: candidateHash,
      commitReceiptId: row['receipt_id'] as String,
      transactionEvidenceHash: transactionEvidenceHash,
      proseHash: proseHash,
      generationBundleHash: context.cell.generationBundleHash,
      executorReleaseHash: executorReleaseHash,
    );
  }
}

List<Map<String, Object?>> _pendingWriteManifest(Object? encoded) {
  try {
    final decoded = jsonDecode(encoded as String);
    if (decoded is! List || decoded.isEmpty) {
      throw const FormatException('empty manifest');
    }
    final result = <Map<String, Object?>>[];
    final ids = <String>{};
    for (final item in decoded) {
      if (item is! Map || item.length != 2) {
        throw const FormatException('invalid manifest item');
      }
      final id = item['writeId'];
      final hash = item['payloadHash'];
      if (id is! String ||
          id.trim().isEmpty ||
          hash is! String ||
          !_isPrefixedDigest(hash) ||
          !ids.add(id)) {
        throw const FormatException('invalid manifest identity');
      }
      result.add(<String, Object?>{'writeId': id, 'payloadHash': hash});
    }
    return result;
  } on Object {
    throw const AgentEvaluationProductionEvidenceException(
      'production pending-write manifest is malformed',
    );
  }
}

bool _outboxPayloadMatches(
  Object? encoded, {
  required String runId,
  required int candidateRevision,
  required String receiptId,
  required Iterable<String> writeIds,
}) {
  try {
    final decoded = jsonDecode(encoded as String);
    if (decoded is! Map ||
        decoded['runId'] != runId ||
        decoded['candidateRevision'] != candidateRevision ||
        decoded['receiptId'] != receiptId) {
      return false;
    }
    final encodedWriteIds = decoded['writeIds'];
    if (encodedWriteIds is! List ||
        encodedWriteIds.any((value) => value is! String)) {
      return false;
    }
    final expected = writeIds.toList()..sort();
    final actual = encodedWriteIds.cast<String>().toList()..sort();
    if (actual.length != expected.length) return false;
    for (var index = 0; index < expected.length; index += 1) {
      if (actual[index] != expected[index]) return false;
    }
    return true;
  } on Object {
    return false;
  }
}

bool _isPrefixedDigest(String value) =>
    RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(value);

String _rawDigest(String value) =>
    value.startsWith('sha256:') ? value.substring(7) : value;
