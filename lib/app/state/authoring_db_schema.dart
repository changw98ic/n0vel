import 'package:sqlite3/sqlite3.dart';

import 'db_schema_manager.dart';
import 'authoring_legacy_migrations.dart';
import 'authoring_table_definitions.dart';

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
    description: 'Add character_relations table for inter-character relationships.',
    migrate: _migrateAuthoringV3,
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
