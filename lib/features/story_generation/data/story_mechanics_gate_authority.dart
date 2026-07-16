import 'generation_ledger_digest.dart';
import 'polish_canon_evidence.dart';
import 'polish_canon_verifier.dart';
import 'production_pre_quality_gate.dart';
import 'story_mechanics_evidence.dart';
import 'story_mechanics_verifier.dart';

/// Shared gate/report rederiver for the complete deterministic story gate.
abstract final class StoryMechanicsGateAuthority {
  static bool verifyReceipt({
    required Object? encodedPolishCanonEvidence,
    required Object? encodedStoryMechanicsEvidence,
    required String gateFinalProseHash,
    required String deterministicGateEvidenceHash,
    Object? encodedDeterministicGate,
    String? finalProse,
  }) {
    // The legacy argument set can reconstruct only deterministic-gate-v3. It
    // cannot establish the v4 production boundary, brief binding, or exact
    // pre-quality prose identity, so absence of the complete gate must fail
    // closed instead of silently accepting a stale receipt.
    if (encodedDeterministicGate == null || finalProse == null) return false;
    try {
      final gate = _stringObjectMap(encodedDeterministicGate);
      final encodedPolish = PolishCanonEvidence.fromJson(
        encodedPolishCanonEvidence,
      );
      final encodedMechanics = StoryMechanicsEvidence.fromJson(
        encodedStoryMechanicsEvidence,
      );
      final gatePolish = PolishCanonEvidence.fromJson(
        gate['polishCanonEvidence'],
      );
      final gateMechanics = StoryMechanicsEvidence.fromJson(
        gate['storyMechanicsEvidence'],
      );
      return gate['finalProseHash'] == gateFinalProseHash &&
          gatePolish.evidenceHash == encodedPolish.evidenceHash &&
          gateMechanics.evidenceHash == encodedMechanics.evidenceHash &&
          verifyDeterministicGate(
            encodedGate: gate,
            finalProse: finalProse,
            deterministicGateEvidenceHash: deterministicGateEvidenceHash,
          );
    } on Object {
      return false;
    }
  }

  /// Verifies the complete v4 deterministic-gate payload emitted by candidate
  /// finalization. A v3 payload cannot be upgraded from its two nested proofs
  /// because it never bound the production pre-quality boundary or SceneBrief.
  static bool verifyDeterministicGate({
    required Object? encodedGate,
    required String finalProse,
    required String deterministicGateEvidenceHash,
  }) {
    try {
      if (finalProse.trim().isEmpty) return false;
      final gate = _stringObjectMap(encodedGate);
      const requiredKeys = <String>{
        'algorithm',
        'finalProseHash',
        'passed',
        'boundaryReleaseHash',
        'briefRequirementsHash',
        'productionPreQualityEvidence',
        'polishCanonEvidence',
        'storyMechanicsEvidence',
      };
      const optionalKeys = <String>{'narrativeContinuityEvidence'};
      final keys = gate.keys.toSet();
      if (requiredKeys.difference(keys).isNotEmpty ||
          keys.difference(<String>{
            ...requiredKeys,
            ...optionalKeys,
          }).isNotEmpty ||
          gate['algorithm'] != 'deterministic-gate-v4' ||
          gate['passed'] != true ||
          gate['boundaryReleaseHash'] != ProductionPreQualityGate.releaseHash ||
          gate['finalProseHash'] != GenerationLedgerDigest.text(finalProse) ||
          GenerationLedgerDigest.object(gate) !=
              deterministicGateEvidenceHash) {
        return false;
      }

      final preQuality = ProductionPreQualityEvidence.fromJson(
        gate['productionPreQualityEvidence'],
      );
      final polish = PolishCanonEvidence.fromJson(gate['polishCanonEvidence']);
      final mechanics = StoryMechanicsEvidence.fromJson(
        gate['storyMechanicsEvidence'],
      );
      if (!preQuality.passed ||
          !preQuality.hardGatesEnabled ||
          preQuality.sourceMode !=
              ProductionPreQualitySourceMode.pipelinePolish ||
          !preQuality.candidateFinalizationEligible ||
          preQuality.boundaryReleaseHash !=
              ProductionPreQualityGate.releaseHash ||
          preQuality.finalProseHash !=
              ProductionPreQualityGate.finalProseHash(finalProse) ||
          preQuality.briefRequirementsHash != gate['briefRequirementsHash'] ||
          preQuality.polishCanonEvidence.evidenceHash != polish.evidenceHash ||
          preQuality.storyMechanicsEvidence.evidenceHash !=
              mechanics.evidenceHash ||
          !polish.passed ||
          polish.verifierReleaseHash != PolishCanonVerifier.releaseHash ||
          polish.finalProseHash != PolishCanonVerifier.proseHash(finalProse) ||
          !mechanics.passed ||
          mechanics.verifierReleaseHash != StoryMechanicsVerifier.releaseHash ||
          mechanics.proseHash != StoryMechanicsVerifier.proseHash(finalProse)) {
        return false;
      }

      final rawNarrative = gate['narrativeContinuityEvidence'];
      if (rawNarrative != null) {
        final narrative = _stringObjectMap(rawNarrative);
        if (narrative.keys.toSet().difference(const <String>{
              'passed',
              'ledgerIgnored',
              'resultingLedger',
            }).isNotEmpty ||
            const <String>{
              'passed',
              'ledgerIgnored',
              'resultingLedger',
            }.difference(narrative.keys.toSet()).isNotEmpty ||
            narrative['passed'] != true ||
            narrative['ledgerIgnored'] is! bool ||
            narrative['resultingLedger'] is! List) {
          return false;
        }
      }
      return true;
    } on Object {
      return false;
    }
  }

  static Map<String, Object?> _stringObjectMap(Object? raw) {
    if (raw is! Map) throw const FormatException('gate must be an object');
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        throw const FormatException('gate keys must be strings');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }
}
