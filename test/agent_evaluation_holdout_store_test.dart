import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_holdout_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';

void main() {
  late Directory tempDirectory;
  late String databasePath;
  late Database db;
  late AgentEvaluationHoldoutStore store;
  late AgentEvaluationTrustedHoldoutSigner signer;
  late AgentEvaluationTrustedHoldoutVerifier verifier;

  setUp(() async {
    tempDirectory = Directory.systemTemp.createTempSync('holdout-store-');
    databasePath = '${tempDirectory.path}/authority.sqlite';
    db = sqlite3.open(databasePath);
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    signer = await AgentEvaluationTrustedHoldoutSigner.fromSeed(
      keyId: 'holdout-store-test-key',
      seed: List<int>.generate(32, (index) => 32 - index),
    );
    verifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: signer.keyId,
      publicKey: signer.publicKey,
      runnerReleaseHash: AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
    );
    _seedAuthorityGraph(db, holdoutPolicyHash: verifier.trustPolicyHash);
    store = AgentEvaluationHoldoutStore(
      db: db,
      trustedHoldoutVerifier: verifier,
    );
  });

  tearDown(() {
    db.dispose();
    tempDirectory.deleteSync(recursive: true);
  });

  test('minimum reader and writer compatibility is enforced', () {
    final contract = store.assertCompatible(
      readerVersion: 27,
      writerVersion: 27,
    );
    expect(contract.schemaVersion, 27);
    expect(contract.minReaderVersion, 27);
    expect(contract.minWriterVersion, 27);

    expect(
      () => store.assertCompatible(readerVersion: 26, writerVersion: 27),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
    expect(
      () => store.assertCompatible(readerVersion: 27, writerVersion: 26),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
    expect(
      () => db.execute(
        '''UPDATE schema_compatibility_contracts SET min_reader_version = 1
           WHERE schema_version = 27''',
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('unregistered and duplicate challengers are rejected', () {
    _createFamily(store);
    expect(
      () => store.issueToken(
        tokenId: 'token-unregistered',
        familyId: 'family-1',
        challengerBundleHash: _digest('b'),
        regressionVerdictHash: _digest('9'),
        alphaCostMicros: 50000,
        issuedAtMs: 2,
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
    store.registerChallenger(
      familyId: 'family-1',
      challengerBundleHash: _digest('b'),
      registeredAtMs: 2,
    );
    expect(
      () => store.registerChallenger(
        familyId: 'family-1',
        challengerBundleHash: _digest('b'),
        registeredAtMs: 3,
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
  });

  test('ambiguous promoted challengers cannot be caller-selected', () {
    _createFamily(store);
    store.registerChallenger(
      familyId: 'family-1',
      challengerBundleHash: _digest('b'),
      registeredAtMs: 2,
    );
    db.execute(
      '''INSERT INTO generation_bundles
         (bundle_hash, bundle_id, releases_json, created_at_ms)
         VALUES (?, 'challenger-2', '[]', 2)''',
      <Object?>[_digest('c')],
    );
    store.registerChallenger(
      familyId: 'family-1',
      challengerBundleHash: _digest('c'),
      registeredAtMs: 2,
    );
    db.execute(
      '''INSERT INTO eval_scorecards (
           scorecard_hash, execution_id, scope, scope_key, aggregate_json,
           input_set_hash, expected_set_hash, aggregator_release_hash,
           created_at_ms
         ) VALUES (?, 'execution-1', 'cell', 'second-regression', '{}',
           ?, ?, ?, 2)''',
      <Object?>[_digest('0'), _digest('6'), _digest('8'), _digest('2')],
    );
    db.execute(
      '''INSERT INTO eval_release_gate_verdicts (
           verdict_hash, verdict_kind, experiment_id, execution_id,
           scorecard_hash, champion_bundle_hash, challenger_bundle_hash,
           status, reasons_json, comparison_input_set_hash,
           expected_pair_set_hash, policy_hash, gate_release_hash,
           created_at_ms
         ) VALUES (?, 'regression', 'experiment-1', 'execution-1', ?, ?, ?,
           'promote', '[]', ?, ?, ?, ?, 2)''',
      <Object?>[
        _digest('1'),
        _digest('0'),
        _digest('a'),
        _digest('c'),
        _digest('6'),
        _digest('8'),
        AgentEvaluationStandardGatePolicy.policyHash,
        AgentEvaluationStandardGatePolicy.gateReleaseHash,
      ],
    );
    db.execute(
      '''INSERT INTO eval_release_gate_derivations (
           verdict_hash, projection_hash, authority_release_hash,
           created_at_ms
         ) VALUES (?, ?, ?, 2)''',
      <Object?>[
        _digest('1'),
        _digest('5'),
        AgentEvaluationStandardGatePolicy.gateReleaseHash,
      ],
    );

    expect(
      () => store.issueToken(
        tokenId: 'caller-picked-token',
        familyId: 'family-1',
        challengerBundleHash: _digest('b'),
        regressionVerdictHash: _digest('9'),
        alphaCostMicros: 50000,
        issuedAtMs: 3,
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
    expect(db.select('SELECT * FROM eval_holdout_tokens'), isEmpty);
  });

  test('caller timestamp cannot roll the trusted TTL clock backward', () async {
    _prepareToken(store, tokenId: 'token-expired-clock');
    store.beginHoldoutAccess(
      accessId: 'access-expired-clock',
      tokenId: 'token-expired-clock',
      challengerBundleHash: _digest('b'),
      executionId: 'execution-1',
      trustedRunnerReleaseHash:
          AgentEvaluationTrustedHoldoutRunnerPolicy.releaseHash,
      begunAtMs: 3,
    );
    db.execute('''UPDATE eval_executions SET status = 'completed',
           started_at_ms = COALESCE(started_at_ms, created_at_ms),
           finished_at_ms = 4
         WHERE execution_id = 'execution-1' ''');
    final verdictHash = _insertHoldoutVerdict(db, status: 'promote');
    final now = DateTime.now().millisecondsSinceEpoch;

    await expectLater(
      store.sealTrustedHoldoutConfirmation(
        confirmationId: 'confirmation-expired-clock',
        accessId: 'access-expired-clock',
        gateVerdictHash: verdictHash,
        sealedAtMs: 5,
        attestation: await _signedAttestation(
          signer,
          holdoutPolicyHash: verifier.trustPolicyHash,
          accessId: 'access-expired-clock',
          tokenId: 'token-expired-clock',
          issuedAtMs: now - 2000,
          expiresAtMs: now - 1000,
        ),
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
    expect(db.select('SELECT * FROM eval_holdout_confirmations'), isEmpty);
  });

  test('caller cannot replace the family trusted signing root', () async {
    _prepareToken(store, tokenId: 'token-replaced-root');
    store.beginHoldoutAccess(
      accessId: 'access-replaced-root',
      tokenId: 'token-replaced-root',
      challengerBundleHash: _digest('b'),
      executionId: 'execution-1',
      trustedRunnerReleaseHash:
          AgentEvaluationTrustedHoldoutRunnerPolicy.releaseHash,
      begunAtMs: 3,
    );
    db.execute('''UPDATE eval_executions SET status = 'completed',
           started_at_ms = COALESCE(started_at_ms, created_at_ms),
           finished_at_ms = 4
         WHERE execution_id = 'execution-1' ''');
    final verdictHash = _insertHoldoutVerdict(db, status: 'promote');
    final attackerSigner = await AgentEvaluationTrustedHoldoutSigner.fromSeed(
      keyId: 'attacker-root',
      seed: List<int>.filled(32, 7),
    );
    final attackerVerifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: attackerSigner.keyId,
      publicKey: attackerSigner.publicKey,
      runnerReleaseHash: AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
    );
    final attackerStore = AgentEvaluationHoldoutStore(
      db: db,
      trustedHoldoutVerifier: attackerVerifier,
    );

    await expectLater(
      attackerStore.sealTrustedHoldoutConfirmation(
        confirmationId: 'confirmation-replaced-root',
        accessId: 'access-replaced-root',
        gateVerdictHash: verdictHash,
        sealedAtMs: 5,
        attestation: await _signedAttestation(
          attackerSigner,
          holdoutPolicyHash: verifier.trustPolicyHash,
          accessId: 'access-replaced-root',
          tokenId: 'token-replaced-root',
        ),
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
    expect(db.select('SELECT * FROM eval_holdout_confirmations'), isEmpty);
  });

  test('caller-selected trusted runner digest cannot spend holdout access', () {
    _prepareToken(store, tokenId: 'token-untrusted-runner');

    expect(
      () => store.beginHoldoutAccess(
        accessId: 'access-untrusted-runner',
        tokenId: 'token-untrusted-runner',
        challengerBundleHash: _digest('b'),
        executionId: 'execution-1',
        trustedRunnerReleaseHash: _digest('9'),
        begunAtMs: 3,
      ),
      throwsA(
        isA<AgentEvaluationHoldoutConflict>().having(
          (error) => error.message,
          'message',
          contains('frozen trusted runner'),
        ),
      ),
    );
    expect(
      db
          .select(
            "SELECT state FROM eval_holdout_tokens WHERE token_id = 'token-untrusted-runner'",
          )
          .single['state'],
      'issued',
    );
    expect(
      db
          .select(
            "SELECT used_accesses FROM eval_experiment_families WHERE family_id = 'family-1'",
          )
          .single['used_accesses'],
      0,
    );
  });

  test('two connections can begin a holdout access only once', () async {
    _prepareToken(store, tokenId: 'token-1');
    final competingDb = sqlite3.open(databasePath);
    addTearDown(competingDb.dispose);
    competingDb.execute('PRAGMA foreign_keys = ON');
    final competingStore = AgentEvaluationHoldoutStore(
      db: competingDb,
      trustedHoldoutVerifier: verifier,
    );

    final access = store.beginHoldoutAccess(
      accessId: 'access-winner',
      tokenId: 'token-1',
      challengerBundleHash: _digest('b'),
      executionId: 'execution-1',
      trustedRunnerReleaseHash:
          AgentEvaluationTrustedHoldoutRunnerPolicy.releaseHash,
      begunAtMs: 3,
    );
    expect(access.state, 'begun');
    expect(
      () => competingStore.beginHoldoutAccess(
        accessId: 'access-loser',
        tokenId: 'token-1',
        challengerBundleHash: _digest('b'),
        executionId: 'execution-1',
        trustedRunnerReleaseHash:
            AgentEvaluationTrustedHoldoutRunnerPolicy.releaseHash,
        begunAtMs: 4,
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
    db.execute('''UPDATE eval_executions SET status = 'completed',
           started_at_ms = COALESCE(started_at_ms, created_at_ms),
           finished_at_ms = 4
         WHERE execution_id = 'execution-1' ''');
    final verdictHash = _insertHoldoutVerdict(db, status: 'promote');
    final confirmation = await store.sealTrustedHoldoutConfirmation(
      confirmationId: 'confirmation-winner',
      accessId: 'access-winner',
      gateVerdictHash: verdictHash,
      sealedAtMs: 5,
      attestation: await _signedAttestation(
        signer,
        holdoutPolicyHash: verifier.trustPolicyHash,
        accessId: 'access-winner',
        tokenId: 'token-1',
      ),
    );
    expect(confirmation.publicResultJson, '{"result":"pass"}');
    expect(store.readConfirmations('family-1'), hasLength(1));
    expect(
      store.readConfirmations('family-1').single.publicResultJson,
      isNot(contains('scenario')),
    );
    expect(
      () => db.execute('''UPDATE eval_holdout_accesses SET state = 'begun',
             gate_verdict_hash = NULL, sealed_at_ms = NULL
           WHERE access_id = 'access-winner' '''),
      throwsA(isA<SqliteException>()),
    );
  });

  test('access and alpha budgets are spent before fixture execution', () {
    _prepareToken(store, tokenId: 'token-1', maxAccesses: 1);
    store.beginHoldoutAccess(
      accessId: 'access-1',
      tokenId: 'token-1',
      challengerBundleHash: _digest('b'),
      executionId: 'execution-1',
      trustedRunnerReleaseHash:
          AgentEvaluationTrustedHoldoutRunnerPolicy.releaseHash,
      begunAtMs: 3,
    );

    expect(
      () => store.issueToken(
        tokenId: 'token-after-budget',
        familyId: 'family-1',
        challengerBundleHash: _digest('b'),
        regressionVerdictHash: _digest('9'),
        alphaCostMicros: 1,
        issuedAtMs: 4,
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
    final family = db
        .select(
          "SELECT * FROM eval_experiment_families WHERE family_id = 'family-1'",
        )
        .single;
    expect(family['used_accesses'], 1);
    expect(family['status'], 'exhausted');
    expect(
      () => db.execute(
        '''UPDATE eval_holdout_tokens SET state = 'issued', consumed_at_ms = NULL
           WHERE token_id = 'token-1' ''',
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute('''UPDATE eval_experiment_families SET used_accesses = 0,
             alpha_spent_micros = 0, status = 'active'
           WHERE family_id = 'family-1' '''),
      throwsA(isA<SqliteException>()),
    );
  });

  test('holdout verdict must match the family policy', () async {
    _prepareToken(store, tokenId: 'token-policy');
    store.beginHoldoutAccess(
      accessId: 'access-policy',
      tokenId: 'token-policy',
      challengerBundleHash: _digest('b'),
      executionId: 'execution-1',
      trustedRunnerReleaseHash:
          AgentEvaluationTrustedHoldoutRunnerPolicy.releaseHash,
      begunAtMs: 3,
    );
    db.execute('''UPDATE eval_executions SET status = 'completed',
           started_at_ms = COALESCE(started_at_ms, created_at_ms),
           finished_at_ms = 4
         WHERE execution_id = 'execution-1' ''');
    final verdictHash = _insertHoldoutVerdict(
      db,
      status: 'promote',
      policyHash: _digest('0'),
    );

    await expectLater(
      store.sealTrustedHoldoutConfirmation(
        confirmationId: 'confirmation-policy',
        accessId: 'access-policy',
        gateVerdictHash: verdictHash,
        sealedAtMs: 5,
        attestation: await _signedAttestation(
          signer,
          holdoutPolicyHash: verifier.trustPolicyHash,
          accessId: 'access-policy',
          tokenId: 'token-policy',
        ),
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
  });

  test('caller-supplied holdout pass is rejected without spending token', () {
    _prepareToken(store, tokenId: 'token-legacy');

    expect(
      () => store.consumeToken(
        confirmationId: 'forged-confirmation',
        tokenId: 'token-legacy',
        challengerBundleHash: _digest('b'),
        executionId: 'execution-1',
        result: 'pass',
        createdAtMs: 3,
      ),
      throwsA(isA<AgentEvaluationHoldoutConflict>()),
    );
    expect(
      db
          .select(
            "SELECT state FROM eval_holdout_tokens WHERE token_id = 'token-legacy'",
          )
          .single['state'],
      'issued',
    );
  });
}

void _createFamily(AgentEvaluationHoldoutStore store, {int maxAccesses = 2}) {
  store.createFamily(
    familyId: 'family-1',
    scenarioSetReleaseHash: _digest('f'),
    holdoutAccessPolicyHash: store.trustedHoldoutPolicyHash,
    maxAccesses: maxAccesses,
    alphaBudgetMicros: 100000,
    createdAtMs: 1,
  );
}

void _prepareToken(
  AgentEvaluationHoldoutStore store, {
  required String tokenId,
  int maxAccesses = 2,
}) {
  _createFamily(store, maxAccesses: maxAccesses);
  store.registerChallenger(
    familyId: 'family-1',
    challengerBundleHash: _digest('b'),
    registeredAtMs: 1,
  );
  store.issueToken(
    tokenId: tokenId,
    familyId: 'family-1',
    challengerBundleHash: _digest('b'),
    regressionVerdictHash: _digest('9'),
    alphaCostMicros: 50000,
    issuedAtMs: 2,
  );
}

void _seedAuthorityGraph(Database db, {required String holdoutPolicyHash}) {
  db.execute(
    '''INSERT INTO generation_bundles (
         bundle_hash, bundle_id, releases_json, created_at_ms
       ) VALUES (?, 'champion', '[]', 1), (?, 'challenger', '[]', 1)''',
    <Object?>[_digest('a'), _digest('b')],
  );
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'evaluator', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    <Object?>[_digest('e'), _digest('1'), _digest('2'), _digest('3')],
  );
  db.execute(
    '''INSERT INTO eval_scenario_sets (
         scenario_set_release_hash, set_id, version, manifest_hash, created_at_ms
       ) VALUES (?, 'holdout-set', '1.0.0', ?, 1)''',
    <Object?>[_digest('f'), _digest('4')],
  );
  db.execute(
    '''INSERT INTO eval_experiments (
         experiment_id, manifest_json, manifest_hash, scenario_set_release_hash,
         evaluation_bundle_hash, expected_cell_set_hash, expected_slot_set_hash,
         trials_per_cell, created_at_ms
       ) VALUES ('experiment-1', ?, ?, ?, ?, ?, ?, 1, 1)''',
    <Object?>[
      '{"holdoutAccessPolicy":{"policyHash":"$holdoutPolicyHash"}}',
      _digest('5'),
      _digest('f'),
      _digest('e'),
      _digest('6'),
      _digest('8'),
    ],
  );
  db.execute(
    '''INSERT INTO eval_executions (
         execution_id, experiment_id, status, expected_cell_set_hash,
         expected_slot_set_hash, created_at_ms
       ) VALUES ('execution-1', 'experiment-1', 'created', ?, ?, 1)''',
    <Object?>[_digest('6'), _digest('8')],
  );
  db.execute(
    '''INSERT INTO eval_scorecards (
         scorecard_hash, execution_id, scope, scope_key, aggregate_json,
         input_set_hash, expected_set_hash, aggregator_release_hash,
         created_at_ms
       ) VALUES (?, 'execution-1', 'cell', 'regression-eligibility', '{}', ?, ?, ?, 1)''',
    <Object?>[_digest('9'), _digest('6'), _digest('8'), _digest('2')],
  );
  db.execute(
    '''INSERT INTO eval_release_gate_verdicts (
         verdict_hash, verdict_kind, experiment_id, execution_id,
         scorecard_hash, champion_bundle_hash, challenger_bundle_hash,
         status, reasons_json, comparison_input_set_hash,
         expected_pair_set_hash, policy_hash, gate_release_hash, created_at_ms
       ) VALUES (?, 'regression', 'experiment-1', 'execution-1', ?, ?, ?,
         'promote', '[]', ?, ?, ?, ?, 1)''',
    <Object?>[
      _digest('9'),
      _digest('9'),
      _digest('a'),
      _digest('b'),
      _digest('6'),
      _digest('8'),
      AgentEvaluationStandardGatePolicy.policyHash,
      AgentEvaluationStandardGatePolicy.gateReleaseHash,
    ],
  );
  db.execute(
    '''INSERT INTO eval_release_gate_derivations (
         verdict_hash, projection_hash, authority_release_hash, created_at_ms
       ) VALUES (?, ?, ?, 1)''',
    <Object?>[
      _digest('9'),
      _digest('a'),
      AgentEvaluationStandardGatePolicy.gateReleaseHash,
    ],
  );
}

Future<AgentEvaluationTrustedHoldoutAttestation> _signedAttestation(
  AgentEvaluationTrustedHoldoutSigner signer, {
  required String holdoutPolicyHash,
  required String accessId,
  required String tokenId,
  int? issuedAtMs,
  int? expiresAtMs,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return signer.sign(
    AgentEvaluationTrustedHoldoutAttestation(
      familyId: 'family-1',
      tokenId: tokenId,
      accessId: accessId,
      regressionVerdictHash: _digest('9'),
      championBundleHash: _digest('a'),
      challengerBundleHash: _digest('b'),
      executionId: 'execution-1',
      scenarioSetReleaseHash: _digest('f'),
      holdoutAccessPolicyHash: holdoutPolicyHash,
      evaluationBundleHash: _digest('e'),
      gatePolicyHash: AgentEvaluationStandardGatePolicy.policyHash,
      result: 'pass',
      fixtureReleaseHash: _digest('c'),
      auditRootHash: _digest('d'),
      runnerReleaseHash: AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
      keyId: signer.keyId,
      nonce: 'holdout-store-test-nonce-$accessId',
      issuedAtMs: issuedAtMs ?? now - 1000,
      expiresAtMs: expiresAtMs ?? now + 60000,
      signatureBase64: 'unsigned',
    ),
  );
}

String _insertHoldoutVerdict(
  Database db, {
  required String status,
  String? policyHash,
}) {
  final scorecardHash = _digest('d');
  db.execute(
    '''INSERT INTO eval_scorecards (
         scorecard_hash, execution_id, scope, scope_key, aggregate_json,
         input_set_hash, expected_set_hash, aggregator_release_hash,
         created_at_ms
       ) VALUES (?, 'execution-1', 'execution', 'execution-1', '{}', ?, ?, ?, 4)''',
    <Object?>[scorecardHash, _digest('6'), _digest('8'), _digest('2')],
  );
  final verdictHash = _digest(status == 'promote' ? 'c' : '0');
  db.execute(
    '''INSERT INTO eval_release_gate_verdicts (
         verdict_hash, verdict_kind, experiment_id, execution_id,
         scorecard_hash, champion_bundle_hash, challenger_bundle_hash,
         status, reasons_json, comparison_input_set_hash,
         expected_pair_set_hash, policy_hash, gate_release_hash, created_at_ms
       ) VALUES (?, 'holdout', 'experiment-1', 'execution-1', ?, ?, ?, ?,
         '[]', ?, ?, ?, ?, 4)''',
    <Object?>[
      verdictHash,
      scorecardHash,
      _digest('a'),
      _digest('b'),
      status,
      _digest('6'),
      _digest('8'),
      policyHash ?? AgentEvaluationStandardGatePolicy.policyHash,
      AgentEvaluationStandardGatePolicy.gateReleaseHash,
    ],
  );
  db.execute(
    '''INSERT INTO eval_release_gate_derivations (
         verdict_hash, projection_hash, authority_release_hash, created_at_ms
       ) VALUES (?, ?, ?, 4)''',
    <Object?>[
      verdictHash,
      _digest('a'),
      AgentEvaluationStandardGatePolicy.gateReleaseHash,
    ],
  );
  return verdictHash;
}

String _digest(String value) => List<String>.filled(64, value).join();
