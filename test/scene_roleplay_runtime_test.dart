import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_runtime.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';

void main() {
  group('SceneRoleplayRuntime round budget', () {
    test('defaults to one roleplay round', () async {
      final store = _settingsStore();
      final roleSkill = _FakeRoleTurnSkill();
      final runtime = _runtime(store, roleSkill);

      final result = await runtime.runSession(
        brief: _brief(),
        cast: _cast(),
        director: const SceneDirectorOutput(text: '目标：推进'),
      );

      expect(result.session.rounds, hasLength(1));
      expect(roleSkill.calls, 2);
    });

    test(
      'honors explicit roleplayRounds one without clamping to two',
      () async {
        final store = _settingsStore();
        final roleSkill = _FakeRoleTurnSkill();
        final runtime = _runtime(store, roleSkill);

        final result = await runtime.runSession(
          brief: _brief(metadata: const {'roleplayRounds': 1}),
          cast: _cast(),
          director: const SceneDirectorOutput(text: '目标：推进'),
        );

        expect(result.session.rounds, hasLength(1));
        expect(roleSkill.calls, 2);
      },
    );
  });

  group('SceneRoleplayRuntime turn concurrency', () {
    test('starts same-round actor turns concurrently by default', () async {
      final store = _settingsStore();
      final roleSkill = _BlockingRoleTurnSkill();
      final runtime = _runtime(store, roleSkill);
      var sessionDone = false;

      final future = runtime
          .runSession(
            brief: _brief(),
            cast: _cast(),
            director: const SceneDirectorOutput(text: '目标：推进'),
          )
          .then((result) {
            sessionDone = true;
            return result;
          });

      await roleSkill.waitForStarted(2).timeout(const Duration(seconds: 1));
      expect(roleSkill.startedCharacterIds, ['a', 'b']);
      expect(sessionDone, isFalse);

      roleSkill.release('b');
      await Future<void>.delayed(Duration.zero);
      expect(sessionDone, isFalse);

      roleSkill.release('a');
      final result = await future;

      expect(
        result.session.rounds.single.turns.map((turn) => turn.characterId),
        ['a', 'b'],
      );
      expect(roleSkill.completedCharacterIds, ['b', 'a']);
    });
  });
}

AppSettingsStore _settingsStore() {
  final store = AppSettingsStore(storage: InMemoryAppSettingsStorage());
  addTearDown(store.dispose);
  return store;
}

SceneRoleplayRuntime _runtime(AppSettingsStore store, RoleTurnSkill roleSkill) {
  return SceneRoleplayRuntime(
    settingsStore: store,
    roleSkillRegistry: RoleSkillRegistry(
      settingsStore: store,
      externalSkills: [roleSkill],
    ),
    arbiterSkill: const _FakeArbiterSkill(),
  );
}

SceneBrief _brief({Map<String, Object?> metadata = const {}}) {
  return SceneBrief(
    chapterId: 'chapter-01',
    chapterTitle: '第一章',
    sceneId: 'scene-01',
    sceneTitle: '旧码头',
    sceneSummary: '两名角色在旧码头交换线索。',
    metadata: {'defaultRoleSkillId': 'fake_role_turn', ...metadata},
  );
}

List<ResolvedSceneCastMember> _cast() {
  return [
    ResolvedSceneCastMember(
      characterId: 'a',
      name: '阿岚',
      role: '调查者',
      contributions: [SceneCastContribution.action],
    ),
    ResolvedSceneCastMember(
      characterId: 'b',
      name: '伯恩',
      role: '线人',
      contributions: [SceneCastContribution.dialogue],
    ),
  ];
}

class _FakeRoleTurnSkill implements RoleTurnSkill {
  int calls = 0;

  @override
  String get skillId => 'fake_role_turn';

  @override
  String get version => '1.0.0';

  @override
  RoleSkillDescriptor get descriptor => const RoleSkillDescriptor(
    skillId: 'fake_role_turn',
    version: '1.0.0',
    inputSchema: {'type': 'CharacterVisibleContext'},
    outputSchema: {'type': 'SceneRoleplayTurn'},
  );

  @override
  Future<SceneRoleplayTurn> runTurn({
    required CharacterVisibleContext context,
    required int round,
  }) async {
    calls += 1;
    return SceneRoleplayTurn(
      round: round,
      characterId: context.characterId,
      name: context.characterName,
      intent: '推进第$round轮',
      visibleAction: '行动第$round轮',
      dialogue: '对白第$round轮',
      innerState: '内心第$round轮',
      taboo: '',
      rawText: 'fake',
      skillId: skillId,
      skillVersion: version,
    );
  }
}

class _BlockingRoleTurnSkill implements RoleTurnSkill {
  final startedCharacterIds = <String>[];
  final completedCharacterIds = <String>[];
  final _releases = <String, Completer<void>>{};
  final _waiters = <int, Completer<void>>{};

  Future<void> waitForStarted(int count) {
    if (startedCharacterIds.length >= count) {
      return Future<void>.value();
    }
    return (_waiters[count] ??= Completer<void>()).future;
  }

  void release(String characterId) {
    (_releases[characterId] ??= Completer<void>()).complete();
  }

  @override
  String get skillId => 'fake_role_turn';

  @override
  String get version => '1.0.0';

  @override
  RoleSkillDescriptor get descriptor => const RoleSkillDescriptor(
    skillId: 'fake_role_turn',
    version: '1.0.0',
    inputSchema: {'type': 'CharacterVisibleContext'},
    outputSchema: {'type': 'SceneRoleplayTurn'},
  );

  @override
  Future<SceneRoleplayTurn> runTurn({
    required CharacterVisibleContext context,
    required int round,
  }) async {
    startedCharacterIds.add(context.characterId);
    for (final entry in _waiters.entries) {
      if (!entry.value.isCompleted && startedCharacterIds.length >= entry.key) {
        entry.value.complete();
      }
    }
    await (_releases[context.characterId] ??= Completer<void>()).future;
    completedCharacterIds.add(context.characterId);
    return SceneRoleplayTurn(
      round: round,
      characterId: context.characterId,
      name: context.characterName,
      intent: '推进第$round轮',
      visibleAction: '行动第$round轮',
      dialogue: '对白第$round轮',
      innerState: '内心第$round轮',
      taboo: '',
      rawText: 'fake',
      skillId: skillId,
      skillVersion: version,
    );
  }
}

class _FakeArbiterSkill implements SceneArbiterSkill {
  const _FakeArbiterSkill();

  @override
  String get skillId => 'fake_arbiter';

  @override
  String get version => '1.0.0';

  @override
  Future<SceneRoleplayArbitration> arbitrate({
    required String sceneTitle,
    required String previousPublicState,
    required int round,
    required List<SceneRoleplayTurn> roundTurns,
    required List<SceneRoleplayTurn> transcript,
  }) async {
    return SceneRoleplayArbitration(
      fact: '第$round轮事实',
      state: '第$round轮状态',
      pressure: '第$round轮压力',
      nextPublicState: '$previousPublicState / 第$round轮事实',
      shouldStop: false,
      rawText: 'fake',
      skillId: skillId,
      skillVersion: version,
    );
  }
}
