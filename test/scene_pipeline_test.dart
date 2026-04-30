import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/retrieval_controller.dart';
import 'package:novel_writer/features/story_generation/data/scene_director_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/scene_editorial_generator.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart';
import 'package:novel_writer/features/story_generation/data/dynamic_role_agent_runner.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/scene_state_resolver.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';

import 'test_support/fake_app_llm_client.dart';

// ---------------------------------------------------------------------------
// Shared test fixtures
// ---------------------------------------------------------------------------

SceneBrief _brief() => SceneBrief(
  chapterId: 'chapter-01',
  chapterTitle: '第一章 雨夜码头',
  sceneId: 'scene-01',
  sceneTitle: '仓库门外',
  sceneSummary: '柳溪在风雨中拦住岳刃，必须逼出货单去向。',
  targetBeat: '拿到账本去向，并把沈渡拖上同一条船。',
  worldNodeIds: const ['old-harbor', 'customs-yard'],
  cast: [
    SceneCastCandidate(
      characterId: 'char-liuxi',
      name: '柳溪',
      role: '调查记者',
      participation: const SceneCastParticipation(
        action: '挡住退路',
        interaction: '逼近岳刃',
      ),
    ),
    SceneCastCandidate(
      characterId: 'char-yueren',
      name: '岳刃',
      role: '走私联络人',
      participation: const SceneCastParticipation(dialogue: '“你今晚不该来这里。”'),
    ),
  ],
);

ResolvedSceneCastMember _castMember({
  String characterId = 'char-liuxi',
  String name = '柳溪',
  String role = '调查记者',
}) => ResolvedSceneCastMember(
  characterId: characterId,
  name: name,
  role: role,
  contributions: const [SceneCastContribution.action],
);

SceneTaskCard _taskCard({
  List<CharacterBelief> beliefs = const [],
  List<RelationshipSlice> relationships = const [],
  List<SocialPositionSlice> socialPositions = const [],
  List<KnowledgeAtom> knowledge = const [],
}) => SceneTaskCard(
  brief: _brief(),
  cast: [
    _castMember(),
    _castMember(characterId: 'char-yueren', name: '岳刃', role: '走私联络人'),
  ],
  directorPlan: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
  beliefs: beliefs,
  relationships: relationships,
  socialPositions: socialPositions,
  knowledge: knowledge,
);

AppLlmChatResult? _defaultRoleplayResponse(AppLlmChatRequest request) {
  final userPrompt = request.messages.last.content;
  if (userPrompt.contains('任务：scene_roleplay_turn')) {
    return const AppLlmChatResult.success(
      text:
          '意图：压迫对方\n'
          '可见动作：柳溪逼近半步\n'
          '对白：货单在哪\n'
          '内心：先稳住节奏。',
    );
  }
  if (userPrompt.contains('任务：scene_roleplay_arbitrate')) {
    return const AppLlmChatResult.success(
      text: '事实：柳溪逼近半步并追问货单\n状态：岳刃被迫应对\n压力：升级\n收束：是',
    );
  }
  return null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Pipeline data models
  // =========================================================================
  group('ScenePipelineModels', () {
    test('SceneTaskCard query methods return correct slices', () {
      final card = _taskCard(
        beliefs: [
          const CharacterBelief(
            holderId: 'char-liuxi',
            targetId: 'char-yueren',
            aspect: '忠诚度',
            value: '不可信',
          ),
          const CharacterBelief(
            holderId: 'char-yueren',
            targetId: 'char-liuxi',
            aspect: '威胁',
            value: '高度危险',
          ),
        ],
        relationships: [
          const RelationshipSlice(
            characterA: 'char-liuxi',
            characterB: 'char-yueren',
            label: '对峙',
            tension: 8,
            trust: 1,
          ),
        ],
        socialPositions: [
          const SocialPositionSlice(
            characterId: 'char-liuxi',
            role: '调查记者',
            formalRank: '无',
            actualInfluence: '高',
          ),
        ],
      );

      final liuxiBeliefs = card.beliefsFor('char-liuxi');
      expect(liuxiBeliefs, hasLength(1));
      expect(liuxiBeliefs.first.aspect, '忠诚度');

      final liuxiRels = card.relationshipsFor('char-liuxi');
      expect(liuxiRels, hasLength(1));
      expect(liuxiRels.first.label, '对峙');

      final sp = card.socialPositionFor('char-liuxi');
      expect(sp, isNotNull);
      expect(sp!.actualInfluence, '高');
      expect(card.socialPositionFor('char-yueren'), isNull);
    });

    test('SceneTaskCard collections are immutable', () {
      final card = _taskCard();
      expect(() => card.cast.add(_castMember()), throwsUnsupportedError);
      expect(
        () => card.beliefs.add(
          const CharacterBelief(
            holderId: '',
            targetId: '',
            aspect: '',
            value: '',
          ),
        ),
        throwsUnsupportedError,
      );
      expect(() => card.metadata['x'] = 1, throwsUnsupportedError);
    });

    test('PresentationState detects deception correctly', () {
      const honest = PresentationState(
        characterId: 'c1',
        surfaceEmotion: '冷静',
        hiddenEmotion: '冷静',
        deceptionTarget: '',
        deceptionContent: '',
      );
      expect(honest.isDeceptive, isFalse);

      const deceptive = PresentationState(
        characterId: 'c1',
        surfaceEmotion: '平静',
        hiddenEmotion: '愤怒',
        deceptionTarget: 'char-yueren',
        deceptionContent: '假装不在意',
      );
      expect(deceptive.isDeceptive, isTrue);
    });

    test(
      'RolePlayTurnOutput.fromDynamicAgentOutput parses structured lines',
      () {
        final output = DynamicRoleAgentOutput(
          characterId: 'char-liuxi',
          name: '柳溪',
          text: '立场：压迫\n动作：逼近半步\n禁忌：拖延',
        );
        final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

        expect(turn.characterId, 'char-liuxi');
        expect(turn.name, '柳溪');
        expect(turn.stance, '压迫');
        expect(turn.action, '逼近半步');
        expect(turn.taboo, '拖延');
        expect(turn.retrievalIntents, isEmpty);
      },
    );

    test(
      'RolePlayTurnOutput.fromDynamicAgentOutput handles malformed input',
      () {
        final output = DynamicRoleAgentOutput(
          characterId: 'char-x',
          name: '未知',
          text: '这是一段没有结构的文本',
        );
        final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

        expect(turn.stance, isEmpty);
        expect(turn.action, isEmpty);
        expect(turn.taboo, isEmpty);
      },
    );

    test(
      'RolePlayTurnOutput.fromDynamicAgentOutput parses retrieval intents',
      () {
        final output = DynamicRoleAgentOutput(
          characterId: 'char-liuxi',
          name: '柳溪',
          text:
              '立场：压迫\n动作：逼近半步\n禁忌：拖延'
              '\n检索：character_profile|岳刃|了解背景'
              '\n检索：relationship|char-yueren|关系状态',
        );
        final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

        expect(turn.stance, '压迫');
        expect(turn.action, '逼近半步');
        expect(turn.taboo, '拖延');
        expect(turn.retrievalIntents, hasLength(2));
        expect(turn.retrievalIntents[0].toolName, 'character_profile');
        expect(turn.retrievalIntents[0].query, '岳刃');
        expect(turn.retrievalIntents[0].purpose, '了解背景');
        expect(turn.retrievalIntents[1].toolName, 'relationship');
        expect(turn.retrievalIntents[1].query, 'char-yueren');
        expect(turn.retrievalIntents[1].purpose, '关系状态');
      },
    );

    test(
      'RolePlayTurnOutput.fromDynamicAgentOutput skips malformed retrieval',
      () {
        final output = DynamicRoleAgentOutput(
          characterId: 'char-x',
          name: '未知',
          text: '立场：压迫\n检索：no_pipe_separator\n检索：tool|query',
        );
        final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

        expect(turn.stance, '压迫');
        expect(turn.retrievalIntents, hasLength(1));
        expect(turn.retrievalIntents[0].toolName, 'tool');
        expect(turn.retrievalIntents[0].query, 'query');
        expect(turn.retrievalIntents[0].purpose, isEmpty);
      },
    );

    test('SceneBeat kind and order are preserved', () {
      const beat = SceneBeat(
        kind: SceneBeatKind.dialogue,
        content: '你怎么来了',
        sourceCharacterId: 'char-liuxi',
        order: 3,
      );
      expect(beat.kind, SceneBeatKind.dialogue);
      expect(beat.order, 3);
      expect(beat.content, '你怎么来了');
    });

    test('SceneEditorialDraft records beat count', () {
      const draft = SceneEditorialDraft(text: '正文', beatCount: 5, attempt: 1);
      expect(draft.beatCount, 5);
      expect(draft.attempt, 1);
    });

    test('ScenePipelineOutput collections are immutable', () {
      final output = ScenePipelineOutput(
        taskCard: _taskCard(),
        roleTurns: [],
        capsules: [],
        resolvedBeats: const [
          SceneBeat(
            kind: SceneBeatKind.fact,
            content: 'f',
            sourceCharacterId: 'n',
          ),
        ],
        editorialDraft: const SceneEditorialDraft(
          text: 't',
          beatCount: 1,
          attempt: 1,
        ),
        review: const SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '',
            rawText: '决定：PASS\n原因：通过。',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '',
            rawText: '决定：PASS\n原因：通过。',
          ),
          decision: SceneReviewDecision.pass,
        ),
        proseAttempts: 1,
        softFailureCount: 0,
      );

      expect(
        () => output.roleTurns.add(
          RolePlayTurnOutput(
            characterId: '',
            name: '',
            stance: '',
            action: '',
            taboo: '',
            retrievalIntents: [],
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => output.capsules.add(
          const ContextCapsule(
            intent: RetrievalIntent(toolName: '', query: '', purpose: ''),
            summary: '',
            tokenBudget: 0,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => output.resolvedBeats.add(
          const SceneBeat(
            kind: SceneBeatKind.action,
            content: '',
            sourceCharacterId: '',
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('RetrievalIntent defines standard tool name constants', () {
      expect(RetrievalIntent.kToolCharacterProfile, 'character_profile');
      expect(RetrievalIntent.kToolRelationship, 'relationship');
      expect(RetrievalIntent.kToolWorldSetting, 'world_setting');
      expect(RetrievalIntent.kToolPastEvent, 'past_event');
    });
  });

  // =========================================================================
  // RetrievalController
  // =========================================================================
  group('RetrievalController', () {
    late RetrievalController controller;

    setUp(() {
      controller = const RetrievalController();
    });

    test('returns empty when no turns have retrieval intents', () {
      final card = _taskCard();
      final turns = [
        RolePlayTurnOutput(
          characterId: 'c1',
          name: 'A',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: const [],
        ),
      ];

      final capsules = controller.resolve(taskCard: card, turns: turns);
      expect(capsules, isEmpty);
    });

    test('executes character_profile retrieval from task card cast', () {
      final card = _taskCard(
        beliefs: [
          const CharacterBelief(
            holderId: 'char-liuxi',
            targetId: 'char-yueren',
            aspect: '意图',
            value: '隐藏货单',
          ),
        ],
        socialPositions: [
          const SocialPositionSlice(
            characterId: 'char-liuxi',
            role: '调查记者',
            formalRank: '无',
            actualInfluence: '高',
          ),
        ],
      );

      final turns = [
        RolePlayTurnOutput(
          characterId: 'char-liuxi',
          name: '柳溪',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: [
            const RetrievalIntent(
              toolName: RetrievalIntent.kToolCharacterProfile,
              query: '柳溪',
              purpose: '了解立场',
            ),
          ],
        ),
      ];

      final capsules = controller.resolve(taskCard: card, turns: turns);
      expect(capsules, hasLength(1));
      expect(capsules.first.summary, contains('柳溪'));
      expect(capsules.first.summary, contains('调查记者'));
    });

    test('executes relationship retrieval', () {
      final card = _taskCard(
        relationships: [
          const RelationshipSlice(
            characterA: 'char-liuxi',
            characterB: 'char-yueren',
            label: '对峙',
            tension: 7,
            trust: 2,
          ),
        ],
      );

      final turns = [
        RolePlayTurnOutput(
          characterId: 'c1',
          name: 'A',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: [
            const RetrievalIntent(
              toolName: RetrievalIntent.kToolRelationship,
              query: 'char-liuxi',
              purpose: '关系',
            ),
          ],
        ),
      ];

      final capsules = controller.resolve(taskCard: card, turns: turns);
      expect(capsules, hasLength(1));
      expect(capsules.first.summary, contains('对峙'));
      expect(capsules.first.summary, contains('张力7'));
    });

    test('executes world_setting retrieval', () {
      final card = _taskCard();
      final turns = [
        RolePlayTurnOutput(
          characterId: 'c1',
          name: 'A',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: [
            const RetrievalIntent(
              toolName: RetrievalIntent.kToolWorldSetting,
              query: 'old-harbor',
              purpose: '场景设定',
            ),
          ],
        ),
      ];

      final capsules = controller.resolve(taskCard: card, turns: turns);
      expect(capsules, hasLength(1));
      expect(capsules.first.summary, contains('old-harbor'));
    });

    test('executes past_event retrieval from knowledge atoms', () {
      final card = _taskCard(
        knowledge: [
          const KnowledgeAtom(
            id: 'k1',
            category: 'event',
            content: '昨夜码头发生火拼，三死两伤。',
            sourceId: 'scene-prev',
          ),
        ],
      );

      final turns = [
        RolePlayTurnOutput(
          characterId: 'c1',
          name: 'A',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: [
            const RetrievalIntent(
              toolName: RetrievalIntent.kToolPastEvent,
              query: '码头',
              purpose: '前情',
            ),
          ],
        ),
      ];

      final capsules = controller.resolve(taskCard: card, turns: turns);
      expect(capsules, hasLength(1));
      expect(capsules.first.summary, contains('火拼'));
    });

    test('ignores unknown tool names', () {
      final card = _taskCard();
      final turns = [
        RolePlayTurnOutput(
          characterId: 'c1',
          name: 'A',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: [
            const RetrievalIntent(
              toolName: 'hack_system',
              query: '*',
              purpose: '恶意',
            ),
          ],
        ),
      ];

      expect(controller.resolve(taskCard: card, turns: turns), isEmpty);
    });

    test('deduplicates identical tool+query pairs', () {
      final card = _taskCard(
        relationships: [
          const RelationshipSlice(
            characterA: 'char-liuxi',
            characterB: 'char-yueren',
            label: '对峙',
            tension: 5,
            trust: 3,
          ),
        ],
      );

      final turns = [
        RolePlayTurnOutput(
          characterId: 'c1',
          name: 'A',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: [
            const RetrievalIntent(
              toolName: RetrievalIntent.kToolRelationship,
              query: 'char-liuxi',
              purpose: 'p1',
            ),
          ],
        ),
        RolePlayTurnOutput(
          characterId: 'c2',
          name: 'B',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: [
            const RetrievalIntent(
              toolName: RetrievalIntent.kToolRelationship,
              query: 'char-liuxi',
              purpose: 'p2',
            ),
          ],
        ),
      ];

      final capsules = controller.resolve(taskCard: card, turns: turns);
      expect(capsules, hasLength(1));
    });

    test('caps at maximum capsules per cycle', () {
      final card = _taskCard(
        knowledge: [
          for (var i = 0; i < 10; i++)
            KnowledgeAtom(
              id: 'k$i',
              category: 'event',
              content: '事件$i的内容描述',
              sourceId: 'src-$i',
            ),
        ],
      );

      final turns = [
        RolePlayTurnOutput(
          characterId: 'c1',
          name: 'A',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: [
            for (var i = 0; i < 10; i++)
              RetrievalIntent(
                toolName: RetrievalIntent.kToolPastEvent,
                query: '事件$i',
                purpose: 'p$i',
              ),
          ],
        ),
      ];

      final capsules = controller.resolve(taskCard: card, turns: turns);
      expect(capsules.length, 4);
    });

    test('compresses long summaries to token budget', () {
      final longContent = 'A' * 500;
      final card = _taskCard(
        knowledge: [
          KnowledgeAtom(
            id: 'k1',
            category: 'event',
            content: longContent,
            sourceId: 'src',
          ),
        ],
      );

      final turns = [
        RolePlayTurnOutput(
          characterId: 'c1',
          name: 'A',
          stance: 's',
          action: 'a',
          taboo: 't',
          retrievalIntents: [
            const RetrievalIntent(
              toolName: RetrievalIntent.kToolPastEvent,
              query: 'a',
              purpose: 'p',
            ),
          ],
        ),
      ];

      final capsules = controller.resolve(taskCard: card, turns: turns);
      expect(capsules, hasLength(1));
      expect(capsules.first.summary.length, lessThanOrEqualTo(120));
      expect(capsules.first.summary, endsWith('...'));
    });
  });

  // =========================================================================
  // DynamicRoleAgentRunner (cognition context)
  // =========================================================================
  group('DynamicRoleAgentRunner cognition context', () {
    test(
      'includes beliefs, relationships, social position in prompt',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final roleplay = _defaultRoleplayResponse(request);
            if (roleplay != null) return roleplay;
            throw StateError('Unexpected prompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final runner = DynamicRoleAgentRunner(settingsStore: settingsStore);
        final brief = _brief();
        final cast = [
          _castMember(),
          _castMember(characterId: 'char-yueren', name: '岳刃', role: '走私联络人'),
        ];
        final director = const SceneDirectorOutput(text: '目标：逼问\n冲突：顶压');

        final taskCard = SceneTaskCard(
          brief: brief,
          cast: cast,
          directorPlan: director.text,
          beliefs: [
            const CharacterBelief(
              holderId: 'char-liuxi',
              targetId: 'char-yueren',
              aspect: '忠诚度',
              value: '不可信',
            ),
          ],
          relationships: [
            const RelationshipSlice(
              characterA: 'char-liuxi',
              characterB: 'char-yueren',
              label: '对峙',
              tension: 8,
              trust: 1,
            ),
          ],
          socialPositions: [
            const SocialPositionSlice(
              characterId: 'char-liuxi',
              role: '调查记者',
              formalRank: '无',
              actualInfluence: '高',
            ),
          ],
        );

        await runner.run(
          brief: brief,
          cast: cast,
          director: director,
          taskCard: taskCard,
        );

        // Verify the prompt for char-liuxi includes cognition data
        final liuxiRequest = fakeClient.requests.firstWhere(
          (r) => r.messages.last.content.contains('柳溪'),
        );
        final userPrompt = liuxiRequest.messages.last.content;
        expect(userPrompt, contains('信念：'));
        expect(userPrompt, contains('不可信'));
        expect(userPrompt, contains('关系：'));
        expect(userPrompt, contains('对峙'));
        expect(userPrompt, contains('社会位置：'));
        expect(userPrompt, contains('高'));

        // Verify system prompt uses the current structured role-turn shape.
        final systemPrompt = liuxiRequest.messages.first.content;
        expect(systemPrompt, contains('Use this five-line shape'));
      },
    );

    test('omits cognition context when taskCard is null', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final roleplay = _defaultRoleplayResponse(request);
          if (roleplay != null) return roleplay;
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final runner = DynamicRoleAgentRunner(settingsStore: settingsStore);

      await runner.run(
        brief: _brief(),
        cast: [_castMember()],
        director: const SceneDirectorOutput(text: '目标：逼问'),
      );

      final request = fakeClient.requests.first;
      final userPrompt = request.messages.last.content;
      expect(userPrompt, isNot(contains('信念：')));
      expect(userPrompt, isNot(contains('关系：')));

      final systemPrompt = request.messages.first.content;
      expect(systemPrompt, contains('Use this five-line shape'));
      expect(systemPrompt, isNot(contains('检索')));
    });

    test(
      'returns roleplay output without retrieval intents by default',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final roleplay = _defaultRoleplayResponse(request);
            if (roleplay != null) return roleplay;
            throw StateError('Unexpected prompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final runner = DynamicRoleAgentRunner(settingsStore: settingsStore);

        final outputs = await runner.run(
          brief: _brief(),
          cast: [_castMember()],
          director: const SceneDirectorOutput(text: '目标：逼问'),
        );

        expect(outputs, hasLength(1));
        final turn = RolePlayTurnOutput.fromDynamicAgentOutput(outputs.first);
        expect(turn.retrievalIntents, isEmpty);
      },
    );
  });

  // =========================================================================
  // SceneStateResolver
  // =========================================================================
  group('SceneStateResolver', () {
    test('parses structured beat output from LLM', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text:
                  '[叙述] @narrator 雨夜的仓库门外，柳溪挡住了岳刃的去路。\n'
                  '[对白] @char-liuxi 你把货单藏哪了\n'
                  '[动作] @char-yueren 转身想走\n'
                  '[心理] @char-liuxi 不能让他跑了\n'
                  '[事实] @narrator 货单在仓库的铁柜里',
            );
          }
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final resolver = SceneStateResolver(settingsStore: settingsStore);
      final beats = await resolver.resolve(
        taskCard: _taskCard(),
        roleTurns: [],
        capsules: const [],
      );

      expect(beats, hasLength(5));
      expect(beats[0].kind, SceneBeatKind.narration);
      expect(beats[0].sourceCharacterId, 'narrator');
      expect(beats[1].kind, SceneBeatKind.dialogue);
      expect(beats[1].sourceCharacterId, 'char-liuxi');
      expect(beats[2].kind, SceneBeatKind.action);
      expect(beats[3].kind, SceneBeatKind.internal);
      expect(beats[4].kind, SceneBeatKind.fact);
      expect(beats[4].content, '货单在仓库的铁柜里');

      // Verify order is preserved
      for (var i = 0; i < beats.length; i++) {
        expect(beats[i].order, i);
      }
    });

    test('falls back to beats from role turns on LLM failure', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'Connection reset',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final resolver = SceneStateResolver(settingsStore: settingsStore);
      final beats = await resolver.resolve(
        taskCard: _taskCard(),
        roleTurns: [
          RolePlayTurnOutput(
            characterId: 'char-liuxi',
            name: '柳溪',
            stance: '压迫',
            action: '逼近半步',
            taboo: '拖延',
            retrievalIntents: const [],
            disclosure: '你今晚走不了',
          ),
        ],
        capsules: const [],
      );

      // Expect narration beat (from summary), fact beat (from director plan),
      // action beat (from turn action), dialogue beat (from disclosure)
      expect(beats.length, greaterThanOrEqualTo(3));
      expect(beats.first.kind, SceneBeatKind.narration);
      expect(beats.first.sourceCharacterId, 'narrator');
      expect(beats.any((b) => b.kind == SceneBeatKind.action), isTrue);
      expect(beats.any((b) => b.kind == SceneBeatKind.dialogue), isTrue);
    });

    test(
      'limits beat resolve escalation before falling back on timeout',
      () async {
        var callCount = 0;
        final fakeClient = FakeAppLlmClient(
          responder: (_) {
            callCount += 1;
            if (callCount == 1) {
              return const AppLlmChatResult.success(text: '');
            }
            return const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.timeout,
              detail: 'timed out',
            );
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final resolver = SceneStateResolver(settingsStore: settingsStore);
        final beats = await resolver.resolve(
          taskCard: _taskCard(),
          roleTurns: [
            RolePlayTurnOutput(
              characterId: 'char-liuxi',
              name: '柳溪',
              stance: '压迫',
              action: '逼近半步',
              taboo: '',
              retrievalIntents: const [],
              disclosure: '你今晚走不了',
            ),
          ],
          capsules: const [],
        );

        expect(beats.any((b) => b.kind == SceneBeatKind.action), isTrue);
        expect(fakeClient.requests.map((r) => r.maxTokens), [1024, 4096]);
      },
    );

    test('skips beats with empty content', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[动作] @char-liuxi\n[对白] @char-yueren \n[事实] @narrator 有效内容',
            );
          }
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final resolver = SceneStateResolver(settingsStore: settingsStore);
      final beats = await resolver.resolve(
        taskCard: _taskCard(),
        roleTurns: [],
        capsules: const [],
      );

      expect(beats, hasLength(1));
      expect(beats.first.content, '有效内容');
    });

    test('assigns narrator as default when no @characterId present', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(text: '[叙述] 夜色深沉\n[事实] 雨还在下');
          }
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final resolver = SceneStateResolver(settingsStore: settingsStore);
      final beats = await resolver.resolve(
        taskCard: _taskCard(),
        roleTurns: [],
        capsules: const [],
      );

      expect(beats, hasLength(2));
      expect(beats.every((b) => b.sourceCharacterId == 'narrator'), isTrue);
    });
  });

  // =========================================================================
  // SceneEditorialGenerator
  // =========================================================================
  group('SceneEditorialGenerator', () {
    test('sends resolved beats to LLM and returns editorial draft', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene editor')) {
            return const AppLlmChatResult.success(
              text: '雨夜仓库门外，柳溪挡住了岳刃的去路。"货单呢？"她逼近一步。岳刃转身想走，却被堵在墙角。',
            );
          }
          throw StateError('Unexpected prompt: $systemPrompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final generator = SceneEditorialGenerator(settingsStore: settingsStore);
      final draft = await generator.generate(
        taskCard: _taskCard(),
        resolvedBeats: const [
          SceneBeat(
            kind: SceneBeatKind.narration,
            content: '雨夜',
            sourceCharacterId: 'narrator',
          ),
          SceneBeat(
            kind: SceneBeatKind.dialogue,
            content: '货单呢',
            sourceCharacterId: 'char-liuxi',
          ),
          SceneBeat(
            kind: SceneBeatKind.action,
            content: '转身想走',
            sourceCharacterId: 'char-yueren',
          ),
        ],
        capsules: const [],
        attempt: 1,
      );

      expect(draft.text, contains('柳溪'));
      expect(draft.beatCount, 3);
      expect(draft.attempt, 1);

      // Verify prompt contains beats not raw role summaries
      final userPrompt = fakeClient.requests.last.messages.last.content;
      expect(userPrompt, contains('场景拍：'));
      expect(userPrompt, contains('[叙述]'));
      expect(userPrompt, contains('[对白]'));
      expect(userPrompt, contains('[动作]'));
    });

    test('includes review feedback on rewrite attempts', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene editor')) {
            final userPrompt = request.messages.last.content;
            if (userPrompt.contains('编辑反馈')) {
              return const AppLlmChatResult.success(text: '修改后正文');
            }
            return const AppLlmChatResult.success(text: '初始正文');
          }
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final generator = SceneEditorialGenerator(settingsStore: settingsStore);
      final draft = await generator.generate(
        taskCard: _taskCard(),
        resolvedBeats: const [
          SceneBeat(
            kind: SceneBeatKind.fact,
            content: 'f',
            sourceCharacterId: 'n',
          ),
        ],
        capsules: const [],
        attempt: 2,
        reviewFeedback: '冲突不够强烈',
      );

      expect(draft.text, '修改后正文');
      final userPrompt = fakeClient.requests.last.messages.last.content;
      expect(userPrompt, contains('编辑反馈：冲突不够强烈'));
    });

    test('includes capsule context when present', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene editor')) {
            return const AppLlmChatResult.success(text: '带上下文正文');
          }
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final generator = SceneEditorialGenerator(settingsStore: settingsStore);
      await generator.generate(
        taskCard: _taskCard(),
        resolvedBeats: const [],
        capsules: const [
          ContextCapsule(
            intent: RetrievalIntent(
              toolName: 'relationship',
              query: 'q',
              purpose: 'p',
            ),
            summary: '柳溪与岳刃对峙',
            tokenBudget: 100,
          ),
        ],
        attempt: 1,
      );

      final userPrompt = fakeClient.requests.last.messages.last.content;
      expect(userPrompt, contains('上下文'));
      expect(userPrompt, contains('柳溪与岳刃对峙'));
    });

    test(
      'uses roleplay prose draft as the editorial base when present',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            if (systemPrompt.contains('scene editor')) {
              final userPrompt = request.messages.last.content;
              expect(userPrompt, contains('角色扮演正文草稿：'));
              expect(userPrompt, contains('柳溪把旧照片压在雨水里'));
              expect(userPrompt, contains('润色边界：'));
              return const AppLlmChatResult.success(text: '润色后的角色草稿正文');
            }
            throw StateError('Unexpected prompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final generator = SceneEditorialGenerator(settingsStore: settingsStore);
        final draft = await generator.generate(
          taskCard: _taskCard(),
          resolvedBeats: const [
            SceneBeat(
              kind: SceneBeatKind.action,
              content: '柳溪逼近岳刃',
              sourceCharacterId: 'char-liuxi',
            ),
          ],
          capsules: const [],
          attempt: 1,
          roleplaySession: SceneRoleplaySession(
            chapterId: 'chapter-01',
            sceneId: 'scene-01',
            sceneTitle: '仓库门外',
            rounds: [
              SceneRoleplayRound(
                round: 1,
                turns: [
                  SceneRoleplayTurn(
                    round: 1,
                    characterId: 'char-liuxi',
                    name: '柳溪',
                    intent: '逼问货单',
                    visibleAction: '柳溪逼近岳刃',
                    dialogue: '货单在哪',
                    innerState: '先压住退路。',
                    proseFragment: '柳溪把旧照片压在雨水里，鞋尖抵住岳刃后退的路。“货单在哪？”',
                    taboo: '',
                    rawText: '',
                  ),
                ],
                arbitration: SceneRoleplayArbitration(
                  fact: '柳溪逼近岳刃并追问货单',
                  state: '岳刃被迫应对',
                  pressure: '升级',
                  nextPublicState: '柳溪掌握主动',
                  shouldStop: true,
                  rawText: '',
                ),
              ),
            ],
          ),
        );

        expect(draft.text, '润色后的角色草稿正文');
      },
    );

    test('throws on LLM failure', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          detail: 'Server error',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final generator = SceneEditorialGenerator(settingsStore: settingsStore);

      await expectLater(
        generator.generate(
          taskCard: _taskCard(),
          resolvedBeats: const [],
          capsules: const [],
          attempt: 1,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // =========================================================================
  // ScenePipelineOrchestrator - full pipeline integration
  // =========================================================================
  group('ScenePipelineOrchestrator', () {
    test(
      'runs full pipeline end to end and produces all intermediates',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(
                text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
              );
            }
            final roleplay = _defaultRoleplayResponse(request);
            if (roleplay != null) return roleplay;
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text:
                    '[叙述] @narrator 雨夜码头\n'
                    '[对白] @char-liuxi 货单在哪\n'
                    '[动作] @char-yueren 沉默不语\n'
                    '[事实] @narrator 岳刃知道货单的位置',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(
                text: '柳溪在雨中拦住岳刃。"货单在哪？"她逼近一步。岳刃沉默不语，目光闪烁。',
              );
            }
            if (systemPrompt.contains('scene judge review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：冲突成立。');
            }
            if (systemPrompt.contains('scene consistency review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：动线一致。');
            }

            throw StateError('Unexpected prompt: $systemPrompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final orchestrator = ScenePipelineOrchestrator(
          settingsStore: settingsStore,
        );

        final result = await orchestrator.runScene(_brief());

        // Verify all pipeline intermediates exist
        expect(result.taskCard.brief.sceneId, 'scene-01');
        expect(result.taskCard.directorPlan, contains('目标'));
        expect(result.roleTurns, isNotEmpty);
        expect(result.resolvedBeats, hasLength(4));
        expect(result.resolvedBeats.first.kind, SceneBeatKind.narration);
        expect(result.editorialDraft.text, contains('柳溪'));
        expect(result.editorialDraft.beatCount, 4);
        expect(result.review.decision, SceneReviewDecision.pass);
        expect(result.proseAttempts, 1);
        expect(result.softFailureCount, 0);
      },
    );

    test('pipeline retries editorial on soft review failure', () async {
      var editorialAttempts = 0;
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;

          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
            );
          }
          final roleplay = _defaultRoleplayResponse(request);
          if (roleplay != null) return roleplay;
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[叙述] @narrator 场景开始\n[对白] @char-liuxi 说话',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            editorialAttempts += 1;
            return AppLlmChatResult.success(
              text: editorialAttempts == 1 ? '第一版正文：冲突不够' : '第二版正文：柳溪逼近，冲突升级。',
            );
          }
          if (systemPrompt.contains('scene judge review')) {
            final userPrompt = request.messages.last.content;
            return AppLlmChatResult.success(
              text: userPrompt.contains('第一版')
                  ? '决定：REWRITE_PROSE\n原因：冲突升级不足。'
                  : '决定：PASS\n原因：冲突升级成立。',
            );
          }
          if (systemPrompt.contains('scene consistency review')) {
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：一致。');
          }

          throw StateError('Unexpected: $systemPrompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = ScenePipelineOrchestrator(
        settingsStore: settingsStore,
        maxProseRetries: 2,
      );

      final result = await orchestrator.runScene(_brief());

      expect(result.review.decision, SceneReviewDecision.pass);
      expect(result.proseAttempts, 2);
      expect(result.softFailureCount, 1);
      expect(result.editorialDraft.text, contains('第二版'));
    });

    test(
      'pipeline passes character cognition data through task card',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(
                text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
              );
            }
            final roleplay = _defaultRoleplayResponse(request);
            if (roleplay != null) return roleplay;
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[对白] @char-liuxi 你说谎\n[心理] @char-yueren 被识破了',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(text: '编辑正文');
            }
            if (systemPrompt.contains('review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。');
            }

            throw StateError('Unexpected: $systemPrompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final orchestrator = ScenePipelineOrchestrator(
          settingsStore: settingsStore,
        );

        final result = await orchestrator.runScene(
          _brief(),
          beliefs: [
            const CharacterBelief(
              holderId: 'char-liuxi',
              targetId: 'char-yueren',
              aspect: '诚实度',
              value: '经常说谎',
            ),
          ],
          relationships: [
            const RelationshipSlice(
              characterA: 'char-liuxi',
              characterB: 'char-yueren',
              label: '审讯',
              tension: 9,
              trust: 0,
            ),
          ],
          socialPositions: [
            const SocialPositionSlice(
              characterId: 'char-liuxi',
              role: '调查记者',
              formalRank: '无',
              actualInfluence: '高',
            ),
          ],
        );

        expect(result.taskCard.beliefs, hasLength(1));
        expect(result.taskCard.beliefs.first.value, '经常说谎');
        expect(result.taskCard.relationships.first.tension, 9);
        expect(result.taskCard.socialPositions.first.actualInfluence, '高');
      },
    );

    test(
      'pipeline preserves capsules from retrieval intents in role turns',
      () async {
        // The existing DynamicRoleAgentRunner doesn't emit retrieval intents,
        // so capsules will be empty. But the pipeline should still handle this
        // gracefully.
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(
                text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
              );
            }
            final roleplay = _defaultRoleplayResponse(request);
            if (roleplay != null) return roleplay;
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[叙述] @narrator 场景\n[事实] @narrator 事件',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(text: '最终正文');
            }
            if (systemPrompt.contains('review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。');
            }

            throw StateError('Unexpected: $systemPrompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final orchestrator = ScenePipelineOrchestrator(
          settingsStore: settingsStore,
        );

        final result = await orchestrator.runScene(
          _brief(),
          knowledge: [
            const KnowledgeAtom(
              id: 'k1',
              category: 'event',
              content: '前情提要',
              sourceId: 'prev',
            ),
          ],
        );

        // No retrieval intents → empty capsules
        expect(result.capsules, isEmpty);
        // But knowledge is preserved in the task card
        expect(result.taskCard.knowledge, hasLength(1));
      },
    );

    test(
      'pipeline keeps roleplay turns free of implicit retrieval intents',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(
                text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
              );
            }

            final roleplay = _defaultRoleplayResponse(request);
            if (roleplay != null) return roleplay;

            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[叙述] @narrator 场景开始\n[对白] @char-liuxi 说话',
              );
            }

            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(text: '最终正文');
            }

            if (systemPrompt.contains('review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。');
            }

            throw StateError('Unexpected: $systemPrompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final orchestrator = ScenePipelineOrchestrator(
          settingsStore: settingsStore,
        );

        final result = await orchestrator.runScene(
          _brief(),
          relationships: [
            const RelationshipSlice(
              characterA: 'char-liuxi',
              characterB: 'char-yueren',
              label: '对峙',
              tension: 8,
              trust: 1,
            ),
          ],
        );

        // The current role-turn skill keeps retrieval out of the four-line
        // roleplay output; retrieval coverage is exercised by RetrievalController.
        expect(
          result.roleTurns.every((t) => t.retrievalIntents.isEmpty),
          isTrue,
        );
        expect(result.capsules, isEmpty);
      },
    );
  });

  // =========================================================================
  // SceneDirectorPlan model
  // =========================================================================
  group('SceneDirectorPlan', () {
    test('tryParse succeeds on valid 4-line format', () {
      const text = '目标：逼出货单\n冲突：柳溪与岳刃对峙\n推进：施压→松动\n约束：不离题';
      final plan = SceneDirectorPlan.tryParse(text)!;
      expect(plan, isNotNull);
      expect(plan.target, '逼出货单');
      expect(plan.conflict, '柳溪与岳刃对峙');
      expect(plan.progression, '施压→松动');
      expect(plan.constraints, '不离题');
    });

    test('tryParse returns null on missing lines', () {
      expect(SceneDirectorPlan.tryParse('目标：a\n冲突：b'), isNull);
    });

    test('tryParse returns null on wrong prefixes', () {
      expect(SceneDirectorPlan.tryParse('目标：a\n摘要：b\n推进：c\n约束：d'), isNull);
    });

    test('toText reconstructs the 4-line format', () {
      final plan = SceneDirectorPlan(
        target: '逼问',
        conflict: '顶压',
        progression: '失守',
        constraints: '不离题',
      );
      expect(plan.toText(), '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题');
    });

    test('noteFor returns matching character note', () {
      final plan = SceneDirectorPlan(
        target: 't',
        conflict: 'c',
        progression: 'p',
        constraints: 'k',
        characterNotes: [
          const DirectorCharacterNote(
            characterId: 'char-liuxi',
            name: '柳溪',
            motivation: '逼出货单',
            emotionalArc: '冷静→施压',
            keyAction: '堵住退路',
          ),
          const DirectorCharacterNote(
            characterId: 'char-yueren',
            name: '岳刃',
            motivation: '保护自己',
          ),
        ],
      );
      expect(plan.noteFor('char-liuxi'), isNotNull);
      expect(plan.noteFor('char-liuxi')!.motivation, '逼出货单');
      expect(plan.noteFor('char-yueren')!.name, '岳刃');
      expect(plan.noteFor('nonexistent'), isNull);
    });

    test('character notes list is immutable', () {
      final plan = SceneDirectorPlan(
        target: 't',
        conflict: 'c',
        progression: 'p',
        constraints: 'k',
        characterNotes: [
          const DirectorCharacterNote(characterId: 'c1', name: 'A'),
        ],
      );
      expect(
        () => plan.characterNotes.add(
          const DirectorCharacterNote(characterId: 'c2', name: 'B'),
        ),
        throwsUnsupportedError,
      );
    });
  });

  // =========================================================================
  // SceneDirectorOrchestrator (enhanced)
  // =========================================================================
  group('SceneDirectorOrchestrator', () {
    test('produces structured plan with character notes and tone', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text:
                  '目标：逼出货单去向\n冲突：柳溪(调查记者)与岳刃(走私联络人)对峙\n推进：柳溪施压→岳刃防线松动\n约束：遵守old-harbor规则',
            );
          }
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(
        brief: _brief(),
        cast: [
          _castMember(),
          _castMember(characterId: 'char-yueren', name: '岳刃', role: '走私联络人'),
        ],
      );

      // Text is the polished plan
      expect(output.text, contains('目标'));
      expect(output.text, contains('冲突'));

      // Structured plan is parsed
      expect(output.plan, isNotNull);
      expect(output.plan!.target, '逼出货单去向');
      expect(output.plan!.conflict, contains('柳溪'));

      // Character notes for each cast member
      expect(output.plan!.characterNotes, hasLength(2));
      expect(output.plan!.noteFor('char-liuxi'), isNotNull);
      expect(output.plan!.noteFor('char-yueren'), isNotNull);
      expect(output.plan!.noteFor('char-liuxi')!.motivation, isNotEmpty);
      expect(output.plan!.noteFor('char-liuxi')!.emotionalArc, isNotEmpty);
      expect(output.plan!.noteFor('char-liuxi')!.keyAction, isNotEmpty);

      // Tone is inferred from scene summary
      expect(output.plan!.tone, isNotEmpty);
    });

    test(
      'infers tension tone from scene summary with conflict keywords',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'timeout',
          ),
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final tense = SceneBrief(
          chapterId: 'c1',
          chapterTitle: '第1章',
          sceneId: 's1',
          sceneTitle: '对峙',
          sceneSummary: '柳溪拦住岳刃，逼问货单去向。',
        );

        final orchestrator = SceneDirectorOrchestrator(
          settingsStore: settingsStore,
        );
        final output = await orchestrator.run(brief: tense, cast: []);

        expect(output.plan!.tone, '紧张');
      },
    );

    test('infers calm tone from peaceful scene summary', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timeout',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final calm = SceneBrief(
        chapterId: 'c1',
        chapterTitle: '第1章',
        sceneId: 's1',
        sceneTitle: '回忆',
        sceneSummary: '柳溪回忆起童年时光，在宁静的河边闲聊。',
      );

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(brief: calm, cast: []);

      expect(output.plan!.tone, '平和');
    });

    test('infers fast pacing for short scenes', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timeout',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final short = SceneBrief(
        chapterId: 'c1',
        chapterTitle: '第1章',
        sceneId: 's1',
        sceneTitle: '突发',
        sceneSummary: '一声枪响。',
        targetLength: 200,
      );

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(brief: short, cast: []);

      expect(output.plan!.pacing, ScenePacing.fast);
    });

    test('builds richer local plan with cast roles', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timeout',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(
        brief: _brief(),
        cast: [
          _castMember(),
          _castMember(characterId: 'char-yueren', name: '岳刃', role: '走私联络人'),
        ],
      );

      // Local plan should reference character roles
      expect(output.text, contains('柳溪'));
      expect(output.text, contains('岳刃'));
      expect(output.text, contains('调查记者'));
      expect(output.text, contains('走私联络人'));
    });

    test('falls back gracefully when plan is unparseable', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text: 'This is not a structured plan at all.',
            );
          }
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(brief: _brief(), cast: []);

      // Falls back to local plan which IS structured
      expect(output.text, contains('目标：'));
      expect(output.plan, isNotNull);
      expect(output.plan!.target, isNotEmpty);
    });
  });

  // =========================================================================
  // Enhanced role agent: character direction notes in prompt
  // =========================================================================
  group('DynamicRoleAgentRunner with director character notes', () {
    test(
      'includes character motivation, emotional arc, key action in prompt',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final roleplay = _defaultRoleplayResponse(request);
            if (roleplay != null) return roleplay;
            throw StateError('Unexpected prompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final runner = DynamicRoleAgentRunner(settingsStore: settingsStore);
        final brief = _brief();
        final cast = [
          _castMember(),
          _castMember(characterId: 'char-yueren', name: '岳刃', role: '走私联络人'),
        ];

        final taskCard = SceneTaskCard(
          brief: brief,
          cast: cast,
          directorPlan: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
          directorPlanParsed: SceneDirectorPlan(
            target: '逼问',
            conflict: '顶压',
            progression: '失守',
            constraints: '不离题',
            tone: '紧张',
            characterNotes: [
              const DirectorCharacterNote(
                characterId: 'char-liuxi',
                name: '柳溪',
                motivation: '逼出货单',
                emotionalArc: '冷静→施压→紧逼',
                keyAction: '堵住退路',
              ),
              const DirectorCharacterNote(
                characterId: 'char-yueren',
                name: '岳刃',
                motivation: '保护自己',
                emotionalArc: '戒备→动摇',
                keyAction: '隐瞒信息',
              ),
            ],
          ),
        );

        await runner.run(
          brief: brief,
          cast: cast,
          director: SceneDirectorOutput(
            text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
            plan: taskCard.directorPlanParsed,
          ),
        );

        // Verify char-liuxi prompt includes her direction notes
        final liuxiRequest = fakeClient.requests.firstWhere(
          (r) => r.messages.last.content.contains('柳溪'),
        );
        final userPrompt = liuxiRequest.messages.last.content;
        expect(userPrompt, contains('动机=逼出货单'));
        expect(userPrompt, contains('情绪=冷静→施压→紧逼'));
        expect(userPrompt, contains('当前冲动=堵住退路'));
      },
    );
  });

  // =========================================================================
  // Enhanced state resolver: tone and pacing in prompt
  // =========================================================================
  group('SceneStateResolver with tone and pacing', () {
    test('includes tone and pacing when director plan is parsed', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene beat resolver')) {
            // Verify tone and pacing are in the user prompt
            final userPrompt = request.messages.last.content;
            expect(userPrompt, contains('基调：紧张'));
            expect(userPrompt, contains('节奏：'));
            return const AppLlmChatResult.success(
              text: '[叙述] @narrator 雨夜场景\n[对白] @char-liuxi 说话',
            );
          }
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final resolver = SceneStateResolver(settingsStore: settingsStore);
      await resolver.resolve(
        taskCard: SceneTaskCard(
          brief: _brief(),
          cast: [_castMember()],
          directorPlan: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
          directorPlanParsed: SceneDirectorPlan(
            target: '逼问',
            conflict: '顶压',
            progression: '失守',
            constraints: '不离题',
            tone: '紧张',
            pacing: ScenePacing.fast,
          ),
        ),
        roleTurns: [],
        capsules: const [],
      );
    });

    test('omits tone/pacing when directorPlanParsed is null', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          if (systemPrompt.contains('scene beat resolver')) {
            final userPrompt = request.messages.last.content;
            expect(userPrompt, isNot(contains('基调：')));
            expect(userPrompt, isNot(contains('节奏：')));
            return const AppLlmChatResult.success(
              text: '[叙述] @narrator 场景\n[事实] @narrator 事件',
            );
          }
          throw StateError('Unexpected prompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final resolver = SceneStateResolver(settingsStore: settingsStore);
      final taskCard = SceneTaskCard(
        brief: SceneBrief(
          chapterId: 'ch1',
          chapterTitle: 'Chapter 1',
          sceneId: 's1',
          sceneTitle: 'Scene 1',
          sceneSummary: 'Test',
        ),
        cast: [],
      );
      await resolver.resolve(
        taskCard: taskCard,
        roleTurns: [],
        capsules: const [],
      );
    });
  });

  // =========================================================================
  // ReplanRouter (Task 11)
  // =========================================================================
  group('ReplanRouter', () {
    DirectorRoundState roundState({int round = 0, int maxRounds = 3}) {
      return DirectorRoundState(
        sceneId: 'scene-01',
        round: round,
        maxRounds: maxRounds,
      );
    }

    test('pass decision returns ReplanRoute.pass', () {
      final outcome = ReplanRouter.resolve(
        decision: SceneReviewDecision.pass,
        currentRoundState: roundState(),
      );
      expect(outcome.route, ReplanRoute.pass);
      expect(outcome.message, contains('passed'));
      expect(outcome.updatedRoundState.round, 0);
    });

    test('rewriteProse decision returns ReplanRoute.rewrite', () {
      final outcome = ReplanRouter.resolve(
        decision: SceneReviewDecision.rewriteProse,
        currentRoundState: roundState(),
      );
      expect(outcome.route, ReplanRoute.rewrite);
      expect(outcome.message, contains('rewrite'));
      expect(outcome.updatedRoundState.round, 0);
    });

    test('replanScene at round 0 returns ReplanRoute.replan', () {
      final outcome = ReplanRouter.resolve(
        decision: SceneReviewDecision.replanScene,
        currentRoundState: roundState(round: 0),
      );
      expect(outcome.route, ReplanRoute.replan);
      expect(outcome.updatedRoundState.round, 1);
      expect(outcome.message, contains('round 1/3'));
    });

    test('replanScene at round 2 (max 3) returns ReplanRoute.replan', () {
      final outcome = ReplanRouter.resolve(
        decision: SceneReviewDecision.replanScene,
        currentRoundState: roundState(round: 2),
      );
      expect(outcome.route, ReplanRoute.replan);
      expect(outcome.updatedRoundState.round, 3);
    });

    test('replanScene at round 3 (max 3) returns ReplanRoute.blocked', () {
      final outcome = ReplanRouter.resolve(
        decision: SceneReviewDecision.replanScene,
        currentRoundState: roundState(round: 3),
      );
      expect(outcome.route, ReplanRoute.blocked);
      expect(outcome.message, contains('blocked'));
      expect(outcome.message, contains('3 replan rounds'));
    });

    test('blocked state includes clear message', () {
      final outcome = ReplanRouter.resolve(
        decision: SceneReviewDecision.replanScene,
        currentRoundState: DirectorRoundState(
          sceneId: 'scene-climax',
          round: 5,
          maxRounds: 3,
        ),
      );
      expect(outcome.route, ReplanRoute.blocked);
      expect(outcome.message, contains('scene-climax'));
      expect(outcome.message, contains('could not be satisfied'));
    });

    test('round state is correctly incremented on replan', () {
      var state = roundState(round: 0);
      // maxRounds=3 allows rounds 0, 1, 2 to replan; round 3 blocks
      for (var i = 1; i <= 3; i++) {
        final outcome = ReplanRouter.resolve(
          decision: SceneReviewDecision.replanScene,
          currentRoundState: state,
        );
        expect(outcome.route, ReplanRoute.replan);
        expect(outcome.updatedRoundState.round, i);
        state = outcome.updatedRoundState;
      }
      // round 3 → nextRound=4 > 3, should block
      final blocked = ReplanRouter.resolve(
        decision: SceneReviewDecision.replanScene,
        currentRoundState: state,
      );
      expect(blocked.route, ReplanRoute.blocked);
    });

    test('custom maxRetries is respected', () {
      // maxRetries = 5, round = 4 → should replan to 5
      final replan = ReplanRouter.resolve(
        decision: SceneReviewDecision.replanScene,
        currentRoundState: roundState(round: 4, maxRounds: 5),
        maxRetries: 5,
      );
      expect(replan.route, ReplanRoute.replan);
      expect(replan.updatedRoundState.round, 5);

      // round = 5 → should block
      final blocked = ReplanRouter.resolve(
        decision: SceneReviewDecision.replanScene,
        currentRoundState: roundState(round: 5, maxRounds: 5),
        maxRetries: 5,
      );
      expect(blocked.route, ReplanRoute.blocked);
      expect(blocked.message, contains('5 replan rounds'));
    });

    test('maxRetries=1 allows exactly one replan then blocks', () {
      // maxRetries=1: round 0 → nextRound=1, 1 > 1 = false → replan allowed
      final replan = ReplanRouter.resolve(
        decision: SceneReviewDecision.replanScene,
        currentRoundState: roundState(round: 0),
        maxRetries: 1,
      );
      expect(replan.route, ReplanRoute.replan);
      expect(replan.updatedRoundState.round, 1);

      // round 1 → nextRound=2, 2 > 1 = true → blocked
      final blocked = ReplanRouter.resolve(
        decision: SceneReviewDecision.replanScene,
        currentRoundState: roundState(round: 1),
        maxRetries: 1,
      );
      expect(blocked.route, ReplanRoute.blocked);
    });
  });
}
