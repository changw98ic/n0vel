import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_fingerprints.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_receipt.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';

import 'test_support/generation_evidence_receipt_fixture.dart';

void main() {
  test(
    'real terminal receipt round-trips and binds exact artifact bytes',
    () async {
      final fixture = await prepareGenerationEvidenceReceiptFixture();
      final receipt = fixture.issue();
      final restored = GenerationEvidenceReceipt.fromCanonicalJson(
        receipt.canonicalJson,
      );

      expect(fixture.providerCallCount, 2);
      expect(restored.receiptHash, receipt.receiptHash);
      expect(restored.canonicalJson, receipt.canonicalJson);
      expect(
        restored.attemptEvidenceEnvelopeDigest,
        receipt.attemptEvidenceEnvelopeDigest,
      );
      expect(
        restored.generationFingerprintSetDigest,
        receipt.generationFingerprintSetDigest,
      );
      expect(restored.attemptCount, 2);
      expect(restored.generationBundleHashes, {fixture.generationBundleHash});
      expect(restored.finalProseSource, <String, Object?>{
        'logicalAttemptId': fixture.outcomes.last.logicalAttemptId,
        'callSiteId': 'language-polish',
      });
      expect(
        (jsonDecode(restored.canonicalJson) as Map)['schemaVersion'],
        GenerationEvidenceReceipt.schemaVersion,
      );
      expect(restored.matchesArtifactText(fixture.artifactText), isTrue);
      expect(
        restored.matchesArtifactText('${fixture.artifactText}\n'),
        isFalse,
      );
      final judgeAttempt = fixture.outcomes.first;
      expect(
        judgeAttempt.artifactDigest?.digest,
        isNot(judgeAttempt.evaluationFingerprint?.artifactDigest.digest),
      );
      expect(
        verifyStoryGenerationAttemptEvidenceJson(
          judgeAttempt.toJson(),
        ).evidenceComplete,
        isTrue,
      );
      expect(
        receipt.canonicalJson,
        isNot(contains(generationEvidenceReceiptFixtureRawJudgeSentinel)),
      );
    },
  );

  test('canonical receipt parser rejects non-canonical source bytes', () async {
    final receipt = (await prepareGenerationEvidenceReceiptFixture()).issue();
    final decoded = Map<String, Object?>.from(
      jsonDecode(receipt.canonicalJson) as Map,
    );
    final reordered = <String, Object?>{
      for (final entry in decoded.entries.toList().reversed)
        entry.key: entry.value,
    };
    final nonCanonicalSources = <String, String>{
      'leading whitespace': ' ${receipt.canonicalJson}',
      'trailing whitespace': '${receipt.canonicalJson}\n',
      'pretty printed': const JsonEncoder.withIndent('  ').convert(decoded),
      'key reordered': jsonEncode(reordered),
    };

    for (final source in nonCanonicalSources.entries) {
      expect(
        () => GenerationEvidenceReceipt.fromCanonicalJson(source.value),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'generation receipt JSON is not canonical',
          ),
        ),
        reason: source.key,
      );
    }
  });

  test(
    'terminal reread fixes receipt pairs in journal admission order',
    () async {
      final fixture = await prepareGenerationEvidenceReceiptFixture();
      final receipt = fixture.issue();
      final decoded = Map<String, Object?>.from(
        jsonDecode(receipt.canonicalJson) as Map,
      );
      final private = Map<String, Object?>.from(decoded['private']! as Map);
      final intents = List<Object?>.from(private['intents']! as List);
      final outcomes = List<Object?>.from(private['outcomes']! as List);

      expect(intents.map((value) => (value! as Map)['sequenceNo']), <int>[
        0,
        1,
      ]);
      expect(outcomes.map((value) => (value! as Map)['sequenceNo']), <int>[
        0,
        1,
      ]);
      for (var index = 0; index < intents.length; index += 1) {
        expect(
          (intents[index]! as Map)['logicalAttemptId'],
          (outcomes[index]! as Map)['logicalAttemptId'],
        );
      }
    },
  );

  test('terminal journal authority is one-shot', () async {
    final fixture = await prepareGenerationEvidenceReceiptFixture();
    fixture.issue();

    expect(
      fixture.issue,
      throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
    );
  });

  test(
    'receipt rejects forged or discontinuous journal admission slots',
    () async {
      final fixture = await prepareGenerationEvidenceReceiptFixture();
      final first = fixture.intents.first;
      final second = fixture.intents.last;

      expect(
        () => fixture.issue(
          overrideIntents: <GenerationEvidenceReceiptIntent>[
            first,
            GenerationEvidenceReceiptIntent(
              admissionSequenceNo: first.admissionSequenceNo,
              intent: second.intent,
            ),
          ],
        ),
        throwsStateError,
      );
    },
  );

  test(
    'hand-set verified booleans cannot replay a provider receipt or issue',
    () async {
      final fixture = await prepareGenerationEvidenceReceiptFixture();
      final replayed = _withProviderReceiptNonce(
        fixture.outcomes.first,
        fixture.outcomes.last.logicalAttemptId!,
      );
      expect(replayed.providerBoundaryReceiptVerified, isTrue);
      expect(replayed.formalDispatchWitness, isNull);

      expect(
        () => fixture.issue(
          overrideEnvelope: StoryGenerationAttemptEvidenceEnvelope(
            attempts: <StoryGenerationAttemptEvidence>[
              replayed,
              fixture.outcomes.last,
            ],
          ),
        ),
        throwsStateError,
      );
    },
  );

  test('hand-set verified booleans cannot enter a fresh journal', () async {
    final fixture = await prepareGenerationEvidenceReceiptFixture();
    final sourceIntent = fixture.intents.last.intent;
    final sourceOutcome = fixture.outcomes.last;
    final forgedIntent = _retargetIntent(
      sourceIntent,
      evidenceRunId: '${fixture.evidenceRunId}-forged',
      sceneId: '${fixture.sceneId}-forged',
    );
    final forged = _withoutFormalDispatchWitness(
      sourceOutcome,
      logicalAttemptId: forgedIntent.logicalAttemptId,
    );
    expect(forged.providerBoundaryReceiptVerified, isTrue);
    expect(forged.formalDispatchWitness, isNull);
    expect(
      verifyStoryGenerationAttemptEvidenceJson(
        forged.toJson(),
      ).evidenceComplete,
      isTrue,
    );

    final directory = await Directory.systemTemp.createTemp(
      'novel-writer-forged-receipt-',
    );
    final log = PipelineEventLogImpl(
      jsonlPath: '${directory.path}/evidence.jsonl',
    );
    try {
      final journal = await log.openStoryGenerationEvidenceJournal(
        evidenceRunId: forgedIntent.evidenceRunId,
        sceneId: forgedIntent.sceneId,
        preparedBriefDigest: fixture.preparedBriefDigest,
        generationArmPolicy: fixture.generationArmPolicy,
      );
      await journal.persistIntent(forgedIntent);

      await expectLater(
        journal.persistAttempt(forged),
        throwsA(
          isA<StoryGenerationEvidenceIntegrityFailure>().having(
            (error) => error.message,
            'message',
            contains('was not issued by the App LLM IO boundary'),
          ),
        ),
      );
    } finally {
      await log.dispose();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });

  test(
    'pure verifier rejects malformed evaluation fingerprint shapes',
    () async {
      final source =
          (await prepareGenerationEvidenceReceiptFixture()).outcomes.first;
      final evaluation = Map<String, Object?>.from(
        source.evaluationFingerprint!.toCanonicalMap(),
      );
      final judgeInput =
          Map<String, Object?>.from(evaluation['judgeInput']! as Map)
            ..['evaluatedArtifactDigest'] = ArtifactDigest.fromUtf8String(
              'another evaluated artifact',
            ).toCanonicalMap();
      evaluation['judgeInput'] = judgeInput;
      final tampered = <String, Object?>{
        ...source.toJson(),
        'evaluationFingerprint': evaluation,
        'evaluationFingerprintDigest': AppLlmCanonicalHash.domainHash(
          EvaluationFingerprint.defaultDomainTag,
          evaluation,
        ),
      };

      final verification = verifyStoryGenerationAttemptEvidenceJson(tampered);
      expect(verification.evidenceComplete, isFalse);
      expect(
        verification.errors,
        contains('evaluation fingerprint judge input binding is invalid'),
      );

      final rawLeakingEvaluation = Map<String, Object?>.from(
        source.evaluationFingerprint!.toCanonicalMap(),
      );
      final rawLeakingJudgeInput = Map<String, Object?>.from(
        rawLeakingEvaluation['judgeInput']! as Map,
      )..['semanticInput'] = generationEvidenceReceiptFixtureRawJudgeSentinel;
      rawLeakingEvaluation['judgeInput'] = rawLeakingJudgeInput;
      final rawLeakingPayload = <String, Object?>{
        ...source.toJson(),
        'evaluationFingerprint': rawLeakingEvaluation,
        'evaluationFingerprintDigest': AppLlmCanonicalHash.domainHash(
          EvaluationFingerprint.defaultDomainTag,
          rawLeakingEvaluation,
        ),
      };
      final rawLeakingVerification = verifyStoryGenerationAttemptEvidenceJson(
        rawLeakingPayload,
      );
      expect(rawLeakingVerification.evidenceComplete, isFalse);
      expect(
        rawLeakingVerification.errors,
        contains('evaluation fingerprint judge input binding is invalid'),
      );

      final malformedOuterValues = <String, Object?>{
        'evaluationBundleHash': 'not-a-digest',
        'judgeModelRoute': 'not-a-digest',
        'rubricHash': 'not-a-digest',
        'blindingPolicy': const <String, Object?>{
          'rawInput': generationEvidenceReceiptFixtureRawJudgeSentinel,
        },
      };
      for (final mutation in malformedOuterValues.entries) {
        final malformedEvaluation = Map<String, Object?>.from(
          source.evaluationFingerprint!.toCanonicalMap(),
        )..[mutation.key] = mutation.value;
        final malformedPayload = <String, Object?>{
          ...source.toJson(),
          'evaluationFingerprint': malformedEvaluation,
          'evaluationFingerprintDigest': AppLlmCanonicalHash.domainHash(
            EvaluationFingerprint.defaultDomainTag,
            malformedEvaluation,
          ),
        };
        final malformedVerification = verifyStoryGenerationAttemptEvidenceJson(
          malformedPayload,
        );
        expect(
          malformedVerification.evidenceComplete,
          isFalse,
          reason: mutation.key,
        );
        expect(
          malformedVerification.errors,
          contains('evaluation fingerprint shape or digest is invalid'),
          reason: mutation.key,
        );
      }
    },
  );

  test(
    'preliminary evaluation may bind an earlier artifact but mints no proof',
    () async {
      final fixture = await prepareGenerationEvidenceReceiptFixture(
        evaluatedArtifactText: 'non-sealed prose',
      );
      expect(
        verifyStoryGenerationAttemptEvidenceJson(
          fixture.outcomes.first.toJson(),
        ).evidenceComplete,
        isTrue,
      );

      final receipt = fixture.issue();
      expect(receipt.matchesArtifactText(fixture.artifactText), isTrue);
      expect(receipt.finalEvaluationManifest, isNull);
      expect(receipt.proofAdmission, isNull);
    },
  );

  test(
    'pure verifier rejects transport secrets and altered endpoint identity',
    () async {
      final source =
          (await prepareGenerationEvidenceReceiptFixture()).outcomes.first;
      final secretReceipt = <String, Object?>{
        ...source.providerBoundaryReceipt!,
        'apiKey': 'secret-must-never-persist',
      };
      final secretPayload = <String, Object?>{
        ...source.toJson(),
        'providerBoundaryReceipt': secretReceipt,
        'providerBoundaryReceiptHash': AppLlmCanonicalHash.domainHash(
          'story-generation-provider-boundary-receipt-v1',
          secretReceipt,
        ),
      };
      expect(
        verifyStoryGenerationAttemptEvidenceJson(
          secretPayload,
        ).evidenceComplete,
        isFalse,
      );

      final alteredResolution = <String, Object?>{
        ...source.observedDispatchResolution!,
        'endpointId': 'replayed-endpoint',
      };
      final alteredPayload = <String, Object?>{
        ...source.toJson(),
        'observedDispatchResolution': alteredResolution,
        'observedDispatchResolutionHash': AppLlmCanonicalHash.domainHash(
          'story-generation-selected-physical-endpoint-v1',
          alteredResolution,
        ),
      };
      expect(
        verifyStoryGenerationAttemptEvidenceJson(
          alteredPayload,
        ).evidenceComplete,
        isFalse,
      );
    },
  );

  test('tampered nested generation fingerprint is rejected', () async {
    final receipt = (await prepareGenerationEvidenceReceiptFixture()).issue();
    final tampered = Map<String, Object?>.from(
      jsonDecode(receipt.canonicalJson) as Map,
    );
    final private = Map<String, Object?>.from(tampered['private']! as Map);
    final outcomes = List<Object?>.from(private['outcomes']! as List);
    final generationIndex = outcomes.indexWhere(
      (item) => (item! as Map)['generationFingerprint'] != null,
    );
    expect(generationIndex, isNonNegative);
    final first = Map<String, Object?>.from(outcomes[generationIndex]! as Map);
    final fingerprint = Map<String, Object?>.from(
      first['generationFingerprint']! as Map,
    );
    fingerprint['modelRoute'] = _hash('tampered-route');
    first['generationFingerprint'] = fingerprint;
    outcomes[generationIndex] = first;
    private['outcomes'] = outcomes;
    tampered['private'] = private;

    expect(
      () => GenerationEvidenceReceipt.fromCanonicalJson(
        AppLlmCanonicalHash.canonicalJson(tampered),
      ),
      throwsStateError,
    );
  });

  test('intent without exactly one outcome is rejected', () async {
    final fixture = await prepareGenerationEvidenceReceiptFixture();

    expect(
      () => fixture.issue(
        overrideEnvelope: StoryGenerationAttemptEvidenceEnvelope(
          attempts: <StoryGenerationAttemptEvidence>[fixture.outcomes.first],
        ),
      ),
      throwsStateError,
    );
  });

  test('duplicate same outcome instance is rejected', () async {
    final fixture = await prepareGenerationEvidenceReceiptFixture();
    final duplicate = fixture.outcomes.first;

    expect(
      () => fixture.issue(
        overrideEnvelope: StoryGenerationAttemptEvidenceEnvelope(
          attempts: <StoryGenerationAttemptEvidence>[duplicate, duplicate],
        ),
      ),
      throwsStateError,
    );
  });

  test('receipt rejects a seal no successful provider artifact made', () async {
    final fixture = await prepareGenerationEvidenceReceiptFixture();

    expect(
      () => fixture.issue(
        overrideSealedArtifactDigest: ArtifactDigest.fromUtf8String(
          'invented prose',
        ),
      ),
      throwsStateError,
    );
  });

  test('receipt fails closed on an unknown v2 field', () async {
    final receipt = (await prepareGenerationEvidenceReceiptFixture()).issue();
    final tampered = Map<String, Object?>.from(
      jsonDecode(receipt.canonicalJson) as Map,
    )..['futureUncheckedField'] = true;

    expect(
      () => GenerationEvidenceReceipt.fromCanonicalJson(
        AppLlmCanonicalHash.canonicalJson(tampered),
      ),
      throwsStateError,
    );
  });
}

String _hash(String value) => AppLlmCanonicalHash.domainHash(
  'generation-evidence-receipt-test-v2',
  <String, Object?>{'value': value},
);

StoryGenerationAttemptEvidence _withProviderReceiptNonce(
  StoryGenerationAttemptEvidence source,
  String dispatchEvidenceNonce,
) {
  final receipt = <String, Object?>{
    ...source.providerBoundaryReceipt!,
    'dispatchEvidenceNonce': dispatchEvidenceNonce,
  };
  return source.copyWithFormalEvidence(
    stageId: source.stageId!,
    callSiteId: source.callSiteId!,
    variantId: source.variantId!,
    preparedBriefDigest: source.preparedBriefDigest!,
    logicalAttemptId: source.logicalAttemptId,
    generationBundleHash: source.generationBundleHash!,
    promptReleaseRef: source.promptReleaseRef!,
    promptReleaseContentHash: source.promptReleaseContentHash!,
    renderedMessagesDigest: source.renderedMessagesDigest!,
    resolvedVariablesDigest: source.resolvedVariablesDigest!,
    rendererContractHash: source.rendererContractHash!,
    selectedRouteBindingHash: source.selectedRouteBindingHash,
    selectedRouteBinding: source.selectedRouteBinding,
    observedDispatchResolutionHash: source.observedDispatchResolutionHash,
    observedDispatchResolution: source.observedDispatchResolution,
    routeResolutionRequired: source.routeResolutionRequired,
    routeResolutionVerified: source.routeResolutionVerified,
    providerBoundaryReceiptHash: AppLlmCanonicalHash.domainHash(
      'story-generation-provider-boundary-receipt-v1',
      receipt,
    ),
    providerBoundaryReceipt: receipt,
    providerBoundaryPhysicalDispatchCount:
        source.providerBoundaryPhysicalDispatchCount,
    providerBoundaryReceiptRequired: source.providerBoundaryReceiptRequired,
    providerBoundaryReceiptVerified: source.providerBoundaryReceiptVerified,
    artifactDigest: source.artifactDigest,
    generationFingerprint: source.generationFingerprint,
    evaluationFingerprint: source.evaluationFingerprint,
    evaluationParserRelease: source.evaluationParserRelease,
    evaluationPhase: source.evaluationPhase,
    evaluationFingerprintRequired: source.evaluationFingerprintRequired,
  );
}

StoryGenerationAttemptEvidence _withoutFormalDispatchWitness(
  StoryGenerationAttemptEvidence source, {
  required String logicalAttemptId,
}) {
  final receipt = <String, Object?>{
    ...source.providerBoundaryReceipt!,
    'dispatchEvidenceNonce': logicalAttemptId,
  };
  return source.copyWithFormalEvidence(
    stageId: source.stageId!,
    callSiteId: source.callSiteId!,
    variantId: source.variantId!,
    preparedBriefDigest: source.preparedBriefDigest!,
    logicalAttemptId: logicalAttemptId,
    generationBundleHash: source.generationBundleHash!,
    promptReleaseRef: source.promptReleaseRef!,
    promptReleaseContentHash: source.promptReleaseContentHash!,
    renderedMessagesDigest: source.renderedMessagesDigest!,
    resolvedVariablesDigest: source.resolvedVariablesDigest!,
    rendererContractHash: source.rendererContractHash!,
    selectedRouteBindingHash: source.selectedRouteBindingHash,
    selectedRouteBinding: source.selectedRouteBinding,
    observedDispatchResolutionHash: source.observedDispatchResolutionHash,
    observedDispatchResolution: source.observedDispatchResolution,
    routeResolutionRequired: source.routeResolutionRequired,
    routeResolutionVerified: source.routeResolutionVerified,
    providerBoundaryReceiptHash: AppLlmCanonicalHash.domainHash(
      'story-generation-provider-boundary-receipt-v1',
      receipt,
    ),
    providerBoundaryReceipt: receipt,
    providerBoundaryPhysicalDispatchCount:
        source.providerBoundaryPhysicalDispatchCount,
    providerBoundaryReceiptRequired: source.providerBoundaryReceiptRequired,
    providerBoundaryReceiptVerified: source.providerBoundaryReceiptVerified,
    artifactDigest: source.artifactDigest,
    generationFingerprint: source.generationFingerprint,
    evaluationFingerprint: source.evaluationFingerprint,
    evaluationParserRelease: source.evaluationParserRelease,
    evaluationPhase: source.evaluationPhase,
    evaluationFingerprintRequired: source.evaluationFingerprintRequired,
  );
}

StoryGenerationAttemptIntent _retargetIntent(
  StoryGenerationAttemptIntent source, {
  required String evidenceRunId,
  required String sceneId,
}) {
  final logicalAttemptId = AppLlmCanonicalHash.domainHash(
    'story-generation-logical-attempt-id-v1',
    <String, Object?>{
      'evidenceRunId': evidenceRunId,
      'sceneId': sceneId,
      'preparedBriefDigest': source.preparedBriefDigest,
      'attempt': source.attempt,
      'maxTokens': source.maxTokens,
      'transientRetryCount': source.transientRetryCount,
      'outputRetryCount': source.outputRetryCount,
      'stageId': source.stageId,
      'callSiteId': source.callSiteId,
      'variantId': source.variantId,
      'generationBundleHash': source.generationBundleHash,
      'promptReleaseContentHash': source.promptReleaseContentHash,
      'renderedMessagesDigest': source.renderedMessagesDigest,
      'resolvedVariablesDigest': source.resolvedVariablesDigest,
      'rendererContractHash': source.rendererContractHash,
      'selectedRouteBindingHash': source.selectedRouteBindingHash,
      'generationArmPolicy': source.generationArmPolicy,
      'retryContractHash': source.retryContractHash,
      'evaluationPhase': source.evaluationPhase?.name,
    },
  );
  return StoryGenerationAttemptIntent(
    evidenceRunId: evidenceRunId,
    sceneId: sceneId,
    preparedBriefDigest: source.preparedBriefDigest,
    logicalAttemptId: logicalAttemptId,
    attempt: source.attempt,
    maxTokens: source.maxTokens,
    transientRetryCount: source.transientRetryCount,
    outputRetryCount: source.outputRetryCount,
    stageId: source.stageId,
    callSiteId: source.callSiteId,
    variantId: source.variantId,
    generationBundleHash: source.generationBundleHash,
    promptReleaseRef: source.promptReleaseRef,
    promptReleaseContentHash: source.promptReleaseContentHash,
    renderedMessagesDigest: source.renderedMessagesDigest,
    resolvedVariablesDigest: source.resolvedVariablesDigest,
    rendererContractHash: source.rendererContractHash,
    selectedRouteBindingHash: source.selectedRouteBindingHash,
    generationArmPolicy: source.generationArmPolicy,
    retryContractHash: source.retryContractHash,
    evaluationPhase: source.evaluationPhase,
  );
}
