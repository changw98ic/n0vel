import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_private_holdout_runtime.dart' as private_runtime;
import 'features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_private_holdout.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_private_holdout_runner.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_real_release_harness.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_release_coordinator.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_release_supervisor.dart'
    as release_supervisor;
import 'features/story_generation/data/evaluation/agent_evaluation_sandbox_seal_verifier.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_supervisor_connection.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_spec_evidence.dart';

const agentEvaluationReleaseSupervisorMarker =
    '--novel-writer-agent-evaluation-release-supervisor-v1';

/// Unified fixed release binary. The same prebuilt artifact runs the public
/// coordinator and, in a separate process, the private holdout branch. This
/// prevents an authorized workflow from rebuilding or switching executables.
Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 &&
      arguments.single == agentEvaluationReleaseSupervisorMarker) {
    await release_supervisor.runAgentEvaluationReleaseSupervisor(
      const <String>[],
    );
    await stdout.flush();
    await stderr.flush();
    exit(exitCode);
  }
  if (arguments.any(
    (argument) => argument.startsWith(
      '--novel-writer-agent-evaluation-release-supervisor',
    ),
  )) {
    stderr.writeln('invalid release supervisor arguments');
    await stderr.flush();
    exit(64);
  }
  final verifierExitCode = runAgentEvaluationSealVerifierCommand(arguments);
  if (verifierExitCode != null) {
    await stdout.flush();
    await stderr.flush();
    exit(verifierExitCode);
  }
  final environment = Platform.environment;
  AgentEvaluationSupervisorConnection? supervisor;
  var failureStage = 'bootstrap';
  try {
    supervisor = await AgentEvaluationSupervisorConnection.connect(environment);
    if (environment['AGENT_EVAL_PRIVATE_RUNTIME_BOOTSTRAPPED'] == '1') {
      await private_runtime.main();
      await supervisor.closeNormally();
      return;
    }
    if (environment['AGENT_EVAL_RELEASE_COORDINATOR_BOOTSTRAPPED'] != '1' ||
        environment['RUN_REAL_AGENT_EVAL'] != '1' ||
        environment['REAL_LLM_COST_ACK'] != 'YES') {
      throw StateError('release coordinator runtime was not bootstrapped');
    }
    failureStage = 'flutter-binding';
    WidgetsFlutterBinding.ensureInitialized();
    String value(String name) {
      final result = (environment[name] ?? '').trim();
      if (result.isEmpty) throw StateError('release coordinator input missing');
      return result;
    }

    final phase = value('AGENT_EVAL_RELEASE_COORDINATOR_PHASE');
    if (phase != 'public-only' && phase != 'complete') {
      throw StateError('release coordinator phase is invalid');
    }

    failureStage = 'configuration';
    final configuration =
        agentEvaluationRealReleaseConfigurationFromEnvironment(environment);
    final publicCustodyCapability = await _verifyPublicCustodyCapability(
      environment: environment,
      configuration: configuration,
    );
    final baselineCriteriaSeal =
        loadAndVerifyAgentEvaluationProductionCriteriaBaseline(
          sealPath: value('AGENT_EVAL_BASELINE_CRITERIA_SEAL'),
          sourceTreeHash: configuration.sourceTreeHash,
        );
    if (publicCustodyCapability.baselineCriteriaSealHash !=
            baselineCriteriaSeal.sealHash ||
        publicCustodyCapability.baselineSourceTreeHash !=
            configuration.sourceTreeHash) {
      throw StateError(
        'public custody capability does not authorize the criteria baseline',
      );
    }
    late final AgentEvaluationRealReleaseResult publicResult;
    late final Map<String, Object?> publicCommitments;
    if (phase == 'public-only') {
      failureStage = 'public-harness';
      final publicHarness = AgentEvaluationRealReleaseHarness.realProvider(
        configuration: configuration,
        outputDirectory: Directory(value('AGENT_EVAL_PUBLIC_REPORT_DIR')),
        workDirectory: Directory(value('AGENT_EVAL_PUBLIC_WORK_DIR')),
        releaseBudgetDirectory: Directory(
          value('AGENT_EVAL_RELEASE_BUDGET_DIR'),
        ),
        publicCustodyCapability: publicCustodyCapability,
      );
      try {
        try {
          publicResult = await publicHarness.run();
          failureStage = 'public-harness-completed';
        } on Object {
          failureStage = 'public-harness-failed';
          rethrow;
        }
      } finally {
        publicHarness.dispose();
      }
      failureStage = 'public-commitments';
      publicCommitments = _publicCommitments(
        configuration: configuration,
        result: publicResult,
      );
    } else {
      failureStage = 'public-recovery';
      final recovered = recoverAgentEvaluationPublicCapability(
        environment: environment,
        configuration: configuration,
        realProviderEvidence: true,
      );
      publicResult = recovered.result;
      publicCommitments = recovered.commitments;
    }
    _verifyPublicCustodyBinding(
      result: publicResult,
      capability: publicCustodyCapability,
    );
    if (phase == 'public-only') {
      stdout.write(AgentEvaluationHashes.canonicalJson(publicCommitments));
      await stdout.flush();
      await supervisor.closeNormally();
      return;
    }
    stdout.writeln(
      AgentEvaluationHashes.canonicalJson(<String, Object?>{
        'schemaVersion': 'agent-evaluation-release-coordinator-phase2-ready-v1',
        'publicCommitmentsHash': AgentEvaluationHashes.domainHash(
          'agent-evaluation-public-release-commitments-v1',
          publicCommitments,
        ),
      }),
    );
    await stdout.flush();
    failureStage = 'private-capability';
    final brokerInput = StreamIterator<String>(
      utf8.decoder.bind(stdin).transform(const LineSplitter()),
    );
    if (!await brokerInput.moveNext().timeout(const Duration(seconds: 30)) ||
        utf8.encode(brokerInput.current).length > 64 * 1024) {
      throw StateError('private deployment capability is missing');
    }
    final privateDeployment = _strictObject(brokerInput.current);
    const capabilityKeys = <String>{
      'schemaVersion',
      'signingMode',
      'privateTimeoutMs',
      'privatePlanHash',
      'opaqueScenarioSetHash',
      'keyId',
      'publicKeyBase64',
      'signerCommandIdentityHash',
      'custodyAttestationPayloadJson',
      'custodyAttestationSignatureBase64',
      'verifiedAtMs',
      'nonce',
      'capabilityHash',
    };
    if (privateDeployment.keys.toSet().difference(capabilityKeys).isNotEmpty ||
        capabilityKeys.difference(privateDeployment.keys.toSet()).isNotEmpty ||
        privateDeployment['schemaVersion'] !=
            'agent-evaluation-private-broker-capability-v1' ||
        privateDeployment['signingMode'] != 'external-command-v1') {
      throw StateError('private deployment capability is invalid');
    }
    String privateValue(String name) {
      final result = (privateDeployment[name] as String?)?.trim() ?? '';
      if (result.isEmpty) throw StateError('private deployment input missing');
      return result;
    }

    final publicKeyBytes = base64Decode(privateValue('publicKeyBase64'));
    if (publicKeyBytes.length != 32) {
      throw StateError('release coordinator public key is invalid');
    }
    final timeoutMs = int.parse(privateValue('privateTimeoutMs'));
    if (timeoutMs <= 0) throw StateError('private timeout is invalid');
    final capabilityPayload = <String, Object?>{...privateDeployment}
      ..remove('capabilityHash');
    final capabilityHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-private-broker-capability-v1',
      capabilityPayload,
    );
    if (privateDeployment['capabilityHash'] != capabilityHash ||
        privateDeployment['verifiedAtMs'] is! int ||
        privateDeployment['nonce'] is! String) {
      throw StateError('private deployment capability hash is invalid');
    }
    final signingPublicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    final privateCommitment =
        AgentEvaluationPrivateReleaseCommitment.externalSigner(
          privatePlanHash: privateValue('privatePlanHash'),
          opaqueScenarioSetHash: privateValue('opaqueScenarioSetHash'),
          keyId: privateValue('keyId'),
          publicKey: signingPublicKey,
          externalSigningCapability:
              AgentEvaluationExternalReleaseSigningCapability(
                keyId: privateValue('keyId'),
                publicKey: signingPublicKey,
                signerCommandIdentityHash: privateValue(
                  'signerCommandIdentityHash',
                ),
                custodyAttestationPayloadJson: privateValue(
                  'custodyAttestationPayloadJson',
                ),
                custodyAttestationSignatureBase64: privateValue(
                  'custodyAttestationSignatureBase64',
                ),
              ),
        );
    failureStage = 'private-coordinator';
    final coordinator = AgentEvaluationReleaseCoordinator.production(
      coordinatorRunId: value('AGENT_EVAL_COORDINATOR_RUN_ID'),
      publicResult: publicResult,
      privateCommitment: privateCommitment,
      workDirectory: Directory(value('AGENT_EVAL_COORDINATOR_WORK_DIR')),
      reportDirectory: Directory(value('AGENT_EVAL_COORDINATOR_REPORT_DIR')),
      channel: value('AGENT_EVAL_RELEASE_CHANNEL'),
      approver: value('AGENT_EVAL_RELEASE_APPROVER'),
      processTimeout: Duration(milliseconds: timeoutMs),
      custodyToken: publicCustodyCapability,
      combinedBudgetEvidenceReader: () =>
          readAgentEvaluationCombinedReleaseBudgetEvidence(
            configuration: configuration,
            releaseBudgetDirectory: Directory(
              value('AGENT_EVAL_RELEASE_BUDGET_DIR'),
            ),
            minimumProviderCalls:
                publicResult.partitions.fold<int>(
                  0,
                  (sum, partition) => sum + partition.providerCallCount,
                ) +
                configuration.expectedSlots,
            minimumJudgeCalls: configuration.expectedSlots * 2,
          ),
      baselineCriteriaSeal: baselineCriteriaSeal,
      requiredModelRouteHashes: configuration.sutRoutes.map(
        (route) => route.modelRouteHash,
      ),
      privateRunnerBroker:
          ({required authorityDatabasePath, required accessId}) async {
            final requestId = AgentEvaluationHashes.domainHash(
              'agent-evaluation-private-broker-request-v1',
              <String, Object?>{
                'capabilityHash': capabilityHash,
                'accessId': accessId,
                'authorityPathHash': AgentEvaluationHashes.domainHash(
                  'agent-evaluation-private-authority-path-v1',
                  authorityDatabasePath,
                ),
              },
            );
            stdout.writeln(
              AgentEvaluationHashes.canonicalJson(<String, Object?>{
                'schemaVersion': 'agent-evaluation-private-broker-request-v1',
                'requestId': requestId,
                'capabilityHash': capabilityHash,
                'accessId': accessId,
                'authorityDatabasePath': authorityDatabasePath,
              }),
            );
            await stdout.flush();
            if (!await brokerInput.moveNext().timeout(
                  Duration(milliseconds: timeoutMs),
                ) ||
                utf8.encode(brokerInput.current).length > 600 * 1024) {
              throw StateError('private broker response is missing');
            }
            final envelope = _strictObject(brokerInput.current);
            if (envelope.length != 4 ||
                envelope['schemaVersion'] !=
                    'agent-evaluation-private-broker-response-v1' ||
                envelope['requestId'] != requestId ||
                envelope['responseJson'] is! String ||
                envelope['responseHash'] !=
                    AgentEvaluationHashes.domainHash(
                      'agent-evaluation-private-broker-response-v1',
                      <String, Object?>{
                        'requestId': requestId,
                        'responseJson': envelope['responseJson'],
                      },
                    )) {
              throw StateError('private broker response is invalid');
            }
            return envelope['responseJson']! as String;
          },
    );
    final result = await coordinator.run();
    stdout.writeln(
      AgentEvaluationHashes.canonicalJson(<String, Object?>{
        'schemaVersion': 'agent-evaluation-release-coordinator-response-v1',
        'releaseEligible': result.releaseEligible,
        'realProviderEvidence': result.realProviderEvidence,
        'reportPath': result.reportPath,
        'reportHash': result.reportHash,
      }),
    );
    await supervisor.closeNormally();
    exit(result.releaseEligible ? 0 : 2);
  } catch (_) {
    await supervisor?.closeNormally();
    stderr.writeln(
      'agent evaluation release coordinator failed at $failureStage',
    );
    exit(2);
  }
}

Future<AgentEvaluationVerifiedProductionCustodyToken>
_verifyPublicCustodyCapability({
  required Map<String, String> environment,
  required AgentEvaluationRealReleaseConfiguration configuration,
}) async {
  final source =
      (environment['AGENT_EVAL_PUBLIC_CUSTODY_CAPABILITY_JSON'] ?? '').trim();
  final value = _strictObject(source);
  const keys = <String>{
    'schemaVersion',
    'keyId',
    'publicKeyBase64',
    'signerCommandIdentityHash',
    'custodyAttestationPayloadJson',
    'custodyAttestationSignatureBase64',
    'verifiedAtMs',
    'nonce',
    'capabilityHash',
  };
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty ||
      value['schemaVersion'] !=
          'agent-evaluation-public-custody-capability-v1' ||
      value['keyId'] is! String ||
      value['publicKeyBase64'] is! String ||
      value['signerCommandIdentityHash'] is! String ||
      value['custodyAttestationPayloadJson'] is! String ||
      value['custodyAttestationSignatureBase64'] is! String ||
      value['verifiedAtMs'] is! int ||
      value['nonce'] is! String ||
      value['capabilityHash'] is! String) {
    throw StateError('public custody capability is invalid');
  }
  final payload = <String, Object?>{...value}..remove('capabilityHash');
  final capabilityHash = AgentEvaluationHashes.domainHash(
    'agent-evaluation-public-custody-capability-v1',
    payload,
  );
  if (value['capabilityHash'] != capabilityHash) {
    throw StateError('public custody capability hash is invalid');
  }
  final publicKeyBytes = base64Decode(value['publicKeyBase64']! as String);
  if (publicKeyBytes.length != 32) {
    throw StateError('public custody signing key is invalid');
  }
  final privateTimeoutMs = int.parse(
    environment['AGENT_EVAL_PRIVATE_TIMEOUT_MS']!,
  );
  return AgentEvaluationVerifiedProductionCustodyToken.verifyProductionCapability(
    capabilityHash: capabilityHash,
    verifiedAtMs: value['verifiedAtMs']! as int,
    nonce: value['nonce']! as String,
    keyId: value['keyId']! as String,
    publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
    signerCommandIdentityHash: value['signerCommandIdentityHash']! as String,
    runnerArtifactHash:
        AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
    payloadJson: value['custodyAttestationPayloadJson']! as String,
    signatureBase64: value['custodyAttestationSignatureBase64']! as String,
    nowMs: DateTime.now().millisecondsSinceEpoch,
    minimumRemainingTtl:
        configuration.deadline +
        Duration(milliseconds: privateTimeoutMs) +
        const Duration(minutes: 2),
  );
}

void _verifyPublicCustodyBinding({
  required AgentEvaluationRealReleaseResult result,
  required AgentEvaluationPublicCustodyBinding capability,
}) {
  final db = sqlite3.open(
    result.authorityDatabasePath,
    mode: OpenMode.readOnly,
  );
  try {
    final capabilities = db.select(
      'SELECT * FROM eval_external_custody_capabilities',
    );
    final bindings = db.select(
      'SELECT * FROM eval_external_custody_receipt_bindings',
    );
    if (capabilities.length != 1 ||
        bindings.length != 1 ||
        capabilities.single['capability_hash'] != capability.capabilityHash ||
        capabilities.single['attestation_hash'] != capability.attestationHash ||
        capabilities.single['verified_at_ms'] != capability.verifiedAtMs ||
        capabilities.single['nonce_hash'] !=
            AgentEvaluationHashes.domainHash(
              'agent-evaluation-public-custody-nonce-v1',
              capability.nonce,
            ) ||
        bindings.single['capability_hash'] != capability.capabilityHash ||
        bindings.single['authority_receipt_hash'] == null) {
      throw StateError('public custody capability is not receipt-bound');
    }
  } on SqliteException {
    throw StateError('public custody capability binding is unavailable');
  } finally {
    db.dispose();
  }
}

({AgentEvaluationRealReleaseResult result, Map<String, Object?> commitments})
recoverAgentEvaluationPublicCapability({
  required Map<String, String> environment,
  required AgentEvaluationRealReleaseConfiguration configuration,
  required bool realProviderEvidence,
}) {
  final path = (environment['AGENT_EVAL_PUBLIC_CAPABILITY_PATH'] ?? '').trim();
  final expectedHash = (environment['AGENT_EVAL_PUBLIC_CAPABILITY_HASH'] ?? '')
      .trim();
  final expectedPath = File(
    '${environment['AGENT_EVAL_COORDINATOR_WORK_DIR']}/'
    'public-capability-${configuration.executionId}.json',
  ).absolute.path;
  final file = File(path).absolute;
  if (path.isEmpty ||
      file.path != expectedPath ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash) ||
      FileSystemEntity.typeSync(file.path, followLinks: false) !=
          FileSystemEntityType.file ||
      (!Platform.isWindows && (file.statSync().mode & 0x1ff) != 0x180)) {
    throw StateError('public release capability is not frozen');
  }
  final envelope = _strictObject(file.readAsStringSync());
  final commitmentsValue = envelope['publicCommitments'];
  if (envelope.length != 3 ||
      envelope['schemaVersion'] !=
          'agent-evaluation-public-release-capability-v1' ||
      commitmentsValue is! Map<String, Object?> ||
      envelope['publicCommitmentsHash'] != expectedHash ||
      AgentEvaluationHashes.domainHash(
            'agent-evaluation-public-release-commitments-v1',
            commitmentsValue,
          ) !=
          expectedHash ||
      AgentEvaluationHashes.canonicalJson(
            commitmentsValue['releaseConfiguration'],
          ) !=
          AgentEvaluationHashes.canonicalJson(
            configuration.toCanonicalReleaseConfiguration(),
          )) {
    throw StateError('public release capability contradicts configuration');
  }
  final reportPath = commitmentsValue['publicReportPath'];
  final authorityPath = commitmentsValue['authorityDatabasePath'];
  if (reportPath is! String || authorityPath is! String) {
    throw StateError('public release capability paths are invalid');
  }
  final reportDecoded = jsonDecode(File(reportPath).readAsStringSync());
  if (reportDecoded is! Map<String, Object?> ||
      reportDecoded['schemaVersion'] !=
          'agent-evaluation-real-release-report-v1' ||
      reportDecoded['claimScope'] != 'real-provider-release' ||
      reportDecoded['realProviderEvidence'] != realProviderEvidence ||
      reportDecoded['trustedHoldoutConfirmed'] != false ||
      reportDecoded['releaseEligible'] != false ||
      reportDecoded['partitions'] is! List<Object?> ||
      (reportDecoded['partitions']! as List<Object?>).isEmpty ||
      (reportDecoded['partitions']! as List<Object?>).any(
        (partition) => partition is! Map<String, Object?>,
      )) {
    throw StateError('public release capability report is invalid');
  }
  final partitions = (reportDecoded['partitions']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final result = AgentEvaluationRealReleaseResult(
    claimScope: 'real-provider-release',
    releaseEligible: false,
    realProviderEvidence: realProviderEvidence,
    trustedHoldoutConfirmed: false,
    partitions: <AgentEvaluationRealReleasePartitionResult>[
      for (final partition in partitions)
        AgentEvaluationRealReleasePartitionResult(
          modelRouteHash: partition['modelRouteHash']! as String,
          executionId: partition['executionId']! as String,
          manifestHash: partition['manifestHash']! as String,
          publicReportHash: partition['publicReportHash']! as String,
          scorecardHash: partition['scorecardHash']! as String,
          regressionVerdictHash: partition['regressionVerdictHash']! as String,
          regressionStatus: partition['regressionStatus']! as String,
          cellCount: partition['cellCount']! as int,
          slotCount: partition['slotCount']! as int,
          productionReceiptCount: partition['productionReceiptCount']! as int,
          providerCallCount: partition['providerCallCount']! as int,
        ),
    ],
    reportPath: File(reportPath).absolute.path,
    authorityDatabasePath: File(authorityPath).absolute.path,
    releaseConfigurationHash: configuration.releaseConfigurationHash,
  );
  final rebuilt = _publicCommitments(
    configuration: configuration,
    result: result,
  );
  if (AgentEvaluationHashes.canonicalJson(rebuilt) !=
      AgentEvaluationHashes.canonicalJson(commitmentsValue)) {
    throw StateError('public release capability DB readback diverged');
  }
  return (result: result, commitments: rebuilt);
}

Map<String, Object?> _publicCommitments({
  required AgentEvaluationRealReleaseConfiguration configuration,
  required AgentEvaluationRealReleaseResult result,
}) {
  if (result.partitions.isEmpty) {
    throw StateError('public release has no model partitions');
  }
  final db = sqlite3.open(
    result.authorityDatabasePath,
    mode: OpenMode.readOnly,
  );
  try {
    final reportSource = File(result.reportPath).readAsStringSync();
    final reportDecoded = jsonDecode(reportSource);
    if (reportDecoded is! Map<String, Object?>) {
      throw StateError('public release report is invalid');
    }
    final report = reportDecoded;
    final reportPayload = <String, Object?>{...report}..remove('reportHash');
    if (report['reportHash'] !=
            AgentEvaluationHashes.domainHash(
              'agent-evaluation-real-release-report-v1',
              reportPayload,
            ) ||
        result.releaseConfigurationHash !=
            configuration.releaseConfigurationHash) {
      throw StateError('public release commitments are not promotable');
    }
    final frozenRoutes = configuration.sutRoutes
        .map((route) => route.modelRouteHash)
        .toSet();
    final coveredRoutes = <String>{};
    final verdicts = <Map<String, Object?>>[];
    for (final partition in result.partitions) {
      final rows = db.select(
        '''SELECT v.champion_bundle_hash, v.challenger_bundle_hash,
             v.verdict_hash, v.status, e.scenario_set_release_hash,
             e.manifest_json
           FROM eval_release_gate_verdicts v
           JOIN eval_executions x ON x.execution_id = v.execution_id
           JOIN eval_experiments e ON e.experiment_id = x.experiment_id
           WHERE v.execution_id = ? AND v.verdict_kind = 'regression' ''',
        <Object?>[partition.executionId],
      );
      if (rows.length != 1 ||
          rows.single['verdict_hash'] != partition.regressionVerdictHash ||
          rows.single['status'] != 'promote') {
        throw StateError('public partition is not promotable');
      }
      final manifest = jsonDecode(rows.single['manifest_json'] as String);
      if (manifest is! Map<String, Object?> ||
          manifest['modelRouteHashes'] is! List<Object?>) {
        throw StateError('public partition manifest is invalid');
      }
      final routes = (manifest['modelRouteHashes']! as List<Object?>)
          .whereType<String>()
          .toSet();
      if (routes.isEmpty ||
          routes.length !=
              (manifest['modelRouteHashes']! as List<Object?>).length ||
          routes.difference(frozenRoutes).isNotEmpty ||
          coveredRoutes.intersection(routes).isNotEmpty) {
        throw StateError('public partition route coverage is invalid');
      }
      coveredRoutes.addAll(routes);
      verdicts.add(<String, Object?>{
        'partitionModelRouteHash': partition.modelRouteHash,
        'champion_bundle_hash': rows.single['champion_bundle_hash'],
        'challenger_bundle_hash': rows.single['challenger_bundle_hash'],
        'verdict_hash': rows.single['verdict_hash'],
        'scenario_set_release_hash': rows.single['scenario_set_release_hash'],
      });
    }
    if (coveredRoutes.length != frozenRoutes.length ||
        coveredRoutes.difference(frozenRoutes).isNotEmpty) {
      throw StateError('public partitions omit frozen model routes');
    }
    verdicts.sort(
      (left, right) => (left['partitionModelRouteHash']! as String).compareTo(
        right['partitionModelRouteHash']! as String,
      ),
    );
    final primary = verdicts.first;
    if (verdicts.any(
      (row) =>
          row['champion_bundle_hash'] != primary['champion_bundle_hash'] ||
          row['challenger_bundle_hash'] != primary['challenger_bundle_hash'] ||
          row['scenario_set_release_hash'] !=
              primary['scenario_set_release_hash'],
    )) {
      throw StateError('public partitions disagree on release authority');
    }
    return <String, Object?>{
      'schemaVersion': 'agent-evaluation-public-release-commitments-v1',
      'executionId': configuration.executionId,
      'authorityDatabasePath': File(result.authorityDatabasePath).absolute.path,
      'publicReportPath': File(result.reportPath).absolute.path,
      'publicReportHash': report['reportHash'],
      'releaseConfiguration': configuration.toCanonicalReleaseConfiguration(),
      'releaseConfigurationHash': result.releaseConfigurationHash,
      'buildArtifactHash': configuration.buildArtifactHash,
      'championBundleHash': primary['champion_bundle_hash'],
      'challengerBundleHash': primary['challenger_bundle_hash'],
      'regressionVerdictHash': primary['verdict_hash'],
      'regressionScenarioSetHash': primary['scenario_set_release_hash'],
    };
  } finally {
    db.dispose();
  }
}

Map<String, Object?> _strictObject(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?> ||
      AgentEvaluationHashes.canonicalJson(decoded) != source) {
    throw const FormatException('release coordinator IPC is not canonical');
  }
  return decoded;
}
