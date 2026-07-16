import 'dart:convert';

import '../../../../app/llm/app_llm_call_trace.dart';
import '../generation_commit_coordinator.dart';
import '../generation_ledger_digest.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_metered_client.dart';
import 'agent_evaluation_runner.dart';
import 'agent_evaluation_typed_evidence.dart';
import '../../domain/evaluation/outcome_evaluation.dart';

class AgentEvaluationProductionEvidenceException implements Exception {
  const AgentEvaluationProductionEvidenceException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationProductionEvidenceException: $message';
}

abstract interface class AgentEvaluationFrozenPriceTable {
  String get releaseHash;

  int costMicrousd(AgentEvaluationProviderCallEvidence call);
}

final class AgentEvaluationVerifierResult {
  AgentEvaluationVerifierResult({
    required this.passed,
    required this.evidenceHash,
  }) {
    AgentEvaluationHashes.requireDigest(evidenceHash, 'evidenceHash');
  }

  final bool passed;
  final String evidenceHash;
}

abstract interface class AgentEvaluationProductionSafetyVerifier {
  String get releaseHash;

  AgentEvaluationVerifierResult verify({
    required String prose,
    required Map<String, Object?> referenceFacts,
    required Map<String, Object?> productionProof,
  });
}

abstract final class AgentEvaluationProductionTransactionPolicy {
  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'eval-production-transaction-verifier-v2',
    <String, Object?>{
      'runStatus': 'committed',
      'proofReceipt': 'candidate-and-write-set-match',
      'prose': 'working-prose-and-draft-version-hashes-match',
      'pendingWrites': 'all-committed',
      'outbox': 'completed-without-error-v1',
      'attemptBinding': 'evaluation-attempt-to-story-run-v1',
    },
  );
}

/// Converts one normal production story run into raw evaluation evidence.
///
/// External prose scoring and safety verification remain separate injected
/// authorities. Provider usage comes from a fail-closed metering wrapper, not
/// the story budget reservation table or best-effort traces.
final class AgentEvaluationProductionEvidenceCollector {
  const AgentEvaluationProductionEvidenceCollector();

  AgentEvaluationTrialExecutionResult collect({
    required AgentEvaluationTrialContext context,
    required String storyRunId,
    required List<AppLlmCallTraceEntry> traces,
    required AgentEvaluationMeterSnapshot meterSnapshot,
    required AgentEvaluationFrozenPriceTable priceTable,
    required AgentEvaluationQualityEvidence qualityEvidence,
    String? judgeCandidateJson,
    Iterable<AgentEvaluationProviderCallEvidence> externalProviderCalls =
        const <AgentEvaluationProviderCallEvidence>[],
    required AgentEvaluationProductionSafetyVerifier safetyVerifier,
    String? executorReleaseHash,
  }) {
    if (storyRunId.trim().isEmpty ||
        traces.isEmpty ||
        meterSnapshot.calls.isEmpty) {
      throw const AgentEvaluationProductionEvidenceException(
        'production run, formal traces, and metered provider calls are required',
      );
    }
    if (meterSnapshot.trialSlotId != context.lease.trialSlotId ||
        meterSnapshot.attemptNo != context.attemptNo ||
        meterSnapshot.modelRouteHash != context.cell.modelRouteHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'meter snapshot belongs to another formal attempt or route',
      );
    }
    if (storyRunId != context.runId) {
      throw const AgentEvaluationProductionEvidenceException(
        'production story run must be created in the current evaluation attempt namespace',
      );
    }
    if (priceTable.releaseHash != context.manifest.priceTableHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'metered cost does not use the manifest price table release',
      );
    }
    AgentEvaluationHashes.requireDigest(
      safetyVerifier.releaseHash,
      'safetyVerifierReleaseHash',
    );
    if (executorReleaseHash != null) {
      AgentEvaluationHashes.requireDigest(
        executorReleaseHash,
        'executorReleaseHash',
      );
    }
    final expectedBundle = 'sha256:${context.cell.generationBundleHash}';
    for (final trace in traces) {
      if (trace.metadata['experimentId'] != context.manifest.experimentId ||
          trace.metadata['executionId'] != context.lease.executionId ||
          trace.metadata['runId'] != context.runId ||
          trace.metadata['trialSlotId'] != context.lease.trialSlotId ||
          trace.metadata['attemptNo'] != context.attemptNo ||
          trace.generationBundleHash != expectedBundle ||
          trace.promptReleaseRef == null ||
          trace.renderedMessagesDigest == null ||
          trace.resolvedVariablesDigest == null) {
        throw const AgentEvaluationProductionEvidenceException(
          'production trace is missing or contradicts formal trial identity',
        );
      }
    }
    if (traces.length != meterSnapshot.calls.length) {
      throw AgentEvaluationProductionEvidenceException(
        'formal traces and metered provider calls do not reconcile: '
        '${traces.length} traces for ${meterSnapshot.calls.length} calls',
      );
    }
    for (var index = 0; index < traces.length; index += 1) {
      final trace = traces[index];
      final call = meterSnapshot.calls[index];
      if (call.sequenceNo != index + 1 ||
          trace.model != call.model ||
          trace.promptTokens != call.promptTokens ||
          trace.completionTokens != call.completionTokens ||
          trace.succeeded != call.succeeded) {
        throw const AgentEvaluationProductionEvidenceException(
          'formal trace contradicts the metered provider call sequence',
        );
      }
    }
    final pricedCalls = <AgentEvaluationPricedProviderCall>[];
    for (final call in meterSnapshot.calls) {
      if (call.modelRouteHash != context.cell.modelRouteHash) {
        throw const AgentEvaluationProductionEvidenceException(
          'metered provider call used another model route',
        );
      }
      final cost = priceTable.costMicrousd(call);
      if (cost < 0) {
        throw const AgentEvaluationProductionEvidenceException(
          'price table returned a negative cost',
        );
      }
      pricedCalls.add(
        AgentEvaluationPricedProviderCall(
          sequenceNo: call.sequenceNo,
          modelRouteHash: call.modelRouteHash,
          model: call.model,
          promptTokens: call.promptTokens,
          completionTokens: call.completionTokens,
          succeeded: call.succeeded,
          costMicrousd: cost,
          purpose: 'sut',
        ),
      );
    }
    for (final call in externalProviderCalls) {
      final cost = priceTable.costMicrousd(call);
      pricedCalls.add(
        AgentEvaluationPricedProviderCall(
          sequenceNo: pricedCalls.length + 1,
          modelRouteHash: call.modelRouteHash,
          model: call.model,
          promptTokens: call.promptTokens,
          completionTokens: call.completionTokens,
          succeeded: call.succeeded,
          costMicrousd: cost,
          purpose: 'externalJudge',
        ),
      );
    }
    _validateEvaluationBudget(context, pricedCalls);

    final rows = context.database.select(
      '''SELECT run.status AS run_status, run.committed_at_ms,
           p.*, prose.prose_text AS final_prose,
           prose.prose_hash AS working_prose_hash,
           receipt.receipt_id, receipt.committed_candidate_hash,
           receipt.committed_draft_hash, receipt.version_content_hash,
           receipt.pending_write_set_hash AS receipt_pending_write_set_hash,
           receipt.outbox_set_hash, receipt.scene_scope_id,
           receipt.version_id,
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
        'production proof, permanent prose, bundle, and receipt must join once',
      );
    }
    final row = rows.single;
    final prose = row['final_prose'];
    final proofMatches =
        prose is String &&
        prose.trim().isNotEmpty &&
        GenerationCommitDigest.text(prose) == row['final_prose_hash'] &&
        row['working_prose_hash'] == row['final_prose_hash'] &&
        _isDigest(row['candidate_hash']) &&
        _isDigest(row['deterministic_gate_evidence_hash']) &&
        _isDigest(row['final_council_evidence_hash']) &&
        _isDigest(row['quality_evidence_hash']) &&
        _isDigest(row['pending_write_set_hash']) &&
        _rawDigest(row['run_bundle_hash']) ==
            context.cell.generationBundleHash &&
        row['payload_final_prose'] == prose;
    if (!proofMatches) {
      throw const AgentEvaluationProductionEvidenceException(
        'production candidate proof does not bind prose and arm bundle',
      );
    }
    final evaluatedContentHash = AgentEvaluationHashes.domainHash(
      'eval-trial-content-v1',
      prose,
    );
    if (qualityEvidence.evaluatedContentHash != evaluatedContentHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'external quality evidence belongs to different production prose',
      );
    }
    final manifest = _pendingWriteManifest(row['pending_write_manifest_json']);
    final expectedPendingWriteSetHash = GenerationLedgerDigest.object(manifest);
    final expectedCandidateHash = GenerationLedgerDigest.object(<
      String,
      Object?
    >{
      'runId': storyRunId,
      'candidateRevision': row['candidate_revision'],
      'finalProseHash': row['final_prose_hash'],
      'deterministicGateEvidenceHash': row['deterministic_gate_evidence_hash'],
      'finalCouncilEvidenceHash': row['final_council_evidence_hash'],
      'qualityEvidenceHash': row['quality_evidence_hash'],
      'pendingWriteSetHash': expectedPendingWriteSetHash,
      'materialDigest': row['material_digest'],
      'inputDigest': row['input_digest'],
      // The ledger normalizes foreign keys to the raw digest, while the
      // immutable candidate proof was hashed with the public prefixed
      // GenerationBundle identity returned by the prompt registry.
      'generationBundleHash': 'sha256:${_rawDigest(row['run_bundle_hash'])}',
    });
    if (row['pending_write_set_hash'] != expectedPendingWriteSetHash ||
        row['candidate_hash'] != expectedCandidateHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'production proof hashes cannot be recomputed from the candidate payload',
      );
    }
    final pending = context.database.select(
      '''SELECT write_id, payload_hash, payload_json, state, committed_at_ms
         FROM story_generation_pending_writes
         WHERE run_id = ? AND candidate_revision = ? ORDER BY write_id''',
      <Object?>[storyRunId, row['candidate_revision']],
    );
    final manifestByWriteId = <String, String>{
      for (final entry in manifest)
        entry['writeId']! as String: entry['payloadHash']! as String,
    };
    final pendingByWriteId = <String, Object?>{
      for (final entry in pending) entry['write_id'] as String: entry,
    };
    final allPendingCommitted =
        manifest.isNotEmpty &&
        pending.length == manifest.length &&
        pendingByWriteId.keys.toSet().containsAll(manifestByWriteId.keys) &&
        pending.every(
          (entry) =>
              entry['state'] == 'committed' &&
              entry['committed_at_ms'] == row['receipt_committed_at_ms'] &&
              manifestByWriteId[entry['write_id']] == entry['payload_hash'] &&
              GenerationCommitDigest.text(entry['payload_json'] as String) ==
                  entry['payload_hash'],
        );
    final sceneScopeId = row['scene_scope_id'];
    final draftRows = context.database.select(
      'SELECT text_body FROM draft_documents WHERE project_id = ?',
      <Object?>[sceneScopeId],
    );
    final versionRows = context.database.select(
      '''SELECT content FROM version_entries
         WHERE project_id = ? AND sequence_no = 0''',
      <Object?>[sceneScopeId],
    );
    final outboxRows = context.database.select(
      '''SELECT operation_key, run_id, payload_json, source_receipt_id,
           state, attempt_count, lease_owner, lease_expires_at_ms,
           next_attempt_at_ms, last_error_code, last_error_summary
         FROM story_generation_outbox WHERE source_receipt_id = ?''',
      <Object?>[row['receipt_id']],
    );
    final outboxMatches =
        outboxRows.length == 1 &&
        outboxRows.single['operation_key'] == 'index:${row['receipt_id']}' &&
        outboxRows.single['run_id'] == storyRunId &&
        outboxRows.single['state'] == 'completed' &&
        outboxRows.single['attempt_count'] is int &&
        (outboxRows.single['attempt_count'] as int) >= 1 &&
        outboxRows.single['lease_owner'] == '' &&
        outboxRows.single['lease_expires_at_ms'] == 0 &&
        outboxRows.single['next_attempt_at_ms'] == 0 &&
        outboxRows.single['last_error_code'] == null &&
        outboxRows.single['last_error_summary'] == null &&
        _outboxPayloadMatches(
          outboxRows.single['payload_json'],
          runId: storyRunId,
          candidateRevision: row['candidate_revision'] as int,
          receiptId: row['receipt_id'] as String,
          writeIds: manifestByWriteId.keys,
        );
    final actualDraftMatches =
        draftRows.length == 1 &&
        GenerationCommitDigest.text(draftRows.single['text_body'] as String) ==
            row['final_prose_hash'];
    final actualVersionMatches =
        versionRows.length == 1 &&
        GenerationCommitDigest.text(versionRows.single['content'] as String) ==
            row['final_prose_hash'];
    final transactionMatches =
        row['run_status'] == 'committed' &&
        row['committed_at_ms'] == row['receipt_committed_at_ms'] &&
        row['committed_candidate_hash'] == row['candidate_hash'] &&
        row['receipt_pending_write_set_hash'] ==
            row['pending_write_set_hash'] &&
        row['committed_draft_hash'] == row['final_prose_hash'] &&
        row['version_content_hash'] == row['final_prose_hash'] &&
        row['outbox_set_hash'] ==
            'outbox:$storyRunId:${row['candidate_revision']}' &&
        allPendingCommitted &&
        actualDraftMatches &&
        actualVersionMatches &&
        outboxMatches;
    if (!transactionMatches) {
      throw const AgentEvaluationProductionEvidenceException(
        'production transaction receipt does not prove the committed run',
      );
    }
    final proofSnapshot = <String, Object?>{
      'evaluationAttemptRunId': context.runId,
      'trialSlotId': context.lease.trialSlotId,
      'productionStoryRunId': storyRunId,
      'candidateRevision': row['candidate_revision'],
      'candidateHash': row['candidate_hash'],
      'finalProseHash': row['final_prose_hash'],
      'generationBundleHash': row['run_bundle_hash'],
      'receiptId': row['receipt_id'],
      'committedAtMs': row['receipt_committed_at_ms'],
      'pendingWriteSetHash': row['pending_write_set_hash'],
      'outboxSetHash': row['outbox_set_hash'],
      'draftContentHash': GenerationCommitDigest.text(
        draftRows.single['text_body'] as String,
      ),
      'versionContentHash': GenerationCommitDigest.text(
        versionRows.single['content'] as String,
      ),
      'outboxPayloadHash': GenerationCommitDigest.text(
        outboxRows.single['payload_json'] as String,
      ),
    };
    final safety = safetyVerifier.verify(
      prose: prose,
      referenceFacts: context.scenario.referenceFacts,
      productionProof: Map<String, Object?>.unmodifiable(proofSnapshot),
    );
    final transactionEvidenceHash = AgentEvaluationHashes.domainHash(
      'eval-production-transaction-evidence-v1',
      proofSnapshot,
    );
    final safetyBlocked = !safety.passed;
    return AgentEvaluationTrialExecutionResult(
      outcome: ActualTrialOutcome(
        terminalState: safetyBlocked
            ? TrialTerminalState.blocked
            : TrialTerminalState.accepted,
        failureCodes: safetyBlocked
            ? const <String>{'safety.blocked'}
            : const <String>{},
        accepted: !safetyBlocked,
        evidenceComplete: true,
      ),
      evaluatedContent: prose,
      productionStoryRunId: storyRunId,
      productionCandidateHash: row['candidate_hash'] as String,
      productionReceiptId: row['receipt_id'] as String,
      productionTransactionEvidenceHash: transactionEvidenceHash,
      productionExecutorReleaseHash: executorReleaseHash,
      usage: AgentEvaluationAttemptUsage.frozen(
        priceTableHash: priceTable.releaseHash,
        providerCalls: pricedCalls,
      ),
      qualityEvidence: qualityEvidence,
      judgeCandidateJson: judgeCandidateJson,
      hardGateEvidence: AgentEvaluationHardGateEvidence(
        safetyPassed: safety.passed,
        transactionPassed: true,
        safetyVerifierReleaseHash: safetyVerifier.releaseHash,
        transactionVerifierReleaseHash:
            AgentEvaluationProductionTransactionPolicy.releaseHash,
        safetyEvidenceHash: safety.evidenceHash,
        transactionEvidenceHash: transactionEvidenceHash,
      ),
    );
  }
}

void _validateEvaluationBudget(
  AgentEvaluationTrialContext context,
  List<AgentEvaluationPricedProviderCall> calls,
) {
  final evaluatorCalls = calls
      .where((call) => call.purpose == 'externalJudge')
      .toList(growable: false);
  if (evaluatorCalls.isEmpty) return;
  final maxCalls = context.manifest.budgets['evaluatorCalls'];
  final maxTokens = context.manifest.budgets['evaluatorTokens'];
  final maxCost = context.manifest.budgets['evaluatorCostMicrousd'];
  if (maxCalls is! int ||
      maxCalls <= 0 ||
      maxTokens is! int ||
      maxTokens <= 0 ||
      maxCost is! int ||
      maxCost < 0) {
    throw const AgentEvaluationProductionEvidenceException(
      'manifest omitted frozen external evaluator budgets',
    );
  }
  final tokens = evaluatorCalls.fold<int>(
    0,
    (sum, call) => sum + call.promptTokens + call.completionTokens,
  );
  final cost = evaluatorCalls.fold<int>(
    0,
    (sum, call) => sum + call.costMicrousd,
  );
  if (evaluatorCalls.length > maxCalls ||
      tokens > maxTokens ||
      cost > maxCost) {
    throw const AgentEvaluationProductionEvidenceException(
      'external evaluator exceeded the frozen call/token/cost budget',
    );
  }
}

bool _isDigest(Object? value) =>
    value is String && RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(value);

String? _rawDigest(Object? value) {
  if (value is! String) return null;
  return value.startsWith('sha256:')
      ? value.substring('sha256:'.length)
      : value;
}

List<Map<String, Object?>> _pendingWriteManifest(Object? encoded) {
  try {
    final decoded = jsonDecode(encoded as String);
    if (decoded is! List || decoded.isEmpty) {
      throw const FormatException('manifest must be a non-empty list');
    }
    final result = <Map<String, Object?>>[];
    final writeIds = <String>{};
    for (final item in decoded) {
      if (item is! Map || item.length != 2) {
        throw const FormatException('manifest item shape is invalid');
      }
      final writeId = item['writeId'];
      final payloadHash = item['payloadHash'];
      if (writeId is! String ||
          writeId.trim().isEmpty ||
          payloadHash is! String ||
          !_isDigest(payloadHash) ||
          !writeIds.add(writeId)) {
        throw const FormatException('manifest identity is invalid');
      }
      result.add(<String, Object?>{
        'writeId': writeId,
        'payloadHash': payloadHash,
      });
    }
    return result;
  } on Object {
    throw const AgentEvaluationProductionEvidenceException(
      'candidate pending-write manifest is malformed',
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
    final value = jsonDecode(encoded as String);
    if (value is! Map) return false;
    final actualWriteIds = value['writeIds'];
    return value['runId'] == runId &&
        value['candidateRevision'] == candidateRevision &&
        value['receiptId'] == receiptId &&
        actualWriteIds is List &&
        actualWriteIds.length == writeIds.length &&
        actualWriteIds.toSet().containsAll(writeIds);
  } on Object {
    return false;
  }
}
