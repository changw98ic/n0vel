import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_renderer.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';

void main() {
  test(
    'production story calls cannot use the legacy unversioned retry helper',
    () {
      final offenders = <String>[];
      for (final entity in Directory(
        'lib/features/story_generation/data',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('story_generation_pass_retry.dart')) continue;
        if (entity.readAsStringSync().contains(
          'requestStoryGenerationPassWithRetry(',
        )) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty);
    },
  );

  test('direct story completion calls carry an immutable prompt release', () {
    final offenders = <String>[];
    for (final entity in Directory(
      'lib/features/story_generation/data',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(
        r'\.requestAiCompletion\(',
      ).allMatches(source)) {
        final end = (match.start + 1600).clamp(0, source.length);
        final invocation = source.substring(match.start, end);
        if (!invocation.contains('promptReleaseRef:') ||
            !invocation.contains('promptInvocationEvidence:')) {
          offenders.add('${entity.path}:${match.start}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test(
    'formal story calls materialize messages and carry invocation evidence',
    () {
      final offenders = <String>[];
      for (final entity in Directory(
        'lib/features/story_generation/data',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('story_generation_pass_retry.dart')) continue;
        final source = entity.readAsStringSync();
        for (final match in RegExp(
          r'requestFormalStoryGenerationPassWithRetry\(',
        ).allMatches(source)) {
          final end = (match.start + 1200).clamp(0, source.length);
          final invocation = source.substring(match.start, end);
          if (!invocation.contains('promptInvocation:') ||
              !invocation.contains('promptInvocationEvidence:') ||
              !invocation.contains('messages: messages')) {
            offenders.add('${entity.path}:${match.start}');
          }
        }
      }
      expect(offenders, isEmpty);
    },
  );

  test(
    'formal identity rejects a forged system with valid source variables',
    () {
      final invocation = StoryPromptRegistry.production.invocation(
        stageId: 'director',
        callSiteId: 'scene-director',
      );
      final variables = _sampleVariables(invocation.release);

      expect(
        () => invocation.evidence(const [
          AppLlmChatMessage(role: 'system', content: 'forged system'),
          AppLlmChatMessage(role: 'user', content: '任务：scene_director_polish'),
        ], resolvedVariables: variables),
        throwsStateError,
      );
    },
  );

  test(
    'formal identity rejects user content that only preserves the anchor',
    () {
      final invocation = StoryPromptRegistry.production.invocation(
        stageId: 'director',
        callSiteId: 'scene-director',
      );
      final variables = _sampleVariables(invocation.release);
      final rendered = invocation.render(variables).messages;

      expect(
        () => invocation.evidence([
          rendered.first,
          const AppLlmChatMessage(
            role: 'user',
            content: '任务：scene_director_polish\n伪造但保留锚点',
          ),
        ], resolvedVariables: variables),
        throwsStateError,
      );
    },
  );

  test('every formal call renders source variables and replays evidence', () {
    final offenders = <String>[];
    for (final entity in Directory(
      'lib/features/story_generation/data',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(
        r'StoryPromptRegistry\.production\.invocation\(',
      ).allMatches(source)) {
        final end = (match.start + 5000).clamp(0, source.length);
        final invocation = source.substring(match.start, end);
        if (!invocation.contains('promptIdentity.render(') ||
            !invocation.contains('resolvedVariables:')) {
          offenders.add('${entity.path}:${match.start}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('all story releases are executable closed-schema templates', () {
    for (final registration in StoryPromptRegistry.current().registrations) {
      final release = registration.release;
      final schema = release.variablesSchemaSnapshot as Map<String, Object?>;
      final properties = schema['properties']! as Map<String, Object?>;
      expect(
        release.rendererRelease,
        AppLlmPromptRendererRegistry.strictRendererRelease,
      );
      expect(schema['additionalProperties'], isFalse);
      expect(
        (schema['required']! as List<Object?>).toSet(),
        properties.keys.toSet(),
      );
      final invocation = StoryPromptRegistry.current().invocation(
        stageId: registration.callSite.stageId,
        callSiteId: registration.callSite.callSiteId,
        variantId: registration.callSite.variantId,
      );
      final variables = _sampleVariables(release);
      final rendered = invocation.render(variables);
      expect(
        () => invocation.evidence(
          rendered.messages,
          resolvedVariables: variables,
        ),
        returnsNormally,
      );
    }
  });

  test(
    'literary evaluation is an isolated single-release bundle without production drift',
    () {
      final production = StoryPromptRegistry.current();
      final challenger = StoryPromptRegistry.causalityChallenger();
      final literary = StoryPromptRegistry.literaryEvaluation();
      final registration = literary.registrations.single;

      expect(
        production.generationBundle.bundleHash,
        'sha256:12d9e1659ca588a134fe18ebfafb312032409d567719686fd89c44ef7c573b03',
      );
      expect(
        challenger.generationBundle.bundleHash,
        'sha256:96b2ca057fc23432497a929585079c30cc1c1f20423404e84b1c414a3ef2b9df',
      );
      expect(
        production.registrations.map((item) => item.callSite.key).toSet(),
        <String>{
          for (final callSite in StoryPromptRegistry.requiredCallSites)
            callSite.key,
        },
      );
      expect(
        StoryPromptRegistry.requiredCallSites.map((item) => item.key),
        isNot(contains(StoryPromptRegistry.literaryEvaluationCallSite.key)),
      );
      expect(literary.registrations, hasLength(1));
      expect(literary.generationBundle.releases, hasLength(1));
      expect(
        registration.callSite.key,
        StoryPromptRegistry.literaryEvaluationCallSite.key,
      );
      expect(
        literary.generationBundle.releases.single.callSiteKey,
        StoryPromptRegistry.literaryEvaluationCallSite.key,
      );
      expect(
        () => production.resolve(
          stageId: 'literary-quality',
          callSiteId: 'scene-evaluator',
          variantId: 'zh',
        ),
        throwsStateError,
      );
      expect(
        () => literary.resolve(
          stageId: 'quality-gate',
          callSiteId: 'quality-scorer',
          variantId: 'zh',
        ),
        throwsStateError,
      );
    },
  );

  test('literary evaluation release is strict and mirrors parser JSON shape', () {
    final registry = StoryPromptRegistry.literaryEvaluation();
    final invocation = registry.invocation(
      stageId: 'literary-quality',
      callSiteId: 'scene-evaluator',
    );
    final release = invocation.release;
    expect(
      release.contentHash,
      'sha256:a2e69dc47a58fe1bf3b49ee65266c690ce4cbfbbbb87092e3326dcb52fcb16d1',
    );
    expect(
      registry.generationBundle.bundleHash,
      'sha256:d7ad5efa0012d394bf4d55ff010489189b9e3bbf316bafae366b8a71ff391aed',
    );
    final variablesSchema =
        release.variablesSchemaSnapshot as Map<String, Object?>;
    final variableProperties =
        variablesSchema['properties']! as Map<String, Object?>;
    final outputSchema = release.outputSchemaSnapshot as Map<String, Object?>;
    final outputProperties =
        outputSchema['properties']! as Map<String, Object?>;
    final craft = outputProperties['craft']! as Map<String, Object?>;
    final craftProperties = craft['properties']! as Map<String, Object?>;
    final dimensions = craftProperties['dimensions']! as Map<String, Object?>;
    final styleFit = outputProperties['styleFit']! as Map<String, Object?>;
    final styleFitProperties = styleFit['properties']! as Map<String, Object?>;
    final readerEffect =
        outputProperties['readerEffect']! as Map<String, Object?>;
    final readerEffectProperties =
        readerEffect['properties']! as Map<String, Object?>;
    final effectEstimates =
        readerEffectProperties['effectEstimates']! as Map<String, Object?>;
    final findings = outputProperties['findings']! as Map<String, Object?>;
    final findingSchema = findings['items']! as Map<String, Object?>;
    final findingProperties =
        findingSchema['properties']! as Map<String, Object?>;
    final evidence = findingProperties['evidence']! as Map<String, Object?>;
    final evidenceItem = evidence['items']! as Map<String, Object?>;
    final evidenceProperties =
        evidenceItem['properties']! as Map<String, Object?>;

    expect(
      release.rendererRelease,
      AppLlmPromptRendererRegistry.strictRendererRelease,
    );
    expect(variablesSchema['additionalProperties'], isFalse);
    expect(variablesSchema['required'], <String>['evaluationInputJson']);
    expect(variableProperties.keys, <String>['evaluationInputJson']);
    expect(outputProperties.keys.toSet(), <String>{
      'schemaVersion',
      'semanticHardReview',
      'craft',
      'styleFit',
      'readerEffect',
      'findings',
      'evaluatorSelfConfidence',
    });
    expect(outputSchema['additionalProperties'], isFalse);
    expect(
      (dimensions['properties']! as Map<String, Object?>).keys.toSet(),
      <String>{
        'prosePrecision',
        'paragraphFunction',
        'scenePressure',
        'characterVoice',
        'informationControl',
        'coherence',
        'completenessAndTurn',
      },
    );
    expect(styleFitProperties.keys.toSet(), <String>{
      'decision',
      'axisExplanations',
      'deviationIds',
      'evidenceRefs',
      'deviationAuthorizationRefs',
    });
    expect(
      (effectEstimates['properties']! as Map<String, Object?>).keys.toSet(),
      <String>{
        'tension',
        'clarity',
        'curiosity',
        'emotionalImpact',
        'momentum',
      },
    );
    expect(findingProperties.keys.toSet(), <String>{
      'findingId',
      'findingClass',
      'severity',
      'axis',
      'code',
      'claim',
      'evidence',
      'contractRefs',
      'suggestedAction',
      'effectiveFunction',
      'expectedReturnCondition',
      'deviationAuthorizationRefs',
    });
    expect(evidenceProperties.keys.toSet(), <String>{
      'startOffset',
      'endOffset',
      'localExcerpt',
    });
    expect(evidenceProperties, isNot(contains('occurrenceIndex')));
    expect(release.semanticVersion, '1.2.0');
    expect(release.systemTemplate, contains('UTF-16 code-unit'));
    expect(release.systemTemplate, contains('finding.evidence 必须是 JSON 数组'));
    expect(release.systemTemplate, contains('完成场景契约、没有硬错误、阅读顺畅，只能证明稿件合格'));
    expect(
      release.systemTemplate,
      contains('sceneContract 授权只能对应 plannedDeviation'),
    );
    expect(release.systemTemplate, contains('axisExplanations 必须是 JSON 对象'));
    expect(release.systemTemplate, contains('- 60：存在多个 major 工艺问题'));
    expect(release.systemTemplate, contains('- 95：近终稿'));
    expect(release.systemTemplate, contains('93..94 也属于近终稿带'));
    expect(release.systemTemplate, contains('结尾的关系定性、抽象总结'));

    final variables = <String, Object?>{
      'evaluationInputJson': '{"prose":"示例正文"}',
    };
    final rendered = invocation.render(variables);
    expect(
      () =>
          invocation.evidence(rendered.messages, resolvedVariables: variables),
      returnsNormally,
    );
    expect(
      () => invocation.render(<String, Object?>{
        ...variables,
        'unexpected': 'rejected',
      }),
      throwsFormatException,
    );
  });

  test('structured story releases freeze dual-mode parser behavior', () {
    final registry = StoryPromptRegistry.current();
    final expectations =
        <
          ({String stageId, String callSiteId}),
          ({
            String parserRelease,
            List<String> exactShape,
            String compatibility,
          })
        >{
          (stageId: 'roleplay', callSiteId: 'role-turn'): (
            parserRelease:
                'scene-role-turn-parser-v2-formal-exact-nonformal-compatible',
            exactShape: const <String>['意图', '可见动作', '对白', '内心', '正文片段'],
            compatibility: 'legacy-role-turn-normalize-and-synthesize-v1',
          ),
          (stageId: 'roleplay', callSiteId: 'arbiter'): (
            parserRelease:
                'scene-roleplay-arbiter-parser-v2-formal-exact-nonformal-compatible',
            exactShape: const <String>['事实', '状态', '压力', '收束'],
            compatibility: 'legacy-arbiter-parse-and-fallback-state-v1',
          ),
          (stageId: 'stage-narration', callSiteId: 'stage-narrator'): (
            parserRelease:
                'scene-stage-narration-parser-v2-formal-exact-nonformal-compatible',
            exactShape: const <String>['舞台事实', '环境氛围', '可见证据', '边界'],
            compatibility: 'legacy-stage-text-normalize-or-null-v1',
          ),
        };

    for (final entry in expectations.entries) {
      final release = registry.resolve(
        stageId: entry.key.stageId,
        callSiteId: entry.key.callSiteId,
        variantId: 'zh',
      );
      final policy = release.repairPolicySnapshot as Map<String, Object?>;
      final formal = policy['formal']! as Map<String, Object?>;
      final compatibility =
          policy['nonFormalCompatibility']! as Map<String, Object?>;

      expect(release.semanticVersion, '2.1.0-exact-structured-output');
      expect(release.parserRelease, entry.value.parserRelease);
      expect(formal['maxOutputRetries'], 2);
      expect(formal['localRepair'], isFalse);
      expect(formal['exactShape'], entry.value.exactShape);
      expect(compatibility['policy'], entry.value.compatibility);
    }
  });

  test(
    'template mutation cannot validate a request rendered by the old release',
    () {
      final production = StoryPromptRegistry.current();
      final original = production.registrations.first;
      final release = original.release;
      final variables = _sampleVariables(release);
      final oldMessages = production
          .invocation(
            stageId: original.callSite.stageId,
            callSiteId: original.callSite.callSiteId,
            variantId: original.callSite.variantId,
          )
          .render(variables)
          .messages;
      final mutated = PromptRelease(
        templateId: release.templateId,
        semanticVersion: 'mutation-test',
        language: release.language,
        systemTemplate: release.systemTemplate,
        userTemplate: '${release.userTemplate}\nMUTATED',
        variablesSchemaSnapshot: release.variablesSchemaSnapshot,
        outputSchemaSnapshot: release.outputSchemaSnapshot,
        rendererRelease: release.rendererRelease,
        parserRelease: release.parserRelease,
        repairPolicySnapshot: release.repairPolicySnapshot,
        owner: release.owner,
        changeNote: 'adversarial mutation',
        createdAt: DateTime.utc(2026, 7, 13),
      );
      final variant = production.replacing(
        StoryPromptRegistration(callSite: original.callSite, release: mutated),
      );
      final invocation = variant.invocation(
        stageId: original.callSite.stageId,
        callSiteId: original.callSite.callSiteId,
        variantId: original.callSite.variantId,
      );

      expect(
        () => invocation.evidence(oldMessages, resolvedVariables: variables),
        throwsStateError,
      );
    },
  );

  test(
    'registry replacement changes behavior identity only inside its zone',
    () async {
      final production = StoryPromptRegistry.production;
      final original = production.registrations.first;
      final release = original.release;
      final replacement = StoryPromptRegistration(
        callSite: original.callSite,
        release: PromptRelease(
          templateId: release.templateId,
          semanticVersion: '99.0.0-test',
          language: release.language,
          systemTemplate: '${release.systemTemplate}\nTEST VARIANT',
          userTemplate: release.userTemplate,
          variablesSchemaSnapshot: release.variablesSchemaSnapshot,
          outputSchemaSnapshot: release.outputSchemaSnapshot,
          rendererRelease: release.rendererRelease,
          parserRelease: release.parserRelease,
          repairPolicySnapshot: release.repairPolicySnapshot,
          owner: release.owner,
          changeNote: 'test variant',
          createdAt: DateTime.utc(2026, 7, 12),
        ),
      );
      final variant = production.replacing(replacement);

      expect(
        variant.generationBundle.bundleHash,
        isNot(production.generationBundle.bundleHash),
      );
      await variant.runAsync(() async {
        expect(StoryPromptRegistry.production, same(variant));
        expect(
          StoryPromptRegistry.production
              .resolve(
                stageId: replacement.callSite.stageId,
                callSiteId: replacement.callSite.callSiteId,
                variantId: replacement.callSite.variantId,
              )
              .systemTemplate,
          endsWith('TEST VARIANT'),
        );
      });
      expect(StoryPromptRegistry.production, same(production));
    },
  );

  test('causality challenger changes the actual editorial system request', () {
    final champion = StoryPromptRegistry.current();
    final challenger = StoryPromptRegistry.causalityChallenger();
    final championPrompt = champion.resolve(
      stageId: 'editorial',
      callSiteId: 'scene-editorial-generator',
      variantId: 'zh',
    );
    final challengerPrompt = challenger.resolve(
      stageId: 'editorial',
      callSiteId: 'scene-editorial-generator',
      variantId: 'zh',
    );

    expect(
      challenger.generationBundle.bundleHash,
      isNot(champion.generationBundle.bundleHash),
    );
    expect(
      challenger.generationBundle.bundleId,
      isNot(champion.generationBundle.bundleId),
    );
    expect(
      challengerPrompt.systemTemplate,
      isNot(championPrompt.systemTemplate),
    );
    expect(challengerPrompt.systemTemplate, contains('specific trigger'));
    expect(
      champion.generationBundle.bundleHash,
      'sha256:12d9e1659ca588a134fe18ebfafb312032409d567719686fd89c44ef7c573b03',
    );
    expect(
      challenger.generationBundle.bundleHash,
      'sha256:96b2ca057fc23432497a929585079c30cc1c1f20423404e84b1c414a3ef2b9df',
    );
    expect(
      challengerPrompt.contentHash,
      'sha256:4d015ce94cd3f01bc76d6b9d52017f26bbadcc4b2f353eb65e17aad6228a9abc',
    );
  });

  test(
    'covers every required production call-site with an independent release',
    () {
      final registry = StoryPromptRegistry.current();
      final requiredKeys = {
        for (final callSite in StoryPromptRegistry.requiredCallSites)
          callSite.key,
      };
      final actualKeys = {
        for (final registration in registry.registrations)
          registration.callSite.key,
      };

      expect(actualKeys, requiredKeys);
      expect(
        registry.registrations,
        hasLength(StoryPromptRegistry.requiredCallSites.length),
      );
      expect(
        registry.registrations.map((item) => item.release.contentHash).toSet(),
        hasLength(StoryPromptRegistry.requiredCallSites.length),
      );
      expect(
        registry.generationBundle.releases,
        hasLength(StoryPromptRegistry.requiredCallSites.length),
      );
      expect(
        registry.generationBundle.releases
            .map((item) => item.callSiteKey)
            .toSet(),
        requiredKeys,
      );
    },
  );

  test('contains review judge, consistency, and format repair separately', () {
    final registry = StoryPromptRegistry.current();
    final refs = [
      registry.resolve(stageId: 'review', callSiteId: 'judge', variantId: 'zh'),
      registry.resolve(
        stageId: 'review',
        callSiteId: 'consistency',
        variantId: 'zh',
      ),
      registry.resolve(
        stageId: 'review',
        callSiteId: 'format-repair-judge',
        variantId: 'zh',
      ),
    ];

    expect(refs.map((release) => release.templateId).toSet(), hasLength(3));
    expect(refs.map((release) => release.contentHash).toSet(), hasLength(3));
  });

  test('role and editorial implementations have independent releases', () {
    final registry = StoryPromptRegistry.current();
    final releases = [
      registry.resolve(
        stageId: 'roleplay',
        callSiteId: 'role-agent-controller',
        variantId: 'zh',
      ),
      registry.resolve(
        stageId: 'roleplay',
        callSiteId: 'role-turn',
        variantId: 'zh',
      ),
      registry.resolve(
        stageId: 'editorial',
        callSiteId: 'scene-editor',
        variantId: 'zh',
      ),
      registry.resolve(
        stageId: 'editorial',
        callSiteId: 'scene-editorial-generator',
        variantId: 'zh',
      ),
    ];
    expect(
      releases.map((release) => release.contentHash).toSet(),
      hasLength(4),
    );
  });

  test('missing call-site coverage fails closed', () {
    final incomplete = StoryPromptRegistry.currentRegistrations.sublist(1);

    expect(
      () => StoryPromptRegistry.fromRegistrations(incomplete),
      throwsStateError,
    );
  });

  test('duplicate call-site and unknown lookup fail closed', () {
    final registrations = StoryPromptRegistry.currentRegistrations;
    expect(
      () => StoryPromptRegistry.fromRegistrations([
        ...registrations,
        registrations.first,
      ]),
      throwsStateError,
    );
    expect(
      () => StoryPromptRegistry.current().resolve(
        stageId: 'review',
        callSiteId: 'unknown',
        variantId: 'zh',
      ),
      throwsStateError,
    );
  });
}

Map<String, Object?> _sampleVariables(PromptRelease release) {
  final schema = release.variablesSchemaSnapshot as Map<String, Object?>;
  final properties = schema['properties']! as Map<String, Object?>;
  return <String, Object?>{
    for (final entry in properties.entries)
      entry.key: switch ((entry.value as Map<String, Object?>)['type']) {
        'string' => 'sample-${entry.key}',
        'integer' => 1,
        'number' => 1.5,
        'boolean' => true,
        _ => throw StateError('unsupported story test variable: ${entry.key}'),
      },
  };
}
