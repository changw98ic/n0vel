import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart';

import 'features/story_generation/data/evaluation/agent_evaluation_external_signer.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_external_custody_trust_store.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_private_holdout.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_private_holdout_runner.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_spec_evidence.dart';

/// Alternate release entrypoint for the dedicated private holdout process.
/// It deliberately never calls runApp: the Flutter engine supplies dart:ui to
/// the production authoring runtime, then this process performs one bounded
/// evaluation and exits.
Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final environment = Platform.environment;
    if (environment['AGENT_EVAL_PRIVATE_RUNTIME_BOOTSTRAPPED'] != '1') {
      throw StateError('private runtime was not bootstrapped');
    }
    String value(String name) {
      final result = (environment[name] ?? '').trim();
      if (result.isEmpty) throw StateError('private runtime input is missing');
      return result;
    }

    final configuration =
        agentEvaluationRealReleaseConfigurationFromEnvironment(environment);
    final keyId = value('AGENT_EVAL_PRIVATE_KEY_ID');
    late final AgentEvaluationExternalHoldoutSigner signer;
    late final AgentEvaluationVerifiedProductionCustodyToken
    publicCustodyCapability;
    if (environment['AGENT_EVAL_EXTERNAL_SIGNER_ENABLED'] == '1') {
      final publicKeyBytes = base64Decode(
        value('AGENT_EVAL_EXTERNAL_SIGNER_PUBLIC_KEY_BASE64'),
      );
      final argumentsDecoded = jsonDecode(
        value('AGENT_EVAL_EXTERNAL_SIGNER_ARGUMENTS_JSON'),
      );
      final timeoutMs = int.tryParse(
        value('AGENT_EVAL_EXTERNAL_SIGNER_TIMEOUT_MS'),
      );
      if (publicKeyBytes.length != 32 ||
          argumentsDecoded is! List<Object?> ||
          argumentsDecoded.any((item) => item is! String) ||
          timeoutMs == null) {
        throw StateError('external signer configuration is invalid');
      }
      final entrypoint =
          (environment['AGENT_EVAL_EXTERNAL_SIGNER_ENTRYPOINT'] ?? '').trim();
      final trustRegistry =
          AgentEvaluationExternalCustodyTrustRegistry.production();
      final custodyPayload =
          AgentEvaluationExternalCustodyAttestationPayload.fromCanonicalJson(
            value('AGENT_EVAL_CUSTODY_ATTESTATION_PAYLOAD_JSON'),
          );
      final trustEntry = trustRegistry.resolve(custodyPayload.rootKeyId);
      final signerCommand =
          AgentEvaluationExternalSignerCommand.productionBrokered(
            executablePath: value('AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE'),
            entrypointPath: entrypoint.isEmpty ? null : entrypoint,
            fixedArguments: argumentsDecoded.cast<String>(),
            trustEntry: trustEntry,
          );
      if (signerCommand.identityHash !=
          value('AGENT_EVAL_EXTERNAL_SIGNER_COMMAND_IDENTITY_HASH')) {
        throw StateError('external signer command identity changed');
      }
      publicCustodyCapability = await _readPublicCustodyCapability(
        source: value('AGENT_EVAL_PUBLIC_CUSTODY_CAPABILITY_JSON'),
        keyId: keyId,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
        signerCommandIdentityHash: signerCommand.identityHash,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        minimumRemainingTtl:
            configuration.deadline +
            Duration(milliseconds: timeoutMs) +
            const Duration(minutes: 1),
      );
      signer = AgentEvaluationExternalHoldoutSigner.production(
        keyId: keyId,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
        command: signerCommand,
        timeout: Duration(milliseconds: timeoutMs),
        custodyToken: publicCustodyCapability,
        runnerArtifactHash:
            AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
      );
    } else {
      throw StateError('production private runtime requires external custody');
    }
    final vault = File(value('AGENT_EVAL_PRIVATE_VAULT')).absolute;
    final accessId = value('AGENT_EVAL_PRIVATE_ACCESS_ID');
    final workIdentity = AgentEvaluationHashes.domainHash(
      'eval-private-holdout-work-directory-v1',
      accessId,
    ).substring(0, 16);
    final runner = AgentEvaluationPrivateProductionHoldoutRunner.production(
      authorityDatabasePath: value('AGENT_EVAL_PRIVATE_AUTHORITY_DB'),
      accessId: accessId,
      privatePlanPath: value('AGENT_EVAL_PRIVATE_PLAN'),
      vaultPath: vault.path,
      privateWorkDirectory: Directory(
        '${vault.parent.path}/private-production-$workIdentity',
      ),
      signer: signer,
      configuration: configuration,
      releaseBudgetDirectory: Directory(value('AGENT_EVAL_RELEASE_BUDGET_DIR')),
      publicCustodyCapability: publicCustodyCapability,
    );
    final response = await runner.run();
    stdout.write(response.canonicalJson);
    exit(0);
  } catch (_) {
    stderr.writeln('private production holdout failed');
    exit(2);
  }
}

Future<AgentEvaluationVerifiedProductionCustodyToken>
_readPublicCustodyCapability({
  required String source,
  required String keyId,
  required SimplePublicKey publicKey,
  required String signerCommandIdentityHash,
  required int nowMs,
  required Duration minimumRemainingTtl,
}) async {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?> ||
      AgentEvaluationHashes.canonicalJson(decoded) != source) {
    throw StateError('public custody capability is not canonical');
  }
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
  final payload = <String, Object?>{...decoded}..remove('capabilityHash');
  final capabilityHash = AgentEvaluationHashes.domainHash(
    'agent-evaluation-public-custody-capability-v1',
    payload,
  );
  if (decoded.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(decoded.keys.toSet()).isNotEmpty ||
      decoded['schemaVersion'] !=
          'agent-evaluation-public-custody-capability-v1' ||
      decoded['keyId'] != keyId ||
      decoded['publicKeyBase64'] != base64Encode(publicKey.bytes) ||
      decoded['signerCommandIdentityHash'] != signerCommandIdentityHash ||
      decoded['capabilityHash'] != capabilityHash ||
      decoded['verifiedAtMs'] is! int ||
      decoded['nonce'] is! String) {
    throw StateError('public custody capability authority changed');
  }
  return AgentEvaluationVerifiedProductionCustodyToken.verifyProductionCapability(
    capabilityHash: capabilityHash,
    verifiedAtMs: decoded['verifiedAtMs']! as int,
    nonce: decoded['nonce']! as String,
    keyId: keyId,
    publicKey: publicKey,
    signerCommandIdentityHash: signerCommandIdentityHash,
    runnerArtifactHash:
        AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
    payloadJson: decoded['custodyAttestationPayloadJson']! as String,
    signatureBase64: decoded['custodyAttestationSignatureBase64']! as String,
    nowMs: nowMs,
    minimumRemainingTtl: minimumRemainingTtl,
  );
}
