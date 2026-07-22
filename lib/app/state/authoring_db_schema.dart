import 'package:sqlite3/sqlite3.dart';

import '../rag/vector_store_schema.dart';
import 'db_schema_manager.dart';
import 'authoring_legacy_migrations.dart';
import 'authoring_table_definitions.dart';
import 'fulltext_search_storage.dart';

const List<SchemaMigration> authoringSchemaMigrations = [
  SchemaMigration(
    version: 1,
    description:
        'Initial authoring schema: workspace, version, draft, '
        'ai_history, scene_context, json_blobs, story_memory tables. '
        'Includes legacy data migration from pre-versioned databases.',
    migrate: _migrateAuthoringV1,
  ),
  SchemaMigration(
    version: 2,
    description: 'Add roleplay session and character memory artifact tables.',
    migrate: _migrateAuthoringV2,
  ),
  SchemaMigration(
    version: 3,
    description:
        'Add character_relations table for inter-character relationships.',
    migrate: _migrateAuthoringV3,
  ),
  SchemaMigration(
    version: 4,
    description:
        'Add story_arc_states table for narrative arc and foreshadowing persistence.',
    migrate: _migrateAuthoringV4,
  ),
  SchemaMigration(
    version: 5,
    description:
        'Add fulltext search tables (fulltext_chapter_contents + fulltext_chapters FTS5) '
        'for chapter/scene full-text search with CJK support.',
    migrate: _migrateAuthoringV5,
  ),
  SchemaMigration(
    version: 6,
    description:
        'Add writing_daily_stats, writing_project_stats, and writing_goals tables.',
    migrate: _migrateAuthoringV6,
  ),
  SchemaMigration(
    version: 7,
    description:
        'Replace JSON vector embeddings with project-scoped Float32 BLOBs '
        'and a SQLite-indexed LSH candidate table.',
    migrate: _migrateAuthoringV7,
  ),
  SchemaMigration(
    version: 8,
    description:
        'Align normalized story memory tables with runtime tier and producer '
        'fields used by StoryMemoryStorageIO.',
    migrate: _migrateAuthoringV8,
  ),
  SchemaMigration(
    version: 9,
    description:
        'Add the typed story-generation ledger, durable candidate proof, '
        'budget, event, and outbox persistence tables.',
    migrate: _migrateAuthoringV9,
  ),
  SchemaMigration(
    version: 10,
    description:
        'Add hash-bound, provenance-aware stage checkpoint and evidence '
        'records for latest-compatible scene-generation resume.',
    migrate: _migrateAuthoringV10,
  ),
  SchemaMigration(
    version: 11,
    description:
        'Add canonical material-source journal and immutable run manifests '
        'for in-transaction author-accept material CAS.',
    migrate: _migrateAuthoringV11,
  ),
  SchemaMigration(
    version: 12,
    description:
        'Add receipt-bound chapter summary heads, revisions, contributions, '
        'and authoritative narrative continuity projections.',
    migrate: _migrateAuthoringV12,
  ),
  SchemaMigration(
    version: 13,
    description:
        'Bind stage checkpoints and evidence to working prose revisions so '
        'edited candidate namespaces cannot reuse earlier cache rows.',
    migrate: _migrateAuthoringV13,
  ),
  SchemaMigration(
    version: 14,
    description:
        'Make checkpoint prose revisions real working-prose foreign-key '
        'parents and invalidate dangling legacy cache rows.',
    migrate: _migrateAuthoringV14,
  ),
  SchemaMigration(
    version: 15,
    description:
        'Add immutable agent-evaluation releases, manifests, canonical cells, '
        'trial ledgers, observations, scorecards, and prompt channel decisions.',
    migrate: _migrateAuthoringV15,
  ),
  SchemaMigration(
    version: 16,
    description:
        'Add schema compatibility contracts, immutable generation-run bundle '
        'binding, and holdout family/token/confirmation authority.',
    migrate: _migrateAuthoringV16,
  ),
  SchemaMigration(
    version: 17,
    description:
        'Require append-only release-gate verdicts, pre-spent holdout access, '
        'verified promotion authorization, and immutable sealed trial evidence.',
    migrate: _migrateAuthoringV17,
  ),
  SchemaMigration(
    version: 18,
    description:
        'Bind release verdicts to DB-derived authority projections and reject '
        'attempt or observation appends after slot sealing.',
    migrate: _migrateAuthoringV18,
  ),
  SchemaMigration(
    version: 19,
    description:
        'Add immutable seeded evaluation dispatch plans and hash-chained '
        'claim, recovery, and seal events.',
    migrate: _migrateAuthoringV19,
  ),
  SchemaMigration(
    version: 20,
    description:
        'Backfill immutable production evaluation authority receipts, '
        'executor recovery results, and frozen provider price releases.',
    migrate: _migrateAuthoringV20,
  ),
  SchemaMigration(
    version: 21,
    description:
        'Add append-only, gate-recomputable deterministic quality receipts.',
    migrate: _migrateAuthoringV21,
  ),
  SchemaMigration(
    version: 22,
    description:
        'Add lease-fenced durable sandbox generations and independently '
        'signed trusted-holdout attestations.',
    migrate: _migrateAuthoringV22,
  ),
  SchemaMigration(
    version: 23,
    description:
        'Separate regression and opaque production-holdout authorities, '
        'and persist only signed redacted production attestations.',
    migrate: _migrateAuthoringV23,
  ),
  SchemaMigration(
    version: 24,
    description:
        'Freeze a unique production holdout family authority so changing a '
        'coordinator run id cannot reset the one-probe budget.',
    migrate: _migrateAuthoringV24,
  ),
  SchemaMigration(
    version: 25,
    description:
        'Add an immutable prepared production-evidence checkpoint so a '
        'committed evaluation can finish without dispatching the provider again.',
    migrate: _migrateAuthoringV25,
  ),
  SchemaMigration(
    version: 26,
    description:
        'Add lease-fenced, hash-bound sandbox recovery checkpoints so a '
        'successor worker can resume a provider-complete attempt from a new '
        'SQLite connection without replaying the provider.',
    migrate: _migrateAuthoringV26,
  ),
  SchemaMigration(
    version: 27,
    description:
        'Persist the owning principal for agent-private story memory chunks.',
    migrate: _migrateAuthoringV27,
  ),
  SchemaMigration(
    version: 28,
    description:
        'Bind new durable candidates to effective brief identity and optional '
        'verified no-redraw attempt evidence without fabricating legacy proof.',
    migrate: _migrateAuthoringV28,
  ),
  SchemaMigration(
    version: 29,
    description:
        'Repair the candidate-proof V2 admission trigger installed by early '
        'V28 builds and reject ambiguous generation-run scene addresses; '
        'retain V28 receipt storage unchanged.',
    migrate: _migrateAuthoringV29,
  ),
];

// ── Version 1 migration ────────────────────────────────────────────────────

void _migrateAuthoringV1(Database db) {
  // 1. Legacy data migrations that DROP/recreate tables.
  //    They detect old column structures and only act if found.
  migrateLegacyWorkspaceProjects(db);
  migrateLegacyScopedTables(db);

  // 2. Ensure all workspace tables exist (IF NOT EXISTS).
  //    Required before the preference migration below which INSERTs into
  //    workspace_project_preferences.
  createWorkspaceTables(db);

  // 3. Legacy preference migration (needs workspace_project_preferences).
  migrateLegacyProjectPreferences(db);

  // 4. Legacy version/draft migrations (each recreates its own table).
  migrateLegacyVersionEntries(db);
  migrateLegacyDraftDocuments(db);

  // 5. Create all remaining tables (IF NOT EXISTS).
  createVersionTables(db);
  createDraftTables(db);
  createAiHistoryTables(db);
  createSceneContextTables(db);
  createStoryOutlineSnapshotTable(db);
  createStoryGenerationStateTable(db);
  createStoryMemoryTables(db);
}

void _migrateAuthoringV2(Database db) {
  createRoleplayArtifactTables(db);
}

void _migrateAuthoringV3(Database db) {
  createCharacterRelationsTable(db);
}

void _migrateAuthoringV4(Database db) {
  createStoryArcStateTable(db);
}

void _migrateAuthoringV5(Database db) {
  createFulltextSearchTables(db);
}

void _migrateAuthoringV6(Database db) {
  createWritingStatsTables(db);
}

void _migrateAuthoringV7(Database db) {
  ensureVectorStoreSchema(db);
}

void _migrateAuthoringV8(Database db) {
  _addColumnIfMissing(
    db,
    table: 'story_memory_chunks',
    column: 'tier',
    definition: "TEXT NOT NULL DEFAULT 'scene'",
  );
  _addColumnIfMissing(
    db,
    table: 'story_memory_chunks',
    column: 'producer',
    definition: "TEXT NOT NULL DEFAULT ''",
  );
  _addColumnIfMissing(
    db,
    table: 'story_thought_atoms',
    column: 'tier',
    definition: "TEXT NOT NULL DEFAULT 'scene'",
  );
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_memory_tier
    ON story_memory_chunks(project_id, tier)
  ''');
}

void _migrateAuthoringV9(Database db) {
  createStoryGenerationLedgerTables(db);
}

void _migrateAuthoringV10(Database db) {
  createStoryGenerationStageCheckpointTables(db);
}

void _migrateAuthoringV11(Database db) {
  createStoryGenerationMaterialManifestTables(db);
}

void _migrateAuthoringV12(Database db) {
  createGenerationSummaryAuthorityTables(db);
}

void _migrateAuthoringV13(Database db) {
  migrateStoryGenerationCheckpointRevisionIsolation(db);
}

void _migrateAuthoringV14(Database db) {
  migrateStoryGenerationCheckpointRevisionIsolation(db);
}

void _migrateAuthoringV15(Database db) {
  createAgentEvaluationTables(db);
}

void _migrateAuthoringV16(Database db) {
  createAgentEvaluationV16Tables(db);
}

void _migrateAuthoringV17(Database db) {
  createAgentEvaluationV17Tables(db);
}

void _migrateAuthoringV18(Database db) {
  createAgentEvaluationV18Tables(db);
}

void _migrateAuthoringV19(Database db) {
  createAgentEvaluationV19Tables(db);
}

void _migrateAuthoringV20(Database db) {
  createAgentEvaluationV20Tables(db);
}

void _migrateAuthoringV21(Database db) {
  createAgentEvaluationV21Tables(db);
}

void _migrateAuthoringV22(Database db) {
  createAgentEvaluationV22Tables(db);
}

void _migrateAuthoringV23(Database db) {
  createAgentEvaluationV23Tables(db);
}

void _migrateAuthoringV24(Database db) {
  createAgentEvaluationV24Tables(db);
}

void _migrateAuthoringV25(Database db) {
  createAgentEvaluationV25Tables(db);
}

void _migrateAuthoringV26(Database db) {
  createAgentEvaluationV26Tables(db);
}

void _migrateAuthoringV27(Database db) {
  _addColumnIfMissing(
    db,
    table: 'story_memory_chunks',
    column: 'owner_id',
    definition: "TEXT NOT NULL DEFAULT ''",
  );
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      27, 27, 27,
      '{"policy":"forward-only-v27","requiresBackup":true}',
      '{"policy":"restore-v26-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}

void _migrateAuthoringV28(Database db) {
  _addColumnIfMissing(
    db,
    table: 'story_generation_candidate_proofs',
    column: 'proof_identity_version',
    definition: "TEXT NOT NULL DEFAULT 'candidate-proof-v1'",
  );
  _addColumnIfMissing(
    db,
    table: 'story_generation_candidate_proofs',
    column: 'prepared_brief_digest',
    definition: 'TEXT',
  );
  _addColumnIfMissing(
    db,
    table: 'story_generation_candidate_proofs',
    column: 'effective_brief_digest',
    definition: 'TEXT',
  );
  _addColumnIfMissing(
    db,
    table: 'story_generation_candidate_proofs',
    column: 'generation_evidence_mode',
    definition: "TEXT NOT NULL DEFAULT 'legacy-unsealed-v1'",
  );
  _addColumnIfMissing(
    db,
    table: 'story_generation_candidate_proofs',
    column: 'generation_evidence_receipt_hash',
    definition: 'TEXT',
  );
  _addColumnIfMissing(
    db,
    table: 'story_generation_candidate_proofs',
    column: 'attempt_evidence_envelope_digest',
    definition: 'TEXT',
  );
  _addColumnIfMissing(
    db,
    table: 'story_generation_candidate_proofs',
    column: 'generation_fingerprint_set_digest',
    definition: 'TEXT',
  );
  _addColumnIfMissing(
    db,
    table: 'story_generation_candidate_proofs',
    column: 'generation_evidence_receipt_json',
    definition: 'TEXT',
  );
  _addColumnIfMissing(
    db,
    table: 'story_generation_candidate_payloads',
    column: 'generation_evidence_receipt_json',
    definition: "TEXT NOT NULL DEFAULT '{}'",
  );
  createCandidateProofV2WriteGuards(db);
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      28, 28, 28,
      '{"policy":"forward-only-v28","requiresBackup":true}',
      '{"policy":"restore-v27-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}

void _migrateAuthoringV29(Database db) {
  // Early V28 databases may have the V1-only admission trigger.  Rebuild the
  // trigger under a new schema version so the correction is observable and
  // replayable; V28's durable receipt columns and existing proof rows are not
  // altered.
  // Existing V28 rows cannot be silently relabelled: scene_scope_id is the
  // author-draft key.  Audit before installing any V29 object so a failure
  // rolls the complete migration back to the exact V28 state.
  auditStoryGenerationRunSceneScopeIdentities(db);
  createCandidateProofV2WriteGuards(db);
  createStoryGenerationRunIdentityWriteGuards(db);
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      29, 29, 29,
      '{"policy":"forward-only-v29","requiresBackup":true}',
      '{"policy":"restore-v28-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}

void _addColumnIfMissing(
  Database db, {
  required String table,
  required String column,
  required String definition,
}) {
  final exists = db
      .select("SELECT name FROM pragma_table_info('$table')")
      .any((row) => row['name'] == column);
  if (!exists) {
    db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}
