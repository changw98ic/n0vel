import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_holdout_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_holdout_reuse_authority.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';

void main() {
  late Database db;
  late AgentEvaluationTrustedHoldoutSigner signer;
  late AgentEvaluationTrustedHoldoutVerifier verifier;
  late AgentEvaluationProductionHoldoutProjection projection;

  setUp(() async {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    signer = await AgentEvaluationTrustedHoldoutSigner.fromSeed(
      keyId: 'production-holdout-key',
      seed: List<int>.generate(32, (index) => index + 3),
    );
    verifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: signer.keyId,
      publicKey: signer.publicKey,
      runnerReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
    );
    _seedAuthority(db, verifier);
    projection = _projection();
  });

  tearDown(() => db.dispose());

  test('V23 freezes distinct regression and opaque holdout authorities', () {
    expect(
      db.select('PRAGMA user_version').single['user_version'],
      authoringSchemaMigrations.last.version,
    );
    final family = db
        .select(
          'SELECT * FROM eval_experiment_families '
          "WHERE family_id = 'family-v23'",
        )
        .single;
    expect(family['scenario_set_release_hash'], _digest('1'));
    expect(family['opaque_holdout_scenario_set_hash'], _digest('2'));
    expect(family['private_plan_hash'], _digest('3'));
    expect(
      () => db.execute(
        'UPDATE eval_experiment_families SET private_plan_hash = ? '
        "WHERE family_id = 'family-v23'",
        <Object?>[_digest('4')],
      ),
      throwsA(isA<SqliteException>()),
    );
    final holdout = AgentEvaluationHoldoutStore(
      db: db,
      trustedHoldoutVerifier: verifier,
    );
    expect(
      () => holdout.createProductionFamily(
        familyId: 'family-v23-reset-attempt',
        productionAuthorityHash: _digest('a'),
        regressionScenarioSetHash: _digest('1'),
        opaqueHoldoutScenarioSetHash: _digest('2'),
        privatePlanHash: _digest('3'),
        holdoutAccessPolicyHash: verifier.trustPolicyHash,
        maxAccesses: 1,
        alphaBudgetMicros: 50000,
        createdAtMs: 2,
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
  });

  test(
    'signed V2 projection imports atomically without private material',
    () async {
      const sentinel = 'PRIVATE-PROMPT-FACT-SENTINEL';
      final signed = await signer.signProduction(
        _unsignedAttestation(projection),
      );
      final importer = AgentEvaluationProductionHoldoutImporter(
        db: db,
        verifier: verifier,
      );

      final claim = await importer.import(
        attestation: signed,
        projection: projection,
      );

      expect(claim.claimHash, signed.claimHash);
      final row = db.select(
        'SELECT * FROM eval_production_holdout_claims WHERE claim_hash = ?',
        <Object?>[claim.claimHash],
      ).single;
      expect(row['result'], 'pass');
      expect(row['private_scorecard_hash'], _digest('8'));
      expect(row['private_gate_verdict_hash'], _digest('9'));
      expect(row['private_projection_hash'], _digest('a'));
      expect(row.values.join(' '), isNot(contains(sentinel)));
      expect(
        db
            .select(
              'SELECT state FROM eval_production_holdout_accesses '
              "WHERE access_id = 'access-v23'",
            )
            .single['state'],
        'imported',
      );
      expect(
        () => db.execute(
          'UPDATE eval_production_holdout_claims SET result = \'fail\' '
          'WHERE claim_hash = ?',
          <Object?>[claim.claimHash],
        ),
        throwsA(isA<SqliteException>()),
      );
    },
  );

  test(
    'promote rollback conflict leaves epoch zero and no half decision',
    () async {
      final signed = await signer.signProduction(
        _unsignedAttestation(projection),
      );
      final claim = await AgentEvaluationProductionHoldoutImporter(
        db: db,
        verifier: verifier,
      ).import(attestation: signed, projection: projection);
      final release = AgentEvaluationReleaseStore(
        db: db,
        trustedHoldoutVerifier: verifier,
      );
      release.initializeChannelHead(
        channel: 'atomic-failure',
        bundleHash: _digest('b'),
        createdAtMs: 10,
      );

      await expectLater(
        release.exercisePromoteThenRollbackVerified(
          promotionDecisionId: 'same-decision-id',
          rollbackDecisionId: 'same-decision-id',
          channel: 'atomic-failure',
          expectedBundleHash: _digest('b'),
          expectedEpoch: 0,
          challengerBundleHash: _digest('c'),
          experimentId: 'regression-v23',
          regressionVerdictHash: _digest('d'),
          productionHoldoutClaimHash: claim.claimHash,
          approver: 'atomic-test',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
        throwsA(isA<AgentEvaluationPromotionConflict>()),
      );

      final head = release.readChannelHead('atomic-failure');
      expect(head.bundleHash, _digest('b'));
      expect(head.epoch, 0);
      expect(release.readDecisions('atomic-failure'), isEmpty);
      expect(
        db.select(
          'SELECT * FROM prompt_release_decision_production_authorizations',
        ),
        isEmpty,
      );
    },
  );

  test(
    'promote and rollback commit two decisions and epoch two together',
    () async {
      final signed = await signer.signProduction(
        _unsignedAttestation(projection),
      );
      final claim = await AgentEvaluationProductionHoldoutImporter(
        db: db,
        verifier: verifier,
      ).import(attestation: signed, projection: projection);
      final release = AgentEvaluationReleaseStore(
        db: db,
        trustedHoldoutVerifier: verifier,
      );
      release.initializeChannelHead(
        channel: 'atomic-success',
        bundleHash: _digest('b'),
        createdAtMs: 10,
      );

      final result = await release.exercisePromoteThenRollbackVerified(
        promotionDecisionId: 'atomic-promote',
        rollbackDecisionId: 'atomic-rollback',
        channel: 'atomic-success',
        expectedBundleHash: _digest('b'),
        expectedEpoch: 0,
        challengerBundleHash: _digest('c'),
        experimentId: 'regression-v23',
        regressionVerdictHash: _digest('d'),
        productionHoldoutClaimHash: claim.claimHash,
        approver: 'atomic-test',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );

      expect(result.promoted.epoch, 1);
      expect(result.rolledBack.epoch, 2);
      final head = release.readChannelHead('atomic-success');
      expect(head.bundleHash, _digest('b'));
      expect(head.epoch, 2);
      expect(
        release.readDecisions('atomic-success').map((item) => item.action),
        orderedEquals(<String>['promote', 'rollback']),
      );
      expect(
        db.select(
          'SELECT * FROM prompt_release_decision_production_authorizations',
        ),
        hasLength(1),
      );
      final reuseProjection = AgentEvaluationHoldoutReuseAuthority.read(
        db: db,
        claimHash: claim.claimHash,
      );
      expect(reuseProjection.familyCount, 1);
      expect(reuseProjection.tokenCount, 1);
      expect(reuseProjection.accessCount, 1);
      expect(reuseProjection.claimCount, 1);
      expect(reuseProjection.authorizationCount, 1);
      expect(reuseProjection.legacyConfirmationCount, 0);
      expect(reuseProjection.projectionHash, hasLength(64));
    },
  );

  test(
    'tampered signed result and projection fail without partial import',
    () async {
      final signed = await signer.signProduction(
        _unsignedAttestation(projection),
      );
      final importer = AgentEvaluationProductionHoldoutImporter(
        db: db,
        verifier: verifier,
      );

      await expectLater(
        importer.import(
          attestation: signed.copyWith(result: 'fail'),
          projection: projection,
        ),
        throwsA(isA<AgentEvaluationProductionHoldoutException>()),
      );
      expect(
        db.select('SELECT * FROM eval_production_holdout_claims'),
        isEmpty,
      );
      expect(
        db
            .select(
              'SELECT state FROM eval_production_holdout_accesses '
              "WHERE access_id = 'access-v23'",
            )
            .single['state'],
        'begun',
      );
    },
  );

  test('redacted projection rejects private fields and free-form leakage', () {
    expect(
      () => AgentEvaluationProductionHoldoutProjection(
        executionSummary: <String, Object?>{
          ...projection.executionSummary,
          'prompt': 'PRIVATE-PROMPT-FACT-SENTINEL',
        },
        scorecard: projection.scorecard,
        gateVerdict: projection.gateVerdict,
      ),
      throwsFormatException,
    );
    expect(
      () => AgentEvaluationProductionHoldoutProjection(
        executionSummary: projection.executionSummary,
        scorecard: projection.scorecard,
        gateVerdict: <String, Object?>{
          ...projection.gateVerdict,
          'reasonCodes': <String>['private fact: sentinel'],
        },
      ),
      throwsFormatException,
    );
  });

  test('first import after the signed TTL is rejected atomically', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = await signer.signProduction(
      _unsignedAttestation(
        projection,
        issuedAtMs: now - 2000,
        expiresAtMs: now - 1000,
      ),
    );
    final importer = AgentEvaluationProductionHoldoutImporter(
      db: db,
      verifier: verifier,
    );

    await expectLater(
      importer.import(attestation: expired, projection: projection),
      throwsA(isA<AgentEvaluationProductionHoldoutException>()),
    );
    expect(db.select('SELECT * FROM eval_production_holdout_claims'), isEmpty);
    expect(
      db
          .select(
            'SELECT state FROM eval_production_holdout_accesses '
            "WHERE access_id = 'access-v23'",
          )
          .single['state'],
      'begun',
    );
  });

  test('strict parser rejects caller-added evaluator or timestamp fields', () {
    final unsigned = _unsignedAttestation(projection);
    final payload = <String, Object?>{
      ...unsigned.payload,
      'evaluator': 'caller-selected',
      'createdAtMs': 0,
    };
    expect(
      () => AgentEvaluationProductionHoldoutAttestation.fromStorage(
        payloadJson: jsonEncode(payload),
        signatureBase64: 'forged',
      ),
      throwsFormatException,
    );
  });

  test('V1 exact-reference confirmation is never promotion evidence', () async {
    final store = AgentEvaluationReleaseStore(
      db: db,
      trustedHoldoutVerifier: verifier,
    );
    await expectLater(
      store.promoteVerified(
        decisionId: 'legacy-v1-promotion',
        channel: 'stable',
        expectedBundleHash: _digest('b'),
        expectedEpoch: 0,
        challengerBundleHash: _digest('c'),
        experimentId: 'regression-v23',
        regressionVerdictHash: _digest('d'),
        holdoutConfirmationId: 'legacy-exact-reference-confirmation',
        approver: 'release-bot',
        createdAtMs: 0,
      ),
      throwsA(
        isA<AgentEvaluationPromotionConflict>().having(
          (error) => error.message,
          'message',
          contains('not release eligible'),
        ),
      ),
    );
  });
}

AgentEvaluationProductionHoldoutProjection _projection() =>
    AgentEvaluationProductionHoldoutProjection(
      executionSummary: <String, Object?>{
        'schemaVersion': 'production-holdout-redacted-execution-summary-v1',
        'status': 'completed',
        'releaseConfigurationHash': _digest('2'),
        'executionCommitmentHash': _digest('7'),
        'expectedSlotCount': 60,
        'completedSlotCount': 60,
      },
      scorecard: <String, Object?>{
        'schemaVersion': 'production-holdout-redacted-scorecard-v1',
        'inputSetHash': _digest('6'),
        'expectedCellSetHash': _digest('4'),
        'expectedSlotSetHash': _digest('5'),
        'aggregateCommitmentHash': _digest('8'),
      },
      gateVerdict: <String, Object?>{
        'schemaVersion': 'production-holdout-redacted-gate-v1',
        'status': 'promote',
        'scorecardHash': _digest('8'),
        'projectionHash': _digest('a'),
        'policyHash': AgentEvaluationStandardGatePolicy.policyHash,
        'reasonCodes': <String>['all-gates-pass'],
      },
    );

AgentEvaluationProductionHoldoutAttestation _unsignedAttestation(
  AgentEvaluationProductionHoldoutProjection projection, {
  int? issuedAtMs,
  int? expiresAtMs,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return AgentEvaluationProductionHoldoutAttestation(
    familyId: 'family-v23',
    tokenId: 'token-v23',
    accessId: 'access-v23',
    regressionVerdictHash: _digest('d'),
    championBundleHash: _digest('b'),
    challengerBundleHash: _digest('c'),
    regressionScenarioSetHash: _digest('1'),
    opaqueHoldoutScenarioSetHash: _digest('2'),
    privatePlanHash: _digest('3'),
    productionManifestHash: _digest('e'),
    privateExecutionSummaryHash: _digest('7'),
    privateScorecardHash: _digest('8'),
    privateGateVerdictHash: _digest('9'),
    privateProjectionHash: _digest('a'),
    redactedExecutionSummaryHash: projection.executionSummaryHash,
    redactedScorecardHash: projection.scorecardHash,
    redactedGateVerdictHash: projection.gateVerdictHash,
    expectedCellSetHash: _digest('4'),
    expectedSlotSetHash: _digest('5'),
    executionBudgetPolicyHash: _digest('f'),
    executorReleaseHash: _digest('0'),
    evaluationBundleHash: _digest('e'),
    priceTableHash: _digest('f'),
    gatePolicyHash: AgentEvaluationStandardGatePolicy.policyHash,
    auditRootHash: _digest('6'),
    result: 'pass',
    runnerReleaseHash: AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
    resolverReleaseHash:
        AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
    keyId: 'production-holdout-key',
    nonce: 'production-v23-nonce',
    issuedAtMs: issuedAtMs ?? now - 1000,
    expiresAtMs: expiresAtMs ?? now + 60000,
    signatureBase64: 'unsigned',
  );
}

void _seedAuthority(
  Database db,
  AgentEvaluationTrustedHoldoutVerifier verifier,
) {
  db.execute(
    '''INSERT INTO generation_bundles
       (bundle_hash, bundle_id, releases_json, created_at_ms)
       VALUES (?, 'champion-v23', '[]', 1),
              (?, 'challenger-v23', '[]', 1)''',
    <Object?>[_digest('b'), _digest('c')],
  );
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'eval-v23', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    <Object?>[_digest('e'), _digest('1'), _digest('2'), _digest('3')],
  );
  db.execute(
    '''INSERT INTO eval_scenario_sets (
         scenario_set_release_hash, set_id, version, manifest_hash,
         created_at_ms
       ) VALUES (?, 'regression-v23', '1', ?, 1)''',
    <Object?>[_digest('1'), _digest('2')],
  );
  db.execute(
    '''INSERT INTO eval_experiments (
         experiment_id, manifest_json, manifest_hash,
         scenario_set_release_hash, evaluation_bundle_hash,
         expected_cell_set_hash, expected_slot_set_hash, trials_per_cell,
         created_at_ms
       ) VALUES ('regression-v23', '{}', ?, ?, ?, ?, ?, 3, 1)''',
    <Object?>[
      _digest('a'),
      _digest('1'),
      _digest('e'),
      _digest('4'),
      _digest('5'),
    ],
  );
  db.execute(
    '''INSERT INTO eval_executions (
         execution_id, experiment_id, status, expected_cell_set_hash,
         expected_slot_set_hash, created_at_ms, started_at_ms, finished_at_ms
       ) VALUES ('regression-execution-v23', 'regression-v23', 'completed',
         ?, ?, 1, 2, 3)''',
    <Object?>[_digest('4'), _digest('5')],
  );
  db.execute(
    '''INSERT INTO eval_scorecards (
         scorecard_hash, execution_id, scope, scope_key, aggregate_json,
         input_set_hash, expected_set_hash, aggregator_release_hash,
         created_at_ms
       ) VALUES (?, 'regression-execution-v23', 'execution',
         'regression-execution-v23', '{}', ?, ?, ?, 3)''',
    <Object?>[_digest('7'), _digest('6'), _digest('5'), _digest('2')],
  );
  db.execute(
    '''INSERT INTO eval_release_gate_verdicts (
         verdict_hash, verdict_kind, experiment_id, execution_id,
         scorecard_hash, champion_bundle_hash, challenger_bundle_hash,
         status, reasons_json, comparison_input_set_hash,
         expected_pair_set_hash, policy_hash, gate_release_hash,
         created_at_ms
       ) VALUES (?, 'regression', 'regression-v23',
         'regression-execution-v23', ?, ?, ?, 'promote', '[]', ?, ?, ?, ?, 4)''',
    <Object?>[
      _digest('d'),
      _digest('7'),
      _digest('b'),
      _digest('c'),
      _digest('6'),
      _digest('5'),
      AgentEvaluationStandardGatePolicy.policyHash,
      AgentEvaluationStandardGatePolicy.gateReleaseHash,
    ],
  );
  db.execute(
    '''INSERT INTO eval_release_gate_derivations (
         verdict_hash, projection_hash, authority_release_hash, created_at_ms
       ) VALUES (?, ?, ?, 4)''',
    <Object?>[
      _digest('d'),
      _digest('a'),
      AgentEvaluationStandardGatePolicy.gateReleaseHash,
    ],
  );
  db.execute(
    '''INSERT INTO eval_price_table_releases (
         price_table_hash, table_id, currency, entries_json,
         rounding_policy, created_at_ms
       ) VALUES (?, 'price-v23', 'USD', '{}',
         'ceil-per-attempt-microusd-v1', 1)''',
    <Object?>[_digest('f')],
  );

  final holdout = AgentEvaluationHoldoutStore(
    db: db,
    trustedHoldoutVerifier: verifier,
  );
  holdout.createProductionFamily(
    familyId: 'family-v23',
    productionAuthorityHash: _digest('a'),
    regressionScenarioSetHash: _digest('1'),
    opaqueHoldoutScenarioSetHash: _digest('2'),
    privatePlanHash: _digest('3'),
    holdoutAccessPolicyHash: verifier.trustPolicyHash,
    maxAccesses: 1,
    alphaBudgetMicros: 50000,
    createdAtMs: 1,
  );
  holdout.registerChallenger(
    familyId: 'family-v23',
    challengerBundleHash: _digest('c'),
    registeredAtMs: 1,
  );
  holdout.issueToken(
    tokenId: 'token-v23',
    familyId: 'family-v23',
    challengerBundleHash: _digest('c'),
    regressionVerdictHash: _digest('d'),
    alphaCostMicros: 50000,
    issuedAtMs: 2,
  );
  holdout.beginProductionHoldoutAccess(
    accessId: 'access-v23',
    tokenId: 'token-v23',
    challengerBundleHash: _digest('c'),
  );
}

String _digest(String value) => value * 64;
