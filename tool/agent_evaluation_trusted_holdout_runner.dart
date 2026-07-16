import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';

Future<void> main(List<String> arguments) async {
  AgentEvaluationTrustedHoldoutVault? vault;
  try {
    final options = _parseOptions(arguments);
    final requestFile = File(options['request']!).absolute;
    if (FileSystemEntity.typeSync(requestFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('request must be a regular file');
    }
    final decoded = jsonDecode(requestFile.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('request must be a JSON object');
    }
    final request = AgentEvaluationTrustedHoldoutProcessRequest.fromJson(
      decoded,
    );
    final signer = await AgentEvaluationTrustedHoldoutSigner.fromSeedFile(
      keyId: options['key-id']!,
      path: options['seed-file']!,
    );
    vault = AgentEvaluationTrustedHoldoutVault.open(
      path: options['vault']!,
      signer: signer,
    );
    final attestation = await vault.evaluateAndAttest(
      authorityDatabasePath: options['authority-db']!,
      grant: request.grant,
      fixtureReleaseHash: request.fixtureReleaseHash,
      candidateEvidence: request.candidateEvidence,
      nonce: request.nonce,
      issuedAtMs: request.issuedAtMs,
      expiresAtMs: request.expiresAtMs,
    );
    stdout.write(
      AgentEvaluationHashes.canonicalJson(<String, Object?>{
        'schemaVersion': 'trusted-holdout-process-response-v1',
        'payloadJson': attestation.payloadJson,
        'signatureBase64': attestation.signatureBase64,
      }),
    );
  } catch (_) {
    stderr.writeln('trusted holdout evaluation failed');
    exitCode = 2;
  } finally {
    vault?.dispose();
  }
}

Map<String, String> _parseOptions(List<String> arguments) {
  const required = <String>{
    'authority-db',
    'vault',
    'seed-file',
    'key-id',
    'request',
  };
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length || !arguments[index].startsWith('--')) {
      throw const FormatException('invalid trusted holdout runner options');
    }
    final key = arguments[index].substring(2);
    final value = arguments[index + 1];
    if (!required.contains(key) ||
        value.trim().isEmpty ||
        result[key] != null) {
      throw const FormatException('invalid trusted holdout runner options');
    }
    result[key] = value;
  }
  if (result.keys.toSet().difference(required).isNotEmpty ||
      required.difference(result.keys.toSet()).isNotEmpty) {
    throw const FormatException('missing trusted holdout runner options');
  }
  return result;
}
