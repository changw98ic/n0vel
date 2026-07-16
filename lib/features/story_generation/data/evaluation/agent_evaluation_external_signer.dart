import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_external_custody_trust_store.dart';
import 'agent_evaluation_spec_evidence.dart';
import 'agent_evaluation_trusted_holdout.dart';

abstract final class AgentEvaluationExternalSignerPolicy {
  static const maximumResponseBytes = 64 * 1024;
  static const maximumStderrBytes = 4096;

  static String get protocolReleaseHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-external-signer-protocol-v1',
    const <String, Object?>{
      'transport': 'one-process-per-signature-stdin-stdout-v1',
      'request': 'canonical-json-exact-payload-v1',
      'response': 'request-bound-ed25519-v1',
      'parentEnvironment': false,
      'fallback': 'disabled',
    },
  );
}

final class AgentEvaluationExternalSignerException implements Exception {
  const AgentEvaluationExternalSignerException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationExternalSignerException: $message';
}

final class AgentEvaluationMacBrokerCodeIdentity {
  AgentEvaluationMacBrokerCodeIdentity._({
    required this.teamIdentifier,
    required this.designatedRequirement,
    required this.cdHash,
  });

  factory AgentEvaluationMacBrokerCodeIdentity.parse({
    required String details,
    required String requirement,
  }) {
    final team = RegExp(
      r'^TeamIdentifier=(.+)$',
      multiLine: true,
    ).firstMatch(details)?.group(1)?.trim();
    final cdHash = RegExp(
      r'^CDHash=(.+)$',
      multiLine: true,
    ).firstMatch(details)?.group(1)?.trim().toUpperCase();
    const marker = 'designated => ';
    final markerIndex = requirement.indexOf(marker);
    final designated = markerIndex < 0
        ? null
        : requirement.substring(markerIndex + marker.length).trim();
    if (details.contains('Signature=adhoc') ||
        team == null ||
        team == 'not set' ||
        cdHash == null ||
        designated == null) {
      throw const FormatException('provider broker code identity is invalid');
    }
    return AgentEvaluationMacBrokerCodeIdentity._(
      teamIdentifier: team,
      designatedRequirement: designated,
      cdHash: cdHash,
    );
  }

  final String teamIdentifier;
  final String designatedRequirement;
  final String cdHash;

  void verifyPinned(AgentEvaluationExternalCustodyTrustEntry trustEntry) {
    if (teamIdentifier != trustEntry.macTeamIdentifier ||
        designatedRequirement != trustEntry.macDesignatedRequirement ||
        cdHash != trustEntry.macCdHash) {
      throw const FormatException('provider broker code identity changed');
    }
  }
}

final class AgentEvaluationExternalSignerCommand {
  AgentEvaluationExternalSignerCommand.auditOnly({
    required this.executablePath,
    this.entrypointPath,
    Iterable<String> fixedArguments = const <String>[],
  }) : fixedArguments = List<String>.unmodifiable(fixedArguments),
       _productionBrokered = false,
       _trustEntry = null {
    _validate();
  }

  AgentEvaluationExternalSignerCommand.productionBrokered({
    required this.executablePath,
    this.entrypointPath,
    Iterable<String> fixedArguments = const <String>[],
    required AgentEvaluationExternalCustodyTrustEntry trustEntry,
  }) : fixedArguments = List<String>.unmodifiable(fixedArguments),
       _productionBrokered = true,
       _trustEntry = trustEntry {
    _validate();
  }

  void _validate() {
    final executable = File(executablePath).absolute;
    final entrypoint = entrypointPath == null
        ? null
        : File(entrypointPath!).absolute;
    if (FileSystemEntity.typeSync(executable.path, followLinks: false) !=
            FileSystemEntityType.file ||
        (entrypoint != null &&
            FileSystemEntity.typeSync(entrypoint.path, followLinks: false) !=
                FileSystemEntityType.file) ||
        fixedArguments.length > 16 ||
        fixedArguments.any(
          (value) =>
              value.isEmpty ||
              value.length > 128 ||
              !RegExp(r'^[A-Za-z0-9_.=:+-]+$').hasMatch(value),
        )) {
      throw ArgumentError('external signer command is not frozen');
    }
    if (_productionBrokered) {
      _verifyProductionArtifact(
        executable,
        requireExecutable: true,
        signingIdentity: _trustEntry,
      );
      if (entrypoint != null) {
        _verifyProductionArtifact(
          entrypoint,
          requireExecutable: false,
          signingIdentity: null,
        );
      }
    }
    identityHash = _currentIdentityHash();
  }

  final String executablePath;
  final String? entrypointPath;
  final List<String> fixedArguments;
  final bool _productionBrokered;
  final AgentEvaluationExternalCustodyTrustEntry? _trustEntry;

  List<String> get processArguments => <String>[
    ?entrypointPath,
    ...fixedArguments,
  ];

  late final String identityHash;

  void verifyCurrentIdentity() {
    var matches = false;
    try {
      matches = _currentIdentityHash() == identityHash;
    } on Object {
      // Normalize missing, symlinked, or unreadable artifacts to one
      // non-diagnostic identity failure.
    }
    if (!matches) {
      throw const AgentEvaluationExternalSignerException(
        'external signer command identity changed',
      );
    }
  }

  String _currentIdentityHash() {
    final executable = File(executablePath).absolute;
    final entrypoint = entrypointPath == null
        ? null
        : File(entrypointPath!).absolute;
    if (_productionBrokered) {
      _verifyProductionArtifact(
        executable,
        requireExecutable: true,
        signingIdentity: _trustEntry,
      );
      if (entrypoint != null) {
        _verifyProductionArtifact(
          entrypoint,
          requireExecutable: false,
          signingIdentity: null,
        );
      }
    }
    return AgentEvaluationHashes.domainHash(
      'agent-evaluation-external-signer-command-v1',
      <String, Object?>{
        'executablePath': executable.path,
        'executableHash': _fileHash(executable),
        'executableMode': executable.statSync().mode & 0x1ff,
        'entrypointPath': entrypoint?.path,
        'entrypointHash': entrypoint == null ? null : _fileHash(entrypoint),
        'entrypointMode': (entrypoint?.statSync().mode ?? 0) & 0x1ff,
        'fixedArguments': fixedArguments,
        'productionBrokered': _productionBrokered,
        'providerBrokerTrustEntryHash': _trustEntry?.entryHash,
        'protocolReleaseHash':
            AgentEvaluationExternalSignerPolicy.protocolReleaseHash,
      },
    );
  }
}

void _verifyProductionArtifact(
  File file, {
  required bool requireExecutable,
  required AgentEvaluationExternalCustodyTrustEntry? signingIdentity,
}) {
  final absolute = file.absolute;
  late final String resolved;
  try {
    resolved = absolute.resolveSymbolicLinksSync();
  } on FileSystemException {
    throw ArgumentError('external signer production artifact is invalid');
  }
  if (resolved != absolute.path ||
      FileSystemEntity.typeSync(absolute.path, followLinks: false) !=
          FileSystemEntityType.file) {
    throw ArgumentError('external signer production artifact is symlinked');
  }
  final stat = absolute.statSync();
  final mode = stat.mode & 0x1ff;
  if ((mode & 0x12) != 0 || (requireExecutable && (mode & 0x40) == 0)) {
    throw ArgumentError('external signer production artifact mode is unsafe');
  }
  if (!Platform.isMacOS || _currentUserId() == 0) {
    throw ArgumentError('external signer production broker platform is unsafe');
  }
  final owner = _platformOwnerId(absolute.path);
  if (owner != 0) {
    throw ArgumentError(
      'external signer production artifact is not system-owned',
    );
  }
  var cursor = absolute.parent;
  while (true) {
    if (FileSystemEntity.typeSync(cursor.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        cursor.resolveSymbolicLinksSync() != cursor.path ||
        _platformOwnerId(cursor.path) != 0 ||
        (cursor.statSync().mode & 0x12) != 0) {
      throw ArgumentError('external signer production parent chain is unsafe');
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) break;
    cursor = parent;
  }
  if (signingIdentity != null) {
    final verified = Process.runSync('/usr/bin/codesign', <String>[
      '--verify',
      '--strict',
      absolute.path,
    ]);
    if (verified.exitCode != 0) {
      throw ArgumentError('external signer production helper is unsigned');
    }
    final details = Process.runSync('/usr/bin/codesign', <String>[
      '-d',
      '--verbose=4',
      absolute.path,
    ]);
    final detailText = '${details.stdout}\n${details.stderr}';
    if (details.exitCode != 0) {
      throw ArgumentError(
        'external signer production helper signing identity changed',
      );
    }
    final requirement = Process.runSync('/usr/bin/codesign', <String>[
      '-d',
      '-r-',
      absolute.path,
    ]);
    final requirementText = '${requirement.stdout}\n${requirement.stderr}';
    if (requirement.exitCode != 0) {
      throw ArgumentError(
        'external signer production helper requirement changed',
      );
    }
    try {
      AgentEvaluationMacBrokerCodeIdentity.parse(
        details: detailText,
        requirement: requirementText,
      ).verifyPinned(signingIdentity);
    } on FormatException {
      throw ArgumentError(
        'external signer production helper code identity changed',
      );
    }
  }
}

int? _currentUserId() {
  if (Platform.isWindows) return null;
  final result = Process.runSync('/usr/bin/id', const <String>['-u']);
  if (result.exitCode != 0) return null;
  return int.tryParse((result.stdout as String).trim());
}

int? _platformOwnerId(String path) {
  if (Platform.isWindows) return 0;
  final result = Platform.isMacOS
      ? Process.runSync('/usr/bin/stat', <String>['-f', '%u', path])
      : Process.runSync('/usr/bin/stat', <String>['-c', '%u', path]);
  if (result.exitCode != 0) return null;
  return int.tryParse((result.stdout as String).trim());
}

/// A fail-closed signing capability backed by a separately managed process.
///
/// The process receives only a canonical public payload. It must obtain its
/// KMS authority without inherited application environment or local seed
/// material. Every response is bound to a fresh request identity and is
/// independently verified against the frozen public key before it is used.
final class AgentEvaluationExternalHoldoutSigner
    implements AgentEvaluationHoldoutSigningAuthority {
  AgentEvaluationExternalHoldoutSigner.auditOnly({
    required this.keyId,
    required this.publicKey,
    required this.command,
    required this.timeout,
  }) : _custodyToken = null,
       _runnerArtifactHash = null {
    _validate();
  }

  AgentEvaluationExternalHoldoutSigner.production({
    required this.keyId,
    required this.publicKey,
    required this.command,
    required this.timeout,
    required AgentEvaluationVerifiedProductionCustodyToken custodyToken,
    required String runnerArtifactHash,
  }) : _custodyToken = custodyToken,
       _runnerArtifactHash = runnerArtifactHash {
    _validate();
    AgentEvaluationHashes.requireDigest(
      runnerArtifactHash,
      'runnerArtifactHash',
    );
    if (custodyToken.keyId != keyId ||
        custodyToken.publicKey.bytes.length != publicKey.bytes.length ||
        !_constantTimeBytesEqual(
          custodyToken.publicKey.bytes,
          publicKey.bytes,
        ) ||
        custodyToken.signerCommandIdentityHash != command.identityHash ||
        custodyToken.runnerArtifactHash != runnerArtifactHash) {
      throw ArgumentError('production signer custody token does not match');
    }
  }

  void _validate() {
    if (!RegExp(r'^[A-Za-z0-9_.:-]{1,128}$').hasMatch(keyId) ||
        publicKey.type != KeyPairType.ed25519 ||
        publicKey.bytes.length != 32 ||
        timeout <= Duration.zero ||
        timeout > const Duration(minutes: 5)) {
      throw ArgumentError('external signing authority is invalid');
    }
  }

  @override
  final String keyId;

  @override
  final SimplePublicKey publicKey;

  final AgentEvaluationExternalSignerCommand command;
  final Duration timeout;
  final AgentEvaluationVerifiedProductionCustodyToken? _custodyToken;
  final String? _runnerArtifactHash;

  bool get productionAuthorityEligible =>
      _custodyToken != null &&
      _runnerArtifactHash != null &&
      command._productionBrokered;

  @override
  Future<String> signCanonicalPayload(String payloadJson) async {
    final decoded = _strictCanonicalObject(payloadJson, 'signing payload');
    if (decoded['keyId'] != keyId) {
      throw const AgentEvaluationExternalSignerException(
        'external signer payload key does not match frozen authority',
      );
    }
    final payloadHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-external-signing-payload-v1',
      decoded,
    );
    final requestId = AgentEvaluationHashes.domainHash(
      'agent-evaluation-external-signing-request-id-v1',
      <String, Object?>{
        'payloadHash': payloadHash,
        'entropy': base64UrlEncode(
          List<int>.generate(32, (_) => Random.secure().nextInt(256)),
        ),
      },
    );
    final request = <String, Object?>{
      'schemaVersion': 'agent-evaluation-external-sign-request-v1',
      'requestId': requestId,
      'keyId': keyId,
      'publicKeyBase64': base64Encode(publicKey.bytes),
      'payloadJson': payloadJson,
      'payloadHash': payloadHash,
      'commandIdentityHash': command.identityHash,
      'protocolReleaseHash':
          AgentEvaluationExternalSignerPolicy.protocolReleaseHash,
    };
    final requestJson = AgentEvaluationHashes.canonicalJson(request);
    final requestHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-external-signing-request-v1',
      request,
    );

    Process? process;
    try {
      if (_custodyToken case final custodyToken?) {
        await custodyToken.reverify(
          nowMs: DateTime.now().millisecondsSinceEpoch,
          minimumRemainingTtl: timeout + const Duration(minutes: 1),
        );
      }
      // Re-check immediately before spawn. Production helpers and their full
      // parent chain are root-owned and not writable by the app user, so the
      // app cannot win the remaining check-to-exec interval. A compromised
      // root/kernel or provider broker is outside this process boundary and is
      // covered by the separately pinned broker identity and provider ACL.
      command.verifyCurrentIdentity();
      process = await Process.start(
        File(command.executablePath).absolute.path,
        command.processArguments,
        workingDirectory: Directory.current.absolute.path,
        environment: const <String, String>{
          'AGENT_EVAL_EXTERNAL_SIGNER_PROTOCOL': '1',
        },
        includeParentEnvironment: false,
      );
      process.stdin.write(requestJson);
      await process.stdin.close();
      final values = await Future.wait<Object?>(<Future<Object?>>[
        process.exitCode,
        _readBounded(
          process.stdout,
          AgentEvaluationExternalSignerPolicy.maximumResponseBytes,
        ),
        _readBounded(
          process.stderr,
          AgentEvaluationExternalSignerPolicy.maximumStderrBytes,
        ),
      ]).timeout(timeout);
      if (values[0] != 0) {
        throw const AgentEvaluationExternalSignerException(
          'external signer command failed',
        );
      }
      final response = _strictProcessResponse(values[1]! as String);
      const keys = <String>{
        'schemaVersion',
        'requestId',
        'requestHash',
        'keyId',
        'publicKeyBase64',
        'payloadHash',
        'signatureBase64',
      };
      if (response.keys.toSet().difference(keys).isNotEmpty ||
          keys.difference(response.keys.toSet()).isNotEmpty ||
          response['schemaVersion'] !=
              'agent-evaluation-external-sign-response-v1' ||
          response['requestId'] != requestId ||
          response['requestHash'] != requestHash ||
          response['keyId'] != keyId ||
          response['publicKeyBase64'] != base64Encode(publicKey.bytes) ||
          response['payloadHash'] != payloadHash ||
          response['signatureBase64'] is! String) {
        throw const AgentEvaluationExternalSignerException(
          'external signer response does not match its request',
        );
      }
      final signatureBase64 = response['signatureBase64']! as String;
      late final List<int> signature;
      try {
        signature = base64Decode(signatureBase64);
      } on FormatException {
        throw const AgentEvaluationExternalSignerException(
          'external signer signature is invalid',
        );
      }
      if (signature.length != 64 ||
          base64Encode(signature) != signatureBase64) {
        throw const AgentEvaluationExternalSignerException(
          'external signer signature is invalid',
        );
      }
      final verified = await DartEd25519().verify(
        utf8.encode(payloadJson),
        signature: Signature(signature, publicKey: publicKey),
      );
      if (!verified) {
        throw const AgentEvaluationExternalSignerException(
          'external signer signature is invalid',
        );
      }
      return signatureBase64;
    } on TimeoutException {
      process?.kill(ProcessSignal.sigkill);
      throw const AgentEvaluationExternalSignerException(
        'external signer command timed out',
      );
    } on AgentEvaluationExternalSignerException {
      rethrow;
    } on Object {
      process?.kill(ProcessSignal.sigkill);
      throw const AgentEvaluationExternalSignerException(
        'external signer command could not be executed',
      );
    } finally {
      process?.kill(ProcessSignal.sigkill);
    }
  }
}

bool _constantTimeBytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

Map<String, Object?> _strictCanonicalObject(String source, String label) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?> ||
      AgentEvaluationHashes.canonicalJson(decoded) != source) {
    throw AgentEvaluationExternalSignerException('$label is not canonical');
  }
  return decoded;
}

Map<String, Object?> _strictProcessResponse(String source) {
  final normalized = source.endsWith('\n')
      ? source.substring(0, source.length - 1)
      : source;
  if (normalized.contains('\n') || normalized.contains('\r')) {
    throw const AgentEvaluationExternalSignerException(
      'external signer emitted an invalid response envelope',
    );
  }
  return _strictCanonicalObject(normalized, 'external signer response');
}

Future<String> _readBounded(Stream<List<int>> source, int maximumBytes) async {
  final bytes = <int>[];
  await for (final chunk in source) {
    if (bytes.length + chunk.length > maximumBytes) {
      throw const AgentEvaluationExternalSignerException(
        'external signer output exceeded its fixed envelope',
      );
    }
    bytes.addAll(chunk);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw const AgentEvaluationExternalSignerException(
      'external signer output is not UTF-8',
    );
  }
}

String _fileHash(File source) {
  final file = source.absolute;
  if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw ArgumentError('external signer artifact is missing');
  }
  final digest = const DartSha256().hashSync(file.readAsBytesSync());
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
