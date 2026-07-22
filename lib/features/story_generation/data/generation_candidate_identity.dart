import '../../../app/llm/app_llm_canonical_hash.dart';
import 'generation_ledger_digest.dart';

/// Versioned identity of a durable author candidate.
///
/// V1 is retained only so existing immutable proof rows remain readable. New
/// candidates use V2, whose hash binds the effective model-visible brief and
/// the explicit generation-evidence mode. A sealed no-redraw candidate also
/// binds the verified attempt envelope and its ordered generation fingerprint
/// set.
final class GenerationCandidateIdentity {
  const GenerationCandidateIdentity._();

  static const String v1 = 'candidate-proof-v1';
  static const String v2 = 'candidate-proof-v2';

  static const String legacyUnsealedMode = 'legacy-unsealed-v1';
  static const String adaptiveUnsealedMode = 'adaptive-unsealed-v1';
  static const String sealedNoRedrawMode = 'sealed-no-redraw-v1';

  static String computeV1({
    required String runId,
    required int candidateRevision,
    required String finalProseHash,
    required String deterministicGateEvidenceHash,
    required String finalCouncilEvidenceHash,
    required String qualityEvidenceHash,
    required String pendingWriteSetHash,
    required String materialDigest,
    required String inputDigest,
    required String generationBundleHash,
  }) {
    _requireIdentity(runId, 'runId');
    return GenerationLedgerDigest.object(<String, Object?>{
      'runId': runId,
      'candidateRevision': candidateRevision,
      'finalProseHash': finalProseHash,
      'deterministicGateEvidenceHash': deterministicGateEvidenceHash,
      'finalCouncilEvidenceHash': finalCouncilEvidenceHash,
      'qualityEvidenceHash': qualityEvidenceHash,
      'pendingWriteSetHash': pendingWriteSetHash,
      'materialDigest': materialDigest,
      'inputDigest': inputDigest,
      'generationBundleHash': generationBundleHash,
    });
  }

  static String computeV2({
    required String runId,
    required int candidateRevision,
    required String finalProseHash,
    required String deterministicGateEvidenceHash,
    required String finalCouncilEvidenceHash,
    required String qualityEvidenceHash,
    required String pendingWriteSetHash,
    required String materialDigest,
    required String effectiveInputDigest,
    required String preparedBriefDigest,
    required String effectiveBriefDigest,
    required String generationBundleHash,
    required String generationEvidenceMode,
    String? generationEvidenceReceiptHash,
    String? attemptEvidenceEnvelopeDigest,
    String? generationFingerprintSetDigest,
  }) {
    _requireIdentity(runId, 'runId');
    if (candidateRevision < 0) {
      throw ArgumentError.value(
        candidateRevision,
        'candidateRevision',
        'must be non-negative',
      );
    }
    for (final entry in <String, String>{
      'finalProseHash': finalProseHash,
      'deterministicGateEvidenceHash': deterministicGateEvidenceHash,
      'finalCouncilEvidenceHash': finalCouncilEvidenceHash,
      'qualityEvidenceHash': qualityEvidenceHash,
      'pendingWriteSetHash': pendingWriteSetHash,
      'materialDigest': materialDigest,
      'effectiveInputDigest': effectiveInputDigest,
      'preparedBriefDigest': preparedBriefDigest,
      'effectiveBriefDigest': effectiveBriefDigest,
      'generationBundleHash': generationBundleHash,
    }.entries) {
      _requireSha256(entry.value, entry.key);
    }
    if (generationEvidenceMode != adaptiveUnsealedMode &&
        generationEvidenceMode != sealedNoRedrawMode) {
      throw ArgumentError.value(
        generationEvidenceMode,
        'generationEvidenceMode',
        'must be an explicit V2 evidence mode',
      );
    }
    final sealed = generationEvidenceMode == sealedNoRedrawMode;
    if (sealed && preparedBriefDigest != effectiveBriefDigest) {
      throw ArgumentError.value(
        effectiveBriefDigest,
        'effectiveBriefDigest',
        'sealed no-redraw candidate must retain its prepared brief identity',
      );
    }
    final evidenceDigests = <String, String?>{
      'generationEvidenceReceiptHash': generationEvidenceReceiptHash,
      'attemptEvidenceEnvelopeDigest': attemptEvidenceEnvelopeDigest,
      'generationFingerprintSetDigest': generationFingerprintSetDigest,
    };
    for (final entry in evidenceDigests.entries) {
      if (sealed) {
        _requireSha256(entry.value, entry.key);
      } else if (entry.value != null) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'adaptive-unsealed candidates cannot claim sealed evidence',
        );
      }
    }

    // V2 is deliberately not a new field set inside the legacy ledger hash
    // domain.  A verifier must be able to tell which identity contract it is
    // checking before it interprets the payload.
    return AppLlmCanonicalHash.domainHash(v2, <String, Object?>{
      'identityVersion': v2,
      'runId': runId,
      'candidateRevision': candidateRevision,
      'finalProseHash': finalProseHash,
      'deterministicGateEvidenceHash': deterministicGateEvidenceHash,
      'finalCouncilEvidenceHash': finalCouncilEvidenceHash,
      'qualityEvidenceHash': qualityEvidenceHash,
      'pendingWriteSetHash': pendingWriteSetHash,
      'materialDigest': materialDigest,
      'effectiveInputDigest': effectiveInputDigest,
      'preparedBriefDigest': preparedBriefDigest,
      'effectiveBriefDigest': effectiveBriefDigest,
      'generationBundleHash': generationBundleHash,
      'generationEvidence': <String, Object?>{
        'mode': generationEvidenceMode,
        if (sealed) ...<String, Object?>{
          'receiptHash': generationEvidenceReceiptHash,
          'attemptEnvelopeDigest': attemptEvidenceEnvelopeDigest,
          'generationFingerprintSetDigest': generationFingerprintSetDigest,
        },
      },
    });
  }
}

void _requireIdentity(String value, String field) {
  if (value.isEmpty ||
      value != value.trim() ||
      value.length > 256 ||
      RegExp(r'[\u0000-\u001f\u007f-\u009f]').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      field,
      'must be trimmed, non-empty, at most 256 code units, and control-free',
    );
  }
}

void _requireSha256(String? value, String field) {
  if (value == null || !RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(value, field, 'must be sha256:<lower-hex>');
  }
}
