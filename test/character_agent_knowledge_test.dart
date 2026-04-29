import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/domain/character_cognition_models.dart';
import 'package:novel_writer/features/story_generation/data/knowledge_tool_registry.dart';
import 'package:novel_writer/features/story_generation/data/knowledge_visibility_filter.dart';
import 'package:novel_writer/features/story_generation/data/role_agent_controller.dart';
import 'package:novel_writer/features/story_generation/domain/roleplay_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_beat_resolver.dart';
import 'package:novel_writer/features/story_generation/data/scene_editor.dart';
import 'package:novel_writer/features/story_generation/domain/pipeline_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/data/tool_intent_parser.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  // ---------------------------------------------------------------
  // Acceptance 1: Structured roleplay output
  // ---------------------------------------------------------------
  group('RoleplayTurn', () {
    test('parses structured 3-line output into typed fields', () {
      final turn = RoleplayTurn.parse(
        characterId: 'char-liuxi',
        name: '柳溪',
        text: '立场：强压\n动作：逼近半步逼问\n禁忌：拖延和犹豫',
      );
      expect(turn.characterId, 'char-liuxi');
      expect(turn.name, '柳溪');
      expect(turn.stance, '强压');
      expect(turn.action, '逼近半步逼问');
      expect(turn.taboo, '拖延和犹豫');
    });

    test('round-trips through toStructuredText and parse', () {
      final original = RoleplayTurn(
        characterId: 'char-yueren',
        name: '岳人',
        stance: '回避',
        action: '转移话题',
        taboo: '暴露真实调度',
      );
      final restored = RoleplayTurn.parse(
        characterId: original.characterId,
        name: original.name,
        text: original.toStructuredText(),
      );
      expect(restored, equals(original));
    });

    test('leaves fields empty when labels are missing', () {
      final turn = RoleplayTurn.parse(
        characterId: 'a',
        name: 'b',
        text: 'some free-form text\nanother line',
      );
      expect(turn.stance, isEmpty);
      expect(turn.action, isEmpty);
      expect(turn.taboo, isEmpty);
    });

    test('equality and hashCode', () {
      final a = RoleplayTurn(
        characterId: 'x',
        name: 'y',
        stance: 's',
        action: 'a',
        taboo: 't',
      );
      final b = RoleplayTurn(
        characterId: 'x',
        name: 'y',
        stance: 's',
        action: 'a',
        taboo: 't',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ---------------------------------------------------------------
  // Acceptance 2: On-demand retrieval intent
  // ---------------------------------------------------------------
  group('ToolIntentParser', () {
    test('parses retrieval intent from agent output', () {
      const text = '立场：需要更多信息\nRETRIEVE:character_profile:targetId=yueren';
      final parser = ToolIntentParser();
      final intent = parser.tryParse(text, 'char-liuxi');

      expect(intent, isNotNull);
      expect(intent!.characterId, 'char-liuxi');
      expect(intent.toolName, 'character_profile');
      expect(intent.parameters['targetId'], 'yueren');
      expect(intent.isToolAllowed, isTrue);
    });

    test('parses retrieval intent without parameters', () {
      const text = 'RETRIEVE:scene_context';
      final parser = ToolIntentParser();
      final intent = parser.tryParse(text, 'a');

      expect(intent, isNotNull);
      expect(intent!.toolName, 'scene_context');
      expect(intent.parameters, isEmpty);
    });

    test('returns null when no retrieval line present', () {
      const text = '立场：强硬\n动作：逼问\n禁忌：退缩';
      final parser = ToolIntentParser();
      expect(parser.tryParse(text, 'a'), isNull);
    });

    test('hasValidRetrievalIntent detects allowed tool', () {
      const text = 'RETRIEVE:world_rule:ruleId=harbor-protocol';
      final parser = ToolIntentParser();
      expect(parser.hasValidRetrievalIntent(text), isTrue);
    });

    test('hasValidRetrievalIntent rejects unknown tool', () {
      const text = 'RETRIEVE:hack_the_mainframe';
      final parser = ToolIntentParser();
      expect(parser.hasValidRetrievalIntent(text), isFalse);
    });

    test('parses multiple parameters', () {
      const text = 'RETRIEVE:relationship_history:charA=liuxi,charB=yueren,depth=2';
      final parser = ToolIntentParser();
      final intent = parser.tryParse(text, 'char-liuxi');

      expect(intent, isNotNull);
      expect(intent!.parameters['charA'], 'liuxi');
      expect(intent.parameters['charB'], 'yueren');
      expect(intent.parameters['depth'], '2');
    });
  });

  // ---------------------------------------------------------------
  // Acceptance 3 (partial): Capsule assembly is covered in
  // scene_pipeline_models_test.dart. Here we verify the capsule
  // reinjection contract for the controller prompt.
  // ---------------------------------------------------------------
  group('Capsule reinjection contract', () {
    test('capsule summary is bounded and injectable', () {
      final capsule = ContextCapsule(
        id: 'cap-1',
        sourceTool: 'character_profile',
        summary: '柳溪是调查记者',
        charBudget: 200,
      );
      expect(capsule.isWithinBudget, isTrue);
      expect(capsule.summary.length, lessThanOrEqualTo(200));
    });

    test('capsule truncates content exceeding budget', () {
      final capsule = ContextCapsule(
        id: 'cap-2',
        sourceTool: 'relationship_history',
        summary: 'A' * 500,
        charBudget: 100,
      );
      expect(capsule.summary.length, lessThanOrEqualTo(100));
      expect(capsule.summary, endsWith('...'));
    });
  });

  // ---------------------------------------------------------------
  // Acceptance 4: Belief isolation
  // ---------------------------------------------------------------
  group('Belief isolation', () {
    test('characters only see their own beliefs via snapshot builder', () {
      final liuxiBelief = CharacterBelief(
        subjectId: 'char-liuxi',
        targetId: 'char-yueren',
        claim: '岳人不可信',
      );
      final yuerenBelief = CharacterBelief(
        subjectId: 'char-yueren',
        targetId: 'char-liuxi',
        claim: '柳溪太急躁',
      );

      final liuxiSnapshot = CharacterCognitionSnapshot(
        characterId: 'char-liuxi',
        name: '柳溪',
        role: '调查记者',
        beliefs: [liuxiBelief],
      );
      final yuerenSnapshot = CharacterCognitionSnapshot(
        characterId: 'char-yueren',
        name: '岳人',
        role: '线人',
        beliefs: [yuerenBelief],
      );

      expect(liuxiSnapshot.beliefs, contains(liuxiBelief));
      expect(liuxiSnapshot.beliefs, isNot(contains(yuerenBelief)));
      expect(yuerenSnapshot.beliefs, contains(yuerenBelief));
      expect(yuerenSnapshot.beliefs, isNot(contains(liuxiBelief)));
    });

    test('two characters hold different beliefs about the same fact', () {
      final liuxiBelief = CharacterBelief(
        subjectId: 'char-liuxi',
        targetId: 'fact-cargo-manifest',
        claim: '货单是伪造的',
        confidence: 0.9,
      );
      final yuerenBelief = CharacterBelief(
        subjectId: 'char-yueren',
        targetId: 'fact-cargo-manifest',
        claim: '货单是真实的',
        confidence: 0.7,
      );

      // Both have beliefs about the same target but with different claims
      expect(liuxiBelief.targetId, equals(yuerenBelief.targetId));
      expect(liuxiBelief.claim, isNot(equals(yuerenBelief.claim)));
    });
  });

  // ---------------------------------------------------------------
  // Knowledge visibility filtering
  // ---------------------------------------------------------------
  group('KnowledgeVisibilityFilter', () {
    late KnowledgeVisibilityFilter filter;

    setUp(() {
      filter = KnowledgeVisibilityFilter();
    });

    test('public facts are visible to all characters', () {
      final facts = [
        KnowledgeFact(
          factId: 'fact-weather',
          content: '暴雨如注',
          isPublic: true,
        ),
      ];
      final visible = filter.visibleFacts(facts, 'char-liuxi', []);
      expect(visible, hasLength(1));
    });

    test('private facts require disclosure policy', () {
      final facts = [
        KnowledgeFact(
          factId: 'fact-forged-manifest',
          content: '货单是伪造的',
          isPublic: false,
        ),
      ];
      // No policy → not visible
      expect(filter.visibleFacts(facts, 'char-liuxi', []), isEmpty);

      // With policy granting access
      final policies = [
        DisclosurePolicy(
          factId: 'fact-forged-manifest',
          knownBy: {'char-liuxi'},
        ),
      ];
      expect(filter.visibleFacts(facts, 'char-liuxi', policies), hasLength(1));
      expect(filter.visibleFacts(facts, 'char-yueren', policies), isEmpty);
    });

    test('isFactVisibleTo returns correct visibility', () {
      final facts = [
        KnowledgeFact(factId: 'fact-secret', content: '秘密', isPublic: false),
      ];
      final policies = [
        DisclosurePolicy(factId: 'fact-secret', knownBy: {'char-liuxi'}),
      ];

      expect(
        filter.isFactVisibleTo('fact-secret', 'char-liuxi', facts, policies),
        isTrue,
      );
      expect(
        filter.isFactVisibleTo('fact-secret', 'char-yueren', facts, policies),
        isFalse,
      );
    });

    test('partitionFacts assigns correct visibility per character', () {
      final facts = [
        KnowledgeFact(factId: 'public', content: '公开', isPublic: true),
        KnowledgeFact(factId: 'secret', content: '秘密', isPublic: false),
      ];
      final policies = [
        DisclosurePolicy(factId: 'secret', knownBy: {'char-liuxi'}),
      ];

      final partitioned = filter.partitionFacts(
        facts,
        ['char-liuxi', 'char-yueren'],
        policies,
      );

      expect(partitioned['char-liuxi'], hasLength(2));
      expect(partitioned['char-yueren'], hasLength(1));
      expect(partitioned['char-yueren']!.first.factId, 'public');
    });
  });

  // ---------------------------------------------------------------
  // Disclosure policy matching
  // ---------------------------------------------------------------
  group('DisclosurePolicy', () {
    test('isKnownTo checks character membership', () {
      final policy = DisclosurePolicy(
        factId: 'fact-a',
        knownBy: {'char-liuxi', 'char-shendu'},
      );
      expect(policy.isKnownTo('char-liuxi'), isTrue);
      expect(policy.isKnownTo('char-shendu'), isTrue);
      expect(policy.isKnownTo('char-yueren'), isFalse);
    });

    test('empty knownBy means nobody knows', () {
      final policy = DisclosurePolicy(factId: 'fact-hidden');
      expect(policy.isKnownTo('char-liuxi'), isFalse);
      expect(policy.isKnownTo('char-yueren'), isFalse);
    });

    test('equality and hashCode', () {
      final a = DisclosurePolicy(factId: 'x', knownBy: {'a', 'b'});
      final b = DisclosurePolicy(factId: 'x', knownBy: {'b', 'a'});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ---------------------------------------------------------------
  // Acceptance 5: Scene-state resolution
  // ---------------------------------------------------------------
  group('SceneBeatResolver', () {
    late SceneBeatResolver resolver;

    setUp(() {
      resolver = SceneBeatResolver();
    });

    test('accepts all beats when no conflicts', () {
      final beats = [
        SceneBeat(characterId: 'a', action: '观察环境'),
        SceneBeat(characterId: 'b', action: '低声警告'),
      ];
      final delta = resolver.resolve(beats);

      expect(delta.resolvedBeats, hasLength(2));
      expect(delta.acceptedBeats, hasLength(2));
      expect(delta.rejectedBeats, isEmpty);
    });

    test('accepts first and rejects later conflicting beats on same target',
        () {
      final beats = [
        SceneBeat(
          characterId: 'char-liuxi',
          action: '抓住货单',
          targetId: 'item-manifest',
        ),
        SceneBeat(
          characterId: 'char-yueren',
          action: '抢走货单',
          targetId: 'item-manifest',
        ),
      ];
      final delta = resolver.resolve(beats);

      expect(delta.resolvedBeats, hasLength(2));
      expect(delta.acceptedBeats, hasLength(1));
      expect(delta.rejectedBeats, hasLength(1));
      expect(delta.acceptedBeats.first.beat.characterId, 'char-liuxi');
      expect(delta.rejectedBeats.first.beat.characterId, 'char-yueren');
      expect(
        delta.rejectedBeats.first.reason,
        contains('conflicts with earlier action'),
      );
    });

    test('beats without targetId never conflict', () {
      final beats = [
        SceneBeat(characterId: 'a', action: '思考'),
        SceneBeat(characterId: 'b', action: '思考'),
      ];
      final delta = resolver.resolve(beats);
      expect(delta.acceptedBeats, hasLength(2));
    });

    test('different targets do not conflict', () {
      final beats = [
        SceneBeat(
          characterId: 'a',
          action: '抓住货单',
          targetId: 'item-manifest',
        ),
        SceneBeat(
          characterId: 'b',
          action: '打开门锁',
          targetId: 'item-door',
        ),
      ];
      final delta = resolver.resolve(beats);
      expect(delta.acceptedBeats, hasLength(2));
    });

    test('resolveWithBeliefUpdates generates updates for rejections', () {
      final beats = [
        SceneBeat(
          characterId: 'char-liuxi',
          action: '抓住货单',
          targetId: 'item-manifest',
        ),
        SceneBeat(
          characterId: 'char-yueren',
          action: '抢走货单',
          targetId: 'item-manifest',
        ),
      ];
      final delta = resolver.resolveWithBeliefUpdates(
        beats,
        updateReason: (rejected, accepted) =>
            '${rejected.characterId}看到${accepted.characterId}先拿到了货单',
      );

      expect(delta.beliefUpdates, hasLength(1));
      expect(delta.beliefUpdates.first.characterId, 'char-yueren');
      expect(delta.beliefUpdates.first.oldClaim, '抢走货单');
      expect(delta.beliefUpdates.first.newClaim, '抓住货单');
    });

    test('does not silently drop conflicting actions', () {
      final beats = [
        SceneBeat(characterId: 'a', action: 'x', targetId: 't1'),
        SceneBeat(characterId: 'b', action: 'y', targetId: 't1'),
        SceneBeat(characterId: 'c', action: 'z', targetId: 't1'),
      ];
      final delta = resolver.resolve(beats);

      expect(delta.resolvedBeats, hasLength(3));
      // Every beat has an explicit resolution
      for (final rb in delta.resolvedBeats) {
        expect(
          rb.resolution,
          anyOf(BeatResolution.accepted, BeatResolution.rejected),
        );
        expect(rb.reason, isNotEmpty);
      }
    });
  });

  // ---------------------------------------------------------------
  // Belief update rules
  // ---------------------------------------------------------------
  group('BeliefUpdate', () {
    test('constructs with all fields', () {
      final update = BeliefUpdate(
        characterId: 'char-yueren',
        targetId: 'char-liuxi',
        oldClaim: '柳溪不知道真相',
        newClaim: '柳溪已经拿到货单',
        reason: '目睹柳溪拿到货单',
      );
      expect(update.characterId, 'char-yueren');
      expect(update.targetId, 'char-liuxi');
      expect(update.oldClaim, '柳溪不知道真相');
      expect(update.newClaim, '柳溪已经拿到货单');
    });

    test('equality and hashCode', () {
      final a = BeliefUpdate(
        characterId: 'x',
        targetId: 'y',
        oldClaim: 'o',
        newClaim: 'n',
        reason: 'r',
      );
      final b = BeliefUpdate(
        characterId: 'x',
        targetId: 'y',
        oldClaim: 'o',
        newClaim: 'n',
        reason: 'r',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('SceneStateDelta', () {
    test('acceptedBeats and rejectedBeats partition correctly', () {
      final delta = SceneStateDelta(
        resolvedBeats: [
          ResolvedBeat(
            beat: SceneBeat(characterId: 'a', action: 'x'),
            resolution: BeatResolution.accepted,
            reason: 'ok',
          ),
          ResolvedBeat(
            beat: SceneBeat(characterId: 'b', action: 'y', targetId: 't'),
            resolution: BeatResolution.rejected,
            reason: 'conflict',
          ),
        ],
      );
      expect(delta.acceptedBeats, hasLength(1));
      expect(delta.rejectedBeats, hasLength(1));
    });

    test('empty delta has empty partitions', () {
      final delta = SceneStateDelta(resolvedBeats: []);
      expect(delta.acceptedBeats, isEmpty);
      expect(delta.rejectedBeats, isEmpty);
      expect(delta.beliefUpdates, isEmpty);
    });
  });

  // ---------------------------------------------------------------
  // Acceptance 3: Capsule-only prompt reinjection
  // ---------------------------------------------------------------
  group('RoleAgentController integration', () {
    test('injects capsule summary not raw payload on retrieval loop',
        () async {
      var callCount = 0;
      const rawPayload = '岳人背景：卧底探员，执行秘密任务三年。';

      final fakeClient = FakeAppLlmClient(
        responder: (request) async {
          callCount++;
          if (callCount == 1) {
            return const AppLlmChatResult.success(
              text: 'RETRIEVE:character_profile:targetId=char-yueren',
            );
          }
          return const AppLlmChatResult.success(
            text: '立场：警惕\n动作：暗中观察\n禁忌：暴露意图',
          );
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);
      await settingsStore.save(
        providerName: 'Test',
        baseUrl: 'https://test.example.com/v1',
        model: 'test-model',
        apiKey: 'sk-test',
        timeout: AppLlmTimeoutConfig.uniform(60000),
        maxConcurrentRequests: 2,
      );

      final controller = RoleAgentController(settingsStore: settingsStore);
      final turn = await controller.runWithRetrieval(
        brief: _testBrief(),
        member: _testMember(),
        director: const SceneDirectorOutput(text: '目标：逼问\n冲突：顶压'),
        retrievalTool: (intent) async => rawPayload,
      );

      expect(turn.characterId, 'char-liuxi');
      expect(turn.stance, '警惕');
      expect(turn.action, '暗中观察');
      expect(callCount, 2);

      // Verify the second request injects via capsule format, not raw chat
      final secondRequest = fakeClient.requests[1];
      // Each request should have exactly 2 messages (system + user).
      // Raw payload must NOT be appended as a separate chat message.
      expect(secondRequest.messages, hasLength(2));
      expect(secondRequest.messages.first.role, 'system');
      expect(secondRequest.messages.last.role, 'user');

      // The capsule is injected inside the user message with structured format
      final userPrompt = secondRequest.messages.last.content;
      expect(userPrompt, contains('补充信息'));
      expect(userPrompt, contains('[character_profile]'));
    });

    test('truncates long raw payload through capsule compressor', () async {
      // Raw payload exceeding the 200-char default capsule budget
      final rawPayload = 'A' * 300;
      var callCount = 0;

      final fakeClient = FakeAppLlmClient(
        responder: (request) async {
          callCount++;
          if (callCount == 1) {
            return const AppLlmChatResult.success(
              text: 'RETRIEVE:scene_context',
            );
          }
          return const AppLlmChatResult.success(
            text: '立场：决断\n动作：行动\n禁忌：犹豫',
          );
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);
      await settingsStore.save(
        providerName: 'Test',
        baseUrl: 'https://test.example.com/v1',
        model: 'test-model',
        apiKey: 'sk-test',
        timeout: AppLlmTimeoutConfig.uniform(60000),
        maxConcurrentRequests: 2,
      );

      final controller = RoleAgentController(settingsStore: settingsStore);
      await controller.runWithRetrieval(
        brief: _testBrief(),
        member: _testMember(),
        director: const SceneDirectorOutput(text: '目标：行动'),
        retrievalTool: (intent) async => rawPayload,
      );

      // The second request's user prompt must contain the truncated
      // capsule (<=200 chars), not the full 300-char raw payload.
      final userPrompt = fakeClient.requests[1].messages.last.content;
      expect(userPrompt, contains('补充信息'));
      // Verify the injected content is truncated (ends with ...)
      // and is shorter than the raw 300-char payload
      final capsuleMatch = RegExp(r'\[scene_context\] (.+)').firstMatch(userPrompt);
      expect(capsuleMatch, isNotNull);
      final capsuleSummary = capsuleMatch!.group(1)!;
      expect(capsuleSummary.length, lessThanOrEqualTo(200));
      expect(capsuleSummary.length, lessThan(rawPayload.length));
    });

    test('respects max retrieval rounds and returns turn', () async {
      var callCount = 0;
      final fakeClient = FakeAppLlmClient(
        responder: (request) async {
          callCount++;
          // Always emit a retrieval intent to test budget
          return AppLlmChatResult.success(
            text: callCount < 3
                ? 'RETRIEVE:scene_context'
                : '立场：决断\n动作：行动\n禁忌：犹豫',
          );
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);
      await settingsStore.save(
        providerName: 'Test',
        baseUrl: 'https://test.example.com/v1',
        model: 'test-model',
        apiKey: 'sk-test',
        timeout: AppLlmTimeoutConfig.uniform(60000),
        maxConcurrentRequests: 2,
      );

      final controller = RoleAgentController(
        settingsStore: settingsStore,
        maxRetrievalRounds: 2,
      );
      final turn = await controller.runWithRetrieval(
        brief: _testBrief(),
        member: _testMember(),
        director: const SceneDirectorOutput(text: '目标：行动'),
        retrievalTool: (intent) async => 'Some context data',
      );

      expect(turn.stance, '决断');
      // 2 retrieval rounds + 1 final = 3 calls
      expect(callCount, 3);
    });
  });

  // ---------------------------------------------------------------
  // Acceptance 6: Editor fact discipline
  // ---------------------------------------------------------------
  group('EditorialDraft fact discipline', () {
    test('isNovelFact detects facts not grounded in accepted beats', () {
      final draft = EditorialDraft(
        text: '柳溪抓住了货单，发现上面盖着伪造的海关章。',
        acceptedBeats: [
          ResolvedBeat(
            beat: SceneBeat(characterId: 'char-liuxi', action: '抓住货单'),
            resolution: BeatResolution.accepted,
            reason: 'ok',
          ),
        ],
      );
      expect(draft.isNovelFact('抓住货单'), isFalse);
      expect(draft.isNovelFact('伪造的海关章'), isTrue);
    });

    test('isNovelFact considers allowed narration context', () {
      final draft = EditorialDraft(
        text: '暴风雨中，柳溪抓住了货单。',
        acceptedBeats: [
          ResolvedBeat(
            beat: SceneBeat(characterId: 'char-liuxi', action: '抓住货单'),
            resolution: BeatResolution.accepted,
            reason: 'ok',
          ),
        ],
        allowedNarrationContext: '暴风雨中',
      );
      expect(draft.isNovelFact('暴风雨'), isFalse);
      expect(draft.isNovelFact('抓住货单'), isFalse);
    });

    test('isNovelFact returns false for text not in prose', () {
      final draft = EditorialDraft(
        text: '柳溪站在码头上。',
        acceptedBeats: [],
      );
      expect(draft.isNovelFact('不存在的文本'), isFalse);
    });

    test('allowedFacts yields beat actions and narration context', () {
      final draft = EditorialDraft(
        text: 'prose',
        acceptedBeats: [
          ResolvedBeat(
            beat: SceneBeat(characterId: 'a', action: 'action-a'),
            resolution: BeatResolution.accepted,
            reason: 'ok',
          ),
          ResolvedBeat(
            beat: SceneBeat(characterId: 'b', action: 'action-b'),
            resolution: BeatResolution.accepted,
            reason: 'ok',
          ),
        ],
        allowedNarrationContext: '天气：暴雨',
      );
      final facts = draft.allowedFacts.toList();
      expect(facts, containsAll(['action-a', 'action-b', '天气：暴雨']));
    });

    test('draft with empty beats and no context has no allowed facts', () {
      final draft = EditorialDraft(
        text: 'some prose',
        acceptedBeats: [],
      );
      expect(draft.allowedFacts, isEmpty);
    });
  });

  group('SceneEditor system prompt', () {
    test('enforces fact discipline constraint in system message', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) async {
          return const AppLlmChatResult.success(
            text: '柳溪抓住货单，暴雨中看清了上面的字迹。',
          );
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);
      await settingsStore.save(
        providerName: 'Test',
        baseUrl: 'https://test.example.com/v1',
        model: 'test-model',
        apiKey: 'sk-test',
        timeout: AppLlmTimeoutConfig.uniform(60000),
        maxConcurrentRequests: 2,
      );

      final editor = SceneEditor(settingsStore: settingsStore);
      final delta = SceneStateDelta(
        resolvedBeats: [
          ResolvedBeat(
            beat: SceneBeat(characterId: 'char-liuxi', action: '抓住货单'),
            resolution: BeatResolution.accepted,
            reason: 'ok',
          ),
        ],
      );

      final draft = await editor.draft(
        brief: _testBrief(),
        delta: delta,
      );

      final systemPrompt = fakeClient.requests.first.messages.first.content;
      expect(systemPrompt, contains('Do NOT introduce'));
      expect(systemPrompt, contains('accepted beats'));
      expect(systemPrompt, contains('allowed narration context'));

      expect(draft.acceptedBeats, hasLength(1));
      expect(draft.acceptedBeats.first.beat.action, '抓住货单');
    });

    test('passes allowed narration context to prompt', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) async {
          return const AppLlmChatResult.success(text: 'prose');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);
      await settingsStore.save(
        providerName: 'Test',
        baseUrl: 'https://test.example.com/v1',
        model: 'test-model',
        apiKey: 'sk-test',
        timeout: AppLlmTimeoutConfig.uniform(60000),
        maxConcurrentRequests: 2,
      );

      final editor = SceneEditor(settingsStore: settingsStore);
      final delta = SceneStateDelta(
        resolvedBeats: [
          ResolvedBeat(
            beat: SceneBeat(characterId: 'a', action: 'act'),
            resolution: BeatResolution.accepted,
            reason: 'ok',
          ),
        ],
      );

      await editor.draft(
        brief: _testBrief(),
        delta: delta,
        allowedNarrationContext: '暴雨倾盆，码头灯光昏暗',
      );

      final userPrompt = fakeClient.requests.first.messages.last.content;
      expect(userPrompt, contains('允许的叙述上下文'));
      expect(userPrompt, contains('暴雨倾盆'));
    });
  });
  // ---------------------------------------------------------------
  // RolePromptPacket
  // ---------------------------------------------------------------
  group('RolePromptPacket', () {
    test('JSON round-trip preserves all fields', () {
      final packet = RolePromptPacket(
        characterId: 'char-liuxi',
        characterName: '柳溪',
        characterRole: '调查记者',
        currentUnderstanding: '岳人在码头出现',
        currentFeeling: '紧张但坚定',
        viewOfOthers: '岳人不可信',
        surfaceBehavior: '表面镇定',
        unspokenThoughts: '怀疑岳人在隐瞒什么',
        actionIntent: '逼问真相',
        dialogueTendency: '单刀直入',
        sourceAtomIds: ['atom-1', 'atom-2'],
        metadata: {'scene': 'scene-01'},
      );

      final json = packet.toJson();
      final restored = RolePromptPacket.fromJson(json);

      expect(restored, equals(packet));
    });

    test('JSON round-trip handles empty optional fields', () {
      final packet = RolePromptPacket(
        characterId: 'char-a',
        characterName: 'A',
        characterRole: '角色',
      );
      final json = packet.toJson();
      final restored = RolePromptPacket.fromJson(json);

      expect(restored.characterId, 'char-a');
      expect(restored.currentUnderstanding, isEmpty);
      expect(restored.sourceAtomIds, isEmpty);
      expect(restored.metadata, isEmpty);
      expect(restored, equals(packet));
    });

    test('equality and hashCode', () {
      final a = RolePromptPacket(
        characterId: 'x',
        characterName: 'n',
        characterRole: 'r',
        currentUnderstanding: 'u',
        sourceAtomIds: ['a1'],
      );
      final b = RolePromptPacket(
        characterId: 'x',
        characterName: 'n',
        characterRole: 'r',
        currentUnderstanding: 'u',
        sourceAtomIds: ['a1'],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different fields produce unequal packets', () {
      final a = RolePromptPacket(
        characterId: 'x',
        characterName: 'n',
        characterRole: 'r',
        currentFeeling: 'angry',
      );
      final b = RolePromptPacket(
        characterId: 'x',
        characterName: 'n',
        characterRole: 'r',
        currentFeeling: 'calm',
      );
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------
  // KnowledgeToolRegistry.buildPacket
  // ---------------------------------------------------------------
  group('KnowledgeToolRegistry.buildPacket', () {
    test('maps each atom kind to the correct packet field', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'char-liuxi',
        name: '柳溪',
        role: '调查记者',
      );

      final atoms = [
        CharacterCognitionAtom.perceivedEvent(
          id: 'a1',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 0,
          content: '岳人在码头出现',
        ),
        CharacterCognitionAtom.reportedEvent(
          id: 'a2',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 1,
          content: '有人报告仓库有动静',
        ),
        CharacterCognitionAtom.selfState(
          id: 'a3',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 2,
          content: '紧张但坚定',
        ),
        CharacterCognitionAtom.acceptedBelief(
          id: 'a4',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 3,
          content: '岳人不可信',
        ),
        CharacterCognitionAtom.inference(
          id: 'a5',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 4,
          content: '岳人在隐瞒什么',
        ),
        CharacterCognitionAtom(
          id: 'a6',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 5,
          kind: CognitionKind.presentation,
          content: '表面镇定',
        ),
        CharacterCognitionAtom.suspicion(
          id: 'a7',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 6,
          content: '怀疑岳人在暗中观察',
        ),
        CharacterCognitionAtom(
          id: 'a8',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 7,
          kind: CognitionKind.uncertainty,
          content: '不确定货单真伪',
        ),
        CharacterCognitionAtom.goal(
          id: 'a9',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 8,
          content: '逼问真相',
        ),
        CharacterCognitionAtom.intent(
          id: 'a10',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 9,
          content: '单刀直入',
        ),
      ];

      final packet = KnowledgeToolRegistry.buildPacket(
        snapshot: snapshot,
        atoms: atoms,
      );

      expect(packet.characterId, 'char-liuxi');
      expect(packet.characterName, '柳溪');
      expect(packet.characterRole, '调查记者');
      expect(packet.currentUnderstanding, contains('岳人在码头出现'));
      expect(packet.currentUnderstanding, contains('有人报告仓库有动静'));
      expect(packet.currentFeeling, '紧张但坚定');
      expect(packet.viewOfOthers, contains('岳人不可信'));
      expect(packet.viewOfOthers, contains('岳人在隐瞒什么'));
      expect(packet.surfaceBehavior, '表面镇定');
      expect(packet.unspokenThoughts, contains('怀疑岳人在暗中观察'));
      expect(packet.unspokenThoughts, contains('不确定货单真伪'));
      expect(packet.actionIntent, '逼问真相');
      expect(packet.dialogueTendency, '单刀直入');
      expect(packet.sourceAtomIds, hasLength(10));
    });

    test('excludes atoms belonging to other characters', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'char-liuxi',
        name: '柳溪',
        role: '调查记者',
      );

      final atoms = [
        CharacterCognitionAtom.selfState(
          id: 'a-liuxi',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 0,
          content: '坚定',
        ),
        CharacterCognitionAtom.selfState(
          id: 'a-yueren',
          projectId: 'p',
          characterId: 'char-yueren',
          sceneId: 's',
          sequence: 0,
          content: '恐惧',
        ),
        CharacterCognitionAtom.selfState(
          id: 'a-shendu',
          projectId: 'p',
          characterId: 'char-shendu',
          sceneId: 's',
          sequence: 0,
          content: '冷漠',
        ),
      ];

      final packet = KnowledgeToolRegistry.buildPacket(
        snapshot: snapshot,
        atoms: atoms,
      );

      expect(packet.currentFeeling, '坚定');
      expect(packet.currentFeeling, isNot(contains('恐惧')));
      expect(packet.currentFeeling, isNot(contains('冷漠')));
      expect(packet.sourceAtomIds, equals(['a-liuxi']));
    });

    test('empty snapshot produces packet with empty fields', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'char-empty',
        name: '空角色',
        role: '路人',
      );

      final packet = KnowledgeToolRegistry.buildPacket(
        snapshot: snapshot,
        atoms: [],
      );

      expect(packet.characterId, 'char-empty');
      expect(packet.characterName, '空角色');
      expect(packet.characterRole, '路人');
      expect(packet.currentUnderstanding, isEmpty);
      expect(packet.currentFeeling, isEmpty);
      expect(packet.viewOfOthers, isEmpty);
      expect(packet.surfaceBehavior, isEmpty);
      expect(packet.unspokenThoughts, isEmpty);
      expect(packet.actionIntent, isEmpty);
      expect(packet.dialogueTendency, isEmpty);
      expect(packet.sourceAtomIds, isEmpty);
    });

    test('sourceAtomIds are preserved and ordered by atom sort', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'c1',
        name: 'N',
        role: 'R',
      );

      final atoms = [
        CharacterCognitionAtom.goal(
          id: 'goal-2',
          projectId: 'p',
          characterId: 'c1',
          sceneId: 's',
          sequence: 5,
          content: 'later goal',
        ),
        CharacterCognitionAtom.goal(
          id: 'goal-1',
          projectId: 'p',
          characterId: 'c1',
          sceneId: 's',
          sequence: 0,
          content: 'first goal',
        ),
      ];

      final packet = KnowledgeToolRegistry.buildPacket(
        snapshot: snapshot,
        atoms: atoms,
      );

      // Sorted by sequence: goal-1 before goal-2
      expect(packet.sourceAtomIds, equals(['goal-1', 'goal-2']));
      expect(packet.actionIntent, contains('first goal'));
      expect(packet.actionIntent, contains('later goal'));
    });

    test('packet is deterministic for same input', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'c1',
        name: 'N',
        role: 'R',
      );

      final atoms = [
        CharacterCognitionAtom.perceivedEvent(
          id: 'ev1',
          projectId: 'p',
          characterId: 'c1',
          sceneId: 's',
          sequence: 0,
          content: '事件A',
        ),
        CharacterCognitionAtom.selfState(
          id: 'st1',
          projectId: 'p',
          characterId: 'c1',
          sceneId: 's',
          sequence: 1,
          content: '平静',
        ),
      ];

      final packet1 = KnowledgeToolRegistry.buildPacket(
        snapshot: snapshot,
        atoms: atoms,
      );
      final packet2 = KnowledgeToolRegistry.buildPacket(
        snapshot: snapshot,
        atoms: atoms,
      );

      expect(packet1, equals(packet2));
      expect(packet1.hashCode, equals(packet2.hashCode));
    });

    test('truncates field content exceeding 200 chars', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'c1',
        name: 'N',
        role: 'R',
      );

      final longContent = 'A' * 150;
      final atoms = [
        CharacterCognitionAtom.perceivedEvent(
          id: 'ev1',
          projectId: 'p',
          characterId: 'c1',
          sceneId: 's',
          sequence: 0,
          content: longContent,
        ),
        CharacterCognitionAtom.reportedEvent(
          id: 'ev2',
          projectId: 'p',
          characterId: 'c1',
          sceneId: 's',
          sequence: 1,
          content: longContent,
        ),
      ];

      final packet = KnowledgeToolRegistry.buildPacket(
        snapshot: snapshot,
        atoms: atoms,
      );

      // 150 + '；' (1 char) + 150 = 301 chars -> truncated to 200
      expect(packet.currentUnderstanding.length, equals(200));
      expect(packet.currentUnderstanding, endsWith('...'));
    });

    test('private/hidden data is not leaked into packet', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'char-liuxi',
        name: '柳溪',
        role: '调查记者',
        presentation: PresentationState(
          characterId: 'char-liuxi',
          displayedEmotion: '镇定',
          hiddenEmotion: '极度恐惧',
          deceptionTarget: 'char-yueren',
          deceptionContent: '假装不在乎',
        ),
      );

      final atoms = [
        CharacterCognitionAtom(
          id: 'pres1',
          projectId: 'p',
          characterId: 'char-liuxi',
          sceneId: 's',
          sequence: 0,
          kind: CognitionKind.presentation,
          content: '表现镇定',
        ),
      ];

      final packet = KnowledgeToolRegistry.buildPacket(
        snapshot: snapshot,
        atoms: atoms,
      );

      // Packet only contains the atom content, not the hidden presentation data
      expect(packet.surfaceBehavior, '表现镇定');
      expect(packet.surfaceBehavior, isNot(contains('极度恐惧')));
      expect(packet.surfaceBehavior, isNot(contains('假装不在乎')));
    });
  });
}

// -- Test helpers ---------------------------------------------------------

SceneBrief _testBrief() {
  return SceneBrief(
    chapterId: 'chapter-01',
    chapterTitle: '第一章',
    sceneId: 'scene-01',
    sceneTitle: '仓库门外',
    sceneSummary: '柳溪在风雨中拦住岳刃。',
  );
}

ResolvedSceneCastMember _testMember() {
  return ResolvedSceneCastMember(
    characterId: 'char-liuxi',
    name: '柳溪',
    role: '调查记者',
    contributions: const [SceneCastContribution.action],
  );
}
