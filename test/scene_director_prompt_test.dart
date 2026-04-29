import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/director_memory.dart';
import 'package:novel_writer/features/story_generation/data/scene_director_orchestrator.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  group('SceneDirectorOrchestrator prompt generation', () {
    test('local plan lists cast names in conflict line', () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'offline',
          ),
        ),
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(
        brief: _brief(),
        cast: [
          ResolvedSceneCastMember(
            characterId: 'char-liuxi',
            name: '柳溪',
            role: '调查记者',
            contributions: const [SceneCastContribution.action],
          ),
          ResolvedSceneCastMember(
            characterId: 'char-shendu',
            name: '沈渡',
            role: '港区向导',
            contributions: const [SceneCastContribution.dialogue],
          ),
        ],
      );

      expect(output.text, contains('冲突：柳溪与沈渡在目标上相互施压'));
    });

    test('local plan uses default conflict when cast is empty', () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'offline',
          ),
        ),
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(
        brief: _brief(),
        cast: const [],
      );

      expect(output.text, contains('冲突：围绕场景目标推进'));
    });

    test('local plan falls back to sceneSummary when targetBeat is empty',
        () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'offline',
          ),
        ),
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(
        brief: SceneBrief(
          chapterId: 'chapter-02',
          chapterTitle: '第二章',
          sceneId: 'scene-02',
          sceneTitle: '巷口',
          sceneSummary: '柳溪独自站在雨中等待消息。',
          targetBeat: '',
          worldNodeIds: const [],
        ),
        cast: const [],
      );

      final lines = output.text.split('\n');
      expect(lines[0], startsWith('目标：'));
      expect(lines[0], contains('柳溪独自站在雨中等待消息'));
      expect(lines[2], startsWith('推进：'));
      expect(lines[2], contains('柳溪独自站在雨中等待消息'));
    });

    test('local plan includes worldNodeIds in constraints', () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'offline',
          ),
        ),
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(
        brief: SceneBrief(
          chapterId: 'chapter-01',
          chapterTitle: '第一章',
          sceneId: 'scene-01',
          sceneTitle: '码头',
          sceneSummary: '交易现场。',
          worldNodeIds: const ['old-harbor', 'customs-yard'],
        ),
        cast: const [],
      );

      expect(
        output.text,
        contains('约束：遵守old-harbor/customs-yard相关规则'),
      );
    });

    test('local plan uses default constraints when worldNodeIds is empty',
        () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'offline',
          ),
        ),
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(
        brief: SceneBrief(
          chapterId: 'chapter-01',
          chapterTitle: '第一章',
          sceneId: 'scene-01',
          sceneTitle: '码头',
          sceneSummary: '交易现场。',
          worldNodeIds: const [],
        ),
        cast: const [],
      );

      expect(output.text, contains('约束：遵守当前世界观和角色设定'));
    });

    test('local plan always outputs exactly 4 lines', () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'offline',
          ),
        ),
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(brief: _brief(), cast: const []);

      final lines = output.text.split('\n');
      expect(lines, hasLength(4));
      expect(lines[0], startsWith('目标：'));
      expect(lines[1], startsWith('冲突：'));
      expect(lines[2], startsWith('推进：'));
      expect(lines[3], startsWith('约束：'));
    });

    test('system prompt instructs 4-line structured output', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text: '目标：逼问\n冲突：施压\n推进：突破\n约束：不拖延',
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
      await orchestrator.run(brief: _brief(), cast: const []);

      final request = fakeClient.requests.single;
      final systemPrompt = request.messages.first.content;

      expect(systemPrompt, contains('scene plan polisher'));
      expect(systemPrompt, contains('目标：'));
      expect(systemPrompt, contains('冲突：'));
      expect(systemPrompt, contains('推进：'));
      expect(systemPrompt, contains('约束：'));
      expect(systemPrompt, contains('Polish the existing plan only'));
    });

    test('user prompt contains task type, chapter, scene, and local plan',
        () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text: '目标：a\n冲突：b\n推进：c\n约束：d',
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
      await orchestrator.run(brief: _brief(), cast: const []);

      final request = fakeClient.requests.single;
      final userPrompt = request.messages.last.content;

      expect(userPrompt, contains('任务：scene_director_polish'));
      expect(userPrompt, contains('格式：目标/冲突/推进/约束'));
      expect(userPrompt, contains('章：'));
      expect(userPrompt, contains('第一章'));
      expect(userPrompt, contains('场：'));
      expect(userPrompt, contains('仓库门外'));
      expect(userPrompt, contains('本地计划：'));
    });

    test('user prompt includes RAG context when provided', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text: '目标：a\n冲突：b\n推进：c\n约束：d',
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
      await orchestrator.run(
        brief: _brief(),
        cast: const [],
        ragContext: '码头仓库区曾被海关查封，内部暗道连通旧船坞。',
      );

      final request = fakeClient.requests.single;
      final userPrompt = request.messages.last.content;

      expect(userPrompt, contains('码头仓库区曾被海关查封'));
    });

    test('user prompt omits RAG context when null or empty', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text: '目标：a\n冲突：b\n推进：c\n约束：d',
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
      await orchestrator.run(
        brief: _brief(),
        cast: const [],
        ragContext: 'some context',
      );
      await orchestrator.run(brief: _brief(), cast: const [], ragContext: '');
      await orchestrator.run(brief: _brief(), cast: const []);

      // First request includes RAG context
      final firstPrompt = fakeClient.requests[0].messages.last.content;
      expect(firstPrompt, contains('some context'));

      // Second and third requests should not have RAG context appended
      for (final request in fakeClient.requests.skip(1)) {
        final userPrompt = request.messages.last.content;
        // The user prompt should end with the local plan content,
        // not have an extra empty line from ragContext
        expect(userPrompt, isNot(endsWith('\n\n')));
        expect(userPrompt, isNot(contains('some context')));
      }
    });

    test('returns polished plan when LLM returns valid 4-line output',
        () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text: '目标：逼问账本下落\n冲突：柳溪与岳刃正面施压\n推进：信息逐步揭露\n约束：不离题、不拖延',
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
      final output = await orchestrator.run(brief: _brief(), cast: const []);

      expect(output.text, contains('逼问账本下落'));
      expect(output.text, contains('柳溪与岳刃正面施压'));
      expect(output.text, contains('信息逐步揭露'));
      expect(output.text, contains('不离题、不拖延'));
    });

    test('falls back to local plan when LLM returns unstructured text',
        () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text: '这场戏需要柳溪用压迫感逼岳刃开口，同时保持悬念。',
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
          ResolvedSceneCastMember(
            characterId: 'char-liuxi',
            name: '柳溪',
            role: '调查记者',
            contributions: const [SceneCastContribution.action],
          ),
        ],
      );

      // Should be the local plan, not the unstructured LLM text
      expect(output.text, isNot(contains('这场戏需要')));
      expect(output.text, startsWith('目标：'));
      expect(output.text, contains('柳溪在目标上相互施压'));
    });

    test('falls back when LLM returns 3 lines instead of 4', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) =>
            const AppLlmChatResult.success(text: '目标：a\n冲突：b\n推进：c'),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(brief: _brief(), cast: const []);

      // 3 lines fails validation → local plan
      final lines = output.text.split('\n');
      expect(lines, hasLength(4));
    });

    test('falls back when LLM output has wrong line prefixes', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text: '目标：a\n冲突：b\n发展：c\n约束：d'),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(brief: _brief(), cast: const []);

      // "发展" ≠ "推进" → fails validation → local plan
      final lines = output.text.split('\n');
      expect(lines[2], startsWith('推进：'));
    });

    test('truncates long chapter and scene identifiers to 40 chars', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text: '目标：a\n冲突：b\n推进：c\n约束：d',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final longTitle = '非常非常非常非常非常非常非常非常非常非常非常长的章节标题超过四十个字';
      final longSceneTitle = '同样非常非常非常非常非常非常非常非常非常长的场景标题也超过四十个字';

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      await orchestrator.run(
        brief: SceneBrief(
          chapterId: 'chapter-01',
          chapterTitle: longTitle,
          sceneId: 'scene-01',
          sceneTitle: longSceneTitle,
          sceneSummary: '摘要',
        ),
        cast: const [],
      );

      final request = fakeClient.requests.single;
      final userPrompt = request.messages.last.content;

      final chapterLine =
          userPrompt.split('\n').firstWhere((line) => line.startsWith('章：'));
      final sceneLine =
          userPrompt.split('\n').firstWhere((line) => line.startsWith('场：'));

      // _compact with maxChars: 40 → chapter/scene identifier ≤ 40 chars
      expect(chapterLine.length, lessThanOrEqualTo(42)); // '章：' prefix + 40
      expect(sceneLine.length, lessThanOrEqualTo(42));
    });

    test('truncates long targetBeat and sceneSummary to 48 chars', () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'offline',
          ),
        ),
      );
      addTearDown(settingsStore.dispose);

      final longSummary = '这是'
          '一个非常非常非常非常非常非常非常非常非常非常'
          '非常非常非常非常非常长的场景摘要超过四十八个字符的限制';

      final orchestrator = SceneDirectorOrchestrator(
        settingsStore: settingsStore,
      );
      final output = await orchestrator.run(
        brief: SceneBrief(
          chapterId: 'chapter-01',
          chapterTitle: '第一章',
          sceneId: 'scene-01',
          sceneTitle: '码头',
          sceneSummary: longSummary,
        ),
        cast: const [],
      );

      final lines = output.text.split('\n');
      // Each line's content after the prefix should be ≤ 48 chars
      for (final line in lines) {
        final content = line.split('：').skip(1).join('：');
        expect(content.length, lessThanOrEqualTo(48));
      }
    });
  });

  group('DirectorCue', () {
    test('toJson/fromJson round-trip', () {
      final cue = DirectorCue(
        id: 'cue-1',
        sceneId: 'scene-01',
        label: 'goal_pacing',
        goal: '逼问账本下落',
        pressure: 0.7,
        pacing: '先慢后快',
        beatGuidance: ['开场对峙', '施压升级', '突破'],
        exitCondition: '获得线索',
        cueBudget: 3,
      );
      final decoded = DirectorCue.fromJson(cue.toJson());
      expect(decoded, equals(cue));
      expect(decoded.beatGuidance, equals(['开场对峙', '施压升级', '突破']));
    });

    test('pressure is clamped to 0.0-1.0', () {
      final high = DirectorCue(
        id: 'h', sceneId: 's', label: 'x', pressure: 5.0,
      );
      expect(high.pressure, equals(1.0));
      final low = DirectorCue(
        id: 'l', sceneId: 's', label: 'x', pressure: -1.0,
      );
      expect(low.pressure, equals(0.0));
    });

    test('toPromptText includes label and goal', () {
      final cue = DirectorCue(
        id: 'cue-1', sceneId: 's1', label: 'conflict',
        goal: '柳溪与岳刃正面施压', pressure: 0.8, pacing: '渐强',
      );
      final text = cue.toPromptText();
      expect(text, contains('指令[conflict]: 柳溪与岳刃正面施压'));
      expect(text, contains('节奏: 渐强'));
      expect(text, contains('张力: 80%'));
    });

    test('toPromptText omits empty optional fields', () {
      final cue = DirectorCue(
        id: 'c1', sceneId: 's1', label: 'test', goal: 'do something',
      );
      final text = cue.toPromptText();
      expect(text, isNot(contains('节奏:')));
      expect(text, isNot(contains('退出条件:')));
    });

    test('malformed json uses defaults', () {
      final cue = DirectorCue.fromJson({});
      expect(cue.id, equals(''));
      expect(cue.pressure, equals(0.0));
      expect(cue.cueBudget, equals(3));
      expect(cue.beatGuidance, isEmpty);
    });
  });

  group('DirectorTaskCard', () {
    test('toJson/fromJson round-trip with nested cues', () {
      final card = DirectorTaskCard(
        sceneId: 'scene-01',
        sceneTitle: '仓库门外',
        objective: '逼出账本去向',
        pressure: 0.6,
        pacing: '渐强',
        cues: [
          DirectorCue(id: 'c1', sceneId: 'scene-01', label: 'goal'),
          DirectorCue(id: 'c2', sceneId: 'scene-01', label: 'conflict'),
        ],
        exitCondition: '获得线索',
      );
      final decoded = DirectorTaskCard.fromJson(card.toJson());
      expect(decoded, equals(card));
      expect(decoded.cues, hasLength(2));
    });
  });

  group('DirectorRoundState', () {
    test('isExhausted tracks round vs maxRounds', () {
      final fresh = DirectorRoundState(sceneId: 's1', round: 0, maxRounds: 3);
      expect(fresh.isExhausted, isFalse);
      final exhausted = DirectorRoundState(sceneId: 's1', round: 3, maxRounds: 3);
      expect(exhausted.isExhausted, isTrue);
    });

    test('hasTaskCard reflects taskCard presence', () {
      final without = DirectorRoundState(sceneId: 's1');
      expect(without.hasTaskCard, isFalse);
      final withCard = DirectorRoundState(
        sceneId: 's1',
        taskCard: DirectorTaskCard(
          sceneId: 's1', sceneTitle: 't', objective: 'o',
        ),
      );
      expect(withCard.hasTaskCard, isTrue);
    });

    test('toJson/fromJson round-trip', () {
      final state = DirectorRoundState(
        sceneId: 's1',
        round: 1,
        maxRounds: 3,
        taskCard: DirectorTaskCard(
          sceneId: 's1', sceneTitle: '巷口', objective: '侦查',
        ),
        appliedCues: [
          DirectorCue(id: 'c1', sceneId: 's1', label: 'goal'),
        ],
        outcome: 'partial',
      );
      final decoded = DirectorRoundState.fromJson(state.toJson());
      expect(decoded, equals(state));
    });
  });

  group('DirectorMemory with cue metadata', () {
    test('toPromptText includes round state when present', () {
      final memory = DirectorMemory(
        activeRoundState: DirectorRoundState(
          sceneId: 'scene-01',
          round: 1,
          maxRounds: 3,
          taskCard: DirectorTaskCard(
            sceneId: 'scene-01',
            sceneTitle: '仓库门外',
            objective: '逼问账本下落',
            pacing: '渐强',
            exitCondition: '获得线索',
          ),
        ),
      );
      final text = memory.toPromptText();
      expect(text, contains('导演轮次: 1/3'));
      expect(text, contains('场景任务: 逼问账本下落'));
      expect(text, contains('节奏: 渐强'));
      expect(text, contains('退出条件: 获得线索'));
    });

    test('toPromptText includes applied cue text', () {
      final memory = DirectorMemory(
        activeRoundState: DirectorRoundState(
          sceneId: 'scene-01',
          round: 0,
          appliedCues: [
            DirectorCue(
              id: 'c1', sceneId: 'scene-01', label: 'conflict',
              goal: '柳溪与岳刃正面施压', pressure: 0.8,
            ),
          ],
        ),
      );
      final text = memory.toPromptText();
      expect(text, contains('指令[conflict]: 柳溪与岳刃正面施压'));
      expect(text, contains('张力: 80%'));
    });

    test('toPromptText returns empty when no reviews and no round state', () {
      final memory = DirectorMemory();
      expect(memory.toPromptText(), equals(''));
    });

    test('incorporate preserves activeRoundState', () {
      final roundState = DirectorRoundState(sceneId: 's1', round: 1);
      final memory = DirectorMemory(activeRoundState: roundState);
      final updated = memory.incorporate(
        SceneReviewDigest(
          sceneId: 's1',
          decision: SceneReviewDecision.pass,
        ),
      );
      expect(updated.activeRoundState, isNotNull);
      expect(updated.activeRoundState!.sceneId, equals('s1'));
    });
  });
}

SceneBrief _brief() {
  return SceneBrief(
    chapterId: 'chapter-01',
    chapterTitle: '第一章 雨夜码头',
    sceneId: 'scene-01',
    sceneTitle: '仓库门外',
    sceneSummary: '柳溪在风雨中拦住岳刃，必须逼出货单去向。',
    targetBeat: '拿到账本去向，并把沈渡拖上同一条船。',
    worldNodeIds: const ['old-harbor', 'customs-yard'],
  );
}
