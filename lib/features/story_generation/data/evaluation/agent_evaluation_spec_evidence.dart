import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_external_custody_trust_store.dart';

enum AgentEvaluationSpecEvidenceLevel {
  unit('unit'),
  integration('integration'),
  realProviderRelease('real-provider-release');

  const AgentEvaluationSpecEvidenceLevel(this.wireValue);
  final String wireValue;
}

enum AgentEvaluationEvidenceRetentionLevel {
  audit('audit'),
  regrade('regrade'),
  reExecute('re-execute');

  const AgentEvaluationEvidenceRetentionLevel(this.wireValue);
  final String wireValue;
}

enum AgentEvaluationSpecCriteriaStatus {
  passed('passed'),
  failed('failed'),
  notEvaluated('not-evaluated');

  const AgentEvaluationSpecCriteriaStatus(this.wireValue);
  final String wireValue;
}

final class AgentEvaluationSpecCriterionEvidence {
  AgentEvaluationSpecCriterionEvidence({
    required this.criteriaId,
    required this.artifactPath,
    required this.artifactHash,
    required this.sanitizedCommand,
    required this.exitCode,
    required this.durationMs,
    required this.sourceTreeHash,
    required this.reportHash,
    required this.evidenceLevel,
    required this.retentionLevel,
    required this.status,
  }) {
    if (!RegExp(r'^AEE-(0[1-9]|1[0-9]|2[0-4])$').hasMatch(criteriaId)) {
      throw ArgumentError('criteriaId is not a frozen AEE criterion');
    }
    _requireArchiveRelativePath(artifactPath, 'artifactPath');
    for (final entry in <MapEntry<String, String>>[
      MapEntry<String, String>('artifactHash', artifactHash),
      MapEntry<String, String>('sourceTreeHash', sourceTreeHash),
      MapEntry<String, String>('reportHash', reportHash),
    ]) {
      AgentEvaluationHashes.requireDigest(entry.value, entry.key);
    }
    _requireSanitizedCommand(sanitizedCommand);
    if (durationMs < 0 || exitCode < -1 || exitCode > 255) {
      throw ArgumentError('criteria command result is invalid');
    }
    if (status == AgentEvaluationSpecCriteriaStatus.notEvaluated) {
      if (exitCode != -1 || durationMs != 0) {
        throw ArgumentError(
          'not-evaluated criteria must not claim command execution',
        );
      }
    } else if (exitCode < 0) {
      throw ArgumentError('evaluated criteria require a process exit code');
    }
    if (status == AgentEvaluationSpecCriteriaStatus.passed && exitCode != 0) {
      throw ArgumentError('passed criteria require exit code zero');
    }
  }

  final String criteriaId;
  final String artifactPath;
  final String artifactHash;
  final String sanitizedCommand;
  final int exitCode;
  final int durationMs;
  final String sourceTreeHash;
  final String reportHash;
  final AgentEvaluationSpecEvidenceLevel evidenceLevel;
  final AgentEvaluationEvidenceRetentionLevel retentionLevel;
  final AgentEvaluationSpecCriteriaStatus status;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'criteriaId': criteriaId,
    'artifactPath': artifactPath,
    'artifactHash': artifactHash,
    'sanitizedCommand': sanitizedCommand,
    'exitCode': exitCode,
    'durationMs': durationMs,
    'sourceTreeHash': sourceTreeHash,
    'reportHash': reportHash,
    'evidenceLevel': evidenceLevel.wireValue,
    'retentionLevel': retentionLevel.wireValue,
    'status': status.wireValue,
  };

  factory AgentEvaluationSpecCriterionEvidence.fromCanonicalMap(
    Map<String, Object?> value,
  ) {
    const keys = <String>{
      'criteriaId',
      'artifactPath',
      'artifactHash',
      'sanitizedCommand',
      'exitCode',
      'durationMs',
      'sourceTreeHash',
      'reportHash',
      'evidenceLevel',
      'retentionLevel',
      'status',
    };
    _requireExactKeys(value, keys, 'criteria evidence');
    return AgentEvaluationSpecCriterionEvidence(
      criteriaId: _string(value, 'criteriaId'),
      artifactPath: _string(value, 'artifactPath'),
      artifactHash: _string(value, 'artifactHash'),
      sanitizedCommand: _string(value, 'sanitizedCommand'),
      exitCode: _integer(value, 'exitCode'),
      durationMs: _integer(value, 'durationMs'),
      sourceTreeHash: _string(value, 'sourceTreeHash'),
      reportHash: _string(value, 'reportHash'),
      evidenceLevel: _enumValue(
        AgentEvaluationSpecEvidenceLevel.values,
        _string(value, 'evidenceLevel'),
        (item) => item.wireValue,
        'evidenceLevel',
      ),
      retentionLevel: _enumValue(
        AgentEvaluationEvidenceRetentionLevel.values,
        _string(value, 'retentionLevel'),
        (item) => item.wireValue,
        'retentionLevel',
      ),
      status: _enumValue(
        AgentEvaluationSpecCriteriaStatus.values,
        _string(value, 'status'),
        (item) => item.wireValue,
        'status',
      ),
    );
  }
}

final class AgentEvaluationSpecCriteriaRegistry {
  AgentEvaluationSpecCriteriaRegistry({
    required List<AgentEvaluationSpecCriterionEvidence> entries,
  }) : entries = List<AgentEvaluationSpecCriterionEvidence>.unmodifiable(
         entries,
       ) {
    final ids = this.entries.map((entry) => entry.criteriaId).toList();
    if (ids.length != requiredCriteriaIds.length ||
        ids.toSet().length != ids.length ||
        !_orderedEquals(ids, requiredCriteriaIds)) {
      throw ArgumentError(
        'criteria registry must contain AEE-01 through AEE-24 exactly once',
      );
    }
    for (final entry in this.entries) {
      final minimum = minimumEvidenceLevel(entry.criteriaId);
      if (entry.status == AgentEvaluationSpecCriteriaStatus.passed &&
          entry.evidenceLevel.index < minimum.index) {
        throw ArgumentError(
          '${entry.criteriaId} passed below its minimum evidence level',
        );
      }
    }
  }

  static final List<String> requiredCriteriaIds = List<String>.unmodifiable(
    List<String>.generate(
      24,
      (index) => 'AEE-${(index + 1).toString().padLeft(2, '0')}',
    ),
  );

  static const Set<String> realProviderCriteriaIds = <String>{
    'AEE-14',
    'AEE-15',
    'AEE-18',
    'AEE-23',
    'AEE-24',
  };

  static AgentEvaluationSpecEvidenceLevel minimumEvidenceLevel(
    String criteriaId,
  ) {
    if (!requiredCriteriaIds.contains(criteriaId)) {
      throw ArgumentError('unknown AEE criterion');
    }
    return realProviderCriteriaIds.contains(criteriaId)
        ? AgentEvaluationSpecEvidenceLevel.realProviderRelease
        : AgentEvaluationSpecEvidenceLevel.integration;
  }

  static final String contractHash = AgentEvaluationHashes.domainHash(
    'agent-evaluation-spec-criteria-registry-contract-v1',
    <String, Object?>{
      'schemaVersion': 'spec-criteria-registry-v1',
      'requiredCriteriaIds': requiredCriteriaIds,
      'entryFields': const <String>[
        'criteriaId',
        'artifactPath',
        'artifactHash',
        'sanitizedCommand',
        'exitCode',
        'durationMs',
        'sourceTreeHash',
        'reportHash',
        'evidenceLevel',
        'retentionLevel',
        'status',
      ],
      'evidenceLevels': <String>[
        for (final value in AgentEvaluationSpecEvidenceLevel.values)
          value.wireValue,
      ],
      'retentionLevels': <String>[
        for (final value in AgentEvaluationEvidenceRetentionLevel.values)
          value.wireValue,
      ],
      'statuses': <String>[
        for (final value in AgentEvaluationSpecCriteriaStatus.values)
          value.wireValue,
      ],
      'minimumEvidenceLevels': <String, Object?>{
        for (final criteriaId in requiredCriteriaIds)
          criteriaId: minimumEvidenceLevel(criteriaId).wireValue,
      },
      'artifactPathPolicy': 'safe-archive-relative-v1',
      'commandPolicy': 'single-line-secret-sanitized-v1',
    },
  );

  final List<AgentEvaluationSpecCriterionEvidence> entries;

  bool get allPassed => entries.every(
    (entry) => entry.status == AgentEvaluationSpecCriteriaStatus.passed,
  );

  void requireProductionBaseline({required String sourceTreeHash}) {
    AgentEvaluationHashes.requireDigest(sourceTreeHash, 'sourceTreeHash');
    for (final entry in entries) {
      if (entry.sourceTreeHash != sourceTreeHash) {
        throw const FormatException(
          'criteria baseline belongs to another source tree',
        );
      }
      final productionOnly = realProviderCriteriaIds.contains(entry.criteriaId);
      if (productionOnly) {
        if (entry.status != AgentEvaluationSpecCriteriaStatus.notEvaluated) {
          throw const FormatException(
            'criteria baseline cannot pre-authorize real-provider evidence',
          );
        }
      } else if (entry.status != AgentEvaluationSpecCriteriaStatus.passed) {
        throw const FormatException(
          'criteria baseline is missing a required integration result',
        );
      }
    }
  }

  void requireAllPassedForRelease() {
    if (!allPassed) {
      throw const FormatException(
        'release eligibility requires every AEE criterion to pass',
      );
    }
  }

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'spec-criteria-registry-v1',
    'contractHash': contractHash,
    'entries': <Object?>[for (final entry in entries) entry.toCanonicalMap()],
  };

  String get canonicalJson =>
      AgentEvaluationHashes.canonicalJson(toCanonicalMap());

  String get registryHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-spec-criteria-registry-v1',
    toCanonicalMap(),
  );

  factory AgentEvaluationSpecCriteriaRegistry.fromCanonicalJson(String source) {
    final value = _canonicalObject(source, 'criteria registry');
    const keys = <String>{'schemaVersion', 'contractHash', 'entries'};
    _requireExactKeys(value, keys, 'criteria registry');
    final rawEntries = value['entries'];
    if (value['schemaVersion'] != 'spec-criteria-registry-v1' ||
        value['contractHash'] != contractHash ||
        rawEntries is! List<Object?> ||
        rawEntries.any((entry) => entry is! Map<String, Object?>)) {
      throw const FormatException('criteria registry contract is invalid');
    }
    return AgentEvaluationSpecCriteriaRegistry(
      entries: <AgentEvaluationSpecCriterionEvidence>[
        for (final entry in rawEntries)
          AgentEvaluationSpecCriterionEvidence.fromCanonicalMap(
            entry! as Map<String, Object?>,
          ),
      ],
    );
  }
}

final class AgentEvaluationSpecCriteriaRegistrySeal {
  AgentEvaluationSpecCriteriaRegistrySeal._({required this.registry});

  factory AgentEvaluationSpecCriteriaRegistrySeal.create(
    AgentEvaluationSpecCriteriaRegistry registry,
  ) => AgentEvaluationSpecCriteriaRegistrySeal._(registry: registry);

  final AgentEvaluationSpecCriteriaRegistry registry;

  String get sealHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-spec-criteria-registry-seal-v1',
    <String, Object?>{
      'contractHash': AgentEvaluationSpecCriteriaRegistry.contractHash,
      'registryHash': registry.registryHash,
    },
  );

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'spec-criteria-registry-seal-v1',
    'contractHash': AgentEvaluationSpecCriteriaRegistry.contractHash,
    'registryHash': registry.registryHash,
    'registry': registry.toCanonicalMap(),
    'sealHash': sealHash,
  };

  String get canonicalJson =>
      AgentEvaluationHashes.canonicalJson(toCanonicalMap());

  factory AgentEvaluationSpecCriteriaRegistrySeal.fromCanonicalJson(
    String source,
  ) {
    final value = _canonicalObject(source, 'criteria registry seal');
    const keys = <String>{
      'schemaVersion',
      'contractHash',
      'registryHash',
      'registry',
      'sealHash',
    };
    _requireExactKeys(value, keys, 'criteria registry seal');
    final rawRegistry = value['registry'];
    if (value['schemaVersion'] != 'spec-criteria-registry-seal-v1' ||
        value['contractHash'] !=
            AgentEvaluationSpecCriteriaRegistry.contractHash ||
        rawRegistry is! Map<String, Object?>) {
      throw const FormatException('criteria registry seal is invalid');
    }
    final registry = AgentEvaluationSpecCriteriaRegistry.fromCanonicalJson(
      AgentEvaluationHashes.canonicalJson(rawRegistry),
    );
    final seal = AgentEvaluationSpecCriteriaRegistrySeal.create(registry);
    if (value['registryHash'] != registry.registryHash ||
        value['sealHash'] != seal.sealHash) {
      throw const FormatException('criteria registry seal hash is invalid');
    }
    return seal;
  }
}

AgentEvaluationSpecCriteriaRegistrySeal
loadAndVerifyAgentEvaluationProductionCriteriaBaseline({
  required String sealPath,
  required String sourceTreeHash,
}) {
  final sealFile = File(sealPath).absolute;
  final archiveRoot = sealFile.parent.absolute;
  if (!File(sealPath).isAbsolute ||
      FileSystemEntity.typeSync(sealFile.path, followLinks: false) !=
          FileSystemEntityType.file ||
      sealFile.resolveSymbolicLinksSync() != sealFile.path ||
      (!Platform.isWindows && (sealFile.statSync().mode & 0x3f) != 0)) {
    throw const FormatException(
      'production criteria baseline seal is not a secure regular file',
    );
  }
  final seal = AgentEvaluationSpecCriteriaRegistrySeal.fromCanonicalJson(
    sealFile.readAsStringSync(),
  );
  seal.registry.requireProductionBaseline(sourceTreeHash: sourceTreeHash);
  verifyAgentEvaluationSpecCriteriaArtifacts(
    registry: seal.registry,
    archiveRoot: archiveRoot,
  );
  return seal;
}

void verifyAgentEvaluationSpecCriteriaArtifacts({
  required AgentEvaluationSpecCriteriaRegistry registry,
  required Directory archiveRoot,
}) {
  final root = archiveRoot.absolute;
  if (!archiveRoot.isAbsolute ||
      FileSystemEntity.typeSync(root.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      root.resolveSymbolicLinksSync() != root.path) {
    throw const FormatException(
      'criteria archive root is not a canonical regular directory',
    );
  }
  for (final entry in registry.entries) {
    final artifact = File('${root.path}/${entry.artifactPath}').absolute;
    if (!artifact.path.startsWith('${root.path}${Platform.pathSeparator}') ||
        FileSystemEntity.typeSync(artifact.path, followLinks: false) !=
            FileSystemEntityType.file ||
        artifact.resolveSymbolicLinksSync() != artifact.path ||
        _sha256Hex(artifact) != entry.artifactHash) {
      throw FormatException(
        'production criteria ${entry.criteriaId} artifact is invalid',
      );
    }
  }
}

String _sha256Hex(File file) {
  final digest = const DartSha256().hashSync(file.readAsBytesSync());
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

AgentEvaluationSpecCriteriaRegistrySeal
deriveAgentEvaluationProductionCriteriaSeal({
  required AgentEvaluationSpecCriteriaRegistrySeal baselineSeal,
  required String sourceTreeHash,
  required String productionArtifactPath,
  required String productionArtifactHash,
  required Map<String, String> productionCriterionReportHashes,
  required String sanitizedCommand,
  required int durationMs,
  required AgentEvaluationEvidenceRetentionLevel retentionLevel,
}) {
  baselineSeal.registry.requireProductionBaseline(
    sourceTreeHash: sourceTreeHash,
  );
  if (productionCriterionReportHashes.keys
          .toSet()
          .difference(
            AgentEvaluationSpecCriteriaRegistry.realProviderCriteriaIds,
          )
          .isNotEmpty ||
      AgentEvaluationSpecCriteriaRegistry.realProviderCriteriaIds
          .difference(productionCriterionReportHashes.keys.toSet())
          .isNotEmpty) {
    throw ArgumentError(
      'production criteria evidence must cover every real-provider criterion',
    );
  }
  for (final hash in productionCriterionReportHashes.values) {
    AgentEvaluationHashes.requireDigest(hash, 'productionCriterionReportHash');
  }
  final registry = AgentEvaluationSpecCriteriaRegistry(
    entries: <AgentEvaluationSpecCriterionEvidence>[
      for (final entry in baselineSeal.registry.entries)
        if (!AgentEvaluationSpecCriteriaRegistry.realProviderCriteriaIds
            .contains(entry.criteriaId))
          entry
        else
          AgentEvaluationSpecCriterionEvidence(
            criteriaId: entry.criteriaId,
            artifactPath: productionArtifactPath,
            artifactHash: productionArtifactHash,
            sanitizedCommand: sanitizedCommand,
            exitCode: 0,
            durationMs: durationMs,
            sourceTreeHash: sourceTreeHash,
            reportHash: productionCriterionReportHashes[entry.criteriaId]!,
            evidenceLevel: AgentEvaluationSpecEvidenceLevel.realProviderRelease,
            retentionLevel: retentionLevel,
            status: AgentEvaluationSpecCriteriaStatus.passed,
          ),
    ],
  );
  return AgentEvaluationSpecCriteriaRegistrySeal.create(registry);
}

bool deriveAgentEvaluationCriteriaReleaseEligibility({
  required bool prerequisitesMet,
  required AgentEvaluationSpecCriteriaRegistrySeal criteriaSeal,
}) => prerequisitesMet && criteriaSeal.registry.allPassed;

void verifyAgentEvaluationCriteriaReleaseClaim({
  required bool releaseEligible,
  required AgentEvaluationSpecCriteriaRegistrySeal criteriaSeal,
}) {
  if (releaseEligible) criteriaSeal.registry.requireAllPassedForRelease();
}

enum AgentEvaluationEvidenceCustodyMode {
  localFileSeed('local-file-seed'),
  externallyAttestedNonExportableKms(
    'externally-attested-non-exportable-kms-independent-acl',
  );

  const AgentEvaluationEvidenceCustodyMode(this.wireValue);
  final String wireValue;
}

final class AgentEvaluationExternalCustodyAttestationPayload {
  AgentEvaluationExternalCustodyAttestationPayload({
    required this.rootKeyId,
    required this.keyId,
    required this.keyVersion,
    required this.signingPublicKeyHash,
    required this.kmsProviderReleaseHash,
    required this.kmsKeyResourceHash,
    required this.runnerPrincipalHash,
    required this.runnerArtifactHash,
    required this.signerCommandIdentityHash,
    required this.fixtureStorePolicyHash,
    required this.retentionPolicyHash,
    required this.baselineCriteriaSealHash,
    required this.baselineSourceTreeHash,
    required this.issuedAtMs,
    required this.expiresAtMs,
  }) {
    for (final value in <String>[rootKeyId, keyId, keyVersion]) {
      if (!RegExp(r'^[A-Za-z0-9_.:-]{1,128}$').hasMatch(value)) {
        throw ArgumentError('external custody key identity is invalid');
      }
    }
    for (final entry in <MapEntry<String, String>>[
      MapEntry<String, String>(
        'kmsProviderReleaseHash',
        kmsProviderReleaseHash,
      ),
      MapEntry<String, String>('signingPublicKeyHash', signingPublicKeyHash),
      MapEntry<String, String>('kmsKeyResourceHash', kmsKeyResourceHash),
      MapEntry<String, String>('runnerPrincipalHash', runnerPrincipalHash),
      MapEntry<String, String>('runnerArtifactHash', runnerArtifactHash),
      MapEntry<String, String>(
        'signerCommandIdentityHash',
        signerCommandIdentityHash,
      ),
      MapEntry<String, String>(
        'fixtureStorePolicyHash',
        fixtureStorePolicyHash,
      ),
      MapEntry<String, String>('retentionPolicyHash', retentionPolicyHash),
      MapEntry<String, String>(
        'baselineCriteriaSealHash',
        baselineCriteriaSealHash,
      ),
      MapEntry<String, String>(
        'baselineSourceTreeHash',
        baselineSourceTreeHash,
      ),
    ]) {
      AgentEvaluationHashes.requireDigest(entry.value, entry.key);
    }
    if (issuedAtMs < 0 ||
        expiresAtMs <= issuedAtMs ||
        expiresAtMs - issuedAtMs > const Duration(hours: 72).inMilliseconds) {
      throw ArgumentError('external custody attestation TTL is invalid');
    }
  }

  final String rootKeyId;
  final String keyId;
  final String keyVersion;
  final String signingPublicKeyHash;
  final String kmsProviderReleaseHash;
  final String kmsKeyResourceHash;
  final String runnerPrincipalHash;
  final String runnerArtifactHash;
  final String signerCommandIdentityHash;
  final String fixtureStorePolicyHash;
  final String retentionPolicyHash;
  final String baselineCriteriaSealHash;
  final String baselineSourceTreeHash;
  final int issuedAtMs;
  final int expiresAtMs;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'external-custody-attestation-v2',
    'rootKeyId': rootKeyId,
    'keyId': keyId,
    'keyVersion': keyVersion,
    'signingPublicKeyHash': signingPublicKeyHash,
    'custodyMode': AgentEvaluationEvidenceCustodyMode
        .externallyAttestedNonExportableKms
        .wireValue,
    'nonExportable': true,
    'independentAcl': true,
    'kmsProviderReleaseHash': kmsProviderReleaseHash,
    'kmsKeyResourceHash': kmsKeyResourceHash,
    'runnerPrincipalHash': runnerPrincipalHash,
    'runnerArtifactHash': runnerArtifactHash,
    'signerCommandIdentityHash': signerCommandIdentityHash,
    'fixtureStorePolicyHash': fixtureStorePolicyHash,
    'retentionPolicyHash': retentionPolicyHash,
    'baselineCriteriaSealHash': baselineCriteriaSealHash,
    'baselineSourceTreeHash': baselineSourceTreeHash,
    'issuedAtMs': issuedAtMs,
    'expiresAtMs': expiresAtMs,
  };

  String get canonicalJson =>
      AgentEvaluationHashes.canonicalJson(toCanonicalMap());

  factory AgentEvaluationExternalCustodyAttestationPayload.fromCanonicalJson(
    String source,
  ) {
    final value = _canonicalObject(source, 'external custody attestation');
    const keys = <String>{
      'schemaVersion',
      'rootKeyId',
      'keyId',
      'keyVersion',
      'signingPublicKeyHash',
      'custodyMode',
      'nonExportable',
      'independentAcl',
      'kmsProviderReleaseHash',
      'kmsKeyResourceHash',
      'runnerPrincipalHash',
      'runnerArtifactHash',
      'signerCommandIdentityHash',
      'fixtureStorePolicyHash',
      'retentionPolicyHash',
      'baselineCriteriaSealHash',
      'baselineSourceTreeHash',
      'issuedAtMs',
      'expiresAtMs',
    };
    _requireExactKeys(value, keys, 'external custody attestation');
    if (value['schemaVersion'] != 'external-custody-attestation-v2' ||
        value['custodyMode'] !=
            AgentEvaluationEvidenceCustodyMode
                .externallyAttestedNonExportableKms
                .wireValue ||
        value['nonExportable'] != true ||
        value['independentAcl'] != true) {
      throw const FormatException('external custody claims are invalid');
    }
    return AgentEvaluationExternalCustodyAttestationPayload(
      rootKeyId: _string(value, 'rootKeyId'),
      keyId: _string(value, 'keyId'),
      keyVersion: _string(value, 'keyVersion'),
      signingPublicKeyHash: _string(value, 'signingPublicKeyHash'),
      kmsProviderReleaseHash: _string(value, 'kmsProviderReleaseHash'),
      kmsKeyResourceHash: _string(value, 'kmsKeyResourceHash'),
      runnerPrincipalHash: _string(value, 'runnerPrincipalHash'),
      runnerArtifactHash: _string(value, 'runnerArtifactHash'),
      signerCommandIdentityHash: _string(value, 'signerCommandIdentityHash'),
      fixtureStorePolicyHash: _string(value, 'fixtureStorePolicyHash'),
      retentionPolicyHash: _string(value, 'retentionPolicyHash'),
      baselineCriteriaSealHash: _string(value, 'baselineCriteriaSealHash'),
      baselineSourceTreeHash: _string(value, 'baselineSourceTreeHash'),
      issuedAtMs: _integer(value, 'issuedAtMs'),
      expiresAtMs: _integer(value, 'expiresAtMs'),
    );
  }
}

final class AgentEvaluationEvidenceCustodyContract {
  AgentEvaluationEvidenceCustodyContract._({
    required this.mode,
    required this.keyIdHash,
    required this.publicKeyHash,
    required this.runnerArtifactHash,
    required this.attestationRootPublicKeyHash,
    required this.externalAttestationHash,
    required this.kmsProviderReleaseHash,
    required this.kmsKeyResourceHash,
    required this.runnerPrincipalHash,
    required this.fixtureStorePolicyHash,
    required this.retentionPolicyHash,
    required this.productionTrustPinned,
    required this.externalAttestationPayloadJson,
    required this.externalAttestationSignatureBase64,
    required this.externalAttestationIssuedAtMs,
    required this.externalAttestationExpiresAtMs,
    required this.trustEntryHash,
    required this.nonExportable,
    required this.independentAcl,
  });

  factory AgentEvaluationEvidenceCustodyContract.localFileSeed({
    required String keyId,
    required String publicKeyHash,
    required String runnerArtifactHash,
  }) {
    if (keyId.trim().isEmpty) {
      throw ArgumentError('local custody key identity is invalid');
    }
    AgentEvaluationHashes.requireDigest(publicKeyHash, 'publicKeyHash');
    AgentEvaluationHashes.requireDigest(
      runnerArtifactHash,
      'runnerArtifactHash',
    );
    return AgentEvaluationEvidenceCustodyContract._(
      mode: AgentEvaluationEvidenceCustodyMode.localFileSeed,
      keyIdHash: AgentEvaluationHashes.domainHash(
        'agent-evaluation-custody-key-id-v1',
        keyId,
      ),
      publicKeyHash: publicKeyHash,
      runnerArtifactHash: runnerArtifactHash,
      attestationRootPublicKeyHash: null,
      externalAttestationHash: null,
      kmsProviderReleaseHash: null,
      kmsKeyResourceHash: null,
      runnerPrincipalHash: null,
      fixtureStorePolicyHash: AgentEvaluationHashes.domainHash(
        'agent-evaluation-local-file-custody-policy-v1',
        const <String, Object?>{
          'directoryMode': '0700',
          'fileMode': '0600',
          'encryption': 'not-externally-attested',
          'principalIsolation': 'not-externally-attested',
        },
      ),
      retentionPolicyHash: null,
      productionTrustPinned: false,
      externalAttestationPayloadJson: null,
      externalAttestationSignatureBase64: null,
      externalAttestationIssuedAtMs: null,
      externalAttestationExpiresAtMs: null,
      trustEntryHash: null,
      nonExportable: false,
      independentAcl: false,
    );
  }

  static Future<AgentEvaluationEvidenceCustodyContract> verifyExternal({
    required String payloadJson,
    required String signatureBase64,
    required AgentEvaluationExternalCustodyTrustRegistry trustRegistry,
    required String expectedKeyId,
    required SimplePublicKey expectedSigningPublicKey,
    required String expectedRunnerArtifactHash,
    required String expectedSignerCommandIdentityHash,
    required int nowMs,
    Duration minimumRemainingTtl = Duration.zero,
  }) async {
    if (minimumRemainingTtl < Duration.zero) {
      throw const FormatException('external custody TTL floor is invalid');
    }
    final payload =
        AgentEvaluationExternalCustodyAttestationPayload.fromCanonicalJson(
          payloadJson,
        );
    final trustEntry = trustRegistry.resolve(payload.rootKeyId);
    final rootPublicKey = trustEntry.validateAndExtractRoot();
    if (expectedSigningPublicKey.type != KeyPairType.ed25519 ||
        expectedSigningPublicKey.bytes.length != 32 ||
        rootPublicKey.bytes.length != expectedSigningPublicKey.bytes.length ||
        _constantTimeBytesEqual(
          rootPublicKey.bytes,
          expectedSigningPublicKey.bytes,
        )) {
      throw const FormatException(
        'external custody roots must be independently controlled',
      );
    }
    AgentEvaluationHashes.requireDigest(
      expectedRunnerArtifactHash,
      'expectedRunnerArtifactHash',
    );
    AgentEvaluationHashes.requireDigest(
      expectedSignerCommandIdentityHash,
      'expectedSignerCommandIdentityHash',
    );
    final expectedSigningPublicKeyHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-holdout-public-key-v1',
      base64Encode(expectedSigningPublicKey.bytes),
    );
    if (payload.keyId != expectedKeyId ||
        payload.signingPublicKeyHash != expectedSigningPublicKeyHash ||
        payload.kmsProviderReleaseHash != trustEntry.kmsProviderReleaseHash ||
        payload.kmsKeyResourceHash != trustEntry.kmsKeyResourceHash ||
        !trustEntry.allowedRunnerPrincipalHashes.contains(
          payload.runnerPrincipalHash,
        ) ||
        !trustEntry.allowedSigningKeyIds.contains(payload.keyId) ||
        payload.runnerArtifactHash != expectedRunnerArtifactHash ||
        payload.signerCommandIdentityHash !=
            expectedSignerCommandIdentityHash ||
        nowMs < payload.issuedAtMs ||
        nowMs >= payload.expiresAtMs ||
        payload.expiresAtMs - nowMs < minimumRemainingTtl.inMilliseconds) {
      throw const FormatException('external custody authority is not current');
    }
    late final List<int> signatureBytes;
    try {
      signatureBytes = base64Decode(signatureBase64);
    } on FormatException {
      throw const FormatException('external custody signature is invalid');
    }
    if (signatureBytes.length != 64 ||
        base64Encode(signatureBytes) != signatureBase64) {
      throw const FormatException('external custody signature is invalid');
    }
    final verified = await DartEd25519().verify(
      utf8.encode(payload.canonicalJson),
      signature: Signature(signatureBytes, publicKey: rootPublicKey),
    );
    if (!verified) {
      throw const FormatException('external custody signature is invalid');
    }
    return AgentEvaluationEvidenceCustodyContract._(
      mode:
          AgentEvaluationEvidenceCustodyMode.externallyAttestedNonExportableKms,
      keyIdHash: AgentEvaluationHashes.domainHash(
        'agent-evaluation-custody-key-id-v1',
        <String, Object?>{
          'keyId': payload.keyId,
          'keyVersion': payload.keyVersion,
        },
      ),
      publicKeyHash: payload.signingPublicKeyHash,
      runnerArtifactHash: payload.runnerArtifactHash,
      attestationRootPublicKeyHash: AgentEvaluationHashes.domainHash(
        'agent-evaluation-custody-attestation-root-v1',
        base64Encode(rootPublicKey.bytes),
      ),
      externalAttestationHash: AgentEvaluationHashes.domainHash(
        'agent-evaluation-external-custody-attestation-v1',
        <String, Object?>{
          'payload': payload.toCanonicalMap(),
          'signatureBase64': signatureBase64,
        },
      ),
      kmsProviderReleaseHash: payload.kmsProviderReleaseHash,
      kmsKeyResourceHash: payload.kmsKeyResourceHash,
      runnerPrincipalHash: payload.runnerPrincipalHash,
      fixtureStorePolicyHash: payload.fixtureStorePolicyHash,
      retentionPolicyHash: payload.retentionPolicyHash,
      // Serialized custody contracts are evidence only. Trusting the registry
      // used by this verification call must never turn a DTO into authority.
      productionTrustPinned: false,
      externalAttestationPayloadJson: payload.canonicalJson,
      externalAttestationSignatureBase64: signatureBase64,
      externalAttestationIssuedAtMs: payload.issuedAtMs,
      externalAttestationExpiresAtMs: payload.expiresAtMs,
      trustEntryHash: trustEntry.entryHash,
      nonExportable: true,
      independentAcl: true,
    );
  }

  final AgentEvaluationEvidenceCustodyMode mode;
  final String keyIdHash;
  final String? publicKeyHash;
  final String runnerArtifactHash;
  final String? attestationRootPublicKeyHash;
  final String? externalAttestationHash;
  final String? kmsProviderReleaseHash;
  final String? kmsKeyResourceHash;
  final String? runnerPrincipalHash;
  final String fixtureStorePolicyHash;
  final String? retentionPolicyHash;
  final bool productionTrustPinned;
  final String? externalAttestationPayloadJson;
  final String? externalAttestationSignatureBase64;
  final int? externalAttestationIssuedAtMs;
  final int? externalAttestationExpiresAtMs;
  final String? trustEntryHash;
  final bool nonExportable;
  final bool independentAcl;

  /// Serialized custody evidence is deliberately never release-authoritative.
  /// Production authority lives only in
  /// [AgentEvaluationVerifiedProductionCustodyToken].
  bool get releaseAuthorityEligible => false;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'evidence-custody-contract-v1',
    'mode': mode.wireValue,
    'keyIdHash': keyIdHash,
    'publicKeyHash': publicKeyHash,
    'runnerArtifactHash': runnerArtifactHash,
    'attestationRootPublicKeyHash': attestationRootPublicKeyHash,
    'externalAttestationHash': externalAttestationHash,
    'kmsProviderReleaseHash': kmsProviderReleaseHash,
    'kmsKeyResourceHash': kmsKeyResourceHash,
    'runnerPrincipalHash': runnerPrincipalHash,
    'fixtureStorePolicyHash': fixtureStorePolicyHash,
    'retentionPolicyHash': retentionPolicyHash,
    'productionTrustPinned': productionTrustPinned,
    'externalAttestationPayloadJson': externalAttestationPayloadJson,
    'externalAttestationSignatureBase64': externalAttestationSignatureBase64,
    'externalAttestationIssuedAtMs': externalAttestationIssuedAtMs,
    'externalAttestationExpiresAtMs': externalAttestationExpiresAtMs,
    'trustEntryHash': trustEntryHash,
    'nonExportable': nonExportable,
    'independentAcl': independentAcl,
    'releaseAuthorityEligible': releaseAuthorityEligible,
  };

  String get canonicalJson =>
      AgentEvaluationHashes.canonicalJson(toCanonicalMap());

  String get custodyHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-evidence-custody-contract-v1',
    toCanonicalMap(),
  );

  Future<void> reverifyExternal({
    required AgentEvaluationExternalCustodyTrustRegistry trustRegistry,
    required String expectedKeyId,
    required SimplePublicKey expectedSigningPublicKey,
    required String expectedRunnerArtifactHash,
    required String expectedSignerCommandIdentityHash,
    required int nowMs,
    Duration minimumRemainingTtl = Duration.zero,
  }) async {
    if (externalAttestationPayloadJson == null ||
        externalAttestationSignatureBase64 == null) {
      throw const FormatException('external custody proof is unavailable');
    }
    final verified = await verifyExternal(
      payloadJson: externalAttestationPayloadJson!,
      signatureBase64: externalAttestationSignatureBase64!,
      trustRegistry: trustRegistry,
      expectedKeyId: expectedKeyId,
      expectedSigningPublicKey: expectedSigningPublicKey,
      expectedRunnerArtifactHash: expectedRunnerArtifactHash,
      expectedSignerCommandIdentityHash: expectedSignerCommandIdentityHash,
      nowMs: nowMs,
      minimumRemainingTtl: minimumRemainingTtl,
    );
    if (verified.custodyHash != custodyHash) {
      throw const FormatException('external custody proof changed');
    }
  }

  factory AgentEvaluationEvidenceCustodyContract.fromCanonicalJson(
    String source,
  ) {
    final value = _canonicalObject(source, 'evidence custody contract');
    const keys = <String>{
      'schemaVersion',
      'mode',
      'keyIdHash',
      'publicKeyHash',
      'runnerArtifactHash',
      'attestationRootPublicKeyHash',
      'externalAttestationHash',
      'kmsProviderReleaseHash',
      'kmsKeyResourceHash',
      'runnerPrincipalHash',
      'fixtureStorePolicyHash',
      'retentionPolicyHash',
      'productionTrustPinned',
      'externalAttestationPayloadJson',
      'externalAttestationSignatureBase64',
      'externalAttestationIssuedAtMs',
      'externalAttestationExpiresAtMs',
      'trustEntryHash',
      'nonExportable',
      'independentAcl',
      'releaseAuthorityEligible',
    };
    _requireExactKeys(value, keys, 'evidence custody contract');
    if (value['schemaVersion'] != 'evidence-custody-contract-v1') {
      throw const FormatException('evidence custody schema is invalid');
    }
    final mode = _enumValue(
      AgentEvaluationEvidenceCustodyMode.values,
      _string(value, 'mode'),
      (item) => item.wireValue,
      'custody mode',
    );
    String? nullableDigest(String key) {
      final item = value[key];
      if (item == null) return null;
      if (item is! String) throw FormatException('$key is invalid');
      AgentEvaluationHashes.requireDigest(item, key);
      return item;
    }

    final contract = AgentEvaluationEvidenceCustodyContract._(
      mode: mode,
      keyIdHash: _string(value, 'keyIdHash'),
      publicKeyHash: nullableDigest('publicKeyHash'),
      runnerArtifactHash: _string(value, 'runnerArtifactHash'),
      attestationRootPublicKeyHash: nullableDigest(
        'attestationRootPublicKeyHash',
      ),
      externalAttestationHash: nullableDigest('externalAttestationHash'),
      kmsProviderReleaseHash: nullableDigest('kmsProviderReleaseHash'),
      kmsKeyResourceHash: nullableDigest('kmsKeyResourceHash'),
      runnerPrincipalHash: nullableDigest('runnerPrincipalHash'),
      fixtureStorePolicyHash: _string(value, 'fixtureStorePolicyHash'),
      retentionPolicyHash: nullableDigest('retentionPolicyHash'),
      productionTrustPinned: false,
      externalAttestationPayloadJson:
          value['externalAttestationPayloadJson'] as String?,
      externalAttestationSignatureBase64:
          value['externalAttestationSignatureBase64'] as String?,
      externalAttestationIssuedAtMs:
          value['externalAttestationIssuedAtMs'] as int?,
      externalAttestationExpiresAtMs:
          value['externalAttestationExpiresAtMs'] as int?,
      trustEntryHash: nullableDigest('trustEntryHash'),
      nonExportable: _boolean(value, 'nonExportable'),
      independentAcl: _boolean(value, 'independentAcl'),
    );
    for (final entry in <MapEntry<String, String>>[
      MapEntry<String, String>('keyIdHash', contract.keyIdHash),
      MapEntry<String, String>(
        'runnerArtifactHash',
        contract.runnerArtifactHash,
      ),
      MapEntry<String, String>(
        'fixtureStorePolicyHash',
        contract.fixtureStorePolicyHash,
      ),
    ]) {
      AgentEvaluationHashes.requireDigest(entry.value, entry.key);
    }
    final isLocal = mode == AgentEvaluationEvidenceCustodyMode.localFileSeed;
    if (_boolean(value, 'productionTrustPinned') ||
        _boolean(value, 'releaseAuthorityEligible') ||
        (isLocal &&
            (contract.nonExportable ||
                contract.independentAcl ||
                contract.attestationRootPublicKeyHash != null ||
                contract.externalAttestationHash != null ||
                contract.kmsProviderReleaseHash != null ||
                contract.kmsKeyResourceHash != null ||
                contract.runnerPrincipalHash != null ||
                contract.retentionPolicyHash != null ||
                contract.productionTrustPinned ||
                contract.externalAttestationPayloadJson != null ||
                contract.externalAttestationSignatureBase64 != null ||
                contract.externalAttestationIssuedAtMs != null ||
                contract.externalAttestationExpiresAtMs != null ||
                contract.trustEntryHash != null)) ||
        (!isLocal &&
            (contract.attestationRootPublicKeyHash == null ||
                contract.publicKeyHash == null ||
                contract.externalAttestationPayloadJson == null ||
                contract.externalAttestationSignatureBase64 == null ||
                contract.externalAttestationIssuedAtMs == null ||
                contract.externalAttestationExpiresAtMs == null ||
                contract.trustEntryHash == null))) {
      throw const FormatException('evidence custody claims are inconsistent');
    }
    return contract;
  }
}

/// Minimal binding data persisted beside the first production authority
/// receipt. Implementations do not imply that the caller may execute a real
/// provider; that privilege is carried only by the opaque token below.
abstract interface class AgentEvaluationPublicCustodyBinding {
  String get capabilityHash;
  String get attestationHash;
  int get verifiedAtMs;
  String get nonce;
}

/// Non-serializable proof that the current process revalidated an external
/// custody attestation against the compile-time production trust registry.
///
/// There is intentionally no public constructor, JSON factory, or `toJson`.
/// Recovery must call [verifyProductionCapability] again using the raw signed
/// attestation and obtains a fresh in-memory instance.
final class AgentEvaluationVerifiedProductionCustodyToken
    implements AgentEvaluationPublicCustodyBinding {
  AgentEvaluationVerifiedProductionCustodyToken._({
    required this.capabilityHash,
    required this.verifiedAtMs,
    required this.nonce,
    required this.keyId,
    required this.publicKey,
    required this.signerCommandIdentityHash,
    required this.runnerArtifactHash,
    required this.payloadJson,
    required this.signatureBase64,
    required this.auditContract,
    required this.baselineCriteriaSealHash,
    required this.baselineSourceTreeHash,
  }) : attestationHash = auditContract.externalAttestationHash!;

  static Future<AgentEvaluationVerifiedProductionCustodyToken>
  verifyProductionCapability({
    required String capabilityHash,
    required int verifiedAtMs,
    required String nonce,
    required String keyId,
    required SimplePublicKey publicKey,
    required String signerCommandIdentityHash,
    required String runnerArtifactHash,
    required String payloadJson,
    required String signatureBase64,
    required int nowMs,
    Duration minimumRemainingTtl = Duration.zero,
  }) async {
    if (verifiedAtMs < 0 ||
        verifiedAtMs > nowMs ||
        nonce.length < 32 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(capabilityHash)) {
      throw const FormatException('production custody capability is invalid');
    }
    AgentEvaluationHashes.requireDigest(
      signerCommandIdentityHash,
      'signerCommandIdentityHash',
    );
    AgentEvaluationHashes.requireDigest(
      runnerArtifactHash,
      'runnerArtifactHash',
    );
    final capabilityPayload = <String, Object?>{
      'schemaVersion': 'agent-evaluation-public-custody-capability-v1',
      'keyId': keyId,
      'publicKeyBase64': base64Encode(publicKey.bytes),
      'signerCommandIdentityHash': signerCommandIdentityHash,
      'custodyAttestationPayloadJson': payloadJson,
      'custodyAttestationSignatureBase64': signatureBase64,
      'verifiedAtMs': verifiedAtMs,
      'nonce': nonce,
    };
    final expectedCapabilityHash = AgentEvaluationHashes.domainHash(
      'agent-evaluation-public-custody-capability-v1',
      capabilityPayload,
    );
    if (capabilityHash != expectedCapabilityHash) {
      throw const FormatException('production custody capability changed');
    }
    final productionRegistry =
        AgentEvaluationExternalCustodyTrustRegistry.production();
    if (!productionRegistry.productionPinned) {
      throw const FormatException('production custody registry is invalid');
    }
    final auditContract =
        await AgentEvaluationEvidenceCustodyContract.verifyExternal(
          payloadJson: payloadJson,
          signatureBase64: signatureBase64,
          trustRegistry: productionRegistry,
          expectedKeyId: keyId,
          expectedSigningPublicKey: publicKey,
          expectedRunnerArtifactHash: runnerArtifactHash,
          expectedSignerCommandIdentityHash: signerCommandIdentityHash,
          nowMs: nowMs,
          minimumRemainingTtl: minimumRemainingTtl,
        );
    final attestation =
        AgentEvaluationExternalCustodyAttestationPayload.fromCanonicalJson(
          payloadJson,
        );
    return AgentEvaluationVerifiedProductionCustodyToken._(
      capabilityHash: capabilityHash,
      verifiedAtMs: verifiedAtMs,
      nonce: nonce,
      keyId: keyId,
      publicKey: publicKey,
      signerCommandIdentityHash: signerCommandIdentityHash,
      runnerArtifactHash: runnerArtifactHash,
      payloadJson: payloadJson,
      signatureBase64: signatureBase64,
      auditContract: auditContract,
      baselineCriteriaSealHash: attestation.baselineCriteriaSealHash,
      baselineSourceTreeHash: attestation.baselineSourceTreeHash,
    );
  }

  @override
  final String capabilityHash;
  @override
  final String attestationHash;
  @override
  final int verifiedAtMs;
  @override
  final String nonce;
  final String keyId;
  final SimplePublicKey publicKey;
  final String signerCommandIdentityHash;
  final String runnerArtifactHash;
  final String payloadJson;
  final String signatureBase64;
  final AgentEvaluationEvidenceCustodyContract auditContract;
  final String baselineCriteriaSealHash;
  final String baselineSourceTreeHash;

  Future<void> reverify({
    required int nowMs,
    Duration minimumRemainingTtl = Duration.zero,
  }) async {
    final fresh = await verifyProductionCapability(
      capabilityHash: capabilityHash,
      verifiedAtMs: verifiedAtMs,
      nonce: nonce,
      keyId: keyId,
      publicKey: publicKey,
      signerCommandIdentityHash: signerCommandIdentityHash,
      runnerArtifactHash: runnerArtifactHash,
      payloadJson: payloadJson,
      signatureBase64: signatureBase64,
      nowMs: nowMs,
      minimumRemainingTtl: minimumRemainingTtl,
    );
    if (fresh.attestationHash != attestationHash ||
        fresh.auditContract.trustEntryHash != auditContract.trustEntryHash ||
        fresh.baselineCriteriaSealHash != baselineCriteriaSealHash ||
        fresh.baselineSourceTreeHash != baselineSourceTreeHash) {
      throw const FormatException('production custody proof changed');
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

final class AgentEvaluationEvidenceRetentionContract {
  AgentEvaluationEvidenceRetentionContract._({
    required this.level,
    required this.policyId,
    required this.custodyHash,
    required this.encryptedAtRest,
    required this.expiresAtMs,
    required this.encryptionPolicyHash,
    required this.blobIndexHash,
    required this.supportsRegrade,
    required this.supportsReExecute,
  });

  factory AgentEvaluationEvidenceRetentionContract.auditOnly({
    required AgentEvaluationEvidenceCustodyContract custody,
  }) => AgentEvaluationEvidenceRetentionContract._(
    level: AgentEvaluationEvidenceRetentionLevel.audit,
    policyId: custody.mode == AgentEvaluationEvidenceCustodyMode.localFileSeed
        ? 'audit-verifiable-local-custody-v1'
        : 'audit-verifiable-external-custody-v1',
    custodyHash: custody.custodyHash,
    encryptedAtRest: false,
    expiresAtMs: null,
    encryptionPolicyHash: null,
    blobIndexHash: null,
    supportsRegrade: false,
    supportsReExecute: false,
  );

  factory AgentEvaluationEvidenceRetentionContract.protectedReplay({
    required AgentEvaluationEvidenceCustodyContract custody,
    AgentEvaluationVerifiedProductionCustodyToken? custodyToken,
    required AgentEvaluationEvidenceRetentionLevel level,
    required String encryptionPolicyHash,
    required String blobIndexHash,
    required int expiresAtMs,
    required int nowMs,
  }) {
    if (custodyToken == null ||
        custodyToken.auditContract.custodyHash != custody.custodyHash ||
        level == AgentEvaluationEvidenceRetentionLevel.audit ||
        nowMs < 0 ||
        expiresAtMs <= nowMs) {
      throw ArgumentError(
        'replay retention requires current external KMS/ACL custody',
      );
    }
    AgentEvaluationHashes.requireDigest(
      encryptionPolicyHash,
      'encryptionPolicyHash',
    );
    AgentEvaluationHashes.requireDigest(blobIndexHash, 'blobIndexHash');
    return AgentEvaluationEvidenceRetentionContract._(
      level: level,
      policyId: level == AgentEvaluationEvidenceRetentionLevel.regrade
          ? 'encrypted-ttl-regrade-v1'
          : 'encrypted-ttl-re-execute-v1',
      custodyHash: custody.custodyHash,
      encryptedAtRest: true,
      expiresAtMs: expiresAtMs,
      encryptionPolicyHash: encryptionPolicyHash,
      blobIndexHash: blobIndexHash,
      supportsRegrade: true,
      supportsReExecute:
          level == AgentEvaluationEvidenceRetentionLevel.reExecute,
    );
  }

  final AgentEvaluationEvidenceRetentionLevel level;
  final String policyId;
  final String custodyHash;
  final bool encryptedAtRest;
  final int? expiresAtMs;
  final String? encryptionPolicyHash;
  final String? blobIndexHash;
  final bool supportsRegrade;
  final bool supportsReExecute;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'evidence-retention-contract-v1',
    'level': level.wireValue,
    'policyId': policyId,
    'custodyHash': custodyHash,
    'encryptedAtRest': encryptedAtRest,
    'expiresAtMs': expiresAtMs,
    'encryptionPolicyHash': encryptionPolicyHash,
    'blobIndexHash': blobIndexHash,
    'supportsRegrade': supportsRegrade,
    'supportsReExecute': supportsReExecute,
  };

  String get canonicalJson =>
      AgentEvaluationHashes.canonicalJson(toCanonicalMap());

  String get retentionHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-evidence-retention-contract-v1',
    toCanonicalMap(),
  );

  factory AgentEvaluationEvidenceRetentionContract.fromCanonicalJson(
    String source,
  ) {
    final value = _canonicalObject(source, 'evidence retention contract');
    const keys = <String>{
      'schemaVersion',
      'level',
      'policyId',
      'custodyHash',
      'encryptedAtRest',
      'expiresAtMs',
      'encryptionPolicyHash',
      'blobIndexHash',
      'supportsRegrade',
      'supportsReExecute',
    };
    _requireExactKeys(value, keys, 'evidence retention contract');
    if (value['schemaVersion'] != 'evidence-retention-contract-v1') {
      throw const FormatException('evidence retention schema is invalid');
    }
    final level = _enumValue(
      AgentEvaluationEvidenceRetentionLevel.values,
      _string(value, 'level'),
      (item) => item.wireValue,
      'retention level',
    );
    final custodyHash = _string(value, 'custodyHash');
    AgentEvaluationHashes.requireDigest(custodyHash, 'custodyHash');
    final encrypted = _boolean(value, 'encryptedAtRest');
    final expires = value['expiresAtMs'];
    final encryptionHash = value['encryptionPolicyHash'];
    final blobHash = value['blobIndexHash'];
    if (expires != null && expires is! int ||
        encryptionHash != null && encryptionHash is! String ||
        blobHash != null && blobHash is! String) {
      throw const FormatException('retention artifact claims are invalid');
    }
    if (encryptionHash is String) {
      AgentEvaluationHashes.requireDigest(
        encryptionHash,
        'encryptionPolicyHash',
      );
    }
    if (blobHash is String) {
      AgentEvaluationHashes.requireDigest(blobHash, 'blobIndexHash');
    }
    final supportsRegrade = _boolean(value, 'supportsRegrade');
    final supportsReExecute = _boolean(value, 'supportsReExecute');
    final isAudit = level == AgentEvaluationEvidenceRetentionLevel.audit;
    if ((isAudit &&
            (encrypted ||
                expires != null ||
                encryptionHash != null ||
                blobHash != null ||
                supportsRegrade ||
                supportsReExecute)) ||
        (!isAudit &&
            (!encrypted ||
                expires is! int ||
                encryptionHash is! String ||
                blobHash is! String ||
                !supportsRegrade ||
                (level == AgentEvaluationEvidenceRetentionLevel.regrade &&
                    supportsReExecute) ||
                (level == AgentEvaluationEvidenceRetentionLevel.reExecute &&
                    !supportsReExecute)))) {
      throw const FormatException('retention level overclaims its artifacts');
    }
    return AgentEvaluationEvidenceRetentionContract._(
      level: level,
      policyId: _string(value, 'policyId'),
      custodyHash: custodyHash,
      encryptedAtRest: encrypted,
      expiresAtMs: expires as int?,
      encryptionPolicyHash: encryptionHash as String?,
      blobIndexHash: blobHash as String?,
      supportsRegrade: supportsRegrade,
      supportsReExecute: supportsReExecute,
    );
  }
}

Map<String, Object?> _canonicalObject(String source, String label) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?> ||
      AgentEvaluationHashes.canonicalJson(decoded) != source) {
    throw FormatException('$label must be a canonical JSON object');
  }
  return decoded;
}

void _requireExactKeys(
  Map<String, Object?> value,
  Set<String> keys,
  String label,
) {
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty) {
    throw FormatException('$label fields are invalid');
  }
}

String _string(Map<String, Object?> value, String key) {
  final item = value[key];
  if (item is! String || item.trim().isEmpty) {
    throw FormatException('$key is invalid');
  }
  return item;
}

int _integer(Map<String, Object?> value, String key) {
  final item = value[key];
  if (item is! int) throw FormatException('$key is invalid');
  return item;
}

bool _boolean(Map<String, Object?> value, String key) {
  final item = value[key];
  if (item is! bool) throw FormatException('$key is invalid');
  return item;
}

T _enumValue<T>(
  List<T> values,
  String wireValue,
  String Function(T value) project,
  String label,
) {
  final matches = values.where((value) => project(value) == wireValue).toList();
  if (matches.length != 1) throw FormatException('$label is invalid');
  return matches.single;
}

void _requireArchiveRelativePath(String value, String label) {
  if (value.isEmpty ||
      value.length > 512 ||
      value.startsWith('/') ||
      value.contains('\\') ||
      value.contains('\n') ||
      value.contains('\u0000') ||
      value
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..') ||
      !RegExp(r'^[A-Za-z0-9._/-]+$').hasMatch(value)) {
    throw ArgumentError('$label must be a safe archive-relative path');
  }
}

void _requireSanitizedCommand(String value) {
  final lower = value.toLowerCase();
  final credentialAssignments = RegExp(
    r'(api[_-]?key|authorization|token|secret|password)\s*=\s*([^\s]+)',
    caseSensitive: false,
  ).allMatches(value).map((match) => match.group(2)!);
  final credentialFlags = RegExp(
    r'(?:^|\s)--?(?:api[_-]?key|authorization|token|secret|password)'
    r'(?:\s+|=)([^\s]+)',
    caseSensitive: false,
  ).allMatches(value).map((match) => match.group(1)!);
  final hasUnsanitizedCredential = <String>[
    ...credentialAssignments,
    ...credentialFlags,
  ].any((credential) => credential != '<redacted>');
  if (value.isEmpty ||
      value.length > 4096 ||
      value.contains('\n') ||
      value.contains('\u0000') ||
      lower.contains('authorization:') ||
      lower.contains('bearer ') ||
      lower.contains('begin private key') ||
      lower.contains('sk-') ||
      hasUnsanitizedCredential) {
    throw ArgumentError('criteria command contains unsanitized material');
  }
}

bool _orderedEquals(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
