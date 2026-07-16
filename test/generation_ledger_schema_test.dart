import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/authoring_table_definitions.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('V9 story-generation ledger schema', () {
    test(
      'creates the durable proof, payload, budget, event, and outbox tables',
      () {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');

        DatabaseSchemaManager(
          migrations: authoringSchemaMigrations,
        ).ensureSchema(db);

        final tables = db
            .select("SELECT name FROM sqlite_master WHERE type = 'table'")
            .map((row) => row['name'] as String)
            .toSet();
        expect(
          tables,
          containsAll([
            'story_generation_runs',
            'story_generation_working_prose_revisions',
            'story_generation_candidate_namespaces',
            'story_generation_candidate_proofs',
            'story_generation_candidate_payloads',
            'story_generation_pending_writes',
            'story_generation_commit_receipts',
            'story_generation_committed_continuity',
            'story_generation_run_budgets',
            'story_generation_budget_reservations',
            'story_generation_events',
            'story_generation_outbox',
          ]),
        );
        expect(
          db.select('PRAGMA user_version').single['user_version'],
          authoringSchemaMigrations.length,
        );

        final pendingPrimaryKey =
            db
                .select("PRAGMA table_info('story_generation_pending_writes')")
                .where((row) => (row['pk'] as int) > 0)
                .toList()
              ..sort(
                (left, right) =>
                    (left['pk'] as int).compareTo(right['pk'] as int),
              );
        expect(pendingPrimaryKey.map((row) => row['name']), [
          'run_id',
          'candidate_revision',
          'write_id',
        ]);
        expect(
          pendingPrimaryKey.map((row) => row['name']),
          isNot(contains('payload_hash')),
        );

        final proofForeignKeys = db.select(
          "PRAGMA foreign_key_list('story_generation_candidate_proofs')",
        );
        expect(
          proofForeignKeys.any(
            (row) => row['table'] == 'story_generation_candidate_namespaces',
          ),
          isTrue,
        );
        final continuityTriggers = db
            .select('''SELECT name FROM sqlite_master
                 WHERE type = 'trigger'
                   AND tbl_name = 'story_generation_committed_continuity' ''')
            .map((row) => row['name'] as String)
            .toSet();
        expect(
          continuityTriggers,
          containsAll(<String>{
            'prevent_committed_continuity_update',
            'prevent_committed_continuity_delete',
          }),
        );
        final commitOrdinalColumn = db
            .select(
              "PRAGMA table_info('story_generation_committed_continuity')",
            )
            .singleWhere((row) => row['name'] == 'commit_ordinal');
        expect(commitOrdinalColumn['notnull'], 1);
        final commitOrdinalIndex = db
            .select(
              "PRAGMA index_list('story_generation_committed_continuity')",
            )
            .singleWhere(
              (row) =>
                  row['name'] ==
                  'idx_generation_committed_continuity_commit_ordinal',
            );
        expect(commitOrdinalIndex['unique'], 1);
      },
    );

    test(
      'rolls V9 creation back when a migration fails after table creation',
      () {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA user_version = 8');
        final manager = DatabaseSchemaManager(
          migrations: [
            SchemaMigration(
              version: 9,
              description: 'fault injection',
              migrate: (database) {
                createStoryGenerationLedgerTables(database);
                throw StateError('injected V9 failure');
              },
            ),
          ],
        );

        expect(() => manager.ensureSchema(db), throwsStateError);
        expect(db.select('PRAGMA user_version').single['user_version'], 8);
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'story_generation_runs'",
          ),
          isEmpty,
        );
      },
    );

    test(
      'runtime ensure additively installs continuity authority on an existing schema',
      () {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        DatabaseSchemaManager(
          migrations: authoringSchemaMigrations,
        ).ensureSchema(db);
        final version = db.select('PRAGMA user_version').single['user_version'];
        db.execute('DROP TABLE story_generation_committed_continuity');
        db.execute('''
          CREATE TABLE story_generation_committed_continuity (
            receipt_id TEXT PRIMARY KEY,
            run_id TEXT NOT NULL,
            candidate_revision INTEGER NOT NULL,
            project_id TEXT NOT NULL,
            chapter_id TEXT NOT NULL,
            scene_id TEXT NOT NULL,
            write_id TEXT NOT NULL,
            write_kind TEXT NOT NULL,
            state TEXT NOT NULL,
            payload_hash TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            final_prose_hash TEXT NOT NULL,
            pending_write_set_hash TEXT NOT NULL,
            committed_at_ms INTEGER NOT NULL
          )
        ''');

        final ledger = GenerationLedgerSqliteStore(db: db);
        ledger.ensureTables();
        ledger.ensureTables();

        expect(
          db.select(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' "
            "AND name = 'story_generation_committed_continuity'",
          ),
          hasLength(1),
        );
        final ordinal = db
            .select(
              "PRAGMA table_info('story_generation_committed_continuity')",
            )
            .singleWhere((row) => row['name'] == 'commit_ordinal');
        // Existing authority rows cannot be assigned a truthful order, so the
        // additive column remains nullable and reload rejects null ordinals.
        expect(ordinal['notnull'], 0);
        expect(
          db
              .select(
                "PRAGMA index_list('story_generation_committed_continuity')",
              )
              .map((row) => row['name']),
          contains('idx_generation_committed_continuity_commit_ordinal'),
        );
        expect(
          db.select('PRAGMA user_version').single['user_version'],
          version,
        );
      },
    );
  });

  group('V13 checkpoint prose-revision migration', () {
    test(
      'rebuilds V10 rows once and keeps N and N+1 checkpoint identities distinct',
      () {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        createStoryGenerationLedgerTables(db);
        db.execute('''
        CREATE TABLE story_generation_stage_checkpoints (
          run_id TEXT NOT NULL,
          ordinal INTEGER NOT NULL,
          stage_id TEXT NOT NULL,
          stage_attempt INTEGER NOT NULL,
          codec_version INTEGER NOT NULL,
          status TEXT NOT NULL,
          input_digest TEXT NOT NULL,
          artifact_digest TEXT NOT NULL,
          upstream_chain_digest TEXT NOT NULL,
          base_draft_digest TEXT NOT NULL,
          material_digest TEXT NOT NULL,
          prompt_digest TEXT NOT NULL,
          model_digest TEXT NOT NULL,
          artifact_type TEXT NOT NULL,
          artifact_json TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          completed_at_ms INTEGER,
          PRIMARY KEY (run_id, ordinal, stage_attempt)
        )
      ''');
        db.execute('''
        CREATE TABLE story_generation_stage_evidence (
          run_id TEXT NOT NULL,
          ordinal INTEGER NOT NULL,
          stage_attempt INTEGER NOT NULL,
          evidence_kind TEXT NOT NULL,
          evidence_digest TEXT NOT NULL,
          provenance_digest TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          PRIMARY KEY (run_id, ordinal, stage_attempt, evidence_kind),
          FOREIGN KEY (run_id, ordinal, stage_attempt)
            REFERENCES story_generation_stage_checkpoints(run_id, ordinal, stage_attempt)
            ON DELETE CASCADE
        )
      ''');
        final digest = 'a' * 64;
        db.execute('''INSERT INTO story_generation_runs (
             run_id, request_id, project_id, chapter_id, scene_id, scene_scope_id,
             status, phase, schema_version, created_at_ms, updated_at_ms
           ) VALUES ('run', 'request', 'project', 'chapter', 'scene', 'scope',
             'running', 'draft', 10, 1, 1)''');
        db.execute(
          '''INSERT INTO story_generation_stage_checkpoints VALUES (
          'run', 4, 'sceneDirector', 1, 1, 'completed', ?, ?, ?, ?, ?, ?, ?,
          'director', '{}', 1, 1
        )''',
          [digest, digest, digest, digest, digest, digest, digest],
        );
        db.execute(
          '''INSERT INTO story_generation_stage_evidence VALUES
          ('run', 4, 1, 'artifact', ?, ?, 1)''',
          [digest, digest],
        );

        migrateStoryGenerationCheckpointRevisionIsolation(db);
        // The helper also runs from non-migration construction paths, so it
        // must be an idempotent no-op after the atomic rebuild completed.
        migrateStoryGenerationCheckpointRevisionIsolation(db);

        expect(
          db.select('''SELECT prose_revision, ordinal, stage_attempt
                     FROM story_generation_stage_checkpoints'''),
          [
            {'prose_revision': 0, 'ordinal': 4, 'stage_attempt': 1},
          ],
        );
        expect(
          db.select(
            '''SELECT prose_revision FROM story_generation_stage_evidence''',
          ),
          [
            {'prose_revision': 0},
          ],
        );
        db.execute('''
        INSERT INTO story_generation_working_prose_revisions (
          run_id, prose_revision, prose_hash, prose_text, source_kind, created_at_ms
        ) VALUES ('run', 1, 'sha256:test-revision-1', '改稿', 'authorEdit', 2)
      ''');
        db.execute(
          '''INSERT INTO story_generation_stage_checkpoints (
             run_id, prose_revision, ordinal, stage_id, stage_attempt,
             codec_version, status, input_digest, artifact_digest,
             upstream_chain_digest, base_draft_digest, material_digest,
             prompt_digest, model_digest, artifact_type, artifact_json,
             created_at_ms, completed_at_ms
           ) VALUES ('run', 1, 4, 'sceneDirector', 1, 1, 'completed',
             ?, ?, ?, ?, ?, ?, ?, 'director', '{}', 2, 2)''',
          [digest, digest, digest, digest, digest, digest, digest],
        );
        expect(
          db
              .select(
                '''SELECT prose_revision FROM story_generation_stage_checkpoints
                     WHERE run_id = 'run' AND ordinal = 4
                     ORDER BY prose_revision''',
              )
              .map((row) => row['prose_revision']),
          [0, 1],
        );
        expect(
          () => db.execute(
            '''INSERT INTO story_generation_stage_checkpoints (
               run_id, prose_revision, ordinal, stage_id, stage_attempt,
               codec_version, status, input_digest, artifact_digest,
               upstream_chain_digest, base_draft_digest, material_digest,
               prompt_digest, model_digest, artifact_type, artifact_json,
               created_at_ms, completed_at_ms
             ) VALUES ('run', 99, 5, 'editorial', 1, 1, 'completed',
               ?, ?, ?, ?, ?, ?, ?, 'editorial', '{}', 3, 3)''',
            [digest, digest, digest, digest, digest, digest, digest],
          ),
          throwsA(isA<SqliteException>()),
        );
        db.execute('''DELETE FROM story_generation_working_prose_revisions
                    WHERE run_id = 'run' AND prose_revision = 1''');
        expect(
          db.select('''SELECT * FROM story_generation_stage_checkpoints
                     WHERE run_id = 'run' AND prose_revision = 1'''),
          isEmpty,
        );
      },
    );
  });
}
