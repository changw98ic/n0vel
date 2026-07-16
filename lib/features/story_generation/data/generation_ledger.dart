import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../app/llm/app_llm_canonical_hash.dart';
import '../../../app/state/authoring_table_definitions.dart';
import 'generation_ledger_digest.dart';
import 'generation_ledger_models.dart';

/// Canonical encoding and SHA-256 identity for pending-write payloads.
///
/// Pending writes cross two durable trust boundaries: candidate acceptance and
/// committed continuity reload.  Both boundaries use this implementation so a
/// database row cannot keep a trusted hash while its JSON bytes are replaced.
abstract final class GenerationPendingWritePayloadIntegrity {
  static String canonicalJson(Object? value) =>
      GenerationLedgerDigest.canonicalJson(value);

  static String hashCanonicalJson(String payloadJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payloadJson);
    } on FormatException {
      throw const FormatException('pending-write payload is not JSON');
    }
    if (decoded is! Map) {
      throw const FormatException('pending-write payload must be an object');
    }
    final canonical = canonicalJson(decoded);
    if (canonical != payloadJson) {
      throw const FormatException('pending-write payload is not canonical');
    }
    return GenerationLedgerDigest.text(canonical);
  }

  static String hashValue(Object? value) =>
      GenerationLedgerDigest.object(value);

  static String hashText(String value) => GenerationLedgerDigest.text(value);
}

final class _CommittedContinuityAuthority {
  const _CommittedContinuityAuthority({
    required this.commitOrdinal,
    required this.payload,
  });

  final int commitOrdinal;
  final Map<String, Object?> payload;
}

/// SQLite repository for the durable generation ledger.
///
/// It intentionally owns the few cross-row rules SQLite cannot express with a
/// plain foreign key: idempotent pending writes, proof/receipt hash matching,
/// and atomic budget reservation/settlement.
class GenerationLedgerSqliteStore {
  GenerationLedgerSqliteStore({required this.db});

  final Database db;

  static final String releaseHash = AppLlmCanonicalHash.domainHash(
    'generation-ledger-sqlite-release-v2',
    const <String, Object?>{
      'checkpoint': 'completed-row-and-artifact-evidence-atomic',
      'completedReplay': 'exact-idempotency-or-immutable-conflict',
      'transaction': 'sqlite-begin-immediate',
      'continuityReload':
          'latest-authority-per-scene-then-caller-narrative-order-v2',
    },
  );

  void ensureTables() {
    migrateStoryGenerationCheckpointRevisionIsolation(db);
    createStoryGenerationCommittedContinuityTables(db);
  }

  /// Rebuilds the latest committed narrative-entity state for an ordered
  /// prefix of scenes. Candidate rows are deliberately excluded: only writes
  /// made durable by the author-accept commit boundary may feed a later scene.
  List<Map<String, Object?>> loadCommittedContinuityLedger({
    required String projectId,
    required List<String> sourceSceneIds,
  }) {
    ensureTables();
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty || sourceSceneIds.isEmpty) {
      return const <Map<String, Object?>>[];
    }
    if (sourceSceneIds.any(
          (sceneId) => sceneId.trim().isEmpty || sceneId.trim() != sceneId,
        ) ||
        sourceSceneIds.toSet().length != sourceSceneIds.length) {
      throw const GenerationLedgerInvariantViolation(
        'committed continuity source scene order is invalid',
      );
    }
    final sourceSceneIdSet = sourceSceneIds.toSet();
    final rows = db.select(
      '''
      SELECT c.receipt_id, c.run_id, c.candidate_revision, c.project_id,
        c.chapter_id, c.scene_id, c.write_id, c.write_kind, c.state,
        c.payload_hash, c.payload_json,
        c.final_prose_hash AS authority_final_prose_hash,
        c.pending_write_set_hash AS authority_write_set_hash,
        c.committed_at_ms AS authority_committed_at_ms,
        c.commit_ordinal AS authority_commit_ordinal,
        r.status AS run_status,
        r.current_candidate_revision AS run_candidate_revision,
        r.project_id AS run_project_id, r.chapter_id AS run_chapter_id,
        r.scene_id AS run_scene_id,
        p.candidate_hash, p.final_prose_hash AS proof_final_prose_hash,
        p.pending_write_set_hash AS proof_write_set_hash,
        p.project_id AS proof_project_id, p.chapter_id AS proof_chapter_id,
        p.scene_id AS proof_scene_id,
        cr.run_id AS receipt_run_id,
        cr.candidate_revision AS receipt_candidate_revision,
        cr.committed_at_ms AS receipt_committed_at_ms,
        cr.committed_candidate_hash,
        cr.committed_draft_hash,
        cr.version_content_hash,
        cr.pending_write_set_hash AS receipt_write_set_hash
      FROM story_generation_committed_continuity c
      LEFT JOIN story_generation_runs r ON r.run_id = c.run_id
      LEFT JOIN story_generation_candidate_proofs p
        ON p.run_id = c.run_id
       AND p.candidate_revision = c.candidate_revision
      LEFT JOIN story_generation_commit_receipts cr
        ON cr.receipt_id = c.receipt_id
      WHERE c.project_id = ?
      ''',
      <Object?>[normalizedProjectId],
    );
    final latestBySceneId = <String, _CommittedContinuityAuthority>{};
    final legacySceneIds = <String>{};
    for (final row in rows) {
      final sceneId = row['scene_id'] as String;
      if (!sourceSceneIdSet.contains(sceneId)) continue;
      final payload = _validatedCommittedContinuityPayload(row);
      final commitOrdinal = row['authority_commit_ordinal'];
      if (commitOrdinal == null) {
        // Null is possible only for rows that predate the additive ordinal
        // installation. A positive row for the same scene was necessarily
        // committed later and can safely supersede this validated authority.
        legacySceneIds.add(sceneId);
        continue;
      }
      if (commitOrdinal is! int || commitOrdinal <= 0) {
        throw const GenerationLedgerInvariantViolation(
          'committed continuity has an invalid commit ordinal',
        );
      }
      final authority = _CommittedContinuityAuthority(
        commitOrdinal: commitOrdinal,
        payload: payload,
      );
      final current = latestBySceneId[sceneId];
      if (current?.commitOrdinal == commitOrdinal) {
        throw const GenerationLedgerInvariantViolation(
          'committed continuity commit ordinal is ambiguous',
        );
      }
      if (current == null || current.commitOrdinal < commitOrdinal) {
        latestBySceneId[sceneId] = authority;
      }
    }
    if (legacySceneIds.any(
      (sceneId) => !latestBySceneId.containsKey(sceneId),
    )) {
      throw const GenerationLedgerInvariantViolation(
        'committed continuity has no stable commit ordinal',
      );
    }

    final latestByEntityId = <String, Map<String, Object?>>{};
    // The workspace's ordered prefix is the production narrative authority.
    // Commit time answers only "which version of this scene is latest"; it
    // must never reorder distinct scenes in the story.
    for (final sceneId in sourceSceneIds) {
      final decoded = latestBySceneId[sceneId]?.payload;
      if (decoded == null) continue;
      final contribution = decoded['contribution'];
      if (contribution is! Map) {
        throw const GenerationLedgerInvariantViolation(
          'committed continuity contribution has no contribution payload',
        );
      }
      final rawLedger = contribution['continuityLedger'];
      if (rawLedger == null) continue;
      if (rawLedger is! List) {
        throw const GenerationLedgerInvariantViolation(
          'committed continuity ledger is not a list',
        );
      }
      for (final rawEntry in rawLedger) {
        if (rawEntry is! Map) {
          throw const GenerationLedgerInvariantViolation(
            'committed continuity ledger entry is malformed',
          );
        }
        final entry = <String, Object?>{
          for (final item in rawEntry.entries) item.key.toString(): item.value,
        };
        final entityId = entry['entityId']?.toString().trim() ?? '';
        if (entityId.isEmpty) {
          throw const GenerationLedgerInvariantViolation(
            'committed continuity ledger entry has no entityId',
          );
        }
        latestByEntityId[entityId] = entry;
      }
    }
    return <Map<String, Object?>>[
      for (final entry in latestByEntityId.values)
        Map<String, Object?>.unmodifiable(entry),
    ];
  }

  Map<String, Object?> _validatedCommittedContinuityPayload(Row row) {
    Never invalid(String message) =>
        throw GenerationLedgerInvariantViolation(message);

    final candidateRevision = row['candidate_revision'] as int;
    final payloadJson = row['payload_json'] as String;
    final storedPayloadHash = row['payload_hash'] as String;
    String recomputedPayloadHash;
    try {
      recomputedPayloadHash =
          GenerationPendingWritePayloadIntegrity.hashCanonicalJson(payloadJson);
    } on FormatException {
      invalid('committed continuity contribution is not canonical JSON');
    }
    if (recomputedPayloadHash != storedPayloadHash) {
      invalid('committed continuity contribution hash does not match payload');
    }

    final proofSetHash = row['proof_write_set_hash'];
    final finalProseHash = row['proof_final_prose_hash'];
    if (row['run_status'] != 'committed' ||
        row['run_candidate_revision'] != candidateRevision ||
        row['run_project_id'] != row['project_id'] ||
        row['run_chapter_id'] != row['chapter_id'] ||
        row['run_scene_id'] != row['scene_id'] ||
        row['proof_project_id'] != row['project_id'] ||
        row['proof_chapter_id'] != row['chapter_id'] ||
        row['proof_scene_id'] != row['scene_id'] ||
        row['receipt_run_id'] != row['run_id'] ||
        row['receipt_candidate_revision'] != candidateRevision ||
        row['receipt_committed_at_ms'] != row['authority_committed_at_ms'] ||
        row['candidate_hash'] is! String ||
        finalProseHash is! String ||
        proofSetHash is! String ||
        row['write_kind'] != 'sceneSummaryContribution' ||
        row['state'] != 'committed' ||
        row['authority_final_prose_hash'] != finalProseHash ||
        row['authority_write_set_hash'] != proofSetHash ||
        row['committed_candidate_hash'] != row['candidate_hash'] ||
        row['receipt_write_set_hash'] != proofSetHash ||
        row['committed_draft_hash'] != finalProseHash ||
        row['version_content_hash'] != finalProseHash) {
      invalid(
        'committed continuity contribution has no matching run, proof, and receipt',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(payloadJson);
    } on FormatException {
      invalid('committed continuity contribution is malformed');
    }
    if (decoded is! Map) {
      invalid('committed continuity contribution is malformed');
    }
    final result = <String, Object?>{
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    };
    final contribution = result['contribution'];
    final target = result['target'];
    if (contribution is! Map ||
        target is! Map ||
        result['kind'] != 'sceneSummaryContribution' ||
        result['projectId'] != row['project_id'] ||
        result['chapterId'] != row['chapter_id'] ||
        result['sceneId'] != row['scene_id'] ||
        target['projectId'] != row['project_id'] ||
        target['chapterId'] != row['chapter_id'] ||
        target['sceneId'] != row['scene_id'] ||
        result['schemaVersion'] != 1 ||
        contribution['sceneId'] != row['scene_id'] ||
        contribution['finalProseHash'] != finalProseHash ||
        contribution['prose'] is! String ||
        GenerationPendingWritePayloadIntegrity.hashText(
              contribution['prose'] as String,
            ) !=
            finalProseHash) {
      invalid(
        'committed continuity contribution is not bound to exact final prose',
      );
    }
    return result;
  }

  /// Persists one attempt. Completed checkpoint plus its artifact evidence are
  /// one SQLite transaction so a crash cannot expose a reusable artifact
  /// without the metadata needed to validate it.
  void saveStageCheckpoint(GenerationStageCheckpointRecord checkpoint) {
    _validateCheckpoint(checkpoint);
    _inImmediateTransaction(() {
      final existingRows = db.select(
        '''SELECT * FROM story_generation_stage_checkpoints
           WHERE run_id = ? AND prose_revision = ? AND ordinal = ?
             AND stage_attempt = ?''',
        <Object?>[
          checkpoint.runId,
          checkpoint.proseRevision,
          checkpoint.ordinal,
          checkpoint.stageAttempt,
        ],
      );
      if (existingRows.isNotEmpty) {
        final existing = _checkpointFromRow(existingRows.single);
        if (existing.isCompleted) {
          if (_sameCheckpoint(existing, checkpoint)) return;
          throw const GenerationLedgerInvariantViolation(
            'completed stage checkpoint is immutable',
          );
        }
      }
      db.execute(
        '''
        INSERT INTO story_generation_stage_checkpoints (
          run_id, prose_revision, ordinal, stage_id, stage_attempt, codec_version, status,
          input_digest, artifact_digest, upstream_chain_digest,
          base_draft_digest, material_digest, prompt_digest, model_digest,
          artifact_type, artifact_json, created_at_ms, completed_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(run_id, prose_revision, ordinal, stage_attempt) DO UPDATE SET
          stage_id = excluded.stage_id,
          codec_version = excluded.codec_version,
          status = excluded.status,
          input_digest = excluded.input_digest,
          artifact_digest = excluded.artifact_digest,
          upstream_chain_digest = excluded.upstream_chain_digest,
          base_draft_digest = excluded.base_draft_digest,
          material_digest = excluded.material_digest,
          prompt_digest = excluded.prompt_digest,
          model_digest = excluded.model_digest,
          artifact_type = excluded.artifact_type,
          artifact_json = excluded.artifact_json,
          created_at_ms = excluded.created_at_ms,
          completed_at_ms = excluded.completed_at_ms
        ''',
        [
          checkpoint.runId,
          checkpoint.proseRevision,
          checkpoint.ordinal,
          checkpoint.stageId,
          checkpoint.stageAttempt,
          checkpoint.codecVersion,
          checkpoint.status,
          checkpoint.inputDigest,
          checkpoint.artifactDigest,
          checkpoint.upstreamChainDigest,
          checkpoint.provenance.baseDraftDigest,
          checkpoint.provenance.materialDigest,
          checkpoint.provenance.promptDigest,
          checkpoint.provenance.modelDigest,
          checkpoint.artifactType,
          checkpoint.artifactJson,
          checkpoint.createdAtMs,
          checkpoint.completedAtMs,
        ],
      );
      if (checkpoint.isCompleted) {
        final evidenceDigest = checkpoint.artifactDigest;
        // The codec computes this chain digest from every provenance field;
        // storing it here avoids duplicating a crypto implementation in the
        // synchronous SQLite repository.
        final provenanceDigest = checkpoint.upstreamChainDigest;
        db.execute(
          '''
          INSERT INTO story_generation_stage_evidence (
            run_id, prose_revision, ordinal, stage_attempt, evidence_kind, evidence_digest,
            provenance_digest, created_at_ms
          ) VALUES (?, ?, ?, ?, 'artifact', ?, ?, ?)
          ON CONFLICT(run_id, prose_revision, ordinal, stage_attempt, evidence_kind)
          DO UPDATE SET evidence_digest = excluded.evidence_digest,
            provenance_digest = excluded.provenance_digest,
            created_at_ms = excluded.created_at_ms
          ''',
          [
            checkpoint.runId,
            checkpoint.proseRevision,
            checkpoint.ordinal,
            checkpoint.stageAttempt,
            evidenceDigest,
            provenanceDigest,
            checkpoint.completedAtMs,
          ],
        );
      }
    });
  }

  static bool _sameCheckpoint(
    GenerationStageCheckpointRecord left,
    GenerationStageCheckpointRecord right,
  ) =>
      left.runId == right.runId &&
      left.proseRevision == right.proseRevision &&
      left.ordinal == right.ordinal &&
      left.stageId == right.stageId &&
      left.stageAttempt == right.stageAttempt &&
      left.codecVersion == right.codecVersion &&
      left.status == right.status &&
      left.inputDigest == right.inputDigest &&
      left.artifactDigest == right.artifactDigest &&
      left.upstreamChainDigest == right.upstreamChainDigest &&
      left.provenance.baseDraftDigest == right.provenance.baseDraftDigest &&
      left.provenance.materialDigest == right.provenance.materialDigest &&
      left.provenance.promptDigest == right.provenance.promptDigest &&
      left.provenance.modelDigest == right.provenance.modelDigest &&
      left.artifactType == right.artifactType &&
      left.artifactJson == right.artifactJson &&
      left.createdAtMs == right.createdAtMs &&
      left.completedAtMs == right.completedAtMs;

  List<GenerationStageCheckpointRecord> loadStageCheckpoints({
    required String runId,
    int? proseRevision,
  }) {
    return [
      for (final row in db.select(
        '''
        SELECT * FROM story_generation_stage_checkpoints
        WHERE run_id = ?
          AND (? IS NULL OR prose_revision = ?)
        ORDER BY prose_revision ASC, ordinal ASC, stage_attempt ASC
        ''',
        [runId, proseRevision, proseRevision],
      ))
        _checkpointFromRow(row),
    ];
  }

  void _validateCheckpoint(GenerationStageCheckpointRecord checkpoint) {
    if (checkpoint.ordinal < 0 ||
        checkpoint.ordinal > 12 ||
        checkpoint.stageAttempt <= 0 ||
        checkpoint.codecVersion <= 0 ||
        (checkpoint.status != 'started' && checkpoint.status != 'completed') ||
        (checkpoint.isCompleted && checkpoint.artifactJson.trim().isEmpty)) {
      throw const GenerationLedgerInvariantViolation(
        'invalid stage checkpoint',
      );
    }
    for (final digest in [
      checkpoint.inputDigest,
      checkpoint.upstreamChainDigest,
      checkpoint.provenance.baseDraftDigest,
      checkpoint.provenance.materialDigest,
      checkpoint.provenance.promptDigest,
      checkpoint.provenance.modelDigest,
      if (checkpoint.isCompleted) checkpoint.artifactDigest,
    ]) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
        throw const GenerationLedgerInvariantViolation(
          'checkpoint digests must be canonical SHA-256 hex',
        );
      }
    }
    if (checkpoint.isCompleted) {
      try {
        final decoded = jsonDecode(checkpoint.artifactJson);
        if (decoded is! Map) {
          throw const FormatException('artifact is not object');
        }
      } on Object {
        throw const GenerationLedgerInvariantViolation(
          'checkpoint artifact must be a JSON object',
        );
      }
    }
  }

  GenerationStageCheckpointRecord _checkpointFromRow(Row row) {
    return GenerationStageCheckpointRecord(
      runId: row['run_id'] as String,
      proseRevision: row['prose_revision'] as int,
      ordinal: row['ordinal'] as int,
      stageId: row['stage_id'] as String,
      stageAttempt: row['stage_attempt'] as int,
      codecVersion: row['codec_version'] as int,
      status: row['status'] as String,
      inputDigest: row['input_digest'] as String,
      artifactDigest: row['artifact_digest'] as String,
      upstreamChainDigest: row['upstream_chain_digest'] as String,
      provenance: GenerationCheckpointProvenance(
        baseDraftDigest: row['base_draft_digest'] as String,
        materialDigest: row['material_digest'] as String,
        promptDigest: row['prompt_digest'] as String,
        modelDigest: row['model_digest'] as String,
      ),
      artifactType: row['artifact_type'] as String,
      artifactJson: row['artifact_json'] as String,
      createdAtMs: row['created_at_ms'] as int,
      completedAtMs: row['completed_at_ms'] as int?,
    );
  }

  GenerationRunRecord createRun(GenerationRunRecord run) {
    _requireIdentity(run.runId, 'runId');
    _requireIdentity(run.requestId, 'requestId');
    _requireIdentity(run.projectId, 'projectId');
    _requireIdentity(run.chapterId, 'chapterId');
    _requireIdentity(run.sceneId, 'sceneId');
    _requireIdentity(run.sceneScopeId, 'sceneScopeId');
    if (run.status == 'committing') {
      throw const GenerationLedgerInvariantViolation(
        'committing is not a persisted run state',
      );
    }
    final byRequest = db.select(
      'SELECT run_id FROM story_generation_runs WHERE request_id = ?',
      [run.requestId],
    );
    if (byRequest.isNotEmpty) {
      if (byRequest.single['run_id'] == run.runId) return run;
      throw const GenerationLedgerInvariantViolation(
        'request id is already owned by another run',
      );
    }
    db.execute(
      '''
      INSERT INTO story_generation_runs (
        run_id, request_id, project_id, chapter_id, scene_id, scene_scope_id,
        status, phase, blocked_stage, schema_version, current_prose_revision,
        current_candidate_revision, last_error_code, created_at_ms,
        updated_at_ms, committed_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        run.runId,
        run.requestId,
        run.projectId,
        run.chapterId,
        run.sceneId,
        run.sceneScopeId,
        run.status,
        run.phase,
        run.blockedStage,
        run.schemaVersion,
        run.currentProseRevision,
        run.currentCandidateRevision,
        run.lastErrorCode,
        run.createdAtMs,
        run.updatedAtMs,
        run.committedAtMs,
      ],
    );
    return run;
  }

  /// Creates (or resumes) a production run and binds it to one immutable
  /// generation bundle in the same transaction. A run can never be rebound to
  /// another bundle, even when the request is retried after a crash.
  GenerationRunRecord createRunWithGenerationBundle({
    required GenerationRunRecord run,
    required String generationBundleHash,
    required int createdAtMs,
  }) {
    final rawBundleHash = _rawPrefixedSha256(
      generationBundleHash,
      'generationBundleHash',
    );
    ensureTables();
    createAgentEvaluationTables(db);
    createAgentEvaluationV16Tables(db);
    return _inImmediateTransaction(() {
      final published = db.select(
        'SELECT 1 FROM generation_bundles WHERE bundle_hash = ?',
        <Object?>[rawBundleHash],
      );
      if (published.length != 1) {
        throw const GenerationLedgerInvariantViolation(
          'generation bundle is not published',
        );
      }
      final created = createRun(run);
      final existing = db.select(
        '''SELECT bundle_hash FROM story_generation_run_bundles
           WHERE run_id = ?''',
        <Object?>[run.runId],
      );
      if (existing.isNotEmpty &&
          (existing.length != 1 ||
              existing.single['bundle_hash'] != rawBundleHash)) {
        throw const GenerationLedgerInvariantViolation(
          'generation run is already bound to another bundle',
        );
      }
      db.execute(
        '''INSERT OR IGNORE INTO story_generation_run_bundles
           (run_id, bundle_hash, created_at_ms) VALUES (?, ?, ?)''',
        <Object?>[run.runId, rawBundleHash, createdAtMs],
      );
      final bound = db.select(
        '''SELECT bundle_hash FROM story_generation_run_bundles
           WHERE run_id = ?''',
        <Object?>[run.runId],
      );
      if (bound.length != 1 || bound.single['bundle_hash'] != rawBundleHash) {
        throw const GenerationLedgerInvariantViolation(
          'generation run bundle binding was not persisted',
        );
      }
      return created;
    });
  }

  /// Resolves the bundle identity used by every proof under [runId].
  String generationBundleHashForRun(String runId) {
    _requireIdentity(runId, 'runId');
    final rows = db.select(
      '''SELECT bundle_hash FROM story_generation_run_bundles
         WHERE run_id = ?''',
      <Object?>[runId],
    );
    if (rows.length != 1) {
      throw const GenerationLedgerInvariantViolation(
        'generation run has no unique bundle binding',
      );
    }
    return 'sha256:${rows.single['bundle_hash']}';
  }

  bool isRunBoundToGenerationBundle({
    required String runId,
    required String generationBundleHash,
  }) {
    try {
      return generationBundleHashForRun(runId) == generationBundleHash;
    } on GenerationLedgerInvariantViolation {
      return false;
    }
  }

  /// Persists a terminal or blocked run state independently of the UI
  /// snapshot. Error code is an opaque classification, never raw provider
  /// output or prompt text.
  void markRunTerminal({
    required String runId,
    required String status,
    required String phase,
    String? blockedStage,
    String? errorCode,
    required int updatedAtMs,
  }) {
    const allowed = {
      'preliminaryReviewBlocked',
      'finalReviewBlocked',
      'qualityBlocked',
      'budgetBlocked',
      'conflict',
      'failed',
      'cancelled',
    };
    if (!allowed.contains(status)) {
      throw const GenerationLedgerInvariantViolation(
        'terminal run status is not allowed',
      );
    }
    if (errorCode != null &&
        !RegExp(r'^[A-Za-z0-9_.-]{1,96}$').hasMatch(errorCode)) {
      throw const GenerationLedgerInvariantViolation(
        'terminal error code is unsafe',
      );
    }
    db.execute(
      '''UPDATE story_generation_runs
         SET status = ?, phase = ?, blocked_stage = ?, last_error_code = ?,
             updated_at_ms = ?
         WHERE run_id = ?
           AND status NOT IN ('committed', 'rejected', 'cancelled')''',
      [status, phase, blockedStage, errorCode, updatedAtMs, runId],
    );
    if (db.updatedRows != 1) {
      throw const GenerationLedgerInvariantViolation(
        'run is missing or already terminal',
      );
    }
  }

  void createWorkingProseRevision(WorkingProseRevisionRecord revision) {
    _requireIdentity(revision.proseHash, 'proseHash');
    db.execute(
      '''
      INSERT INTO story_generation_working_prose_revisions (
        run_id, prose_revision, prose_hash, prose_text, source_kind, created_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        revision.runId,
        revision.proseRevision,
        revision.proseHash,
        revision.proseText,
        revision.sourceKind,
        revision.createdAtMs,
      ],
    );
  }

  void reserveCandidateNamespace(CandidateNamespaceRecord namespace) {
    db.execute(
      '''
      INSERT INTO story_generation_candidate_namespaces (
        run_id, candidate_revision, source_prose_revision, reserved_at_ms
      ) VALUES (?, ?, ?, ?)
      ''',
      [
        namespace.runId,
        namespace.candidateRevision,
        namespace.sourceProseRevision,
        namespace.reservedAtMs,
      ],
    );
  }

  /// Returns the newest author-edit namespace that has been reserved but has
  /// not yet produced an immutable proof. This is the durable replacement for
  /// an in-memory "currently editing" flag after an app restart.
  CandidateNamespaceRecord? loadUnfinalizedCandidateNamespace({
    required String runId,
  }) {
    final rows = db.select(
      '''
      SELECT n.candidate_revision, n.source_prose_revision, n.reserved_at_ms
      FROM story_generation_candidate_namespaces n
      LEFT JOIN story_generation_candidate_proofs p
        ON p.run_id = n.run_id AND p.candidate_revision = n.candidate_revision
      WHERE n.run_id = ? AND p.candidate_revision IS NULL
      ORDER BY n.candidate_revision DESC
      LIMIT 1
      ''',
      [runId],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return CandidateNamespaceRecord(
      runId: runId,
      candidateRevision: row['candidate_revision'] as int,
      sourceProseRevision: row['source_prose_revision'] as int,
      reservedAtMs: row['reserved_at_ms'] as int,
    );
  }

  /// Starts author editing from a durable candidate without allowing the new
  /// namespace to inherit prose-derived state. Only explicitly allowlisted
  /// pre-prose writes are re-materialized with new deterministic identities.
  CandidateNamespaceRecord createEditedWorkingRevision({
    required String runId,
    required int sourceCandidateRevision,
    required String prose,
    required int nowMs,
  }) {
    if (prose.trim().isEmpty) {
      throw const GenerationLedgerInvariantViolation(
        'edited candidate prose cannot be empty',
      );
    }
    return _inImmediateTransaction(() {
      final parent = db.select(
        '''SELECT source_prose_revision FROM story_generation_candidate_namespaces
           WHERE run_id = ? AND candidate_revision = ?''',
        [runId, sourceCandidateRevision],
      );
      if (parent.length != 1) {
        throw const GenerationLedgerInvariantViolation(
          'edited revision requires an existing candidate namespace',
        );
      }
      final next =
          db
                  .select(
                    '''SELECT COALESCE(MAX(prose_revision), -1) + 1 AS next_revision
           FROM story_generation_working_prose_revisions WHERE run_id = ?''',
                    [runId],
                  )
                  .single['next_revision']
              as int;
      final nextCandidate =
          db
                  .select(
                    '''SELECT COALESCE(MAX(candidate_revision), -1) + 1 AS next_revision
           FROM story_generation_candidate_namespaces WHERE run_id = ?''',
                    [runId],
                  )
                  .single['next_revision']
              as int;
      final proseHash = _sha256Text(prose);
      createWorkingProseRevision(
        WorkingProseRevisionRecord(
          runId: runId,
          proseRevision: next,
          proseHash: proseHash,
          proseText: prose,
          sourceKind: 'authorEdit',
          createdAtMs: nowMs,
        ),
      );
      final namespace = CandidateNamespaceRecord(
        runId: runId,
        candidateRevision: nextCandidate,
        sourceProseRevision: next,
        reservedAtMs: nowMs,
      );
      reserveCandidateNamespace(namespace);
      final writes = db.select(
        '''SELECT * FROM story_generation_pending_writes
           WHERE run_id = ? AND candidate_revision = ?''',
        [runId, sourceCandidateRevision],
      );
      for (final row in writes) {
        if (row['derivation_class'] != 'preProse' ||
            !_isCloneablePreProseKind(row['write_kind'] as String)) {
          if (row['derivation_class'] == 'preProse') {
            throw const GenerationLedgerInvariantViolation(
              'unknown pre-prose write kind cannot cross an edited namespace',
            );
          }
          continue;
        }
        upsertPendingWrite(
          PendingWriteRecord(
            runId: runId,
            candidateRevision: nextCandidate,
            writeId: 'preprose-v2:$runId:$nextCandidate:${row['write_id']}',
            projectId: row['project_id'] as String,
            chapterId: row['chapter_id'] as String,
            sceneId: row['scene_id'] as String,
            logicalEntityId: row['logical_entity_id'] as String,
            writeKind: row['write_kind'] as String,
            payloadHash: row['payload_hash'] as String,
            payloadJson: row['payload_json'] as String,
            derivationClass: 'preProse',
            tier: row['tier'] as String,
            producer: row['producer'] as String,
            visibility: row['visibility'] as String,
            ownerId: row['owner_id'] as String,
            createdAtMs: nowMs,
            expiresAtMs: row['expires_at_ms'] as int,
          ),
        );
      }
      db.execute(
        '''UPDATE story_generation_runs
           SET status = 'running', phase = 'authorEdit',
             current_prose_revision = ?, current_candidate_revision = NULL,
             updated_at_ms = ? WHERE run_id = ?''',
        [next, nowMs, runId],
      );
      return namespace;
    });
  }

  bool _isCloneablePreProseKind(String kind) =>
      const {'roleplaySession', 'characterDelta'}.contains(kind);

  String _sha256Text(String value) {
    // Must be byte-for-byte compatible with the finalizer's proof identity.
    // A weaker local hash lets an edited namespace exist but makes it
    // impossible for finalization to bind that exact prose.
    return GenerationLedgerDigest.text(value);
  }

  PendingWriteRecord upsertPendingWrite(PendingWriteRecord write) {
    _validatePendingWrite(write);
    final existing = db.select(
      '''
      SELECT payload_hash, payload_json, state
      FROM story_generation_pending_writes
      WHERE run_id = ? AND candidate_revision = ? AND write_id = ?
      ''',
      [write.runId, write.candidateRevision, write.writeId],
    );
    if (existing.isNotEmpty) {
      final row = existing.single;
      if (row['payload_hash'] != write.payloadHash ||
          row['payload_json'] != write.payloadJson) {
        throw const GenerationLedgerInvariantViolation(
          'same pending-write identity has a different payload',
        );
      }
      return write;
    }
    db.execute(
      '''
      INSERT INTO story_generation_pending_writes (
        run_id, candidate_revision, write_id, project_id, chapter_id, scene_id,
        logical_entity_id, write_kind, payload_hash, payload_json,
        derivation_class, state, tier, producer, visibility, owner_id,
        created_at_ms, expires_at_ms, committed_at_ms, discarded_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        write.runId,
        write.candidateRevision,
        write.writeId,
        write.projectId,
        write.chapterId,
        write.sceneId,
        write.logicalEntityId,
        write.writeKind,
        write.payloadHash,
        write.payloadJson,
        write.derivationClass,
        write.state,
        write.tier,
        write.producer,
        write.visibility,
        write.ownerId,
        write.createdAtMs,
        write.expiresAtMs,
        write.committedAtMs,
        write.discardedAtMs,
      ],
    );
    return write;
  }

  void createCandidateProof(CandidateProofRecord proof) {
    _createCandidateProof(proof);
  }

  /// Writes provider-free finalization atomically: proof and its expiring
  /// payload are either both visible, or neither is visible after a failure.
  void finalizeCandidate({
    required CandidateProofRecord proof,
    required CandidatePayloadRecord payload,
  }) {
    if (proof.runId != payload.runId ||
        proof.candidateRevision != payload.candidateRevision) {
      throw const GenerationLedgerInvariantViolation(
        'candidate proof and payload must share one namespace',
      );
    }
    _inImmediateTransaction(() {
      _createCandidateProof(proof);
      _saveCandidatePayload(payload);
    });
  }

  /// Provider-free finalization boundary used by production generation.  The
  /// UI must not observe a ready candidate until all three rows (proof,
  /// payload, and run pointer) commit together.
  void finalizeAndMarkCandidateReady({
    required CandidateProofRecord proof,
    required CandidatePayloadRecord payload,
    required int updatedAtMs,
    required int currentProseRevision,
    GenerationStageCheckpointRecord? finalizationCheckpoint,
  }) {
    if (proof.runId != payload.runId ||
        proof.candidateRevision != payload.candidateRevision) {
      throw const GenerationLedgerInvariantViolation(
        'candidate proof and payload must share one namespace',
      );
    }
    _inImmediateTransaction(() {
      _createCandidateProof(proof);
      _saveCandidatePayload(payload);
      if (finalizationCheckpoint != null) {
        _insertStageCheckpointInTransaction(finalizationCheckpoint);
      }
      db.execute(
        '''
        UPDATE story_generation_runs
        SET status = 'candidateReady', phase = 'finalization',
          current_candidate_revision = ?, current_prose_revision = ?,
          updated_at_ms = ?, last_error_code = NULL
        WHERE run_id = ?
        ''',
        [
          proof.candidateRevision,
          currentProseRevision,
          updatedAtMs,
          proof.runId,
        ],
      );
      if (db.updatedRows != 1) {
        throw const GenerationLedgerInvariantViolation(
          'generation run is missing',
        );
      }
    });
  }

  void _insertStageCheckpointInTransaction(
    GenerationStageCheckpointRecord checkpoint,
  ) {
    _validateCheckpoint(checkpoint);
    db.execute(
      '''
      INSERT INTO story_generation_stage_checkpoints (
        run_id, prose_revision, ordinal, stage_id, stage_attempt, codec_version, status,
        input_digest, artifact_digest, upstream_chain_digest,
        base_draft_digest, material_digest, prompt_digest, model_digest,
        artifact_type, artifact_json, created_at_ms, completed_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(run_id, prose_revision, ordinal, stage_attempt) DO UPDATE SET
        status = excluded.status, artifact_digest = excluded.artifact_digest,
        artifact_type = excluded.artifact_type, artifact_json = excluded.artifact_json,
        completed_at_ms = excluded.completed_at_ms
      ''',
      [
        checkpoint.runId,
        checkpoint.proseRevision,
        checkpoint.ordinal,
        checkpoint.stageId,
        checkpoint.stageAttempt,
        checkpoint.codecVersion,
        checkpoint.status,
        checkpoint.inputDigest,
        checkpoint.artifactDigest,
        checkpoint.upstreamChainDigest,
        checkpoint.provenance.baseDraftDigest,
        checkpoint.provenance.materialDigest,
        checkpoint.provenance.promptDigest,
        checkpoint.provenance.modelDigest,
        checkpoint.artifactType,
        checkpoint.artifactJson,
        checkpoint.createdAtMs,
        checkpoint.completedAtMs,
      ],
    );
    db.execute(
      '''
      INSERT INTO story_generation_stage_evidence (
        run_id, prose_revision, ordinal, stage_attempt, evidence_kind, evidence_digest,
        provenance_digest, created_at_ms
      ) VALUES (?, ?, ?, ?, 'artifact', ?, ?, ?)
      ON CONFLICT(run_id, prose_revision, ordinal, stage_attempt, evidence_kind)
      DO UPDATE SET evidence_digest = excluded.evidence_digest,
        provenance_digest = excluded.provenance_digest,
        created_at_ms = excluded.created_at_ms
      ''',
      [
        checkpoint.runId,
        checkpoint.proseRevision,
        checkpoint.ordinal,
        checkpoint.stageAttempt,
        checkpoint.artifactDigest,
        checkpoint.upstreamChainDigest,
        checkpoint.completedAtMs,
      ],
    );
  }

  void _createCandidateProof(CandidateProofRecord proof) {
    _requireIdentity(proof.candidateHash, 'candidateHash');
    final namespace = db.select(
      '''
      SELECT source_prose_revision
      FROM story_generation_candidate_namespaces
      WHERE run_id = ? AND candidate_revision = ?
      ''',
      [proof.runId, proof.candidateRevision],
    );
    if (namespace.length != 1 ||
        namespace.single['source_prose_revision'] !=
            proof.sourceProseRevision) {
      throw const GenerationLedgerInvariantViolation(
        'proof must use its namespace source prose revision',
      );
    }
    db.execute(
      '''
      INSERT INTO story_generation_candidate_proofs (
        run_id, candidate_revision, project_id, chapter_id, scene_id,
        source_prose_revision, candidate_hash, final_prose_hash,
        deterministic_gate_evidence_hash, final_council_evidence_hash,
        quality_evidence_hash, pending_write_set_hash, material_digest,
        input_digest, created_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        proof.runId,
        proof.candidateRevision,
        proof.projectId,
        proof.chapterId,
        proof.sceneId,
        proof.sourceProseRevision,
        proof.candidateHash,
        proof.finalProseHash,
        proof.deterministicGateEvidenceHash,
        proof.finalCouncilEvidenceHash,
        proof.qualityEvidenceHash,
        proof.pendingWriteSetHash,
        proof.materialDigest,
        proof.inputDigest,
        proof.createdAtMs,
      ],
    );
  }

  void saveCandidatePayload(CandidatePayloadRecord payload) {
    _saveCandidatePayload(payload);
  }

  /// Makes a durable proof visible to the author.  This is deliberately
  /// separate from [finalizeCandidate]: the finalization transaction creates
  /// evidence first, then this pointer is moved only after both proof and
  /// payload exist.
  void markCandidateReady({
    required String runId,
    required int candidateRevision,
    required int updatedAtMs,
  }) {
    final candidate = db.select(
      '''
      SELECT 1 FROM story_generation_candidate_proofs p
      JOIN story_generation_candidate_payloads cp
        ON cp.run_id = p.run_id AND cp.candidate_revision = p.candidate_revision
      WHERE p.run_id = ? AND p.candidate_revision = ?
      ''',
      [runId, candidateRevision],
    );
    if (candidate.length != 1) {
      throw const GenerationLedgerInvariantViolation(
        'a run cannot become candidate-ready without proof and payload',
      );
    }
    db.execute(
      '''
      UPDATE story_generation_runs
      SET status = 'candidateReady', phase = 'finalization',
        current_candidate_revision = ?, updated_at_ms = ?, last_error_code = NULL
      WHERE run_id = ?
      ''',
      [candidateRevision, updatedAtMs, runId],
    );
    if (db.updatedRows != 1) {
      throw const GenerationLedgerInvariantViolation(
        'generation run is missing',
      );
    }
  }

  /// Checks the database authority behind a presentation snapshot.  A JSON
  /// snapshot is never enough to render an author-actionable candidate after
  /// restart.
  bool hasCandidateProofAndPayload({
    required String runId,
    required int candidateRevision,
    required String candidateHash,
  }) {
    final rows = db.select(
      '''
      SELECT 1
      FROM story_generation_candidate_proofs p
      JOIN story_generation_candidate_payloads cp
        ON cp.run_id = p.run_id AND cp.candidate_revision = p.candidate_revision
      WHERE p.run_id = ? AND p.candidate_revision = ? AND p.candidate_hash = ?
      ''',
      [runId, candidateRevision, candidateHash],
    );
    return rows.length == 1;
  }

  /// Rejecting a candidate never promotes its staged write set.  The proof is
  /// intentionally retained, while its payload may later follow retention.
  void rejectCandidate({
    required String runId,
    required int candidateRevision,
    required int rejectedAtMs,
  }) {
    _inImmediateTransaction(() {
      final run = db.select(
        '''
        SELECT status, current_candidate_revision FROM story_generation_runs
        WHERE run_id = ?
        ''',
        [runId],
      );
      if (run.length != 1 ||
          run.single['status'] != 'candidateReady' ||
          run.single['current_candidate_revision'] != candidateRevision) {
        throw const GenerationLedgerInvariantViolation(
          'only the current ready candidate may be rejected',
        );
      }
      db.execute(
        '''
        UPDATE story_generation_pending_writes
        SET state = 'discarded', discarded_at_ms = ?
        WHERE run_id = ? AND candidate_revision = ? AND state = 'staged'
        ''',
        [rejectedAtMs, runId, candidateRevision],
      );
      db.execute(
        '''
        UPDATE story_generation_runs
        SET status = 'rejected', phase = 'finalization', updated_at_ms = ?
        WHERE run_id = ?
        ''',
        [rejectedAtMs, runId],
      );
    });
  }

  void _saveCandidatePayload(CandidatePayloadRecord payload) {
    if (payload.expiresAtMs <= payload.createdAtMs) {
      throw const GenerationLedgerInvariantViolation(
        'candidate payload expiry must be after creation',
      );
    }
    db.execute(
      '''
      INSERT INTO story_generation_candidate_payloads (
        run_id, candidate_revision, final_prose, pending_write_manifest_json,
        retrieval_trace_json, review_payload_json, quality_payload_json,
        created_at_ms, expires_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        payload.runId,
        payload.candidateRevision,
        payload.finalProse,
        payload.pendingWriteManifestJson,
        payload.retrievalTraceJson,
        payload.reviewPayloadJson,
        payload.qualityPayloadJson,
        payload.createdAtMs,
        payload.expiresAtMs,
      ],
    );
  }

  int deleteExpiredCandidatePayloads({required int nowMs}) {
    db.execute(
      'DELETE FROM story_generation_candidate_payloads WHERE expires_at_ms <= ?',
      [nowMs],
    );
    return db.updatedRows;
  }

  int deleteExpiredPendingWrites({required int nowMs}) {
    db.execute(
      'DELETE FROM story_generation_pending_writes WHERE expires_at_ms <= ?',
      [nowMs],
    );
    return db.updatedRows;
  }

  /// Clears only discardable material in one SQLite transaction.
  ///
  /// An expired reservation cannot safely be released: the provider may have
  /// received the request just before a process crash.  It is therefore
  /// conservatively settled as `abandonedCharged`, so a restart cannot obtain
  /// a free extra provider call.  Proofs, commit receipts and their immutable
  /// identifiers are intentionally never deleted.
  GenerationRetentionReport sweepRetention({
    required int nowMs,
    int? completedCheckpointBeforeMs,
  }) {
    if (completedCheckpointBeforeMs != null &&
        completedCheckpointBeforeMs > nowMs) {
      throw const GenerationLedgerInvariantViolation(
        'checkpoint retention cutoff cannot be in the future',
      );
    }
    return _inImmediateTransaction(() {
      db.execute(
        'DELETE FROM story_generation_candidate_payloads '
        'WHERE expires_at_ms <= ?',
        [nowMs],
      );
      final deletedPayloads = db.updatedRows;

      // Pending rows are staging/cache data even after their typed projection
      // has committed. The immutable proof retains the set hash for audit.
      db.execute(
        'DELETE FROM story_generation_pending_writes '
        'WHERE expires_at_ms <= ?',
        [nowMs],
      );
      final deletedWrites = db.updatedRows;

      final expiredReservations = db.select(
        '''SELECT run_id, provider_request_id, reserved_calls,
                  reserved_tokens, reserved_cost_microusd
           FROM story_generation_budget_reservations
           WHERE state = 'reserved' AND lease_expires_at_ms <= ?''',
        [nowMs],
      );
      for (final reservation in expiredReservations) {
        final runId = reservation['run_id'] as String;
        final calls = reservation['reserved_calls'] as int;
        final tokens = reservation['reserved_tokens'] as int;
        final cost = reservation['reserved_cost_microusd'] as int;
        db.execute(
          '''UPDATE story_generation_run_budgets
             SET reserved_calls = reserved_calls - ?,
                 reserved_tokens = reserved_tokens - ?,
                 reserved_cost_microusd = reserved_cost_microusd - ?,
                 used_calls = used_calls + ?,
                 used_tokens = used_tokens + ?,
                 used_cost_microusd = used_cost_microusd + ?,
                 updated_at_ms = ?
             WHERE run_id = ?''',
          [calls, tokens, cost, calls, tokens, cost, nowMs, runId],
        );
        if (db.updatedRows != 1) {
          throw const GenerationLedgerInvariantViolation(
            'expired reservation has no budget ledger',
          );
        }
        db.execute(
          '''UPDATE story_generation_budget_reservations
             SET actual_calls = ?, actual_tokens = ?,
                 actual_cost_microusd = ?, state = 'abandonedCharged',
                 settled_at_ms = ?
             WHERE run_id = ? AND provider_request_id = ?
               AND state = 'reserved' ''',
          [
            calls,
            tokens,
            cost,
            nowMs,
            runId,
            reservation['provider_request_id'] as String,
          ],
        );
        if (db.updatedRows != 1) {
          throw const GenerationLedgerInvariantViolation(
            'expired reservation settlement raced unexpectedly',
          );
        }
      }

      var deletedCheckpoints = 0;
      if (completedCheckpointBeforeMs != null) {
        // Completed checkpoints are a replay cache, never authority. Keep
        // active/recoverable runs untouched; terminal run caches can go.
        db.execute(
          '''DELETE FROM story_generation_stage_checkpoints
             WHERE status = 'completed' AND completed_at_ms <= ?
               AND run_id IN (
                 SELECT run_id FROM story_generation_runs
                 WHERE status IN ('completed', 'failed', 'cancelled',
                   'budgetBlocked', 'qualityBlocked',
                   'preliminaryReviewBlocked', 'finalReviewBlocked',
                   'conflict')
               )''',
          [completedCheckpointBeforeMs],
        );
        deletedCheckpoints = db.updatedRows;
      }

      return GenerationRetentionReport(
        deletedCandidatePayloads: deletedPayloads,
        deletedPendingWrites: deletedWrites,
        abandonedReservations: expiredReservations.length,
        deletedStageCheckpoints: deletedCheckpoints,
      );
    });
  }

  CommitReceiptRecord createCommitReceipt(CommitReceiptRecord receipt) {
    final existing = db.select(
      '''
      SELECT receipt_id, run_id, candidate_revision
      FROM story_generation_commit_receipts
      WHERE accept_idempotency_key = ?
      ''',
      [receipt.acceptIdempotencyKey],
    );
    if (existing.isNotEmpty) {
      final row = existing.single;
      if (row['run_id'] == receipt.runId &&
          row['candidate_revision'] == receipt.candidateRevision) {
        return receipt;
      }
      throw const GenerationLedgerInvariantViolation(
        'accept idempotency key belongs to another candidate',
      );
    }
    final proof = db.select(
      '''
      SELECT candidate_hash, pending_write_set_hash
      FROM story_generation_candidate_proofs
      WHERE run_id = ? AND candidate_revision = ?
      ''',
      [receipt.runId, receipt.candidateRevision],
    );
    if (proof.length != 1 ||
        proof.single['candidate_hash'] != receipt.committedCandidateHash ||
        proof.single['pending_write_set_hash'] != receipt.pendingWriteSetHash) {
      throw const GenerationLedgerInvariantViolation(
        'commit receipt must match a durable candidate proof',
      );
    }
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
    return receipt;
  }

  void initializeBudget(RunBudgetRecord budget) {
    final existing = db.select(
      '''
      SELECT max_calls, max_tokens, max_cost_microusd
      FROM story_generation_run_budgets WHERE run_id = ?
      ''',
      [budget.runId],
    );
    if (existing.isNotEmpty) {
      final row = existing.single;
      if (row['max_calls'] == budget.maxCalls &&
          row['max_tokens'] == budget.maxTokens &&
          row['max_cost_microusd'] == budget.maxCostMicrousd) {
        return;
      }
      throw const GenerationLedgerInvariantViolation(
        'run budget limits are immutable',
      );
    }
    db.execute(
      '''
      INSERT INTO story_generation_run_budgets (
        run_id, max_calls, max_tokens, max_cost_microusd, updated_at_ms
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      [
        budget.runId,
        budget.maxCalls,
        budget.maxTokens,
        budget.maxCostMicrousd,
        budget.updatedAtMs,
      ],
    );
  }

  BudgetReservationRecord reserveBudget(BudgetReservationRequest request) {
    _validateReservation(request);
    return _inImmediateTransaction(() {
      final existing = db.select(
        '''
        SELECT reservation_id, reserved_calls, reserved_tokens,
          reserved_cost_microusd, state, actual_calls, actual_tokens,
          actual_cost_microusd, settled_at_ms
        FROM story_generation_budget_reservations
        WHERE run_id = ? AND provider_request_id = ?
        ''',
        [request.runId, request.providerRequestId],
      );
      if (existing.isNotEmpty) {
        final row = existing.single;
        if (row['reservation_id'] != request.reservationId ||
            row['reserved_calls'] != request.reservedCalls ||
            row['reserved_tokens'] != request.reservedTokens ||
            row['reserved_cost_microusd'] != request.reservedCostMicrousd) {
          throw const GenerationLedgerInvariantViolation(
            'provider request already has a different reservation',
          );
        }
        return _reservationFromRow(request, row);
      }
      db.execute(
        '''
        UPDATE story_generation_run_budgets
        SET reserved_calls = reserved_calls + ?,
            reserved_tokens = reserved_tokens + ?,
            reserved_cost_microusd = reserved_cost_microusd + ?,
            updated_at_ms = ?
        WHERE run_id = ?
          AND reserved_calls + used_calls + ? <= max_calls
          AND reserved_tokens + used_tokens + ? <= max_tokens
          AND reserved_cost_microusd + used_cost_microusd + ? <= max_cost_microusd
        ''',
        [
          request.reservedCalls,
          request.reservedTokens,
          request.reservedCostMicrousd,
          request.createdAtMs,
          request.runId,
          request.reservedCalls,
          request.reservedTokens,
          request.reservedCostMicrousd,
        ],
      );
      if (db.updatedRows != 1) {
        throw GenerationBudgetUnavailable(request.runId);
      }
      db.execute(
        '''
        INSERT INTO story_generation_budget_reservations (
          run_id, provider_request_id, reservation_id, reserved_calls,
          reserved_tokens, reserved_cost_microusd, state, lease_owner,
          lease_expires_at_ms, created_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, 'reserved', ?, ?, ?)
        ''',
        [
          request.runId,
          request.providerRequestId,
          request.reservationId,
          request.reservedCalls,
          request.reservedTokens,
          request.reservedCostMicrousd,
          request.leaseOwner,
          request.leaseExpiresAtMs,
          request.createdAtMs,
        ],
      );
      return BudgetReservationRecord(
        runId: request.runId,
        providerRequestId: request.providerRequestId,
        reservationId: request.reservationId,
        reservedCalls: request.reservedCalls,
        reservedTokens: request.reservedTokens,
        reservedCostMicrousd: request.reservedCostMicrousd,
        leaseOwner: request.leaseOwner,
        leaseExpiresAtMs: request.leaseExpiresAtMs,
        createdAtMs: request.createdAtMs,
        state: 'reserved',
      );
    });
  }

  BudgetReservationRecord settleBudget({
    required String runId,
    required String providerRequestId,
    required int actualCalls,
    required int actualTokens,
    required int actualCostMicrousd,
    required int settledAtMs,
  }) {
    if (actualCalls < 0 || actualTokens < 0 || actualCostMicrousd < 0) {
      throw const GenerationLedgerInvariantViolation(
        'actual budget usage cannot be negative',
      );
    }
    return _inImmediateTransaction(() {
      final rows = db.select(
        '''
        SELECT * FROM story_generation_budget_reservations
        WHERE run_id = ? AND provider_request_id = ?
        ''',
        [runId, providerRequestId],
      );
      if (rows.length != 1) {
        throw const GenerationLedgerInvariantViolation('reservation not found');
      }
      final row = rows.single;
      final request = BudgetReservationRequest(
        runId: runId,
        providerRequestId: providerRequestId,
        reservationId: row['reservation_id'] as String,
        reservedCalls: row['reserved_calls'] as int,
        reservedTokens: row['reserved_tokens'] as int,
        reservedCostMicrousd: row['reserved_cost_microusd'] as int,
        leaseOwner: row['lease_owner'] as String,
        leaseExpiresAtMs: row['lease_expires_at_ms'] as int,
        createdAtMs: row['created_at_ms'] as int,
      );
      if (row['state'] != 'reserved') {
        return _reservationFromRow(request, row);
      }
      if (actualCalls > request.reservedCalls ||
          actualTokens > request.reservedTokens ||
          actualCostMicrousd > request.reservedCostMicrousd) {
        throw const GenerationLedgerInvariantViolation(
          'actual usage exceeds its conservative reservation',
        );
      }
      db.execute(
        '''
        UPDATE story_generation_run_budgets
        SET reserved_calls = reserved_calls - ?,
            reserved_tokens = reserved_tokens - ?,
            reserved_cost_microusd = reserved_cost_microusd - ?,
            used_calls = used_calls + ?,
            used_tokens = used_tokens + ?,
            used_cost_microusd = used_cost_microusd + ?,
            updated_at_ms = ?
        WHERE run_id = ?
        ''',
        [
          request.reservedCalls,
          request.reservedTokens,
          request.reservedCostMicrousd,
          actualCalls,
          actualTokens,
          actualCostMicrousd,
          settledAtMs,
          runId,
        ],
      );
      db.execute(
        '''
        UPDATE story_generation_budget_reservations
        SET actual_calls = ?, actual_tokens = ?, actual_cost_microusd = ?,
            state = 'settled', settled_at_ms = ?
        WHERE run_id = ? AND provider_request_id = ?
        ''',
        [
          actualCalls,
          actualTokens,
          actualCostMicrousd,
          settledAtMs,
          runId,
          providerRequestId,
        ],
      );
      return BudgetReservationRecord(
        runId: request.runId,
        providerRequestId: request.providerRequestId,
        reservationId: request.reservationId,
        reservedCalls: request.reservedCalls,
        reservedTokens: request.reservedTokens,
        reservedCostMicrousd: request.reservedCostMicrousd,
        leaseOwner: request.leaseOwner,
        leaseExpiresAtMs: request.leaseExpiresAtMs,
        createdAtMs: request.createdAtMs,
        state: 'settled',
        actualCalls: actualCalls,
        actualTokens: actualTokens,
        actualCostMicrousd: actualCostMicrousd,
        settledAtMs: settledAtMs,
      );
    });
  }

  void appendEvent(GenerationEventRecord event) {
    _rejectUnsafeEventText(event.errorSummary);
    _rejectUnsafeEventText(event.metadataJson);
    db.execute(
      '''
      INSERT INTO story_generation_events (
        event_id, run_id, sequence_no, stage_id, reviewer_id, event_type,
        attempt, duration_ms, failure_code, error_code, error_summary,
        metadata_json, created_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        event.eventId,
        event.runId,
        event.sequenceNo,
        event.stageId,
        event.reviewerId,
        event.eventType,
        event.attempt,
        event.durationMs,
        event.failureCode,
        event.errorCode,
        event.errorSummary,
        event.metadataJson,
        event.createdAtMs,
      ],
    );
  }

  void enqueueOutbox(GenerationOutboxRecord outbox) {
    final existing = db.select(
      'SELECT operation_key FROM story_generation_outbox WHERE operation_key = ?',
      [outbox.operationKey],
    );
    if (existing.isNotEmpty) return;
    db.execute(
      '''
      INSERT INTO story_generation_outbox (
        operation_key, run_id, project_id, entity_id, operation, payload_json,
        state, attempt_count, lease_owner, lease_expires_at_ms,
        next_attempt_at_ms, last_error_code, last_error_summary,
        source_receipt_id, created_at_ms, updated_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        outbox.operationKey,
        outbox.runId,
        outbox.projectId,
        outbox.entityId,
        outbox.operation,
        outbox.payloadJson,
        outbox.state,
        outbox.attemptCount,
        outbox.leaseOwner,
        outbox.leaseExpiresAtMs,
        outbox.nextAttemptAtMs,
        outbox.lastErrorCode,
        outbox.lastErrorSummary,
        outbox.sourceReceiptId,
        outbox.createdAtMs,
        outbox.updatedAtMs,
      ],
    );
  }

  /// Leases due derived-index work. The lease transition is atomic so two
  /// application processes cannot index the same receipt concurrently.
  List<GenerationOutboxRecord> claimDueOutbox({
    required String leaseOwner,
    required int nowMs,
    required int leaseDurationMs,
    int maxItems = 16,
    String? sourceReceiptId,
  }) {
    _requireIdentity(leaseOwner, 'leaseOwner');
    if (sourceReceiptId != null) {
      _requireIdentity(sourceReceiptId, 'sourceReceiptId');
    }
    if (leaseDurationMs <= 0 || maxItems <= 0) {
      throw const GenerationLedgerInvariantViolation('outbox lease is invalid');
    }
    return _inImmediateTransaction(() {
      final receiptClause = sourceReceiptId == null
          ? ''
          : 'source_receipt_id = ? AND ';
      final rows = db.select(
        '''SELECT * FROM story_generation_outbox
           WHERE $receiptClause
             ((state IN ('pending', 'failed') AND next_attempt_at_ms <= ?)
              OR (state = 'leased' AND lease_expires_at_ms <= ?))
           ORDER BY next_attempt_at_ms, created_at_ms, operation_key
           LIMIT ?''',
        [?sourceReceiptId, nowMs, nowMs, maxItems],
      );
      final claimed = <GenerationOutboxRecord>[];
      for (final row in rows) {
        final key = row['operation_key'] as String;
        db.execute(
          '''UPDATE story_generation_outbox
             SET state = 'leased', lease_owner = ?, lease_expires_at_ms = ?,
                 attempt_count = attempt_count + 1, updated_at_ms = ?
             WHERE operation_key = ?
               AND ((state IN ('pending', 'failed') AND next_attempt_at_ms <= ?)
                    OR (state = 'leased' AND lease_expires_at_ms <= ?))''',
          [leaseOwner, nowMs + leaseDurationMs, nowMs, key, nowMs, nowMs],
        );
        if (db.updatedRows == 1) {
          final fresh = db.select(
            'SELECT * FROM story_generation_outbox WHERE operation_key = ?',
            [key],
          );
          if (fresh.length == 1) claimed.add(_outboxFromRow(fresh.single));
        }
      }
      return claimed;
    });
  }

  void completeOutbox({
    required String operationKey,
    required String leaseOwner,
    required int completedAtMs,
  }) {
    db.execute(
      '''UPDATE story_generation_outbox
         SET state = 'completed', lease_owner = '', lease_expires_at_ms = 0,
             next_attempt_at_ms = 0, last_error_code = NULL,
             last_error_summary = NULL, updated_at_ms = ?
         WHERE operation_key = ? AND state = 'leased' AND lease_owner = ?''',
      [completedAtMs, operationKey, leaseOwner],
    );
    if (db.updatedRows != 1) {
      throw const GenerationLedgerInvariantViolation('outbox lease is lost');
    }
  }

  void retryOutbox({
    required String operationKey,
    required String leaseOwner,
    required String errorCode,
    required int nextAttemptAtMs,
    required int updatedAtMs,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_.-]{1,96}$').hasMatch(errorCode)) {
      throw const GenerationLedgerInvariantViolation(
        'outbox error code is unsafe',
      );
    }
    db.execute(
      '''UPDATE story_generation_outbox
         SET state = 'failed', lease_owner = '', lease_expires_at_ms = 0,
             next_attempt_at_ms = ?, last_error_code = ?,
             last_error_summary = NULL, updated_at_ms = ?
         WHERE operation_key = ? AND state = 'leased' AND lease_owner = ?''',
      [nextAttemptAtMs, errorCode, updatedAtMs, operationKey, leaseOwner],
    );
    if (db.updatedRows != 1) {
      throw const GenerationLedgerInvariantViolation('outbox lease is lost');
    }
  }

  T _inImmediateTransaction<T>(T Function() body) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final value = body();
      db.execute('COMMIT');
      return value;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  BudgetReservationRecord _reservationFromRow(
    BudgetReservationRequest request,
    Row row,
  ) {
    return BudgetReservationRecord(
      runId: request.runId,
      providerRequestId: request.providerRequestId,
      reservationId: request.reservationId,
      reservedCalls: request.reservedCalls,
      reservedTokens: request.reservedTokens,
      reservedCostMicrousd: request.reservedCostMicrousd,
      leaseOwner: request.leaseOwner,
      leaseExpiresAtMs: request.leaseExpiresAtMs,
      createdAtMs: request.createdAtMs,
      state: row['state'] as String,
      actualCalls: row['actual_calls'] as int?,
      actualTokens: row['actual_tokens'] as int?,
      actualCostMicrousd: row['actual_cost_microusd'] as int?,
      settledAtMs: row['settled_at_ms'] as int?,
    );
  }

  GenerationOutboxRecord _outboxFromRow(Row row) => GenerationOutboxRecord(
    operationKey: row['operation_key'] as String,
    runId: row['run_id'] as String,
    projectId: row['project_id'] as String,
    entityId: row['entity_id'] as String,
    operation: row['operation'] as String,
    payloadJson: row['payload_json'] as String,
    sourceReceiptId: row['source_receipt_id'] as String?,
    state: row['state'] as String,
    attemptCount: row['attempt_count'] as int,
    leaseOwner: row['lease_owner'] as String,
    leaseExpiresAtMs: row['lease_expires_at_ms'] as int,
    nextAttemptAtMs: row['next_attempt_at_ms'] as int,
    lastErrorCode: row['last_error_code'] as String?,
    lastErrorSummary: row['last_error_summary'] as String?,
    createdAtMs: row['created_at_ms'] as int,
    updatedAtMs: row['updated_at_ms'] as int,
  );

  void _validatePendingWrite(PendingWriteRecord write) {
    _requireIdentity(write.runId, 'runId');
    _requireIdentity(write.writeId, 'writeId');
    _requireIdentity(write.payloadHash, 'payloadHash');
    if (write.derivationClass != 'preProse' &&
        write.derivationClass != 'proseDerived') {
      throw const GenerationLedgerInvariantViolation(
        'pending write derivation class is invalid',
      );
    }
    if (write.expiresAtMs <= write.createdAtMs) {
      throw const GenerationLedgerInvariantViolation(
        'pending write expiry must be after creation',
      );
    }
  }

  void _validateReservation(BudgetReservationRequest request) {
    _requireIdentity(request.runId, 'runId');
    _requireIdentity(request.providerRequestId, 'providerRequestId');
    _requireIdentity(request.reservationId, 'reservationId');
    if (request.reservedCalls < 0 ||
        request.reservedTokens < 0 ||
        request.reservedCostMicrousd < 0) {
      throw const GenerationLedgerInvariantViolation(
        'reserved budget cannot be negative',
      );
    }
  }

  void _rejectUnsafeEventText(String? value) {
    if (value == null) return;
    final normalized = value.toLowerCase();
    if (normalized.contains('authorization') ||
        normalized.contains('api_key') ||
        normalized.contains('bearer ')) {
      throw const GenerationLedgerInvariantViolation(
        'event payload contains disallowed secret-like content',
      );
    }
  }

  void _requireIdentity(String value, String field) {
    if (value.trim().isEmpty) {
      throw GenerationLedgerInvariantViolation('$field is required');
    }
  }

  String _rawPrefixedSha256(String value, String field) {
    if (!RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(value)) {
      throw GenerationLedgerInvariantViolation(
        '$field must be a prefixed canonical SHA-256 digest',
      );
    }
    return value.substring('sha256:'.length);
  }
}
