import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_holdout_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout_runner.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_material_builder.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';

const _sentinel = 'OPAQUE-PRIVATE-MATERIAL-SENTINEL';

void main() {
  late Directory temporary;
  late File authority;
  late File scenarios;
  late File configuration;
  late Map<String, Object?> configurationMap;
  late String configurationHash;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('private-material-test-');
    _chmod(temporary.path, '700');
    authority = File('${temporary.path}/authority.sqlite');
    _seedRegressionAuthority(authority);
    _chmod(authority.path, '600');
    scenarios = File('${temporary.path}/private-scenarios.json');
    scenarios.writeAsStringSync(
      AgentEvaluationHashes.canonicalJson(_scenarioSet()),
      flush: true,
    );
    _chmod(scenarios.path, '600');
    configurationMap = _releaseConfiguration();
    configurationHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-release-configuration-v1',
      configurationMap,
    );
    configuration = File('${temporary.path}/release-configuration.json');
    configuration.writeAsStringSync(
      AgentEvaluationHashes.canonicalJson(configurationMap),
      flush: true,
    );
    _chmod(configuration.path, '600');
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  test(
    'prepare creates loader-valid V26 private materials and bind receipt',
    () async {
      final root = Directory('${temporary.path}/materials');
      const builder = AgentEvaluationPrivateMaterialBuilder();
      final prepared = await builder.prepare(
        rootPath: root.path,
        authorityDatabasePath: authority.path,
        scenarioSourcePath: scenarios.path,
        releaseConfigurationPath: configuration.path,
        releaseConfigurationHash: configurationHash,
        appArtifactHash: _digest('4'),
        championBundleHash: _digest('b'),
        challengerBundleHash: _digest('c'),
        regressionVerdictHash: _digest('d'),
        keyId: 'private-material-key',
      );

      expect(root.statSync().mode & 0x3f, 0);
      for (final name in <String>[
        'fixture.sqlite',
        'private-plan.json',
        'ed25519.seed',
        'public-metadata.json',
      ]) {
        expect(File('${root.path}/$name').statSync().mode & 0x3f, 0);
      }
      final plan = AgentEvaluationPrivateProductionPlan.fromCanonicalJson(
        File('${root.path}/private-plan.json').readAsStringSync(),
      );
      expect(plan.planHash, prepared.privatePlanHash);
      expect(plan.opaqueHoldoutScenarioSetHash, prepared.opaqueScenarioSetHash);
      expect(
        agentEvaluationCanonicalSqliteAuditRoot('${root.path}/fixture.sqlite'),
        prepared.fixtureAuditRootHash,
      );
      final fixture = sqlite3.open(
        '${root.path}/fixture.sqlite',
        mode: OpenMode.readOnly,
      );
      try {
        expect(
          fixture.select('PRAGMA user_version').single.values.single,
          authoringSchemaMigrations.last.version,
        );
        expect(
          fixture.select('SELECT * FROM generation_bundles'),
          hasLength(2),
        );
        expect(
          fixture.select('SELECT * FROM generation_bundle_releases'),
          hasLength(2),
        );
        final workspaceProject = fixture.select(
          '''SELECT id, scene_id FROM workspace_projects
                 WHERE scope_key = 'workspace-default' ''',
        ).single;
        expect(workspaceProject['id'], 'private-holdout-project-v2');
        expect(workspaceProject['scene_id'], 'private-holdout-scene-v2');
        final privateManifest = fixture
            .select('SELECT * FROM private_holdout_material_manifest')
            .single;
        expect(privateManifest['scenario_set_json'], contains(_sentinel));
        expect(
          privateManifest['release_configuration_hash'],
          configurationHash,
        );
      } finally {
        fixture.dispose();
      }

      final metadata =
          jsonDecode(
                File('${root.path}/public-metadata.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      final signer = await AgentEvaluationTrustedHoldoutSigner.fromSeedFile(
        keyId: metadata['keyId']! as String,
        path: '${root.path}/ed25519.seed',
      );
      final verifier = AgentEvaluationTrustedHoldoutVerifier(
        keyId: signer.keyId,
        publicKey: signer.publicKey,
        runnerReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
      );
      expect(verifier.trustPolicyHash, metadata['trustPolicyHash']);
      final db = sqlite3.open(authority.path);
      try {
        final holdout = AgentEvaluationHoldoutStore(
          db: db,
          trustedHoldoutVerifier: verifier,
        );
        holdout.createProductionFamily(
          familyId: 'material-family',
          productionAuthorityHash: _digest('a'),
          regressionScenarioSetHash: _digest('1'),
          opaqueHoldoutScenarioSetHash:
              metadata['opaqueHoldoutScenarioSetHash']! as String,
          privatePlanHash: metadata['privatePlanHash']! as String,
          holdoutAccessPolicyHash: verifier.trustPolicyHash,
          maxAccesses: 1,
          alphaBudgetMicros: 50000,
          createdAtMs: 10,
        );
        holdout.registerChallenger(
          familyId: 'material-family',
          challengerBundleHash: _digest('c'),
          registeredAtMs: 11,
        );
        holdout.issueToken(
          tokenId: 'material-token',
          familyId: 'material-family',
          challengerBundleHash: _digest('c'),
          regressionVerdictHash: _digest('d'),
          alphaCostMicros: 50000,
          issuedAtMs: 12,
        );
        holdout.beginProductionHoldoutAccess(
          accessId: 'material-access',
          tokenId: 'material-token',
          challengerBundleHash: _digest('c'),
        );
      } finally {
        db.dispose();
      }
      final bound = await builder.bind(
        rootPath: root.path,
        authorityDatabasePath: authority.path,
        accessId: 'material-access',
      );
      expect(bound.bindingHash, hasLength(64));
      expect(
        File('${root.path}/grant-binding.json').readAsStringSync(),
        isNot(contains(_sentinel)),
      );
      final rebound = await builder.bind(
        rootPath: root.path,
        authorityDatabasePath: authority.path,
        accessId: 'material-access',
      );
      expect(rebound.bindingHash, bound.bindingHash);
      final bindingFile = File('${root.path}/grant-binding.json');
      final originalBinding = bindingFile.readAsStringSync();
      final tampered = jsonDecode(originalBinding) as Map<String, Object?>;
      tampered['bindingHash'] = _digest('f');
      bindingFile.writeAsStringSync(
        AgentEvaluationHashes.canonicalJson(tampered),
        flush: true,
      );
      _chmod(bindingFile.path, '600');
      await expectLater(
        builder.bind(
          rootPath: root.path,
          authorityDatabasePath: authority.path,
          accessId: 'material-access',
        ),
        throwsA(isA<AgentEvaluationPrivateMaterialException>()),
      );
      bindingFile.writeAsStringSync(originalBinding, flush: true);
      _chmod(bindingFile.path, '600');
      await expectLater(
        builder.bind(
          rootPath: root.path,
          authorityDatabasePath: authority.path,
          accessId: 'other-access',
        ),
        throwsA(isA<AgentEvaluationPrivateMaterialException>()),
      );
      final resumed = await builder.prepare(
        rootPath: root.path,
        authorityDatabasePath: authority.path,
        scenarioSourcePath: scenarios.path,
        releaseConfigurationPath: configuration.path,
        releaseConfigurationHash: configurationHash,
        appArtifactHash: _digest('4'),
        championBundleHash: _digest('b'),
        challengerBundleHash: _digest('c'),
        regressionVerdictHash: _digest('d'),
        keyId: 'private-material-key',
      );
      expect(resumed.metadataHash, prepared.metadataHash);
      expect(resumed.privatePlanHash, prepared.privatePlanHash);
      await expectLater(
        builder.loadPrepared(
          rootPath: root.path,
          authorityDatabasePath: authority.path,
          scenarioSourcePath: scenarios.path,
          releaseConfigurationPath: configuration.path,
          releaseConfigurationHash: configurationHash,
          appArtifactHash: _digest('5'),
          championBundleHash: _digest('b'),
          challengerBundleHash: _digest('c'),
          regressionVerdictHash: _digest('d'),
          keyId: 'private-material-key',
        ),
        throwsA(isA<AgentEvaluationPrivateMaterialException>()),
      );
    },
  );

  test('external custody preparation never creates a local seed', () async {
    final keyPair = await DartEd25519().newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 41),
    );
    final publicKey = await keyPair.extractPublicKey();
    final root = Directory('${temporary.path}/external-materials');
    const builder = AgentEvaluationPrivateMaterialBuilder();
    final prepared = await builder.prepare(
      rootPath: root.path,
      authorityDatabasePath: authority.path,
      scenarioSourcePath: scenarios.path,
      releaseConfigurationPath: configuration.path,
      releaseConfigurationHash: configurationHash,
      appArtifactHash: _digest('4'),
      championBundleHash: _digest('b'),
      challengerBundleHash: _digest('c'),
      regressionVerdictHash: _digest('d'),
      keyId: 'external-kms-key',
      externalPublicKey: publicKey,
    );

    expect(File('${root.path}/ed25519.seed').existsSync(), isFalse);
    final metadata =
        jsonDecode(File('${root.path}/public-metadata.json').readAsStringSync())
            as Map<String, Object?>;
    expect(metadata['custodyMode'], 'external-command-v1');
    expect((metadata['files']! as Map<String, Object?>)['seed'], isNull);
    final resumed = await builder.loadPrepared(
      rootPath: root.path,
      authorityDatabasePath: authority.path,
      scenarioSourcePath: scenarios.path,
      releaseConfigurationPath: configuration.path,
      releaseConfigurationHash: configurationHash,
      appArtifactHash: _digest('4'),
      championBundleHash: _digest('b'),
      challengerBundleHash: _digest('c'),
      regressionVerdictHash: _digest('d'),
      keyId: 'external-kms-key',
      externalPublicKey: publicKey,
    );
    expect(resumed.metadataHash, prepared.metadataHash);
  });

  test('process output contains commitments but no private material', () async {
    final root = '${temporary.path}/process-materials';
    final result = await Process.run(
      _projectDartExecutable(),
      <String>[
        'run',
        'tool/agent_evaluation_private_material_builder.dart',
        'prepare',
        '--root',
        root,
        '--authority-db',
        authority.path,
        '--scenario-source',
        scenarios.path,
        '--release-configuration',
        configuration.path,
        '--release-configuration-hash',
        configurationHash,
        '--app-artifact-hash',
        _digest('4'),
        '--champion-bundle-hash',
        _digest('b'),
        '--challenger-bundle-hash',
        _digest('c'),
        '--regression-verdict-hash',
        _digest('d'),
        '--key-id',
        'private-process-key',
      ],
      environment: <String, String>{
        'PATH': Platform.environment['PATH'] ?? '',
        'HOME': Platform.environment['HOME'] ?? '',
      },
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0);
    expect(result.stdout, matches(RegExp(r'^prepared=[a-f0-9]{64}\n$')));
    expect(result.stdout, isNot(contains(_sentinel)));
    expect(result.stderr, isEmpty);
  });

  test(
    'generated opaque scenarios are unique, loader-valid, and nondiagnostic',
    () async {
      const builder = AgentEvaluationPrivateMaterialBuilder();
      final firstFile = File('${temporary.path}/generated-first.json');
      final secondFile = File('${temporary.path}/generated-second.json');
      final firstHash = builder.generateScenarios(outputPath: firstFile.path);
      final secondHash = builder.generateScenarios(outputPath: secondFile.path);

      expect(firstHash, isNot(secondHash));
      expect(firstFile.statSync().mode & 0x3f, 0);
      for (final entry in <MapEntry<File, String>>[
        MapEntry<File, String>(firstFile, firstHash),
        MapEntry<File, String>(secondFile, secondHash),
      ]) {
        final source = entry.key.readAsStringSync();
        final decoded = jsonDecode(source) as Map<String, Object?>;
        final loaded = AgentEvaluationPrivateProductionPlan.parseScenarioSet(
          decoded,
        );
        expect(loaded.releaseHash, entry.value);
        expect(loaded.scenarios, hasLength(10));
        expect(
          loaded.scenarios.map((scenario) => scenario.scenarioId).toSet(),
          hasLength(10),
        );
        expect(
          loaded.scenarios.every(
            (scenario) =>
                scenario.requiredCapabilities.contains('story-generation') &&
                scenario.inputFixture['projectId'] ==
                    'private-holdout-project-v2' &&
                scenario.inputFixture['sceneId'] ==
                    'private-holdout-scene-v2' &&
                scenario.inputFixture['sceneScopeId'] ==
                    'private-holdout-project-v2::private-holdout-scene-v2' &&
                scenario.referenceFacts['requiredLiterals'] is List<Object?> &&
                scenario.maxBudget['calls'] == 48,
          ),
          isTrue,
        );
      }
      expect(
        () => builder.generateScenarios(outputPath: firstFile.path),
        throwsA(isA<AgentEvaluationPrivateMaterialException>()),
      );

      final processFile = File('${temporary.path}/generated-process.json');
      final process = await Process.run(
        _projectDartExecutable(),
        <String>[
          'run',
          'tool/agent_evaluation_private_material_builder.dart',
          'generate-scenarios',
          '--output',
          processFile.path,
        ],
        environment: <String, String>{
          'PATH': Platform.environment['PATH'] ?? '',
          'HOME': Platform.environment['HOME'] ?? '',
        },
        includeParentEnvironment: false,
      );
      expect(process.exitCode, 0);
      expect(
        process.stdout,
        matches(RegExp(r'^opaqueScenarioSetHash=[a-f0-9]{64}\n$')),
      );
      expect(process.stdout, isNot(contains('生成一段')));
      expect(process.stdout, isNot(contains('证物-')));
      expect(process.stderr, isEmpty);
    },
  );
}

Map<String, Object?> _scenarioSet() => <String, Object?>{
  'setId': 'opaque-material-scenarios-v1',
  'version': '1.0.0',
  'holdout': true,
  'fixtureCount': 10,
  'outlineSceneCount': 10,
  'createdAtMs': 1,
  'scenarios': <Object?>[
    for (var index = 0; index < 10; index += 1)
      <String, Object?>{
        'scenarioId': 'opaque-${index + 1}',
        'version': '1.0.0',
        'difficulty': 'holdout',
        'inputFixture': <String, Object?>{'prompt': '$_sentinel-${index + 1}'},
        'fixtureHash': '${index % 10}' * 64,
        'isolationMode': 'independent',
        'episodeId': 'opaque-episode',
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
        'referenceFacts': <String, Object?>{'fact': _sentinel},
        'maxBudget': <String, Object?>{'providerCalls': 48, 'tokens': 100000},
      },
  ],
};

Map<String, Object?> _releaseConfiguration() {
  final sut = _route('glm-private-material-sut');
  final judge = _route('glm-private-material-judge');
  final decoding = <String, Object?>{
    'maxConcurrentRequests': 1,
    'streamingAllowed': false,
    'tokenLimitPolicy': 'production-call-site-max-tokens-v1',
  };
  final prices = <String, Object?>{
    'promptMicrousdPerMillionTokens': 1,
    'completionMicrousdPerMillionTokens': 1,
    'judgePromptMicrousdPerMillionTokens': 1,
    'judgeCompletionMicrousdPerMillionTokens': 1,
  };
  final priceEntries =
      <Map<String, Object?>>[
        <String, Object?>{
          'modelRouteHash': sut['modelRouteHash'],
          'model': sut['model'],
          'promptMicrousdPerMillionTokens': 1,
          'completionMicrousdPerMillionTokens': 1,
        },
        <String, Object?>{
          'modelRouteHash': judge['modelRouteHash'],
          'model': judge['model'],
          'promptMicrousdPerMillionTokens': 1,
          'completionMicrousdPerMillionTokens': 1,
        },
      ]..sort(
        (left, right) => (left['modelRouteHash']! as String).compareTo(
          right['modelRouteHash']! as String,
        ),
      );
  final priceTableReleaseHash = AgentEvaluationHashes.domainHash(
    'eval-price-table-release-v1',
    <String, Object?>{
      'tableId': 'real-release-price-v1',
      'currency': 'USD',
      'roundingPolicy': 'ceil-per-attempt-microusd-v1',
      'entries': priceEntries,
    },
  );
  return <String, Object?>{
    'schemaVersion': 'production-holdout-release-configuration-v2',
    'executionId': 'private-material-execution',
    'sutRoutes': <Object?>[sut],
    'judgeRoute': judge,
    'decoding': <String, Object?>{
      ...decoding,
      'decodingConfigHash': AgentEvaluationHashes.domainHash(
        'eval-production-decoding-release-v1',
        decoding,
      ),
    },
    'budgets': <String, Object?>{
      'maxAttemptsPerTrial': 1,
      'maxCallsPerTrial': 48,
      'maxTokensPerTrial': 5000000,
      'maxPromptTokensPerCall': 100000,
      'maxCompletionTokensPerCall': 4096,
      'maxProviderCalls': 3000,
      'maxTotalTokens': 1000000000,
      'maxTotalCostMicrousd': 100000000,
      'evaluatorMaxCalls': 60,
      'evaluatorMaxTokens': 10000000,
      'evaluatorMaxCostMicrousd': 1000000,
      'evaluatorTokensPerCall': 4096,
      'evaluatorCostMicrousdPerCall': 1000,
      'deadlineMs': 300000,
      'holdoutAccessBudget': 1,
    },
    'prices': prices,
    'providerPriceAuthority': <String, Object?>{
      'rootKeyId': null,
      'priceTableReleaseHash': priceTableReleaseHash,
    },
    'releaseIdentity': <String, Object?>{
      'codeCommit': 'private-material-test',
      'sourceTreeHash': _digest('2'),
      'buildArtifactHash': _digest('4'),
      'runtimeReleaseHash': _digest('5'),
      'tokenizerReleaseHash': _digest('6'),
    },
  };
}

Map<String, Object?> _route(String model) {
  final timeout = <String, Object?>{
    'connectTimeoutMs': 30000,
    'sendTimeoutMs': 30000,
    'receiveTimeoutMs': 30000,
  };
  const provider = 'zhipu';
  const baseUrl = 'https://open.bigmodel.cn/api/paas/v4';
  const revision = 'private-material-api-v1';
  final providerHash = AgentEvaluationHashes.domainHash(
    'eval-provider-config-without-secrets-v1',
    <String, Object?>{
      'model': model,
      'provider': provider,
      'baseUrl': baseUrl,
      'timeout': timeout,
    },
  );
  final routeHash = AgentEvaluationHashes.domainHash(
    'eval-production-model-route-release-v1',
    <String, Object?>{
      'model': model,
      'provider': provider,
      'baseUrl': baseUrl,
      'timeout': timeout,
      'providerApiRevision': revision,
      'sdkAdapterReleaseHash': _digest('1'),
    },
  );
  return <String, Object?>{
    'model': model,
    'provider': provider,
    'baseUrlWithoutSecrets': baseUrl,
    'timeout': timeout,
    'providerConfigHashWithoutSecrets': providerHash,
    'providerApiRevision': revision,
    'sdkAdapterReleaseHash': _digest('1'),
    'modelRouteHash': routeHash,
  };
}

void _seedRegressionAuthority(File file) {
  final db = sqlite3.open(file.path);
  try {
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    db.execute(
      '''INSERT INTO prompt_releases (
           release_id, template_id, semantic_version, language, content_hash,
           system_template, user_template, variables_schema_json,
           output_schema_json, renderer_release, parser_release,
           repair_policy_json, variables_schema_hash, output_schema_hash,
           owner, change_note, created_at_ms
         ) VALUES ('prompt-material', 'material', '1.0.0', 'zh-CN', ?,
           'system', 'user', '{}', '{}', 'renderer-v1', 'parser-v1', '{}',
           ?, ?, 'test', 'material', 1)''',
      <Object?>[_digest('7'), _digest('8'), _digest('9')],
    );
    db.execute(
      '''INSERT INTO generation_bundles
         (bundle_hash, bundle_id, releases_json, created_at_ms)
         VALUES (?, 'champion-material', '[]', 1),
                (?, 'challenger-material', '[]', 1)''',
      <Object?>[_digest('b'), _digest('c')],
    );
    for (final bundle in <String>[_digest('b'), _digest('c')]) {
      db.execute(
        '''INSERT INTO generation_bundle_releases (
             bundle_hash, stage_id, call_site_id, variant_id,
             prompt_release_id
           ) VALUES (?, 'generate', 'material', 'default', 'prompt-material')''',
        <Object?>[bundle],
      );
    }
    db.execute(
      '''INSERT INTO evaluation_bundles (
           evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
           judges_json, rubric_release_hash, aggregator_release_hash,
           failure_taxonomy_hash, blinding_policy_version, created_at_ms
         ) VALUES (?, 'eval-material', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
      <Object?>[_digest('e'), _digest('1'), _digest('2'), _digest('3')],
    );
    db.execute(
      '''INSERT INTO eval_scenario_sets (
           scenario_set_release_hash, set_id, version, manifest_hash,
           created_at_ms
         ) VALUES (?, 'regression-material', '1', ?, 1)''',
      <Object?>[_digest('1'), _digest('2')],
    );
    db.execute(
      '''INSERT INTO eval_experiments (
           experiment_id, manifest_json, manifest_hash,
           scenario_set_release_hash, evaluation_bundle_hash,
           expected_cell_set_hash, expected_slot_set_hash, trials_per_cell,
           created_at_ms
         ) VALUES ('regression-material', '{}', ?, ?, ?, ?, ?, 3, 1)''',
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
         ) VALUES ('regression-execution-material', 'regression-material',
           'completed', ?, ?, 1, 2, 3)''',
      <Object?>[_digest('4'), _digest('5')],
    );
    db.execute(
      '''INSERT INTO eval_scorecards (
           scorecard_hash, execution_id, scope, scope_key, aggregate_json,
           input_set_hash, expected_set_hash, aggregator_release_hash,
           created_at_ms
         ) VALUES (?, 'regression-execution-material', 'execution',
           'regression-execution-material', '{}', ?, ?, ?, 3)''',
      <Object?>[_digest('7'), _digest('6'), _digest('5'), _digest('2')],
    );
    db.execute(
      '''INSERT INTO eval_release_gate_verdicts (
           verdict_hash, verdict_kind, experiment_id, execution_id,
           scorecard_hash, champion_bundle_hash, challenger_bundle_hash,
           status, reasons_json, comparison_input_set_hash,
           expected_pair_set_hash, policy_hash, gate_release_hash,
           created_at_ms
         ) VALUES (?, 'regression', 'regression-material',
           'regression-execution-material', ?, ?, ?, 'promote', '[]', ?, ?, ?, ?, 4)''',
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
  } finally {
    db.dispose();
  }
}

String _digest(String character) => character * 64;

void _chmod(String path, String mode) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>[mode, path]);
  if (result.exitCode != 0) throw StateError('chmod failed');
}

String _projectDartExecutable() {
  final packageConfig =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, Object?>;
  final packages = packageConfig['packages']! as List<Object?>;
  final flutter = packages.cast<Map<String, Object?>>().singleWhere(
    (entry) => entry['name'] == 'flutter',
  );
  final flutterPackage = Directory.fromUri(
    Uri.parse(flutter['rootUri']! as String),
  );
  final sdkRoot = flutterPackage.parent.parent;
  return '${sdkRoot.path}/bin/cache/dart-sdk/bin/dart';
}
