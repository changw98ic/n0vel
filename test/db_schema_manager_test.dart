import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/app/state/simulation_db_schema.dart';
import 'package:novel_writer/app/state/telemetry_db_schema.dart';

void main() {
  // ── Core DatabaseSchemaManager ──────────────────────────────────────────

  group('DatabaseSchemaManager', () {
    test('runs migrations in version order', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      final log = <String>[];
      final manager = DatabaseSchemaManager(
        migrations: [
          SchemaMigration(
            version: 3,
            description: 'v3',
            migrate: (_) => log.add('v3'),
          ),
          SchemaMigration(
            version: 1,
            description: 'v1',
            migrate: (_) => log.add('v1'),
          ),
          SchemaMigration(
            version: 2,
            description: 'v2',
            migrate: (_) => log.add('v2'),
          ),
        ],
      );
      manager.ensureSchema(db);

      expect(log, ['v1', 'v2', 'v3']);
      expect(db.select('PRAGMA user_version').first['user_version'], 3);
    });

    test('is idempotent — second call is a no-op', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      var callCount = 0;
      final manager = DatabaseSchemaManager(
        migrations: [
          SchemaMigration(
            version: 1,
            description: 'once',
            migrate: (_) => callCount++,
          ),
        ],
      );

      manager.ensureSchema(db);
      manager.ensureSchema(db);

      expect(callCount, 1);
      expect(db.select('PRAGMA user_version').first['user_version'], 1);
    });

    test('only runs pending migrations', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      // Pre-set user_version to 1
      db.execute('PRAGMA user_version = 1');

      final log = <String>[];
      final manager = DatabaseSchemaManager(
        migrations: [
          SchemaMigration(
            version: 1,
            description: 'v1',
            migrate: (_) => log.add('v1'),
          ),
          SchemaMigration(
            version: 2,
            description: 'v2',
            migrate: (_) => log.add('v2'),
          ),
          SchemaMigration(
            version: 3,
            description: 'v3',
            migrate: (_) => log.add('v3'),
          ),
        ],
      );
      manager.ensureSchema(db);

      expect(log, ['v2', 'v3']);
      expect(db.select('PRAGMA user_version').first['user_version'], 3);
    });

    test('rolls back on migration failure', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      final manager = DatabaseSchemaManager(
        migrations: [
          SchemaMigration(
            version: 1,
            description: 'create table',
            migrate: (db) =>
                db.execute('CREATE TABLE foo (id INTEGER PRIMARY KEY)'),
          ),
          SchemaMigration(
            version: 2,
            description: 'failing',
            migrate: (_) => throw Exception('boom'),
          ),
        ],
      );

      expect(() => manager.ensureSchema(db), throwsException);
      expect(db.select('PRAGMA user_version').first['user_version'], 0);

      // Table should not exist — rolled back.
      final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'foo'",
      );
      expect(tables, isEmpty);
    });

    test('does nothing when migrations list is empty', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      final manager = DatabaseSchemaManager(migrations: const []);
      manager.ensureSchema(db);

      expect(db.select('PRAGMA user_version').first['user_version'], 0);
    });
  });

  // ── Authoring database schema ───────────────────────────────────────────

  group('authoring schema v1', () {
    test('creates all expected tables on fresh database', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      final tables = db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .map((r) => r['name'] as String)
          .toList();

      expect(
        tables,
        containsAll([
          'workspace_projects',
          'workspace_characters',
          'workspace_scenes',
          'workspace_world_nodes',
          'workspace_audit_issues',
          'workspace_preferences',
          'workspace_project_preferences',
          'version_entries',
          'draft_documents',
          'ai_history_entries',
          'scene_context_snapshots',
          'story_outline_snapshots',
          'story_generation_state',
          'story_memory_sources',
          'story_memory_chunks',
          'story_thought_atoms',
          'vector_embeddings',
          'vector_lsh_buckets',
          'character_relations',
        ]),
      );
      expect(
        db.select('PRAGMA user_version').first['user_version'],
        authoringSchemaMigrations.length,
      );
    });

    test('creates story memory indexes', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      final indexes = db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'index' ORDER BY name",
          )
          .map((r) => r['name'] as String)
          .toList();

      expect(
        indexes,
        containsAll([
          'idx_memory_sources_project',
          'idx_memory_chunks_project',
          'idx_memory_tier',
          'idx_thought_atoms_project',
          'idx_vector_embeddings_scope',
          'idx_vector_lsh_lookup',
        ]),
      );
    });

    test('central story memory schema includes runtime authority fields', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      final chunkColumns = db
          .select("SELECT name FROM pragma_table_info('story_memory_chunks')")
          .map((row) => row['name'] as String)
          .toSet();
      final thoughtColumns = db
          .select("SELECT name FROM pragma_table_info('story_thought_atoms')")
          .map((row) => row['name'] as String)
          .toSet();

      expect(chunkColumns, containsAll(['tier', 'producer', 'owner_id']));
      expect(thoughtColumns, contains('tier'));
    });

    test('V27 additively preserves V26 memory rows and is idempotent', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      db.execute('''
        CREATE TABLE story_memory_chunks (
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
          tags_json TEXT NOT NULL DEFAULT '[]',
          priority INTEGER NOT NULL DEFAULT 0,
          token_cost_estimate INTEGER NOT NULL DEFAULT 0,
          created_at_ms INTEGER NOT NULL DEFAULT 0
        )
      ''');
      db.execute('''
        CREATE TABLE schema_compatibility_contracts (
          schema_version INTEGER PRIMARY KEY,
          min_reader_version INTEGER NOT NULL,
          min_writer_version INTEGER NOT NULL,
          upgrade_policy_json TEXT NOT NULL,
          rollback_policy_json TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL
        )
      ''');
      db.execute('''
        INSERT INTO story_memory_chunks (
          id, project_id, scope_id, chunk_kind, content, visibility
        ) VALUES (
          'legacy-private', 'project', 'scene', 'characterProfile',
          'legacy secret', 'agentPrivate'
        )
      ''');
      db.execute('PRAGMA user_version = 26');

      final manager = DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      );
      manager.ensureSchema(db);
      final firstSchema = db
          .select(
            "SELECT sql FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .map((row) => row['sql']?.toString() ?? '')
          .join('\n');
      manager.ensureSchema(db);

      expect(db.select('PRAGMA user_version').single['user_version'], 27);
      final row = db.select(
        'SELECT content, visibility, owner_id '
        'FROM story_memory_chunks WHERE id = ?',
        ['legacy-private'],
      ).single;
      expect(row['content'], 'legacy secret');
      expect(row['visibility'], 'agentPrivate');
      expect(row['owner_id'], '');
      expect(
        db
            .select(
              "SELECT sql FROM sqlite_master WHERE type = 'table' ORDER BY name",
            )
            .map((row) => row['sql']?.toString() ?? '')
            .join('\n'),
        firstSchema,
      );
      expect(
        db
            .select(
              'SELECT min_reader_version, min_writer_version '
              'FROM schema_compatibility_contracts '
              'WHERE schema_version = 27',
            )
            .single
            .values,
        [27, 27],
      );
    });

    test('migrates legacy workspace_projects without id/scene_id columns', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      // Create old-style table without id, scene_id, last_opened_at_ms.
      db.execute('''
        CREATE TABLE workspace_projects (
          scope_key TEXT NOT NULL,
          position_no INTEGER NOT NULL,
          title TEXT NOT NULL,
          genre TEXT NOT NULL,
          summary TEXT NOT NULL,
          recent_location TEXT NOT NULL,
          PRIMARY KEY (scope_key, position_no)
        )
      ''');
      db.execute('''
        INSERT INTO workspace_projects
          (scope_key, position_no, title, genre, summary, recent_location)
        VALUES ('workspace-default', 0, 'Test', 'Fantasy', 'A test', '场景 1')
      ''');

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      final rows = db.select(
        'SELECT id, scene_id, last_opened_at_ms FROM workspace_projects',
      );
      expect(rows, hasLength(1));
      expect(rows.first['id'], 'project-yuechao');
      expect(rows.first['scene_id'], 'scene-01-migrated-0');
      expect(rows.first['last_opened_at_ms'], isNonZero);
    });

    test('migrates legacy version_entries without project_id', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      db.execute('''
        CREATE TABLE version_entries (
          sequence_no INTEGER NOT NULL,
          label TEXT NOT NULL,
          content TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL,
          PRIMARY KEY (sequence_no)
        )
      ''');
      db.execute('''
        INSERT INTO version_entries (sequence_no, label, content, updated_at_ms)
        VALUES (0, 'v1', 'content', 1000)
      ''');

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      final rows = db.select('SELECT project_id, label FROM version_entries');
      expect(rows, hasLength(1));
      expect(rows.first['project_id'], 'project-yuechao');
      expect(rows.first['label'], 'v1');
    });

    test('migrates legacy draft_documents without project_id', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      db.execute('''
        CREATE TABLE draft_documents (
          text_body TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
      ''');
      db.execute('''
        INSERT INTO draft_documents (text_body, updated_at_ms)
        VALUES ('hello', 1000)
      ''');

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      final rows = db.select(
        'SELECT project_id, text_body FROM draft_documents',
      );
      expect(rows, hasLength(1));
      expect(rows.first['project_id'], 'project-yuechao');
      expect(rows.first['text_body'], 'hello');
    });

    test('does not re-migrate on second ensureSchema call', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      final manager = DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      );
      manager.ensureSchema(db);

      // Insert a row to detect if tables were dropped/recreated.
      db.execute(
        'INSERT INTO version_entries (project_id, sequence_no, label, content, updated_at_ms) '
        "VALUES ('test', 0, 'v1', 'c', 1000)",
      );

      manager.ensureSchema(db);

      final rows = db.select('SELECT * FROM version_entries');
      expect(rows, hasLength(1));
      expect(rows.first['project_id'], 'test');
    });
  });

  // ── Telemetry database schema ───────────────────────────────────────────

  group('telemetry schema v1', () {
    test('creates event log table with indexes', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      DatabaseSchemaManager(
        migrations: telemetrySchemaMigrations,
      ).ensureSchema(db);

      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toList();
      expect(tables, contains('app_event_log_entries'));

      final indexes = db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'index' ORDER BY name",
          )
          .map((r) => r['name'] as String)
          .toList();
      expect(
        indexes,
        containsAll([
          'idx_app_event_log_entries_timestamp',
          'idx_app_event_log_entries_category_action_time',
          'idx_app_event_log_entries_correlation',
          'idx_app_event_log_entries_project_scene_time',
        ]),
      );

      expect(db.select('PRAGMA user_version').first['user_version'], 1);
    });
  });

  // ── Simulation database schema ──────────────────────────────────────────

  group('simulation schema v1', () {
    test('creates simulation tables on fresh database', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      DatabaseSchemaManager(
        migrations: simulationSchemaMigrations,
      ).ensureSchema(db);

      final tables = db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .map((r) => r['name'] as String)
          .toList();

      expect(
        tables,
        containsAll([
          'simulation_runs',
          'simulation_participant_prompts',
          'simulation_chat_messages',
        ]),
      );
      expect(db.select('PRAGMA user_version').first['user_version'], 1);
    });

    test('migrates legacy simulation_state table', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      // Create legacy table with JSON payload.
      db.execute('''
        CREATE TABLE simulation_state (
          id INTEGER PRIMARY KEY,
          payload_json TEXT NOT NULL
        )
      ''');
      db.execute('''
        INSERT INTO simulation_state (id, payload_json) VALUES (1, '{"template":"dialogue","promptOverrides":{"char1":"prompt"},"extraMessages":[]}')
      ''');

      DatabaseSchemaManager(
        migrations: simulationSchemaMigrations,
      ).ensureSchema(db);

      // Legacy table should be gone.
      final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'simulation_state'",
      );
      expect(tables, isEmpty);

      // Data should be in new tables.
      final runs = db.select('SELECT * FROM simulation_runs');
      expect(runs, hasLength(1));
      expect(runs.first['template_name'], 'dialogue');

      final prompts = db.select('SELECT * FROM simulation_participant_prompts');
      expect(prompts, hasLength(1));
      expect(prompts.first['participant_key'], 'char1');
    });

    test('handles malformed legacy payload gracefully', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      db.execute('''
        CREATE TABLE simulation_state (
          id INTEGER PRIMARY KEY,
          payload_json TEXT NOT NULL
        )
      ''');
      db.execute('''
        INSERT INTO simulation_state (id, payload_json) VALUES (1, 'not-valid-json')
      ''');

      // Should not throw.
      DatabaseSchemaManager(
        migrations: simulationSchemaMigrations,
      ).ensureSchema(db);

      // Legacy table should be gone, tables created.
      final tables = db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .map((r) => r['name'] as String)
          .toList();
      expect(
        tables,
        containsAll([
          'simulation_runs',
          'simulation_participant_prompts',
          'simulation_chat_messages',
        ]),
      );
    });
  });
}
