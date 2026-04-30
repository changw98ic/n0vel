import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/character_visible_context_models.dart';
import 'package:novel_writer/features/story_generation/data/role_turn_skill.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  group('BasicRoleTurnSkill prompt and validation', () {
    test(
      'repairs inner state locally when it contains backstory or body reaction',
      () async {
        var calls = 0;
        final fakeClient = FakeAppLlmClient(
          responder: (_) {
            calls += 1;
            return const AppLlmChatResult.success(
              text:
                  '意图：稳住场面\n'
                  '可见动作：陆沉按住谐振器\n'
                  '对白：先别动\n'
                  '内心：十五年调音师，胃里还是猛地一缩。',
            );
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final skill = BasicRoleTurnSkill(settingsStore: settingsStore);
        final turn = await skill.runTurn(context: _context(), round: 1);

        expect(calls, 1);
        expect(turn.innerState, '我必须稳住场面。');
      },
    );

    test(
      'strips contaminated inner clauses when a clean judgment remains',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.success(
            text:
                '意图：拖延对方\n'
                '可见动作：陆沉挡在门口\n'
                '对白：等一下\n'
                '内心：十五年前的事他还记得，但现在不能表露。',
          ),
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final skill = BasicRoleTurnSkill(settingsStore: settingsStore);
        final turn = await skill.runTurn(context: _context(), round: 1);

        expect(fakeClient.requests, hasLength(1));
        expect(turn.innerState, '现在不能表露。');
      },
    );

    test('repairs intent and visible action field drift locally', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text:
              '意图：他上前逼严泊交出录音\n'
              '可见动作：紧张地握紧拳头，内心挣扎\n'
              '对白：你不该来这里\n'
              '内心：这个条件太顺，背后一定有文章。',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final skill = BasicRoleTurnSkill(settingsStore: settingsStore);
      final turn = await skill.runTurn(context: _context(), round: 1);

      expect(fakeClient.requests, hasLength(1));
      expect(turn.intent, '逼严泊交出录音');
      expect(turn.visibleAction, '握紧拳头');
      expect(turn.dialogue, '你不该来这里');
      expect(turn.innerState, '这个条件太顺，背后一定有文章。');
    });

    test('parses roleplay prose fragment as a public turn artifact', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text:
              '意图：稳住失控频率\n'
              '可见动作：陆沉按住谐振器\n'
              '对白：先别动\n'
              '内心：先锁住频率。\n'
              '正文片段：陆沉俯身按住桌面上剧烈震颤的谐振器，指节被金属边缘硌得发白。'
              '他没有回头，只把声音压低：“先别动。”',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final skill = BasicRoleTurnSkill(settingsStore: settingsStore);
      final turn = await skill.runTurn(context: _context(), round: 1);

      expect(turn.proseFragment, contains('陆沉俯身按住桌面上剧烈震颤的谐振器'));
      expect(turn.proseFragment, contains('“先别动。”'));
    });

    test('builds prose fragment for legacy four-line role turns', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text:
              '意图：稳住失控频率\n'
              '可见动作：陆沉按住谐振器\n'
              '对白：先别动\n'
              '内心：先锁住频率。',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final skill = BasicRoleTurnSkill(settingsStore: settingsStore);
      final turn = await skill.runTurn(context: _context(), round: 1);

      expect(turn.proseFragment, contains('陆沉按住谐振器'));
      expect(turn.proseFragment, isNot(contains('陆沉陆沉')));
      expect(turn.toPublicEventLine(), contains('正文片段='));
    });

    test('retries when dialogue contains drafting alternatives', () async {
      var calls = 0;
      final fakeClient = FakeAppLlmClient(
        responder: (_) {
          calls += 1;
          if (calls == 1) {
            return const AppLlmChatResult.success(
              text:
                  '意图：逼停对方\n'
                  '可见动作：陆沉按下急停闸刀\n'
                  '对白：可能是"停下"，或者留空。让我看看哪句更好。\n'
                  '内心：先切断声音。',
            );
          }
          return const AppLlmChatResult.success(
            text:
                '意图：逼停对方\n'
                '可见动作：陆沉按下急停闸刀\n'
                '对白：停下。\n'
                '内心：先切断声音。',
          );
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final skill = BasicRoleTurnSkill(settingsStore: settingsStore);
      final turn = await skill.runTurn(context: _context(), round: 1);

      expect(calls, 2);
      expect(turn.dialogue, '停下。');
    });

    test('uses positive guidance in role turn prompts', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text:
              '意图：稳住场面\n'
              '可见动作：陆沉按住谐振器\n'
              '对白：先别动\n'
              '内心：先锁住频率。',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final skill = BasicRoleTurnSkill(settingsStore: settingsStore);
      await skill.runTurn(context: _context(), round: 1);

      final prompt = fakeClient.requests.single.messages
          .map((message) => message.content)
          .join('\n');
      expect(prompt, isNot(contains('禁止')));
      expect(prompt, isNot(contains('不得')));
      expect(prompt, isNot(contains('不要')));
      expect(prompt, isNot(contains('Do not')));
      expect(prompt, isNot(contains('Never')));
      expect(prompt, contains('意图字段：写角色此刻想达成的目标'));
      expect(prompt, contains('可见动作字段：写第三方能拍到的外部画面'));
      expect(prompt, contains('内心字段：写一句当下判断或决定'));
      expect(prompt, contains('正文片段字段：写小说正文片段'));
      expect(prompt, contains('我怀疑他在试探'));
    });
  });
}

CharacterVisibleContext _context() {
  return CharacterVisibleContext(
    characterId: 'luchen',
    characterName: '陆沉',
    role: '调音师',
    privateBriefing: '负责稳定异常频率。',
    publicSceneState: const PublicSceneState(summary: '旧区公寓内，谐振器正在失控。'),
    knownFacts: [
      CharacterKnownFact(content: '陆沉是调音师', acl: VisibilityAcl.public()),
    ],
  );
}
