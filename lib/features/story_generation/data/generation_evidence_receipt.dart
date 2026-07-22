import 'dart:convert';

import '../../../app/llm/app_llm_canonical_hash.dart';
import '../../../app/llm/app_llm_provider_outcome_seal.dart';
import 'generation_evidence_fingerprints.dart';
import 'pipeline_event_log.dart';
import 'pipeline_stage_runner_impl.dart'
    show PipelineFinalEvaluationManifestAuthority;
import 'story_generation_pass_retry.dart';

/// Durable, self-verifying receipt for one completed no-redraw scene.
///
/// The journal may observe provider outcomes in completion order. This receipt
/// joins intents and outcomes by logical attempt id and canonicalizes them in
/// durable dispatch-admission order. Consequently, concurrent completions do
/// not make a candidate identity depend on scheduler timing.
final class GenerationEvidenceReceipt {
  factory GenerationEvidenceReceipt.fromVerified({
    required StoryGenerationEvidenceReceiptAuthority authority,
    required String evidenceRunId,
    required String sceneId,
    required String generationArmPolicy,
    required String preparedBriefDigest,
    required Iterable<GenerationEvidenceReceiptIntent> intents,
    required StoryGenerationAttemptEvidenceEnvelope envelope,
    required ArtifactDigest sealedArtifactDigest,
    PipelineFinalEvaluationManifestAuthority? finalEvaluationManifestAuthority,
  }) {
    if (!envelope.evidenceComplete) {
      throw StateError(
        'cannot issue a receipt for incomplete attempt evidence',
      );
    }
    final intentList = List<GenerationEvidenceReceiptIntent>.from(intents)
      ..sort(
        (left, right) =>
            left.admissionSequenceNo.compareTo(right.admissionSequenceNo),
      );
    if (intentList.isEmpty) {
      throw StateError('a generation receipt requires at least one intent');
    }
    for (var index = 0; index < intentList.length; index += 1) {
      if (intentList[index].admissionSequenceNo != index) {
        throw StateError(
          'receipt intents require unique, continuous journal admission '
          'sequence numbers beginning at zero',
        );
      }
    }
    final outcomesById = <String, StoryGenerationAttemptEvidence>{};
    for (final outcome in envelope.attempts) {
      final logicalAttemptId = outcome.logicalAttemptId;
      if (logicalAttemptId == null ||
          outcomesById.containsKey(logicalAttemptId)) {
        throw StateError(
          'attempt outcomes require unique logical attempt identities',
        );
      }
      outcomesById[logicalAttemptId] = outcome;
    }
    final privateIntents = <Object?>[];
    final privateOutcomes = <Object?>[];
    for (final admittedIntent in intentList) {
      final sequenceNo = admittedIntent.admissionSequenceNo;
      final intent = admittedIntent.intent;
      final outcome = outcomesById.remove(intent.logicalAttemptId);
      if (outcome == null) {
        throw StateError(
          'intent ${intent.logicalAttemptId} has no durable outcome',
        );
      }
      privateIntents.add(<String, Object?>{
        'sequenceNo': sequenceNo,
        'attemptIntentDigest': intent.privateIntentDigest,
        ...intent.toPrivateJson(),
      });
      privateOutcomes.add(<String, Object?>{
        'sequenceNo': sequenceNo,
        'attemptEvidenceDigest': outcome.privateEvidenceDigest,
        ...outcome.toJson(),
      });
    }
    if (outcomesById.isNotEmpty) {
      throw StateError('attempt envelope contains outcomes without intents');
    }
    final finalProseSource = authority.finalProseSource.toCanonicalMap();
    if (!authority.consumeForReceipt(
      evidenceRunId: evidenceRunId,
      sceneId: sceneId,
      generationArmPolicy: generationArmPolicy,
      preparedBriefDigest: preparedBriefDigest,
      intents: intentList.map((admission) => admission.intent),
      envelope: envelope,
      sealedArtifactDigest: sealedArtifactDigest,
    )) {
      throw StateError(
        'generation receipt requires one terminal journal authority',
      );
    }
    Map<String, Object?>? finalEvaluationManifest;
    if (finalEvaluationManifestAuthority != null) {
      if (intentList
              .map((item) => item.intent.generationBundleHash)
              .toSet()
              .length !=
          1) {
        throw StateError(
          'final evaluation manifest requires one generation bundle',
        );
      }
      final generationBundleHash = intentList.first.intent.generationBundleHash;
      finalEvaluationManifest = finalEvaluationManifestAuthority
          .consumeForReceipt(
            runId: evidenceRunId,
            sceneId: sceneId,
            preparedBriefDigest: preparedBriefDigest,
            generationArmPolicy: generationArmPolicy,
            generationBundleHash: generationBundleHash,
            finalArtifactDigest: sealedArtifactDigest,
          );
      if (finalEvaluationManifest == null) {
        throw StateError(
          'generation receipt requires one matching final evaluation manifest '
          'authority',
        );
      }
    }

    final seed = <String, Object?>{
      'schemaVersion': schemaVersion,
      'visibility': 'private',
      'evidenceComplete': true,
      'evidenceRunId': evidenceRunId,
      'sceneId': sceneId,
      'generationArmPolicy': generationArmPolicy,
      'preparedBriefDigest': preparedBriefDigest,
      'sealedArtifactDigest': sealedArtifactDigest.toCanonicalMap(),
      'finalProseSource': finalProseSource,
      'finalEvaluationManifest': finalEvaluationManifest,
      'sourceEnvelopeSchemaVersion': envelope.schemaVersion,
      'private': <String, Object?>{
        'intents': privateIntents,
        'outcomes': privateOutcomes,
      },
    };
    final derived = _deriveReceiptDigests(seed);
    final withDerived = <String, Object?>{
      ...seed,
      'attemptEvidenceEnvelopeDigest': derived.attemptEnvelopeDigest,
      'generationFingerprintSetDigest': derived.generationFingerprintSetDigest,
    };
    return GenerationEvidenceReceipt._validate(<String, Object?>{
      ...withDerived,
      'receiptHash': AppLlmCanonicalHash.domainHash(
        receiptDomainTag,
        withDerived,
      ),
    }, authorizeProofAdmission: true);
  }

  factory GenerationEvidenceReceipt.fromCanonicalJson(String canonicalJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(canonicalJson);
    } on FormatException catch (error) {
      throw StateError('generation receipt JSON is malformed: $error');
    }
    if (canonicalJson != AppLlmCanonicalHash.canonicalJson(decoded)) {
      throw StateError('generation receipt JSON is not canonical');
    }
    return GenerationEvidenceReceipt._validate(_stringMap(decoded, 'receipt'));
  }

  factory GenerationEvidenceReceipt._validate(
    Map<String, Object?> candidate, {
    bool authorizeProofAdmission = false,
  }) {
    _requireExactKeys(candidate, _receiptKeys, 'receipt');
    if (candidate['schemaVersion'] != schemaVersion ||
        candidate['visibility'] != 'private' ||
        candidate['evidenceComplete'] != true) {
      throw StateError('generation receipt header is invalid');
    }
    final evidenceRunId = _requiredString(
      candidate['evidenceRunId'],
      'evidenceRunId',
    );
    final sceneId = _requiredString(candidate['sceneId'], 'sceneId');
    final generationArmPolicy = _requiredString(
      candidate['generationArmPolicy'],
      'generationArmPolicy',
    );
    final preparedBriefDigest = _sha256(
      candidate['preparedBriefDigest'],
      'preparedBriefDigest',
    );
    final sourceEnvelopeSchemaVersion = _requiredString(
      candidate['sourceEnvelopeSchemaVersion'],
      'sourceEnvelopeSchemaVersion',
    );
    if (sourceEnvelopeSchemaVersion !=
        'story-generation-attempt-evidence-envelope-v1') {
      throw StateError('generation receipt source envelope is unsupported');
    }
    final sealedArtifactDigest = _artifactMap(
      candidate['sealedArtifactDigest'],
      'sealedArtifactDigest',
    );
    final finalProseSource = _finalProseSourceMap(
      candidate['finalProseSource'],
    );
    final finalEvaluationManifest = _finalEvaluationManifestMap(
      candidate['finalEvaluationManifest'],
    );
    final derived = _deriveReceiptDigests(candidate);
    final persistedEnvelopeDigest = _sha256(
      candidate['attemptEvidenceEnvelopeDigest'],
      'attemptEvidenceEnvelopeDigest',
    );
    final persistedFingerprintSetDigest = _sha256(
      candidate['generationFingerprintSetDigest'],
      'generationFingerprintSetDigest',
    );
    if (persistedEnvelopeDigest != derived.attemptEnvelopeDigest ||
        persistedFingerprintSetDigest !=
            derived.generationFingerprintSetDigest) {
      throw StateError('generation receipt derived digests do not reconcile');
    }
    final receiptHash = _sha256(candidate['receiptHash'], 'receiptHash');
    final receiptPayload = Map<String, Object?>.from(candidate)
      ..remove('receiptHash');
    final recomputedReceiptHash = AppLlmCanonicalHash.domainHash(
      receiptDomainTag,
      receiptPayload,
    );
    if (receiptHash != recomputedReceiptHash) {
      throw StateError('generation receipt hash mismatch');
    }
    final canonicalJson = AppLlmCanonicalHash.canonicalJson(candidate);
    return GenerationEvidenceReceipt._(
      evidenceRunId: evidenceRunId,
      sceneId: sceneId,
      generationArmPolicy: generationArmPolicy,
      preparedBriefDigest: preparedBriefDigest,
      sourceEnvelopeSchemaVersion: sourceEnvelopeSchemaVersion,
      sealedArtifactDigest: sealedArtifactDigest,
      finalProseSource: finalProseSource,
      finalEvaluationManifest: finalEvaluationManifest,
      attemptEvidenceEnvelopeDigest: persistedEnvelopeDigest,
      generationFingerprintSetDigest: persistedFingerprintSetDigest,
      receiptHash: receiptHash,
      generationBundleHashes: derived.generationBundleHashes,
      attemptCount: derived.attemptCount,
      canonicalJson: canonicalJson,
      proofAdmission: authorizeProofAdmission && finalEvaluationManifest != null
          ? GenerationEvidenceReceiptProofAdmission._(
              canonicalJson: canonicalJson,
              receiptHash: receiptHash,
              evidenceRunId: evidenceRunId,
              sceneId: sceneId,
              sealedArtifactDigest: sealedArtifactDigest,
            )
          : null,
    );
  }

  const GenerationEvidenceReceipt._({
    required this.evidenceRunId,
    required this.sceneId,
    required this.generationArmPolicy,
    required this.preparedBriefDigest,
    required this.sourceEnvelopeSchemaVersion,
    required this.sealedArtifactDigest,
    required this.finalProseSource,
    required this.finalEvaluationManifest,
    required this.attemptEvidenceEnvelopeDigest,
    required this.generationFingerprintSetDigest,
    required this.receiptHash,
    required this.generationBundleHashes,
    required this.attemptCount,
    required this.canonicalJson,
    required GenerationEvidenceReceiptProofAdmission? proofAdmission,
  }) : _proofAdmission = proofAdmission;

  static const String schemaVersion = 'story-generation-evidence-receipt-v2';
  static const String receiptDomainTag = 'story-generation-evidence-receipt-v2';
  static const String attemptEnvelopeDomainTag =
      'story-generation-attempt-envelope-v3';
  static const String generationFingerprintSetDomainTag =
      'story-generation-fingerprint-set-v1';

  final String evidenceRunId;
  final String sceneId;
  final String generationArmPolicy;
  final String preparedBriefDigest;
  final String sourceEnvelopeSchemaVersion;
  final Map<String, Object?> sealedArtifactDigest;
  final Map<String, Object?> finalProseSource;
  final Map<String, Object?>? finalEvaluationManifest;
  final String attemptEvidenceEnvelopeDigest;
  final String generationFingerprintSetDigest;
  final String receiptHash;
  final Set<String> generationBundleHashes;
  final int attemptCount;
  final String canonicalJson;
  final GenerationEvidenceReceiptProofAdmission? _proofAdmission;

  String? get finalReviewParsedOutputDigest =>
      finalEvaluationManifest?['reviewParsedOutputDigest'] as String?;

  String? get finalQualityParsedOutputDigest =>
      finalEvaluationManifest?['qualityParsedOutputDigest'] as String?;

  /// Runtime-only authority for the first immutable proof admission.
  ///
  /// A receipt reconstructed from [fromCanonicalJson] deliberately returns
  /// `null`: canonical hashes prove integrity of already-durable bytes, not
  /// that a caller observed the terminal provider journal which originally
  /// authorized those bytes.
  GenerationEvidenceReceiptProofAdmission? get proofAdmission =>
      _proofAdmission;

  bool matchesArtifactText(String text) => _canonicalEquals(
    sealedArtifactDigest,
    ArtifactDigest.fromUtf8String(text).toCanonicalMap(),
  );

  Map<String, Object?> toJson() =>
      _stringMap(jsonDecode(canonicalJson), 'canonical receipt');
}

/// One-shot capability required when a sealed receipt first crosses the
/// immutable candidate-proof boundary.
///
/// The constructor is library-private and the value is never serialized.
/// Only [GenerationEvidenceReceipt.fromVerified] creates one, after consuming
/// the terminal journal receipt authority.  Public receipt parsing therefore
/// cannot mint proof-admission authority by recomputing canonical hashes.
@pragma('vm:isolate-unsendable')
final class GenerationEvidenceReceiptProofAdmission {
  GenerationEvidenceReceiptProofAdmission._({
    required String canonicalJson,
    required String receiptHash,
    required String evidenceRunId,
    required String sceneId,
    required Map<String, Object?> sealedArtifactDigest,
  }) : _canonicalJson = canonicalJson,
       _receiptHash = receiptHash,
       _evidenceRunId = evidenceRunId,
       _sceneId = sceneId,
       _sealedArtifactDigest = Map<String, Object?>.unmodifiable(
         sealedArtifactDigest,
       );

  final String _canonicalJson;
  final String _receiptHash;
  final String _evidenceRunId;
  final String _sceneId;
  final Map<String, Object?> _sealedArtifactDigest;
  bool _consumed = false;

  bool _matches({
    required String canonicalJson,
    required String receiptHash,
    required String runId,
    required String sceneId,
    required String candidateHash,
    required Map<String, Object?> sealedArtifactDigest,
  }) =>
      canonicalJson == _canonicalJson &&
      receiptHash == _receiptHash &&
      runId == _evidenceRunId &&
      sceneId == _sceneId &&
      RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(candidateHash) &&
      _canonicalEquals(sealedArtifactDigest, _sealedArtifactDigest);

  /// Consumes this capability exactly once for the exact receipt bytes and
  /// proof scope. A mismatched presentation burns the capability fail closed.
  bool consume({
    required String canonicalJson,
    required String receiptHash,
    required String runId,
    required String sceneId,
    required String candidateHash,
    required Map<String, Object?> sealedArtifactDigest,
  }) {
    if (_consumed) return false;
    // Burn before comparing. A capability presented for the wrong proof is
    // an integrity failure, not a reusable credential-discovery oracle.
    _consumed = true;
    return _matches(
      canonicalJson: canonicalJson,
      receiptHash: receiptHash,
      runId: runId,
      sceneId: sceneId,
      candidateHash: candidateHash,
      sealedArtifactDigest: sealedArtifactDigest,
    );
  }
}

/// A verified, rehydrated journal admission record.
///
/// [admissionSequenceNo] is persisted by the attempt journal at admission
/// time.  It is deliberately not inferred from an iterable's caller-provided
/// order: providers may complete concurrent attempts in any order and callers
/// may freely reorder their collections before issuing a receipt.
final class GenerationEvidenceReceiptIntent {
  const GenerationEvidenceReceiptIntent({
    required this.admissionSequenceNo,
    required this.intent,
  });

  final int admissionSequenceNo;
  final StoryGenerationAttemptIntent intent;
}

_DerivedReceiptDigests _deriveReceiptDigests(Map<String, Object?> receipt) {
  // The factory derives these values before the receipt hash exists, whereas
  // reload validation receives the fully sealed shape.  Both must be strict,
  // but a construction seed must not be mistaken for a malformed persisted
  // receipt.
  _requireExactKeys(
    receipt,
    _receiptSeedKeys,
    'receipt seed',
    optional: _receiptDerivedKeys,
  );
  final evidenceRunId = _requiredString(
    receipt['evidenceRunId'],
    'evidenceRunId',
  );
  final sceneId = _requiredString(receipt['sceneId'], 'sceneId');
  final generationArmPolicy = _requiredString(
    receipt['generationArmPolicy'],
    'generationArmPolicy',
  );
  final preparedBriefDigest = _sha256(
    receipt['preparedBriefDigest'],
    'preparedBriefDigest',
  );
  final sourceEnvelopeSchemaVersion = _requiredString(
    receipt['sourceEnvelopeSchemaVersion'],
    'sourceEnvelopeSchemaVersion',
  );
  if (sourceEnvelopeSchemaVersion !=
      'story-generation-attempt-evidence-envelope-v1') {
    throw StateError('generation receipt source envelope is unsupported');
  }
  final sealedArtifactDigest = _artifactMap(
    receipt['sealedArtifactDigest'],
    'sealedArtifactDigest',
  );
  final finalProseSource = _finalProseSourceMap(receipt['finalProseSource']);
  final sourceLogicalAttemptId =
      finalProseSource['logicalAttemptId']! as String;
  final sourceCallSiteId = finalProseSource['callSiteId']! as String;
  final private = _stringMap(receipt['private'], 'private');
  _requireExactKeys(private, _privateKeys, 'private');
  final rawIntents = _objectList(private['intents'], 'private.intents');
  final rawOutcomes = _objectList(private['outcomes'], 'private.outcomes');
  if (rawIntents.isEmpty || rawIntents.length != rawOutcomes.length) {
    throw StateError(
      'generation receipt intent/outcome cardinality is invalid',
    );
  }

  final pairs = <Object?>[];
  final fingerprintMembers = <Object?>[];
  final bundleHashes = <String>{};
  final logicalAttemptIds = <String>{};
  var finalProseSourceMatchCount = 0;
  for (var sequenceNo = 0; sequenceNo < rawIntents.length; sequenceNo += 1) {
    final intentRecord = _stringMap(
      rawIntents[sequenceNo],
      'private.intents[$sequenceNo]',
    );
    final outcomeRecord = _stringMap(
      rawOutcomes[sequenceNo],
      'private.outcomes[$sequenceNo]',
    );
    if (intentRecord['sequenceNo'] != sequenceNo ||
        outcomeRecord['sequenceNo'] != sequenceNo) {
      throw StateError('generation receipt sequence is not canonical');
    }
    _requireExactKeys(
      intentRecord,
      _intentRecordKeys,
      'private.intents[$sequenceNo]',
    );
    _requireExactKeys(
      outcomeRecord,
      _outcomeRecordRequiredKeys,
      'private.outcomes[$sequenceNo]',
      optional: _outcomeRecordOptionalKeys,
    );

    final intentDigest = _sha256(
      intentRecord['attemptIntentDigest'],
      'attemptIntentDigest',
    );
    final intentPayload = Map<String, Object?>.from(intentRecord)
      ..remove('sequenceNo')
      ..remove('attemptIntentDigest');
    final recomputedIntentDigest = AppLlmCanonicalHash.domainHash(
      'story-generation-attempt-intent-record-v1',
      intentPayload,
    );
    if (intentDigest != recomputedIntentDigest) {
      throw StateError('attempt intent digest mismatch at $sequenceNo');
    }
    final logicalAttemptId = _sha256(
      intentPayload['logicalAttemptId'],
      'logicalAttemptId',
    );
    if (!logicalAttemptIds.add(logicalAttemptId)) {
      throw StateError('duplicate logical attempt id');
    }
    if (intentPayload['evidenceRunId'] != evidenceRunId ||
        intentPayload['sceneId'] != sceneId ||
        intentPayload['preparedBriefDigest'] != preparedBriefDigest ||
        intentPayload['generationArmPolicy'] != generationArmPolicy ||
        intentPayload['physicalDispatchPolicy'] != 'single') {
      throw StateError('attempt intent is outside the receipt scope');
    }
    final recomputedLogicalAttemptId = AppLlmCanonicalHash.domainHash(
      'story-generation-logical-attempt-id-v1',
      <String, Object?>{
        'evidenceRunId': intentPayload['evidenceRunId'],
        'sceneId': intentPayload['sceneId'],
        'preparedBriefDigest': intentPayload['preparedBriefDigest'],
        'attempt': intentPayload['attempt'],
        'maxTokens': intentPayload['maxTokens'],
        'transientRetryCount': intentPayload['transientRetryCount'],
        'outputRetryCount': intentPayload['outputRetryCount'],
        'stageId': intentPayload['stageId'],
        'callSiteId': intentPayload['callSiteId'],
        'variantId': intentPayload['variantId'],
        'generationBundleHash': intentPayload['generationBundleHash'],
        'promptReleaseContentHash': intentPayload['promptReleaseContentHash'],
        'renderedMessagesDigest': intentPayload['renderedMessagesDigest'],
        'resolvedVariablesDigest': intentPayload['resolvedVariablesDigest'],
        'rendererContractHash': intentPayload['rendererContractHash'],
        'selectedRouteBindingHash': intentPayload['selectedRouteBindingHash'],
        'generationArmPolicy': intentPayload['generationArmPolicy'],
        'retryContractHash': intentPayload['retryContractHash'],
        'evaluationPhase': intentPayload['evaluationPhase'],
      },
    );
    if (logicalAttemptId != recomputedLogicalAttemptId) {
      throw StateError('logical attempt identity mismatch at $sequenceNo');
    }

    final outcomeDigest = _sha256(
      outcomeRecord['attemptEvidenceDigest'],
      'attemptEvidenceDigest',
    );
    final outcomePayload = Map<String, Object?>.from(outcomeRecord)
      ..remove('sequenceNo')
      ..remove('attemptEvidenceDigest');
    final recomputedOutcomeDigest = AppLlmCanonicalHash.domainHash(
      'story-generation-attempt-evidence-record-v1',
      outcomePayload,
    );
    if (outcomeDigest != recomputedOutcomeDigest ||
        outcomePayload['logicalAttemptId'] != logicalAttemptId) {
      throw StateError('attempt outcome digest mismatch at $sequenceNo');
    }
    final outcomeVerification = verifyStoryGenerationAttemptEvidenceJson(
      outcomePayload,
    );
    if (!outcomeVerification.evidenceComplete) {
      throw StateError(
        'attempt outcome is incomplete at $sequenceNo: '
        '${outcomeVerification.errors.join(', ')}',
      );
    }
    _requireMatchingAttemptIdentity(intentPayload, outcomePayload, sequenceNo);
    _requireCredentialFreeTransportReceipts(
      intent: intentPayload,
      outcome: outcomePayload,
      sequenceNo: sequenceNo,
    );

    final succeeded = outcomePayload['succeeded'];
    if (succeeded is! bool) {
      throw StateError('attempt outcome succeeded flag is invalid');
    }
    final isFinalProseSource = logicalAttemptId == sourceLogicalAttemptId;
    if (isFinalProseSource &&
        (!succeeded || outcomePayload['callSiteId'] != sourceCallSiteId)) {
      throw StateError(
        'final prose source must identify one successful matching callsite',
      );
    }
    final generationFingerprintDigest =
        outcomePayload['generationFingerprintDigest'];
    final evaluationRequired =
        outcomePayload['evaluationFingerprintRequired'] == true;
    final providerOutcomeSealHash = _sha256(
      outcomePayload['providerOutcomeSealHash'],
      'providerOutcomeSealHash',
    );
    final generationFingerprint = outcomePayload['generationFingerprint'];
    if (succeeded && !evaluationRequired) {
      final fingerprintMap = _stringMap(
        generationFingerprint,
        'generationFingerprint',
      );
      final fingerprintDigest = _sha256(
        generationFingerprintDigest,
        'generationFingerprintDigest',
      );
      final domainTag = _requiredString(
        fingerprintMap['domainTag'],
        'generationFingerprint.domainTag',
      );
      if (domainTag != 'story-generation-fingerprint-v1') {
        throw StateError('generation fingerprint domain is invalid');
      }
      if (AppLlmCanonicalHash.domainHash(domainTag, fingerprintMap) !=
          fingerprintDigest) {
        throw StateError('generation fingerprint mismatch at $sequenceNo');
      }
      _requireFingerprintMatchesIntent(
        fingerprintMap,
        intentPayload,
        sequenceNo,
      );
      final expectedModelRoute = AppLlmCanonicalHash.domainHash(
        _observedModelRouteDomainTag,
        <String, Object?>{
          'configuredRouteHash': intentPayload['selectedRouteBindingHash'],
          'providerEchoedModel': outcomePayload['providerModel'],
        },
      );
      if (fingerprintMap['modelRoute'] != expectedModelRoute) {
        throw StateError(
          'generation fingerprint model route mismatch at $sequenceNo',
        );
      }
      fingerprintMembers.add(<String, Object?>{
        'sequenceNo': sequenceNo,
        'logicalAttemptId': logicalAttemptId,
        'generationFingerprintDigest': fingerprintDigest,
      });
      final artifact = _artifactMap(
        outcomePayload['artifactDigest'],
        'artifactDigest',
      );
      if (isFinalProseSource) {
        if (!_canonicalEquals(artifact, sealedArtifactDigest)) {
          throw StateError(
            'final prose source artifact does not match the durable seal',
          );
        }
        finalProseSourceMatchCount += 1;
      }
    } else if (generationFingerprintDigest != null ||
        generationFingerprint != null) {
      throw StateError(
        'failed or evaluation attempt cannot claim a generation fingerprint',
      );
    }

    final evaluationFingerprint = outcomePayload['evaluationFingerprint'];
    final evaluationFingerprintDigest =
        outcomePayload['evaluationFingerprintDigest'];
    if (evaluationFingerprint != null || evaluationFingerprintDigest != null) {
      final evaluationMap = _stringMap(
        evaluationFingerprint,
        'evaluationFingerprint',
      );
      final evaluationDigest = _sha256(
        evaluationFingerprintDigest,
        'evaluationFingerprintDigest',
      );
      final evaluationDomainTag = _requiredString(
        evaluationMap['domainTag'],
        'evaluationFingerprint.domainTag',
      );
      if (!_hasExactEvaluationFingerprintShape(evaluationMap) ||
          evaluationMap['canonicalContract'] != AppLlmCanonicalHash.contract ||
          evaluationDomainTag != 'story-evaluation-fingerprint-v1' ||
          AppLlmCanonicalHash.domainHash(evaluationDomainTag, evaluationMap) !=
              evaluationDigest) {
        throw StateError('evaluation fingerprint mismatch at $sequenceNo');
      }
      if (!succeeded || !evaluationRequired) {
        throw StateError(
          'evaluation fingerprint is outside an evaluation attempt at '
          '$sequenceNo',
        );
      }
      _requiredString(
        outcomePayload['evaluationParserRelease'],
        'evaluationParserRelease',
      );
      _requiredString(outcomePayload['evaluationPhase'], 'evaluationPhase');
    }

    final bundleHash = _sha256(
      intentPayload['generationBundleHash'],
      'generationBundleHash',
    );
    bundleHashes.add(bundleHash);
    pairs.add(<String, Object?>{
      'sequenceNo': sequenceNo,
      'logicalAttemptId': logicalAttemptId,
      'attemptIntentDigest': intentDigest,
      'attemptEvidenceDigest': outcomeDigest,
      'providerOutcomeSealHash': providerOutcomeSealHash,
      'succeeded': succeeded,
      ...?generationFingerprintDigest == null
          ? null
          : <String, Object?>{
              'generationFingerprintDigest': generationFingerprintDigest,
            },
      ...?evaluationFingerprintDigest == null
          ? null
          : <String, Object?>{
              'evaluationFingerprintDigest': evaluationFingerprintDigest,
            },
    });
  }

  _validateFinalEvaluationManifestAgainstOutcomes(
    manifest: _finalEvaluationManifestMap(receipt['finalEvaluationManifest']),
    rawOutcomes: rawOutcomes,
    sealedArtifactDigest: sealedArtifactDigest,
  );

  if (finalProseSourceMatchCount != 1) {
    throw StateError(
      'final prose source must uniquely match one successful sealed attempt',
    );
  }

  final fingerprintSetDigest = AppLlmCanonicalHash.domainHash(
    GenerationEvidenceReceipt.generationFingerprintSetDomainTag,
    <String, Object?>{
      'ordering': 'durable-intent-admission-v1',
      'members': fingerprintMembers,
    },
  );
  final attemptEnvelopeDigest = AppLlmCanonicalHash.domainHash(
    GenerationEvidenceReceipt.attemptEnvelopeDomainTag,
    <String, Object?>{
      'sourceEnvelopeSchemaVersion': sourceEnvelopeSchemaVersion,
      'evidenceRunId': evidenceRunId,
      'sceneId': sceneId,
      'generationArmPolicy': generationArmPolicy,
      'preparedBriefDigest': preparedBriefDigest,
      'sealedArtifactDigest': sealedArtifactDigest,
      'finalProseSource': finalProseSource,
      'ordering': 'durable-intent-admission-v1',
      'attemptPairs': pairs,
    },
  );
  return _DerivedReceiptDigests(
    attemptEnvelopeDigest: attemptEnvelopeDigest,
    generationFingerprintSetDigest: fingerprintSetDigest,
    generationBundleHashes: Set<String>.unmodifiable(bundleHashes),
    attemptCount: pairs.length,
  );
}

void _validateFinalEvaluationManifestAgainstOutcomes({
  required Map<String, Object?>? manifest,
  required List<Object?> rawOutcomes,
  required Map<String, Object?> sealedArtifactDigest,
}) {
  if (manifest == null) return;
  if (!_canonicalEquals(
    manifest['finalArtifactDigest'],
    sealedArtifactDigest,
  )) {
    throw StateError(
      'final evaluation manifest does not bind the sealed artifact',
    );
  }
  final calls = _objectList(
    manifest['orderedCalls'],
    'finalEvaluationManifest.orderedCalls',
  );
  final manifestedIds = <String>{};
  final callSites = <String>{};
  final orderedCallSiteIds = <String>[];
  String? qualityParsedDigest;
  for (var index = 0; index < calls.length; index += 1) {
    final call = _stringMap(
      calls[index],
      'finalEvaluationManifest.orderedCalls[$index]',
    );
    final sequenceNo = call['sequenceNo']! as int;
    if (sequenceNo < 0 || sequenceNo >= rawOutcomes.length) {
      throw StateError('final evaluation call sequence is outside receipt');
    }
    final outcomeRecord = _stringMap(
      rawOutcomes[sequenceNo],
      'private.outcomes[$sequenceNo]',
    );
    final outcome = Map<String, Object?>.from(outcomeRecord)
      ..remove('sequenceNo')
      ..remove('attemptEvidenceDigest');
    final logicalAttemptId = call['logicalAttemptId']! as String;
    final stageId = call['stageId']! as String;
    final callSiteId = call['callSiteId']! as String;
    orderedCallSiteIds.add(callSiteId);
    final expectedPhase = stageId == 'quality-gate'
        ? StoryGenerationEvaluationPhase.quality.name
        : StoryGenerationEvaluationPhase.finalCouncil.name;
    if (!manifestedIds.add(logicalAttemptId) ||
        !callSites.add(callSiteId) ||
        outcome['succeeded'] != true ||
        outcome['evaluationFingerprintRequired'] != true ||
        outcome['logicalAttemptId'] != logicalAttemptId ||
        outcome['stageId'] != stageId ||
        outcome['callSiteId'] != callSiteId ||
        outcome['evaluationPhase'] != expectedPhase ||
        call['phase'] != expectedPhase ||
        outcome['providerOutcomeSealHash'] != call['providerOutcomeSealHash'] ||
        !_canonicalEquals(
          outcome['artifactDigest'],
          call['providerArtifactDigest'],
        ) ||
        outcome['promptReleaseContentHash'] !=
            call['promptReleaseContentHash'] ||
        outcome['evaluationParserRelease'] != call['parserRelease'] ||
        outcome['evaluationFingerprintDigest'] !=
            call['evaluationFingerprintDigest']) {
      throw StateError(
        'final evaluation manifest call does not match receipt outcome at '
        '$sequenceNo',
      );
    }
    final evaluation = _stringMap(
      outcome['evaluationFingerprint'],
      'evaluationFingerprint',
    );
    if (!_canonicalEquals(evaluation['artifactDigest'], sealedArtifactDigest)) {
      throw StateError(
        'final evaluation manifest selected a non-final artifact',
      );
    }
    if (stageId == 'quality-gate') {
      if (callSiteId != 'quality-scorer' || qualityParsedDigest != null) {
        throw StateError('final evaluation quality call is not unique');
      }
      qualityParsedDigest = call['parsedOutputDigest']! as String;
    } else if (stageId != 'review' ||
        !const <String>{
          'judge',
          'consistency',
          'reader-flow',
          'lexicon',
          'adjudication',
        }.contains(callSiteId)) {
      throw StateError('final evaluation callsite is not allowlisted');
    }
  }
  if (!callSites.containsAll(const <String>{
        'judge',
        'consistency',
        'quality-scorer',
      }) ||
      qualityParsedDigest != manifest['qualityParsedOutputDigest']) {
    throw StateError('final evaluation manifest is incomplete');
  }
  final expectedCallSiteOrder = <String>[
    'judge',
    'consistency',
    if (callSites.contains('reader-flow')) 'reader-flow',
    if (callSites.contains('lexicon')) 'lexicon',
    if (callSites.contains('adjudication')) 'adjudication',
    'quality-scorer',
  ];
  if (!_canonicalEquals(orderedCallSiteIds, expectedCallSiteOrder)) {
    throw StateError(
      'final evaluation manifest callsite order is not canonical',
    );
  }

  final eligibleOutcomeIds = <String>{};
  for (final rawOutcome in rawOutcomes) {
    final outcome = _stringMap(rawOutcome, 'private.outcome');
    if (outcome['succeeded'] != true ||
        outcome['evaluationFingerprintRequired'] != true) {
      continue;
    }
    final phase = outcome['evaluationPhase'];
    if (phase != StoryGenerationEvaluationPhase.finalCouncil.name &&
        phase != StoryGenerationEvaluationPhase.quality.name) {
      continue;
    }
    final evaluation = _stringMap(
      outcome['evaluationFingerprint'],
      'evaluationFingerprint',
    );
    if (_canonicalEquals(evaluation['artifactDigest'], sealedArtifactDigest)) {
      eligibleOutcomeIds.add(outcome['logicalAttemptId']! as String);
    }
  }
  if (eligibleOutcomeIds.length != manifestedIds.length ||
      !eligibleOutcomeIds.containsAll(manifestedIds)) {
    throw StateError(
      'final evaluation manifest omits or adds terminal evaluation outcomes',
    );
  }
}

Map<String, Object?> _finalProseSourceMap(Object? value) {
  final source = _stringMap(value, 'finalProseSource');
  _requireExactKeys(source, const <String>{
    'logicalAttemptId',
    'callSiteId',
  }, 'finalProseSource');
  _sha256(source['logicalAttemptId'], 'finalProseSource.logicalAttemptId');
  final callSiteId = _requiredString(
    source['callSiteId'],
    'finalProseSource.callSiteId',
  );
  if (!storyGenerationFinalProseSourceCallSites.contains(callSiteId)) {
    throw StateError('finalProseSource.callSiteId is not a prose producer');
  }
  return Map<String, Object?>.unmodifiable(source);
}

Map<String, Object?>? _finalEvaluationManifestMap(Object? value) {
  if (value == null) return null;
  final manifest = _stringMap(value, 'finalEvaluationManifest');
  _requireExactKeys(manifest, const <String>{
    'schemaVersion',
    'finalArtifactDigest',
    'reviewParsedOutputDigest',
    'qualityParsedOutputDigest',
    'orderedCalls',
  }, 'finalEvaluationManifest');
  if (manifest['schemaVersion'] != 'pipeline-final-evaluation-manifest-v1') {
    throw StateError('final evaluation manifest schema is unsupported');
  }
  _artifactMap(
    manifest['finalArtifactDigest'],
    'finalEvaluationManifest.finalArtifactDigest',
  );
  _sha256(
    manifest['reviewParsedOutputDigest'],
    'finalEvaluationManifest.reviewParsedOutputDigest',
  );
  _sha256(
    manifest['qualityParsedOutputDigest'],
    'finalEvaluationManifest.qualityParsedOutputDigest',
  );
  final calls = _objectList(
    manifest['orderedCalls'],
    'finalEvaluationManifest.orderedCalls',
  );
  if (calls.length < 3) {
    throw StateError(
      'final evaluation manifest requires council and quality calls',
    );
  }
  var previousSequenceNo = -1;
  final logicalAttemptIds = <String>{};
  final callSiteIds = <String>{};
  for (var index = 0; index < calls.length; index += 1) {
    final call = _stringMap(
      calls[index],
      'finalEvaluationManifest.orderedCalls[$index]',
    );
    _requireExactKeys(call, const <String>{
      'sequenceNo',
      'phase',
      'stageId',
      'callSiteId',
      'logicalAttemptId',
      'providerOutcomeSealHash',
      'providerArtifactDigest',
      'promptReleaseContentHash',
      'parserRelease',
      'evaluationFingerprintDigest',
      'parsedOutputDigest',
    }, 'finalEvaluationManifest.orderedCalls[$index]');
    final sequenceNo = call['sequenceNo'];
    if (sequenceNo is! int || sequenceNo <= previousSequenceNo) {
      throw StateError('final evaluation manifest call order is invalid');
    }
    previousSequenceNo = sequenceNo;
    final logicalAttemptId = _sha256(
      call['logicalAttemptId'],
      'finalEvaluationManifest.logicalAttemptId',
    );
    final callSiteId = _requiredString(
      call['callSiteId'],
      'finalEvaluationManifest.callSiteId',
    );
    if (!logicalAttemptIds.add(logicalAttemptId) ||
        !callSiteIds.add(callSiteId)) {
      throw StateError('final evaluation manifest calls must be unique');
    }
    _requiredString(call['phase'], 'finalEvaluationManifest.phase');
    _requiredString(call['stageId'], 'finalEvaluationManifest.stageId');
    _sha256(
      call['providerOutcomeSealHash'],
      'finalEvaluationManifest.providerOutcomeSealHash',
    );
    _artifactMap(
      call['providerArtifactDigest'],
      'finalEvaluationManifest.providerArtifactDigest',
    );
    _sha256(
      call['promptReleaseContentHash'],
      'finalEvaluationManifest.promptReleaseContentHash',
    );
    _requiredString(
      call['parserRelease'],
      'finalEvaluationManifest.parserRelease',
    );
    _sha256(
      call['evaluationFingerprintDigest'],
      'finalEvaluationManifest.evaluationFingerprintDigest',
    );
    _sha256(
      call['parsedOutputDigest'],
      'finalEvaluationManifest.parsedOutputDigest',
    );
  }
  return Map<String, Object?>.unmodifiable(manifest);
}

void _requireMatchingAttemptIdentity(
  Map<String, Object?> intent,
  Map<String, Object?> outcome,
  int sequenceNo,
) {
  const fields = <String>[
    'attempt',
    'maxTokens',
    'transientRetryCount',
    'outputRetryCount',
    'stageId',
    'callSiteId',
    'variantId',
    'preparedBriefDigest',
    'generationBundleHash',
    'promptReleaseContentHash',
    'renderedMessagesDigest',
    'resolvedVariablesDigest',
    'rendererContractHash',
    'selectedRouteBindingHash',
    'evaluationPhase',
  ];
  for (final field in fields) {
    if (!_canonicalEquals(intent[field], outcome[field])) {
      throw StateError('attempt intent/outcome $field mismatch at $sequenceNo');
    }
  }
  if (outcome['routeResolutionRequired'] != true ||
      outcome['routeResolutionVerified'] != true) {
    throw StateError('attempt route was not physically verified');
  }
}

void _requireFingerprintMatchesIntent(
  Map<String, Object?> fingerprint,
  Map<String, Object?> intent,
  int sequenceNo,
) {
  _requireExactKeys(fingerprint, const <String>{
    'domainTag',
    'canonicalContract',
    'semanticInput',
    'generationBundleHash',
    'modelRoute',
    'decodingParameters',
    'armPolicy',
    'retryPolicy',
  }, 'generationFingerprint');
  if (fingerprint['canonicalContract'] != AppLlmCanonicalHash.contract) {
    throw StateError(
      'generation fingerprint canonical contract is unsupported',
    );
  }
  if (fingerprint['generationBundleHash'] != intent['generationBundleHash'] ||
      fingerprint['armPolicy'] != intent['generationArmPolicy'] ||
      fingerprint['retryPolicy'] != intent['retryContractHash']) {
    throw StateError('generation fingerprint contract mismatch at $sequenceNo');
  }
  final semanticInput = _stringMap(
    fingerprint['semanticInput'],
    'generationFingerprint.semanticInput',
  );
  _requireExactKeys(semanticInput, const <String>{
    'stageId',
    'callSiteId',
    'promptReleaseContentHash',
    'renderedMessagesDigest',
    'resolvedVariablesDigest',
    'rendererContractHash',
    'preparedBriefDigest',
  }, 'generationFingerprint.semanticInput');
  final expected = <String, Object?>{
    'stageId': intent['stageId'],
    'callSiteId': intent['callSiteId'],
    'promptReleaseContentHash': intent['promptReleaseContentHash'],
    'renderedMessagesDigest': intent['renderedMessagesDigest'],
    'resolvedVariablesDigest': intent['resolvedVariablesDigest'],
    'rendererContractHash': intent['rendererContractHash'],
    'preparedBriefDigest': intent['preparedBriefDigest'],
  };
  for (final entry in expected.entries) {
    if (!_canonicalEquals(semanticInput[entry.key], entry.value)) {
      throw StateError(
        'generation fingerprint ${entry.key} mismatch at $sequenceNo',
      );
    }
  }
  _sha256(fingerprint['modelRoute'], 'generationFingerprint.modelRoute');
  final decodingParameters = _stringMap(
    fingerprint['decodingParameters'],
    'generationFingerprint.decodingParameters',
  );
  _requireExactKeys(decodingParameters, const <String>{
    'maxTokens',
  }, 'generationFingerprint.decodingParameters');
  if (decodingParameters['maxTokens'] != intent['maxTokens']) {
    throw StateError(
      'generation fingerprint decoding parameters mismatch at $sequenceNo',
    );
  }
}

void _requireCredentialFreeTransportReceipts({
  required Map<String, Object?> intent,
  required Map<String, Object?> outcome,
  required int sequenceNo,
}) {
  final selectedBinding = _stringMap(
    outcome['selectedRouteBinding'],
    'selectedRouteBinding',
  );
  final observedResolution = _stringMap(
    outcome['observedDispatchResolution'],
    'observedDispatchResolution',
  );
  final providerReceipt = _stringMap(
    outcome['providerBoundaryReceipt'],
    'providerBoundaryReceipt',
  );
  final providerOutcomeSeal = _stringMap(
    outcome['providerOutcomeSeal'],
    'providerOutcomeSeal',
  );
  final selectedBindingHash = _sha256(
    outcome['selectedRouteBindingHash'],
    'selectedRouteBindingHash',
  );
  if (selectedBindingHash != intent['selectedRouteBindingHash'] ||
      selectedBindingHash !=
          AppLlmCanonicalHash.domainHash(
            _configuredRouteDomainTag,
            selectedBinding,
          )) {
    throw StateError('selected route binding changed at $sequenceNo');
  }
  // The transport side owns these serializations.  Rehashing their
  // credential-free canonical payloads prevents a retained boolean/hash pair
  // from becoming a stand-in for the actual dispatch proof.
  final observedHash = AppLlmCanonicalHash.domainHash(
    _selectedPhysicalEndpointDomainTag,
    observedResolution,
  );
  if (observedHash != outcome['observedDispatchResolutionHash']) {
    throw StateError('observed dispatch resolution mismatch at $sequenceNo');
  }
  final providerHash = AppLlmCanonicalHash.domainHash(
    _providerBoundaryReceiptDomainTag,
    providerReceipt,
  );
  if (providerHash != outcome['providerBoundaryReceiptHash']) {
    throw StateError('provider boundary receipt mismatch at $sequenceNo');
  }
  _requireProviderOutcomeSealMatches(
    outcome: outcome,
    providerReceipt: providerReceipt,
    providerOutcomeSeal: providerOutcomeSeal,
    sequenceNo: sequenceNo,
  );
  _requireExactKeys(providerReceipt, const <String>{
    'contract',
    'physicalDispatchCount',
    'requestedBaseUrl',
    'requestedModel',
    'requestedProvider',
    'dispatchEvidenceNonce',
    'transportEndpoint',
  }, 'providerBoundaryReceipt');
  if (providerReceipt['physicalDispatchCount'] != 1 ||
      providerReceipt['contract'] != 'app-llm-provider-boundary-receipt-v1') {
    throw StateError('provider receipt is not exactly one physical dispatch');
  }
  final logicalAttemptId = _sha256(
    outcome['logicalAttemptId'],
    'logicalAttemptId',
  );
  if (_sha256(
        providerReceipt['dispatchEvidenceNonce'],
        'providerBoundaryReceipt.dispatchEvidenceNonce',
      ) !=
      logicalAttemptId) {
    throw StateError(
      'provider receipt is replayed from a different logical attempt at '
      '$sequenceNo',
    );
  }
  final transportEndpoint = Uri.tryParse(
    _requiredString(
      providerReceipt['transportEndpoint'],
      'providerBoundaryReceipt.transportEndpoint',
    ),
  );
  if (transportEndpoint == null ||
      !transportEndpoint.isAbsolute ||
      transportEndpoint.userInfo.isNotEmpty) {
    throw StateError(
      'provider receipt transport endpoint is not credential-free and absolute',
    );
  }
  final selectedEndpoint = _stringMap(
    selectedBinding['selectedEndpoint'],
    'selectedRouteBinding.selectedEndpoint',
  );
  for (final field in const <String>['baseUrl', 'model', 'provider']) {
    if (selectedEndpoint[field] != observedResolution[field]) {
      throw StateError(
        'observed dispatch endpoint $field mismatch at $sequenceNo',
      );
    }
  }
  if (providerReceipt['requestedBaseUrl'] != selectedEndpoint['baseUrl'] ||
      providerReceipt['requestedModel'] != selectedEndpoint['model'] ||
      providerReceipt['requestedProvider'] != selectedEndpoint['provider']) {
    throw StateError('provider receipt endpoint mismatch at $sequenceNo');
  }
}

void _requireProviderOutcomeSealMatches({
  required Map<String, Object?> outcome,
  required Map<String, Object?> providerReceipt,
  required Map<String, Object?> providerOutcomeSeal,
  required int sequenceNo,
}) {
  _requireExactKeys(providerOutcomeSeal, const <String>{
    'contract',
    'succeeded',
    'requestedProvider',
    'requestedModel',
    'statusCode',
    'failureKind',
    'dispatchFailureDisposition',
    'providerModel',
    'providerResponseIdUtf8',
    'promptTokens',
    'completionTokens',
    'totalTokens',
    'textUtf8',
    'detailUtf8',
  }, 'providerOutcomeSeal');
  if (providerOutcomeSeal['contract'] != 'app-llm-provider-outcome-seal-v1') {
    throw StateError('provider outcome seal contract is unsupported');
  }
  final persistedSealHash = _sha256(
    outcome['providerOutcomeSealHash'],
    'providerOutcomeSealHash',
  );
  if (appLlmProviderOutcomeSealDigest(providerOutcomeSeal) !=
      persistedSealHash) {
    throw StateError('provider outcome seal hash mismatch at $sequenceNo');
  }
  for (final field in const <String>[
    'promptTokens',
    'completionTokens',
    'totalTokens',
  ]) {
    final value = providerOutcomeSeal[field];
    if (value != null && (value is! int || value < 0)) {
      throw StateError('provider outcome seal $field is invalid');
    }
  }
  final providerResponseIdUtf8 = _optionalExactUtf8Seal(
    providerOutcomeSeal['providerResponseIdUtf8'],
    'providerOutcomeSeal.providerResponseIdUtf8',
  );
  final textUtf8 = _optionalExactUtf8Seal(
    providerOutcomeSeal['textUtf8'],
    'providerOutcomeSeal.textUtf8',
  );
  final detailUtf8 = _optionalExactUtf8Seal(
    providerOutcomeSeal['detailUtf8'],
    'providerOutcomeSeal.detailUtf8',
  );
  final providerResponseId = outcome['providerResponseId'];
  final expectedProviderResponseIdUtf8 = appLlmExactUtf8Seal(
    providerResponseId is String ? providerResponseId : null,
  );
  if (providerOutcomeSeal['requestedProvider'] !=
          providerReceipt['requestedProvider'] ||
      providerOutcomeSeal['requestedModel'] !=
          providerReceipt['requestedModel'] ||
      providerOutcomeSeal['succeeded'] != outcome['succeeded'] ||
      providerOutcomeSeal['failureKind'] != outcome['failureKind'] ||
      providerOutcomeSeal['statusCode'] != outcome['statusCode'] ||
      providerOutcomeSeal['providerModel'] != outcome['providerModel'] ||
      !_canonicalEquals(
        providerResponseIdUtf8,
        expectedProviderResponseIdUtf8,
      ) ||
      providerOutcomeSeal['promptTokens'] != outcome['promptTokens'] ||
      providerOutcomeSeal['completionTokens'] != outcome['completionTokens'] ||
      providerOutcomeSeal['totalTokens'] != outcome['totalTokens'] ||
      providerOutcomeSeal['dispatchFailureDisposition'] !=
          outcome['dispatchFailureDisposition']) {
    throw StateError(
      'provider outcome seal disagrees with attempt fields at $sequenceNo',
    );
  }

  final succeeded = outcome['succeeded'];
  if (succeeded == true) {
    final artifact = _artifactMap(outcome['artifactDigest'], 'artifactDigest');
    if (textUtf8 == null ||
        !_canonicalEquals(textUtf8, <String, Object?>{
          'byteLength': artifact['byteLength'],
          'digest': artifact['digest'],
        }) ||
        detailUtf8 != null ||
        outcome['failureKind'] != null) {
      throw StateError(
        'successful provider outcome does not seal its exact artifact bytes',
      );
    }
    return;
  }
  if (succeeded == false) {
    final responseDigest = outcome['responseDigest'];
    if (textUtf8 != null ||
        outcome['artifactDigest'] != null ||
        (detailUtf8 == null
            ? responseDigest != null
            : detailUtf8['digest'] != responseDigest)) {
      throw StateError(
        'failed provider outcome does not seal its exact failure detail',
      );
    }
    return;
  }
  throw StateError('provider outcome seal succeeded flag is invalid');
}

Map<String, Object?>? _optionalExactUtf8Seal(Object? value, String field) {
  if (value == null) return null;
  final seal = _stringMap(value, field);
  _requireExactKeys(seal, const <String>{'byteLength', 'digest'}, field);
  final byteLength = seal['byteLength'];
  if (byteLength is! int || byteLength < 0) {
    throw StateError('$field byteLength is invalid');
  }
  _sha256(seal['digest'], '$field.digest');
  return Map<String, Object?>.unmodifiable(seal);
}

Map<String, Object?> _artifactMap(Object? value, String field) {
  final map = _stringMap(value, field);
  _requireExactKeys(map, const <String>{
    'domainTag',
    'byteContract',
    'byteLength',
    'digest',
  }, field);
  if (map['domainTag'] != ArtifactDigest.defaultDomainTag ||
      map['byteContract'] != 'exact-utf8-bytes-no-normalization-v1' ||
      map['byteLength'] is! int ||
      (map['byteLength']! as int) < 0) {
    throw StateError('$field is not an exact UTF-8 artifact identity');
  }
  _sha256(map['digest'], '$field.digest');
  return Map<String, Object?>.unmodifiable(map);
}

Map<String, Object?> _stringMap(Object? value, String field) {
  if (value is! Map) throw StateError('$field must be an object');
  try {
    return Map<String, Object?>.from(value);
  } on Object {
    throw StateError('$field must use string keys');
  }
}

List<Object?> _objectList(Object? value, String field) {
  if (value is! List) throw StateError('$field must be a list');
  return List<Object?>.from(value);
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.isEmpty || value != value.trim()) {
    throw StateError('$field is required');
  }
  return value;
}

String _sha256(Object? value, String field) {
  final text = _requiredString(value, field);
  if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(text)) {
    throw StateError('$field must be sha256:<lower-hex>');
  }
  return text;
}

bool _canonicalEquals(Object? left, Object? right) {
  try {
    return AppLlmCanonicalHash.canonicalJson(left) ==
        AppLlmCanonicalHash.canonicalJson(right);
  } on Object {
    return false;
  }
}

bool _hasExactEvaluationFingerprintShape(Map<String, Object?> value) {
  try {
    _requireExactKeys(value, const <String>{
      'domainTag',
      'canonicalContract',
      'artifactDigest',
      'evaluationBundleHash',
      'judgeInput',
      'judgeModelRoute',
      'rubricHash',
      'blindingPolicy',
    }, 'evaluationFingerprint');
    final evaluatedArtifact = _artifactMap(
      value['artifactDigest'],
      'evaluationFingerprint.artifactDigest',
    );
    final judgeInput = _stringMap(
      value['judgeInput'],
      'evaluationFingerprint.judgeInput',
    );
    _requireExactKeys(judgeInput, const <String>{
      'evaluatedArtifactDigest',
      'semanticInputDigest',
    }, 'evaluationFingerprint.judgeInput');
    final judgeEvaluatedArtifact = _artifactMap(
      judgeInput['evaluatedArtifactDigest'],
      'evaluationFingerprint.judgeInput.evaluatedArtifactDigest',
    );
    _sha256(
      judgeInput['semanticInputDigest'],
      'evaluationFingerprint.judgeInput.semanticInputDigest',
    );
    if (!_canonicalEquals(judgeEvaluatedArtifact, evaluatedArtifact)) {
      throw StateError(
        'evaluationFingerprint.judgeInput must bind artifactDigest',
      );
    }
    _sha256(
      value['evaluationBundleHash'],
      'evaluationFingerprint.evaluationBundleHash',
    );
    _sha256(value['rubricHash'], 'evaluationFingerprint.rubricHash');
    _sha256(value['judgeModelRoute'], 'evaluationFingerprint.judgeModelRoute');
    _requiredString(
      value['blindingPolicy'],
      'evaluationFingerprint.blindingPolicy',
    );
    return true;
  } on StateError {
    return false;
  }
}

void _requireExactKeys(
  Map<String, Object?> map,
  Set<String> required,
  String field, {
  Set<String> optional = const <String>{},
}) {
  final allowed = <String>{...required, ...optional};
  if (!map.keys.toSet().containsAll(required) ||
      map.keys.any((key) => !allowed.contains(key))) {
    throw StateError('$field has an unsupported v1 shape');
  }
}

const Set<String> _receiptKeys = <String>{
  'schemaVersion',
  'visibility',
  'evidenceComplete',
  'evidenceRunId',
  'sceneId',
  'generationArmPolicy',
  'preparedBriefDigest',
  'sealedArtifactDigest',
  'finalProseSource',
  'finalEvaluationManifest',
  'sourceEnvelopeSchemaVersion',
  'private',
  'attemptEvidenceEnvelopeDigest',
  'generationFingerprintSetDigest',
  'receiptHash',
};

const String _configuredRouteDomainTag =
    'story-generation-configured-model-route-v1';
const String _selectedPhysicalEndpointDomainTag =
    'story-generation-selected-physical-endpoint-v1';
const String _providerBoundaryReceiptDomainTag =
    'story-generation-provider-boundary-receipt-v1';
const String _observedModelRouteDomainTag =
    'story-generation-observed-model-route-v1';

const Set<String> _receiptSeedKeys = <String>{
  'schemaVersion',
  'visibility',
  'evidenceComplete',
  'evidenceRunId',
  'sceneId',
  'generationArmPolicy',
  'preparedBriefDigest',
  'sealedArtifactDigest',
  'finalProseSource',
  'finalEvaluationManifest',
  'sourceEnvelopeSchemaVersion',
  'private',
};

const Set<String> _receiptDerivedKeys = <String>{
  'attemptEvidenceEnvelopeDigest',
  'generationFingerprintSetDigest',
  'receiptHash',
};

const Set<String> _privateKeys = <String>{'intents', 'outcomes'};

const Set<String> _intentRecordKeys = <String>{
  'sequenceNo',
  'attemptIntentDigest',
  'evidenceRunId',
  'sceneId',
  'preparedBriefDigest',
  'logicalAttemptId',
  'attempt',
  'maxTokens',
  'transientRetryCount',
  'outputRetryCount',
  'stageId',
  'callSiteId',
  'variantId',
  'generationBundleHash',
  'promptReleaseRef',
  'promptReleaseContentHash',
  'renderedMessagesDigest',
  'resolvedVariablesDigest',
  'rendererContractHash',
  'selectedRouteBindingHash',
  'generationArmPolicy',
  'retryContractHash',
  'evaluationPhase',
  'physicalDispatchPolicy',
};

const Set<String> _outcomeRecordRequiredKeys = <String>{
  'sequenceNo',
  'attemptEvidenceDigest',
  'attempt',
  'maxTokens',
  'transientRetryCount',
  'outputRetryCount',
  'succeeded',
  'disposition',
  'stageId',
  'callSiteId',
  'variantId',
  'preparedBriefDigest',
  'logicalAttemptId',
  'generationBundleHash',
  'promptReleaseRef',
  'promptReleaseContentHash',
  'renderedMessagesDigest',
  'resolvedVariablesDigest',
  'rendererContractHash',
  'selectedRouteBindingHash',
  'selectedRouteBinding',
  'observedDispatchResolutionHash',
  'observedDispatchResolution',
  'providerBoundaryReceiptHash',
  'providerBoundaryReceipt',
  'providerOutcomeSealHash',
  'providerOutcomeSeal',
  'routeResolutionRequired',
  'routeResolutionVerified',
  'providerBoundaryReceiptRequired',
  'providerBoundaryReceiptVerified',
  'evaluationFingerprintRequired',
  'evidenceComplete',
};

const Set<String> _outcomeRecordOptionalKeys = <String>{
  'failureKind',
  'statusCode',
  'providerModel',
  'providerResponseId',
  'promptTokens',
  'completionTokens',
  'totalTokens',
  'responseDigest',
  'providerBoundaryPhysicalDispatchCount',
  'dispatchFailureDisposition',
  'artifactDigest',
  'generationFingerprintDigest',
  'generationFingerprint',
  'evaluationFingerprintDigest',
  'evaluationFingerprint',
  'evaluationParserRelease',
  'evaluationPhase',
};

final class _DerivedReceiptDigests {
  const _DerivedReceiptDigests({
    required this.attemptEnvelopeDigest,
    required this.generationFingerprintSetDigest,
    required this.generationBundleHashes,
    required this.attemptCount,
  });

  final String attemptEnvelopeDigest;
  final String generationFingerprintSetDigest;
  final Set<String> generationBundleHashes;
  final int attemptCount;
}
