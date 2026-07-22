import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../app/state/authoring_db_schema.dart';
import '../../../../app/state/app_workspace_storage_io.dart';
import '../../../../app/state/db_schema_manager.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_production_side_effects.dart';
import 'agent_evaluation_trusted_holdout.dart';

final String _productionRunnerReleaseHash = AgentEvaluationHashes.domainHash(
  'eval-production-holdout-runner-v3',
  const <String, Object?>{
    'processBoundary': 'separate-private-production-process',
    'privateInputsDisclosure': 'none',
    'publicProjection': 'allowlisted-redacted-projection-v1',
    'attestation': 'production-attestation-v2-ed25519',
    'pricing': 'compile-time-trust-price-table-and-free-route-policy-v1',
  },
);

final String _productionResolverReleaseHash = AgentEvaluationHashes.domainHash(
  'eval-production-holdout-resolver-v2',
  const <String, Object?>{
    'authority': 'spent-production-holdout-access-v1',
    'projection': 'hash-bound-redacted-import-v1',
    'audit': 'private-append-only-root-v1',
  },
);

class AgentEvaluationPrivateMaterialException implements Exception {
  const AgentEvaluationPrivateMaterialException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationPrivateMaterialException: $message';
}

const _privateFixtureProjectId = 'private-holdout-project-v2';
const _privateFixtureSceneId = 'private-holdout-scene-v2';
const _privateFixtureSceneScopeId =
    '$_privateFixtureProjectId::$_privateFixtureSceneId';

Map<String, Object?> _privateFixtureWorkspace() => <String, Object?>{
  'projects': <Object?>[
    <String, Object?>{
      'id': _privateFixtureProjectId,
      'sceneId': _privateFixtureSceneId,
      'title': '私有盲测夹具',
      'genre': '悬疑',
      'summary': '隔离的私有生成评测工作区。',
      'recentLocation': '第一章 / 私有场景',
      'lastOpenedAtMs': 1,
    },
  ],
  'charactersByProject': <String, Object?>{
    _privateFixtureProjectId: <Object?>[
      <String, Object?>{
        'id': 'private-holdout-character-v2',
        'name': '调查者',
        'role': '主角',
        'note': '按冻结场景命令行动',
        'need': '取得并验证关键证据',
        'summary': '谨慎而果断',
        'referenceSummary': '私有盲测通用角色',
        'linkedSceneIds': <String>[_privateFixtureSceneId],
      },
    ],
  },
  'scenesByProject': <String, Object?>{
    _privateFixtureProjectId: <Object?>[
      <String, Object?>{
        'id': _privateFixtureSceneId,
        'chapterLabel': '第一章',
        'title': '私有调查场景',
        'summary': '主角取得证据并据此改变下一步选择。',
      },
    ],
  },
  'worldNodesByProject': <String, Object?>{},
  'auditIssuesByProject': <String, Object?>{},
  'projectStyles': <String, Object?>{},
  'projectAuditStates': <String, Object?>{},
  'projectDeletionTombstones': <String, Object?>{},
  'projectTransferState': '',
  'currentProjectId': _privateFixtureProjectId,
};

final class AgentEvaluationPrivateMaterialPreparation {
  const AgentEvaluationPrivateMaterialPreparation({
    required this.rootPath,
    required this.metadataHash,
    required this.privatePlanHash,
    required this.opaqueScenarioSetHash,
    required this.fixtureAuditRootHash,
    required this.trustPolicyHash,
  });

  final String rootPath;
  final String metadataHash;
  final String privatePlanHash;
  final String opaqueScenarioSetHash;
  final String fixtureAuditRootHash;
  final String trustPolicyHash;
}

final class AgentEvaluationPrivateMaterialBinding {
  const AgentEvaluationPrivateMaterialBinding({
    required this.bindingHash,
    required this.accessId,
  });

  final String bindingHash;
  final String accessId;
}

final class AgentEvaluationPrivateMaterialBuilder {
  const AgentEvaluationPrivateMaterialBuilder();

  String generateScenarios({required String outputPath}) {
    final output = File(outputPath).absolute;
    if (!File(outputPath).isAbsolute ||
        FileSystemEntity.typeSync(output.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw const AgentEvaluationPrivateMaterialException(
        'private scenario output must be a new absolute file',
      );
    }
    final parent = output.parent;
    if (FileSystemEntity.typeSync(parent.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        !Platform.isWindows && (parent.statSync().mode & 0x3f) != 0) {
      throw const AgentEvaluationPrivateMaterialException(
        'private scenario parent must have mode 0700',
      );
    }
    const characters = <String>[
      '林澈',
      '周岚',
      '沈砚',
      '顾遥',
      '程雪',
      '许舟',
      '韩青',
      '陆宁',
      '江晚',
      '苏衡',
    ];
    const places = <String>[
      '废弃气象站',
      '封存档案馆',
      '夜航渡口',
      '停运地铁站',
      '旧城区钟楼',
      '山间信号塔',
      '临海冷库',
      '地下拍卖场',
      '边境检查站',
      '无人值守灯塔',
    ];
    const conflicts = <String>[
      '发现时间记录与目击证词互相冲突',
      '必须在盟友隐瞒真相时保住关键证据',
      '确认看似意外的故障由人为制造',
      '在追踪者抵达前辨认伪造的通行凭证',
      '从两份相反口供中找出共同缺口',
      '阻止错误指令触发不可逆的转移',
      '在通信中断前验证匿名警告的来源',
      '识破现场被刻意安排的错误因果',
      '用新证据迫使对手改变原定行动',
      '在公开选择与私人承诺之间制造后果',
    ];
    final random = Random.secure();
    final runNonce = _randomHex(16);
    final scenarios = <Map<String, Object?>>[];
    for (var index = 0; index < 10; index += 1) {
      final character = characters[(index + random.nextInt(10)) % 10];
      final place = places[(index + random.nextInt(10)) % 10];
      final conflict = conflicts[(index + random.nextInt(10)) % 10];
      final evidenceCode = '证物-${_randomHex(4).toUpperCase()}-${index + 1}';
      final prompt =
          '$character在$place取得$evidenceCode，并$conflict。'
          '生成一段可采纳的章节场景：必须包含行动、对话、明确因果推进，'
          '让$evidenceCode改变人物下一步选择，并以新的现实压力收束。';
      final inputFixture = <String, Object?>{
        'projectId': _privateFixtureProjectId,
        'sceneId': _privateFixtureSceneId,
        'sceneScopeId': _privateFixtureSceneScopeId,
        'episodeId': 'opaque-$runNonce-${index + 1}',
        'episodeStep': 1,
        'prompt': prompt,
      };
      scenarios.add(<String, Object?>{
        'scenarioId': 'opaque-$runNonce-${index + 1}',
        'version': '1.0.0',
        'difficulty': 'release-holdout',
        'inputFixture': inputFixture,
        'fixtureHash': AgentEvaluationHashes.domainHash(
          'eval-private-generated-fixture-v1',
          inputFixture,
        ),
        'isolationMode': 'independent',
        'episodeId': 'opaque-$runNonce-${index + 1}',
        'episodeStep': 1,
        'requiredCapabilities': const <String>['story-generation'],
        'adversarialMutations': const <String>['causal-transition'],
        'verifierReleaseRefs': const <String>['production-safety@1.0.0'],
        'rubricReleaseRef': 'six-dimension-rubric@1.0.0',
        'expectedTerminalState': 'accepted',
        'requiredFailureCodes': const <String>[],
        'allowedAdditionalFailureCodes': const <String>[],
        'forbiddenFailureCodes': const <String>['provider.invalid_content'],
        'outcomeComparatorReleaseRef': 'expected-outcome@1.0.0',
        'forbiddenSideEffects': const <String>[
          AgentEvaluationProductionSideEffectKeys.authoritativeWrite,
        ],
        'acceptExpected': true,
        'referenceFacts': <String, Object?>{
          'requiredLiterals': <String>[evidenceCode],
          'forbiddenLiterals': const <String>[],
          'requiredCharacterNames': <String>[character],
          'requiredCanonRootSourceIds': const <String>[],
        },
        'maxBudget': const <String, Object?>{'calls': 48, 'maxTokens': 5000000},
      });
    }
    final scenarioMap = <String, Object?>{
      'setId': 'opaque-generated-$runNonce',
      'version': '1.0.0',
      'scenarios': scenarios,
      'fixtureCount': 10,
      'outlineSceneCount': 10,
      'holdout': true,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    final scenarioSet = _parseScenarioSet(scenarioMap);
    final lock = File('${output.path}.lock');
    RandomAccessFile? handle;
    try {
      lock.createSync(exclusive: true);
      handle = lock.openSync(mode: FileMode.writeOnly);
      if (output.existsSync()) {
        throw const AgentEvaluationPrivateMaterialException(
          'private scenario output raced',
        );
      }
      final temporary = File('${output.path}.tmp-${_randomHex(8)}');
      _writePrivateText(
        temporary,
        AgentEvaluationHashes.canonicalJson(scenarioMap),
      );
      temporary.renameSync(output.path);
      _chmod(output.path, '600');
    } finally {
      handle?.closeSync();
      if (lock.existsSync()) lock.deleteSync();
    }
    return scenarioSet.releaseHash;
  }

  Future<AgentEvaluationPrivateMaterialPreparation> prepare({
    required String rootPath,
    required String authorityDatabasePath,
    required String scenarioSourcePath,
    required String releaseConfigurationPath,
    required String releaseConfigurationHash,
    required String appArtifactHash,
    required String championBundleHash,
    required String challengerBundleHash,
    required String regressionVerdictHash,
    required String keyId,
    SimplePublicKey? externalPublicKey,
  }) async {
    for (final digest in <String>[
      releaseConfigurationHash,
      appArtifactHash,
      championBundleHash,
      challengerBundleHash,
      regressionVerdictHash,
    ]) {
      AgentEvaluationHashes.requireDigest(digest, 'private material identity');
    }
    if (championBundleHash == challengerBundleHash || keyId.trim().isEmpty) {
      throw const AgentEvaluationPrivateMaterialException(
        'private material identity is invalid',
      );
    }
    final root = Directory(rootPath).absolute;
    final rootType = FileSystemEntity.typeSync(root.path, followLinks: false);
    if (rootType == FileSystemEntityType.directory) {
      return loadPrepared(
        rootPath: root.path,
        authorityDatabasePath: authorityDatabasePath,
        scenarioSourcePath: scenarioSourcePath,
        releaseConfigurationPath: releaseConfigurationPath,
        releaseConfigurationHash: releaseConfigurationHash,
        appArtifactHash: appArtifactHash,
        championBundleHash: championBundleHash,
        challengerBundleHash: challengerBundleHash,
        regressionVerdictHash: regressionVerdictHash,
        keyId: keyId,
        externalPublicKey: externalPublicKey,
      );
    }
    if (rootType != FileSystemEntityType.notFound) {
      throw const AgentEvaluationPrivateMaterialException(
        'private material root conflicts with an existing entity',
      );
    }
    final authority = _privateFile(authorityDatabasePath, 'authority database');
    final scenarioSource = _privateFile(
      scenarioSourcePath,
      'private scenario source',
    );
    final releaseConfigurationFile = _privateFile(
      releaseConfigurationPath,
      'release configuration',
    );
    final scenarioJson = scenarioSource.readAsStringSync();
    final scenarioMap = _canonicalObject(
      scenarioJson,
      'private scenario source',
    );
    final scenarioSet = _parseScenarioSet(scenarioMap);
    final releaseConfigurationJson = releaseConfigurationFile
        .readAsStringSync();
    final releaseConfiguration = _canonicalObject(
      releaseConfigurationJson,
      'release configuration',
    );
    _validateReleaseConfiguration(releaseConfiguration);
    final actualConfigurationHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-release-configuration-v1',
      releaseConfiguration,
    );
    final releaseIdentity = releaseConfiguration['releaseIdentity'];
    if (actualConfigurationHash != releaseConfigurationHash ||
        releaseIdentity is! Map<String, Object?> ||
        releaseIdentity['buildArtifactHash'] != appArtifactHash) {
      throw const AgentEvaluationPrivateMaterialException(
        'release configuration commitment is invalid',
      );
    }
    final publicAuthority = _readPreparationAuthority(
      authority.path,
      regressionVerdictHash: regressionVerdictHash,
      championBundleHash: championBundleHash,
      challengerBundleHash: challengerBundleHash,
    );

    root.parent.createSync(recursive: true);
    final staging = Directory(
      '${root.parent.path}/.${root.uri.pathSegments.last}.staging-'
      '${_randomHex(12)}',
    );
    if (FileSystemEntity.typeSync(staging.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const AgentEvaluationPrivateMaterialException(
        'private material staging collision',
      );
    }
    staging.createSync();
    _chmod(staging.path, '700');
    try {
      if (externalPublicKey != null &&
          (externalPublicKey.type != KeyPairType.ed25519 ||
              externalPublicKey.bytes.length != 32)) {
        throw const AgentEvaluationPrivateMaterialException(
          'external signing public key is invalid',
        );
      }
      final seed = externalPublicKey == null
          ? List<int>.generate(32, (_) => Random.secure().nextInt(256))
          : null;
      final localSigner = seed == null
          ? null
          : await AgentEvaluationTrustedHoldoutSigner.fromSeed(
              keyId: keyId,
              seed: seed,
            );
      final publicKey = externalPublicKey ?? localSigner!.publicKey;
      final verifier = AgentEvaluationTrustedHoldoutVerifier(
        keyId: keyId,
        publicKey: publicKey,
        runnerReleaseHash: _productionRunnerReleaseHash,
        resolverReleaseHash: _productionResolverReleaseHash,
      );
      if (seed != null) {
        _writePrivateBytes(File('${staging.path}/ed25519.seed'), seed);
      }

      final fixture = File('${staging.path}/fixture.sqlite');
      await _buildFixture(
        destinationPath: fixture.path,
        authorityDatabasePath: authority.path,
        championBundleHash: championBundleHash,
        challengerBundleHash: challengerBundleHash,
        evaluationBundleHash: publicAuthority.evaluationBundleHash,
        scenarioSet: scenarioSet,
        scenarioSourceJson: scenarioJson,
        releaseConfigurationHash: releaseConfigurationHash,
        appArtifactHash: appArtifactHash,
        preparationAuthorityHash: publicAuthority.authorityHash,
      );
      _chmod(fixture.path, '600');
      final fixtureAuditRootHash = _canonicalSqliteFileAuditRoot(fixture.path);
      final finalFixturePath = '${root.path}/fixture.sqlite';
      final privatePlan = <String, Object?>{
        'schemaVersion': 'production-holdout-private-plan-v1',
        'opaqueHoldoutScenarioSetHash': scenarioSet.releaseHash,
        'scenarioSet': scenarioMap,
        'fixture': <String, Object?>{
          'databasePath': finalFixturePath,
          'databaseAuditRootHash': fixtureAuditRootHash,
        },
        'releaseConfiguration': releaseConfiguration,
      };
      final privatePlanHash = AgentEvaluationHashes.domainHash(
        'eval-production-holdout-private-plan-v1',
        privatePlan,
      );
      _writePrivateText(
        File('${staging.path}/private-plan.json'),
        AgentEvaluationHashes.canonicalJson(privatePlan),
      );
      final metadataPayload = <String, Object?>{
        'schemaVersion': 'production-holdout-private-material-metadata-v1',
        'state': 'prepared-awaiting-public-grant-binding',
        'custodyMode': externalPublicKey == null
            ? 'local-file-seed'
            : 'external-command-v1',
        'keyId': keyId,
        'publicKeyBase64': base64Encode(publicKey.bytes),
        'runnerReleaseHash': _productionRunnerReleaseHash,
        'resolverReleaseHash': _productionResolverReleaseHash,
        'trustPolicyHash': verifier.trustPolicyHash,
        'championBundleHash': championBundleHash,
        'challengerBundleHash': challengerBundleHash,
        'regressionVerdictHash': regressionVerdictHash,
        'opaqueHoldoutScenarioSetHash': scenarioSet.releaseHash,
        'privatePlanHash': privatePlanHash,
        'fixtureAuditRootHash': fixtureAuditRootHash,
        'releaseConfigurationHash': releaseConfigurationHash,
        'appArtifactHash': appArtifactHash,
        'preparationAuthorityHash': publicAuthority.authorityHash,
        'files': <String, Object?>{
          'fixture': 'fixture.sqlite',
          'privatePlan': 'private-plan.json',
          'seed': externalPublicKey == null ? 'ed25519.seed' : null,
        },
      };
      final metadataHash = AgentEvaluationHashes.domainHash(
        'eval-production-holdout-private-material-metadata-v1',
        metadataPayload,
      );
      _writePrivateText(
        File('${staging.path}/public-metadata.json'),
        AgentEvaluationHashes.canonicalJson(<String, Object?>{
          ...metadataPayload,
          'metadataHash': metadataHash,
        }),
      );
      if (FileSystemEntity.typeSync(root.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        staging.deleteSync(recursive: true);
        return loadPrepared(
          rootPath: root.path,
          authorityDatabasePath: authorityDatabasePath,
          scenarioSourcePath: scenarioSourcePath,
          releaseConfigurationPath: releaseConfigurationPath,
          releaseConfigurationHash: releaseConfigurationHash,
          appArtifactHash: appArtifactHash,
          championBundleHash: championBundleHash,
          challengerBundleHash: challengerBundleHash,
          regressionVerdictHash: regressionVerdictHash,
          keyId: keyId,
          externalPublicKey: externalPublicKey,
        );
      }
      staging.renameSync(root.path);
      _assertMaterialAcl(root);
      return AgentEvaluationPrivateMaterialPreparation(
        rootPath: root.path,
        metadataHash: metadataHash,
        privatePlanHash: privatePlanHash,
        opaqueScenarioSetHash: scenarioSet.releaseHash,
        fixtureAuditRootHash: fixtureAuditRootHash,
        trustPolicyHash: verifier.trustPolicyHash,
      );
    } on Object {
      if (staging.existsSync()) staging.deleteSync(recursive: true);
      rethrow;
    }
  }

  Future<AgentEvaluationPrivateMaterialPreparation> loadPrepared({
    required String rootPath,
    required String authorityDatabasePath,
    required String scenarioSourcePath,
    required String releaseConfigurationPath,
    required String releaseConfigurationHash,
    required String appArtifactHash,
    required String championBundleHash,
    required String challengerBundleHash,
    required String regressionVerdictHash,
    required String keyId,
    SimplePublicKey? externalPublicKey,
  }) async {
    for (final digest in <String>[
      releaseConfigurationHash,
      appArtifactHash,
      championBundleHash,
      challengerBundleHash,
      regressionVerdictHash,
    ]) {
      AgentEvaluationHashes.requireDigest(digest, 'private material identity');
    }
    final root = Directory(rootPath).absolute;
    _assertMaterialAcl(root);
    final scenarioSource = _privateFile(
      scenarioSourcePath,
      'private scenario source',
    );
    final scenarioJson = scenarioSource.readAsStringSync();
    final scenarioMap = _canonicalObject(
      scenarioJson,
      'private scenario source',
    );
    final scenarioSet = _parseScenarioSet(scenarioMap);
    final configurationFile = _privateFile(
      releaseConfigurationPath,
      'release configuration',
    );
    final configurationJson = configurationFile.readAsStringSync();
    final configuration = _canonicalObject(
      configurationJson,
      'release configuration',
    );
    _validateReleaseConfiguration(configuration);
    if (AgentEvaluationHashes.domainHash(
          'agent-evaluation-release-configuration-v1',
          configuration,
        ) !=
        releaseConfigurationHash) {
      throw const AgentEvaluationPrivateMaterialException(
        'prepared release configuration changed',
      );
    }
    final identity = configuration['releaseIdentity']! as Map<String, Object?>;
    if (identity['buildArtifactHash'] != appArtifactHash) {
      throw const AgentEvaluationPrivateMaterialException(
        'prepared app artifact changed',
      );
    }
    final authority = _privateFile(authorityDatabasePath, 'authority database');
    final publicAuthority = _readPreparationAuthority(
      authority.path,
      regressionVerdictHash: regressionVerdictHash,
      championBundleHash: championBundleHash,
      challengerBundleHash: challengerBundleHash,
    );
    final metadata = _canonicalObject(
      _privateFile(
        '${root.path}/public-metadata.json',
        'private material metadata',
      ).readAsStringSync(),
      'private material metadata',
    );
    _verifyMetadata(metadata);
    final expected = <String, Object?>{
      'keyId': keyId,
      'championBundleHash': championBundleHash,
      'challengerBundleHash': challengerBundleHash,
      'regressionVerdictHash': regressionVerdictHash,
      'opaqueHoldoutScenarioSetHash': scenarioSet.releaseHash,
      'releaseConfigurationHash': releaseConfigurationHash,
      'appArtifactHash': appArtifactHash,
      'preparationAuthorityHash': publicAuthority.authorityHash,
      'runnerReleaseHash': _productionRunnerReleaseHash,
      'resolverReleaseHash': _productionResolverReleaseHash,
    };
    if (expected.entries.any((entry) => metadata[entry.key] != entry.value)) {
      throw const AgentEvaluationPrivateMaterialException(
        'prepared metadata does not match the requested commitments',
      );
    }
    final metadataMode = metadata['custodyMode'];
    if (metadataMode !=
        (externalPublicKey == null
            ? 'local-file-seed'
            : 'external-command-v1')) {
      throw const AgentEvaluationPrivateMaterialException(
        'prepared custody mode changed',
      );
    }
    late final SimplePublicKey publicKey;
    if (externalPublicKey == null) {
      final signer = await AgentEvaluationTrustedHoldoutSigner.fromSeedFile(
        keyId: keyId,
        path: '${root.path}/ed25519.seed',
      );
      publicKey = signer.publicKey;
    } else {
      publicKey = externalPublicKey;
    }
    final verifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: keyId,
      publicKey: publicKey,
      runnerReleaseHash: _productionRunnerReleaseHash,
      resolverReleaseHash: _productionResolverReleaseHash,
    );
    if (base64Encode(publicKey.bytes) != metadata['publicKeyBase64'] ||
        verifier.trustPolicyHash != metadata['trustPolicyHash']) {
      throw const AgentEvaluationPrivateMaterialException(
        'prepared signing authority changed',
      );
    }
    final planSource = _privateFile(
      '${root.path}/private-plan.json',
      'private plan',
    ).readAsStringSync();
    final plan = _canonicalObject(planSource, 'private plan');
    if (plan['schemaVersion'] != 'production-holdout-private-plan-v1' ||
        AgentEvaluationHashes.canonicalJson(plan['scenarioSet']) !=
            scenarioJson ||
        AgentEvaluationHashes.canonicalJson(plan['releaseConfiguration']) !=
            configurationJson ||
        plan['opaqueHoldoutScenarioSetHash'] != scenarioSet.releaseHash ||
        plan['fixture'] is! Map<String, Object?>) {
      throw const AgentEvaluationPrivateMaterialException(
        'prepared private plan changed',
      );
    }
    final planHash = AgentEvaluationHashes.domainHash(
      'eval-production-holdout-private-plan-v1',
      plan,
    );
    final fixtureFields = plan['fixture']! as Map<String, Object?>;
    final fixture = _privateFile(
      '${root.path}/fixture.sqlite',
      'private fixture',
    );
    final fixtureAuditRoot = _canonicalSqliteFileAuditRoot(fixture.path);
    if (planHash != metadata['privatePlanHash'] ||
        fixtureFields['databasePath'] != fixture.path ||
        fixtureFields['databaseAuditRootHash'] != fixtureAuditRoot ||
        fixtureAuditRoot != metadata['fixtureAuditRootHash']) {
      throw const AgentEvaluationPrivateMaterialException(
        'prepared fixture or plan commitment changed',
      );
    }
    final fixtureDb = sqlite3.open(fixture.path, mode: OpenMode.readOnly);
    try {
      final rows = fixtureDb.select(
        'SELECT * FROM private_holdout_material_manifest',
      );
      if (rows.length != 1 ||
          rows.single['scenario_set_release_hash'] != scenarioSet.releaseHash ||
          rows.single['scenario_set_json'] != scenarioJson ||
          rows.single['release_configuration_hash'] !=
              releaseConfigurationHash ||
          rows.single['app_artifact_hash'] != appArtifactHash ||
          rows.single['preparation_authority_hash'] !=
              publicAuthority.authorityHash) {
        throw const AgentEvaluationPrivateMaterialException(
          'prepared fixture manifest changed',
        );
      }
    } finally {
      fixtureDb.dispose();
    }
    return AgentEvaluationPrivateMaterialPreparation(
      rootPath: root.path,
      metadataHash: metadata['metadataHash']! as String,
      privatePlanHash: planHash,
      opaqueScenarioSetHash: scenarioSet.releaseHash,
      fixtureAuditRootHash: fixtureAuditRoot,
      trustPolicyHash: verifier.trustPolicyHash,
    );
  }

  Future<AgentEvaluationPrivateMaterialBinding> bind({
    required String rootPath,
    required String authorityDatabasePath,
    required String accessId,
  }) async {
    if (accessId.trim().isEmpty) {
      throw const AgentEvaluationPrivateMaterialException(
        'public grant access identity is invalid',
      );
    }
    final root = Directory(rootPath).absolute;
    _assertMaterialAcl(root);
    final binding = File('${root.path}/grant-binding.json');
    final bindingType = FileSystemEntity.typeSync(
      binding.path,
      followLinks: false,
    );
    if (bindingType != FileSystemEntityType.notFound &&
        bindingType != FileSystemEntityType.file) {
      throw const AgentEvaluationPrivateMaterialException(
        'public grant binding conflicts with an existing entity',
      );
    }
    final metadata = _canonicalObject(
      _privateFile(
        '${root.path}/public-metadata.json',
        'private material metadata',
      ).readAsStringSync(),
      'private material metadata',
    );
    _verifyMetadata(metadata);
    final metadataMode = metadata['custodyMode'];
    if (metadataMode == 'local-file-seed') {
      final seedFile = _privateFile(
        '${root.path}/ed25519.seed',
        'signing seed',
      );
      final signer = await AgentEvaluationTrustedHoldoutSigner.fromSeedFile(
        keyId: metadata['keyId']! as String,
        path: seedFile.path,
      );
      if (base64Encode(signer.publicKey.bytes) != metadata['publicKeyBase64']) {
        throw const AgentEvaluationPrivateMaterialException(
          'signing seed does not match public metadata',
        );
      }
    } else if (metadataMode != 'external-command-v1' ||
        FileSystemEntity.typeSync(
              '${root.path}/ed25519.seed',
              followLinks: false,
            ) !=
            FileSystemEntityType.notFound) {
      throw const AgentEvaluationPrivateMaterialException(
        'external material must not contain a local signing seed',
      );
    }
    final authority = _privateFile(authorityDatabasePath, 'authority database');
    final grant = _readBindingAuthority(authority.path, accessId: accessId);
    if (grant.regressionVerdictHash != metadata['regressionVerdictHash'] ||
        grant.championBundleHash != metadata['championBundleHash'] ||
        grant.challengerBundleHash != metadata['challengerBundleHash'] ||
        grant.opaqueScenarioSetHash !=
            metadata['opaqueHoldoutScenarioSetHash'] ||
        grant.privatePlanHash != metadata['privatePlanHash'] ||
        grant.holdoutAccessPolicyHash != metadata['trustPolicyHash'] ||
        grant.runnerReleaseHash != metadata['runnerReleaseHash']) {
      throw const AgentEvaluationPrivateMaterialException(
        'public grant does not bind the prepared private material',
      );
    }
    final payload = <String, Object?>{
      'schemaVersion': 'production-holdout-private-material-binding-v1',
      'metadataHash': metadata['metadataHash'],
      'accessId': grant.accessId,
      'tokenId': grant.tokenId,
      'familyId': grant.familyId,
      'regressionVerdictHash': grant.regressionVerdictHash,
      'championBundleHash': grant.championBundleHash,
      'challengerBundleHash': grant.challengerBundleHash,
      'opaqueHoldoutScenarioSetHash': grant.opaqueScenarioSetHash,
      'privatePlanHash': grant.privatePlanHash,
      'holdoutAccessPolicyHash': grant.holdoutAccessPolicyHash,
      'runnerReleaseHash': grant.runnerReleaseHash,
      'productionAuthorityHash': grant.productionAuthorityHash,
      'regressionScenarioSetHash': grant.regressionScenarioSetHash,
      'alphaCostMicros': grant.alphaCostMicros,
      'begunAtMs': grant.begunAtMs,
      'consumedAtMs': grant.consumedAtMs,
      'releaseConfigurationHash': metadata['releaseConfigurationHash'],
      'appArtifactHash': metadata['appArtifactHash'],
    };
    final bindingHash = AgentEvaluationHashes.domainHash(
      'eval-production-holdout-private-material-binding-v1',
      payload,
    );
    final expectedBinding = <String, Object?>{
      ...payload,
      'bindingHash': bindingHash,
    };
    if (bindingType == FileSystemEntityType.file) {
      _assertExactBinding(binding, expectedBinding);
      return AgentEvaluationPrivateMaterialBinding(
        bindingHash: bindingHash,
        accessId: accessId,
      );
    }
    final lock = File('${root.path}/.grant-binding.lock');
    RandomAccessFile? handle;
    try {
      lock.createSync(exclusive: true);
      handle = lock.openSync(mode: FileMode.writeOnly);
      if (binding.existsSync()) {
        _assertExactBinding(binding, expectedBinding);
        return AgentEvaluationPrivateMaterialBinding(
          bindingHash: bindingHash,
          accessId: accessId,
        );
      }
      final temporary = File('${root.path}/.grant-binding-${_randomHex(8)}');
      _writePrivateText(
        temporary,
        AgentEvaluationHashes.canonicalJson(expectedBinding),
      );
      temporary.renameSync(binding.path);
      _chmod(binding.path, '600');
    } finally {
      handle?.closeSync();
      if (lock.existsSync()) lock.deleteSync();
    }
    return AgentEvaluationPrivateMaterialBinding(
      bindingHash: bindingHash,
      accessId: accessId,
    );
  }
}

void _validateReleaseConfiguration(Map<String, Object?> value) {
  const keys = <String>{
    'schemaVersion',
    'executionId',
    'sutRoutes',
    'judgeRoute',
    'decoding',
    'budgets',
    'prices',
    'providerPriceAuthority',
    'releaseIdentity',
  };
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty ||
      value['schemaVersion'] != 'production-holdout-release-configuration-v2' ||
      value['executionId'] is! String ||
      (value['executionId']! as String).trim().isEmpty ||
      value['sutRoutes'] is! List<Object?> ||
      value['judgeRoute'] is! Map<String, Object?> ||
      value['decoding'] is! Map<String, Object?> ||
      value['budgets'] is! Map<String, Object?> ||
      value['prices'] is! Map<String, Object?> ||
      value['providerPriceAuthority'] is! Map<String, Object?> ||
      value['releaseIdentity'] is! Map<String, Object?>) {
    throw const AgentEvaluationPrivateMaterialException(
      'release configuration schema is invalid',
    );
  }
  final routes = value['sutRoutes']! as List<Object?>;
  if (routes.isEmpty || routes.any((item) => item is! Map<String, Object?>)) {
    throw const AgentEvaluationPrivateMaterialException(
      'release SUT routes are invalid',
    );
  }
  final parsedRoutes = routes.cast<Map<String, Object?>>();
  for (final route in <Map<String, Object?>>[
    ...parsedRoutes,
    value['judgeRoute']! as Map<String, Object?>,
  ]) {
    _validateReleaseRoute(route);
  }
  final routeHashes = parsedRoutes
      .map((route) => route['modelRouteHash']! as String)
      .toList(growable: false);
  final sortedRouteHashes = routeHashes.toList()..sort();
  if (routeHashes.toSet().length != routeHashes.length ||
      routeHashes.join('\n') != sortedRouteHashes.join('\n') ||
      routeHashes.contains(
        (value['judgeRoute']! as Map<String, Object?>)['modelRouteHash'],
      )) {
    throw const AgentEvaluationPrivateMaterialException(
      'release route identities are not canonical and independent',
    );
  }
  final decoding = value['decoding']! as Map<String, Object?>;
  const decodingKeys = <String>{
    'maxConcurrentRequests',
    'streamingAllowed',
    'tokenLimitPolicy',
    'decodingConfigHash',
  };
  if (decoding.keys.toSet().difference(decodingKeys).isNotEmpty ||
      decodingKeys.difference(decoding.keys.toSet()).isNotEmpty ||
      decoding['maxConcurrentRequests'] != 1 ||
      decoding['streamingAllowed'] != false ||
      decoding['tokenLimitPolicy'] != 'production-call-site-max-tokens-v1' ||
      decoding['decodingConfigHash'] !=
          AgentEvaluationHashes.domainHash(
            'eval-production-decoding-release-v1',
            <String, Object?>{
              'maxConcurrentRequests': decoding['maxConcurrentRequests'],
              'streamingAllowed': decoding['streamingAllowed'],
              'tokenLimitPolicy': decoding['tokenLimitPolicy'],
            },
          )) {
    throw const AgentEvaluationPrivateMaterialException(
      'release decoding configuration is invalid',
    );
  }
  final budgets = value['budgets']! as Map<String, Object?>;
  const budgetKeys = <String>{
    'maxAttemptsPerTrial',
    'maxCallsPerTrial',
    'maxTokensPerTrial',
    'maxPromptTokensPerCall',
    'maxCompletionTokensPerCall',
    'maxProviderCalls',
    'maxTotalTokens',
    'maxTotalCostMicrousd',
    'evaluatorMaxCalls',
    'evaluatorMaxTokens',
    'evaluatorMaxCostMicrousd',
    'evaluatorTokensPerCall',
    'evaluatorCostMicrousdPerCall',
    'deadlineMs',
    'holdoutAccessBudget',
  };
  if (budgets.keys.toSet().difference(budgetKeys).isNotEmpty ||
      budgetKeys.difference(budgets.keys.toSet()).isNotEmpty ||
      budgets.values.any((item) => item is! int || item <= 0)) {
    throw const AgentEvaluationPrivateMaterialException(
      'release budgets are invalid',
    );
  }
  final slots = parsedRoutes.length * 10 * 2 * 3;
  final attempts = budgets['maxAttemptsPerTrial']! as int;
  final callsPerAttempt = budgets['maxCallsPerTrial']! as int;
  final promptTokensPerCall = budgets['maxPromptTokensPerCall']! as int;
  final completionTokensPerCall = budgets['maxCompletionTokensPerCall']! as int;
  final evaluatorTokensPerCall = budgets['evaluatorTokensPerCall']! as int;
  final worstSutCalls = slots * attempts * callsPerAttempt;
  final worstJudgeCalls = slots * attempts;
  final worstSutTokens =
      worstSutCalls * (promptTokensPerCall + completionTokensPerCall);
  final worstJudgeTokens =
      worstJudgeCalls * (promptTokensPerCall + evaluatorTokensPerCall);
  if ((budgets['maxProviderCalls']! as int) < worstSutCalls + worstJudgeCalls ||
      (budgets['maxTotalTokens']! as int) < worstSutTokens + worstJudgeTokens ||
      (budgets['evaluatorMaxCalls']! as int) < worstJudgeCalls ||
      (budgets['evaluatorMaxTokens']! as int) < worstJudgeTokens ||
      (budgets['maxTokensPerTrial']! as int) <
          callsPerAttempt * (promptTokensPerCall + completionTokensPerCall)) {
    throw const AgentEvaluationPrivateMaterialException(
      'release budgets do not cover the private matrix',
    );
  }
  final prices = value['prices']! as Map<String, Object?>;
  const priceKeys = <String>{
    'promptMicrousdPerMillionTokens',
    'completionMicrousdPerMillionTokens',
    'judgePromptMicrousdPerMillionTokens',
    'judgeCompletionMicrousdPerMillionTokens',
  };
  if (prices.keys.toSet().difference(priceKeys).isNotEmpty ||
      priceKeys.difference(prices.keys.toSet()).isNotEmpty ||
      prices.values.any((item) => item is! int || item < 0)) {
    throw const AgentEvaluationPrivateMaterialException(
      'release prices are invalid',
    );
  }
  final priceAuthority =
      value['providerPriceAuthority']! as Map<String, Object?>;
  const priceAuthorityKeys = <String>{'rootKeyId', 'priceTableReleaseHash'};
  final rootKeyId = priceAuthority['rootKeyId'];
  final priceTableReleaseHash = priceAuthority['priceTableReleaseHash'];
  if (priceAuthority.keys.toSet().difference(priceAuthorityKeys).isNotEmpty ||
      priceAuthorityKeys.difference(priceAuthority.keys.toSet()).isNotEmpty ||
      (rootKeyId != null &&
          (rootKeyId is! String ||
              !RegExp(r'^[A-Za-z0-9_.:-]{1,128}$').hasMatch(rootKeyId))) ||
      priceTableReleaseHash is! String) {
    throw const AgentEvaluationPrivateMaterialException(
      'provider price authority is invalid',
    );
  }
  AgentEvaluationHashes.requireDigest(
    priceTableReleaseHash,
    'priceTableReleaseHash',
  );
  final judgeRoute = value['judgeRoute']! as Map<String, Object?>;
  final priceEntries =
      <Map<String, Object?>>[
        for (final route in parsedRoutes)
          <String, Object?>{
            'modelRouteHash': route['modelRouteHash'],
            'model': route['model'],
            'promptMicrousdPerMillionTokens':
                prices['promptMicrousdPerMillionTokens'],
            'completionMicrousdPerMillionTokens':
                prices['completionMicrousdPerMillionTokens'],
          },
        <String, Object?>{
          'modelRouteHash': judgeRoute['modelRouteHash'],
          'model': judgeRoute['model'],
          'promptMicrousdPerMillionTokens':
              prices['judgePromptMicrousdPerMillionTokens'],
          'completionMicrousdPerMillionTokens':
              prices['judgeCompletionMicrousdPerMillionTokens'],
        },
      ]..sort(
        (left, right) => (left['modelRouteHash']! as String).compareTo(
          right['modelRouteHash']! as String,
        ),
      );
  final expectedPriceTableReleaseHash = AgentEvaluationHashes.domainHash(
    'eval-price-table-release-v1',
    <String, Object?>{
      'tableId': 'real-release-price-v1',
      'currency': 'USD',
      'roundingPolicy': 'ceil-per-attempt-microusd-v1',
      'entries': priceEntries,
    },
  );
  if (priceTableReleaseHash != expectedPriceTableReleaseHash) {
    throw const AgentEvaluationPrivateMaterialException(
      'provider price authority does not bind the configured routes',
    );
  }
  final identity = value['releaseIdentity']! as Map<String, Object?>;
  const identityKeys = <String>{
    'codeCommit',
    'sourceTreeHash',
    'buildArtifactHash',
    'runtimeReleaseHash',
    'tokenizerReleaseHash',
  };
  if (identity.keys.toSet().difference(identityKeys).isNotEmpty ||
      identityKeys.difference(identity.keys.toSet()).isNotEmpty ||
      identity['codeCommit'] is! String ||
      (identity['codeCommit']! as String).trim().isEmpty) {
    throw const AgentEvaluationPrivateMaterialException(
      'release identity is invalid',
    );
  }
  for (final key in identityKeys.difference(const <String>{'codeCommit'})) {
    final digest = identity[key];
    if (digest is! String) {
      throw const AgentEvaluationPrivateMaterialException(
        'release identity digest is invalid',
      );
    }
    AgentEvaluationHashes.requireDigest(digest, key);
  }
}

void _validateReleaseRoute(Map<String, Object?> route) {
  const keys = <String>{
    'model',
    'provider',
    'baseUrlWithoutSecrets',
    'timeout',
    'providerConfigHashWithoutSecrets',
    'providerApiRevision',
    'sdkAdapterReleaseHash',
    'modelRouteHash',
  };
  if (route.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(route.keys.toSet()).isNotEmpty ||
      route['model'] is! String ||
      (route['model']! as String).trim().isEmpty ||
      route['provider'] is! String ||
      (route['provider']! as String).trim().isEmpty ||
      route['providerApiRevision'] is! String ||
      (route['providerApiRevision']! as String).trim().isEmpty ||
      route['baseUrlWithoutSecrets'] is! String ||
      route['timeout'] is! Map<String, Object?>) {
    throw const AgentEvaluationPrivateMaterialException(
      'release route is invalid',
    );
  }
  final uri = Uri.tryParse(route['baseUrlWithoutSecrets']! as String);
  final timeout = route['timeout']! as Map<String, Object?>;
  if (uri == null ||
      !uri.isAbsolute ||
      !<String>{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      timeout.keys.toSet().difference(const <String>{
        'connectTimeoutMs',
        'sendTimeoutMs',
        'receiveTimeoutMs',
        'idleTimeoutMs',
      }).isNotEmpty ||
      timeout.entries.any(
        (entry) => entry.value is! int || (entry.value! as int) <= 0,
      )) {
    throw const AgentEvaluationPrivateMaterialException(
      'release route transport is invalid',
    );
  }
  final providerConfigHash = AgentEvaluationHashes.domainHash(
    'eval-provider-config-without-secrets-v1',
    <String, Object?>{
      'model': (route['model']! as String).trim(),
      'provider': route['provider'],
      'baseUrl': route['baseUrlWithoutSecrets'],
      'timeout': timeout,
    },
  );
  final modelRouteHash = AgentEvaluationHashes.domainHash(
    'eval-production-model-route-release-v1',
    <String, Object?>{
      'model': (route['model']! as String).trim(),
      'provider': route['provider'],
      'baseUrl': route['baseUrlWithoutSecrets'],
      'timeout': timeout,
      'providerApiRevision': (route['providerApiRevision']! as String).trim(),
      'sdkAdapterReleaseHash': route['sdkAdapterReleaseHash'],
    },
  );
  if (route['providerConfigHashWithoutSecrets'] != providerConfigHash ||
      route['modelRouteHash'] != modelRouteHash ||
      route['sdkAdapterReleaseHash'] is! String) {
    throw const AgentEvaluationPrivateMaterialException(
      'release route commitment is invalid',
    );
  }
  AgentEvaluationHashes.requireDigest(
    route['sdkAdapterReleaseHash']! as String,
    'sdkAdapterReleaseHash',
  );
}

final class _PreparationAuthority {
  const _PreparationAuthority({
    required this.evaluationBundleHash,
    required this.authorityHash,
  });

  final String evaluationBundleHash;
  final String authorityHash;
}

_PreparationAuthority _readPreparationAuthority(
  String path, {
  required String regressionVerdictHash,
  required String championBundleHash,
  required String challengerBundleHash,
}) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final rows = db.select(
      '''SELECT v.verdict_hash, v.status, v.champion_bundle_hash,
           v.challenger_bundle_hash, v.policy_hash, v.gate_release_hash,
           d.authority_release_hash, e.evaluation_bundle_hash,
           e.scenario_set_release_hash
         FROM eval_release_gate_verdicts v
         JOIN eval_release_gate_derivations d ON d.verdict_hash = v.verdict_hash
         JOIN eval_executions x ON x.execution_id = v.execution_id
         JOIN eval_experiments e ON e.experiment_id = x.experiment_id
         WHERE v.verdict_hash = ? AND v.verdict_kind = 'regression' ''',
      <Object?>[regressionVerdictHash],
    );
    if (rows.length != 1 ||
        rows.single['status'] != 'promote' ||
        rows.single['champion_bundle_hash'] != championBundleHash ||
        rows.single['challenger_bundle_hash'] != challengerBundleHash ||
        rows.single['gate_release_hash'] !=
            rows.single['authority_release_hash']) {
      throw const AgentEvaluationPrivateMaterialException(
        'regression authority does not authorize material preparation',
      );
    }
    for (final bundle in <String>[championBundleHash, challengerBundleHash]) {
      if (db.select(
            'SELECT bundle_hash FROM generation_bundles WHERE bundle_hash = ?',
            <Object?>[bundle],
          ).length !=
          1) {
        throw const AgentEvaluationPrivateMaterialException(
          'frozen generation bundle is missing',
        );
      }
    }
    final payload = <String, Object?>{
      for (final key in <String>[
        'verdict_hash',
        'champion_bundle_hash',
        'challenger_bundle_hash',
        'policy_hash',
        'gate_release_hash',
        'authority_release_hash',
        'evaluation_bundle_hash',
        'scenario_set_release_hash',
      ])
        key: rows.single[key],
    };
    return _PreparationAuthority(
      evaluationBundleHash: rows.single['evaluation_bundle_hash']! as String,
      authorityHash: AgentEvaluationHashes.domainHash(
        'eval-private-material-preparation-authority-v1',
        payload,
      ),
    );
  } finally {
    db.dispose();
  }
}

final class _BindingAuthority {
  const _BindingAuthority({
    required this.accessId,
    required this.tokenId,
    required this.familyId,
    required this.regressionVerdictHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.opaqueScenarioSetHash,
    required this.privatePlanHash,
    required this.holdoutAccessPolicyHash,
    required this.runnerReleaseHash,
    required this.productionAuthorityHash,
    required this.regressionScenarioSetHash,
    required this.alphaCostMicros,
    required this.begunAtMs,
    required this.consumedAtMs,
  });

  final String accessId;
  final String tokenId;
  final String familyId;
  final String regressionVerdictHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String opaqueScenarioSetHash;
  final String privatePlanHash;
  final String holdoutAccessPolicyHash;
  final String runnerReleaseHash;
  final String productionAuthorityHash;
  final String regressionScenarioSetHash;
  final int alphaCostMicros;
  final int begunAtMs;
  final int consumedAtMs;
}

_BindingAuthority _readBindingAuthority(
  String path, {
  required String accessId,
}) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final rows = db.select(
      '''SELECT a.access_id, a.token_id, a.family_id,
           a.challenger_bundle_hash, a.trusted_runner_release_hash,
           a.alpha_cost_micros, a.state AS access_state, a.begun_at_ms,
           t.state AS token_state, t.consumed_at_ms,
           t.regression_verdict_hash,
           f.scenario_set_release_hash, f.opaque_holdout_scenario_set_hash,
           f.private_plan_hash,
           f.holdout_access_policy_hash, f.production_authority_hash,
           v.status AS regression_status, v.champion_bundle_hash,
           v.challenger_bundle_hash AS verdict_challenger_bundle_hash
         FROM eval_production_holdout_accesses a
         JOIN eval_holdout_tokens t ON t.token_id = a.token_id
         JOIN eval_experiment_families f ON f.family_id = a.family_id
         JOIN eval_release_gate_verdicts v
           ON v.verdict_hash = t.regression_verdict_hash
         WHERE a.access_id = ?''',
      <Object?>[accessId],
    );
    if (rows.length != 1) {
      throw const AgentEvaluationPrivateMaterialException(
        'spent public grant is missing',
      );
    }
    final row = rows.single;
    if (row['access_state'] != 'begun' ||
        row['token_state'] != 'consumed' ||
        row['consumed_at_ms'] == null ||
        row['consumed_at_ms'] != row['begun_at_ms'] ||
        row['regression_status'] != 'promote' ||
        row['challenger_bundle_hash'] !=
            row['verdict_challenger_bundle_hash']) {
      throw const AgentEvaluationPrivateMaterialException(
        'spent public grant is invalid',
      );
    }
    return _BindingAuthority(
      accessId: row['access_id']! as String,
      tokenId: row['token_id']! as String,
      familyId: row['family_id']! as String,
      regressionVerdictHash: row['regression_verdict_hash']! as String,
      championBundleHash: row['champion_bundle_hash']! as String,
      challengerBundleHash: row['challenger_bundle_hash']! as String,
      opaqueScenarioSetHash: row['opaque_holdout_scenario_set_hash']! as String,
      privatePlanHash: row['private_plan_hash']! as String,
      holdoutAccessPolicyHash: row['holdout_access_policy_hash']! as String,
      runnerReleaseHash: row['trusted_runner_release_hash']! as String,
      productionAuthorityHash: row['production_authority_hash']! as String,
      regressionScenarioSetHash: row['scenario_set_release_hash']! as String,
      alphaCostMicros: row['alpha_cost_micros']! as int,
      begunAtMs: row['begun_at_ms']! as int,
      consumedAtMs: row['consumed_at_ms']! as int,
    );
  } finally {
    db.dispose();
  }
}

Future<void> _buildFixture({
  required String destinationPath,
  required String authorityDatabasePath,
  required String championBundleHash,
  required String challengerBundleHash,
  required String evaluationBundleHash,
  required ScenarioSetRelease scenarioSet,
  required String scenarioSourceJson,
  required String releaseConfigurationHash,
  required String appArtifactHash,
  required String preparationAuthorityHash,
}) async {
  final destination = sqlite3.open(destinationPath);
  final authority = sqlite3.open(
    authorityDatabasePath,
    mode: OpenMode.readOnly,
  );
  try {
    destination.execute('PRAGMA foreign_keys = ON');
    destination.execute('PRAGMA journal_mode = DELETE');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(destination);
    destination.execute('BEGIN IMMEDIATE');
    try {
      final bundleHashes = <String>[championBundleHash, challengerBundleHash];
      final membership = authority.select(
        '''SELECT * FROM generation_bundle_releases
           WHERE bundle_hash IN (?, ?)
           ORDER BY bundle_hash, stage_id, call_site_id, variant_id''',
        <Object?>[championBundleHash, challengerBundleHash],
      );
      final releaseIds =
          membership
              .map((row) => row['prompt_release_id']! as String)
              .toSet()
              .toList()
            ..sort();
      if (membership.isEmpty || releaseIds.isEmpty) {
        throw const AgentEvaluationPrivateMaterialException(
          'frozen prompt registry membership is incomplete',
        );
      }
      for (final releaseId in releaseIds) {
        final rows = authority.select(
          'SELECT * FROM prompt_releases WHERE release_id = ?',
          <Object?>[releaseId],
        );
        if (rows.length != 1) {
          throw const AgentEvaluationPrivateMaterialException(
            'frozen prompt release is missing',
          );
        }
        _insertRow(destination, 'prompt_releases', rows.single);
      }
      for (final hash in bundleHashes) {
        final rows = authority.select(
          'SELECT * FROM generation_bundles WHERE bundle_hash = ?',
          <Object?>[hash],
        );
        if (rows.length != 1) {
          throw const AgentEvaluationPrivateMaterialException(
            'frozen generation bundle is missing',
          );
        }
        _insertRow(destination, 'generation_bundles', rows.single);
      }
      for (final row in membership) {
        _insertRow(destination, 'generation_bundle_releases', row);
      }
      final evaluationRows = authority.select(
        '''SELECT * FROM evaluation_bundles
           WHERE evaluation_bundle_hash = ?''',
        <Object?>[evaluationBundleHash],
      );
      if (evaluationRows.length != 1) {
        throw const AgentEvaluationPrivateMaterialException(
          'frozen evaluation bundle is missing',
        );
      }
      _insertRow(destination, 'evaluation_bundles', evaluationRows.single);
      destination.execute(
        '''INSERT INTO eval_scenario_sets (
             scenario_set_release_hash, set_id, version, manifest_hash,
             created_at_ms
           ) VALUES (?, ?, ?, ?, ?)''',
        <Object?>[
          scenarioSet.releaseHash,
          scenarioSet.setId,
          scenarioSet.version,
          AgentEvaluationHashes.domainHash(
            'eval-private-scenario-source-manifest-v1',
            jsonDecode(scenarioSourceJson),
          ),
          scenarioSet.createdAtMs,
        ],
      );
      destination.execute('''
        CREATE TABLE private_holdout_material_manifest (
          singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
          scenario_set_release_hash TEXT NOT NULL,
          scenario_set_json TEXT NOT NULL,
          release_configuration_hash TEXT NOT NULL,
          app_artifact_hash TEXT NOT NULL,
          preparation_authority_hash TEXT NOT NULL
        )
      ''');
      destination.execute(
        '''INSERT INTO private_holdout_material_manifest (
             singleton_id, scenario_set_release_hash, scenario_set_json,
             release_configuration_hash, app_artifact_hash,
             preparation_authority_hash
           ) VALUES (1, ?, ?, ?, ?, ?)''',
        <Object?>[
          scenarioSet.releaseHash,
          scenarioSourceJson,
          releaseConfigurationHash,
          appArtifactHash,
          preparationAuthorityHash,
        ],
      );
      destination.execute('''
        CREATE TRIGGER private_holdout_material_manifest_no_update
        BEFORE UPDATE ON private_holdout_material_manifest
        BEGIN SELECT RAISE(ABORT, 'private material manifest is immutable'); END
      ''');
      destination.execute('''
        CREATE TRIGGER private_holdout_material_manifest_no_delete
        BEFORE DELETE ON private_holdout_material_manifest
        BEGIN SELECT RAISE(ABORT, 'private material manifest is permanent'); END
      ''');
      destination.execute('COMMIT');
    } on Object {
      destination.execute('ROLLBACK');
      rethrow;
    }
    final version = destination
        .select('PRAGMA user_version')
        .single
        .values
        .single;
    if (version != authoringSchemaMigrations.last.version) {
      throw const AgentEvaluationPrivateMaterialException(
        'private fixture schema is not current',
      );
    }
  } finally {
    authority.dispose();
    destination.dispose();
  }
  final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: destinationPath);
  final expectedWorkspace = _privateFixtureWorkspace();
  await workspaceStorage.save(expectedWorkspace);
  final persistedWorkspace = await workspaceStorage.load();
  if (persistedWorkspace == null ||
      AgentEvaluationHashes.canonicalJson(persistedWorkspace) !=
          AgentEvaluationHashes.canonicalJson(expectedWorkspace)) {
    throw const AgentEvaluationPrivateMaterialException(
      'private fixture workspace failed canonical write verification',
    );
  }
}

void _insertRow(Database db, String table, Row row) {
  final columns = row.keys.toList(growable: false);
  final quotedColumns = columns
      .map((column) => '"${column.replaceAll('"', '""')}"')
      .join(', ');
  final placeholders = List<String>.filled(columns.length, '?').join(', ');
  db.execute(
    'INSERT INTO "$table" ($quotedColumns) VALUES ($placeholders)',
    <Object?>[for (final column in columns) row[column]],
  );
}

ScenarioSetRelease _parseScenarioSet(Map<String, Object?> value) {
  const keys = <String>{
    'setId',
    'version',
    'scenarios',
    'fixtureCount',
    'outlineSceneCount',
    'holdout',
    'createdAtMs',
  };
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty ||
      value['setId'] is! String ||
      value['version'] is! String ||
      value['scenarios'] is! List<Object?> ||
      value['fixtureCount'] != 10 ||
      value['outlineSceneCount'] != 10 ||
      value['holdout'] != true ||
      value['createdAtMs'] is! int) {
    throw const AgentEvaluationPrivateMaterialException(
      'private scenario source must be one ten-scenario holdout set',
    );
  }
  final scenarios = (value['scenarios']! as List<Object?>)
      .map((item) {
        if (item is! Map<String, Object?>) {
          throw const AgentEvaluationPrivateMaterialException(
            'private scenario release is invalid',
          );
        }
        return _parseScenario(item);
      })
      .toList(growable: false);
  if (scenarios.length != 10 ||
      scenarios.map((item) => item.scenarioId).toSet().length != 10) {
    throw const AgentEvaluationPrivateMaterialException(
      'private scenario set must contain ten unique scenarios',
    );
  }
  return ScenarioSetRelease(
    setId: value['setId']! as String,
    version: value['version']! as String,
    scenarios: scenarios,
    fixtureCount: 10,
    outlineSceneCount: 10,
    holdout: true,
    createdAtMs: value['createdAtMs']! as int,
  );
}

ScenarioRelease _parseScenario(Map<String, Object?> value) {
  const keys = <String>{
    'scenarioId',
    'version',
    'difficulty',
    'inputFixture',
    'fixtureHash',
    'isolationMode',
    'episodeId',
    'episodeStep',
    'requiredCapabilities',
    'adversarialMutations',
    'verifierReleaseRefs',
    'rubricReleaseRef',
    'expectedTerminalState',
    'requiredFailureCodes',
    'allowedAdditionalFailureCodes',
    'forbiddenFailureCodes',
    'outcomeComparatorReleaseRef',
    'forbiddenSideEffects',
    'acceptExpected',
    'referenceFacts',
    'maxBudget',
  };
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty) {
    throw const AgentEvaluationPrivateMaterialException(
      'private scenario release is invalid',
    );
  }
  String string(String key) {
    final result = value[key];
    if (result is! String || result.trim().isEmpty) {
      throw const AgentEvaluationPrivateMaterialException(
        'private scenario release is invalid',
      );
    }
    return result;
  }

  Map<String, Object?> map(String key) {
    final result = value[key];
    if (result is! Map<String, Object?>) {
      throw const AgentEvaluationPrivateMaterialException(
        'private scenario release is invalid',
      );
    }
    return result;
  }

  List<String> strings(String key) {
    final result = value[key];
    if (result is! List<Object?> || result.any((item) => item is! String)) {
      throw const AgentEvaluationPrivateMaterialException(
        'private scenario release is invalid',
      );
    }
    return result.cast<String>();
  }

  final fixtureHash = string('fixtureHash');
  AgentEvaluationHashes.requireDigest(fixtureHash, 'fixtureHash');
  if (value['acceptExpected'] is! bool ||
      value['episodeId'] != null && value['episodeId'] is! String ||
      value['episodeStep'] != null && value['episodeStep'] is! int) {
    throw const AgentEvaluationPrivateMaterialException(
      'private scenario release is invalid',
    );
  }
  return ScenarioRelease(
    scenarioId: string('scenarioId'),
    version: string('version'),
    difficulty: string('difficulty'),
    inputFixture: map('inputFixture'),
    fixtureHash: fixtureHash,
    isolationMode: string('isolationMode'),
    requiredCapabilities: strings('requiredCapabilities'),
    adversarialMutations: strings('adversarialMutations'),
    verifierReleaseRefs: strings('verifierReleaseRefs'),
    rubricReleaseRef: string('rubricReleaseRef'),
    expectedTerminalState: string('expectedTerminalState'),
    requiredFailureCodes: strings('requiredFailureCodes'),
    allowedAdditionalFailureCodes: strings('allowedAdditionalFailureCodes'),
    forbiddenFailureCodes: strings('forbiddenFailureCodes'),
    outcomeComparatorReleaseRef: string('outcomeComparatorReleaseRef'),
    forbiddenSideEffects: strings('forbiddenSideEffects'),
    acceptExpected: value['acceptExpected']! as bool,
    referenceFacts: map('referenceFacts'),
    maxBudget: map('maxBudget'),
    episodeId: value['episodeId'] as String?,
    episodeStep: value['episodeStep'] as int?,
  );
}

String _canonicalSqliteFileAuditRoot(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    db.execute('PRAGMA query_only = ON');
    db.execute('BEGIN');
    final integrity = db.select('PRAGMA quick_check');
    if (integrity.length != 1 || integrity.single.values.single != 'ok') {
      throw const AgentEvaluationPrivateMaterialException(
        'private fixture integrity check failed',
      );
    }
    final schemaRows = db.select(
      '''SELECT type, name, tbl_name, sql FROM sqlite_schema
         WHERE name NOT LIKE 'sqlite_%' OR name = 'sqlite_sequence'
         ORDER BY type, name, tbl_name''',
    );
    final schema = <Object?>[
      for (final row in schemaRows)
        <String, Object?>{
          'type': row['type'],
          'name': row['name'],
          'tableName': row['tbl_name'],
          'sql': row['sql'],
        },
    ];
    final contents = <Object?>[];
    for (final row in schemaRows.where((row) => row['type'] == 'table')) {
      final table = row['name']! as String;
      final quoted = '"${table.replaceAll('"', '""')}"';
      final columns = db
          .select('PRAGMA table_info($quoted)')
          .map((item) => item['name']! as String)
          .toList(growable: false);
      final rows = <String>[
        for (final item in db.select('SELECT * FROM $quoted'))
          AgentEvaluationHashes.canonicalJson(<Object?>[
            for (final column in columns) _sqliteValue(item[column]),
          ]),
      ]..sort();
      contents.add(<String, Object?>{
        'table': table,
        'columns': columns,
        'rows': rows,
      });
    }
    db.execute('COMMIT');
    return AgentEvaluationHashes.domainHash(
      'eval-private-sqlite-canonical-audit-root-v1',
      <String, Object?>{'schema': schema, 'contents': contents},
    );
  } on Object {
    try {
      db.execute('ROLLBACK');
    } on Object {
      // Preserve the original error.
    }
    rethrow;
  } finally {
    db.dispose();
  }
}

Object? _sqliteValue(Object? value) {
  if (value == null || value is String || value is int || value is double) {
    return value;
  }
  if (value is List<int>) {
    return <String, Object?>{'blobBase64': base64Encode(value)};
  }
  throw const AgentEvaluationPrivateMaterialException(
    'private fixture contains unsupported SQLite data',
  );
}

Map<String, Object?> _canonicalObject(String source, String label) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?> ||
      AgentEvaluationHashes.canonicalJson(decoded) != source) {
    throw AgentEvaluationPrivateMaterialException('$label is not canonical');
  }
  return decoded;
}

void _verifyMetadata(Map<String, Object?> metadata) {
  const keys = <String>{
    'schemaVersion',
    'state',
    'custodyMode',
    'keyId',
    'publicKeyBase64',
    'runnerReleaseHash',
    'resolverReleaseHash',
    'trustPolicyHash',
    'championBundleHash',
    'challengerBundleHash',
    'regressionVerdictHash',
    'opaqueHoldoutScenarioSetHash',
    'privatePlanHash',
    'fixtureAuditRootHash',
    'releaseConfigurationHash',
    'appArtifactHash',
    'preparationAuthorityHash',
    'files',
    'metadataHash',
  };
  final claimed = metadata['metadataHash'];
  if (claimed is! String ||
      metadata.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(metadata.keys.toSet()).isNotEmpty ||
      !<String>{
        'local-file-seed',
        'external-command-v1',
      }.contains(metadata['custodyMode']) ||
      AgentEvaluationHashes.canonicalJson(metadata['files']) !=
          AgentEvaluationHashes.canonicalJson(<String, Object?>{
            'fixture': 'fixture.sqlite',
            'privatePlan': 'private-plan.json',
            'seed': metadata['custodyMode'] == 'local-file-seed'
                ? 'ed25519.seed'
                : null,
          })) {
    throw const AgentEvaluationPrivateMaterialException(
      'private material metadata is invalid',
    );
  }
  final payload = <String, Object?>{...metadata}..remove('metadataHash');
  if (metadata['schemaVersion'] !=
          'production-holdout-private-material-metadata-v1' ||
      metadata['state'] != 'prepared-awaiting-public-grant-binding' ||
      claimed !=
          AgentEvaluationHashes.domainHash(
            'eval-production-holdout-private-material-metadata-v1',
            payload,
          )) {
    throw const AgentEvaluationPrivateMaterialException(
      'private material metadata commitment is invalid',
    );
  }
}

void _assertExactBinding(File binding, Map<String, Object?> expectedBinding) {
  final file = _privateFile(binding.path, 'public grant binding');
  final source = file.readAsStringSync();
  final decoded = _canonicalObject(source, 'public grant binding');
  if (AgentEvaluationHashes.canonicalJson(decoded) !=
      AgentEvaluationHashes.canonicalJson(expectedBinding)) {
    throw const AgentEvaluationPrivateMaterialException(
      'existing public grant binding does not match current authority',
    );
  }
}

File _privateFile(String path, String label) {
  final file = File(path).absolute;
  if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw AgentEvaluationPrivateMaterialException(
      '$label must be a regular file',
    );
  }
  if (!Platform.isWindows && (file.statSync().mode & 0x3f) != 0) {
    throw AgentEvaluationPrivateMaterialException('$label must have mode 0600');
  }
  return file;
}

void _assertMaterialAcl(Directory root) {
  if (FileSystemEntity.typeSync(root.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw const AgentEvaluationPrivateMaterialException(
      'private material root is missing',
    );
  }
  if (!Platform.isWindows && (root.statSync().mode & 0x3f) != 0) {
    throw const AgentEvaluationPrivateMaterialException(
      'private material root must have mode 0700',
    );
  }
  for (final name in <String>[
    'fixture.sqlite',
    'private-plan.json',
    'public-metadata.json',
  ]) {
    _privateFile('${root.path}/$name', name);
  }
  final seedType = FileSystemEntity.typeSync(
    '${root.path}/ed25519.seed',
    followLinks: false,
  );
  if (seedType != FileSystemEntityType.notFound) {
    _privateFile('${root.path}/ed25519.seed', 'ed25519.seed');
  }
}

void _writePrivateText(File file, String value) =>
    _writePrivateBytes(file, utf8.encode(value));

void _writePrivateBytes(File file, List<int> value) {
  file.createSync(exclusive: true);
  final handle = file.openSync(mode: FileMode.writeOnly);
  try {
    handle.writeFromSync(value);
    handle.flushSync();
  } finally {
    handle.closeSync();
  }
  _chmod(file.path, '600');
}

void _chmod(String path, String mode) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>[mode, path]);
  if (result.exitCode != 0) {
    throw const AgentEvaluationPrivateMaterialException(
      'private material ACL could not be restricted',
    );
  }
}

String _randomHex(int bytes) => List<int>.generate(
  bytes,
  (_) => Random.secure().nextInt(256),
).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
