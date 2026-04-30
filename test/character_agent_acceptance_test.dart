import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/dynamic_role_agent_runner.dart';
import 'package:novel_writer/features/story_generation/data/retrieval_controller.dart';
import 'package:novel_writer/features/story_generation/data/scene_editorial_generator.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/scene_state_resolver.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';

import 'test_support/fake_app_llm_client.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

SceneBrief _brief() => SceneBrief(
  chapterId: 'chapter-01',
  chapterTitle: '第一章',
  sceneId: 'scene-01',
  sceneTitle: '仓库门外',
  sceneSummary: '柳溪拦住岳刃逼问货单。',
  targetBeat: '拿到账单去向。',
  worldNodeIds: const ['old-harbor'],
  cast: [
    SceneCastCandidate(
      characterId: 'char-liuxi',
      name: '柳溪',
      role: '调查记者',
      participation: const SceneCastParticipation(action: '挡住退路'),
    ),
    SceneCastCandidate(
      characterId: 'char-yueren',
      name: '岳刃',
      role: '走私联络人',
      participation: const SceneCastParticipation(dialogue: '不该来。'),
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
  directorPlan: '目标：逼问\n冲突：顶压',
  beliefs: beliefs,
  relationships: relationships,
  socialPositions: socialPositions,
  knowledge: knowledge,
);

AppLlmChatResult? _defaultArbitrationResponse(AppLlmChatRequest request) {
  if (!request.messages.last.content.contains('任务：scene_roleplay_arbitrate')) {
    return null;
  }
  return const AppLlmChatResult.success(
    text: '事实：柳溪推进逼问\n状态：对峙延续\n压力：升级\n收束：是',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ===========================================================================
  // AT-1: Structured roleplay output
  // Given a scene task card and a character runtime state,
  // When a role agent runs,
  // Then the output must be structured as roleplay turn data, not free-form
  // prose.
  // ===========================================================================
  group('AT-1: Structured roleplay output', () {
    test('structured stance/action/taboo lines parse into typed fields', () {
      final output = DynamicRoleAgentOutput(
        characterId: 'char-liuxi',
        name: '柳溪',
        text: '立场：压迫\n动作：逼近半步\n禁忌：拖延',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

      expect(turn.stance, '压迫');
      expect(turn.action, '逼近半步');
      expect(turn.taboo, '拖延');
      expect(turn.retrievalIntents, isEmpty);
    });

    test('free-form prose produces empty structured fields (detectable)', () {
      final output = DynamicRoleAgentOutput(
        characterId: 'char-liuxi',
        name: '柳溪',
        text: '柳溪站在雨中，心中充满怀疑。她决定逼问货单。',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

      // Free-form text has no structured fields → caller can detect the
      // formatting violation.
      expect(turn.stance, isEmpty);
      expect(turn.action, isEmpty);
      expect(turn.taboo, isEmpty);
    });

    test(
      'mixed structured and unstructured output extracts only tagged lines',
      () {
        final output = DynamicRoleAgentOutput(
          characterId: 'char-liuxi',
          name: '柳溪',
          text: '立场：压迫\n这段是多余的散文\n动作：逼近\n禁忌：拖延',
        );
        final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

        expect(turn.stance, '压迫');
        expect(turn.action, '逼近');
        expect(turn.taboo, '拖延');
      },
    );
  });

  // ===========================================================================
  // AT-2: On-demand retrieval intent
  // Given insufficient local context,
  // When a role agent runs,
  // Then it may emit a retrieval intent instead of guessing.
  // ===========================================================================
  group('AT-2: On-demand retrieval intent', () {
    test('role agent can emit a retrieval intent for missing context', () {
      final output = DynamicRoleAgentOutput(
        characterId: 'char-liuxi',
        name: '柳溪',
        text:
            '立场：压迫\n动作：逼近\n禁忌：拖延'
            '\n检索：character_profile|岳刃|了解意图',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

      expect(turn.stance, '压迫');
      expect(turn.retrievalIntents, hasLength(1));
      expect(turn.retrievalIntents.first.toolName, 'character_profile');
      expect(turn.retrievalIntents.first.query, '岳刃');
      expect(turn.retrievalIntents.first.purpose, '了解意图');
    });

    test('role agent can emit multiple retrieval intents', () {
      final output = DynamicRoleAgentOutput(
        characterId: 'char-liuxi',
        name: '柳溪',
        text:
            '立场：压迫\n动作：逼近\n禁忌：拖延'
            '\n检索：character_profile|岳刃|了解意图'
            '\n检索：world_setting|old-harbor|场景布局',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

      expect(turn.retrievalIntents, hasLength(2));
    });

    test('role agent without retrieval intents produces empty list', () {
      final output = DynamicRoleAgentOutput(
        characterId: 'char-liuxi',
        name: '柳溪',
        text: '立场：压迫\n动作：逼近\n禁忌：拖延',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);

      expect(turn.retrievalIntents, isEmpty);
    });
  });

  // ===========================================================================
  // AT-3: Capsule-only prompt reinjection
  // Given a retrieval tool response,
  // When the controller loops the agent,
  // Then only the compressed capsule is injected into the next prompt
  // And raw tool payload is not appended as plain chat history.
  // ===========================================================================
  group('AT-3: Capsule-only prompt reinjection', () {
    test(
      'editorial prompt contains capsule summary, not raw retrieval payload',
      () async {
        final rawLongData = 'A' * 500;
        const compressedSummary = '前情摘要...';

        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(text: '编辑正文');
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
                toolName: 'past_event',
                query: 'q',
                purpose: 'p',
              ),
              summary: compressedSummary,
              tokenBudget: 120,
            ),
          ],
          attempt: 1,
        );

        final userPrompt = fakeClient.requests.last.messages.last.content;
        expect(userPrompt, contains(compressedSummary));
        expect(userPrompt, isNot(contains(rawLongData)));
      },
    );

    test(
      'resolver injects capsule context via dedicated section, not raw data',
      () async {
        const capsuleSummary = '柳溪与岳刃对峙，张力极高';

        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[叙述] @narrator 场景开始',
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
          taskCard: _taskCard(),
          roleTurns: [],
          capsules: const [
            ContextCapsule(
              intent: RetrievalIntent(
                toolName: 'relationship',
                query: 'q',
                purpose: 'p',
              ),
              summary: capsuleSummary,
              tokenBudget: 120,
            ),
          ],
        );

        final userPrompt = fakeClient.requests.last.messages.last.content;
        // Capsule is injected via a dedicated context section
        expect(userPrompt, contains('检索上下文'));
        expect(userPrompt, contains(capsuleSummary));
        // Raw tool JSON/metadata must not appear
        expect(userPrompt, isNot(contains('toolName')));
        expect(userPrompt, isNot(contains('tokenBudget')));
      },
    );
  });

  // ===========================================================================
  // AT-4: Belief isolation
  // Given two characters with different beliefs about the same third-party
  // fact,
  // When each agent acts,
  // Then they must produce outputs consistent with their own belief slice,
  // not a shared omniscient state.
  // ===========================================================================
  group('AT-4: Belief isolation', () {
    test(
      'each character receives only their own belief slice in the prompt',
      () async {
        final promptsByCharacter = <String, String>{};

        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (request.messages.last.content.contains(
              '任务：scene_roleplay_turn',
            )) {
              final userPrompt = request.messages.last.content;
              if (userPrompt.contains('角色：柳溪')) {
                promptsByCharacter['char-liuxi'] = userPrompt;
              } else if (userPrompt.contains('角色：岳刃')) {
                promptsByCharacter['char-yueren'] = userPrompt;
              }
              return const AppLlmChatResult.success(
                text: '意图：施压\n可见动作：逼近\n对白：\n内心：先稳住节奏',
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

        final taskCard = _taskCard(
          beliefs: [
            const CharacterBelief(
              holderId: 'char-liuxi',
              targetId: 'char-yueren',
              aspect: '诚实度',
              value: '不可信',
            ),
            const CharacterBelief(
              holderId: 'char-yueren',
              targetId: 'char-liuxi',
              aspect: '威胁',
              value: '高度危险',
            ),
          ],
        );

        final runner = DynamicRoleAgentRunner(settingsStore: settingsStore);
        await runner.run(
          brief: _brief(),
          cast: [
            _castMember(),
            _castMember(characterId: 'char-yueren', name: '岳刃', role: '走私联络人'),
          ],
          director: const SceneDirectorOutput(text: '目标：逼问'),
          taskCard: taskCard,
        );

        // 柳溪 sees her belief ("不可信") but not 岳刃's belief
        // ("高度危险")
        final liuxiPrompt = promptsByCharacter['char-liuxi']!;
        expect(liuxiPrompt, contains('不可信'));
        expect(liuxiPrompt, isNot(contains('高度危险')));

        // 岳刃 sees his belief ("高度危险") but not 柳溪's belief
        // ("不可信")
        final yuerenPrompt = promptsByCharacter['char-yueren']!;
        expect(yuerenPrompt, contains('高度危险'));
        expect(yuerenPrompt, isNot(contains('不可信')));
      },
    );

    test(
      'characters with different beliefs about same third party act independently',
      () async {
        final outputsByCharacter = <String, DynamicRoleAgentOutput>{};

        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (request.messages.last.content.contains(
              '任务：scene_roleplay_turn',
            )) {
              final userPrompt = request.messages.last.content;
              if (userPrompt.contains('角色：柳溪')) {
                final output = DynamicRoleAgentOutput(
                  characterId: 'char-liuxi',
                  name: '柳溪',
                  text: '意图：信任\n可见动作：合作\n对白：\n内心：压下怀疑',
                );
                outputsByCharacter['char-liuxi'] = output;
                return AppLlmChatResult.success(text: output.text);
              }
              if (userPrompt.contains('角色：岳刃')) {
                final output = DynamicRoleAgentOutput(
                  characterId: 'char-yueren',
                  name: '岳刃',
                  text: '意图：警惕\n可见动作：防备\n对白：\n内心：守住线索边界',
                );
                outputsByCharacter['char-yueren'] = output;
                return AppLlmChatResult.success(text: output.text);
              }
            }
            throw StateError('Unexpected prompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final taskCard = SceneTaskCard(
          brief: _brief(),
          cast: [
            _castMember(),
            _castMember(characterId: 'char-yueren', name: '岳刃', role: '走私联络人'),
          ],
          directorPlan: '目标：对峙',
          beliefs: [
            const CharacterBelief(
              holderId: 'char-liuxi',
              targetId: 'char-shendu',
              aspect: '立场',
              value: '盟友',
            ),
            const CharacterBelief(
              holderId: 'char-yueren',
              targetId: 'char-shendu',
              aspect: '立场',
              value: '叛徒',
            ),
          ],
        );

        final runner = DynamicRoleAgentRunner(settingsStore: settingsStore);
        final outputs = await runner.run(
          brief: _brief(),
          cast: [
            _castMember(),
            _castMember(characterId: 'char-yueren', name: '岳刃', role: '走私联络人'),
          ],
          director: const SceneDirectorOutput(text: '目标：对峙'),
          taskCard: taskCard,
        );

        expect(outputs, hasLength(2));

        final liuxiTurn = RolePlayTurnOutput.fromDynamicAgentOutput(
          outputs.first,
        );
        final yuerenTurn = RolePlayTurnOutput.fromDynamicAgentOutput(
          outputs.last,
        );

        // Each character produces output consistent with their own belief
        expect(liuxiTurn.stance, '信任');
        expect(yuerenTurn.stance, '警惕');
      },
    );
  });

  // ===========================================================================
  // AT-5: Scene-state resolution
  // Given conflicting roleplay actions,
  // When the resolver runs,
  // Then it must explicitly accept/reject actions and emit resolved beats
  // plus scene-state deltas.
  // ===========================================================================
  group('AT-5: Scene-state resolution', () {
    test('resolver explicitly classifies every beat by kind', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          final arbitrationResponse = _defaultArbitrationResponse(request);
          if (arbitrationResponse != null) return arbitrationResponse;
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text:
                  '[对白] @char-liuxi 你在哪拿到的\n'
                  '[动作] @char-yueren 后退一步\n'
                  '[事实] @narrator 货单在仓库铁柜中',
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

      expect(beats[0].kind, SceneBeatKind.dialogue);
      expect(beats[0].sourceCharacterId, 'char-liuxi');
      expect(beats[1].kind, SceneBeatKind.action);
      expect(beats[1].sourceCharacterId, 'char-yueren');
      expect(beats[2].kind, SceneBeatKind.fact);
      expect(beats[2].sourceCharacterId, 'narrator');

      for (var i = 0; i < beats.length; i++) {
        expect(beats[i].order, i);
      }
    });

    test(
      'resolver does not silently drop beats from conflicting actions',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text:
                    '[动作] @char-liuxi 挡住去路\n'
                    '[动作] @char-yueren 强行突破\n'
                    '[事实] @narrator 两人发生肢体冲突',
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

        // Both conflicting actions are present — no silent drops
        expect(beats, hasLength(3));
        expect(beats.any((b) => b.content.contains('挡住去路')), isTrue);
        expect(beats.any((b) => b.content.contains('强行突破')), isTrue);
        expect(beats.any((b) => b.kind == SceneBeatKind.fact), isTrue);
      },
    );

    test(
      'fallback preserves all role turn actions without silent drops',
      () async {
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
              action: '挡住去路',
              taboo: '拖延',
              retrievalIntents: const [],
              disclosure: '你走不了',
            ),
            RolePlayTurnOutput(
              characterId: 'char-yueren',
              name: '岳刃',
              stance: '逃避',
              action: '强行突破',
              taboo: '暴露',
              retrievalIntents: const [],
              disclosure: '让开',
            ),
          ],
          capsules: const [],
        );

        // Every character's action and dialogue survives the fallback path
        expect(beats.any((b) => b.content == '挡住去路'), isTrue);
        expect(beats.any((b) => b.content == '强行突破'), isTrue);
        expect(beats.any((b) => b.content == '你走不了'), isTrue);
        expect(beats.any((b) => b.content == '让开'), isTrue);
      },
    );
  });

  // ===========================================================================
  // AT-6: Editor fact discipline
  // Given resolved beats,
  // When the editor drafts prose,
  // Then the resulting draft must not introduce a new fact absent from
  // accepted beats or allowed narration context.
  // ===========================================================================
  group('AT-6: Editor fact discipline', () {
    test('editorial system prompt guides fact discipline', () async {
      String? capturedSystemPrompt;

      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          final arbitrationResponse = _defaultArbitrationResponse(request);
          if (arbitrationResponse != null) return arbitrationResponse;
          if (systemPrompt.contains('scene editor')) {
            capturedSystemPrompt = systemPrompt;
            return const AppLlmChatResult.success(text: '编辑正文');
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
        resolvedBeats: const [
          SceneBeat(
            kind: SceneBeatKind.fact,
            content: '货单在仓库里',
            sourceCharacterId: 'narrator',
          ),
          SceneBeat(
            kind: SceneBeatKind.dialogue,
            content: '交出来',
            sourceCharacterId: 'char-liuxi',
          ),
        ],
        capsules: const [],
        attempt: 1,
      );

      expect(capturedSystemPrompt, isNotNull);
      expect(
        capturedSystemPrompt!,
        contains('Keep all beat facts present and aligned'),
      );
      expect(capturedSystemPrompt!, contains('Preserve every beat'));
    });

    test(
      'editorial user prompt contains structured beats, not raw role summaries',
      () async {
        String? capturedUserPrompt;

        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (systemPrompt.contains('scene editor')) {
              capturedUserPrompt = request.messages.last.content;
              return const AppLlmChatResult.success(text: '编辑正文');
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
              content: '转身',
              sourceCharacterId: 'char-yueren',
            ),
          ],
          capsules: const [],
          attempt: 1,
        );

        expect(capturedUserPrompt, isNotNull);
        expect(capturedUserPrompt!, contains('场景拍'));
        expect(capturedUserPrompt!, contains('[叙述]'));
        expect(capturedUserPrompt!, contains('[对白]'));
        expect(capturedUserPrompt!, contains('[动作]'));
        // Must not contain raw role agent output format
        expect(capturedUserPrompt!, isNot(contains('立场：')));
        expect(capturedUserPrompt!, isNot(contains('禁忌：')));
      },
    );
  });

  // ===========================================================================
  // Unit: Knowledge visibility filtering
  // ===========================================================================
  group('Knowledge visibility filtering', () {
    test('beliefsFor returns only beliefs held by the specified character', () {
      final card = _taskCard(
        beliefs: [
          const CharacterBelief(
            holderId: 'char-liuxi',
            targetId: 'char-yueren',
            aspect: '诚实度',
            value: '不可信',
          ),
          const CharacterBelief(
            holderId: 'char-yueren',
            targetId: 'char-liuxi',
            aspect: '威胁',
            value: '高度危险',
          ),
          const CharacterBelief(
            holderId: 'char-liuxi',
            targetId: 'char-shendu',
            aspect: '立场',
            value: '盟友',
          ),
        ],
      );

      final liuxiBeliefs = card.beliefsFor('char-liuxi');
      expect(liuxiBeliefs, hasLength(2));
      expect(liuxiBeliefs.every((b) => b.holderId == 'char-liuxi'), isTrue);

      final yuerenBeliefs = card.beliefsFor('char-yueren');
      expect(yuerenBeliefs, hasLength(1));
      expect(yuerenBeliefs.first.value, '高度危险');

      expect(card.beliefsFor('char-shendu'), isEmpty);
    });

    test(
      'relationshipsFor returns slices involving the specified character',
      () {
        final card = _taskCard(
          relationships: [
            const RelationshipSlice(
              characterA: 'char-liuxi',
              characterB: 'char-yueren',
              label: '对峙',
              tension: 8,
            ),
            const RelationshipSlice(
              characterA: 'char-yueren',
              characterB: 'char-shendu',
              label: '合作',
              tension: 3,
            ),
          ],
        );

        expect(card.relationshipsFor('char-liuxi'), hasLength(1));
        expect(card.relationshipsFor('char-liuxi').first.label, '对峙');
        expect(card.relationshipsFor('char-yueren'), hasLength(2));
        expect(card.relationshipsFor('char-shendu'), hasLength(1));
      },
    );

    test('socialPositionFor returns only the specified character position', () {
      final card = _taskCard(
        socialPositions: [
          const SocialPositionSlice(
            characterId: 'char-liuxi',
            role: '调查记者',
            formalRank: '无',
            actualInfluence: '高',
          ),
          const SocialPositionSlice(
            characterId: 'char-yueren',
            role: '走私联络人',
            formalRank: '无',
            actualInfluence: '中',
          ),
        ],
      );

      expect(card.socialPositionFor('char-liuxi')?.actualInfluence, '高');
      expect(card.socialPositionFor('char-yueren')?.actualInfluence, '中');
      expect(card.socialPositionFor('char-shendu'), isNull);
    });

    test(
      'knowledge atoms are not auto-injected into role agent prompts',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (request.messages.last.content.contains(
              '任务：scene_roleplay_turn',
            )) {
              return const AppLlmChatResult.success(
                text: '意图：施压\n可见动作：逼近\n对白：\n内心：先稳住节奏',
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

        final taskCard = _taskCard(
          knowledge: [
            const KnowledgeAtom(
              id: 'k1',
              category: 'secret',
              content: '岳刃的真实身份是卧底',
              sourceId: 'prev',
            ),
          ],
        );

        final runner = DynamicRoleAgentRunner(settingsStore: settingsStore);
        await runner.run(
          brief: _brief(),
          cast: [_castMember()],
          director: const SceneDirectorOutput(text: '目标：逼问'),
          taskCard: taskCard,
        );

        // Knowledge is pull-based: characters only get it via retrieval
        // intents, never auto-injected.
        final userPrompt = fakeClient.requests.last.messages.last.content;
        expect(userPrompt, isNot(contains('卧底')));
        expect(userPrompt, isNot(contains('secret')));
      },
    );
  });

  // ===========================================================================
  // Unit: Disclosure policy matching
  // ===========================================================================
  group('Disclosure policy matching', () {
    test('PresentationState correctly identifies deception', () {
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

    test('whitespace-only deceptionTarget is not deceptive', () {
      const state = PresentationState(
        characterId: 'c1',
        surfaceEmotion: '平静',
        hiddenEmotion: '愤怒',
        deceptionTarget: '   ',
        deceptionContent: '假装不在意',
      );
      expect(state.isDeceptive, isFalse);
    });

    test('deception content alone without target is not deceptive', () {
      const state = PresentationState(
        characterId: 'c1',
        surfaceEmotion: '平静',
        hiddenEmotion: '愤怒',
        deceptionTarget: '',
        deceptionContent: '隐瞒关键信息',
      );
      expect(state.isDeceptive, isFalse);
    });
  });

  // ===========================================================================
  // Unit: Belief update rules
  // ===========================================================================
  group('Belief update rules', () {
    test('task card beliefs are immutable after construction', () {
      final card = _taskCard(
        beliefs: [
          const CharacterBelief(
            holderId: 'c1',
            targetId: 'c2',
            aspect: '信任',
            value: '高',
          ),
        ],
      );
      expect(
        () => card.beliefs.add(
          const CharacterBelief(
            holderId: 'c2',
            targetId: 'c1',
            aspect: '信任',
            value: '低',
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('belief query methods handle empty card gracefully', () {
      final card = _taskCard();
      expect(card.beliefsFor('any'), isEmpty);
      expect(card.relationshipsFor('any'), isEmpty);
      expect(card.socialPositionFor('any'), isNull);
    });

    test('beliefs list in task card preserves insertion order', () {
      final card = _taskCard(
        beliefs: [
          const CharacterBelief(
            holderId: 'c1',
            targetId: 'c2',
            aspect: '信任',
            value: '高',
          ),
          const CharacterBelief(
            holderId: 'c1',
            targetId: 'c3',
            aspect: '忠诚',
            value: '中',
          ),
          const CharacterBelief(
            holderId: 'c1',
            targetId: 'c4',
            aspect: '意图',
            value: '低',
          ),
        ],
      );
      final beliefs = card.beliefsFor('c1');
      expect(beliefs[0].aspect, '信任');
      expect(beliefs[1].aspect, '忠诚');
      expect(beliefs[2].aspect, '意图');
    });
  });

  // ===========================================================================
  // Unit: Resolver conflict handling
  // ===========================================================================
  group('Resolver conflict handling', () {
    test('resolver rejects empty-content beats', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          final arbitrationResponse = _defaultArbitrationResponse(request);
          if (arbitrationResponse != null) return arbitrationResponse;
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text:
                  '[动作] @char-liuxi\n[对白] @char-yueren \n'
                  '[事实] @narrator 有效内容',
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

    test('resolver assigns narrator when no @characterId present', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          final arbitrationResponse = _defaultArbitrationResponse(request);
          if (arbitrationResponse != null) return arbitrationResponse;
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

  // ===========================================================================
  // Integration: Two characters with one hidden fact
  // ===========================================================================
  group('Integration: Hidden fact across characters', () {
    test(
      'character without knowledge of a fact does not see it in prompt',
      () async {
        final promptsByCharacter = <String, String>{};

        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (request.messages.last.content.contains(
              '任务：scene_roleplay_turn',
            )) {
              final userPrompt = request.messages.last.content;
              if (userPrompt.contains('角色：柳溪')) {
                promptsByCharacter['char-liuxi'] = userPrompt;
              } else if (userPrompt.contains('角色：岳刃')) {
                promptsByCharacter['char-yueren'] = userPrompt;
              }
              return const AppLlmChatResult.success(
                text: '意图：施压\n可见动作：逼近\n对白：\n内心：先稳住节奏',
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

        // Only 柳溪 knows where the ledger is
        final taskCard = _taskCard(
          beliefs: [
            const CharacterBelief(
              holderId: 'char-liuxi',
              targetId: 'ledger',
              aspect: '位置',
              value: '仓库铁柜',
            ),
          ],
        );

        final runner = DynamicRoleAgentRunner(settingsStore: settingsStore);
        await runner.run(
          brief: _brief(),
          cast: [
            _castMember(),
            _castMember(characterId: 'char-yueren', name: '岳刃', role: '走私联络人'),
          ],
          director: const SceneDirectorOutput(text: '目标：对峙'),
          taskCard: taskCard,
        );

        // 柳溪 sees her belief about the ledger location
        expect(promptsByCharacter['char-liuxi'], contains('仓库铁柜'));
        // 岳刃 does not see 柳溪's belief about the ledger
        expect(promptsByCharacter['char-yueren'], isNot(contains('仓库铁柜')));
      },
    );

    test(
      'retrieval controller serves hidden knowledge only on explicit request',
      () {
        final card = _taskCard(
          knowledge: [
            const KnowledgeAtom(
              id: 'k1',
              category: 'secret',
              content: '岳刃的真实身份是卧底',
              sourceId: 'prev',
            ),
          ],
        );

        // No retrieval intent → no capsule
        final noRequest = const RetrievalController().resolve(
          taskCard: card,
          turns: [
            RolePlayTurnOutput(
              characterId: 'char-yueren',
              name: '岳刃',
              stance: 's',
              action: 'a',
              taboo: 't',
              retrievalIntents: [],
            ),
          ],
        );
        expect(noRequest, isEmpty);

        // Explicit request → knowledge retrieved via capsule
        final withRequest = const RetrievalController().resolve(
          taskCard: card,
          turns: [
            RolePlayTurnOutput(
              characterId: 'char-liuxi',
              name: '柳溪',
              stance: 's',
              action: 'a',
              taboo: 't',
              retrievalIntents: [
                RetrievalIntent(
                  toolName: RetrievalIntent.kToolPastEvent,
                  query: '卧底',
                  purpose: '确认身份',
                ),
              ],
            ),
          ],
        );
        expect(withRequest, hasLength(1));
        expect(withRequest.first.summary, contains('卧底'));
      },
    );
  });

  // ===========================================================================
  // Integration: Mistaken belief propagation
  // ===========================================================================
  group('Integration: Mistaken belief through pipeline', () {
    test(
      'character acts on mistaken belief and it flows through to beats',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (request.messages.last.content.contains(
              '任务：scene_roleplay_turn',
            )) {
              final userPrompt = request.messages.last.content;
              // 柳溪 believes 岳刃 is untrustworthy (mistaken)
              if (userPrompt.contains('角色：柳溪')) {
                expect(userPrompt, contains('不可信'));
                return const AppLlmChatResult.success(
                  text: '意图：怀疑\n可见动作：逼问\n对白：你在骗我\n内心：压下轻信的冲动',
                );
              }
              return const AppLlmChatResult.success(
                text: '意图：解释\n可见动作：摊开手解释\n对白：我没有\n内心：先把解释说清',
              );
            }
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text:
                    '[对白] @char-liuxi 你在骗我\n'
                    '[对白] @char-yueren 我没有\n'
                    '[事实] @narrator 柳溪的怀疑是基于错误信息',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(
                text: '柳溪逼问岳刃，态度强硬。岳刃试图解释，但柳溪基于错误的前提继续施压。',
              );
            }
            if (systemPrompt.contains('review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：冲突成立。');
            }
            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(text: '目标：对峙\n冲突：信任危机');
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
              value: '不可信',
            ),
          ],
        );

        // The mistaken belief drives the character's behavior through the
        // pipeline
        expect(result.roleTurns, isNotEmpty);
        expect(result.resolvedBeats, hasLength(3));
        expect(result.editorialDraft.text, contains('错误'));
        expect(result.review.decision, SceneReviewDecision.pass);

        // The mistaken belief is preserved in the task card for later
        // correction
        expect(result.taskCard.beliefsFor('char-liuxi'), hasLength(1));
        expect(result.taskCard.beliefsFor('char-liuxi').first.value, '不可信');
      },
    );
  });

  // ===========================================================================
  // Integration: Full pipeline end-to-end
  // ===========================================================================
  group('Integration: Full pipeline with belief isolation and retrieval', () {
    test(
      'pipeline end-to-end preserves belief isolation through all stages',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final arbitrationResponse = _defaultArbitrationResponse(request);
            if (arbitrationResponse != null) return arbitrationResponse;
            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(text: '目标：对峙\n冲突：信任危机');
            }
            if (request.messages.last.content.contains(
              '任务：scene_roleplay_turn',
            )) {
              return const AppLlmChatResult.success(
                text: '意图：施压\n可见动作：逼近\n对白：\n内心：先稳住节奏',
              );
            }
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text:
                    '[叙述] @narrator 场景\n'
                    '[对白] @char-liuxi 说话\n'
                    '[动作] @char-yueren 反应',
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
          beliefs: [
            const CharacterBelief(
              holderId: 'char-liuxi',
              targetId: 'char-yueren',
              aspect: '诚实度',
              value: '不可信',
            ),
            const CharacterBelief(
              holderId: 'char-yueren',
              targetId: 'char-liuxi',
              aspect: '威胁',
              value: '致命',
            ),
          ],
        );

        expect(result.taskCard.beliefs, hasLength(2));
        expect(result.taskCard.beliefsFor('char-liuxi'), hasLength(1));
        expect(result.taskCard.beliefsFor('char-yueren'), hasLength(1));
        expect(result.resolvedBeats, isNotEmpty);
        expect(result.editorialDraft.text, contains('最终正文'));
        expect(result.review.decision, SceneReviewDecision.pass);
      },
    );
  });

  // ===========================================================================
  // Integration: Editor stitches multiple resolved beats into coherent prose
  // ===========================================================================
  group(
    'Integration: Editor stitches multiple beat types into coherent prose',
    () {
      test(
        'editor receives all five beat kinds and produces woven prose draft',
        () async {
          String? capturedUserPrompt;
          String? capturedSystemPrompt;

          final fakeClient = FakeAppLlmClient(
            responder: (request) {
              final systemPrompt = request.messages.first.content;
              final arbitrationResponse = _defaultArbitrationResponse(request);
              if (arbitrationResponse != null) return arbitrationResponse;
              if (systemPrompt.contains('scene editor')) {
                capturedSystemPrompt = systemPrompt;
                capturedUserPrompt = request.messages.last.content;
                // Return prose that weaves all beats together
                return const AppLlmChatResult.success(
                  text:
                      '雨夜的仓库门外，铁锈味的空气混着海水。'
                      '柳溪挡在岳刃面前，目光如刀。"货单在哪？"她逼问。'
                      '岳刃沉默片刻，转身欲走，却被堵在墙角。'
                      '他心里清楚，一旦暴露就全完了。'
                      '货单藏在仓库的铁柜里，只有他知道。',
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

          final generator = SceneEditorialGenerator(
            settingsStore: settingsStore,
          );

          // All five beat kinds
          final beats = [
            const SceneBeat(
              kind: SceneBeatKind.narration,
              content: '雨夜仓库门外，铁锈味弥漫',
              sourceCharacterId: 'narrator',
            ),
            const SceneBeat(
              kind: SceneBeatKind.dialogue,
              content: '货单在哪',
              sourceCharacterId: 'char-liuxi',
            ),
            const SceneBeat(
              kind: SceneBeatKind.action,
              content: '转身欲走',
              sourceCharacterId: 'char-yueren',
            ),
            const SceneBeat(
              kind: SceneBeatKind.internal,
              content: '一旦暴露就全完了',
              sourceCharacterId: 'char-yueren',
            ),
            const SceneBeat(
              kind: SceneBeatKind.fact,
              content: '货单藏在仓库铁柜里',
              sourceCharacterId: 'narrator',
            ),
          ];

          final draft = await generator.generate(
            taskCard: _taskCard(),
            resolvedBeats: beats,
            capsules: const [],
            attempt: 1,
          );

          // Draft reflects all five beats
          expect(draft.beatCount, 5);
          expect(draft.attempt, 1);
          expect(draft.text, contains('柳溪'));
          expect(draft.text, contains('货单'));
          expect(draft.text, contains('仓库'));

          // Prompt contains all five beat kinds formatted as structured tags
          expect(capturedUserPrompt, isNotNull);
          expect(capturedUserPrompt!, contains('[叙述]'));
          expect(capturedUserPrompt!, contains('[对白]'));
          expect(capturedUserPrompt!, contains('[动作]'));
          expect(capturedUserPrompt!, contains('[心理]'));
          expect(capturedUserPrompt!, contains('[事实]'));

          // Each beat's content is present in the prompt
          expect(capturedUserPrompt!, contains('铁锈味弥漫'));
          expect(capturedUserPrompt!, contains('货单在哪'));
          expect(capturedUserPrompt!, contains('转身欲走'));
          expect(capturedUserPrompt!, contains('一旦暴露'));
          expect(capturedUserPrompt!, contains('铁柜'));

          // System prompt enforces fact discipline
          expect(
            capturedSystemPrompt,
            contains('Keep all beat facts present and aligned'),
          );
          expect(capturedSystemPrompt, contains('Preserve every beat'));

          // Raw role-agent output markers must not leak
          expect(capturedUserPrompt!, isNot(contains('立场：')));
          expect(capturedUserPrompt!, isNot(contains('禁忌：')));
        },
      );

      test(
        'editor with capsules weaves context into beat-based prose',
        () async {
          String? capturedUserPrompt;

          final fakeClient = FakeAppLlmClient(
            responder: (request) {
              final systemPrompt = request.messages.first.content;
              final arbitrationResponse = _defaultArbitrationResponse(request);
              if (arbitrationResponse != null) return arbitrationResponse;
              if (systemPrompt.contains('scene editor')) {
                capturedUserPrompt = request.messages.last.content;
                return const AppLlmChatResult.success(
                  text: '柳溪知道岳刃与沈渡曾合作，此刻逼问他货单去向。岳刃沉默以对。',
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

          final generator = SceneEditorialGenerator(
            settingsStore: settingsStore,
          );

          final draft = await generator.generate(
            taskCard: _taskCard(),
            resolvedBeats: const [
              SceneBeat(
                kind: SceneBeatKind.dialogue,
                content: '你和沈渡什么关系',
                sourceCharacterId: 'char-liuxi',
              ),
              SceneBeat(
                kind: SceneBeatKind.action,
                content: '沉默',
                sourceCharacterId: 'char-yueren',
              ),
            ],
            capsules: const [
              ContextCapsule(
                intent: RetrievalIntent(
                  toolName: 'relationship',
                  query: 'char-yueren',
                  purpose: '过往合作',
                ),
                summary: '岳刃与沈渡曾在码头合作走私',
                tokenBudget: 100,
              ),
            ],
            attempt: 1,
          );

          // Draft incorporates capsule context
          expect(draft.text, contains('合作'));
          expect(draft.beatCount, 2);

          // Prompt contains both beats AND capsule
          expect(capturedUserPrompt!, contains('[对白]'));
          expect(capturedUserPrompt!, contains('[动作]'));
          expect(capturedUserPrompt!, contains('上下文'));
          expect(capturedUserPrompt!, contains('岳刃与沈渡曾在码头合作走私'));

          // Raw capsule metadata must not leak
          expect(capturedUserPrompt!, isNot(contains('tokenBudget')));
          expect(capturedUserPrompt!, isNot(contains('toolName')));
        },
      );
    },
  );
}
