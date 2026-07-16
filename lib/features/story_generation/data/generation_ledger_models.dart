/// Typed values persisted by the V9 scene-generation ledger.
///
/// These models deliberately contain hashes and identity metadata rather than
/// treating a candidate payload as the source of truth. Payloads can expire;
/// proofs and receipts cannot.
library;

class GenerationLedgerInvariantViolation implements Exception {
  const GenerationLedgerInvariantViolation(this.message);

  final String message;

  @override
  String toString() => 'GenerationLedgerInvariantViolation: $message';
}

class GenerationBudgetUnavailable implements Exception {
  const GenerationBudgetUnavailable(this.runId);

  final String runId;

  @override
  String toString() => 'GenerationBudgetUnavailable: $runId';
}

/// Result of one bounded retention sweep.  Candidate proofs and commit
/// receipts deliberately do not appear here: they are permanent evidence and
/// are never retention targets.
class GenerationRetentionReport {
  const GenerationRetentionReport({
    required this.deletedCandidatePayloads,
    required this.deletedPendingWrites,
    required this.abandonedReservations,
    required this.deletedStageCheckpoints,
  });

  final int deletedCandidatePayloads;
  final int deletedPendingWrites;
  final int abandonedReservations;
  final int deletedStageCheckpoints;
}

/// Provenance which must remain unchanged for a completed artifact to be
/// reusable. All values are canonical SHA-256 digests; raw prompts, provider
/// requests, credentials and store handles are intentionally never persisted.
class GenerationCheckpointProvenance {
  const GenerationCheckpointProvenance({
    required this.baseDraftDigest,
    required this.materialDigest,
    required this.promptDigest,
    required this.modelDigest,
  });

  final String baseDraftDigest;
  final String materialDigest;
  final String promptDigest;
  final String modelDigest;
}

class GenerationStageCheckpointRecord {
  const GenerationStageCheckpointRecord({
    required this.runId,
    this.proseRevision = 0,
    required this.ordinal,
    required this.stageId,
    required this.stageAttempt,
    required this.codecVersion,
    required this.status,
    required this.inputDigest,
    required this.artifactDigest,
    required this.upstreamChainDigest,
    required this.provenance,
    required this.createdAtMs,
    this.completedAtMs,
    this.artifactType = '',
    this.artifactJson = '{}',
  });

  final String runId;
  final int proseRevision;
  final int ordinal;
  final String stageId;
  final int stageAttempt;
  final int codecVersion;
  final String status;
  final String inputDigest;
  final String artifactDigest;
  final String upstreamChainDigest;
  final GenerationCheckpointProvenance provenance;
  final int createdAtMs;
  final int? completedAtMs;
  final String artifactType;
  final String artifactJson;

  bool get isCompleted => status == 'completed' && completedAtMs != null;
}

class GenerationRunRecord {
  const GenerationRunRecord({
    required this.runId,
    required this.requestId,
    required this.projectId,
    required this.chapterId,
    required this.sceneId,
    required this.sceneScopeId,
    required this.status,
    required this.phase,
    required this.schemaVersion,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.blockedStage,
    this.currentProseRevision = 0,
    this.currentCandidateRevision,
    this.lastErrorCode,
    this.committedAtMs,
  });

  final String runId;
  final String requestId;
  final String projectId;
  final String chapterId;
  final String sceneId;
  final String sceneScopeId;
  final String status;
  final String phase;
  final String? blockedStage;
  final int schemaVersion;
  final int currentProseRevision;
  final int? currentCandidateRevision;
  final String? lastErrorCode;
  final int createdAtMs;
  final int updatedAtMs;
  final int? committedAtMs;
}

class WorkingProseRevisionRecord {
  const WorkingProseRevisionRecord({
    required this.runId,
    required this.proseRevision,
    required this.proseHash,
    required this.proseText,
    required this.sourceKind,
    required this.createdAtMs,
  });

  final String runId;
  final int proseRevision;
  final String proseHash;
  final String proseText;
  final String sourceKind;
  final int createdAtMs;
}

class CandidateNamespaceRecord {
  const CandidateNamespaceRecord({
    required this.runId,
    required this.candidateRevision,
    required this.sourceProseRevision,
    required this.reservedAtMs,
  });

  final String runId;
  final int candidateRevision;
  final int sourceProseRevision;
  final int reservedAtMs;
}

class CandidateProofRecord {
  const CandidateProofRecord({
    required this.runId,
    required this.candidateRevision,
    required this.projectId,
    required this.chapterId,
    required this.sceneId,
    required this.sourceProseRevision,
    required this.candidateHash,
    required this.finalProseHash,
    required this.deterministicGateEvidenceHash,
    required this.finalCouncilEvidenceHash,
    required this.qualityEvidenceHash,
    required this.pendingWriteSetHash,
    required this.materialDigest,
    required this.inputDigest,
    required this.createdAtMs,
  });

  final String runId;
  final int candidateRevision;
  final String projectId;
  final String chapterId;
  final String sceneId;
  final int sourceProseRevision;
  final String candidateHash;
  final String finalProseHash;
  final String deterministicGateEvidenceHash;
  final String finalCouncilEvidenceHash;
  final String qualityEvidenceHash;
  final String pendingWriteSetHash;
  final String materialDigest;
  final String inputDigest;
  final int createdAtMs;
}

class CandidatePayloadRecord {
  const CandidatePayloadRecord({
    required this.runId,
    required this.candidateRevision,
    required this.finalProse,
    required this.pendingWriteManifestJson,
    required this.createdAtMs,
    required this.expiresAtMs,
    this.retrievalTraceJson = '{}',
    this.reviewPayloadJson = '{}',
    this.qualityPayloadJson = '{}',
  });

  final String runId;
  final int candidateRevision;
  final String finalProse;
  final String pendingWriteManifestJson;
  final String retrievalTraceJson;
  final String reviewPayloadJson;
  final String qualityPayloadJson;
  final int createdAtMs;
  final int expiresAtMs;
}

class PendingWriteRecord {
  const PendingWriteRecord({
    required this.runId,
    required this.candidateRevision,
    required this.writeId,
    required this.projectId,
    required this.chapterId,
    required this.sceneId,
    required this.logicalEntityId,
    required this.writeKind,
    required this.payloadHash,
    required this.payloadJson,
    required this.derivationClass,
    required this.createdAtMs,
    required this.expiresAtMs,
    this.state = 'staged',
    this.tier = 'draft',
    this.producer = '',
    this.visibility = 'publicObservable',
    this.ownerId = '',
    this.committedAtMs,
    this.discardedAtMs,
  });

  final String runId;
  final int candidateRevision;
  final String writeId;
  final String projectId;
  final String chapterId;
  final String sceneId;
  final String logicalEntityId;
  final String writeKind;
  final String payloadHash;
  final String payloadJson;
  final String derivationClass;
  final String state;
  final String tier;
  final String producer;
  final String visibility;
  final String ownerId;
  final int createdAtMs;
  final int expiresAtMs;
  final int? committedAtMs;
  final int? discardedAtMs;
}

class CommitReceiptRecord {
  const CommitReceiptRecord({
    required this.receiptId,
    required this.acceptIdempotencyKey,
    required this.runId,
    required this.candidateRevision,
    required this.sceneScopeId,
    required this.committedCandidateHash,
    required this.previousDraftHash,
    required this.committedDraftHash,
    required this.versionId,
    required this.versionContentHash,
    required this.pendingWriteSetHash,
    required this.committedAtMs,
    this.chapterSummaryRevisionId,
    this.outboxSetHash = '',
  });

  final String receiptId;
  final String acceptIdempotencyKey;
  final String runId;
  final int candidateRevision;
  final String sceneScopeId;
  final String committedCandidateHash;
  final String previousDraftHash;
  final String committedDraftHash;
  final String versionId;
  final String versionContentHash;
  final String pendingWriteSetHash;
  final String? chapterSummaryRevisionId;
  final String outboxSetHash;
  final int committedAtMs;
}

class RunBudgetRecord {
  const RunBudgetRecord({
    required this.runId,
    required this.maxCalls,
    required this.maxTokens,
    required this.maxCostMicrousd,
    required this.updatedAtMs,
  });

  final String runId;
  final int maxCalls;
  final int maxTokens;
  final int maxCostMicrousd;
  final int updatedAtMs;
}

class BudgetReservationRequest {
  const BudgetReservationRequest({
    required this.runId,
    required this.providerRequestId,
    required this.reservationId,
    required this.reservedCalls,
    required this.reservedTokens,
    required this.reservedCostMicrousd,
    required this.leaseOwner,
    required this.leaseExpiresAtMs,
    required this.createdAtMs,
  });

  final String runId;
  final String providerRequestId;
  final String reservationId;
  final int reservedCalls;
  final int reservedTokens;
  final int reservedCostMicrousd;
  final String leaseOwner;
  final int leaseExpiresAtMs;
  final int createdAtMs;
}

class BudgetReservationRecord extends BudgetReservationRequest {
  const BudgetReservationRecord({
    required super.runId,
    required super.providerRequestId,
    required super.reservationId,
    required super.reservedCalls,
    required super.reservedTokens,
    required super.reservedCostMicrousd,
    required super.leaseOwner,
    required super.leaseExpiresAtMs,
    required super.createdAtMs,
    required this.state,
    this.actualCalls,
    this.actualTokens,
    this.actualCostMicrousd,
    this.settledAtMs,
  });

  final String state;
  final int? actualCalls;
  final int? actualTokens;
  final int? actualCostMicrousd;
  final int? settledAtMs;
}

class GenerationEventRecord {
  const GenerationEventRecord({
    required this.eventId,
    required this.runId,
    required this.sequenceNo,
    required this.eventType,
    required this.createdAtMs,
    this.stageId,
    this.reviewerId,
    this.attempt = 0,
    this.durationMs,
    this.failureCode,
    this.errorCode,
    this.errorSummary,
    this.metadataJson = '{}',
  });

  final String eventId;
  final String runId;
  final int sequenceNo;
  final String eventType;
  final String? stageId;
  final String? reviewerId;
  final int attempt;
  final int? durationMs;
  final String? failureCode;
  final String? errorCode;
  final String? errorSummary;
  final String metadataJson;
  final int createdAtMs;
}

class GenerationOutboxRecord {
  const GenerationOutboxRecord({
    required this.operationKey,
    required this.runId,
    required this.projectId,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.sourceReceiptId,
    this.state = 'pending',
    this.attemptCount = 0,
    this.leaseOwner = '',
    this.leaseExpiresAtMs = 0,
    this.nextAttemptAtMs = 0,
    this.lastErrorCode,
    this.lastErrorSummary,
  });

  final String operationKey;
  final String runId;
  final String projectId;
  final String entityId;
  final String operation;
  final String payloadJson;
  final String? sourceReceiptId;
  final String state;
  final int attemptCount;
  final String leaseOwner;
  final int leaseExpiresAtMs;
  final int nextAttemptAtMs;
  final String? lastErrorCode;
  final String? lastErrorSummary;
  final int createdAtMs;
  final int updatedAtMs;
}

/// Immutable input for the author-accept compare-and-swap.
///
/// The values are intentionally explicit.  A caller must carry the hashes it
/// observed while rendering a candidate instead of asking the commit path to
/// infer intent from mutable UI state.
class GenerationCommitRequest {
  const GenerationCommitRequest({
    required this.acceptIdempotencyKey,
    required this.runId,
    required this.candidateRevision,
    required this.projectId,
    required this.sceneScopeId,
    required this.candidateHash,
    required this.expectedBaseDraftHash,
    required this.expectedMaterialDigest,
    required this.expectedInputDigest,
    required this.expectedFinalProseHash,
    required this.expectedDeterministicGateEvidenceHash,
    required this.expectedFinalCouncilEvidenceHash,
    required this.expectedQualityEvidenceHash,
    required this.expectedPendingWriteSetHash,
    required this.committedAtMs,
    this.feedbackLeases = const [],
    this.versionLabel = '作者采纳候选稿',
  });

  final String acceptIdempotencyKey;
  final String runId;
  final int candidateRevision;
  final String projectId;
  final String sceneScopeId;
  final String candidateHash;
  final String expectedBaseDraftHash;
  final String expectedMaterialDigest;
  final String expectedInputDigest;
  final String expectedFinalProseHash;
  final String expectedDeterministicGateEvidenceHash;
  final String expectedFinalCouncilEvidenceHash;
  final String expectedQualityEvidenceHash;
  final String expectedPendingWriteSetHash;
  final List<GenerationFeedbackLease> feedbackLeases;
  final String versionLabel;
  final int committedAtMs;
}

/// Lease identity carried from revision-request selection to author accept.
///
/// Until the feedback schema is normalized, this is persisted inside the
/// project JSON document.  The coordinator validates it while holding the
/// authoring database write transaction, so it must never be emulated with a
/// separate store save.
class GenerationFeedbackLease {
  const GenerationFeedbackLease({
    required this.feedbackId,
    required this.ownerRunId,
    required this.leaseExpiresAtMs,
  });

  final String feedbackId;
  final String ownerRunId;
  final int leaseExpiresAtMs;
}

class GenerationFeedbackLeaseClaimRequest {
  const GenerationFeedbackLeaseClaimRequest({
    required this.projectId,
    required this.runId,
    required this.feedbackIds,
    required this.leaseExpiresAtMs,
    required this.claimedAtMs,
  });

  final String projectId;
  final String runId;
  final List<String> feedbackIds;
  final int leaseExpiresAtMs;
  final int claimedAtMs;
}

sealed class GenerationCommitResult {
  const GenerationCommitResult(this.receipt);

  final CommitReceiptRecord receipt;
}

class GenerationCommitApplied extends GenerationCommitResult {
  const GenerationCommitApplied(super.receipt);
}

class GenerationCommitAlreadyApplied extends GenerationCommitResult {
  const GenerationCommitAlreadyApplied(super.receipt);
}

sealed class GenerationCommitConflict implements Exception {
  const GenerationCommitConflict(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class GenerationIdempotencyConflict extends GenerationCommitConflict {
  const GenerationIdempotencyConflict(super.message);
}

class GenerationDraftConflict extends GenerationCommitConflict {
  const GenerationDraftConflict(super.message);
}

class GenerationMaterialConflict extends GenerationCommitConflict {
  const GenerationMaterialConflict(super.message);
}

class GenerationCandidateEvidenceConflict extends GenerationCommitConflict {
  const GenerationCandidateEvidenceConflict(super.message);
}

class GenerationRunStateConflict extends GenerationCommitConflict {
  const GenerationRunStateConflict(super.message);
}

class GenerationCancelWonConflict extends GenerationCommitConflict {
  const GenerationCancelWonConflict(super.message);
}

/// Transaction checkpoints exposed only for deterministic crash testing.
enum GenerationCommitStep {
  begun,
  candidateValidated,
  draftWritten,
  versionWritten,
  pendingWritesCommitted,
  feedbackConsumed,
  receiptWritten,
  runCommitted,
  outboxWritten,
  beforeCommit,
  afterCommit,
}

typedef GenerationCommitFaultInjector =
    void Function(GenerationCommitStep step);
