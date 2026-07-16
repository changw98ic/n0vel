import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_external_custody_trust_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_spec_evidence.dart';

void main() {
  const sourceHash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const reportHash =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const artifactHash =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  AgentEvaluationSpecCriterionEvidence evidence(
    String criteriaId, {
    AgentEvaluationSpecCriteriaStatus status =
        AgentEvaluationSpecCriteriaStatus.passed,
    String? artifactPath,
    String? sanitizedCommand,
  }) => AgentEvaluationSpecCriterionEvidence(
    criteriaId: criteriaId,
    artifactPath: artifactPath ?? 'evidence/$criteriaId.json',
    artifactHash: artifactHash,
    sanitizedCommand:
        sanitizedCommand ?? 'flutter test test/$criteriaId.dart --no-pub',
    exitCode: status == AgentEvaluationSpecCriteriaStatus.notEvaluated ? -1 : 0,
    durationMs: status == AgentEvaluationSpecCriteriaStatus.notEvaluated
        ? 0
        : 12,
    sourceTreeHash: sourceHash,
    reportHash: reportHash,
    evidenceLevel:
        status == AgentEvaluationSpecCriteriaStatus.passed &&
            AgentEvaluationSpecCriteriaRegistry.realProviderCriteriaIds
                .contains(criteriaId)
        ? AgentEvaluationSpecEvidenceLevel.realProviderRelease
        : AgentEvaluationSpecEvidenceLevel.integration,
    retentionLevel: AgentEvaluationEvidenceRetentionLevel.audit,
    status: status,
  );

  test('criteria registry requires exactly AEE-01 through AEE-24', () {
    final entries = <AgentEvaluationSpecCriterionEvidence>[
      for (final id in AgentEvaluationSpecCriteriaRegistry.requiredCriteriaIds)
        evidence(id),
    ];
    final registry = AgentEvaluationSpecCriteriaRegistry(entries: entries);
    final seal = AgentEvaluationSpecCriteriaRegistrySeal.create(registry);

    expect(registry.entries, hasLength(24));
    expect(registry.allPassed, isTrue);
    expect(registry.requireAllPassedForRelease, returnsNormally);
    expect(
      registry.entries.map((entry) => entry.criteriaId),
      orderedEquals(AgentEvaluationSpecCriteriaRegistry.requiredCriteriaIds),
    );
    expect(
      AgentEvaluationSpecCriteriaRegistrySeal.fromCanonicalJson(
        seal.canonicalJson,
      ).registry.registryHash,
      registry.registryHash,
    );

    expect(
      () =>
          AgentEvaluationSpecCriteriaRegistry(entries: entries.sublist(0, 23)),
      throwsArgumentError,
    );
    expect(
      () => AgentEvaluationSpecCriteriaRegistry(
        entries: <AgentEvaluationSpecCriterionEvidence>[
          ...entries.take(23),
          evidence('AEE-23'),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('criteria and seal reject extra fields or modified evidence', () {
    final entries = <AgentEvaluationSpecCriterionEvidence>[
      for (final id in AgentEvaluationSpecCriteriaRegistry.requiredCriteriaIds)
        evidence(id),
    ];
    final registry = AgentEvaluationSpecCriteriaRegistry(entries: entries);
    final decoded = jsonDecode(registry.canonicalJson) as Map<String, Object?>;
    decoded['unexpected'] = true;
    expect(
      () => AgentEvaluationSpecCriteriaRegistry.fromCanonicalJson(
        AgentEvaluationHashes.canonicalJson(decoded),
      ),
      throwsFormatException,
    );

    final seal = AgentEvaluationSpecCriteriaRegistrySeal.create(registry);
    final sealMap = jsonDecode(seal.canonicalJson) as Map<String, Object?>;
    sealMap['registryHash'] = sourceHash;
    expect(
      () => AgentEvaluationSpecCriteriaRegistrySeal.fromCanonicalJson(
        AgentEvaluationHashes.canonicalJson(sealMap),
      ),
      throwsFormatException,
    );
  });

  test('criteria command is secret-safe and not-evaluated is explicit', () {
    expect(
      () => AgentEvaluationSpecCriterionEvidence(
        criteriaId: 'AEE-01',
        artifactPath: 'evidence/a.json',
        artifactHash: artifactHash,
        sanitizedCommand: 'ZHIPU_API_KEY=live-secret flutter test',
        exitCode: 0,
        durationMs: 1,
        sourceTreeHash: sourceHash,
        reportHash: reportHash,
        evidenceLevel: AgentEvaluationSpecEvidenceLevel.unit,
        retentionLevel: AgentEvaluationEvidenceRetentionLevel.audit,
        status: AgentEvaluationSpecCriteriaStatus.passed,
      ),
      throwsArgumentError,
    );
    expect(
      () => evidence(
        'AEE-01',
        status: AgentEvaluationSpecCriteriaStatus.notEvaluated,
      ),
      returnsNormally,
    );
    for (final command in <String>[
      'flutter test --api-key live-secret',
      'flutter test --token live-secret',
      'flutter test --password=live-secret',
      'API_KEY=<redacted> TOKEN=live-secret flutter test',
      'flutter test --api-key <redacted> --token live-secret',
    ]) {
      expect(
        () => evidence('AEE-01', sanitizedCommand: command),
        throwsArgumentError,
      );
    }
    expect(
      () => evidence('AEE-01', artifactPath: 'evidence/./a.json'),
      throwsArgumentError,
    );
  });

  test('real-provider criteria cannot pass on integration evidence', () {
    expect(
      () => AgentEvaluationSpecCriteriaRegistry(
        entries: <AgentEvaluationSpecCriterionEvidence>[
          for (final id
              in AgentEvaluationSpecCriteriaRegistry.requiredCriteriaIds)
            if (id != 'AEE-14')
              evidence(id)
            else
              AgentEvaluationSpecCriterionEvidence(
                criteriaId: id,
                artifactPath: 'evidence/$id.json',
                artifactHash: artifactHash,
                sanitizedCommand: 'flutter test test/$id.dart --no-pub',
                exitCode: 0,
                durationMs: 12,
                sourceTreeHash: sourceHash,
                reportHash: reportHash,
                evidenceLevel: AgentEvaluationSpecEvidenceLevel.integration,
                retentionLevel: AgentEvaluationEvidenceRetentionLevel.audit,
                status: AgentEvaluationSpecCriteriaStatus.passed,
              ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('production overlay preserves local baseline and upgrades real IDs', () {
    final baseline = AgentEvaluationSpecCriteriaRegistrySeal.create(
      AgentEvaluationSpecCriteriaRegistry(
        entries: <AgentEvaluationSpecCriterionEvidence>[
          for (final id
              in AgentEvaluationSpecCriteriaRegistry.requiredCriteriaIds)
            evidence(
              id,
              status:
                  AgentEvaluationSpecCriteriaRegistry.realProviderCriteriaIds
                      .contains(id)
                  ? AgentEvaluationSpecCriteriaStatus.notEvaluated
                  : AgentEvaluationSpecCriteriaStatus.passed,
            ),
        ],
      ),
    );
    final hashes = <String, String>{
      for (final id
          in AgentEvaluationSpecCriteriaRegistry.realProviderCriteriaIds)
        id: reportHash,
    };
    final combined = deriveAgentEvaluationProductionCriteriaSeal(
      baselineSeal: baseline,
      sourceTreeHash: sourceHash,
      productionArtifactPath: 'release/criteria.json',
      productionArtifactHash: artifactHash,
      productionCriterionReportHashes: hashes,
      sanitizedCommand:
          'dart run tool/agent_evaluation_release_coordinator.dart',
      durationMs: 25,
      retentionLevel: AgentEvaluationEvidenceRetentionLevel.audit,
    );

    expect(combined.registry.allPassed, isTrue);
    for (final entry in combined.registry.entries) {
      if (AgentEvaluationSpecCriteriaRegistry.realProviderCriteriaIds.contains(
        entry.criteriaId,
      )) {
        expect(
          entry.evidenceLevel,
          AgentEvaluationSpecEvidenceLevel.realProviderRelease,
        );
        expect(entry.artifactPath, 'release/criteria.json');
      } else {
        expect(
          entry.toCanonicalMap(),
          baseline.registry.entries
              .singleWhere((item) => item.criteriaId == entry.criteriaId)
              .toCanonicalMap(),
        );
      }
    }
  });

  test('production baseline loader reverifies every retained artifact', () {
    final createdRoot = Directory.systemTemp.createTempSync(
      'criteria-baseline-',
    );
    final root = Directory(createdRoot.resolveSymbolicLinksSync());
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final entries = <AgentEvaluationSpecCriterionEvidence>[];
    for (final id in AgentEvaluationSpecCriteriaRegistry.requiredCriteriaIds) {
      final file = File('${root.path}/evidence/$id.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"criterion":"$id"}', flush: true);
      final digest = const DartSha256()
          .hashSync(file.readAsBytesSync())
          .bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final productionOnly = AgentEvaluationSpecCriteriaRegistry
          .realProviderCriteriaIds
          .contains(id);
      entries.add(
        AgentEvaluationSpecCriterionEvidence(
          criteriaId: id,
          artifactPath: 'evidence/$id.json',
          artifactHash: digest,
          sanitizedCommand: 'flutter test --no-pub',
          exitCode: productionOnly ? -1 : 0,
          durationMs: productionOnly ? 0 : 1,
          sourceTreeHash: sourceHash,
          reportHash: reportHash,
          evidenceLevel: AgentEvaluationSpecEvidenceLevel.integration,
          retentionLevel: AgentEvaluationEvidenceRetentionLevel.audit,
          status: productionOnly
              ? AgentEvaluationSpecCriteriaStatus.notEvaluated
              : AgentEvaluationSpecCriteriaStatus.passed,
        ),
      );
    }
    final seal = AgentEvaluationSpecCriteriaRegistrySeal.create(
      AgentEvaluationSpecCriteriaRegistry(entries: entries),
    );
    final sealFile = File('${root.path}/seal.json')
      ..writeAsStringSync(seal.canonicalJson, flush: true);
    if (!Platform.isWindows) {
      final chmod = Process.runSync('/bin/chmod', <String>[
        '600',
        sealFile.path,
      ]);
      expect(chmod.exitCode, 0);
    }

    expect(
      loadAndVerifyAgentEvaluationProductionCriteriaBaseline(
        sealPath: sealFile.path,
        sourceTreeHash: sourceHash,
      ).sealHash,
      seal.sealHash,
    );
    if (!Platform.isWindows) {
      final linkedArtifact = File('${root.path}/evidence/AEE-02.json');
      final linkedContent = linkedArtifact.readAsStringSync();
      final linkedTarget = File('${root.path}/linked-target.json')
        ..writeAsStringSync(linkedContent, flush: true);
      linkedArtifact.deleteSync();
      Link(linkedArtifact.path).createSync(linkedTarget.path);
      expect(
        () => loadAndVerifyAgentEvaluationProductionCriteriaBaseline(
          sealPath: sealFile.path,
          sourceTreeHash: sourceHash,
        ),
        throwsFormatException,
      );
      Link(linkedArtifact.path).deleteSync();
      linkedArtifact.writeAsStringSync(linkedContent, flush: true);
    }
    File(
      '${root.path}/evidence/AEE-01.json',
    ).writeAsStringSync('{"criterion":"tampered"}', flush: true);
    expect(
      () => loadAndVerifyAgentEvaluationProductionCriteriaBaseline(
        sealPath: sealFile.path,
        sourceTreeHash: sourceHash,
      ),
      throwsFormatException,
    );
  });

  test('release eligibility rejects any non-passed criterion', () {
    final registry = AgentEvaluationSpecCriteriaRegistry(
      entries: <AgentEvaluationSpecCriterionEvidence>[
        for (final id
            in AgentEvaluationSpecCriteriaRegistry.requiredCriteriaIds)
          evidence(
            id,
            status: id == 'AEE-23'
                ? AgentEvaluationSpecCriteriaStatus.notEvaluated
                : AgentEvaluationSpecCriteriaStatus.passed,
          ),
      ],
    );

    expect(registry.allPassed, isFalse);
    expect(registry.requireAllPassedForRelease, throwsFormatException);
    final seal = AgentEvaluationSpecCriteriaRegistrySeal.create(registry);
    expect(
      deriveAgentEvaluationCriteriaReleaseEligibility(
        prerequisitesMet: true,
        criteriaSeal: seal,
      ),
      isFalse,
    );
    expect(
      () => verifyAgentEvaluationCriteriaReleaseClaim(
        releaseEligible: true,
        criteriaSeal: seal,
      ),
      throwsFormatException,
    );
  });

  test('local file custody is audit-only and never release-authoritative', () {
    final custody = AgentEvaluationEvidenceCustodyContract.localFileSeed(
      keyId: 'local-key-v1',
      publicKeyHash: sourceHash,
      runnerArtifactHash: reportHash,
    );
    final retention = AgentEvaluationEvidenceRetentionContract.auditOnly(
      custody: custody,
    );

    expect(custody.releaseAuthorityEligible, isFalse);
    expect(custody.mode, AgentEvaluationEvidenceCustodyMode.localFileSeed);
    expect(retention.level, AgentEvaluationEvidenceRetentionLevel.audit);
    expect(retention.supportsRegrade, isFalse);
    expect(retention.supportsReExecute, isFalse);
    expect(retention.canonicalJson, isNot(contains('immutable')));
    expect(retention.canonicalJson, isNot(contains('regrade')));
    expect(retention.canonicalJson, isNot(contains('re-execute')));

    expect(
      () => AgentEvaluationEvidenceRetentionContract.protectedReplay(
        custody: custody,
        level: AgentEvaluationEvidenceRetentionLevel.regrade,
        encryptionPolicyHash: artifactHash,
        blobIndexHash: reportHash,
        expiresAtMs: 200,
        nowMs: 100,
      ),
      throwsArgumentError,
    );

    final forgedCustody =
        jsonDecode(custody.canonicalJson) as Map<String, Object?>;
    forgedCustody['releaseAuthorityEligible'] = true;
    expect(
      () => AgentEvaluationEvidenceCustodyContract.fromCanonicalJson(
        AgentEvaluationHashes.canonicalJson(forgedCustody),
      ),
      throwsFormatException,
    );
    forgedCustody['releaseAuthorityEligible'] = false;
    forgedCustody['productionTrustPinned'] = true;
    expect(
      () => AgentEvaluationEvidenceCustodyContract.fromCanonicalJson(
        AgentEvaluationHashes.canonicalJson(forgedCustody),
      ),
      throwsFormatException,
    );
    final missingCustody =
        jsonDecode(custody.canonicalJson) as Map<String, Object?>;
    missingCustody.remove('independentAcl');
    expect(
      () => AgentEvaluationEvidenceCustodyContract.fromCanonicalJson(
        AgentEvaluationHashes.canonicalJson(missingCustody),
      ),
      throwsFormatException,
    );
    final overclaimedRetention =
        jsonDecode(retention.canonicalJson) as Map<String, Object?>;
    overclaimedRetention['supportsRegrade'] = true;
    expect(
      () => AgentEvaluationEvidenceRetentionContract.fromCanonicalJson(
        AgentEvaluationHashes.canonicalJson(overclaimedRetention),
      ),
      throwsFormatException,
    );
  });

  test(
    'external custody requires a valid independent signed attestation',
    () async {
      final root = await DartEd25519().newKeyPairFromSeed(
        List<int>.generate(32, (index) => index + 1),
      );
      final publicKey = await root.extractPublicKey();
      final signingKeyPair = await DartEd25519().newKeyPairFromSeed(
        List<int>.generate(32, (index) => index + 41),
      );
      final signingPublicKey = await signingKeyPair.extractPublicKey();
      final auditRegistry =
          AgentEvaluationExternalCustodyTrustRegistry.auditOnly(
            entries: <AgentEvaluationExternalCustodyTrustEntry>[
              AgentEvaluationExternalCustodyTrustEntry(
                rootKeyId: 'deployment-root-v1',
                rootPublicKeyBase64: base64Encode(publicKey.bytes),
                kmsProviderReleaseHash: sourceHash,
                kmsKeyResourceHash: reportHash,
                allowedRunnerPrincipalHashes: const <String>[artifactHash],
                allowedSigningKeyIds: const <String>['kms-key-v1'],
                macTeamIdentifier: 'AUDITTEST1',
                macDesignatedRequirement: 'identifier "audit.test"',
                macCdHash: 'A' * 40,
                runtimeAppTeamIdentifier: 'RUNTIME001',
                runtimeAppDesignatedRequirement:
                    'identifier "runtime.audit.test"',
                runtimeAppCdHash: 'B' * 40,
                runtimeAppAuthorityChain: const <String>[
                  'Audit Runtime Authority',
                ],
              ),
            ],
          );
      final payload = AgentEvaluationExternalCustodyAttestationPayload(
        rootKeyId: 'deployment-root-v1',
        keyId: 'kms-key-v1',
        keyVersion: '7',
        signingPublicKeyHash: AgentEvaluationHashes.domainHash(
          'agent-evaluation-holdout-public-key-v1',
          base64Encode(signingPublicKey.bytes),
        ),
        kmsProviderReleaseHash: sourceHash,
        kmsKeyResourceHash: reportHash,
        runnerPrincipalHash: artifactHash,
        runnerArtifactHash: sourceHash,
        signerCommandIdentityHash: artifactHash,
        fixtureStorePolicyHash: reportHash,
        retentionPolicyHash: artifactHash,
        baselineCriteriaSealHash: artifactHash,
        baselineSourceTreeHash: sourceHash,
        issuedAtMs: 100,
        expiresAtMs: 200,
      );
      final signature = await DartEd25519().sign(
        utf8.encode(payload.canonicalJson),
        keyPair: root,
      );
      final custody =
          await AgentEvaluationEvidenceCustodyContract.verifyExternal(
            payloadJson: payload.canonicalJson,
            signatureBase64: base64Encode(signature.bytes),
            trustRegistry: auditRegistry,
            expectedKeyId: 'kms-key-v1',
            expectedSigningPublicKey: signingPublicKey,
            expectedRunnerArtifactHash: sourceHash,
            expectedSignerCommandIdentityHash: artifactHash,
            nowMs: 150,
          );

      expect(custody.releaseAuthorityEligible, isFalse);
      expect(custody.productionTrustPinned, isFalse);
      expect(
        custody.mode,
        AgentEvaluationEvidenceCustodyMode.externallyAttestedNonExportableKms,
      );
      expect(
        () => AgentEvaluationEvidenceCustodyContract.fromCanonicalJson(
          custody.canonicalJson,
        ),
        returnsNormally,
      );

      await expectLater(
        AgentEvaluationEvidenceCustodyContract.verifyExternal(
          payloadJson: payload.canonicalJson,
          signatureBase64: base64Encode(signature.bytes),
          trustRegistry:
              AgentEvaluationExternalCustodyTrustRegistry.production(),
          expectedKeyId: 'kms-key-v1',
          expectedSigningPublicKey: signingPublicKey,
          expectedRunnerArtifactHash: sourceHash,
          expectedSignerCommandIdentityHash: artifactHash,
          nowMs: 150,
        ),
        throwsFormatException,
      );
      for (final entry in <AgentEvaluationExternalCustodyTrustEntry>[
        AgentEvaluationExternalCustodyTrustEntry(
          rootKeyId: 'deployment-root-v1',
          rootPublicKeyBase64: base64Encode(publicKey.bytes),
          kmsProviderReleaseHash: reportHash,
          kmsKeyResourceHash: reportHash,
          allowedRunnerPrincipalHashes: const <String>[artifactHash],
          allowedSigningKeyIds: const <String>['kms-key-v1'],
          macTeamIdentifier: 'AUDITTEST1',
          macDesignatedRequirement: 'identifier "audit.test"',
          macCdHash: 'A' * 40,
          runtimeAppTeamIdentifier: 'RUNTIME001',
          runtimeAppDesignatedRequirement: 'identifier "runtime.audit.test"',
          runtimeAppCdHash: 'B' * 40,
          runtimeAppAuthorityChain: const <String>['Audit Runtime Authority'],
        ),
        AgentEvaluationExternalCustodyTrustEntry(
          rootKeyId: 'deployment-root-v1',
          rootPublicKeyBase64: base64Encode(publicKey.bytes),
          kmsProviderReleaseHash: sourceHash,
          kmsKeyResourceHash: artifactHash,
          allowedRunnerPrincipalHashes: const <String>[artifactHash],
          allowedSigningKeyIds: const <String>['kms-key-v1'],
          macTeamIdentifier: 'AUDITTEST1',
          macDesignatedRequirement: 'identifier "audit.test"',
          macCdHash: 'A' * 40,
          runtimeAppTeamIdentifier: 'RUNTIME001',
          runtimeAppDesignatedRequirement: 'identifier "runtime.audit.test"',
          runtimeAppCdHash: 'B' * 40,
          runtimeAppAuthorityChain: const <String>['Audit Runtime Authority'],
        ),
        AgentEvaluationExternalCustodyTrustEntry(
          rootKeyId: 'deployment-root-v1',
          rootPublicKeyBase64: base64Encode(publicKey.bytes),
          kmsProviderReleaseHash: sourceHash,
          kmsKeyResourceHash: reportHash,
          allowedRunnerPrincipalHashes: const <String>[sourceHash],
          allowedSigningKeyIds: const <String>['kms-key-v1'],
          macTeamIdentifier: 'AUDITTEST1',
          macDesignatedRequirement: 'identifier "audit.test"',
          macCdHash: 'A' * 40,
          runtimeAppTeamIdentifier: 'RUNTIME001',
          runtimeAppDesignatedRequirement: 'identifier "runtime.audit.test"',
          runtimeAppCdHash: 'B' * 40,
          runtimeAppAuthorityChain: const <String>['Audit Runtime Authority'],
        ),
        AgentEvaluationExternalCustodyTrustEntry(
          rootKeyId: 'deployment-root-v1',
          rootPublicKeyBase64: base64Encode(publicKey.bytes),
          kmsProviderReleaseHash: sourceHash,
          kmsKeyResourceHash: reportHash,
          allowedRunnerPrincipalHashes: const <String>[artifactHash],
          allowedSigningKeyIds: const <String>['different-key'],
          macTeamIdentifier: 'AUDITTEST1',
          macDesignatedRequirement: 'identifier "audit.test"',
          macCdHash: 'A' * 40,
          runtimeAppTeamIdentifier: 'RUNTIME001',
          runtimeAppDesignatedRequirement: 'identifier "runtime.audit.test"',
          runtimeAppCdHash: 'B' * 40,
          runtimeAppAuthorityChain: const <String>['Audit Runtime Authority'],
        ),
      ]) {
        await expectLater(
          AgentEvaluationEvidenceCustodyContract.verifyExternal(
            payloadJson: payload.canonicalJson,
            signatureBase64: base64Encode(signature.bytes),
            trustRegistry:
                AgentEvaluationExternalCustodyTrustRegistry.auditOnly(
                  entries: <AgentEvaluationExternalCustodyTrustEntry>[entry],
                ),
            expectedKeyId: 'kms-key-v1',
            expectedSigningPublicKey: signingPublicKey,
            expectedRunnerArtifactHash: sourceHash,
            expectedSignerCommandIdentityHash: artifactHash,
            nowMs: 150,
          ),
          throwsFormatException,
        );
      }
      await expectLater(
        AgentEvaluationEvidenceCustodyContract.verifyExternal(
          payloadJson: payload.canonicalJson,
          signatureBase64: base64Encode(signature.bytes),
          trustRegistry: auditRegistry,
          expectedKeyId: 'kms-key-v1',
          expectedSigningPublicKey: signingPublicKey,
          expectedRunnerArtifactHash: sourceHash,
          expectedSignerCommandIdentityHash: artifactHash,
          nowMs: 150,
          minimumRemainingTtl: const Duration(milliseconds: 51),
        ),
        throwsFormatException,
      );

      await expectLater(
        AgentEvaluationEvidenceCustodyContract.verifyExternal(
          payloadJson: payload.canonicalJson,
          signatureBase64: base64Encode(<int>[...signature.bytes]..[0] ^= 0xff),
          trustRegistry: auditRegistry,
          expectedKeyId: 'kms-key-v1',
          expectedSigningPublicKey: signingPublicKey,
          expectedRunnerArtifactHash: sourceHash,
          expectedSignerCommandIdentityHash: artifactHash,
          nowMs: 150,
        ),
        throwsFormatException,
      );
      await expectLater(
        AgentEvaluationEvidenceCustodyContract.verifyExternal(
          payloadJson: payload.canonicalJson,
          signatureBase64: base64Encode(signature.bytes),
          trustRegistry: AgentEvaluationExternalCustodyTrustRegistry.auditOnly(
            entries: <AgentEvaluationExternalCustodyTrustEntry>[
              AgentEvaluationExternalCustodyTrustEntry(
                rootKeyId: 'deployment-root-v1',
                rootPublicKeyBase64: base64Encode(signingPublicKey.bytes),
                kmsProviderReleaseHash: sourceHash,
                kmsKeyResourceHash: reportHash,
                allowedRunnerPrincipalHashes: const <String>[artifactHash],
                allowedSigningKeyIds: const <String>['kms-key-v1'],
                macTeamIdentifier: 'AUDITTEST1',
                macDesignatedRequirement: 'identifier "audit.test"',
                macCdHash: 'A' * 40,
                runtimeAppTeamIdentifier: 'RUNTIME001',
                runtimeAppDesignatedRequirement:
                    'identifier "runtime.audit.test"',
                runtimeAppCdHash: 'B' * 40,
                runtimeAppAuthorityChain: const <String>[
                  'Audit Runtime Authority',
                ],
              ),
            ],
          ),
          expectedKeyId: 'kms-key-v1',
          expectedSigningPublicKey: signingPublicKey,
          expectedRunnerArtifactHash: sourceHash,
          expectedSignerCommandIdentityHash: artifactHash,
          nowMs: 150,
        ),
        throwsFormatException,
      );
      await expectLater(
        AgentEvaluationEvidenceCustodyContract.verifyExternal(
          payloadJson: payload.canonicalJson,
          signatureBase64: base64Encode(signature.bytes),
          trustRegistry: auditRegistry,
          expectedKeyId: 'different-kms-key',
          expectedSigningPublicKey: signingPublicKey,
          expectedRunnerArtifactHash: sourceHash,
          expectedSignerCommandIdentityHash: artifactHash,
          nowMs: 150,
        ),
        throwsFormatException,
      );
      await expectLater(
        AgentEvaluationEvidenceCustodyContract.verifyExternal(
          payloadJson: payload.canonicalJson,
          signatureBase64: base64Encode(signature.bytes),
          trustRegistry: auditRegistry,
          expectedKeyId: 'kms-key-v1',
          expectedSigningPublicKey: signingPublicKey,
          expectedRunnerArtifactHash: sourceHash,
          expectedSignerCommandIdentityHash: reportHash,
          nowMs: 150,
        ),
        throwsFormatException,
      );
      final extra = jsonDecode(payload.canonicalJson) as Map<String, Object?>;
      extra['callerSaysKms'] = true;
      await expectLater(
        AgentEvaluationEvidenceCustodyContract.verifyExternal(
          payloadJson: AgentEvaluationHashes.canonicalJson(extra),
          signatureBase64: base64Encode(signature.bytes),
          trustRegistry: auditRegistry,
          expectedKeyId: 'kms-key-v1',
          expectedSigningPublicKey: signingPublicKey,
          expectedRunnerArtifactHash: sourceHash,
          expectedSignerCommandIdentityHash: artifactHash,
          nowMs: 150,
        ),
        throwsFormatException,
      );
    },
  );
}
