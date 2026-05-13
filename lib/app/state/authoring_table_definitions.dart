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
      source_refs_json TEXT NOT NULL DEFAULT '[]',
      root_source_ids_json TEXT NOT NULL DEFAULT '[]',
      visibility TEXT NOT NULL DEFAULT 'publicObservable',
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
