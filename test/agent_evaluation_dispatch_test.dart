import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_dispatch.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';

void main() {
  test('frozen inputs produce one deterministic adjacent two-arm plan', () {
    final descriptors = _descriptors();
    final first = AgentEvaluationDispatchPlanner.build(
      experimentId: 'experiment-1',
      manifestHash: _digest('6'),
      seedPolicy: const <String, Object?>{'mode': 'recorded'},
      expectedSlotSetHash: _digest('7'),
      descriptors: descriptors,
    );
    final reversed = AgentEvaluationDispatchPlanner.build(
      experimentId: 'experiment-1',
      manifestHash: _digest('6'),
      seedPolicy: const <String, Object?>{'mode': 'recorded'},
      expectedSlotSetHash: _digest('7'),
      descriptors: descriptors.reversed,
    );

    expect(reversed.planHash, first.planHash);
    expect(reversed.slotIds, first.slotIds);
    expect(first.entries.map((entry) => entry.armOrdinal), <int>[0, 1]);
    expect(first.entries[0].pairId, first.entries[1].pairId);
    expect(
      AgentEvaluationDispatchPlanner.build(
        experimentId: 'experiment-1',
        manifestHash: _digest('6'),
        seedPolicy: const <String, Object?>{'mode': 'different'},
        expectedSlotSetHash: _digest('7'),
        descriptors: descriptors,
      ).seedHash,
      isNot(first.seedHash),
    );
  });

  test('actual starts follow the plan and sealed history replays', () {
    final db = _openSeededDatabase();
    addTearDown(db.dispose);
    final ledger = AgentEvaluationLedger(db: db);
    _createExecution(ledger);

    final first = ledger.claimNextSlot(
      executionId: 'execution-1',
      owner: 'worker-1',
      nowMs: 10,
      leaseDurationMs: 100,
    )!;
    expect(
      ledger.claimNextSlot(
        executionId: 'execution-1',
        owner: 'worker-2',
        nowMs: 11,
        leaseDurationMs: 100,
      ),
      isNull,
    );
    _finishFailedSlot(ledger, first, baseTime: 12);

    final second = ledger.claimNextSlot(
      executionId: 'execution-1',
      owner: 'worker-2',
      nowMs: 20,
      leaseDurationMs: 100,
    )!;
    _finishFailedSlot(ledger, second, baseTime: 21);

    final replay = AgentEvaluationDispatchReplay.verify(
      db: db,
      executionId: 'execution-1',
    );
    expect(replay.firstStartOrder, <String>[
      first.trialSlotId,
      second.trialSlotId,
    ]);
    expect(replay.eventCount, 6);
    expect(
      db
          .select('''SELECT event_type FROM eval_dispatch_events
               ORDER BY event_ordinal''')
          .map((row) => row['event_type']),
      <String>[
        'claimed',
        'attemptStarted',
        'sealed',
        'claimed',
        'attemptStarted',
        'sealed',
      ],
    );
  });

  test('exact expiry reclaim increments epoch and tampering is detected', () {
    final db = _openSeededDatabase();
    addTearDown(db.dispose);
    final ledger = AgentEvaluationLedger(db: db);
    _createExecution(ledger);
    final oldLease = ledger.claimNextSlot(
      executionId: 'execution-1',
      owner: 'worker-old',
      nowMs: 10,
      leaseDurationMs: 10,
    )!;
    final replacement = ledger.claimNextSlot(
      executionId: 'execution-1',
      owner: 'worker-new',
      nowMs: 20,
      leaseDurationMs: 20,
    )!;
    expect(replacement.trialSlotId, oldLease.trialSlotId);
    expect(replacement.epoch, 2);
    expect(
      AgentEvaluationDispatchReplay.verify(
        db: db,
        executionId: 'execution-1',
        requireComplete: false,
      ).eventCount,
      2,
    );

    db.execute('DROP TRIGGER prevent_eval_dispatch_events_update');
    db.execute('''UPDATE eval_dispatch_events SET occurred_at_ms = 19
         WHERE event_type = 'reclaimed' ''');
    expect(
      () => AgentEvaluationDispatchReplay.verify(
        db: db,
        executionId: 'execution-1',
        requireComplete: false,
      ),
      throwsA(isA<AgentEvaluationDispatchReplayException>()),
    );
  });

  test('recovered attempt adopts the new fence and remains replayable', () {
    final db = _openSeededDatabase();
    addTearDown(db.dispose);
    final ledger = AgentEvaluationLedger(db: db);
    _createExecution(ledger);
    final oldLease = ledger.claimNextSlot(
      executionId: 'execution-1',
      owner: 'worker-old',
      nowMs: 10,
      leaseDurationMs: 10,
    )!;
    ledger.startAttempt(
      lease: oldLease,
      attemptNo: 1,
      runId: '${oldLease.trialSlotId}-run',
      kind: 'transport',
      startedAtMs: 11,
    );
    final replacement = ledger.claimNextSlot(
      executionId: 'execution-1',
      owner: 'worker-new',
      nowMs: 20,
      leaseDurationMs: 20,
    )!;
    _finishFailedSlot(ledger, replacement, baseTime: 21);

    final replay = AgentEvaluationDispatchReplay.verify(
      db: db,
      executionId: 'execution-1',
      requireComplete: false,
    );
    expect(replay.firstStartOrder, <String>[replacement.trialSlotId]);
    expect(
      db
          .select('''SELECT event_type FROM eval_dispatch_events
               ORDER BY event_ordinal''')
          .map((row) => row['event_type']),
      <String>[
        'claimed',
        'attemptStarted',
        'reclaimed',
        'attemptStarted',
        'sealed',
      ],
    );
  });

  test('episode steps remain ordered before randomized arm order', () {
    AgentEvaluationDispatchDescriptor descriptor({
      required String slot,
      required String bundle,
      required String scenario,
      required int step,
    }) => AgentEvaluationDispatchDescriptor(
      trialSlotId: slot,
      cellId: AgentEvaluationHashes.domainHash('episode-cell', slot),
      generationBundleHash: bundle,
      modelRouteHash: _digest('b'),
      scenarioReleaseHash: scenario,
      decodingConfigHash: _digest('d'),
      trialNo: 1,
      isolationMode: 'episode',
      episodeId: 'episode-1',
      episodeStep: step,
    );

    final stepZeroScenario = _digest('c');
    final stepOneScenario = _digest('e');
    final plan = AgentEvaluationDispatchPlanner.build(
      experimentId: 'experiment-episode',
      manifestHash: _digest('6'),
      seedPolicy: const <String, Object?>{'mode': 'recorded'},
      expectedSlotSetHash: _digest('7'),
      descriptors: <AgentEvaluationDispatchDescriptor>[
        descriptor(
          slot: _digest('1'),
          bundle: _digest('a'),
          scenario: stepOneScenario,
          step: 1,
        ),
        descriptor(
          slot: _digest('2'),
          bundle: _digest('9'),
          scenario: stepOneScenario,
          step: 1,
        ),
        descriptor(
          slot: _digest('3'),
          bundle: _digest('a'),
          scenario: stepZeroScenario,
          step: 0,
        ),
        descriptor(
          slot: _digest('4'),
          bundle: _digest('9'),
          scenario: stepZeroScenario,
          step: 0,
        ),
      ],
    );
    expect(
      plan.entries.take(2).map((entry) => entry.trialSlotId).toSet(),
      <String>{_digest('3'), _digest('4')},
    );
  });

  test('two SQLite processes cannot claim ahead of the first start', () async {
    final directory = Directory.systemTemp.createTempSync('eval-dispatch-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/authority.sqlite';
    final setup = _openSeededDatabase(path: path);
    _createExecution(AgentEvaluationLedger(db: setup));
    setup.dispose();

    Future<String?> claim(String owner) => Isolate.run(() {
      final connection = sqlite3.open(path);
      try {
        connection.execute('PRAGMA foreign_keys = ON');
        connection.execute('PRAGMA busy_timeout = 5000');
        return AgentEvaluationLedger(db: connection)
            .claimNextSlot(
              executionId: 'execution-1',
              owner: owner,
              nowMs: 10,
              leaseDurationMs: 100,
            )
            ?.trialSlotId;
      } finally {
        connection.dispose();
      }
    });

    final results = await Future.wait(<Future<String?>>[
      claim('process-a'),
      claim('process-b'),
    ]);
    expect(results.whereType<String>(), hasLength(1));
    final verify = sqlite3.open(path);
    addTearDown(verify.dispose);
    expect(
      verify.select(
        "SELECT * FROM eval_dispatch_events WHERE event_type = 'claimed'",
      ),
      hasLength(1),
    );
  });
}

List<AgentEvaluationDispatchDescriptor> _descriptors() =>
    <AgentEvaluationDispatchDescriptor>[
      AgentEvaluationDispatchDescriptor(
        trialSlotId: _digest('a'),
        cellId: _digest('1'),
        generationBundleHash: _digest('b'),
        modelRouteHash: _digest('c'),
        scenarioReleaseHash: _digest('d'),
        decodingConfigHash: _digest('e'),
        trialNo: 1,
        isolationMode: 'independent',
      ),
      AgentEvaluationDispatchDescriptor(
        trialSlotId: _digest('f'),
        cellId: _digest('2'),
        generationBundleHash: _digest('3'),
        modelRouteHash: _digest('c'),
        scenarioReleaseHash: _digest('d'),
        decodingConfigHash: _digest('e'),
        trialNo: 1,
        isolationMode: 'independent',
      ),
    ];

Database _openSeededDatabase({String? path}) {
  final db = path == null ? sqlite3.openInMemory() : sqlite3.open(path);
  db.execute('PRAGMA foreign_keys = ON');
  DatabaseSchemaManager(migrations: authoringSchemaMigrations).ensureSchema(db);
  final cells = _cells();
  for (final cell in cells) {
    db.execute(
      '''INSERT INTO generation_bundles (
           bundle_hash, bundle_id, releases_json, created_at_ms
         ) VALUES (?, ?, '[]', 1)''',
      <Object?>[cell.generationBundleHash, cell.generationBundleHash],
    );
  }
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'evaluation', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
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
         'rubric-1', 'rejected', '[]', '[]', '[]', 'comparator-1', '[]', 0, '{}', 1)''',
    <Object?>[_digest('c'), _digest('f'), _digest('5')],
  );
  final cellIds = cells.map((cell) => cell.cellId).toList()..sort();
  final manifest = AgentEvaluationHashes.canonicalJson(<String, Object?>{
    'seedPolicy': <String, Object?>{'mode': 'recorded'},
  });
  db.execute(
    '''INSERT INTO eval_experiments (
         experiment_id, manifest_json, manifest_hash, scenario_set_release_hash,
         evaluation_bundle_hash, expected_cell_set_hash, expected_slot_set_hash,
         trials_per_cell, created_at_ms
       ) VALUES ('experiment-1', ?, ?, ?, ?, ?, ?, 1, 1)''',
    <Object?>[
      manifest,
      _digest('6'),
      _digest('f'),
      _digest('e'),
      AgentEvaluationLedger.canonicalCellSetHash(cellIds),
      AgentEvaluationLedger.canonicalSlotSetHash(cellIds, 1),
    ],
  );
  return db;
}

List<AgentEvaluationCellDefinition> _cells() => <AgentEvaluationCellDefinition>[
  AgentEvaluationCellDefinition(
    generationBundleHash: _digest('a'),
    sutModelRouteHash: _digest('b'),
    scenarioReleaseHash: _digest('c'),
    decodingConfigHash: _digest('d'),
  ),
  AgentEvaluationCellDefinition(
    generationBundleHash: _digest('9'),
    sutModelRouteHash: _digest('b'),
    scenarioReleaseHash: _digest('c'),
    decodingConfigHash: _digest('d'),
  ),
];

AgentEvaluationExecution _createExecution(AgentEvaluationLedger ledger) =>
    ledger.createOrValidateExecution(
      executionId: 'execution-1',
      experimentId: 'experiment-1',
      cells: _cells(),
      createdAtMs: 1,
    );

void _finishFailedSlot(
  AgentEvaluationLedger ledger,
  AgentEvaluationLease lease, {
  required int baseTime,
}) {
  ledger.startAttempt(
    lease: lease,
    attemptNo: 1,
    runId: '${lease.trialSlotId}-run',
    kind: 'transport',
    startedAtMs: baseTime,
  );
  final observation = AgentEvaluationObservationInput(
    observationId: '${lease.trialSlotId}-observation',
    attemptNo: 1,
    sequenceNo: 0,
    stageId: 'failure',
    kind: 'taxonomy',
    itemKey: 'singleton',
    valueJson: AgentEvaluationHashes.canonicalJson(<String, Object?>{
      'primary': 'provider.transport',
      'labels': <String>['provider.transport'],
    }),
    evidenceHash: _digest('8'),
    evaluationBundleHash: _digest('e'),
    createdAtMs: baseTime + 1,
  );
  ledger.appendObservation(lease: lease, observation: observation);
  ledger.finishAttempt(
    lease: lease,
    attemptNo: 1,
    status: 'failed',
    finalKind: 'transport',
    finishedAtMs: baseTime + 2,
  );
  ledger.sealSlot(
    lease: lease,
    result: 'fail',
    expectedEvidence: <AgentEvaluationEvidenceKey>[observation.evidenceKey],
    sealedAtMs: baseTime + 3,
  );
}

String _digest(String character) => List<String>.filled(64, character).join();
