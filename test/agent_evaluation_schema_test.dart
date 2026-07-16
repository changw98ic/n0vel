import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
  });

  tearDown(() => db.dispose());

  test('V15 creates the complete agent evaluation ledger', () {
    final tables = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'] as String)
        .toSet();

    expect(
      tables,
      containsAll(<String>{
        'prompt_releases',
        'prompt_release_lifecycle_events',
        'generation_bundles',
        'generation_bundle_releases',
        'evaluation_bundles',
        'eval_scenario_sets',
        'eval_scenarios',
        'eval_experiments',
        'eval_cells',
        'eval_experiment_cells',
        'eval_executions',
        'eval_execution_cells',
        'eval_trial_slots',
        'eval_trial_attempts',
        'eval_observations',
        'eval_scorecards',
        'prompt_channel_heads',
        'prompt_release_decisions',
      }),
    );
    expect(
      db.select('PRAGMA user_version').single['user_version'],
      authoringSchemaMigrations.last.version,
    );
  });

  test('immutable release and manifest rows reject rewrites and deletes', () {
    _seedReleaseGraph(db);

    expect(
      () => db.execute(
        "UPDATE prompt_releases SET change_note = 'rewritten' "
        "WHERE release_id = 'prompt-1'",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "DELETE FROM eval_experiments WHERE experiment_id = 'experiment-1'",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "UPDATE generation_bundles SET releases_json = '[]' "
        'WHERE bundle_hash = ?',
        [_hash('b')],
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('canonical cells and logical trial slots cannot be duplicated', () {
    _seedExecutionGraph(db);

    expect(
      () => db.execute(
        '''INSERT INTO eval_cells (
             cell_id, generation_bundle_hash, sut_model_route_hash,
             scenario_release_hash, decoding_config_hash, created_at_ms
           ) VALUES (?, ?, ?, ?, ?, 2)''',
        [_hash('x'), _hash('b'), _hash('m'), _hash('s'), _hash('d')],
      ),
      throwsA(isA<SqliteException>()),
    );

    _insertSlot(db, slotId: 'slot-1', trialNo: 1);
    expect(
      () => _insertSlot(db, slotId: 'replacement-sample', trialNo: 1),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => _insertSlot(
        db,
        slotId: 'missing-cell',
        trialNo: 2,
        cellId: _hash('z'),
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        '''INSERT INTO eval_trial_slots (
             trial_slot_id, execution_id, cell_id, trial_no, status,
             lease_epoch, created_at_ms, updated_at_ms
           ) VALUES ('invalid-seal', 'execution-1', ?, 2, 'sealed', 1, 1, 1)''',
        [_hash('c')],
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('observations are append-only and conflict on their logical key', () {
    _seedExecutionGraph(db);
    _insertRunningSlotAndAttempt(db);
    _insertObservation(
      db,
      observationId: 'observation-1',
      evidenceHash: _hash('v'),
    );

    expect(
      () => _insertObservation(
        db,
        observationId: 'observation-replacement',
        evidenceHash: _hash('w'),
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "UPDATE eval_observations SET value_json = '{\"score\":100}' "
        "WHERE observation_id = 'observation-1'",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "DELETE FROM eval_observations WHERE observation_id = 'observation-1'",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        '''INSERT INTO eval_observations (
             observation_id, trial_slot_id, attempt_no, sequence_no, stage_id,
             kind, item_key, value_json, evidence_hash,
             evaluation_bundle_hash, lease_epoch, lease_owner, created_at_ms
           ) VALUES ('orphan-observation', 'unknown-slot', 1, 0, 'quality',
             'score', 'singleton', '{}', ?, ?, 1, 'worker-1', 1)''',
        [_hash('o'), _hash('e')],
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('promotion history is append-only and channel epochs are unique', () {
    _seedExecutionGraph(db);
    _insertRunningSlotAndAttempt(db);
    _insertObservation(
      db,
      observationId: 'observation-1',
      evidenceHash: _hash('v'),
    );
    db.execute(
      '''INSERT INTO eval_scorecards (
           scorecard_hash, execution_id, scope, scope_key, aggregate_json,
           input_set_hash, expected_set_hash, aggregator_release_hash,
           created_at_ms
         ) VALUES (?, 'execution-1', 'execution', 'execution-1', '{}', ?, ?, ?, 2)''',
      [_hash('k'), _hash('i'), _hash('t'), _hash('a')],
    );
    db.execute(
      '''INSERT INTO generation_bundles (
           bundle_hash, bundle_id, releases_json, created_at_ms
         ) VALUES (?, 'challenger', '[]', 2)''',
      [_hash('n')],
    );
    db.execute(
      '''INSERT INTO prompt_channel_heads (channel, bundle_hash, epoch, updated_at_ms)
         VALUES ('stable', ?, 0, 1)''',
      [_hash('b')],
    );
    db.execute(
      '''INSERT INTO prompt_release_decisions (
           decision_id, channel, action, from_bundle_hash, to_bundle_hash,
           from_epoch, to_epoch, experiment_id, scorecard_hash, approver,
           created_at_ms
         ) VALUES ('decision-1', 'stable', 'promote', ?, ?, 0, 1,
           'experiment-1', ?, 'release-bot', 3)''',
      [_hash('b'), _hash('n'), _hash('k')],
    );

    expect(
      () => db.execute(
        '''INSERT INTO prompt_release_decisions (
             decision_id, channel, action, from_bundle_hash, to_bundle_hash,
             from_epoch, to_epoch, experiment_id, scorecard_hash, approver,
             created_at_ms
           ) VALUES ('decision-replay', 'stable', 'promote', ?, ?, 0, 1,
             'experiment-1', ?, 'release-bot', 4)''',
        [_hash('b'), _hash('n'), _hash('k')],
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "DELETE FROM prompt_release_decisions WHERE decision_id = 'decision-1'",
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}

String _hash(String character) => List<String>.filled(64, character).join();

void _seedReleaseGraph(Database db) {
  db.execute(
    '''INSERT INTO prompt_releases (
         release_id, template_id, semantic_version, language, content_hash,
         system_template, user_template, variables_schema_json,
         output_schema_json, renderer_release, parser_release,
         repair_policy_json, variables_schema_hash, output_schema_hash,
         owner, change_note, created_at_ms
       ) VALUES ('prompt-1', 'scene.prose', '1.0.0', 'zh-CN', ?,
         'system', 'user', '{}', '{}', 'renderer-v1', 'parser-v1', '{}',
         ?, ?, 'story-team', 'initial', 1)''',
    [_hash('p'), _hash('v'), _hash('o')],
  );
  db.execute(
    '''INSERT INTO generation_bundles (
         bundle_hash, bundle_id, releases_json, created_at_ms
       ) VALUES (?, 'champion', '["prompt-1"]', 1)''',
    [_hash('b')],
  );
  db.execute(
    '''INSERT INTO generation_bundle_releases (
         bundle_hash, stage_id, call_site_id, variant_id, prompt_release_id
       ) VALUES (?, 'editorial', 'scene-prose', 'default', 'prompt-1')''',
    [_hash('b')],
  );
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'evaluator-v1', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    [_hash('e'), _hash('r'), _hash('a'), _hash('f')],
  );
  db.execute(
    '''INSERT INTO eval_scenario_sets (
         scenario_set_release_hash, set_id, version, manifest_hash, created_at_ms
       ) VALUES (?, 'regression', '1.0.0', ?, 1)''',
    [_hash('q'), _hash('u')],
  );
  db.execute(
    '''INSERT INTO eval_scenarios (
         scenario_release_hash, scenario_set_release_hash, scenario_id, version,
         fixture_hash, isolation_mode, verifier_release_refs_json,
         rubric_release_ref, expected_terminal_state,
         required_failure_codes_json, allowed_failure_codes_json,
         forbidden_failure_codes_json, outcome_comparator_release_ref,
         forbidden_side_effects_json, accept_expected, scenario_json,
         created_at_ms
       ) VALUES (?, ?, 'normal-scene', '1.0.0', ?, 'independent', '[]',
         'rubric-v1', 'accepted', '[]', '[]', '[]', 'comparator-v1', '[]', 1,
         '{}', 1)''',
    [_hash('s'), _hash('q'), _hash('g')],
  );
  db.execute(
    '''INSERT INTO eval_experiments (
         experiment_id, manifest_json, manifest_hash, scenario_set_release_hash,
         evaluation_bundle_hash, expected_cell_set_hash,
         expected_slot_set_hash, trials_per_cell, created_at_ms
       ) VALUES ('experiment-1', '{}', ?, ?, ?, ?, ?, 3, 1)''',
    [_hash('h'), _hash('q'), _hash('e'), _hash('j'), _hash('l')],
  );
}

void _seedExecutionGraph(Database db) {
  _seedReleaseGraph(db);
  db.execute(
    '''INSERT INTO eval_cells (
         cell_id, generation_bundle_hash, sut_model_route_hash,
         scenario_release_hash, decoding_config_hash, created_at_ms
       ) VALUES (?, ?, ?, ?, ?, 1)''',
    [_hash('c'), _hash('b'), _hash('m'), _hash('s'), _hash('d')],
  );
  db.execute(
    '''INSERT INTO eval_experiment_cells (experiment_id, cell_id, ordinal)
       VALUES ('experiment-1', ?, 0)''',
    [_hash('c')],
  );
  db.execute(
    '''INSERT INTO eval_executions (
         execution_id, experiment_id, status, expected_cell_set_hash,
         expected_slot_set_hash, created_at_ms
       ) VALUES ('execution-1', 'experiment-1', 'running', ?, ?, 1)''',
    [_hash('j'), _hash('l')],
  );
  db.execute(
    '''INSERT INTO eval_execution_cells (execution_id, cell_id, ordinal)
       VALUES ('execution-1', ?, 0)''',
    [_hash('c')],
  );
}

void _insertSlot(
  Database db, {
  required String slotId,
  required int trialNo,
  String? cellId,
}) {
  db.execute(
    '''INSERT INTO eval_trial_slots (
         trial_slot_id, execution_id, cell_id, trial_no, status,
         lease_epoch, created_at_ms, updated_at_ms
       ) VALUES (?, 'execution-1', ?, ?, 'queued', 0, 1, 1)''',
    [slotId, cellId ?? _hash('c'), trialNo],
  );
}

void _insertRunningSlotAndAttempt(Database db) {
  db.execute(
    '''INSERT INTO eval_trial_slots (
         trial_slot_id, execution_id, cell_id, trial_no, status, lease_epoch,
         lease_owner, lease_expires_at_ms, created_at_ms, updated_at_ms
       ) VALUES ('slot-1', 'execution-1', ?, 1, 'running', 1,
         'worker-1', 1000, 1, 1)''',
    [_hash('c')],
  );
  db.execute('''INSERT INTO eval_trial_attempts (
         trial_slot_id, attempt_no, run_id, kind, status, lease_epoch,
         lease_owner, started_at_ms
       ) VALUES ('slot-1', 1, 'run-1', 'content', 'started', 1,
         'worker-1', 1)''');
}

void _insertObservation(
  Database db, {
  required String observationId,
  required String evidenceHash,
}) {
  db.execute(
    '''INSERT INTO eval_observations (
         observation_id, trial_slot_id, attempt_no, sequence_no, stage_id,
         kind, item_key, value_json, evidence_hash,
         evaluation_bundle_hash, prose_hash, lease_epoch, lease_owner,
         created_at_ms
       ) VALUES (?, 'slot-1', 1, 0, 'quality', 'score', 'singleton',
         '{"score":96}', ?, ?, ?, 1, 'worker-1', 1)''',
    [observationId, evidenceHash, _hash('e'), _hash('y')],
  );
}
