import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_holdout_store.dart';
import 'agent_evaluation_holdout_reuse_authority.dart';
import 'agent_evaluation_external_custody_trust_store.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_private_holdout.dart';
import 'agent_evaluation_private_holdout_runner.dart';
import 'agent_evaluation_real_release_harness.dart';
import 'agent_evaluation_release_store.dart';
import 'agent_evaluation_spec_evidence.dart';
import 'agent_evaluation_trusted_holdout.dart';

abstract final class AgentEvaluationReleaseCoordinatorPolicy {
  static const maxPrivateResponseBytes = 512 * 1024;
  static const maxPrivateStderrBytes = 4096;
  static const accessBudget = 1;
  static const alphaBudgetMicros = 50000;
  static const alphaCostMicros = 50000;

  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-release-coordinator-v1',
    <String, Object?>{
      'public': 'frozen-route-set-partition-aggregate-db-regression-v2',
      'private': 'separate-process-production-attestation-v2',
      'promotion': 'verified-production-claim-cas-v1',
      'rollback': 'verified-predecessor-cas-v1',
      'report':
          'audit-verifiable-secret-free-db-derived-v6-schema-bound-routes',
      'budget': 'sealed-combined-public-private-journal-v1',
      'pricing': 'compile-time-trust-price-table-and-free-route-policy-v1',
      'criteriaRegistryContractHash':
          AgentEvaluationSpecCriteriaRegistry.contractHash,
      'custody': 'external-attestation-required-for-release-v1',
      'accessBudget': accessBudget,
      'alphaBudgetMicros': alphaBudgetMicros,
      'alphaCostMicros': alphaCostMicros,
    },
  );
}

enum AgentEvaluationCoordinatorPurposeFault {
  afterPrivateComplete,
  afterImport,
  afterReportBeforeSeal,
}

class AgentEvaluationReleaseCoordinatorException implements Exception {
  const AgentEvaluationReleaseCoordinatorException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationReleaseCoordinatorException: $message';
}

final class AgentEvaluationPrivateRunnerCommand {
  AgentEvaluationPrivateRunnerCommand({
    required this.executablePath,
    required this.entrypointPath,
    Iterable<String> fixedArguments = const <String>[],
  }) : fixedArguments = List<String>.unmodifiable(fixedArguments) {
    final executable = File(executablePath).absolute;
    final entrypoint = File(entrypointPath).absolute;
    if (!executable.isAbsolute ||
        !entrypoint.isAbsolute ||
        FileSystemEntity.typeSync(executable.path, followLinks: false) !=
            FileSystemEntityType.file ||
        FileSystemEntity.typeSync(entrypoint.path, followLinks: false) !=
            FileSystemEntityType.file ||
        this.fixedArguments.any(
          (value) =>
              value.isEmpty ||
              value.length > 64 ||
              !RegExp(r'^[A-Za-z0-9_.=-]+$').hasMatch(value),
        )) {
      throw ArgumentError('private runner command is not a frozen executable');
    }
  }

  final String executablePath;
  final String entrypointPath;
  final List<String> fixedArguments;

  String get identityHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-private-runner-command-v1',
    <String, Object?>{
      'executableHash': _fileHash(File(executablePath)),
      'entrypointHash': _fileHash(File(entrypointPath)),
      'fixedArguments': fixedArguments,
    },
  );
}

final class AgentEvaluationPrivateReleaseCommitment {
  AgentEvaluationPrivateReleaseCommitment({
    required this.privatePlanHash,
    required this.opaqueScenarioSetHash,
    required this.keyId,
    required this.publicKey,
    required this.privatePlanPath,
    required this.vaultPath,
    required this.seedFilePath,
  }) : externalSigningCapability = null {
    for (final digest in <String>[privatePlanHash, opaqueScenarioSetHash]) {
      AgentEvaluationHashes.requireDigest(digest, 'privateReleaseCommitment');
    }
    if (keyId.trim().isEmpty ||
        publicKey.type != KeyPairType.ed25519 ||
        publicKey.bytes.length != 32) {
      throw ArgumentError('private release public trust root is invalid');
    }
    // Deliberately do not open private inputs here. The trusted child owns
    // their ACL/symlink/hash checks after the public access is spent.
    for (final path in <String>[privatePlanPath!, vaultPath!, seedFilePath!]) {
      if (!File(path).isAbsolute || path.trim().isEmpty) {
        throw ArgumentError('private child path must be absolute');
      }
    }
  }

  factory AgentEvaluationPrivateReleaseCommitment.externalSigner({
    required String privatePlanHash,
    required String opaqueScenarioSetHash,
    required String keyId,
    required SimplePublicKey publicKey,
    required AgentEvaluationExternalReleaseSigningCapability
    externalSigningCapability,
  }) => AgentEvaluationPrivateReleaseCommitment._externalSigner(
    privatePlanHash: privatePlanHash,
    opaqueScenarioSetHash: opaqueScenarioSetHash,
    keyId: keyId,
    publicKey: publicKey,
    externalSigningCapability: externalSigningCapability,
  );

  AgentEvaluationPrivateReleaseCommitment._externalSigner({
    required this.privatePlanHash,
    required this.opaqueScenarioSetHash,
    required this.keyId,
    required this.publicKey,
    required this.externalSigningCapability,
  }) : privatePlanPath = null,
       vaultPath = null,
       seedFilePath = null {
    final capability = externalSigningCapability!;
    for (final digest in <String>[privatePlanHash, opaqueScenarioSetHash]) {
      AgentEvaluationHashes.requireDigest(digest, 'privateReleaseCommitment');
    }
    if (keyId.trim().isEmpty ||
        keyId != capability.keyId ||
        publicKey.type != KeyPairType.ed25519 ||
        publicKey.bytes.length != 32 ||
        base64Encode(publicKey.bytes) !=
            base64Encode(capability.publicKey.bytes)) {
      throw ArgumentError('external release signing authority is invalid');
    }
  }

  final String privatePlanHash;
  final String opaqueScenarioSetHash;
  final String keyId;
  final SimplePublicKey publicKey;
  final String? privatePlanPath;
  final String? vaultPath;
  final String? seedFilePath;
  final AgentEvaluationExternalReleaseSigningCapability?
  externalSigningCapability;

  bool get usesExternalSigner => externalSigningCapability != null;
}

typedef AgentEvaluationPrivateRunnerBroker =
    Future<String> Function({
      required String authorityDatabasePath,
      required String accessId,
    });

typedef AgentEvaluationCombinedBudgetEvidenceReader =
    Map<String, Object?> Function();

final class AgentEvaluationExternalReleaseSigningCapability {
  AgentEvaluationExternalReleaseSigningCapability({
    required this.keyId,
    required this.publicKey,
    required this.signerCommandIdentityHash,
    required this.custodyAttestationPayloadJson,
    required this.custodyAttestationSignatureBase64,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_.:-]{1,128}$').hasMatch(keyId) ||
        publicKey.type != KeyPairType.ed25519 ||
        publicKey.bytes.length != 32 ||
        custodyAttestationPayloadJson.trim().isEmpty ||
        custodyAttestationSignatureBase64.trim().isEmpty) {
      throw ArgumentError('external release signing capability is invalid');
    }
    AgentEvaluationHashes.requireDigest(
      signerCommandIdentityHash,
      'signerCommandIdentityHash',
    );
  }

  final String keyId;
  final SimplePublicKey publicKey;
  final String signerCommandIdentityHash;
  final String custodyAttestationPayloadJson;
  final String custodyAttestationSignatureBase64;
}

final class AgentEvaluationReleaseCoordinatorResult {
  const AgentEvaluationReleaseCoordinatorResult({
    required this.releaseEligible,
    required this.realProviderEvidence,
    required this.regressionVerdictHash,
    required this.productionHoldoutClaimHash,
    required this.promotionDecisionId,
    required this.rollbackDecisionId,
    required this.finalChannelEpoch,
    required this.reportPath,
    required this.reportHash,
  });

  final bool releaseEligible;
  final bool realProviderEvidence;
  final String regressionVerdictHash;
  final String productionHoldoutClaimHash;
  final String promotionDecisionId;
  final String rollbackDecisionId;
  final int finalChannelEpoch;
  final String reportPath;
  final String reportHash;
}

final class AgentEvaluationReleaseCoordinator {
  factory AgentEvaluationReleaseCoordinator.production({
    required String coordinatorRunId,
    required AgentEvaluationRealReleaseResult publicResult,
    required AgentEvaluationPrivateReleaseCommitment privateCommitment,
    required Directory workDirectory,
    required Directory reportDirectory,
    required String channel,
    required String approver,
    required Duration processTimeout,
    required AgentEvaluationPrivateRunnerBroker privateRunnerBroker,
    required AgentEvaluationVerifiedProductionCustodyToken custodyToken,
    required AgentEvaluationCombinedBudgetEvidenceReader
    combinedBudgetEvidenceReader,
    required AgentEvaluationSpecCriteriaRegistrySeal baselineCriteriaSeal,
    required Iterable<String> requiredModelRouteHashes,
  }) => AgentEvaluationReleaseCoordinator._(
    coordinatorRunId: coordinatorRunId,
    publicResult: publicResult,
    privateCommitment: privateCommitment,
    privateRunnerCommand: _fixedProductionRunnerCommand(),
    workDirectory: workDirectory,
    reportDirectory: reportDirectory,
    channel: channel,
    approver: approver,
    processTimeout: processTimeout,
    privateRunnerReleaseHash:
        AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
    productionMode: true,
    privateRunnerBroker: privateRunnerBroker,
    custodyToken: custodyToken,
    combinedBudgetEvidenceReader: combinedBudgetEvidenceReader,
    baselineCriteriaSeal: baselineCriteriaSeal,
    requiredModelRouteHashes: requiredModelRouteHashes,
  );

  factory AgentEvaluationReleaseCoordinator.purposeBuilt({
    required String coordinatorRunId,
    required AgentEvaluationRealReleaseResult publicResult,
    required AgentEvaluationPrivateReleaseCommitment privateCommitment,
    required AgentEvaluationPrivateRunnerCommand privateRunnerCommand,
    required Directory workDirectory,
    required Directory reportDirectory,
    required String channel,
    required String approver,
    required Duration processTimeout,
    required Iterable<String> requiredModelRouteHashes,
    AgentEvaluationCoordinatorPurposeFault? injectedFault,
  }) => AgentEvaluationReleaseCoordinator._(
    coordinatorRunId: coordinatorRunId,
    publicResult: publicResult,
    privateCommitment: privateCommitment,
    privateRunnerCommand: privateRunnerCommand,
    workDirectory: workDirectory,
    reportDirectory: reportDirectory,
    channel: channel,
    approver: approver,
    processTimeout: processTimeout,
    privateRunnerReleaseHash:
        agentEvaluationPurposeBuiltProductionHoldoutRunnerReleaseHash,
    productionMode: false,
    privateRunnerBroker: null,
    custodyToken: null,
    combinedBudgetEvidenceReader: null,
    baselineCriteriaSeal: null,
    requiredModelRouteHashes: requiredModelRouteHashes,
    injectedFault: injectedFault,
  );

  AgentEvaluationReleaseCoordinator._({
    required this.coordinatorRunId,
    required this.publicResult,
    required this.privateCommitment,
    required this.privateRunnerCommand,
    required this.workDirectory,
    required this.reportDirectory,
    required this.channel,
    required this.approver,
    required this.processTimeout,
    required this.privateRunnerReleaseHash,
    required bool productionMode,
    required AgentEvaluationPrivateRunnerBroker? privateRunnerBroker,
    required AgentEvaluationVerifiedProductionCustodyToken? custodyToken,
    required AgentEvaluationCombinedBudgetEvidenceReader?
    combinedBudgetEvidenceReader,
    required AgentEvaluationSpecCriteriaRegistrySeal? baselineCriteriaSeal,
    required Iterable<String> requiredModelRouteHashes,
    AgentEvaluationCoordinatorPurposeFault? injectedFault,
  }) : _productionMode = productionMode,
       _requiredModelRouteHashes = Set<String>.unmodifiable(
         requiredModelRouteHashes,
       ),
       _custodyToken = custodyToken {
    if (coordinatorRunId.trim().isEmpty ||
        channel.trim().isEmpty ||
        approver.trim().isEmpty ||
        processTimeout <= Duration.zero ||
        publicResult.partitions.isEmpty ||
        _requiredModelRouteHashes.isEmpty ||
        _requiredModelRouteHashes.any(
          (hash) => !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash),
        ) ||
        publicResult.claimScope != 'real-provider-release' ||
        (productionMode
            ? !publicResult.realProviderEvidence
            : publicResult.realProviderEvidence)) {
      throw ArgumentError('release coordinator configuration is incomplete');
    }
    if (productionMode && injectedFault != null) {
      throw ArgumentError('production coordinator cannot inject faults');
    }
    _injectedFault = injectedFault;
    _privateRunnerBroker = privateRunnerBroker;
    _combinedBudgetEvidenceReader = combinedBudgetEvidenceReader;
    _baselineCriteriaSeal = baselineCriteriaSeal;
    if (productionMode && privateRunnerBroker == null) {
      throw ArgumentError('production private runner broker is required');
    }
    if (productionMode && custodyToken == null) {
      throw ArgumentError('production custody token is required');
    }
    if (productionMode && combinedBudgetEvidenceReader == null) {
      throw ArgumentError('production combined budget evidence is required');
    }
    if (productionMode && baselineCriteriaSeal == null) {
      throw ArgumentError('production criteria baseline is required');
    }
  }

  final String coordinatorRunId;
  final AgentEvaluationRealReleaseResult publicResult;
  final AgentEvaluationPrivateReleaseCommitment privateCommitment;
  final AgentEvaluationPrivateRunnerCommand privateRunnerCommand;
  final Directory workDirectory;
  final Directory reportDirectory;
  final String channel;
  final String approver;
  final Duration processTimeout;
  final String privateRunnerReleaseHash;
  final bool _productionMode;
  final Set<String> _requiredModelRouteHashes;
  final AgentEvaluationVerifiedProductionCustodyToken? _custodyToken;
  late final AgentEvaluationPrivateRunnerBroker? _privateRunnerBroker;
  late final AgentEvaluationCombinedBudgetEvidenceReader?
  _combinedBudgetEvidenceReader;
  late final AgentEvaluationSpecCriteriaRegistrySeal? _baselineCriteriaSeal;
  late final AgentEvaluationCoordinatorPurposeFault? _injectedFault;

  var _stage = 'preflight';
  int? _childExitCode;
  String? _effectiveChannel;
  int? _observedChannelEpoch;
  String? _observedChannelBundleHash;

  Future<AgentEvaluationReleaseCoordinatorResult> run() async {
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      return await _run(startedAtMs);
    } on Object {
      _writeFailureReport(startedAtMs);
      rethrow;
    }
  }

  Future<AgentEvaluationReleaseCoordinatorResult> _run(int startedAtMs) async {
    _prepareDirectories();
    final authorityFile = File(publicResult.authorityDatabasePath).absolute;
    final publicReportFile = File(publicResult.reportPath).absolute;
    if (!authorityFile.existsSync() || !publicReportFile.existsSync()) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'public release evidence is missing',
      );
    }
    _stage = 'custody-preflight';
    final custody = await _evidenceCustody();
    final publicReport = _strictJsonObject(publicReportFile.readAsStringSync());
    final declaredPublicReportHash = publicReport['reportHash'];
    final publicPayload = <String, Object?>{...publicReport}
      ..remove('reportHash');
    if (declaredPublicReportHash is! String ||
        declaredPublicReportHash !=
            AgentEvaluationHashes.domainHash(
              'agent-evaluation-real-release-report-v1',
              publicPayload,
            ) ||
        publicReport['schemaVersion'] !=
            'agent-evaluation-real-release-report-v1' ||
        publicReport['realProviderEvidence'] !=
            publicResult.realProviderEvidence ||
        publicReport['claimScope'] != publicResult.claimScope) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'public report contradicts its result object',
      );
    }

    final db = sqlite3.open(authorityFile.path);
    try {
      db.execute('PRAGMA foreign_keys = ON');
      final verifier = AgentEvaluationTrustedHoldoutVerifier(
        keyId: privateCommitment.keyId,
        publicKey: privateCommitment.publicKey,
        runnerReleaseHash: privateRunnerReleaseHash,
        resolverReleaseHash:
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
      );
      final publicAuthority = _readPublicAuthority(
        db,
        publicReport: publicReport,
        holdoutAccessPolicyHash: verifier.trustPolicyHash,
      );
      _preflightPrivateRuntime();
      final productionFamilyAuthorityHash = AgentEvaluationHashes.domainHash(
        'agent-evaluation-production-family-authority-v1',
        <String, Object?>{
          'championBundleHash': publicAuthority.championBundleHash,
          'challengerBundleHash': publicAuthority.challengerBundleHash,
          'regressionVerdictHash': publicAuthority.regressionVerdictHash,
          'regressionVerdictSetHash': publicAuthority.regressionVerdictSetHash,
          'regressionScenarioSetHash':
              publicAuthority.regressionScenarioSetHash,
          'opaqueScenarioSetHash': privateCommitment.opaqueScenarioSetHash,
          'privatePlanHash': privateCommitment.privatePlanHash,
          'holdoutAccessPolicyHash': verifier.trustPolicyHash,
          'maxAccesses': AgentEvaluationReleaseCoordinatorPolicy.accessBudget,
          'alphaBudgetMicros':
              AgentEvaluationReleaseCoordinatorPolicy.alphaBudgetMicros,
        },
      );
      final releaseChannel = _productionMode
          ? 'eval-drill-${productionFamilyAuthorityHash.substring(0, 32)}'
          : channel;
      _effectiveChannel = releaseChannel;
      final ids = _CoordinatorIds.from(
        runId: coordinatorRunId,
        regressionVerdictHash: publicAuthority.regressionVerdictHash,
        productionFamilyAuthorityHash: productionFamilyAuthorityHash,
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final holdout = AgentEvaluationHoldoutStore(
        db: db,
        trustedHoldoutVerifier: verifier,
      );
      _stage = 'spend-private-access';
      holdout.createProductionFamily(
        familyId: ids.familyId,
        productionAuthorityHash: productionFamilyAuthorityHash,
        regressionScenarioSetHash: publicAuthority.regressionScenarioSetHash,
        opaqueHoldoutScenarioSetHash: privateCommitment.opaqueScenarioSetHash,
        privatePlanHash: privateCommitment.privatePlanHash,
        holdoutAccessPolicyHash: verifier.trustPolicyHash,
        maxAccesses: AgentEvaluationReleaseCoordinatorPolicy.accessBudget,
        alphaBudgetMicros:
            AgentEvaluationReleaseCoordinatorPolicy.alphaBudgetMicros,
        createdAtMs: nowMs,
      );
      final challengerRegistrations = db.select(
        '''SELECT 1 FROM eval_family_challengers
           WHERE family_id = ? AND challenger_bundle_hash = ?''',
        <Object?>[ids.familyId, publicAuthority.challengerBundleHash],
      );
      if (challengerRegistrations.isEmpty) {
        holdout.registerChallenger(
          familyId: ids.familyId,
          challengerBundleHash: publicAuthority.challengerBundleHash,
          registeredAtMs: nowMs,
        );
      } else if (challengerRegistrations.length != 1) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'production challenger registration is ambiguous',
        );
      }
      final tokenRows = db.select(
        'SELECT * FROM eval_holdout_tokens WHERE token_id = ?',
        <Object?>[ids.tokenId],
      );
      if (tokenRows.isEmpty) {
        holdout.issueToken(
          tokenId: ids.tokenId,
          familyId: ids.familyId,
          challengerBundleHash: publicAuthority.challengerBundleHash,
          regressionVerdictHash: publicAuthority.regressionVerdictHash,
          alphaCostMicros:
              AgentEvaluationReleaseCoordinatorPolicy.alphaCostMicros,
          issuedAtMs: nowMs,
        );
      } else if (tokenRows.length != 1 ||
          tokenRows.single['family_id'] != ids.familyId ||
          tokenRows.single['challenger_bundle_hash'] !=
              publicAuthority.challengerBundleHash ||
          tokenRows.single['regression_verdict_hash'] !=
              publicAuthority.regressionVerdictHash ||
          tokenRows.single['alpha_cost_micros'] !=
              AgentEvaluationReleaseCoordinatorPolicy.alphaCostMicros ||
          !<String>{'issued', 'consumed'}.contains(tokenRows.single['state'])) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'existing holdout token contradicts frozen authority',
        );
      }
      var accessRows = db.select(
        'SELECT * FROM eval_production_holdout_accesses WHERE access_id = ?',
        <Object?>[ids.accessId],
      );
      if (accessRows.isEmpty) {
        holdout.beginProductionHoldoutAccess(
          accessId: ids.accessId,
          tokenId: ids.tokenId,
          challengerBundleHash: publicAuthority.challengerBundleHash,
        );
        accessRows = db.select(
          'SELECT * FROM eval_production_holdout_accesses WHERE access_id = ?',
          <Object?>[ids.accessId],
        );
      }
      if (accessRows.length != 1 ||
          accessRows.single['token_id'] != ids.tokenId ||
          accessRows.single['family_id'] != ids.familyId ||
          accessRows.single['challenger_bundle_hash'] !=
              publicAuthority.challengerBundleHash ||
          accessRows.single['trusted_runner_release_hash'] !=
              privateRunnerReleaseHash ||
          accessRows.single['alpha_cost_micros'] !=
              AgentEvaluationReleaseCoordinatorPolicy.alphaCostMicros ||
          !<String>{'begun', 'imported'}.contains(accessRows.single['state'])) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'existing production access contradicts frozen authority',
        );
      }
      await _bindPrivateMaterial(
        authorityDatabasePath: authorityFile.path,
        accessId: ids.accessId,
      );

      final existingClaims = db.select(
        'SELECT * FROM eval_production_holdout_claims WHERE access_id = ?',
        <Object?>[ids.accessId],
      );
      late final AgentEvaluationProductionHoldoutClaimRecord claim;
      if (existingClaims.isNotEmpty) {
        if (existingClaims.length != 1) {
          throw const AgentEvaluationReleaseCoordinatorException(
            'existing production claim is ambiguous',
          );
        }
        final row = existingClaims.single;
        final executionSummary = _strictJsonObject(
          row['redacted_execution_summary_json'] as String,
        );
        if (accessRows.single['state'] != 'imported' ||
            row['family_id'] != ids.familyId ||
            row['token_id'] != ids.tokenId ||
            row['regression_verdict_hash'] !=
                publicAuthority.regressionVerdictHash ||
            row['champion_bundle_hash'] != publicAuthority.championBundleHash ||
            row['challenger_bundle_hash'] !=
                publicAuthority.challengerBundleHash ||
            row['private_plan_hash'] != privateCommitment.privatePlanHash ||
            row['price_table_hash'] != publicAuthority.priceTableReleaseHash ||
            row['result'] != 'pass' ||
            executionSummary['releaseConfigurationHash'] !=
                publicAuthority.releaseConfigurationHash) {
          throw const AgentEvaluationReleaseCoordinatorException(
            'existing production claim contradicts frozen authority',
          );
        }
        claim = AgentEvaluationProductionHoldoutClaimRecord(
          claimHash: row['claim_hash'] as String,
          accessId: row['access_id'] as String,
          familyId: row['family_id'] as String,
          result: row['result'] as String,
          importedAtMs: row['imported_at_ms'] as int,
        );
      } else {
        if (accessRows.single['state'] != 'begun') {
          throw const AgentEvaluationReleaseCoordinatorException(
            'imported access is missing its unique production claim',
          );
        }
        _stage = 'private-child';
        await _reverifyExternalCustody(custody);
        final childAuthority = _snapshotAuthority(db, ids.accessId);
        late final _PrivateProcessResult processResponse;
        try {
          processResponse = await _runPrivateChild(
            authorityDatabasePath: childAuthority.path,
            accessId: ids.accessId,
          );
        } finally {
          final childDirectory = childAuthority.parent;
          if (childDirectory.existsSync()) {
            childDirectory.deleteSync(recursive: true);
          }
        }
        late final AgentEvaluationPrivateProductionProcessResponse response;
        try {
          response = AgentEvaluationPrivateProductionProcessResponse.fromJson(
            _strictJsonObject(processResponse.stdoutText),
          );
        } on FormatException {
          throw const AgentEvaluationReleaseCoordinatorException(
            'private child response is not strict production V2 evidence',
          );
        }
        if (response.canonicalJson != processResponse.stdoutText ||
            response.projection.executionSummary['releaseConfigurationHash'] !=
                publicAuthority.releaseConfigurationHash ||
            response.attestation.priceTableHash !=
                publicAuthority.priceTableReleaseHash) {
          throw const AgentEvaluationReleaseCoordinatorException(
            'private child response contradicts frozen release configuration',
          );
        }
        _injectPurposeFault(
          AgentEvaluationCoordinatorPurposeFault.afterPrivateComplete,
        );
        _stage = 'import-v2';
        claim =
            await AgentEvaluationProductionHoldoutImporter(
              db: db,
              verifier: verifier,
            ).import(
              attestation: response.attestation,
              projection: response.projection,
            );
        _injectPurposeFault(AgentEvaluationCoordinatorPurposeFault.afterImport);
      }
      if (claim.result != 'pass') {
        throw const AgentEvaluationReleaseCoordinatorException(
          'private V2 holdout did not pass',
        );
      }

      _stage = 'promote';
      final releaseStore = AgentEvaluationReleaseStore(
        db: db,
        trustedHoldoutVerifier: verifier,
      );
      final existingHeads = db.select(
        'SELECT * FROM prompt_channel_heads WHERE channel = ?',
        <Object?>[releaseChannel],
      );
      if (existingHeads.isEmpty) {
        releaseStore.initializeChannelHead(
          channel: releaseChannel,
          bundleHash: publicAuthority.championBundleHash,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        );
      } else if (existingHeads.length != 1) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'release channel head is ambiguous',
        );
      }
      var head = releaseStore.readChannelHead(releaseChannel);
      _observedChannelEpoch = head.epoch;
      _observedChannelBundleHash = head.bundleHash;
      if (head.epoch == 0 &&
          head.bundleHash == publicAuthority.championBundleHash) {
        _stage = 'promote-rollback-atomic';
        await releaseStore.exercisePromoteThenRollbackVerified(
          promotionDecisionId: ids.promotionDecisionId,
          rollbackDecisionId: ids.rollbackDecisionId,
          channel: releaseChannel,
          expectedBundleHash: publicAuthority.championBundleHash,
          expectedEpoch: 0,
          challengerBundleHash: publicAuthority.challengerBundleHash,
          experimentId: publicAuthority.experimentId,
          regressionVerdictHash: publicAuthority.regressionVerdictHash,
          productionHoldoutClaimHash: claim.claimHash,
          approver: approver,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        head = releaseStore.readChannelHead(releaseChannel);
      }
      final rollbackReadback = releaseStore.readChannelHead(releaseChannel);
      _observedChannelEpoch = rollbackReadback.epoch;
      _observedChannelBundleHash = rollbackReadback.bundleHash;
      final decisions = releaseStore.readDecisions(releaseChannel);
      if (head.bundleHash != publicAuthority.championBundleHash ||
          head.epoch != 2 ||
          rollbackReadback.bundleHash != head.bundleHash ||
          rollbackReadback.epoch != head.epoch ||
          !_hasPromotionAuthorization(
            db,
            decisionId: ids.promotionDecisionId,
            regressionVerdictHash: publicAuthority.regressionVerdictHash,
            claimHash: claim.claimHash,
          ) ||
          decisions.length != 2 ||
          decisions[0].decisionId != ids.promotionDecisionId ||
          decisions[0].action != 'promote' ||
          decisions[0].fromBundleHash != publicAuthority.championBundleHash ||
          decisions[0].toBundleHash != publicAuthority.challengerBundleHash ||
          decisions[0].fromEpoch != 0 ||
          decisions[0].toEpoch != 1 ||
          decisions[1].decisionId != ids.rollbackDecisionId ||
          decisions[1].action != 'rollback' ||
          decisions[1].fromBundleHash != publicAuthority.challengerBundleHash ||
          decisions[1].toBundleHash != publicAuthority.championBundleHash ||
          decisions[1].fromEpoch != 1 ||
          decisions[1].toEpoch != 2) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'verified rollback readback failed',
        );
      }

      _stage = 'report';
      await _reverifyExternalCustody(custody);
      final realProviderEvidence =
          _productionMode && publicResult.realProviderEvidence;
      final retention = AgentEvaluationEvidenceRetentionContract.auditOnly(
        custody: custody,
      );
      final combinedBudgetEvidence = _combinedBudgetEvidenceReader?.call();
      if (realProviderEvidence) {
        if (combinedBudgetEvidence == null) {
          throw const AgentEvaluationReleaseCoordinatorException(
            'combined release budget evidence is missing',
          );
        }
        verifyAgentEvaluationCombinedReleaseBudgetEvidence(
          combinedBudgetEvidence,
        );
      }
      final productionCriteriaArtifact = _productionMode
          ? _writeProductionCriteriaArtifact(
              db: db,
              authority: publicAuthority,
              claim: claim,
              promotionDecisionId: ids.promotionDecisionId,
              rollbackDecisionId: ids.rollbackDecisionId,
              custody: custody,
              retention: retention,
              combinedBudgetEvidence: combinedBudgetEvidence!,
              startedAtMs: startedAtMs,
            )
          : null;
      final criteriaSeal =
          productionCriteriaArtifact?.criteriaSeal ??
          _criteriaRegistrySeal(
            authority: publicAuthority,
            retention: retention,
            startedAtMs: startedAtMs,
          );
      final releasePrerequisitesMet =
          realProviderEvidence &&
          publicAuthority.regressionStatus == 'promote' &&
          claim.result == 'pass' &&
          head.epoch == 2 &&
          _custodyToken != null;
      final releaseEligible = deriveAgentEvaluationCriteriaReleaseEligibility(
        prerequisitesMet: releasePrerequisitesMet,
        criteriaSeal: criteriaSeal,
      );
      final writtenReport = _writeFinalReport(
        db: db,
        startedAtMs: startedAtMs,
        authority: publicAuthority,
        claim: claim,
        promotionDecisionId: ids.promotionDecisionId,
        rollbackDecisionId: ids.rollbackDecisionId,
        realProviderEvidence: realProviderEvidence,
        releaseEligible: releaseEligible,
        custody: custody,
        retention: retention,
        criteriaSeal: criteriaSeal,
        productionCriteriaArtifact: productionCriteriaArtifact,
        combinedBudgetEvidence: combinedBudgetEvidence,
      );
      _injectPurposeFault(
        AgentEvaluationCoordinatorPurposeFault.afterReportBeforeSeal,
      );
      await _reverifyExternalCustody(custody);
      _sealFinalReport(
        db: db,
        report: writtenReport,
        authority: publicAuthority,
        claimHash: claim.claimHash,
        promotionDecisionId: ids.promotionDecisionId,
        rollbackDecisionId: ids.rollbackDecisionId,
      );
      return AgentEvaluationReleaseCoordinatorResult(
        releaseEligible: releaseEligible,
        realProviderEvidence: realProviderEvidence,
        regressionVerdictHash: publicAuthority.regressionVerdictHash,
        productionHoldoutClaimHash: claim.claimHash,
        promotionDecisionId: ids.promotionDecisionId,
        rollbackDecisionId: ids.rollbackDecisionId,
        finalChannelEpoch: head.epoch,
        reportPath: writtenReport.path,
        reportHash: writtenReport.reportHash,
      );
    } finally {
      db.dispose();
    }
  }

  void _injectPurposeFault(AgentEvaluationCoordinatorPurposeFault fault) {
    if (_injectedFault == fault) {
      throw AgentEvaluationReleaseCoordinatorException(
        'purpose-built injected coordinator crash at ${fault.name}',
      );
    }
  }

  Future<void> _bindPrivateMaterial({
    required String authorityDatabasePath,
    required String accessId,
  }) async {
    if (_productionMode) return;
    _stage = 'seal-purpose-private-material';
    _sealPurposeBuiltPrivateMaterial();
  }

  /// Purpose-built/offline runners predate the production material builder:
  /// their authority-bound plan legitimately names an arbitrary private
  /// fixture file. Do not mistake that source directory for a prepared
  /// production material root. Instead, freeze the declared source into a
  /// coordinator-owned canonical root and revalidate both copies immediately
  /// before every child launch.
  void _sealPurposeBuiltPrivateMaterial() {
    final planFile = _purposePrivateFile(
      privateCommitment.privatePlanPath!,
      'private production plan',
    );
    final planSource = planFile.readAsStringSync();
    late final AgentEvaluationPrivateProductionPlan plan;
    try {
      plan = AgentEvaluationPrivateProductionPlan.fromCanonicalJson(planSource);
    } on Object {
      throw const AgentEvaluationReleaseCoordinatorException(
        'purpose-built private plan is invalid',
      );
    }
    if (plan.planHash != privateCommitment.privatePlanHash ||
        plan.opaqueHoldoutScenarioSetHash !=
            privateCommitment.opaqueScenarioSetHash) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'purpose-built private plan is not authority-bound',
      );
    }
    final fixturePath = plan.fixture['databasePath']! as String;
    final fixtureFile = _purposePrivateFile(
      fixturePath,
      'private production fixture',
    );
    if (fixtureFile.parent.path != planFile.parent.path) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'purpose-built private fixture escapes its plan root',
      );
    }
    final declaredAuditRoot = plan.fixture['databaseAuditRootHash']! as String;
    late final String sourceAuditRoot;
    try {
      sourceAuditRoot = agentEvaluationCanonicalSqliteAuditRoot(
        fixtureFile.path,
      );
    } on Object {
      throw const AgentEvaluationReleaseCoordinatorException(
        'purpose-built private fixture cannot be audited',
      );
    }
    if (sourceAuditRoot != declaredAuditRoot) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'purpose-built private fixture changed',
      );
    }

    final materialRoot = Directory(
      '${workDirectory.absolute.path}/purpose-private-material-'
      '${privateCommitment.privatePlanHash.substring(0, 16)}',
    );
    final sealPayload = <String, Object?>{
      'schemaVersion': 'purpose-built-private-material-seal-v1',
      'privatePlanHash': privateCommitment.privatePlanHash,
      'opaqueScenarioSetHash': privateCommitment.opaqueScenarioSetHash,
      'fixtureAuditRootHash': declaredAuditRoot,
      'sourcePlanPathHash': AgentEvaluationHashes.domainHash(
        'agent-evaluation-private-source-path-v1',
        planFile.path,
      ),
      'sourceFixturePathHash': AgentEvaluationHashes.domainHash(
        'agent-evaluation-private-source-path-v1',
        fixtureFile.path,
      ),
    };
    final sealSource = AgentEvaluationHashes.canonicalJson(<String, Object?>{
      ...sealPayload,
      'sealHash': AgentEvaluationHashes.domainHash(
        'agent-evaluation-purpose-private-material-seal-v1',
        sealPayload,
      ),
    });

    void verifyCanonicalRoot() {
      if (FileSystemEntity.typeSync(materialRoot.path, followLinks: false) !=
              FileSystemEntityType.directory ||
          (!Platform.isWindows && (materialRoot.statSync().mode & 0x3f) != 0)) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'purpose-built private material root is invalid',
        );
      }
      final canonicalPlan = _purposePrivateFile(
        '${materialRoot.path}/private-plan.json',
        'canonical private plan',
      );
      final canonicalFixture = _purposePrivateFile(
        '${materialRoot.path}/fixture.sqlite',
        'canonical private fixture',
      );
      final seal = _purposePrivateFile(
        '${materialRoot.path}/seal.json',
        'canonical private material seal',
      );
      if (canonicalPlan.readAsStringSync() != planSource ||
          seal.readAsStringSync() != sealSource ||
          agentEvaluationCanonicalSqliteAuditRoot(canonicalFixture.path) !=
              declaredAuditRoot ||
          agentEvaluationCanonicalSqliteAuditRoot(fixtureFile.path) !=
              declaredAuditRoot) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'purpose-built private material seal changed',
        );
      }
    }

    final rootType = FileSystemEntity.typeSync(
      materialRoot.path,
      followLinks: false,
    );
    if (rootType == FileSystemEntityType.directory) {
      verifyCanonicalRoot();
      return;
    }
    if (rootType != FileSystemEntityType.notFound) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'purpose-built private material root conflicts',
      );
    }
    final staging = Directory(
      '${materialRoot.parent.path}/.${materialRoot.uri.pathSegments.last}'
      '.staging-${DateTime.now().microsecondsSinceEpoch}',
    );
    staging.createSync();
    _chmod(staging.path, '700');
    try {
      fixtureFile.copySync('${staging.path}/fixture.sqlite');
      _chmod('${staging.path}/fixture.sqlite', '600');
      File(
        '${staging.path}/private-plan.json',
      ).writeAsStringSync(planSource, flush: true);
      _chmod('${staging.path}/private-plan.json', '600');
      File(
        '${staging.path}/seal.json',
      ).writeAsStringSync(sealSource, flush: true);
      _chmod('${staging.path}/seal.json', '600');
      if (agentEvaluationCanonicalSqliteAuditRoot(
                '${staging.path}/fixture.sqlite',
              ) !=
              declaredAuditRoot ||
          agentEvaluationCanonicalSqliteAuditRoot(fixtureFile.path) !=
              declaredAuditRoot) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'purpose-built private fixture changed while sealing',
        );
      }
      staging.renameSync(materialRoot.path);
      verifyCanonicalRoot();
    } on Object {
      if (staging.existsSync()) staging.deleteSync(recursive: true);
      rethrow;
    }
  }

  File _purposePrivateFile(String path, String label) {
    final file = File(path).absolute;
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        (!Platform.isWindows && (file.statSync().mode & 0x3f) != 0)) {
      throw AgentEvaluationReleaseCoordinatorException(
        '$label must be a regular mode-0600 file',
      );
    }
    return file;
  }

  _PublicReleaseAuthority _readPublicAuthority(
    Database db, {
    required Map<String, Object?> publicReport,
    required String holdoutAccessPolicyHash,
  }) {
    final reportPartitions = publicReport['partitions'];
    final reportReleaseIdentity = publicReport['releaseIdentity'];
    final reportExecution = publicReport['execution'];
    final reportAuthorityDatabase = publicReport['authorityDatabase'];
    final reportMatrix = publicReport['matrix'];
    if (reportPartitions is! List<Object?> ||
        reportPartitions.length != publicResult.partitions.length ||
        reportPartitions.any((item) => item is! Map<String, Object?>) ||
        reportReleaseIdentity is! Map<String, Object?> ||
        reportExecution is! Map<String, Object?> ||
        reportAuthorityDatabase is! Map<String, Object?> ||
        reportMatrix is! Map<String, Object?>) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'public report authority projection is malformed',
      );
    }
    final expectedRunnerReleaseHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-real-release-runner-v1',
      const <String, Object?>{
        'matrix': 'single-cross-model-execution-v1',
        'budget': 'coordinator-wide-public-private-journal-v1',
        'transport': 'internally-owned-real-provider-clients-v1',
        'report': 'audit-verifiable-secret-free-archive-v4-price-authority',
        'pricing': 'compile-time-trust-price-table-and-free-route-policy-v1',
      },
    );
    final expectedTransportHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-release-transport-provenance-v1',
      _productionMode
          ? 'app-llm-io-client-factory-v1'
          : 'purpose-built-production-protocol-v1',
    );
    final publicAuditMatches =
        AgentEvaluationHashes.canonicalJson(reportAuthorityDatabase) ==
        AgentEvaluationHashes.canonicalJson(_publicAuthorityAuditSummary(db));
    if (publicReport['realProviderEvidence'] != _productionMode ||
        reportExecution['commandIdentity'] !=
            (_productionMode
                ? 'tool-agent-evaluation-release-runner-v1'
                : 'purpose-built-production-protocol-v1') ||
        reportReleaseIdentity['transportProvenanceHash'] !=
            expectedTransportHash ||
        reportReleaseIdentity['runnerReleaseHash'] !=
            expectedRunnerReleaseHash ||
        reportReleaseIdentity['releaseConfigurationHash'] !=
            publicResult.releaseConfigurationHash ||
        reportReleaseIdentity['priceTableReleaseHash'] is! String ||
        (_productionMode
            ? (reportReleaseIdentity['priceAuthorityTrustEntryHash']
                      is! String ||
                  reportReleaseIdentity['freeRoutePolicyVersion'] !=
                      agentEvaluationTrustedFreeRoutePolicyVersion ||
                  reportReleaseIdentity['freeRoutePolicyHash'] is! String)
            : (reportReleaseIdentity['priceAuthorityTrustEntryHash'] != null ||
                  reportReleaseIdentity['freeRoutePolicyVersion'] != null ||
                  reportReleaseIdentity['freeRoutePolicyHash'] != null))) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'public real-provider report is not bound to the authority database',
      );
    }

    final resultRouteHashes = publicResult.partitions
        .map((partition) => partition.modelRouteHash)
        .toList(growable: false);
    if (resultRouteHashes.toSet().length != resultRouteHashes.length) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'public model partitions are duplicated',
      );
    }
    final reportByRoute = <String, Map<String, Object?>>{};
    for (final item in reportPartitions.cast<Map<String, Object?>>()) {
      final routeHash = item['modelRouteHash'];
      if (routeHash is! String ||
          reportByRoute.putIfAbsent(routeHash, () => item) != item) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public report model partitions are duplicated',
        );
      }
    }

    final partitionAuthorities = <_PublicPartitionAuthority>[];
    final coveredRoutes = <String>{};
    for (final partition in publicResult.partitions) {
      final rows = db.select(
        '''SELECT v.*, x.experiment_id, e.scenario_set_release_hash,
             d.authority_release_hash
           FROM eval_release_gate_verdicts v
           JOIN eval_release_gate_derivations d
             ON d.verdict_hash = v.verdict_hash
           JOIN eval_executions x ON x.execution_id = v.execution_id
           JOIN eval_experiments e ON e.experiment_id = x.experiment_id
           WHERE v.execution_id = ? AND v.verdict_kind = 'regression' ''',
        <Object?>[partition.executionId],
      );
      if (rows.length != 1) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public execution has no unique regression verdict',
        );
      }
      final row = rows.single;
      if (row['verdict_hash'] != partition.regressionVerdictHash ||
          row['status'] != 'promote' ||
          row['policy_hash'] != AgentEvaluationStandardGatePolicy.policyHash ||
          row['gate_release_hash'] !=
              AgentEvaluationStandardGatePolicy.gateReleaseHash ||
          row['authority_release_hash'] != row['gate_release_hash']) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public regression verdict is not authority-derived promote evidence',
        );
      }
      final experimentId = row['experiment_id'] as String;
      final experiment = db.select(
        'SELECT manifest_json, manifest_hash FROM eval_experiments '
        'WHERE experiment_id = ?',
        <Object?>[experimentId],
      );
      if (experiment.length != 1 ||
          experiment.single['manifest_hash'] != partition.manifestHash) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public manifest identity is missing',
        );
      }
      final manifest = _strictJsonObject(
        experiment.single['manifest_json'] as String,
      );
      final manifestRoutes = (manifest['modelRouteHashes'] as List<Object?>?)
          ?.whereType<String>()
          .toSet();
      if (manifestRoutes == null ||
          manifestRoutes.isEmpty ||
          manifestRoutes.length !=
              (manifest['modelRouteHashes'] as List).length ||
          manifestRoutes.difference(_requiredModelRouteHashes).isNotEmpty ||
          partition.modelRouteHash !=
              manifest['providerConfigHashWithoutSecrets'] ||
          coveredRoutes.intersection(manifestRoutes).isNotEmpty) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public manifest route set contradicts its frozen partition',
        );
      }
      coveredRoutes.addAll(manifestRoutes);
      final manifestPriceTableHash = manifest['priceTableHash'];
      if (manifestPriceTableHash is! String) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public manifest price authority is missing',
        );
      }
      AgentEvaluationHashes.requireDigest(
        manifestPriceTableHash,
        'priceTableReleaseHash',
      );
      final manifestBudgets = manifest['budgets'];
      if (reportReleaseIdentity['sourceTreeHash'] !=
              manifest['sourceTreeHash'] ||
          reportReleaseIdentity['buildArtifactHash'] !=
              manifest['buildArtifactHash'] ||
          reportReleaseIdentity['runtimeReleaseHash'] !=
              manifest['runtimeReleaseHash'] ||
          reportReleaseIdentity['priceTableReleaseHash'] !=
              manifestPriceTableHash ||
          manifestBudgets is! Map<String, Object?> ||
          manifestBudgets['releaseConfigurationHash'] !=
              publicResult.releaseConfigurationHash ||
          db.select(
                'SELECT COUNT(*) AS count FROM eval_price_table_releases '
                'WHERE price_table_hash = ?',
                <Object?>[manifestPriceTableHash],
              ).single['count'] !=
              1) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public source, build, and runtime identities are not frozen',
        );
      }
      final scorecards = db.select(
        '''SELECT scorecard_hash, aggregate_json FROM eval_scorecards
           WHERE execution_id = ?''',
        <Object?>[partition.executionId],
      );
      if (scorecards.length != 1 ||
          scorecards.single['scorecard_hash'] != partition.scorecardHash) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public execution has no unique scorecard authority',
        );
      }
      final aggregate = _strictJsonObject(
        scorecards.single['aggregate_json'] as String,
      );
      final aggregateCounts = aggregate['counts'];
      if (aggregate['reportHash'] != partition.publicReportHash ||
          aggregate['executionId'] != partition.executionId ||
          aggregateCounts is! Map<String, Object?>) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public scorecard does not bind its execution report',
        );
      }
      final dbCounts = _PublicPartitionCounts(
        cellCount:
            db.select(
                  'SELECT COUNT(*) AS count FROM eval_experiment_cells '
                  'WHERE experiment_id = ?',
                  <Object?>[experimentId],
                ).single['count']
                as int,
        slotCount: aggregateCounts['slots']! as int,
        productionReceiptCount: aggregateCounts['productionReceipts']! as int,
        providerCallCount: aggregateCounts['providerCalls']! as int,
      );
      final reportPartition = reportByRoute[partition.modelRouteHash];
      if (reportPartition == null ||
          reportPartition['executionId'] != partition.executionId ||
          reportPartition['manifestHash'] != partition.manifestHash ||
          reportPartition['publicReportHash'] != partition.publicReportHash ||
          reportPartition['scorecardHash'] != partition.scorecardHash ||
          reportPartition['regressionVerdictHash'] !=
              partition.regressionVerdictHash ||
          reportPartition['regressionStatus'] != 'promote' ||
          reportPartition['cellCount'] != partition.cellCount ||
          reportPartition['slotCount'] != partition.slotCount ||
          reportPartition['productionReceiptCount'] !=
              partition.productionReceiptCount ||
          reportPartition['providerCallCount'] != partition.providerCallCount ||
          partition.cellCount != dbCounts.cellCount ||
          partition.slotCount != dbCounts.slotCount ||
          partition.productionReceiptCount != dbCounts.productionReceiptCount ||
          partition.providerCallCount != dbCounts.providerCallCount ||
          partition.productionReceiptCount != partition.slotCount) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public partition counters are not DB-derived',
        );
      }
      final arms = db
          .select(
            '''SELECT DISTINCT c.generation_bundle_hash
               FROM eval_experiment_cells ec
               JOIN eval_cells c ON c.cell_id = ec.cell_id
               WHERE ec.experiment_id = ? ORDER BY c.generation_bundle_hash''',
            <Object?>[experimentId],
          )
          .map((item) => item['generation_bundle_hash'] as String)
          .toList(growable: false);
      final champion = row['champion_bundle_hash'] as String;
      final challenger = row['challenger_bundle_hash'] as String;
      if (arms.length != 2 ||
          !arms.contains(champion) ||
          !arms.contains(challenger) ||
          champion == challenger) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'public manifest does not contain exactly the verdict arms',
        );
      }
      partitionAuthorities.add(
        _PublicPartitionAuthority(
          modelRouteHash: partition.modelRouteHash,
          experimentId: experimentId,
          executionId: partition.executionId,
          manifestHash: partition.manifestHash,
          publicReportHash: partition.publicReportHash,
          scorecardHash: partition.scorecardHash,
          regressionVerdictHash: partition.regressionVerdictHash,
          regressionStatus: row['status'] as String,
          regressionScenarioSetHash: row['scenario_set_release_hash'] as String,
          championBundleHash: champion,
          challengerBundleHash: challenger,
          priceTableReleaseHash: manifestPriceTableHash,
          cellCount: dbCounts.cellCount,
          slotCount: dbCounts.slotCount,
          productionReceiptCount: dbCounts.productionReceiptCount,
          providerCallCount: dbCounts.providerCallCount,
        ),
      );
    }
    if (coveredRoutes.length != _requiredModelRouteHashes.length ||
        coveredRoutes.difference(_requiredModelRouteHashes).isNotEmpty) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'public partitions do not cover the frozen model route set',
      );
    }
    partitionAuthorities.sort(
      (left, right) => left.modelRouteHash.compareTo(right.modelRouteHash),
    );
    final primary = partitionAuthorities.first;
    if (partitionAuthorities.any(
          (partition) =>
              partition.regressionScenarioSetHash !=
                  primary.regressionScenarioSetHash ||
              partition.championBundleHash != primary.championBundleHash ||
              partition.challengerBundleHash != primary.challengerBundleHash ||
              partition.priceTableReleaseHash != primary.priceTableReleaseHash,
        ) ||
        primary.regressionScenarioSetHash ==
            privateCommitment.opaqueScenarioSetHash) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'public partitions do not share one release authority',
      );
    }
    final totalCells = partitionAuthorities.fold<int>(
      0,
      (sum, partition) => sum + partition.cellCount,
    );
    final totalSlots = partitionAuthorities.fold<int>(
      0,
      (sum, partition) => sum + partition.slotCount,
    );
    if (reportMatrix['scenarioCount'] != 10 ||
        reportMatrix['armCount'] != 2 ||
        reportMatrix['trialsPerCell'] != 3 ||
        reportMatrix['modelPartitionCount'] != partitionAuthorities.length ||
        reportMatrix['cellCount'] != totalCells ||
        reportMatrix['slotCount'] != totalSlots) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'public report matrix does not aggregate every partition',
      );
    }
    final resumeFamilies = db.select(
      '''SELECT family_id FROM eval_experiment_families
         WHERE scenario_set_release_hash = ?
           AND opaque_holdout_scenario_set_hash = ?
           AND private_plan_hash = ?
           AND holdout_access_policy_hash = ?''',
      <Object?>[
        primary.regressionScenarioSetHash,
        privateCommitment.opaqueScenarioSetHash,
        privateCommitment.privatePlanHash,
        holdoutAccessPolicyHash,
      ],
    );
    if (!publicAuditMatches && resumeFamilies.length != 1) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'public authority database changed outside the resumable workflow',
      );
    }
    for (final entry in <MapEntry<String, Object?>>[
      MapEntry<String, Object?>(
        'priceTableReleaseHash',
        reportReleaseIdentity['priceTableReleaseHash'],
      ),
      if (_productionMode)
        MapEntry<String, Object?>(
          'priceAuthorityTrustEntryHash',
          reportReleaseIdentity['priceAuthorityTrustEntryHash'],
        ),
      if (_productionMode)
        MapEntry<String, Object?>(
          'freeRoutePolicyHash',
          reportReleaseIdentity['freeRoutePolicyHash'],
        ),
    ]) {
      AgentEvaluationHashes.requireDigest(entry.value! as String, entry.key);
    }
    return _PublicReleaseAuthority(
      partitions: partitionAuthorities,
      experimentId: primary.experimentId,
      executionId: primary.executionId,
      regressionVerdictHash: primary.regressionVerdictHash,
      regressionStatus: 'promote',
      regressionScenarioSetHash: primary.regressionScenarioSetHash,
      championBundleHash: primary.championBundleHash,
      challengerBundleHash: primary.challengerBundleHash,
      releaseConfigurationHash: publicResult.releaseConfigurationHash,
      priceTableReleaseHash: primary.priceTableReleaseHash,
      priceAuthorityTrustEntryHash:
          reportReleaseIdentity['priceAuthorityTrustEntryHash'] as String?,
      freeRoutePolicyVersion:
          reportReleaseIdentity['freeRoutePolicyVersion'] as String?,
      freeRoutePolicyHash:
          reportReleaseIdentity['freeRoutePolicyHash'] as String?,
      publicReportHash: publicReport['reportHash']! as String,
      sourceTreeHash: reportReleaseIdentity['sourceTreeHash']! as String,
    );
  }

  File _snapshotAuthority(Database db, String accessId) {
    final directory = Directory('${workDirectory.path}/private-child')
      ..createSync(recursive: true);
    _chmod(directory.path, '700');
    final identity = AgentEvaluationHashes.domainHash(
      'agent-evaluation-private-authority-copy-v1',
      accessId,
    ).substring(0, 16);
    final file = File('${directory.path}/authority-$identity.sqlite');
    if (file.existsSync()) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'private authority copy already exists',
      );
    }
    db.execute('VACUUM INTO ?', <Object?>[file.path]);
    _chmod(file.path, '600');
    return file;
  }

  void _preflightPrivateRuntime() {
    // Purpose-built E2E commands are already frozen to two regular files by
    // AgentEvaluationPrivateRunnerCommand. They can never assert release
    // eligibility, so no production artifact claim is accepted here.
    if (!_productionMode) return;
    final repository = Directory.current.absolute;
    final runtime = File(
      '${repository.path}/build/macos/Build/Products/Release/'
      'novel_writer.app/Contents/MacOS/novel_writer',
    ).absolute;
    if (privateRunnerCommand.executablePath != runtime.path ||
        privateRunnerCommand.entrypointPath != runtime.path ||
        privateRunnerCommand.fixedArguments.isNotEmpty) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production private runtime identity is not frozen',
      );
    }
    final expectedHash =
        (Platform.environment['AGENT_EVAL_BUILD_ARTIFACT_HASH'] ?? '').trim();
    if (FileSystemEntity.typeSync(runtime.path, followLinks: false) !=
            FileSystemEntityType.file ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash) ||
        _sha256File(runtime) != expectedHash) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production private runtime artifact is not preflighted',
      );
    }
  }

  Future<_PrivateProcessResult> _runPrivateChild({
    required String authorityDatabasePath,
    required String accessId,
  }) async {
    if (_productionMode) {
      try {
        final response = await _privateRunnerBroker!(
          authorityDatabasePath: authorityDatabasePath,
          accessId: accessId,
        ).timeout(processTimeout);
        if (utf8.encode(response).length >
                AgentEvaluationReleaseCoordinatorPolicy
                    .maxPrivateResponseBytes ||
            response.isEmpty) {
          throw const AgentEvaluationReleaseCoordinatorException(
            'private broker response exceeded its fixed envelope',
          );
        }
        _childExitCode = 0;
        return _PrivateProcessResult(stdoutText: response, exitCode: 0);
      } on TimeoutException {
        _childExitCode = 124;
        throw const AgentEvaluationReleaseCoordinatorException(
          'private broker exceeded its frozen deadline',
        );
      }
    }
    final arguments = _productionMode
        ? const <String>[]
        : <String>[
            ...privateRunnerCommand.fixedArguments,
            privateRunnerCommand.entrypointPath,
            '--authority-db',
            authorityDatabasePath,
            '--access-id',
            accessId,
            '--private-plan',
            privateCommitment.privatePlanPath!,
            '--vault',
            privateCommitment.vaultPath!,
            '--seed-file',
            privateCommitment.seedFilePath!,
            '--key-id',
            privateCommitment.keyId,
          ];
    final process = await Process.start(
      privateRunnerCommand.executablePath,
      arguments,
      workingDirectory: Directory.current.path,
      environment: Platform.environment,
      includeParentEnvironment: true,
      mode: ProcessStartMode.normal,
    );
    final stdoutFuture = _readBounded(
      process.stdout,
      AgentEvaluationReleaseCoordinatorPolicy.maxPrivateResponseBytes,
    );
    final stderrFuture = _readBounded(
      process.stderr,
      AgentEvaluationReleaseCoordinatorPolicy.maxPrivateStderrBytes,
    );
    try {
      final values = await Future.wait<Object>(<Future<Object>>[
        process.exitCode,
        stdoutFuture,
        stderrFuture,
      ]).timeout(processTimeout);
      final exitCode = values[0] as int;
      final stdoutText = values[1] as String;
      final stderrText = values[2] as String;
      _childExitCode = exitCode;
      if (exitCode != 0 ||
          (!_productionMode && stderrText.isNotEmpty) ||
          stdoutText.isEmpty) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'private child failed its fixed process envelope',
        );
      }
      return _PrivateProcessResult(stdoutText: stdoutText, exitCode: exitCode);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      _childExitCode = 124;
      throw const AgentEvaluationReleaseCoordinatorException(
        'private child exceeded its frozen deadline',
      );
    } on Object {
      process.kill(ProcessSignal.sigkill);
      rethrow;
    }
  }

  Future<AgentEvaluationEvidenceCustodyContract> _evidenceCustody() async {
    final capability = privateCommitment.externalSigningCapability;
    if (capability == null) {
      return AgentEvaluationEvidenceCustodyContract.localFileSeed(
        keyId: privateCommitment.keyId,
        publicKeyHash: AgentEvaluationHashes.domainHash(
          'agent-evaluation-holdout-public-key-v1',
          base64Encode(privateCommitment.publicKey.bytes),
        ),
        runnerArtifactHash: privateRunnerReleaseHash,
      );
    }
    try {
      final token = _custodyToken;
      if (token == null ||
          token.payloadJson != capability.custodyAttestationPayloadJson ||
          token.signatureBase64 !=
              capability.custodyAttestationSignatureBase64 ||
          token.keyId != privateCommitment.keyId ||
          token.signerCommandIdentityHash !=
              capability.signerCommandIdentityHash ||
          token.runnerArtifactHash != privateRunnerReleaseHash) {
        throw const FormatException('production custody token mismatch');
      }
      await token.reverify(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        minimumRemainingTtl: processTimeout + const Duration(minutes: 1),
      );
      return token.auditContract;
    } on FormatException {
      throw const AgentEvaluationReleaseCoordinatorException(
        'external signer custody attestation is invalid',
      );
    }
  }

  Future<void> _reverifyExternalCustody(
    AgentEvaluationEvidenceCustodyContract custody,
  ) async {
    final capability = privateCommitment.externalSigningCapability;
    if (capability == null) return;
    try {
      final token = _custodyToken;
      if (token == null ||
          token.auditContract.custodyHash != custody.custodyHash) {
        throw const FormatException('production custody token mismatch');
      }
      await token.reverify(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        minimumRemainingTtl: processTimeout + const Duration(minutes: 1),
      );
    } on FormatException {
      throw const AgentEvaluationReleaseCoordinatorException(
        'external signer custody attestation is no longer current',
      );
    }
  }

  _ProductionCriteriaArtifact _writeProductionCriteriaArtifact({
    required Database db,
    required _PublicReleaseAuthority authority,
    required AgentEvaluationProductionHoldoutClaimRecord claim,
    required String promotionDecisionId,
    required String rollbackDecisionId,
    required AgentEvaluationEvidenceCustodyContract custody,
    required AgentEvaluationEvidenceRetentionContract retention,
    required Map<String, Object?> combinedBudgetEvidence,
    required int startedAtMs,
  }) {
    final baselineSeal = _baselineCriteriaSeal;
    final token = _custodyToken;
    if (baselineSeal == null || token == null) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria authorities are missing',
      );
    }
    if (token.baselineCriteriaSealHash != baselineSeal.sealHash ||
        token.baselineSourceTreeHash != authority.sourceTreeHash) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'external custody does not authorize the criteria baseline',
      );
    }
    try {
      baselineSeal.registry.requireProductionBaseline(
        sourceTreeHash: authority.sourceTreeHash,
      );
    } on Object {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria baseline is invalid',
      );
    }
    final claimRows = db.select(
      'SELECT * FROM eval_production_holdout_claims WHERE claim_hash = ?',
      <Object?>[claim.claimHash],
    );
    if (claimRows.length != 1) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria holdout claim is missing',
      );
    }
    final claimRow = claimRows.single;
    final baselineVerification = baselineSeal.registry.entries.singleWhere(
      (entry) => entry.criteriaId == 'AEE-24',
    );
    final budgetEvidenceHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-combined-budget-evidence-v1',
      combinedBudgetEvidence,
    );
    final holdoutReuse = AgentEvaluationHoldoutReuseAuthority.read(
      db: db,
      claimHash: claim.claimHash,
    ).toReportMap();
    final facts = <String, Map<String, Object?>>{
      'AEE-14': <String, Object?>{
        'publicReportHash': authority.publicReportHash,
        'regressionVerdictSetHash': authority.regressionVerdictSetHash,
        'regressionStatus': authority.regressionStatus,
        'modelPartitionCount': authority.partitions.length,
        'partitions': <Object?>[
          for (final partition in authority.partitions)
            partition.toCriteriaMap(),
        ],
        'completedSlotCount': authority.slotCount,
        'productionReceiptCount': authority.productionReceiptCount,
        'providerCallCount': authority.providerCallCount,
      },
      'AEE-15': <String, Object?>{
        'scenarioCount': 10,
        'armCount': 2,
        'trialsPerCell': 3,
        'modelRouteCount': _requiredModelRouteHashes.length,
        'modelPartitionCount': authority.partitions.length,
        'cellCount': authority.cellCount,
        'slotCount': authority.slotCount,
        'productionReceiptCount': authority.productionReceiptCount,
      },
      'AEE-18': <String, Object?>{
        'productionHoldoutClaimHash': claim.claimHash,
        'productionHoldoutResult': claim.result,
        'holdoutImportedAtMs': claim.importedAtMs,
        'holdoutIssuedAtMs': claimRow['issued_at_ms'],
        'holdoutExpiresAtMs': claimRow['expires_at_ms'],
        'custodyCapabilityHash': token.capabilityHash,
        'custodyAttestationHash': token.attestationHash,
        'custodyHash': custody.custodyHash,
        'holdoutReuseAuthority': holdoutReuse,
      },
      'AEE-23': <String, Object?>{
        'regressionScenarioSetHash': authority.regressionScenarioSetHash,
        'opaqueHoldoutScenarioSetHash': privateCommitment.opaqueScenarioSetHash,
        'modelRouteCount': _requiredModelRouteHashes.length,
        'modelPartitionCount': authority.partitions.length,
        'expectedPublicCellCount': authority.cellCount,
        'expectedPublicSlotCount': authority.slotCount,
        'completedPublicSlotCount': authority.productionReceiptCount,
        'privateExpectedCellSetHash': claimRow['expected_cell_set_hash'],
        'privateExpectedSlotSetHash': claimRow['expected_slot_set_hash'],
        'productionHoldoutClaimHash': claim.claimHash,
      },
      'AEE-24': <String, Object?>{
        'baselineCriteriaSealHash': baselineSeal.sealHash,
        'baselineVerificationArtifactPath': baselineVerification.artifactPath,
        'baselineVerificationArtifactHash': baselineVerification.artifactHash,
        'baselineVerificationReportHash': baselineVerification.reportHash,
        'sourceTreeHash': authority.sourceTreeHash,
        'publicReportHash': authority.publicReportHash,
        'combinedBudgetEvidenceHash': budgetEvidenceHash,
        'productionHoldoutClaimHash': claim.claimHash,
        'promotionDecisionHash': _decisionHash(db, promotionDecisionId),
        'rollbackDecisionHash': _decisionHash(db, rollbackDecisionId),
        'finalChannelEpoch': 2,
      },
    };
    final criterionReportHashes = <String, String>{
      for (final entry in facts.entries)
        entry.key: AgentEvaluationHashes.domainHash(
          'agent-evaluation-production-criterion-${entry.key.toLowerCase()}-v1',
          entry.value,
        ),
    };
    final payload = <String, Object?>{
      'schemaVersion': 'agent-evaluation-production-criteria-evidence-v1',
      'sourceTreeHash': authority.sourceTreeHash,
      'baselineCriteriaSeal': baselineSeal.toCanonicalMap(),
      'baselineCriteriaSealHash': baselineSeal.sealHash,
      'criterionFacts': facts,
      'criterionReportHashes': criterionReportHashes,
    };
    final reportHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-production-criteria-evidence-v1',
      payload,
    );
    final body = const JsonEncoder.withIndent(
      ' ',
    ).convert(<String, Object?>{...payload, 'reportHash': reportHash});
    final directory = Directory('${reportDirectory.path}/release');
    final file = writeAgentEvaluationUniqueReportFileAtomically(
      directory: directory,
      fileStem:
          'agent-evaluation-production-criteria-'
          '${reportHash.substring(0, 16)}',
      body: body,
    );
    if (file == null) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria evidence namespace is exhausted',
      );
    }
    final artifactPath = 'release/${file.uri.pathSegments.last}';
    final artifactHash = _sha256File(file);
    final criteriaSeal = deriveAgentEvaluationProductionCriteriaSeal(
      baselineSeal: baselineSeal,
      sourceTreeHash: authority.sourceTreeHash,
      productionArtifactPath: artifactPath,
      productionArtifactHash: artifactHash,
      productionCriterionReportHashes: criterionReportHashes,
      sanitizedCommand:
          'dart run tool/agent_evaluation_release_coordinator.dart',
      durationMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
      retentionLevel: retention.level,
    );
    return _ProductionCriteriaArtifact(
      artifactPath: artifactPath,
      artifactHash: artifactHash,
      reportHash: reportHash,
      criterionFacts: facts,
      criterionReportHashes: criterionReportHashes,
      baselineCriteriaSeal: baselineSeal,
      criteriaSeal: criteriaSeal,
    );
  }

  AgentEvaluationSpecCriteriaRegistrySeal _criteriaRegistrySeal({
    required _PublicReleaseAuthority authority,
    required AgentEvaluationEvidenceRetentionContract retention,
    required int startedAtMs,
  }) {
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAtMs;
    final failedByLocalCustody =
        retention.custodyHash == _localCustodyHashForCriteria()
        ? <String>{'AEE-18', 'AEE-23'}
        : const <String>{};
    final evidenceLevel = _productionMode
        ? AgentEvaluationSpecEvidenceLevel.realProviderRelease
        : AgentEvaluationSpecEvidenceLevel.integration;
    final registry = AgentEvaluationSpecCriteriaRegistry(
      entries: <AgentEvaluationSpecCriterionEvidence>[
        for (final criteriaId
            in AgentEvaluationSpecCriteriaRegistry.requiredCriteriaIds)
          AgentEvaluationSpecCriterionEvidence(
            criteriaId: criteriaId,
            artifactPath: 'release/public-report.json',
            artifactHash: authority.publicReportHash,
            sanitizedCommand:
                'dart run tool/agent_evaluation_release_coordinator.dart',
            exitCode: failedByLocalCustody.contains(criteriaId) ? 2 : -1,
            durationMs: failedByLocalCustody.contains(criteriaId)
                ? elapsedMs
                : 0,
            sourceTreeHash: authority.sourceTreeHash,
            reportHash: authority.publicReportHash,
            evidenceLevel: evidenceLevel,
            retentionLevel: retention.level,
            status: failedByLocalCustody.contains(criteriaId)
                ? AgentEvaluationSpecCriteriaStatus.failed
                : AgentEvaluationSpecCriteriaStatus.notEvaluated,
          ),
      ],
    );
    return AgentEvaluationSpecCriteriaRegistrySeal.create(registry);
  }

  String _localCustodyHashForCriteria() =>
      AgentEvaluationEvidenceCustodyContract.localFileSeed(
        keyId: privateCommitment.keyId,
        publicKeyHash: AgentEvaluationHashes.domainHash(
          'agent-evaluation-holdout-public-key-v1',
          base64Encode(privateCommitment.publicKey.bytes),
        ),
        runnerArtifactHash: privateRunnerReleaseHash,
      ).custodyHash;

  _WrittenReport _writeFinalReport({
    required Database db,
    required int startedAtMs,
    required _PublicReleaseAuthority authority,
    required AgentEvaluationProductionHoldoutClaimRecord claim,
    required String promotionDecisionId,
    required String rollbackDecisionId,
    required bool realProviderEvidence,
    required bool releaseEligible,
    required AgentEvaluationEvidenceCustodyContract custody,
    required AgentEvaluationEvidenceRetentionContract retention,
    required AgentEvaluationSpecCriteriaRegistrySeal criteriaSeal,
    required _ProductionCriteriaArtifact? productionCriteriaArtifact,
    required Map<String, Object?>? combinedBudgetEvidence,
  }) {
    final holdoutReuse = AgentEvaluationHoldoutReuseAuthority.read(
      db: db,
      claimHash: claim.claimHash,
    );
    final payload = <String, Object?>{
      'schemaVersion': 'agent-evaluation-final-release-report-v1',
      'claimScope': 'real-provider-release',
      'releaseEligible': releaseEligible,
      'realProviderEvidence': realProviderEvidence,
      'regressionStatus': authority.regressionStatus,
      'productionHoldoutResult': claim.result,
      'publicReportHash': authority.publicReportHash,
      'authorityDatabase': _authorityAudit(db),
      'holdoutReuseAuthority': holdoutReuse.toReportMap(),
      'combinedBudgetEvidence': combinedBudgetEvidence,
      'productionCriteriaEvidence': productionCriteriaArtifact
          ?.toCommitmentMap(),
      'authority': <String, Object?>{
        'coordinatorReleaseHash':
            AgentEvaluationReleaseCoordinatorPolicy.releaseHash,
        'privateRunnerReleaseHash': privateRunnerReleaseHash,
        'privateResolverReleaseHash':
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
        'privateRunnerCommandHash': privateRunnerCommand.identityHash,
        'regressionVerdictHash': authority.regressionVerdictHash,
        'regressionVerdictSetHash': authority.regressionVerdictSetHash,
        'publicPartitions': <Object?>[
          for (final partition in authority.partitions)
            partition.toCriteriaMap(),
        ],
        'productionHoldoutClaimHash': claim.claimHash,
        'privatePlanHash': privateCommitment.privatePlanHash,
        'releaseConfigurationHash': authority.releaseConfigurationHash,
        'priceTableReleaseHash': authority.priceTableReleaseHash,
        'priceAuthorityTrustEntryHash': authority.priceAuthorityTrustEntryHash,
        'freeRoutePolicyVersion': authority.freeRoutePolicyVersion,
        'freeRoutePolicyHash': authority.freeRoutePolicyHash,
        'opaqueScenarioSetHash': privateCommitment.opaqueScenarioSetHash,
        'promotionDecisionHash': _decisionHash(db, promotionDecisionId),
        'rollbackDecisionHash': _decisionHash(db, rollbackDecisionId),
        'criteriaRegistryContractHash':
            AgentEvaluationSpecCriteriaRegistry.contractHash,
        'criteriaRegistrySealHash': criteriaSeal.sealHash,
        'custodyHash': custody.custodyHash,
        'retentionHash': retention.retentionHash,
      },
      'execution': <String, Object?>{
        'runIdHash': AgentEvaluationHashes.domainHash(
          'agent-evaluation-release-coordinator-run-v1',
          coordinatorRunId,
        ),
        'durationMs': DateTime.now().millisecondsSinceEpoch - startedAtMs,
        'childExitCode': _childExitCode,
        'exitSemantics': 'promoted-then-verified-rollback',
      },
      'criteriaRegistrySeal': criteriaSeal.toCanonicalMap(),
      'custody': custody.toCanonicalMap(),
      'retention': retention.toCanonicalMap(),
    };
    return _writeUniqueReport(
      payload: payload,
      domain: 'agent-evaluation-final-release-report-v1',
    );
  }

  void _writeFailureReport(int startedAtMs) {
    try {
      _prepareDirectories();
      _writeUniqueReport(
        payload: <String, Object?>{
          'schemaVersion': 'agent-evaluation-final-release-failure-report-v1',
          'claimScope': 'real-provider-release',
          'releaseEligible': false,
          'realProviderEvidence': false,
          'stage': _stage,
          'authority': <String, Object?>{
            'coordinatorReleaseHash':
                AgentEvaluationReleaseCoordinatorPolicy.releaseHash,
            'privateRunnerReleaseHash': privateRunnerReleaseHash,
            'privateRunnerCommandHash': privateRunnerCommand.identityHash,
            'privatePlanHash': privateCommitment.privatePlanHash,
            'opaqueScenarioSetHash': privateCommitment.opaqueScenarioSetHash,
          },
          'execution': <String, Object?>{
            'runIdHash': AgentEvaluationHashes.domainHash(
              'agent-evaluation-release-coordinator-run-v1',
              coordinatorRunId,
            ),
            'durationMs': DateTime.now().millisecondsSinceEpoch - startedAtMs,
            'childExitCode': _childExitCode,
            'exitSemantics': _observedChannelEpoch == 1
                ? 'failed-with-isolated-promotion-pending-rollback'
                : _observedChannelEpoch == 2
                ? 'failed-after-verified-rollback'
                : 'failed-before-channel-promotion',
            'channelState': <String, Object?>{
              'channelHash': _effectiveChannel == null
                  ? null
                  : AgentEvaluationHashes.domainHash(
                      'agent-evaluation-release-channel-v1',
                      _effectiveChannel,
                    ),
              'epoch': _observedChannelEpoch,
              'bundleHash': _observedChannelBundleHash,
            },
          },
        },
        domain: 'agent-evaluation-final-release-failure-report-v1',
      );
    } on Object {
      // Never replace the authoritative workflow failure with report cleanup.
    }
  }

  _WrittenReport _writeUniqueReport({
    required Map<String, Object?> payload,
    required String domain,
  }) {
    final reportHash = AgentEvaluationHashes.domainHash(domain, payload);
    final body = const JsonEncoder.withIndent(
      ' ',
    ).convert(<String, Object?>{...payload, 'reportHash': reportHash});
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = writeAgentEvaluationUniqueReportFileAtomically(
      directory: reportDirectory,
      fileStem:
          'agent-evaluation-final-release-$timestamp-'
          '${reportHash.substring(0, 16)}',
      body: body,
    );
    if (file != null) {
      return _WrittenReport(
        path: file.path,
        reportHash: reportHash,
        fileContentHash: _sha256File(file),
      );
    }
    throw const AgentEvaluationReleaseCoordinatorException(
      'final release report namespace is exhausted',
    );
  }

  void _sealFinalReport({
    required Database db,
    required _WrittenReport report,
    required _PublicReleaseAuthority authority,
    required String claimHash,
    required String promotionDecisionId,
    required String rollbackDecisionId,
  }) {
    var commitAttempted = false;
    try {
      final authorityAudit = _authorityAudit(db);
      if (_sha256File(File(report.path)) != report.fileContentHash) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'final release report changed before sealing',
        );
      }
      db.execute('BEGIN IMMEDIATE');
      db.execute(
        '''INSERT INTO eval_final_release_report_seals (
             report_hash, file_content_hash, report_path_hash,
             authority_audit_root_hash, release_configuration_hash,
             regression_verdict_hash, production_holdout_claim_hash,
             promotion_decision_id, rollback_decision_id, created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          report.reportHash,
          report.fileContentHash,
          AgentEvaluationHashes.domainHash(
            'agent-evaluation-final-report-path-v1',
            File(report.path).absolute.path,
          ),
          authorityAudit['auditRootHash'],
          authority.releaseConfigurationHash,
          authority.regressionVerdictHash,
          claimHash,
          promotionDecisionId,
          rollbackDecisionId,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      final rows = db.select(
        'SELECT * FROM eval_final_release_report_seals WHERE report_hash = ?',
        <Object?>[report.reportHash],
      );
      if (rows.length != 1 ||
          rows.single['file_content_hash'] != report.fileContentHash ||
          rows.single['report_path_hash'] !=
              AgentEvaluationHashes.domainHash(
                'agent-evaluation-final-report-path-v1',
                File(report.path).absolute.path,
              ) ||
          rows.single['authority_audit_root_hash'] !=
              authorityAudit['auditRootHash'] ||
          rows.single['release_configuration_hash'] !=
              authority.releaseConfigurationHash ||
          _sha256File(File(report.path)) != report.fileContentHash) {
        throw const AgentEvaluationReleaseCoordinatorException(
          'final release report seal readback failed',
        );
      }
      commitAttempted = true;
      db.execute('COMMIT');
    } on Object {
      if (!commitAttempted) {
        try {
          db.execute('ROLLBACK');
        } on Object {
          // The original seal failure remains authoritative.
        }
        final file = File(report.path);
        if (file.existsSync()) file.deleteSync();
      }
      rethrow;
    }
  }

  void _prepareDirectories() {
    workDirectory.createSync(recursive: true);
    reportDirectory.createSync(recursive: true);
    _chmod(workDirectory.path, '700');
  }
}

AgentEvaluationPrivateRunnerCommand _fixedProductionRunnerCommand() {
  final repository = Directory.current.absolute;
  final runtime =
      '${repository.path}/build/macos/Build/Products/Release/'
      'novel_writer.app/Contents/MacOS/novel_writer';
  return AgentEvaluationPrivateRunnerCommand(
    executablePath: runtime,
    entrypointPath: runtime,
  );
}

final class _CoordinatorIds {
  const _CoordinatorIds({
    required this.familyId,
    required this.tokenId,
    required this.accessId,
    required this.promotionDecisionId,
    required this.rollbackDecisionId,
  });

  factory _CoordinatorIds.from({
    required String runId,
    required String regressionVerdictHash,
    required String productionFamilyAuthorityHash,
  }) {
    String executionId(String kind) {
      final hash = AgentEvaluationHashes.domainHash(
        'agent-evaluation-release-coordinator-id-v1',
        <String, Object?>{
          'runId': runId,
          'verdictHash': regressionVerdictHash,
          'kind': kind,
        },
      );
      return '$kind-${hash.substring(0, 24)}';
    }

    String familyId(String kind) {
      final hash = AgentEvaluationHashes.domainHash(
        'agent-evaluation-production-family-id-v1',
        <String, Object?>{
          'productionFamilyAuthorityHash': productionFamilyAuthorityHash,
          'kind': kind,
        },
      );
      return '$kind-${hash.substring(0, 24)}';
    }

    return _CoordinatorIds(
      familyId: familyId('family'),
      tokenId: familyId('token'),
      accessId: familyId('access'),
      promotionDecisionId: executionId('promote'),
      rollbackDecisionId: executionId('rollback'),
    );
  }

  final String familyId;
  final String tokenId;
  final String accessId;
  final String promotionDecisionId;
  final String rollbackDecisionId;
}

final class _PublicReleaseAuthority {
  const _PublicReleaseAuthority({
    required this.partitions,
    required this.experimentId,
    required this.executionId,
    required this.regressionVerdictHash,
    required this.regressionStatus,
    required this.regressionScenarioSetHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.releaseConfigurationHash,
    required this.priceTableReleaseHash,
    required this.priceAuthorityTrustEntryHash,
    required this.freeRoutePolicyVersion,
    required this.freeRoutePolicyHash,
    required this.publicReportHash,
    required this.sourceTreeHash,
  });

  final List<_PublicPartitionAuthority> partitions;
  final String experimentId;
  final String executionId;
  final String regressionVerdictHash;
  final String regressionStatus;
  final String regressionScenarioSetHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String releaseConfigurationHash;
  final String priceTableReleaseHash;
  final String? priceAuthorityTrustEntryHash;
  final String? freeRoutePolicyVersion;
  final String? freeRoutePolicyHash;
  final String publicReportHash;
  final String sourceTreeHash;

  int get cellCount =>
      partitions.fold<int>(0, (sum, partition) => sum + partition.cellCount);

  int get slotCount =>
      partitions.fold<int>(0, (sum, partition) => sum + partition.slotCount);

  int get productionReceiptCount => partitions.fold<int>(
    0,
    (sum, partition) => sum + partition.productionReceiptCount,
  );

  int get providerCallCount => partitions.fold<int>(
    0,
    (sum, partition) => sum + partition.providerCallCount,
  );

  String get regressionVerdictSetHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-regression-verdict-set-v1',
    <String>[
      for (final partition in partitions) partition.regressionVerdictHash,
    ],
  );
}

final class _PublicPartitionAuthority {
  const _PublicPartitionAuthority({
    required this.modelRouteHash,
    required this.experimentId,
    required this.executionId,
    required this.manifestHash,
    required this.publicReportHash,
    required this.scorecardHash,
    required this.regressionVerdictHash,
    required this.regressionStatus,
    required this.regressionScenarioSetHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.priceTableReleaseHash,
    required this.cellCount,
    required this.slotCount,
    required this.productionReceiptCount,
    required this.providerCallCount,
  });

  final String modelRouteHash;
  final String experimentId;
  final String executionId;
  final String manifestHash;
  final String publicReportHash;
  final String scorecardHash;
  final String regressionVerdictHash;
  final String regressionStatus;
  final String regressionScenarioSetHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String priceTableReleaseHash;
  final int cellCount;
  final int slotCount;
  final int productionReceiptCount;
  final int providerCallCount;

  Map<String, Object?> toCriteriaMap() => <String, Object?>{
    'modelRouteHash': modelRouteHash,
    'executionId': executionId,
    'manifestHash': manifestHash,
    'publicReportHash': publicReportHash,
    'scorecardHash': scorecardHash,
    'regressionVerdictHash': regressionVerdictHash,
    'regressionStatus': regressionStatus,
    'cellCount': cellCount,
    'slotCount': slotCount,
    'productionReceiptCount': productionReceiptCount,
    'providerCallCount': providerCallCount,
  };
}

final class _PublicPartitionCounts {
  const _PublicPartitionCounts({
    required this.cellCount,
    required this.slotCount,
    required this.productionReceiptCount,
    required this.providerCallCount,
  });

  final int cellCount;
  final int slotCount;
  final int productionReceiptCount;
  final int providerCallCount;
}

final class _PrivateProcessResult {
  const _PrivateProcessResult({
    required this.stdoutText,
    required this.exitCode,
  });

  final String stdoutText;
  final int exitCode;
}

final class _WrittenReport {
  const _WrittenReport({
    required this.path,
    required this.reportHash,
    required this.fileContentHash,
  });

  final String path;
  final String reportHash;
  final String fileContentHash;
}

final class _ProductionCriteriaArtifact {
  const _ProductionCriteriaArtifact({
    required this.artifactPath,
    required this.artifactHash,
    required this.reportHash,
    required this.criterionFacts,
    required this.criterionReportHashes,
    required this.baselineCriteriaSeal,
    required this.criteriaSeal,
  });

  final String artifactPath;
  final String artifactHash;
  final String reportHash;
  final Map<String, Map<String, Object?>> criterionFacts;
  final Map<String, String> criterionReportHashes;
  final AgentEvaluationSpecCriteriaRegistrySeal baselineCriteriaSeal;
  final AgentEvaluationSpecCriteriaRegistrySeal criteriaSeal;

  Map<String, Object?> toCommitmentMap() => <String, Object?>{
    'artifactPath': artifactPath,
    'artifactHash': artifactHash,
    'reportHash': reportHash,
    'baselineCriteriaSealHash': baselineCriteriaSeal.sealHash,
    'criterionReportHashes': criterionReportHashes,
  };
}

Future<String> _readBounded(Stream<List<int>> source, int maximumBytes) async {
  final bytes = <int>[];
  await for (final chunk in source) {
    if (bytes.length + chunk.length > maximumBytes) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'private child output exceeded its fixed envelope',
      );
    }
    bytes.addAll(chunk);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw const AgentEvaluationReleaseCoordinatorException(
      'private child output is not UTF-8',
    );
  }
}

Map<String, Object?> _strictJsonObject(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release process JSON object is invalid',
    );
  }
  return decoded;
}

bool _hasPromotionAuthorization(
  Database db, {
  required String decisionId,
  required String regressionVerdictHash,
  required String claimHash,
}) =>
    db
        .select(
          '''SELECT 1 FROM prompt_release_decision_production_authorizations
         WHERE decision_id = ? AND regression_verdict_hash = ?
           AND production_holdout_claim_hash = ?''',
          <Object?>[decisionId, regressionVerdictHash, claimHash],
        )
        .length ==
    1;

String _decisionHash(Database db, String decisionId) {
  final rows = db.select(
    'SELECT * FROM prompt_release_decisions WHERE decision_id = ?',
    <Object?>[decisionId],
  );
  if (rows.length != 1) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release decision readback is missing',
    );
  }
  final row = rows.single;
  return AgentEvaluationHashes.domainHash(
    'agent-evaluation-release-decision-v1',
    <String, Object?>{
      'decisionId': row['decision_id'],
      'channel': row['channel'],
      'action': row['action'],
      'fromBundleHash': row['from_bundle_hash'],
      'toBundleHash': row['to_bundle_hash'],
      'fromEpoch': row['from_epoch'],
      'toEpoch': row['to_epoch'],
      'experimentId': row['experiment_id'],
      'scorecardHash': row['scorecard_hash'],
      'approver': row['approver'],
      'createdAtMs': row['created_at_ms'],
    },
  );
}

Map<String, Object?> _authorityAudit(Database db) {
  final authorityTables = db
      .select('''SELECT name FROM sqlite_master
           WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
           ORDER BY name''')
      .map((row) => row['name'] as String)
      .where(_isFinalAuthorityTableName)
      .toList(growable: false);
  final tables = authorityTables
      .where((name) => name != 'eval_final_release_report_seals')
      .toList(growable: false);
  final roots = <Map<String, Object?>>[];
  var totalRows = 0;
  for (final table in tables) {
    final columns = db
        .select('PRAGMA table_info("$table")')
        .map((row) => row['name'] as String)
        .toList(growable: false);
    final rowHashes = <String>[
      for (final row in db.select('SELECT * FROM "$table"'))
        AgentEvaluationHashes.domainHash(
          'agent-evaluation-final-authority-row-v1',
          <String, Object?>{for (final column in columns) column: row[column]},
        ),
    ]..sort();
    totalRows += rowHashes.length;
    roots.add(<String, Object?>{
      'table': table,
      'rowCount': rowHashes.length,
      'rowSetHash': AgentEvaluationHashes.domainHash(
        'agent-evaluation-final-authority-table-v1',
        rowHashes,
      ),
    });
  }
  final authorityTableSet = authorityTables.toSet();
  final schemaObjects = db
      .select('''SELECT type, name, tbl_name, sql FROM sqlite_master
           WHERE type IN ('table', 'index', 'trigger')
             AND name NOT LIKE 'sqlite_%'
           ORDER BY type, name''')
      .where((row) => authorityTableSet.contains(row['tbl_name']))
      .map(
        (row) => <String, Object?>{
          'type': row['type'],
          'name': row['name'],
          'table': row['tbl_name'],
          'sql': row['sql'],
        },
      )
      .toList(growable: false);
  final schemaRootHash = AgentEvaluationHashes.domainHash(
    'agent-evaluation-final-authority-schema-v1',
    schemaObjects,
  );
  return <String, Object?>{
    'tableCount': tables.length,
    'totalRows': totalRows,
    'schemaObjectCount': schemaObjects.length,
    'schemaRootHash': schemaRootHash,
    'auditRootHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-final-authority-database-v2',
      <String, Object?>{
        'tables': roots,
        'schemaObjectCount': schemaObjects.length,
        'schemaRootHash': schemaRootHash,
      },
    ),
  };
}

bool _isFinalAuthorityTableName(String name) =>
    name.startsWith('eval_') ||
    name.startsWith('prompt_release_') ||
    name == 'prompt_releases' ||
    name == 'prompt_channel_heads' ||
    name == 'evaluation_bundles' ||
    name == 'generation_bundles' ||
    name == 'generation_bundle_releases';

Map<String, Object?> _publicAuthorityAuditSummary(Database db) {
  final tables = db
      .select('''SELECT name FROM sqlite_master
           WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
           ORDER BY name''')
      .map((row) => row['name'] as String)
      .where(
        (name) =>
            name.startsWith('eval_') ||
            name == 'evaluation_bundles' ||
            name == 'generation_bundles' ||
            name == 'generation_bundle_releases' ||
            name == 'prompt_releases',
      )
      .toList(growable: false);
  final roots = <Map<String, Object?>>[];
  var totalRows = 0;
  for (final table in tables) {
    final columns = db
        .select('PRAGMA table_info("$table")')
        .map((row) => row['name'] as String)
        .toList(growable: false);
    final rowHashes = <String>[
      for (final row in db.select('SELECT * FROM "$table"'))
        AgentEvaluationHashes.domainHash(
          'agent-evaluation-authority-row-v1',
          <String, Object?>{for (final column in columns) column: row[column]},
        ),
    ]..sort();
    totalRows += rowHashes.length;
    roots.add(<String, Object?>{
      'table': table,
      'rowCount': rowHashes.length,
      'rowSetHash': AgentEvaluationHashes.domainHash(
        'agent-evaluation-authority-table-v1',
        rowHashes,
      ),
    });
  }
  return <String, Object?>{
    'tableCount': tables.length,
    'totalRows': totalRows,
    'auditRootHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-authority-database-audit-v1',
      roots,
    ),
    'summaryHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-authority-database-summary-v1',
      <String, Object?>{'tableCount': tables.length, 'totalRows': totalRows},
    ),
  };
}

String _fileHash(File file) => AgentEvaluationHashes.domainHash(
  'agent-evaluation-release-file-v1',
  base64Encode(file.readAsBytesSync()),
);

String _sha256File(File file) {
  final digest = const DartSha256().hashSync(file.readAsBytesSync());
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

void _chmod(String path, String mode) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>[mode, path]);
  if (result.exitCode != 0) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release coordinator could not secure a private path',
    );
  }
}

Future<void> verifyAgentEvaluationFinalReportSeal({
  required String reportPath,
  required String expectedReportHash,
  required String authorityDatabasePath,
  Map<String, Object?>? expectedCombinedBudgetEvidence,
  AgentEvaluationVerifiedProductionCustodyToken? productionCustodyToken,
  AgentEvaluationSpecCriteriaRegistrySeal? verifiedBaselineCriteriaSeal,
}) async {
  final file = File(reportPath).absolute;
  final source = file.readAsStringSync();
  final decoded = _strictJsonObject(source);
  if (decoded['reportHash'] != expectedReportHash) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'final release report identity is invalid',
    );
  }
  final payload = <String, Object?>{...decoded}..remove('reportHash');
  if (AgentEvaluationHashes.domainHash(
        'agent-evaluation-final-release-report-v1',
        payload,
      ) !=
      expectedReportHash) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'final release report content was modified',
    );
  }
  final contentHash = _sha256File(file);
  final pathHash = AgentEvaluationHashes.domainHash(
    'agent-evaluation-final-report-path-v1',
    file.path,
  );
  final criteriaRaw = decoded['criteriaRegistrySeal'];
  final custodyRaw = decoded['custody'];
  final retentionRaw = decoded['retention'];
  final holdoutReuseRaw = decoded['holdoutReuseAuthority'];
  final combinedBudgetRaw = decoded['combinedBudgetEvidence'];
  if (decoded['claimScope'] != 'real-provider-release' ||
      decoded['releaseEligible'] is! bool ||
      decoded['realProviderEvidence'] is! bool ||
      criteriaRaw is! Map<String, Object?> ||
      custodyRaw is! Map<String, Object?> ||
      retentionRaw is! Map<String, Object?> ||
      holdoutReuseRaw is! Map<String, Object?> ||
      (decoded['releaseEligible'] == true &&
          decoded['realProviderEvidence'] != true) ||
      (decoded['realProviderEvidence'] == true &&
          combinedBudgetRaw is! Map<String, Object?>) ||
      (expectedCombinedBudgetEvidence != null &&
          (combinedBudgetRaw is! Map<String, Object?> ||
              AgentEvaluationHashes.canonicalJson(combinedBudgetRaw) !=
                  AgentEvaluationHashes.canonicalJson(
                    expectedCombinedBudgetEvidence,
                  )))) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'final release evidence contracts are missing',
    );
  }
  if (combinedBudgetRaw is Map<String, Object?>) {
    try {
      verifyAgentEvaluationCombinedReleaseBudgetEvidence(combinedBudgetRaw);
    } on Object {
      throw const AgentEvaluationReleaseCoordinatorException(
        'final combined budget evidence is invalid',
      );
    }
  }
  late final AgentEvaluationSpecCriteriaRegistrySeal criteriaSeal;
  late final AgentEvaluationEvidenceCustodyContract custody;
  late final AgentEvaluationEvidenceRetentionContract retention;
  try {
    criteriaSeal = AgentEvaluationSpecCriteriaRegistrySeal.fromCanonicalJson(
      AgentEvaluationHashes.canonicalJson(criteriaRaw),
    );
    custody = AgentEvaluationEvidenceCustodyContract.fromCanonicalJson(
      AgentEvaluationHashes.canonicalJson(custodyRaw),
    );
    retention = AgentEvaluationEvidenceRetentionContract.fromCanonicalJson(
      AgentEvaluationHashes.canonicalJson(retentionRaw),
    );
  } on Object {
    throw const AgentEvaluationReleaseCoordinatorException(
      'final release evidence contracts are invalid',
    );
  }
  try {
    verifyAgentEvaluationCriteriaReleaseClaim(
      releaseEligible: decoded['releaseEligible'] == true,
      criteriaSeal: criteriaSeal,
    );
  } on FormatException {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release eligibility contradicts the AEE criteria registry',
    );
  }
  final db = sqlite3.open(authorityDatabasePath, mode: OpenMode.readOnly);
  try {
    final seals = db.select(
      '''SELECT authority_audit_root_hash, release_configuration_hash,
                regression_verdict_hash, production_holdout_claim_hash,
                promotion_decision_id, rollback_decision_id
         FROM eval_final_release_report_seals
         WHERE report_hash = ? AND file_content_hash = ?
           AND report_path_hash = ?''',
      <Object?>[expectedReportHash, contentHash, pathHash],
    );
    final releaseEligible = decoded['releaseEligible'] == true;
    if (releaseEligible) {
      await _verifyRecoveredProductionAuthorities(
        db: db,
        token: productionCustodyToken,
        custody: custody,
        decoded: decoded,
      );
    }
    final authorityDatabase = decoded['authorityDatabase'];
    final authority = decoded['authority'];
    final claimHash = authority is Map<String, Object?>
        ? authority['productionHoldoutClaimHash']
        : null;
    final regressionVerdictHash = authority is Map<String, Object?>
        ? authority['regressionVerdictHash']
        : null;
    final manifestRows = regressionVerdictHash is String
        ? db.select(
            '''SELECT e.manifest_json
                 FROM eval_release_gate_verdicts v
                 JOIN eval_experiments e ON e.experiment_id = v.experiment_id
                WHERE v.verdict_hash = ?''',
            <Object?>[regressionVerdictHash],
          )
        : const <Row>[];
    String? manifestPriceTableHash;
    if (manifestRows.length == 1) {
      try {
        final manifest = _strictJsonObject(
          manifestRows.single['manifest_json'] as String,
        );
        manifestPriceTableHash = manifest['priceTableHash'] as String?;
      } on Object {
        manifestPriceTableHash = null;
      }
    }
    final priceTableRows = manifestPriceTableHash == null
        ? const <Row>[]
        : db.select(
            'SELECT price_table_hash FROM eval_price_table_releases '
            'WHERE price_table_hash = ?',
            <Object?>[manifestPriceTableHash],
          );
    final rederivedHoldoutReuse = claimHash is String
        ? AgentEvaluationHoldoutReuseAuthority.read(
            db: db,
            claimHash: claimHash,
          ).toReportMap()
        : null;
    final rederivedAuthorityDatabase = _authorityAudit(db);
    if (seals.length != 1 ||
        authorityDatabase is! Map<String, Object?> ||
        authority is! Map<String, Object?> ||
        AgentEvaluationHashes.canonicalJson(authorityDatabase) !=
            AgentEvaluationHashes.canonicalJson(rederivedAuthorityDatabase) ||
        rederivedHoldoutReuse == null ||
        AgentEvaluationHashes.canonicalJson(rederivedHoldoutReuse) !=
            AgentEvaluationHashes.canonicalJson(holdoutReuseRaw) ||
        authority['coordinatorReleaseHash'] !=
            AgentEvaluationReleaseCoordinatorPolicy.releaseHash ||
        authority['criteriaRegistryContractHash'] !=
            AgentEvaluationSpecCriteriaRegistry.contractHash ||
        authority['criteriaRegistrySealHash'] != criteriaSeal.sealHash ||
        authority['custodyHash'] != custody.custodyHash ||
        authority['retentionHash'] != retention.retentionHash ||
        authority['priceTableReleaseHash'] != manifestPriceTableHash ||
        priceTableRows.length != 1 ||
        (decoded['releaseEligible'] == true &&
            (authority['priceAuthorityTrustEntryHash'] !=
                    custody.trustEntryHash ||
                authority['freeRoutePolicyVersion'] !=
                    agentEvaluationTrustedFreeRoutePolicyVersion ||
                authority['freeRoutePolicyHash'] is! String)) ||
        retention.custodyHash != custody.custodyHash ||
        (custody.mode == AgentEvaluationEvidenceCustodyMode.localFileSeed &&
            (retention.level != AgentEvaluationEvidenceRetentionLevel.audit ||
                retention.supportsRegrade ||
                retention.supportsReExecute)) ||
        seals.single['authority_audit_root_hash'] !=
            authorityDatabase['auditRootHash'] ||
        seals.single['release_configuration_hash'] !=
            authority['releaseConfigurationHash'] ||
        seals.single['regression_verdict_hash'] !=
            authority['regressionVerdictHash'] ||
        seals.single['production_holdout_claim_hash'] !=
            authority['productionHoldoutClaimHash'] ||
        authority['promotionDecisionHash'] !=
            _decisionHash(
              db,
              seals.single['promotion_decision_id'] as String,
            ) ||
        authority['rollbackDecisionHash'] !=
            _decisionHash(db, seals.single['rollback_decision_id'] as String)) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'final release report has no unique database seal',
      );
    }
    if (releaseEligible) {
      _verifyProductionCriteriaEvidence(
        db: db,
        reportFile: file,
        decoded: decoded,
        criteriaSeal: criteriaSeal,
        custodyToken: productionCustodyToken!,
        verifiedBaselineCriteriaSeal: verifiedBaselineCriteriaSeal,
        combinedBudgetEvidence: combinedBudgetRaw! as Map<String, Object?>,
        finalSealRow: seals.single,
      );
    }
  } finally {
    db.dispose();
  }
}

Future<void> _verifyRecoveredProductionAuthorities({
  required Database db,
  required AgentEvaluationVerifiedProductionCustodyToken? token,
  required AgentEvaluationEvidenceCustodyContract custody,
  required Map<String, Object?> decoded,
}) async {
  final authority = decoded['authority'];
  if (token == null || authority is! Map<String, Object?>) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release recovery requires a freshly verified production custody token',
    );
  }
  try {
    await token.reverify(nowMs: DateTime.now().millisecondsSinceEpoch);
  } on Object {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release recovery custody attestation is invalid',
    );
  }
  if (AgentEvaluationHashes.canonicalJson(
            token.auditContract.toCanonicalMap(),
          ) !=
          AgentEvaluationHashes.canonicalJson(custody.toCanonicalMap()) ||
      authority['custodyHash'] != token.auditContract.custodyHash ||
      authority['priceAuthorityTrustEntryHash'] !=
          token.auditContract.trustEntryHash) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release recovery custody binding changed',
    );
  }

  final capabilityRows = db.select(
    'SELECT * FROM eval_external_custody_capabilities',
  );
  final bindingRows = db.select(
    'SELECT * FROM eval_external_custody_receipt_bindings',
  );
  final firstReceiptRows = db.select(
    'SELECT authority_receipt_hash FROM eval_production_authority_receipts '
    'ORDER BY created_at_ms, trial_slot_id, attempt_no LIMIT 1',
  );
  final nonceHash = AgentEvaluationHashes.domainHash(
    'agent-evaluation-public-custody-nonce-v1',
    token.nonce,
  );
  if (capabilityRows.length != 1 ||
      bindingRows.length != 1 ||
      capabilityRows.single['capability_hash'] != token.capabilityHash ||
      capabilityRows.single['attestation_hash'] != token.attestationHash ||
      capabilityRows.single['verified_at_ms'] != token.verifiedAtMs ||
      capabilityRows.single['nonce_hash'] != nonceHash ||
      bindingRows.single['capability_hash'] != token.capabilityHash ||
      firstReceiptRows.length != 1 ||
      bindingRows.single['authority_receipt_hash'] !=
          firstReceiptRows.single['authority_receipt_hash']) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release recovery database custody capability is invalid',
    );
  }

  final claimHash = authority['productionHoldoutClaimHash'];
  if (claimHash is! String) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release recovery production claim is missing',
    );
  }
  final claimRows = db.select(
    'SELECT * FROM eval_production_holdout_claims WHERE claim_hash = ?',
    <Object?>[claimHash],
  );
  if (claimRows.length != 1) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release recovery production claim is ambiguous',
    );
  }
  try {
    final row = claimRows.single;
    final attestation = AgentEvaluationProductionHoldoutAttestation.fromStorage(
      payloadJson: row['payload_json'] as String,
      signatureBase64: row['signature_base64'] as String,
    );
    final importedAtMs = row['imported_at_ms'];
    final projection = AgentEvaluationProductionHoldoutProjection(
      executionSummary: _strictJsonObject(
        row['redacted_execution_summary_json'] as String,
      ),
      scorecard: _strictJsonObject(row['redacted_scorecard_json'] as String),
      gateVerdict: _strictJsonObject(
        row['redacted_gate_verdict_json'] as String,
      ),
    );
    final verifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: token.keyId,
      publicKey: token.publicKey,
      runnerReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
      resolverReleaseHash:
          AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
    );
    final verdictRows = db.select(
      '''SELECT v.champion_bundle_hash, v.challenger_bundle_hash,
           v.experiment_id, e.manifest_json
         FROM eval_release_gate_verdicts v
         JOIN eval_experiments e ON e.experiment_id = v.experiment_id
        WHERE v.verdict_hash = ? AND v.verdict_kind = 'regression'
          AND v.status = 'promote' ''',
      <Object?>[authority['regressionVerdictHash']],
    );
    final manifest = verdictRows.length == 1
        ? _strictJsonObject(verdictRows.single['manifest_json'] as String)
        : const <String, Object?>{};
    final manifestBudgets = manifest['budgets'];
    if (attestation.claimHash != claimHash ||
        importedAtMs is! int ||
        importedAtMs < attestation.issuedAtMs ||
        importedAtMs >= attestation.expiresAtMs ||
        !_productionClaimColumnsMatch(row, attestation) ||
        projection.executionSummaryHash !=
            attestation.redactedExecutionSummaryHash ||
        projection.scorecardHash != attestation.redactedScorecardHash ||
        projection.gateVerdictHash != attestation.redactedGateVerdictHash ||
        projection.result != attestation.result ||
        projection.executionSummary['releaseConfigurationHash'] !=
            authority['releaseConfigurationHash'] ||
        attestation.regressionVerdictHash !=
            authority['regressionVerdictHash'] ||
        attestation.privatePlanHash != authority['privatePlanHash'] ||
        attestation.opaqueHoldoutScenarioSetHash !=
            authority['opaqueScenarioSetHash'] ||
        verdictRows.length != 1 ||
        attestation.championBundleHash !=
            verdictRows.single['champion_bundle_hash'] ||
        attestation.challengerBundleHash !=
            verdictRows.single['challenger_bundle_hash'] ||
        manifestBudgets is! Map<String, Object?> ||
        manifestBudgets['releaseConfigurationHash'] !=
            authority['releaseConfigurationHash'] ||
        !await verifier.verifyProductionSignature(attestation)) {
      throw const FormatException('production claim verification failed');
    }
  } on Object {
    throw const AgentEvaluationReleaseCoordinatorException(
      'release recovery production holdout signature is invalid',
    );
  }
}

bool _productionClaimColumnsMatch(
  Row row,
  AgentEvaluationProductionHoldoutAttestation attestation,
) => <(Object?, Object?)>[
  (row['family_id'], attestation.familyId),
  (row['token_id'], attestation.tokenId),
  (row['access_id'], attestation.accessId),
  (row['regression_verdict_hash'], attestation.regressionVerdictHash),
  (row['champion_bundle_hash'], attestation.championBundleHash),
  (row['challenger_bundle_hash'], attestation.challengerBundleHash),
  (row['regression_scenario_set_hash'], attestation.regressionScenarioSetHash),
  (
    row['opaque_holdout_scenario_set_hash'],
    attestation.opaqueHoldoutScenarioSetHash,
  ),
  (row['private_plan_hash'], attestation.privatePlanHash),
  (row['production_manifest_hash'], attestation.productionManifestHash),
  (
    row['private_execution_summary_hash'],
    attestation.privateExecutionSummaryHash,
  ),
  (
    row['redacted_execution_summary_hash'],
    attestation.redactedExecutionSummaryHash,
  ),
  (row['private_scorecard_hash'], attestation.privateScorecardHash),
  (row['redacted_scorecard_hash'], attestation.redactedScorecardHash),
  (row['private_gate_verdict_hash'], attestation.privateGateVerdictHash),
  (row['redacted_gate_verdict_hash'], attestation.redactedGateVerdictHash),
  (row['private_projection_hash'], attestation.privateProjectionHash),
  (row['expected_cell_set_hash'], attestation.expectedCellSetHash),
  (row['expected_slot_set_hash'], attestation.expectedSlotSetHash),
  (row['execution_budget_policy_hash'], attestation.executionBudgetPolicyHash),
  (row['executor_release_hash'], attestation.executorReleaseHash),
  (row['evaluation_bundle_hash'], attestation.evaluationBundleHash),
  (row['price_table_hash'], attestation.priceTableHash),
  (row['gate_policy_hash'], attestation.gatePolicyHash),
  (row['audit_root_hash'], attestation.auditRootHash),
  (row['result'], attestation.result),
  (row['key_id'], attestation.keyId),
  (row['runner_release_hash'], attestation.runnerReleaseHash),
  (row['resolver_release_hash'], attestation.resolverReleaseHash),
  (row['issued_at_ms'], attestation.issuedAtMs),
  (row['expires_at_ms'], attestation.expiresAtMs),
].every((binding) => binding.$1 == binding.$2);

({
  List<Map<String, Object?>> partitions,
  int modelRouteCount,
  int scenarioCount,
  int armCount,
  int trialsPerCell,
  int cellCount,
  int slotCount,
  int productionReceiptCount,
  int providerCallCount,
  String regressionVerdictSetHash,
  String regressionScenarioSetHash,
  String sourceTreeHash,
})
_rederivePublicPartitionCriteria({
  required Database db,
  required Map<String, Object?> authority,
  required Map<String, Object?> decoded,
}) {
  final rawPartitions = authority['publicPartitions'];
  if (rawPartitions is! List<Object?> ||
      rawPartitions.isEmpty ||
      rawPartitions.any((item) => item is! Map<String, Object?>)) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria public partitions are missing',
    );
  }
  const partitionKeys = <String>{
    'modelRouteHash',
    'executionId',
    'manifestHash',
    'publicReportHash',
    'scorecardHash',
    'regressionVerdictHash',
    'regressionStatus',
    'cellCount',
    'slotCount',
    'productionReceiptCount',
    'providerCallCount',
  };
  final declared = rawPartitions.cast<Map<String, Object?>>();
  final partitionHashes = <String>{};
  final executionIds = <String>{};
  final coveredRoutes = <String>{};
  final rederived = <Map<String, Object?>>[];
  String? scenarioSetHash;
  String? sourceTreeHash;
  String? championBundleHash;
  String? challengerBundleHash;
  int? scenarioCount;
  int? armCount;
  int? trialsPerCell;
  var totalCells = 0;
  var totalSlots = 0;
  var totalReceipts = 0;
  var totalProviderCalls = 0;
  for (final descriptor in declared) {
    if (descriptor.keys.toSet().difference(partitionKeys).isNotEmpty ||
        partitionKeys.difference(descriptor.keys.toSet()).isNotEmpty) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria partition contract is invalid',
      );
    }
    final partitionHash = descriptor['modelRouteHash'];
    final executionId = descriptor['executionId'];
    if (partitionHash is! String ||
        executionId is! String ||
        !partitionHashes.add(partitionHash) ||
        !executionIds.add(executionId)) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria partitions are duplicated',
      );
    }
    final rows = db.select(
      '''SELECT v.*, e.manifest_json, e.manifest_hash,
                e.scenario_set_release_hash, s.scorecard_hash,
                s.aggregate_json
           FROM eval_release_gate_verdicts v
           JOIN eval_experiments e ON e.experiment_id = v.experiment_id
           JOIN eval_scorecards s ON s.execution_id = v.execution_id
          WHERE v.execution_id = ? AND v.verdict_kind = 'regression' ''',
      <Object?>[executionId],
    );
    if (rows.length != 1) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria partition authority is ambiguous',
      );
    }
    final row = rows.single;
    final manifest = _strictJsonObject(row['manifest_json'] as String);
    final aggregate = _strictJsonObject(row['aggregate_json'] as String);
    final counts = aggregate['counts'];
    final isolation = manifest['trialIsolationPolicy'];
    final budgets = manifest['budgets'];
    final routes = manifest['modelRouteHashes'];
    final bundles = manifest['generationBundleHashes'];
    if (counts is! Map<String, Object?> ||
        isolation is! Map<String, Object?> ||
        budgets is! Map<String, Object?> ||
        routes is! List<Object?> ||
        bundles is! List<Object?> ||
        routes.isEmpty ||
        routes.any((route) => route is! String) ||
        routes.toSet().length != routes.length ||
        coveredRoutes.intersection(routes.cast<String>().toSet()).isNotEmpty ||
        partitionHash != manifest['providerConfigHashWithoutSecrets'] ||
        budgets['releaseConfigurationHash'] !=
            authority['releaseConfigurationHash'] ||
        manifest['priceTableHash'] != authority['priceTableReleaseHash'] ||
        descriptor['manifestHash'] != row['manifest_hash'] ||
        descriptor['publicReportHash'] != aggregate['reportHash'] ||
        descriptor['scorecardHash'] != row['scorecard_hash'] ||
        descriptor['regressionVerdictHash'] != row['verdict_hash'] ||
        descriptor['regressionStatus'] != 'promote' ||
        row['status'] != 'promote') {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria partition is not DB-derived promote evidence',
      );
    }
    coveredRoutes.addAll(routes.cast<String>());
    final cellCount =
        db.select(
              'SELECT COUNT(*) AS count FROM eval_experiment_cells '
              'WHERE experiment_id = ?',
              <Object?>[row['experiment_id']],
            ).single['count']
            as int;
    final slotCount =
        db.select(
              'SELECT COUNT(*) AS count FROM eval_trial_slots '
              'WHERE execution_id = ?',
              <Object?>[executionId],
            ).single['count']
            as int;
    final receiptCount =
        db
                .select(
                  '''SELECT COUNT(*) AS count
               FROM eval_production_authority_receipts r
               JOIN eval_trial_slots s ON s.trial_slot_id = r.trial_slot_id
              WHERE s.execution_id = ?''',
                  <Object?>[executionId],
                )
                .single['count']
            as int;
    final providerCalls = counts['providerCalls'];
    if (providerCalls is! int ||
        counts['slots'] != slotCount ||
        counts['productionReceipts'] != receiptCount ||
        descriptor['cellCount'] != cellCount ||
        descriptor['slotCount'] != slotCount ||
        descriptor['productionReceiptCount'] != receiptCount ||
        descriptor['providerCallCount'] != providerCalls ||
        slotCount != receiptCount) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria partition matrix is incomplete',
      );
    }
    final rowScenarioSetHash = row['scenario_set_release_hash'] as String;
    final rowSourceTreeHash = manifest['sourceTreeHash'] as String?;
    final rowChampion = row['champion_bundle_hash'] as String;
    final rowChallenger = row['challenger_bundle_hash'] as String;
    final rowScenarioCount = isolation['scenarioCount'] as int?;
    final rowTrialsPerCell = manifest['trialsPerCell'] as int?;
    if (rowSourceTreeHash == null ||
        rowScenarioCount == null ||
        rowTrialsPerCell == null ||
        (scenarioSetHash != null && scenarioSetHash != rowScenarioSetHash) ||
        (sourceTreeHash != null && sourceTreeHash != rowSourceTreeHash) ||
        (championBundleHash != null && championBundleHash != rowChampion) ||
        (challengerBundleHash != null &&
            challengerBundleHash != rowChallenger) ||
        (scenarioCount != null && scenarioCount != rowScenarioCount) ||
        (armCount != null && armCount != bundles.length) ||
        (trialsPerCell != null && trialsPerCell != rowTrialsPerCell)) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria partitions disagree on frozen matrix authority',
      );
    }
    scenarioSetHash ??= rowScenarioSetHash;
    sourceTreeHash ??= rowSourceTreeHash;
    championBundleHash ??= rowChampion;
    challengerBundleHash ??= rowChallenger;
    scenarioCount ??= rowScenarioCount;
    armCount ??= bundles.length;
    trialsPerCell ??= rowTrialsPerCell;
    totalCells += cellCount;
    totalSlots += slotCount;
    totalReceipts += receiptCount;
    totalProviderCalls += providerCalls;
    rederived.add(<String, Object?>{
      'modelRouteHash': partitionHash,
      'executionId': executionId,
      'manifestHash': row['manifest_hash'],
      'publicReportHash': aggregate['reportHash'],
      'scorecardHash': row['scorecard_hash'],
      'regressionVerdictHash': row['verdict_hash'],
      'regressionStatus': row['status'],
      'cellCount': cellCount,
      'slotCount': slotCount,
      'productionReceiptCount': receiptCount,
      'providerCallCount': providerCalls,
    });
  }
  rederived.sort(
    (left, right) => (left['modelRouteHash']! as String).compareTo(
      right['modelRouteHash']! as String,
    ),
  );
  if (AgentEvaluationHashes.canonicalJson(declared) !=
          AgentEvaluationHashes.canonicalJson(rederived) ||
      authority['regressionVerdictHash'] !=
          rederived.first['regressionVerdictHash'] ||
      authority['releaseConfigurationHash'] == null ||
      decoded['regressionStatus'] != 'promote') {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria partition commitment changed',
    );
  }
  final verdictSetHash = AgentEvaluationHashes.domainHash(
    'agent-evaluation-regression-verdict-set-v1',
    <Object?>[
      for (final partition in rederived) partition['regressionVerdictHash'],
    ],
  );
  if (authority['regressionVerdictSetHash'] != verdictSetHash) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria verdict set commitment changed',
    );
  }
  return (
    partitions: List<Map<String, Object?>>.unmodifiable(rederived),
    modelRouteCount: coveredRoutes.length,
    scenarioCount: scenarioCount!,
    armCount: armCount!,
    trialsPerCell: trialsPerCell!,
    cellCount: totalCells,
    slotCount: totalSlots,
    productionReceiptCount: totalReceipts,
    providerCallCount: totalProviderCalls,
    regressionVerdictSetHash: verdictSetHash,
    regressionScenarioSetHash: scenarioSetHash!,
    sourceTreeHash: sourceTreeHash!,
  );
}

void _verifyProductionCriteriaEvidence({
  required Database db,
  required File reportFile,
  required Map<String, Object?> decoded,
  required AgentEvaluationSpecCriteriaRegistrySeal criteriaSeal,
  required AgentEvaluationVerifiedProductionCustodyToken custodyToken,
  required AgentEvaluationSpecCriteriaRegistrySeal?
  verifiedBaselineCriteriaSeal,
  required Map<String, Object?> combinedBudgetEvidence,
  required Row finalSealRow,
}) {
  final commitment = decoded['productionCriteriaEvidence'];
  final authority = decoded['authority'];
  if (commitment is! Map<String, Object?> ||
      authority is! Map<String, Object?> ||
      commitment.keys.toSet().difference(const <String>{
        'artifactPath',
        'artifactHash',
        'reportHash',
        'baselineCriteriaSealHash',
        'criterionReportHashes',
      }).isNotEmpty ||
      const <String>{
        'artifactPath',
        'artifactHash',
        'reportHash',
        'baselineCriteriaSealHash',
        'criterionReportHashes',
      }.difference(commitment.keys.toSet()).isNotEmpty) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria commitment is invalid',
    );
  }
  final realEntries = criteriaSeal.registry.entries
      .where(
        (entry) => AgentEvaluationSpecCriteriaRegistry.realProviderCriteriaIds
            .contains(entry.criteriaId),
      )
      .toList(growable: false);
  if (realEntries.length != 5 ||
      realEntries.any(
        (entry) =>
            entry.artifactPath != commitment['artifactPath'] ||
            entry.artifactHash != commitment['artifactHash'] ||
            entry.sourceTreeHash != realEntries.first.sourceTreeHash ||
            entry.evidenceLevel !=
                AgentEvaluationSpecEvidenceLevel.realProviderRelease ||
            entry.status != AgentEvaluationSpecCriteriaStatus.passed ||
            entry.exitCode != 0,
      )) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria registry entries are invalid',
    );
  }
  final artifactPath = realEntries.first.artifactPath;
  final artifactFile = File('${reportFile.parent.path}/$artifactPath').absolute;
  final reportRoot =
      '${reportFile.parent.absolute.path}${Platform.pathSeparator}';
  if (!artifactFile.path.startsWith(reportRoot) ||
      FileSystemEntity.typeSync(artifactFile.path, followLinks: false) !=
          FileSystemEntityType.file ||
      _sha256File(artifactFile) != commitment['artifactHash']) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria artifact is unavailable or modified',
    );
  }
  final artifact = _strictJsonObject(artifactFile.readAsStringSync());
  const artifactKeys = <String>{
    'schemaVersion',
    'sourceTreeHash',
    'baselineCriteriaSeal',
    'baselineCriteriaSealHash',
    'criterionFacts',
    'criterionReportHashes',
    'reportHash',
  };
  final artifactPayload = <String, Object?>{...artifact}..remove('reportHash');
  final rawBaseline = artifact['baselineCriteriaSeal'];
  final rawFacts = artifact['criterionFacts'];
  final rawReportHashes = artifact['criterionReportHashes'];
  if (artifact.keys.toSet().difference(artifactKeys).isNotEmpty ||
      artifactKeys.difference(artifact.keys.toSet()).isNotEmpty ||
      artifact['schemaVersion'] !=
          'agent-evaluation-production-criteria-evidence-v1' ||
      artifact['reportHash'] != commitment['reportHash'] ||
      artifact['reportHash'] !=
          AgentEvaluationHashes.domainHash(
            'agent-evaluation-production-criteria-evidence-v1',
            artifactPayload,
          ) ||
      rawBaseline is! Map<String, Object?> ||
      rawFacts is! Map<String, Object?> ||
      rawReportHashes is! Map<String, Object?> ||
      AgentEvaluationHashes.canonicalJson(rawReportHashes) !=
          AgentEvaluationHashes.canonicalJson(
            commitment['criterionReportHashes'],
          )) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria artifact contract is invalid',
    );
  }
  late final AgentEvaluationSpecCriteriaRegistrySeal baselineSeal;
  try {
    baselineSeal = AgentEvaluationSpecCriteriaRegistrySeal.fromCanonicalJson(
      AgentEvaluationHashes.canonicalJson(rawBaseline),
    );
    baselineSeal.registry.requireProductionBaseline(
      sourceTreeHash: artifact['sourceTreeHash']! as String,
    );
  } on Object {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria baseline cannot authorize this release',
    );
  }
  if (baselineSeal.sealHash != artifact['baselineCriteriaSealHash'] ||
      baselineSeal.sealHash != commitment['baselineCriteriaSealHash'] ||
      baselineSeal.sealHash != custodyToken.baselineCriteriaSealHash ||
      artifact['sourceTreeHash'] != custodyToken.baselineSourceTreeHash) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria baseline binding changed',
    );
  }
  if (verifiedBaselineCriteriaSeal == null ||
      AgentEvaluationHashes.canonicalJson(
            verifiedBaselineCriteriaSeal.toCanonicalMap(),
          ) !=
          AgentEvaluationHashes.canonicalJson(baselineSeal.toCanonicalMap())) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria artifacts were not reverified for recovery',
    );
  }

  final claimRows = db.select(
    'SELECT * FROM eval_production_holdout_claims WHERE claim_hash = ?',
    <Object?>[authority['productionHoldoutClaimHash']],
  );
  if (claimRows.length != 1) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria database authorities are ambiguous',
    );
  }
  final claim = claimRows.single;
  final publicCriteria = _rederivePublicPartitionCriteria(
    db: db,
    authority: authority,
    decoded: decoded,
  );
  final baselineVerification = baselineSeal.registry.entries.singleWhere(
    (entry) => entry.criteriaId == 'AEE-24',
  );
  final holdoutReuse = AgentEvaluationHoldoutReuseAuthority.read(
    db: db,
    claimHash: authority['productionHoldoutClaimHash']! as String,
  ).toReportMap();
  final facts = <String, Map<String, Object?>>{
    'AEE-14': <String, Object?>{
      'publicReportHash': decoded['publicReportHash'],
      'regressionVerdictSetHash': publicCriteria.regressionVerdictSetHash,
      'regressionStatus': 'promote',
      'modelPartitionCount': publicCriteria.partitions.length,
      'partitions': publicCriteria.partitions,
      'completedSlotCount': publicCriteria.slotCount,
      'productionReceiptCount': publicCriteria.productionReceiptCount,
      'providerCallCount': publicCriteria.providerCallCount,
    },
    'AEE-15': <String, Object?>{
      'scenarioCount': publicCriteria.scenarioCount,
      'armCount': publicCriteria.armCount,
      'trialsPerCell': publicCriteria.trialsPerCell,
      'modelRouteCount': publicCriteria.modelRouteCount,
      'modelPartitionCount': publicCriteria.partitions.length,
      'cellCount': publicCriteria.cellCount,
      'slotCount': publicCriteria.slotCount,
      'productionReceiptCount': publicCriteria.productionReceiptCount,
    },
    'AEE-18': <String, Object?>{
      'productionHoldoutClaimHash': claim['claim_hash'],
      'productionHoldoutResult': claim['result'],
      'holdoutImportedAtMs': claim['imported_at_ms'],
      'holdoutIssuedAtMs': claim['issued_at_ms'],
      'holdoutExpiresAtMs': claim['expires_at_ms'],
      'custodyCapabilityHash': custodyToken.capabilityHash,
      'custodyAttestationHash': custodyToken.attestationHash,
      'custodyHash': custodyToken.auditContract.custodyHash,
      'holdoutReuseAuthority': holdoutReuse,
    },
    'AEE-23': <String, Object?>{
      'regressionScenarioSetHash': publicCriteria.regressionScenarioSetHash,
      'opaqueHoldoutScenarioSetHash': claim['opaque_holdout_scenario_set_hash'],
      'modelRouteCount': publicCriteria.modelRouteCount,
      'modelPartitionCount': publicCriteria.partitions.length,
      'expectedPublicCellCount': publicCriteria.cellCount,
      'expectedPublicSlotCount': publicCriteria.slotCount,
      'completedPublicSlotCount': publicCriteria.productionReceiptCount,
      'privateExpectedCellSetHash': claim['expected_cell_set_hash'],
      'privateExpectedSlotSetHash': claim['expected_slot_set_hash'],
      'productionHoldoutClaimHash': claim['claim_hash'],
    },
    'AEE-24': <String, Object?>{
      'baselineCriteriaSealHash': baselineSeal.sealHash,
      'baselineVerificationArtifactPath': baselineVerification.artifactPath,
      'baselineVerificationArtifactHash': baselineVerification.artifactHash,
      'baselineVerificationReportHash': baselineVerification.reportHash,
      'sourceTreeHash': publicCriteria.sourceTreeHash,
      'publicReportHash': decoded['publicReportHash'],
      'combinedBudgetEvidenceHash': AgentEvaluationHashes.domainHash(
        'agent-evaluation-combined-budget-evidence-v1',
        combinedBudgetEvidence,
      ),
      'productionHoldoutClaimHash': claim['claim_hash'],
      'promotionDecisionHash': _decisionHash(
        db,
        finalSealRow['promotion_decision_id'] as String,
      ),
      'rollbackDecisionHash': _decisionHash(
        db,
        finalSealRow['rollback_decision_id'] as String,
      ),
      'finalChannelEpoch': 2,
    },
  };
  if (AgentEvaluationHashes.canonicalJson(rawFacts) !=
      AgentEvaluationHashes.canonicalJson(facts)) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria facts are not database-derived',
    );
  }
  final reportHashes = <String, String>{
    for (final entry in facts.entries)
      entry.key: AgentEvaluationHashes.domainHash(
        'agent-evaluation-production-criterion-${entry.key.toLowerCase()}-v1',
        entry.value,
      ),
  };
  if (AgentEvaluationHashes.canonicalJson(rawReportHashes) !=
          AgentEvaluationHashes.canonicalJson(reportHashes) ||
      realEntries.any(
        (entry) => entry.reportHash != reportHashes[entry.criteriaId],
      )) {
    throw const AgentEvaluationReleaseCoordinatorException(
      'production criteria report hashes are not authoritative',
    );
  }
  final baselineLocalEntries = baselineSeal.registry.entries.where(
    (entry) => !AgentEvaluationSpecCriteriaRegistry.realProviderCriteriaIds
        .contains(entry.criteriaId),
  );
  for (final baselineEntry in baselineLocalEntries) {
    final finalEntry = criteriaSeal.registry.entries.singleWhere(
      (entry) => entry.criteriaId == baselineEntry.criteriaId,
    );
    if (AgentEvaluationHashes.canonicalJson(finalEntry.toCanonicalMap()) !=
        AgentEvaluationHashes.canonicalJson(baselineEntry.toCanonicalMap())) {
      throw const AgentEvaluationReleaseCoordinatorException(
        'production criteria changed a signed baseline result',
      );
    }
  }
}
