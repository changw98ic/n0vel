import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';
import 'package:novel_writer/features/story_generation/domain/character_cognition_models.dart';

void main() {
  // ===========================================================================
  // SceneCastParticipation
  // ===========================================================================
  group('SceneCastParticipation', () {
    test('default constructor yields null optional fields', () {
      const p = SceneCastParticipation();
      expect(p.action, isNull);
      expect(p.dialogue, isNull);
      expect(p.interaction, isNull);
    });

    test('preserves all provided values', () {
      const p = SceneCastParticipation(
        action: '挡住退路',
        dialogue: '你今晚不该来',
        interaction: '逼近岳刃',
      );
      expect(p.action, '挡住退路');
      expect(p.dialogue, '你今晚不该来');
      expect(p.interaction, '逼近岳刃');
    });
  });

  // ===========================================================================
  // SceneCastCandidate
  // ===========================================================================
  group('SceneCastCandidate', () {
    test('stores required fields and defaults', () {
      final c = SceneCastCandidate(
        characterId: 'char-01',
        name: '柳溪',
        role: '调查记者',
      );
      expect(c.characterId, 'char-01');
      expect(c.name, '柳溪');
      expect(c.role, '调查记者');
      expect(c.participation.action, isNull);
      expect(c.metadata, isEmpty);
    });

    test('metadata is immutable and defensively copied', () {
      final meta = <String, Object?>{'key': 'value'};
      final c = SceneCastCandidate(
        characterId: 'c1',
        name: 'A',
        role: 'B',
        metadata: meta,
      );

      meta['key'] = 'changed';
      expect(c.metadata['key'], 'value');

      expect(() => c.metadata['new'] = 1, throwsUnsupportedError);
    });

    test('nested metadata maps are also immutable', () {
      final c = SceneCastCandidate(
        characterId: 'c1',
        name: 'A',
        role: 'B',
        metadata: {
          'nested': {'inner': 42},
        },
      );

      final nested = c.metadata['nested'] as Map<String, Object?>;
      expect(() => nested['inner'] = 99, throwsUnsupportedError);
    });
  });

  // ===========================================================================
  // SceneBrief
  // ===========================================================================
  group('SceneBrief', () {
    test('stores all fields with defaults', () {
      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '第一章',
        sceneId: 'sc-01',
        sceneTitle: '仓库门外',
        sceneSummary: '柳溪拦住岳刃。',
      );

      expect(brief.chapterId, 'ch-01');
      expect(brief.targetLength, 400);
      expect(brief.targetBeat, isEmpty);
      expect(brief.worldNodeIds, isEmpty);
      expect(brief.cast, isEmpty);
      expect(brief.metadata, isEmpty);
    });

    test('worldNodeIds list is defensively copied and immutable', () {
      final nodes = <String>['node-a', 'node-b'];
      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: 'T',
        sceneId: 'sc-01',
        sceneTitle: 'T',
        sceneSummary: 'S',
        worldNodeIds: nodes,
      );

      nodes.add('node-c');
      expect(brief.worldNodeIds, ['node-a', 'node-b']);
      expect(() => brief.worldNodeIds.add('x'), throwsUnsupportedError);
    });

    test('cast list is defensively copied and immutable', () {
      final cast = <SceneCastCandidate>[
        SceneCastCandidate(characterId: 'c1', name: 'A', role: 'R'),
      ];
      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: 'T',
        sceneId: 'sc-01',
        sceneTitle: 'T',
        sceneSummary: 'S',
        cast: cast,
      );

      cast.add(SceneCastCandidate(characterId: 'c2', name: 'B', role: 'R'));
      expect(brief.cast, hasLength(1));
      expect(
        () => brief.cast.add(
          SceneCastCandidate(characterId: 'c3', name: 'C', role: 'R'),
        ),
        throwsUnsupportedError,
      );
    });

    test('metadata is defensively copied and deeply immutable', () {
      final meta = <String, Object?>{
        'top': 'val',
        'list': [1, 2],
        'map': {'k': 'v'},
      };
      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: 'T',
        sceneId: 'sc-01',
        sceneTitle: 'T',
        sceneSummary: 'S',
        metadata: meta,
      );

      meta['top'] = 'changed';
      expect(brief.metadata['top'], 'val');

      expect(() => brief.metadata['new'] = 1, throwsUnsupportedError);
      final list = brief.metadata['list'] as List<Object?>;
      expect(() => list.add(3), throwsUnsupportedError);
      final map = brief.metadata['map'] as Map<String, Object?>;
      expect(() => map['k'] = 'x', throwsUnsupportedError);
    });
  });

  // ===========================================================================
  // ResolvedSceneCastMember
  // ===========================================================================
  group('ResolvedSceneCastMember', () {
    test('stores all fields', () {
      final m = ResolvedSceneCastMember(
        characterId: 'char-liuxi',
        name: '柳溪',
        role: '调查记者',
        contributions: const [
          SceneCastContribution.action,
          SceneCastContribution.interaction,
        ],
      );
      expect(m.characterId, 'char-liuxi');
      expect(m.contributions, hasLength(2));
      expect(m.metadata, isEmpty);
    });

    test('contributions list is immutable and defensively copied', () {
      final contribs = <SceneCastContribution>[SceneCastContribution.dialogue];
      final m = ResolvedSceneCastMember(
        characterId: 'c1',
        name: 'A',
        role: 'R',
        contributions: contribs,
      );

      contribs.add(SceneCastContribution.action);
      expect(m.contributions, hasLength(1));
      expect(
        () => m.contributions.add(SceneCastContribution.interaction),
        throwsUnsupportedError,
      );
    });
  });

  // ===========================================================================
  // SceneCastContribution enum
  // ===========================================================================
  group('SceneCastContribution', () {
    test('has exactly three values', () {
      expect(SceneCastContribution.values, hasLength(3));
      expect(
        SceneCastContribution.values,
        containsAll([
          SceneCastContribution.action,
          SceneCastContribution.dialogue,
          SceneCastContribution.interaction,
        ]),
      );
    });
  });

  // ===========================================================================
  // SceneDirectorOutput
  // ===========================================================================
  group('SceneDirectorOutput', () {
    test('stores text', () {
      const output = SceneDirectorOutput(text: '目标：逼问\n冲突：顶压');
      expect(output.text, contains('目标'));
      expect(output.text, contains('冲突'));
    });
  });

  // ===========================================================================
  // DynamicRoleAgentOutput
  // ===========================================================================
  group('DynamicRoleAgentOutput', () {
    test('stores all fields', () {
      const output = DynamicRoleAgentOutput(
        characterId: 'char-liuxi',
        name: '柳溪',
        text: '立场：压迫\n动作：逼近',
      );
      expect(output.characterId, 'char-liuxi');
      expect(output.name, '柳溪');
      expect(output.text, contains('立场'));
    });
  });

  // ===========================================================================
  // SceneProseDraft
  // ===========================================================================
  group('SceneProseDraft', () {
    test('stores text and attempt number', () {
      const draft = SceneProseDraft(text: '柳溪逼近半步。', attempt: 1);
      expect(draft.text, '柳溪逼近半步。');
      expect(draft.attempt, 1);
    });

    test('tracks retry attempts', () {
      const first = SceneProseDraft(text: '第一稿', attempt: 1);
      const second = SceneProseDraft(text: '第二稿', attempt: 2);
      expect(first.attempt, lessThan(second.attempt));
    });
  });

  // ===========================================================================
  // SceneReviewStatus enum
  // ===========================================================================
  group('SceneReviewStatus', () {
    test('has pass, rewriteProse, replanScene', () {
      expect(SceneReviewStatus.values, hasLength(3));
      expect(SceneReviewStatus.values, contains(SceneReviewStatus.pass));
      expect(
        SceneReviewStatus.values,
        contains(SceneReviewStatus.rewriteProse),
      );
      expect(
        SceneReviewStatus.values,
        contains(SceneReviewStatus.replanScene),
      );
    });
  });

  // ===========================================================================
  // SceneReviewDecision enum
  // ===========================================================================
  group('SceneReviewDecision', () {
    test('has pass, rewriteProse, replanScene', () {
      expect(SceneReviewDecision.values, hasLength(3));
      expect(SceneReviewDecision.values, contains(SceneReviewDecision.pass));
    });
  });

  // ===========================================================================
  // SceneReviewPassResult
  // ===========================================================================
  group('SceneReviewPassResult', () {
    test('stores all fields', () {
      const result = SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: '冲突闭环成立。',
        rawText: '决定：PASS\n原因：冲突闭环成立。',
      );
      expect(result.status, SceneReviewStatus.pass);
      expect(result.reason, '冲突闭环成立。');
      expect(result.rawText, contains('PASS'));
    });
  });

  // ===========================================================================
  // SceneReviewResult
  // ===========================================================================
  group('SceneReviewResult', () {
    test('feedback joins judge and consistency reasons', () {
      const result = SceneReviewResult(
        judge: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '戏剧推进成立',
          rawText: '',
        ),
        consistency: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '动线一致',
          rawText: '',
        ),
        decision: SceneReviewDecision.pass,
      );

      expect(result.feedback, contains('Judge:'));
      expect(result.feedback, contains('戏剧推进成立'));
      expect(result.feedback, contains('Consistency:'));
      expect(result.feedback, contains('动线一致'));
    });

    test('feedback skips empty reasons', () {
      const result = SceneReviewResult(
        judge: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '成立',
          rawText: '',
        ),
        consistency: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '',
          rawText: '',
        ),
        decision: SceneReviewDecision.pass,
      );

      expect(result.feedback, contains('Judge:'));
      expect(result.feedback, isNot(contains('Consistency:')));
    });

    test('feedback is empty when both reasons are blank', () {
      const result = SceneReviewResult(
        judge: SceneReviewPassResult(
          status: SceneReviewStatus.rewriteProse,
          reason: '   ',
          rawText: '',
        ),
        consistency: SceneReviewPassResult(
          status: SceneReviewStatus.rewriteProse,
          reason: '',
          rawText: '',
        ),
        decision: SceneReviewDecision.rewriteProse,
      );

      expect(result.feedback, isEmpty);
    });

    test('decision field is preserved', () {
      const result = SceneReviewResult(
        judge: SceneReviewPassResult(
          status: SceneReviewStatus.replanScene,
          reason: '',
          rawText: '',
        ),
        consistency: SceneReviewPassResult(
          status: SceneReviewStatus.replanScene,
          reason: '空间矛盾',
          rawText: '',
        ),
        decision: SceneReviewDecision.replanScene,
      );
      expect(result.decision, SceneReviewDecision.replanScene);
    });
  });

  // ===========================================================================
  // SceneRuntimeOutput
  // ===========================================================================
  group('SceneRuntimeOutput', () {
    SceneRuntimeOutput makeOutput() => SceneRuntimeOutput(
          brief: SceneBrief(
            chapterId: 'ch-01',
            chapterTitle: '第一章',
            sceneId: 'sc-01',
            sceneTitle: '仓库门外',
            sceneSummary: '摘要',
          ),
          resolvedCast: [
            ResolvedSceneCastMember(
              characterId: 'c1',
              name: '柳溪',
              role: '调查记者',
              contributions: const [SceneCastContribution.action],
            ),
          ],
          director: const SceneDirectorOutput(text: '导演计划'),
          roleOutputs: const [
            DynamicRoleAgentOutput(
              characterId: 'c1',
              name: '柳溪',
              text: '立场：压迫',
            ),
          ],
          prose: const SceneProseDraft(text: '正文', attempt: 1),
          review: const SceneReviewResult(
            judge: SceneReviewPassResult(
              status: SceneReviewStatus.pass,
              reason: '通过',
              rawText: '',
            ),
            consistency: SceneReviewPassResult(
              status: SceneReviewStatus.pass,
              reason: '一致',
              rawText: '',
            ),
            decision: SceneReviewDecision.pass,
          ),
          proseAttempts: 1,
          softFailureCount: 0,
        );

    test('stores all fields', () {
      final output = makeOutput();
      expect(output.brief.sceneId, 'sc-01');
      expect(output.resolvedCast, hasLength(1));
      expect(output.director.text, '导演计划');
      expect(output.roleOutputs, hasLength(1));
      expect(output.prose.text, '正文');
      expect(output.prose.attempt, 1);
      expect(output.review.decision, SceneReviewDecision.pass);
      expect(output.proseAttempts, 1);
      expect(output.softFailureCount, 0);
    });

    test('resolvedCast is immutable and defensively copied', () {
      final cast = <ResolvedSceneCastMember>[
        ResolvedSceneCastMember(
          characterId: 'c1',
          name: 'A',
          role: 'R',
          contributions: const [],
        ),
      ];
      final output = SceneRuntimeOutput(
        brief: SceneBrief(
          chapterId: 'ch',
          chapterTitle: 'T',
          sceneId: 'sc',
          sceneTitle: 'T',
          sceneSummary: 'S',
        ),
        resolvedCast: cast,
        director: const SceneDirectorOutput(text: ''),
        roleOutputs: const [],
        prose: const SceneProseDraft(text: '', attempt: 1),
        review: const SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '',
            rawText: '',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '',
            rawText: '',
          ),
          decision: SceneReviewDecision.pass,
        ),
        proseAttempts: 0,
        softFailureCount: 0,
      );

      cast.add(ResolvedSceneCastMember(
        characterId: 'c2',
        name: 'B',
        role: 'R',
        contributions: const [],
      ));
      expect(output.resolvedCast, hasLength(1));
      expect(
        () => output.resolvedCast.add(ResolvedSceneCastMember(
          characterId: 'c3',
          name: 'C',
          role: 'R',
          contributions: const [],
        )),
        throwsUnsupportedError,
      );
    });

    test('roleOutputs is immutable and defensively copied', () {
      final roles = <DynamicRoleAgentOutput>[
        const DynamicRoleAgentOutput(
          characterId: 'c1',
          name: 'A',
          text: 'text',
        ),
      ];
      final output = SceneRuntimeOutput(
        brief: SceneBrief(
          chapterId: 'ch',
          chapterTitle: 'T',
          sceneId: 'sc',
          sceneTitle: 'T',
          sceneSummary: 'S',
        ),
        resolvedCast: const [],
        director: const SceneDirectorOutput(text: ''),
        roleOutputs: roles,
        prose: const SceneProseDraft(text: '', attempt: 1),
        review: const SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '',
            rawText: '',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '',
            rawText: '',
          ),
          decision: SceneReviewDecision.pass,
        ),
        proseAttempts: 0,
        softFailureCount: 0,
      );

      roles.add(const DynamicRoleAgentOutput(
        characterId: 'c2',
        name: 'B',
        text: 't',
      ));
      expect(output.roleOutputs, hasLength(1));
      expect(
        () => output.roleOutputs.add(const DynamicRoleAgentOutput(
          characterId: 'c3',
          name: 'C',
          text: 't',
        )),
        throwsUnsupportedError,
      );
    });
  });

  // ===========================================================================
  // Pipeline model basic construction
  // ===========================================================================
  group('CharacterBelief', () {
    test('stores subject, target, claim, and confidence', () {
      final b = CharacterBelief(
        subjectId: 'char-liuxi',
        targetId: 'char-yueren',
        claim: '不可信',
        confidence: 1.0,
        source: 'test',
      );
      expect(b.subjectId, 'char-liuxi');
      expect(b.targetId, 'char-yueren');
      expect(b.claim, '不可信');
      expect(b.confidence, 1.0);
    });
  });

  group('RelationshipSlice', () {
    test('stores all fields including tension and trust defaults', () {
      final r = RelationshipSlice(
        characterId: 'char-liuxi',
        otherId: 'char-yueren',
        kind: '对峙',
      );
      expect(r.characterId, 'char-liuxi');
      expect(r.otherId, 'char-yueren');
      expect(r.kind, '对峙');
      expect(r.tension, 0.0);
      expect(r.trust, 0.5);
    });

    test('accepts custom tension and trust', () {
      final r = RelationshipSlice(
        characterId: 'a',
        otherId: 'b',
        kind: '盟友',
        tension: 0.2,
        trust: 0.8,
      );
      expect(r.tension, closeTo(0.2, 0.001));
      expect(r.trust, closeTo(0.8, 0.001));
    });
  });

  group('SocialPositionSlice', () {
    test('stores all fields', () {
      const sp = SocialPositionSlice(
        characterId: 'char-liuxi',
        contextId: 'scene-1',
        role: '调查记者',
        rank: 3,
        notes: '高影响力',
      );
      expect(sp.characterId, 'char-liuxi');
      expect(sp.role, '调查记者');
      expect(sp.contextId, 'scene-1');
      expect(sp.rank, 3);
      expect(sp.notes, '高影响力');
    });
  });

  group('KnowledgeSnippet', () {
    test('stores all fields', () {
      const k = KnowledgeSnippet(
        id: 'k1',
        category: 'event',
        content: '昨夜码头火拼。',
        sourceId: 'scene-prev',
      );
      expect(k.id, 'k1');
      expect(k.category, 'event');
      expect(k.content, '昨夜码头火拼。');
      expect(k.sourceId, 'scene-prev');
    });
  });

  group('LightContextCapsule', () {
    test('stores intent, summary, and token budget', () {
      const capsule = LightContextCapsule(
        intent: LightRetrievalIntent(
          toolName: 'relationship',
          query: 'char-liuxi',
          purpose: '了解关系',
        ),
        summary: '柳溪与岳刃对峙，张力7',
        tokenBudget: 100,
      );
      expect(capsule.intent.toolName, 'relationship');
      expect(capsule.summary, contains('对峙'));
      expect(capsule.tokenBudget, 100);
    });
  });

  group('SceneBeatKind', () {
    test('covers all beat types', () {
      expect(SceneBeatKind.values, hasLength(5));
      expect(
        SceneBeatKind.values,
        containsAll([
          SceneBeatKind.fact,
          SceneBeatKind.dialogue,
          SceneBeatKind.action,
          SceneBeatKind.internal,
          SceneBeatKind.narration,
        ]),
      );
    });
  });
}
