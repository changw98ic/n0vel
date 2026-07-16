import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/agent_evaluation_release_coordinator_runtime.dart';
import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_holdout_reuse_authority.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_holdout_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout_runner.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_executor.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_release_harness.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_cas_authority.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_spec_evidence.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trace_context.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support/agent_evaluation_production_protocol_client.dart';

const _privateSentinel = 'PRIVATE-COORDINATOR-SENTINEL';

void main() {
  late Directory suiteRoot;
  late AgentEvaluationRealReleaseResult publicTemplate;
  late File privatePlan;
  late File privateFixture;
  late File seedFile;
  late AgentEvaluationTrustedHoldoutSigner signer;
  late String opaqueScenarioSetHash;
  late String privatePlanHash;
  late AgentEvaluationRealReleaseConfiguration releaseConfiguration;

  AgentEvaluationPrivateReleaseCommitment commitment(
    File vault, {
    String? planPath,
  }) => AgentEvaluationPrivateReleaseCommitment(
    privatePlanHash: privatePlanHash,
    opaqueScenarioSetHash: opaqueScenarioSetHash,
    keyId: signer.keyId,
    publicKey: signer.publicKey,
    privatePlanPath: planPath ?? privatePlan.path,
    vaultPath: vault.path,
    seedFilePath: seedFile.path,
  );

  setUpAll(() async {
    suiteRoot = Directory.systemTemp.createTempSync(
      'release-coordinator-suite-',
    );
    _chmod(suiteRoot.path, '700');
    final publicRoot = Directory('${suiteRoot.path}/public');
    releaseConfiguration = _configuration();
    final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
      configuration: releaseConfiguration,
      sutClient: _PromotableChallengerClient(),
      judgeClient: _PromotableMarkerJudgeClient(),
      outputDirectory: Directory('${publicRoot.path}/reports'),
      workDirectory: Directory('${publicRoot.path}/work'),
    );
    try {
      publicTemplate = await harness.run();
    } finally {
      harness.dispose();
    }
    expect(publicTemplate.partitions.single.regressionStatus, 'promote');

    privateFixture = File('${suiteRoot.path}/private-fixture.sqlite');
    final fixtureDb = sqlite3.open(privateFixture.path);
    fixtureDb.execute('CREATE TABLE private_facts (id INTEGER, fact TEXT)');
    fixtureDb.execute(
      'INSERT INTO private_facts (id, fact) VALUES (1, ?)',
      <Object?>[_privateSentinel],
    );
    fixtureDb.dispose();
    _chmod(privateFixture.path, '600');

    final scenarioSet = _scenarioSet();
    opaqueScenarioSetHash =
        AgentEvaluationPrivateProductionPlan.scenarioSetHash(scenarioSet);
    final planPayload = <String, Object?>{
      'schemaVersion': AgentEvaluationPrivateProductionPlan.schemaVersion,
      'opaqueHoldoutScenarioSetHash': opaqueScenarioSetHash,
      'scenarioSet': scenarioSet,
      'fixture': <String, Object?>{
        'databasePath': privateFixture.path,
        'databaseAuditRootHash': agentEvaluationCanonicalSqliteAuditRoot(
          privateFixture.path,
        ),
      },
      'releaseConfiguration':
          AgentEvaluationRealHarnessPrivateProductionExecution.canonicalReleaseConfiguration(
            releaseConfiguration,
          ),
    };
    privatePlan = File('${suiteRoot.path}/private-plan.json')
      ..writeAsStringSync(
        AgentEvaluationHashes.canonicalJson(planPayload),
        flush: true,
      );
    _chmod(privatePlan.path, '600');
    privatePlanHash = AgentEvaluationHashes.domainHash(
      'eval-production-holdout-private-plan-v1',
      planPayload,
    );

    seedFile = File('${suiteRoot.path}/private-signing-seed.bin')
      ..writeAsBytesSync(
        List<int>.generate(32, (index) => index + 17),
        flush: true,
      );
    _chmod(seedFile.path, '600');
    signer = await AgentEvaluationTrustedHoldoutSigner.fromSeedFile(
      keyId: 'purpose-coordinator-key-v1',
      path: seedFile.path,
    );
  });

  tearDownAll(() {
    if (suiteRoot.existsSync()) suiteRoot.deleteSync(recursive: true);
  });

  test(
    'complete phase rebuilds public result from a frozen capability only',
    () async {
      final root = Directory('${suiteRoot.path}/two-phase-capability')
        ..createSync();
      _chmod(root.path, '700');
      final phase1 = _copyPublicTemplate(publicTemplate, root);
      final commitments = _publicCommitmentsForTest(
        phase1,
        releaseConfiguration,
      );
      final commitmentsHash = AgentEvaluationHashes.domainHash(
        'agent-evaluation-public-release-commitments-v1',
        commitments,
      );
      final capability =
          File(
            '${root.path}/public-capability-'
            '${releaseConfiguration.executionId}.json',
          )..writeAsStringSync(
            AgentEvaluationHashes.canonicalJson(<String, Object?>{
              'schemaVersion': 'agent-evaluation-public-release-capability-v1',
              'publicCommitments': commitments,
              'publicCommitmentsHash': commitmentsHash,
            }),
            flush: true,
          );
      _chmod(capability.path, '600');
      final environment = <String, String>{
        'AGENT_EVAL_COORDINATOR_WORK_DIR': root.path,
        'AGENT_EVAL_PUBLIC_CAPABILITY_PATH': capability.path,
        'AGENT_EVAL_PUBLIC_CAPABILITY_HASH': commitmentsHash,
      };

      final recovered = recoverAgentEvaluationPublicCapability(
        environment: environment,
        configuration: releaseConfiguration,
        realProviderEvidence: false,
      );
      expect(
        AgentEvaluationHashes.canonicalJson(recovered.commitments),
        AgentEvaluationHashes.canonicalJson(commitments),
      );
      expect(recovered.result.reportPath, phase1.reportPath);

      final canonical = capability.readAsStringSync();
      capability.writeAsStringSync('$canonical\n', flush: true);
      expect(
        () => recoverAgentEvaluationPublicCapability(
          environment: environment,
          configuration: releaseConfiguration,
          realProviderEvidence: false,
        ),
        throwsA(anything),
      );
      capability.writeAsStringSync(canonical, flush: true);
      File(
        phase1.authorityDatabasePath,
      ).renameSync('${phase1.authorityDatabasePath}.original');
      sqlite3.open(phase1.authorityDatabasePath).dispose();
      expect(
        () => recoverAgentEvaluationPublicCapability(
          environment: environment,
          configuration: releaseConfiguration,
          realProviderEvidence: false,
        ),
        throwsA(anything),
      );
    },
  );

  test(
    'real provider harness rejects caller pricing before custody or provider IO',
    () {
      final root = Directory('${suiteRoot.path}/missing-public-custody')
        ..createSync();
      _chmod(root.path, '700');
      expect(
        () => AgentEvaluationRealReleaseHarness.realProvider(
          configuration: _configuration(),
          outputDirectory: Directory('${root.path}/reports'),
          workDirectory: Directory('${root.path}/work'),
          releaseBudgetDirectory: Directory('${root.path}/release-budget'),
        ),
        throwsArgumentError,
      );
    },
  );

  test('audit custody binding is not a production custody token', () {
    final auditBinding =
        AgentEvaluationPublicCustodyCapability.auditOnlyForTest(
          capabilityHash: 'a' * 64,
          attestationHash: 'b' * 64,
          verifiedAtMs: 1,
          nonce: 'audit-${'n' * 40}',
        );
    expect(
      auditBinding,
      isNot(isA<AgentEvaluationVerifiedProductionCustodyToken>()),
    );
  });

  test(
    'local seed can exercise rollback but cannot become release authority',
    () async {
      final runRoot = Directory('${suiteRoot.path}/success')..createSync();
      _chmod(runRoot.path, '700');
      final publicResult = _copyPublicTemplate(publicTemplate, runRoot);
      final vault = File('${runRoot.path}/private-vault.sqlite');
      final coordinator = AgentEvaluationReleaseCoordinator.purposeBuilt(
        coordinatorRunId: 'purpose-coordinator-success',
        publicResult: publicResult,
        privateCommitment: commitment(vault),
        privateRunnerCommand: _purposeCommand(),
        workDirectory: Directory('${runRoot.path}/work'),
        reportDirectory: Directory('${runRoot.path}/reports'),
        channel: 'purpose-release',
        approver: 'offline-verifier',
        processTimeout: const Duration(minutes: 3),
        requiredModelRouteHashes: releaseConfiguration.sutRoutes.map(
          (route) => route.modelRouteHash,
        ),
      );

      final result = await coordinator.run();

      final canonicalMaterial = Directory(
        '${runRoot.path}/work/purpose-private-material-'
        '${privatePlanHash.substring(0, 16)}',
      );
      final canonicalFixture = File('${canonicalMaterial.path}/fixture.sqlite');
      expect(canonicalMaterial.existsSync(), isTrue);
      expect(
        File('${canonicalMaterial.path}/private-plan.json').readAsStringSync(),
        privatePlan.readAsStringSync(),
      );
      expect(
        agentEvaluationCanonicalSqliteAuditRoot(canonicalFixture.path),
        agentEvaluationCanonicalSqliteAuditRoot(privateFixture.path),
      );
      expect(File('${canonicalMaterial.path}/seal.json').existsSync(), isTrue);

      expect(result.releaseEligible, isFalse);
      expect(result.realProviderEvidence, isFalse);
      expect(result.finalChannelEpoch, 2);
      expect(result.productionHoldoutClaimHash, hasLength(64));
      expect(File(result.reportPath).existsSync(), isTrue);
      expect(result.reportHash, hasLength(64));
      final finalReport =
          jsonDecode(File(result.reportPath).readAsStringSync())
              as Map<String, Object?>;
      final custody = finalReport['custody']! as Map<String, Object?>;
      expect(custody['mode'], 'local-file-seed');
      expect(custody['releaseAuthorityEligible'], isFalse);
      await verifyAgentEvaluationFinalReportSeal(
        reportPath: result.reportPath,
        expectedReportHash: result.reportHash,
        authorityDatabasePath: publicResult.authorityDatabasePath,
      );
      expect(
        Directory('${runRoot.path}/work/private-child').existsSync(),
        isFalse,
      );
      final report = File(result.reportPath).readAsStringSync();
      expect(report, contains('"productionHoldoutResult": "pass"'));
      expect(report, contains('"claimScope": "real-provider-release"'));
      expect(
        report,
        contains('"schemaVersion": "spec-criteria-registry-seal-v1"'),
      );
      expect(report, contains('"criteriaId": "AEE-01"'));
      expect(report, contains('"criteriaId": "AEE-24"'));
      expect(report, contains('"mode": "local-file-seed"'));
      expect(report, contains('"releaseAuthorityEligible": false'));
      expect(report, contains('"level": "audit"'));
      expect(report, contains('"supportsRegrade": false'));
      expect(report, contains('"supportsReExecute": false'));
      expect(report, isNot(contains('immutable-release-archive')));
      expect(
        report,
        contains('"exitSemantics": "promoted-then-verified-rollback"'),
      );
      for (final secret in <String>[
        _privateSentinel,
        privatePlan.path,
        privateFixture.path,
        seedFile.path,
        vault.path,
        'sut-test-secret',
        'judge-test-secret',
        'apiKey',
        'baseUrl',
      ]) {
        expect(report, isNot(contains(secret)));
      }
      File(result.reportPath).writeAsStringSync('$report\n', flush: true);
      await expectLater(
        () async => verifyAgentEvaluationFinalReportSeal(
          reportPath: result.reportPath,
          expectedReportHash: result.reportHash,
          authorityDatabasePath: publicResult.authorityDatabasePath,
        ),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );
      File(result.reportPath).writeAsStringSync(report, flush: true);
      final unsealedAuthority = File(
        '${runRoot.path}/unsealed-authority.sqlite',
      );
      File(publicResult.authorityDatabasePath).copySync(unsealedAuthority.path);
      final unsealedDb = sqlite3.open(unsealedAuthority.path);
      unsealedDb.execute(
        'DROP TRIGGER prevent_eval_final_release_report_seals_delete',
      );
      unsealedDb.execute('DELETE FROM eval_final_release_report_seals');
      unsealedDb.dispose();
      await expectLater(
        () async => verifyAgentEvaluationFinalReportSeal(
          reportPath: result.reportPath,
          expectedReportHash: result.reportHash,
          authorityDatabasePath: unsealedAuthority.path,
        ),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );

      final forgedAuthority = File('${runRoot.path}/forged-authority.sqlite');
      File(publicResult.authorityDatabasePath).copySync(forgedAuthority.path);
      final forgedDb = sqlite3.open(forgedAuthority.path);
      forgedDb.execute('CREATE TABLE eval_forged_authority (value TEXT)');
      forgedDb.execute(
        'INSERT INTO eval_forged_authority (value) VALUES (?)',
        <Object?>['self-consistent-hash-bypass'],
      );
      forgedDb.dispose();
      await expectLater(
        () async => verifyAgentEvaluationFinalReportSeal(
          reportPath: result.reportPath,
          expectedReportHash: result.reportHash,
          authorityDatabasePath: forgedAuthority.path,
        ),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );

      final triggerTamperedAuthority = File(
        '${runRoot.path}/trigger-tampered-authority.sqlite',
      );
      File(
        publicResult.authorityDatabasePath,
      ).copySync(triggerTamperedAuthority.path);
      final triggerTamperedDb = sqlite3.open(triggerTamperedAuthority.path);
      triggerTamperedDb.execute(
        'DROP TRIGGER prevent_generation_bundle_releases_update',
      );
      triggerTamperedDb.dispose();
      await expectLater(
        () async => verifyAgentEvaluationFinalReportSeal(
          reportPath: result.reportPath,
          expectedReportHash: result.reportHash,
          authorityDatabasePath: triggerTamperedAuthority.path,
        ),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );

      final membershipTamperedAuthority = File(
        '${runRoot.path}/membership-tampered-authority.sqlite',
      );
      File(
        publicResult.authorityDatabasePath,
      ).copySync(membershipTamperedAuthority.path);
      final membershipTamperedDb = sqlite3.open(
        membershipTamperedAuthority.path,
      );
      membershipTamperedDb.execute(
        'DROP TRIGGER prevent_generation_bundle_releases_delete',
      );
      membershipTamperedDb.execute(
        'DELETE FROM generation_bundle_releases WHERE rowid = '
        '(SELECT rowid FROM generation_bundle_releases LIMIT 1)',
      );
      membershipTamperedDb.dispose();
      await expectLater(
        () async => verifyAgentEvaluationFinalReportSeal(
          reportPath: result.reportPath,
          expectedReportHash: result.reportHash,
          authorityDatabasePath: membershipTamperedAuthority.path,
        ),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );

      final db = sqlite3.open(publicResult.authorityDatabasePath);
      addTearDown(db.dispose);
      expect(
        db.select('SELECT * FROM eval_production_holdout_claims'),
        hasLength(1),
      );
      final decisions = db.select(
        'SELECT action FROM prompt_release_decisions ORDER BY from_epoch',
      );
      expect(
        decisions.map((row) => row['action']),
        orderedEquals(<String>['promote', 'rollback']),
      );
      final head = db.select(
        'SELECT bundle_hash, epoch FROM prompt_channel_heads '
        'WHERE channel = ?',
        <Object?>['purpose-release'],
      ).single;
      expect(head['epoch'], 2);
      expect(
        head['bundle_hash'],
        db
            .select(
              'SELECT champion_bundle_hash FROM eval_release_gate_verdicts',
            )
            .single['champion_bundle_hash'],
      );

      final claimRow = db
          .select('SELECT * FROM eval_production_holdout_claims')
          .single;
      final projection = AgentEvaluationHoldoutReuseAuthority.read(
        db: db,
        claimHash: claimRow['claim_hash'] as String,
      );
      expect(projection.accessCount, 1);
      expect(projection.claimCount, 1);
      expect(projection.authorizationCount, 1);
      expect(projection.legacyConfirmationCount, 0);
      expect(
        AgentEvaluationHashes.canonicalJson(
          finalReport['holdoutReuseAuthority'],
        ),
        AgentEvaluationHashes.canonicalJson(projection.toReportMap()),
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
      final familyRow = db
          .select('SELECT * FROM eval_experiment_families')
          .single;
      final regressionRow = db
          .select(
            'SELECT * FROM eval_release_gate_verdicts '
            "WHERE verdict_kind = 'regression'",
          )
          .single;
      expect(
        () => holdout.issueToken(
          tokenId: 'second-statistical-token',
          familyId: familyRow['family_id'] as String,
          challengerBundleHash:
              regressionRow['challenger_bundle_hash'] as String,
          regressionVerdictHash: regressionRow['verdict_hash'] as String,
          alphaCostMicros:
              AgentEvaluationReleaseCoordinatorPolicy.alphaCostMicros,
          issuedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
        throwsA(isA<AgentEvaluationHoldoutConflict>()),
      );
      expect(
        () => holdout.beginProductionHoldoutAccess(
          accessId: 'second-statistical-access',
          tokenId: claimRow['token_id'] as String,
          challengerBundleHash:
              regressionRow['challenger_bundle_hash'] as String,
        ),
        throwsA(isA<AgentEvaluationHoldoutConflict>()),
      );

      final releaseStore = AgentEvaluationReleaseStore(
        db: db,
        trustedHoldoutVerifier: verifier,
      );
      await expectLater(
        releaseStore.promoteVerified(
          decisionId: 'second-claim-reuse-decision',
          channel: 'purpose-release',
          expectedBundleHash: regressionRow['champion_bundle_hash'] as String,
          expectedEpoch: 2,
          challengerBundleHash:
              regressionRow['challenger_bundle_hash'] as String,
          experimentId: regressionRow['experiment_id'] as String,
          regressionVerdictHash: regressionRow['verdict_hash'] as String,
          productionHoldoutClaimHash: claimRow['claim_hash'] as String,
          approver: 'offline-verifier',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
        throwsA(isA<AgentEvaluationPromotionConflict>()),
      );
      expect(db.select('SELECT * FROM eval_holdout_tokens'), hasLength(1));
      expect(
        db.select('SELECT * FROM eval_production_holdout_accesses'),
        hasLength(1),
      );
      expect(
        db.select('SELECT * FROM eval_production_holdout_claims'),
        hasLength(1),
      );
      expect(db.select('SELECT * FROM prompt_release_decisions'), hasLength(2));
      expect(
        db.select(
          'SELECT * FROM prompt_release_decision_production_authorizations',
        ),
        hasLength(1),
      );
      final headAfterReuse = releaseStore.readChannelHead('purpose-release');
      expect(headAfterReuse.epoch, 2);
      expect(headAfterReuse.bundleHash, regressionRow['champion_bundle_hash']);
      for (final row in db.select(
        'SELECT public_result_json FROM eval_holdout_confirmations',
      )) {
        final publicResultJson = row['public_result_json'] as String;
        for (final secret in <String>[
          _privateSentinel,
          privatePlan.path,
          privateFixture.path,
          seedFile.path,
          vault.path,
          'apiKey',
          'baseUrl',
        ]) {
          expect(publicResultJson, isNot(contains(secret)));
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'malformed real subprocess response fails after one spent access',
    () async {
      final runRoot = Directory('${suiteRoot.path}/malformed')..createSync();
      _chmod(runRoot.path, '700');
      final publicResult = _copyPublicTemplate(publicTemplate, runRoot);
      final invalidTool = File(
        '${Directory.current.path}/tool/'
        'agent_evaluation_release_coordinator_invalid_child.dart',
      );
      final coordinator = AgentEvaluationReleaseCoordinator.purposeBuilt(
        coordinatorRunId: 'purpose-coordinator-malformed',
        publicResult: publicResult,
        privateCommitment: commitment(
          File('${runRoot.path}/private-vault.sqlite'),
        ),
        privateRunnerCommand: AgentEvaluationPrivateRunnerCommand(
          executablePath: _dartExecutable(),
          entrypointPath: invalidTool.path,
          fixedArguments: const <String>['run'],
        ),
        workDirectory: Directory('${runRoot.path}/work'),
        reportDirectory: Directory('${runRoot.path}/reports'),
        channel: 'purpose-malformed',
        approver: 'offline-verifier',
        processTimeout: const Duration(minutes: 1),
        requiredModelRouteHashes: releaseConfiguration.sutRoutes.map(
          (route) => route.modelRouteHash,
        ),
      );

      await expectLater(
        coordinator.run(),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );

      expect(
        Directory('${runRoot.path}/work/private-child').existsSync(),
        isFalse,
      );
      final db = sqlite3.open(publicResult.authorityDatabasePath);
      addTearDown(db.dispose);
      expect(
        db.select('SELECT state FROM eval_holdout_tokens').single['state'],
        'consumed',
      );
      expect(db.select('SELECT * FROM eval_experiment_families'), hasLength(1));
      expect(db.select('SELECT * FROM eval_holdout_tokens'), hasLength(1));
      expect(
        db.select('SELECT * FROM eval_production_holdout_accesses'),
        hasLength(1),
      );
      expect(db.select('SELECT * FROM prompt_release_decisions'), isEmpty);
      final reports = Directory(
        '${runRoot.path}/reports',
      ).listSync().whereType<File>().toList(growable: false);
      expect(reports, hasLength(1));
      final report = reports.single.readAsStringSync();
      expect(report, contains('"releaseEligible": false'));
      expect(report, isNot(contains(_privateSentinel)));
      expect(report, isNot(contains(seedFile.path)));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'two frozen SUT routes complete one aggregate matrix without local release authority',
    () async {
      final root = Directory('${suiteRoot.path}/two-sut-routes')..createSync();
      _chmod(root.path, '700');
      final configuration = _configuration(
        sutRouteCount: 2,
        executionId: 'purpose-coordinator-two-sut-execution',
      );
      final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
        configuration: configuration,
        sutClient: _PromotableChallengerClient(),
        judgeClient: _PromotableMarkerJudgeClient(),
        outputDirectory: Directory('${root.path}/public-reports'),
        workDirectory: Directory('${root.path}/public-work'),
      );
      late final AgentEvaluationRealReleaseResult aggregateTemplate;
      try {
        aggregateTemplate = await harness.run();
      } finally {
        harness.dispose();
      }
      expect(aggregateTemplate.partitions, hasLength(1));
      expect(aggregateTemplate.partitions.single.cellCount, 40);
      expect(aggregateTemplate.partitions.single.slotCount, 120);
      expect(aggregateTemplate.partitions.single.productionReceiptCount, 120);
      final publicReport =
          jsonDecode(File(aggregateTemplate.reportPath).readAsStringSync())
              as Map<String, Object?>;
      expect(publicReport['matrix'], containsPair('modelPartitionCount', 1));
      expect(publicReport['matrix'], containsPair('cellCount', 40));
      expect(publicReport['matrix'], containsPair('slotCount', 120));

      final twoRoutePlanPayload = <String, Object?>{
        'schemaVersion': AgentEvaluationPrivateProductionPlan.schemaVersion,
        'opaqueHoldoutScenarioSetHash': opaqueScenarioSetHash,
        'scenarioSet': _scenarioSet(),
        'fixture': <String, Object?>{
          'databasePath': privateFixture.path,
          'databaseAuditRootHash': agentEvaluationCanonicalSqliteAuditRoot(
            privateFixture.path,
          ),
        },
        'releaseConfiguration':
            AgentEvaluationRealHarnessPrivateProductionExecution.canonicalReleaseConfiguration(
              configuration,
            ),
      };
      final twoRoutePlan = File('${suiteRoot.path}/two-route-private-plan.json')
        ..writeAsStringSync(
          AgentEvaluationHashes.canonicalJson(twoRoutePlanPayload),
          flush: true,
        );
      _chmod(twoRoutePlan.path, '600');
      final twoRoutePlanHash = AgentEvaluationHashes.domainHash(
        'eval-production-holdout-private-plan-v1',
        twoRoutePlanPayload,
      );
      AgentEvaluationPrivateReleaseCommitment twoRouteCommitment(File vault) =>
          AgentEvaluationPrivateReleaseCommitment(
            privatePlanHash: twoRoutePlanHash,
            opaqueScenarioSetHash: opaqueScenarioSetHash,
            keyId: signer.keyId,
            publicKey: signer.publicKey,
            privatePlanPath: twoRoutePlan.path,
            vaultPath: vault.path,
            seedFilePath: seedFile.path,
          );

      final negativeRoot = Directory('${root.path}/missing-route')
        ..createSync();
      _chmod(negativeRoot.path, '700');
      final missingRoutePublic = _copyPublicTemplate(
        aggregateTemplate,
        negativeRoot,
      );
      final missingRouteCoordinator =
          AgentEvaluationReleaseCoordinator.purposeBuilt(
            coordinatorRunId: 'purpose-coordinator-missing-sut-route',
            publicResult: missingRoutePublic,
            privateCommitment: twoRouteCommitment(
              File('${negativeRoot.path}/private-vault.sqlite'),
            ),
            privateRunnerCommand: _purposeCommand(),
            workDirectory: Directory('${negativeRoot.path}/work'),
            reportDirectory: Directory('${negativeRoot.path}/reports'),
            channel: 'purpose-two-route-negative',
            approver: 'offline-verifier',
            processTimeout: const Duration(minutes: 3),
            requiredModelRouteHashes: <String>{
              configuration.sutRoutes.first.modelRouteHash,
            },
          );
      await expectLater(
        missingRouteCoordinator.run(),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );

      final successRoot = Directory('${root.path}/success')..createSync();
      _chmod(successRoot.path, '700');
      final aggregatePublic = _copyPublicTemplate(
        aggregateTemplate,
        successRoot,
      );
      final coordinator = AgentEvaluationReleaseCoordinator.purposeBuilt(
        coordinatorRunId: 'purpose-coordinator-two-sut-routes',
        publicResult: aggregatePublic,
        privateCommitment: twoRouteCommitment(
          File('${successRoot.path}/private-vault.sqlite'),
        ),
        privateRunnerCommand: _purposeCommand(),
        workDirectory: Directory('${successRoot.path}/work'),
        reportDirectory: Directory('${successRoot.path}/reports'),
        channel: 'purpose-two-route-release',
        approver: 'offline-verifier',
        processTimeout: const Duration(minutes: 5),
        requiredModelRouteHashes: configuration.sutRoutes.map(
          (route) => route.modelRouteHash,
        ),
      );
      final result = await coordinator.run();
      expect(result.releaseEligible, isFalse);
      expect(result.realProviderEvidence, isFalse);
      expect(result.finalChannelEpoch, 2);
      final report =
          jsonDecode(File(result.reportPath).readAsStringSync())
              as Map<String, Object?>;
      final authority = report['authority']! as Map<String, Object?>;
      final partitions = authority['publicPartitions']! as List<Object?>;
      expect(partitions, hasLength(1));
      expect(
        partitions.single,
        containsPair('cellCount', configuration.expectedCells),
      );
      expect(
        partitions.single,
        containsPair('slotCount', configuration.expectedSlots),
      );
      await verifyAgentEvaluationFinalReportSeal(
        reportPath: result.reportPath,
        expectedReportHash: result.reportHash,
        authorityDatabasePath: aggregatePublic.authorityDatabasePath,
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  test(
    'directory vault is rejected by the real child process',
    () async {
      final runRoot = Directory('${suiteRoot.path}/directory-vault')
        ..createSync();
      _chmod(runRoot.path, '700');
      final publicResult = _copyPublicTemplate(publicTemplate, runRoot);
      final vaultDirectory = Directory('${runRoot.path}/private-vault')
        ..createSync();
      _chmod(vaultDirectory.path, '700');
      final coordinator = AgentEvaluationReleaseCoordinator.purposeBuilt(
        coordinatorRunId: 'purpose-coordinator-directory-vault',
        publicResult: publicResult,
        privateCommitment: commitment(File(vaultDirectory.path)),
        privateRunnerCommand: _purposeCommand(),
        workDirectory: Directory('${runRoot.path}/work'),
        reportDirectory: Directory('${runRoot.path}/reports'),
        channel: 'purpose-directory-vault',
        approver: 'offline-verifier',
        processTimeout: const Duration(minutes: 2),
        requiredModelRouteHashes: releaseConfiguration.sutRoutes.map(
          (route) => route.modelRouteHash,
        ),
      );

      await expectLater(
        coordinator.run(),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );

      final db = sqlite3.open(publicResult.authorityDatabasePath);
      addTearDown(db.dispose);
      expect(
        db.select('SELECT state FROM eval_holdout_tokens').single['state'],
        'consumed',
      );
      expect(db.select('SELECT * FROM prompt_release_decisions'), isEmpty);
      expect(
        Directory('${runRoot.path}/work/private-child').existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'world-readable private plan is rejected by the real child process',
    () async {
      final runRoot = Directory('${suiteRoot.path}/broad-plan-acl')
        ..createSync();
      _chmod(runRoot.path, '700');
      final publicResult = _copyPublicTemplate(publicTemplate, runRoot);
      final broadPlan = File('${runRoot.path}/private-plan.json');
      privatePlan.copySync(broadPlan.path);
      _chmod(broadPlan.path, '644');
      final coordinator = AgentEvaluationReleaseCoordinator.purposeBuilt(
        coordinatorRunId: 'purpose-coordinator-broad-plan-acl',
        publicResult: publicResult,
        privateCommitment: commitment(
          File('${runRoot.path}/private-vault.sqlite'),
          planPath: broadPlan.path,
        ),
        privateRunnerCommand: _purposeCommand(),
        workDirectory: Directory('${runRoot.path}/work'),
        reportDirectory: Directory('${runRoot.path}/reports'),
        channel: 'purpose-broad-plan-acl',
        approver: 'offline-verifier',
        processTimeout: const Duration(minutes: 2),
        requiredModelRouteHashes: releaseConfiguration.sutRoutes.map(
          (route) => route.modelRouteHash,
        ),
      );

      await expectLater(
        coordinator.run(),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );

      final db = sqlite3.open(publicResult.authorityDatabasePath);
      addTearDown(db.dispose);
      expect(
        db.select('SELECT state FROM eval_holdout_tokens').single['state'],
        'consumed',
      );
      expect(
        db.select('SELECT * FROM eval_production_holdout_claims'),
        isEmpty,
      );
      expect(db.select('SELECT * FROM prompt_release_decisions'), isEmpty);
      expect(
        Directory('${runRoot.path}/work/private-child').existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'independent processes apply one promotion and one rollback CAS',
    () async {
      final runRoot = Directory('${suiteRoot.path}/release-cas')..createSync();
      _chmod(runRoot.path, '700');
      final publicResult = _copyPublicTemplate(publicTemplate, runRoot);
      final vault = File('${runRoot.path}/private-vault.sqlite');
      final coordinator = AgentEvaluationReleaseCoordinator.purposeBuilt(
        coordinatorRunId: 'purpose-coordinator-release-cas',
        publicResult: publicResult,
        privateCommitment: commitment(vault),
        privateRunnerCommand: _purposeCommand(),
        workDirectory: Directory('${runRoot.path}/work'),
        reportDirectory: Directory('${runRoot.path}/reports'),
        channel: 'purpose-release-cas',
        approver: 'offline-verifier',
        processTimeout: const Duration(minutes: 3),
        requiredModelRouteHashes: releaseConfiguration.sutRoutes.map(
          (route) => route.modelRouteHash,
        ),
        injectedFault: AgentEvaluationCoordinatorPurposeFault.afterImport,
      );
      await expectLater(
        coordinator.run(),
        throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
      );

      final verifier = AgentEvaluationTrustedHoldoutVerifier(
        keyId: signer.keyId,
        publicKey: signer.publicKey,
        runnerReleaseHash:
            agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
      );
      final authority = sqlite3.open(publicResult.authorityDatabasePath);
      authority.execute('PRAGMA foreign_keys = ON');
      final store = AgentEvaluationReleaseStore(
        db: authority,
        trustedHoldoutVerifier: verifier,
      );
      final claim = authority
          .select('SELECT * FROM eval_production_holdout_claims')
          .single;
      final regression = authority
          .select(
            'SELECT * FROM eval_release_gate_verdicts '
            "WHERE verdict_kind = 'regression'",
          )
          .single;
      const channel = 'purpose-release-cas';
      store.initializeChannelHead(
        channel: channel,
        bundleHash: regression['champion_bundle_hash'] as String,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      authority.dispose();

      AgentEvaluationReleaseCasWorkerRequest request({
        required String action,
        required String decisionId,
        required String expectedBundleHash,
        required int expectedEpoch,
        required String targetBundleHash,
        String promotionDecisionId = '',
      }) => AgentEvaluationReleaseCasWorkerRequest(
        action: action,
        authorityDatabasePath: publicResult.authorityDatabasePath,
        decisionId: decisionId,
        channel: channel,
        expectedBundleHash: expectedBundleHash,
        expectedEpoch: expectedEpoch,
        challengerBundleHash: targetBundleHash,
        experimentId: regression['experiment_id'] as String,
        regressionVerdictHash: regression['verdict_hash'] as String,
        productionHoldoutClaimHash: claim['claim_hash'] as String,
        promotionDecisionId: promotionDecisionId,
        approver: 'offline-verifier',
        keyId: signer.keyId,
        publicKeyBase64: base64Encode(signer.publicKey.bytes),
        runnerReleaseHash:
            agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
      );

      final promotionRequests = <AgentEvaluationReleaseCasWorkerRequest>[
        request(
          action: 'promote',
          decisionId: 'cas-promote-a',
          expectedBundleHash: regression['champion_bundle_hash'] as String,
          expectedEpoch: 0,
          targetBundleHash: regression['challenger_bundle_hash'] as String,
        ),
        request(
          action: 'promote',
          decisionId: 'cas-promote-b',
          expectedBundleHash: regression['champion_bundle_hash'] as String,
          expectedEpoch: 0,
          targetBundleHash: regression['challenger_bundle_hash'] as String,
        ),
      ];
      final promotionReceipts = await _runReleaseCasRace(
        root: Directory('${runRoot.path}/promotion-race'),
        requests: promotionRequests,
      );
      expect(
        promotionReceipts.map((receipt) => receipt.status).toSet(),
        <String>{'applied', 'casConflict'},
      );
      final promotionWinnerHash = promotionReceipts
          .singleWhere((receipt) => receipt.status == 'applied')
          .decisionIdHash;
      final promotionWinnerId = <String>['cas-promote-a', 'cas-promote-b']
          .singleWhere(
            (decisionId) =>
                AgentEvaluationReleaseCasAuthority.decisionIdHash(decisionId) ==
                promotionWinnerHash,
          );

      final rollbackRequests = <AgentEvaluationReleaseCasWorkerRequest>[
        request(
          action: 'rollback',
          decisionId: 'cas-rollback-a',
          expectedBundleHash: regression['challenger_bundle_hash'] as String,
          expectedEpoch: 1,
          targetBundleHash: regression['champion_bundle_hash'] as String,
          promotionDecisionId: promotionWinnerId,
        ),
        request(
          action: 'rollback',
          decisionId: 'cas-rollback-b',
          expectedBundleHash: regression['challenger_bundle_hash'] as String,
          expectedEpoch: 1,
          targetBundleHash: regression['champion_bundle_hash'] as String,
          promotionDecisionId: promotionWinnerId,
        ),
      ];
      final rollbackReceipts = await _runReleaseCasRace(
        root: Directory('${runRoot.path}/rollback-race'),
        requests: rollbackRequests,
      );
      expect(
        rollbackReceipts.map((receipt) => receipt.status).toSet(),
        <String>{'applied', 'casConflict'},
      );

      final readback = sqlite3.open(
        publicResult.authorityDatabasePath,
        mode: OpenMode.readOnly,
      );
      final projection = AgentEvaluationReleaseCasAuthority.verify(
        db: readback,
        claimHash: claim['claim_hash'] as String,
        promotionRequests: promotionRequests,
        promotionReceipts: promotionReceipts,
        rollbackRequests: rollbackRequests,
        rollbackReceipts: rollbackReceipts,
      );
      expect(projection.decisionCount, 2);
      expect(projection.authorizationCount, 1);
      expect(projection.processIdentityHashes, hasLength(4));
      expect(projection.processReceiptHashes, hasLength(4));
      expect(projection.projectionHash, hasLength(64));
      readback.dispose();

      final recoveryReceipt = (await _runReleaseCasRace(
        root: Directory('${runRoot.path}/rollback-recovery'),
        requests: <AgentEvaluationReleaseCasWorkerRequest>[
          request(
            action: 'rollback',
            decisionId: 'cas-rollback-recovery',
            expectedBundleHash: regression['challenger_bundle_hash'] as String,
            expectedEpoch: 1,
            targetBundleHash: regression['champion_bundle_hash'] as String,
            promotionDecisionId: promotionWinnerId,
          ),
        ],
      )).single;
      expect(recoveryReceipt.status, 'casConflict');
      expect(recoveryReceipt.exitCode, 21);
      final recoveryDb = sqlite3.open(
        publicResult.authorityDatabasePath,
        mode: OpenMode.readOnly,
      );
      expect(
        recoveryDb.select('SELECT * FROM prompt_release_decisions'),
        hasLength(2),
      );
      expect(
        recoveryDb.select(
          'SELECT * FROM prompt_release_decision_production_authorizations',
        ),
        hasLength(1),
      );
      expect(
        recoveryDb.select(
          'SELECT epoch FROM prompt_channel_heads WHERE channel = ?',
          <Object?>[channel],
        ).single['epoch'],
        2,
      );
      recoveryDb.dispose();
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'same frozen run resumes every crash boundary without a second probe',
    () async {
      for (final fault in AgentEvaluationCoordinatorPurposeFault.values) {
        final suffix = fault.name;
        final runRoot = Directory('${suiteRoot.path}/resume-$suffix')
          ..createSync();
        _chmod(runRoot.path, '700');
        final publicResult = _copyPublicTemplate(publicTemplate, runRoot);
        final vault = File('${runRoot.path}/private-vault.sqlite');
        AgentEvaluationReleaseCoordinator coordinator({
          AgentEvaluationCoordinatorPurposeFault? injectedFault,
        }) => AgentEvaluationReleaseCoordinator.purposeBuilt(
          coordinatorRunId: 'purpose-coordinator-resume-$suffix',
          publicResult: publicResult,
          privateCommitment: commitment(vault),
          privateRunnerCommand: _purposeCommand(),
          workDirectory: Directory('${runRoot.path}/work'),
          reportDirectory: Directory('${runRoot.path}/reports'),
          channel: 'purpose-resume-$suffix',
          approver: 'offline-verifier',
          processTimeout: const Duration(minutes: 3),
          requiredModelRouteHashes: releaseConfiguration.sutRoutes.map(
            (route) => route.modelRouteHash,
          ),
          injectedFault: injectedFault,
        );

        await expectLater(
          coordinator(injectedFault: fault).run(),
          throwsA(isA<AgentEvaluationReleaseCoordinatorException>()),
        );
        final result = await coordinator().run();

        expect(result.finalChannelEpoch, 2);
        final vaultDb = sqlite3.open(vault.path, mode: OpenMode.readOnly);
        expect(
          vaultDb.select('SELECT * FROM production_holdout_runs'),
          hasLength(1),
        );
        vaultDb.dispose();
        final authority = sqlite3.open(publicResult.authorityDatabasePath);
        expect(
          authority.select('SELECT * FROM eval_experiment_families'),
          hasLength(1),
        );
        expect(
          authority.select('SELECT * FROM eval_production_holdout_accesses'),
          hasLength(1),
        );
        expect(
          authority.select('SELECT * FROM eval_production_holdout_claims'),
          hasLength(1),
        );
        expect(
          authority.select('SELECT * FROM prompt_release_decisions'),
          hasLength(2),
        );
        expect(
          authority.select('SELECT * FROM eval_final_release_report_seals'),
          hasLength(1),
        );
        final resumedClaimHash =
            authority
                    .select(
                      'SELECT claim_hash FROM eval_production_holdout_claims',
                    )
                    .single['claim_hash']
                as String;
        final resumedProjection = AgentEvaluationHoldoutReuseAuthority.read(
          db: authority,
          claimHash: resumedClaimHash,
        );
        expect(resumedProjection.accessCount, 1);
        expect(resumedProjection.claimCount, 1);
        expect(resumedProjection.authorizationCount, 1);
        final resumedReport =
            jsonDecode(File(result.reportPath).readAsStringSync())
                as Map<String, Object?>;
        expect(
          AgentEvaluationHashes.canonicalJson(
            resumedReport['holdoutReuseAuthority'],
          ),
          AgentEvaluationHashes.canonicalJson(resumedProjection.toReportMap()),
        );
        authority.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<List<AgentEvaluationReleaseCasProcessReceipt>> _runReleaseCasRace({
  required Directory root,
  required List<AgentEvaluationReleaseCasWorkerRequest> requests,
}) async {
  if (requests.isEmpty) throw ArgumentError('release CAS race is empty');
  root.createSync(recursive: true);
  _chmod(root.path, '700');
  final barrier = File('${root.path}/start.barrier');
  final processes =
      <
        ({
          Process process,
          Future<int> exitCode,
          Future<String> stdout,
          Future<String> stderr,
        })
      >[];
  final readyFiles = <File>[];
  var earlyExitIndex = -1;
  var earlyExitCode = -1;
  for (var index = 0; index < requests.length; index += 1) {
    final requestFile = File('${root.path}/request-$index.json')
      ..writeAsStringSync(requests[index].canonicalJson, flush: true);
    _chmod(requestFile.path, '600');
    final readyFile = File('${root.path}/ready-$index');
    readyFiles.add(readyFile);
    final process = await Process.start(_releaseCasDartExecutable(), <String>[
      '${Directory.current.path}/tool/agent_evaluation_release_cas_worker.dart',
      requestFile.path,
      readyFile.path,
      barrier.path,
    ], workingDirectory: Directory.current.path);
    final stdoutFuture = utf8.decoder.bind(process.stdout).join();
    final stderrFuture = utf8.decoder.bind(process.stderr).join();
    final exitFuture = process.exitCode;
    final processIndex = index;
    exitFuture.then((code) {
      if (!readyFile.existsSync() && earlyExitIndex < 0) {
        earlyExitIndex = processIndex;
        earlyExitCode = code;
      }
    });
    processes.add((
      process: process,
      exitCode: exitFuture,
      stdout: stdoutFuture,
      stderr: stderrFuture,
    ));
  }
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (readyFiles.any((file) => !file.existsSync())) {
    if (earlyExitIndex >= 0) {
      final failed = processes[earlyExitIndex];
      throw StateError(
        'release CAS worker $earlyExitIndex exited before barrier with '
        '$earlyExitCode; stdout=${await failed.stdout}; '
        'stderr=${await failed.stderr}',
      );
    }
    if (DateTime.now().isAfter(deadline)) {
      for (final run in processes) {
        run.process.kill(ProcessSignal.sigkill);
      }
      throw StateError('release CAS workers did not reach the barrier');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  barrier.createSync(exclusive: true);
  return Future.wait(<Future<AgentEvaluationReleaseCasProcessReceipt>>[
    for (final run in processes)
      () async {
        final exitCode = await run.exitCode.timeout(
          const Duration(seconds: 30),
        );
        final stdoutText = await run.stdout;
        final stderrText = await run.stderr;
        if (!const <int>{0, 21}.contains(exitCode) || stderrText.isNotEmpty) {
          throw StateError(
            'release CAS worker failed with $exitCode: $stderrText',
          );
        }
        final receipt =
            AgentEvaluationReleaseCasProcessReceipt.fromCanonicalJson(
              stdoutText,
            );
        if (receipt.exitCode != exitCode) {
          throw StateError('release CAS process exit contradicts its receipt');
        }
        return receipt;
      }(),
  ]);
}

String _releaseCasDartExecutable() {
  var directory = File(Platform.resolvedExecutable).absolute.parent;
  while (directory.parent.path != directory.path) {
    final candidate = File('${directory.path}/bin/cache/dart-sdk/bin/dart');
    if (candidate.existsSync()) return candidate.path;
    directory = directory.parent;
  }
  throw StateError('clean Flutter Dart executable was not found');
}

Map<String, Object?> _publicCommitmentsForTest(
  AgentEvaluationRealReleaseResult result,
  AgentEvaluationRealReleaseConfiguration configuration,
) {
  final partition = result.partitions.single;
  final db = sqlite3.open(
    result.authorityDatabasePath,
    mode: OpenMode.readOnly,
  );
  try {
    final verdict = db
        .select(
          '''SELECT v.champion_bundle_hash, v.challenger_bundle_hash,
           v.verdict_hash, e.scenario_set_release_hash
         FROM eval_release_gate_verdicts v
         JOIN eval_executions x ON x.execution_id = v.execution_id
         JOIN eval_experiments e ON e.experiment_id = x.experiment_id
         WHERE v.execution_id = ? AND v.verdict_kind = 'regression' ''',
          <Object?>[partition.executionId],
        )
        .single;
    final report =
        jsonDecode(File(result.reportPath).readAsStringSync())
            as Map<String, Object?>;
    return <String, Object?>{
      'schemaVersion': 'agent-evaluation-public-release-commitments-v1',
      'executionId': configuration.executionId,
      'authorityDatabasePath': File(result.authorityDatabasePath).absolute.path,
      'publicReportPath': File(result.reportPath).absolute.path,
      'publicReportHash': report['reportHash'],
      'releaseConfiguration': configuration.toCanonicalReleaseConfiguration(),
      'releaseConfigurationHash': result.releaseConfigurationHash,
      'buildArtifactHash': configuration.buildArtifactHash,
      'championBundleHash': verdict['champion_bundle_hash'],
      'challengerBundleHash': verdict['challenger_bundle_hash'],
      'regressionVerdictHash': verdict['verdict_hash'],
      'regressionScenarioSetHash': verdict['scenario_set_release_hash'],
    };
  } finally {
    db.dispose();
  }
}

AgentEvaluationPrivateRunnerCommand _purposeCommand() =>
    AgentEvaluationPrivateRunnerCommand(
      executablePath: _dartExecutable(),
      entrypointPath:
          '${Directory.current.path}/tool/'
          'agent_evaluation_purpose_built_private_holdout_runner.dart',
      fixedArguments: const <String>['run'],
    );

String _dartExecutable() {
  final config = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  final decoded = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  final packages = decoded['packages']! as List<Object?>;
  final flutter = packages.whereType<Map<String, Object?>>().singleWhere(
    (item) => item['name'] == 'flutter',
  );
  final flutterPackage = Directory.fromUri(
    config.uri.resolve(flutter['rootUri']! as String),
  );
  return '${flutterPackage.parent.parent.path}/bin/cache/dart-sdk/bin/dart';
}

AgentEvaluationRealReleaseResult _copyPublicTemplate(
  AgentEvaluationRealReleaseResult template,
  Directory runRoot,
) {
  final authority = File('${runRoot.path}/authority.sqlite');
  File(template.authorityDatabasePath).copySync(authority.path);
  final report = File('${runRoot.path}/public-report.json');
  File(template.reportPath).copySync(report.path);
  return AgentEvaluationRealReleaseResult(
    claimScope: template.claimScope,
    releaseEligible: template.releaseEligible,
    realProviderEvidence: template.realProviderEvidence,
    trustedHoldoutConfirmed: template.trustedHoldoutConfirmed,
    partitions: template.partitions,
    reportPath: report.path,
    authorityDatabasePath: authority.path,
    releaseConfigurationHash: template.releaseConfigurationHash,
  );
}

AgentEvaluationRealReleaseConfiguration _configuration({
  int sutRouteCount = 1,
  String executionId = 'purpose-coordinator-public-execution',
}) {
  final sutRoutes = <AgentEvaluationProductionRouteRelease>[
    for (var index = 1; index <= sutRouteCount; index += 1)
      AgentEvaluationProductionRouteRelease(
        model: index == 1
            ? 'glm-purpose-coordinator-sut'
            : 'glm-purpose-coordinator-sut-$index',
        provider: AppLlmProvider.zhipu,
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        apiKey: index == 1 ? 'sut-test-secret' : 'sut-test-secret-$index',
        timeout: const AppLlmTimeoutConfig.uniform(30000),
        providerApiRevision: 'purpose-built-api-v1',
        sdkAdapterReleaseHash: _digest('1'),
      ),
  ];
  final judgeRoute = AgentEvaluationProductionRouteRelease(
    model: 'glm-purpose-coordinator-judge',
    provider: AppLlmProvider.zhipu,
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    apiKey: 'judge-test-secret',
    timeout: const AppLlmTimeoutConfig.uniform(30000),
    providerApiRevision: 'purpose-built-api-v1',
    sdkAdapterReleaseHash: _digest('1'),
  );
  return AgentEvaluationRealReleaseConfiguration(
    executionId: executionId,
    sutRoutes: sutRoutes,
    judgeRoute: judgeRoute,
    decoding: AgentEvaluationProductionDecodingRelease.standard(),
    maxAttemptsPerTrial: 1,
    maxCallsPerTrial: 64,
    maxTokensPerTrial: 10000000,
    maxPromptTokensPerCall: 100000,
    maxCompletionTokensPerCall: 4096,
    maxProviderCalls: 100000,
    maxTotalTokens: 1000000000,
    maxTotalCostMicrousd: 100000000,
    evaluatorMaxCalls: 120,
    evaluatorMaxTokens: 20000000,
    evaluatorMaxCostMicrousd: 1000000,
    evaluatorTokensPerCall: 4096,
    evaluatorCostMicrousdPerCall: 1000,
    promptMicrousdPerMillionTokens: 1,
    completionMicrousdPerMillionTokens: 1,
    judgePromptMicrousdPerMillionTokens: 1,
    judgeCompletionMicrousdPerMillionTokens: 1,
    deadline: const Duration(minutes: 5),
    holdoutAccessBudget: 1,
    codeCommit: 'purpose-built-test-commit',
    sourceTreeHash: _digest('2'),
    buildArtifactHash: _digest('3'),
    runtimeReleaseHash: _digest('4'),
    tokenizerReleaseHash: _digest('5'),
  );
}

final class _PromotableChallengerClient implements AppLlmClient {
  final _inner = PurposeBuiltProductionProtocolClient();

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final result = await _inner.chat(request);
    final challengerBundleHash =
        StoryPromptRegistry.causalityChallenger().generationBundle.bundleHash;
    final challenger =
        request.formalCacheIdentity?.generationBundleHash ==
            challengerBundleHash ||
        AgentEvaluationTraceContext.current?.generationBundleHash ==
            challengerBundleHash;
    final prose =
        request.messages.first.content.contains('scene editor') ||
        request.messages.last.content.contains('任务：language_polish');
    if (!result.succeeded || !challenger || !prose) return result;
    final source = result.text!;
    final marked = source.contains(_challengerReplacement)
        ? source
        : source.contains(_challengerSource)
        ? source.replaceAll(_challengerSource, _challengerReplacement)
        : '$source\n$_challengerReplacement';
    return AppLlmChatResult.success(
      text: marked,
      latencyMs: result.latencyMs,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
      totalTokens: result.totalTokens,
      tokenUsage: result.tokenUsage,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release evaluation disables streaming');
}

final class _PromotableMarkerJudgeClient implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final challenger = request.messages.any(
      (message) => message.content.contains(_challengerReplacement),
    );
    final score = challenger ? 100 : 1;
    return AppLlmChatResult.success(
      text:
          '{"scores":{"proseReadability":$score,"plotCausality":$score},'
          '"summary":"blind comparison"}',
      latencyMs: 3,
      promptTokens: 30,
      completionTokens: 12,
      totalTokens: 42,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release judge disables streaming');
}

Map<String, Object?> _scenarioSet() => <String, Object?>{
  'setId': 'opaque-private-coordinator-v1',
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
        'inputFixture': <String, Object?>{
          'prompt': '$_privateSentinel-${index + 1}',
        },
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
        'referenceFacts': <String, Object?>{'privateFact': _privateSentinel},
        'maxBudget': <String, Object?>{'providerCalls': 48, 'tokens': 100000},
      },
  ],
};

const _challengerSource = '真正的编号刻在仓门内侧';
const _challengerReplacement = '真正的编号刻在仓门内侧，门框上还留着一道新鲜划痕';

String _digest(String character) => List.filled(64, character).join();

void _chmod(String path, String mode) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>[mode, path]);
  if (result.exitCode != 0) throw StateError('test chmod failed');
}
