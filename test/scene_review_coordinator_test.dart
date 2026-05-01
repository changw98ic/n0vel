import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart'
    as pipeline;
import 'package:novel_writer/features/story_generation/data/scene_review_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/scene_state_resolver.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_formatter_trace.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';

import 'test_support/fake_app_llm_client.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

SceneBrief _brief({Map<String, Object?> metadata = const {}}) => SceneBrief(
  chapterId: 'chapter-01',
  chapterTitle: '第一章 雨夜码头',
  sceneId: 'scene-01',
  sceneTitle: '仓库门外',
  sceneSummary: '柳溪在风雨中拦住岳刃。',
  metadata: metadata,
);

const _director = SceneDirectorOutput(text: '目标：逼问\n冲突：顶压\n推进：失守');

const _prose = SceneProseDraft(text: '柳溪在雨中拦住岳刃。"货单呢？"她逼近一步。', attempt: 1);

const _roleOutputs = [
  DynamicRoleAgentOutput(
    characterId: 'char-liuxi',
    name: '柳溪',
    text: '立场：压迫\n动作：逼近半步',
  ),
  DynamicRoleAgentOutput(
    characterId: 'char-yueren',
    name: '岳刃',
    text: '立场：抗拒\n动作：转身',
  ),
];

AppSettingsStore _setupStore(FakeAppLlmClient fakeClient) {
  final store = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: fakeClient,
  );
  addTearDown(store.dispose);
  return store;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ===========================================================================
  // review() — full pass-through
  // ===========================================================================
  group('SceneReviewCoordinator.review()', () {
    test('default review uses a single combined LLM pass', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          final user = request.messages.last.content;
          expect(system, contains('scene combined review'));
          expect(system, contains('scene judge review'));
          expect(system, contains('scene consistency review'));
          expect(system, contains('scene roleplay fidelity review'));
          expect(user, contains('任务：scene_combined_review'));
          expect(
            user,
            contains(
              '评审类别：prose, scene_plan, chapter_plan, continuity, '
              'character_state, world_state',
            ),
          );
          return const AppLlmChatResult.success(text: '决定：PASS\n原因：冲突成立，动线合理。');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(fakeClient.requests, hasLength(1));
      expect(result.judge.status, SceneReviewStatus.pass);
      expect(result.judge.reason, '冲突成立，动线合理。');
      expect(result.consistency.status, SceneReviewStatus.pass);
      expect(result.decision, SceneReviewDecision.pass);
    });

    test('includes noninteractive cast boundaries in review prompt', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final user = request.messages.last.content;
          expect(user, contains('非行动角色边界'));
          expect(user, contains('陈默'));
          expect(user, contains('不可主动行动、说话或产生即时心理描写'));
          expect(user, contains('也不可主动移动、喷吐、伸出、攻击'));
          return const AppLlmChatResult.success(text: '决定：PASS\n原因：角色边界成立。');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: SceneBrief(
          chapterId: 'chapter-01',
          chapterTitle: '第一章 无声的共振层',
          sceneId: 'scene-02',
          sceneTitle: '被缝嘴的笑者',
          sceneSummary: '陆沉扫描陈默的尸体。',
          cast: [
            SceneCastCandidate(
              characterId: 'victim-chen',
              name: '陈默',
              role: '受害者遗体',
              participation: const SceneCastParticipation(
                interaction: '缝合嘴角渗出黑色液体',
              ),
              metadata: const {
                'roleplayMode': 'evidence',
                'canAct': false,
                'lifeState': 'corpse',
              },
            ),
          ],
        ),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.decision, SceneReviewDecision.pass);
    });

    test(
      'local boundary guard rewrites when a corpse body becomes active',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：模型误判通过。');
          },
        );
        final store = _setupStore(fakeClient);
        final coordinator = SceneReviewCoordinator(settingsStore: store);

        final result = await coordinator.review(
          brief: SceneBrief(
            chapterId: 'chapter-01',
            chapterTitle: '第一章 无声的共振层',
            sceneId: 'scene-02',
            sceneTitle: '被缝嘴的笑者',
            sceneSummary: '陆沉扫描陈默的尸体。',
            cast: [
              SceneCastCandidate(
                characterId: 'victim-chen',
                name: '陈默',
                role: '受害者遗体',
                metadata: const {
                  'roleplayMode': 'evidence',
                  'canAct': false,
                  'lifeState': 'corpse',
                },
              ),
            ],
          ),
          director: _director,
          roleOutputs: _roleOutputs,
          prose: const SceneProseDraft(
            text: '陈默嘴角的黑色骨线开始蠕动，随后从口腔激射而出。',
            attempt: 1,
          ),
        );

        expect(result.decision, SceneReviewDecision.rewriteProse);
        expect(result.judge.status, SceneReviewStatus.rewriteProse);
        expect(result.judge.reason, contains('非行动角色边界违规'));
      },
    );

    test(
      'blocking review mode metadata still uses the default combined pass',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final system = request.messages.first.content;
            expect(system, contains('scene combined review'));
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：没有阻塞问题。');
          },
        );
        final store = _setupStore(fakeClient);
        final formatterTraceSink = _RecordingFormatterTraceSink();
        final coordinator = SceneReviewCoordinator(
          settingsStore: store,
          formatterTraceSink: formatterTraceSink,
        );

        final result = await coordinator.review(
          brief: _brief(metadata: const {'reviewMode': 'blocking'}),
          director: _director,
          roleOutputs: _roleOutputs,
          prose: _prose,
        );

        expect(fakeClient.requests, hasLength(1));
        expect(result.decision, SceneReviewDecision.pass);
        expect(result.judge.reason, '没有阻塞问题。');
        expect(result.consistency.status, SceneReviewStatus.pass);
      },
    );

    test('judge REWRITE_PROSE → decision is rewriteProse', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          if (system.contains('scene judge review')) {
            return const AppLlmChatResult.success(
              text: '决定：REWRITE_PROSE\n原因：对话不够自然。',
            );
          }
          if (system.contains('scene consistency review')) {
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：一致。');
          }
          throw StateError('Unexpected prompt');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.judge.status, SceneReviewStatus.rewriteProse);
      expect(result.decision, SceneReviewDecision.rewriteProse);
    });

    test('combined REPLAN_SCENE → decision is replanScene', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          if (system.contains('scene combined review')) {
            return const AppLlmChatResult.success(
              text: '决定：REPLAN_SCENE\n原因：角色行为与设定矛盾。',
            );
          }
          throw StateError('Unexpected prompt');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.consistency.status, SceneReviewStatus.replanScene);
      expect(result.decision, SceneReviewDecision.replanScene);
    });

    test('combined REPLAN_SCENE remains a replan decision', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          if (system.contains('scene combined review')) {
            return const AppLlmChatResult.success(
              text: '决定：REPLAN_SCENE\n原因：严重矛盾。',
            );
          }
          throw StateError('Unexpected prompt');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.decision, SceneReviewDecision.replanScene);
    });

    test('judge REPLAN_SCENE also takes priority', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          if (system.contains('scene judge review')) {
            return const AppLlmChatResult.success(
              text: '决定：REPLAN_SCENE\n原因：逻辑崩塌。',
            );
          }
          if (system.contains('scene consistency review')) {
            return const AppLlmChatResult.success(
              text: '决定：REWRITE_PROSE\n原因：用词不准。',
            );
          }
          throw StateError('Unexpected prompt');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.decision, SceneReviewDecision.replanScene);
    });

    test('malformed judge decision degrades to rewriteProse', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          if (system.contains('scene judge review')) {
            return const AppLlmChatResult.success(text: '决定：X\n原因：格式错误。');
          }
          if (system.contains('scene consistency review')) {
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：一致。');
          }
          throw StateError('Unexpected prompt');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.judge.status, SceneReviewStatus.rewriteProse);
      expect(result.judge.reason, contains('评审决定格式异常'));
      expect(result.judge.reason, contains('格式错误'));
      expect(result.decision, SceneReviewDecision.rewriteProse);
    });

    test(
      'malformed judge decision can be repaired within the review pass',
      () async {
        var repairCalls = 0;
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final system = request.messages.first.content;
            if (system.contains('format repair')) {
              repairCalls += 1;
              return const AppLlmChatResult.success(
                text: '决定：REWRITE_PROSE\n原因：格式错误，需要复核正文。',
              );
            }
            if (system.contains('scene judge review')) {
              return const AppLlmChatResult.success(text: '决定：X\n原因：格式错误。');
            }
            if (system.contains('scene consistency review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：一致。');
            }
            throw StateError('Unexpected prompt');
          },
        );
        final store = _setupStore(fakeClient);
        final formatterTraceSink = _RecordingFormatterTraceSink();
        final coordinator = SceneReviewCoordinator(
          settingsStore: store,
          formatterTraceSink: formatterTraceSink,
        );

        final result = await coordinator.review(
          brief: _brief(),
          director: _director,
          roleOutputs: _roleOutputs,
          prose: _prose,
        );

        expect(repairCalls, 1);
        expect(result.judge.status, SceneReviewStatus.rewriteProse);
        expect(result.judge.reason, '格式错误，需要复核正文。');
        expect(result.decision, SceneReviewDecision.rewriteProse);
        expect(formatterTraceSink.entries, hasLength(1));
        final trace = formatterTraceSink.entries.single;
        expect(trace.chapterId, 'chapter-01');
        expect(trace.sceneId, 'scene-01');
        expect(trace.passLabel, 'combined');
        expect(trace.rawText, '决定：X\n原因：格式错误。');
        expect(trace.repairedText, '决定：REWRITE_PROSE\n原因：格式错误，需要复核正文。');
        expect(trace.finalText, trace.repairedText);
        expect(trace.repairAttempted, isTrue);
        expect(trace.usedFallback, isFalse);
      },
    );

    test(
      'does not accept echoed decision examples buried in malformed review text',
      () async {
        var repairCalls = 0;
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final system = request.messages.first.content;
            if (system.contains('format repair')) {
              repairCalls += 1;
              return const AppLlmChatResult.success(
                text: '决定：REWRITE_PROSE\n原因：正文不是小说正文，需要重写。',
              );
            }
            if (system.contains('scene combined review')) {
              return const AppLlmChatResult.success(
                text: '''
The user asks for a scene review.

The first line must be one of:
决定：PASS
决定：REWRITE_PROSE
决定：REPLAN_SCENE

Analysis: 正文完全是模型元分析，不是小说正文。
''',
              );
            }
            throw StateError('Unexpected prompt');
          },
        );
        final store = _setupStore(fakeClient);
        final formatterTraceSink = _RecordingFormatterTraceSink();
        final coordinator = SceneReviewCoordinator(
          settingsStore: store,
          formatterTraceSink: formatterTraceSink,
        );

        final result = await coordinator.review(
          brief: _brief(),
          director: _director,
          roleOutputs: _roleOutputs,
          prose: _prose,
        );

        expect(repairCalls, 1);
        expect(result.judge.status, SceneReviewStatus.rewriteProse);
        expect(result.judge.reason, '正文不是小说正文，需要重写。');
        expect(result.decision, SceneReviewDecision.rewriteProse);
        expect(formatterTraceSink.entries.single.repairAttempted, isTrue);
      },
    );
  });

  // ===========================================================================
  // Prompt construction
  // ===========================================================================
  group('SceneReviewCoordinator prompt construction', () {
    test(
      'attaches all stable review categories to the combined pass',
      () async {
        final seenTaskTypes = <String>{};
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final user = request.messages.last.content;
            if (user.contains('任务：scene_combined_review')) {
              seenTaskTypes.add('combined');
              expect(
                user,
                contains(
                  '评审类别：prose, scene_plan, chapter_plan, continuity, '
                  'character_state, world_state',
                ),
              );
            } else {
              throw StateError('Unexpected prompt: $user');
            }
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。');
          },
        );
        final store = _setupStore(fakeClient);
        final coordinator = SceneReviewCoordinator(settingsStore: store);

        final result = await coordinator.review(
          brief: _brief(),
          director: _director,
          roleOutputs: _roleOutputs,
          prose: _prose,
          enableReaderFlowReview: true,
          enableLexiconReview: true,
        );

        expect(seenTaskTypes, {'combined'});
        expect(fakeClient.requests, hasLength(1));
        expect(result.judge.categories, [
          SceneReviewCategory.prose,
          SceneReviewCategory.scenePlan,
          SceneReviewCategory.chapterPlan,
          SceneReviewCategory.continuity,
          SceneReviewCategory.characterState,
          SceneReviewCategory.worldState,
        ]);
        expect(result.consistency.categories, [
          SceneReviewCategory.chapterPlan,
          SceneReviewCategory.continuity,
          SceneReviewCategory.characterState,
          SceneReviewCategory.worldState,
        ]);
        expect(result.readerFlow!.categories, [SceneReviewCategory.prose]);
        expect(result.lexicon!.categories, [SceneReviewCategory.prose]);
      },
    );

    test('includes retrieval summary in the combined pass', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          if (system.contains('scene combined review')) {
            final user = request.messages.last.content;
            expect(user, contains('已知事实'));
            expect(user, contains('柳溪曾受伤'));
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。');
          }
          throw StateError('Unexpected prompt');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
        retrievalPack: const StoryRetrievalPack(
          query: StoryMemoryQuery(
            projectId: 'chapter-01',
            queryType: StoryMemoryQueryType.concreteFact,
            text: '柳溪状态',
          ),
          hits: [
            StoryMemoryHit(
              chunk: StoryMemoryChunk(
                id: 'accepted-state-1',
                projectId: 'chapter-01',
                scopeId: 'scene-00',
                kind: MemorySourceKind.acceptedState,
                content: '柳溪曾受伤',
                rootSourceIds: ['scene-00'],
              ),
              score: 1,
            ),
          ],
        ),
      );
    });

    test('omits retrieval section when null', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final user = request.messages.last.content;
          expect(user, isNot(contains('已知事实')));
          return const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );
    });

    test('omits retrieval section when empty string', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final user = request.messages.last.content;
          expect(user, isNot(contains('已知事实')));
          return const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );
    });

    test('includes brief, director, roles, and prose in prompt', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          final user = request.messages.last.content;
          expect(system, contains('同等剧情功能'));
          expect(user, contains('仓库门外'));
          expect(user, contains('目标：逼问'));
          expect(user, contains('柳溪'));
          expect(user, contains('岳刃'));
          expect(user, contains('货单'));
          return const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );
    });

    test('empty role outputs show 无', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final user = request.messages.last.content;
          expect(user, contains('角色输入：无'));
          return const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。');
        },
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: const [],
        prose: _prose,
      );
    });
  });

  // ===========================================================================
  // Status callbacks
  // ===========================================================================
  group('SceneReviewCoordinator status callbacks', () {
    test('reports status for the combined review pass', () async {
      final statuses = <String>[];
      final fakeClient = FakeAppLlmClient(
        responder: (_) =>
            const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。'),
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
        onStatus: statuses.add,
      );

      expect(statuses, hasLength(1));
      expect(statuses[0], contains('combined review'));
      expect(statuses[0], contains('chapter-01'));
      expect(statuses[0], contains('scene-01'));
    });
  });

  // ===========================================================================
  // Error handling
  // ===========================================================================
  group('SceneReviewCoordinator error handling', () {
    test('throws StateError on LLM failure', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'Connection refused',
        ),
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      await expectLater(
        coordinator.review(
          brief: _brief(),
          director: _director,
          roleOutputs: _roleOutputs,
          prose: _prose,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('empty LLM output degrades to rewriteProse', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(text: ''),
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.judge.status, SceneReviewStatus.rewriteProse);
      expect(result.judge.reason, contains('评审决定格式异常'));
      expect(result.decision, SceneReviewDecision.rewriteProse);
    });

    test('malformed decision line degrades to rewriteProse', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) =>
            const AppLlmChatResult.success(text: '这是第一行\n原因：未知格式。'),
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.judge.status, SceneReviewStatus.rewriteProse);
      expect(result.judge.reason, contains('未知格式'));
      expect(result.decision, SceneReviewDecision.rewriteProse);
    });

    test('whitespace-only output degrades to rewriteProse', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(text: '   \n  \n  '),
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.judge.status, SceneReviewStatus.rewriteProse);
      expect(result.judge.reason, contains('评审决定格式异常'));
      expect(result.decision, SceneReviewDecision.rewriteProse);
    });
  });

  // ===========================================================================
  // SceneReviewResult.feedback
  // ===========================================================================
  group('SceneReviewResult.feedback', () {
    test('joins judge and consistency reasons', () {
      const result = SceneReviewResult(
        judge: SceneReviewPassResult(
          status: SceneReviewStatus.rewriteProse,
          reason: '对话不够自然',
          rawText: '决定：REWRITE_PROSE\n原因：对话不够自然',
        ),
        consistency: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '设定一致',
          rawText: '决定：PASS\n原因：设定一致',
        ),
        decision: SceneReviewDecision.rewriteProse,
      );

      expect(result.feedback, contains('Judge:'));
      expect(result.feedback, contains('对话不够自然'));
      expect(result.feedback, contains('Consistency:'));
      expect(result.feedback, contains('设定一致'));
    });

    test('omits empty reasons', () {
      const result = SceneReviewResult(
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
      );

      expect(result.feedback, isEmpty);
    });
  });

  // ===========================================================================
  // SceneReviewDecision._deriveDecision — comprehensive
  // ===========================================================================
  group('SceneReviewDecision derivation', () {
    test('both pass → pass', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) =>
            const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。'),
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.decision, SceneReviewDecision.pass);
    });

    test('both REWRITE_PROSE → rewriteProse', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) =>
            const AppLlmChatResult.success(text: '决定：REWRITE_PROSE\n原因：需要润色。'),
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.decision, SceneReviewDecision.rewriteProse);
    });

    test('both REPLAN_SCENE → replanScene', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) =>
            const AppLlmChatResult.success(text: '决定：REPLAN_SCENE\n原因：严重矛盾。'),
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(settingsStore: store);

      final result = await coordinator.review(
        brief: _brief(),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: _prose,
      );

      expect(result.decision, SceneReviewDecision.replanScene);
    });
  });

  group('SceneStateResolver transition tracking', () {
    test(
      'records partial transition pass without blocking optional misses',
      () {
        final taskCard = pipeline.SceneTaskCard(
          brief: _brief(),
          cast: [
            ResolvedSceneCastMember(
              characterId: 'char-liuxi',
              name: '柳溪',
              role: '调查记者',
              contributions: const [SceneCastContribution.action],
            ),
          ],
          metadata: const {
            'requiredTransitions': [
              {
                'id': 'ledger-located',
                'description': '账本去向被确认',
                'match': ['账本去向'],
              },
            ],
            'optionalTransitions': [
              {
                'id': 'ally-joins',
                'description': '沈渡加入同盟',
                'match': ['沈渡加入'],
              },
            ],
          },
        );
        const beats = [
          pipeline.SceneBeat(
            kind: pipeline.SceneBeatKind.fact,
            content: '柳溪确认账本去向在旧码头。',
            sourceCharacterId: 'char-liuxi',
            order: 0,
          ),
        ];

        final report = SceneStateResolver.trackTransitions(
          taskCard: taskCard,
          resolvedBeats: beats,
        );

        expect(
          report.requiredChecks.single.status,
          SceneTransitionStatus.passed,
        );
        expect(
          report.optionalChecks.single.status,
          SceneTransitionStatus.missed,
        );
        expect(report.missingRequired, isEmpty);
        expect(report.allRequiredPassed, isTrue);
        expect(report.allTransitionsPassed, isFalse);
      },
    );

    test('detects missed required transition as blocking', () {
      final taskCard = pipeline.SceneTaskCard(
        brief: _brief(),
        cast: const [],
        metadata: const {
          'requiredTransitions': [
            {
              'id': 'exit-secured',
              'description': '撤离路线被确保',
              'match': ['撤离路线'],
            },
          ],
        },
      );

      final report = SceneStateResolver.trackTransitions(
        taskCard: taskCard,
        resolvedBeats: const [
          pipeline.SceneBeat(
            kind: pipeline.SceneBeatKind.action,
            content: '岳刃转身避开追问。',
            sourceCharacterId: 'char-yueren',
          ),
        ],
      );

      expect(report.hasMissedRequired, isTrue);
      expect(report.missingRequired.single.id, 'exit-secured');
      expect(report.blockingReason, contains('exit-secured'));
    });
  });

  // ===========================================================================
  // categorizeChanges
  // ===========================================================================
  group('categorizeChanges', () {
    test('returns correct categories for each known aspect', () {
      expect(categorizeChanges({'prose'}), contains(SceneReviewCategory.prose));
      expect(
        categorizeChanges({'dialogue'}),
        contains(SceneReviewCategory.prose),
      );
      expect(
        categorizeChanges({'scene_plan'}),
        contains(SceneReviewCategory.scenePlan),
      );
      expect(
        categorizeChanges({'chapter_plan'}),
        contains(SceneReviewCategory.chapterPlan),
      );
      expect(
        categorizeChanges({'continuity'}),
        contains(SceneReviewCategory.continuity),
      );
      expect(
        categorizeChanges({'character_state'}),
        contains(SceneReviewCategory.characterState),
      );
      expect(
        categorizeChanges({'world_state'}),
        contains(SceneReviewCategory.worldState),
      );
    });

    test('returns deduplicated categories for overlapping aspects', () {
      final categories = categorizeChanges({'prose', 'dialogue', 'narration'});
      expect(
        categories.where((c) => c == SceneReviewCategory.prose),
        hasLength(1),
      );
    });

    test('returns multiple categories for diverse aspects', () {
      final categories = categorizeChanges({
        'prose',
        'continuity',
        'world_state',
      });
      expect(categories, contains(SceneReviewCategory.prose));
      expect(categories, contains(SceneReviewCategory.continuity));
      expect(categories, contains(SceneReviewCategory.worldState));
    });

    test('unknown aspects are handled gracefully', () {
      final categories = categorizeChanges({
        'unknown_aspect',
        'totally_made_up',
      });
      expect(categories, isEmpty);
    });

    test('mix of known and unknown aspects returns only known categories', () {
      final categories = categorizeChanges({
        'prose',
        'unknown_thing',
        'character_state',
      });
      expect(categories, hasLength(2));
      expect(categories, contains(SceneReviewCategory.prose));
      expect(categories, contains(SceneReviewCategory.characterState));
    });

    test('empty set returns empty list', () {
      expect(categorizeChanges({}), isEmpty);
    });
  });
}

class _RecordingFormatterTraceSink
    implements StoryGenerationFormatterTraceSink {
  final entries = <StoryGenerationFormatterTraceEntry>[];

  @override
  Future<void> record(StoryGenerationFormatterTraceEntry entry) async {
    entries.add(entry);
  }
}
