import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_candidate_identity.dart';

void main() {
  const hashA =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const hashB =
      'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const hashC =
      'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  test('V1 preserves the pre-V28 candidate formula', () {
    final first = GenerationCandidateIdentity.computeV1(
      runId: 'run-1',
      candidateRevision: 0,
      finalProseHash: hashA,
      deterministicGateEvidenceHash: hashA,
      finalCouncilEvidenceHash: hashA,
      qualityEvidenceHash: hashA,
      pendingWriteSetHash: hashA,
      materialDigest: hashA,
      inputDigest: hashA,
      generationBundleHash: hashA,
    );
    final second = GenerationCandidateIdentity.computeV1(
      runId: 'run-1',
      candidateRevision: 0,
      finalProseHash: hashA,
      deterministicGateEvidenceHash: hashA,
      finalCouncilEvidenceHash: hashA,
      qualityEvidenceHash: hashA,
      pendingWriteSetHash: hashA,
      materialDigest: hashA,
      inputDigest: hashA,
      generationBundleHash: hashA,
    );

    expect(first, second);
    expect(first, matches(RegExp(r'^sha256:[0-9a-f]{64}$')));
  });

  test('candidate identity rejects ambiguous run identifiers', () {
    for (final runId in <String>[' run-1', 'run-1 ', 'run\u0000-1']) {
      expect(
        () => GenerationCandidateIdentity.computeV1(
          runId: runId,
          candidateRevision: 0,
          finalProseHash: hashA,
          deterministicGateEvidenceHash: hashA,
          finalCouncilEvidenceHash: hashA,
          qualityEvidenceHash: hashA,
          pendingWriteSetHash: hashA,
          materialDigest: hashA,
          inputDigest: hashA,
          generationBundleHash: hashA,
        ),
        throwsArgumentError,
      );
    }
  });

  test('V2 binds prepared and effective brief identities', () {
    final baseline = _v2(
      preparedBriefDigest: hashA,
      effectiveBriefDigest: hashA,
    );

    expect(
      _v2(preparedBriefDigest: hashB, effectiveBriefDigest: hashA),
      isNot(baseline),
    );
    expect(
      _v2(preparedBriefDigest: hashA, effectiveBriefDigest: hashB),
      isNot(baseline),
    );
  });

  test('sealed V2 binds receipt, envelope, and fingerprint-set digests', () {
    final baseline = _v2(
      generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
      generationEvidenceReceiptHash: hashA,
      attemptEvidenceEnvelopeDigest: hashB,
      generationFingerprintSetDigest: hashC,
    );

    expect(
      _v2(
        generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
        generationEvidenceReceiptHash: hashB,
        attemptEvidenceEnvelopeDigest: hashB,
        generationFingerprintSetDigest: hashC,
      ),
      isNot(baseline),
    );
    expect(
      () => _v2(
        generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
        generationEvidenceReceiptHash: hashA,
      ),
      throwsArgumentError,
    );
  });

  test('adaptive V2 cannot claim sealed evidence', () {
    expect(
      () => _v2(generationEvidenceReceiptHash: hashA),
      throwsArgumentError,
    );
    expect(() => _v2(generationEvidenceReceiptHash: ''), throwsArgumentError);
  });

  test('sealed V2 rejects prepared/effective brief divergence', () {
    expect(
      () => _v2(
        preparedBriefDigest: hashA,
        effectiveBriefDigest: hashB,
        generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
        generationEvidenceReceiptHash: hashA,
        attemptEvidenceEnvelopeDigest: hashB,
        generationFingerprintSetDigest: hashC,
      ),
      throwsArgumentError,
    );
  });
}

String _v2({
  String preparedBriefDigest =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String effectiveBriefDigest =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String generationEvidenceMode =
      GenerationCandidateIdentity.adaptiveUnsealedMode,
  String? generationEvidenceReceiptHash,
  String? attemptEvidenceEnvelopeDigest,
  String? generationFingerprintSetDigest,
}) => GenerationCandidateIdentity.computeV2(
  runId: 'run-1',
  candidateRevision: 0,
  finalProseHash:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  deterministicGateEvidenceHash:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  finalCouncilEvidenceHash:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  qualityEvidenceHash:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  pendingWriteSetHash:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  materialDigest:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  effectiveInputDigest:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  preparedBriefDigest: preparedBriefDigest,
  effectiveBriefDigest: effectiveBriefDigest,
  generationBundleHash:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  generationEvidenceMode: generationEvidenceMode,
  generationEvidenceReceiptHash: generationEvidenceReceiptHash,
  attemptEvidenceEnvelopeDigest: attemptEvidenceEnvelopeDigest,
  generationFingerprintSetDigest: generationFingerprintSetDigest,
);
