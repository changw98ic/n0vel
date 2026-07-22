import 'dart:io';

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
      'keeps durable run identity immutable while lifecycle fields advance',
      () {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA foreign_keys = ON');
        DatabaseSchemaManager(
          migrations: authoringSchemaMigrations,
        ).ensureSchema(db);
        for (final attack in const <List<String>>[
          <String>['project-1', 'scene-1', 'project-1::scene-2'],
          <String>['a::b', 'c', 'a::b::c'],
          <String>['a', 'b::c', 'a::b::c'],
          <String>['a:', 'b', 'a:::b'],
          <String>['a', ':b', 'a:::b'],
        ]) {
          expect(
            () => db.execute(
              '''
              INSERT INTO story_generation_runs (
                run_id, request_id, project_id, chapter_id, scene_id,
                scene_scope_id, status, phase, schema_version,
                created_at_ms, updated_at_ms
              ) VALUES (?, ?, ?, 'chapter-1', ?, ?, 'running', 'planning',
                2, 1, 1)
              ''',
              <Object?>[
                'run-attack-${attack[0]}-${attack[1]}',
                'request-attack-${attack[0]}-${attack[1]}',
                attack[0],
                attack[1],
                attack[2],
              ],
            ),
            throwsA(isA<SqliteException>()),
          );
        }
        expect(db.select('SELECT * FROM story_generation_runs'), isEmpty);
        db.execute('''
          INSERT INTO story_generation_runs (
            run_id, request_id, project_id, chapter_id, scene_id,
            scene_scope_id, status, phase, schema_version,
            created_at_ms, updated_at_ms
          ) VALUES (
            'run-immutable', 'request-immutable', 'project-1', 'chapter-1',
            'scene-1', 'project-1::scene-1', 'running', 'planning', 2, 1, 1
          )
        ''');

        const mutations = <String, Object?>{
          'run_id': 'run-relabeled',
          'request_id': 'request-relabeled',
          'project_id': 'project-2',
          'chapter_id': 'chapter-2',
          'scene_id': 'scene-2',
          'scene_scope_id': 'project-1::scene-2',
          'schema_version': 3,
          'created_at_ms': 2,
        };
        for (final entry in mutations.entries) {
          expect(
            () => db.execute(
              'UPDATE story_generation_runs SET ${entry.key} = ? '
              "WHERE run_id = 'run-immutable'",
              <Object?>[entry.value],
            ),
            throwsA(isA<SqliteException>()),
            reason: '${entry.key} must remain bound to the sealed run',
          );
        }

        db.execute('''
          UPDATE story_generation_runs
          SET status = 'candidateReady', phase = 'qualityGate',
              current_prose_revision = 1, updated_at_ms = 2
          WHERE run_id = 'run-immutable'
        ''');
        final row = db.select('''
          SELECT run_id, request_id, project_id, chapter_id, scene_id,
                 scene_scope_id, schema_version, created_at_ms,
                 status, phase, current_prose_revision, updated_at_ms
          FROM story_generation_runs
          WHERE run_id = 'run-immutable'
        ''').single;
        expect(row, <String, Object?>{
          'run_id': 'run-immutable',
          'request_id': 'request-immutable',
          'project_id': 'project-1',
          'chapter_id': 'chapter-1',
          'scene_id': 'scene-1',
          'scene_scope_id': 'project-1::scene-1',
          'schema_version': 2,
          'created_at_ms': 1,
          'status': 'candidateReady',
          'phase': 'qualityGate',
          'current_prose_revision': 1,
          'updated_at_ms': 2,
        });
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
           ) VALUES ('run', 'request', 'project', 'chapter', 'scene', 'project::scene',
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

  test(
    'V29 repairs legacy admission guards and rejects incomplete V2 writes',
    () {
      final directory = Directory.systemTemp.createTempSync(
        'novel-writer-v28-legacy-writer-',
      );
      final databasePath = '${directory.path}/authoring.sqlite';
      final oldWriter = sqlite3.open(databasePath);
      final upgrader = sqlite3.open(databasePath);
      final fresh = sqlite3.openInMemory();
      addTearDown(() {
        oldWriter.dispose();
        upgrader.dispose();
        fresh.dispose();
        directory.deleteSync(recursive: true);
      });

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations.sublist(0, 27),
      ).ensureSchema(oldWriter);
      // The current table factory is shared by historical test migrations, so
      // it already exposes additive V28 columns while user_version is 27.
      // Remove only the current admission trigger to seed the old durable V1
      // row, then verify V28 restores the guard without changing that row.
      oldWriter.execute(
        'DROP TRIGGER IF EXISTS prevent_new_legacy_generation_proof_insert',
      );
      oldWriter.execute(_oldProofInsertSql);
      final latest = DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      );
      latest.ensureSchema(upgrader);
      expect(
        upgrader.select(
          '''SELECT proof_identity_version
                           FROM story_generation_candidate_proofs
                           WHERE run_id = 'old-connection-run' ''',
        ).single['proof_identity_version'],
        'candidate-proof-v1',
      );
      // A repeated migration must leave exactly the same one guard in place.
      latest.ensureSchema(upgrader);
      expect(
        upgrader.select(
          '''SELECT name FROM sqlite_master
                       WHERE type = 'trigger'
                         AND name = 'prevent_new_legacy_generation_proof_insert' ''',
        ).length,
        1,
      );

      // A connection opened by the V28 process may continue writing during a
      // rolling handover. Its canonical INSERT remains compatible, while the
      // newly installed database guard rejects the old malformed shape.
      oldWriter.execute('''
        INSERT INTO story_generation_runs (
          run_id, request_id, project_id, chapter_id, scene_id, scene_scope_id,
          status, phase, schema_version, created_at_ms, updated_at_ms
        ) VALUES (
          'old-writer-valid-run', 'old-writer-valid-request', 'project',
          'chapter', 'scene', 'project::scene', 'running', 'planning', 9, 1, 1
        )
      ''');
      expect(
        () => oldWriter.execute('''
          INSERT INTO story_generation_runs (
            run_id, request_id, project_id, chapter_id, scene_id,
            scene_scope_id, status, phase, schema_version,
            created_at_ms, updated_at_ms
          ) VALUES (
            'old-writer-bad-run', 'old-writer-bad-request', 'project',
            'chapter', 'scene-a', 'project::scene-b', 'running', 'planning',
            9, 1, 1
          )
        '''),
        throwsA(isA<SqliteException>()),
      );

      expect(
        () => oldWriter.execute(
          _oldProofInsertSql.replaceFirst(
            'old-connection-run',
            'post-upgrade-old-writer',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(fresh);
      expect(
        () => fresh.execute(_oldProofInsertSql),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => fresh.execute(_incompleteSealedV2ProofInsertSql),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => fresh.execute(_malformedSealedV2ProofInsertSql),
        throwsA(isA<SqliteException>()),
      );
    },
  );

  test('V29 rebuilds the weak admission guard left by an early V28 build', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations.sublist(0, 28),
    ).ensureSchema(db);
    db.execute(
      'DROP TRIGGER IF EXISTS prevent_new_legacy_generation_proof_insert',
    );
    db.execute('''
      CREATE TRIGGER prevent_new_legacy_generation_proof_insert
      BEFORE INSERT ON story_generation_candidate_proofs
      WHEN NEW.proof_identity_version = 'candidate-proof-v1'
      BEGIN SELECT RAISE(ABORT, 'weak V28 guard'); END
    ''');

    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);

    expect(db.select('PRAGMA user_version').single['user_version'], 29);
    final guardSql =
        db.select(
              '''SELECT sql FROM sqlite_master
                   WHERE type = 'trigger'
                     AND name = 'prevent_new_legacy_generation_proof_insert' ''',
            ).single['sql']
            as String;
    expect(
      guardSql,
      contains("NEW.proof_identity_version <> 'candidate-proof-v2'"),
    );
    expect(
      guardSql,
      contains("NEW.generation_evidence_receipt_hash NOT GLOB 'sha256:*'"),
    );
    expect(
      db.select('''SELECT name FROM sqlite_master
           WHERE type = 'trigger'
             AND name = 'prevent_generation_run_identity_update' '''),
      hasLength(1),
    );
    expect(
      db.select('''SELECT name FROM sqlite_master
           WHERE type = 'trigger'
             AND name = 'prevent_noncanonical_generation_run_insert' '''),
      hasLength(1),
    );
  });

  test('V29 rejects boundary-colon collisions and rolls V28 back intact', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations.sublist(0, 28),
    ).ensureSchema(db);
    db.execute(
      'DROP TRIGGER IF EXISTS prevent_noncanonical_generation_run_insert',
    );
    // The current table factory contains the fresh-schema CHECK even while
    // constructing a historical V28 fixture. Ignore it only long enough to
    // represent a row written by an actual pre-V29 database.
    db.execute('PRAGMA ignore_check_constraints = ON');
    db.execute('''
      INSERT INTO story_generation_runs (
        run_id, request_id, project_id, chapter_id, scene_id, scene_scope_id,
        status, phase, schema_version, created_at_ms, updated_at_ms
      ) VALUES
        ('dirty-project-colon', 'dirty-project-colon-request', 'a:',
         'chapter-1', 'b', 'a:::b', 'running', 'planning', 9, 1, 1),
        ('dirty-scene-colon', 'dirty-scene-colon-request', 'a',
         'chapter-1', ':b', 'a:::b', 'running', 'planning', 9, 1, 1)
    ''');
    db.execute('PRAGMA ignore_check_constraints = OFF');

    final latest = DatabaseSchemaManager(migrations: authoringSchemaMigrations);
    expect(() => latest.ensureSchema(db), throwsStateError);
    expect(db.select('PRAGMA user_version').single['user_version'], 28);
    expect(
      db.select('''SELECT run_id, project_id, scene_id, scene_scope_id
           FROM story_generation_runs ORDER BY run_id'''),
      <Map<String, Object?>>[
        <String, Object?>{
          'run_id': 'dirty-project-colon',
          'project_id': 'a:',
          'scene_id': 'b',
          'scene_scope_id': 'a:::b',
        },
        <String, Object?>{
          'run_id': 'dirty-scene-colon',
          'project_id': 'a',
          'scene_id': ':b',
          'scene_scope_id': 'a:::b',
        },
      ],
    );
    expect(
      db.select('''SELECT name FROM sqlite_master
           WHERE type = 'trigger'
             AND name = 'prevent_noncanonical_generation_run_insert' '''),
      isEmpty,
    );

    // Explicit operator repair permits a clean retry; migration itself never
    // guesses or rewrites the author-draft address.
    db.execute('DROP TRIGGER IF EXISTS prevent_generation_run_identity_update');
    db.execute('''
      UPDATE story_generation_runs
      SET project_id = 'a-project', scene_scope_id = 'a-project::b'
      WHERE run_id = 'dirty-project-colon'
    ''');
    db.execute('''
      UPDATE story_generation_runs
      SET scene_id = 'b-scene', scene_scope_id = 'a::b-scene'
      WHERE run_id = 'dirty-scene-colon'
    ''');
    createStoryGenerationRunIdentityWriteGuards(db);
    latest.ensureSchema(db);
    expect(db.select('PRAGMA user_version').single['user_version'], 29);
  });

  test('V29 admission-guard repair rolls back with a failed migration', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations.sublist(0, 28),
    ).ensureSchema(db);
    db.execute(
      'DROP TRIGGER IF EXISTS prevent_new_legacy_generation_proof_insert',
    );
    db.execute('DROP TRIGGER IF EXISTS prevent_generation_run_identity_update');
    db.execute(
      'DROP TRIGGER IF EXISTS prevent_noncanonical_generation_run_insert',
    );

    final failingV29 = <SchemaMigration>[
      ...authoringSchemaMigrations.sublist(0, 28),
      SchemaMigration(
        version: 29,
        description: 'fault after V29 legacy-write guard',
        migrate: (database) {
          createCandidateProofV2WriteGuards(database);
          createStoryGenerationRunIdentityWriteGuards(database);
          throw StateError('injected V29 failure');
        },
      ),
    ];

    expect(
      () => DatabaseSchemaManager(migrations: failingV29).ensureSchema(db),
      throwsStateError,
    );
    expect(db.select('PRAGMA user_version').single['user_version'], 28);
    expect(
      db.select(
        '''SELECT name FROM sqlite_master
                   WHERE type = 'trigger'
                     AND name = 'prevent_new_legacy_generation_proof_insert' ''',
      ),
      isEmpty,
    );
    expect(
      db.select('''SELECT name FROM sqlite_master
           WHERE type = 'trigger'
             AND name = 'prevent_generation_run_identity_update' '''),
      isEmpty,
    );
    expect(
      db.select('''SELECT name FROM sqlite_master
           WHERE type = 'trigger'
             AND name = 'prevent_noncanonical_generation_run_insert' '''),
      isEmpty,
    );
  });
}

const String _oldProofInsertSql = '''
  INSERT INTO story_generation_candidate_proofs (
    run_id, candidate_revision, project_id, chapter_id, scene_id,
    source_prose_revision, candidate_hash, final_prose_hash,
    deterministic_gate_evidence_hash, final_council_evidence_hash,
    quality_evidence_hash, pending_write_set_hash, material_digest,
    input_digest, created_at_ms
  ) VALUES (
    'old-connection-run', 0, 'project', 'chapter', 'scene', 0,
    'candidate', 'prose', 'gate', 'council', 'quality', 'writes',
    'material', 'input', 1
  )
''';

const String _incompleteSealedV2ProofInsertSql = '''
  INSERT INTO story_generation_candidate_proofs (
    run_id, candidate_revision, project_id, chapter_id, scene_id,
    source_prose_revision, candidate_hash, final_prose_hash,
    deterministic_gate_evidence_hash, final_council_evidence_hash,
    quality_evidence_hash, pending_write_set_hash, material_digest,
    input_digest, proof_identity_version, prepared_brief_digest,
    effective_brief_digest, generation_evidence_mode, created_at_ms
  ) VALUES (
    'incomplete-sealed-run', 0, 'project', 'chapter', 'scene', 0,
    'candidate', 'prose', 'gate', 'council', 'quality', 'writes',
    'material', 'input', 'candidate-proof-v2', 'sha256:brief',
    'sha256:brief', 'sealed-no-redraw-v1', 1
  )
''';

const String _malformedSealedV2ProofInsertSql = '''
  INSERT INTO story_generation_candidate_proofs (
    run_id, candidate_revision, project_id, chapter_id, scene_id,
    source_prose_revision, candidate_hash, final_prose_hash,
    deterministic_gate_evidence_hash, final_council_evidence_hash,
    quality_evidence_hash, pending_write_set_hash, material_digest,
    input_digest, proof_identity_version, prepared_brief_digest,
    effective_brief_digest, generation_evidence_mode,
    generation_evidence_receipt_hash, attempt_evidence_envelope_digest,
    generation_fingerprint_set_digest, generation_evidence_receipt_json,
    created_at_ms
  ) VALUES (
    'malformed-sealed-run', 0, 'project', 'chapter', 'scene', 0,
    'candidate', 'prose', 'gate', 'council', 'quality', 'writes',
    'material', 'input', 'candidate-proof-v2', 'sha256:brief',
    'sha256:brief', 'sealed-no-redraw-v1', 'not-a-sha256',
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    '{}', 1
  )
''';
