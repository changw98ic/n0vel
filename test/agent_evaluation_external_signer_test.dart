import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_external_signer.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_external_custody_trust_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';

void main() {
  late String dartExecutable;
  late String adapterPath;
  late SimplePublicKey publicKey;

  setUpAll(() async {
    dartExecutable = File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/dart',
    ).absolute.path;
    if (!File(dartExecutable).existsSync()) {
      throw StateError('standalone Dart executable is unavailable');
    }
    adapterPath = File(
      'test/test_support/agent_evaluation_external_signer_process.dart',
    ).absolute.path;
    final keyPair = await DartEd25519().newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 41),
    );
    publicKey = await keyPair.extractPublicKey();
  });

  AgentEvaluationExternalHoldoutSigner signer(
    String mode, {
    Duration timeout = const Duration(seconds: 10),
  }) => AgentEvaluationExternalHoldoutSigner.auditOnly(
    keyId: 'kms-key-v1',
    publicKey: publicKey,
    command: AgentEvaluationExternalSignerCommand.auditOnly(
      executablePath: dartExecutable,
      entrypointPath: adapterPath,
      fixedArguments: <String>[mode],
    ),
    timeout: timeout,
  );

  final payloadJson =
      AgentEvaluationHashes.canonicalJson(const <String, Object?>{
        'schemaVersion': 'test-signing-payload-v1',
        'keyId': 'kms-key-v1',
        'nonce': 'unique-request',
      });

  AgentEvaluationExternalCustodyTrustEntry auditTrustEntry() =>
      AgentEvaluationExternalCustodyTrustEntry(
        rootKeyId: 'audit-root',
        rootPublicKeyBase64: base64Encode(publicKey.bytes),
        kmsProviderReleaseHash: 'a' * 64,
        kmsKeyResourceHash: 'b' * 64,
        allowedRunnerPrincipalHashes: <String>['c' * 64],
        allowedSigningKeyIds: const <String>['kms-key-v1'],
        macTeamIdentifier: 'AUDITTEST1',
        macDesignatedRequirement: 'identifier "audit.test"',
        macCdHash: 'A' * 40,
        runtimeAppTeamIdentifier: 'RUNTIME001',
        runtimeAppDesignatedRequirement: 'identifier "runtime.audit.test"',
        runtimeAppCdHash: 'B' * 40,
        runtimeAppAuthorityChain: const <String>['Audit Runtime Authority'],
      );

  test(
    'external signer accepts only a request-bound verified signature',
    () async {
      final signature = await signer('valid').signCanonicalPayload(payloadJson);
      expect(signature, isNotEmpty);
    },
  );

  test('external signer does not inherit parent credentials', () async {
    final signature = await signer(
      'no-parent-env',
    ).signCanonicalPayload(payloadJson);
    expect(signature, isNotEmpty);
  });

  test('external signer rejects tamper, replay, and key mismatch', () async {
    for (final mode in <String>['tamper-signature', 'replay', 'key-mismatch']) {
      await expectLater(
        signer(mode).signCanonicalPayload(payloadJson),
        throwsA(isA<AgentEvaluationExternalSignerException>()),
        reason: mode,
      );
    }
  });

  test('external signer fails closed on command failure and timeout', () async {
    await expectLater(
      signer('failure').signCanonicalPayload(payloadJson),
      throwsA(isA<AgentEvaluationExternalSignerException>()),
    );
    for (final mode in <String>['oversize-stdout', 'oversize-stderr']) {
      await expectLater(
        signer(mode).signCanonicalPayload(payloadJson),
        throwsA(isA<AgentEvaluationExternalSignerException>()),
        reason: mode,
      );
    }
    await expectLater(
      signer(
        'timeout',
        timeout: const Duration(milliseconds: 100),
      ).signCanonicalPayload(payloadJson),
      throwsA(isA<AgentEvaluationExternalSignerException>()),
    );
  });

  test(
    'external signer rejects command mutation after custody freeze',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'external-signer-mutation-',
      );
      try {
        final mutableEntrypoint = File('${root.path}/signer.dart')
          ..writeAsBytesSync(File(adapterPath).readAsBytesSync(), flush: true);
        final frozenSigner = AgentEvaluationExternalHoldoutSigner.auditOnly(
          keyId: 'kms-key-v1',
          publicKey: publicKey,
          command: AgentEvaluationExternalSignerCommand.auditOnly(
            executablePath: dartExecutable,
            entrypointPath: mutableEntrypoint.path,
            fixedArguments: const <String>['valid'],
          ),
          timeout: const Duration(seconds: 10),
        );
        mutableEntrypoint.writeAsStringSync(
          '\n// changed after command identity was frozen\n',
          mode: FileMode.append,
          flush: true,
        );
        await expectLater(
          frozenSigner.signCanonicalPayload(payloadJson),
          throwsA(
            isA<AgentEvaluationExternalSignerException>().having(
              (error) => error.message,
              'message',
              contains('identity changed'),
            ),
          ),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('production broker rejects unsafe parent chain and symlink path', () {
    final root = Directory.systemTemp.createTempSync('external-signer-path-');
    try {
      final helper = File('${root.path}/helper')
        ..writeAsBytesSync(File(dartExecutable).readAsBytesSync(), flush: true);
      if (!Platform.isWindows) {
        Process.runSync('chmod', <String>['700', helper.path]);
      }
      expect(
        () => AgentEvaluationExternalSignerCommand.productionBrokered(
          executablePath: helper.path,
          trustEntry: auditTrustEntry(),
        ),
        throwsArgumentError,
      );
      if (!Platform.isWindows) {
        final linked = Link('${root.path}/linked-helper')
          ..createSync(helper.path);
        expect(
          () => AgentEvaluationExternalSignerCommand.productionBrokered(
            executablePath: linked.path,
            trustEntry: auditTrustEntry(),
          ),
          throwsArgumentError,
        );
      }
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production broker rejects ad-hoc and changed code identity', () {
    const validDetails = '''
Signature=Developer ID
TeamIdentifier=AUDITTEST1
CDHash=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
''';
    const validRequirement = 'designated => identifier "audit.test"';
    expect(
      () => AgentEvaluationMacBrokerCodeIdentity.parse(
        details: validDetails,
        requirement: validRequirement,
      ).verifyPinned(auditTrustEntry()),
      returnsNormally,
    );
    for (final details in <String>[
      validDetails.replaceFirst('Developer ID', 'adhoc'),
      validDetails.replaceFirst('AUDITTEST1', 'OTHERTEAM1'),
      validDetails.replaceFirst('A' * 40, 'B' * 40),
      validDetails.replaceFirst(
        'TeamIdentifier=AUDITTEST1',
        'TeamIdentifier=not set',
      ),
    ]) {
      expect(
        () => AgentEvaluationMacBrokerCodeIdentity.parse(
          details: details,
          requirement: validRequirement,
        ).verifyPinned(auditTrustEntry()),
        throwsFormatException,
      );
    }
    expect(
      () => AgentEvaluationMacBrokerCodeIdentity.parse(
        details: validDetails,
        requirement: 'designated => identifier "attacker"',
      ).verifyPinned(auditTrustEntry()),
      throwsFormatException,
    );
  });
}
