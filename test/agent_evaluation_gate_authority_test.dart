import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_dispatch.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_executor.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_evidence.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_authorities.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_authority.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_typed_evidence.dart';

void main() {
  late Database db;
  late AgentEvaluationReleaseStore store;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    store = AgentEvaluationReleaseStore(db: db);
  });

  tearDown(() => db.dispose());

  test('gate release identity binds the complete v4 receipt contract', () {
    final legacyProjectionIdentity = AgentEvaluationHashes.domainHash(
      'eval-release-gate-implementation-v1',
      <String, Object?>{
        'policyHash': AgentEvaluationStandardGatePolicy.policyHash,
        'algorithm': 'sealed-db-dispatch-production-authority-projection-v3',
      },
    );
    final snapshot = AgentEvaluationStandardGatePolicy.gateReleaseSnapshot;

    expect(
      snapshot['deterministicQualityAuthorityReleaseHash'],
      AgentEvaluationDeterministicQualityPolicy.authorityReleaseHash,
    );
    expect(
      snapshot['deterministicQualityReceiptContractReleaseHash'],
      AgentEvaluationDeterministicQualityPolicy.receiptContractReleaseHash,
    );
    expect(
      snapshot['algorithm'],
      'sealed-db-dispatch-production-authority-projection-v4',
    );
    expect(
      AgentEvaluationStandardGatePolicy.gateReleaseHash,
      isNot(legacyProjectionIdentity),
      reason: 'the v3 identity must not claim the v4 receipt semantics',
    );
  });

  test('legacy projection identity cannot occupy the current verdict', () {
    final fixture = _seedReleaseExecution(db, challengerScore: 99);
    final scorecard = store.writeScorecard(
      executionId: fixture.executionId,
      scope: 'execution',
      scopeKey: fixture.executionId,
      aggregateJson: '{"status":"promote"}',
      aggregatorReleaseHash: fixture.aggregatorReleaseHash,
      expectedInputSetHash: store.computeInputSetHash(fixture.executionId),
      createdAtMs: 100,
    );
    final projection = store.rederiveGateAuthorityProjection(
      experimentId: fixture.experimentId,
      executionId: fixture.executionId,
      scorecardHash: scorecard.scorecardHash,
      championBundleHash: fixture.championBundleHash,
      challengerBundleHash: fixture.challengerBundleHash,
    );
    final legacyProjectionIdentity = AgentEvaluationHashes.domainHash(
      'eval-release-gate-implementation-v1',
      <String, Object?>{
        'policyHash': AgentEvaluationStandardGatePolicy.policyHash,
        'algorithm': 'sealed-db-dispatch-production-authority-projection-v3',
      },
    );
    db.execute(
      '''INSERT INTO eval_release_gate_verdicts (
           verdict_hash, verdict_kind, experiment_id, execution_id,
           scorecard_hash, champion_bundle_hash, challenger_bundle_hash,
           status, reasons_json, comparison_input_set_hash,
           expected_pair_set_hash, policy_hash, gate_release_hash,
           created_at_ms
         ) VALUES (?, 'regression', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 101)''',
      <Object?>[
        _digest('0'),
        fixture.experimentId,
        fixture.executionId,
        scorecard.scorecardHash,
        fixture.championBundleHash,
        fixture.challengerBundleHash,
        projection.status,
        AgentEvaluationHashes.canonicalJson(projection.reasons),
        projection.comparisonInputSetHash,
        projection.expectedPairSetHash,
        AgentEvaluationStandardGatePolicy.policyHash,
        legacyProjectionIdentity,
      ],
    );

    expect(
      () => store.evaluateAndRecordGateVerdict(
        verdictKind: 'regression',
        experimentId: fixture.experimentId,
        executionId: fixture.executionId,
        scorecardHash: scorecard.scorecardHash,
        championBundleHash: fixture.championBundleHash,
        challengerBundleHash: fixture.challengerBundleHash,
        createdAtMs: 102,
      ),
      throwsA(isA<AgentEvaluationPromotionConflict>()),
    );
    expect(
      db
          .select('SELECT gate_release_hash FROM eval_release_gate_verdicts')
          .single['gate_release_hash'],
      legacyProjectionIdentity,
    );
  });

  test('caller-supplied gate status is permanently rejected', () {
    expect(
      () => store.recordGateVerdict(
        verdictKind: 'regression',
        experimentId: 'experiment-1',
        executionId: 'execution-1',
        scorecardHash: _digest('1'),
        championBundleHash: _digest('a'),
        challengerBundleHash: _digest('b'),
        status: 'promote',
        reasons: const <String>[],
        comparisonInputSetHash: _digest('2'),
        expectedPairSetHash: _digest('3'),
        policyHash: _digest('4'),
        gateReleaseHash: _digest('5'),
        createdAtMs: 1,
      ),
      throwsA(isA<AgentEvaluationPromotionConflict>()),
    );
    expect(db.select('SELECT * FROM eval_release_gate_verdicts'), isEmpty);
  });

  test('legacy v1 receipts cannot authorize a forged promotion aggregate', () {
    final fixture = _seedReleaseExecution(db, challengerScore: 80);
    final scorecard = store.writeScorecard(
      executionId: fixture.executionId,
      scope: 'execution',
      scopeKey: fixture.executionId,
      aggregateJson: '{"status":"promote","lcb":999,"passRate":1}',
      aggregatorReleaseHash: fixture.aggregatorReleaseHash,
      expectedInputSetHash: store.computeInputSetHash(fixture.executionId),
      createdAtMs: 100,
    );

    final verdict = store.evaluateAndRecordGateVerdict(
      verdictKind: 'regression',
      experimentId: fixture.experimentId,
      executionId: fixture.executionId,
      scorecardHash: scorecard.scorecardHash,
      championBundleHash: fixture.championBundleHash,
      challengerBundleHash: fixture.challengerBundleHash,
      createdAtMs: 101,
    );

    expect(verdict.status, 'insufficientEvidence');
    expect(verdict.reasonsJson, contains('qualityEvidenceInsufficient'));
    expect(verdict.reasonsJson, isNot(contains('999')));
    expect(verdict.policyHash, AgentEvaluationStandardGatePolicy.policyHash);
  });

  test('production observation without runner authority cannot authorize', () {
    final fixture = _seedReleaseExecution(db, challengerScore: 99);
    db.execute(
      'DROP TRIGGER prevent_eval_production_authority_receipts_delete',
    );
    db.execute('DELETE FROM eval_production_authority_receipts');
    final scorecard = store.writeScorecard(
      executionId: fixture.executionId,
      scope: 'execution',
      scopeKey: fixture.executionId,
      aggregateJson: '{"status":"promote"}',
      aggregatorReleaseHash: fixture.aggregatorReleaseHash,
      expectedInputSetHash: store.computeInputSetHash(fixture.executionId),
      createdAtMs: 100,
    );

    expect(
      () => store.evaluateAndRecordGateVerdict(
        verdictKind: 'regression',
        experimentId: fixture.experimentId,
        executionId: fixture.executionId,
        scorecardHash: scorecard.scorecardHash,
        championBundleHash: fixture.championBundleHash,
        challengerBundleHash: fixture.challengerBundleHash,
        createdAtMs: 101,
      ),
      throwsA(isA<AgentEvaluationPromotionConflict>()),
    );
  });

  test('missing one canonical quality pair is insufficient evidence', () {
    final fixture = _seedReleaseExecution(
      db,
      challengerScore: 99,
      omitOneQualityPair: true,
    );
    final scorecard = store.writeScorecard(
      executionId: fixture.executionId,
      scope: 'execution',
      scopeKey: fixture.executionId,
      aggregateJson: '{"status":"promote"}',
      aggregatorReleaseHash: fixture.aggregatorReleaseHash,
      expectedInputSetHash: store.computeInputSetHash(fixture.executionId),
      createdAtMs: 100,
    );

    final verdict = store.evaluateAndRecordGateVerdict(
      verdictKind: 'regression',
      experimentId: fixture.experimentId,
      executionId: fixture.executionId,
      scorecardHash: scorecard.scorecardHash,
      championBundleHash: fixture.championBundleHash,
      challengerBundleHash: fixture.challengerBundleHash,
      createdAtMs: 101,
    );

    expect(verdict.status, 'insufficientEvidence');
    expect(verdict.reasonsJson, contains('qualityEvidenceInsufficient'));
  });

  for (final tamperedKind in <String>['usage', 'quality']) {
    test('tampered $tamperedKind evidence cannot authorize release', () {
      final fixture = _seedReleaseExecution(
        db,
        challengerScore: 99,
        tamperUsageEvidence: tamperedKind == 'usage',
        tamperQualityEvidence: tamperedKind == 'quality',
      );
      final scorecard = store.writeScorecard(
        executionId: fixture.executionId,
        scope: 'execution',
        scopeKey: fixture.executionId,
        aggregateJson: '{"status":"promote"}',
        aggregatorReleaseHash: fixture.aggregatorReleaseHash,
        expectedInputSetHash: store.computeInputSetHash(fixture.executionId),
        createdAtMs: 100,
      );

      final verdict = store.evaluateAndRecordGateVerdict(
        verdictKind: 'regression',
        experimentId: fixture.experimentId,
        executionId: fixture.executionId,
        scorecardHash: scorecard.scorecardHash,
        championBundleHash: fixture.championBundleHash,
        challengerBundleHash: fixture.challengerBundleHash,
        createdAtMs: 101,
      );

      expect(verdict.status, 'insufficientEvidence');
    });
  }

  test('judge identity outside the frozen evaluation bundle is rejected', () {
    final fixture = _seedReleaseExecution(
      db,
      challengerScore: 99,
      tamperJudgeIdentity: true,
    );
    final verdict = _deriveVerdict(store, fixture);

    expect(verdict.status, 'insufficientEvidence');
    expect(verdict.reasonsJson, contains('qualityEvidenceInsufficient'));
  });

  test('quality scores bound to different prose cannot authorize release', () {
    final fixture = _seedReleaseExecution(
      db,
      challengerScore: 99,
      tamperProseBinding: true,
    );
    final verdict = _deriveVerdict(store, fixture);

    expect(verdict.status, 'insufficientEvidence');
    expect(verdict.reasonsJson, contains('qualityEvidenceInsufficient'));
  });

  test('changed quality score with stale external evidence is rejected', () {
    final fixture = _seedReleaseExecution(
      db,
      challengerScore: 99,
      tamperExternalScoreBinding: true,
    );
    final verdict = _deriveVerdict(store, fixture);

    expect(verdict.status, 'insufficientEvidence');
    expect(verdict.reasonsJson, contains('qualityEvidenceInsufficient'));
  });

  for (final forgery in <String>['underpriced', 'wrongRoute']) {
    test('self-consistent $forgery usage cannot authorize release', () {
      final fixture = _seedReleaseExecution(
        db,
        challengerScore: 99,
        forgeUnderpricedUsage: forgery == 'underpriced',
        forgeWrongRouteUsage: forgery == 'wrongRoute',
      );
      final verdict = _deriveVerdict(store, fixture);

      expect(verdict.status, 'insufficientEvidence');
      expect(verdict.reasonsJson, contains('performanceEvidenceInsufficient'));
    });
  }

  test('rehashed deterministic score cannot bypass authority receipt', () {
    final fixture = _seedReleaseExecution(
      db,
      challengerScore: 99,
      forgeDeterministicScore: true,
    );
    final verdict = _deriveVerdict(store, fixture);

    expect(verdict.status, 'insufficientEvidence');
    expect(verdict.reasonsJson, contains('qualityEvidenceInsufficient'));
  });

  test('per-trial judge calls cannot bypass execution evaluator budget', () {
    final fixture = _seedReleaseExecution(
      db,
      challengerScore: 99,
      underbudgetEvaluatorExecution: true,
    );
    final verdict = _deriveVerdict(store, fixture);

    expect(verdict.status, 'insufficientEvidence');
    expect(verdict.reasonsJson, contains('armEvidenceIncomplete'));
  });

  test('legacy v1 receipt remains fail-closed with a missing transaction', () {
    final fixture = _seedReleaseExecution(
      db,
      challengerScore: 99,
      omitOneTransactionGate: true,
    );
    final verdict = _deriveVerdict(store, fixture);

    expect(verdict.status, 'insufficientEvidence');
    expect(verdict.reasonsJson, contains('qualityEvidenceInsufficient'));
    expect(verdict.reasonsJson, contains('transactionFailed'));
  });
}

AgentEvaluationGateVerdictRecord _deriveVerdict(
  AgentEvaluationReleaseStore store,
  _Fixture fixture,
) {
  final scorecard = store.writeScorecard(
    executionId: fixture.executionId,
    scope: 'execution',
    scopeKey: fixture.executionId,
    aggregateJson: '{"status":"promote"}',
    aggregatorReleaseHash: fixture.aggregatorReleaseHash,
    expectedInputSetHash: store.computeInputSetHash(fixture.executionId),
    createdAtMs: 100,
  );
  return store.evaluateAndRecordGateVerdict(
    verdictKind: 'regression',
    experimentId: fixture.experimentId,
    executionId: fixture.executionId,
    scorecardHash: scorecard.scorecardHash,
    championBundleHash: fixture.championBundleHash,
    challengerBundleHash: fixture.challengerBundleHash,
    createdAtMs: 101,
  );
}

class _Fixture {
  const _Fixture({
    required this.experimentId,
    required this.executionId,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.aggregatorReleaseHash,
  });

  final String experimentId;
  final String executionId;
  final String championBundleHash;
  final String challengerBundleHash;
  final String aggregatorReleaseHash;
}

_Fixture _seedReleaseExecution(
  Database db, {
  required double challengerScore,
  bool omitOneQualityPair = false,
  bool tamperUsageEvidence = false,
  bool tamperQualityEvidence = false,
  bool tamperJudgeIdentity = false,
  bool tamperProseBinding = false,
  bool tamperExternalScoreBinding = false,
  bool omitOneTransactionGate = false,
  bool forgeUnderpricedUsage = false,
  bool forgeWrongRouteUsage = false,
  bool forgeDeterministicScore = false,
  bool underbudgetEvaluatorExecution = false,
}) {
  const experimentId = 'release-experiment-1';
  const executionId = 'release-execution-1';
  final champion = _digest('a');
  final challenger = _digest('b');
  final evaluationBundle = _digest('e');
  final scenarioSet = _digest('f');
  final model = _digest('1');
  final decoding = _digest('2');
  final rubric = _digest('3');
  final aggregator = _digest('4');
  final judgePrompt = _digest('5');
  final judgeModel = _digest('6');
  final safetyVerifier = _digest('c');
  final transactionVerifier =
      AgentEvaluationProductionTransactionPolicy.releaseHash;
  final priceTable = AgentEvaluationFrozenProviderPriceTable(
    tableId: 'gate-fixture-price-table',
    entries: <AgentEvaluationPriceEntry>[
      AgentEvaluationPriceEntry(
        modelRouteHash: model,
        model: 'gate-fixture-model',
        promptMicrousdPerMillionTokens: 500000,
        completionMicrousdPerMillionTokens: 500000,
      ),
      AgentEvaluationPriceEntry(
        modelRouteHash: judgeModel,
        model: 'gate-fixture-judge',
        promptMicrousdPerMillionTokens: 500000,
        completionMicrousdPerMillionTokens: 500000,
      ),
    ],
  );
  priceTable.publish(db, createdAtMs: 1);
  final verifiersJson = AgentEvaluationHashes.canonicalJson(<String>[
    'sha256:$safetyVerifier',
    'sha256:$transactionVerifier',
    for (final releaseHash
        in AgentEvaluationDeterministicQualityPolicy
            .verifierReleaseHashes
            .values)
      'sha256:$releaseHash',
  ]);
  final judgesJson = AgentEvaluationHashes.canonicalJson(<String, Object?>{
    'judgePromptReleases': <Object?>[
      <String, Object?>{
        'templateId': 'release-judge',
        'semanticVersion': '1.0.0',
        'language': 'zh',
        'contentHash': 'sha256:$judgePrompt',
      },
    ],
    'judgeModelRoutes': <String>['sha256:$judgeModel'],
  });
  db.execute(
    '''INSERT INTO generation_bundles (
         bundle_hash, bundle_id, releases_json, created_at_ms
       ) VALUES (?, 'champion', '[]', 1), (?, 'challenger', '[]', 1)''',
    <Object?>[champion, challenger],
  );
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'evaluation', ?, ?, ?, ?, ?, 'blind-v1', 1)''',
    <Object?>[
      evaluationBundle,
      verifiersJson,
      judgesJson,
      rubric,
      aggregator,
      _digest('7'),
    ],
  );
  db.execute(
    '''INSERT INTO eval_scenario_sets (
         scenario_set_release_hash, set_id, version, manifest_hash, created_at_ms
       ) VALUES (?, 'release-set', '1.0.0', ?, 1)''',
    <Object?>[scenarioSet, _digest('8')],
  );

  final cells = <({String id, String bundle, String scenario})>[];
  for (var scenarioIndex = 0; scenarioIndex < 7; scenarioIndex += 1) {
    final scenario = AgentEvaluationHashes.domainHash(
      'gate-test-scenario-v1',
      scenarioIndex,
    );
    db.execute(
      '''INSERT INTO eval_scenarios (
           scenario_release_hash, scenario_set_release_hash, scenario_id,
           version, fixture_hash, isolation_mode,
           verifier_release_refs_json, rubric_release_ref,
           expected_terminal_state, required_failure_codes_json,
           allowed_failure_codes_json, forbidden_failure_codes_json,
           outcome_comparator_release_ref, forbidden_side_effects_json,
           accept_expected, scenario_json, created_at_ms
         ) VALUES (?, ?, ?, '1.0.0', ?, 'independent', '[]', 'rubric-v1',
           'accepted', '[]', '[]', '[]', 'comparator-v1', '[]', 1, ?, 1)''',
      <Object?>[
        scenario,
        scenarioSet,
        'scenario-$scenarioIndex',
        AgentEvaluationHashes.domainHash('gate-test-fixture-v1', scenarioIndex),
        AgentEvaluationHashes.canonicalJson(<String, Object?>{
          'referenceFacts': <String, Object?>{},
          'adversarialMutations': <String>[],
          'maxBudget': <String, Object?>{'calls': 1, 'maxTokens': 200},
        }),
      ],
    );
    for (final bundle in <String>[champion, challenger]) {
      final cellId = AgentEvaluationReleaseStore.canonicalCellId(
        generationBundleHash: bundle,
        sutModelRouteHash: model,
        scenarioReleaseHash: scenario,
        decodingConfigHash: decoding,
      );
      cells.add((id: cellId, bundle: bundle, scenario: scenario));
      db.execute(
        '''INSERT INTO eval_cells (
             cell_id, generation_bundle_hash, sut_model_route_hash,
             scenario_release_hash, decoding_config_hash, created_at_ms
           ) VALUES (?, ?, ?, ?, ?, 1)''',
        <Object?>[cellId, bundle, model, scenario, decoding],
      );
    }
  }
  cells.sort((left, right) => left.id.compareTo(right.id));
  final cellIds = cells.map((cell) => cell.id).toList(growable: false);
  final cellSetHash = AgentEvaluationReleaseStore.canonicalCellSetHash(cellIds);
  final slotSetHash = AgentEvaluationReleaseStore.canonicalSlotSetHash(
    cellIds,
    3,
  );
  final manifestJson = AgentEvaluationHashes.canonicalJson(<String, Object?>{
    'priceTableHash': priceTable.releaseHash,
    'qualityComparisonPolicyHash': AgentEvaluationStandardGatePolicy.policyHash,
    'performanceSamplingPolicy': <String, Object?>{
      'pairing': 'canonical-by-model-scenario-decoding-trial-v1',
      'order': 'interleaved-randomized-v1',
      'minimumPairedSamples': 20,
    },
    'qualityThresholds': <String, Object?>{
      'claimScope': 'real-provider-release',
    },
    'budgets': <String, Object?>{
      'evaluatorCalls': underbudgetEvaluatorExecution ? 1 : cells.length * 3,
      'evaluatorTokens': cells.length * 3 * 200,
      'evaluatorCostMicrousd': cells.length * 3 * 100,
    },
  });
  db.execute(
    '''INSERT INTO eval_experiments (
         experiment_id, manifest_json, manifest_hash, scenario_set_release_hash,
         evaluation_bundle_hash, expected_cell_set_hash, expected_slot_set_hash,
         trials_per_cell, created_at_ms
       ) VALUES (?, ?, ?, ?, ?, ?, ?, 3, 1)''',
    <Object?>[
      experimentId,
      manifestJson,
      AgentEvaluationHashes.domainHash(
        'gate-test-manifest-v1',
        jsonDecode(manifestJson),
      ),
      scenarioSet,
      evaluationBundle,
      cellSetHash,
      slotSetHash,
    ],
  );
  for (var ordinal = 0; ordinal < cells.length; ordinal += 1) {
    db.execute(
      '''INSERT INTO eval_experiment_cells (experiment_id, cell_id, ordinal)
         VALUES (?, ?, ?)''',
      <Object?>[experimentId, cells[ordinal].id, ordinal],
    );
  }
  db.execute(
    '''INSERT INTO eval_executions (
         execution_id, experiment_id, status, expected_cell_set_hash,
         expected_slot_set_hash, created_at_ms, started_at_ms
       ) VALUES (?, ?, 'running', ?, ?, 1, 1)''',
    <Object?>[executionId, experimentId, cellSetHash, slotSetHash],
  );
  for (var ordinal = 0; ordinal < cells.length; ordinal += 1) {
    db.execute(
      '''INSERT INTO eval_execution_cells (execution_id, cell_id, ordinal)
         VALUES (?, ?, ?)''',
      <Object?>[executionId, cells[ordinal].id, ordinal],
    );
  }

  var omitted = false;
  var usageTampered = false;
  var qualityTampered = false;
  var externalScoreTampered = false;
  var transactionOmitted = false;
  for (final cell in cells) {
    for (var trialNo = 1; trialNo <= 3; trialNo += 1) {
      final slotId = AgentEvaluationReleaseStore.canonicalTrialSlotId(
        executionId: executionId,
        cellId: cell.id,
        trialNo: trialNo,
      );
      final contentDigest = AgentEvaluationHashes.domainHash(
        'gate-test-content-v1',
        <Object?>[cell.id, trialNo],
      );
      db.execute(
        '''INSERT INTO eval_trial_slots (
             trial_slot_id, execution_id, cell_id, trial_no, status, result,
             lease_epoch, lease_owner, lease_expires_at_ms,
             created_at_ms, updated_at_ms
           ) VALUES (?, ?, ?, ?, 'running', NULL, 1, 'worker-1', 1000, 1, 2)''',
        <Object?>[slotId, executionId, cell.id, trialNo],
      );
      db.execute(
        '''INSERT INTO eval_trial_attempts (
             trial_slot_id, attempt_no, run_id, kind, status, lease_epoch,
             lease_owner, started_at_ms, finished_at_ms
           ) VALUES (?, 1, ?, 'content', 'completed', 1, 'worker-1', 2, 8)''',
        <Object?>[slotId, '$slotId-run'],
      );
      final outcome = <String, Object?>{
        'terminalState': 'accepted',
        'failureCodes': <String>[],
        'accepted': true,
        'sideEffectCounts': <String, int>{},
        'evidenceComplete': true,
        'contentDigest': contentDigest,
        'independence': 'independent',
        'isolationTrialId': slotId,
        'cacheSourceTrialSlotId': null,
        'violations': <String>[],
      };
      final usageValue = AgentEvaluationAttemptUsage.frozen(
        priceTableHash: priceTable.releaseHash,
        providerCalls: <AgentEvaluationPricedProviderCall>[
          AgentEvaluationPricedProviderCall(
            sequenceNo: 1,
            modelRouteHash: forgeWrongRouteUsage ? _digest('f') : model,
            model: 'gate-fixture-model',
            promptTokens: 100,
            completionTokens: 100,
            succeeded: true,
            costMicrousd: forgeUnderpricedUsage ? 0 : 100,
          ),
          AgentEvaluationPricedProviderCall(
            sequenceNo: 2,
            modelRouteHash: judgeModel,
            model: 'gate-fixture-judge',
            promptTokens: 100,
            completionTokens: 100,
            succeeded: true,
            costMicrousd: 100,
            purpose: 'externalJudge',
          ),
        ],
      ).toJson();
      final usageEvidenceHash = AgentEvaluationHashes.domainHash(
        'eval-attempt-usage-observation-v1',
        <String, Object?>{
          'trialSlotId': slotId,
          'attemptNo': 1,
          'value': usageValue,
        },
      );
      _insertObservation(
        db,
        slotId: slotId,
        sequenceNo: 0,
        stageId: 'outcome',
        kind: 'comparison',
        itemKey: 'singleton',
        value: outcome,
        evidenceHash: AgentEvaluationHashes.domainHash(
          'eval-outcome-observation-v1',
          outcome,
        ),
        evaluationBundleHash: evaluationBundle,
        proseHash: contentDigest,
      );
      _insertObservation(
        db,
        slotId: slotId,
        sequenceNo: 1,
        stageId: 'performance',
        kind: 'usage',
        itemKey: 'singleton',
        value: usageValue,
        evidenceHash: tamperUsageEvidence && !usageTampered
            ? _digest('0')
            : usageEvidenceHash,
        evaluationBundleHash: evaluationBundle,
        proseHash: contentDigest,
      );
      usageTampered = usageTampered || tamperUsageEvidence;
      var sequenceNo = 2;
      final dimensions =
          AgentEvaluationStandardGatePolicy.requiredQualityDimensions.toList()
            ..sort();
      final score = cell.bundle == champion ? 99.0 : challengerScore;
      final scores = <String, int>{
        for (final dimension in dimensions)
          dimension: (score * 1000000).round(),
        'characterConsistency': 0,
        'canonMemory': 0,
        'robustness': 0,
        'efficiency': 50000000,
      };
      final deterministicInputs = <String, Object?>{
        'schemaVersion': 'eval-deterministic-quality-inputs-v1',
        'scenarioReleaseHash': cell.scenario,
        'referenceFactsHash': AgentEvaluationHashes.domainHash(
          'eval-quality-reference-facts-v1',
          <String, Object?>{},
        ),
        'proof': <String, Object?>{
          'candidateHash': 'sha256:${_digest('a')}',
          'deterministicGateEvidenceHash': 'sha256:${_digest('b')}',
          'finalCouncilEvidenceHash': 'sha256:${_digest('c')}',
          'qualityEvidenceHash': 'sha256:${_digest('d')}',
        },
        'characterEvidence': <String, Object?>{
          'requiredNameHashes': <String>[],
          'matchedNameHashes': <String>[],
          'structuredStateRootHash': AgentEvaluationHashes.domainHash(
            'eval-character-structured-state-root-v1',
            <Object?>[],
          ),
        },
        'canonEvidence': <String, Object?>{
          'requiredRootSourceIdHashes': <String>[],
          'matchedRootSourceIdHashes': <String>[],
          'committedProvenanceRootHash': AgentEvaluationHashes.domainHash(
            'eval-canon-committed-provenance-root-v1',
            <Object?>[],
          ),
        },
        'adversarialMutations': <String>[],
        'recoveryEventHashes': <String>[],
        'usage': <String, Object?>{
          'calls': 1,
          'tokens': 200,
          'maxCalls': 1,
          'maxTokens': 200,
        },
        'verifierReleaseHashes':
            AgentEvaluationDeterministicQualityPolicy.verifierReleaseHashes,
      };
      final deterministicScores = <String, int>{
        'characterConsistency': scores['characterConsistency']!,
        'canonMemory': scores['canonMemory']!,
        'robustness': scores['robustness']!,
        'efficiency': scores['efficiency']!,
      };
      final deterministicReceiptValue = <String, Object?>{
        'authorityReleaseHash':
            AgentEvaluationDeterministicQualityPolicy.authorityReleaseHash,
        'executionId': executionId,
        'trialSlotId': slotId,
        'attemptNo': 1,
        'evaluationBundleHash': evaluationBundle,
        'proseHash': contentDigest,
        'inputs': deterministicInputs,
        'scores': deterministicScores,
      };
      final deterministicReceiptHash = AgentEvaluationHashes.domainHash(
        'eval-deterministic-quality-receipt-v1',
        deterministicReceiptValue,
      );
      db.execute(
        '''INSERT INTO eval_deterministic_quality_receipts (
             receipt_hash, authority_release_hash, execution_id,
             trial_slot_id, attempt_no, evaluation_bundle_hash, prose_hash,
             inputs_json, scores_json, created_at_ms
           ) VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?, 7)''',
        <Object?>[
          deterministicReceiptHash,
          AgentEvaluationDeterministicQualityPolicy.authorityReleaseHash,
          executionId,
          slotId,
          evaluationBundle,
          contentDigest,
          AgentEvaluationHashes.canonicalJson(deterministicInputs),
          AgentEvaluationHashes.canonicalJson(deterministicScores),
        ],
      );
      if (forgeDeterministicScore &&
          cell.bundle == challenger &&
          trialNo == 1) {
        scores['robustness'] = 100000000;
      }
      final usedProseHash = tamperProseBinding ? _digest('0') : contentDigest;
      final usedJudgePrompt = tamperJudgeIdentity ? _digest('0') : judgePrompt;
      final judgeOutputHash = _digest('d');
      final boundScores = Map<String, int>.of(scores);
      if (tamperExternalScoreBinding && !externalScoreTampered) {
        boundScores[dimensions.first] =
            boundScores[dimensions.first]! - 1000000;
        externalScoreTampered = true;
      }
      final externalEvidenceHash =
          AgentEvaluationQualityEvidence.calculateExternalEvidenceHash(
            scoreMicrosByDimension: boundScores,
            judgePromptReleaseHash: usedJudgePrompt,
            judgeModelRouteHash: judgeModel,
            rubricReleaseHash: rubric,
            aggregatorReleaseHash: aggregator,
            evaluatedContentHash: usedProseHash,
            externalJudgeOutputHash: judgeOutputHash,
            deterministicQualityReceiptHash: deterministicReceiptHash,
          );
      for (final dimension in dimensions) {
        if (omitOneQualityPair &&
            !omitted &&
            cell.bundle == challenger &&
            trialNo == 1) {
          omitted = true;
          sequenceNo += 1;
          continue;
        }
        final qualityValue = <String, Object?>{
          'schemaVersion': 'eval-quality-dimension-v1',
          'scoreMicros': scores[dimension],
          'judgePromptReleaseHash': usedJudgePrompt,
          'judgeModelRouteHash': judgeModel,
          'rubricReleaseHash': rubric,
          'aggregatorReleaseHash': aggregator,
          'evaluatedContentHash': usedProseHash,
          'externalJudgeOutputHash': judgeOutputHash,
          'externalEvaluationEvidenceHash': externalEvidenceHash,
          'deterministicQualityReceiptHash': deterministicReceiptHash,
        };
        final qualityEvidenceHash = AgentEvaluationHashes.domainHash(
          'eval-quality-dimension-observation-v1',
          <String, Object?>{
            'trialSlotId': slotId,
            'attemptNo': 1,
            'dimensionId': dimension,
            'proseHash': usedProseHash,
            'evaluationBundleHash': evaluationBundle,
            'value': qualityValue,
          },
        );
        _insertObservation(
          db,
          slotId: slotId,
          sequenceNo: sequenceNo++,
          stageId: 'quality',
          kind: 'dimension',
          itemKey: dimension,
          value: qualityValue,
          evidenceHash: tamperQualityEvidence && !qualityTampered
              ? _digest('0')
              : qualityEvidenceHash,
          evaluationBundleHash: evaluationBundle,
          proseHash: tamperProseBinding ? _digest('0') : contentDigest,
        );
        qualityTampered = qualityTampered || tamperQualityEvidence;
      }
      for (final gateKind in <String>['safety', 'transaction']) {
        if (omitOneTransactionGate &&
            !transactionOmitted &&
            gateKind == 'transaction') {
          transactionOmitted = true;
          continue;
        }
        final value = <String, Object?>{
          'schemaVersion': gateKind == 'safety'
              ? 'eval-safety-gate-v1'
              : 'eval-transaction-gate-v1',
          'passed': true,
          'verifierReleaseHash': gateKind == 'safety'
              ? safetyVerifier
              : transactionVerifier,
          'verifierEvidenceHash': gateKind == 'safety'
              ? _digest('1')
              : _digest('2'),
        };
        final evidenceHash = AgentEvaluationHashes.domainHash(
          'eval-hard-gate-observation-v1',
          <String, Object?>{
            'trialSlotId': slotId,
            'attemptNo': 1,
            'gateKind': gateKind,
            'proseHash': contentDigest,
            'evaluationBundleHash': evaluationBundle,
            'value': value,
          },
        );
        _insertObservation(
          db,
          slotId: slotId,
          sequenceNo: sequenceNo++,
          stageId: 'hard-gate',
          kind: gateKind,
          itemKey: 'singleton',
          value: value,
          evidenceHash: evidenceHash,
          evaluationBundleHash: evaluationBundle,
          proseHash: contentDigest,
        );
      }
      _insertProductionObservation(
        db,
        slotId: slotId,
        runId: '$slotId-run',
        bundleHash: cell.bundle,
        proseHash: contentDigest,
        evaluationBundleHash: evaluationBundle,
      );
      db.execute(
        '''UPDATE eval_trial_slots SET status = 'sealed', result = 'pass',
             lease_owner = NULL, lease_expires_at_ms = NULL,
             sealed_evidence_hash = ?, updated_at_ms = 10, sealed_at_ms = 10
           WHERE trial_slot_id = ?''',
        <Object?>[_digest('9'), slotId],
      );
    }
  }
  AgentEvaluationLedger(db: db).createOrValidateExecution(
    executionId: executionId,
    experimentId: experimentId,
    cells: cells
        .map(
          (cell) => AgentEvaluationCellDefinition(
            generationBundleHash: cell.bundle,
            sutModelRouteHash: model,
            scenarioReleaseHash: cell.scenario,
            decodingConfigHash: decoding,
          ),
        )
        .toList(growable: false),
    createdAtMs: 1,
  );
  _seedDispatchHistory(db, executionId: executionId);
  return _Fixture(
    experimentId: experimentId,
    executionId: executionId,
    championBundleHash: champion,
    challengerBundleHash: challenger,
    aggregatorReleaseHash: aggregator,
  );
}

void _insertProductionObservation(
  Database db, {
  required String slotId,
  required String runId,
  required String bundleHash,
  required String proseHash,
  required String evaluationBundleHash,
}) {
  final slot = db
      .select(
        '''SELECT execution_id, lease_epoch, lease_owner
       FROM eval_trial_slots WHERE trial_slot_id = ?''',
        <Object?>[slotId],
      )
      .single;
  final authorityReceiptHash = AgentEvaluationHashes.domainHash(
    'test-production-authority-receipt-v1',
    slotId,
  );
  db.execute(
    '''INSERT INTO eval_production_authority_receipts (
         authority_receipt_hash, authority_release_hash, execution_id,
         trial_slot_id, attempt_no, attempt_run_id, sandbox_database_path,
         candidate_hash, commit_receipt_id, transaction_evidence_hash,
         prose_hash, generation_bundle_hash, executor_release_hash,
         lease_epoch, lease_owner, created_at_ms
       ) VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 8)''',
    <Object?>[
      authorityReceiptHash,
      AgentEvaluationProductionDatabaseAuthority.releaseHash,
      slot['execution_id'],
      slotId,
      runId,
      '/fixture/$slotId.sqlite',
      _digest('a'),
      '$slotId-receipt',
      _digest('b'),
      proseHash,
      bundleHash,
      AgentEvaluationProductionExecutorPolicy.releaseHash,
      slot['lease_epoch'],
      slot['lease_owner'],
    ],
  );
  final value = <String, Object?>{
    'schemaVersion': 'eval-production-receipt-v2',
    'authorityReceiptHash': authorityReceiptHash,
    'authorityReleaseHash':
        AgentEvaluationProductionDatabaseAuthority.releaseHash,
    'executorReleaseHash': AgentEvaluationProductionExecutorPolicy.releaseHash,
    'attemptRunId': runId,
    'storyRunId': runId,
    'candidateHash': _digest('a'),
    'receiptId': '$slotId-receipt',
    'transactionEvidenceHash': _digest('b'),
    'proseHash': proseHash,
    'generationBundleHash': bundleHash,
  };
  _insertObservation(
    db,
    slotId: slotId,
    sequenceNo: 10,
    stageId: 'production',
    kind: 'receipt',
    itemKey: 'singleton',
    value: value,
    evidenceHash: AgentEvaluationHashes.domainHash(
      'eval-production-receipt-observation-v2',
      <String, Object?>{'trialSlotId': slotId, 'attemptNo': 1, 'value': value},
    ),
    evaluationBundleHash: evaluationBundleHash,
    proseHash: proseHash,
  );
}

void _seedDispatchHistory(Database db, {required String executionId}) {
  final entries = db.select(
    '''SELECT * FROM eval_dispatch_entries WHERE execution_id = ?
       ORDER BY dispatch_ordinal''',
    <Object?>[executionId],
  );
  String? previousHash;
  var eventOrdinal = 0;
  for (final entry in entries) {
    final slotId = entry['trial_slot_id'] as String;
    for (final event
        in <
          ({
            String type,
            int? expiry,
            String? evidence,
            int? attemptNo,
            String? runId,
            int occurredAt,
          })
        >[
          (
            type: 'claimed',
            expiry: 1000,
            evidence: null,
            attemptNo: null,
            runId: null,
            occurredAt: 1,
          ),
          (
            type: 'attemptStarted',
            expiry: 1000,
            evidence: null,
            attemptNo: 1,
            runId: '$slotId-run',
            occurredAt: 2,
          ),
          (
            type: 'sealed',
            expiry: null,
            evidence: _digest('9'),
            attemptNo: null,
            runId: null,
            occurredAt: 10,
          ),
        ]) {
      final hash = AgentEvaluationDispatchPlanner.canonicalEventHash(
        executionId: executionId,
        eventOrdinal: eventOrdinal,
        dispatchOrdinal: entry['dispatch_ordinal'] as int,
        trialSlotId: slotId,
        eventType: event.type,
        leaseEpoch: 1,
        leaseOwner: 'worker-1',
        leaseExpiresAtMs: event.expiry,
        sealedEvidenceHash: event.evidence,
        attemptNo: event.attemptNo,
        runId: event.runId,
        occurredAtMs: event.occurredAt,
        previousEventHash: previousHash,
      );
      db.execute(
        '''INSERT INTO eval_dispatch_events (
             event_hash, execution_id, event_ordinal, dispatch_ordinal,
             trial_slot_id, event_type, lease_epoch, lease_owner,
             lease_expires_at_ms, sealed_evidence_hash, attempt_no, run_id,
             occurred_at_ms, previous_event_hash
           ) VALUES (?, ?, ?, ?, ?, ?, 1, 'worker-1', ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          hash,
          executionId,
          eventOrdinal,
          entry['dispatch_ordinal'],
          slotId,
          event.type,
          event.expiry,
          event.evidence,
          event.attemptNo,
          event.runId,
          event.occurredAt,
          previousHash,
        ],
      );
      previousHash = hash;
      eventOrdinal += 1;
    }
  }
}

void _insertObservation(
  Database db, {
  required String slotId,
  required int sequenceNo,
  required String stageId,
  required String kind,
  required String itemKey,
  required Map<String, Object?> value,
  required String evidenceHash,
  required String evaluationBundleHash,
  required String proseHash,
}) {
  db.execute(
    '''INSERT INTO eval_observations (
         observation_id, trial_slot_id, attempt_no, sequence_no, stage_id,
         kind, item_key, value_json, evidence_hash, evaluation_bundle_hash,
         prose_hash, lease_epoch, lease_owner, created_at_ms
       ) VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, 1, 'worker-1', 8)''',
    <Object?>[
      '$slotId-$sequenceNo',
      slotId,
      sequenceNo,
      stageId,
      kind,
      itemKey,
      AgentEvaluationHashes.canonicalJson(value),
      evidenceHash,
      evaluationBundleHash,
      proseHash,
    ],
  );
}

String _digest(String value) => List<String>.filled(64, value).join();
