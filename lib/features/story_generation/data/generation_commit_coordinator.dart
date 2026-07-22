import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../app/state/app_draft_store.dart';
import '../../../app/llm/app_llm_canonical_hash.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/state/authoring_table_definitions.dart';
import '../../author_feedback/data/author_feedback_store.dart';
import 'generation_candidate_identity.dart';
import 'generation_evidence_receipt.dart';
import 'generation_ledger.dart';
import 'generation_ledger_digest.dart';
import 'generation_ledger_models.dart';
import 'generation_material_manifest_repository.dart';
import 'generation_scene_scope_identity.dart';

/// The sole authoritative transition from a durable candidate to author prose.
///
/// All durable effects deliberately use [db].  In particular, this class must
/// not call the async draft/version/feedback storage APIs: each of those opens
/// another connection and would make a partial author accept possible.
class GenerationCommitCoordinator {
  GenerationCommitCoordinator({
    required this.db,
    this.draftStore,
    this.versionStore,
    this.authorFeedbackStore,
    this.faultInjector,
  });

  final Database db;
  final AppDraftStore? draftStore;
  final AppVersionStore? versionStore;
  final AuthorFeedbackStore? authorFeedbackStore;
  final GenerationCommitFaultInjector? faultInjector;

  static final String releaseHash = AppLlmCanonicalHash.domainHash(
    'generation-commit-coordinator-release-v2',
    const <String, Object?>{
      'transaction': 'begin-immediate-single-authoring-connection',
      'idempotency': 'accept-key-bound-to-run-revision-candidate-scope',
      'cas': 'base-draft-and-material-digest',
      'effects': 'draft-version-pending-feedback-receipt-run-summary-outbox',
      'pendingWriteIntegrity':
          'canonical-payload-manifest-proof-revalidation-before-projection-v2',
      'continuityAuthority':
          'immutable-receipt-bound-projection-with-commit-ordinal-v2',
      'sceneScopeIdentity': 'injective-project-scene-address-v1',
      'sealedParsedEvaluation':
          'restart-recomputed-receipt-and-proof-cross-check-v1',
    },
  );

  /// Creates the compatibility tables needed by focused/in-memory callers.
  /// Production databases get these from migrations, so this is idempotent.
  void ensureTables() {
    GenerationLedgerSqliteStore(db: db).ensureTables();
    createDraftTables(db);
    createVersionTables(db);
    createStoryMemoryTables(db);
    createRoleplayArtifactTables(db);
    createGenerationSummaryAuthorityTables(db);
    db.execute('''
      CREATE TABLE IF NOT EXISTS author_feedback_projects (
        project_id TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
  }

  GenerationCommitResult accept(GenerationCommitRequest request) {
    _validateRequest(request);
    ensureTables();

    db.execute('BEGIN IMMEDIATE');
    try {
      _step(GenerationCommitStep.begun);
      _requireCanonicalRunSceneScope(request);
      final prior = _findReceiptForKey(request.acceptIdempotencyKey);
      if (prior != null) {
        if (prior.runId == request.runId &&
            prior.candidateRevision == request.candidateRevision &&
            prior.committedCandidateHash == request.candidateHash &&
            prior.sceneScopeId == request.sceneScopeId) {
          db.execute('COMMIT');
          _refreshStores(request, prior, _readCandidateProse(request));
          return GenerationCommitAlreadyApplied(prior);
        }
        throw const GenerationIdempotencyConflict(
          'accept idempotency key is already bound to another candidate',
        );
      }

      final candidate = _loadAndValidateCandidate(request);
      _step(GenerationCommitStep.candidateValidated);

      final materialRepository = GenerationMaterialManifestRepository(db: db);
      if (materialRepository.hasFrozenManifest(request.runId)) {
        final sceneRows = db.select(
          'SELECT scene_id FROM story_generation_runs WHERE run_id = ?',
          [request.runId],
        );
        if (sceneRows.length != 1) {
          throw const GenerationRunStateConflict('generation run is missing');
        }
        final currentMaterial = materialRepository.buildCurrent(
          projectId: request.projectId,
          sceneId: sceneRows.single['scene_id'] as String,
        );
        if (currentMaterial.materialDigest != request.expectedMaterialDigest) {
          throw const GenerationMaterialConflict(
            'authoritative material sources changed after this candidate was created',
          );
        }
      }

      final previousDraft = _readDraft(request.sceneScopeId);
      final actualDraftHash = GenerationCommitDigest.text(previousDraft);
      if (actualDraftHash != request.expectedBaseDraftHash) {
        throw const GenerationDraftConflict(
          'the draft changed after this candidate was created',
        );
      }

      final feedbackDocument = _validateAndConsumeFeedbackLeases(request);
      final finalProse = candidate.finalProse;
      final receiptId = _receiptId(request);
      final versionId = _versionId(request);
      final outboxSetHash = _outboxSetHash(request);
      final receipt = CommitReceiptRecord(
        receiptId: receiptId,
        acceptIdempotencyKey: request.acceptIdempotencyKey,
        runId: request.runId,
        candidateRevision: request.candidateRevision,
        sceneScopeId: request.sceneScopeId,
        committedCandidateHash: request.candidateHash,
        previousDraftHash: actualDraftHash,
        committedDraftHash: GenerationCommitDigest.text(finalProse),
        versionId: versionId,
        versionContentHash: request.expectedFinalProseHash,
        pendingWriteSetHash: request.expectedPendingWriteSetHash,
        outboxSetHash: outboxSetHash,
        committedAtMs: request.committedAtMs,
      );

      _writeDraft(request.sceneScopeId, finalProse, request.committedAtMs);
      _step(GenerationCommitStep.draftWritten);
      _insertNewestVersion(
        sceneScopeId: request.sceneScopeId,
        label: request.versionLabel,
        content: finalProse,
        committedAtMs: request.committedAtMs,
      );
      _step(GenerationCommitStep.versionWritten);
      final pendingProjection = _projectAndCommitPendingWrites(
        request,
        candidate,
      );
      _step(GenerationCommitStep.pendingWritesCommitted);
      _saveFeedbackDocument(
        projectId: request.projectId,
        document: feedbackDocument,
        updatedAtMs: request.committedAtMs,
      );
      _step(GenerationCommitStep.feedbackConsumed);
      _insertReceipt(receipt);
      _step(GenerationCommitStep.receiptWritten);
      _insertCommittedContinuityAuthority(
        request: request,
        receipt: receipt,
        continuity: pendingProjection.continuity,
      );
      _commitRun(request);
      _step(GenerationCommitStep.runCommitted);
      _projectAuthoritativeSummary(
        request: request,
        receipt: receipt,
        finalProse: finalProse,
      );
      _enqueueOutbox(request, receipt, pendingProjection.writeIds);
      _step(GenerationCommitStep.outboxWritten);
      _step(GenerationCommitStep.beforeCommit);
      db.execute('COMMIT');
      _step(GenerationCommitStep.afterCommit);
      _refreshStores(request, receipt, finalProse, feedbackDocument);
      return GenerationCommitApplied(receipt);
    } catch (_) {
      // A fault may be deliberately injected immediately after COMMIT.  SQLite
      // reports no active transaction in that case; never issue a compensating
      // write that could undo a durable receipt.
      if (!db.autocommit) {
        db.execute('ROLLBACK');
      }
      rethrow;
    }
  }

  /// Claims revision requests for one run using the same SQLite connection as
  /// accept.  This is the safe V9 bridge while feedback remains a JSON blob.
  /// A repeated claim by the same run is idempotent; an active lease cannot be
  /// stolen by another run.
  List<GenerationFeedbackLease> claimFeedbackLeases(
    GenerationFeedbackLeaseClaimRequest request,
  ) {
    if (request.projectId.trim().isEmpty ||
        request.runId.trim().isEmpty ||
        request.claimedAtMs < 0 ||
        request.leaseExpiresAtMs <= request.claimedAtMs ||
        request.feedbackIds.any((id) => id.trim().isEmpty) ||
        request.feedbackIds.toSet().length != request.feedbackIds.length) {
      throw const GenerationMaterialConflict('feedback lease claim is invalid');
    }
    ensureTables();
    db.execute('BEGIN IMMEDIATE');
    try {
      final rows = db.select(
        'SELECT payload_json FROM author_feedback_projects WHERE project_id = ?',
        [request.projectId],
      );
      if (rows.length != 1) {
        throw const GenerationMaterialConflict(
          'feedback lease document is not available for this project',
        );
      }
      final decoded = _decodeFeedbackDocument(
        rows.single['payload_json'] as String,
      );
      final rawItems = decoded['items'];
      final rawLeases = decoded['generationLeases'];
      if (rawItems is! List || rawLeases is! Map) {
        throw const GenerationMaterialConflict(
          'feedback lease document has an incompatible shape',
        );
      }
      final items = List<Object?>.from(rawItems);
      final leases = Map<String, Object?>.from(rawLeases);
      final claimed = <GenerationFeedbackLease>[];
      for (final feedbackId in request.feedbackIds) {
        final existing = leases[feedbackId];
        if (existing is Map && existing['state'] == 'leased') {
          if (existing['ownerRunId'] != request.runId ||
              existing['expiresAtMs'] != request.leaseExpiresAtMs ||
              (existing['expiresAtMs'] as int? ?? 0) <= request.claimedAtMs) {
            throw const GenerationMaterialConflict(
              'feedback lease is already owned by another active run',
            );
          }
          claimed.add(
            GenerationFeedbackLease(
              feedbackId: feedbackId,
              ownerRunId: request.runId,
              leaseExpiresAtMs: request.leaseExpiresAtMs,
            ),
          );
          continue;
        }
        if (existing is Map && existing['state'] == 'consumed') {
          throw const GenerationMaterialConflict('feedback lease was consumed');
        }
        final itemIndex = items.indexWhere(
          (item) => item is Map && item['id'] == feedbackId,
        );
        if (itemIndex < 0 || items[itemIndex] is! Map) {
          throw const GenerationMaterialConflict('feedback item is missing');
        }
        final item = Map<String, Object?>.from(items[itemIndex] as Map);
        if (item['status'] != 'revisionRequested') {
          throw const GenerationMaterialConflict(
            'only revision-requested feedback may be leased',
          );
        }
        final decisions = List<Object?>.from(
          item['decisions'] as List? ?? const [],
        );
        decisions.insert(0, {
          'status': 'inProgress',
          'note': 'Leased by a scene generation run.',
          'createdAt': DateTime.fromMillisecondsSinceEpoch(
            request.claimedAtMs,
            isUtc: true,
          ).toIso8601String(),
          'sourceRunId': request.runId,
          'sourceReviewId': null,
        });
        item['status'] = 'inProgress';
        item['updatedAt'] = DateTime.fromMillisecondsSinceEpoch(
          request.claimedAtMs,
          isUtc: true,
        ).toIso8601String();
        item['decisions'] = decisions;
        items[itemIndex] = item;
        leases[feedbackId] = {
          'ownerRunId': request.runId,
          'expiresAtMs': request.leaseExpiresAtMs,
          'state': 'leased',
        };
        claimed.add(
          GenerationFeedbackLease(
            feedbackId: feedbackId,
            ownerRunId: request.runId,
            leaseExpiresAtMs: request.leaseExpiresAtMs,
          ),
        );
      }
      final next = {...decoded, 'items': items, 'generationLeases': leases};
      _saveFeedbackDocument(
        projectId: request.projectId,
        document: next,
        updatedAtMs: request.claimedAtMs,
      );
      db.execute('COMMIT');
      authorFeedbackStore?.applyCommittedJsonFromAuthoringTransaction(
        next,
        projectId: request.projectId,
      );
      return List.unmodifiable(claimed);
    } catch (_) {
      if (!db.autocommit) db.execute('ROLLBACK');
      rethrow;
    }
  }

  CommitReceiptRecord? _findReceiptForKey(String key) {
    final rows = db.select(
      '''
      SELECT * FROM story_generation_commit_receipts
      WHERE accept_idempotency_key = ?
      ''',
      [key],
    );
    if (rows.isEmpty) return null;
    return _receiptFromRow(rows.single);
  }

  _ValidatedCandidate _loadAndValidateCandidate(
    GenerationCommitRequest request,
  ) {
    final runRows = db.select(
      '''
      SELECT project_id, chapter_id, scene_id, scene_scope_id, status,
        current_candidate_revision
      FROM story_generation_runs WHERE run_id = ?
      ''',
      [request.runId],
    );
    if (runRows.length != 1) {
      throw const GenerationRunStateConflict('generation run does not exist');
    }
    final run = runRows.single;
    if (!_runSceneScopeIsCanonical(run) ||
        run['project_id'] != request.projectId ||
        run['scene_scope_id'] != request.sceneScopeId) {
      throw const GenerationRunStateConflict(
        'run ownership or scene scope does not match the accept request',
      );
    }
    final status = run['status'] as String;
    if (status == 'cancelled' || status == 'cancelledExpired') {
      throw const GenerationCancelWonConflict(
        'the candidate was cancelled before author accept',
      );
    }
    if (status != 'candidateReady' ||
        run['current_candidate_revision'] != request.candidateRevision) {
      throw const GenerationRunStateConflict(
        'run is not currently accepting this candidate revision',
      );
    }

    final rows = db.select(
      '''
      SELECT p.*, cp.final_prose, cp.pending_write_manifest_json,
        cp.review_payload_json, cp.quality_payload_json,
        cp.generation_evidence_receipt_json AS payload_generation_evidence_receipt_json,
        rb.bundle_hash AS generation_bundle_hash,
        n.source_prose_revision AS namespace_source_prose_revision,
        w.prose_hash AS source_prose_hash
      FROM story_generation_candidate_proofs p
      JOIN story_generation_candidate_payloads cp
        ON cp.run_id = p.run_id AND cp.candidate_revision = p.candidate_revision
      LEFT JOIN story_generation_run_bundles rb ON rb.run_id = p.run_id
      JOIN story_generation_candidate_namespaces n
        ON n.run_id = p.run_id AND n.candidate_revision = p.candidate_revision
      JOIN story_generation_working_prose_revisions w
        ON w.run_id = p.run_id AND w.prose_revision = p.source_prose_revision
      WHERE p.run_id = ? AND p.candidate_revision = ?
      ''',
      [request.runId, request.candidateRevision],
    );
    if (rows.length != 1) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate proof, payload, namespace, or source prose is missing',
      );
    }
    final row = rows.single;
    if (row['material_digest'] != request.expectedMaterialDigest) {
      throw const GenerationMaterialConflict(
        'project materials changed after this candidate was created',
      );
    }
    final evidenceMatches =
        row['project_id'] == request.projectId &&
        row['candidate_hash'] == request.candidateHash &&
        row['final_prose_hash'] == request.expectedFinalProseHash &&
        row['deterministic_gate_evidence_hash'] ==
            request.expectedDeterministicGateEvidenceHash &&
        row['final_council_evidence_hash'] ==
            request.expectedFinalCouncilEvidenceHash &&
        row['quality_evidence_hash'] == request.expectedQualityEvidenceHash &&
        row['pending_write_set_hash'] == request.expectedPendingWriteSetHash &&
        row['input_digest'] == request.expectedInputDigest &&
        row['source_prose_revision'] ==
            row['namespace_source_prose_revision'] &&
        row['final_prose_hash'] == row['source_prose_hash'];
    if (!evidenceMatches) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate proof evidence no longer matches the acceptance snapshot',
      );
    }
    final finalProse = row['final_prose'] as String;
    if (finalProse.trim().isEmpty) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate payload no longer contains final prose',
      );
    }
    if (GenerationCommitDigest.text(finalProse) !=
        request.expectedFinalProseHash) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate payload prose no longer matches its proof hash',
      );
    }
    _validateV2CandidateIdentity(
      row,
      finalProse,
      expectedRunId: request.runId,
      expectedSceneId: run['scene_id'] as String,
    );
    final manifestWriteIds = _validateManifest(
      request: request,
      manifestJson: row['pending_write_manifest_json'] as String,
      chapterId: run['chapter_id'] as String,
      sceneId: run['scene_id'] as String,
    );
    return _ValidatedCandidate(
      finalProse: finalProse,
      manifestWriteIds: manifestWriteIds,
      chapterId: run['chapter_id'] as String,
      sceneId: run['scene_id'] as String,
    );
  }

  void _validateV2CandidateIdentity(
    Row row,
    String finalProse, {
    required String expectedRunId,
    required String expectedSceneId,
  }) {
    final version = row['proof_identity_version'] as String;
    if (version == GenerationCandidateIdentity.v1) return;
    if (version != GenerationCandidateIdentity.v2) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate proof identity version is unsupported',
      );
    }
    final preparedBriefDigest = row['prepared_brief_digest'] as String?;
    final effectiveBriefDigest = row['effective_brief_digest'] as String?;
    final rawBundleHash = row['generation_bundle_hash'] as String?;
    if (preparedBriefDigest == null ||
        effectiveBriefDigest == null ||
        rawBundleHash == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(rawBundleHash)) {
      throw const GenerationCandidateEvidenceConflict(
        'V2 candidate proof is missing brief or generation-bundle identity',
      );
    }
    final mode = row['generation_evidence_mode'] as String;
    final receiptJson = row['generation_evidence_receipt_json'] as String?;
    if (mode == GenerationCandidateIdentity.sealedNoRedrawMode) {
      final GenerationEvidenceReceipt receipt;
      try {
        if (receiptJson == null || receiptJson.isEmpty) {
          throw const FormatException();
        }
        receipt = GenerationEvidenceReceipt.fromCanonicalJson(receiptJson);
      } on Object {
        throw const GenerationCandidateEvidenceConflict(
          'sealed candidate receipt is malformed or internally inconsistent',
        );
      }
      if (receipt.receiptHash != row['generation_evidence_receipt_hash'] ||
          row['run_id'] != expectedRunId ||
          row['scene_id'] != expectedSceneId ||
          receipt.evidenceRunId != expectedRunId ||
          receipt.sceneId != expectedSceneId ||
          receipt.attemptEvidenceEnvelopeDigest !=
              row['attempt_evidence_envelope_digest'] ||
          receipt.generationFingerprintSetDigest !=
              row['generation_fingerprint_set_digest'] ||
          receipt.preparedBriefDigest != preparedBriefDigest ||
          receipt.generationBundleHashes.length != 1 ||
          !receipt.generationBundleHashes.contains('sha256:$rawBundleHash') ||
          !receipt.matchesArtifactText(finalProse)) {
        throw const GenerationCandidateEvidenceConflict(
          'sealed candidate receipt no longer matches proof, bundle, or prose',
        );
      }
      if (row['payload_generation_evidence_receipt_json'] != receiptJson) {
        throw const GenerationCandidateEvidenceConflict(
          'sealed candidate payload receipt does not mirror permanent proof evidence',
        );
      }
      final reviewDigest = receipt.finalReviewParsedOutputDigest;
      final qualityDigest = receipt.finalQualityParsedOutputDigest;
      if (reviewDigest == null || qualityDigest == null) {
        throw const GenerationCandidateEvidenceConflict(
          'sealed candidate receipt lacks final parsed evaluation evidence',
        );
      }
      try {
        GenerationCandidateEvaluationPayloadIntegrity.validateSealed(
          reviewPayloadJson: row['review_payload_json'] as String,
          qualityPayloadJson: row['quality_payload_json'] as String,
          finalProseHash: row['final_prose_hash'] as String,
          deterministicGateEvidenceHash:
              row['deterministic_gate_evidence_hash'] as String,
          finalCouncilEvidenceHash:
              row['final_council_evidence_hash'] as String,
          qualityEvidenceHash: row['quality_evidence_hash'] as String,
          receiptReviewParsedOutputDigest: reviewDigest,
          receiptQualityParsedOutputDigest: qualityDigest,
        );
      } on Object {
        throw const GenerationCandidateEvidenceConflict(
          'sealed candidate parsed evaluation evidence is malformed or inconsistent',
        );
      }
    } else if (mode == GenerationCandidateIdentity.adaptiveUnsealedMode) {
      try {
        final decoded = receiptJson == null ? null : jsonDecode(receiptJson);
        if (receiptJson != null ||
            decoded != null ||
            row['payload_generation_evidence_receipt_json'] != '{}') {
          throw const FormatException();
        }
      } on Object {
        throw const GenerationCandidateEvidenceConflict(
          'adaptive-unsealed proof or payload carries unexpected sealed evidence',
        );
      }
    } else {
      throw const GenerationCandidateEvidenceConflict(
        'V2 candidate evidence mode is unsupported',
      );
    }

    final String recomputed;
    try {
      recomputed = GenerationCandidateIdentity.computeV2(
        runId: row['run_id'] as String,
        candidateRevision: row['candidate_revision'] as int,
        finalProseHash: row['final_prose_hash'] as String,
        deterministicGateEvidenceHash:
            row['deterministic_gate_evidence_hash'] as String,
        finalCouncilEvidenceHash: row['final_council_evidence_hash'] as String,
        qualityEvidenceHash: row['quality_evidence_hash'] as String,
        pendingWriteSetHash: row['pending_write_set_hash'] as String,
        materialDigest: row['material_digest'] as String,
        effectiveInputDigest: row['input_digest'] as String,
        preparedBriefDigest: preparedBriefDigest,
        effectiveBriefDigest: effectiveBriefDigest,
        generationBundleHash: 'sha256:$rawBundleHash',
        generationEvidenceMode: mode,
        generationEvidenceReceiptHash:
            row['generation_evidence_receipt_hash'] as String?,
        attemptEvidenceEnvelopeDigest:
            row['attempt_evidence_envelope_digest'] as String?,
        generationFingerprintSetDigest:
            row['generation_fingerprint_set_digest'] as String?,
      );
    } on Object {
      throw const GenerationCandidateEvidenceConflict(
        'V2 candidate proof fields cannot form a valid identity',
      );
    }
    if (recomputed != row['candidate_hash']) {
      throw const GenerationCandidateEvidenceConflict(
        'V2 candidate hash does not match its durable evidence fields',
      );
    }
  }

  List<String> _validateManifest({
    required GenerationCommitRequest request,
    required String manifestJson,
    required String chapterId,
    required String sceneId,
  }) {
    final List<dynamic> entries;
    try {
      final decoded = jsonDecode(manifestJson);
      if (decoded is List) {
        entries = decoded;
      } else if (decoded is Map && decoded['writes'] is List) {
        entries = decoded['writes'] as List<dynamic>;
      } else {
        throw const FormatException('manifest must contain a writes list');
      }
    } on FormatException {
      throw const GenerationCandidateEvidenceConflict(
        'candidate pending-write manifest is malformed',
      );
    }

    final expectedHashes = <String, String>{};
    for (final entry in entries) {
      if (entry is! Map) {
        throw const GenerationCandidateEvidenceConflict(
          'candidate pending-write manifest contains a non-object entry',
        );
      }
      final writeId = entry['writeId']?.toString().trim() ?? '';
      final payloadHash = entry['payloadHash']?.toString().trim() ?? '';
      if (writeId.isEmpty ||
          payloadHash.isEmpty ||
          expectedHashes.containsKey(writeId)) {
        throw const GenerationCandidateEvidenceConflict(
          'candidate pending-write manifest has an invalid or duplicate entry',
        );
      }
      expectedHashes[writeId] = payloadHash;
      if ((entry.containsKey('runId') && entry['runId'] != request.runId) ||
          (entry.containsKey('candidateRevision') &&
              entry['candidateRevision'] != request.candidateRevision)) {
        throw const GenerationCandidateEvidenceConflict(
          'candidate pending-write manifest crosses a candidate namespace',
        );
      }
    }
    if (GenerationPendingWritePayloadIntegrity.hashValue(entries) !=
        request.expectedPendingWriteSetHash) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate pending-write manifest does not match its proof hash',
      );
    }

    final rows = db.select(
      '''
      SELECT write_id, payload_hash, payload_json, project_id, chapter_id,
        scene_id, state
      FROM story_generation_pending_writes
      WHERE run_id = ? AND candidate_revision = ?
      ''',
      [request.runId, request.candidateRevision],
    );
    if (rows.length != expectedHashes.length) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate manifest does not cover the complete pending-write namespace',
      );
    }
    for (final row in rows) {
      final writeId = row['write_id'] as String;
      final recomputedPayloadHash = _recomputePendingWritePayloadHash(
        row['payload_json'] as String,
      );
      if (row['project_id'] != request.projectId ||
          row['chapter_id'] != chapterId ||
          row['scene_id'] != sceneId ||
          row['state'] != 'staged' ||
          expectedHashes[writeId] != row['payload_hash'] ||
          recomputedPayloadHash != row['payload_hash']) {
        throw const GenerationCandidateEvidenceConflict(
          'candidate manifest and staged pending writes do not match',
        );
      }
    }
    return expectedHashes.keys.toList(growable: false);
  }

  Map<String, Object?> _validateAndConsumeFeedbackLeases(
    GenerationCommitRequest request,
  ) {
    if (request.feedbackLeases.isEmpty) return const {};
    final rows = db.select(
      'SELECT payload_json FROM author_feedback_projects WHERE project_id = ?',
      [request.projectId],
    );
    if (rows.length != 1) {
      throw const GenerationMaterialConflict(
        'feedback lease document is not available for this project',
      );
    }
    final decoded = _decodeFeedbackDocument(
      rows.single['payload_json'] as String,
    );
    final rawItems = decoded['items'];
    final rawLeases = decoded['generationLeases'];
    if (rawItems is! List || rawLeases is! Map) {
      throw const GenerationMaterialConflict(
        'feedback lease document has an incompatible shape',
      );
    }
    final items = List<Object?>.from(rawItems);
    final leases = Map<String, Object?>.from(rawLeases);
    for (final expectedLease in request.feedbackLeases) {
      if (expectedLease.ownerRunId != request.runId ||
          expectedLease.leaseExpiresAtMs <= request.committedAtMs) {
        throw const GenerationMaterialConflict('feedback lease is invalid');
      }
      final rawLease = leases[expectedLease.feedbackId];
      if (rawLease is! Map ||
          rawLease['ownerRunId'] != request.runId ||
          rawLease['state'] != 'leased' ||
          rawLease['expiresAtMs'] != expectedLease.leaseExpiresAtMs) {
        throw const GenerationMaterialConflict(
          'feedback lease was changed or is owned by another run',
        );
      }
      final index = items.indexWhere(
        (item) => item is Map && item['id'] == expectedLease.feedbackId,
      );
      if (index < 0 || items[index] is! Map) {
        throw const GenerationMaterialConflict(
          'leased feedback item is missing',
        );
      }
      final item = Map<String, Object?>.from(items[index] as Map);
      final status = item['status'];
      if (status != 'revisionRequested' && status != 'inProgress') {
        throw const GenerationMaterialConflict(
          'leased feedback is not actionable',
        );
      }
      final decisions = List<Object?>.from(
        item['decisions'] as List? ?? const [],
      );
      decisions.insert(0, {
        'status': 'accepted',
        'note': 'Consumed by accepted scene generation candidate.',
        'createdAt': DateTime.fromMillisecondsSinceEpoch(
          request.committedAtMs,
          isUtc: true,
        ).toIso8601String(),
        'sourceRunId': request.runId,
        'sourceReviewId': null,
      });
      item['status'] = 'accepted';
      item['updatedAt'] = DateTime.fromMillisecondsSinceEpoch(
        request.committedAtMs,
        isUtc: true,
      ).toIso8601String();
      item['decisions'] = decisions;
      items[index] = item;
      leases[expectedLease.feedbackId] = {
        'ownerRunId': request.runId,
        'expiresAtMs': expectedLease.leaseExpiresAtMs,
        'state': 'consumed',
      };
    }
    return {...decoded, 'items': items, 'generationLeases': leases};
  }

  Map<String, Object?> _decodeFeedbackDocument(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } on FormatException {
      // Converted below to one typed CAS conflict.
    }
    throw const GenerationMaterialConflict(
      'feedback lease document cannot be decoded safely',
    );
  }

  String _readDraft(String sceneScopeId) {
    final rows = db.select(
      'SELECT text_body FROM draft_documents WHERE project_id = ?',
      [sceneScopeId],
    );
    return rows.isEmpty ? '' : rows.single['text_body'] as String;
  }

  String _readCandidateProse(GenerationCommitRequest request) {
    final rows = db.select(
      '''
      SELECT final_prose FROM story_generation_candidate_payloads
      WHERE run_id = ? AND candidate_revision = ?
      ''',
      [request.runId, request.candidateRevision],
    );
    return rows.isEmpty ? '' : rows.single['final_prose'] as String;
  }

  void _writeDraft(String sceneScopeId, String text, int updatedAtMs) {
    db.execute(
      '''
      INSERT INTO draft_documents (project_id, text_body, updated_at_ms)
      VALUES (?, ?, ?)
      ON CONFLICT(project_id) DO UPDATE SET
        text_body = excluded.text_body, updated_at_ms = excluded.updated_at_ms
      ''',
      [sceneScopeId, text, updatedAtMs],
    );
  }

  void _insertNewestVersion({
    required String sceneScopeId,
    required String label,
    required String content,
    required int committedAtMs,
  }) {
    db.execute(
      'DELETE FROM version_entries WHERE project_id = ? AND sequence_no >= 4',
      [sceneScopeId],
    );
    db.execute(
      '''
      UPDATE version_entries SET sequence_no = sequence_no + 100
      WHERE project_id = ?
      ''',
      [sceneScopeId],
    );
    db.execute(
      '''
      UPDATE version_entries SET sequence_no = sequence_no - 99
      WHERE project_id = ?
      ''',
      [sceneScopeId],
    );
    db.execute(
      '''
      INSERT INTO version_entries (
        project_id, sequence_no, label, content, updated_at_ms
      ) VALUES (?, 0, ?, ?, ?)
      ''',
      [sceneScopeId, label, content, committedAtMs],
    );
  }

  _PendingWriteProjection _projectAndCommitPendingWrites(
    GenerationCommitRequest request,
    _ValidatedCandidate candidate,
  ) {
    final authorityRows = db.select(
      '''
      SELECT cp.pending_write_manifest_json, p.pending_write_set_hash,
        r.project_id, r.chapter_id, r.scene_id
      FROM story_generation_candidate_payloads cp
      JOIN story_generation_candidate_proofs p
        ON p.run_id = cp.run_id
       AND p.candidate_revision = cp.candidate_revision
      JOIN story_generation_runs r ON r.run_id = cp.run_id
      WHERE cp.run_id = ? AND cp.candidate_revision = ?
      ''',
      <Object?>[request.runId, request.candidateRevision],
    );
    if (authorityRows.length != 1) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate pending-write authority disappeared before projection',
      );
    }
    final authority = authorityRows.single;
    if (authority['pending_write_set_hash'] !=
            request.expectedPendingWriteSetHash ||
        authority['project_id'] != request.projectId ||
        authority['chapter_id'] != candidate.chapterId ||
        authority['scene_id'] != candidate.sceneId) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate pending-write proof changed before projection',
      );
    }
    final revalidatedWriteIds = _validateManifest(
      request: request,
      manifestJson: authority['pending_write_manifest_json'] as String,
      chapterId: candidate.chapterId,
      sceneId: candidate.sceneId,
    );
    if (!_sameStrings(candidate.manifestWriteIds, revalidatedWriteIds)) {
      throw const GenerationCandidateEvidenceConflict(
        'candidate pending-write manifest changed before projection',
      );
    }

    final rows = db.select(
      '''
      SELECT write_id, write_kind, project_id, chapter_id, scene_id,
        payload_hash, payload_json
      FROM story_generation_pending_writes
      WHERE run_id = ? AND candidate_revision = ?
    ''',
      [request.runId, request.candidateRevision],
    );
    _ContinuityWriteProjection? continuity;
    for (final row in rows) {
      final payloadJson = row['payload_json'] as String;
      if (_recomputePendingWritePayloadHash(payloadJson) !=
          row['payload_hash']) {
        throw const GenerationCandidateEvidenceConflict(
          'staged write payload changed before projection',
        );
      }
      final payload = _decodeStagedPayload(payloadJson);
      final kind = payload['kind']?.toString();
      if (kind != row['write_kind'] || payload['schemaVersion'] != 1) {
        throw const GenerationCandidateEvidenceConflict(
          'staged write kind or schema is invalid',
        );
      }
      _requirePayloadTarget(payload, row);
      switch (kind) {
        case 'roleplaySession':
          _projectRoleplaySession(payload, row);
        case 'characterDelta':
          _projectCharacterDelta(payload, row);
        case 'thoughtAtom':
          _projectThoughtAtom(payload, row);
        case 'narrativeArc':
          _projectNarrativeArc(payload, row);
        case 'sceneSummaryContribution':
          _validateSummaryContribution(payload, row, request);
          if (continuity != null) {
            throw const GenerationCandidateEvidenceConflict(
              'candidate has multiple continuity contributions',
            );
          }
          continuity = _ContinuityWriteProjection(
            writeId: row['write_id'] as String,
            projectId: row['project_id'] as String,
            chapterId: row['chapter_id'] as String,
            sceneId: row['scene_id'] as String,
            payloadHash: row['payload_hash'] as String,
            payloadJson: payloadJson,
          );
        default:
          throw const GenerationCandidateEvidenceConflict(
            'unknown staged write kind cannot be committed',
          );
      }
    }
    db.execute(
      '''
      UPDATE story_generation_pending_writes
      SET state = 'committed', committed_at_ms = ?
      WHERE run_id = ? AND candidate_revision = ? AND state = 'staged'
      ''',
      [request.committedAtMs, request.runId, request.candidateRevision],
    );
    if (db.updatedRows != rows.length) {
      throw const GenerationCandidateEvidenceConflict(
        'pending-write namespace changed while it was being committed',
      );
    }
    return _PendingWriteProjection(
      writeIds: revalidatedWriteIds,
      continuity: continuity,
    );
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Map<String, Object?> _decodeStagedPayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } on FormatException {
      // Normalized to a typed conflict below.
    }
    throw const GenerationCandidateEvidenceConflict(
      'staged write payload is malformed',
    );
  }

  String _recomputePendingWritePayloadHash(String payloadJson) {
    try {
      return GenerationPendingWritePayloadIntegrity.hashCanonicalJson(
        payloadJson,
      );
    } on FormatException {
      throw const GenerationCandidateEvidenceConflict(
        'staged write payload is not canonical JSON',
      );
    }
  }

  void _requirePayloadTarget(Map<String, Object?> payload, Row row) {
    final target = payload['target'];
    if (target is! Map ||
        payload['projectId'] != row['project_id'] ||
        payload['chapterId'] != row['chapter_id'] ||
        payload['sceneId'] != row['scene_id'] ||
        target['projectId'] != row['project_id'] ||
        target['chapterId'] != row['chapter_id'] ||
        target['sceneId'] != row['scene_id']) {
      throw const GenerationCandidateEvidenceConflict(
        'staged write crosses its project or scene target',
      );
    }
  }

  void _projectRoleplaySession(Map<String, Object?> payload, Row row) {
    final session = payload['session'];
    if (session is! Map ||
        session['chapterId'] != row['chapter_id'] ||
        session['sceneId'] != row['scene_id'] ||
        session['sceneTitle'] is! String ||
        session['finalPublicState'] is! String ||
        session['rounds'] is! List ||
        session['committedFacts'] is! List) {
      throw const GenerationCandidateEvidenceConflict(
        'roleplay session payload is malformed',
      );
    }
    final sessionId =
        '${row['project_id']}:${row['chapter_id']}:${row['scene_id']}';
    for (final table in [
      'roleplay_turns',
      'roleplay_arbitrations',
      'roleplay_rounds',
      'roleplay_committed_facts',
    ]) {
      db.execute('DELETE FROM $table WHERE session_id = ?', [sessionId]);
    }
    db.execute('DELETE FROM roleplay_sessions WHERE id = ?', [sessionId]);
    db.execute(
      '''
      INSERT INTO roleplay_sessions
      (id, project_id, chapter_id, scene_id, scene_title, final_public_state)
      VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [
        sessionId,
        row['project_id'],
        row['chapter_id'],
        row['scene_id'],
        session['sceneTitle'],
        session['finalPublicState'],
      ],
    );
    for (final rawRound in session['rounds'] as List) {
      if (rawRound is! Map ||
          rawRound['round'] is! num ||
          rawRound['turns'] is! List ||
          rawRound['arbitration'] is! Map) {
        throw const GenerationCandidateEvidenceConflict(
          'roleplay round payload is malformed',
        );
      }
      final round = (rawRound['round'] as num).toInt();
      db.execute(
        'INSERT INTO roleplay_rounds (session_id, round) VALUES (?, ?)',
        [sessionId, round],
      );
      final turns = rawRound['turns'] as List;
      for (var index = 0; index < turns.length; index += 1) {
        final turn = turns[index];
        if (turn is! Map ||
            !_hasStrings(turn, const [
              'characterId',
              'name',
              'intent',
              'visibleAction',
              'dialogue',
              'innerState',
              'proseFragment',
              'taboo',
              'rawText',
              'skillId',
              'skillVersion',
            ]) ||
            turn['proposedMemoryDeltas'] is! List) {
          throw const GenerationCandidateEvidenceConflict(
            'roleplay turn payload is malformed',
          );
        }
        db.execute(
          '''
          INSERT INTO roleplay_turns (session_id, round, turn_order, character_id, name, intent, visible_action, dialogue, inner_state, prose_fragment, taboo, raw_text, skill_id, skill_version, proposed_memory_deltas)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            sessionId,
            round,
            index,
            turn['characterId'],
            turn['name'],
            turn['intent'],
            turn['visibleAction'],
            turn['dialogue'],
            turn['innerState'],
            turn['proseFragment'],
            turn['taboo'],
            turn['rawText'],
            turn['skillId'],
            turn['skillVersion'],
            jsonEncode(turn['proposedMemoryDeltas']),
          ],
        );
      }
      final arbitration = rawRound['arbitration'] as Map;
      if (!_hasStrings(arbitration, const [
            'fact',
            'state',
            'pressure',
            'nextPublicState',
            'rawText',
            'skillId',
            'skillVersion',
          ]) ||
          arbitration['shouldStop'] is! bool ||
          arbitration['acceptedMemoryDeltas'] is! List ||
          arbitration['rejectedMemoryDeltas'] is! List) {
        throw const GenerationCandidateEvidenceConflict(
          'roleplay arbitration payload is malformed',
        );
      }
      db.execute(
        '''
        INSERT INTO roleplay_arbitrations (session_id, round, fact, state, pressure, next_public_state, should_stop, raw_text, skill_id, skill_version, accepted_memory_deltas, rejected_memory_deltas)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          sessionId,
          round,
          arbitration['fact'],
          arbitration['state'],
          arbitration['pressure'],
          arbitration['nextPublicState'],
          arbitration['shouldStop'] == true ? 1 : 0,
          arbitration['rawText'],
          arbitration['skillId'],
          arbitration['skillVersion'],
          jsonEncode(arbitration['acceptedMemoryDeltas']),
          jsonEncode(arbitration['rejectedMemoryDeltas']),
        ],
      );
    }
    for (final fact in session['committedFacts'] as List) {
      if (fact is! Map ||
          !_hasStrings(fact, const [
            'source',
            'content',
            'previousHash',
            'contentHash',
          ]) ||
          fact['sequenceId'] is! num ||
          fact['round'] is! num) {
        throw const GenerationCandidateEvidenceConflict(
          'roleplay fact payload is malformed',
        );
      }
      db.execute(
        'INSERT INTO roleplay_committed_facts (session_id, sequence_id, round, source, content, previous_hash, content_hash) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          sessionId,
          (fact['sequenceId'] as num).toInt(),
          (fact['round'] as num).toInt(),
          fact['source'],
          fact['content'],
          fact['previousHash'],
          fact['contentHash'],
        ],
      );
    }
  }

  void _projectCharacterDelta(Map<String, Object?> payload, Row row) {
    final target = payload['target'] as Map;
    final delta = payload['delta'];
    if (target['characterId'] is! String ||
        (target['characterId'] as String).trim().isEmpty ||
        delta is! Map ||
        !_hasStrings(delta, const [
          'deltaId',
          'characterId',
          'kind',
          'content',
          'sourceTurnId',
        ]) ||
        delta['characterId'] != target['characterId'] ||
        delta['acl'] is! Map ||
        delta['sourceRound'] is! num ||
        delta['confidence'] is! num ||
        delta['accepted'] != true) {
      throw const GenerationCandidateEvidenceConflict(
        'character delta payload is malformed',
      );
    }
    final id =
        '${row['project_id']}:${row['chapter_id']}:${row['scene_id']}:${delta['deltaId']}';
    db.execute(
      '''
      INSERT OR REPLACE INTO character_memories (id, project_id, chapter_id, scene_id, character_id, kind, content, source_round, source_turn_id, confidence, data)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        id,
        row['project_id'],
        row['chapter_id'],
        row['scene_id'],
        delta['characterId'],
        delta['kind'],
        delta['content'],
        (delta['sourceRound'] as num).toInt(),
        delta['sourceTurnId'],
        (delta['confidence'] as num).toDouble(),
        jsonEncode(delta),
      ],
    );
  }

  void _projectThoughtAtom(Map<String, Object?> payload, Row row) {
    final thought = payload['thought'];
    if (thought is! Map ||
        !_hasStrings(thought, const [
          'id',
          'projectId',
          'scopeId',
          'content',
        ]) ||
        thought['projectId'] != row['project_id']) {
      throw const GenerationCandidateEvidenceConflict(
        'thought payload is malformed',
      );
    }
    db.execute(
      '''
      INSERT INTO story_thought_atoms
      (id, project_id, scope_id, thought_type, content, tier, confidence,
       abstraction_level, source_refs_json, root_source_ids_json, tags_json,
       priority, token_cost_estimate, created_at_ms)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        project_id = excluded.project_id,
        scope_id = excluded.scope_id,
        thought_type = excluded.thought_type,
        content = excluded.content,
        tier = excluded.tier,
        confidence = excluded.confidence,
        abstraction_level = excluded.abstraction_level,
        source_refs_json = excluded.source_refs_json,
        root_source_ids_json = excluded.root_source_ids_json,
        tags_json = excluded.tags_json,
        priority = excluded.priority,
        token_cost_estimate = excluded.token_cost_estimate,
        created_at_ms = excluded.created_at_ms
      ''',
      [
        thought['id'],
        row['project_id'],
        thought['scopeId'],
        thought['thoughtType']?.toString() ?? 'observation',
        thought['content'],
        thought['tier']?.toString() ?? 'scene',
        (thought['confidence'] as num?)?.toDouble() ?? 1.0,
        (thought['abstractionLevel'] as num?)?.toDouble() ?? 1.0,
        jsonEncode(thought['sourceRefs'] is List ? thought['sourceRefs'] : []),
        jsonEncode(
          thought['rootSourceIds'] is List ? thought['rootSourceIds'] : [],
        ),
        jsonEncode(thought['tags'] is List ? thought['tags'] : []),
        (thought['priority'] as num?)?.toInt() ?? 0,
        (thought['tokenCostEstimate'] as num?)?.toInt() ?? 0,
        (thought['createdAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  void _projectNarrativeArc(Map<String, Object?> payload, Row row) {
    final arc = payload['arc'];
    if (arc is! Map || payload['projectId'] != row['project_id']) {
      throw const GenerationCandidateEvidenceConflict(
        'narrative arc payload is malformed',
      );
    }
    db.execute(
      '''
      INSERT OR REPLACE INTO story_generation_committed_arcs
      (receipt_id, project_id, chapter_id, scene_id, payload_json, created_at_ms)
      VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [
        'arc:${row['write_id']}',
        row['project_id'],
        row['chapter_id'],
        row['scene_id'],
        jsonEncode(arc),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  void _validateSummaryContribution(
    Map<String, Object?> payload,
    Row row,
    GenerationCommitRequest request,
  ) {
    final contribution = payload['contribution'];
    if (contribution is! Map ||
        payload['projectId'] != row['project_id'] ||
        contribution['sceneId'] != row['scene_id'] ||
        contribution['finalProseHash'] != request.expectedFinalProseHash ||
        contribution['prose'] is! String ||
        GenerationCommitDigest.text(contribution['prose'] as String) !=
            request.expectedFinalProseHash) {
      throw const GenerationCandidateEvidenceConflict(
        'summary contribution is not bound to exact final prose',
      );
    }
  }

  bool _hasStrings(Map value, List<String> keys) =>
      keys.every((key) => value[key] is String);

  String _projectAuthoritativeSummary({
    required GenerationCommitRequest request,
    required CommitReceiptRecord receipt,
    required String finalProse,
  }) {
    final chapterId = _chapterIdForRun(request.runId);
    final contribution = <String, Object?>{
      'sceneId': request.sceneScopeId,
      'receiptId': receipt.receiptId,
      'candidateHash': receipt.committedCandidateHash,
      'prose': finalProse,
    };
    final contributionJson = jsonEncode(contribution);
    final contributionHash = GenerationCommitDigest.text(contributionJson);
    db.execute(
      '''
      INSERT OR REPLACE INTO story_generation_summary_contributions
      (receipt_id, project_id, chapter_id, scene_id, contribution_hash, payload_json, created_at_ms)
      SELECT ?, project_id, chapter_id, scene_id, ?, ?, ?
      FROM story_generation_runs WHERE run_id = ?
    ''',
      [
        receipt.receiptId,
        contributionHash,
        contributionJson,
        request.committedAtMs,
        request.runId,
      ],
    );
    final incomplete = db.select(
      '''
      SELECT 1 FROM story_generation_runs
      WHERE project_id = ? AND chapter_id = ? AND status != 'committed'
      LIMIT 1
    ''',
      [request.projectId, chapterId],
    );
    // Persist every receipt contribution even while the chapter is incomplete,
    // so the first complete head contains earlier out-of-order scene commits.
    // A head itself always represents a complete receipt set.
    if (incomplete.isNotEmpty) return '';
    final rows = db.select(
      '''
      SELECT c.receipt_id, c.contribution_hash, c.payload_json
      FROM story_generation_summary_contributions c
      JOIN story_generation_commit_receipts r ON r.receipt_id = c.receipt_id
      WHERE c.project_id = ? AND c.chapter_id = ?
      ORDER BY c.receipt_id
    ''',
      [request.projectId, _chapterIdForRun(request.runId)],
    );
    final set = [
      for (final row in rows)
        '${row['receipt_id']}:${row['contribution_hash']}',
    ];
    final setHash = GenerationCommitDigest.text(jsonEncode(set));
    final revisionId =
        'csr:${request.projectId}:${_chapterIdForRun(request.runId)}:$setHash';
    final summary = <String, Object?>{
      'chapterId': chapterId,
      'chapterTitle': chapterId,
      'sceneCount': rows.length,
      'plotProgress': [
        for (final row in rows)
          (jsonDecode(row['payload_json'] as String) as Map)['prose']
                  ?.toString() ??
              '',
      ].join('\n'),
      'createdAtMs': request.committedAtMs,
    };
    db.execute(
      '''
      INSERT OR IGNORE INTO story_generation_summary_revisions
      (revision_id, project_id, chapter_id, scene_commit_set_hash, payload_json, created_at_ms)
      VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [
        revisionId,
        request.projectId,
        chapterId,
        setHash,
        jsonEncode({'sceneCommitSetHash': setHash, 'summary': summary}),
        request.committedAtMs,
      ],
    );
    db.execute(
      '''
      INSERT INTO story_generation_summary_heads (project_id, chapter_id, revision_id, updated_at_ms)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(project_id, chapter_id) DO UPDATE SET
        revision_id = excluded.revision_id, updated_at_ms = excluded.updated_at_ms
    ''',
      [request.projectId, chapterId, revisionId, request.committedAtMs],
    );
    return revisionId;
  }

  String _chapterIdForRun(String runId) {
    final rows = db.select(
      'SELECT chapter_id FROM story_generation_runs WHERE run_id = ?',
      [runId],
    );
    if (rows.length != 1) {
      throw const GenerationRunStateConflict('run chapter is unavailable');
    }
    return rows.single['chapter_id'] as String;
  }

  void _saveFeedbackDocument({
    required String projectId,
    required Map<String, Object?> document,
    required int updatedAtMs,
  }) {
    if (document.isEmpty) return;
    db.execute(
      '''
      INSERT INTO author_feedback_projects (project_id, payload_json, updated_at_ms)
      VALUES (?, ?, ?)
      ON CONFLICT(project_id) DO UPDATE SET
        payload_json = excluded.payload_json, updated_at_ms = excluded.updated_at_ms
      ''',
      [projectId, jsonEncode(document), updatedAtMs],
    );
  }

  void _insertReceipt(CommitReceiptRecord receipt) {
    db.execute(
      '''
      INSERT INTO story_generation_commit_receipts (
        receipt_id, accept_idempotency_key, run_id, candidate_revision,
        scene_scope_id, committed_candidate_hash, previous_draft_hash,
        committed_draft_hash, version_id, version_content_hash,
        pending_write_set_hash, chapter_summary_revision_id, outbox_set_hash,
        committed_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        receipt.receiptId,
        receipt.acceptIdempotencyKey,
        receipt.runId,
        receipt.candidateRevision,
        receipt.sceneScopeId,
        receipt.committedCandidateHash,
        receipt.previousDraftHash,
        receipt.committedDraftHash,
        receipt.versionId,
        receipt.versionContentHash,
        receipt.pendingWriteSetHash,
        receipt.chapterSummaryRevisionId,
        receipt.outboxSetHash,
        receipt.committedAtMs,
      ],
    );
  }

  void _insertCommittedContinuityAuthority({
    required GenerationCommitRequest request,
    required CommitReceiptRecord receipt,
    required _ContinuityWriteProjection? continuity,
  }) {
    if (continuity == null) return;
    if (continuity.projectId != request.projectId ||
        continuity.payloadHash !=
            _recomputePendingWritePayloadHash(continuity.payloadJson)) {
      throw const GenerationCandidateEvidenceConflict(
        'continuity projection no longer matches its accepted payload',
      );
    }
    final commitOrdinal =
        db.select('''
                  SELECT COALESCE(MAX(commit_ordinal), 0) + 1 AS next_ordinal
                  FROM story_generation_committed_continuity
                ''').single['next_ordinal']
            as int;
    db.execute(
      '''
      INSERT INTO story_generation_committed_continuity (
        receipt_id, run_id, candidate_revision, project_id, chapter_id,
        scene_id, write_id, write_kind, state, payload_hash, payload_json,
        final_prose_hash, pending_write_set_hash, committed_at_ms,
        commit_ordinal
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'sceneSummaryContribution', 'committed',
        ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        receipt.receiptId,
        request.runId,
        request.candidateRevision,
        continuity.projectId,
        continuity.chapterId,
        continuity.sceneId,
        continuity.writeId,
        continuity.payloadHash,
        continuity.payloadJson,
        request.expectedFinalProseHash,
        request.expectedPendingWriteSetHash,
        request.committedAtMs,
        commitOrdinal,
      ],
    );
  }

  void _commitRun(GenerationCommitRequest request) {
    db.execute(
      '''
      UPDATE story_generation_runs
      SET status = 'committed', phase = 'committed', committed_at_ms = ?,
          updated_at_ms = ?
      WHERE run_id = ? AND status = 'candidateReady'
        AND current_candidate_revision = ? AND project_id = ?
      ''',
      [
        request.committedAtMs,
        request.committedAtMs,
        request.runId,
        request.candidateRevision,
        request.projectId,
      ],
    );
    if (db.updatedRows != 1) {
      throw const GenerationRunStateConflict(
        'run state changed while author accept was in progress',
      );
    }
  }

  void _enqueueOutbox(
    GenerationCommitRequest request,
    CommitReceiptRecord receipt,
    List<String> writeIds,
  ) {
    db.execute(
      '''
      INSERT OR IGNORE INTO story_generation_outbox (
        operation_key, run_id, project_id, entity_id, operation, payload_json,
        state, attempt_count, lease_owner, lease_expires_at_ms,
        next_attempt_at_ms, last_error_code, last_error_summary,
        source_receipt_id, created_at_ms, updated_at_ms
      ) VALUES (?, ?, ?, ?, 'index_committed_scene', ?, 'pending', 0, '', 0,
        0, NULL, NULL, ?, ?, ?)
      ''',
      [
        'index:${receipt.receiptId}',
        request.runId,
        request.projectId,
        request.sceneScopeId,
        jsonEncode({
          'runId': request.runId,
          'candidateRevision': request.candidateRevision,
          'receiptId': receipt.receiptId,
          'writeIds': writeIds,
        }),
        receipt.receiptId,
        request.committedAtMs,
        request.committedAtMs,
      ],
    );
  }

  void _refreshStores(
    GenerationCommitRequest request,
    CommitReceiptRecord receipt,
    String finalProse, [
    Map<String, Object?>? feedbackDocument,
  ]) {
    if (finalProse.isNotEmpty) {
      draftStore?.applyCommittedTextFromAuthoringTransaction(
        sceneScopeId: request.sceneScopeId,
        text: finalProse,
      );
      versionStore?.applyCommittedSnapshotFromAuthoringTransaction(
        sceneScopeId: request.sceneScopeId,
        label: request.versionLabel,
        content: finalProse,
      );
    }
    if (feedbackDocument != null) {
      authorFeedbackStore?.applyCommittedJsonFromAuthoringTransaction(
        feedbackDocument,
        projectId: request.projectId,
      );
    }
  }

  CommitReceiptRecord _receiptFromRow(Row row) => CommitReceiptRecord(
    receiptId: row['receipt_id'] as String,
    acceptIdempotencyKey: row['accept_idempotency_key'] as String,
    runId: row['run_id'] as String,
    candidateRevision: row['candidate_revision'] as int,
    sceneScopeId: row['scene_scope_id'] as String,
    committedCandidateHash: row['committed_candidate_hash'] as String,
    previousDraftHash: row['previous_draft_hash'] as String,
    committedDraftHash: row['committed_draft_hash'] as String,
    versionId: row['version_id'] as String,
    versionContentHash: row['version_content_hash'] as String,
    pendingWriteSetHash: row['pending_write_set_hash'] as String,
    chapterSummaryRevisionId: row['chapter_summary_revision_id'] as String?,
    outboxSetHash: row['outbox_set_hash'] as String,
    committedAtMs: row['committed_at_ms'] as int,
  );

  String _receiptId(GenerationCommitRequest request) =>
      'receipt:${request.runId}:${request.candidateRevision}';

  String _versionId(GenerationCommitRequest request) =>
      'version:${request.runId}:${request.candidateRevision}';

  String _outboxSetHash(GenerationCommitRequest request) =>
      'outbox:${request.runId}:${request.candidateRevision}';

  void _validateRequest(GenerationCommitRequest request) {
    final identities = [
      request.acceptIdempotencyKey,
      request.runId,
      request.projectId,
      request.sceneScopeId,
      request.candidateHash,
      request.expectedBaseDraftHash,
      request.expectedMaterialDigest,
      request.expectedInputDigest,
      request.expectedFinalProseHash,
      request.expectedDeterministicGateEvidenceHash,
      request.expectedFinalCouncilEvidenceHash,
      request.expectedQualityEvidenceHash,
      request.expectedPendingWriteSetHash,
    ];
    if (request.candidateRevision < 0 ||
        request.committedAtMs < 0 ||
        identities.any((value) => value.trim().isEmpty)) {
      throw const GenerationCandidateEvidenceConflict(
        'author accept request is missing a required immutable identity',
      );
    }
  }

  void _requireCanonicalRunSceneScope(GenerationCommitRequest request) {
    final rows = db.select(
      '''SELECT project_id, scene_id, scene_scope_id
         FROM story_generation_runs WHERE run_id = ?''',
      <Object?>[request.runId],
    );
    if (rows.length != 1 ||
        !_runSceneScopeIsCanonical(rows.single) ||
        rows.single['project_id'] != request.projectId ||
        rows.single['scene_scope_id'] != request.sceneScopeId) {
      throw const GenerationRunStateConflict(
        'run has no canonical scene address for this accept request',
      );
    }
  }

  bool _runSceneScopeIsCanonical(Row row) {
    return GenerationSceneScopeIdentity.matches(
      projectId: row['project_id'] as String,
      sceneId: row['scene_id'] as String,
      sceneScopeId: row['scene_scope_id'] as String,
    );
  }

  void _step(GenerationCommitStep step) => faultInjector?.call(step);
}

class _ValidatedCandidate {
  const _ValidatedCandidate({
    required this.finalProse,
    required this.manifestWriteIds,
    required this.chapterId,
    required this.sceneId,
  });

  final String finalProse;
  final List<String> manifestWriteIds;
  final String chapterId;
  final String sceneId;
}

class _PendingWriteProjection {
  const _PendingWriteProjection({
    required this.writeIds,
    required this.continuity,
  });

  final List<String> writeIds;
  final _ContinuityWriteProjection? continuity;
}

class _ContinuityWriteProjection {
  const _ContinuityWriteProjection({
    required this.writeId,
    required this.projectId,
    required this.chapterId,
    required this.sceneId,
    required this.payloadHash,
    required this.payloadJson,
  });

  final String writeId;
  final String projectId;
  final String chapterId;
  final String sceneId;
  final String payloadHash;
  final String payloadJson;
}

/// Canonical SHA-256 identity used by draft CAS and final-prose proof binding.
class GenerationCommitDigest {
  const GenerationCommitDigest._();

  static String text(String value) => GenerationLedgerDigest.text(value);
}
