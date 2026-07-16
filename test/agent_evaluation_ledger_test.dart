import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';

void main() {
  late Database db;
  late AgentEvaluationLedger ledger;
  late AgentEvaluationCellDefinition cell;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    cell = AgentEvaluationCellDefinition(
      generationBundleHash: _digest('b'),
      sutModelRouteHash: _digest('a'),
      scenarioReleaseHash: _digest('c'),
      decodingConfigHash: _digest('d'),
    );
    _seedManifest(db, cell: cell, trialsPerCell: 1);
    ledger = AgentEvaluationLedger(db: db);
  });

  tearDown(() => db.dispose());

  test('creates and recovers exactly the frozen canonical execution set', () {
    final first = _createExecution(ledger, cell);
    final recovered = _createExecution(ledger, cell);

    expect(recovered.cellIds, first.cellIds);
    expect(recovered.trialSlotIds, first.trialSlotIds);
    expect(db.select('SELECT * FROM eval_trial_slots'), hasLength(1));

    db.execute(
      '''INSERT INTO eval_trial_slots (
           trial_slot_id, execution_id, cell_id, trial_no, status,
           lease_epoch, created_at_ms, updated_at_ms
         ) VALUES ('polluted-slot', 'execution-1', ?, 99, 'queued', 0, 2, 2)''',
      <Object?>[cell.cellId],
    );
    expect(
      () => _createExecution(ledger, cell),
      throwsA(isA<AgentEvaluationConflict>()),
    );
  });

  test('claim is idempotent and expired lease recovery increments epoch', () {
    _createExecution(ledger, cell);
    final oldLease = ledger.claimNextSlot(
      executionId: 'execution-1',
      owner: 'worker-old',
      nowMs: 10,
      leaseDurationMs: 10,
    )!;
    final duplicate = ledger.claimNextSlot(
      executionId: 'execution-1',
      owner: 'worker-old',
      nowMs: 11,
      leaseDurationMs: 10,
    )!;
    expect(duplicate.trialSlotId, oldLease.trialSlotId);
    expect(duplicate.epoch, 1);

    final replacement = ledger.claimNextSlot(
      executionId: 'execution-1',
      owner: 'worker-new',
      nowMs: 20,
      leaseDurationMs: 20,
    )!;
    expect(replacement.trialSlotId, oldLease.trialSlotId);
    expect(replacement.epoch, 2);
    expect(
      () => ledger.renewLease(lease: oldLease, nowMs: 21, leaseDurationMs: 10),
      throwsA(isA<AgentEvaluationLeaseLost>()),
    );
  });

  test(
    'stale worker cannot write attempt observation seal or candidate artifact',
    () {
      _createExecution(ledger, cell);
      final oldLease = _claim(ledger, 'worker-old', 1, 5);
      ledger.startAttempt(
        lease: oldLease,
        attemptNo: 1,
        runId: 'run-1',
        kind: 'content',
        startedAtMs: 2,
      );
      final newLease = _claim(ledger, 'worker-new', 6, 20);
      db.execute(
        'CREATE TABLE candidate_like_artifacts (id TEXT PRIMARY KEY, value TEXT)',
      );

      expect(
        () => ledger.startAttempt(
          lease: oldLease,
          attemptNo: 2,
          runId: 'late-run',
          kind: 'transport',
          startedAtMs: 7,
        ),
        throwsA(isA<AgentEvaluationLeaseLost>()),
      );
      expect(
        () => ledger.appendObservation(
          lease: oldLease,
          observation: _observation('late-observation', 7),
        ),
        throwsA(isA<AgentEvaluationLeaseLost>()),
      );
      expect(
        () => ledger.performFencedMutation<void>(
          lease: oldLease,
          nowMs: 7,
          mutation: (database) => database.execute(
            "INSERT INTO candidate_like_artifacts VALUES ('late', 'bad')",
          ),
        ),
        throwsA(isA<AgentEvaluationLeaseLost>()),
      );
      expect(
        () => ledger.sealSlot(
          lease: oldLease,
          result: 'pass',
          expectedEvidence: <AgentEvaluationEvidenceKey>[
            _observation('unused', 7).evidenceKey,
          ],
          sealedAtMs: 7,
        ),
        throwsA(isA<AgentEvaluationLeaseLost>()),
      );
      expect(db.select('SELECT * FROM candidate_like_artifacts'), isEmpty);

      final adopted = ledger.startAttempt(
        lease: newLease,
        attemptNo: 1,
        runId: 'run-1',
        kind: 'content',
        startedAtMs: 7,
      );
      expect(adopted.leaseEpoch, 2);
      ledger.performFencedMutation<void>(
        lease: newLease,
        nowMs: 7,
        mutation: (database) => database.execute(
          "INSERT INTO candidate_like_artifacts VALUES ('current', 'ok')",
        ),
      );
      expect(db.select('SELECT * FROM candidate_like_artifacts'), hasLength(1));
    },
  );

  test('observation replay is idempotent but divergent evidence conflicts', () {
    _createExecution(ledger, cell);
    final lease = _claim(ledger, 'worker-1', 1, 50);
    ledger.startAttempt(
      lease: lease,
      attemptNo: 1,
      runId: 'run-1',
      kind: 'content',
      startedAtMs: 2,
    );
    final input = _observation('observation-1', 3);
    final first = ledger.appendObservation(lease: lease, observation: input);
    final replay = ledger.appendObservation(
      lease: lease,
      observation: AgentEvaluationObservationInput(
        observationId: 'replacement-id',
        attemptNo: input.attemptNo,
        sequenceNo: input.sequenceNo,
        stageId: input.stageId,
        kind: input.kind,
        itemKey: input.itemKey,
        valueJson: input.valueJson,
        evidenceHash: input.evidenceHash,
        evaluationBundleHash: input.evaluationBundleHash,
        proseHash: input.proseHash,
        createdAtMs: 4,
      ),
    );
    expect(replay.observationId, first.observationId);
    expect(db.select('SELECT * FROM eval_observations'), hasLength(1));

    expect(
      () => ledger.appendObservation(
        lease: lease,
        observation: AgentEvaluationObservationInput(
          observationId: 'divergent',
          attemptNo: 1,
          sequenceNo: 0,
          stageId: input.stageId,
          kind: input.kind,
          itemKey: 'singleton',
          valueJson: AgentEvaluationHashes.canonicalJson(<String, Object?>{
            'schemaVersion': 'eval-attempt-usage-v1',
            'promptTokens': 2,
            'completionTokens': 1,
            'costMicrousd': 0,
          }),
          evidenceHash: _digest('f'),
          evaluationBundleHash: _digest('e'),
          createdAtMs: 4,
        ),
      ),
      throwsA(isA<AgentEvaluationConflict>()),
    );
  });

  test('unknown observation type is rejected before SQLite insert', () {
    final lease = _startedLease(ledger);
    final invalid = _copyObservation(
      _observation('unknown-observation', 3),
      stageId: 'provider',
      kind: 'raw-response',
    );

    expect(
      () => ledger.appendObservation(lease: lease, observation: invalid),
      throwsA(isA<AgentEvaluationLedgerException>()),
    );
    expect(db.select('SELECT * FROM eval_observations'), isEmpty);
  });

  test('extra observation field is rejected before SQLite insert', () {
    final lease = _startedLease(ledger);
    final invalid = _copyObservation(
      _observation('extra-field-observation', 3),
      valueJson:
          '{"schemaVersion":"eval-attempt-usage-v1",'
          '"promptTokens":1,"completionTokens":1,"costMicrousd":0,'
          '"rawResponse":"tainted"}',
    );

    expect(
      () => ledger.appendObservation(lease: lease, observation: invalid),
      throwsA(isA<AgentEvaluationLedgerException>()),
    );
    expect(db.select('SELECT * FROM eval_observations'), isEmpty);
  });

  test('oversized observation is rejected before SQLite insert', () {
    final lease = _startedLease(ledger);
    final invalid = _copyObservation(
      _observation('oversized-observation', 3),
      stageId: 'failure',
      kind: 'taxonomy',
      valueJson: '{"labels":["${'x' * 65536}"],"primary":"provider.failure"}',
    );

    expect(
      () => ledger.appendObservation(lease: lease, observation: invalid),
      throwsA(isA<AgentEvaluationLedgerException>()),
    );
    expect(db.select('SELECT * FROM eval_observations'), isEmpty);
  });

  test('secret-bearing observation is rejected before SQLite insert', () {
    final lease = _startedLease(ledger);
    final invalid = _copyObservation(
      _observation('secret-observation', 3),
      valueJson:
          '{"authorization":"Bearer private-token",'
          '"completionTokens":1,"costMicrousd":0,"promptTokens":1,'
          '"schemaVersion":"eval-attempt-usage-v1"}',
    );

    expect(
      () => ledger.appendObservation(lease: lease, observation: invalid),
      throwsA(isA<AgentEvaluationLedgerException>()),
    );
    expect(db.select('SELECT * FROM eval_observations'), isEmpty);
  });

  test('seal requires completed content and exact expected evidence', () {
    _createExecution(ledger, cell);
    final lease = _claim(ledger, 'worker-1', 1, 50);
    ledger.startAttempt(
      lease: lease,
      attemptNo: 1,
      runId: 'run-1',
      kind: 'content',
      startedAtMs: 2,
    );
    final input = _observation('observation-1', 3);
    ledger.appendObservation(lease: lease, observation: input);

    expect(
      () => ledger.sealSlot(
        lease: lease,
        result: 'pass',
        expectedEvidence: <AgentEvaluationEvidenceKey>[input.evidenceKey],
        sealedAtMs: 4,
      ),
      throwsA(isA<AgentEvaluationConflict>()),
    );
    ledger.finishAttempt(
      lease: lease,
      attemptNo: 1,
      status: 'completed',
      finalKind: 'content',
      finishedAtMs: 4,
    );
    expect(
      () => ledger.sealSlot(
        lease: lease,
        result: 'pass',
        expectedEvidence: <AgentEvaluationEvidenceKey>[
          input.evidenceKey,
          const AgentEvaluationEvidenceKey(
            attemptNo: 1,
            stageId: 'missing',
            kind: 'gate',
            itemKey: 'singleton',
          ),
        ],
        sealedAtMs: 5,
      ),
      throwsA(isA<AgentEvaluationConflict>()),
    );
    final sealed = ledger.sealSlot(
      lease: lease,
      result: 'pass',
      expectedEvidence: <AgentEvaluationEvidenceKey>[input.evidenceKey],
      sealedAtMs: 5,
    );
    expect(
      ledger.readSealedResult(sealed.trialSlotId)?.evidenceHash,
      sealed.evidenceHash,
    );
    expect(
      ledger.claimNextSlot(
        executionId: 'execution-1',
        owner: 'worker-2',
        nowMs: 100,
        leaseDurationMs: 20,
      ),
      isNull,
    );
  });

  test('content completion and slot seal commit or roll back together', () {
    _createExecution(ledger, cell);
    final lease = _claim(ledger, 'worker-atomic', 1, 50);
    ledger.startAttempt(
      lease: lease,
      attemptNo: 1,
      runId: 'run-atomic',
      kind: 'content',
      startedAtMs: 2,
    );
    final input = _observation('observation-atomic', 3);
    ledger.appendObservation(lease: lease, observation: input);

    expect(
      () => ledger.sealSlot(
        lease: lease,
        result: 'pass',
        expectedEvidence: <AgentEvaluationEvidenceKey>[input.evidenceKey],
        sealedAtMs: 4,
        completeContentAttemptNo: 1,
        sandboxCommit: AgentEvaluationSandboxCommit(
          isolationTrialId: lease.trialSlotId,
          isolationMode: 'independent',
          databasePath: '/tmp/atomic.sqlite',
          databaseFileHash: _digest('8'),
          baseGenerationHash: _digest('9'),
        ),
      ),
      throwsA(isA<AgentEvaluationConflict>()),
    );
    expect(
      db
          .select(
            '''SELECT status FROM eval_trial_attempts
               WHERE trial_slot_id = ? AND attempt_no = 1''',
            <Object?>[lease.trialSlotId],
          )
          .single['status'],
      'started',
    );
    expect(
      db.select(
        'SELECT status FROM eval_trial_slots WHERE trial_slot_id = ?',
        <Object?>[lease.trialSlotId],
      ).single['status'],
      'running',
    );

    ledger.sealSlot(
      lease: lease,
      result: 'pass',
      expectedEvidence: <AgentEvaluationEvidenceKey>[input.evidenceKey],
      sealedAtMs: 5,
      completeContentAttemptNo: 1,
      sandboxCommit: AgentEvaluationSandboxCommit(
        isolationTrialId: lease.trialSlotId,
        isolationMode: 'independent',
        databasePath: '/tmp/atomic.sqlite',
        databaseFileHash: _digest('8'),
        baseGenerationHash: null,
      ),
    );
    expect(
      db
          .select(
            '''SELECT status FROM eval_trial_attempts
               WHERE trial_slot_id = ? AND attempt_no = 1''',
            <Object?>[lease.trialSlotId],
          )
          .single['status'],
      'completed',
    );
    expect(
      db.select(
        'SELECT status FROM eval_trial_slots WHERE trial_slot_id = ?',
        <Object?>[lease.trialSlotId],
      ).single['status'],
      'sealed',
    );
  });
}

AgentEvaluationExecution _createExecution(
  AgentEvaluationLedger ledger,
  AgentEvaluationCellDefinition cell,
) => ledger.createOrValidateExecution(
  executionId: 'execution-1',
  experimentId: 'experiment-1',
  cells: <AgentEvaluationCellDefinition>[cell],
  createdAtMs: 1,
);

AgentEvaluationLease _claim(
  AgentEvaluationLedger ledger,
  String owner,
  int nowMs,
  int durationMs,
) => ledger.claimNextSlot(
  executionId: 'execution-1',
  owner: owner,
  nowMs: nowMs,
  leaseDurationMs: durationMs,
)!;

AgentEvaluationLease _startedLease(AgentEvaluationLedger ledger) {
  _createExecution(
    ledger,
    AgentEvaluationCellDefinition(
      generationBundleHash: _digest('b'),
      sutModelRouteHash: _digest('a'),
      scenarioReleaseHash: _digest('c'),
      decodingConfigHash: _digest('d'),
    ),
  );
  final lease = _claim(ledger, 'worker-1', 1, 50);
  ledger.startAttempt(
    lease: lease,
    attemptNo: 1,
    runId: 'run-1',
    kind: 'content',
    startedAtMs: 2,
  );
  return lease;
}

AgentEvaluationObservationInput _observation(String id, int createdAtMs) =>
    AgentEvaluationObservationInput(
      observationId: id,
      attemptNo: 1,
      sequenceNo: 0,
      stageId: 'performance',
      kind: 'usage',
      itemKey: 'singleton',
      valueJson: AgentEvaluationHashes.canonicalJson(<String, Object?>{
        'schemaVersion': 'eval-attempt-usage-v1',
        'promptTokens': 1,
        'completionTokens': 1,
        'costMicrousd': 0,
      }),
      evidenceHash: _digest('8'),
      evaluationBundleHash: _digest('e'),
      createdAtMs: createdAtMs,
    );

AgentEvaluationObservationInput _copyObservation(
  AgentEvaluationObservationInput source, {
  String? stageId,
  String? kind,
  String? valueJson,
}) => AgentEvaluationObservationInput(
  observationId: source.observationId,
  attemptNo: source.attemptNo,
  sequenceNo: source.sequenceNo,
  stageId: stageId ?? source.stageId,
  kind: kind ?? source.kind,
  itemKey: source.itemKey,
  valueJson: valueJson ?? source.valueJson,
  evidenceHash: source.evidenceHash,
  evaluationBundleHash: source.evaluationBundleHash,
  proseHash: source.proseHash,
  createdAtMs: source.createdAtMs,
);

void _seedManifest(
  Database db, {
  required AgentEvaluationCellDefinition cell,
  required int trialsPerCell,
}) {
  db.execute(
    '''INSERT INTO generation_bundles (bundle_hash, bundle_id, releases_json, created_at_ms)
       VALUES (?, 'bundle-1', '[]', 1)''',
    <Object?>[cell.generationBundleHash],
  );
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'evaluator-1', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    <Object?>[_digest('e'), _digest('1'), _digest('2'), _digest('3')],
  );
  db.execute(
    '''INSERT INTO eval_scenario_sets (
         scenario_set_release_hash, set_id, version, manifest_hash, created_at_ms
       ) VALUES (?, 'set-1', '1.0.0', ?, 1)''',
    <Object?>[_digest('f'), _digest('4')],
  );
  db.execute(
    '''INSERT INTO eval_scenarios (
         scenario_release_hash, scenario_set_release_hash, scenario_id, version,
         fixture_hash, isolation_mode, verifier_release_refs_json,
         rubric_release_ref, expected_terminal_state,
         required_failure_codes_json, allowed_failure_codes_json,
         forbidden_failure_codes_json, outcome_comparator_release_ref,
         forbidden_side_effects_json, accept_expected, scenario_json, created_at_ms
       ) VALUES (?, ?, 'scenario-1', '1.0.0', ?, 'independent', '[]',
         'rubric-1', 'accepted', '[]', '[]', '[]', 'comparator-1', '[]', 1, '{}', 1)''',
    <Object?>[cell.scenarioReleaseHash, _digest('f'), _digest('5')],
  );
  final cellId = cell.cellId;
  db.execute(
    '''INSERT INTO eval_experiments (
         experiment_id, manifest_json, manifest_hash, scenario_set_release_hash,
         evaluation_bundle_hash, expected_cell_set_hash, expected_slot_set_hash,
         trials_per_cell, created_at_ms
       ) VALUES ('experiment-1', '{}', ?, ?, ?, ?, ?, ?, 1)''',
    <Object?>[
      _digest('6'),
      _digest('f'),
      _digest('e'),
      AgentEvaluationLedger.canonicalCellSetHash(<String>[cellId]),
      AgentEvaluationLedger.canonicalSlotSetHash(<String>[
        cellId,
      ], trialsPerCell),
      trialsPerCell,
    ],
  );
}

String _digest(String character) => List<String>.filled(64, character).join();
