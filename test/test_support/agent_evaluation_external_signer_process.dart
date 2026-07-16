import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';

Future<void> main(List<String> arguments) async {
  final mode = arguments.single;
  if (mode == 'failure') exit(7);
  if (mode == 'timeout') {
    await Future<void>.delayed(const Duration(seconds: 5));
    exit(0);
  }
  if (mode == 'oversize-stdout') {
    stdout.write('x' * (70 * 1024));
    exit(0);
  }
  if (mode == 'oversize-stderr') {
    stderr.write('x' * 5000);
    exit(7);
  }
  if (mode == 'no-parent-env' &&
      (Platform.environment.containsKey('HOME') ||
          Platform.environment.containsKey('ZHIPU_API_KEY'))) {
    exit(10);
  }
  final source = await stdin.transform(utf8.decoder).join();
  final request = jsonDecode(source);
  if (request is! Map<String, Object?> ||
      AgentEvaluationHashes.canonicalJson(request) != source) {
    exit(8);
  }
  final payloadJson = request['payloadJson'];
  if (payloadJson is! String) exit(9);
  final keyPair = await DartEd25519().newKeyPairFromSeed(
    List<int>.generate(32, (index) => index + 41),
  );
  final publicKey = await keyPair.extractPublicKey();
  final signedPayload = mode == 'tamper-signature'
      ? '$payloadJson '
      : payloadJson;
  final signature = await DartEd25519().sign(
    utf8.encode(signedPayload),
    keyPair: keyPair,
  );
  final response = <String, Object?>{
    'schemaVersion': 'agent-evaluation-external-sign-response-v1',
    'requestId': mode == 'replay' ? '0' * 64 : request['requestId'],
    'requestHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-external-signing-request-v1',
      request,
    ),
    'keyId': request['keyId'],
    'publicKeyBase64': mode == 'key-mismatch'
        ? base64Encode(List<int>.filled(32, 0))
        : base64Encode(publicKey.bytes),
    'payloadHash': request['payloadHash'],
    'signatureBase64': base64Encode(signature.bytes),
  };
  stdout.write(AgentEvaluationHashes.canonicalJson(response));
}
