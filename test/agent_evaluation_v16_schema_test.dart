import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/authoring_table_definitions.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';

void main() {
  test('V16 migration is additive and idempotent', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute('PRAGMA foreign_keys = ON');
    final manager = DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    );

    manager.ensureSchema(db);
    manager.ensureSchema(db);

    expect(
      db.select('PRAGMA user_version').single['user_version'],
      authoringSchemaMigrations.last.version,
    );
    final tables = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(
      tables,
      containsAll(<String>{
        'schema_compatibility_contracts',
        'story_generation_run_bundles',
        'eval_experiment_families',
        'eval_family_challengers',
        'eval_holdout_tokens',
        'eval_holdout_confirmations',
        'eval_release_gate_verdicts',
        'eval_holdout_accesses',
        'prompt_release_decision_authorizations',
        'eval_dispatch_plans',
        'eval_dispatch_entries',
        'eval_dispatch_events',
        'eval_production_authority_receipts',
        'eval_production_executor_results',
        'eval_production_prepared_results',
        'eval_price_table_releases',
        'eval_deterministic_quality_receipts',
        'eval_sandbox_generations',
        'eval_sandbox_recovery_checkpoints',
        'eval_sandbox_recovery_seals',
        'eval_trusted_holdout_attestations',
      }),
    );
    expect(
      db.select('SELECT * FROM schema_compatibility_contracts'),
      hasLength(12),
    );
    final latestContract = db
        .select(
          'SELECT * FROM schema_compatibility_contracts '
          'ORDER BY schema_version DESC LIMIT 1',
        )
        .single;
    expect(latestContract['schema_version'], 27);
    expect(latestContract['min_reader_version'], 27);
    expect(latestContract['min_writer_version'], 27);
  });

  test('V16 objects roll back atomically when migration fails', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    final manager = DatabaseSchemaManager(
      migrations: <SchemaMigration>[
        SchemaMigration(
          version: 16,
          description: 'failing V16 probe',
          migrate: (database) {
            createAgentEvaluationV16Tables(database);
            throw StateError('after V16');
          },
        ),
      ],
    );

    expect(() => manager.ensureSchema(db), throwsStateError);
    expect(db.select('PRAGMA user_version').single['user_version'], 0);
    expect(
      db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'schema_compatibility_contracts'",
      ),
      isEmpty,
    );
  });

  test('V25 additively upgrades V24 and keeps prepared evidence immutable', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations
          .where((migration) => migration.version <= 24)
          .toList(growable: false),
    ).ensureSchema(db);
    expect(db.select('PRAGMA user_version').single['user_version'], 24);

    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    expect(db.select('PRAGMA user_version').single['user_version'], 27);
    db.execute('''INSERT INTO story_generation_runs (
           run_id, request_id, project_id, chapter_id, scene_id,
           scene_scope_id, status, phase, schema_version,
           created_at_ms, updated_at_ms
         ) VALUES ('prepared-run', 'prepared-request', 'project', 'chapter',
           'scene', 'scope', 'candidateReady', 'finalization', 1, 1, 1)''');
    db.execute('''INSERT INTO story_generation_working_prose_revisions (
           run_id, prose_revision, prose_hash, prose_text, source_kind,
           created_at_ms
         ) VALUES ('prepared-run', 0, 'prose-hash', 'prose', 'test', 1)''');
    db.execute('''INSERT INTO story_generation_candidate_namespaces (
           run_id, candidate_revision, source_prose_revision, reserved_at_ms
         ) VALUES ('prepared-run', 0, 0, 1)''');
    db.execute(
      '''INSERT INTO story_generation_candidate_proofs (
           run_id, candidate_revision, project_id, chapter_id, scene_id,
           source_prose_revision, candidate_hash, final_prose_hash,
           deterministic_gate_evidence_hash, final_council_evidence_hash,
           quality_evidence_hash, pending_write_set_hash, material_digest,
           input_digest, created_at_ms
         ) VALUES ('prepared-run', 0, 'project', 'chapter', 'scene', 0, ?,
           'final-hash', 'gate-hash', 'council-hash', 'quality-hash',
           'write-hash', 'material-hash', 'input-hash', 1)''',
      <Object?>[List<String>.filled(64, 'b').join()],
    );
    db.execute(
      'UPDATE story_generation_runs SET current_candidate_revision = 0 '
      "WHERE run_id = 'prepared-run'",
    );
    expect(
      () => db.execute(
        '''INSERT INTO eval_production_prepared_results (
             run_id, execution_id, trial_slot_id, attempt_no,
             original_lease_epoch, original_lease_owner, cell_id,
             manifest_hash, candidate_revision, candidate_hash,
             prepared_json, prepared_hash,
             executor_release_hash, created_at_ms
           ) VALUES ('prepared-run', 'execution', 'slot', 1, 1, 'worker',
             'cell', ?, 0, ?, '{}', ?, ?, 1)''',
        <Object?>[
          List<String>.filled(64, 'a').join(),
          List<String>.filled(64, 'e').join(),
          List<String>.filled(64, 'c').join(),
          List<String>.filled(64, 'd').join(),
        ],
      ),
      throwsA(anything),
      reason: 'prepared evidence cannot name a different candidate hash',
    );
    db.execute(
      '''INSERT INTO eval_production_prepared_results (
           run_id, execution_id, trial_slot_id, attempt_no,
           original_lease_epoch, original_lease_owner, cell_id,
           manifest_hash, candidate_revision, candidate_hash,
           prepared_json, prepared_hash,
           executor_release_hash, created_at_ms
         ) VALUES ('prepared-run', 'execution', 'slot', 1, 1, 'worker',
           'cell', ?, 0, ?, '{}', ?, ?, 1)''',
      <Object?>[
        List<String>.filled(64, 'a').join(),
        List<String>.filled(64, 'b').join(),
        List<String>.filled(64, 'c').join(),
        List<String>.filled(64, 'd').join(),
      ],
    );
    expect(
      () => db.execute(
        "UPDATE eval_production_prepared_results SET prepared_json = '{\"x\":1}'",
      ),
      throwsA(anything),
    );
    expect(
      () => db.execute('DELETE FROM eval_production_prepared_results'),
      throwsA(anything),
    );
  });

  test('run bundle binding enforces both FKs and cannot be rewritten', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    db.execute(
      '''INSERT INTO generation_bundles (
           bundle_hash, bundle_id, releases_json, created_at_ms
         ) VALUES (?, 'bundle-1', '[]', 1)''',
      <Object?>[_digest('b')],
    );
    db.execute('''INSERT INTO story_generation_runs (
           run_id, request_id, project_id, chapter_id, scene_id,
           scene_scope_id, status, phase, schema_version,
           created_at_ms, updated_at_ms
         ) VALUES ('run-1', 'request-1', 'project-1', 'chapter-1', 'scene-1',
           'scope-1', 'queued', 'queued', 1, 1, 1)''');
    db.execute(
      '''INSERT INTO story_generation_run_bundles (run_id, bundle_hash, created_at_ms)
         VALUES ('run-1', ?, 1)''',
      <Object?>[_digest('b')],
    );

    expect(
      () => db.execute(
        'UPDATE story_generation_run_bundles SET bundle_hash = ?',
        <Object?>[_digest('a')],
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "DELETE FROM story_generation_run_bundles WHERE run_id = 'run-1'",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        '''INSERT INTO story_generation_run_bundles (run_id, bundle_hash, created_at_ms)
           VALUES ('unknown-run', ?, 1)''',
        <Object?>[_digest('b')],
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('V18 makes sealed slots, attempts, and evidence permanent', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    db.execute('PRAGMA foreign_keys = OFF');
    db.execute(
      '''INSERT INTO eval_trial_slots (
           trial_slot_id, execution_id, cell_id, trial_no, status, result,
           lease_epoch, lease_owner, lease_expires_at_ms,
           created_at_ms, updated_at_ms
         ) VALUES ('sealed-slot', 'execution-1', ?, 1, 'running', NULL,
           1, 'worker-1', 100, 1, 1)''',
      <Object?>[_digest('c')],
    );
    db.execute('''INSERT INTO eval_trial_attempts (
           trial_slot_id, attempt_no, run_id, kind, status, lease_epoch,
           lease_owner, started_at_ms, finished_at_ms
         ) VALUES ('sealed-slot', 1, 'run-1', 'content', 'completed',
           1, 'worker-1', 1, 2)''');
    db.execute(
      '''UPDATE eval_trial_slots SET status = 'sealed', result = 'pass',
           lease_owner = NULL, lease_expires_at_ms = NULL,
           sealed_evidence_hash = ?, updated_at_ms = 2, sealed_at_ms = 2
         WHERE trial_slot_id = 'sealed-slot' ''',
      <Object?>[_digest('e')],
    );

    expect(
      () => db.execute(
        "UPDATE eval_trial_slots SET result = 'fail' "
        "WHERE trial_slot_id = 'sealed-slot'",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "DELETE FROM eval_trial_slots WHERE trial_slot_id = 'sealed-slot'",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "UPDATE eval_trial_attempts SET status = 'failed' "
        "WHERE run_id = 'run-1'",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () =>
          db.execute("DELETE FROM eval_trial_attempts WHERE run_id = 'run-1'"),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute('''INSERT INTO eval_trial_attempts (
             trial_slot_id, attempt_no, run_id, kind, status, lease_epoch,
             lease_owner, started_at_ms, finished_at_ms
           ) VALUES ('sealed-slot', 2, 'late-run', 'transport', 'failed',
             1, 'late-worker', 3, 4)'''),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        '''INSERT INTO eval_observations (
             observation_id, trial_slot_id, attempt_no, sequence_no, stage_id,
             kind, item_key, value_json, evidence_hash,
             evaluation_bundle_hash, lease_epoch, lease_owner, created_at_ms
           ) VALUES ('late-observation', 'sealed-slot', 1, 0, 'late', 'write',
             'singleton', '{}', ?, ?, 1, 'late-worker', 4)''',
        <Object?>[_digest('1'), _digest('2')],
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}

String _digest(String value) => List<String>.filled(64, value).join();
