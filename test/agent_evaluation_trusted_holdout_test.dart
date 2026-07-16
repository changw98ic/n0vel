import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'trusted subprocess hides private facts and derives result itself',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'trusted-holdout-process-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final seedFile = File('${root.path}/signing.seed')
        ..writeAsBytesSync(List<int>.generate(32, (index) => index));
      if (!Platform.isWindows) {
        expect(
          Process.runSync('chmod', <String>['600', seedFile.path]).exitCode,
          0,
        );
      }
      final signer = await AgentEvaluationTrustedHoldoutSigner.fromSeedFile(
        keyId: 'trusted-key-v1',
        path: seedFile.path,
      );
      final verifier = AgentEvaluationTrustedHoldoutVerifier(
        keyId: signer.keyId,
        publicKey: signer.publicKey,
        runnerReleaseHash:
            AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
      );
      final vaultPath = '${root.path}/private/holdout.sqlite';
      final vault = AgentEvaluationTrustedHoldoutVault.open(
        path: vaultPath,
        signer: signer,
      );
      const sentinel = 'PRIVATE-HOLDOUT-SENTINEL-DO-NOT-LEAK';
      final fixtureReleaseHash = vault.publishFixture(
        scenarioSetReleaseHash: _digest('f'),
        fixture: const <String, Object?>{
          'secret': sentinel,
          'candidateEvidenceSchema': 'exact-reference-facts-v1',
        },
        referenceFacts: const <String, Object?>{
          'expectedCandidateEvidence': <String, Object?>{
            'answer': 'expected-answer',
          },
          'privateNote': sentinel,
        },
        createdAtMs: 10,
        expiresAtMs: 100,
      );
      vault.dispose();

      final authorityPath = '${root.path}/authoring.sqlite';
      _createAuthorityDatabase(authorityPath);
      for (final access in <String>[
        'access-pass',
        'access-forged-pass',
        'access-before-created',
        'access-after-expiry',
      ]) {
        _addBegunAccess(authorityPath, access);
      }

      final pass = await _runTrustedProcess(
        root: root,
        authorityPath: authorityPath,
        vaultPath: vaultPath,
        seedPath: seedFile.path,
        request: _request(
          accessId: 'access-pass',
          fixtureReleaseHash: fixtureReleaseHash,
          candidateEvidence: const <String, Object?>{
            'answer': 'expected-answer',
          },
          issuedAtMs: 20,
          expiresAtMs: 90,
        ),
      );
      expect(pass.exitCode, 0, reason: pass.stderr as String);
      expect(pass.stdout as String, isNot(contains(sentinel)));
      expect(pass.stderr as String, isNot(contains(sentinel)));
      final attestation = _decodeAttestation(pass.stdout as String);
      expect(attestation.result, 'pass');
      expect(await verifier.verify(attestation, nowMs: 30), isTrue);

      final forgedPass = await _runTrustedProcess(
        root: root,
        authorityPath: authorityPath,
        vaultPath: vaultPath,
        seedPath: seedFile.path,
        request: _request(
          accessId: 'access-forged-pass',
          fixtureReleaseHash: fixtureReleaseHash,
          candidateEvidence: const <String, Object?>{'result': 'pass'},
          issuedAtMs: 20,
          expiresAtMs: 90,
        ),
      );
      expect(forgedPass.exitCode, 0, reason: forgedPass.stderr as String);
      final failedAttestation = _decodeAttestation(forgedPass.stdout as String);
      expect(failedAttestation.result, 'fail');
      expect(forgedPass.stdout as String, isNot(contains(sentinel)));
      expect(forgedPass.stderr as String, isNot(contains(sentinel)));

      final unspent = await _runTrustedProcess(
        root: root,
        authorityPath: authorityPath,
        vaultPath: vaultPath,
        seedPath: seedFile.path,
        request: _request(
          accessId: 'access-not-spent',
          fixtureReleaseHash: fixtureReleaseHash,
          candidateEvidence: const <String, Object?>{
            'answer': 'expected-answer',
          },
          issuedAtMs: 20,
          expiresAtMs: 90,
        ),
      );
      expect(unspent.exitCode, 2);
      expect(unspent.stdout as String, isEmpty);
      expect(unspent.stderr as String, isNot(contains(sentinel)));

      final beforeCreation = await _runTrustedProcess(
        root: root,
        authorityPath: authorityPath,
        vaultPath: vaultPath,
        seedPath: seedFile.path,
        request: _request(
          accessId: 'access-before-created',
          fixtureReleaseHash: fixtureReleaseHash,
          candidateEvidence: const <String, Object?>{
            'answer': 'expected-answer',
          },
          issuedAtMs: 9,
          expiresAtMs: 90,
        ),
      );
      expect(beforeCreation.exitCode, 2);
      expect(beforeCreation.stdout as String, isEmpty);
      expect(beforeCreation.stderr as String, isNot(contains(sentinel)));

      final afterExpiry = await _runTrustedProcess(
        root: root,
        authorityPath: authorityPath,
        vaultPath: vaultPath,
        seedPath: seedFile.path,
        request: _request(
          accessId: 'access-after-expiry',
          fixtureReleaseHash: fixtureReleaseHash,
          candidateEvidence: const <String, Object?>{
            'answer': 'expected-answer',
          },
          issuedAtMs: 20,
          expiresAtMs: 101,
        ),
      );
      expect(afterExpiry.exitCode, 2);
      expect(afterExpiry.stdout as String, isEmpty);
      expect(afterExpiry.stderr as String, isNot(contains(sentinel)));

      if (!Platform.isWindows) {
        expect(FileStat.statSync(vaultPath).mode & 0x3f, 0);
        expect(FileStat.statSync(seedFile.path).mode & 0x3f, 0);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('wrong signing root and replayed access fail closed', () async {
    final signer = await AgentEvaluationTrustedHoldoutSigner.fromSeed(
      keyId: 'trusted-key-v1',
      seed: List<int>.filled(32, 1),
    );
    final wrongSigner = await AgentEvaluationTrustedHoldoutSigner.fromSeed(
      keyId: 'trusted-key-v1',
      seed: List<int>.filled(32, 2),
    );
    final unsigned = AgentEvaluationTrustedHoldoutAttestation(
      familyId: 'family-1',
      tokenId: 'token-1',
      accessId: 'access-1',
      regressionVerdictHash: _digest('9'),
      championBundleHash: _digest('a'),
      challengerBundleHash: _digest('b'),
      executionId: 'execution-1',
      scenarioSetReleaseHash: _digest('f'),
      holdoutAccessPolicyHash: _digest('7'),
      evaluationBundleHash: _digest('e'),
      gatePolicyHash: _digest('6'),
      result: 'pass',
      fixtureReleaseHash: _digest('c'),
      auditRootHash: _digest('d'),
      runnerReleaseHash: AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
      keyId: signer.keyId,
      nonce: 'nonce-1',
      issuedAtMs: 1,
      expiresAtMs: 50,
      signatureBase64: 'unsigned',
    );
    final signedByWrongRoot = await wrongSigner.sign(unsigned);
    final verifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: signer.keyId,
      publicKey: signer.publicKey,
      runnerReleaseHash: AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
    );

    expect(await verifier.verify(signedByWrongRoot, nowMs: 10), isFalse);
    final valid = await signer.sign(unsigned);
    expect(await verifier.verify(valid, nowMs: 10), isTrue);
    expect(
      await verifier.verify(valid.copyWith(accessId: 'access-2'), nowMs: 10),
      isFalse,
    );
    expect(
      () => AgentEvaluationTrustedHoldoutVerifier(
        keyId: 'wrong-algorithm',
        publicKey: SimplePublicKey(
          List<int>.filled(32, 1),
          type: KeyPairType.x25519,
        ),
        runnerReleaseHash:
            AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
      ),
      throwsArgumentError,
    );
  });
}

AgentEvaluationTrustedHoldoutProcessRequest _request({
  required String accessId,
  required String fixtureReleaseHash,
  required Map<String, Object?> candidateEvidence,
  required int issuedAtMs,
  required int expiresAtMs,
}) => AgentEvaluationTrustedHoldoutProcessRequest(
  grant: _grant(accessId),
  fixtureReleaseHash: fixtureReleaseHash,
  candidateEvidence: candidateEvidence,
  nonce: 'nonce-$accessId',
  issuedAtMs: issuedAtMs,
  expiresAtMs: expiresAtMs,
);

AgentEvaluationTrustedHoldoutGrant _grant(String accessId) =>
    AgentEvaluationTrustedHoldoutGrant(
      familyId: 'family-1',
      tokenId: 'token-$accessId',
      accessId: accessId,
      regressionVerdictHash: _digest('9'),
      championBundleHash: _digest('a'),
      challengerBundleHash: _digest('b'),
      executionId: 'execution-$accessId',
      scenarioSetReleaseHash: _digest('f'),
      holdoutAccessPolicyHash: _digest('7'),
      evaluationBundleHash: _digest('e'),
      gatePolicyHash: _digest('6'),
    );

Future<ProcessResult> _runTrustedProcess({
  required Directory root,
  required String authorityPath,
  required String vaultPath,
  required String seedPath,
  required AgentEvaluationTrustedHoldoutProcessRequest request,
}) {
  final requestFile = File(
    '${root.path}/request-${request.grant.accessId}.json',
  )..writeAsStringSync(jsonEncode(request.toJson()), flush: true);
  return Process.run('dart', <String>[
    'run',
    'tool/agent_evaluation_trusted_holdout_runner.dart',
    '--authority-db',
    authorityPath,
    '--vault',
    vaultPath,
    '--seed-file',
    seedPath,
    '--key-id',
    'trusted-key-v1',
    '--request',
    requestFile.path,
  ], workingDirectory: Directory.current.path);
}

AgentEvaluationTrustedHoldoutAttestation _decodeAttestation(String output) {
  final decoded = jsonDecode(output);
  expect(decoded, isA<Map<String, Object?>>());
  final response = decoded as Map<String, Object?>;
  expect(response['schemaVersion'], 'trusted-holdout-process-response-v1');
  return AgentEvaluationTrustedHoldoutAttestation.fromStorage(
    payloadJson: response['payloadJson']! as String,
    signatureBase64: response['signatureBase64']! as String,
  );
}

void _createAuthorityDatabase(String path) {
  final db = sqlite3.open(path);
  try {
    db.execute('''
      CREATE TABLE eval_holdout_accesses (
        access_id TEXT PRIMARY KEY, token_id TEXT, family_id TEXT,
        challenger_bundle_hash TEXT, execution_id TEXT,
        trusted_runner_release_hash TEXT, state TEXT, begun_at_ms INTEGER
      );
      CREATE TABLE eval_holdout_tokens (
        token_id TEXT PRIMARY KEY, family_id TEXT,
        challenger_bundle_hash TEXT, state TEXT, consumed_at_ms INTEGER,
        regression_verdict_hash TEXT
      );
      CREATE TABLE eval_experiment_families (
        family_id TEXT PRIMARY KEY, scenario_set_release_hash TEXT,
        holdout_access_policy_hash TEXT
      );
      CREATE TABLE eval_executions (
        execution_id TEXT PRIMARY KEY, experiment_id TEXT
      );
      CREATE TABLE eval_experiments (
        experiment_id TEXT PRIMARY KEY, evaluation_bundle_hash TEXT
      );
      CREATE TABLE eval_release_gate_verdicts (
        verdict_hash TEXT PRIMARY KEY, verdict_kind TEXT, status TEXT,
        champion_bundle_hash TEXT, challenger_bundle_hash TEXT,
        policy_hash TEXT, gate_release_hash TEXT
      );
      CREATE TABLE eval_release_gate_derivations (
        verdict_hash TEXT, authority_release_hash TEXT
      );
    ''');
    db.execute(
      'INSERT INTO eval_experiment_families VALUES (?, ?, ?)',
      <Object?>['family-1', _digest('f'), _digest('7')],
    );
    db.execute('INSERT INTO eval_experiments VALUES (?, ?)', <Object?>[
      'experiment-1',
      _digest('e'),
    ]);
    db.execute(
      'INSERT INTO eval_release_gate_verdicts VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        _digest('9'),
        'regression',
        'promote',
        _digest('a'),
        _digest('b'),
        _digest('6'),
        _digest('8'),
      ],
    );
    db.execute(
      'INSERT INTO eval_release_gate_derivations VALUES (?, ?)',
      <Object?>[_digest('9'), _digest('8')],
    );
  } finally {
    db.dispose();
  }
}

void _addBegunAccess(String path, String accessId) {
  final db = sqlite3.open(path);
  try {
    final grant = _grant(accessId);
    db.execute(
      'INSERT INTO eval_holdout_tokens VALUES (?, ?, ?, ?, ?, ?)',
      <Object?>[
        grant.tokenId,
        grant.familyId,
        grant.challengerBundleHash,
        'consumed',
        10,
        grant.regressionVerdictHash,
      ],
    );
    db.execute('INSERT INTO eval_executions VALUES (?, ?)', <Object?>[
      grant.executionId,
      'experiment-1',
    ]);
    db.execute(
      'INSERT INTO eval_holdout_accesses VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        accessId,
        grant.tokenId,
        grant.familyId,
        grant.challengerBundleHash,
        grant.executionId,
        AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash,
        'begun',
        10,
      ],
    );
  } finally {
    db.dispose();
  }
}

String _digest(String character) => List<String>.filled(64, character).join();
