import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_holdout_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout_runner.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_executor.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_release_harness.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';

const _sentinel = 'PRIVATE-PROMPT-FACT-SENTINEL';

void main() {
  late Directory root;
  late File authority;
  late File plan;
  late File fixture;
  late File vault;
  late Directory work;
  late AgentEvaluationTrustedHoldoutSigner signer;
  late _RecordingExecution execution;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('private-production-runner-');
    _chmod(root.path, '700');
    signer = await AgentEvaluationTrustedHoldoutSigner.fromSeed(
      keyId: 'private-production-key',
      seed: List<int>.generate(32, (index) => index + 7),
    );
    fixture = File('${root.path}/private-fixture.sqlite');
    final fixtureDb = sqlite3.open(fixture.path);
    fixtureDb.execute('CREATE TABLE private_facts (id INTEGER, fact TEXT)');
    fixtureDb.execute(
      'INSERT INTO private_facts (id, fact) VALUES (1, ?)',
      <Object?>[_sentinel],
    );
    fixtureDb.dispose();
    _chmod(fixture.path, '600');
    plan = File('${root.path}/private-plan.json');
    final planJson = _privatePlanJson(
      fixturePath: fixture.path,
      fixtureAuditRootHash: agentEvaluationCanonicalSqliteAuditRoot(
        fixture.path,
      ),
    );
    plan.writeAsStringSync(planJson, flush: true);
    _chmod(plan.path, '600');
    authority = File('${root.path}/authority.sqlite');
    _seedAuthority(
      authority,
      signer,
      privatePlanHash: AgentEvaluationHashes.domainHash(
        'eval-production-holdout-private-plan-v1',
        jsonDecode(planJson) as Map<String, Object?>,
      ),
      opaqueScenarioSetHash:
          AgentEvaluationPrivateProductionPlan.scenarioSetHash(_scenarioSet()),
    );
    _chmod(authority.path, '600');
    vault = File('${root.path}/private-audit.sqlite');
    work = Directory('${root.path}/work');
    execution = _RecordingExecution();
  });

  tearDown(() => root.deleteSync(recursive: true));

  test(
    'offline protocol consumes private plan once and emits only commitments',
    () async {
      final runner = _runner(
        authority: authority,
        plan: plan,
        vault: vault,
        work: work,
        signer: signer,
        execution: execution,
      );

      final first = await runner.run();
      final vaultDb = sqlite3.open(vault.path);
      try {
        expect(
          () => vaultDb.execute('DELETE FROM production_holdout_runs'),
          throwsA(isA<SqliteException>()),
        );
        expect(
          () => vaultDb.execute(
            "UPDATE production_holdout_runs SET state = 'running'",
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(
          () => vaultDb.execute('DELETE FROM production_holdout_audit_events'),
          throwsA(isA<SqliteException>()),
        );
      } finally {
        vaultDb.dispose();
      }
      final replay = await runner.run();

      expect(execution.calls, 1);
      expect(execution.sawPrivateSentinel, isTrue);
      expect(replay.canonicalJson, first.canonicalJson);
      expect(first.canonicalJson, isNot(contains(_sentinel)));
      expect(first.canonicalJson, isNot(contains('prompt')));
      expect(first.canonicalJson, isNot(contains('fact')));
      expect(first.canonicalJson, isNot(contains(root.path)));
      expect(
        first.attestation.runnerReleaseHash,
        agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash,
      );
      expect(first.attestation.result, 'pass');
      expect(
        runner.verifySpentAuthority().holdoutAccessPolicyHash,
        AgentEvaluationTrustedHoldoutVerifier(
          keyId: signer.keyId,
          publicKey: signer.publicKey,
          runnerReleaseHash:
              agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash,
          resolverReleaseHash:
              AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
        ).trustPolicyHash,
      );
      expect(FileStat.statSync(vault.path).mode & 0x3f, 0);
      expect(FileStat.statSync(work.path).mode & 0x3f, 0);
      expect(
        latin1.decode(vault.readAsBytesSync()),
        isNot(contains(_sentinel)),
      );

      final purposeVerifier = AgentEvaluationTrustedHoldoutVerifier(
        keyId: signer.keyId,
        publicKey: signer.publicKey,
        runnerReleaseHash:
            agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
      );
      expect(
        await purposeVerifier.verifyProduction(
          first.attestation,
          nowMs: first.attestation.issuedAtMs,
        ),
        isTrue,
      );
      final productionVerifier = AgentEvaluationTrustedHoldoutVerifier(
        keyId: signer.keyId,
        publicKey: signer.publicKey,
        runnerReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
      );
      expect(
        await productionVerifier.verifyProduction(
          first.attestation,
          nowMs: first.attestation.issuedAtMs,
        ),
        isFalse,
      );
      final authorityDb = sqlite3.open(authority.path);
      try {
        final claim = await AgentEvaluationProductionHoldoutImporter(
          db: authorityDb,
          verifier: purposeVerifier,
        ).import(attestation: first.attestation, projection: first.projection);
        expect(claim.result, 'pass');
        await expectLater(
          AgentEvaluationReleaseStore(
            db: authorityDb,
            trustedHoldoutVerifier: productionVerifier,
          ).promoteVerified(
            decisionId: 'purpose-cannot-promote-production',
            channel: 'stable',
            expectedBundleHash: _digest('b'),
            expectedEpoch: 0,
            challengerBundleHash: _digest('c'),
            experimentId: 'regression-private',
            regressionVerdictHash: _digest('d'),
            productionHoldoutClaimHash: claim.claimHash,
            approver: 'release-bot',
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
          throwsA(isA<AgentEvaluationPromotionConflict>()),
        );
      } finally {
        authorityDb.dispose();
      }
    },
  );

  test('crash leaves the spent access fenced against a second probe', () async {
    final crashing = _RecordingExecution(throwAfterPrivateRead: true);
    final runner = _runner(
      authority: authority,
      plan: plan,
      vault: vault,
      work: work,
      signer: signer,
      execution: crashing,
    );

    await expectLater(runner.run(), throwsA(isA<StateError>()));
    expect(crashing.calls, 1);
    final token = sqlite3.open(authority.path, mode: OpenMode.readOnly);
    try {
      expect(
        token
            .select(
              "SELECT state FROM eval_holdout_tokens WHERE token_id = 'token-private'",
            )
            .single['state'],
        'consumed',
      );
    } finally {
      token.dispose();
    }
    final vaultDb = sqlite3.open(vault.path);
    try {
      expect(
        () => vaultDb.execute(
          "DELETE FROM production_holdout_runs WHERE access_id = 'access-private'",
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => vaultDb.execute(
          "UPDATE production_holdout_runs SET state = 'completed' "
          "WHERE access_id = 'access-private'",
        ),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      vaultDb.dispose();
    }

    await expectLater(
      runner.run(),
      throwsA(
        isA<AgentEvaluationPrivateHoldoutRunnerException>().having(
          (error) => error.message,
          'message',
          contains('already probed'),
        ),
      ),
    );
    expect(crashing.calls, 1);
  });

  test('spent grant is verified before a private plan is opened', () async {
    final invalidPlan = File('${root.path}/missing-private-plan.json');
    final runner = _runner(
      authority: authority,
      plan: invalidPlan,
      vault: vault,
      work: work,
      signer: signer,
      execution: execution,
      accessId: 'caller-selected-access',
    );

    expect(
      runner.verifySpentAuthority,
      throwsA(
        isA<AgentEvaluationPrivateHoldoutRunnerException>().having(
          (error) => error.message,
          'message',
          contains('authority is missing'),
        ),
      ),
    );
    await expectLater(
      runner.run(),
      throwsA(isA<AgentEvaluationPrivateHoldoutRunnerException>()),
    );
    expect(vault.existsSync(), isFalse);
    expect(execution.calls, 0);
  });

  test('private files reject loose ACLs and symlinks', () async {
    if (Platform.isWindows) return;
    _chmod(plan.path, '644');
    final loosePlanRunner = _runner(
      authority: authority,
      plan: plan,
      vault: vault,
      work: work,
      signer: signer,
      execution: execution,
    );
    await expectLater(
      loosePlanRunner.run(),
      throwsA(
        isA<AgentEvaluationPrivateHoldoutRunnerException>().having(
          (error) => error.message,
          'message',
          contains('mode 0600'),
        ),
      ),
    );
    expect(execution.calls, 0);

    // Use a fresh access/vault because the first ACL failure permanently
    // reserved the original access before it attempted to read private data.
    final linkedRoot = Directory.systemTemp.createTempSync(
      'private-plan-link-',
    );
    addTearDown(() => linkedRoot.deleteSync(recursive: true));
    final link = Link('${linkedRoot.path}/plan-link')..createSync(plan.path);
    final linkedAuthority = File('${linkedRoot.path}/authority.sqlite')
      ..writeAsBytesSync(authority.readAsBytesSync());
    _chmod(linkedAuthority.path, '600');
    final linkedRunner = _runner(
      authority: linkedAuthority,
      plan: File(link.path),
      vault: File('${linkedRoot.path}/vault.sqlite'),
      work: Directory('${linkedRoot.path}/work'),
      signer: signer,
      execution: execution,
    );
    await expectLater(
      linkedRunner.run(),
      throwsA(isA<AgentEvaluationPrivateHoldoutRunnerException>()),
    );
    expect(execution.calls, 0);
  });

  test('strict response parser rejects injected diagnostic fields', () async {
    final response = await _runner(
      authority: authority,
      plan: plan,
      vault: vault,
      work: work,
      signer: signer,
      execution: execution,
    ).run();
    for (final injected in <MapEntry<String, Object?>>[
      const MapEntry('result', 'pass'),
      const MapEntry('evaluator', 'caller-selected'),
      const MapEntry('timestamp', 0),
      const MapEntry('candidateEvidence', <String, Object?>{}),
      const MapEntry('privatePath', '/private/fixture'),
    ]) {
      expect(
        () => AgentEvaluationPrivateProductionProcessResponse.fromJson(
          <String, Object?>{...response.toJson(), injected.key: injected.value},
        ),
        throwsFormatException,
      );
    }
  });

  test('plan commitment mismatch is fenced without executing', () async {
    final decoded = jsonDecode(plan.readAsStringSync()) as Map<String, Object?>;
    decoded['fixture'] = <String, Object?>{
      ...(decoded['fixture']! as Map<String, Object?>),
      'databaseAuditRootHash': _digest('9'),
    };
    plan.writeAsStringSync(AgentEvaluationHashes.canonicalJson(decoded));
    _chmod(plan.path, '600');

    await expectLater(
      _runner(
        authority: authority,
        plan: plan,
        vault: vault,
        work: work,
        signer: signer,
        execution: execution,
      ).run(),
      throwsA(
        isA<AgentEvaluationPrivateHoldoutRunnerException>().having(
          (error) => error.message,
          'message',
          contains('not authority-bound'),
        ),
      ),
    );
    expect(execution.calls, 0);
  });

  test(
    'runtime config mismatch fails before private fixture or provider access',
    () async {
      final parsedPlan = AgentEvaluationPrivateProductionPlan.fromCanonicalJson(
        plan.readAsStringSync(),
      );
      final grant = AgentEvaluationPrivateProductionGrant(
        accessId: 'access-private',
        tokenId: 'token-private',
        familyId: 'family-private',
        regressionVerdictHash: _digest('d'),
        championBundleHash: _digest('b'),
        challengerBundleHash: _digest('c'),
        regressionScenarioSetHash: _digest('1'),
        opaqueHoldoutScenarioSetHash: parsedPlan.opaqueHoldoutScenarioSetHash,
        privatePlanHash: parsedPlan.planHash,
        holdoutAccessPolicyHash: _digest('2'),
        accessBudget: 1,
        accessOrdinal: 0,
      );
      final adapter =
          AgentEvaluationRealHarnessPrivateProductionExecution.auditOnly(
            configuration: _releaseConfiguration(),
          );

      await expectLater(
        adapter.run(grant: grant, plan: parsedPlan, privateWorkDirectory: work),
        throwsA(
          isA<AgentEvaluationPrivateHoldoutRunnerException>().having(
            (error) => error.message,
            'message',
            contains('does not match the runtime'),
          ),
        ),
      );
      expect(work.existsSync(), isFalse);
    },
  );

  test('audit private execution cannot enter real-provider harness', () async {
    final configuration = _releaseConfiguration();
    final boundPlan = AgentEvaluationPrivateProductionPlan.fromCanonicalJson(
      _privatePlanJson(
        fixturePath: fixture.path,
        fixtureAuditRootHash: agentEvaluationCanonicalSqliteAuditRoot(
          fixture.path,
        ),
        releaseConfiguration:
            AgentEvaluationRealHarnessPrivateProductionExecution.canonicalReleaseConfiguration(
              configuration,
            ),
      ),
    );
    await expectLater(
      AgentEvaluationRealHarnessPrivateProductionExecution.auditOnly(
        configuration: configuration,
      ).run(
        grant: _grant(boundPlan),
        plan: boundPlan,
        privateWorkDirectory: work,
      ),
      throwsA(
        isA<AgentEvaluationPrivateHoldoutRunnerException>().having(
          (error) => error.message,
          'message',
          contains('verified external custody'),
        ),
      ),
    );
  });

  test('private DB manifest cannot sign a different A/B pair', () {
    final parsedPlan = AgentEvaluationPrivateProductionPlan.fromCanonicalJson(
      plan.readAsStringSync(),
    );
    final manifest = <String, Object?>{
      'generationBundleHashes': <String>[_digest('c'), _digest('d')],
    };
    expect(
      () => validateAgentEvaluationPrivateManifestArmBinding(
        manifest: manifest,
        expectedManifestHash: AgentEvaluationHashes.domainHash(
          'eval-experiment-manifest-v1',
          manifest,
        ),
        grant: _grant(parsedPlan),
      ),
      throwsA(isA<AgentEvaluationPrivateHoldoutRunnerException>()),
    );
  });

  test('same-path fixture replacement fails before provider access', () async {
    final configuration = _releaseConfiguration();
    final originalAuditRoot = agentEvaluationCanonicalSqliteAuditRoot(
      fixture.path,
    );
    final boundPlan = AgentEvaluationPrivateProductionPlan.fromCanonicalJson(
      _privatePlanJson(
        fixturePath: fixture.path,
        fixtureAuditRootHash: originalAuditRoot,
        releaseConfiguration:
            AgentEvaluationRealHarnessPrivateProductionExecution.canonicalReleaseConfiguration(
              configuration,
            ),
      ),
    );
    fixture.deleteSync();
    final replacement = sqlite3.open(fixture.path);
    replacement.execute('CREATE TABLE replacement (value TEXT)');
    replacement.execute("INSERT INTO replacement VALUES ('attacker')");
    replacement.dispose();
    _chmod(fixture.path, '600');

    await expectLater(
      AgentEvaluationRealHarnessPrivateProductionExecution.auditOnly(
        configuration: configuration,
      ).run(
        grant: _grant(boundPlan),
        plan: boundPlan,
        privateWorkDirectory: work,
      ),
      throwsA(
        isA<AgentEvaluationPrivateHoldoutRunnerException>().having(
          (error) => error.message,
          'message',
          contains('commitment changed'),
        ),
      ),
    );
    expect(File('${work.path}/fixture-snapshot.sqlite').existsSync(), isFalse);
  });

  test(
    'concurrent accesses reserve one consistent append-only audit chain',
    () async {
      final secondScenarioSet = <String, Object?>{
        ..._scenarioSet(),
        'setId': 'opaque-private-ten-scenario-v2',
      };
      final secondPlan = File('${root.path}/private-plan-2.json');
      secondPlan.writeAsStringSync(
        _privatePlanJson(
          fixturePath: fixture.path,
          fixtureAuditRootHash: agentEvaluationCanonicalSqliteAuditRoot(
            fixture.path,
          ),
          scenarioSet: secondScenarioSet,
        ),
        flush: true,
      );
      _chmod(secondPlan.path, '600');
      final secondAuthority = File('${root.path}/authority-2.sqlite');
      _seedAuthority(
        secondAuthority,
        signer,
        privatePlanHash: AgentEvaluationHashes.domainHash(
          'eval-production-holdout-private-plan-v1',
          jsonDecode(secondPlan.readAsStringSync()) as Map<String, Object?>,
        ),
        opaqueScenarioSetHash:
            AgentEvaluationPrivateProductionPlan.scenarioSetHash(
              secondScenarioSet,
            ),
        familyId: 'family-private-2',
        tokenId: 'token-private-2',
        accessId: 'access-private-2',
      );
      _chmod(secondAuthority.path, '600');
      final firstExecution = _RecordingExecution(
        delay: const Duration(milliseconds: 20),
      );
      final secondExecution = _RecordingExecution(
        delay: const Duration(milliseconds: 20),
      );
      final responses = await Future.wait(
        <Future<AgentEvaluationPrivateProductionProcessResponse>>[
          _runner(
            authority: authority,
            plan: plan,
            vault: vault,
            work: Directory('${root.path}/work-1'),
            signer: signer,
            execution: firstExecution,
          ).run(),
          _runner(
            authority: secondAuthority,
            plan: secondPlan,
            vault: vault,
            work: Directory('${root.path}/work-2'),
            signer: signer,
            execution: secondExecution,
            accessId: 'access-private-2',
          ).run(),
        ],
      );
      final db = sqlite3.open(vault.path, mode: OpenMode.readOnly);
      try {
        final events = db.select(
          '''SELECT * FROM production_holdout_audit_events
           ORDER BY event_ordinal''',
        );
        expect(events, hasLength(2));
        expect(events[0]['event_ordinal'], 0);
        expect(events[0]['previous_event_hash'], isNull);
        expect(events[1]['event_ordinal'], 1);
        expect(events[1]['previous_event_hash'], events[0]['event_hash']);
        expect(
          responses.map((value) => value.attestation.auditRootHash).toSet(),
          events.map((row) => row['event_hash']).toSet(),
        );
      } finally {
        db.dispose();
      }
    },
  );

  test(
    'expired completed response refreshes TTL without a second execution',
    () async {
      var nowMs = DateTime.now().millisecondsSinceEpoch;
      final runner = _runner(
        authority: authority,
        plan: plan,
        vault: vault,
        work: work,
        signer: signer,
        execution: execution,
        clock: () => nowMs,
      );
      final original = await runner.run();
      nowMs = original.attestation.expiresAtMs + 1;

      final refreshed = await runner.run();

      expect(execution.calls, 1);
      expect(
        refreshed.attestation.claimHash,
        isNot(original.attestation.claimHash),
      );
      expect(
        refreshed.attestation.auditRootHash,
        isNot(original.attestation.auditRootHash),
      );
      expect(
        refreshed.projection.executionSummaryJson,
        original.projection.executionSummaryJson,
      );
      expect(refreshed.attestation.issuedAtMs, nowMs);
      final db = sqlite3.open(vault.path, mode: OpenMode.readOnly);
      try {
        expect(
          db.select('SELECT * FROM production_holdout_refresh_slots'),
          hasLength(1),
        );
        expect(
          db.select('SELECT * FROM production_holdout_response_refreshes'),
          hasLength(1),
        );
        final run = db.select('SELECT * FROM production_holdout_runs').single;
        expect(run['response_json'], original.canonicalJson);
        final slot = db
            .select('SELECT * FROM production_holdout_refresh_slots')
            .single;
        expect(
          slot['previous_audit_root_hash'],
          original.attestation.auditRootHash,
        );
        expect(slot['refresh_root_hash'], refreshed.attestation.auditRootHash);
      } finally {
        db.dispose();
      }
      final writeDb = sqlite3.open(vault.path);
      try {
        expect(
          () => writeDb.execute('DELETE FROM production_holdout_refresh_slots'),
          throwsA(isA<SqliteException>()),
        );
        expect(
          () => writeDb.execute(
            'UPDATE production_holdout_response_refreshes '
            "SET prior_claim_hash = '${_digest('f')}'",
          ),
          throwsA(isA<SqliteException>()),
        );
      } finally {
        writeDb.dispose();
      }
      final verifier = AgentEvaluationTrustedHoldoutVerifier(
        keyId: signer.keyId,
        publicKey: signer.publicKey,
        runnerReleaseHash:
            agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
      );
      expect(
        await verifier.verifyProduction(
          refreshed.attestation,
          nowMs: refreshed.attestation.issuedAtMs,
        ),
        isTrue,
      );
      expect(
        await verifier.verifyProductionSignature(
          refreshed.attestation.copyWith(accessId: 'other-access'),
        ),
        isFalse,
      );
      expect((await runner.run()).canonicalJson, refreshed.canonicalJson);
      expect(execution.calls, 1);
    },
  );
}

AgentEvaluationPrivateProductionHoldoutRunner _runner({
  required File authority,
  required File plan,
  required File vault,
  required Directory work,
  required AgentEvaluationTrustedHoldoutSigner signer,
  required AgentEvaluationPrivateProductionExecution execution,
  String accessId = 'access-private',
  int Function()? clock,
}) => AgentEvaluationPrivateProductionHoldoutRunner.purposeBuilt(
  authorityDatabasePath: authority.path,
  accessId: accessId,
  privatePlanPath: plan.path,
  vaultPath: vault.path,
  privateWorkDirectory: work,
  signer: signer,
  execution: execution,
  clock: clock,
);

final class _RecordingExecution
    implements AgentEvaluationPrivateProductionExecution {
  _RecordingExecution({
    this.throwAfterPrivateRead = false,
    this.delay = Duration.zero,
  });

  final bool throwAfterPrivateRead;
  final Duration delay;
  var calls = 0;
  var sawPrivateSentinel = false;

  @override
  Future<AgentEvaluationPrivateProductionArtifacts> run({
    required AgentEvaluationPrivateProductionGrant grant,
    required AgentEvaluationPrivateProductionPlan plan,
    required Directory privateWorkDirectory,
  }) async {
    calls += 1;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    sawPrivateSentinel = AgentEvaluationHashes.canonicalJson(<String, Object?>{
      'scenarioSet': plan.scenarioSet,
      'fixture': plan.fixture,
    }).contains(_sentinel);
    if (throwAfterPrivateRead) throw StateError('simulated private crash');
    final projection = _projection();
    return AgentEvaluationPrivateProductionArtifacts(
      productionManifestHash: _digest('e'),
      privateExecutionSummaryHash: _digest('7'),
      privateScorecardHash: _digest('8'),
      privateGateVerdictHash: _digest('9'),
      privateProjectionHash: _digest('a'),
      expectedCellSetHash: _digest('4'),
      expectedSlotSetHash: _digest('5'),
      executionBudgetPolicyHash: _digest('f'),
      executorReleaseHash: _digest('0'),
      evaluationBundleHash: _digest('e'),
      priceTableHash: _digest('f'),
      gatePolicyHash: AgentEvaluationStandardGatePolicy.policyHash,
      projection: projection,
    );
  }
}

AgentEvaluationPrivateProductionGrant _grant(
  AgentEvaluationPrivateProductionPlan plan,
) => AgentEvaluationPrivateProductionGrant(
  accessId: 'access-private',
  tokenId: 'token-private',
  familyId: 'family-private',
  regressionVerdictHash: _digest('d'),
  championBundleHash: _digest('b'),
  challengerBundleHash: _digest('c'),
  regressionScenarioSetHash: _digest('1'),
  opaqueHoldoutScenarioSetHash: plan.opaqueHoldoutScenarioSetHash,
  privatePlanHash: plan.planHash,
  holdoutAccessPolicyHash: _digest('2'),
  accessBudget: 2,
  accessOrdinal: 0,
);

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

Map<String, Object?> _scenarioSet() => <String, Object?>{
  'setId': 'opaque-private-ten-scenario-v1',
  'version': '1.0.0',
  'holdout': true,
  'fixtureCount': 10,
  'outlineSceneCount': 10,
  'createdAtMs': 1,
  'scenarios': <Object?>[
    for (var index = 0; index < 10; index += 1)
      <String, Object?>{
        'scenarioId': 'private-${index + 1}',
        'version': '1.0.0',
        'difficulty': 'holdout',
        'inputFixture': <String, Object?>{'prompt': '$_sentinel-${index + 1}'},
        'fixtureHash': _digest('${index % 10}'),
        'isolationMode': 'independent',
        'episodeId': 'private-episode',
        'episodeStep': index + 1,
        'requiredCapabilities': <String>['chapter-generation'],
        'adversarialMutations': <String>[],
        'verifierReleaseRefs': <String>[],
        'rubricReleaseRef': 'private-rubric-v1',
        'expectedTerminalState': 'completed',
        'requiredFailureCodes': <String>[],
        'allowedAdditionalFailureCodes': <String>[],
        'forbiddenFailureCodes': <String>[],
        'outcomeComparatorReleaseRef': 'private-comparator-v1',
        'forbiddenSideEffects': <String>[],
        'acceptExpected': true,
        'referenceFacts': <String, Object?>{'privateFact': _sentinel},
        'maxBudget': <String, Object?>{'providerCalls': 48, 'tokens': 100000},
      },
  ],
};

String _privatePlanJson({
  required String fixturePath,
  required String fixtureAuditRootHash,
  Map<String, Object?>? releaseConfiguration,
  Map<String, Object?>? scenarioSet,
}) {
  final scenarios = scenarioSet ?? _scenarioSet();
  return AgentEvaluationHashes.canonicalJson(<String, Object?>{
    'schemaVersion': AgentEvaluationPrivateProductionPlan.schemaVersion,
    'opaqueHoldoutScenarioSetHash':
        AgentEvaluationPrivateProductionPlan.scenarioSetHash(scenarios),
    'scenarioSet': scenarios,
    'fixture': <String, Object?>{
      'databasePath': fixturePath,
      'databaseAuditRootHash': fixtureAuditRootHash,
    },
    'releaseConfiguration':
        releaseConfiguration ??
        <String, Object?>{
          'matrix': '10-scenarios-2-arms-3-slots',
          'budgetPolicy': 'frozen-explicit-v1',
        },
  });
}

void _seedAuthority(
  File file,
  AgentEvaluationTrustedHoldoutSigner signer, {
  required String privatePlanHash,
  required String opaqueScenarioSetHash,
  String familyId = 'family-private',
  String tokenId = 'token-private',
  String accessId = 'access-private',
}) {
  final db = sqlite3.open(file.path);
  try {
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    db.execute(
      '''INSERT INTO generation_bundles
         (bundle_hash, bundle_id, releases_json, created_at_ms)
         VALUES (?, 'champion-private', '[]', 1),
                (?, 'challenger-private', '[]', 1)''',
      <Object?>[_digest('b'), _digest('c')],
    );
    db.execute(
      '''INSERT INTO evaluation_bundles (
           evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
           judges_json, rubric_release_hash, aggregator_release_hash,
           failure_taxonomy_hash, blinding_policy_version, created_at_ms
         ) VALUES (?, 'eval-private', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
      <Object?>[_digest('e'), _digest('1'), _digest('2'), _digest('3')],
    );
    db.execute(
      '''INSERT INTO eval_scenario_sets (
           scenario_set_release_hash, set_id, version, manifest_hash,
           created_at_ms
         ) VALUES (?, 'regression-private', '1', ?, 1)''',
      <Object?>[_digest('1'), _digest('2')],
    );
    db.execute(
      '''INSERT INTO eval_experiments (
           experiment_id, manifest_json, manifest_hash,
           scenario_set_release_hash, evaluation_bundle_hash,
           expected_cell_set_hash, expected_slot_set_hash, trials_per_cell,
           created_at_ms
         ) VALUES ('regression-private', '{}', ?, ?, ?, ?, ?, 3, 1)''',
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
         ) VALUES ('regression-execution-private', 'regression-private',
           'completed', ?, ?, 1, 2, 3)''',
      <Object?>[_digest('4'), _digest('5')],
    );
    db.execute(
      '''INSERT INTO eval_scorecards (
           scorecard_hash, execution_id, scope, scope_key, aggregate_json,
           input_set_hash, expected_set_hash, aggregator_release_hash,
           created_at_ms
         ) VALUES (?, 'regression-execution-private', 'execution',
           'regression-execution-private', '{}', ?, ?, ?, 3)''',
      <Object?>[_digest('7'), _digest('6'), _digest('5'), _digest('2')],
    );
    db.execute(
      '''INSERT INTO eval_release_gate_verdicts (
           verdict_hash, verdict_kind, experiment_id, execution_id,
           scorecard_hash, champion_bundle_hash, challenger_bundle_hash,
           status, reasons_json, comparison_input_set_hash,
           expected_pair_set_hash, policy_hash, gate_release_hash,
           created_at_ms
         ) VALUES (?, 'regression', 'regression-private',
           'regression-execution-private', ?, ?, ?, 'promote', '[]', ?, ?, ?, ?, 4)''',
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
         ) VALUES (?, 'price-private', 'USD', '{}',
           'ceil-per-attempt-microusd-v1', 1)''',
      <Object?>[_digest('f')],
    );
    final verifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: signer.keyId,
      publicKey: signer.publicKey,
      runnerReleaseHash:
          agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
    );
    final holdout = AgentEvaluationHoldoutStore(
      db: db,
      trustedHoldoutVerifier: verifier,
    );
    holdout.createProductionFamily(
      familyId: familyId,
      productionAuthorityHash: AgentEvaluationHashes.domainHash(
        'purpose-built-production-family-authority-v1',
        <String, Object?>{
          'familyId': familyId,
          'privatePlanHash': privatePlanHash,
        },
      ),
      regressionScenarioSetHash: _digest('1'),
      opaqueHoldoutScenarioSetHash: opaqueScenarioSetHash,
      privatePlanHash: privatePlanHash,
      holdoutAccessPolicyHash: verifier.trustPolicyHash,
      maxAccesses: 1,
      alphaBudgetMicros: 50000,
      createdAtMs: 1,
    );
    holdout.registerChallenger(
      familyId: familyId,
      challengerBundleHash: _digest('c'),
      registeredAtMs: 1,
    );
    holdout.issueToken(
      tokenId: tokenId,
      familyId: familyId,
      challengerBundleHash: _digest('c'),
      regressionVerdictHash: _digest('d'),
      alphaCostMicros: 50000,
      issuedAtMs: 2,
    );
    holdout.beginProductionHoldoutAccess(
      accessId: accessId,
      tokenId: tokenId,
      challengerBundleHash: _digest('c'),
    );
  } finally {
    db.dispose();
  }
}

String _digest(String value) => value * 64;

AgentEvaluationRealReleaseConfiguration _releaseConfiguration() {
  final sut = AgentEvaluationProductionRouteRelease(
    model: 'glm-private-sut',
    provider: AppLlmProvider.zhipu,
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    apiKey: 'not-used-before-binding',
    timeout: const AppLlmTimeoutConfig.uniform(30000),
    providerApiRevision: 'private-api-v1',
    sdkAdapterReleaseHash: _digest('1'),
  );
  final judge = AgentEvaluationProductionRouteRelease(
    model: 'glm-private-judge',
    provider: AppLlmProvider.zhipu,
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    apiKey: 'not-used-before-binding',
    timeout: const AppLlmTimeoutConfig.uniform(30000),
    providerApiRevision: 'private-api-v1',
    sdkAdapterReleaseHash: _digest('1'),
  );
  return AgentEvaluationRealReleaseConfiguration(
    executionId: 'private-config-binding',
    sutRoutes: <AgentEvaluationProductionRouteRelease>[sut],
    judgeRoute: judge,
    decoding: AgentEvaluationProductionDecodingRelease.standard(),
    maxAttemptsPerTrial: 1,
    maxCallsPerTrial: 64,
    maxTokensPerTrial: 10000000,
    maxPromptTokensPerCall: 100000,
    maxCompletionTokensPerCall: 4096,
    maxProviderCalls: 100000,
    maxTotalTokens: 1000000000,
    maxTotalCostMicrousd: 100000000,
    evaluatorMaxCalls: 60,
    evaluatorMaxTokens: 10000000,
    evaluatorMaxCostMicrousd: 1000000,
    evaluatorTokensPerCall: 4096,
    evaluatorCostMicrousdPerCall: 1000,
    promptMicrousdPerMillionTokens: 1,
    completionMicrousdPerMillionTokens: 1,
    judgePromptMicrousdPerMillionTokens: 1,
    judgeCompletionMicrousdPerMillionTokens: 1,
    deadline: const Duration(minutes: 5),
    holdoutAccessBudget: 1,
    codeCommit: 'private-test-commit',
    sourceTreeHash: _digest('2'),
    buildArtifactHash: _digest('3'),
    runtimeReleaseHash: _digest('4'),
    tokenizerReleaseHash: _digest('5'),
  );
}

void _chmod(String path, String mode) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>[mode, path]);
  if (result.exitCode != 0) throw StateError('chmod failed');
}
