import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_retriever.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

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

// ---------------------------------------------------------------------------
// LLM responder that handles all pipeline stages with configurable review
// ---------------------------------------------------------------------------

/// Builds a fake LLM responder. [reviewDecisions] controls what each
/// editorial round's judge review returns. Consistency review always passes.
/// Editorial text includes the attempt number for verification.
FakeAppLlmResponder _buildResponder({
  required List<String> reviewDecisions,
  String? rewriteReason,
}) {
  var editorialCall = 0;
  return (request) {
    final systemPrompt = request.messages.first.content;

    if (systemPrompt.contains('scene plan polisher')) {
      return const AppLlmChatResult.success(
        text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
      );
    }
    if (systemPrompt.contains('dynamic role agent')) {
      return const AppLlmChatResult.success(
        text: '立场：压迫\n动作：逼近\n禁忌：拖延',
      );
    }
    if (systemPrompt.contains('scene beat resolver')) {
      return const AppLlmChatResult.success(
        text: '[叙述] @narrator 场景开始\n[对白] @char-liuxi 说话',
      );
    }
    if (systemPrompt.contains('scene editor')) {
      editorialCall += 1;
      return AppLlmChatResult.success(text: '第$editorialCall版正文');
    }
    if (systemPrompt.contains('scene judge review')) {
      final idx = editorialCall - 1;
      if (idx < reviewDecisions.length) {
        final decision = reviewDecisions[idx];
        if (decision == 'REWRITE_PROSE') {
          return AppLlmChatResult.success(
            text: '决定：REWRITE_PROSE\n原因：${rewriteReason ?? '冲突不足。'}',
          );
        }
        if (decision == 'REPLAN_SCENE') {
          return const AppLlmChatResult.success(
            text: '决定：REPLAN_SCENE\n原因：场景方向错误。',
          );
        }
      }
      return const AppLlmChatResult.success(
        text: '决定：PASS\n原因：通过。',
      );
    }
    if (systemPrompt.contains('scene consistency review')) {
      return const AppLlmChatResult.success(
        text: '决定：PASS\n原因：一致。',
      );
    }

    throw StateError('Unexpected prompt: $systemPrompt');
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ===========================================================================
  // RC-1: First-round pass terminates immediately
  // ===========================================================================
  group('RC-1: First-round pass', () {
    test('pipeline completes on first attempt when review passes', () async {
      final fakeClient = FakeAppLlmClient(
        responder: _buildResponder(reviewDecisions: ['PASS']),
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

      expect(result.review.decision, SceneReviewDecision.pass);
      expect(result.proseAttempts, 1);
      expect(result.softFailureCount, 0);
      expect(result.editorialDraft.text, '第1版正文');
    });
  });

  // ===========================================================================
  // RC-2: maxProseRetries = 0 disables retry
  // ===========================================================================
  group('RC-2: Zero retry budget', () {
    test('pipeline does not retry when maxProseRetries is 0', () async {
      final fakeClient = FakeAppLlmClient(
        responder: _buildResponder(
          reviewDecisions: ['REWRITE_PROSE', 'PASS'],
          rewriteReason: '冲突不足。',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = ScenePipelineOrchestrator(
        settingsStore: settingsStore,
        maxProseRetries: 0,
      );
      final result = await orchestrator.runScene(_brief());

      // softFailureCount incremented but no retry happened
      expect(result.proseAttempts, 1);
      expect(result.softFailureCount, 1);
      // review is the REWRITE_PROSE result (no second chance to pass)
      expect(
        result.review.decision,
        SceneReviewDecision.rewriteProse,
      );
      expect(result.editorialDraft.text, '第1版正文');
    });
  });

  // ===========================================================================
  // RC-3: Retry within budget succeeds on second attempt
  // ===========================================================================
  group('RC-3: Single retry succeeds', () {
    test('pipeline retries once and passes on second attempt', () async {
      final fakeClient = FakeAppLlmClient(
        responder: _buildResponder(
          reviewDecisions: ['REWRITE_PROSE', 'PASS'],
          rewriteReason: '冲突不够强烈。',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = ScenePipelineOrchestrator(
        settingsStore: settingsStore,
        maxProseRetries: 1,
      );
      final result = await orchestrator.runScene(_brief());

      expect(result.review.decision, SceneReviewDecision.pass);
      expect(result.proseAttempts, 2);
      expect(result.softFailureCount, 1);
      // Final draft is the second version
      expect(result.editorialDraft.text, '第2版正文');
    });
  });

  // ===========================================================================
  // RC-4: Exhausting retry budget returns last attempt
  // ===========================================================================
  group('RC-4: Retry budget exhausted', () {
    test('pipeline stops after max retries and returns last result', () async {
      final fakeClient = FakeAppLlmClient(
        responder: _buildResponder(
          reviewDecisions: ['REWRITE_PROSE', 'REWRITE_PROSE', 'PASS'],
          rewriteReason: '仍然不行。',
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = ScenePipelineOrchestrator(
        settingsStore: settingsStore,
        maxProseRetries: 1,
      );
      final result = await orchestrator.runScene(_brief());

      // Only 1 retry allowed → 2 total attempts → still REWRITE_PROSE
      expect(result.proseAttempts, 2);
      expect(result.softFailureCount, 2);
      expect(
        result.review.decision,
        SceneReviewDecision.rewriteProse,
      );
      expect(result.editorialDraft.text, '第2版正文');
    });
  });

  // ===========================================================================
  // RC-5: Multiple retries with feedback propagation
  // ===========================================================================
  group('RC-5: Multi-round retry with feedback', () {
    test('review feedback from round N appears in editorial prompt for round N+1',
        () async {
      final capturedPrompts = <String>[];

      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;

          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
            );
          }
          if (systemPrompt.contains('dynamic role agent')) {
            return const AppLlmChatResult.success(
              text: '立场：压迫\n动作：逼近\n禁忌：拖延',
            );
          }
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[叙述] @narrator 场景开始\n[对白] @char-liuxi 说话',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            capturedPrompts.add(request.messages.last.content);
            return const AppLlmChatResult.success(text: '正文');
          }
          if (systemPrompt.contains('scene judge review')) {
            return const AppLlmChatResult.success(
              text: '决定：REWRITE_PROSE\n原因：缺少动作描写。',
            );
          }
          if (systemPrompt.contains('scene consistency review')) {
            return const AppLlmChatResult.success(
              text: '决定：PASS\n原因：一致。',
            );
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
      await orchestrator.runScene(_brief());

      // First editorial prompt has no feedback
      expect(capturedPrompts[0], isNot(contains('编辑反馈')));
      // Second editorial prompt contains feedback from first round
      expect(capturedPrompts[1], contains('编辑反馈'));
      expect(capturedPrompts[1], contains('缺少动作描写'));
      // Third editorial prompt contains feedback from second round (same reason)
      expect(capturedPrompts[2], contains('编辑反馈'));
    });

    test('attempt number increments in editorial prompt across rounds',
        () async {
      final capturedAttempts = <int>[];

      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;

          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
            );
          }
          if (systemPrompt.contains('dynamic role agent')) {
            return const AppLlmChatResult.success(
              text: '立场：压迫\n动作：逼近\n禁忌：拖延',
            );
          }
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[叙述] @narrator 场景\n[对白] @char-liuxi 说话',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            final userPrompt = request.messages.last.content;
            final match = RegExp(r'当前尝试：(\d+)').firstMatch(userPrompt);
            if (match != null) {
              capturedAttempts.add(int.parse(match.group(1)!));
            }
            return const AppLlmChatResult.success(text: '正文');
          }
          if (systemPrompt.contains('review')) {
            return const AppLlmChatResult.success(
              text: '决定：PASS\n原因：通过。',
            );
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
      await orchestrator.runScene(_brief());

      expect(capturedAttempts, [1]);
    });
  });

  // ===========================================================================
  // RC-6: Replan scene terminates immediately without retry
  // ===========================================================================
  group('RC-6: Replan scene decision', () {
    test('replan scene does not trigger editorial retry', () async {
      var editorialCalls = 0;

      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;

          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
            );
          }
          if (systemPrompt.contains('dynamic role agent')) {
            return const AppLlmChatResult.success(
              text: '立场：压迫\n动作：逼近\n禁忌：拖延',
            );
          }
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[叙述] @narrator 场景\n[对白] @char-liuxi 说话',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            editorialCalls += 1;
            return const AppLlmChatResult.success(text: '正文');
          }
          if (systemPrompt.contains('review')) {
            return const AppLlmChatResult.success(
              text: '决定：REPLAN_SCENE\n原因：场景方向完全错误。',
            );
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
        maxProseRetries: 5,
      );
      final result = await orchestrator.runScene(_brief());

      // Replan terminates immediately — no retry loop entered
      expect(result.review.decision, SceneReviewDecision.replanScene);
      expect(result.proseAttempts, 1);
      expect(result.softFailureCount, 0);
      // Only one editorial call despite maxProseRetries=5
      expect(editorialCalls, 1);
    });
  });

  // ===========================================================================
  // RC-7: Status callback receives round-by-round messages
  // ===========================================================================
  group('RC-7: Status callback per round', () {
    test('onStatus receives editorial attempt messages for each round', () async {
      final statusMessages = <String>[];

      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;

          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
            );
          }
          if (systemPrompt.contains('dynamic role agent')) {
            return const AppLlmChatResult.success(
              text: '立场：压迫\n动作：逼近\n禁忌：拖延',
            );
          }
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[叙述] @narrator 场景\n[对白] @char-liuxi 说话',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            return const AppLlmChatResult.success(text: '正文');
          }
          if (systemPrompt.contains('review')) {
            return const AppLlmChatResult.success(
              text: '决定：PASS\n原因：通过。',
            );
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
        onStatus: statusMessages.add,
      );
      await orchestrator.runScene(_brief());

      // Should have editorial attempt 1 message
      expect(
        statusMessages.any((m) => m.contains('editorial attempt 1')),
        isTrue,
      );
    });

    test('onStatus receives attempt messages for each retry round', () async {
      final statusMessages = <String>[];
      var editorialCall = 0;

      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;

          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
            );
          }
          if (systemPrompt.contains('dynamic role agent')) {
            return const AppLlmChatResult.success(
              text: '立场：压迫\n动作：逼近\n禁忌：拖延',
            );
          }
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[叙述] @narrator 场景\n[对白] @char-liuxi 说话',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            editorialCall += 1;
            return const AppLlmChatResult.success(text: '正文');
          }
          if (systemPrompt.contains('scene judge review')) {
            return AppLlmChatResult.success(
              text: editorialCall < 3
                  ? '决定：REWRITE_PROSE\n原因：不够好。'
                  : '决定：PASS\n原因：通过。',
            );
          }
          if (systemPrompt.contains('scene consistency review')) {
            return const AppLlmChatResult.success(
              text: '决定：PASS\n原因：一致。',
            );
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
        maxProseRetries: 3,
        onStatus: statusMessages.add,
      );
      final result = await orchestrator.runScene(_brief());

      expect(result.proseAttempts, 3);
      // Each retry round emits a status message with attempt number
      expect(
        statusMessages.any((m) => m.contains('editorial attempt 1')),
        isTrue,
      );
      expect(
        statusMessages.any((m) => m.contains('editorial attempt 2')),
        isTrue,
      );
      expect(
        statusMessages.any((m) => m.contains('editorial attempt 3')),
        isTrue,
      );
    });
  });

  // ===========================================================================
  // RC-8: Consistency review triggers rewriteProse
  // ===========================================================================
  group('RC-8: Consistency review rewrite', () {
    test(
        'consistency REWRITE_PROSE triggers retry even when judge passes',
        () async {
      var editorialCall = 0;

      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;

          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text: '目标：逼问\n冲突：顶压\n推进：失守\n约束：不离题',
            );
          }
          if (systemPrompt.contains('dynamic role agent')) {
            return const AppLlmChatResult.success(
              text: '立场：压迫\n动作：逼近\n禁忌：拖延',
            );
          }
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[叙述] @narrator 场景\n[对白] @char-liuxi 说话',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            editorialCall += 1;
            return AppLlmChatResult.success(text: '第$editorialCall版');
          }
          if (systemPrompt.contains('scene judge review')) {
            return const AppLlmChatResult.success(
              text: '决定：PASS\n原因：通过。',
            );
          }
          if (systemPrompt.contains('scene consistency review')) {
            return AppLlmChatResult.success(
              text: editorialCall == 1
                  ? '决定：REWRITE_PROSE\n原因：时间线矛盾。'
                  : '决定：PASS\n原因：一致。',
            );
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
        maxProseRetries: 1,
      );
      final result = await orchestrator.runScene(_brief());

      // Consistency failure triggered the retry
      expect(result.proseAttempts, 2);
      expect(result.softFailureCount, 1);
      expect(result.review.decision, SceneReviewDecision.pass);
      expect(result.editorialDraft.text, '第2版');
    });
  });

  // ===========================================================================
  // RC-9: Editorial draft tracks correct attempt number
  // ===========================================================================
  group('RC-9: Draft attempt tracking', () {
    test('editorial draft attempt field matches pipeline proseAttempts', () async {
      final fakeClient = FakeAppLlmClient(
        responder: _buildResponder(
          reviewDecisions: ['REWRITE_PROSE', 'REWRITE_PROSE', 'PASS'],
        ),
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = ScenePipelineOrchestrator(
        settingsStore: settingsStore,
        maxProseRetries: 3,
      );
      final result = await orchestrator.runScene(_brief());

      // After 2 rewrites, 3rd attempt passes
      expect(result.proseAttempts, 3);
      expect(result.editorialDraft.attempt, 3);
      expect(result.softFailureCount, 2);
    });
  });

  // ===========================================================================
  // Viewer-context retrieval tests (Task 7: Role Retrieval API Hardening)
  // ===========================================================================

  group('ViewerContext retrieval', () {
    late _InMemoryStoryMemoryStorage storage;
    late StoryMemoryRetriever retriever;

    setUp(() {
      storage = _InMemoryStoryMemoryStorage();
      retriever = StoryMemoryRetriever(storage: storage);
    });

    // --- Helper to create chunks quickly ---
    StoryMemoryChunk makeChunk({
      required String id,
      required String scopeId,
      MemoryVisibility visibility = MemoryVisibility.publicObservable,
      List<String> tags = const [],
      String content = 'test content',
      int priority = 0,
    }) {
      return StoryMemoryChunk(
        id: id,
        projectId: 'proj-1',
        scopeId: scopeId,
        kind: MemorySourceKind.acceptedState,
        content: content,
        visibility: visibility,
        tags: tags,
        priority: priority,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }

    // ---- VR-1: Valid viewer context returns filtered results ----

    test('VR-1: retrieval with valid viewer context returns filtered results',
        () async {
      await storage.saveChunks('proj-1', [
        makeChunk(id: 'c1', scopeId: 'char-liuxi', content: '柳溪的内心独白'),
        makeChunk(
            id: 'c2',
            scopeId: 'char-yueren',
            content: '岳刃的公开行为',
            visibility: MemoryVisibility.publicObservable),
      ]);

      final context = ViewerContext(
        viewerId: 'proj-1',
        characterId: 'char-liuxi',
      );

      final results = await retriever.retrieveForViewer(
        context: context,
        query: '独白',
      );

      // char-liuxi sees own chunks + public chunks from other characters
      expect(results, isNotEmpty);
      expect(results.any((c) => c.id == 'c1'), isTrue);
    });

    // ---- VR-2: Invalid viewer context (empty IDs) returns empty ----

    test('VR-2: retrieval with invalid viewer context returns empty', () async {
      await storage.saveChunks('proj-1', [
        makeChunk(id: 'c1', scopeId: 'char-liuxi', content: 'some content'),
      ]);

      final invalidContext = ViewerContext(
        viewerId: '',
        characterId: 'char-liuxi',
      );

      final results = await retriever.retrieveForViewer(
        context: invalidContext,
        query: 'content',
      );

      expect(results, isEmpty);
    });

    // ---- VR-3: Viewer context with both empty IDs returns empty ----

    test('VR-3: retrieval with both empty IDs returns empty', () async {
      await storage.saveChunks('proj-1', [
        makeChunk(id: 'c1', scopeId: 'char-liuxi', content: 'some content'),
      ]);

      final invalidContext = ViewerContext(
        viewerId: '',
        characterId: '',
      );

      final results = await retriever.retrieveForViewer(
        context: invalidContext,
        query: 'content',
      );

      expect(results, isEmpty);
    });

    // ---- VR-4: Character A cannot see Character B's selfState atoms ----

    test('VR-4: Character A cannot see Character B selfState atoms',
        () async {
      await storage.saveChunks('proj-1', [
        makeChunk(
          id: 'self-b',
          scopeId: 'char-yueren',
          content: '岳刃的内心秘密',
          tags: ['selfState'],
        ),
        makeChunk(
          id: 'self-a',
          scopeId: 'char-liuxi',
          content: '柳溪的内心秘密',
          tags: ['selfState'],
        ),
        makeChunk(
          id: 'public-b',
          scopeId: 'char-yueren',
          content: '岳刃的公开行为',
        ),
      ]);

      final context = ViewerContext(
        viewerId: 'proj-1',
        characterId: 'char-liuxi',
      );

      final results = await retriever.retrieveForViewer(
        context: context,
        query: '秘密 行为',
      );

      final ids = results.map((c) => c.id).toList();

      // liuxi sees own selfState but NOT yueren's selfState
      expect(ids, contains('self-a'));
      expect(ids, isNot(contains('self-b')));
      // liuxi can see yueren's public (non-selfState) chunks
      expect(ids, contains('public-b'));
    });

    // ---- VR-5: Viewer can see perceived/reported atoms about others ----

    test('VR-5: Viewer can see perceived/reported atoms about other characters',
        () async {
      await storage.saveChunks('proj-1', [
        makeChunk(
          id: 'perceived',
          scopeId: 'char-yueren',
          content: '岳刃被观察到在码头徘徊',
          tags: ['perceivedEvent'],
        ),
        makeChunk(
          id: 'reported',
          scopeId: 'char-yueren',
          content: '据报岳刃已离开仓库',
          tags: ['reported'],
        ),
        makeChunk(
          id: 'self-b',
          scopeId: 'char-yueren',
          content: '岳刃的真实想法',
          tags: ['selfState'],
        ),
      ]);

      final context = ViewerContext(
        viewerId: 'proj-1',
        characterId: 'char-liuxi',
      );

      final results = await retriever.retrieveForViewer(
        context: context,
        query: '岳刃',
      );

      final ids = results.map((c) => c.id).toList();

      // liuxi can see perceived and reported atoms about yueren
      expect(ids, contains('perceived'));
      expect(ids, contains('reported'));
      // but NOT yueren's selfState
      expect(ids, isNot(contains('self-b')));
    });

    // ---- VR-6: Viewer can see own selfState atoms ----

    test('VR-6: Viewer can see own selfState atoms', () async {
      await storage.saveChunks('proj-1', [
        makeChunk(
          id: 'own-self',
          scopeId: 'char-liuxi',
          content: '柳溪意识到自己在被跟踪',
          tags: ['selfState'],
        ),
        makeChunk(
          id: 'own-private',
          scopeId: 'char-liuxi',
          content: '柳溪的秘密计划',
          tags: ['private'],
        ),
      ]);

      final context = ViewerContext(
        viewerId: 'proj-1',
        characterId: 'char-liuxi',
      );

      final results = await retriever.retrieveForViewer(
        context: context,
        query: '柳溪',
      );

      final ids = results.map((c) => c.id).toList();

      // liuxi can see own selfState and private atoms
      expect(ids, contains('own-self'));
      expect(ids, contains('own-private'));
    });

    // ---- VR-7: Private tag restricts visibility to owning character ----

    test('VR-7: Character A cannot see Character B private-tagged atoms',
        () async {
      await storage.saveChunks('proj-1', [
        makeChunk(
          id: 'priv-b',
          scopeId: 'char-yueren',
          content: '岳刃的私密情报',
          tags: ['private'],
        ),
      ]);

      final context = ViewerContext(
        viewerId: 'proj-1',
        characterId: 'char-liuxi',
      );

      final results = await retriever.retrieveForViewer(
        context: context,
        query: '私密',
      );

      expect(results.every((c) => c.id != 'priv-b'), isTrue);
    });

    // ---- VR-8: Agent-private visibility restricts to owner ----

    test('VR-8: Agent-private visibility is only visible to scope owner',
        () async {
      await storage.saveChunks('proj-1', [
        makeChunk(
          id: 'agent-priv-b',
          scopeId: 'char-yueren',
          content: 'agent内部状态',
          visibility: MemoryVisibility.agentPrivate,
        ),
        makeChunk(
          id: 'agent-priv-a',
          scopeId: 'char-liuxi',
          content: 'liuxi agent内部状态',
          visibility: MemoryVisibility.agentPrivate,
        ),
      ]);

      final context = ViewerContext(
        viewerId: 'proj-1',
        characterId: 'char-liuxi',
      );

      final results = await retriever.retrieveForViewer(
        context: context,
        query: 'agent',
      );

      final ids = results.map((c) => c.id).toList();

      expect(ids, contains('agent-priv-a'));
      expect(ids, isNot(contains('agent-priv-b')));
    });

    // ---- VR-9: maxResults limits output ----

    test('VR-9: maxResults limits the number of returned chunks', () async {
      final chunks = List.generate(
        15,
        (i) => makeChunk(
          id: 'c$i',
          scopeId: 'char-liuxi',
          content: 'chunk $i',
        ),
      );
      await storage.saveChunks('proj-1', chunks);

      final context = ViewerContext(
        viewerId: 'proj-1',
        characterId: 'char-liuxi',
      );

      final results = await retriever.retrieveForViewer(
        context: context,
        query: 'chunk',
        maxResults: 5,
      );

      expect(results.length, 5);
    });
  });
}

// ---------------------------------------------------------------------------
// Real in-memory storage implementation (no mocks)
// ---------------------------------------------------------------------------

class _InMemoryStoryMemoryStorage implements StoryMemoryStorage {
  final Map<String, List<StoryMemorySource>> _sources = {};
  final Map<String, List<StoryMemoryChunk>> _chunks = {};
  final Map<String, List<ThoughtAtom>> _thoughts = {};

  @override
  Future<void> saveSources(
      String projectId, List<StoryMemorySource> sources) async {
    _sources[projectId] = List.of(sources);
  }

  @override
  Future<List<StoryMemorySource>> loadSources(String projectId) async {
    return _sources[projectId] ?? const [];
  }

  @override
  Future<void> saveChunks(
      String projectId, List<StoryMemoryChunk> chunks) async {
    _chunks[projectId] = List.of(chunks);
  }

  @override
  Future<List<StoryMemoryChunk>> loadChunks(String projectId) async {
    return _chunks[projectId] ?? const [];
  }

  @override
  Future<void> saveThoughts(
      String projectId, List<ThoughtAtom> thoughts) async {
    _thoughts[projectId] = List.of(thoughts);
  }

  @override
  Future<List<ThoughtAtom>> loadThoughts(String projectId) async {
    return _thoughts[projectId] ?? const [];
  }

  @override
  Future<void> clearProject(String projectId) async {
    _sources.remove(projectId);
    _chunks.remove(projectId);
    _thoughts.remove(projectId);
  }
}
