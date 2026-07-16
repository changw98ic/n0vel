import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';

void main() {
  group('PromptRelease', () {
    test('freezes schema snapshots and verifies its immutable identity', () {
      final variables = <String, Object?>{
        'required': <Object?>['scene'],
      };
      final release = _release(variablesSchema: variables);
      (variables['required']! as List<Object?>).add('attacker');

      expect(release.hasValidContentHash, isTrue);
      expect(release.variablesSchemaSnapshot, {
        'required': ['scene'],
      });
      expect(
        () =>
            (release.variablesSchemaSnapshot!
                    as Map<String, Object?>)['extra'] =
                true,
        throwsUnsupportedError,
      );
    });

    test('rejects a snapshot paired with a stale content hash', () {
      final original = _release();
      expect(
        () => _release(
          systemTemplate: 'tampered system prompt',
          expectedContentHash: original.contentHash,
        ),
        throwsStateError,
      );
    });

    test('NFC-equivalent prompt sources have the same ref', () {
      final composed = _release(userTemplate: 'Résumé');
      final decomposed = _release(userTemplate: 'Re\u0301sume\u0301');

      expect(composed.contentHash, decomposed.contentHash);
      expect(composed.ref, decomposed.ref);
    });
  });

  group('GenerationBundle', () {
    test('identity is independent of release declaration order', () {
      final release = _release().ref;
      final first = GenerationBundle(
        bundleId: 'story-v1',
        releases: [
          GenerationBundleBinding(
            stageId: 'review',
            callSiteId: 'format-repair',
            variantId: 'zh',
            promptReleaseRef: release,
          ),
          GenerationBundleBinding(
            stageId: 'review',
            callSiteId: 'judge',
            variantId: 'zh',
            promptReleaseRef: release,
          ),
        ],
      );
      final second = GenerationBundle(
        bundleId: 'story-v1',
        releases: first.releases.reversed,
      );

      expect(first.bundleHash, second.bundleHash);
      expect(() => first.releases.clear(), throwsUnsupportedError);
    });

    test('rejects duplicate stage/call-site/variant identities', () {
      final release = _release().ref;
      GenerationBundleBinding binding() => GenerationBundleBinding(
        stageId: 'review',
        callSiteId: 'judge',
        variantId: 'zh',
        promptReleaseRef: release,
      );

      expect(
        () => GenerationBundle(
          bundleId: 'story-v1',
          releases: [binding(), binding()],
        ),
        throwsArgumentError,
      );
    });

    test('detects a tampered frozen bundle hash', () {
      final release = _release().ref;
      final original = GenerationBundle(
        bundleId: 'story-v1',
        releases: [
          GenerationBundleBinding(
            stageId: 'editorial',
            callSiteId: 'draft',
            variantId: 'zh',
            promptReleaseRef: release,
          ),
        ],
      );

      expect(
        () => GenerationBundle(
          bundleId: 'tampered',
          releases: original.releases,
          expectedBundleHash: original.bundleHash,
        ),
        throwsStateError,
      );
    });
  });

  test('EvaluationBundle freezes and hashes evaluator identity', () {
    final judge = _release(templateId: 'judge').ref;
    final first = EvaluationBundle(
      evaluatorBundleId: 'eval-v1',
      deterministicVerifierReleases: [_hashA, _hashB],
      judgePromptReleases: [judge],
      judgeModelRoutes: ['glm-judge', 'local-deterministic'],
      rubricReleaseHash: _hashC,
      aggregatorReleaseHash: _hashD,
      failureTaxonomyHash: _hashE,
      blindingPolicyVersion: 'blind-v1',
    );
    final reordered = EvaluationBundle(
      evaluatorBundleId: 'eval-v1',
      deterministicVerifierReleases: [_hashB, _hashA],
      judgePromptReleases: [judge],
      judgeModelRoutes: ['local-deterministic', 'glm-judge'],
      rubricReleaseHash: _hashC,
      aggregatorReleaseHash: _hashD,
      failureTaxonomyHash: _hashE,
      blindingPolicyVersion: 'blind-v1',
    );

    expect(first.evaluatorBundleHash, reordered.evaluatorBundleHash);
    expect(
      () => first.deterministicVerifierReleases.add(_hashC),
      throwsUnsupportedError,
    );
    expect(
      () => EvaluationBundle(
        evaluatorBundleId: 'eval-v1',
        deterministicVerifierReleases: [_hashA, _hashA],
        judgePromptReleases: [judge],
        judgeModelRoutes: ['glm-judge'],
        rubricReleaseHash: _hashC,
        aggregatorReleaseHash: _hashD,
        failureTaxonomyHash: _hashE,
        blindingPolicyVersion: 'blind-v1',
      ),
      throwsArgumentError,
    );
  });
}

PromptRelease _release({
  String templateId = 'scene-editorial',
  String systemTemplate = 'system',
  String userTemplate = 'user',
  Object? variablesSchema = const {'type': 'object'},
  String? expectedContentHash,
}) => PromptRelease(
  templateId: templateId,
  semanticVersion: '1.0.0',
  language: 'zh',
  systemTemplate: systemTemplate,
  userTemplate: userTemplate,
  variablesSchemaSnapshot: variablesSchema,
  outputSchemaSnapshot: const {'type': 'string'},
  rendererRelease: 'renderer-v1',
  parserRelease: 'parser-v1',
  repairPolicySnapshot: const {'maxAttempts': 1},
  owner: 'story-generation',
  changeNote: 'initial',
  createdAt: DateTime.utc(2026),
  expectedContentHash: expectedContentHash,
);

const _hashA =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _hashC =
    'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _hashD =
    'sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _hashE =
    'sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
