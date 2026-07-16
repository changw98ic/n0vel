import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_promotion_performance_authority.dart';
import 'package:novel_writer/features/story_generation/data/scene_hard_gates.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/agent_adversarial_scenarios.dart';

void main() {
  late Directory suiteDirectory;
  late Directory authorityDirectory;
  late List<AgentAdversarialProductionPathEvidence> evidence;
  late AgentAdversarialProductionEvidenceArchive archive;
  late String archiveSource;

  setUpAll(() async {
    suiteDirectory = Directory.systemTemp.createTempSync(
      'agent-adversarial-production-suite-',
    );
    final output = File('${suiteDirectory.path}/evidence.json');
    authorityDirectory = Directory('${suiteDirectory.path}/work');
    archive = await AgentAdversarialProductionPathRunner().runAndArchive(
      workDirectory: authorityDirectory,
      outputPath: output.path,
    );
    evidence = archive.evidence;
    archiveSource = output.readAsStringSync();
  });

  tearDownAll(() {
    if (suiteDirectory.existsSync()) suiteDirectory.deleteSync(recursive: true);
  });

  test('production registry exactly covers all 50 catalog scenario IDs', () {
    final registered = AgentAdversarialProductionCaseRegistry.cases;
    final catalog = AgentAdversarialScenarioCatalog.specV1();

    expect(registered, hasLength(50));
    expect(
      registered.map((item) => item.scenarioId).toSet(),
      catalog.scenarios.map((item) => item.scenarioId).toSet(),
    );
    expect(registered.map((item) => item.scenarioId).toSet(), hasLength(50));
  });

  test('all pairs use registered production authorities', () async {
    const implementedCases = <int>{
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
    };
    final implemented = evidence
        .where((item) => implementedCases.contains(item.caseNumber))
        .toList(growable: false);
    final missing = evidence
        .where((item) => !implementedCases.contains(item.caseNumber))
        .toList(growable: false);

    expect(evidence, hasLength(50));
    expect(implemented, hasLength(50));
    for (final item in implemented) {
      expect(item.passed, isTrue, reason: jsonEncode(item.toJson()));
    }
    expect(
      implemented
          .where((item) => item.caseNumber <= 3)
          .every(
            (item) =>
                item.status ==
                    AgentAdversarialProductionEvidenceStatus.passed &&
                item.entryReleaseHash == sceneHardGateReleaseHash &&
                item.releaseMembershipHash != null &&
                item.authoritySources.length == 1 &&
                item.authoritySources.single.sourceType ==
                    'scene-hard-gate-receipt' &&
                item.authoritySources.single.releaseHash ==
                    sceneHardGateReleaseHash &&
                item.authoritySources.single.sourceHash.startsWith('sha256:'),
          ),
      isTrue,
    );
    expect(missing, isEmpty);
  });

  test(
    'implemented attack/control pairs follow distinct authority roots',
    () async {
      for (var caseNumber = 1; caseNumber <= 3; caseNumber += 1) {
        final pair = evidence
            .where((item) => item.caseNumber == caseNumber)
            .toList(growable: false);
        expect(pair, hasLength(2));
        expect(pair.map((item) => item.variant).toSet(), <String>{
          'attack',
          'control',
        });
        expect(
          pair.map((item) => item.authorityRootHash).toSet(),
          hasLength(2),
        );
        expect(pair.map((item) => item.actualOutcome).toSet(), <String>{
          'blocked',
          'accepted',
        });
      }
    },
  );

  test('private memory pair uses production hybrid RAG admission', () async {
    final pair = evidence.where((item) => item.caseNumber == 8).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    expect(
      pair.every(
        (item) =>
            item.authoritySources.single.sourceType ==
            'hybrid-rag-private-memory-admission-receipt',
      ),
      isTrue,
    );
  });

  test('expected-block pair is derived by the real production runner', () {
    final pair = evidence.where((item) => item.caseNumber == 20).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    for (final item in pair) {
      final source = item.authoritySources.single;
      expect(source.sourceType, 'runner-production-expected-outcome-receipt');
      expect(source.payload['comparisonHardPass'], isTrue);
      expect(source.payload['productionAuthorityReceiptCount'], 1);
      expect(source.payload['productionAuthoritativeWriteCount'], 0);
      expect(source.payload['comparatorInEvaluationBundle'], isTrue);
    }
  });

  test('polish canon pair is enforced by the durable candidate finalizer', () {
    final pair = evidence.where((item) => item.caseNumber == 7).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    final control = pair.singleWhere((item) => item.variant == 'control');
    expect(attack.authoritySources.single.payload['finalizerRejected'], isTrue);
    expect(attack.authoritySources.single.payload['proofCount'], 0);
    expect(
      control.authoritySources.single.payload['finalizerRejected'],
      isFalse,
    );
    expect(control.authoritySources.single.payload['proofCount'], 1);
    expect(
      control.authoritySources.single.payload['deterministicGateEvidenceHash'],
      isNotNull,
    );
  });

  test('story mechanics pairs cross real HTTP pipeline and v3 finalizer', () {
    for (var caseNumber = 4; caseNumber <= 6; caseNumber += 1) {
      final pair = evidence
          .where((item) => item.caseNumber == caseNumber)
          .toList();
      expect(pair, hasLength(2));
      expect(pair.every((item) => item.passed), isTrue);
      final attack = pair.singleWhere((item) => item.variant == 'attack');
      final control = pair.singleWhere((item) => item.variant == 'control');
      expect(
        attack.authoritySources.single.payload['pipelineRejected'],
        isTrue,
      );
      expect(attack.authoritySources.single.payload['proofCount'], 0);
      expect(attack.authoritySources.single.payload['httpDispatchCount'], 1);
      expect(
        control.authoritySources.single.payload['pipelineRejected'],
        isFalse,
      );
      expect(control.authoritySources.single.payload['proofCount'], 1);
      expect(
        control.authoritySources.single.payload['payloadSchemaVersion'],
        'candidate-quality-payload-v3',
      );
      expect(control.authoritySources.single.payload['httpDispatchCount'], 1);
    }
  });

  test('RAG starvation pair admits one Canon past 4096 private rows', () {
    final pair = evidence.where((item) => item.caseNumber == 9).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    expect(
      pair.every(
        (item) =>
            item.authoritySources.single.sourceType ==
            'hybrid-rag-sql-admission-receipt',
      ),
      isTrue,
    );
  });

  test('crash recovery pair crosses killed helper process boundaries', () {
    final pair = evidence.where((item) => item.caseNumber == 10).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    expect(
      pair.every(
        (item) =>
            item.authoritySources.single.sourceType ==
                'generation-ledger-cross-process-recovery-authority' &&
            item.authoritySources.single.payload['phaseOneKilled'] == true &&
            item.authoritySources.single.payload['distinctProcesses'] == true,
      ),
      isTrue,
    );
    expect(
      pair
          .singleWhere((item) => item.variant == 'attack')
          .authoritySources
          .single
          .payload['conflictingReplayRejected'],
      isTrue,
    );
  });

  test('accept CAS pair uses four worker isolates and two SQLite races', () {
    final pair = evidence.where((item) => item.caseNumber == 12).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    expect(
      pair.every(
        (item) =>
            item.authoritySources.single.sourceType ==
                'generation-commit-concurrent-cas-authority' &&
            item.authoritySources.single.payload['workerIsolateCount'] == 4,
      ),
      isTrue,
    );
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    expect(
      attack.authoritySources.single.payload['materialWorkerStatuses'],
      <String>['materialConflict', 'materialConflict'],
    );
    expect(
      attack.authoritySources.single.payload['idempotencyResult'],
      'idempotencyConflict',
    );
  });

  test('transport matrix crosses production HTTP IO and metered failover', () {
    final pair = evidence.where((item) => item.caseNumber == 11).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    final payload = attack.authoritySources.single.payload;
    expect(
      attack.authoritySources.single.sourceType,
      'metered-http-transport-matrix-authority',
    );
    expect(payload['classifications'], <String>[
      'timeout',
      'rateLimited',
      'invalidResponse',
      'invalidResponse',
    ]);
    expect(payload['failureKinds'], <String, int>{
      'timeout': 1,
      'rateLimited': 2,
      'invalidResponse': 2,
    });
    expect(payload['duplicateDetected'], isTrue);
    expect(payload['failoverAttemptCount'], 2);
    expect(payload['totalPhysicalRequests'], 10);
    expect(payload['meteredCallCount'], 8);
    expect(payload['replacementDenied'], isTrue);
  });

  test('provider failures remain metered through production HTTP IO', () {
    final pair = evidence.where((item) => item.caseNumber == 18).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    expect(
      attack.authoritySources.single.payload['providerDispatchCount'],
      100,
    );
    expect(attack.authoritySources.single.payload['providerFailedCalls'], 97);
    expect(attack.authoritySources.single.payload['providerSucceededCalls'], 3);
    expect(attack.authoritySources.single.payload['replacementDenied'], isTrue);
  });

  test('promotion performance pair is rederived from sealed 60-slot DBs', () {
    final pair = evidence.where((item) => item.caseNumber == 15).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    final control = pair.singleWhere((item) => item.variant == 'control');
    expect(attack.authoritySources.single.payload['status'], 'reject');
    expect(attack.authoritySources.single.payload['reasons'], <String>[
      'costRegression',
    ]);
    expect(
      attack.authoritySources.single.payload['costRegressionBasisPoints']
          as int,
      greaterThan(1500),
    );
    expect(control.authoritySources.single.payload['status'], 'promote');
    expect(control.authoritySources.single.payload['reasons'], isEmpty);
    expect(
      control.authoritySources.single.payload['costRegressionBasisPoints']
          as int,
      lessThanOrEqualTo(1500),
    );
    expect(control.authoritySources.single.payload['slotCount'], 60);
    expect(
      control.authoritySources.single.payload['sutProviderCallCount'],
      AgentEvaluationPromotionPerformanceScenario.expectedSutProviderCallCount,
    );
  });

  test('scorer isolation ignores the SUT fixed-high quality claim', () {
    final pair = evidence.where((item) => item.caseNumber == 16).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    final control = pair.singleWhere((item) => item.variant == 'control');
    expect(
      attack.authoritySources.single.payload['sutOverallMicros'],
      100000000,
    );
    expect(attack.authoritySources.single.payload['judgeAccepted'], isFalse);
    expect(
      control.authoritySources.single.payload['sutOverallMicros'],
      96000000,
    );
    expect(control.authoritySources.single.payload['judgeAccepted'], isTrue);
    expect(
      attack.authoritySources.single.payload['pipelinePhysicalRequests'],
      3,
    );
    expect(attack.authoritySources.single.payload['judgePhysicalRequests'], 1);
  });

  test('cache provenance is derived from immutable runner receipts', () {
    final pair = evidence.where((item) => item.caseNumber == 17).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    final control = pair.singleWhere((item) => item.variant == 'control');
    expect(attack.authoritySources.single.payload['providerDispatchCount'], 2);
    expect(attack.authoritySources.single.payload['crossSlotReceiptCount'], 0);
    expect(
      attack.authoritySources.single.payload['nonIndependentOutcomeCount'],
      0,
    );
    expect(control.authoritySources.single.payload['providerDispatchCount'], 2);
    expect(
      control.authoritySources.single.payload['forgedCallerClaimIgnored'],
      isTrue,
    );
  });

  test('release CAS pair binds four process receipts and epoch-two head', () {
    final pair = evidence.where((item) => item.caseNumber == 21).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    final control = pair.singleWhere((item) => item.variant == 'control');
    expect(attack.authoritySources.single.payload['processCount'], 4);
    expect(
      attack.authoritySources.single.payload['multipleWinnersRejected'],
      isTrue,
    );
    expect(control.authoritySources.single.payload['processCount'], 4);
    expect(control.authoritySources.single.payload['finalEpoch'], 2);
    expect(control.authoritySources.single.payload['decisionCount'], 2);
    expect(control.authoritySources.single.payload['authorizationCount'], 1);
    expect(
      control.authoritySources.single.payload['recoveryStatus'],
      'casConflict',
    );
  });

  test(
    'judge injection pair uses frozen independent judge safety receipts',
    () {
      final pair = evidence.where((item) => item.caseNumber == 22).toList();
      expect(pair, hasLength(2));
      expect(pair.every((item) => item.passed), isTrue);
      final attack = pair.singleWhere((item) => item.variant == 'attack');
      final control = pair.singleWhere((item) => item.variant == 'control');
      final attackReceipt =
          attack.authoritySources.single.payload['judgeReceipt']!
              as Map<String, Object?>;
      final controlReceipt =
          control.authoritySources.single.payload['judgeReceipt']!
              as Map<String, Object?>;
      expect(attackReceipt['guardFailureCodes'], <String>[
        'judge_injection_rubric_override',
        'judge_injection_secret_leak',
      ]);
      expect(controlReceipt['guardFailureCodes'], isEmpty);
      expect(attackReceipt['detectedInjectionMarkerHashes'], hasLength(3));
      expect(controlReceipt['detectedInjectionMarkerHashes'], hasLength(3));
      expect(
        attack.authoritySources.single.payload['judgePhysicalRequests'],
        1,
      );
    },
  );

  test('holdout reuse pair re-derives one-access strict report authority', () {
    final pair = evidence.where((item) => item.caseNumber == 23).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    final control = pair.singleWhere((item) => item.variant == 'control');
    expect(
      attack.authoritySources.single.payload['secondAccessRejected'],
      isTrue,
    );
    expect(
      attack.authoritySources.single.payload['reportProjectionMatches'],
      isFalse,
    );
    expect(
      control.authoritySources.single.payload['secondAccessAttempted'],
      isFalse,
    );
    expect(
      control.authoritySources.single.payload['reportProjectionMatches'],
      isTrue,
    );
    expect(control.authoritySources.single.payload['accessCount'], 1);
    expect(control.authoritySources.single.payload['claimCount'], 1);
    expect(control.authoritySources.single.payload['authorizationCount'], 1);
  });

  test('cell-shape mutations fail at manifest preflight before provider', () {
    final pair = evidence.where((item) => item.caseNumber == 25).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    expect(
      pair.every(
        (item) =>
            item.authoritySources.single.sourceType ==
            'manifest-cell-preflight-authority',
      ),
      isTrue,
    );
  });

  test('manifest-shape invariants all fail before provider', () {
    final pair = evidence.where((item) => item.caseNumber == 14).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    expect(
      pair.every(
        (item) =>
            item.authoritySources.single.sourceType ==
            'manifest-preflight-authority',
      ),
      isTrue,
    );
  });

  test('prompt release authority rejects identity and old-schema attacks', () {
    final pair = evidence.where((item) => item.caseNumber == 13).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    expect(
      pair.every(
        (item) =>
            item.authoritySources.single.sourceType ==
            'prompt-release-store-authority',
      ),
      isTrue,
    );
  });

  test('stale lease pair fences every ledger mutation and orphan sandbox', () {
    final pair = evidence.where((item) => item.caseNumber == 24).toList();
    expect(pair, hasLength(2));
    expect(pair.every((item) => item.passed), isTrue);
    expect(
      pair.every(
        (item) =>
            item.authoritySources.single.sourceType ==
            'ledger-full-lease-fence-authority',
      ),
      isTrue,
    );
    final attack = pair.singleWhere((item) => item.variant == 'attack');
    final staleRejections =
        attack.authoritySources.single.payload['staleRejections']!
            as Map<String, Object?>;
    expect(staleRejections.values.every((value) => value == true), isTrue);
    expect(
      attack.authoritySources.single.payload['orphanSandboxRegistered'],
      isFalse,
    );
  });

  test('complete archive is accepted as production-path evidence', () async {
    final decoded = jsonDecode(archiveSource) as Map<String, Object?>;

    expect(archive.evidence, hasLength(50));
    expect(archive.complete, isTrue);
    expect(decoded['complete'], isTrue);
    expect(
      AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
        archiveSource,
        authorityDirectory: authorityDirectory,
      ),
      isTrue,
    );
    expect(
      AgentAdversarialProductionEvidenceArchive.verifyJsonText(
        archiveSource,
        authorityDirectory: authorityDirectory,
      ),
      isTrue,
    );
    expect(decoded['evidenceLevel'], 'integration-production-path');
    for (final forbidden in <String>[
      'apiKey',
      'Authorization',
      'Bearer ',
      'private prompt',
      'raw provider response',
    ]) {
      expect(archiveSource, isNot(contains(forbidden)));
    }
  });

  test(
    'diagnostic verifier rejects exact-schema and membership attacks',
    () async {
      final baseline = jsonDecode(archiveSource) as Map<String, Object?>;

      Map<String, Object?> copy() =>
          jsonDecode(jsonEncode(baseline)) as Map<String, Object?>;
      void rejected(Map<String, Object?> archive) => expect(
        AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
          jsonEncode(_rehashArchive(archive)),
          authorityDirectory: authorityDirectory,
        ),
        isFalse,
      );

      final extraRootKey = copy()..['unexpected'] = true;
      rejected(extraRootKey);

      final duplicate = copy();
      final duplicateEvidence = duplicate['evidence']! as List<Object?>;
      duplicateEvidence[1] = duplicateEvidence[0];
      rejected(duplicate);

      final wrongVariant = copy();
      final wrongVariantEvidence = wrongVariant['evidence']! as List<Object?>;
      (wrongVariantEvidence.first! as Map<String, Object?>)['variant'] =
          'control';
      rejected(wrongVariant);

      final wrongRoot = copy();
      final wrongRootEvidence = wrongRoot['evidence']! as List<Object?>;
      (wrongRootEvidence.first! as Map<String, Object?>)['authorityRootHash'] =
          'sha256:${List<String>.filled(64, '0').join()}';
      rejected(wrongRoot);

      final missingEvidenceKey = copy();
      final missingKeyEvidence =
          missingEvidenceKey['evidence']! as List<Object?>;
      (missingKeyEvidence.first! as Map<String, Object?>).remove('status');
      rejected(missingEvidenceKey);

      final extraEvidenceKey = copy();
      final extraKeyEvidence = extraEvidenceKey['evidence']! as List<Object?>;
      (extraKeyEvidence.first! as Map<String, Object?>)['score'] = 100;
      rejected(extraEvidenceKey);

      final inventedAuthority = copy();
      final inventedEvidence =
          (inventedAuthority['evidence']! as List<Object?>).first!
              as Map<String, Object?>;
      final inventedSource =
          (inventedEvidence['authoritySources']! as List<Object?>).single!
              as Map<String, Object?>;
      inventedSource['sourceType'] = 'invented-production-receipt';
      _rehashEvidence(inventedEvidence);
      rejected(inventedAuthority);

      final nestedSensitive = copy();
      final sensitiveEvidence = nestedSensitive['evidence']! as List<Object?>;
      final firstEvidence = sensitiveEvidence.first! as Map<String, Object?>;
      final authoritySources =
          firstEvidence['authoritySources']! as List<Object?>;
      final source = authoritySources.first! as Map<String, Object?>;
      final payload = source['payload']! as Map<String, Object?>;
      payload['nested'] = <String, Object?>{
        'authorization': 'Bearer must-not-archive',
      };
      rejected(nestedSensitive);

      final inventedTransportCount = copy();
      final transportEvidence =
          (inventedTransportCount['evidence']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .singleWhere(
                (item) =>
                    item['caseNumber'] == 11 && item['variant'] == 'attack',
              );
      final transportSource =
          (transportEvidence['authoritySources']! as List<Object?>).single!
              as Map<String, Object?>;
      final transportPayload =
          transportSource['payload']! as Map<String, Object?>;
      transportPayload['totalPhysicalRequests'] = 9;
      _rehashEvidence(transportEvidence);
      rejected(inventedTransportCount);
    },
  );

  test(
    'transport matrix verifier rejects durable budget journal tampering',
    () {
      final caseElevenAttack = evidence.singleWhere(
        (item) => item.caseNumber == 11 && item.variant == 'attack',
      );
      final payload = caseElevenAttack.authoritySources.single.payload;
      final journal = File(
        '${authorityDirectory.path}/${payload['budgetJournalFile']}',
      );
      final original = journal.readAsBytesSync();
      try {
        final decoded =
            jsonDecode(utf8.decode(original)) as Map<String, Object?>;
        decoded['failedCalls'] = 4;
        journal.writeAsStringSync(jsonEncode(decoded), flush: true);
        expect(
          AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
            archiveSource,
            authorityDirectory: authorityDirectory,
          ),
          isFalse,
        );
      } finally {
        journal.writeAsBytesSync(original, flush: true);
      }
      expect(
        AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
          archiveSource,
          authorityDirectory: authorityDirectory,
        ),
        isTrue,
      );
    },
  );

  test('trial isolation verifier rejects projection tampering', () {
    final attack = evidence.singleWhere(
      (item) => item.caseNumber == 19 && item.variant == 'attack',
    );
    final payload = attack.authoritySources.single.payload;
    final projection = File(
      '${authorityDirectory.path}/${payload['projectionFile']}',
    );
    final original = projection.readAsBytesSync();
    try {
      final decoded = jsonDecode(utf8.decode(original)) as Map<String, Object?>;
      decoded['productionSourceFileHashAfter'] = List<String>.filled(
        64,
        '0',
      ).join();
      projection.writeAsStringSync(jsonEncode(decoded), flush: true);
      expect(
        AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
          archiveSource,
          authorityDirectory: authorityDirectory,
        ),
        isFalse,
      );
    } finally {
      projection.writeAsBytesSync(original, flush: true);
    }
    expect(
      AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
        archiveSource,
        authorityDirectory: authorityDirectory,
      ),
      isTrue,
    );
  });

  test('judge injection verifier rejects immutable receipt tampering', () {
    final attack = evidence.singleWhere(
      (item) => item.caseNumber == 22 && item.variant == 'attack',
    );
    final payload = attack.authoritySources.single.payload;
    final receiptFile = File(
      '${authorityDirectory.path}/${payload['receiptFile']}',
    );
    final original = receiptFile.readAsBytesSync();
    try {
      final decoded = jsonDecode(utf8.decode(original)) as Map<String, Object?>;
      decoded['guardFailureCodes'] = <String>[];
      receiptFile.writeAsStringSync(jsonEncode(decoded), flush: true);
      expect(
        AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
          archiveSource,
          authorityDirectory: authorityDirectory,
        ),
        isFalse,
      );
    } finally {
      receiptFile.writeAsBytesSync(original, flush: true);
    }
    expect(
      AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
        archiveSource,
        authorityDirectory: authorityDirectory,
      ),
      isTrue,
    );
  });

  test('cache provenance verifier rejects append-only receipt tampering', () {
    final attack = evidence.singleWhere(
      (item) => item.caseNumber == 17 && item.variant == 'attack',
    );
    final payload = attack.authoritySources.single.payload;
    final database = File(
      '${authorityDirectory.path}/${payload['databaseFile']}',
    );
    final original = database.readAsBytesSync();
    try {
      final db = sqlite3.open(database.path);
      db.execute('DROP TRIGGER eval_cache_receipts_no_update');
      db.execute(
        "UPDATE eval_cache_receipts SET current_trial_slot_id = 'forged-slot' "
        "WHERE disposition = 'hit'",
      );
      db.dispose();
      expect(
        AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
          archiveSource,
          authorityDirectory: authorityDirectory,
        ),
        isFalse,
      );
    } finally {
      database.writeAsBytesSync(original, flush: true);
    }
    expect(
      AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
        archiveSource,
        authorityDirectory: authorityDirectory,
      ),
      isTrue,
    );
  });

  test('diagnostic verifier rejects authority database tampering', () {
    final caseEightAttack = evidence.singleWhere(
      (item) => item.caseNumber == 8 && item.variant == 'attack',
    );
    final payload = caseEightAttack.authoritySources.single.payload;
    final database = File(
      '${authorityDirectory.path}/${payload['databaseFile']}',
    );
    final original = database.readAsBytesSync();
    try {
      final db = sqlite3.open(database.path);
      db.execute(
        "UPDATE rag_documents SET owner_id = 'character-bob' "
        "WHERE path = 'private-memory'",
      );
      db.dispose();
      expect(
        AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
          archiveSource,
          authorityDirectory: authorityDirectory,
        ),
        isFalse,
      );
    } finally {
      database.writeAsBytesSync(original, flush: true);
    }
    expect(
      AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
        archiveSource,
        authorityDirectory: authorityDirectory,
      ),
      isTrue,
    );
  });
}

Map<String, Object?> _rehashArchive(Map<String, Object?> archive) {
  archive.remove('reportHash');
  archive['reportHash'] = AppLlmCanonicalHash.domainHash(
    'agent-adversarial-production-archive-v2',
    archive,
  );
  return archive;
}

void _rehashEvidence(Map<String, Object?> evidence) {
  final sources = evidence['authoritySources']! as List<Object?>;
  for (final value in sources) {
    final source = value! as Map<String, Object?>;
    source['sourceHash'] = AppLlmCanonicalHash.domainHash(
      'agent-adversarial-production-authority-source-v2',
      <String, Object?>{
        'sourceType': source['sourceType'],
        'sourceId': source['sourceId'],
        'releaseHash': source['releaseHash'],
        'payload': source['payload'],
      },
    );
  }
  final releaseHashes = <String>[
    for (final value in sources)
      (value! as Map<String, Object?>)['releaseHash']! as String,
  ]..sort();
  evidence['releaseMembershipHash'] = AppLlmCanonicalHash.domainHash(
    'agent-adversarial-production-release-membership-v2',
    <String, Object?>{
      'entryReleaseHash': evidence['entryReleaseHash'],
      'authorityReleaseHashes': releaseHashes,
    },
  );
  evidence['authorityRootHash'] = AppLlmCanonicalHash.domainHash(
    'agent-adversarial-production-evidence-root-v2',
    <String, Object?>{
      'caseNumber': evidence['caseNumber'],
      'scenarioId': evidence['scenarioId'],
      'variant': evidence['variant'],
      'expectedOutcome': evidence['expectedOutcome'],
      'actualOutcome': evidence['actualOutcome'],
      'status': evidence['status'],
      'entryReleaseHash': evidence['entryReleaseHash'],
      'verifierReleaseHash': evidence['verifierReleaseHash'],
      'authoritySources': sources,
      'releaseMembershipHash': evidence['releaseMembershipHash'],
    },
  );
}
