import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';

void main() {
  late Directory tempDirectory;
  late String databasePath;
  late Database db;
  late AgentEvaluationReleaseStore store;
  late AgentEvaluationTrustedHoldoutSigner holdoutSigner;
  late AgentEvaluationTrustedHoldoutVerifier holdoutVerifier;
  late _Fixture fixture;

  setUp(() async {
    tempDirectory = Directory.systemTemp.createTempSync('agent-release-store-');
    databasePath = '${tempDirectory.path}/authoring.sqlite';
    db = sqlite3.open(databasePath);
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    fixture = _seedExecution(db);
    holdoutSigner = await AgentEvaluationTrustedHoldoutSigner.fromSeed(
      keyId: 'holdout-test-key',
      seed: List<int>.generate(32, (index) => index + 1),
    );
    holdoutVerifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: holdoutSigner.keyId,
      publicKey: holdoutSigner.publicKey,
      runnerReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
    );
    store = AgentEvaluationReleaseStore(
      db: db,
      trustedHoldoutVerifier: holdoutVerifier,
    );
  });

  tearDown(() {
    db.dispose();
    tempDirectory.deleteSync(recursive: true);
  });

  test('rejects missing, unsealed, and polluted canonical slot sets', () {
    _insertSlot(db, fixture: fixture, trialNo: 1, sealed: true);
    expect(
      () => _writeScorecard(store),
      throwsA(isA<AgentEvaluationScorecardConflict>()),
    );

    _insertSlot(db, fixture: fixture, trialNo: 2, sealed: false);
    expect(
      () => _writeScorecard(store),
      throwsA(isA<AgentEvaluationScorecardConflict>()),
    );

    db.execute(
      '''UPDATE eval_trial_slots
         SET status = 'sealed', result = 'pass', lease_owner = NULL,
           lease_expires_at_ms = NULL, sealed_evidence_hash = ?,
           updated_at_ms = 3, sealed_at_ms = 3
         WHERE trial_no = 2''',
      <Object?>[_digest('8')],
    );
    _insertSlot(db, fixture: fixture, trialNo: 99, sealed: true);
    expect(
      () => _writeScorecard(store),
      throwsA(isA<AgentEvaluationScorecardConflict>()),
    );
    expect(db.select('SELECT * FROM eval_scorecards'), isEmpty);
  });

  test('scorecard binds the exact sealed input set and rejects tampering', () {
    _insertCompleteSlots(db, fixture);
    final actualInputHash = store.computeInputSetHash('execution-1');

    expect(
      () => store.writeScorecard(
        executionId: 'execution-1',
        scope: 'execution',
        scopeKey: 'execution-1',
        aggregateJson: '{"passRate":1}',
        aggregatorReleaseHash: _digest('7'),
        expectedInputSetHash: _digest('0'),
        createdAtMs: 10,
      ),
      throwsA(isA<AgentEvaluationScorecardConflict>()),
    );
    expect(db.select('SELECT * FROM eval_scorecards'), isEmpty);

    final scorecard = _writeScorecard(
      store,
      expectedInputSetHash: actualInputHash,
    );
    expect(scorecard.inputSetHash, actualInputHash);
    expect(scorecard.expectedSetHash, fixture.slotSetHash);
    expect(
      db
          .select(
            "SELECT status FROM eval_executions WHERE execution_id = 'execution-1'",
          )
          .single['status'],
      'completed',
    );
  });

  test('channel head initialization is idempotent with exact readback', () {
    final first = store.initializeChannelHead(
      channel: 'stable',
      bundleHash: fixture.championBundleHash,
      createdAtMs: 10,
    );
    final repeated = store.initializeChannelHead(
      channel: 'stable',
      bundleHash: fixture.championBundleHash,
      createdAtMs: 99,
    );

    expect(first.bundleHash, fixture.championBundleHash);
    expect(first.epoch, 0);
    expect(repeated.updatedAtMs, 10);
    expect(store.readChannelHead('stable').bundleHash, first.bundleHash);
  });

  test('channel head initialization rejects conflict and nonzero epoch', () {
    store.initializeChannelHead(
      channel: 'stable',
      bundleHash: fixture.championBundleHash,
      createdAtMs: 10,
    );
    expect(
      () => store.initializeChannelHead(
        channel: 'stable',
        bundleHash: fixture.challengerBundleHash,
        createdAtMs: 11,
      ),
      throwsA(isA<AgentEvaluationPromotionConflict>()),
    );
    db.execute(
      "UPDATE prompt_channel_heads SET epoch = 1 WHERE channel = 'stable'",
    );
    expect(
      () => store.initializeChannelHead(
        channel: 'stable',
        bundleHash: fixture.championBundleHash,
        createdAtMs: 12,
      ),
      throwsA(isA<AgentEvaluationPromotionConflict>()),
    );
  });

  test('readChannelHead rejects a missing channel', () {
    expect(
      () => store.readChannelHead('missing'),
      throwsA(isA<AgentEvaluationPromotionConflict>()),
    );
  });

  test(
    'two contenders using the same expected head allow one promotion',
    () async {
      _insertCompleteSlots(db, fixture);
      final scorecard = _writeScorecard(
        store,
        expectedInputSetHash: store.computeInputSetHash('execution-1'),
      );
      _insertChannelHead(db, fixture.championBundleHash);
      final authorization = await _authorizePromotion(
        store,
        db,
        fixture,
        scorecard,
        holdoutSigner,
        holdoutVerifier.trustPolicyHash,
      );

      final contenderDb = sqlite3.open(databasePath);
      addTearDown(contenderDb.dispose);
      contenderDb.execute('PRAGMA foreign_keys = ON');
      final contender = AgentEvaluationReleaseStore(
        db: contenderDb,
        trustedHoldoutVerifier: holdoutVerifier,
      );

      final winner = await store.promoteVerified(
        decisionId: 'decision-winner',
        channel: 'stable',
        expectedBundleHash: fixture.championBundleHash,
        expectedEpoch: 0,
        challengerBundleHash: fixture.challengerBundleHash,
        experimentId: 'experiment-1',
        regressionVerdictHash: authorization.regressionVerdictHash,
        productionHoldoutClaimHash: authorization.holdoutConfirmationId,
        approver: 'release-bot',
        createdAtMs: 20,
      );
      expect(winner.epoch, 1);

      await expectLater(
        contender.promoteVerified(
          decisionId: 'decision-loser',
          channel: 'stable',
          expectedBundleHash: fixture.championBundleHash,
          expectedEpoch: 0,
          challengerBundleHash: fixture.challengerBundleHash,
          experimentId: 'experiment-1',
          regressionVerdictHash: authorization.regressionVerdictHash,
          productionHoldoutClaimHash: authorization.holdoutConfirmationId,
          approver: 'release-bot',
          createdAtMs: 21,
        ),
        throwsA(isA<AgentEvaluationPromotionConflict>()),
      );
      expect(store.readDecisions('stable'), hasLength(1));
    },
  );

  test('claim imported within TTL remains promotable after TTL', () async {
    _insertCompleteSlots(db, fixture);
    final scorecard = _writeScorecard(
      store,
      expectedInputSetHash: store.computeInputSetHash('execution-1'),
    );
    _insertChannelHead(db, fixture.championBundleHash);
    final authorization = await _authorizePromotion(
      store,
      db,
      fixture,
      scorecard,
      holdoutSigner,
      holdoutVerifier.trustPolicyHash,
      expired: true,
    );

    final promoted = await store.promoteVerified(
      decisionId: 'decision-delayed-after-ttl',
      channel: 'stable',
      expectedBundleHash: fixture.championBundleHash,
      expectedEpoch: 0,
      challengerBundleHash: fixture.challengerBundleHash,
      experimentId: 'experiment-1',
      regressionVerdictHash: authorization.regressionVerdictHash,
      productionHoldoutClaimHash: authorization.holdoutConfirmationId,
      approver: 'release-bot',
      createdAtMs: 20,
    );
    expect(promoted.bundleHash, fixture.challengerBundleHash);
    expect(promoted.epoch, 1);
  });

  test('tampered access import time cannot authorize promotion', () async {
    _insertCompleteSlots(db, fixture);
    final scorecard = _writeScorecard(
      store,
      expectedInputSetHash: store.computeInputSetHash('execution-1'),
    );
    _insertChannelHead(db, fixture.championBundleHash);
    final authorization = await _authorizePromotion(
      store,
      db,
      fixture,
      scorecard,
      holdoutSigner,
      holdoutVerifier.trustPolicyHash,
    );
    final claim = db.select(
      'SELECT imported_at_ms FROM eval_production_holdout_claims '
      'WHERE claim_hash = ?',
      <Object?>[authorization.holdoutConfirmationId],
    ).single;
    db.execute('DROP TRIGGER enforce_production_holdout_access_transition');
    db.execute('''UPDATE eval_production_holdout_accesses
         SET imported_at_ms = imported_at_ms + 1
         WHERE access_id = 'holdout-access-1' ''');

    await expectLater(
      store.promoteVerified(
        decisionId: 'decision-tampered-import-time',
        channel: 'stable',
        expectedBundleHash: fixture.championBundleHash,
        expectedEpoch: 0,
        challengerBundleHash: fixture.challengerBundleHash,
        experimentId: 'experiment-1',
        regressionVerdictHash: authorization.regressionVerdictHash,
        productionHoldoutClaimHash: authorization.holdoutConfirmationId,
        approver: 'release-bot',
        createdAtMs: 20,
      ),
      throwsA(isA<AgentEvaluationPromotionConflict>()),
    );
    expect(claim['imported_at_ms'], isA<int>());
    expect(store.readDecisions('stable'), isEmpty);
  });

  test(
    'tampered stored production signature cannot authorize promotion',
    () async {
      _insertCompleteSlots(db, fixture);
      final scorecard = _writeScorecard(
        store,
        expectedInputSetHash: store.computeInputSetHash('execution-1'),
      );
      _insertChannelHead(db, fixture.championBundleHash);
      final authorization = await _authorizePromotion(
        store,
        db,
        fixture,
        scorecard,
        holdoutSigner,
        holdoutVerifier.trustPolicyHash,
      );
      db.execute('DROP TRIGGER prevent_eval_production_holdout_claims_update');
      db.execute(
        '''UPDATE eval_production_holdout_claims
         SET signature_base64 = 'forged-signature'
         WHERE claim_hash = ?''',
        <Object?>[authorization.holdoutConfirmationId],
      );

      await expectLater(
        store.promoteVerified(
          decisionId: 'decision-tampered-signature',
          channel: 'stable',
          expectedBundleHash: fixture.championBundleHash,
          expectedEpoch: 0,
          challengerBundleHash: fixture.challengerBundleHash,
          experimentId: 'experiment-1',
          regressionVerdictHash: authorization.regressionVerdictHash,
          productionHoldoutClaimHash: authorization.holdoutConfirmationId,
          approver: 'release-bot',
          createdAtMs: 20,
        ),
        throwsA(isA<AgentEvaluationPromotionConflict>()),
      );
      expect(store.readDecisions('stable'), isEmpty);
    },
  );

  test('caller cannot replace the promotion trusted root', () async {
    _insertCompleteSlots(db, fixture);
    final scorecard = _writeScorecard(
      store,
      expectedInputSetHash: store.computeInputSetHash('execution-1'),
    );
    _insertChannelHead(db, fixture.championBundleHash);
    final attackerSigner = await AgentEvaluationTrustedHoldoutSigner.fromSeed(
      keyId: 'attacker-root',
      seed: List<int>.filled(32, 9),
    );
    await expectLater(
      _authorizePromotion(
        store,
        db,
        fixture,
        scorecard,
        attackerSigner,
        holdoutVerifier.trustPolicyHash,
      ),
      throwsA(isA<AgentEvaluationProductionHoldoutException>()),
    );
    expect(store.readDecisions('stable'), isEmpty);
  });

  test('rollback advances the epoch and retains append-only history', () async {
    _insertCompleteSlots(db, fixture);
    final scorecard = _writeScorecard(
      store,
      expectedInputSetHash: store.computeInputSetHash('execution-1'),
    );
    _insertChannelHead(db, fixture.championBundleHash);
    final authorization = await _authorizePromotion(
      store,
      db,
      fixture,
      scorecard,
      holdoutSigner,
      holdoutVerifier.trustPolicyHash,
    );
    await store.promoteVerified(
      decisionId: 'decision-promote',
      channel: 'stable',
      expectedBundleHash: fixture.championBundleHash,
      expectedEpoch: 0,
      challengerBundleHash: fixture.challengerBundleHash,
      experimentId: 'experiment-1',
      regressionVerdictHash: authorization.regressionVerdictHash,
      productionHoldoutClaimHash: authorization.holdoutConfirmationId,
      approver: 'release-bot',
      createdAtMs: 20,
    );
    final rollback = store.rollbackVerified(
      decisionId: 'decision-rollback',
      channel: 'stable',
      expectedBundleHash: fixture.challengerBundleHash,
      expectedEpoch: 1,
      promotionDecisionId: 'decision-promote',
      approver: 'release-bot',
      createdAtMs: 21,
    );

    expect(rollback.bundleHash, fixture.championBundleHash);
    expect(rollback.epoch, 2);
    final history = store.readDecisions('stable');
    expect(history.map((entry) => entry.action), <String>[
      'promote',
      'rollback',
    ]);
    expect(history.map((entry) => entry.toEpoch), <int>[1, 2]);
  });

  test('decision rows cannot be rewritten or deleted', () async {
    _insertCompleteSlots(db, fixture);
    final scorecard = _writeScorecard(
      store,
      expectedInputSetHash: store.computeInputSetHash('execution-1'),
    );
    _insertChannelHead(db, fixture.championBundleHash);
    final authorization = await _authorizePromotion(
      store,
      db,
      fixture,
      scorecard,
      holdoutSigner,
      holdoutVerifier.trustPolicyHash,
    );
    await store.promoteVerified(
      decisionId: 'decision-1',
      channel: 'stable',
      expectedBundleHash: fixture.championBundleHash,
      expectedEpoch: 0,
      challengerBundleHash: fixture.challengerBundleHash,
      experimentId: 'experiment-1',
      regressionVerdictHash: authorization.regressionVerdictHash,
      productionHoldoutClaimHash: authorization.holdoutConfirmationId,
      approver: 'release-bot',
      createdAtMs: 20,
    );

    expect(
      () => db.execute(
        "UPDATE prompt_release_decisions SET approver = 'attacker' "
        "WHERE decision_id = 'decision-1'",
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

  test('unverified promotion cannot move the channel head', () {
    _insertCompleteSlots(db, fixture);
    final scorecard = _writeScorecard(
      store,
      expectedInputSetHash: store.computeInputSetHash('execution-1'),
    );
    _insertChannelHead(db, fixture.championBundleHash);

    expect(
      () => store.promote(
        decisionId: 'forged-decision',
        channel: 'stable',
        expectedBundleHash: fixture.championBundleHash,
        expectedEpoch: 0,
        challengerBundleHash: fixture.challengerBundleHash,
        experimentId: 'experiment-1',
        scorecardHash: scorecard.scorecardHash,
        approver: 'attacker',
        createdAtMs: 20,
      ),
      throwsA(isA<AgentEvaluationPromotionConflict>()),
    );
    expect(
      db
          .select(
            "SELECT bundle_hash, epoch FROM prompt_channel_heads WHERE channel = 'stable'",
          )
          .single,
      containsPair('bundle_hash', fixture.championBundleHash),
    );
    expect(store.readDecisions('stable'), isEmpty);
  });

  test(
    'raw promote verdict without a DB derivation cannot move the head',
    () async {
      _insertCompleteSlots(db, fixture);
      final scorecard = _writeScorecard(
        store,
        expectedInputSetHash: store.computeInputSetHash('execution-1'),
      );
      _insertChannelHead(db, fixture.championBundleHash);
      final rawVerdictHash = _insertGateVerdict(
        db,
        verdictHash: _digest('d'),
        verdictKind: 'regression',
        experimentId: 'experiment-1',
        executionId: 'execution-1',
        scorecardHash: scorecard.scorecardHash,
        championBundleHash: fixture.championBundleHash,
        challengerBundleHash: fixture.challengerBundleHash,
        status: 'promote',
        reasonsJson: '[]',
        comparisonInputSetHash: scorecard.inputSetHash,
        expectedPairSetHash: scorecard.expectedSetHash,
        policyHash: AgentEvaluationStandardGatePolicy.policyHash,
        gateReleaseHash: AgentEvaluationStandardGatePolicy.gateReleaseHash,
        createdAtMs: 12,
        addDerivation: false,
      );

      await expectLater(
        store.promoteVerified(
          decisionId: 'raw-verdict-decision',
          channel: 'stable',
          expectedBundleHash: fixture.championBundleHash,
          expectedEpoch: 0,
          challengerBundleHash: fixture.challengerBundleHash,
          experimentId: 'experiment-1',
          regressionVerdictHash: rawVerdictHash,
          holdoutConfirmationId: 'unreached-holdout-check',
          approver: 'attacker',
          createdAtMs: 20,
        ),
        throwsA(isA<AgentEvaluationPromotionConflict>()),
      );
      expect(store.readDecisions('stable'), isEmpty);
    },
  );

  test(
    'reject verdict or missing holdout cannot authorize promotion',
    () async {
      _insertCompleteSlots(db, fixture);
      final scorecard = _writeScorecard(
        store,
        expectedInputSetHash: store.computeInputSetHash('execution-1'),
      );
      _insertChannelHead(db, fixture.championBundleHash);
      final rejectVerdictHash = _insertGateVerdict(
        db,
        verdictHash: _digest('3'),
        verdictKind: 'regression',
        experimentId: 'experiment-1',
        executionId: 'execution-1',
        scorecardHash: scorecard.scorecardHash,
        championBundleHash: fixture.championBundleHash,
        challengerBundleHash: fixture.challengerBundleHash,
        status: 'reject',
        reasonsJson: '["pass3Regression"]',
        comparisonInputSetHash: scorecard.inputSetHash,
        expectedPairSetHash: scorecard.expectedSetHash,
        policyHash: _digest('4'),
        gateReleaseHash: _digest('5'),
        createdAtMs: 12,
      );

      await expectLater(
        store.promoteVerified(
          decisionId: 'rejected-decision',
          channel: 'stable',
          expectedBundleHash: fixture.championBundleHash,
          expectedEpoch: 0,
          challengerBundleHash: fixture.challengerBundleHash,
          experimentId: 'experiment-1',
          regressionVerdictHash: rejectVerdictHash,
          holdoutConfirmationId: 'missing-confirmation',
          approver: 'release-bot',
          createdAtMs: 20,
        ),
        throwsA(isA<AgentEvaluationPromotionConflict>()),
      );
      expect(store.readDecisions('stable'), isEmpty);
    },
  );

  test('caller-selected rollback cannot target an unrelated bundle', () {
    _insertCompleteSlots(db, fixture);
    final scorecard = _writeScorecard(
      store,
      expectedInputSetHash: store.computeInputSetHash('execution-1'),
    );
    _insertChannelHead(db, fixture.championBundleHash);

    expect(
      () => store.rollback(
        decisionId: 'forged-rollback',
        channel: 'stable',
        expectedBundleHash: fixture.championBundleHash,
        expectedEpoch: 0,
        rollbackBundleHash: fixture.challengerBundleHash,
        experimentId: 'experiment-1',
        scorecardHash: scorecard.scorecardHash,
        approver: 'attacker',
        createdAtMs: 20,
      ),
      throwsA(isA<AgentEvaluationPromotionConflict>()),
    );
    expect(store.readDecisions('stable'), isEmpty);
  });

  test(
    'regression execution cannot masquerade as holdout confirmation',
    () async {
      _insertCompleteSlots(db, fixture);
      final scorecard = _writeScorecard(
        store,
        expectedInputSetHash: store.computeInputSetHash('execution-1'),
      );
      _insertChannelHead(db, fixture.championBundleHash);
      final regressionVerdictHash = _insertGateVerdict(
        db,
        verdictHash: _digest('1'),
        verdictKind: 'regression',
        experimentId: 'experiment-1',
        executionId: 'execution-1',
        scorecardHash: scorecard.scorecardHash,
        championBundleHash: fixture.championBundleHash,
        challengerBundleHash: fixture.challengerBundleHash,
        status: 'promote',
        reasonsJson: '[]',
        comparisonInputSetHash: scorecard.inputSetHash,
        expectedPairSetHash: scorecard.expectedSetHash,
        policyHash: _digest('4'),
        gateReleaseHash: _digest('5'),
        createdAtMs: 11,
      );
      final fakeHoldoutVerdictHash = _insertGateVerdict(
        db,
        verdictHash: _digest('4'),
        verdictKind: 'holdout',
        experimentId: 'experiment-1',
        executionId: 'execution-1',
        scorecardHash: scorecard.scorecardHash,
        championBundleHash: fixture.championBundleHash,
        challengerBundleHash: fixture.challengerBundleHash,
        status: 'promote',
        reasonsJson: '[]',
        comparisonInputSetHash: scorecard.inputSetHash,
        expectedPairSetHash: scorecard.expectedSetHash,
        policyHash: _digest('6'),
        gateReleaseHash: _digest('8'),
        createdAtMs: 12,
      );
      _insertRawHoldoutAuthorization(
        db,
        fixture: fixture,
        familyId: 'fake-family',
        tokenId: 'fake-token',
        accessId: 'fake-access',
        confirmationId: 'fake-confirmation',
        executionId: 'execution-1',
        verdictHash: fakeHoldoutVerdictHash,
      );

      await expectLater(
        store.promoteVerified(
          decisionId: 'fake-holdout-decision',
          channel: 'stable',
          expectedBundleHash: fixture.championBundleHash,
          expectedEpoch: 0,
          challengerBundleHash: fixture.challengerBundleHash,
          experimentId: 'experiment-1',
          regressionVerdictHash: regressionVerdictHash,
          holdoutConfirmationId: 'fake-confirmation',
          approver: 'attacker',
          createdAtMs: 20,
        ),
        throwsA(isA<AgentEvaluationPromotionConflict>()),
      );
      expect(store.readDecisions('stable'), isEmpty);
    },
  );
}

AgentEvaluationScorecardRecord _writeScorecard(
  AgentEvaluationReleaseStore store, {
  String? expectedInputSetHash,
}) => store.writeScorecard(
  executionId: 'execution-1',
  scope: 'execution',
  scopeKey: 'execution-1',
  aggregateJson: '{"passRate":1}',
  aggregatorReleaseHash: _digest('7'),
  expectedInputSetHash:
      expectedInputSetHash ?? store.computeInputSetHash('execution-1'),
  createdAtMs: 10,
);

class _Fixture {
  const _Fixture({
    required this.championCellId,
    required this.challengerCellId,
    required this.cellSetHash,
    required this.slotSetHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
  });

  final String championCellId;
  final String challengerCellId;
  List<String> get cellIds =>
      <String>[championCellId, challengerCellId]..sort();
  final String cellSetHash;
  final String slotSetHash;
  final String championBundleHash;
  final String challengerBundleHash;
}

_Fixture _seedExecution(Database db) {
  final champion = _digest('b');
  final challenger = _digest('a');
  final model = _digest('1');
  final scenario = _digest('c');
  final decoding = _digest('d');
  final championCellId = AgentEvaluationReleaseStore.canonicalCellId(
    generationBundleHash: champion,
    sutModelRouteHash: model,
    scenarioReleaseHash: scenario,
    decodingConfigHash: decoding,
  );
  final challengerCellId = AgentEvaluationReleaseStore.canonicalCellId(
    generationBundleHash: challenger,
    sutModelRouteHash: model,
    scenarioReleaseHash: scenario,
    decodingConfigHash: decoding,
  );
  final cellIds = <String>[championCellId, challengerCellId]..sort();
  final cellSetHash = AgentEvaluationReleaseStore.canonicalCellSetHash(<String>[
    ...cellIds,
  ]);
  final slotSetHash = AgentEvaluationReleaseStore.canonicalSlotSetHash(
    cellIds,
    2,
  );
  db.execute(
    '''INSERT INTO generation_bundles (bundle_hash, bundle_id, releases_json, created_at_ms)
       VALUES (?, 'champion', '[]', 1), (?, 'challenger', '[]', 1)''',
    <Object?>[champion, challenger],
  );
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'evaluator', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    <Object?>[_digest('e'), _digest('2'), _digest('7'), _digest('3')],
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
    <Object?>[scenario, _digest('f'), _digest('5')],
  );
  db.execute(
    '''INSERT INTO eval_experiments (
         experiment_id, manifest_json, manifest_hash, scenario_set_release_hash,
         evaluation_bundle_hash, expected_cell_set_hash, expected_slot_set_hash,
         trials_per_cell, created_at_ms
       ) VALUES ('experiment-1', '{}', ?, ?, ?, ?, ?, 2, 1)''',
    <Object?>[
      _digest('6'),
      _digest('f'),
      _digest('e'),
      cellSetHash,
      slotSetHash,
    ],
  );
  db.execute(
    '''INSERT INTO eval_cells (
         cell_id, generation_bundle_hash, sut_model_route_hash,
         scenario_release_hash, decoding_config_hash, created_at_ms
       ) VALUES (?, ?, ?, ?, ?, 1), (?, ?, ?, ?, ?, 1)''',
    <Object?>[
      championCellId,
      champion,
      model,
      scenario,
      decoding,
      challengerCellId,
      challenger,
      model,
      scenario,
      decoding,
    ],
  );
  for (var ordinal = 0; ordinal < cellIds.length; ordinal += 1) {
    db.execute(
      '''INSERT INTO eval_experiment_cells (experiment_id, cell_id, ordinal)
         VALUES ('experiment-1', ?, ?)''',
      <Object?>[cellIds[ordinal], ordinal],
    );
  }
  db.execute(
    '''INSERT INTO eval_executions (
         execution_id, experiment_id, status, expected_cell_set_hash,
         expected_slot_set_hash, created_at_ms, started_at_ms
       ) VALUES ('execution-1', 'experiment-1', 'running', ?, ?, 1, 1)''',
    <Object?>[cellSetHash, slotSetHash],
  );
  for (var ordinal = 0; ordinal < cellIds.length; ordinal += 1) {
    db.execute(
      '''INSERT INTO eval_execution_cells (execution_id, cell_id, ordinal)
         VALUES ('execution-1', ?, ?)''',
      <Object?>[cellIds[ordinal], ordinal],
    );
  }
  return _Fixture(
    championCellId: championCellId,
    challengerCellId: challengerCellId,
    cellSetHash: cellSetHash,
    slotSetHash: slotSetHash,
    championBundleHash: champion,
    challengerBundleHash: challenger,
  );
}

void _insertCompleteSlots(Database db, _Fixture fixture) {
  for (final cellId in fixture.cellIds) {
    _insertSlot(db, fixture: fixture, cellId: cellId, trialNo: 1, sealed: true);
    _insertSlot(db, fixture: fixture, cellId: cellId, trialNo: 2, sealed: true);
  }
}

void _insertSlot(
  Database db, {
  required _Fixture fixture,
  String? cellId,
  required int trialNo,
  required bool sealed,
}) {
  final effectiveCellId = cellId ?? fixture.championCellId;
  final slotId = AgentEvaluationReleaseStore.canonicalTrialSlotId(
    executionId: 'execution-1',
    cellId: effectiveCellId,
    trialNo: trialNo,
  );
  if (sealed) {
    db.execute(
      '''INSERT INTO eval_trial_slots (
           trial_slot_id, execution_id, cell_id, trial_no, status, result,
           lease_epoch, sealed_evidence_hash, created_at_ms, updated_at_ms,
           sealed_at_ms
         ) VALUES (?, 'execution-1', ?, ?, 'sealed', 'pass', 1, ?, 1, 2, 2)''',
      <Object?>[
        slotId,
        effectiveCellId,
        trialNo,
        _digest(trialNo.isEven ? '8' : '9'),
      ],
    );
  } else {
    db.execute(
      '''INSERT INTO eval_trial_slots (
           trial_slot_id, execution_id, cell_id, trial_no, status,
           lease_epoch, created_at_ms, updated_at_ms
         ) VALUES (?, 'execution-1', ?, ?, 'queued', 0, 1, 1)''',
      <Object?>[slotId, effectiveCellId, trialNo],
    );
  }
}

class _PromotionAuthorization {
  const _PromotionAuthorization({
    required this.regressionVerdictHash,
    required this.holdoutConfirmationId,
  });

  final String regressionVerdictHash;
  final String holdoutConfirmationId;
}

String _insertGateVerdict(
  Database db, {
  required String verdictHash,
  required String verdictKind,
  required String experimentId,
  required String executionId,
  required String scorecardHash,
  required String championBundleHash,
  required String challengerBundleHash,
  required String status,
  required String reasonsJson,
  required String comparisonInputSetHash,
  required String expectedPairSetHash,
  required String policyHash,
  required String gateReleaseHash,
  required int createdAtMs,
  bool addDerivation = true,
}) {
  db.execute(
    '''INSERT INTO eval_release_gate_verdicts (
         verdict_hash, verdict_kind, experiment_id, execution_id,
         scorecard_hash, champion_bundle_hash, challenger_bundle_hash,
         status, reasons_json, comparison_input_set_hash,
         expected_pair_set_hash, policy_hash, gate_release_hash, created_at_ms
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
    <Object?>[
      verdictHash,
      verdictKind,
      experimentId,
      executionId,
      scorecardHash,
      championBundleHash,
      challengerBundleHash,
      status,
      reasonsJson,
      comparisonInputSetHash,
      expectedPairSetHash,
      policyHash,
      gateReleaseHash,
      createdAtMs,
    ],
  );
  if (addDerivation) {
    db.execute(
      '''INSERT INTO eval_release_gate_derivations (
           verdict_hash, projection_hash, authority_release_hash, created_at_ms
         ) VALUES (?, ?, ?, ?)''',
      <Object?>[
        verdictHash,
        _digest('f'),
        AgentEvaluationStandardGatePolicy.gateReleaseHash,
        createdAtMs,
      ],
    );
  }
  return verdictHash;
}

void _insertRawHoldoutAuthorization(
  Database db, {
  required _Fixture fixture,
  required String familyId,
  required String tokenId,
  required String accessId,
  required String confirmationId,
  required String executionId,
  required String verdictHash,
}) {
  db.execute(
    '''INSERT INTO eval_experiment_families (
         family_id, scenario_set_release_hash, holdout_access_policy_hash,
         max_accesses, used_accesses, alpha_budget_micros,
         alpha_spent_micros, status, created_at_ms, updated_at_ms
       ) VALUES (?, ?, ?, 1, 1, 100000, 50000, 'exhausted', 1, 12)''',
    <Object?>[familyId, _digest('f'), _digest('6')],
  );
  db.execute(
    '''INSERT INTO eval_family_challengers (
         family_id, challenger_bundle_hash, registered_at_ms
       ) VALUES (?, ?, 1)''',
    <Object?>[familyId, fixture.challengerBundleHash],
  );
  db.execute(
    '''INSERT INTO eval_holdout_tokens (
         token_id, family_id, challenger_bundle_hash, alpha_cost_micros,
         state, issued_at_ms, consumed_at_ms
       ) VALUES (?, ?, ?, 50000, 'consumed', 2, 3)''',
    <Object?>[tokenId, familyId, fixture.challengerBundleHash],
  );
  db.execute(
    '''INSERT INTO eval_holdout_accesses (
         access_id, token_id, family_id, challenger_bundle_hash,
         execution_id, trusted_runner_release_hash, alpha_cost_micros,
         state, gate_verdict_hash, begun_at_ms, sealed_at_ms
       ) VALUES (?, ?, ?, ?, ?, ?, 50000, 'sealed', ?, 3, 13)''',
    <Object?>[
      accessId,
      tokenId,
      familyId,
      fixture.challengerBundleHash,
      executionId,
      _digest('9'),
      verdictHash,
    ],
  );
  db.execute(
    '''INSERT INTO eval_holdout_confirmations (
         confirmation_id, token_id, family_id, challenger_bundle_hash,
         execution_id, result, public_result_json, alpha_cost_micros,
         created_at_ms
       ) VALUES (?, ?, ?, ?, ?, 'pass', '{"result":"pass"}', 50000, 13)''',
    <Object?>[
      confirmationId,
      tokenId,
      familyId,
      fixture.challengerBundleHash,
      executionId,
    ],
  );
}

Future<_PromotionAuthorization> _authorizePromotion(
  AgentEvaluationReleaseStore store,
  Database db,
  _Fixture fixture,
  AgentEvaluationScorecardRecord scorecard,
  AgentEvaluationTrustedHoldoutSigner signer,
  String holdoutPolicyHash, {
  bool expired = false,
}) async {
  final regressionVerdictHash = _insertGateVerdict(
    db,
    verdictHash: _digest('1'),
    verdictKind: 'regression',
    experimentId: 'experiment-1',
    executionId: 'execution-1',
    scorecardHash: scorecard.scorecardHash,
    championBundleHash: fixture.championBundleHash,
    challengerBundleHash: fixture.challengerBundleHash,
    status: 'promote',
    reasonsJson: '[]',
    comparisonInputSetHash: scorecard.inputSetHash,
    expectedPairSetHash: scorecard.expectedSetHash,
    policyHash: AgentEvaluationStandardGatePolicy.policyHash,
    gateReleaseHash: AgentEvaluationStandardGatePolicy.gateReleaseHash,
    createdAtMs: 11,
  );
  const opaqueScenarioSetHash =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const privatePlanHash =
      '4444444444444444444444444444444444444444444444444444444444444444';
  db.execute(
    '''INSERT INTO eval_experiment_families (
         family_id, scenario_set_release_hash,
         opaque_holdout_scenario_set_hash, private_plan_hash,
         holdout_access_policy_hash, max_accesses, used_accesses,
         alpha_budget_micros,
         alpha_spent_micros, status, created_at_ms, updated_at_ms
       ) VALUES ('family-1', ?, ?, ?, ?, 1, 1, 100000, 50000,
         'exhausted', 1, 12)''',
    <Object?>[
      _digest('f'),
      opaqueScenarioSetHash,
      privatePlanHash,
      holdoutPolicyHash,
    ],
  );
  db.execute(
    '''INSERT INTO eval_family_challengers (
         family_id, challenger_bundle_hash, registered_at_ms
       ) VALUES ('family-1', ?, 1)''',
    <Object?>[fixture.challengerBundleHash],
  );
  db.execute(
    '''INSERT INTO eval_holdout_tokens (
         token_id, family_id, challenger_bundle_hash, alpha_cost_micros,
         state, issued_at_ms, consumed_at_ms, regression_verdict_hash
       ) VALUES ('holdout-token-1', 'family-1', ?, 50000,
         'consumed', 2, 3, ?)''',
    <Object?>[fixture.challengerBundleHash, regressionVerdictHash],
  );
  db.execute(
    '''INSERT INTO eval_production_holdout_accesses (
         access_id, token_id, family_id, challenger_bundle_hash,
         trusted_runner_release_hash, alpha_cost_micros, state, begun_at_ms
       ) VALUES ('holdout-access-1', 'holdout-token-1', 'family-1', ?,
         ?, 50000, 'begun', 3)''',
    <Object?>[
      fixture.challengerBundleHash,
      AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
    ],
  );
  db.execute(
    '''INSERT OR IGNORE INTO eval_price_table_releases (
         price_table_hash, table_id, currency, entries_json,
         rounding_policy, created_at_ms
       ) VALUES (?, 'release-store-price', 'USD', '{}',
         'ceil-per-attempt-microusd-v1', 1)''',
    <Object?>[_digest('3')],
  );
  final projection = AgentEvaluationProductionHoldoutProjection(
    executionSummary: <String, Object?>{
      'schemaVersion': 'production-holdout-redacted-execution-summary-v1',
      'status': 'completed',
      'releaseConfigurationHash': _digest('2'),
      'executionCommitmentHash': _digest('4'),
      'expectedSlotCount': 4,
      'completedSlotCount': 4,
    },
    scorecard: <String, Object?>{
      'schemaVersion': 'production-holdout-redacted-scorecard-v1',
      'inputSetHash': _digest('5'),
      'expectedCellSetHash': fixture.cellSetHash,
      'expectedSlotSetHash': fixture.slotSetHash,
      'aggregateCommitmentHash': _digest('6'),
    },
    gateVerdict: <String, Object?>{
      'schemaVersion': 'production-holdout-redacted-gate-v1',
      'status': 'promote',
      'scorecardHash': _digest('6'),
      'projectionHash': _digest('7'),
      'policyHash': AgentEvaluationStandardGatePolicy.policyHash,
      'reasonCodes': <String>['all-gates-pass'],
    },
  );
  final now = DateTime.now().millisecondsSinceEpoch;
  final signed = await signer.signProduction(
    AgentEvaluationProductionHoldoutAttestation(
      familyId: 'family-1',
      tokenId: 'holdout-token-1',
      accessId: 'holdout-access-1',
      regressionVerdictHash: regressionVerdictHash,
      championBundleHash: fixture.championBundleHash,
      challengerBundleHash: fixture.challengerBundleHash,
      regressionScenarioSetHash: _digest('f'),
      opaqueHoldoutScenarioSetHash: opaqueScenarioSetHash,
      privatePlanHash: privatePlanHash,
      productionManifestHash: _digest('8'),
      privateExecutionSummaryHash: _digest('4'),
      privateScorecardHash: _digest('6'),
      privateGateVerdictHash: _digest('9'),
      privateProjectionHash: _digest('7'),
      redactedExecutionSummaryHash: projection.executionSummaryHash,
      redactedScorecardHash: projection.scorecardHash,
      redactedGateVerdictHash: projection.gateVerdictHash,
      expectedCellSetHash: fixture.cellSetHash,
      expectedSlotSetHash: fixture.slotSetHash,
      executionBudgetPolicyHash: _digest('0'),
      executorReleaseHash: _digest('2'),
      evaluationBundleHash: _digest('e'),
      priceTableHash: _digest('3'),
      gatePolicyHash: AgentEvaluationStandardGatePolicy.policyHash,
      auditRootHash: _digest('a'),
      result: 'pass',
      runnerReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
      keyId: signer.keyId,
      nonce: 'release-store-test-nonce',
      issuedAtMs: expired ? now - 2000 : now - 1000,
      expiresAtMs: expired ? now - 1000 : now + 60000,
      signatureBase64: 'unsigned',
    ),
  );
  final verifier = AgentEvaluationTrustedHoldoutVerifier(
    keyId: signer.keyId,
    publicKey: signer.publicKey,
    runnerReleaseHash: AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
    resolverReleaseHash:
        AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
  );
  final claim = expired
      ? signed.claimHash
      : (await AgentEvaluationProductionHoldoutImporter(
          db: db,
          verifier: verifier,
        ).import(attestation: signed, projection: projection)).claimHash;
  if (expired) {
    // Preserve an expired signed row to prove promotion re-verifies TTL.
    db.execute(
      '''INSERT INTO eval_production_holdout_claims (
           claim_hash, access_id, family_id, token_id,
           regression_verdict_hash, champion_bundle_hash,
           challenger_bundle_hash, regression_scenario_set_hash,
           opaque_holdout_scenario_set_hash, private_plan_hash,
           production_manifest_hash, redacted_execution_summary_hash,
           private_execution_summary_hash, redacted_execution_summary_json,
           private_scorecard_hash, redacted_scorecard_hash,
           redacted_scorecard_json, private_gate_verdict_hash,
           redacted_gate_verdict_hash, redacted_gate_verdict_json,
           private_projection_hash, expected_cell_set_hash,
           expected_slot_set_hash, execution_budget_policy_hash,
           executor_release_hash, evaluation_bundle_hash, price_table_hash,
           gate_policy_hash, audit_root_hash, result, key_id,
           runner_release_hash, resolver_release_hash, payload_json,
           signature_base64, issued_at_ms, expires_at_ms, imported_at_ms
         ) VALUES (?, 'holdout-access-1', 'family-1', 'holdout-token-1',
           ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
           ?, ?, ?, ?, 'pass', ?, ?, ?, ?, ?, ?, ?, ?)''',
      <Object?>[
        signed.claimHash,
        regressionVerdictHash,
        fixture.championBundleHash,
        fixture.challengerBundleHash,
        _digest('f'),
        opaqueScenarioSetHash,
        privatePlanHash,
        signed.productionManifestHash,
        signed.redactedExecutionSummaryHash,
        signed.privateExecutionSummaryHash,
        projection.executionSummaryJson,
        signed.privateScorecardHash,
        signed.redactedScorecardHash,
        projection.scorecardJson,
        signed.privateGateVerdictHash,
        signed.redactedGateVerdictHash,
        projection.gateVerdictJson,
        signed.privateProjectionHash,
        signed.expectedCellSetHash,
        signed.expectedSlotSetHash,
        signed.executionBudgetPolicyHash,
        signed.executorReleaseHash,
        signed.evaluationBundleHash,
        signed.priceTableHash,
        signed.gatePolicyHash,
        signed.auditRootHash,
        signed.keyId,
        signed.runnerReleaseHash,
        signed.resolverReleaseHash,
        signed.payloadJson,
        signed.signatureBase64,
        signed.issuedAtMs,
        signed.expiresAtMs,
        signed.issuedAtMs,
      ],
    );
    db.execute(
      '''UPDATE eval_production_holdout_accesses
         SET state = 'imported', imported_at_ms = ?
         WHERE access_id = 'holdout-access-1' ''',
      <Object?>[signed.issuedAtMs],
    );
  }
  return _PromotionAuthorization(
    regressionVerdictHash: regressionVerdictHash,
    holdoutConfirmationId: claim,
  );
}

void _insertChannelHead(Database db, String bundleHash) {
  db.execute(
    '''INSERT INTO prompt_channel_heads (channel, bundle_hash, epoch, updated_at_ms)
       VALUES ('stable', ?, 0, 1)''',
    <Object?>[bundleHash],
  );
}

String _digest(String character) => List<String>.filled(64, character).join();
