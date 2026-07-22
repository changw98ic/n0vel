import 'package:sqlite3/sqlite3.dart';

// ── Table creation ─────────────────────────────────────────────────────────

void createWorkspaceTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_projects (
      scope_key TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      title TEXT NOT NULL,
      genre TEXT NOT NULL,
      summary TEXT NOT NULL,
      recent_location TEXT NOT NULL,
      last_opened_at_ms INTEGER NOT NULL,
      PRIMARY KEY (scope_key, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_characters (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      name TEXT NOT NULL,
      role TEXT NOT NULL,
      note TEXT NOT NULL,
      need_text TEXT NOT NULL,
      summary TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_scenes (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      id TEXT NOT NULL,
      chapter_label TEXT NOT NULL,
      title TEXT NOT NULL,
      summary TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_world_nodes (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      title TEXT NOT NULL,
      location TEXT NOT NULL,
      type TEXT NOT NULL,
      detail TEXT NOT NULL,
      summary TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_audit_issues (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      title TEXT NOT NULL,
      evidence TEXT NOT NULL,
      target TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, position_no)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_preferences (
      scope_key TEXT NOT NULL,
      preference_key TEXT NOT NULL,
      preference_value TEXT NOT NULL,
      PRIMARY KEY (scope_key, preference_key)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS workspace_project_preferences (
      scope_key TEXT NOT NULL,
      project_id TEXT NOT NULL,
      preference_key TEXT NOT NULL,
      preference_value TEXT NOT NULL,
      PRIMARY KEY (scope_key, project_id, preference_key)
    )
  ''');
}

void createVersionTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS version_entries (
      project_id TEXT NOT NULL,
      sequence_no INTEGER NOT NULL,
      label TEXT NOT NULL,
      content TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL,
      PRIMARY KEY (project_id, sequence_no)
    )
  ''');
}

void createDraftTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS draft_documents (
      project_id TEXT PRIMARY KEY,
      text_body TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
}

void createAiHistoryTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS ai_history_entries (
      project_id TEXT NOT NULL,
      position_no INTEGER NOT NULL,
      sequence_no INTEGER NOT NULL,
      mode TEXT NOT NULL,
      prompt TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL,
      PRIMARY KEY (project_id, position_no)
    )
  ''');
}

void createSceneContextTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS scene_context_snapshots (
      project_id TEXT PRIMARY KEY,
      scene_summary TEXT NOT NULL,
      character_summary TEXT NOT NULL,
      world_summary TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
}

void createStoryOutlineSnapshotTable(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_outline_snapshots (
      project_id TEXT PRIMARY KEY,
      snapshot_json TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
}

void createStoryGenerationStateTable(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_state (
      project_id TEXT PRIMARY KEY,
      payload_json TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
}

void createStoryMemoryTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_memory_sources (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      source_kind TEXT NOT NULL,
      raw_content TEXT NOT NULL,
      metadata_json TEXT NOT NULL DEFAULT '{}',
      created_at_ms INTEGER NOT NULL DEFAULT 0
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_memory_chunks (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      chunk_kind TEXT NOT NULL,
      content TEXT NOT NULL,
      tier TEXT NOT NULL DEFAULT 'scene',
      producer TEXT NOT NULL DEFAULT '',
      source_refs_json TEXT NOT NULL DEFAULT '[]',
      root_source_ids_json TEXT NOT NULL DEFAULT '[]',
      visibility TEXT NOT NULL DEFAULT 'publicObservable',
      owner_id TEXT NOT NULL DEFAULT '',
      tags_json TEXT NOT NULL DEFAULT '[]',
      priority INTEGER NOT NULL DEFAULT 0,
      token_cost_estimate INTEGER NOT NULL DEFAULT 0,
      created_at_ms INTEGER NOT NULL DEFAULT 0
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_thought_atoms (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      thought_type TEXT NOT NULL,
      content TEXT NOT NULL,
      tier TEXT NOT NULL DEFAULT 'scene',
      confidence REAL NOT NULL DEFAULT 0.0,
      abstraction_level REAL NOT NULL DEFAULT 1.0,
      source_refs_json TEXT NOT NULL DEFAULT '[]',
      root_source_ids_json TEXT NOT NULL DEFAULT '[]',
      tags_json TEXT NOT NULL DEFAULT '[]',
      priority INTEGER NOT NULL DEFAULT 0,
      token_cost_estimate INTEGER NOT NULL DEFAULT 0,
      created_at_ms INTEGER NOT NULL DEFAULT 0
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_memory_sources_project
    ON story_memory_sources(project_id)
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_memory_chunks_project
    ON story_memory_chunks(project_id)
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_thought_atoms_project
    ON story_thought_atoms(project_id)
  ''');
}

/// Creates the V9 durable, SQLite-native ledger for scene generation.
///
/// Candidate proof and receipt records deliberately outlive their expiring
/// payload/evidence children. The foreign-key layout is part of the contract:
/// repositories may not substitute application-only references for it.
void createStoryGenerationLedgerTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_runs (
      run_id TEXT PRIMARY KEY CHECK (length(trim(run_id)) > 0),
      request_id TEXT NOT NULL UNIQUE CHECK (length(trim(request_id)) > 0),
      project_id TEXT NOT NULL CHECK (
        length(trim(project_id)) > 0 AND instr(project_id, ':') = 0
      ),
      chapter_id TEXT NOT NULL CHECK (length(trim(chapter_id)) > 0),
      scene_id TEXT NOT NULL CHECK (
        length(trim(scene_id)) > 0 AND instr(scene_id, ':') = 0
      ),
      scene_scope_id TEXT NOT NULL CHECK (
        length(trim(scene_scope_id)) > 0
        AND scene_scope_id = project_id || '::' || scene_id
      ),
      status TEXT NOT NULL CHECK (status <> 'committing'),
      phase TEXT NOT NULL,
      blocked_stage TEXT,
      schema_version INTEGER NOT NULL CHECK (schema_version > 0),
      current_prose_revision INTEGER NOT NULL DEFAULT 0
        CHECK (current_prose_revision >= 0),
      current_candidate_revision INTEGER,
      last_error_code TEXT,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      updated_at_ms INTEGER NOT NULL CHECK (updated_at_ms >= 0),
      committed_at_ms INTEGER,
      UNIQUE (run_id, project_id),
      UNIQUE (run_id, project_id, chapter_id, scene_id),
      FOREIGN KEY (run_id, current_candidate_revision)
        REFERENCES story_generation_candidate_proofs(run_id, candidate_revision)
        ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
    )
  ''');
  createStoryGenerationRunIdentityWriteGuards(db);
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_generation_runs_project_scene
    ON story_generation_runs(project_id, scene_scope_id, created_at_ms DESC)
  ''');
  db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_generation_one_active_run_per_scene
    ON story_generation_runs(project_id, scene_scope_id)
    WHERE status IN (
      'queued', 'running', 'preparing', 'context', 'planning', 'roleplay',
      'narration', 'beatResolution', 'editorial', 'preliminaryReview',
      'polish', 'deterministicGate', 'finalReview',
      'proseDerivedExtraction', 'qualityGate', 'resuming'
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_working_prose_revisions (
      run_id TEXT NOT NULL,
      prose_revision INTEGER NOT NULL CHECK (prose_revision >= 0),
      prose_hash TEXT NOT NULL CHECK (length(trim(prose_hash)) > 0),
      prose_text TEXT NOT NULL,
      source_kind TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      PRIMARY KEY (run_id, prose_revision),
      FOREIGN KEY (run_id) REFERENCES story_generation_runs(run_id)
        ON DELETE CASCADE
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_candidate_namespaces (
      run_id TEXT NOT NULL,
      candidate_revision INTEGER NOT NULL CHECK (candidate_revision >= 0),
      source_prose_revision INTEGER NOT NULL CHECK (source_prose_revision >= 0),
      reserved_at_ms INTEGER NOT NULL CHECK (reserved_at_ms >= 0),
      PRIMARY KEY (run_id, candidate_revision),
      UNIQUE (run_id, source_prose_revision),
      FOREIGN KEY (run_id, source_prose_revision)
        REFERENCES story_generation_working_prose_revisions(run_id, prose_revision)
        ON DELETE CASCADE
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_candidate_proofs (
      run_id TEXT NOT NULL,
      candidate_revision INTEGER NOT NULL CHECK (candidate_revision >= 0),
      project_id TEXT NOT NULL CHECK (length(trim(project_id)) > 0),
      chapter_id TEXT NOT NULL CHECK (length(trim(chapter_id)) > 0),
      scene_id TEXT NOT NULL CHECK (length(trim(scene_id)) > 0),
      source_prose_revision INTEGER NOT NULL CHECK (source_prose_revision >= 0),
      candidate_hash TEXT NOT NULL CHECK (length(trim(candidate_hash)) > 0),
      final_prose_hash TEXT NOT NULL CHECK (length(trim(final_prose_hash)) > 0),
      deterministic_gate_evidence_hash TEXT NOT NULL
        CHECK (length(trim(deterministic_gate_evidence_hash)) > 0),
      final_council_evidence_hash TEXT NOT NULL
        CHECK (length(trim(final_council_evidence_hash)) > 0),
      quality_evidence_hash TEXT NOT NULL
        CHECK (length(trim(quality_evidence_hash)) > 0),
      pending_write_set_hash TEXT NOT NULL
        CHECK (length(trim(pending_write_set_hash)) > 0),
      material_digest TEXT NOT NULL CHECK (length(trim(material_digest)) > 0),
      input_digest TEXT NOT NULL CHECK (length(trim(input_digest)) > 0),
      proof_identity_version TEXT NOT NULL DEFAULT 'candidate-proof-v1',
      prepared_brief_digest TEXT,
      effective_brief_digest TEXT,
      generation_evidence_mode TEXT NOT NULL DEFAULT 'legacy-unsealed-v1',
      generation_evidence_receipt_hash TEXT,
      attempt_evidence_envelope_digest TEXT,
      generation_fingerprint_set_digest TEXT,
      generation_evidence_receipt_json TEXT,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      PRIMARY KEY (run_id, candidate_revision),
      FOREIGN KEY (run_id, candidate_revision)
        REFERENCES story_generation_candidate_namespaces(run_id, candidate_revision)
        ON DELETE RESTRICT,
      FOREIGN KEY (run_id, project_id, chapter_id, scene_id)
        REFERENCES story_generation_runs(run_id, project_id, chapter_id, scene_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (run_id, source_prose_revision)
        REFERENCES story_generation_working_prose_revisions(run_id, prose_revision)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_generation_proof_update
    BEFORE UPDATE ON story_generation_candidate_proofs
    BEGIN SELECT RAISE(ABORT, 'candidate proof is immutable'); END
  ''');
  createCandidateProofV2WriteGuards(db);
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_generation_proof_delete
    BEFORE DELETE ON story_generation_candidate_proofs
    BEGIN SELECT RAISE(ABORT, 'candidate proof is permanent'); END
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_candidate_payloads (
      run_id TEXT NOT NULL,
      candidate_revision INTEGER NOT NULL CHECK (candidate_revision >= 0),
      final_prose TEXT NOT NULL CHECK (length(trim(final_prose)) > 0),
      pending_write_manifest_json TEXT NOT NULL,
      retrieval_trace_json TEXT NOT NULL DEFAULT '{}',
      review_payload_json TEXT NOT NULL DEFAULT '{}',
      quality_payload_json TEXT NOT NULL DEFAULT '{}',
      generation_evidence_receipt_json TEXT NOT NULL DEFAULT '{}',
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      expires_at_ms INTEGER NOT NULL CHECK (expires_at_ms > created_at_ms),
      PRIMARY KEY (run_id, candidate_revision),
      FOREIGN KEY (run_id, candidate_revision)
        REFERENCES story_generation_candidate_proofs(run_id, candidate_revision)
        ON DELETE CASCADE
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_generation_candidate_payload_expiry
    ON story_generation_candidate_payloads(expires_at_ms)
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_pending_writes (
      run_id TEXT NOT NULL,
      candidate_revision INTEGER NOT NULL CHECK (candidate_revision >= 0),
      write_id TEXT NOT NULL CHECK (length(trim(write_id)) > 0),
      project_id TEXT NOT NULL CHECK (length(trim(project_id)) > 0),
      chapter_id TEXT NOT NULL CHECK (length(trim(chapter_id)) > 0),
      scene_id TEXT NOT NULL CHECK (length(trim(scene_id)) > 0),
      logical_entity_id TEXT NOT NULL CHECK (length(trim(logical_entity_id)) > 0),
      write_kind TEXT NOT NULL CHECK (length(trim(write_kind)) > 0),
      payload_hash TEXT NOT NULL CHECK (length(trim(payload_hash)) > 0),
      payload_json TEXT NOT NULL,
      derivation_class TEXT NOT NULL
        CHECK (derivation_class IN ('preProse', 'proseDerived')),
      state TEXT NOT NULL DEFAULT 'staged'
        CHECK (state IN ('staged', 'committed', 'discarded')),
      tier TEXT NOT NULL DEFAULT 'draft',
      producer TEXT NOT NULL DEFAULT '',
      visibility TEXT NOT NULL DEFAULT 'publicObservable',
      owner_id TEXT NOT NULL DEFAULT '',
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      expires_at_ms INTEGER NOT NULL CHECK (expires_at_ms > created_at_ms),
      committed_at_ms INTEGER,
      discarded_at_ms INTEGER,
      PRIMARY KEY (run_id, candidate_revision, write_id),
      FOREIGN KEY (run_id, candidate_revision)
        REFERENCES story_generation_candidate_namespaces(run_id, candidate_revision)
        ON DELETE CASCADE,
      FOREIGN KEY (run_id, project_id, chapter_id, scene_id)
        REFERENCES story_generation_runs(run_id, project_id, chapter_id, scene_id)
        ON DELETE CASCADE
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_generation_discarded_write_revival
    BEFORE UPDATE OF state ON story_generation_pending_writes
    WHEN OLD.state = 'discarded' AND NEW.state <> 'discarded'
    BEGIN SELECT RAISE(ABORT, 'discarded pending write cannot transition'); END
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_generation_pending_write_expiry
    ON story_generation_pending_writes(run_id, candidate_revision, expires_at_ms)
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_commit_receipts (
      receipt_id TEXT PRIMARY KEY CHECK (length(trim(receipt_id)) > 0),
      accept_idempotency_key TEXT NOT NULL UNIQUE
        CHECK (length(trim(accept_idempotency_key)) > 0),
      run_id TEXT NOT NULL,
      candidate_revision INTEGER NOT NULL CHECK (candidate_revision >= 0),
      scene_scope_id TEXT NOT NULL CHECK (length(trim(scene_scope_id)) > 0),
      committed_candidate_hash TEXT NOT NULL
        CHECK (length(trim(committed_candidate_hash)) > 0),
      previous_draft_hash TEXT NOT NULL,
      committed_draft_hash TEXT NOT NULL CHECK (length(trim(committed_draft_hash)) > 0),
      version_id TEXT NOT NULL CHECK (length(trim(version_id)) > 0),
      version_content_hash TEXT NOT NULL
        CHECK (length(trim(version_content_hash)) > 0),
      pending_write_set_hash TEXT NOT NULL
        CHECK (length(trim(pending_write_set_hash)) > 0),
      chapter_summary_revision_id TEXT,
      outbox_set_hash TEXT NOT NULL DEFAULT '',
      committed_at_ms INTEGER NOT NULL CHECK (committed_at_ms >= 0),
      UNIQUE (run_id, candidate_revision),
      FOREIGN KEY (run_id, candidate_revision)
        REFERENCES story_generation_candidate_proofs(run_id, candidate_revision)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_generation_receipt_update
    BEFORE UPDATE ON story_generation_commit_receipts
    BEGIN SELECT RAISE(ABORT, 'commit receipt is immutable'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_generation_receipt_delete
    BEFORE DELETE ON story_generation_commit_receipts
    BEGIN SELECT RAISE(ABORT, 'commit receipt is permanent'); END
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_run_budgets (
      run_id TEXT PRIMARY KEY,
      max_calls INTEGER NOT NULL CHECK (max_calls >= 0),
      max_tokens INTEGER NOT NULL CHECK (max_tokens >= 0),
      max_cost_microusd INTEGER NOT NULL CHECK (max_cost_microusd >= 0),
      reserved_calls INTEGER NOT NULL DEFAULT 0 CHECK (reserved_calls >= 0),
      reserved_tokens INTEGER NOT NULL DEFAULT 0 CHECK (reserved_tokens >= 0),
      reserved_cost_microusd INTEGER NOT NULL DEFAULT 0
        CHECK (reserved_cost_microusd >= 0),
      used_calls INTEGER NOT NULL DEFAULT 0 CHECK (used_calls >= 0),
      used_tokens INTEGER NOT NULL DEFAULT 0 CHECK (used_tokens >= 0),
      used_cost_microusd INTEGER NOT NULL DEFAULT 0 CHECK (used_cost_microusd >= 0),
      updated_at_ms INTEGER NOT NULL CHECK (updated_at_ms >= 0),
      CHECK (reserved_calls + used_calls <= max_calls),
      CHECK (reserved_tokens + used_tokens <= max_tokens),
      CHECK (reserved_cost_microusd + used_cost_microusd <= max_cost_microusd),
      FOREIGN KEY (run_id) REFERENCES story_generation_runs(run_id)
        ON DELETE CASCADE
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_budget_reservations (
      run_id TEXT NOT NULL,
      provider_request_id TEXT NOT NULL CHECK (length(trim(provider_request_id)) > 0),
      reservation_id TEXT NOT NULL UNIQUE CHECK (length(trim(reservation_id)) > 0),
      reserved_calls INTEGER NOT NULL CHECK (reserved_calls >= 0),
      reserved_tokens INTEGER NOT NULL CHECK (reserved_tokens >= 0),
      reserved_cost_microusd INTEGER NOT NULL CHECK (reserved_cost_microusd >= 0),
      actual_calls INTEGER,
      actual_tokens INTEGER,
      actual_cost_microusd INTEGER,
      state TEXT NOT NULL CHECK (state IN ('reserved', 'settled', 'abandonedCharged')),
      lease_owner TEXT NOT NULL DEFAULT '',
      lease_expires_at_ms INTEGER NOT NULL CHECK (lease_expires_at_ms >= 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      settled_at_ms INTEGER,
      PRIMARY KEY (run_id, provider_request_id),
      FOREIGN KEY (run_id) REFERENCES story_generation_run_budgets(run_id)
        ON DELETE CASCADE
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_events (
      event_id TEXT PRIMARY KEY CHECK (length(trim(event_id)) > 0),
      run_id TEXT NOT NULL,
      sequence_no INTEGER NOT NULL CHECK (sequence_no >= 0),
      stage_id TEXT,
      reviewer_id TEXT,
      event_type TEXT NOT NULL CHECK (length(trim(event_type)) > 0),
      attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
      duration_ms INTEGER,
      failure_code TEXT,
      error_code TEXT,
      error_summary TEXT,
      metadata_json TEXT NOT NULL DEFAULT '{}',
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (run_id, sequence_no),
      FOREIGN KEY (run_id) REFERENCES story_generation_runs(run_id)
        ON DELETE CASCADE
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_generation_events_run_stage
    ON story_generation_events(run_id, stage_id, sequence_no)
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_outbox (
      operation_key TEXT PRIMARY KEY CHECK (length(trim(operation_key)) > 0),
      run_id TEXT NOT NULL,
      project_id TEXT NOT NULL CHECK (length(trim(project_id)) > 0),
      entity_id TEXT NOT NULL CHECK (length(trim(entity_id)) > 0),
      operation TEXT NOT NULL CHECK (length(trim(operation)) > 0),
      payload_json TEXT NOT NULL,
      state TEXT NOT NULL DEFAULT 'pending'
        CHECK (state IN ('pending', 'leased', 'completed', 'failed')),
      attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
      lease_owner TEXT NOT NULL DEFAULT '',
      lease_expires_at_ms INTEGER NOT NULL DEFAULT 0 CHECK (lease_expires_at_ms >= 0),
      next_attempt_at_ms INTEGER NOT NULL DEFAULT 0 CHECK (next_attempt_at_ms >= 0),
      last_error_code TEXT,
      last_error_summary TEXT,
      source_receipt_id TEXT,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      updated_at_ms INTEGER NOT NULL CHECK (updated_at_ms >= 0),
      FOREIGN KEY (run_id, project_id)
        REFERENCES story_generation_runs(run_id, project_id)
        ON DELETE CASCADE,
      FOREIGN KEY (source_receipt_id)
        REFERENCES story_generation_commit_receipts(receipt_id)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_generation_outbox_pending
    ON story_generation_outbox(state, next_attempt_at_ms)
  ''');
}

/// Durable, receipt-bound continuity projection.
///
/// Candidate payloads and pending writes are TTL caches. This projection is
/// append-only so later scenes never depend on cache retention for continuity
/// authority.
void createStoryGenerationCommittedContinuityTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_committed_continuity (
      receipt_id TEXT PRIMARY KEY CHECK (length(trim(receipt_id)) > 0),
      run_id TEXT NOT NULL,
      candidate_revision INTEGER NOT NULL CHECK (candidate_revision >= 0),
      project_id TEXT NOT NULL CHECK (length(trim(project_id)) > 0),
      chapter_id TEXT NOT NULL CHECK (length(trim(chapter_id)) > 0),
      scene_id TEXT NOT NULL CHECK (length(trim(scene_id)) > 0),
      write_id TEXT NOT NULL CHECK (length(trim(write_id)) > 0),
      write_kind TEXT NOT NULL CHECK (write_kind = 'sceneSummaryContribution'),
      state TEXT NOT NULL CHECK (state = 'committed'),
      payload_hash TEXT NOT NULL CHECK (length(trim(payload_hash)) > 0),
      payload_json TEXT NOT NULL,
      final_prose_hash TEXT NOT NULL CHECK (length(trim(final_prose_hash)) > 0),
      pending_write_set_hash TEXT NOT NULL
        CHECK (length(trim(pending_write_set_hash)) > 0),
      committed_at_ms INTEGER NOT NULL CHECK (committed_at_ms >= 0),
      commit_ordinal INTEGER NOT NULL CHECK (commit_ordinal > 0),
      UNIQUE (run_id, candidate_revision, write_id),
      FOREIGN KEY (receipt_id)
        REFERENCES story_generation_commit_receipts(receipt_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (run_id, candidate_revision)
        REFERENCES story_generation_candidate_proofs(run_id, candidate_revision)
        ON DELETE RESTRICT,
      FOREIGN KEY (run_id, project_id, chapter_id, scene_id)
        REFERENCES story_generation_runs(run_id, project_id, chapter_id, scene_id)
        ON DELETE RESTRICT
    )
  ''');
  final continuityColumns = db
      .select('PRAGMA table_info(story_generation_committed_continuity)')
      .map((row) => row['name'] as String)
      .toSet();
  if (!continuityColumns.contains('commit_ordinal')) {
    // Older development databases have no stable ordering authority. Keep
    // those rows nullable so reload can fail closed rather than manufacture a
    // false history from timestamps or receipt text. Every new accept writes
    // a positive ordinal under BEGIN IMMEDIATE.
    db.execute('''
      ALTER TABLE story_generation_committed_continuity
      ADD COLUMN commit_ordinal INTEGER CHECK (commit_ordinal > 0)
    ''');
  }
  db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS
      idx_generation_committed_continuity_commit_ordinal
    ON story_generation_committed_continuity(commit_ordinal)
    WHERE commit_ordinal IS NOT NULL
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_generation_committed_continuity_project
    ON story_generation_committed_continuity(
      project_id, committed_at_ms, scene_id
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_committed_continuity_update
    BEFORE UPDATE ON story_generation_committed_continuity
    BEGIN SELECT RAISE(ABORT, 'committed continuity is immutable'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_committed_continuity_delete
    BEFORE DELETE ON story_generation_committed_continuity
    BEGIN SELECT RAISE(ABORT, 'committed continuity is permanent'); END
  ''');
}

/// Makes the identity of a durable generation run immutable in SQLite.
///
/// Candidate proofs and receipts are bound to the run row. Allowing callers
/// to relabel that row after proof creation would move an already-sealed
/// candidate to a different project or scene without changing its evidence.
/// Mutable lifecycle fields (status, phase, revisions, errors, timestamps for
/// updates/commit) deliberately remain outside this guard.
void createStoryGenerationRunIdentityWriteGuards(Database db) {
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_noncanonical_generation_run_insert
    BEFORE INSERT ON story_generation_runs
    WHEN instr(NEW.project_id, ':') <> 0
      OR instr(NEW.scene_id, ':') <> 0
      OR NEW.scene_scope_id <> (NEW.project_id || '::' || NEW.scene_id)
    BEGIN
      SELECT RAISE(ABORT, 'generation run scene scope is not canonical');
    END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_generation_run_identity_update
    BEFORE UPDATE OF
      run_id,
      request_id,
      project_id,
      chapter_id,
      scene_id,
      scene_scope_id,
      schema_version,
      created_at_ms
    ON story_generation_runs
    WHEN OLD.run_id IS NOT NEW.run_id
      OR OLD.request_id IS NOT NEW.request_id
      OR OLD.project_id IS NOT NEW.project_id
      OR OLD.chapter_id IS NOT NEW.chapter_id
      OR OLD.scene_id IS NOT NEW.scene_id
      OR OLD.scene_scope_id IS NOT NEW.scene_scope_id
      OR OLD.schema_version IS NOT NEW.schema_version
      OR OLD.created_at_ms IS NOT NEW.created_at_ms
    BEGIN
      SELECT RAISE(ABORT, 'generation run identity is immutable');
    END
  ''');
}

/// Fails a V29 upgrade when an older database contains an ambiguous or
/// cross-scene run address.
///
/// The schema manager wraps migrations in one transaction.  Throwing here
/// leaves both the rows and `user_version` at V28 so an operator can repair or
/// restore the database explicitly; migration must never guess a new identity.
void auditStoryGenerationRunSceneScopeIdentities(Database db) {
  final tableExists = db
      .select(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' "
        "AND name = 'story_generation_runs'",
      )
      .isNotEmpty;
  if (!tableExists) return;
  final invalidCount =
      db.select('''
        SELECT COUNT(*) AS invalid_count
        FROM story_generation_runs
        WHERE instr(project_id, ':') <> 0
          OR instr(scene_id, ':') <> 0
          OR scene_scope_id <> (project_id || '::' || scene_id)
      ''').single['invalid_count']
          as int;
  if (invalidCount != 0) {
    throw StateError(
      'V29 scene-scope migration blocked by $invalidCount non-canonical '
      'generation run(s); repair or restore the V28 database before retrying',
    );
  }
}

/// Rejects malformed or legacy proof identity on every post-V28 insert.
///
/// This guard intentionally lives in SQLite rather than only in the Dart
/// writer.  A process that opened the database before V28 can retain an old
/// INSERT shape which omits [proof_identity_version]; SQLite would otherwise
/// fill its V1 default after the upgrade and fabricate a new legacy row.
/// Existing durable V1 rows are never updated or deleted by this trigger.
void createCandidateProofV2WriteGuards(Database db) {
  // `IF NOT EXISTS` would leave an earlier V28 build's weaker V1-only guard
  // installed. Recreating this immutable admission guard is idempotent and
  // makes upgrades fail closed as the V2 proof contract gains fields.
  db.execute(
    'DROP TRIGGER IF EXISTS prevent_new_legacy_generation_proof_insert',
  );
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_new_legacy_generation_proof_insert
    BEFORE INSERT ON story_generation_candidate_proofs
    WHEN NEW.proof_identity_version <> 'candidate-proof-v2'
      OR NEW.prepared_brief_digest IS NULL
      OR NEW.effective_brief_digest IS NULL
      OR NEW.generation_evidence_mode NOT IN (
        'adaptive-unsealed-v1', 'sealed-no-redraw-v1'
      )
      OR (
        NEW.generation_evidence_mode = 'adaptive-unsealed-v1'
        AND (
          NEW.generation_evidence_receipt_hash IS NOT NULL
          OR NEW.attempt_evidence_envelope_digest IS NOT NULL
          OR NEW.generation_fingerprint_set_digest IS NOT NULL
          OR NEW.generation_evidence_receipt_json IS NOT NULL
        )
      )
      OR (
        NEW.generation_evidence_mode = 'sealed-no-redraw-v1'
        AND (
          NEW.prepared_brief_digest <> NEW.effective_brief_digest
          OR NEW.generation_evidence_receipt_hash IS NULL
          OR length(trim(NEW.generation_evidence_receipt_hash)) = 0
          OR NEW.generation_evidence_receipt_hash NOT GLOB 'sha256:*'
          OR length(NEW.generation_evidence_receipt_hash) <> 71
          OR substr(NEW.generation_evidence_receipt_hash, 8)
             GLOB '*[^0-9a-f]*'
          OR NEW.attempt_evidence_envelope_digest IS NULL
          OR length(trim(NEW.attempt_evidence_envelope_digest)) = 0
          OR NEW.attempt_evidence_envelope_digest NOT GLOB 'sha256:*'
          OR length(NEW.attempt_evidence_envelope_digest) <> 71
          OR substr(NEW.attempt_evidence_envelope_digest, 8)
             GLOB '*[^0-9a-f]*'
          OR NEW.generation_fingerprint_set_digest IS NULL
          OR length(trim(NEW.generation_fingerprint_set_digest)) = 0
          OR NEW.generation_fingerprint_set_digest NOT GLOB 'sha256:*'
          OR length(NEW.generation_fingerprint_set_digest) <> 71
          OR substr(NEW.generation_fingerprint_set_digest, 8)
             GLOB '*[^0-9a-f]*'
          OR NEW.generation_evidence_receipt_json IS NULL
          OR length(trim(NEW.generation_evidence_receipt_json)) = 0
        )
      )
    BEGIN
      SELECT RAISE(ABORT, 'new candidate proof violates V2 evidence contract');
    END
  ''');
}

/// V10 resume records are deliberately separate from candidate proof data.
/// A checkpoint is a discardable cache, but its provenance and chain are
/// durable enough to decide whether a provider stage may be skipped.
void createStoryGenerationStageCheckpointTables(Database db) {
  createStoryGenerationLedgerTables(db);
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_stage_checkpoints (
      run_id TEXT NOT NULL,
      prose_revision INTEGER NOT NULL DEFAULT 0 CHECK (prose_revision >= 0),
      ordinal INTEGER NOT NULL CHECK (ordinal BETWEEN 0 AND 12),
      stage_id TEXT NOT NULL,
      stage_attempt INTEGER NOT NULL CHECK (stage_attempt > 0),
      codec_version INTEGER NOT NULL CHECK (codec_version > 0),
      status TEXT NOT NULL CHECK (status IN ('started', 'completed')),
      input_digest TEXT NOT NULL CHECK (length(input_digest) = 64),
      artifact_digest TEXT NOT NULL DEFAULT '',
      upstream_chain_digest TEXT NOT NULL CHECK (length(upstream_chain_digest) = 64),
      base_draft_digest TEXT NOT NULL CHECK (length(base_draft_digest) = 64),
      material_digest TEXT NOT NULL CHECK (length(material_digest) = 64),
      prompt_digest TEXT NOT NULL CHECK (length(prompt_digest) = 64),
      model_digest TEXT NOT NULL CHECK (length(model_digest) = 64),
      artifact_type TEXT NOT NULL DEFAULT '',
      artifact_json TEXT NOT NULL DEFAULT '{}',
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      completed_at_ms INTEGER,
      PRIMARY KEY (run_id, prose_revision, ordinal, stage_attempt),
      UNIQUE (run_id, prose_revision, ordinal, stage_attempt, stage_id),
      FOREIGN KEY (run_id) REFERENCES story_generation_runs(run_id)
        ON DELETE CASCADE,
      FOREIGN KEY (run_id, prose_revision)
        REFERENCES story_generation_working_prose_revisions(run_id, prose_revision)
        ON DELETE CASCADE
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_generation_stage_checkpoints_latest
    ON story_generation_stage_checkpoints(run_id, prose_revision, ordinal DESC, stage_attempt DESC)
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_stage_evidence (
      run_id TEXT NOT NULL,
      prose_revision INTEGER NOT NULL DEFAULT 0 CHECK (prose_revision >= 0),
      ordinal INTEGER NOT NULL CHECK (ordinal BETWEEN 0 AND 12),
      stage_attempt INTEGER NOT NULL CHECK (stage_attempt > 0),
      evidence_kind TEXT NOT NULL,
      evidence_digest TEXT NOT NULL CHECK (length(evidence_digest) = 64),
      provenance_digest TEXT NOT NULL CHECK (length(provenance_digest) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      PRIMARY KEY (run_id, prose_revision, ordinal, stage_attempt, evidence_kind),
      FOREIGN KEY (run_id, prose_revision, ordinal, stage_attempt)
        REFERENCES story_generation_stage_checkpoints(run_id, prose_revision, ordinal, stage_attempt)
        ON DELETE CASCADE
    )
  ''');
}

/// V13/V14 rebuild: V10 identities did not include a working-prose revision;
/// the first V13 shape added that column but still left it as application-only
/// metadata. Rebuild until both the composite key and parent FK are present.
///
/// A V10 row has no trustworthy revision parent, so it is preserved for audit
/// but made non-replayable (`codec_version = 1`). V13 rows keep their replay
/// eligibility only if their declared parent exists; dangling rows receive a
/// synthetic audit parent and are likewise invalidated. A checkpoint is a
/// cache, never authority, so fail-closed replay is preferable to guessing.
void migrateStoryGenerationCheckpointRevisionIsolation(Database db) {
  final columns = db.select(
    "PRAGMA table_info('story_generation_stage_checkpoints')",
  );
  final hasProseRevision = columns.any(
    (row) => row['name'] == 'prose_revision',
  );
  final parentForeignKeys = db.select(
    "PRAGMA foreign_key_list('story_generation_stage_checkpoints')",
  );
  final hasRevisionParent = parentForeignKeys.any(
    (row) =>
        row['table'] == 'story_generation_working_prose_revisions' &&
        row['from'] == 'prose_revision' &&
        row['to'] == 'prose_revision',
  );
  final evidenceColumns = db.select(
    "PRAGMA table_info('story_generation_stage_evidence')",
  );
  final evidenceHasProseRevision = evidenceColumns.any(
    (row) => row['name'] == 'prose_revision',
  );
  if (hasProseRevision && hasRevisionParent && evidenceHasProseRevision) {
    return;
  }
  final hasCheckpoint = columns.isNotEmpty;
  if (!hasCheckpoint) {
    createStoryGenerationStageCheckpointTables(db);
    return;
  }
  final hasEvidence = db
      .select(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'story_generation_stage_evidence'",
      )
      .isNotEmpty;
  if (hasEvidence) {
    db.execute(
      'ALTER TABLE story_generation_stage_evidence RENAME TO story_generation_stage_evidence_v10_legacy',
    );
  }
  db.execute(
    'ALTER TABLE story_generation_stage_checkpoints RENAME TO story_generation_stage_checkpoints_v10_legacy',
  );
  db.execute('''
    CREATE TEMP TABLE story_generation_checkpoint_known_parents (
      run_id TEXT NOT NULL,
      prose_revision INTEGER NOT NULL,
      PRIMARY KEY (run_id, prose_revision)
    )
  ''');
  if (hasProseRevision) {
    db.execute('''
      INSERT INTO story_generation_checkpoint_known_parents (run_id, prose_revision)
      SELECT l.run_id, l.prose_revision
      FROM story_generation_stage_checkpoints_v10_legacy l
      JOIN story_generation_working_prose_revisions w
        ON w.run_id = l.run_id AND w.prose_revision = l.prose_revision
      GROUP BY l.run_id, l.prose_revision
    ''');
    db.execute('''
      INSERT OR IGNORE INTO story_generation_working_prose_revisions (
        run_id, prose_revision, prose_hash, prose_text, source_kind, created_at_ms
      )
      SELECT l.run_id, l.prose_revision,
        'sha256:0000000000000000000000000000000000000000000000000000000000000000',
        '', 'legacyCheckpointAudit', 0
      FROM story_generation_stage_checkpoints_v10_legacy l
      LEFT JOIN story_generation_working_prose_revisions w
        ON w.run_id = l.run_id AND w.prose_revision = l.prose_revision
      WHERE w.run_id IS NULL
      GROUP BY l.run_id, l.prose_revision
    ''');
  } else {
    db.execute('''
      INSERT OR IGNORE INTO story_generation_working_prose_revisions (
        run_id, prose_revision, prose_hash, prose_text, source_kind, created_at_ms
      )
      SELECT l.run_id, 0,
        'sha256:0000000000000000000000000000000000000000000000000000000000000000',
        '', 'legacyCheckpointAudit', 0
      FROM story_generation_stage_checkpoints_v10_legacy l
      LEFT JOIN story_generation_working_prose_revisions w
        ON w.run_id = l.run_id AND w.prose_revision = 0
      WHERE w.run_id IS NULL
      GROUP BY l.run_id
    ''');
  }
  createStoryGenerationStageCheckpointTables(db);
  final legacyRevision = hasProseRevision ? 'prose_revision' : '0';
  final legacyCodec = hasProseRevision
      ? '''CASE WHEN EXISTS (
            SELECT 1 FROM story_generation_checkpoint_known_parents p
            WHERE p.run_id = l.run_id AND p.prose_revision = l.prose_revision
          ) THEN l.codec_version ELSE 1 END'''
      : '1';
  final evidenceLegacyRevision = evidenceHasProseRevision
      ? 'prose_revision'
      : '0';
  db.execute('''
    INSERT INTO story_generation_stage_checkpoints (
      run_id, prose_revision, ordinal, stage_id, stage_attempt,
      codec_version, status, input_digest, artifact_digest,
      upstream_chain_digest, base_draft_digest, material_digest,
      prompt_digest, model_digest, artifact_type, artifact_json,
      created_at_ms, completed_at_ms
    )
    SELECT l.run_id, $legacyRevision, l.ordinal, l.stage_id, l.stage_attempt,
      $legacyCodec, l.status, l.input_digest, l.artifact_digest,
      l.upstream_chain_digest, l.base_draft_digest, l.material_digest,
      l.prompt_digest, l.model_digest, l.artifact_type, l.artifact_json,
      l.created_at_ms, l.completed_at_ms
    FROM story_generation_stage_checkpoints_v10_legacy l
  ''');
  if (hasEvidence) {
    db.execute('''
      INSERT INTO story_generation_stage_evidence (
        run_id, prose_revision, ordinal, stage_attempt, evidence_kind,
        evidence_digest, provenance_digest, created_at_ms
      )
      SELECT run_id, $evidenceLegacyRevision, ordinal, stage_attempt, evidence_kind,
        evidence_digest, provenance_digest, created_at_ms
      FROM story_generation_stage_evidence_v10_legacy
    ''');
    db.execute('DROP TABLE story_generation_stage_evidence_v10_legacy');
  }
  db.execute('DROP TABLE story_generation_stage_checkpoints_v10_legacy');
  db.execute('DROP TABLE story_generation_checkpoint_known_parents');
}

/// MaterialDigest.v1 is based on stable source identities and hashes, never
/// raw private text. Source stores update this journal in the same database as
/// author accept; manifests freeze the exact source set observed by a run.
void createStoryGenerationMaterialManifestTables(Database db) {
  createStoryGenerationStageCheckpointTables(db);
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_material_sources (
      project_id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      source_kind TEXT NOT NULL,
      source_id TEXT NOT NULL,
      revision_token TEXT NOT NULL,
      content_hash TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL,
      PRIMARY KEY (project_id, scene_id, source_kind, source_id)
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_generation_material_sources_scene
    ON story_generation_material_sources(project_id, scene_id, source_kind)
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_material_manifests (
      run_id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      material_digest TEXT NOT NULL,
      manifest_json TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL,
      FOREIGN KEY (run_id) REFERENCES story_generation_runs(run_id)
        ON DELETE RESTRICT
    )
  ''');
}

/// 创建角色关系表
///
/// 支持一对多、多对多关系建模。每条记录表示 from_character_id 指向
/// to_character_id 的单向关系，反向关系需显式插入。
void createCharacterRelationsTable(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS character_relations (
      id TEXT NOT NULL,
      project_id TEXT NOT NULL,
      from_character_id TEXT NOT NULL,
      to_character_id TEXT NOT NULL,
      relation_type TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at_ms INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (project_id, from_character_id, to_character_id)
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_character_relations_project
    ON character_relations (project_id)
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_character_relations_from
    ON character_relations (project_id, from_character_id)
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_character_relations_to
    ON character_relations (project_id, to_character_id)
  ''');
}

/// 创建故事弧线状态表
///
/// 存储 NarrativeArcState 的 JSON 序列化数据，包含情节线、伏笔追踪等。
void createStoryArcStateTable(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_arc_states (
      project_id TEXT PRIMARY KEY,
      state_json TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

/// 创建写作统计表（日/项目级）和写作目标表
void createWritingStatsTables(Database db) {
  // 日级统计：每个 scene scope 每天一条
  db.execute('''
    CREATE TABLE IF NOT EXISTS writing_daily_stats (
      stat_date TEXT NOT NULL,
      scene_scope_id TEXT NOT NULL,
      project_id TEXT NOT NULL,
      char_count INTEGER NOT NULL DEFAULT 0,
      delta_chars INTEGER NOT NULL DEFAULT 0,
      chapters_completed INTEGER NOT NULL DEFAULT 0,
      goal_reached INTEGER NOT NULL DEFAULT 0,
      updated_at_ms INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (stat_date, scene_scope_id)
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_writing_daily_stats_project_date
    ON writing_daily_stats (project_id, stat_date)
  ''');

  // 项目级累计统计
  db.execute('''
    CREATE TABLE IF NOT EXISTS writing_project_stats (
      project_id TEXT PRIMARY KEY,
      total_char_count INTEGER NOT NULL DEFAULT 0,
      total_delta_chars INTEGER NOT NULL DEFAULT 0,
      total_chapters INTEGER NOT NULL DEFAULT 0,
      total_sessions INTEGER NOT NULL DEFAULT 0,
      first_write_at_ms INTEGER NOT NULL DEFAULT 0,
      last_write_at_ms INTEGER NOT NULL DEFAULT 0,
      best_day_chars INTEGER NOT NULL DEFAULT 0,
      best_day_date TEXT NOT NULL DEFAULT ''
    )
  ''');

  // 写作目标
  db.execute('''
    CREATE TABLE IF NOT EXISTS writing_goals (
      id TEXT NOT NULL,
      project_id TEXT NOT NULL DEFAULT '',
      goal_type TEXT NOT NULL,
      target_value INTEGER NOT NULL,
      period TEXT NOT NULL DEFAULT 'daily',
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at_ms INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (id)
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_writing_goals_project
    ON writing_goals (project_id)
  ''');
}

void createRoleplayArtifactTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS character_memories (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      character_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      content TEXT NOT NULL,
      source_round INTEGER NOT NULL,
      source_turn_id TEXT NOT NULL,
      confidence REAL NOT NULL,
      data TEXT NOT NULL
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_character_memories_project_character
    ON character_memories (project_id, character_id)
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_character_memories_project
    ON character_memories (project_id)
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_sessions (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      scene_title TEXT NOT NULL,
      final_public_state TEXT NOT NULL
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_roleplay_sessions_project_chapter
    ON roleplay_sessions (project_id, chapter_id)
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_rounds (
      session_id TEXT NOT NULL,
      round INTEGER NOT NULL,
      PRIMARY KEY (session_id, round)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_turns (
      session_id TEXT NOT NULL,
      round INTEGER NOT NULL,
      turn_order INTEGER NOT NULL,
      character_id TEXT NOT NULL,
      name TEXT NOT NULL,
      intent TEXT NOT NULL,
      visible_action TEXT NOT NULL,
      dialogue TEXT NOT NULL,
      inner_state TEXT NOT NULL,
      prose_fragment TEXT NOT NULL DEFAULT '',
      taboo TEXT NOT NULL,
      raw_text TEXT NOT NULL,
      skill_id TEXT NOT NULL,
      skill_version TEXT NOT NULL,
      proposed_memory_deltas TEXT NOT NULL,
      PRIMARY KEY (session_id, round, turn_order)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_arbitrations (
      session_id TEXT NOT NULL,
      round INTEGER NOT NULL,
      fact TEXT NOT NULL,
      state TEXT NOT NULL,
      pressure TEXT NOT NULL,
      next_public_state TEXT NOT NULL,
      should_stop INTEGER NOT NULL,
      raw_text TEXT NOT NULL,
      skill_id TEXT NOT NULL,
      skill_version TEXT NOT NULL,
      accepted_memory_deltas TEXT NOT NULL,
      rejected_memory_deltas TEXT NOT NULL,
      PRIMARY KEY (session_id, round)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS roleplay_committed_facts (
      session_id TEXT NOT NULL,
      sequence_id INTEGER NOT NULL,
      round INTEGER NOT NULL,
      source TEXT NOT NULL,
      content TEXT NOT NULL,
      previous_hash TEXT NOT NULL,
      content_hash TEXT NOT NULL,
      PRIMARY KEY (session_id, sequence_id)
    )
  ''');
}

/// V12 authoritative, receipt-bound continuity state.  These rows are owned
/// by the same SQLite transaction as author acceptance; legacy story-memory
/// blobs are only a read fallback and never the commit source of truth.
void createGenerationSummaryAuthorityTables(Database db) {
  createStoryGenerationCommittedContinuityTables(db);
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_committed_arcs (
      receipt_id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_summary_contributions (
      receipt_id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      contribution_hash TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_summary_revisions (
      revision_id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      scene_commit_set_hash TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL,
      UNIQUE(project_id, chapter_id, scene_commit_set_hash)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_summary_heads (
      project_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      revision_id TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL,
      PRIMARY KEY (project_id, chapter_id)
    )
  ''');
}

/// V15 immutable releases and execution ledger for adversarial Agent
/// evaluation. Runtime repositories still own canonical hashing and CAS, while
/// these constraints make identity collisions, sample replacement, evidence
/// rewrites, and promotion-history rewrites fail closed at the SQLite boundary.
void createAgentEvaluationTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS prompt_releases (
      release_id TEXT PRIMARY KEY CHECK (length(trim(release_id)) > 0),
      template_id TEXT NOT NULL CHECK (length(trim(template_id)) > 0),
      semantic_version TEXT NOT NULL CHECK (length(trim(semantic_version)) > 0),
      language TEXT NOT NULL CHECK (length(trim(language)) > 0),
      content_hash TEXT NOT NULL CHECK (length(content_hash) = 64),
      system_template TEXT NOT NULL,
      user_template TEXT NOT NULL,
      variables_schema_json TEXT NOT NULL,
      output_schema_json TEXT NOT NULL,
      renderer_release TEXT NOT NULL CHECK (length(trim(renderer_release)) > 0),
      parser_release TEXT NOT NULL CHECK (length(trim(parser_release)) > 0),
      repair_policy_json TEXT NOT NULL,
      variables_schema_hash TEXT NOT NULL CHECK (length(variables_schema_hash) = 64),
      output_schema_hash TEXT NOT NULL CHECK (length(output_schema_hash) = 64),
      owner TEXT NOT NULL CHECK (length(trim(owner)) > 0),
      change_note TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (template_id, semantic_version, language)
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'prompt_releases',
    message: 'prompt release is immutable',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS prompt_release_lifecycle_events (
      event_id TEXT PRIMARY KEY CHECK (length(trim(event_id)) > 0),
      release_id TEXT NOT NULL,
      event TEXT NOT NULL CHECK (event IN ('deprecated', 'disabled', 'restored')),
      reason TEXT NOT NULL CHECK (length(trim(reason)) > 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (release_id, event, created_at_ms),
      FOREIGN KEY (release_id) REFERENCES prompt_releases(release_id)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'prompt_release_lifecycle_events',
    message: 'prompt release lifecycle is append-only',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS generation_bundles (
      bundle_hash TEXT PRIMARY KEY CHECK (length(bundle_hash) = 64),
      bundle_id TEXT NOT NULL CHECK (length(trim(bundle_id)) > 0),
      releases_json TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0)
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'generation_bundles',
    message: 'generation bundle is immutable',
  );
  db.execute('''
    CREATE TABLE IF NOT EXISTS generation_bundle_releases (
      bundle_hash TEXT NOT NULL,
      stage_id TEXT NOT NULL CHECK (length(trim(stage_id)) > 0),
      call_site_id TEXT NOT NULL CHECK (length(trim(call_site_id)) > 0),
      variant_id TEXT NOT NULL CHECK (length(trim(variant_id)) > 0),
      prompt_release_id TEXT NOT NULL,
      PRIMARY KEY (bundle_hash, stage_id, call_site_id, variant_id),
      FOREIGN KEY (bundle_hash) REFERENCES generation_bundles(bundle_hash)
        ON DELETE RESTRICT,
      FOREIGN KEY (prompt_release_id) REFERENCES prompt_releases(release_id)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'generation_bundle_releases',
    message: 'generation bundle membership is immutable',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS evaluation_bundles (
      evaluation_bundle_hash TEXT PRIMARY KEY
        CHECK (length(evaluation_bundle_hash) = 64),
      evaluator_bundle_id TEXT NOT NULL CHECK (length(trim(evaluator_bundle_id)) > 0),
      verifiers_json TEXT NOT NULL,
      judges_json TEXT NOT NULL,
      rubric_release_hash TEXT NOT NULL CHECK (length(rubric_release_hash) = 64),
      aggregator_release_hash TEXT NOT NULL
        CHECK (length(aggregator_release_hash) = 64),
      failure_taxonomy_hash TEXT NOT NULL CHECK (length(failure_taxonomy_hash) = 64),
      blinding_policy_version TEXT NOT NULL
        CHECK (length(trim(blinding_policy_version)) > 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0)
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'evaluation_bundles',
    message: 'evaluation bundle is immutable',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_scenario_sets (
      scenario_set_release_hash TEXT PRIMARY KEY
        CHECK (length(scenario_set_release_hash) = 64),
      set_id TEXT NOT NULL CHECK (length(trim(set_id)) > 0),
      version TEXT NOT NULL CHECK (length(trim(version)) > 0),
      manifest_hash TEXT NOT NULL CHECK (length(manifest_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (set_id, version)
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_scenario_sets',
    message: 'scenario set is immutable',
  );
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_scenarios (
      scenario_release_hash TEXT PRIMARY KEY
        CHECK (length(scenario_release_hash) = 64),
      scenario_set_release_hash TEXT NOT NULL,
      scenario_id TEXT NOT NULL CHECK (length(trim(scenario_id)) > 0),
      version TEXT NOT NULL CHECK (length(trim(version)) > 0),
      fixture_hash TEXT NOT NULL CHECK (length(fixture_hash) = 64),
      isolation_mode TEXT NOT NULL CHECK (isolation_mode IN ('independent', 'episode')),
      episode_id TEXT,
      episode_step INTEGER,
      verifier_release_refs_json TEXT NOT NULL,
      rubric_release_ref TEXT NOT NULL CHECK (length(trim(rubric_release_ref)) > 0),
      expected_terminal_state TEXT NOT NULL
        CHECK (length(trim(expected_terminal_state)) > 0),
      required_failure_codes_json TEXT NOT NULL,
      allowed_failure_codes_json TEXT NOT NULL,
      forbidden_failure_codes_json TEXT NOT NULL,
      outcome_comparator_release_ref TEXT NOT NULL
        CHECK (length(trim(outcome_comparator_release_ref)) > 0),
      forbidden_side_effects_json TEXT NOT NULL,
      accept_expected INTEGER NOT NULL CHECK (accept_expected IN (0, 1)),
      scenario_json TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (scenario_set_release_hash, scenario_id, version),
      CHECK (
        (isolation_mode = 'independent' AND episode_id IS NULL AND episode_step IS NULL)
        OR
        (isolation_mode = 'episode' AND episode_id IS NOT NULL
          AND length(trim(episode_id)) > 0 AND episode_step IS NOT NULL
          AND episode_step >= 0)
      ),
      FOREIGN KEY (scenario_set_release_hash)
        REFERENCES eval_scenario_sets(scenario_set_release_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_scenarios',
    message: 'scenario release is immutable',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_experiments (
      experiment_id TEXT PRIMARY KEY CHECK (length(trim(experiment_id)) > 0),
      manifest_json TEXT NOT NULL,
      manifest_hash TEXT NOT NULL UNIQUE CHECK (length(manifest_hash) = 64),
      scenario_set_release_hash TEXT NOT NULL,
      evaluation_bundle_hash TEXT NOT NULL,
      expected_cell_set_hash TEXT NOT NULL CHECK (length(expected_cell_set_hash) = 64),
      expected_slot_set_hash TEXT NOT NULL CHECK (length(expected_slot_set_hash) = 64),
      trials_per_cell INTEGER NOT NULL CHECK (trials_per_cell > 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (scenario_set_release_hash)
        REFERENCES eval_scenario_sets(scenario_set_release_hash)
        ON DELETE RESTRICT,
      FOREIGN KEY (evaluation_bundle_hash)
        REFERENCES evaluation_bundles(evaluation_bundle_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_experiments',
    message: 'experiment manifest is immutable',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_cells (
      cell_id TEXT PRIMARY KEY CHECK (length(cell_id) = 64),
      generation_bundle_hash TEXT NOT NULL,
      sut_model_route_hash TEXT NOT NULL CHECK (length(sut_model_route_hash) = 64),
      scenario_release_hash TEXT NOT NULL,
      decoding_config_hash TEXT NOT NULL CHECK (length(decoding_config_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (
        generation_bundle_hash,
        sut_model_route_hash,
        scenario_release_hash,
        decoding_config_hash
      ),
      FOREIGN KEY (generation_bundle_hash)
        REFERENCES generation_bundles(bundle_hash) ON DELETE RESTRICT,
      FOREIGN KEY (scenario_release_hash)
        REFERENCES eval_scenarios(scenario_release_hash) ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_cells',
    message: 'evaluation cell is immutable',
  );
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_experiment_cells (
      experiment_id TEXT NOT NULL,
      cell_id TEXT NOT NULL,
      ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
      PRIMARY KEY (experiment_id, cell_id),
      UNIQUE (experiment_id, ordinal),
      FOREIGN KEY (experiment_id) REFERENCES eval_experiments(experiment_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (cell_id) REFERENCES eval_cells(cell_id)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_experiment_cells',
    message: 'experiment cell set is immutable',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_executions (
      execution_id TEXT PRIMARY KEY CHECK (length(trim(execution_id)) > 0),
      experiment_id TEXT NOT NULL,
      status TEXT NOT NULL
        CHECK (status IN ('created', 'ready', 'running', 'cancelling',
                          'cancelled', 'completed', 'failed')),
      expected_cell_set_hash TEXT NOT NULL CHECK (length(expected_cell_set_hash) = 64),
      expected_slot_set_hash TEXT NOT NULL CHECK (length(expected_slot_set_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      started_at_ms INTEGER,
      finished_at_ms INTEGER,
      CHECK (started_at_ms IS NULL OR started_at_ms >= created_at_ms),
      CHECK (finished_at_ms IS NULL OR
             (started_at_ms IS NOT NULL AND finished_at_ms >= started_at_ms)),
      FOREIGN KEY (experiment_id) REFERENCES eval_experiments(experiment_id)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_execution_cells (
      execution_id TEXT NOT NULL,
      cell_id TEXT NOT NULL,
      ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
      PRIMARY KEY (execution_id, cell_id),
      UNIQUE (execution_id, ordinal),
      FOREIGN KEY (execution_id) REFERENCES eval_executions(execution_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (cell_id) REFERENCES eval_cells(cell_id)
        ON DELETE RESTRICT
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_trial_slots (
      trial_slot_id TEXT PRIMARY KEY CHECK (length(trim(trial_slot_id)) > 0),
      execution_id TEXT NOT NULL,
      cell_id TEXT NOT NULL,
      trial_no INTEGER NOT NULL CHECK (trial_no > 0),
      status TEXT NOT NULL CHECK (status IN ('queued', 'leased', 'running', 'sealed')),
      result TEXT CHECK (result IN ('pass', 'fail', 'insufficientEvidence')),
      lease_epoch INTEGER NOT NULL DEFAULT 0 CHECK (lease_epoch >= 0),
      lease_owner TEXT,
      lease_expires_at_ms INTEGER,
      sealed_evidence_hash TEXT,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      updated_at_ms INTEGER NOT NULL CHECK (updated_at_ms >= created_at_ms),
      sealed_at_ms INTEGER,
      UNIQUE (execution_id, cell_id, trial_no),
      CHECK (
        (status = 'queued' AND result IS NULL AND lease_owner IS NULL
          AND lease_expires_at_ms IS NULL AND sealed_evidence_hash IS NULL
          AND sealed_at_ms IS NULL)
        OR
        (status IN ('leased', 'running') AND result IS NULL
          AND lease_owner IS NOT NULL AND length(trim(lease_owner)) > 0
          AND lease_expires_at_ms IS NOT NULL AND lease_expires_at_ms > 0
          AND lease_epoch > 0 AND sealed_evidence_hash IS NULL
          AND sealed_at_ms IS NULL)
        OR
        (status = 'sealed' AND result IS NOT NULL AND lease_owner IS NULL
          AND lease_expires_at_ms IS NULL AND sealed_evidence_hash IS NOT NULL
          AND length(sealed_evidence_hash) = 64 AND sealed_at_ms IS NOT NULL
          AND sealed_at_ms >= created_at_ms)
      ),
      FOREIGN KEY (execution_id, cell_id)
        REFERENCES eval_execution_cells(execution_id, cell_id)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_eval_trial_slots_claim
    ON eval_trial_slots(status, lease_expires_at_ms, trial_slot_id)
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_trial_attempts (
      trial_slot_id TEXT NOT NULL,
      attempt_no INTEGER NOT NULL CHECK (attempt_no > 0),
      run_id TEXT NOT NULL UNIQUE CHECK (length(trim(run_id)) > 0),
      kind TEXT NOT NULL CHECK (kind IN ('content', 'transport')),
      status TEXT NOT NULL
        CHECK (status IN ('started', 'completed', 'failed', 'cancelled')),
      lease_epoch INTEGER NOT NULL CHECK (lease_epoch > 0),
      lease_owner TEXT NOT NULL CHECK (length(trim(lease_owner)) > 0),
      started_at_ms INTEGER NOT NULL CHECK (started_at_ms >= 0),
      finished_at_ms INTEGER,
      PRIMARY KEY (trial_slot_id, attempt_no),
      CHECK (finished_at_ms IS NULL OR finished_at_ms >= started_at_ms),
      CHECK ((status = 'started' AND finished_at_ms IS NULL)
        OR (status <> 'started' AND finished_at_ms IS NOT NULL)),
      FOREIGN KEY (trial_slot_id) REFERENCES eval_trial_slots(trial_slot_id)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_eval_trial_one_content_attempt
    ON eval_trial_attempts(trial_slot_id) WHERE kind = 'content'
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_observations (
      observation_id TEXT PRIMARY KEY CHECK (length(trim(observation_id)) > 0),
      trial_slot_id TEXT NOT NULL,
      attempt_no INTEGER NOT NULL CHECK (attempt_no > 0),
      sequence_no INTEGER NOT NULL CHECK (sequence_no >= 0),
      stage_id TEXT NOT NULL CHECK (length(trim(stage_id)) > 0),
      kind TEXT NOT NULL CHECK (length(trim(kind)) > 0),
      item_key TEXT NOT NULL CHECK (length(trim(item_key)) > 0),
      value_json TEXT NOT NULL CHECK (length(value_json) <= 1048576),
      evidence_hash TEXT NOT NULL CHECK (length(evidence_hash) = 64),
      evaluation_bundle_hash TEXT NOT NULL,
      prose_hash TEXT CHECK (prose_hash IS NULL OR length(prose_hash) = 64),
      lease_epoch INTEGER NOT NULL CHECK (lease_epoch > 0),
      lease_owner TEXT NOT NULL CHECK (length(trim(lease_owner)) > 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (trial_slot_id, stage_id, kind, attempt_no, item_key),
      UNIQUE (trial_slot_id, sequence_no),
      FOREIGN KEY (trial_slot_id, attempt_no)
        REFERENCES eval_trial_attempts(trial_slot_id, attempt_no)
        ON DELETE RESTRICT,
      FOREIGN KEY (evaluation_bundle_hash)
        REFERENCES evaluation_bundles(evaluation_bundle_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_observations',
    message: 'evaluation observation is append-only',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_scorecards (
      scorecard_hash TEXT PRIMARY KEY CHECK (length(scorecard_hash) = 64),
      execution_id TEXT NOT NULL,
      scope TEXT NOT NULL CHECK (scope IN ('execution', 'cell', 'scenario', 'bundle')),
      scope_key TEXT NOT NULL CHECK (length(trim(scope_key)) > 0),
      aggregate_json TEXT NOT NULL,
      input_set_hash TEXT NOT NULL CHECK (length(input_set_hash) = 64),
      expected_set_hash TEXT NOT NULL CHECK (length(expected_set_hash) = 64),
      aggregator_release_hash TEXT NOT NULL
        CHECK (length(aggregator_release_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (execution_id, scope, scope_key, aggregator_release_hash),
      FOREIGN KEY (execution_id) REFERENCES eval_executions(execution_id)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_scorecards',
    message: 'evaluation scorecard is immutable',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS prompt_channel_heads (
      channel TEXT PRIMARY KEY CHECK (length(trim(channel)) > 0),
      bundle_hash TEXT NOT NULL,
      epoch INTEGER NOT NULL CHECK (epoch >= 0),
      updated_at_ms INTEGER NOT NULL CHECK (updated_at_ms >= 0),
      FOREIGN KEY (bundle_hash) REFERENCES generation_bundles(bundle_hash)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS prompt_release_decisions (
      decision_id TEXT PRIMARY KEY CHECK (length(trim(decision_id)) > 0),
      channel TEXT NOT NULL,
      action TEXT NOT NULL CHECK (action IN ('promote', 'rollback')),
      from_bundle_hash TEXT NOT NULL,
      to_bundle_hash TEXT NOT NULL,
      from_epoch INTEGER NOT NULL CHECK (from_epoch >= 0),
      to_epoch INTEGER NOT NULL CHECK (to_epoch = from_epoch + 1),
      experiment_id TEXT NOT NULL,
      scorecard_hash TEXT NOT NULL,
      approver TEXT NOT NULL CHECK (length(trim(approver)) > 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (channel, to_epoch),
      FOREIGN KEY (channel) REFERENCES prompt_channel_heads(channel)
        ON DELETE RESTRICT,
      FOREIGN KEY (from_bundle_hash) REFERENCES generation_bundles(bundle_hash)
        ON DELETE RESTRICT,
      FOREIGN KEY (to_bundle_hash) REFERENCES generation_bundles(bundle_hash)
        ON DELETE RESTRICT,
      FOREIGN KEY (experiment_id) REFERENCES eval_experiments(experiment_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (scorecard_hash) REFERENCES eval_scorecards(scorecard_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'prompt_release_decisions',
    message: 'prompt release decision is append-only',
  );
}

void _makeAgentEvalTableAppendOnly(
  Database db, {
  required String table,
  required String message,
}) {
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_${table}_update
    BEFORE UPDATE ON $table
    BEGIN SELECT RAISE(ABORT, '$message'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_${table}_delete
    BEFORE DELETE ON $table
    BEGIN SELECT RAISE(ABORT, '$message'); END
  ''');
}

/// V16 compatibility, generation-bundle provenance, and holdout access
/// authority. This migration is additive and deliberately leaves V1-V15
/// objects untouched.
void createAgentEvaluationV16Tables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS schema_compatibility_contracts (
      schema_version INTEGER PRIMARY KEY CHECK (schema_version > 0),
      min_reader_version INTEGER NOT NULL
        CHECK (min_reader_version > 0 AND min_reader_version <= schema_version),
      min_writer_version INTEGER NOT NULL
        CHECK (min_writer_version > 0 AND min_writer_version <= schema_version),
      upgrade_policy_json TEXT NOT NULL,
      rollback_policy_json TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0)
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'schema_compatibility_contracts',
    message: 'schema compatibility contract is immutable',
  );
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      16, 15, 16,
      '{"policy":"forward-only-v16","requiresBackup":true}',
      '{"policy":"restore-backup","inPlaceDowngrade":false}',
      0
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_run_bundles (
      run_id TEXT PRIMARY KEY,
      bundle_hash TEXT NOT NULL CHECK (length(bundle_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (run_id) REFERENCES story_generation_runs(run_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (bundle_hash) REFERENCES generation_bundles(bundle_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'story_generation_run_bundles',
    message: 'generation run bundle binding is immutable',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_experiment_families (
      family_id TEXT PRIMARY KEY CHECK (length(trim(family_id)) > 0),
      scenario_set_release_hash TEXT NOT NULL,
      holdout_access_policy_hash TEXT NOT NULL
        CHECK (length(holdout_access_policy_hash) = 64),
      max_accesses INTEGER NOT NULL CHECK (max_accesses > 0),
      used_accesses INTEGER NOT NULL DEFAULT 0
        CHECK (used_accesses >= 0 AND used_accesses <= max_accesses),
      alpha_budget_micros INTEGER NOT NULL CHECK (alpha_budget_micros > 0),
      alpha_spent_micros INTEGER NOT NULL DEFAULT 0
        CHECK (alpha_spent_micros >= 0 AND alpha_spent_micros <= alpha_budget_micros),
      status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'exhausted', 'rotated')),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      updated_at_ms INTEGER NOT NULL CHECK (updated_at_ms >= created_at_ms),
      FOREIGN KEY (scenario_set_release_hash)
        REFERENCES eval_scenario_sets(scenario_set_release_hash)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_eval_family_identity_update
    BEFORE UPDATE OF family_id, scenario_set_release_hash,
      holdout_access_policy_hash, max_accesses, alpha_budget_micros,
      created_at_ms ON eval_experiment_families
    BEGIN SELECT RAISE(ABORT, 'experiment family policy is immutable'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_eval_family_delete
    BEFORE DELETE ON eval_experiment_families
    BEGIN SELECT RAISE(ABORT, 'experiment family is permanent'); END
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_family_challengers (
      family_id TEXT NOT NULL,
      challenger_bundle_hash TEXT NOT NULL CHECK (length(challenger_bundle_hash) = 64),
      registered_at_ms INTEGER NOT NULL CHECK (registered_at_ms >= 0),
      PRIMARY KEY (family_id, challenger_bundle_hash),
      FOREIGN KEY (family_id) REFERENCES eval_experiment_families(family_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (challenger_bundle_hash) REFERENCES generation_bundles(bundle_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_family_challengers',
    message: 'family challenger registration is append-only',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_holdout_tokens (
      token_id TEXT PRIMARY KEY CHECK (length(trim(token_id)) > 0),
      family_id TEXT NOT NULL,
      challenger_bundle_hash TEXT NOT NULL,
      alpha_cost_micros INTEGER NOT NULL CHECK (alpha_cost_micros > 0),
      state TEXT NOT NULL DEFAULT 'issued' CHECK (state IN ('issued', 'consumed')),
      issued_at_ms INTEGER NOT NULL CHECK (issued_at_ms >= 0),
      consumed_at_ms INTEGER,
      CHECK ((state = 'issued' AND consumed_at_ms IS NULL)
        OR (state = 'consumed' AND consumed_at_ms IS NOT NULL
          AND consumed_at_ms >= issued_at_ms)),
      FOREIGN KEY (family_id, challenger_bundle_hash)
        REFERENCES eval_family_challengers(family_id, challenger_bundle_hash)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_holdout_token_identity_update
    BEFORE UPDATE OF token_id, family_id, challenger_bundle_hash,
      alpha_cost_micros, issued_at_ms ON eval_holdout_tokens
    BEGIN SELECT RAISE(ABORT, 'holdout token identity is immutable'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_holdout_token_delete
    BEFORE DELETE ON eval_holdout_tokens
    BEGIN SELECT RAISE(ABORT, 'holdout token is permanent'); END
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_holdout_confirmations (
      confirmation_id TEXT PRIMARY KEY CHECK (length(trim(confirmation_id)) > 0),
      token_id TEXT NOT NULL UNIQUE,
      family_id TEXT NOT NULL,
      challenger_bundle_hash TEXT NOT NULL,
      execution_id TEXT NOT NULL,
      result TEXT NOT NULL CHECK (result IN ('pass', 'fail', 'insufficientEvidence')),
      public_result_json TEXT NOT NULL,
      alpha_cost_micros INTEGER NOT NULL CHECK (alpha_cost_micros > 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (token_id) REFERENCES eval_holdout_tokens(token_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (family_id, challenger_bundle_hash)
        REFERENCES eval_family_challengers(family_id, challenger_bundle_hash)
        ON DELETE RESTRICT,
      FOREIGN KEY (execution_id) REFERENCES eval_executions(execution_id)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_holdout_confirmations',
    message: 'holdout confirmation is immutable',
  );
}

/// V17 closes the release-authority bypasses left by the foundational V15/V16
/// schema. Gate verdicts and holdout access are durable authorization facts;
/// caller-provided booleans are never sufficient to move a channel head.
void createAgentEvaluationV17Tables(Database db) {
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      17, 16, 17,
      '{"policy":"forward-only-v17","requiresBackup":true}',
      '{"policy":"bundle-rollback-or-restore-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS enforce_holdout_token_forward_transition
    BEFORE UPDATE OF state, consumed_at_ms ON eval_holdout_tokens
    WHEN NOT (
      OLD.state = 'issued' AND OLD.consumed_at_ms IS NULL
      AND NEW.state = 'consumed' AND NEW.consumed_at_ms IS NOT NULL
      AND NEW.consumed_at_ms >= OLD.issued_at_ms
    )
    BEGIN SELECT RAISE(ABORT, 'holdout token transition must be issued to consumed'); END
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_release_gate_verdicts (
      verdict_hash TEXT PRIMARY KEY CHECK (length(verdict_hash) = 64),
      verdict_kind TEXT NOT NULL CHECK (verdict_kind IN ('regression', 'holdout')),
      experiment_id TEXT NOT NULL,
      execution_id TEXT NOT NULL,
      scorecard_hash TEXT NOT NULL,
      champion_bundle_hash TEXT NOT NULL CHECK (length(champion_bundle_hash) = 64),
      challenger_bundle_hash TEXT NOT NULL CHECK (length(challenger_bundle_hash) = 64),
      status TEXT NOT NULL CHECK (status IN ('promote', 'reject', 'insufficientEvidence')),
      reasons_json TEXT NOT NULL,
      comparison_input_set_hash TEXT NOT NULL
        CHECK (length(comparison_input_set_hash) = 64),
      expected_pair_set_hash TEXT NOT NULL
        CHECK (length(expected_pair_set_hash) = 64),
      policy_hash TEXT NOT NULL CHECK (length(policy_hash) = 64),
      gate_release_hash TEXT NOT NULL CHECK (length(gate_release_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (verdict_kind, experiment_id, champion_bundle_hash,
              challenger_bundle_hash, execution_id),
      CHECK (champion_bundle_hash <> challenger_bundle_hash),
      FOREIGN KEY (experiment_id) REFERENCES eval_experiments(experiment_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (execution_id) REFERENCES eval_executions(execution_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (scorecard_hash) REFERENCES eval_scorecards(scorecard_hash)
        ON DELETE RESTRICT,
      FOREIGN KEY (champion_bundle_hash) REFERENCES generation_bundles(bundle_hash)
        ON DELETE RESTRICT,
      FOREIGN KEY (challenger_bundle_hash) REFERENCES generation_bundles(bundle_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_release_gate_verdicts',
    message: 'release gate verdict is immutable',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_holdout_accesses (
      access_id TEXT PRIMARY KEY CHECK (length(trim(access_id)) > 0),
      token_id TEXT NOT NULL UNIQUE,
      family_id TEXT NOT NULL,
      challenger_bundle_hash TEXT NOT NULL CHECK (length(challenger_bundle_hash) = 64),
      execution_id TEXT NOT NULL UNIQUE,
      trusted_runner_release_hash TEXT NOT NULL
        CHECK (length(trusted_runner_release_hash) = 64),
      alpha_cost_micros INTEGER NOT NULL CHECK (alpha_cost_micros > 0),
      state TEXT NOT NULL CHECK (state IN ('begun', 'sealed')),
      gate_verdict_hash TEXT UNIQUE,
      begun_at_ms INTEGER NOT NULL CHECK (begun_at_ms >= 0),
      sealed_at_ms INTEGER,
      CHECK ((state = 'begun' AND gate_verdict_hash IS NULL AND sealed_at_ms IS NULL)
        OR (state = 'sealed' AND gate_verdict_hash IS NOT NULL
          AND sealed_at_ms IS NOT NULL AND sealed_at_ms >= begun_at_ms)),
      FOREIGN KEY (token_id) REFERENCES eval_holdout_tokens(token_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (family_id, challenger_bundle_hash)
        REFERENCES eval_family_challengers(family_id, challenger_bundle_hash)
        ON DELETE RESTRICT,
      FOREIGN KEY (execution_id) REFERENCES eval_executions(execution_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (gate_verdict_hash)
        REFERENCES eval_release_gate_verdicts(verdict_hash) ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_holdout_access_identity_update
    BEFORE UPDATE OF access_id, token_id, family_id, challenger_bundle_hash,
      execution_id, trusted_runner_release_hash, alpha_cost_micros, begun_at_ms
    ON eval_holdout_accesses
    BEGIN SELECT RAISE(ABORT, 'holdout access identity is immutable'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_holdout_access_delete
    BEFORE DELETE ON eval_holdout_accesses
    BEGIN SELECT RAISE(ABORT, 'holdout access is permanent'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS enforce_holdout_access_forward_transition
    BEFORE UPDATE OF state, gate_verdict_hash, sealed_at_ms
    ON eval_holdout_accesses
    WHEN NOT (
      OLD.state = 'begun' AND OLD.gate_verdict_hash IS NULL
      AND OLD.sealed_at_ms IS NULL AND NEW.state = 'sealed'
      AND NEW.gate_verdict_hash IS NOT NULL AND NEW.sealed_at_ms IS NOT NULL
      AND NEW.sealed_at_ms >= OLD.begun_at_ms
    )
    BEGIN SELECT RAISE(ABORT, 'holdout access transition must be begun to sealed'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS enforce_eval_family_forward_counters
    BEFORE UPDATE OF used_accesses, alpha_spent_micros, status, updated_at_ms
    ON eval_experiment_families
    WHEN NEW.used_accesses < OLD.used_accesses
      OR NEW.alpha_spent_micros < OLD.alpha_spent_micros
      OR NEW.updated_at_ms < OLD.updated_at_ms
      OR (OLD.status <> 'active' AND NEW.status = 'active')
    BEGIN SELECT RAISE(ABORT, 'experiment family budget cannot move backwards'); END
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS prompt_release_decision_authorizations (
      decision_id TEXT PRIMARY KEY,
      regression_verdict_hash TEXT NOT NULL,
      holdout_confirmation_id TEXT NOT NULL UNIQUE,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (decision_id) REFERENCES prompt_release_decisions(decision_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (regression_verdict_hash)
        REFERENCES eval_release_gate_verdicts(verdict_hash) ON DELETE RESTRICT,
      FOREIGN KEY (holdout_confirmation_id)
        REFERENCES eval_holdout_confirmations(confirmation_id) ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'prompt_release_decision_authorizations',
    message: 'release decision authorization is immutable',
  );

  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_sealed_trial_slot_update
    BEFORE UPDATE ON eval_trial_slots WHEN OLD.status = 'sealed'
    BEGIN SELECT RAISE(ABORT, 'sealed trial slot is immutable'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_trial_slot_delete
    BEFORE DELETE ON eval_trial_slots
    BEGIN SELECT RAISE(ABORT, 'trial slot is permanent'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_terminal_trial_attempt_update
    BEFORE UPDATE ON eval_trial_attempts WHEN OLD.status <> 'started'
    BEGIN SELECT RAISE(ABORT, 'terminal trial attempt is immutable'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_trial_attempt_delete
    BEFORE DELETE ON eval_trial_attempts
    BEGIN SELECT RAISE(ABORT, 'trial attempt is permanent'); END
  ''');
}

/// V18 makes a stored `promote` row insufficient by itself. Every usable gate
/// verdict must have an append-only derivation emitted by the DB projection
/// authority, and sealed trials reject all later evidence insertion.
void createAgentEvaluationV18Tables(Database db) {
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      18, 17, 18,
      '{"policy":"forward-only-v18","requiresBackup":true}',
      '{"policy":"bundle-rollback-or-restore-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_release_gate_derivations (
      verdict_hash TEXT PRIMARY KEY,
      projection_hash TEXT NOT NULL CHECK (length(projection_hash) = 64),
      authority_release_hash TEXT NOT NULL
        CHECK (length(authority_release_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (verdict_hash) REFERENCES eval_release_gate_verdicts(verdict_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_release_gate_derivations',
    message: 'release gate derivation is immutable',
  );
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS reject_attempt_after_slot_seal
    BEFORE INSERT ON eval_trial_attempts
    WHEN EXISTS (
      SELECT 1 FROM eval_trial_slots
      WHERE trial_slot_id = NEW.trial_slot_id AND status = 'sealed'
    )
    BEGIN SELECT RAISE(ABORT, 'cannot append attempt after slot seal'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS reject_observation_after_slot_seal
    BEFORE INSERT ON eval_observations
    WHEN EXISTS (
      SELECT 1 FROM eval_trial_slots
      WHERE trial_slot_id = NEW.trial_slot_id AND status = 'sealed'
    )
    BEGIN SELECT RAISE(ABORT, 'cannot append observation after slot seal'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_terminal_eval_execution_update
    BEFORE UPDATE ON eval_executions
    WHEN OLD.status IN ('completed', 'failed', 'cancelled')
    BEGIN SELECT RAISE(ABORT, 'terminal evaluation execution is immutable'); END
  ''');
}

/// V19 makes the declared interleaved randomized order executable and
/// auditable. Plans and events are immutable; the release gate replays both.
void createAgentEvaluationV19Tables(Database db) {
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      19, 18, 19,
      '{"policy":"forward-only-v19","requiresBackup":true}',
      '{"policy":"bundle-rollback-or-restore-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_dispatch_plans (
      execution_id TEXT PRIMARY KEY,
      policy TEXT NOT NULL CHECK (policy = 'interleaved-randomized-v1'),
      policy_release_hash TEXT NOT NULL CHECK (length(policy_release_hash) = 64),
      seed_policy_hash TEXT NOT NULL CHECK (length(seed_policy_hash) = 64),
      seed_hash TEXT NOT NULL CHECK (length(seed_hash) = 64),
      expected_slot_set_hash TEXT NOT NULL
        CHECK (length(expected_slot_set_hash) = 64),
      plan_hash TEXT NOT NULL UNIQUE CHECK (length(plan_hash) = 64),
      entry_count INTEGER NOT NULL CHECK (entry_count > 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (execution_id) REFERENCES eval_executions(execution_id)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_dispatch_plans',
    message: 'evaluation dispatch plan is immutable',
  );
  db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_eval_trial_slots_execution_slot
    ON eval_trial_slots(execution_id, trial_slot_id)
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_dispatch_entries (
      execution_id TEXT NOT NULL,
      dispatch_ordinal INTEGER NOT NULL CHECK (dispatch_ordinal >= 0),
      trial_slot_id TEXT NOT NULL,
      pair_id TEXT NOT NULL CHECK (length(pair_id) = 64),
      arm_ordinal INTEGER NOT NULL CHECK (arm_ordinal >= 0),
      PRIMARY KEY (execution_id, dispatch_ordinal),
      UNIQUE (execution_id, trial_slot_id),
      UNIQUE (execution_id, pair_id, arm_ordinal),
      UNIQUE (execution_id, dispatch_ordinal, trial_slot_id),
      FOREIGN KEY (execution_id) REFERENCES eval_dispatch_plans(execution_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (execution_id, trial_slot_id)
        REFERENCES eval_trial_slots(execution_id, trial_slot_id)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_dispatch_entries',
    message: 'evaluation dispatch entry is immutable',
  );
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_dispatch_events (
      event_hash TEXT PRIMARY KEY CHECK (length(event_hash) = 64),
      execution_id TEXT NOT NULL,
      event_ordinal INTEGER NOT NULL CHECK (event_ordinal >= 0),
      dispatch_ordinal INTEGER NOT NULL CHECK (dispatch_ordinal >= 0),
      trial_slot_id TEXT NOT NULL,
      event_type TEXT NOT NULL
        CHECK (event_type IN (
          'claimed', 'reclaimed', 'renewed', 'attemptStarted', 'sealed'
        )),
      lease_epoch INTEGER NOT NULL CHECK (lease_epoch > 0),
      lease_owner TEXT NOT NULL CHECK (length(trim(lease_owner)) > 0),
      lease_expires_at_ms INTEGER,
      sealed_evidence_hash TEXT,
      attempt_no INTEGER,
      run_id TEXT,
      occurred_at_ms INTEGER NOT NULL CHECK (occurred_at_ms >= 0),
      previous_event_hash TEXT,
      UNIQUE (execution_id, event_ordinal),
      UNIQUE (execution_id, event_hash),
      CHECK ((event_ordinal = 0 AND previous_event_hash IS NULL)
        OR (event_ordinal > 0 AND previous_event_hash IS NOT NULL)),
      CHECK ((event_type = 'sealed' AND lease_expires_at_ms IS NULL
          AND sealed_evidence_hash IS NOT NULL
          AND length(sealed_evidence_hash) = 64)
        OR (event_type <> 'sealed' AND lease_expires_at_ms IS NOT NULL
          AND lease_expires_at_ms > occurred_at_ms
          AND sealed_evidence_hash IS NULL)),
      CHECK ((event_type = 'attemptStarted' AND attempt_no IS NOT NULL
          AND attempt_no > 0 AND run_id IS NOT NULL
          AND length(trim(run_id)) > 0)
        OR (event_type <> 'attemptStarted' AND attempt_no IS NULL
          AND run_id IS NULL)),
      FOREIGN KEY (execution_id, dispatch_ordinal, trial_slot_id)
        REFERENCES eval_dispatch_entries(
          execution_id, dispatch_ordinal, trial_slot_id
        )
        ON DELETE RESTRICT,
      FOREIGN KEY (execution_id, previous_event_hash)
        REFERENCES eval_dispatch_events(execution_id, event_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_dispatch_events',
    message: 'evaluation dispatch event is immutable',
  );
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_eval_dispatch_events_slot
    ON eval_dispatch_events(execution_id, trial_slot_id, event_ordinal)
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_production_authority_receipts (
      authority_receipt_hash TEXT PRIMARY KEY
        CHECK (length(authority_receipt_hash) = 64),
      authority_release_hash TEXT NOT NULL
        CHECK (length(authority_release_hash) = 64),
      execution_id TEXT NOT NULL,
      trial_slot_id TEXT NOT NULL,
      attempt_no INTEGER NOT NULL CHECK (attempt_no > 0),
      attempt_run_id TEXT NOT NULL CHECK (length(trim(attempt_run_id)) > 0),
      sandbox_database_path TEXT NOT NULL
        CHECK (length(trim(sandbox_database_path)) > 0),
      candidate_hash TEXT NOT NULL CHECK (length(candidate_hash) = 64),
      commit_receipt_id TEXT NOT NULL CHECK (length(trim(commit_receipt_id)) > 0),
      transaction_evidence_hash TEXT NOT NULL
        CHECK (length(transaction_evidence_hash) = 64),
      prose_hash TEXT NOT NULL CHECK (length(prose_hash) = 64),
      generation_bundle_hash TEXT NOT NULL
        CHECK (length(generation_bundle_hash) = 64),
      executor_release_hash TEXT NOT NULL
        CHECK (length(executor_release_hash) = 64),
      lease_epoch INTEGER NOT NULL CHECK (lease_epoch > 0),
      lease_owner TEXT NOT NULL CHECK (length(trim(lease_owner)) > 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (trial_slot_id, attempt_no),
      FOREIGN KEY (execution_id, trial_slot_id)
        REFERENCES eval_trial_slots(execution_id, trial_slot_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (trial_slot_id, attempt_no)
        REFERENCES eval_trial_attempts(trial_slot_id, attempt_no)
        ON DELETE RESTRICT,
      FOREIGN KEY (generation_bundle_hash)
        REFERENCES generation_bundles(bundle_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_production_authority_receipts',
    message: 'production authority receipt is append-only',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_production_executor_results (
      run_id TEXT PRIMARY KEY,
      result_json TEXT NOT NULL CHECK (length(result_json) <= 1048576),
      result_hash TEXT NOT NULL UNIQUE CHECK (length(result_hash) = 64),
      executor_release_hash TEXT NOT NULL
        CHECK (length(executor_release_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (run_id) REFERENCES story_generation_runs(run_id)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_production_executor_results',
    message: 'production executor recovery result is append-only',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_price_table_releases (
      price_table_hash TEXT PRIMARY KEY CHECK (length(price_table_hash) = 64),
      table_id TEXT NOT NULL UNIQUE CHECK (length(trim(table_id)) > 0),
      currency TEXT NOT NULL CHECK (currency = 'USD'),
      entries_json TEXT NOT NULL CHECK (length(entries_json) <= 1048576),
      rounding_policy TEXT NOT NULL
        CHECK (rounding_policy = 'ceil-per-attempt-microusd-v1'),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0)
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_price_table_releases',
    message: 'evaluation price table release is append-only',
  );
}

/// V20 backfills release execution authority tables for databases that had
/// already applied the initial V19 dispatch migration.
void createAgentEvaluationV20Tables(Database db) {
  createAgentEvaluationV19Tables(db);
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_deterministic_quality_receipts (
      receipt_hash TEXT PRIMARY KEY CHECK (length(receipt_hash) = 64),
      authority_release_hash TEXT NOT NULL
        CHECK (length(authority_release_hash) = 64),
      execution_id TEXT NOT NULL CHECK (length(trim(execution_id)) > 0),
      trial_slot_id TEXT NOT NULL CHECK (length(trim(trial_slot_id)) > 0),
      attempt_no INTEGER NOT NULL CHECK (attempt_no > 0),
      evaluation_bundle_hash TEXT NOT NULL
        CHECK (length(evaluation_bundle_hash) = 64),
      prose_hash TEXT NOT NULL CHECK (length(prose_hash) = 64),
      inputs_json TEXT NOT NULL CHECK (length(inputs_json) <= 1048576),
      scores_json TEXT NOT NULL CHECK (length(scores_json) <= 65536),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (execution_id, trial_slot_id, attempt_no)
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_deterministic_quality_receipts',
    message: 'deterministic quality receipt is append-only',
  );
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      20, 19, 20,
      '{"policy":"forward-only-v20","requiresBackup":true}',
      '{"policy":"bundle-rollback-or-restore-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}

void createAgentEvaluationV21Tables(Database db) {
  createAgentEvaluationV20Tables(db);
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      21, 20, 21,
      '{"policy":"forward-only-v21","requiresBackup":true}',
      '{"policy":"bundle-rollback-or-restore-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}

/// V22 makes episode state recoverable across processes without allowing a
/// stale worker to mutate the state observed by a successor. Each lease writes
/// an epoch-local SQLite copy; only the copy committed in the same authority
/// transaction as slot sealing becomes a readable generation. Holdout fixture
/// details remain outside this database; only a public-key-verifiable,
/// non-diagnostic attestation is retained here.
void createAgentEvaluationV22Tables(Database db) {
  createAgentEvaluationV21Tables(db);
  final tokenColumns = db.select("PRAGMA table_info('eval_holdout_tokens')");
  if (!tokenColumns.any((row) => row['name'] == 'regression_verdict_hash')) {
    db.execute(
      'ALTER TABLE eval_holdout_tokens ADD COLUMN regression_verdict_hash TEXT',
    );
  }
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_holdout_token_regression_update
    BEFORE UPDATE OF regression_verdict_hash ON eval_holdout_tokens
    BEGIN SELECT RAISE(ABORT, 'holdout regression eligibility is immutable'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS enforce_eval_holdout_family_single_probe
    BEFORE INSERT ON eval_holdout_tokens
    WHEN EXISTS (
      SELECT 1 FROM eval_holdout_tokens WHERE family_id = NEW.family_id
    )
    BEGIN SELECT RAISE(ABORT, 'holdout family permits one probe'); END
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_sandbox_generations (
      generation_hash TEXT PRIMARY KEY CHECK (length(generation_hash) = 64),
      execution_id TEXT NOT NULL,
      isolation_trial_id TEXT NOT NULL
        CHECK (length(trim(isolation_trial_id)) > 0),
      generation_no INTEGER NOT NULL CHECK (generation_no > 0),
      source_trial_slot_id TEXT NOT NULL UNIQUE,
      base_generation_hash TEXT,
      isolation_mode TEXT NOT NULL
        CHECK (isolation_mode IN ('independent', 'episode')),
      database_path TEXT NOT NULL CHECK (length(trim(database_path)) > 0),
      database_file_hash TEXT NOT NULL CHECK (length(database_file_hash) = 64),
      lease_epoch INTEGER NOT NULL CHECK (lease_epoch > 0),
      lease_owner TEXT NOT NULL CHECK (length(trim(lease_owner)) > 0),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (execution_id, isolation_trial_id, generation_no),
      FOREIGN KEY (execution_id, source_trial_slot_id)
        REFERENCES eval_trial_slots(execution_id, trial_slot_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (base_generation_hash)
        REFERENCES eval_sandbox_generations(generation_hash) ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_sandbox_generations',
    message: 'sandbox generation is append-only',
  );
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_eval_sandbox_generation_head
    ON eval_sandbox_generations(
      execution_id, isolation_trial_id, generation_no DESC
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_trusted_holdout_attestations (
      attestation_hash TEXT PRIMARY KEY CHECK (length(attestation_hash) = 64),
      confirmation_id TEXT NOT NULL UNIQUE,
      access_id TEXT NOT NULL UNIQUE,
      key_id TEXT NOT NULL CHECK (length(trim(key_id)) > 0),
      runner_release_hash TEXT NOT NULL CHECK (length(runner_release_hash) = 64),
      resolver_release_hash TEXT NOT NULL
        CHECK (length(resolver_release_hash) = 64),
      fixture_release_hash TEXT NOT NULL CHECK (length(fixture_release_hash) = 64),
      payload_json TEXT NOT NULL CHECK (length(payload_json) <= 65536),
      signature_base64 TEXT NOT NULL CHECK (length(trim(signature_base64)) > 0),
      issued_at_ms INTEGER NOT NULL CHECK (issued_at_ms >= 0),
      expires_at_ms INTEGER NOT NULL CHECK (expires_at_ms > issued_at_ms),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= issued_at_ms),
      FOREIGN KEY (confirmation_id)
        REFERENCES eval_holdout_confirmations(confirmation_id) ON DELETE RESTRICT,
      FOREIGN KEY (access_id)
        REFERENCES eval_holdout_accesses(access_id) ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_trusted_holdout_attestations',
    message: 'trusted holdout attestation is append-only',
  );

  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      22, 21, 22,
      '{"policy":"forward-only-v22","requiresBackup":true,"recoveryDrill":"required"}',
      '{"policy":"restore-v21-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}

/// V23 prevents the exact-reference V22 confirmation path from being used as
/// production release evidence. A family now freezes a separate opaque
/// holdout scenario set and private execution plan. The authoring database
/// receives only an Ed25519-bound, redacted projection; private prompts,
/// facts, paths, per-scenario evidence, and evaluator output stay in the
/// separately permissioned holdout process.
void createAgentEvaluationV23Tables(Database db) {
  createAgentEvaluationV22Tables(db);

  final familyColumns = db.select(
    "PRAGMA table_info('eval_experiment_families')",
  );
  if (!familyColumns.any(
    (row) => row['name'] == 'opaque_holdout_scenario_set_hash',
  )) {
    db.execute('''ALTER TABLE eval_experiment_families
      ADD COLUMN opaque_holdout_scenario_set_hash TEXT''');
  }
  if (!familyColumns.any((row) => row['name'] == 'private_plan_hash')) {
    db.execute('''ALTER TABLE eval_experiment_families
      ADD COLUMN private_plan_hash TEXT''');
  }
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_eval_family_v23_authority_update
    BEFORE UPDATE OF opaque_holdout_scenario_set_hash, private_plan_hash
    ON eval_experiment_families
    BEGIN SELECT RAISE(ABORT, 'production holdout authority is immutable'); END
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_production_holdout_accesses (
      access_id TEXT PRIMARY KEY CHECK (length(trim(access_id)) > 0),
      token_id TEXT NOT NULL UNIQUE,
      family_id TEXT NOT NULL,
      challenger_bundle_hash TEXT NOT NULL
        CHECK (length(challenger_bundle_hash) = 64),
      trusted_runner_release_hash TEXT NOT NULL
        CHECK (length(trusted_runner_release_hash) = 64),
      alpha_cost_micros INTEGER NOT NULL CHECK (alpha_cost_micros > 0),
      state TEXT NOT NULL CHECK (state IN ('begun', 'imported')),
      begun_at_ms INTEGER NOT NULL CHECK (begun_at_ms >= 0),
      imported_at_ms INTEGER,
      CHECK ((state = 'begun' AND imported_at_ms IS NULL) OR
        (state = 'imported' AND imported_at_ms >= begun_at_ms)),
      FOREIGN KEY (token_id) REFERENCES eval_holdout_tokens(token_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (family_id, challenger_bundle_hash)
        REFERENCES eval_family_challengers(family_id, challenger_bundle_hash)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS enforce_production_holdout_access_transition
    BEFORE UPDATE OF state, imported_at_ms
    ON eval_production_holdout_accesses
    WHEN NOT (
      OLD.state = 'begun' AND OLD.imported_at_ms IS NULL AND
      NEW.state = 'imported' AND NEW.imported_at_ms >= OLD.begun_at_ms
    )
    BEGIN SELECT RAISE(ABORT, 'production holdout access transition is invalid'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_production_holdout_access_identity_update
    BEFORE UPDATE OF access_id, token_id, family_id,
      challenger_bundle_hash, trusted_runner_release_hash,
      alpha_cost_micros, begun_at_ms
    ON eval_production_holdout_accesses
    BEGIN SELECT RAISE(ABORT, 'production holdout access identity is immutable'); END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_production_holdout_access_delete
    BEFORE DELETE ON eval_production_holdout_accesses
    BEGIN SELECT RAISE(ABORT, 'production holdout access is permanent'); END
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_production_holdout_claims (
      claim_hash TEXT PRIMARY KEY CHECK (length(claim_hash) = 64),
      access_id TEXT NOT NULL UNIQUE,
      family_id TEXT NOT NULL,
      token_id TEXT NOT NULL UNIQUE,
      regression_verdict_hash TEXT NOT NULL
        CHECK (length(regression_verdict_hash) = 64),
      champion_bundle_hash TEXT NOT NULL
        CHECK (length(champion_bundle_hash) = 64),
      challenger_bundle_hash TEXT NOT NULL
        CHECK (length(challenger_bundle_hash) = 64),
      regression_scenario_set_hash TEXT NOT NULL
        CHECK (length(regression_scenario_set_hash) = 64),
      opaque_holdout_scenario_set_hash TEXT NOT NULL
        CHECK (length(opaque_holdout_scenario_set_hash) = 64),
      private_plan_hash TEXT NOT NULL CHECK (length(private_plan_hash) = 64),
      production_manifest_hash TEXT NOT NULL
        CHECK (length(production_manifest_hash) = 64),
      redacted_execution_summary_hash TEXT NOT NULL
        CHECK (length(redacted_execution_summary_hash) = 64),
      private_execution_summary_hash TEXT NOT NULL
        CHECK (length(private_execution_summary_hash) = 64),
      redacted_execution_summary_json TEXT NOT NULL
        CHECK (length(redacted_execution_summary_json) <= 65536),
      private_scorecard_hash TEXT NOT NULL
        CHECK (length(private_scorecard_hash) = 64),
      redacted_scorecard_hash TEXT NOT NULL
        CHECK (length(redacted_scorecard_hash) = 64),
      redacted_scorecard_json TEXT NOT NULL
        CHECK (length(redacted_scorecard_json) <= 65536),
      private_gate_verdict_hash TEXT NOT NULL
        CHECK (length(private_gate_verdict_hash) = 64),
      redacted_gate_verdict_hash TEXT NOT NULL
        CHECK (length(redacted_gate_verdict_hash) = 64),
      redacted_gate_verdict_json TEXT NOT NULL
        CHECK (length(redacted_gate_verdict_json) <= 65536),
      private_projection_hash TEXT NOT NULL
        CHECK (length(private_projection_hash) = 64),
      expected_cell_set_hash TEXT NOT NULL
        CHECK (length(expected_cell_set_hash) = 64),
      expected_slot_set_hash TEXT NOT NULL
        CHECK (length(expected_slot_set_hash) = 64),
      execution_budget_policy_hash TEXT NOT NULL
        CHECK (length(execution_budget_policy_hash) = 64),
      executor_release_hash TEXT NOT NULL
        CHECK (length(executor_release_hash) = 64),
      evaluation_bundle_hash TEXT NOT NULL
        CHECK (length(evaluation_bundle_hash) = 64),
      price_table_hash TEXT NOT NULL CHECK (length(price_table_hash) = 64),
      gate_policy_hash TEXT NOT NULL CHECK (length(gate_policy_hash) = 64),
      audit_root_hash TEXT NOT NULL CHECK (length(audit_root_hash) = 64),
      result TEXT NOT NULL
        CHECK (result IN ('pass', 'fail', 'insufficientEvidence')),
      key_id TEXT NOT NULL CHECK (length(trim(key_id)) > 0),
      runner_release_hash TEXT NOT NULL CHECK (length(runner_release_hash) = 64),
      resolver_release_hash TEXT NOT NULL
        CHECK (length(resolver_release_hash) = 64),
      payload_json TEXT NOT NULL CHECK (length(payload_json) <= 65536),
      signature_base64 TEXT NOT NULL CHECK (length(trim(signature_base64)) > 0),
      issued_at_ms INTEGER NOT NULL CHECK (issued_at_ms >= 0),
      expires_at_ms INTEGER NOT NULL CHECK (expires_at_ms > issued_at_ms),
      imported_at_ms INTEGER NOT NULL
        CHECK (imported_at_ms >= issued_at_ms AND imported_at_ms < expires_at_ms),
      FOREIGN KEY (access_id)
        REFERENCES eval_production_holdout_accesses(access_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (token_id) REFERENCES eval_holdout_tokens(token_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (regression_verdict_hash)
        REFERENCES eval_release_gate_verdicts(verdict_hash) ON DELETE RESTRICT,
      FOREIGN KEY (price_table_hash)
        REFERENCES eval_price_table_releases(price_table_hash) ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_production_holdout_claims',
    message: 'production holdout claim is append-only',
  );

  db.execute('''
    CREATE TABLE IF NOT EXISTS prompt_release_decision_production_authorizations (
      decision_id TEXT PRIMARY KEY,
      regression_verdict_hash TEXT NOT NULL,
      production_holdout_claim_hash TEXT NOT NULL UNIQUE,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (decision_id) REFERENCES prompt_release_decisions(decision_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (regression_verdict_hash)
        REFERENCES eval_release_gate_verdicts(verdict_hash) ON DELETE RESTRICT,
      FOREIGN KEY (production_holdout_claim_hash)
        REFERENCES eval_production_holdout_claims(claim_hash) ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'prompt_release_decision_production_authorizations',
    message: 'production release decision authorization is immutable',
  );

  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      23, 22, 23,
      '{"policy":"forward-only-v23","requiresBackup":true,"productionHoldout":"signed-redacted-v2","recoveryDrill":"required"}',
      '{"policy":"restore-v22-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}

/// V24 makes the production family identity a database authority. A caller
/// cannot obtain a fresh private probe merely by changing a coordinator run
/// identifier while retaining the same frozen public/private commitments.
void createAgentEvaluationV24Tables(Database db) {
  createAgentEvaluationV23Tables(db);
  final familyColumns = db.select(
    "PRAGMA table_info('eval_experiment_families')",
  );
  if (!familyColumns.any((row) => row['name'] == 'production_authority_hash')) {
    db.execute('''ALTER TABLE eval_experiment_families
      ADD COLUMN production_authority_hash TEXT''');
  }
  db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS
      uq_eval_production_family_authority
    ON eval_experiment_families(production_authority_hash)
    WHERE production_authority_hash IS NOT NULL
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS prevent_eval_family_v24_authority_update
    BEFORE UPDATE OF production_authority_hash ON eval_experiment_families
    BEGIN SELECT RAISE(ABORT, 'production family authority is immutable'); END
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_final_release_report_seals (
      report_hash TEXT PRIMARY KEY CHECK (length(report_hash) = 64),
      file_content_hash TEXT NOT NULL CHECK (length(file_content_hash) = 64),
      report_path_hash TEXT NOT NULL CHECK (length(report_path_hash) = 64),
      authority_audit_root_hash TEXT NOT NULL
        CHECK (length(authority_audit_root_hash) = 64),
      release_configuration_hash TEXT NOT NULL
        CHECK (length(release_configuration_hash) = 64),
      regression_verdict_hash TEXT NOT NULL,
      production_holdout_claim_hash TEXT NOT NULL,
      promotion_decision_id TEXT NOT NULL UNIQUE,
      rollback_decision_id TEXT NOT NULL UNIQUE,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (regression_verdict_hash)
        REFERENCES eval_release_gate_verdicts(verdict_hash) ON DELETE RESTRICT,
      FOREIGN KEY (production_holdout_claim_hash)
        REFERENCES eval_production_holdout_claims(claim_hash) ON DELETE RESTRICT,
      FOREIGN KEY (promotion_decision_id)
        REFERENCES prompt_release_decisions(decision_id) ON DELETE RESTRICT,
      FOREIGN KEY (rollback_decision_id)
        REFERENCES prompt_release_decisions(decision_id) ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_final_release_report_seals',
    message: 'final release report seal is append-only',
  );
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      24, 23, 24,
      '{"policy":"forward-only-v24","requiresBackup":true}',
      '{"policy":"bundle-rollback-or-restore-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}

/// V25 makes the provider-complete / author-accept boundary recoverable.
///
/// The checkpoint is additive and append-only. Older application versions
/// must restore a V24 backup; they cannot open or write a V25 database in
/// place. V25 readers use it only after recomputing its content hash and
/// checking the attempt, manifest, candidate, and executor identities.
void createAgentEvaluationV25Tables(Database db) {
  createAgentEvaluationV24Tables(db);
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_production_prepared_results (
      run_id TEXT PRIMARY KEY,
      execution_id TEXT NOT NULL CHECK (length(trim(execution_id)) > 0),
      trial_slot_id TEXT NOT NULL CHECK (length(trim(trial_slot_id)) > 0),
      attempt_no INTEGER NOT NULL CHECK (attempt_no > 0),
      original_lease_epoch INTEGER NOT NULL CHECK (original_lease_epoch > 0),
      original_lease_owner TEXT NOT NULL
        CHECK (length(trim(original_lease_owner)) > 0),
      cell_id TEXT NOT NULL CHECK (length(trim(cell_id)) > 0),
      manifest_hash TEXT NOT NULL CHECK (length(manifest_hash) = 64),
      candidate_revision INTEGER NOT NULL CHECK (candidate_revision >= 0),
      candidate_hash TEXT NOT NULL CHECK (length(candidate_hash) = 64),
      prepared_json TEXT NOT NULL CHECK (length(prepared_json) <= 4194304),
      prepared_hash TEXT NOT NULL UNIQUE CHECK (length(prepared_hash) = 64),
      executor_release_hash TEXT NOT NULL
        CHECK (length(executor_release_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (trial_slot_id, attempt_no),
      FOREIGN KEY (run_id, candidate_revision)
        REFERENCES story_generation_candidate_proofs(run_id, candidate_revision)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS validate_eval_production_prepared_insert
    BEFORE INSERT ON eval_production_prepared_results
    WHEN NOT EXISTS (
      SELECT 1
      FROM story_generation_runs run
      JOIN story_generation_candidate_proofs proof
        ON proof.run_id = run.run_id
       AND proof.candidate_revision = run.current_candidate_revision
      WHERE run.run_id = NEW.run_id
        AND run.status = 'candidateReady'
        AND run.current_candidate_revision = NEW.candidate_revision
        AND CASE
              WHEN proof.candidate_hash LIKE 'sha256:%'
                THEN substr(proof.candidate_hash, 8)
              ELSE proof.candidate_hash
            END = NEW.candidate_hash
    )
    BEGIN
      SELECT RAISE(ABORT, 'prepared evidence candidate identity is invalid');
    END
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_production_prepared_results',
    message: 'prepared production evaluation evidence is append-only',
  );
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      25, 24, 25,
      '{"policy":"forward-only-v25","requiresBackup":true,"preparedRecovery":"append-only-v1"}',
      '{"policy":"bundle-rollback-or-restore-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}

/// V26 moves provider-complete sandbox recovery under the Runner authority.
///
/// Each row binds one immutable SQLite snapshot to the formal execution,
/// slot, attempt, run, manifest, candidate, and both the original and writing
/// lease identities. The optional seal row is written in the same authority
/// transaction as the terminal sandbox generation and retains the complete
/// recovery chain for audit. V25 rollback requires restoring the pre-upgrade
/// backup; in-place downgrade is not supported.
void createAgentEvaluationV26Tables(Database db) {
  createAgentEvaluationV25Tables(db);
  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_sandbox_recovery_checkpoints (
      checkpoint_hash TEXT PRIMARY KEY CHECK (length(checkpoint_hash) = 64),
      execution_id TEXT NOT NULL CHECK (length(trim(execution_id)) > 0),
      trial_slot_id TEXT NOT NULL CHECK (length(trim(trial_slot_id)) > 0),
      attempt_no INTEGER NOT NULL CHECK (attempt_no > 0),
      attempt_run_id TEXT NOT NULL CHECK (length(trim(attempt_run_id)) > 0),
      original_lease_epoch INTEGER NOT NULL CHECK (original_lease_epoch > 0),
      original_lease_owner TEXT NOT NULL
        CHECK (length(trim(original_lease_owner)) > 0),
      writer_lease_epoch INTEGER NOT NULL CHECK (writer_lease_epoch > 0),
      writer_lease_owner TEXT NOT NULL
        CHECK (length(trim(writer_lease_owner)) > 0),
      cell_id TEXT NOT NULL CHECK (length(cell_id) = 64),
      manifest_hash TEXT NOT NULL CHECK (length(manifest_hash) = 64),
      isolation_trial_id TEXT NOT NULL
        CHECK (length(trim(isolation_trial_id)) > 0),
      isolation_mode TEXT NOT NULL
        CHECK (isolation_mode IN ('independent', 'episode')),
      checkpoint_no INTEGER NOT NULL CHECK (checkpoint_no BETWEEN 1 AND 4),
      stage TEXT NOT NULL
        CHECK (stage IN ('prepared', 'accepted', 'outboxCompleted', 'finalPersisted')),
      candidate_hash TEXT NOT NULL CHECK (length(candidate_hash) = 64),
      database_path TEXT NOT NULL CHECK (length(trim(database_path)) > 0),
      database_file_hash TEXT NOT NULL CHECK (length(database_file_hash) = 64),
      database_file_size INTEGER NOT NULL CHECK (database_file_size > 0),
      state_projection_hash TEXT NOT NULL
        CHECK (length(state_projection_hash) = 64),
      base_checkpoint_hash TEXT,
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      UNIQUE (trial_slot_id, attempt_no, checkpoint_no),
      UNIQUE (trial_slot_id, attempt_no, stage),
      CHECK (
        (checkpoint_no = 1 AND stage = 'prepared') OR
        (checkpoint_no = 2 AND stage = 'accepted') OR
        (checkpoint_no = 3 AND stage = 'outboxCompleted') OR
        (checkpoint_no = 4 AND stage = 'finalPersisted')
      ),
      CHECK (
        (checkpoint_no = 1 AND base_checkpoint_hash IS NULL) OR
        (checkpoint_no > 1 AND base_checkpoint_hash IS NOT NULL
          AND length(base_checkpoint_hash) = 64)
      ),
      FOREIGN KEY (execution_id, trial_slot_id)
        REFERENCES eval_trial_slots(execution_id, trial_slot_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (trial_slot_id, attempt_no)
        REFERENCES eval_trial_attempts(trial_slot_id, attempt_no)
        ON DELETE RESTRICT,
      FOREIGN KEY (base_checkpoint_hash)
        REFERENCES eval_sandbox_recovery_checkpoints(checkpoint_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_sandbox_recovery_checkpoints',
    message: 'sandbox recovery checkpoint is append-only',
  );
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_eval_sandbox_recovery_attempt_head
    ON eval_sandbox_recovery_checkpoints(
      trial_slot_id, attempt_no, checkpoint_no DESC
    )
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS validate_eval_sandbox_recovery_insert
    BEFORE INSERT ON eval_sandbox_recovery_checkpoints
    WHEN
      NOT EXISTS (
        SELECT 1
        FROM eval_trial_slots slot
        JOIN eval_trial_attempts attempt
          ON attempt.trial_slot_id = slot.trial_slot_id
         AND attempt.attempt_no = NEW.attempt_no
        JOIN eval_executions execution
          ON execution.execution_id = slot.execution_id
        JOIN eval_experiments experiment
          ON experiment.experiment_id = execution.experiment_id
        WHERE slot.execution_id = NEW.execution_id
          AND slot.trial_slot_id = NEW.trial_slot_id
          AND slot.cell_id = NEW.cell_id
          AND slot.status IN ('leased', 'running')
          AND slot.lease_epoch = NEW.writer_lease_epoch
          AND slot.lease_owner = NEW.writer_lease_owner
          AND slot.lease_expires_at_ms > NEW.created_at_ms
          AND attempt.run_id = NEW.attempt_run_id
          AND attempt.status = 'started'
          AND attempt.lease_epoch = NEW.writer_lease_epoch
          AND attempt.lease_owner = NEW.writer_lease_owner
          AND experiment.manifest_hash = NEW.manifest_hash
      )
      OR (
        NEW.checkpoint_no = 1 AND (
          NEW.original_lease_epoch <> NEW.writer_lease_epoch OR
          NEW.original_lease_owner <> NEW.writer_lease_owner
        )
      )
      OR (
        NEW.checkpoint_no > 1 AND NOT EXISTS (
          SELECT 1
          FROM eval_sandbox_recovery_checkpoints previous
          WHERE previous.checkpoint_hash = NEW.base_checkpoint_hash
            AND previous.execution_id = NEW.execution_id
            AND previous.trial_slot_id = NEW.trial_slot_id
            AND previous.attempt_no = NEW.attempt_no
            AND previous.attempt_run_id = NEW.attempt_run_id
            AND previous.original_lease_epoch = NEW.original_lease_epoch
            AND previous.original_lease_owner = NEW.original_lease_owner
            AND previous.cell_id = NEW.cell_id
            AND previous.manifest_hash = NEW.manifest_hash
            AND previous.isolation_trial_id = NEW.isolation_trial_id
            AND previous.isolation_mode = NEW.isolation_mode
            AND previous.candidate_hash = NEW.candidate_hash
            AND previous.checkpoint_no = NEW.checkpoint_no - 1
        )
      )
    BEGIN
      SELECT RAISE(ABORT, 'sandbox recovery checkpoint identity is invalid');
    END
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS eval_sandbox_recovery_seals (
      trial_slot_id TEXT PRIMARY KEY,
      checkpoint_hash TEXT NOT NULL UNIQUE,
      generation_hash TEXT NOT NULL UNIQUE,
      sealed_evidence_hash TEXT NOT NULL
        CHECK (length(sealed_evidence_hash) = 64),
      created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
      FOREIGN KEY (trial_slot_id)
        REFERENCES eval_trial_slots(trial_slot_id) ON DELETE RESTRICT,
      FOREIGN KEY (checkpoint_hash)
        REFERENCES eval_sandbox_recovery_checkpoints(checkpoint_hash)
        ON DELETE RESTRICT,
      FOREIGN KEY (generation_hash)
        REFERENCES eval_sandbox_generations(generation_hash)
        ON DELETE RESTRICT
    )
  ''');
  _makeAgentEvalTableAppendOnly(
    db,
    table: 'eval_sandbox_recovery_seals',
    message: 'sandbox recovery seal binding is append-only',
  );
  db.execute('''
    INSERT OR IGNORE INTO schema_compatibility_contracts (
      schema_version, min_reader_version, min_writer_version,
      upgrade_policy_json, rollback_policy_json, created_at_ms
    ) VALUES (
      26, 25, 26,
      '{"policy":"forward-only-v26","requiresBackup":true,"runnerRecovery":"hash-bound-snapshot-chain-v1"}',
      '{"policy":"bundle-rollback-or-restore-backup","inPlaceDowngrade":false}',
      0
    )
  ''');
}
