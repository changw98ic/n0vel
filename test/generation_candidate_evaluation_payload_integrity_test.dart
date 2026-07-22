import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_digest.dart';
import 'package:novel_writer/features/story_generation/data/scene_review_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  group('sealed candidate parsed evaluation payload integrity', () {
    test(
      'accepts the exact canonical review, quality, receipt and proof set',
      () {
        final fixture = _fixture();

        expect(() => fixture.validate(), returnsNormally);
      },
    );

    test('rejects review and quality parsed-output substitution', () {
      final fixture = _fixture();
      final review = _decode(fixture.reviewPayloadJson);
      final reviewOutput = Map<String, Object?>.from(
        review['reviewEvaluationOutput']! as Map,
      )..['decision'] = 'rewriteProse';
      review['reviewEvaluationOutput'] = reviewOutput;

      expect(
        () => fixture.validate(
          reviewPayloadJson: GenerationLedgerDigest.canonicalJson(review),
        ),
        throwsFormatException,
      );

      final quality = _decode(fixture.qualityPayloadJson);
      final qualityOutput = Map<String, Object?>.from(
        quality['qualityEvaluationOutput']! as Map,
      )..['overall'] = 12.0;
      quality['qualityEvaluationOutput'] = qualityOutput;

      expect(
        () => fixture.validate(
          qualityPayloadJson: GenerationLedgerDigest.canonicalJson(quality),
        ),
        throwsFormatException,
      );
    });

    test(
      'rejects old schemas, extra fields, and rehashed gate substitution',
      () {
        final fixture = _fixture();
        final oldReview = _decode(fixture.reviewPayloadJson)
          ..['schemaVersion'] = 'candidate-review-payload-v2';
        expect(
          () => fixture.validate(
            reviewPayloadJson: GenerationLedgerDigest.canonicalJson(oldReview),
          ),
          throwsFormatException,
        );

        final extraQuality = _decode(fixture.qualityPayloadJson)
          ..['callerVerified'] = true;
        expect(
          () => fixture.validate(
            qualityPayloadJson: GenerationLedgerDigest.canonicalJson(
              extraQuality,
            ),
          ),
          throwsFormatException,
        );

        final changedGate = _decode(fixture.qualityPayloadJson);
        changedGate['deterministicGate'] = <String, Object?>{
          'algorithm': 'attacker-rehashed-gate',
          'passed': true,
        };
        expect(
          () => fixture.validate(
            qualityPayloadJson: GenerationLedgerDigest.canonicalJson(
              changedGate,
            ),
          ),
          throwsFormatException,
        );
      },
    );
  });
}

final class _EvaluationPayloadFixture {
  const _EvaluationPayloadFixture({
    required this.reviewPayloadJson,
    required this.qualityPayloadJson,
    required this.finalProseHash,
    required this.gateHash,
    required this.councilHash,
    required this.qualityHash,
    required this.reviewDigest,
    required this.qualityDigest,
  });

  final String reviewPayloadJson;
  final String qualityPayloadJson;
  final String finalProseHash;
  final String gateHash;
  final String councilHash;
  final String qualityHash;
  final String reviewDigest;
  final String qualityDigest;

  void validate({String? reviewPayloadJson, String? qualityPayloadJson}) {
    GenerationCandidateEvaluationPayloadIntegrity.validateSealed(
      reviewPayloadJson: reviewPayloadJson ?? this.reviewPayloadJson,
      qualityPayloadJson: qualityPayloadJson ?? this.qualityPayloadJson,
      finalProseHash: finalProseHash,
      deterministicGateEvidenceHash: gateHash,
      finalCouncilEvidenceHash: councilHash,
      qualityEvidenceHash: qualityHash,
      receiptReviewParsedOutputDigest: reviewDigest,
      receiptQualityParsedOutputDigest: qualityDigest,
    );
  }
}

_EvaluationPayloadFixture _fixture() {
  const pass = SceneReviewPassResult(
    status: SceneReviewStatus.pass,
    reason: '通过。',
    rawText: 'PASS',
  );
  const review = SceneReviewResult(
    judge: pass,
    consistency: pass,
    decision: SceneReviewDecision.pass,
  );
  const quality = SceneQualityScore(
    overall: 96,
    prose: 96,
    coherence: 96,
    character: 96,
    completeness: 96,
    style: 96,
    imagery: 96,
    rhythm: 96,
    faithfulness: 96,
    summary: '通过。',
  );
  const finalProse = '雨水落在账页上，柳溪核对了最后一枚封口。';
  final finalProseHash = GenerationLedgerDigest.text(finalProse);
  final reviewOutput = canonicalSceneReviewEvaluationOutput(review);
  final qualityOutput = quality.toJson();
  final reviewDigest = storyGenerationParsedOutputDigest(reviewOutput);
  final qualityDigest = storyGenerationParsedOutputDigest(qualityOutput);
  final gate = <String, Object?>{
    'algorithm': 'deterministic-gate-v4',
    'finalProseHash': finalProseHash,
    'passed': true,
  };
  const reviewAttempts = <Object?>[];
  final reviewPayloadJson =
      GenerationLedgerDigest.canonicalJson(<String, Object?>{
        'schemaVersion':
            GenerationCandidateEvaluationPayloadIntegrity.reviewSchemaVersion,
        'reviewEvaluationOutput': reviewOutput,
        'reviewEvaluationOutputDigest': reviewDigest,
        'feedback': review.feedback,
        'reviewAttempts': reviewAttempts,
      });
  final qualityPayloadJson =
      GenerationLedgerDigest.canonicalJson(<String, Object?>{
        'schemaVersion':
            GenerationCandidateEvaluationPayloadIntegrity.qualitySchemaVersion,
        'qualityEvaluationOutput': qualityOutput,
        'qualityEvaluationOutputDigest': qualityDigest,
        'deterministicGate': gate,
      });
  return _EvaluationPayloadFixture(
    reviewPayloadJson: reviewPayloadJson,
    qualityPayloadJson: qualityPayloadJson,
    finalProseHash: finalProseHash,
    gateHash: GenerationLedgerDigest.object(gate),
    councilHash: GenerationLedgerDigest.object(<String, Object?>{
      'finalProseHash': finalProseHash,
      'decision': review.decision.name,
      'feedback': review.feedback,
      'reviewAttempts': reviewAttempts,
    }),
    qualityHash: GenerationLedgerDigest.object(<String, Object?>{
      'finalProseHash': finalProseHash,
      'score': qualityOutput,
    }),
    reviewDigest: reviewDigest,
    qualityDigest: qualityDigest,
  );
}

Map<String, Object?> _decode(String source) =>
    Map<String, Object?>.from(jsonDecode(source) as Map);
