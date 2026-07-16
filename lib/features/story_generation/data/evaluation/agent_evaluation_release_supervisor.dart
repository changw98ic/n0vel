import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_external_signer.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_external_custody_trust_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_material_builder.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout_runner.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_release_harness.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_identity.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_spec_evidence.dart';
import 'agent_evaluation_release_coordinator_preflight.dart';
import 'agent_evaluation_release_preflight.dart';

const _runtimeAppBundle = 'build/macos/Build/Products/Release/novel_writer.app';
const _runtimeExecutable = '$_runtimeAppBundle/Contents/MacOS/novel_writer';

Future<void> main(List<String> arguments) =>
    runAgentEvaluationReleaseSupervisor(arguments);

Future<void> runAgentEvaluationReleaseSupervisor(List<String> arguments) async {
  Process? process;
  ServerSocket? supervisor;
  final supervisedSockets = <Socket>[];
  var failureStage = 'preflight';
  try {
    final environment = <String, String>{...Platform.environment};
    final appBundle = Directory(_runtimeAppBundle).absolute;
    final executable = File(_runtimeExecutable).absolute;
    final expectedHash = (environment['AGENT_EVAL_BUILD_ARTIFACT_HASH'] ?? '')
        .trim();
    if (arguments.isNotEmpty || !Platform.isMacOS) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    final bundleIdentifier = readAgentEvaluationMacAppBundleIdentifier(
      appBundle,
    );
    final containerRoot = resolveAgentEvaluationMacAppContainerRoot(
      bundleIdentifier: bundleIdentifier,
    );
    final privateMaterialRootPath =
        environment['AGENT_EVAL_PRIVATE_MATERIAL_ROOT'] ?? '';
    validateAgentEvaluationSandboxPaths(
      containerRoot: containerRoot,
      directoryPaths: <String>[
        for (final name in const <String>{
          'AGENT_EVAL_PUBLIC_WORK_DIR',
          'AGENT_EVAL_PUBLIC_REPORT_DIR',
          'AGENT_EVAL_COORDINATOR_WORK_DIR',
          'AGENT_EVAL_COORDINATOR_REPORT_DIR',
          'AGENT_EVAL_PRIVATE_MATERIAL_ROOT',
        })
          environment[name] ?? '',
      ],
      filePaths: <String>[
        '$privateMaterialRootPath.scenarios.json',
        '$privateMaterialRootPath.configuration.json',
        '$privateMaterialRootPath/private-plan.json',
        '$privateMaterialRootPath/private-vault.sqlite',
        environment['AGENT_EVAL_BASELINE_CRITERIA_SEAL'] ?? '',
      ],
    );
    validateAgentEvaluationCoordinatorPublicPhaseDeployment(environment);
    validateAgentEvaluationExternalSignerDeployment(environment);
    validateAgentEvaluationReleaseSourceTree(
      Directory.current,
      environment['AGENT_EVAL_SOURCE_TREE_HASH']!,
    );
    validateAgentEvaluationMacAppBundle(appBundle, expectedHash);
    if (FileSystemEntity.typeSync(executable.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    validateAgentEvaluationRepositoryCommit(
      Directory.current,
      environment['AGENT_EVAL_CODE_COMMIT']!,
    );
    final trustEntry = _resolveExternalCustodyTrustEntry(environment);
    final custodyRootKeyId =
        AgentEvaluationExternalCustodyAttestationPayload.fromCanonicalJson(
          environment['AGENT_EVAL_CUSTODY_ATTESTATION_PAYLOAD_JSON']!,
        ).rootKeyId;
    validateAgentEvaluationMacRuntimeAppCodeSignature(appBundle, trustEntry);
    final custody = await _verifyExternalCustodyPreflight(
      environment,
      trustEntry,
    );
    final sourceTreeHash = environment['AGENT_EVAL_SOURCE_TREE_HASH']!;
    final baselineCriteriaSeal =
        loadAndVerifyAgentEvaluationProductionCriteriaBaseline(
          sealPath: environment['AGENT_EVAL_BASELINE_CRITERIA_SEAL']!,
          sourceTreeHash: sourceTreeHash,
        );
    final custodyAttestation =
        AgentEvaluationExternalCustodyAttestationPayload.fromCanonicalJson(
          environment['AGENT_EVAL_CUSTODY_ATTESTATION_PAYLOAD_JSON']!,
        );
    if (custodyAttestation.baselineCriteriaSealHash !=
            baselineCriteriaSeal.sealHash ||
        custodyAttestation.baselineSourceTreeHash != sourceTreeHash) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    environment.addAll(<String, String>{
      'AGENT_EVAL_SDK_ADAPTER_RELEASE_HASH':
          AgentEvaluationDerivedReleaseIdentity.sdkAdapterReleaseHash(
            sourceTreeHash: sourceTreeHash,
            buildArtifactHash: expectedHash,
            providerApiRevision:
                environment['AGENT_EVAL_PROVIDER_API_REVISION']!,
          ),
      'AGENT_EVAL_TOKENIZER_RELEASE_HASH':
          AgentEvaluationDerivedReleaseIdentity.tokenizerReleaseHash(
            sourceTreeHash: sourceTreeHash,
            buildArtifactHash: expectedHash,
          ),
      'AGENT_EVAL_RUNTIME_RELEASE_HASH':
          AgentEvaluationDerivedReleaseIdentity.runtimeReleaseHash(
            sourceTreeHash: sourceTreeHash,
            buildArtifactHash: expectedHash,
          ),
      'AGENT_EVAL_PROVIDER_PRICE_AUTHORITY_ROOT_KEY_ID': custodyRootKeyId,
    });
    final reviewedPriceConfiguration =
        agentEvaluationRealReleaseConfigurationFromEnvironment(environment);
    final reviewedPriceTable = reviewedPriceConfiguration.providerPriceTable;
    final reviewedPriceAuthority =
        AgentEvaluationExternalCustodyTrustRegistry.production()
            .authorizeProviderPriceTable(
              rootKeyId: custodyRootKeyId,
              priceTableReleaseHash: reviewedPriceTable.releaseHash,
              zeroPricedModelRouteHashes: <String>[
                for (final entry in reviewedPriceTable.entries)
                  if (entry.promptMicrousdPerMillionTokens == 0 ||
                      entry.completionMicrousdPerMillionTokens == 0)
                    entry.modelRouteHash,
              ],
            );
    if (!reviewedPriceAuthority.productionAuthorityEligible ||
        reviewedPriceAuthority.trustEntryHash != trustEntry.entryHash) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    validateAgentEvaluationDerivedReleaseIdentities(environment);
    failureStage = 'supervisor';
    supervisor = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final supervisorToken = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    supervisor.listen((socket) {
      supervisedSockets.add(socket);
      var authenticated = false;
      utf8.decoder.bind(socket).transform(const LineSplitter()).listen((line) {
        if (!authenticated && line == supervisorToken) {
          authenticated = true;
        } else if (!authenticated) {
          socket.destroy();
        }
      });
    });
    const publicNames = <String>{
      'AGENT_EVAL_COORDINATOR_RUN_ID',
      'AGENT_EVAL_PUBLIC_WORK_DIR',
      'AGENT_EVAL_PUBLIC_REPORT_DIR',
      'AGENT_EVAL_COORDINATOR_WORK_DIR',
      'AGENT_EVAL_COORDINATOR_REPORT_DIR',
      'AGENT_EVAL_RELEASE_CHANNEL',
      'AGENT_EVAL_RELEASE_APPROVER',
      'AGENT_EVAL_BASELINE_CRITERIA_SEAL',
    };
    final signerCommand = _externalSignerCommand(environment, trustEntry);
    final publicCustodyCapabilityJson = _loadOrCreatePublicCustodyCapability(
      environment: environment,
      custody: custody,
      signerCommand: signerCommand,
    );
    final productionCustodyToken =
        await _verifyPublicCustodyCapabilityForRecovery(
          source: publicCustodyCapabilityJson,
          deadlineMs: int.parse(environment['AGENT_EVAL_DEADLINE_MS']!),
          privateTimeoutMs: int.parse(
            environment['AGENT_EVAL_PRIVATE_TIMEOUT_MS']!,
          ),
        );
    if (productionCustodyToken.baselineCriteriaSealHash !=
            baselineCriteriaSeal.sealHash ||
        productionCustodyToken.baselineSourceTreeHash != sourceTreeHash) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    final releaseBudgetDirectory = Directory(
      '${environment['AGENT_EVAL_COORDINATOR_WORK_DIR']}/'
      'release-budget-${environment['AGENT_EVAL_EXECUTION_ID']}',
    ).absolute;
    _preparePrivateDirectory(releaseBudgetDirectory);
    final commonPublicEnvironment = <String, String>{
      for (final name in <String>{
        ...agentEvaluationPaidReleaseRequiredEnvironment,
        ...agentEvaluationDerivedReleaseIdentityEnvironment,
        ...publicNames,
      })
        name: environment[name]!,
      'AGENT_EVAL_RELEASE_COORDINATOR_BOOTSTRAPPED': '1',
      'AGENT_EVAL_SUPERVISOR_PORT': '${supervisor.port}',
      'AGENT_EVAL_SUPERVISOR_TOKEN': supervisorToken,
      'AGENT_EVAL_PRIVATE_TIMEOUT_MS':
          environment['AGENT_EVAL_PRIVATE_TIMEOUT_MS']!,
      'AGENT_EVAL_PUBLIC_CUSTODY_CAPABILITY_JSON': publicCustodyCapabilityJson,
      'AGENT_EVAL_RELEASE_BUDGET_DIR': releaseBudgetDirectory.path,
    };

    failureStage = 'public-capability';
    final publicDeadlineMs = int.parse(environment['AGENT_EVAL_DEADLINE_MS']!);
    final publicCapability = File(
      '${environment['AGENT_EVAL_COORDINATOR_WORK_DIR']}/'
      'public-capability-${environment['AGENT_EVAL_EXECUTION_ID']}.json',
    ).absolute;
    late final Map<String, Object?> publicCommitments;
    late final String publicCommitmentsHash;
    if (publicCapability.existsSync()) {
      final envelope = _strictObject(publicCapability.readAsStringSync());
      final storedCommitments = envelope['publicCommitments'];
      if (envelope.length != 3 ||
          envelope['schemaVersion'] !=
              'agent-evaluation-public-release-capability-v1' ||
          storedCommitments is! Map<String, Object?> ||
          envelope['publicCommitmentsHash'] is! String) {
        throw const FormatException('public release capability is invalid');
      }
      publicCommitments = _strictPublicCommitments(
        _canonicalJson(storedCommitments),
        environment: environment,
      );
      publicCommitmentsHash = _domainHash(
        'agent-evaluation-public-release-commitments-v1',
        publicCommitments,
      );
      if (envelope['publicCommitmentsHash'] != publicCommitmentsHash) {
        throw const FormatException('public release capability hash mismatch');
      }
    } else {
      failureStage = 'public-process-start';
      process = await Process.start(
        executable.path,
        const <String>[],
        workingDirectory: Directory.current.path,
        environment: <String, String>{
          ...commonPublicEnvironment,
          'AGENT_EVAL_RELEASE_COORDINATOR_PHASE': 'public-only',
        },
        includeParentEnvironment: false,
      );
      failureStage = 'public-process-wait';
      final publicValues =
          await Future.wait<Object?>(<Future<Object?>>[
            process.exitCode,
            _readBounded(process.stdout, 256 * 1024),
            _readBounded(process.stderr, 4096),
          ]).timeout(
            Duration(
              milliseconds:
                  publicDeadlineMs + const Duration(minutes: 1).inMilliseconds,
            ),
          );
      if (publicValues[0] != 0) {
        _writeSafeChildFailure(publicValues[2]! as String);
        throw const FormatException('public release phase failed');
      }
      failureStage = 'public-commitments';
      publicCommitments = _strictPublicCommitments(
        publicValues[1]! as String,
        environment: environment,
      );
      publicCommitmentsHash = _domainHash(
        'agent-evaluation-public-release-commitments-v1',
        publicCommitments,
      );
      publicCapability
        ..createSync(exclusive: true)
        ..writeAsStringSync(
          _canonicalJson(<String, Object?>{
            'schemaVersion': 'agent-evaluation-public-release-capability-v1',
            'publicCommitments': publicCommitments,
            'publicCommitmentsHash': publicCommitmentsHash,
          }),
          flush: true,
        );
      _chmodPrivate(publicCapability.path);
    }
    failureStage = 'public-authority';
    final authority = File(
      publicCommitments['authorityDatabasePath']! as String,
    );
    _chmodPrivate(authority.path);
    Map<String, Object?> combinedBudgetEvidence() =>
        _readCombinedBudgetEvidence(
          environment: environment,
          releaseBudgetDirectory: releaseBudgetDirectory,
          publicCommitments: publicCommitments,
        );
    final completedResponse = await _completedResponse(
      authorityDatabasePath: authority.path,
      reportDirectoryPath: environment['AGENT_EVAL_COORDINATOR_REPORT_DIR']!,
      combinedBudgetEvidenceReader: combinedBudgetEvidence,
      productionCustodyToken: productionCustodyToken,
      verifiedBaselineCriteriaSeal: baselineCriteriaSeal,
    );
    if (completedResponse != null) {
      stdout.write(completedResponse);
      return;
    }

    failureStage = 'private-material';
    final materialRoot = Directory(
      environment['AGENT_EVAL_PRIVATE_MATERIAL_ROOT']!,
    ).absolute;
    final scenarioSource = File('${materialRoot.path}.scenarios.json');
    final configurationFile = File('${materialRoot.path}.configuration.json');
    const materialBuilder = AgentEvaluationPrivateMaterialBuilder();
    if (!scenarioSource.existsSync()) {
      materialBuilder.generateScenarios(outputPath: scenarioSource.path);
    }
    if (!configurationFile.existsSync()) {
      configurationFile.writeAsStringSync(
        _canonicalJson(
          publicCommitments['releaseConfiguration']! as Map<String, Object?>,
        ),
        flush: true,
      );
      _chmodPrivate(configurationFile.path);
    }
    final prepared = await materialBuilder.prepare(
      rootPath: materialRoot.path,
      authorityDatabasePath: authority.path,
      scenarioSourcePath: scenarioSource.path,
      releaseConfigurationPath: configurationFile.path,
      releaseConfigurationHash:
          publicCommitments['releaseConfigurationHash']! as String,
      appArtifactHash: expectedHash,
      championBundleHash: publicCommitments['championBundleHash']! as String,
      challengerBundleHash:
          publicCommitments['challengerBundleHash']! as String,
      regressionVerdictHash:
          publicCommitments['regressionVerdictHash']! as String,
      keyId: environment['AGENT_EVAL_PRIVATE_KEY_ID']!,
      externalPublicKey: SimplePublicKey(
        base64Decode(environment['AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64']!),
        type: KeyPairType.ed25519,
      ),
    );
    validateAgentEvaluationSandboxPaths(
      containerRoot: containerRoot,
      directoryPaths: <String>[materialRoot.path],
      filePaths: <String>[
        scenarioSource.path,
        configurationFile.path,
        '${materialRoot.path}/private-plan.json',
        '${materialRoot.path}/private-vault.sqlite',
      ],
    );
    final metadata = _strictObject(
      File('${materialRoot.path}/public-metadata.json').readAsStringSync(),
    );
    if (metadata['metadataHash'] != prepared.metadataHash ||
        metadata['privatePlanHash'] != prepared.privatePlanHash ||
        metadata['opaqueHoldoutScenarioSetHash'] !=
            prepared.opaqueScenarioSetHash ||
        metadata['trustPolicyHash'] != prepared.trustPolicyHash) {
      throw const FormatException('private material commitments diverged');
    }

    final externalDeploymentEnvironment = <String, String>{
      ...environment,
      'AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64':
          metadata['publicKeyBase64']! as String,
    };
    validateAgentEvaluationExternalSignerDeployment(
      externalDeploymentEnvironment,
    );

    failureStage = 'complete-process-start';
    process = await Process.start(
      executable.path,
      const <String>[],
      workingDirectory: Directory.current.path,
      environment: <String, String>{
        ...commonPublicEnvironment,
        'AGENT_EVAL_RELEASE_COORDINATOR_PHASE': 'complete',
        'AGENT_EVAL_PUBLIC_CAPABILITY_PATH': publicCapability.path,
        'AGENT_EVAL_PUBLIC_CAPABILITY_HASH': publicCommitmentsHash,
      },
      includeParentEnvironment: false,
    );
    failureStage = 'complete-process-ready';
    final lines = StreamIterator<String>(
      utf8.decoder.bind(process.stdout).transform(const LineSplitter()),
    );
    final stderrFuture = process.stderr.drain<void>();
    if (!await lines.moveNext().timeout(
      Duration(
        milliseconds:
            publicDeadlineMs + const Duration(minutes: 1).inMilliseconds,
      ),
    )) {
      throw const FormatException('complete phase did not become ready');
    }
    final ready = _strictObject(lines.current);
    if (ready.length != 2 ||
        ready['schemaVersion'] !=
            'agent-evaluation-release-coordinator-phase2-ready-v1' ||
        ready['publicCommitmentsHash'] != publicCommitmentsHash) {
      throw const FormatException('complete phase public recovery diverged');
    }
    failureStage = 'private-capability';
    final verifiedAtMs = DateTime.now().millisecondsSinceEpoch;
    final capabilityPayload = <String, Object?>{
      'schemaVersion': 'agent-evaluation-private-broker-capability-v1',
      'signingMode': 'external-command-v1',
      'privateTimeoutMs': environment['AGENT_EVAL_PRIVATE_TIMEOUT_MS']!,
      'privatePlanHash': prepared.privatePlanHash,
      'opaqueScenarioSetHash': prepared.opaqueScenarioSetHash,
      'keyId': environment['AGENT_EVAL_PRIVATE_KEY_ID']!,
      'publicKeyBase64': metadata['publicKeyBase64'],
      'signerCommandIdentityHash': signerCommand.identityHash,
      'custodyAttestationPayloadJson': custody.externalAttestationPayloadJson,
      'custodyAttestationSignatureBase64':
          custody.externalAttestationSignatureBase64,
      'verifiedAtMs': verifiedAtMs,
      'nonce': base64UrlEncode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      ),
    };
    final capabilityHash = _domainHash(
      'agent-evaluation-private-broker-capability-v1',
      capabilityPayload,
    );
    process.stdin.writeln(
      _canonicalJson(<String, Object?>{
        ...capabilityPayload,
        'capabilityHash': capabilityHash,
      }),
    );
    await process.stdin.flush();
    failureStage = 'complete-process-wait';
    late final String source;
    while (true) {
      if (!await lines.moveNext().timeout(
        Duration(
          milliseconds:
              int.parse(environment['AGENT_EVAL_PRIVATE_TIMEOUT_MS']!) +
              const Duration(minutes: 2).inMilliseconds,
        ),
      )) {
        throw const FormatException('complete phase response is missing');
      }
      final message = _strictObject(lines.current);
      if (message['schemaVersion'] ==
          'agent-evaluation-private-broker-request-v1') {
        failureStage = 'private-broker';
        final responseJson = await _runPrivateBrokerChild(
          request: message,
          expectedCapabilityHash: capabilityHash,
          executable: executable,
          environment: <String, String>{
            ...environment,
            ...commonPublicEnvironment,
          },
          materialRoot: materialRoot,
          materialBuilder: materialBuilder,
          signerCommand: signerCommand,
        );
        final requestId = message['requestId']! as String;
        final responsePayload = <String, Object?>{
          'requestId': requestId,
          'responseJson': responseJson,
        };
        process.stdin.writeln(
          _canonicalJson(<String, Object?>{
            'schemaVersion': 'agent-evaluation-private-broker-response-v1',
            ...responsePayload,
            'responseHash': _domainHash(
              'agent-evaluation-private-broker-response-v1',
              responsePayload,
            ),
          }),
        );
        await process.stdin.flush();
        failureStage = 'complete-process-wait';
        continue;
      }
      source = lines.current;
      break;
    }
    await process.stdin.close();
    if (await lines.moveNext()) {
      throw const FormatException('complete phase emitted extra output');
    }
    final completeExitCode = await process.exitCode;
    await stderrFuture;
    final decoded = _strictObject(source);
    const keys = <String>{
      'schemaVersion',
      'releaseEligible',
      'realProviderEvidence',
      'reportPath',
      'reportHash',
    };
    if (completeExitCode != 0 ||
        decoded.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(decoded.keys.toSet()).isNotEmpty ||
        decoded['schemaVersion'] !=
            'agent-evaluation-release-coordinator-response-v1' ||
        decoded['releaseEligible'] != true ||
        decoded['realProviderEvidence'] != true ||
        decoded['reportPath'] is! String ||
        decoded['reportHash'] is! String) {
      throw const FormatException('release coordinator runtime failed');
    }
    failureStage = 'final-seal';
    await verifyAgentEvaluationFinalReportSeal(
      reportPath: decoded['reportPath']! as String,
      expectedReportHash: decoded['reportHash']! as String,
      authorityDatabasePath:
          '${environment['AGENT_EVAL_PUBLIC_WORK_DIR']}/authority.sqlite',
      expectedCombinedBudgetEvidence: combinedBudgetEvidence(),
      productionCustodyToken: productionCustodyToken,
      verifiedBaselineCriteriaSeal: baselineCriteriaSeal,
    );
    stdout.write(source);
  } on TimeoutException {
    await _killAndWait(process);
    stderr.writeln('agent evaluation release coordinator timed out');
    exitCode = 124;
  } on AgentEvaluationCoordinatorPreflightFailure {
    await _killAndWait(process);
    stderr.writeln('agent evaluation release coordinator preflight failed');
    exitCode = 64;
  } catch (_) {
    await _killAndWait(process);
    stderr.writeln(
      'agent evaluation release coordinator failed at $failureStage',
    );
    exitCode = 2;
  } finally {
    for (final socket in supervisedSockets) {
      socket.destroy();
    }
    await supervisor?.close();
  }
}

String _loadOrCreatePublicCustodyCapability({
  required Map<String, String> environment,
  required AgentEvaluationEvidenceCustodyContract custody,
  required AgentEvaluationExternalSignerCommand signerCommand,
}) {
  final file = File(
    '${environment['AGENT_EVAL_COORDINATOR_WORK_DIR']}/'
    'public-custody-${environment['AGENT_EVAL_EXECUTION_ID']}.json',
  ).absolute;
  Map<String, Object?> buildPayload({
    required int verifiedAtMs,
    required String nonce,
  }) => <String, Object?>{
    'schemaVersion': 'agent-evaluation-public-custody-capability-v1',
    'keyId': environment['AGENT_EVAL_PRIVATE_KEY_ID']!,
    'publicKeyBase64': environment['AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64']!,
    'signerCommandIdentityHash': signerCommand.identityHash,
    'custodyAttestationPayloadJson': custody.externalAttestationPayloadJson,
    'custodyAttestationSignatureBase64':
        custody.externalAttestationSignatureBase64,
    'verifiedAtMs': verifiedAtMs,
    'nonce': nonce,
  };
  if (file.existsSync()) {
    final stored = _strictObject(file.readAsStringSync());
    final verifiedAtMs = stored['verifiedAtMs'];
    final nonce = stored['nonce'];
    if (verifiedAtMs is! int || nonce is! String) {
      throw const FormatException(
        'stored public custody capability is invalid',
      );
    }
    final expectedPayload = buildPayload(
      verifiedAtMs: verifiedAtMs,
      nonce: nonce,
    );
    final expected = <String, Object?>{
      ...expectedPayload,
      'capabilityHash': _domainHash(
        'agent-evaluation-public-custody-capability-v1',
        expectedPayload,
      ),
    };
    if (_canonicalJson(stored) != _canonicalJson(expected)) {
      throw const FormatException(
        'stored public custody capability changed authority',
      );
    }
    return _canonicalJson(expected);
  }
  final payload = buildPayload(
    verifiedAtMs: DateTime.now().millisecondsSinceEpoch,
    nonce: base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    ),
  );
  final source = _canonicalJson(<String, Object?>{
    ...payload,
    'capabilityHash': _domainHash(
      'agent-evaluation-public-custody-capability-v1',
      payload,
    ),
  });
  file
    ..createSync(exclusive: true)
    ..writeAsStringSync(source, flush: true);
  _chmodPrivate(file.path);
  return source;
}

AgentEvaluationExternalSignerCommand _externalSignerCommand(
  Map<String, String> environment,
  AgentEvaluationExternalCustodyTrustEntry trustEntry,
) {
  final arguments =
      jsonDecode(environment['AGENT_EVAL_EXTERNAL_SIGNER_ARGUMENTS_JSON']!)
          as List<Object?>;
  final entrypoint =
      (environment['AGENT_EVAL_EXTERNAL_SIGNER_ENTRYPOINT'] ?? '').trim();
  return AgentEvaluationExternalSignerCommand.productionBrokered(
    executablePath: environment['AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE']!,
    entrypointPath: entrypoint.isEmpty ? null : entrypoint,
    fixedArguments: arguments.cast<String>(),
    trustEntry: trustEntry,
  );
}

AgentEvaluationExternalCustodyTrustEntry _resolveExternalCustodyTrustEntry(
  Map<String, String> environment,
) {
  final attestation =
      AgentEvaluationExternalCustodyAttestationPayload.fromCanonicalJson(
        environment['AGENT_EVAL_CUSTODY_ATTESTATION_PAYLOAD_JSON']!,
      );
  return AgentEvaluationExternalCustodyTrustRegistry.production().resolve(
    attestation.rootKeyId,
  );
}

Future<AgentEvaluationEvidenceCustodyContract> _verifyExternalCustodyPreflight(
  Map<String, String> environment,
  AgentEvaluationExternalCustodyTrustEntry trustEntry,
) async {
  try {
    final signingPublicKey = SimplePublicKey(
      base64Decode(environment['AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64']!),
      type: KeyPairType.ed25519,
    );
    final command = _externalSignerCommand(environment, trustEntry);
    final minimumTtl = Duration(
      milliseconds:
          int.parse(environment['AGENT_EVAL_DEADLINE_MS']!) +
          int.parse(environment['AGENT_EVAL_PRIVATE_TIMEOUT_MS']!) +
          const Duration(minutes: 2).inMilliseconds,
    );
    return await AgentEvaluationEvidenceCustodyContract.verifyExternal(
      payloadJson: environment['AGENT_EVAL_CUSTODY_ATTESTATION_PAYLOAD_JSON']!,
      signatureBase64:
          environment['AGENT_EVAL_CUSTODY_ATTESTATION_SIGNATURE_BASE64']!,
      trustRegistry: AgentEvaluationExternalCustodyTrustRegistry.production(),
      expectedKeyId: environment['AGENT_EVAL_PRIVATE_KEY_ID']!,
      expectedSigningPublicKey: signingPublicKey,
      expectedRunnerArtifactHash:
          AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
      expectedSignerCommandIdentityHash: command.identityHash,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      minimumRemainingTtl: minimumTtl,
    );
  } on Object {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

Future<AgentEvaluationVerifiedProductionCustodyToken>
_verifyPublicCustodyCapabilityForRecovery({
  required String source,
  required int deadlineMs,
  required int privateTimeoutMs,
}) async {
  try {
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
            'agent-evaluation-public-custody-capability-v1') {
      throw const FormatException('invalid public custody capability');
    }
    final publicKeyBytes = base64Decode(value['publicKeyBase64']! as String);
    if (publicKeyBytes.length != 32) {
      throw const FormatException('invalid public custody key');
    }
    return AgentEvaluationVerifiedProductionCustodyToken.verifyProductionCapability(
      capabilityHash: value['capabilityHash']! as String,
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
          Duration(milliseconds: deadlineMs + privateTimeoutMs) +
          const Duration(minutes: 2),
    );
  } on Object {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

Future<String> _runPrivateBrokerChild({
  required Map<String, Object?> request,
  required String expectedCapabilityHash,
  required File executable,
  required Map<String, String> environment,
  required Directory materialRoot,
  required AgentEvaluationPrivateMaterialBuilder materialBuilder,
  required AgentEvaluationExternalSignerCommand signerCommand,
}) async {
  const keys = <String>{
    'schemaVersion',
    'requestId',
    'capabilityHash',
    'accessId',
    'authorityDatabasePath',
  };
  final requestId = request['requestId'];
  final accessId = request['accessId'];
  final authorityPath = request['authorityDatabasePath'];
  if (request.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(request.keys.toSet()).isNotEmpty ||
      request['schemaVersion'] !=
          'agent-evaluation-private-broker-request-v1' ||
      request['capabilityHash'] != expectedCapabilityHash ||
      requestId is! String ||
      accessId is! String ||
      authorityPath is! String) {
    throw const FormatException('private broker request is invalid');
  }
  final authority = File(authorityPath).absolute;
  final expectedParent = Directory(
    '${environment['AGENT_EVAL_COORDINATOR_WORK_DIR']}/private-child',
  ).absolute.path;
  if (authority.parent.path != expectedParent ||
      FileSystemEntity.typeSync(authority.path, followLinks: false) !=
          FileSystemEntityType.file ||
      (!Platform.isWindows && (authority.statSync().mode & 0x1ff) != 0x180) ||
      requestId !=
          _domainHash(
            'agent-evaluation-private-broker-request-v1',
            <String, Object?>{
              'capabilityHash': expectedCapabilityHash,
              'accessId': accessId,
              'authorityPathHash': _domainHash(
                'agent-evaluation-private-authority-path-v1',
                authority.path,
              ),
            },
          )) {
    throw const FormatException('private broker authority is invalid');
  }
  await materialBuilder.bind(
    rootPath: materialRoot.path,
    authorityDatabasePath: authority.path,
    accessId: accessId,
  );
  signerCommand.verifyCurrentIdentity();
  final privateEnvironment = <String, String>{
    for (final name in <String>{
      ...agentEvaluationPaidReleaseRequiredEnvironment,
      ...agentEvaluationDerivedReleaseIdentityEnvironment,
    })
      name: environment[name]!,
    'AGENT_EVAL_SUPERVISOR_PORT': environment['AGENT_EVAL_SUPERVISOR_PORT']!,
    'AGENT_EVAL_SUPERVISOR_TOKEN': environment['AGENT_EVAL_SUPERVISOR_TOKEN']!,
    'AGENT_EVAL_PRIVATE_RUNTIME_BOOTSTRAPPED': '1',
    'AGENT_EVAL_PRIVATE_AUTHORITY_DB': authority.path,
    'AGENT_EVAL_PRIVATE_ACCESS_ID': accessId,
    'AGENT_EVAL_PRIVATE_PLAN': '${materialRoot.path}/private-plan.json',
    'AGENT_EVAL_PRIVATE_VAULT': '${materialRoot.path}/private-vault.sqlite',
    'AGENT_EVAL_PRIVATE_KEY_ID': environment['AGENT_EVAL_PRIVATE_KEY_ID']!,
    'AGENT_EVAL_EXTERNAL_SIGNER_ENABLED': '1',
    'AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE': signerCommand.executablePath,
    'AGENT_EVAL_EXTERNAL_SIGNER_ENTRYPOINT': signerCommand.entrypointPath ?? '',
    'AGENT_EVAL_EXTERNAL_SIGNER_ARGUMENTS_JSON': _canonicalJson(
      signerCommand.fixedArguments,
    ),
    'AGENT_EVAL_EXTERNAL_SIGNER_TIMEOUT_MS':
        environment['AGENT_EVAL_EXTERNAL_SIGNER_TIMEOUT_MS']!,
    'AGENT_EVAL_EXTERNAL_SIGNER_PUBLIC_KEY_BASE64':
        environment['AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64']!,
    'AGENT_EVAL_EXTERNAL_SIGNER_COMMAND_IDENTITY_HASH':
        signerCommand.identityHash,
    'AGENT_EVAL_CUSTODY_ATTESTATION_PAYLOAD_JSON':
        environment['AGENT_EVAL_CUSTODY_ATTESTATION_PAYLOAD_JSON']!,
    'AGENT_EVAL_CUSTODY_ATTESTATION_SIGNATURE_BASE64':
        environment['AGENT_EVAL_CUSTODY_ATTESTATION_SIGNATURE_BASE64']!,
    'AGENT_EVAL_PUBLIC_CUSTODY_CAPABILITY_JSON':
        environment['AGENT_EVAL_PUBLIC_CUSTODY_CAPABILITY_JSON']!,
    'AGENT_EVAL_RELEASE_BUDGET_DIR':
        environment['AGENT_EVAL_RELEASE_BUDGET_DIR']!,
  };
  final child = await Process.start(
    executable.path,
    const <String>[],
    workingDirectory: Directory.current.path,
    environment: privateEnvironment,
    includeParentEnvironment: false,
  );
  final values =
      await Future.wait<Object?>(<Future<Object?>>[
        child.exitCode,
        _readBounded(child.stdout, 512 * 1024),
        _readBounded(child.stderr, 4096),
      ]).timeout(
        Duration(
          milliseconds: int.parse(
            environment['AGENT_EVAL_PRIVATE_TIMEOUT_MS']!,
          ),
        ),
      );
  if (values[0] != 0 || (values[1]! as String).isEmpty) {
    throw const FormatException('private broker child failed');
  }
  return values[1]! as String;
}

void _writeSafeChildFailure(String source) {
  final pattern = RegExp(
    r'^agent evaluation release coordinator failed at [a-z-]+$',
  );
  final matches = const LineSplitter()
      .convert(source)
      .where(pattern.hasMatch)
      .toList(growable: false);
  if (matches.length == 1) {
    stderr.writeln(matches.single);
  }
}

Future<String?> _completedResponse({
  required String authorityDatabasePath,
  required String reportDirectoryPath,
  required Map<String, Object?> Function() combinedBudgetEvidenceReader,
  required AgentEvaluationVerifiedProductionCustodyToken productionCustodyToken,
  required AgentEvaluationSpecCriteriaRegistrySeal verifiedBaselineCriteriaSeal,
}) async {
  final db = sqlite3.open(authorityDatabasePath, mode: OpenMode.readOnly);
  late final List<String> sealedHashes;
  try {
    sealedHashes = db
        .select(
          'SELECT report_hash FROM eval_final_release_report_seals '
          'ORDER BY report_hash',
        )
        .map((row) => row['report_hash'] as String)
        .toList(growable: false);
  } finally {
    db.dispose();
  }
  if (sealedHashes.isEmpty) return null;
  if (sealedHashes.length != 1) {
    throw const FormatException('final release seal recovery is ambiguous');
  }
  final reportDirectory = Directory(reportDirectoryPath).absolute;
  final matches = <({String path, String hash})>[];
  for (final entity in reportDirectory.listSync(followLinks: false)) {
    if (FileSystemEntity.typeSync(entity.path, followLinks: false) !=
        FileSystemEntityType.file) {
      continue;
    }
    try {
      final decoded = jsonDecode(File(entity.path).readAsStringSync());
      if (decoded is Map<String, Object?> &&
          decoded['schemaVersion'] ==
              'agent-evaluation-final-release-report-v1' &&
          decoded['reportHash'] == sealedHashes.single &&
          decoded['releaseEligible'] == true &&
          decoded['realProviderEvidence'] == true) {
        matches.add((
          path: File(entity.path).absolute.path,
          hash: sealedHashes.single,
        ));
      }
    } on FormatException {
      continue;
    }
  }
  if (matches.length != 1) {
    throw const FormatException('sealed final release report is unavailable');
  }
  final match = matches.single;
  await verifyAgentEvaluationFinalReportSeal(
    reportPath: match.path,
    expectedReportHash: match.hash,
    authorityDatabasePath: authorityDatabasePath,
    expectedCombinedBudgetEvidence: combinedBudgetEvidenceReader(),
    productionCustodyToken: productionCustodyToken,
    verifiedBaselineCriteriaSeal: verifiedBaselineCriteriaSeal,
  );
  return _canonicalJson(<String, Object?>{
    'schemaVersion': 'agent-evaluation-release-coordinator-response-v1',
    'releaseEligible': true,
    'realProviderEvidence': true,
    'reportPath': match.path,
    'reportHash': match.hash,
  });
}

Map<String, Object?> _strictPublicCommitments(
  String source, {
  required Map<String, String> environment,
}) {
  final value = _strictObject(source);
  const keys = <String>{
    'schemaVersion',
    'executionId',
    'authorityDatabasePath',
    'publicReportPath',
    'publicReportHash',
    'releaseConfiguration',
    'releaseConfigurationHash',
    'buildArtifactHash',
    'championBundleHash',
    'challengerBundleHash',
    'regressionVerdictHash',
    'regressionScenarioSetHash',
  };
  final digestPattern = RegExp(r'^[a-f0-9]{64}$');
  final digests = <Object?>[
    value['publicReportHash'],
    value['releaseConfigurationHash'],
    value['buildArtifactHash'],
    value['championBundleHash'],
    value['challengerBundleHash'],
    value['regressionVerdictHash'],
    value['regressionScenarioSetHash'],
  ];
  final configuration = value['releaseConfiguration'];
  final authorityPath = File(
    '${environment['AGENT_EVAL_PUBLIC_WORK_DIR']}/authority.sqlite',
  ).absolute.path;
  final publicReportPath = value['publicReportPath'];
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty ||
      value['schemaVersion'] !=
          'agent-evaluation-public-release-commitments-v1' ||
      value['executionId'] != environment['AGENT_EVAL_EXECUTION_ID'] ||
      value['authorityDatabasePath'] != authorityPath ||
      publicReportPath is! String ||
      File(publicReportPath).absolute.parent.path !=
          Directory(
            environment['AGENT_EVAL_PUBLIC_REPORT_DIR']!,
          ).absolute.path ||
      !File(publicReportPath).existsSync() ||
      configuration is! Map<String, Object?> ||
      digests.any(
        (digest) => digest is! String || !digestPattern.hasMatch(digest),
      ) ||
      value['buildArtifactHash'] !=
          environment['AGENT_EVAL_BUILD_ARTIFACT_HASH'] ||
      value['championBundleHash'] == value['challengerBundleHash'] ||
      _domainHash('agent-evaluation-release-configuration-v1', configuration) !=
          value['releaseConfigurationHash']) {
    throw const FormatException('public release commitments are invalid');
  }
  return value;
}

Map<String, Object?> _readCombinedBudgetEvidence({
  required Map<String, String> environment,
  required Directory releaseBudgetDirectory,
  required Map<String, Object?> publicCommitments,
}) {
  final configuration = agentEvaluationRealReleaseConfigurationFromEnvironment(
    environment,
  );
  final report = _strictObject(
    File(publicCommitments['publicReportPath']! as String).readAsStringSync(),
  );
  final publicProviderCalls = agentEvaluationAggregatePublicProviderCallCount(
    report,
  );
  return readAgentEvaluationCombinedReleaseBudgetEvidence(
    configuration: configuration,
    releaseBudgetDirectory: releaseBudgetDirectory,
    minimumProviderCalls: publicProviderCalls + configuration.expectedSlots,
    minimumJudgeCalls: configuration.expectedSlots * 2,
  );
}

int agentEvaluationAggregatePublicProviderCallCount(
  Map<String, Object?> publicReport,
) {
  final rawPartitions = publicReport['partitions'];
  if (rawPartitions is! List<Object?> || rawPartitions.isEmpty) {
    throw const FormatException('public budget baseline is invalid');
  }
  final partitionHashes = <String>{};
  var providerCalls = 0;
  for (final item in rawPartitions) {
    if (item is! Map<String, Object?>) {
      throw const FormatException('public budget baseline is invalid');
    }
    final partitionHash = item['modelRouteHash'];
    final count = item['providerCallCount'];
    if (partitionHash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(partitionHash) ||
        !partitionHashes.add(partitionHash) ||
        count is! int ||
        count <= 0) {
      throw const FormatException('public budget baseline is invalid');
    }
    providerCalls += count;
  }
  return providerCalls;
}

Map<String, Object?> _strictObject(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?> || _canonicalJson(decoded) != source) {
    throw const FormatException('release coordinator IPC is not canonical');
  }
  return decoded;
}

String _canonicalJson(Object? value) =>
    AppLlmCanonicalHash.canonicalJson(value);

String _domainHash(String domain, Object? value) =>
    AppLlmCanonicalHash.domainHash(domain, value).substring('sha256:'.length);

void _chmodPrivate(String path) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>['600', path]);
  if (result.exitCode != 0 || (File(path).statSync().mode & 0x1ff) != 0x180) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

void _preparePrivateDirectory(Directory directory) {
  final type = FileSystemEntity.typeSync(directory.path, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.directory) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  directory.createSync(recursive: true);
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>['700', directory.path]);
  if (result.exitCode != 0 || (directory.statSync().mode & 0x1ff) != 0x1c0) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

Future<void> _killAndWait(Process? process) async {
  if (process == null) return;
  process.kill(ProcessSignal.sigkill);
  try {
    await process.exitCode.timeout(const Duration(seconds: 5));
  } on Object {
    // The supervisor socket is the fail-closed descendant death channel.
  }
}

Future<String> _readBounded(Stream<List<int>> source, int maximumBytes) async {
  final bytes = <int>[];
  await for (final chunk in source) {
    if (bytes.length + chunk.length > maximumBytes) {
      throw const FormatException('release coordinator response is too large');
    }
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}
