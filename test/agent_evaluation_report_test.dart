import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_authorities.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_report.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_typed_evidence.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_digest.dart';
import 'package:novel_writer/features/story_generation/data/production_pre_quality_gate.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  late Database db;
  late AgentEvaluationReportBuilder builder;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    builder = AgentEvaluationReportBuilder(db: db);
  });

  tearDown(() => db.dispose());

  test('failed transport cost remains in all-attempt resource totals', () {
    _seedExecution(db, cellCount: 1, trialsPerCell: 3, failedTransport: true);

    final report = builder.build(executionId: 'execution-1', policy: _policy());
    final json = report.toJson();
    final counts = json['counts']! as Map<String, Object?>;
    final rates = json['rates']! as Map<String, Object?>;
    final resources = json['resources']! as Map<String, Object?>;
    final quality = json['qualityDimensions']! as Map<String, Object?>;
    final prose = quality['proseReadability']! as Map<String, Object?>;

    expect(counts['attempted'], 3);
    expect(counts['completed'], 3);
    expect(counts['transportFail'], 1);
    expect(rates['completionRate'], 1.0);
    expect(rates['passRate'], 1.0);
    expect(rates['pass3Rate'], 1.0);
    expect(resources, <String, Object?>{
      'tokens': 130,
      'latencyMs': 260,
      'costMicrousd': 390,
    });
    expect(prose['mean'], 91.0);
    expect(prose['min'], 90.0);
    expect(report.toMarkdown(), contains('all attempts'));
  });

  test(
    'nineteen samples report mean/min but no p95 or confidence interval',
    () {
      _seedExecution(db, cellCount: 19, trialsPerCell: 1);

      final report = builder.build(
        executionId: 'execution-1',
        policy: _policy(minimumSamples: 20),
      );
      final quality =
          report.toJson()['qualityDimensions']! as Map<String, Object?>;
      final prose = quality['proseReadability']! as Map<String, Object?>;

      expect(prose['samples'], 19);
      expect(prose['evidenceInsufficient'], isTrue);
      expect(prose, isNot(contains('p95')));
      expect(prose, isNot(contains('ci95')));
    },
  );

  test('secret-like valueJson is rejected before public aggregation', () {
    _seedExecution(db, cellCount: 1, trialsPerCell: 1, injectSecret: true);

    expect(
      () => builder.build(executionId: 'execution-1', policy: _policy()),
      throwsA(isA<AgentEvaluationReportException>()),
    );
  });

  test('unknown observation DTO kind is rejected', () {
    _seedExecution(db, cellCount: 1, trialsPerCell: 1, injectUnknownKind: true);

    expect(
      () => builder.build(executionId: 'execution-1', policy: _policy()),
      throwsA(isA<AgentEvaluationReportException>()),
    );
  });

  test('quality observation without deterministic receipt is rejected', () {
    _seedExecution(
      db,
      cellCount: 1,
      trialsPerCell: 1,
      omitDeterministicReceiptHash: true,
    );

    expect(
      () => builder.build(executionId: 'execution-1', policy: _policy()),
      throwsA(isA<AgentEvaluationReportException>()),
    );
  });

  test('valid v4 receipt from another slot cannot be substituted', () {
    _seedExecution(
      db,
      cellCount: 1,
      trialsPerCell: 1,
      substituteUnrelatedDeterministicReceipt: true,
    );

    expect(
      () => builder.build(executionId: 'execution-1', policy: _policy()),
      throwsA(isA<AgentEvaluationReportException>()),
    );
  });

  test('deterministic dimension score must match receipt scores', () {
    _seedExecution(
      db,
      cellCount: 1,
      trialsPerCell: 1,
      qualityDimension: 'efficiency',
      qualityScoreMicros: 49000000,
    );

    expect(
      () => builder.build(executionId: 'execution-1', policy: _policy()),
      throwsA(isA<AgentEvaluationReportException>()),
    );
  });

  for (final tamper in <String>[
    'authority',
    'execution',
    'bundle',
    'outerHash',
    'scores',
    'prose',
  ]) {
    test('deterministic receipt $tamper tamper is rejected', () {
      _seedExecution(
        db,
        cellCount: 1,
        trialsPerCell: 1,
        deterministicReceiptTamper: tamper,
      );

      expect(
        () => builder.build(executionId: 'execution-1', policy: _policy()),
        throwsA(isA<AgentEvaluationReportException>()),
      );
    });
  }

  test('formal usage v2 and production receipt are reportable', () {
    _seedExecution(
      db,
      cellCount: 1,
      trialsPerCell: 3,
      formalProductionEvidence: true,
    );

    final report = builder.build(executionId: 'execution-1', policy: _policy());
    final resources = report.toJson()['resources']! as Map<String, Object?>;

    expect(resources['tokens'], 30);
    expect(
      AgentEvaluationPublicReport.verifyJsonText(report.toJsonText()),
      isTrue,
    );
  });

  test('missing canonical slot prevents report generation', () {
    _seedExecution(db, cellCount: 1, trialsPerCell: 3, slotsToInsert: 2);

    expect(
      () => builder.build(executionId: 'execution-1', policy: _policy()),
      throwsA(isA<AgentEvaluationReportException>()),
    );
  });

  test('report hash is reproducible and detects payload tampering', () {
    _seedExecution(db, cellCount: 1, trialsPerCell: 3);
    final first = builder.build(executionId: 'execution-1', policy: _policy());
    final second = builder.build(executionId: 'execution-1', policy: _policy());

    expect(first.reportHash, second.reportHash);
    expect(
      AgentEvaluationPublicReport.verifyJsonText(first.toJsonText()),
      isTrue,
    );
    final tampered = jsonDecode(first.toJsonText()) as Map<String, Object?>;
    final rates = Map<String, Object?>.from(
      tampered['rates']! as Map<String, Object?>,
    );
    rates['passRate'] = 0.0;
    tampered['rates'] = rates;
    expect(
      AgentEvaluationPublicReport.verifyJsonText(jsonEncode(tampered)),
      isFalse,
    );
  });

  test('report verifier rejects an extra field with a recomputed hash', () {
    _seedExecution(db, cellCount: 1, trialsPerCell: 3);
    final original = builder.build(
      executionId: 'execution-1',
      policy: _policy(),
    );
    final forged = jsonDecode(original.toJsonText()) as Map<String, Object?>;
    forged.remove('reportHash');
    forged['authorization'] = 'Bearer private-token';
    forged['reportHash'] = AgentEvaluationHashes.domainHash(
      'eval-public-report-v1',
      forged,
    );

    expect(
      AgentEvaluationPublicReport.verifyJsonText(jsonEncode(forged)),
      isFalse,
    );
  });
}

AgentEvaluationReportPolicy _policy({int minimumSamples = 20}) =>
    AgentEvaluationReportPolicy(
      aggregatorReleaseHash: _digest('7'),
      minimumDistributionSamples: minimumSamples,
    );

void _seedExecution(
  Database db, {
  required int cellCount,
  required int trialsPerCell,
  int? slotsToInsert,
  bool failedTransport = false,
  bool injectSecret = false,
  bool injectUnknownKind = false,
  bool formalProductionEvidence = false,
  bool omitDeterministicReceiptHash = false,
  bool substituteUnrelatedDeterministicReceipt = false,
  String? deterministicReceiptTamper,
  String qualityDimension = 'proseReadability',
  int? qualityScoreMicros,
}) {
  final bundle = _digest('b');
  final scenario = _digest('c');
  final decoding = _digest('d');
  final evaluator = _digest('e');
  db.execute(
    '''INSERT INTO generation_bundles (
         bundle_hash, bundle_id, releases_json, created_at_ms
       ) VALUES (?, 'bundle-1', '[]', 1)''',
    <Object?>[bundle],
  );
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'evaluator-1', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    <Object?>[evaluator, _digest('1'), _digest('7'), _digest('2')],
  );
  db.execute(
    '''INSERT INTO eval_scenario_sets (
         scenario_set_release_hash, set_id, version, manifest_hash, created_at_ms
       ) VALUES (?, 'set-1', '1.0.0', ?, 1)''',
    <Object?>[_digest('f'), _digest('3')],
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
         'rubric-v1', 'accepted', '[]', '[]', '[]', 'comparator-v1', '[]', 1,
         '{}', 1)''',
    <Object?>[scenario, _digest('f'), _digest('4')],
  );
  final cellIds = <String>[];
  for (var index = 0; index < cellCount; index += 1) {
    final model = AgentEvaluationHashes.domainHash('test-model-v1', index);
    final cellId = AgentEvaluationReleaseStore.canonicalCellId(
      generationBundleHash: bundle,
      sutModelRouteHash: model,
      scenarioReleaseHash: scenario,
      decodingConfigHash: decoding,
    );
    cellIds.add(cellId);
    db.execute(
      '''INSERT INTO eval_cells (
           cell_id, generation_bundle_hash, sut_model_route_hash,
           scenario_release_hash, decoding_config_hash, created_at_ms
         ) VALUES (?, ?, ?, ?, ?, 1)''',
      <Object?>[cellId, bundle, model, scenario, decoding],
    );
  }
  cellIds.sort();
  final cellSetHash = AgentEvaluationReleaseStore.canonicalCellSetHash(cellIds);
  final slotSetHash = AgentEvaluationReleaseStore.canonicalSlotSetHash(
    cellIds,
    trialsPerCell,
  );
  db.execute(
    '''INSERT INTO eval_experiments (
         experiment_id, manifest_json, manifest_hash, scenario_set_release_hash,
         evaluation_bundle_hash, expected_cell_set_hash, expected_slot_set_hash,
         trials_per_cell, created_at_ms
       ) VALUES ('experiment-1', '{}', ?, ?, ?, ?, ?, ?, 1)''',
    <Object?>[
      _digest('5'),
      _digest('f'),
      evaluator,
      cellSetHash,
      slotSetHash,
      trialsPerCell,
    ],
  );
  for (var index = 0; index < cellIds.length; index += 1) {
    db.execute(
      '''INSERT INTO eval_experiment_cells (experiment_id, cell_id, ordinal)
         VALUES ('experiment-1', ?, ?)''',
      <Object?>[cellIds[index], index],
    );
  }
  db.execute(
    '''INSERT INTO eval_executions (
         execution_id, experiment_id, status, expected_cell_set_hash,
         expected_slot_set_hash, created_at_ms, started_at_ms
       ) VALUES ('execution-1', 'experiment-1', 'running', ?, ?, 1, 1)''',
    <Object?>[cellSetHash, slotSetHash],
  );
  for (var index = 0; index < cellIds.length; index += 1) {
    db.execute(
      '''INSERT INTO eval_execution_cells (execution_id, cell_id, ordinal)
         VALUES ('execution-1', ?, ?)''',
      <Object?>[cellIds[index], index],
    );
  }

  final expectedSlots = cellIds.length * trialsPerCell;
  final insertCount = slotsToInsert ?? expectedSlots;
  var inserted = 0;
  for (
    var cellIndex = 0;
    cellIndex < cellIds.length && inserted < insertCount;
    cellIndex += 1
  ) {
    for (
      var trialNo = 1;
      trialNo <= trialsPerCell && inserted < insertCount;
      trialNo += 1
    ) {
      final slotId = AgentEvaluationReleaseStore.canonicalTrialSlotId(
        executionId: 'execution-1',
        cellId: cellIds[cellIndex],
        trialNo: trialNo,
      );
      db.execute(
        '''INSERT INTO eval_trial_slots (
             trial_slot_id, execution_id, cell_id, trial_no, status, result,
             lease_epoch, lease_owner, lease_expires_at_ms,
             created_at_ms, updated_at_ms
           ) VALUES (?, 'execution-1', ?, ?, 'running', NULL, 1,
             'worker-1', 1000, 1, 2)''',
        <Object?>[slotId, cellIds[cellIndex], trialNo],
      );
      _insertAttempt(
        db,
        slotId: slotId,
        attemptNo: 1,
        kind: 'content',
        status: 'completed',
        durationMs: 20,
      );
      _insertObservation(
        db,
        id: '$slotId-usage-1',
        slotId: slotId,
        attemptNo: 1,
        sequenceNo: 0,
        stage: 'performance',
        kind: 'usage',
        itemKey: 'singleton',
        valueJson: AgentEvaluationHashes.canonicalJson(
          formalProductionEvidence
              ? _usageV2()
              : <String, Object?>{
                  'schemaVersion': 'eval-attempt-usage-v1',
                  'promptTokens': 4,
                  'completionTokens': 6,
                  'costMicrousd': 30,
                  if (injectSecret && inserted == 0)
                    'authorization': 'Bearer hidden',
                },
        ),
        evaluator: evaluator,
      );
      _insertOutcomeObservation(
        db,
        slotId: slotId,
        attemptNo: 1,
        sequenceNo: 10,
        evaluator: evaluator,
      );
      const finalProse = '柳溪说：“仓库断电以后，先检查备用电源，再打开门禁。”她守在终端旁，确认线路已经恢复。';
      final proseHash = AgentEvaluationHashes.domainHash(
        'eval-trial-content-v1',
        finalProse,
      );
      final currentReceiptHash = _insertDeterministicReceipt(
        db,
        executionId: 'execution-1',
        slotId: slotId,
        attemptNo: 1,
        evaluationBundleHash: evaluator,
        finalProse: finalProse,
        tamper: inserted == 0 ? deterministicReceiptTamper : null,
      );
      var observationReceiptHash = currentReceiptHash;
      if (substituteUnrelatedDeterministicReceipt && inserted == 0) {
        observationReceiptHash = _insertDeterministicReceipt(
          db,
          executionId: 'execution-1',
          slotId: 'unrelated-valid-slot',
          attemptNo: 2,
          evaluationBundleHash: evaluator,
          finalProse: finalProse,
        );
      }
      if (formalProductionEvidence) {
        _insertObservation(
          db,
          id: '$slotId-production-receipt',
          slotId: slotId,
          attemptNo: 1,
          sequenceNo: 9,
          stage: 'production',
          kind: 'receipt',
          itemKey: 'singleton',
          valueJson: AgentEvaluationHashes.canonicalJson(
            _productionReceipt(proseHash),
          ),
          evaluator: evaluator,
          proseHash: proseHash,
        );
      }
      _insertObservation(
        db,
        id: '$slotId-quality',
        slotId: slotId,
        attemptNo: 1,
        sequenceNo: 1,
        stage: 'quality',
        kind: 'dimension',
        itemKey: qualityDimension,
        valueJson: AgentEvaluationHashes.canonicalJson(
          _qualityValue(
            scoreMicros: qualityScoreMicros ?? (90 + (inserted % 3)) * 1000000,
            proseHash: proseHash,
            deterministicReceiptHash:
                omitDeterministicReceiptHash && inserted == 0
                ? null
                : observationReceiptHash,
          ),
        ),
        evaluator: evaluator,
        proseHash: proseHash,
      );
      if (inserted == 0) {
        _insertObservation(
          db,
          id: '$slotId-failure',
          slotId: slotId,
          attemptNo: 1,
          sequenceNo: 2,
          stage: 'failure',
          kind: 'taxonomy',
          itemKey: 'singleton',
          valueJson: AgentEvaluationHashes.canonicalJson(<String, Object?>{
            'primary': 'quality.repetition',
            'labels': <String>['quality.repetition', 'quality.causal_gap'],
          }),
          evaluator: evaluator,
        );
      }
      if (failedTransport && inserted == 0) {
        _insertAttempt(
          db,
          slotId: slotId,
          attemptNo: 2,
          kind: 'transport',
          status: 'failed',
          durationMs: 200,
        );
        _insertObservation(
          db,
          id: '$slotId-usage-2',
          slotId: slotId,
          attemptNo: 2,
          sequenceNo: 3,
          stage: 'performance',
          kind: 'usage',
          itemKey: 'singleton',
          valueJson: AgentEvaluationHashes.canonicalJson(<String, Object?>{
            'schemaVersion': 'eval-attempt-usage-v1',
            'promptTokens': 40,
            'completionTokens': 60,
            'costMicrousd': 300,
          }),
          evaluator: evaluator,
        );
      }
      if (injectUnknownKind && inserted == 0) {
        _insertObservation(
          db,
          id: '$slotId-unknown',
          slotId: slotId,
          attemptNo: 1,
          sequenceNo: 4,
          stage: 'quality',
          kind: 'raw-prose',
          itemKey: 'singleton',
          valueJson: AgentEvaluationHashes.canonicalJson(<String, Object?>{
            'score': 100,
          }),
          evaluator: evaluator,
        );
      }
      db.execute(
        '''UPDATE eval_trial_slots
           SET status = 'sealed', result = 'pass', lease_owner = NULL,
             lease_expires_at_ms = NULL, sealed_evidence_hash = ?,
             updated_at_ms = 3, sealed_at_ms = 3
           WHERE trial_slot_id = ?''',
        <Object?>[_digest('6'), slotId],
      );
      inserted += 1;
    }
  }
}

void _insertAttempt(
  Database db, {
  required String slotId,
  required int attemptNo,
  required String kind,
  required String status,
  int durationMs = 1,
}) {
  db.execute(
    '''INSERT INTO eval_trial_attempts (
         trial_slot_id, attempt_no, run_id, kind, status, lease_epoch,
         lease_owner, started_at_ms, finished_at_ms
       ) VALUES (?, ?, ?, ?, ?, 1, 'worker-1', 1, ?)''',
    <Object?>[
      slotId,
      attemptNo,
      '$slotId-run-$attemptNo',
      kind,
      status,
      1 + durationMs,
    ],
  );
}

void _insertObservation(
  Database db, {
  required String id,
  required String slotId,
  required int attemptNo,
  required int sequenceNo,
  required String stage,
  required String kind,
  required String itemKey,
  required String valueJson,
  required String evaluator,
  String? proseHash,
}) {
  db.execute(
    '''INSERT INTO eval_observations (
         observation_id, trial_slot_id, attempt_no, sequence_no, stage_id,
         kind, item_key, value_json, evidence_hash, evaluation_bundle_hash,
         prose_hash, lease_epoch, lease_owner, created_at_ms
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 'worker-1', 2)''',
    <Object?>[
      id,
      slotId,
      attemptNo,
      sequenceNo,
      stage,
      kind,
      itemKey,
      valueJson,
      AgentEvaluationHashes.domainHash('test-observation-v1', <Object?>[
        id,
        valueJson,
      ]),
      evaluator,
      proseHash,
    ],
  );
}

Map<String, Object?> _qualityValue({
  required int scoreMicros,
  required String proseHash,
  required String? deterministicReceiptHash,
}) {
  final injectionReceipt = AgentEvaluationJudgeInjectionSafetyReceipt(
    evaluatedContentHash: proseHash,
    candidateJsonDigest: _digest('a'),
    renderedMessagesDigest: _digest('b'),
    judgePromptReleaseHash: _digest('1'),
    judgeModelRouteHash: _digest('2'),
    rubricReleaseHash: _digest('3'),
    parserReleaseHash: _digest('6'),
    aggregatorReleaseHash: _digest('7'),
    rawResponseHash: _digest('4'),
    parsedScoreMicros: <String, int>{
      'proseReadability': scoreMicros,
      'plotCausality': scoreMicros,
    },
    parsedSummaryHash: _digest('8'),
    detectedInjectionMarkerHashes: const <String>[],
    guardFailureCodes: const <String>[],
    verifierReleaseHash: _digest('9'),
  );
  return <String, Object?>{
    'schemaVersion': 'eval-quality-dimension-v1',
    'scoreMicros': scoreMicros,
    'judgePromptReleaseHash': _digest('1'),
    'judgeModelRouteHash': _digest('2'),
    'rubricReleaseHash': _digest('3'),
    'aggregatorReleaseHash': _digest('7'),
    'evaluatedContentHash': proseHash,
    'externalJudgeOutputHash': _digest('4'),
    'externalEvaluationEvidenceHash': _digest('5'),
    'deterministicQualityReceiptHash': ?deterministicReceiptHash,
    'judgeInjectionSafetyReceipt': injectionReceipt.toJson(),
  };
}

String _insertDeterministicReceipt(
  Database db, {
  required String executionId,
  required String slotId,
  required int attemptNo,
  required String evaluationBundleHash,
  required String finalProse,
  String? tamper,
}) {
  final brief = SceneBrief(
    projectId: 'report-project',
    chapterId: 'report-chapter',
    chapterTitle: '报告章节',
    sceneId: 'report-scene',
    sceneTitle: '仓库',
    sceneSummary: '柳溪确认备用电源和门禁状态。',
    targetBeat: '确认线路恢复。',
    sceneIndex: 1,
    totalScenesInChapter: 3,
  );
  const materials = ProjectMaterialSnapshot();
  final preQuality = ProductionPreQualityGate.standard.verifyPipelinePolish(
    brief: brief,
    materials: materials,
    prePolishProse: finalProse,
    finalProse: finalProse,
  );
  if (!preQuality.passed || !preQuality.candidateFinalizationEligible) {
    throw StateError('report test prose did not pass the production boundary');
  }
  final gate = <String, Object?>{
    'algorithm': 'deterministic-gate-v4',
    'finalProseHash': GenerationLedgerDigest.text(finalProse),
    'passed': true,
    'boundaryReleaseHash': preQuality.boundaryReleaseHash,
    'briefRequirementsHash': preQuality.briefRequirementsHash,
    'productionPreQualityEvidence': preQuality.toJson(),
    'polishCanonEvidence': preQuality.polishCanonEvidence.toJson(),
    'storyMechanicsEvidence': preQuality.storyMechanicsEvidence.toJson(),
  };
  final gateHash = GenerationLedgerDigest.object(gate);
  final inputs = <String, Object?>{
    'schemaVersion': 'eval-deterministic-quality-inputs-v4',
    'scenarioReleaseHash': _digest('c'),
    'referenceFactsHash': AgentEvaluationHashes.domainHash(
      'eval-quality-reference-facts-v1',
      const <String, Object?>{},
    ),
    'proof': <String, Object?>{
      'candidateHash': GenerationLedgerDigest.text(finalProse),
      'deterministicGateEvidenceHash': gateHash,
      'finalCouncilEvidenceHash': 'sha256:${_digest('a')}',
      'qualityEvidenceHash': 'sha256:${_digest('b')}',
    },
    'characterEvidence': <String, Object?>{
      'requiredNameHashes': <String>[],
      'matchedNameHashes': <String>[],
      'structuredStateRootHash': _digest('1'),
    },
    'canonEvidence': <String, Object?>{
      'requiredRootSourceIdHashes': <String>[],
      'matchedRootSourceIdHashes': <String>[],
      'committedProvenanceRootHash': _digest('2'),
    },
    'polishCanonEvidence': preQuality.polishCanonEvidence.toJson(),
    'storyMechanicsEvidence': preQuality.storyMechanicsEvidence.toJson(),
    'productionPreQualityEvidence': preQuality.toJson(),
    'briefRequirementsHash': preQuality.briefRequirementsHash,
    'deterministicGateFinalProseHash': gate['finalProseHash'],
    'deterministicGate': gate,
    'finalProse': finalProse,
    'adversarialMutations': <String>[],
    'recoveryEventHashes': <String>[],
    'usage': <String, Object?>{
      'calls': 1,
      'tokens': 10,
      'maxCalls': 1,
      'maxTokens': 10,
    },
    'verifierReleaseHashes':
        AgentEvaluationDeterministicQualityPolicy.verifierReleaseHashes,
  };
  final scores = <String, int>{
    'characterConsistency': 0,
    'canonMemory': 0,
    'robustness': 0,
    'efficiency': 50000000,
  };
  final authorityReleaseHash = tamper == 'authority'
      ? _digest('0')
      : AgentEvaluationDeterministicQualityPolicy.authorityReleaseHash;
  final boundExecutionId = tamper == 'execution'
      ? 'unrelated-execution'
      : executionId;
  final boundEvaluationBundleHash = tamper == 'bundle'
      ? _digest('0')
      : evaluationBundleHash;
  final proseHash = tamper == 'prose'
      ? _digest('0')
      : AgentEvaluationHashes.domainHash('eval-trial-content-v1', finalProse);
  final receiptValue = <String, Object?>{
    'authorityReleaseHash': authorityReleaseHash,
    'executionId': boundExecutionId,
    'trialSlotId': slotId,
    'attemptNo': attemptNo,
    'evaluationBundleHash': boundEvaluationBundleHash,
    'proseHash': proseHash,
    'inputs': inputs,
    'scores': scores,
  };
  final calculatedReceiptHash = AgentEvaluationHashes.domainHash(
    'eval-deterministic-quality-receipt-v2',
    receiptValue,
  );
  final storedReceiptHash = tamper == 'outerHash'
      ? _digest('0')
      : calculatedReceiptHash;
  final storedScores = tamper == 'scores'
      ? <String, int>{...scores, 'efficiency': 49000000}
      : scores;
  db.execute(
    '''INSERT INTO eval_deterministic_quality_receipts (
         receipt_hash, authority_release_hash, execution_id, trial_slot_id,
         attempt_no, evaluation_bundle_hash, prose_hash, inputs_json,
         scores_json, created_at_ms
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 2)''',
    <Object?>[
      storedReceiptHash,
      authorityReleaseHash,
      boundExecutionId,
      slotId,
      attemptNo,
      boundEvaluationBundleHash,
      proseHash,
      AgentEvaluationHashes.canonicalJson(inputs),
      AgentEvaluationHashes.canonicalJson(storedScores),
    ],
  );
  return storedReceiptHash;
}

Map<String, Object?> _usageV2() {
  final calls = <Object?>[
    <String, Object?>{
      'sequenceNo': 1,
      'modelRouteHash': _digest('8'),
      'model': 'glm-4.7-flash',
      'promptTokens': 4,
      'completionTokens': 6,
      'succeeded': true,
      'costMicrousd': 0,
      'purpose': 'sut',
    },
  ];
  final callSetHash = AgentEvaluationHashes.domainHash(
    'eval-priced-provider-call-set-v1',
    calls,
  );
  return <String, Object?>{
    'schemaVersion': 'eval-attempt-usage-v2',
    'promptTokens': 4,
    'completionTokens': 6,
    'costMicrousd': 0,
    'priceTableHash': _digest('9'),
    'providerCalls': calls,
    'providerCallSetHash': callSetHash,
    'costEvidenceHash': AgentEvaluationHashes.domainHash(
      'eval-attempt-cost-evidence-v1',
      <String, Object?>{
        'priceTableHash': _digest('9'),
        'providerCallSetHash': callSetHash,
        'promptTokens': 4,
        'completionTokens': 6,
        'costMicrousd': 0,
      },
    ),
  };
}

Map<String, Object?> _productionReceipt(String proseHash) => <String, Object?>{
  'schemaVersion': 'eval-production-receipt-v2',
  'authorityReceiptHash': _digest('1'),
  'authorityReleaseHash': _digest('2'),
  'executorReleaseHash': _digest('3'),
  'attemptRunId': 'attempt-run-1',
  'storyRunId': 'attempt-run-1',
  'candidateHash': _digest('4'),
  'receiptId': 'receipt-1',
  'transactionEvidenceHash': _digest('5'),
  'proseHash': proseHash,
  'generationBundleHash': _digest('6'),
};

void _insertOutcomeObservation(
  Database db, {
  required String slotId,
  required int attemptNo,
  required int sequenceNo,
  required String evaluator,
}) {
  final contentDigest = AgentEvaluationHashes.domainHash(
    'test-content-v1',
    slotId,
  );
  final value = <String, Object?>{
    'terminalState': 'accepted',
    'failureCodes': <String>[],
    'accepted': true,
    'sideEffectCounts': <String, int>{},
    'evidenceComplete': true,
    'contentDigest': contentDigest,
    'independence': 'independent',
    'isolationTrialId': slotId,
    'cacheSourceTrialSlotId': null,
    'productionStoryRunId': null,
    'productionCandidateHash': null,
    'productionReceiptId': null,
    'violations': <String>[],
  };
  final valueJson = AgentEvaluationHashes.canonicalJson(value);
  db.execute(
    '''INSERT INTO eval_observations (
         observation_id, trial_slot_id, attempt_no, sequence_no, stage_id,
         kind, item_key, value_json, evidence_hash, evaluation_bundle_hash,
         prose_hash, lease_epoch, lease_owner, created_at_ms
       ) VALUES (?, ?, ?, ?, 'outcome', 'comparison', 'singleton', ?, ?, ?, ?,
         1, 'worker-1', 2)''',
    <Object?>[
      '$slotId-outcome',
      slotId,
      attemptNo,
      sequenceNo,
      valueJson,
      AgentEvaluationHashes.domainHash('eval-outcome-observation-v1', value),
      evaluator,
      contentDigest,
    ],
  );
}

String _digest(String character) => List<String>.filled(64, character).join();
