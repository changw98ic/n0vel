import 'package:novel_writer/app/state/authoring_table_definitions.dart';
import 'package:sqlite3/sqlite3.dart';

/// Seeds a candidate written by the pre-V28 system.
///
/// Current production APIs intentionally reject V1 proof writes. Tests that
/// cover compatibility therefore model an already-migrated database row
/// instead of using an escape hatch in the writer.
void seedHistoricalV1Candidate({
  required Database db,
  required String runId,
  required int candidateRevision,
  required String projectId,
  required String chapterId,
  required String sceneId,
  required int sourceProseRevision,
  required String candidateHash,
  required String finalProseHash,
  required String deterministicGateEvidenceHash,
  required String finalCouncilEvidenceHash,
  required String qualityEvidenceHash,
  required String pendingWriteSetHash,
  required String materialDigest,
  required String inputDigest,
  required String finalProse,
  required String pendingWriteManifestJson,
  required int createdAtMs,
  required int expiresAtMs,
}) {
  // V1 fixtures predate run-bundle rows, but current read queries retain a
  // nullable LEFT JOIN to the additive table.  Install its shape without
  // fabricating a bundle binding.
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_run_bundles (
      run_id TEXT PRIMARY KEY,
      bundle_hash TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL DEFAULT 0
    )
  ''');
  _withHistoricalV1SeedAdmission(
    db,
    () => db.execute(
      '''
    INSERT INTO story_generation_candidate_proofs (
      run_id, candidate_revision, project_id, chapter_id, scene_id,
      source_prose_revision, candidate_hash, final_prose_hash,
      deterministic_gate_evidence_hash, final_council_evidence_hash,
      quality_evidence_hash, pending_write_set_hash, material_digest,
      input_digest, proof_identity_version, generation_evidence_mode,
      created_at_ms
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
      'candidate-proof-v1', 'legacy-unsealed-v1', ?)
    ''',
      <Object?>[
        runId,
        candidateRevision,
        projectId,
        chapterId,
        sceneId,
        sourceProseRevision,
        candidateHash,
        finalProseHash,
        deterministicGateEvidenceHash,
        finalCouncilEvidenceHash,
        qualityEvidenceHash,
        pendingWriteSetHash,
        materialDigest,
        inputDigest,
        createdAtMs,
      ],
    ),
  );
  db.execute(
    '''
    INSERT INTO story_generation_candidate_payloads (
      run_id, candidate_revision, final_prose, pending_write_manifest_json,
      created_at_ms, expires_at_ms
    ) VALUES (?, ?, ?, ?, ?, ?)
    ''',
    <Object?>[
      runId,
      candidateRevision,
      finalProse,
      pendingWriteManifestJson,
      createdAtMs,
      expiresAtMs,
    ],
  );
}

void _withHistoricalV1SeedAdmission(Database db, void Function() seed) {
  db.execute(
    'DROP TRIGGER IF EXISTS prevent_new_legacy_generation_proof_insert',
  );
  try {
    seed();
  } finally {
    createCandidateProofV2WriteGuards(db);
  }
}
