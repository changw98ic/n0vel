import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_candidate_identity.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_digest.dart';
import 'package:novel_writer/features/story_generation/data/scene_review_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';

import 'test_support/formal_evaluation_provenance_fixture.dart';

void main() {
  test(
    'real sealed runner issues final-evaluation manifest and finalizes exact output',
    () async {
      final fixture = await prepareRealSealedRunnerFixture();
      addTearDown(fixture.close);

      final receipt = fixture.receipt;
      final manifest = receipt.finalEvaluationManifest;
      expect(fixture.providerCallCount, 14);
      expect(fixture.output.prose.text, sealedRunnerFixtureFinalProse);
      expect(fixture.output.review.decision.name, 'pass');
      expect(fixture.output.qualityScore?.overall, 98);
      expect(manifest, isNotNull);
      expect(
        manifest!['schemaVersion'],
        'pipeline-final-evaluation-manifest-v1',
      );
      final orderedCalls = List<Map<String, Object?>>.unmodifiable(
        (manifest['orderedCalls']! as List).map(
          (call) => Map<String, Object?>.from(call as Map),
        ),
      );
      expect(orderedCalls.map((call) => call['callSiteId']), <String>[
        'judge',
        'consistency',
        'reader-flow',
        'lexicon',
        'quality-scorer',
      ]);
      expect(
        manifest['reviewParsedOutputDigest'],
        storyGenerationParsedOutputDigest(
          canonicalSceneReviewEvaluationOutput(fixture.output.review),
        ),
      );
      expect(
        manifest['qualityParsedOutputDigest'],
        storyGenerationParsedOutputDigest(
          fixture.output.qualityScore!.toJson(),
        ),
      );

      final candidate = fixture.finalizer.finalize(
        runId: fixture.runId,
        output: fixture.output,
        capture: fixture.capture,
        nowMs: 2000,
        generationEvidenceReceipt: receipt,
      );
      expect(
        candidate.generationEvidenceMode,
        GenerationCandidateIdentity.sealedNoRedrawMode,
      );
      expect(candidate.generationEvidenceReceiptHash, receipt.receiptHash);
      expect(
        candidate.finalProseHash,
        GenerationLedgerDigest.text(sealedRunnerFixtureFinalProse),
      );
      expect(
        fixture.ledger.db.select(
          'SELECT * FROM story_generation_candidate_proofs WHERE run_id = ?',
          <Object?>[fixture.runId],
        ),
        hasLength(1),
      );
    },
  );
}
