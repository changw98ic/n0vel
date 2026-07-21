import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_version.dart';
import 'package:novel_writer/domain/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/scene_literary_quality_evaluator.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/settings_contract.dart';
import 'package:novel_writer/features/story_generation/domain/literary_quality_models.dart';

import 'test_support/literary_quality_test_data.dart';

const _prose =
    '雨水敲着蓝色柜机。柳溪听见追兵转过巷口，仍把钥匙推到底。'
    '警报响起，她没有回头，把底册塞进外套，向沈渡亮了一下空手。'
    '“路给你，位置算我的。”她说完便先冲进雨里。';
const _promptReleaseHash = 'prompt-release-literary-evaluator-1';
const _providerModel = 'evaluator-model-1';

void main() {
  const parser = SceneLiteraryQualityOutputParser();

  group('strict layered parser', () {
    test(
      'prompt projection keeps authority local and supplies exact spans',
      () {
        final input = buildLiteraryQualityEvaluationInput(
          prose: _prose,
          promptReleaseHash: _promptReleaseHash,
        );
        final prompt = input.promptInputJson;
        final segments = (prompt['evidenceSegments']! as List<Object?>)
            .cast<Map<String, Object?>>();

        expect(prompt, isNot(contains('calibration')));
        expect(prompt, isNot(contains('ledgerSnapshotHash')));
        expect(prompt, isNot(contains('deterministicGate')));
        expect(segments, isNotEmpty);
        for (final segment in segments) {
          final start = segment['startOffset']! as int;
          final end = segment['endOffset']! as int;
          expect(_prose.substring(start, end), segment['localExcerpt']);
        }
      },
    );

    test(
      'builds canonical result and ignores model self-confidence for gates',
      () {
        final input = buildLiteraryQualityEvaluationInput(
          prose: _prose,
          promptReleaseHash: _promptReleaseHash,
        );
        final result = parser.parse(
          rawOutput: jsonEncode(
            cleanLiteraryQualityModelOutput(evaluatorSelfConfidence: 0.99),
          ),
          input: input,
          promptReleaseHash: _promptReleaseHash,
          providerModel: _providerModel,
        );

        expect(result.evaluatorSelfConfidence, 0.99);
        expect(result.calibratedConfidence, 0.80);
        expect(result.craft.craftOverall, closeTo(95.70, 0.001));
        expect(result.craft.criticalCraftMinimum, 95);
        expect(result.semanticHardReview.passed, isTrue);
        expect(result.styleFit.decision, StyleFitDecision.aligned);
        expect(result.decision.status, SceneCandidateStatus.highCandidate);
        expect(result.decision.reasonCode, 'publicationReviewPending');
        expect(result.evidenceHash, result.canonicalHash);
      },
    );

    test('derives evidence digest from an exact UTF-16 prose span', () {
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );
      const excerpt = '警报响起，她没有回头';
      final start = _prose.indexOf(excerpt);
      final output = cleanLiteraryQualityModelOutput();
      final dimensions =
          (output['craft']! as Map<String, Object?>)['dimensions']!
              as Map<String, Object?>;
      dimensions['scenePressure'] = 70;
      output['findings'] = [
        _finding(
          findingId: 'finding-pressure',
          findingClass: 'craftWeakness',
          severity: 'major',
          axis: 'scenePressure',
          suggestedAction: 'targetedRepair',
          evidence: [
            {
              'startOffset': start,
              'endOffset': start + excerpt.length,
              'localExcerpt': excerpt,
            },
          ],
        ),
      ];
      final result = parser.parse(
        rawOutput: jsonEncode(output),
        input: input,
        promptReleaseHash: _promptReleaseHash,
        providerModel: _providerModel,
      );

      final evidence = result.findings.single.evidence.single;
      expect(evidence.startOffset, start);
      expect(evidence.endOffset, start + excerpt.length);
      expect(evidence.localExcerpt, excerpt);
      expect(evidence.excerptDigest, startsWith('sha256:'));
      expect(result.findings.single.calibratedConfidence, 0.80);
      expect(result.decision.status, SceneCandidateStatus.repairRequired);
    });

    test('rejects unknown, missing, duplicate, and derived score fields', () {
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );
      final unknown = cleanLiteraryQualityModelOutput()..['surprise'] = true;
      final missing = cleanLiteraryQualityModelOutput()..remove('styleFit');
      final derived = cleanLiteraryQualityModelOutput();
      (derived['craft']! as Map<String, Object?>)['craftOverall'] = 100;
      final validRaw = jsonEncode(cleanLiteraryQualityModelOutput());
      final duplicate = validRaw.replaceFirst('{', '{"schemaVersion":1,');

      for (final raw in [
        jsonEncode(unknown),
        jsonEncode(missing),
        jsonEncode(derived),
        duplicate,
      ]) {
        expect(
          () => parser.parse(
            rawOutput: raw,
            input: input,
            promptReleaseHash: _promptReleaseHash,
            providerModel: _providerModel,
          ),
          throwsA(isA<SceneLiteraryQualityEvaluationException>()),
        );
      }
    });

    test('rejects evidence that does not bind the exact prose revision', () {
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );
      final output = cleanLiteraryQualityModelOutput();
      final dimensions =
          (output['craft']! as Map<String, Object?>)['dimensions']!
              as Map<String, Object?>;
      dimensions['coherence'] = 70;
      output['findings'] = [
        _finding(
          findingId: 'finding-bad-span',
          findingClass: 'craftWeakness',
          severity: 'major',
          axis: 'coherence',
          suggestedAction: 'targetedRepair',
          evidence: const [
            {'startOffset': 0, 'endOffset': 4, 'localExcerpt': '并非原文'},
          ],
        ),
      ];

      expect(
        () => parser.parse(
          rawOutput: jsonEncode(output),
          input: input,
          promptReleaseHash: _promptReleaseHash,
          providerModel: _providerModel,
        ),
        throwsA(isA<SceneLiteraryQualityEvaluationException>()),
      );
    });

    test(
      'rejects finding evidence encoded as an object instead of an array',
      () {
        final input = buildLiteraryQualityEvaluationInput(
          prose: _prose,
          promptReleaseHash: _promptReleaseHash,
        );
        final output = cleanLiteraryQualityModelOutput();
        final finding = _finding(
          findingId: 'finding-object-evidence',
          findingClass: 'styleChoice',
          severity: 'note',
          axis: 'prose',
          suggestedAction: 'accept',
        );
        finding['evidence'] = const {
          'startOffset': 0,
          'endOffset': 2,
          'localExcerpt': '雨水',
        };
        output['findings'] = [finding];

        expect(
          () => parser.parse(
            rawOutput: jsonEncode(output),
            input: input,
            promptReleaseHash: _promptReleaseHash,
            providerModel: _providerModel,
          ),
          throwsA(isA<SceneLiteraryQualityEvaluationException>()),
        );
      },
    );

    test('rejects contradictory near-final craft scores', () {
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );
      final weakDimension = cleanLiteraryQualityModelOutput();
      final weakDimensions =
          (weakDimension['craft']! as Map<String, Object?>)['dimensions']!
              as Map<String, Object?>;
      weakDimensions['paragraphFunction'] = 92;

      const excerpt = '她没有回头';
      final start = _prose.indexOf(excerpt);
      final hiddenWeakness = cleanLiteraryQualityModelOutput();
      hiddenWeakness['findings'] = [
        _finding(
          findingId: 'finding-near-final-conflict',
          findingClass: 'craftWeakness',
          severity: 'minor',
          axis: 'informationControl',
          suggestedAction: 'targetedRepair',
          evidence: [
            {
              'startOffset': start,
              'endOffset': start + excerpt.length,
              'localExcerpt': excerpt,
            },
          ],
        ),
      ];

      for (final output in [weakDimension, hiddenWeakness]) {
        expect(
          () => parser.parse(
            rawOutput: jsonEncode(output),
            input: input,
            promptReleaseHash: _promptReleaseHash,
            providerModel: _providerModel,
          ),
          throwsA(isA<SceneLiteraryQualityEvaluationException>()),
        );
      }
    });

    test('rejects unknown contract refs and invented deviation authority', () {
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );
      const excerpt = '钥匙推到底';
      final start = _prose.indexOf(excerpt);
      final unknownContract = cleanLiteraryQualityModelOutput();
      unknownContract['findings'] = [
        _finding(
          findingId: 'finding-contract',
          findingClass: 'hardError',
          severity: 'blocker',
          axis: 'corePromise',
          suggestedAction: 'blockAndReplan',
          contractRefs: const ['invented-contract'],
        ),
      ];
      unknownContract['semanticHardReview'] = {
        'passed': false,
        'hardFindingIds': ['finding-contract'],
      };

      final inventedAuthority = cleanLiteraryQualityModelOutput();
      inventedAuthority['findings'] = [
        _finding(
          findingId: 'finding-deviation',
          findingClass: 'effectiveDeviation',
          severity: 'note',
          axis: 'rhythm',
          suggestedAction: 'acceptWithNote',
          evidence: [
            {
              'startOffset': start,
              'endOffset': start + excerpt.length,
              'localExcerpt': excerpt,
            },
          ],
          effectiveFunction: '压缩压力',
          expectedReturnCondition: '离开巷口后恢复',
          deviationAuthorizationRefs: const [
            {
              'authorizedBy': 'authorOverride',
              'referenceId': 'invented-override',
            },
          ],
        ),
      ];
      inventedAuthority['styleFit'] = {
        'decision': 'approvedDeviation',
        'axisExplanations': {'rhythm': '经作者批准'},
        'deviationIds': ['deviation-pressure-burst'],
        'evidenceRefs': ['finding-deviation'],
        'deviationAuthorizationRefs': const [
          {
            'authorizedBy': 'authorOverride',
            'referenceId': 'invented-override',
          },
        ],
      };

      final findingIdAsDeviationId = cleanLiteraryQualityModelOutput();
      findingIdAsDeviationId['findings'] = [
        _finding(
          findingId: 'finding-deviation',
          findingClass: 'effectiveDeviation',
          severity: 'note',
          axis: 'rhythm',
          suggestedAction: 'acceptWithNote',
          evidence: [
            {
              'startOffset': start,
              'endOffset': start + excerpt.length,
              'localExcerpt': excerpt,
            },
          ],
          effectiveFunction: '压缩压力',
          expectedReturnCondition: '离开巷口后恢复',
          deviationAuthorizationRefs: const [
            {
              'authorizedBy': 'sceneContract',
              'referenceId': 'deviation-pressure-burst',
            },
          ],
        ),
      ];
      findingIdAsDeviationId['styleFit'] = {
        'decision': 'plannedDeviation',
        'axisExplanations': {'rhythm': '按场景契约压缩节奏'},
        'deviationIds': ['finding-deviation'],
        'evidenceRefs': ['finding-deviation'],
        'deviationAuthorizationRefs': const [
          {
            'authorizedBy': 'sceneContract',
            'referenceId': 'deviation-pressure-burst',
          },
        ],
      };

      for (final output in [
        unknownContract,
        inventedAuthority,
        findingIdAsDeviationId,
      ]) {
        expect(
          () => parser.parse(
            rawOutput: jsonEncode(output),
            input: input,
            promptReleaseHash: _promptReleaseHash,
            providerModel: _providerModel,
          ),
          throwsA(isA<SceneLiteraryQualityEvaluationException>()),
        );
      }
    });

    test('rejects semantic hard review contradictions and model drift', () {
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );
      final contradictory = cleanLiteraryQualityModelOutput();
      contradictory['semanticHardReview'] = {
        'passed': false,
        'hardFindingIds': ['missing-hard-finding'],
      };

      expect(
        () => parser.parse(
          rawOutput: jsonEncode(contradictory),
          input: input,
          promptReleaseHash: _promptReleaseHash,
          providerModel: _providerModel,
        ),
        throwsA(isA<SceneLiteraryQualityEvaluationException>()),
      );
      expect(
        () => parser.parse(
          rawOutput: jsonEncode(cleanLiteraryQualityModelOutput()),
          input: input,
          promptReleaseHash: _promptReleaseHash,
          providerModel: 'different-model-release',
        ),
        throwsA(isA<SceneLiteraryQualityEvaluationException>()),
      );
    });

    test('rejects blocker findings without evidence or contract refs', () {
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );
      final output = cleanLiteraryQualityModelOutput();
      output['findings'] = [
        _finding(
          findingId: 'finding-unsupported-blocker',
          findingClass: 'hardError',
          severity: 'blocker',
          axis: 'corePromise',
          suggestedAction: 'blockAndReplan',
        ),
      ];
      output['semanticHardReview'] = {
        'passed': false,
        'hardFindingIds': ['finding-unsupported-blocker'],
      };

      expect(
        () => parser.parse(
          rawOutput: jsonEncode(output),
          input: input,
          promptReleaseHash: _promptReleaseHash,
          providerModel: _providerModel,
        ),
        throwsA(isA<SceneLiteraryQualityEvaluationException>()),
      );
    });

    test('rejects deviation decisions backed by the wrong authority class', () {
      final plannedFromReview = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
        deviationAuthorization: DeviationAuthorization.independentReview,
      );
      final approvedFromSceneContract = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );

      for (final testCase in [
        (
          input: plannedFromReview,
          output: _authorizedDeviationOutput(
            decision: 'plannedDeviation',
            authorizedBy: 'independentReview',
          ),
        ),
        (
          input: approvedFromSceneContract,
          output: _authorizedDeviationOutput(
            decision: 'approvedDeviation',
            authorizedBy: 'sceneContract',
          ),
        ),
      ]) {
        expect(
          () => parser.parse(
            rawOutput: jsonEncode(testCase.output),
            input: testCase.input,
            promptReleaseHash: _promptReleaseHash,
            providerModel: _providerModel,
          ),
          throwsA(isA<SceneLiteraryQualityEvaluationException>()),
        );
      }
    });

    test('accepts an exactly cross-bound planned deviation', () {
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );
      final result = parser.parse(
        rawOutput: jsonEncode(
          _authorizedDeviationOutput(
            decision: 'plannedDeviation',
            authorizedBy: 'sceneContract',
          ),
        ),
        input: input,
        promptReleaseHash: _promptReleaseHash,
        providerModel: _providerModel,
      );

      expect(result.styleFit.decision, StyleFitDecision.plannedDeviation);
      expect(
        result.styleFit.deviationAuthorizationRefs.single.authorizedBy,
        DeviationAuthorization.sceneContract,
      );
    });

    test('rejects unrelated findings smuggled into deviation evidenceRefs', () {
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: _promptReleaseHash,
      );
      final output = _authorizedDeviationOutput(
        decision: 'plannedDeviation',
        authorizedBy: 'sceneContract',
      );
      final findings = output['findings']! as List<Map<String, Object?>>;
      findings.add(
        _finding(
          findingId: 'finding-unrelated-style-choice',
          findingClass: 'styleChoice',
          severity: 'note',
          axis: 'projectVoice',
          suggestedAction: 'accept',
        ),
      );
      final styleFit = output['styleFit']! as Map<String, Object?>;
      styleFit['evidenceRefs'] = [
        'finding-deviation-authority',
        'finding-unrelated-style-choice',
      ];

      expect(
        () => parser.parse(
          rawOutput: jsonEncode(output),
          input: input,
          promptReleaseHash: _promptReleaseHash,
          providerModel: _providerModel,
        ),
        throwsA(isA<SceneLiteraryQualityEvaluationException>()),
      );
    });
  });

  test(
    'evaluator uses its dedicated admitted prompt and bounded output retry',
    () async {
      final registry = StoryPromptRegistry.literaryEvaluation();
      final invocation = registry.invocation(
        stageId: 'literary-quality',
        callSiteId: 'scene-evaluator',
      );
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: invocation.release.contentHash,
        evaluatorModelRelease: _providerModel,
      );
      final settings = _QueueSettingsContract([
        const AppLlmChatResult.success(
          text: '{"schemaVersion":1}',
          providerModel: _providerModel,
        ),
        AppLlmChatResult.success(
          text: jsonEncode(cleanLiteraryQualityModelOutput()),
          providerModel: _providerModel,
        ),
      ]);
      final evaluator = SceneLiteraryQualityEvaluator(
        settingsStore: settings,
        promptRegistry: registry,
      );

      final result = await evaluator.evaluate(input);

      expect(settings.calls, 2);
      expect(settings.lastMaxTokens, literaryQualityEvaluationMaxTokens);
      expect(
        settings.maxTokenHistory,
        everyElement(literaryQualityEvaluationMaxTokens),
      );
      expect(settings.lastPromptReleaseRef, invocation.promptReleaseRef);
      expect(settings.lastBundleHash, invocation.generationBundleHash);
      expect(result.proseHash, input.proseHash);
      expect(result.decision.status, SceneCandidateStatus.highCandidate);
    },
  );

  test(
    'evaluator retry budget is bounded for malformed and timeout results',
    () async {
      final registry = StoryPromptRegistry.literaryEvaluation();
      final invocation = registry.invocation(
        stageId: 'literary-quality',
        callSiteId: 'scene-evaluator',
      );
      final input = buildLiteraryQualityEvaluationInput(
        prose: _prose,
        promptReleaseHash: invocation.release.contentHash,
        evaluatorModelRelease: _providerModel,
      );

      final malformed = _QueueSettingsContract([
        const AppLlmChatResult.success(
          text: '{"schemaVersion":1}',
          providerModel: _providerModel,
        ),
        const AppLlmChatResult.success(
          text: '{"schemaVersion":1}',
          providerModel: _providerModel,
        ),
        AppLlmChatResult.success(
          text: jsonEncode(cleanLiteraryQualityModelOutput()),
          providerModel: _providerModel,
        ),
      ]);
      await expectLater(
        SceneLiteraryQualityEvaluator(
          settingsStore: malformed,
          promptRegistry: registry,
        ).evaluate(input),
        throwsA(isA<SceneLiteraryQualityEvaluationException>()),
      );
      expect(malformed.calls, 2);

      final timedOut = _QueueSettingsContract([
        for (var index = 0; index < 4; index += 1)
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'timeout',
          ),
      ]);
      await expectLater(
        SceneLiteraryQualityEvaluator(
          settingsStore: timedOut,
          promptRegistry: registry,
        ).evaluate(input),
        throwsA(isA<SceneLiteraryQualityEvaluationException>()),
      );
      expect(timedOut.calls, 3);
      expect(
        timedOut.maxTokenHistory,
        everyElement(literaryQualityEvaluationMaxTokens),
      );
    },
  );

  test('WP2 evaluator is not wired into production gate or finalization', () {
    for (final path in const [
      'lib/features/story_generation/data/pipeline_stage_runner_impl.dart',
      'lib/features/story_generation/data/steps/finalization_step.dart',
      'lib/features/story_generation/data/generation_ledger_candidate_finalizer.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('SceneLiteraryQualityEvaluator')));
      expect(source, isNot(contains('scene_literary_quality_evaluator.dart')));
    }
  });
}

Map<String, Object?> _finding({
  required String findingId,
  required String findingClass,
  required String severity,
  required String axis,
  required String suggestedAction,
  List<Map<String, Object?>> evidence = const [],
  List<String> contractRefs = const [],
  String? effectiveFunction,
  String? expectedReturnCondition,
  List<Map<String, Object?>> deviationAuthorizationRefs = const [],
}) => {
  'findingId': findingId,
  'findingClass': findingClass,
  'severity': severity,
  'axis': axis,
  'code': 'test-code',
  'claim': '测试发现必须有具体证据。',
  'evidence': evidence,
  'contractRefs': contractRefs,
  'suggestedAction': suggestedAction,
  'effectiveFunction': effectiveFunction,
  'expectedReturnCondition': expectedReturnCondition,
  'deviationAuthorizationRefs': deviationAuthorizationRefs,
};

Map<String, Object?> _authorizedDeviationOutput({
  required String decision,
  required String authorizedBy,
}) {
  const excerpt = '钥匙推到底';
  final start = _prose.indexOf(excerpt);
  final authorization = {
    'authorizedBy': authorizedBy,
    'referenceId': 'deviation-pressure-burst',
  };
  final output = cleanLiteraryQualityModelOutput();
  output['findings'] = [
    _finding(
      findingId: 'finding-deviation-authority',
      findingClass: 'effectiveDeviation',
      severity: 'note',
      axis: 'rhythm',
      suggestedAction: 'acceptWithNote',
      evidence: [
        {
          'startOffset': start,
          'endOffset': start + excerpt.length,
          'localExcerpt': excerpt,
        },
      ],
      effectiveFunction: '压缩追兵逼近时的叙事时间',
      expectedReturnCondition: '离开柜机巷后恢复常规句长',
      deviationAuthorizationRefs: [authorization],
    ),
  ];
  output['styleFit'] = {
    'decision': decision,
    'axisExplanations': {'rhythm': '按授权短暂压缩节奏'},
    'deviationIds': ['deviation-pressure-burst'],
    'evidenceRefs': ['finding-deviation-authority'],
    'deviationAuthorizationRefs': [authorization],
  };
  return output;
}

final class _QueueSettingsContract implements StoryGenerationSettingsContract {
  _QueueSettingsContract(this._results);

  final List<AppLlmChatResult> _results;
  var calls = 0;
  int? lastMaxTokens;
  final List<int?> maxTokenHistory = [];
  PromptReleaseRef? lastPromptReleaseRef;
  String? lastBundleHash;

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

  @override
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) async {
    calls += 1;
    lastMaxTokens = maxTokens;
    maxTokenHistory.add(maxTokens);
    lastPromptReleaseRef = promptReleaseRef;
    lastBundleHash = generationBundleHash;
    expect(traceName, 'scene_literary_quality_evaluation');
    expect(stageId, 'literary-quality');
    expect(callSiteId, 'scene-evaluator');
    expect(promptInvocationEvidence?.matchesMessages(messages), isTrue);
    return _results.removeAt(0);
  }
}
