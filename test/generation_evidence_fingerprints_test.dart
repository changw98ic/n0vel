import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_fingerprints.dart';

void main() {
  group('Generation evidence fingerprints', () {
    test('generation, evaluation, and artifact hashes are independent', () {
      final generation = _generationFingerprint(
        semanticInput: {'scene': 'A hears the gate open.'},
      );
      final artifact = ArtifactDigest.fromUtf8String(
        'A hears the gate open.\n',
      );
      final evaluation = _evaluationFingerprint(
        artifactDigest: artifact,
        judgeInput: {'artifact': artifact.digest},
      );

      expect(generation.digest, isNot(artifact.digest));
      expect(generation.digest, isNot(evaluation.digest));
      expect(evaluation.digest, isNot(artifact.digest));
      expect(generation.domainTag, 'story-generation-fingerprint-v1');
      expect(evaluation.domainTag, 'story-evaluation-fingerprint-v1');
      expect(artifact.domainTag, 'story-artifact-utf8-bytes-v1');
    });

    test('generation semantic changes alter only generation hash', () {
      final artifact = ArtifactDigest.fromUtf8String('fixed prose');
      final evaluation = _evaluationFingerprint(
        artifactDigest: artifact,
        judgeInput: {'artifact': artifact.digest},
      );
      final generationA = _generationFingerprint(
        semanticInput: {'scene': 'A hears the gate open.'},
      );
      final generationB = _generationFingerprint(
        semanticInput: {'scene': 'A hears the lock click.'},
      );

      expect(generationA.digest, isNot(generationB.digest));
      expect(
        _evaluationFingerprint(
          artifactDigest: artifact,
          judgeInput: {'artifact': artifact.digest},
        ).digest,
        evaluation.digest,
      );
      expect(
        ArtifactDigest.fromUtf8String('fixed prose').digest,
        artifact.digest,
      );
    });

    test('evaluation semantic changes alter only evaluation hash', () {
      final generation = _generationFingerprint(
        semanticInput: {'scene': 'fixed scene'},
      );
      final artifact = ArtifactDigest.fromUtf8String('fixed prose');
      final evaluationA = _evaluationFingerprint(
        artifactDigest: artifact,
        judgeInput: {'rubricFocus': 'rhythm'},
      );
      final evaluationB = _evaluationFingerprint(
        artifactDigest: artifact,
        judgeInput: {'rubricFocus': 'agency'},
      );

      expect(evaluationA.digest, isNot(evaluationB.digest));
      expect(
        _generationFingerprint(semanticInput: {'scene': 'fixed scene'}).digest,
        generation.digest,
      );
      expect(
        ArtifactDigest.fromUtf8String('fixed prose').digest,
        artifact.digest,
      );
    });

    test(
      'evaluation judge binding stores only the artifact and semantic digest',
      () {
        const rawJudgeSentinel = 'RAW-JUDGE-INPUT-MUST-NOT-PERSIST';
        final artifact = ArtifactDigest.fromUtf8String('evaluated prose');
        final rawJudgeInput = <String, Object?>{
          'instruction': rawJudgeSentinel,
          'rubricFocus': <String>['rhythm', 'agency'],
        };
        final evaluation = _evaluationFingerprint(
          artifactDigest: artifact,
          judgeInput: rawJudgeInput,
        );
        final canonical = evaluation.toCanonicalMap();
        final judgeBinding = Map<String, Object?>.from(
          canonical['judgeInput']! as Map,
        );

        expect(
          judgeBinding.keys,
          unorderedEquals(<String>[
            'evaluatedArtifactDigest',
            'semanticInputDigest',
          ]),
        );
        expect(
          judgeBinding['evaluatedArtifactDigest'],
          artifact.toCanonicalMap(),
        );
        expect(
          judgeBinding['semanticInputDigest'],
          AppLlmCanonicalHash.domainHash(
            EvaluationFingerprint.judgeSemanticInputDomainTag,
            AppLlmCanonicalHash.immutableSnapshot(rawJudgeInput),
          ),
        );
        expect(jsonEncode(canonical), isNot(contains(rawJudgeSentinel)));
      },
    );

    test(
      'new generation and evaluation fingerprints use only exact v1 domains',
      () {
        const generationV2 = 'story-generation-fingerprint-v2';
        const evaluationV7 = 'story-evaluation-fingerprint-v7';
        const artifactV12 = 'story-artifact-utf8-bytes-v12';
        final artifact = ArtifactDigest.fromUtf8String('fixed prose');

        expect(
          () => _generationFingerprint(
            semanticInput: {'scene': 'fixed scene'},
            domainTag: generationV2,
          ),
          throwsArgumentError,
        );
        expect(
          () => _evaluationFingerprint(
            artifactDigest: artifact,
            judgeInput: {'rubricFocus': 'rhythm'},
            domainTag: evaluationV7,
          ),
          throwsArgumentError,
        );
        expect(
          () => ArtifactDigest.fromUtf8String(
            'fixed prose',
            domainTag: artifactV12,
          ),
          throwsArgumentError,
        );

        for (final wrongDomain in const [
          EvaluationFingerprint.defaultDomainTag,
          ArtifactDigest.defaultDomainTag,
        ]) {
          expect(
            () => _generationFingerprint(
              semanticInput: {'scene': 'fixed scene'},
              domainTag: wrongDomain,
            ),
            throwsArgumentError,
          );
        }
        for (final wrongDomain in const [
          GenerationFingerprint.defaultDomainTag,
          ArtifactDigest.defaultDomainTag,
        ]) {
          expect(
            () => _evaluationFingerprint(
              artifactDigest: artifact,
              judgeInput: {'rubricFocus': 'rhythm'},
              domainTag: wrongDomain,
            ),
            throwsArgumentError,
          );
        }
        for (final wrongDomain in const [
          GenerationFingerprint.defaultDomainTag,
          EvaluationFingerprint.defaultDomainTag,
        ]) {
          expect(
            () => ArtifactDigest.fromUtf8String(
              'fixed prose',
              domainTag: wrongDomain,
            ),
            throwsArgumentError,
          );
        }
      },
    );

    test(
      'artifact digest binds exact UTF-8 bytes without trim or line folding',
      () {
        final plain = ArtifactDigest.fromUtf8String('寒光');
        final trailingNewline = ArtifactDigest.fromUtf8String('寒光\n');
        final trailingSpace = ArtifactDigest.fromUtf8String('寒光 ');
        final decomposed = ArtifactDigest.fromUtf8String('cafe\u0301');
        final composed = ArtifactDigest.fromUtf8String('café');

        expect(plain.digest, isNot(trailingNewline.digest));
        expect(plain.digest, isNot(trailingSpace.digest));
        expect(decomposed.digest, isNot(composed.digest));
        expect(plain.byteLength, utf8Length('寒光'));
        expect(trailingNewline.byteLength, utf8Length('寒光\n'));
      },
    );

    test('timestamps and paths remain outside semantic fingerprints', () {
      final semantic = {'scene': 'fixed', 'chapter': 1};
      final envelopeA = {
        'createdAt': '2026-07-21T01:00:00Z',
        'artifactPath': '/tmp/a.txt',
      };
      final envelopeB = {
        'createdAt': '2026-07-21T02:00:00Z',
        'artifactPath': '/tmp/b.txt',
      };

      expect(envelopeA, isNot(envelopeB));
      expect(
        _generationFingerprint(semanticInput: semantic).digest,
        _generationFingerprint(semanticInput: semantic).digest,
      );

      final artifact = ArtifactDigest.fromUtf8String('fixed prose');
      expect(
        _evaluationFingerprint(
          artifactDigest: artifact,
          judgeInput: {'rubricFocus': 'rhythm'},
        ).digest,
        _evaluationFingerprint(
          artifactDigest: artifact,
          judgeInput: {'rubricFocus': 'rhythm'},
        ).digest,
      );
    });

    test(
      'validates sha256 digest shape and can recompute canonical hashes',
      () {
        expect(
          () => GenerationFingerprint(
            semanticInput: {'scene': 'x'},
            generationBundleHash: 'not-a-hash',
            modelRoute: 'openai:gpt-test',
            decodingParameters: {'temperature': 0.7},
            armPolicy: 'arm-a',
            retryPolicy: 'no-redraw',
          ),
          throwsArgumentError,
        );

        final generation = _generationFingerprint(
          semanticInput: {'scene': 'A hears the gate open.'},
        );
        final recomputed = AppLlmCanonicalHash.domainHash(
          generation.domainTag,
          generation.toCanonicalMap(),
        );

        expect(recomputed, generation.digest);
      },
    );
  });
}

GenerationFingerprint _generationFingerprint({
  required Object? semanticInput,
  String domainTag = GenerationFingerprint.defaultDomainTag,
}) {
  final bundle = _generationBundle();
  return GenerationFingerprint(
    semanticInput: semanticInput,
    generationBundleHash: bundle.bundleHash,
    modelRoute: 'sha256:${List<String>.filled(64, '1').join()}',
    decodingParameters: {'temperature': 0.7, 'topP': 0.9},
    armPolicy: 'arm-a-current-normalized',
    retryPolicy: 'sha256:${List<String>.filled(64, '2').join()}',
    domainTag: domainTag,
  );
}

EvaluationFingerprint _evaluationFingerprint({
  required ArtifactDigest artifactDigest,
  required Object? judgeInput,
  String domainTag = EvaluationFingerprint.defaultDomainTag,
}) {
  final bundle = _evaluationBundle();
  return EvaluationFingerprint(
    artifactDigest: artifactDigest,
    evaluationBundleHash: bundle.evaluatorBundleHash,
    judgeInput: judgeInput,
    judgeModelRoute: 'sha256:${List<String>.filled(64, '3').join()}',
    rubricHash:
        'sha256:3333333333333333333333333333333333333333333333333333333333333333',
    blindingPolicy: 'blind-arm-labels-v1',
    domainTag: domainTag,
  );
}

GenerationBundle _generationBundle() => GenerationBundle(
  bundleId: 'wp3a-generation',
  releases: [
    GenerationBundleBinding(
      stageId: 'director',
      callSiteId: 'scene-plan',
      variantId: 'v1',
      promptReleaseRef: _promptRef('director'),
    ),
  ],
);

EvaluationBundle _evaluationBundle() => EvaluationBundle(
  evaluatorBundleId: 'wp3a-evaluator',
  deterministicVerifierReleases: ['mechanics-v1'],
  judgePromptReleases: [_promptRef('judge')],
  judgeModelRoutes: ['openai:gpt-judge-test'],
  rubricReleaseHash:
      'sha256:1111111111111111111111111111111111111111111111111111111111111111',
  aggregatorReleaseHash:
      'sha256:2222222222222222222222222222222222222222222222222222222222222222',
  failureTaxonomyHash:
      'sha256:4444444444444444444444444444444444444444444444444444444444444444',
  blindingPolicyVersion: 'blind-arm-labels-v1',
);

PromptReleaseRef _promptRef(String id) => PromptReleaseRef(
  templateId: id,
  semanticVersion: '1.0.0',
  language: 'zh',
  contentHash:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
);

int utf8Length(String value) => utf8.encode(value).length;
