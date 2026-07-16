import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../../../app/llm/app_llm_client_types.dart';
import 'agent_evaluation_external_signer.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_private_holdout.dart';
import 'agent_evaluation_production_executor.dart';
import 'agent_evaluation_real_release_harness.dart';
import 'agent_evaluation_release_identity.dart';
import 'agent_evaluation_release_store.dart';
import 'agent_evaluation_spec_evidence.dart';
import 'agent_evaluation_trusted_holdout.dart';

/// A separate identity for offline protocol tests. Attestations emitted by a
/// purpose-built runner cannot be imported by a production family because the
/// family's trust-policy hash pins the production runner release.
final String agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash =
    AgentEvaluationHashes.domainHash(
      'eval-production-holdout-runner-purpose-built-v1',
      const <String, Object?>{
        'transport': 'caller-owned-offline-protocol-client',
        'releaseEligible': false,
      },
    );

class AgentEvaluationPrivateHoldoutRunnerException implements Exception {
  const AgentEvaluationPrivateHoldoutRunnerException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationPrivateHoldoutRunnerException: $message';
}

/// Public-authority projection consumed before any private scenario material
/// is opened. The authoring database is the sole source of these identities.
final class AgentEvaluationPrivateProductionGrant {
  const AgentEvaluationPrivateProductionGrant({
    required this.accessId,
    required this.tokenId,
    required this.familyId,
    required this.regressionVerdictHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.regressionScenarioSetHash,
    required this.opaqueHoldoutScenarioSetHash,
    required this.privatePlanHash,
    required this.holdoutAccessPolicyHash,
    required this.accessBudget,
    required this.accessOrdinal,
  });

  final String accessId;
  final String tokenId;
  final String familyId;
  final String regressionVerdictHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String regressionScenarioSetHash;
  final String opaqueHoldoutScenarioSetHash;
  final String privatePlanHash;
  final String holdoutAccessPolicyHash;
  final int accessBudget;
  final int accessOrdinal;
}

/// Strict, canonical private-plan envelope. The maps may contain private
/// prompts and fixture facts, so this object must never be serialized to logs,
/// reports, shell arguments, the authoring database, or the process response.
final class AgentEvaluationPrivateProductionPlan {
  AgentEvaluationPrivateProductionPlan._({
    required this.planHash,
    required this.opaqueHoldoutScenarioSetHash,
    required this.scenarioSet,
    required this.fixture,
    required this.releaseConfiguration,
  });

  static const schemaVersion = 'production-holdout-private-plan-v1';
  static const _keys = <String>{
    'schemaVersion',
    'opaqueHoldoutScenarioSetHash',
    'scenarioSet',
    'fixture',
    'releaseConfiguration',
  };

  final String planHash;
  final String opaqueHoldoutScenarioSetHash;
  final Map<String, Object?> scenarioSet;
  final Map<String, Object?> fixture;
  final Map<String, Object?> releaseConfiguration;

  static String scenarioSetHash(Map<String, Object?> scenarioSet) =>
      parseScenarioSet(scenarioSet).releaseHash;

  static ScenarioSetRelease parseScenarioSet(Map<String, Object?> value) {
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
        value['fixtureCount'] is! int ||
        value['outlineSceneCount'] is! int ||
        value['holdout'] != true ||
        value['createdAtMs'] is! int) {
      throw const FormatException('invalid private scenario set');
    }
    final scenarios = (value['scenarios']! as List<Object?>)
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('invalid private scenario release');
          }
          return _parseScenario(item);
        })
        .toList(growable: false);
    final result = ScenarioSetRelease(
      setId: value['setId']! as String,
      version: value['version']! as String,
      scenarios: scenarios,
      fixtureCount: value['fixtureCount']! as int,
      outlineSceneCount: value['outlineSceneCount']! as int,
      holdout: true,
      createdAtMs: value['createdAtMs']! as int,
    );
    if (result.scenarios.length != 10 ||
        result.fixtureCount != 10 ||
        result.outlineSceneCount != 10) {
      throw const FormatException('private scenario matrix must contain 10');
    }
    return result;
  }

  factory AgentEvaluationPrivateProductionPlan.fromCanonicalJson(
    String source,
  ) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?> ||
        AgentEvaluationHashes.canonicalJson(decoded) != source ||
        decoded['schemaVersion'] != schemaVersion ||
        decoded.keys.toSet().difference(_keys).isNotEmpty ||
        _keys.difference(decoded.keys.toSet()).isNotEmpty) {
      throw const FormatException('invalid private production plan');
    }
    final opaqueHash = decoded['opaqueHoldoutScenarioSetHash'];
    final scenarioSet = decoded['scenarioSet'];
    final fixture = decoded['fixture'];
    final releaseConfiguration = decoded['releaseConfiguration'];
    if (opaqueHash is! String ||
        scenarioSet is! Map<String, Object?> ||
        fixture is! Map<String, Object?> ||
        releaseConfiguration is! Map<String, Object?>) {
      throw const FormatException('invalid private production plan');
    }
    AgentEvaluationHashes.requireDigest(
      opaqueHash,
      'opaqueHoldoutScenarioSetHash',
    );
    const fixtureKeys = <String>{'databasePath', 'databaseAuditRootHash'};
    final fixturePath = fixture['databasePath'];
    final fixtureAuditRoot = fixture['databaseAuditRootHash'];
    if (fixture.keys.toSet().difference(fixtureKeys).isNotEmpty ||
        fixtureKeys.difference(fixture.keys.toSet()).isNotEmpty ||
        fixturePath is! String ||
        !File(fixturePath).isAbsolute ||
        fixtureAuditRoot is! String) {
      throw const FormatException('invalid private fixture commitment');
    }
    AgentEvaluationHashes.requireDigest(
      fixtureAuditRoot,
      'databaseAuditRootHash',
    );
    if (scenarioSetHash(scenarioSet) != opaqueHash) {
      throw const FormatException('private scenario-set commitment mismatch');
    }
    return AgentEvaluationPrivateProductionPlan._(
      planHash: AgentEvaluationHashes.domainHash(
        'eval-production-holdout-private-plan-v1',
        decoded,
      ),
      opaqueHoldoutScenarioSetHash: opaqueHash,
      scenarioSet: Map.unmodifiable(scenarioSet),
      fixture: Map.unmodifiable(fixture),
      releaseConfiguration: Map.unmodifiable(releaseConfiguration),
    );
  }
}

/// DB-derived outputs of a complete private production execution. This type
/// deliberately contains commitments and the allowlisted projection only.
final class AgentEvaluationPrivateProductionArtifacts {
  AgentEvaluationPrivateProductionArtifacts({
    required this.productionManifestHash,
    required this.privateExecutionSummaryHash,
    required this.privateScorecardHash,
    required this.privateGateVerdictHash,
    required this.privateProjectionHash,
    required this.expectedCellSetHash,
    required this.expectedSlotSetHash,
    required this.executionBudgetPolicyHash,
    required this.executorReleaseHash,
    required this.evaluationBundleHash,
    required this.priceTableHash,
    required this.gatePolicyHash,
    required this.projection,
  }) {
    for (final digest in <String>[
      productionManifestHash,
      privateExecutionSummaryHash,
      privateScorecardHash,
      privateGateVerdictHash,
      privateProjectionHash,
      expectedCellSetHash,
      expectedSlotSetHash,
      executionBudgetPolicyHash,
      executorReleaseHash,
      evaluationBundleHash,
      priceTableHash,
      gatePolicyHash,
    ]) {
      AgentEvaluationHashes.requireDigest(digest, 'private production output');
    }
    if (projection.scorecard['expectedCellSetHash'] != expectedCellSetHash ||
        projection.scorecard['expectedSlotSetHash'] != expectedSlotSetHash ||
        projection.gateVerdict['scorecardHash'] != privateScorecardHash ||
        projection.gateVerdict['projectionHash'] != privateProjectionHash ||
        projection.gateVerdict['policyHash'] != gatePolicyHash ||
        gatePolicyHash != AgentEvaluationStandardGatePolicy.policyHash) {
      throw ArgumentError('private projection is not DB-authority-bound');
    }
  }

  final String productionManifestHash;
  final String privateExecutionSummaryHash;
  final String privateScorecardHash;
  final String privateGateVerdictHash;
  final String privateProjectionHash;
  final String expectedCellSetHash;
  final String expectedSlotSetHash;
  final String executionBudgetPolicyHash;
  final String executorReleaseHash;
  final String evaluationBundleHash;
  final String priceTableHash;
  final String gatePolicyHash;
  final AgentEvaluationProductionHoldoutProjection projection;
}

abstract interface class AgentEvaluationPrivateProductionExecution {
  Future<AgentEvaluationPrivateProductionArtifacts> run({
    required AgentEvaluationPrivateProductionGrant grant,
    required AgentEvaluationPrivateProductionPlan plan,
    required Directory privateWorkDirectory,
  });
}

/// Real-provider adapter for the formal release harness. The private plan,
/// rather than a public fallback, supplies the ten holdout scenarios and the
/// read-only fixture database. Every returned commitment is re-read from the
/// harness authority database after the matrix seals.
final class AgentEvaluationRealHarnessPrivateProductionExecution
    implements AgentEvaluationPrivateProductionExecution {
  const AgentEvaluationRealHarnessPrivateProductionExecution.auditOnly({
    required this.configuration,
  }) : publicCustodyCapability = null,
       releaseBudgetDirectory = null;

  const AgentEvaluationRealHarnessPrivateProductionExecution.production({
    required this.configuration,
    required this.publicCustodyCapability,
    required this.releaseBudgetDirectory,
  });

  final AgentEvaluationRealReleaseConfiguration configuration;
  final AgentEvaluationVerifiedProductionCustodyToken? publicCustodyCapability;
  final Directory? releaseBudgetDirectory;

  static Map<String, Object?> canonicalReleaseConfiguration(
    AgentEvaluationRealReleaseConfiguration configuration,
  ) => configuration.toCanonicalReleaseConfiguration();

  void validatePlanCommitments({
    required AgentEvaluationPrivateProductionGrant grant,
    required AgentEvaluationPrivateProductionPlan plan,
  }) {
    final scenarioSet = AgentEvaluationPrivateProductionPlan.parseScenarioSet(
      plan.scenarioSet,
    );
    if (scenarioSet.releaseHash != grant.opaqueHoldoutScenarioSetHash) {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'private scenario set is not authority-bound',
      );
    }
    final actualConfiguration = canonicalReleaseConfiguration(configuration);
    if (AgentEvaluationHashes.canonicalJson(plan.releaseConfiguration) !=
        AgentEvaluationHashes.canonicalJson(actualConfiguration)) {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'private release configuration does not match the runtime',
      );
    }
  }

  @override
  Future<AgentEvaluationPrivateProductionArtifacts> run({
    required AgentEvaluationPrivateProductionGrant grant,
    required AgentEvaluationPrivateProductionPlan plan,
    required Directory privateWorkDirectory,
  }) async {
    validatePlanCommitments(grant: grant, plan: plan);
    final scenarioSet = AgentEvaluationPrivateProductionPlan.parseScenarioSet(
      plan.scenarioSet,
    );
    final fixtureFile = _regularFile(
      plan.fixture['databasePath']! as String,
      label: 'private fixture database',
      requirePrivateMode: true,
    );
    final harnessWork = Directory('${privateWorkDirectory.path}/harness');
    final reportDirectory = Directory(
      '${privateWorkDirectory.path}/release-report',
    );
    _secureDirectory(harnessWork);
    _secureDirectory(reportDirectory);
    final fixtureSnapshot = await _openVerifiedFixtureSnapshot(
      sourceFile: fixtureFile,
      expectedAuditRootHash: plan.fixture['databaseAuditRootHash']! as String,
      privateWorkDirectory: privateWorkDirectory,
    );
    final custodyCapability = publicCustodyCapability;
    final combinedBudgetDirectory = releaseBudgetDirectory;
    if (custodyCapability == null) {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'private real-provider execution requires verified external custody',
      );
    }
    if (combinedBudgetDirectory == null) {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'private real-provider execution requires combined release budget',
      );
    }
    final harness = AgentEvaluationRealReleaseHarness.realProvider(
      configuration: configuration,
      outputDirectory: reportDirectory,
      workDirectory: harnessWork,
      releaseBudgetDirectory: combinedBudgetDirectory,
      privateInputs: AgentEvaluationPrivateReleaseInputs(
        scenarioSet: scenarioSet,
        fixtureDatabasePath: fixtureSnapshot.path,
        holdoutAccessPolicy: HoldoutAccessPolicy(
          policyHash: grant.holdoutAccessPolicyHash,
          accessBudget: grant.accessBudget,
          accessOrdinal: grant.accessOrdinal,
          confirmationToken: grant.accessId,
        ),
      ),
      publicCustodyCapability: custodyCapability,
    );
    try {
      final result = await harness.run();
      if (!result.realProviderEvidence || result.partitions.length != 1) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production matrix is incomplete',
        );
      }
      final partition = result.partitions.single;
      final authority = sqlite3.open(
        result.authorityDatabasePath,
        mode: OpenMode.readOnly,
      );
      try {
        return _derivePrivateArtifacts(
          authority,
          partition: partition,
          executionId: configuration.executionId,
          grant: grant,
        );
      } finally {
        authority.dispose();
      }
    } finally {
      harness.dispose();
      _restrictPrivateTree(privateWorkDirectory);
    }
  }
}

/// Builds the exact same frozen production configuration used by the public
/// release runner. Secrets are accepted only from the inherited environment;
/// they are never copied into the private plan or any response/report.
AgentEvaluationRealReleaseConfiguration
agentEvaluationRealReleaseConfigurationFromEnvironment(
  Map<String, String> environment,
) {
  int integer(String name) {
    final value = int.tryParse(environment[name] ?? '');
    if (value == null || value <= 0) {
      throw ArgumentError('invalid frozen private release environment');
    }
    return value;
  }

  int price(String name) {
    final value = int.tryParse(environment[name] ?? '');
    if (value == null || value < 0) {
      throw ArgumentError('invalid frozen private release environment');
    }
    return value;
  }

  String value(String name) {
    final result = (environment[name] ?? '').trim();
    if (result.isEmpty) {
      throw ArgumentError('invalid frozen private release environment');
    }
    return result;
  }

  final models =
      value('AGENT_EVAL_REQUIRED_MODELS')
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  final judgeModel = value('AGENT_EVAL_JUDGE_MODEL');
  if (models.isEmpty || models.contains(judgeModel)) {
    throw ArgumentError('invalid frozen private release environment');
  }
  final deadlineMs = integer('AGENT_EVAL_DEADLINE_MS');
  final timeoutMs = deadlineMs.clamp(1000, 600000);
  final baseUrl = value('ZHIPU_BASE_URL');
  final sourceTreeHash = value('AGENT_EVAL_SOURCE_TREE_HASH');
  final buildArtifactHash = value('AGENT_EVAL_BUILD_ARTIFACT_HASH');
  final providerApiRevision = value('AGENT_EVAL_PROVIDER_API_REVISION');
  final sdkAdapterReleaseHash =
      AgentEvaluationDerivedReleaseIdentity.sdkAdapterReleaseHash(
        sourceTreeHash: sourceTreeHash,
        buildArtifactHash: buildArtifactHash,
        providerApiRevision: providerApiRevision,
      );
  final tokenizerReleaseHash =
      AgentEvaluationDerivedReleaseIdentity.tokenizerReleaseHash(
        sourceTreeHash: sourceTreeHash,
        buildArtifactHash: buildArtifactHash,
      );
  final runtimeReleaseHash =
      AgentEvaluationDerivedReleaseIdentity.runtimeReleaseHash(
        sourceTreeHash: sourceTreeHash,
        buildArtifactHash: buildArtifactHash,
      );
  if (value('AGENT_EVAL_SDK_ADAPTER_RELEASE_HASH') != sdkAdapterReleaseHash ||
      value('AGENT_EVAL_TOKENIZER_RELEASE_HASH') != tokenizerReleaseHash ||
      value('AGENT_EVAL_RUNTIME_RELEASE_HASH') != runtimeReleaseHash) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'release identities do not match the frozen source and binary',
    );
  }
  final provider = Uri.parse(baseUrl).path.toLowerCase().contains('/anthropic')
      ? AppLlmProvider.anthropic
      : AppLlmProvider.zhipu;
  AgentEvaluationProductionRouteRelease route(String model) =>
      AgentEvaluationProductionRouteRelease(
        model: model,
        provider: provider,
        baseUrl: baseUrl,
        apiKey: value('ZHIPU_API_KEY'),
        timeout: AppLlmTimeoutConfig.uniform(timeoutMs),
        providerApiRevision: providerApiRevision,
        sdkAdapterReleaseHash: sdkAdapterReleaseHash,
      );
  final configuration = AgentEvaluationRealReleaseConfiguration(
    executionId:
        environment['AGENT_EVAL_EXECUTION_ID']?.trim().isNotEmpty == true
        ? environment['AGENT_EVAL_EXECUTION_ID']!.trim()
        : 'private-release-${DateTime.now().millisecondsSinceEpoch}',
    sutRoutes: models.map(route),
    judgeRoute: route(judgeModel),
    decoding: AgentEvaluationProductionDecodingRelease.standard(),
    maxAttemptsPerTrial: integer('AGENT_EVAL_MAX_ATTEMPTS_PER_TRIAL'),
    maxCallsPerTrial: integer('AGENT_EVAL_MAX_CALLS_PER_TRIAL'),
    maxTokensPerTrial: integer('AGENT_EVAL_MAX_TOKENS_PER_TRIAL'),
    maxPromptTokensPerCall: integer('AGENT_EVAL_MAX_PROMPT_TOKENS_PER_CALL'),
    maxCompletionTokensPerCall: integer(
      'AGENT_EVAL_MAX_COMPLETION_TOKENS_PER_CALL',
    ),
    maxProviderCalls: integer('AGENT_EVAL_MAX_CALLS'),
    maxTotalTokens: integer('AGENT_EVAL_MAX_TOKENS'),
    maxTotalCostMicrousd: integer('AGENT_EVAL_MAX_COST_MICROUSD'),
    evaluatorMaxCalls: integer('AGENT_EVAL_JUDGE_MAX_CALLS'),
    evaluatorMaxTokens: integer('AGENT_EVAL_JUDGE_MAX_TOKENS'),
    evaluatorMaxCostMicrousd: integer('AGENT_EVAL_JUDGE_MAX_COST_MICROUSD'),
    evaluatorTokensPerCall: integer('AGENT_EVAL_JUDGE_MAX_TOKENS_PER_CALL'),
    evaluatorCostMicrousdPerCall: integer(
      'AGENT_EVAL_JUDGE_MAX_COST_MICROUSD_PER_CALL',
    ),
    promptMicrousdPerMillionTokens: price(
      'AGENT_EVAL_PROMPT_PRICE_MICROUSD_PER_MTOK',
    ),
    completionMicrousdPerMillionTokens: price(
      'AGENT_EVAL_COMPLETION_PRICE_MICROUSD_PER_MTOK',
    ),
    judgePromptMicrousdPerMillionTokens: price(
      'AGENT_EVAL_JUDGE_PROMPT_PRICE_MICROUSD_PER_MTOK',
    ),
    judgeCompletionMicrousdPerMillionTokens: price(
      'AGENT_EVAL_JUDGE_COMPLETION_PRICE_MICROUSD_PER_MTOK',
    ),
    deadline: Duration(milliseconds: deadlineMs),
    holdoutAccessBudget: integer('AGENT_EVAL_HOLDOUT_ACCESS_BUDGET'),
    codeCommit: value('AGENT_EVAL_CODE_COMMIT'),
    sourceTreeHash: sourceTreeHash,
    buildArtifactHash: buildArtifactHash,
    runtimeReleaseHash: runtimeReleaseHash,
    tokenizerReleaseHash: tokenizerReleaseHash,
    providerPriceAuthorityRootKeyId: value(
      'AGENT_EVAL_PROVIDER_PRICE_AUTHORITY_ROOT_KEY_ID',
    ),
  );
  configuration.requireCombinedReleaseBudgetCoverage();
  return configuration;
}

/// Strict process envelope. There is intentionally no free-form diagnostic,
/// evaluator output, private path, prompt, fact, prose, or caller result.
final class AgentEvaluationPrivateProductionProcessResponse {
  AgentEvaluationPrivateProductionProcessResponse({
    required this.attestation,
    required this.projection,
  });

  static const schemaVersion = 'production-holdout-process-response-v2';
  static const _keys = <String>{
    'schemaVersion',
    'payloadJson',
    'signatureBase64',
    'redactedExecutionSummaryJson',
    'redactedScorecardJson',
    'redactedGateVerdictJson',
  };

  final AgentEvaluationProductionHoldoutAttestation attestation;
  final AgentEvaluationProductionHoldoutProjection projection;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'payloadJson': attestation.payloadJson,
    'signatureBase64': attestation.signatureBase64,
    'redactedExecutionSummaryJson': projection.executionSummaryJson,
    'redactedScorecardJson': projection.scorecardJson,
    'redactedGateVerdictJson': projection.gateVerdictJson,
  };

  String get canonicalJson => AgentEvaluationHashes.canonicalJson(toJson());

  factory AgentEvaluationPrivateProductionProcessResponse.fromJson(
    Map<String, Object?> value,
  ) {
    if (value['schemaVersion'] != schemaVersion ||
        value.keys.toSet().difference(_keys).isNotEmpty ||
        _keys.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException('invalid private production response');
    }
    String field(String key) {
      final item = value[key];
      if (item is! String) {
        throw const FormatException('invalid private production response');
      }
      return item;
    }

    Map<String, Object?> document(String key) {
      final source = field(key);
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, Object?> ||
          AgentEvaluationHashes.canonicalJson(decoded) != source) {
        throw const FormatException('invalid private production response');
      }
      return decoded;
    }

    return AgentEvaluationPrivateProductionProcessResponse(
      attestation: AgentEvaluationProductionHoldoutAttestation.fromStorage(
        payloadJson: field('payloadJson'),
        signatureBase64: field('signatureBase64'),
      ),
      projection: AgentEvaluationProductionHoldoutProjection(
        executionSummary: document('redactedExecutionSummaryJson'),
        scorecard: document('redactedScorecardJson'),
        gateVerdict: document('redactedGateVerdictJson'),
      ),
    );
  }
}

/// Dedicated private-process coordinator. [purposeBuilt] is useful for full
/// offline protocol/adversarial tests but emits a distinct, non-release runner
/// identity. [production] may only be used with the real private execution
/// adapter owned by the CLI.
final class AgentEvaluationPrivateProductionHoldoutRunner {
  AgentEvaluationPrivateProductionHoldoutRunner._({
    required this.authorityDatabasePath,
    required this.accessId,
    required this.privatePlanPath,
    required this.vaultPath,
    required this.privateWorkDirectory,
    required this.signer,
    required this.execution,
    required this.runnerReleaseHash,
    required int Function() clock,
  }) : _clock = clock;

  factory AgentEvaluationPrivateProductionHoldoutRunner.purposeBuilt({
    required String authorityDatabasePath,
    required String accessId,
    required String privatePlanPath,
    required String vaultPath,
    required Directory privateWorkDirectory,
    required AgentEvaluationHoldoutSigningAuthority signer,
    required AgentEvaluationPrivateProductionExecution execution,
    int Function()? clock,
  }) => AgentEvaluationPrivateProductionHoldoutRunner._(
    authorityDatabasePath: authorityDatabasePath,
    accessId: accessId,
    privatePlanPath: privatePlanPath,
    vaultPath: vaultPath,
    privateWorkDirectory: privateWorkDirectory,
    signer: signer,
    execution: execution,
    runnerReleaseHash:
        agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash,
    clock: clock ?? _systemNowMs,
  );

  /// Production factory for the supervisor-owned real-provider adapter.
  /// Audit/local signers cannot cross this type and custody gate.
  factory AgentEvaluationPrivateProductionHoldoutRunner.production({
    required String authorityDatabasePath,
    required String accessId,
    required String privatePlanPath,
    required String vaultPath,
    required Directory privateWorkDirectory,
    required AgentEvaluationExternalHoldoutSigner signer,
    required AgentEvaluationRealReleaseConfiguration configuration,
    required Directory releaseBudgetDirectory,
    required AgentEvaluationVerifiedProductionCustodyToken
    publicCustodyCapability,
  }) {
    if (!signer.productionAuthorityEligible) {
      throw ArgumentError(
        'production holdout runner requires registered external signer',
      );
    }
    return AgentEvaluationPrivateProductionHoldoutRunner._(
      authorityDatabasePath: authorityDatabasePath,
      accessId: accessId,
      privatePlanPath: privatePlanPath,
      vaultPath: vaultPath,
      privateWorkDirectory: privateWorkDirectory,
      signer: signer,
      execution:
          AgentEvaluationRealHarnessPrivateProductionExecution.production(
            configuration: configuration,
            publicCustodyCapability: publicCustodyCapability,
            releaseBudgetDirectory: releaseBudgetDirectory,
          ),
      runnerReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
      clock: _systemNowMs,
    );
  }

  final String authorityDatabasePath;
  final String accessId;
  final String privatePlanPath;
  final String vaultPath;
  final Directory privateWorkDirectory;
  final AgentEvaluationHoldoutSigningAuthority signer;
  final AgentEvaluationPrivateProductionExecution execution;
  final String runnerReleaseHash;
  final int Function() _clock;

  /// Public-only preflight. Safe CLIs can call this before constructing a real
  /// private executor. It never opens [privatePlanPath] or [vaultPath].
  AgentEvaluationPrivateProductionGrant verifySpentAuthority() {
    final authorityFile = _regularFile(
      authorityDatabasePath,
      label: 'authority database',
      requirePrivateMode: true,
    );
    final verifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: signer.keyId,
      publicKey: signer.publicKey,
      runnerReleaseHash: runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
    );
    final db = sqlite3.open(authorityFile.path, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        '''SELECT a.*, t.state AS token_state, t.consumed_at_ms,
             t.regression_verdict_hash,
             f.scenario_set_release_hash AS regression_scenario_set_hash,
             f.opaque_holdout_scenario_set_hash, f.private_plan_hash,
             f.holdout_access_policy_hash, f.max_accesses, f.used_accesses,
             v.verdict_kind, v.status AS regression_status,
             v.champion_bundle_hash, v.challenger_bundle_hash AS verdict_challenger_bundle_hash,
             v.policy_hash, v.gate_release_hash, d.authority_release_hash,
             (SELECT COUNT(*) - 1
                FROM eval_production_holdout_accesses prior
                WHERE prior.family_id = a.family_id AND (
                  prior.begun_at_ms < a.begun_at_ms OR
                  (prior.begun_at_ms = a.begun_at_ms
                    AND prior.access_id <= a.access_id)
                )) AS access_ordinal
           FROM eval_production_holdout_accesses a
           JOIN eval_holdout_tokens t ON t.token_id = a.token_id
           JOIN eval_experiment_families f ON f.family_id = a.family_id
           JOIN eval_release_gate_verdicts v
             ON v.verdict_hash = t.regression_verdict_hash
           JOIN eval_release_gate_derivations d
             ON d.verdict_hash = v.verdict_hash
           WHERE a.access_id = ?''',
        <Object?>[accessId],
      );
      if (rows.length != 1) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'spent production holdout authority is missing',
        );
      }
      final row = rows.single;
      if (row['state'] != 'begun' ||
          row['token_state'] != 'consumed' ||
          row['consumed_at_ms'] == null ||
          row['begun_at_ms'] != row['consumed_at_ms'] ||
          row['trusted_runner_release_hash'] != runnerReleaseHash ||
          row['holdout_access_policy_hash'] != verifier.trustPolicyHash ||
          row['verdict_kind'] != 'regression' ||
          row['regression_status'] != 'promote' ||
          row['challenger_bundle_hash'] !=
              row['verdict_challenger_bundle_hash'] ||
          row['policy_hash'] != AgentEvaluationStandardGatePolicy.policyHash ||
          row['gate_release_hash'] !=
              AgentEvaluationStandardGatePolicy.gateReleaseHash ||
          row['authority_release_hash'] != row['gate_release_hash']) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'spent production holdout authority graph is invalid',
        );
      }
      final grant = AgentEvaluationPrivateProductionGrant(
        accessId: row['access_id'] as String,
        tokenId: row['token_id'] as String,
        familyId: row['family_id'] as String,
        regressionVerdictHash: row['regression_verdict_hash'] as String,
        championBundleHash: row['champion_bundle_hash'] as String,
        challengerBundleHash: row['challenger_bundle_hash'] as String,
        regressionScenarioSetHash:
            row['regression_scenario_set_hash'] as String,
        opaqueHoldoutScenarioSetHash:
            row['opaque_holdout_scenario_set_hash'] as String,
        privatePlanHash: row['private_plan_hash'] as String,
        holdoutAccessPolicyHash: row['holdout_access_policy_hash'] as String,
        accessBudget: row['max_accesses'] as int,
        accessOrdinal: row['access_ordinal'] as int,
      );
      for (final digest in <String>[
        grant.regressionVerdictHash,
        grant.championBundleHash,
        grant.challengerBundleHash,
        grant.regressionScenarioSetHash,
        grant.opaqueHoldoutScenarioSetHash,
        grant.privatePlanHash,
        grant.holdoutAccessPolicyHash,
      ]) {
        AgentEvaluationHashes.requireDigest(digest, 'production holdout grant');
      }
      if (grant.accessBudget <= 0 ||
          grant.accessOrdinal < 0 ||
          grant.accessOrdinal >= grant.accessBudget) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'production holdout access budget is invalid',
        );
      }
      return grant;
    } on SqliteException {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'production holdout authority cannot be verified',
      );
    } finally {
      db.dispose();
    }
  }

  Future<AgentEvaluationPrivateProductionProcessResponse> run() async {
    final grant = verifySpentAuthority();
    _secureDirectory(privateWorkDirectory);
    final vault = _PrivateProductionAuditVault.open(vaultPath);
    try {
      final prior = vault.reserveOrRead(
        accessId: grant.accessId,
        privatePlanHash: grant.privatePlanHash,
        runnerReleaseHash: runnerReleaseHash,
      );
      if (prior != null) {
        final attestation = prior.attestation;
        final verifier = AgentEvaluationTrustedHoldoutVerifier(
          keyId: signer.keyId,
          publicKey: signer.publicKey,
          runnerReleaseHash: runnerReleaseHash,
          resolverReleaseHash:
              AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
        );
        if (attestation.accessId != grant.accessId ||
            attestation.tokenId != grant.tokenId ||
            attestation.familyId != grant.familyId ||
            attestation.regressionVerdictHash != grant.regressionVerdictHash ||
            attestation.championBundleHash != grant.championBundleHash ||
            attestation.challengerBundleHash != grant.challengerBundleHash ||
            attestation.privatePlanHash != grant.privatePlanHash ||
            !await verifier.verifyProductionSignature(attestation)) {
          throw const AgentEvaluationPrivateHoldoutRunnerException(
            'private production completion is unverifiable',
          );
        }
        final plan = _loadBoundPlan(grant);
        final productionExecution = execution;
        if (productionExecution
            is AgentEvaluationRealHarnessPrivateProductionExecution) {
          productionExecution.validatePlanCommitments(grant: grant, plan: plan);
        }
        final nowMs = _clock();
        if (nowMs < attestation.expiresAtMs) return prior;
        final refresh = vault.reserveRefreshSlot(
          accessId: grant.accessId,
          priorClaimHash: attestation.claimHash,
          nowMs: nowMs,
        );
        final unsigned = AgentEvaluationProductionHoldoutAttestation(
          familyId: attestation.familyId,
          tokenId: attestation.tokenId,
          accessId: attestation.accessId,
          regressionVerdictHash: attestation.regressionVerdictHash,
          championBundleHash: attestation.championBundleHash,
          challengerBundleHash: attestation.challengerBundleHash,
          regressionScenarioSetHash: attestation.regressionScenarioSetHash,
          opaqueHoldoutScenarioSetHash:
              attestation.opaqueHoldoutScenarioSetHash,
          privatePlanHash: attestation.privatePlanHash,
          productionManifestHash: attestation.productionManifestHash,
          privateExecutionSummaryHash: attestation.privateExecutionSummaryHash,
          privateScorecardHash: attestation.privateScorecardHash,
          privateGateVerdictHash: attestation.privateGateVerdictHash,
          privateProjectionHash: attestation.privateProjectionHash,
          redactedExecutionSummaryHash:
              attestation.redactedExecutionSummaryHash,
          redactedScorecardHash: attestation.redactedScorecardHash,
          redactedGateVerdictHash: attestation.redactedGateVerdictHash,
          expectedCellSetHash: attestation.expectedCellSetHash,
          expectedSlotSetHash: attestation.expectedSlotSetHash,
          executionBudgetPolicyHash: attestation.executionBudgetPolicyHash,
          executorReleaseHash: attestation.executorReleaseHash,
          evaluationBundleHash: attestation.evaluationBundleHash,
          priceTableHash: attestation.priceTableHash,
          gatePolicyHash: attestation.gatePolicyHash,
          auditRootHash: refresh.refreshRootHash,
          result: attestation.result,
          runnerReleaseHash: attestation.runnerReleaseHash,
          resolverReleaseHash: attestation.resolverReleaseHash,
          keyId: attestation.keyId,
          nonce: refresh.nonce,
          issuedAtMs: refresh.issuedAtMs,
          expiresAtMs: refresh.expiresAtMs,
          signatureBase64: 'unsigned',
        );
        final refreshed = AgentEvaluationPrivateProductionProcessResponse(
          attestation: await signer.signProduction(unsigned),
          projection: prior.projection,
        );
        return vault.completeRefresh(
          slot: refresh,
          priorClaimHash: attestation.claimHash,
          response: refreshed,
          completedAtMs: _clock(),
        );
      }

      // Private material is opened only after both the spent public grant and
      // the durable one-probe reservation have succeeded.
      final plan = _loadBoundPlan(grant);
      final artifacts = await execution.run(
        grant: grant,
        plan: plan,
        privateWorkDirectory: privateWorkDirectory,
      );
      final issuedAtMs = _clock();
      final auditReservation = vault.reserveAuditEvent(
        accessId: grant.accessId,
        privatePlanHash: grant.privatePlanHash,
        productionManifestHash: artifacts.productionManifestHash,
        privateExecutionSummaryHash: artifacts.privateExecutionSummaryHash,
        privateScorecardHash: artifacts.privateScorecardHash,
        privateGateVerdictHash: artifacts.privateGateVerdictHash,
        result: artifacts.projection.result,
        createdAtMs: issuedAtMs,
      );
      final nonce = AgentEvaluationHashes.domainHash(
        'eval-production-holdout-nonce-v2',
        <String, Object?>{
          'accessId': grant.accessId,
          'issuedAtMs': issuedAtMs,
          'entropy': List<int>.generate(
            32,
            (_) => Random.secure().nextInt(256),
          ),
        },
      );
      final unsigned = AgentEvaluationProductionHoldoutAttestation(
        familyId: grant.familyId,
        tokenId: grant.tokenId,
        accessId: grant.accessId,
        regressionVerdictHash: grant.regressionVerdictHash,
        championBundleHash: grant.championBundleHash,
        challengerBundleHash: grant.challengerBundleHash,
        regressionScenarioSetHash: grant.regressionScenarioSetHash,
        opaqueHoldoutScenarioSetHash: grant.opaqueHoldoutScenarioSetHash,
        privatePlanHash: grant.privatePlanHash,
        productionManifestHash: artifacts.productionManifestHash,
        privateExecutionSummaryHash: artifacts.privateExecutionSummaryHash,
        privateScorecardHash: artifacts.privateScorecardHash,
        privateGateVerdictHash: artifacts.privateGateVerdictHash,
        privateProjectionHash: artifacts.privateProjectionHash,
        redactedExecutionSummaryHash: artifacts.projection.executionSummaryHash,
        redactedScorecardHash: artifacts.projection.scorecardHash,
        redactedGateVerdictHash: artifacts.projection.gateVerdictHash,
        expectedCellSetHash: artifacts.expectedCellSetHash,
        expectedSlotSetHash: artifacts.expectedSlotSetHash,
        executionBudgetPolicyHash: artifacts.executionBudgetPolicyHash,
        executorReleaseHash: artifacts.executorReleaseHash,
        evaluationBundleHash: artifacts.evaluationBundleHash,
        priceTableHash: artifacts.priceTableHash,
        gatePolicyHash: artifacts.gatePolicyHash,
        auditRootHash: auditReservation.auditRootHash,
        result: artifacts.projection.result,
        runnerReleaseHash: runnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
        keyId: signer.keyId,
        nonce: nonce,
        issuedAtMs: issuedAtMs,
        expiresAtMs: issuedAtMs + const Duration(minutes: 5).inMilliseconds,
        signatureBase64: 'unsigned',
      );
      final response = AgentEvaluationPrivateProductionProcessResponse(
        attestation: await signer.signProduction(unsigned),
        projection: artifacts.projection,
      );
      vault.complete(
        accessId: grant.accessId,
        reservation: auditReservation,
        response: response,
        completedAtMs: _clock(),
      );
      return response;
    } finally {
      vault.dispose();
    }
  }

  AgentEvaluationPrivateProductionPlan _loadBoundPlan(
    AgentEvaluationPrivateProductionGrant grant,
  ) {
    final planFile = _regularFile(
      privatePlanPath,
      label: 'private production plan',
      requirePrivateMode: true,
    );
    if (planFile.lengthSync() > 8 * 1024 * 1024) {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'private production plan is invalid',
      );
    }
    final plan = AgentEvaluationPrivateProductionPlan.fromCanonicalJson(
      planFile.readAsStringSync(),
    );
    if (plan.planHash != grant.privatePlanHash ||
        plan.opaqueHoldoutScenarioSetHash !=
            grant.opaqueHoldoutScenarioSetHash) {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'private production plan is not authority-bound',
      );
    }
    return plan;
  }
}

final class _PrivateProductionAuditVault {
  _PrivateProductionAuditVault._(this._db);

  factory _PrivateProductionAuditVault.open(String path) {
    final file = File(path).absolute;
    _secureDirectory(file.parent);
    final existingType = FileSystemEntity.typeSync(
      file.path,
      followLinks: false,
    );
    if (existingType != FileSystemEntityType.notFound &&
        existingType != FileSystemEntityType.file) {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'private audit vault is invalid',
      );
    }
    final db = sqlite3.open(file.path);
    db.execute('PRAGMA journal_mode = DELETE');
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('''
      CREATE TABLE IF NOT EXISTS production_holdout_runs (
        access_id TEXT PRIMARY KEY,
        private_plan_hash TEXT NOT NULL,
        runner_release_hash TEXT NOT NULL,
        state TEXT NOT NULL CHECK (state IN ('running', 'completed')),
        audit_ordinal INTEGER,
        previous_event_hash TEXT,
        audit_root_hash TEXT,
        response_json TEXT,
        started_at_ms INTEGER NOT NULL,
        completed_at_ms INTEGER
      )
    ''');
    final runColumns = db
        .select('PRAGMA table_info(production_holdout_runs)')
        .map((row) => row['name'])
        .toSet();
    if (!runColumns.contains('audit_ordinal')) {
      db.execute(
        'ALTER TABLE production_holdout_runs ADD COLUMN audit_ordinal INTEGER',
      );
    }
    if (!runColumns.contains('previous_event_hash')) {
      db.execute(
        'ALTER TABLE production_holdout_runs '
        'ADD COLUMN previous_event_hash TEXT',
      );
    }
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS
        uq_production_holdout_plan_runner_probe
      ON production_holdout_runs(private_plan_hash, runner_release_hash)
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS production_holdout_audit_events (
        event_hash TEXT PRIMARY KEY,
        event_ordinal INTEGER NOT NULL UNIQUE,
        access_id TEXT NOT NULL UNIQUE,
        private_plan_hash TEXT NOT NULL,
        production_manifest_hash TEXT NOT NULL,
        private_execution_summary_hash TEXT NOT NULL,
        private_scorecard_hash TEXT NOT NULL,
        private_gate_verdict_hash TEXT NOT NULL,
        result TEXT NOT NULL,
        previous_event_hash TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS production_holdout_refresh_slots (
        refresh_root_hash TEXT PRIMARY KEY,
        access_id TEXT NOT NULL,
        refresh_ordinal INTEGER NOT NULL,
        previous_audit_root_hash TEXT NOT NULL,
        prior_claim_hash TEXT NOT NULL,
        nonce TEXT NOT NULL,
        issued_at_ms INTEGER NOT NULL,
        expires_at_ms INTEGER NOT NULL,
        created_at_ms INTEGER NOT NULL,
        UNIQUE (access_id, refresh_ordinal),
        UNIQUE (access_id, prior_claim_hash)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS production_holdout_response_refreshes (
        refresh_root_hash TEXT PRIMARY KEY,
        access_id TEXT NOT NULL,
        refresh_ordinal INTEGER NOT NULL,
        prior_claim_hash TEXT NOT NULL,
        refreshed_claim_hash TEXT NOT NULL UNIQUE,
        response_json TEXT NOT NULL,
        completed_at_ms INTEGER NOT NULL,
        FOREIGN KEY (refresh_root_hash)
          REFERENCES production_holdout_refresh_slots(refresh_root_hash)
            ON DELETE RESTRICT,
        UNIQUE (access_id, refresh_ordinal)
      )
    ''');
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS production_holdout_runs_no_delete
      BEFORE DELETE ON production_holdout_runs
      BEGIN SELECT RAISE(ABORT, 'production holdout run is permanent'); END
    ''');
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS production_holdout_runs_guard_update
      BEFORE UPDATE ON production_holdout_runs
      WHEN NOT (
        OLD.access_id = NEW.access_id
        AND OLD.private_plan_hash = NEW.private_plan_hash
        AND OLD.runner_release_hash = NEW.runner_release_hash
        AND OLD.started_at_ms = NEW.started_at_ms
        AND (
          (
            OLD.state = 'running' AND NEW.state = 'running'
            AND OLD.audit_ordinal IS NULL AND NEW.audit_ordinal IS NOT NULL
            AND OLD.previous_event_hash IS NULL
            AND OLD.audit_root_hash IS NULL AND NEW.audit_root_hash IS NOT NULL
            AND OLD.response_json IS NULL AND NEW.response_json IS NULL
            AND OLD.completed_at_ms IS NULL AND NEW.completed_at_ms IS NULL
          )
          OR
          (
            OLD.state = 'running' AND NEW.state = 'completed'
            AND OLD.audit_ordinal = NEW.audit_ordinal
            AND OLD.previous_event_hash IS NEW.previous_event_hash
            AND OLD.audit_root_hash = NEW.audit_root_hash
            AND OLD.audit_root_hash IS NOT NULL
            AND OLD.response_json IS NULL AND NEW.response_json IS NOT NULL
            AND OLD.completed_at_ms IS NULL AND NEW.completed_at_ms IS NOT NULL
          )
        )
      )
      BEGIN SELECT RAISE(ABORT, 'production holdout run transition is invalid'); END
    ''');
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS production_holdout_events_no_update
      BEFORE UPDATE ON production_holdout_audit_events
      BEGIN SELECT RAISE(ABORT, 'production holdout audit event is immutable'); END
    ''');
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS production_holdout_events_no_delete
      BEFORE DELETE ON production_holdout_audit_events
      BEGIN SELECT RAISE(ABORT, 'production holdout audit event is permanent'); END
    ''');
    for (final table in <String>[
      'production_holdout_refresh_slots',
      'production_holdout_response_refreshes',
    ]) {
      db.execute('''
        CREATE TRIGGER IF NOT EXISTS ${table}_no_update
        BEFORE UPDATE ON $table
        BEGIN SELECT RAISE(ABORT, 'production holdout refresh is immutable'); END
      ''');
      db.execute('''
        CREATE TRIGGER IF NOT EXISTS ${table}_no_delete
        BEFORE DELETE ON $table
        BEGIN SELECT RAISE(ABORT, 'production holdout refresh is permanent'); END
      ''');
    }
    _chmod(file.path, '600');
    _assertPrivateMode(file, 'private audit vault');
    return _PrivateProductionAuditVault._(db);
  }

  final Database _db;

  AgentEvaluationPrivateProductionProcessResponse? reserveOrRead({
    required String accessId,
    required String privatePlanHash,
    required String runnerReleaseHash,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final rows = _db.select(
        'SELECT * FROM production_holdout_runs WHERE access_id = ?',
        <Object?>[accessId],
      );
      if (rows.isEmpty) {
        _db.execute(
          '''INSERT INTO production_holdout_runs (
               access_id, private_plan_hash, runner_release_hash, state,
               started_at_ms
             ) VALUES (?, ?, ?, 'running', ?)''',
          <Object?>[
            accessId,
            privatePlanHash,
            runnerReleaseHash,
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
        _db.execute('COMMIT');
        return null;
      }
      final row = rows.single;
      if (row['private_plan_hash'] != privatePlanHash ||
          row['runner_release_hash'] != runnerReleaseHash) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production access identity changed',
        );
      }
      if (row['state'] != 'completed' || row['response_json'] is! String) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production access was already probed',
        );
      }
      final mainAudit = _db.select(
        '''SELECT 1 FROM production_holdout_audit_events
           WHERE access_id = ? AND event_hash = ?
             AND private_plan_hash = ?''',
        <Object?>[accessId, row['audit_root_hash'], privatePlanHash],
      );
      if (mainAudit.length != 1) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production completed audit is missing',
        );
      }
      final refreshRows = _db.select(
        '''SELECT r.response_json, r.refreshed_claim_hash,
             s.refresh_root_hash, s.access_id, s.prior_claim_hash,
             s.nonce, s.issued_at_ms, s.expires_at_ms
           FROM production_holdout_response_refreshes r
           JOIN production_holdout_refresh_slots s
             ON s.refresh_root_hash = r.refresh_root_hash
           WHERE r.access_id = ?
           ORDER BY r.refresh_ordinal DESC LIMIT 1''',
        <Object?>[accessId],
      );
      final responseSource = refreshRows.isEmpty
          ? row['response_json'] as String
          : refreshRows.single['response_json'] as String;
      final decoded = jsonDecode(responseSource);
      if (decoded is! Map<String, Object?> ||
          AgentEvaluationHashes.canonicalJson(decoded) != responseSource) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production completion is invalid',
        );
      }
      final response = AgentEvaluationPrivateProductionProcessResponse.fromJson(
        decoded,
      );
      if (refreshRows.isNotEmpty) {
        final refresh = refreshRows.single;
        if (refresh['access_id'] != accessId ||
            refresh['refreshed_claim_hash'] != response.attestation.claimHash ||
            refresh['refresh_root_hash'] !=
                response.attestation.auditRootHash ||
            refresh['nonce'] != response.attestation.nonce ||
            refresh['issued_at_ms'] != response.attestation.issuedAtMs ||
            refresh['expires_at_ms'] != response.attestation.expiresAtMs) {
          throw const AgentEvaluationPrivateHoldoutRunnerException(
            'private production refresh audit is invalid',
          );
        }
      }
      _db.execute('COMMIT');
      return response;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  _PrivateRefreshSlot reserveRefreshSlot({
    required String accessId,
    required String priorClaimHash,
    required int nowMs,
  }) {
    AgentEvaluationHashes.requireDigest(priorClaimHash, 'priorClaimHash');
    _db.execute('BEGIN IMMEDIATE');
    try {
      final run = _db.select(
        '''SELECT audit_root_hash, response_json
           FROM production_holdout_runs
           WHERE access_id = ? AND state = 'completed' ''',
        <Object?>[accessId],
      );
      if (run.length != 1) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production refresh has no completed execution',
        );
      }
      final completed = _db.select(
        '''SELECT r.refreshed_claim_hash, r.response_json,
             s.refresh_root_hash, s.refresh_ordinal
           FROM production_holdout_response_refreshes r
           JOIN production_holdout_refresh_slots s
             ON s.refresh_root_hash = r.refresh_root_hash
           WHERE r.access_id = ?
           ORDER BY r.refresh_ordinal DESC LIMIT 1''',
        <Object?>[accessId],
      );
      final expectedPriorClaim = completed.isEmpty
          ? AgentEvaluationPrivateProductionProcessResponse.fromJson(
              jsonDecode(run.single['response_json']! as String)
                  as Map<String, Object?>,
            ).attestation.claimHash
          : completed.single['refreshed_claim_hash'] as String;
      if (priorClaimHash != expectedPriorClaim) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production refresh does not extend the latest claim',
        );
      }
      final pending = _db.select(
        '''SELECT * FROM production_holdout_refresh_slots s
           WHERE s.access_id = ? AND s.prior_claim_hash = ?
             AND NOT EXISTS (
               SELECT 1 FROM production_holdout_response_refreshes r
               WHERE r.refresh_root_hash = s.refresh_root_hash
             )''',
        <Object?>[accessId, priorClaimHash],
      );
      if (pending.length == 1) {
        final slot = _refreshSlotFromRow(pending.single);
        _db.execute('COMMIT');
        return slot;
      }
      final count =
          _db
                  .select(
                    '''SELECT COUNT(*) AS count
           FROM production_holdout_refresh_slots WHERE access_id = ?''',
                    <Object?>[accessId],
                  )
                  .single['count']!
              as int;
      if (count >= 3) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production response refresh limit is exhausted',
        );
      }
      final ordinal = count + 1;
      final previousAuditRootHash = completed.isEmpty
          ? run.single['audit_root_hash']! as String
          : completed.single['refresh_root_hash']! as String;
      final expiresAtMs = nowMs + const Duration(minutes: 5).inMilliseconds;
      final nonce = AgentEvaluationHashes.domainHash(
        'eval-production-holdout-refresh-nonce-v1',
        <String, Object?>{
          'accessId': accessId,
          'ordinal': ordinal,
          'priorClaimHash': priorClaimHash,
          'issuedAtMs': nowMs,
          'entropy': List<int>.generate(
            32,
            (_) => Random.secure().nextInt(256),
          ),
        },
      );
      final root = AgentEvaluationHashes.domainHash(
        'eval-production-holdout-response-refresh-v1',
        <String, Object?>{
          'accessId': accessId,
          'refreshOrdinal': ordinal,
          'previousAuditRootHash': previousAuditRootHash,
          'priorClaimHash': priorClaimHash,
          'nonce': nonce,
          'issuedAtMs': nowMs,
          'expiresAtMs': expiresAtMs,
        },
      );
      _db.execute(
        '''INSERT INTO production_holdout_refresh_slots (
             refresh_root_hash, access_id, refresh_ordinal,
             previous_audit_root_hash, prior_claim_hash, nonce,
             issued_at_ms, expires_at_ms, created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          root,
          accessId,
          ordinal,
          previousAuditRootHash,
          priorClaimHash,
          nonce,
          nowMs,
          expiresAtMs,
          nowMs,
        ],
      );
      _db.execute('COMMIT');
      return _PrivateRefreshSlot(
        accessId: accessId,
        ordinal: ordinal,
        previousAuditRootHash: previousAuditRootHash,
        priorClaimHash: priorClaimHash,
        refreshRootHash: root,
        nonce: nonce,
        issuedAtMs: nowMs,
        expiresAtMs: expiresAtMs,
      );
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  AgentEvaluationPrivateProductionProcessResponse completeRefresh({
    required _PrivateRefreshSlot slot,
    required String priorClaimHash,
    required AgentEvaluationPrivateProductionProcessResponse response,
    required int completedAtMs,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final existing = _db.select(
        '''SELECT response_json FROM production_holdout_response_refreshes
           WHERE refresh_root_hash = ?''',
        <Object?>[slot.refreshRootHash],
      );
      if (existing.length == 1) {
        final decoded = jsonDecode(existing.single['response_json']! as String);
        if (decoded is! Map<String, Object?>) {
          throw const AgentEvaluationPrivateHoldoutRunnerException(
            'private production refresh completion is invalid',
          );
        }
        final stored = AgentEvaluationPrivateProductionProcessResponse.fromJson(
          decoded,
        );
        _db.execute('COMMIT');
        return stored;
      }
      final reserved = _db.select(
        '''SELECT * FROM production_holdout_refresh_slots
           WHERE refresh_root_hash = ? AND access_id = ?''',
        <Object?>[slot.refreshRootHash, slot.accessId],
      );
      final attestation = response.attestation;
      if (reserved.length != 1 ||
          reserved.single['refresh_ordinal'] != slot.ordinal ||
          reserved.single['previous_audit_root_hash'] !=
              slot.previousAuditRootHash ||
          reserved.single['prior_claim_hash'] != priorClaimHash ||
          reserved.single['nonce'] != attestation.nonce ||
          reserved.single['issued_at_ms'] != attestation.issuedAtMs ||
          reserved.single['expires_at_ms'] != attestation.expiresAtMs ||
          attestation.auditRootHash != slot.refreshRootHash ||
          attestation.accessId != slot.accessId) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production refresh does not match its reserved audit slot',
        );
      }
      _db.execute(
        '''INSERT INTO production_holdout_response_refreshes (
             refresh_root_hash, access_id, refresh_ordinal,
             prior_claim_hash, refreshed_claim_hash, response_json,
             completed_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          slot.refreshRootHash,
          slot.accessId,
          slot.ordinal,
          priorClaimHash,
          attestation.claimHash,
          response.canonicalJson,
          completedAtMs,
        ],
      );
      _db.execute('COMMIT');
      return response;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  _PrivateAuditReservation reserveAuditEvent({
    required String accessId,
    required String privatePlanHash,
    required String productionManifestHash,
    required String privateExecutionSummaryHash,
    required String privateScorecardHash,
    required String privateGateVerdictHash,
    required String result,
    required int createdAtMs,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final run = _db.select(
        '''SELECT * FROM production_holdout_runs
           WHERE access_id = ? AND state = 'running'
             AND audit_ordinal IS NULL AND audit_root_hash IS NULL''',
        <Object?>[accessId],
      );
      if (run.length != 1 ||
          run.single['private_plan_hash'] != privatePlanHash) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production audit reservation is invalid',
        );
      }
      final previous = _db.select('''SELECT event_hash, event_ordinal
           FROM production_holdout_audit_events
           ORDER BY event_ordinal DESC LIMIT 1''');
      final ordinal = previous.isEmpty
          ? 0
          : (previous.single['event_ordinal'] as int) + 1;
      final previousHash = previous.isEmpty
          ? null
          : previous.single['event_hash'] as String;
      final auditRootHash = AgentEvaluationHashes.domainHash(
        'eval-production-holdout-private-audit-event-v1',
        <String, Object?>{
          'ordinal': ordinal,
          'accessId': accessId,
          'privatePlanHash': privatePlanHash,
          'productionManifestHash': productionManifestHash,
          'privateExecutionSummaryHash': privateExecutionSummaryHash,
          'privateScorecardHash': privateScorecardHash,
          'privateGateVerdictHash': privateGateVerdictHash,
          'result': result,
          'previousEventHash': previousHash,
          'createdAtMs': createdAtMs,
        },
      );
      _db.execute(
        '''INSERT INTO production_holdout_audit_events (
             event_hash, event_ordinal, access_id, private_plan_hash,
             production_manifest_hash, private_execution_summary_hash,
             private_scorecard_hash, private_gate_verdict_hash, result,
             previous_event_hash, created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          auditRootHash,
          ordinal,
          accessId,
          privatePlanHash,
          productionManifestHash,
          privateExecutionSummaryHash,
          privateScorecardHash,
          privateGateVerdictHash,
          result,
          previousHash,
          createdAtMs,
        ],
      );
      _db.execute(
        '''UPDATE production_holdout_runs
           SET audit_ordinal = ?, previous_event_hash = ?, audit_root_hash = ?
           WHERE access_id = ? AND state = 'running'
             AND audit_ordinal IS NULL AND audit_root_hash IS NULL''',
        <Object?>[ordinal, previousHash, auditRootHash, accessId],
      );
      if (_db.updatedRows != 1) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production audit reservation raced',
        );
      }
      _db.execute('COMMIT');
      return _PrivateAuditReservation(
        ordinal: ordinal,
        previousEventHash: previousHash,
        auditRootHash: auditRootHash,
      );
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void complete({
    required String accessId,
    required _PrivateAuditReservation reservation,
    required AgentEvaluationPrivateProductionProcessResponse response,
    required int completedAtMs,
  }) {
    final attestation = response.attestation;
    _db.execute('BEGIN IMMEDIATE');
    try {
      final reserved = _db.select(
        '''SELECT r.audit_ordinal, r.previous_event_hash, r.audit_root_hash,
             e.private_plan_hash, e.production_manifest_hash,
             e.private_execution_summary_hash, e.private_scorecard_hash,
             e.private_gate_verdict_hash, e.result
           FROM production_holdout_runs r
           JOIN production_holdout_audit_events e
             ON e.access_id = r.access_id AND e.event_hash = r.audit_root_hash
           WHERE r.access_id = ? AND r.state = 'running' ''',
        <Object?>[accessId],
      );
      if (reserved.length != 1 ||
          reserved.single['audit_ordinal'] != reservation.ordinal ||
          reserved.single['previous_event_hash'] !=
              reservation.previousEventHash ||
          reserved.single['audit_root_hash'] != reservation.auditRootHash ||
          reserved.single['private_plan_hash'] != attestation.privatePlanHash ||
          reserved.single['production_manifest_hash'] !=
              attestation.productionManifestHash ||
          reserved.single['private_execution_summary_hash'] !=
              attestation.privateExecutionSummaryHash ||
          reserved.single['private_scorecard_hash'] !=
              attestation.privateScorecardHash ||
          reserved.single['private_gate_verdict_hash'] !=
              attestation.privateGateVerdictHash ||
          reserved.single['result'] != attestation.result ||
          attestation.auditRootHash != reservation.auditRootHash) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production audit reservation changed before completion',
        );
      }
      _db.execute(
        '''UPDATE production_holdout_runs
           SET state = 'completed', response_json = ?, completed_at_ms = ?
           WHERE access_id = ? AND state = 'running' AND response_json IS NULL''',
        <Object?>[response.canonicalJson, completedAtMs, accessId],
      );
      if (_db.updatedRows != 1) {
        throw const AgentEvaluationPrivateHoldoutRunnerException(
          'private production completion raced',
        );
      }
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void dispose() => _db.dispose();
}

final class _PrivateAuditReservation {
  const _PrivateAuditReservation({
    required this.ordinal,
    required this.previousEventHash,
    required this.auditRootHash,
  });

  final int ordinal;
  final String? previousEventHash;
  final String auditRootHash;
}

final class _PrivateRefreshSlot {
  const _PrivateRefreshSlot({
    required this.accessId,
    required this.ordinal,
    required this.previousAuditRootHash,
    required this.priorClaimHash,
    required this.refreshRootHash,
    required this.nonce,
    required this.issuedAtMs,
    required this.expiresAtMs,
  });

  final String accessId;
  final int ordinal;
  final String previousAuditRootHash;
  final String priorClaimHash;
  final String refreshRootHash;
  final String nonce;
  final int issuedAtMs;
  final int expiresAtMs;
}

_PrivateRefreshSlot _refreshSlotFromRow(Row row) => _PrivateRefreshSlot(
  accessId: row['access_id']! as String,
  ordinal: row['refresh_ordinal']! as int,
  previousAuditRootHash: row['previous_audit_root_hash']! as String,
  priorClaimHash: row['prior_claim_hash']! as String,
  refreshRootHash: row['refresh_root_hash']! as String,
  nonce: row['nonce']! as String,
  issuedAtMs: row['issued_at_ms']! as int,
  expiresAtMs: row['expires_at_ms']! as int,
);

int _systemNowMs() => DateTime.now().millisecondsSinceEpoch;

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
    throw const FormatException('invalid private scenario release');
  }
  String string(String key) {
    final item = value[key];
    if (item is! String || item.trim().isEmpty) {
      throw const FormatException('invalid private scenario release');
    }
    return item;
  }

  Map<String, Object?> map(String key) {
    final item = value[key];
    if (item is! Map<String, Object?>) {
      throw const FormatException('invalid private scenario release');
    }
    return item;
  }

  List<String> strings(String key) {
    final item = value[key];
    if (item is! List<Object?> || item.any((entry) => entry is! String)) {
      throw const FormatException('invalid private scenario release');
    }
    return item.cast<String>();
  }

  final fixtureHash = string('fixtureHash');
  AgentEvaluationHashes.requireDigest(fixtureHash, 'fixtureHash');
  final episodeId = value['episodeId'];
  final episodeStep = value['episodeStep'];
  if (episodeId != null && episodeId is! String ||
      episodeStep != null && episodeStep is! int ||
      value['acceptExpected'] is! bool) {
    throw const FormatException('invalid private scenario release');
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
    episodeId: episodeId as String?,
    episodeStep: episodeStep as int?,
  );
}

AgentEvaluationPrivateProductionArtifacts _derivePrivateArtifacts(
  Database db, {
  required AgentEvaluationRealReleasePartitionResult partition,
  required String executionId,
  required AgentEvaluationPrivateProductionGrant grant,
}) {
  final rows = db.select(
    '''SELECT x.expected_cell_set_hash, x.expected_slot_set_hash,
         e.manifest_json, e.evaluation_bundle_hash,
         s.input_set_hash, v.verdict_kind, v.status AS verdict_status,
         d.projection_hash
       FROM eval_executions x
       JOIN eval_experiments e ON e.experiment_id = x.experiment_id
       JOIN eval_scorecards s ON s.scorecard_hash = ?
       JOIN eval_release_gate_verdicts v ON v.verdict_hash = ?
       JOIN eval_release_gate_derivations d ON d.verdict_hash = v.verdict_hash
       WHERE x.execution_id = ? AND s.execution_id = x.execution_id
         AND v.execution_id = x.execution_id''',
    <Object?>[
      partition.scorecardHash,
      partition.regressionVerdictHash,
      executionId,
    ],
  );
  if (rows.length != 1) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private DB authority projection is incomplete',
    );
  }
  final row = rows.single;
  final manifestSource = row['manifest_json'];
  if (manifestSource is! String) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private DB manifest is invalid',
    );
  }
  final manifest = jsonDecode(manifestSource);
  if (manifest is! Map<String, Object?> ||
      AgentEvaluationHashes.canonicalJson(manifest) != manifestSource ||
      manifest['budgets'] is! Map<String, Object?> ||
      manifest['priceTableHash'] is! String) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private DB manifest is invalid',
    );
  }
  validateAgentEvaluationPrivateManifestArmBinding(
    manifest: manifest,
    expectedManifestHash: partition.manifestHash,
    grant: grant,
  );
  final budgets = manifest['budgets']! as Map<String, Object?>;
  final budgetPolicyHash = budgets['executionBudgetPolicyHash'];
  final releaseConfigurationHash = budgets['releaseConfigurationHash'];
  final expectedCellSetHash = row['expected_cell_set_hash'];
  final expectedSlotSetHash = row['expected_slot_set_hash'];
  final inputSetHash = row['input_set_hash'];
  final projectionHash = row['projection_hash'];
  final evaluationBundleHash = row['evaluation_bundle_hash'];
  final priceTableHash = manifest['priceTableHash'];
  final verdictKind = row['verdict_kind'];
  final verdictStatus = row['verdict_status'];
  if (budgetPolicyHash is! String ||
      releaseConfigurationHash is! String ||
      expectedCellSetHash is! String ||
      expectedSlotSetHash is! String ||
      inputSetHash is! String ||
      projectionHash is! String ||
      evaluationBundleHash is! String ||
      priceTableHash is! String ||
      verdictKind != 'holdout' ||
      verdictStatus is! String ||
      !<String>{
        'promote',
        'reject',
        'insufficientEvidence',
      }.contains(verdictStatus)) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private DB authority projection is invalid',
    );
  }
  final projection = AgentEvaluationProductionHoldoutProjection(
    executionSummary: <String, Object?>{
      'schemaVersion': 'production-holdout-redacted-execution-summary-v1',
      'status': 'completed',
      'releaseConfigurationHash': releaseConfigurationHash,
      'executionCommitmentHash': partition.publicReportHash,
      'expectedSlotCount': partition.slotCount,
      'completedSlotCount': partition.slotCount,
    },
    scorecard: <String, Object?>{
      'schemaVersion': 'production-holdout-redacted-scorecard-v1',
      'inputSetHash': inputSetHash,
      'expectedCellSetHash': expectedCellSetHash,
      'expectedSlotSetHash': expectedSlotSetHash,
      'aggregateCommitmentHash': partition.scorecardHash,
    },
    gateVerdict: <String, Object?>{
      'schemaVersion': 'production-holdout-redacted-gate-v1',
      'status': verdictStatus,
      'scorecardHash': partition.scorecardHash,
      'projectionHash': projectionHash,
      'policyHash': AgentEvaluationStandardGatePolicy.policyHash,
      'reasonCodes': <String>[
        switch (verdictStatus) {
          'promote' => 'all-gates-pass',
          'reject' => 'gate-rejected',
          _ => 'insufficient-evidence',
        },
      ],
    },
  );
  return AgentEvaluationPrivateProductionArtifacts(
    productionManifestHash: partition.manifestHash,
    privateExecutionSummaryHash: partition.publicReportHash,
    privateScorecardHash: partition.scorecardHash,
    privateGateVerdictHash: partition.regressionVerdictHash,
    privateProjectionHash: projectionHash,
    expectedCellSetHash: expectedCellSetHash,
    expectedSlotSetHash: expectedSlotSetHash,
    executionBudgetPolicyHash: budgetPolicyHash,
    executorReleaseHash: AgentEvaluationProductionExecutorPolicy.releaseHash,
    evaluationBundleHash: evaluationBundleHash,
    priceTableHash: priceTableHash,
    gatePolicyHash: AgentEvaluationStandardGatePolicy.policyHash,
    projection: projection,
  );
}

void validateAgentEvaluationPrivateManifestArmBinding({
  required Map<String, Object?> manifest,
  required String expectedManifestHash,
  required AgentEvaluationPrivateProductionGrant grant,
}) {
  final manifestHash = AgentEvaluationHashes.domainHash(
    'eval-experiment-manifest-v1',
    manifest,
  );
  final bundleValues = manifest['generationBundleHashes'];
  final expected = <Object?>{
    grant.championBundleHash,
    grant.challengerBundleHash,
  };
  if (manifestHash != expectedManifestHash ||
      bundleValues is! List<Object?> ||
      bundleValues.length != 2 ||
      bundleValues.any((value) => value is! String) ||
      bundleValues.toSet().length != 2 ||
      bundleValues.toSet().difference(expected).isNotEmpty ||
      expected.difference(bundleValues.toSet()).isNotEmpty) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private DB manifest does not bind the spent champion/challenger arms',
    );
  }
}

/// Logical SQLite commitment used by private-plan authoring. It commits the
/// canonical schema plus every table row, so WAL placement and page layout do
/// not affect the digest.
String agentEvaluationCanonicalSqliteAuditRoot(String databasePath) {
  final file = _regularFile(
    databasePath,
    label: 'private fixture database',
    requirePrivateMode: true,
  );
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    db.execute('PRAGMA query_only = ON');
    db.execute('BEGIN');
    try {
      final root = _canonicalSqliteAuditRoot(db);
      db.execute('COMMIT');
      return root;
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  } finally {
    db.dispose();
  }
}

Future<File> _openVerifiedFixtureSnapshot({
  required File sourceFile,
  required String expectedAuditRootHash,
  required Directory privateWorkDirectory,
}) async {
  final snapshot = File('${privateWorkDirectory.path}/fixture-snapshot.sqlite');
  if (FileSystemEntity.typeSync(snapshot.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private fixture snapshot already exists',
    );
  }
  final source = sqlite3.open(sourceFile.path, mode: OpenMode.readOnly);
  Database? destination;
  try {
    source.execute('PRAGMA query_only = ON');
    source.execute('BEGIN');
    final sourceAuditRoot = _canonicalSqliteAuditRoot(source);
    if (sourceAuditRoot != expectedAuditRootHash) {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'private fixture database commitment changed',
      );
    }
    destination = sqlite3.open(snapshot.path);
    await source.backup(destination, nPage: -1).drain<void>();
    source.execute('COMMIT');
    destination.execute('PRAGMA query_only = ON');
    final snapshotAuditRoot = _canonicalSqliteAuditRoot(destination);
    if (snapshotAuditRoot != sourceAuditRoot) {
      throw const AgentEvaluationPrivateHoldoutRunnerException(
        'private fixture stable snapshot is invalid',
      );
    }
    destination.dispose();
    destination = null;
    _chmod(snapshot.path, '600');
    _assertPrivateMode(snapshot, 'private fixture snapshot');
    return snapshot;
  } on Object {
    try {
      source.execute('ROLLBACK');
    } on Object {
      // Preserve the original fail-closed error.
    }
    destination?.dispose();
    if (snapshot.existsSync()) snapshot.deleteSync();
    rethrow;
  } finally {
    source.dispose();
  }
}

String _canonicalSqliteAuditRoot(Database db) {
  final integrity = db.select('PRAGMA quick_check');
  if (integrity.length != 1 || integrity.single.values.single != 'ok') {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private fixture database integrity check failed',
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
  final tables = schemaRows
      .where((row) => row['type'] == 'table')
      .map((row) => row['name']! as String)
      .toList(growable: false);
  final contents = <Object?>[];
  for (final table in tables) {
    final quoted = '"${table.replaceAll('"', '""')}"';
    final columns = db
        .select('PRAGMA table_info($quoted)')
        .map((row) => row['name']! as String)
        .toList(growable: false);
    final rows = <String>[];
    for (final row in db.select('SELECT * FROM $quoted')) {
      rows.add(
        AgentEvaluationHashes.canonicalJson(<Object?>[
          for (final column in columns) _canonicalSqliteValue(row[column]),
        ]),
      );
    }
    rows.sort();
    contents.add(<String, Object?>{
      'table': table,
      'columns': columns,
      'rows': rows,
    });
  }
  return AgentEvaluationHashes.domainHash(
    'eval-private-sqlite-canonical-audit-root-v1',
    <String, Object?>{'schema': schema, 'contents': contents},
  );
}

Object? _canonicalSqliteValue(Object? value) {
  if (value == null || value is String || value is int || value is double) {
    return value;
  }
  if (value is List<int>) {
    return <String, Object?>{'blobBase64': base64Encode(value)};
  }
  throw const AgentEvaluationPrivateHoldoutRunnerException(
    'private fixture contains an unsupported SQLite value',
  );
}

void _restrictPrivateTree(Directory root) {
  if (!root.existsSync()) return;
  _chmod(root.path, '700');
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      _chmod(entity.path, '700');
    } else if (type == FileSystemEntityType.file) {
      _chmod(entity.path, '600');
    }
  }
}

File _regularFile(
  String path, {
  required String label,
  required bool requirePrivateMode,
}) {
  final file = File(path).absolute;
  if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw AgentEvaluationPrivateHoldoutRunnerException(
      '$label must be a regular file',
    );
  }
  if (requirePrivateMode) _assertPrivateMode(file, label);
  return file;
}

void _secureDirectory(Directory directory) {
  final absolute = directory.absolute;
  final type = FileSystemEntity.typeSync(absolute.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    absolute.createSync(recursive: true);
  } else if (type != FileSystemEntityType.directory) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private work directory is invalid',
    );
  }
  _chmod(absolute.path, '700');
  if (!Platform.isWindows && (absolute.statSync().mode & 0x3f) != 0) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private work directory must have mode 0700',
    );
  }
}

void _assertPrivateMode(File file, String label) {
  if (!Platform.isWindows && (file.statSync().mode & 0x3f) != 0) {
    throw AgentEvaluationPrivateHoldoutRunnerException(
      '$label must have mode 0600',
    );
  }
}

void _chmod(String path, String mode) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>[mode, path]);
  if (result.exitCode != 0) {
    throw const AgentEvaluationPrivateHoldoutRunnerException(
      'private ACL could not be restricted',
    );
  }
}
