import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_fingerprints.dart';
import 'package:novel_writer/features/story_generation/data/scene_quality_scorer.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

import 'test_support/formal_evaluation_provenance_fixture.dart';

void main() {
  // ── SceneQualityScore model ─────────────────────────────────────────

  group('SceneQualityScore', () {
    test('constructs with all fields', () {
      const score = SceneQualityScore(
        overall: 85,
        prose: 90,
        coherence: 80,
        character: 88,
        completeness: 82,
        summary: '整体质量良好',
      );
      expect(score.overall, 85);
      expect(score.prose, 90);
      expect(score.coherence, 80);
      expect(score.character, 88);
      expect(score.completeness, 82);
      expect(score.summary, '整体质量良好');
    });

    test('defaults summary to empty string', () {
      const score = SceneQualityScore(
        overall: 70,
        prose: 70,
        coherence: 70,
        character: 70,
        completeness: 70,
      );
      expect(score.summary, '');
    });

    test('serializes to JSON', () {
      const score = SceneQualityScore(
        overall: 85,
        prose: 90,
        coherence: 80,
        character: 88,
        completeness: 82,
        summary: '良好',
      );
      final json = score.toJson();
      expect(json['overall'], 85);
      expect(json['prose'], 90);
      expect(json['coherence'], 80);
      expect(json['character'], 88);
      expect(json['completeness'], 82);
      expect(json['summary'], '良好');
    });

    test('fromJson reconstructs score', () {
      const original = SceneQualityScore(
        overall: 75.5,
        prose: 80.0,
        coherence: 70.5,
        character: 78.0,
        completeness: 73.5,
        summary: '测试评价',
      );
      final restored = SceneQualityScore.fromJson(original.toJson());
      expect(restored.overall, original.overall);
      expect(restored.prose, original.prose);
      expect(restored.coherence, original.coherence);
      expect(restored.character, original.character);
      expect(restored.completeness, original.completeness);
      expect(restored.summary, original.summary);
    });

    test('fromJson handles missing fields with zero defaults', () {
      final restored = SceneQualityScore.fromJson({});
      expect(restored.overall, 0);
      expect(restored.prose, 0);
      expect(restored.coherence, 0);
      expect(restored.character, 0);
      expect(restored.completeness, 0);
      expect(restored.summary, '');
    });

    test('fromJson handles numeric types', () {
      final restored = SceneQualityScore.fromJson({
        'overall': 85,
        'prose': 90.0,
        'coherence': '80',
        'character': 78,
        'completeness': '82.5',
      });
      expect(restored.overall, 85.0);
      expect(restored.prose, 90.0);
      expect(restored.coherence, 80.0);
      expect(restored.character, 78.0);
      expect(restored.completeness, 82.5);
    });

    test('equality works', () {
      const a = SceneQualityScore(
        overall: 85,
        prose: 90,
        coherence: 80,
        character: 88,
        completeness: 82,
        summary: '良好',
      );
      const b = SceneQualityScore(
        overall: 85,
        prose: 90,
        coherence: 80,
        character: 88,
        completeness: 82,
        summary: '良好',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when fields differ', () {
      const a = SceneQualityScore(
        overall: 85,
        prose: 90,
        coherence: 80,
        character: 88,
        completeness: 82,
      );
      const b = SceneQualityScore(
        overall: 85,
        prose: 90,
        coherence: 80,
        character: 88,
        completeness: 83,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when summary differs', () {
      const a = SceneQualityScore(
        overall: 85,
        prose: 90,
        coherence: 80,
        character: 88,
        completeness: 82,
        summary: '良好',
      );
      const b = SceneQualityScore(
        overall: 85,
        prose: 90,
        coherence: 80,
        character: 88,
        completeness: 82,
        summary: '一般',
      );
      expect(a, isNot(equals(b)));
    });
  });

  // ── SceneQualityScorer.parseScore ────────────────────────────────────

  group('SceneQualityScorer.parseScore', () {
    test('parses well-formed LLM output', () {
      const raw = '文笔：85\n连贯：90\n角色：78\n完整：82\n综合：84\n总结：整体质量良好';
      final score = SceneQualityScorer.parseScore(raw);
      expect(score.prose, 85);
      expect(score.coherence, 90);
      expect(score.character, 78);
      expect(score.completeness, 82);
      expect(score.overall, 84);
      expect(score.summary, '整体质量良好');
    });

    test('parses the extended formal quality rubric', () {
      const raw =
          '文笔：92\n连贯：96\n角色：94\n完整：95\n文风：91\n修辞：90\n'
          '节奏：93\n忠实：98\n综合：94\n总结：比喻克制，事实边界清楚';
      final score = SceneQualityScorer.parseScore(
        raw,
        requireExtendedRubric: true,
      );
      expect(score.hasExtendedRubric, isTrue);
      expect(score.style, 91);
      expect(score.imagery, 90);
      expect(score.rhythm, 93);
      expect(score.faithfulness, 98);
    });

    test('formal rubric rejects legacy scorecards without text dimensions', () {
      const raw = '文笔：95\n连贯：95\n角色：95\n完整：95\n综合：95\n总结：通过';
      expect(
        () => SceneQualityScorer.parseScore(raw, requireExtendedRubric: true),
        throwsFormatException,
      );
    });

    test('rejects an omitted overall score', () {
      const raw = '文笔：80\n连贯：70\n角色：90\n完整：60\n总结：还行';
      expect(() => SceneQualityScorer.parseScore(raw), throwsFormatException);
    });

    test('handles extra whitespace and blank lines', () {
      const raw =
          '\n  文笔：85  \n\n  连贯：90\n\n  角色：78\n\n  完整：82\n\n  综合：84\n\n  总结：不错\n  ';
      final score = SceneQualityScorer.parseScore(raw);
      expect(score.prose, 85);
      expect(score.coherence, 90);
      expect(score.overall, 84);
      expect(score.summary, '不错');
    });

    test('rejects completely empty input', () {
      expect(() => SceneQualityScorer.parseScore(''), throwsFormatException);
    });

    test('rejects unrecognized input', () {
      const raw = 'something completely unrelated\nno scores here';
      expect(() => SceneQualityScorer.parseScore(raw), throwsFormatException);
    });

    test('rejects scores above 100', () {
      const raw = '文笔：150\n连贯：200\n角色：999\n完整：100\n综合：120\n总结：溢出';
      expect(() => SceneQualityScorer.parseScore(raw), throwsFormatException);
    });

    test('rejects negative scores', () {
      const raw = '文笔：-10\n连贯：-50\n角色：-1\n完整：0\n综合：-99\n总结：灾难';
      expect(() => SceneQualityScorer.parseScore(raw), throwsFormatException);
    });

    test('handles decimal scores', () {
      const raw = '文笔：85.5\n连贯：90.3\n角色：78.7\n完整：82.1\n综合：84.2\n总结：精细';
      final score = SceneQualityScorer.parseScore(raw);
      expect(score.prose, 85.5);
      expect(score.coherence, 90.3);
      expect(score.character, 78.7);
      expect(score.completeness, 82.1);
      expect(score.overall, 84.2);
    });

    test('parses markdown-emphasized provider scorecards', () {
      const raw =
          '**文笔：88**\n**连贯：92**\n**角色：85**\n**完整：95**\n'
          '**综合：90**\n**总结：**结构完整且冲突清晰';
      final score = SceneQualityScorer.parseScore(raw);
      expect(score.overall, 90);
      expect(score.prose, 88);
      expect(score.summary, '结构完整且冲突清晰');
    });

    test('accepts ASCII colons and numbered markdown scorecards', () {
      const raw =
          '1. 文笔: 92\n2. 连贯: 94\n3. 角色: 93\n4. 完整: 95\n'
          '5. 文风: 91\n6. 修辞: 90\n7. 节奏: 92\n8. 忠实: 96\n'
          '9. 综合: 93\n10. 总结: 事实边界清楚';
      final score = SceneQualityScorer.parseScore(
        raw,
        requireExtendedRubric: true,
      );
      expect(score.overall, 93);
      expect(score.faithfulness, 96);
    });

    test('rejects non-numeric score values', () {
      const raw = '文笔：good\n连贯：N/A\n角色：78\n完整：82\n综合：80\n总结：部分异常';
      expect(() => SceneQualityScorer.parseScore(raw), throwsFormatException);
    });

    test(
      'rejects duplicate keys rather than accepting an ambiguous scorecard',
      () {
        const raw = '文笔：60\n文笔：85\n连贯：90\n角色：78\n完整：82\n综合：84\n总结：重复';
        expect(() => SceneQualityScorer.parseScore(raw), throwsFormatException);
      },
    );

    test('extracts summary with complex content', () {
      const raw = '文笔：85\n连贯：90\n角色：78\n完整：82\n综合：84\n总结：文笔流畅，角色塑造有待加强，情节连贯性好';
      final score = SceneQualityScorer.parseScore(raw);
      expect(score.summary, '文笔流畅，角色塑造有待加强，情节连贯性好');
    });

    test('summary extraction handles colon in content', () {
      const raw = '文笔：85\n连贯：90\n角色：78\n完整：82\n综合：84\n总结：评价：良好';
      final score = SceneQualityScorer.parseScore(raw);
      expect(score.summary, '评价：良好');
    });

    test('rejects partial input with only some dimensions', () {
      const raw = '文笔：85\n角色：78';
      expect(() => SceneQualityScorer.parseScore(raw), throwsFormatException);
    });
  });

  group('SceneQualityScorer parsed-result provenance', () {
    const prose = SceneProseDraft(text: '雨线斜切过仓门，柳溪按住被风掀起的货单。', attempt: 1);
    final brief = SceneBrief(
      chapterId: 'quality-chapter',
      chapterTitle: '雨夜',
      sceneId: 'quality-scene',
      sceneTitle: '仓门',
      sceneSummary: '柳溪守住货单。',
      formalExecution: true,
    );
    const director = SceneDirectorOutput(text: '守住货单并确认追兵位置。');
    const review = SceneReviewResult(
      judge: SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: '行动清楚。',
        rawText: '决定：PASS\n原因：行动清楚。',
      ),
      consistency: SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: '事实一致。',
        rawText: '决定：PASS\n原因：事实一致。',
      ),
      decision: SceneReviewDecision.pass,
    );
    const response =
        '文笔：92\n连贯：94\n角色：93\n完整：95\n文风：91\n修辞：90\n'
        '节奏：92\n忠实：96\n综合：93\n总结：事实边界清楚';

    Future<SceneQualityScore> realScore() async {
      final run = await runFormalEvaluationProvenanceFixture(
        responses: const [response],
        body: (settingsStore) => SceneQualityScorer(
          settingsStore: settingsStore,
        ).score(brief: brief, director: director, prose: prose, review: review),
      );
      expect(run.providerCallCount, 1);
      expect(run.attempts.single.callSiteId, 'quality-scorer');
      return run.value;
    }

    Future<AppLlmChatResult> rawFormalQualityOutcome() async {
      final promptIdentity = StoryPromptRegistry.production.invocation(
        stageId: 'quality-gate',
        callSiteId: 'quality-scorer',
      );
      final variables = <String, Object?>{
        'sceneTitle': '仓门',
        'sceneSummary': '柳溪守住货单。',
        'director': director.text,
        'prose': prose.text,
        'review': review.editorialFeedback,
        'faithfulnessContext': '仅依据场景概要。',
      };
      final messages = promptIdentity.render(variables).messages;
      final artifactDigest = ArtifactDigest.fromUtf8String(prose.text);
      final run = await runFormalEvaluationProvenanceFixture(
        responses: const [response],
        body: (settingsStore) => StoryGenerationEvaluationScope.run(
          phase: StoryGenerationEvaluationPhase.quality,
          artifactText: prose.text,
          body: () => requestFormalStoryGenerationPassWithRetry(
            settingsStore: settingsStore,
            messages: messages,
            promptInvocation: promptIdentity,
            promptInvocationEvidence: promptIdentity.evidence(
              messages,
              resolvedVariables: variables,
            ),
            evaluationFingerprintSeed: StoryGenerationEvaluationFingerprintSeed(
              artifactDigest: artifactDigest,
              evaluationBundleHash: AppLlmCanonicalHash.domainHash(
                'quality-admission-negative-test-bundle-v1',
                const <String, Object?>{'release': 'fixture'},
              ),
              judgeInput: storyGenerationEvaluationJudgeInput(
                phase: StoryGenerationEvaluationPhase.quality,
                stageId: 'quality-gate',
                callSiteId: 'quality-scorer',
                artifactDigest: artifactDigest,
              ),
              rubricHash: storyGenerationEvaluationRubricHash(
                phase: StoryGenerationEvaluationPhase.quality,
                promptInvocation: promptIdentity,
              ),
              blindingPolicy: 'formal-evaluation-test-v1',
            ),
          ),
        ),
      );
      return run.value;
    }

    test('real durable provider score mints one exact DTO proof', () async {
      final score = await realScore();
      final rehydrated = SceneQualityScore.fromJson(score.toJson());
      final artifactDigest = ArtifactDigest.fromUtf8String(prose.text);

      expect(
        consumeVerifiedSceneQualityProvenance(
          score: rehydrated,
          phase: StoryGenerationEvaluationPhase.quality,
          artifactDigest: artifactDigest,
        ),
        isNull,
      );

      final provenance = consumeVerifiedSceneQualityProvenance(
        score: score,
        phase: StoryGenerationEvaluationPhase.quality,
        artifactDigest: artifactDigest,
      );
      expect(provenance, isNotNull);
      expect(provenance!.outcome.stageId, 'quality-gate');
      expect(provenance.outcome.callSiteId, 'quality-scorer');
      expect(
        provenance.outcome.parserRelease,
        StoryPromptRegistry.production
            .invocation(stageId: 'quality-gate', callSiteId: 'quality-scorer')
            .release
            .parserRelease,
      );
      expect(
        provenance.parsedOutputDigest,
        storyGenerationParsedOutputDigest(score.toJson()),
      );
      expect(
        consumeVerifiedSceneQualityProvenance(
          score: score,
          phase: StoryGenerationEvaluationPhase.quality,
          artifactDigest: artifactDigest,
        ),
        isNull,
      );
    });

    test('phase mismatch burns the exact score proof', () async {
      final score = await realScore();
      final artifactDigest = ArtifactDigest.fromUtf8String(prose.text);

      expect(
        consumeVerifiedSceneQualityProvenance(
          score: score,
          phase: StoryGenerationEvaluationPhase.finalCouncil,
          artifactDigest: artifactDigest,
        ),
        isNull,
      );
      expect(
        consumeVerifiedSceneQualityProvenance(
          score: score,
          phase: StoryGenerationEvaluationPhase.quality,
          artifactDigest: artifactDigest,
        ),
        isNull,
      );
    });

    test('artifact mismatch burns the exact score proof', () async {
      final score = await realScore();

      expect(
        consumeVerifiedSceneQualityProvenance(
          score: score,
          phase: StoryGenerationEvaluationPhase.quality,
          artifactDigest: ArtifactDigest.fromUtf8String('different prose'),
        ),
        isNull,
      );
      expect(
        consumeVerifiedSceneQualityProvenance(
          score: score,
          phase: StoryGenerationEvaluationPhase.quality,
          artifactDigest: ArtifactDigest.fromUtf8String(prose.text),
        ),
        isNull,
      );
    });

    test('public parser output cannot mint a score proof', () {
      final score = SceneQualityScorer.parseScore(response);
      expect(
        consumeVerifiedSceneQualityProvenance(
          score: score,
          phase: StoryGenerationEvaluationPhase.quality,
          artifactDigest: ArtifactDigest.fromUtf8String(prose.text),
        ),
        isNull,
      );
    });

    test('wrong callsite or parser burns the raw provider admission', () async {
      final promptIdentity = StoryPromptRegistry.production.invocation(
        stageId: 'quality-gate',
        callSiteId: 'quality-scorer',
      );
      final artifactDigest = ArtifactDigest.fromUtf8String(prose.text);
      final wrongCallSiteResult = await rawFormalQualityOutcome();

      expect(
        takeStoryGenerationFormalOutcomeAdmission(
          result: wrongCallSiteResult,
          stageId: 'quality-gate',
          callSiteId: 'not-quality-scorer',
          parserRelease: promptIdentity.release.parserRelease,
          evaluationPhase: StoryGenerationEvaluationPhase.quality,
          evaluatedArtifactDigest: artifactDigest,
        ),
        isNull,
      );
      expect(
        takeStoryGenerationFormalOutcomeAdmission(
          result: wrongCallSiteResult,
          stageId: 'quality-gate',
          callSiteId: 'quality-scorer',
          parserRelease: promptIdentity.release.parserRelease,
          evaluationPhase: StoryGenerationEvaluationPhase.quality,
          evaluatedArtifactDigest: artifactDigest,
        ),
        isNull,
      );

      final wrongParserResult = await rawFormalQualityOutcome();
      expect(
        takeStoryGenerationFormalOutcomeAdmission(
          result: wrongParserResult,
          stageId: 'quality-gate',
          callSiteId: 'quality-scorer',
          parserRelease: 'wrong-parser-release',
          evaluationPhase: StoryGenerationEvaluationPhase.quality,
          evaluatedArtifactDigest: artifactDigest,
        ),
        isNull,
      );
      expect(
        takeStoryGenerationFormalOutcomeAdmission(
          result: wrongParserResult,
          stageId: 'quality-gate',
          callSiteId: 'quality-scorer',
          parserRelease: promptIdentity.release.parserRelease,
          evaluationPhase: StoryGenerationEvaluationPhase.quality,
          evaluatedArtifactDigest: artifactDigest,
        ),
        isNull,
      );
    });
  });

  // ── SceneRuntimeOutput.qualityScore integration ─────────────────────

  group('SceneRuntimeOutput with qualityScore', () {
    SceneBrief makeBrief() => SceneBrief(
      chapterId: 'ch1',
      chapterTitle: '第一章',
      sceneId: 'sc1',
      sceneTitle: '开篇',
      sceneSummary: '故事开始',
    );

    test('holds qualityScore when provided', () {
      const score = SceneQualityScore(
        overall: 85,
        prose: 90,
        coherence: 80,
        character: 88,
        completeness: 82,
        summary: '良好',
      );
      final output = SceneRuntimeOutput(
        brief: makeBrief(),
        resolvedCast: [],
        director: const SceneDirectorOutput(text: 'plan'),
        roleOutputs: [],
        prose: const SceneProseDraft(text: 'content', attempt: 1),
        review: const SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: 'ok',
            rawText: 'ok',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: 'ok',
            rawText: 'ok',
          ),
          decision: SceneReviewDecision.pass,
        ),
        proseAttempts: 1,
        softFailureCount: 0,
        qualityScore: score,
      );
      expect(output.qualityScore, isNotNull);
      expect(output.qualityScore!.overall, 85);
      expect(output.qualityScore!.prose, 90);
    });

    test('qualityScore is null when not provided', () {
      final output = SceneRuntimeOutput(
        brief: makeBrief(),
        resolvedCast: [],
        director: const SceneDirectorOutput(text: 'plan'),
        roleOutputs: [],
        prose: const SceneProseDraft(text: 'content', attempt: 1),
        review: const SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: 'ok',
            rawText: 'ok',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: 'ok',
            rawText: 'ok',
          ),
          decision: SceneReviewDecision.pass,
        ),
        proseAttempts: 1,
        softFailureCount: 0,
      );
      expect(output.qualityScore, isNull);
    });
  });
}
