import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/canon_keeper.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_fingerprints.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart'
    as pipeline;
import 'package:novel_writer/features/story_generation/data/scene_review_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/scene_state_resolver.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_formatter_trace.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

import 'test_support/fake_app_llm_client.dart';
import 'test_support/formal_evaluation_provenance_fixture.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

SceneBrief _brief({
  Map<String, Object?> metadata = const {},
  bool formalExecution = false,
}) => SceneBrief(
  chapterId: 'chapter-01',
  chapterTitle: '第一章 雨夜码头',
  sceneId: 'scene-01',
  sceneTitle: '仓库门外',
  sceneSummary: '柳溪在风雨中拦住岳刃。',
  metadata: metadata,
  formalExecution: formalExecution,
);

const _director = SceneDirectorOutput(text: '目标：逼问\n冲突：顶压\n推进：失守');

const _prose = SceneProseDraft(
  text: '柳溪在雨中拦住岳刃。"货单呢？现在交出来。"她逼近一步。',
  attempt: 1,
);

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

SceneReviewPassResult _copyReviewPass(SceneReviewPassResult source) =>
    SceneReviewPassResult(
      status: source.status,
      reason: source.reason,
      rawText: source.rawText,
      categories: <SceneReviewCategory>[...source.categories],
    );

SceneReviewResult _rehydrateReview(SceneReviewResult source) =>
    SceneReviewResult(
      judge: _copyReviewPass(source.judge),
      consistency: _copyReviewPass(source.consistency),
      adjudication: source.adjudication == null
          ? null
          : _copyReviewPass(source.adjudication!),
      readerFlow: source.readerFlow == null
          ? null
          : _copyReviewPass(source.readerFlow!),
      lexicon: source.lexicon == null ? null : _copyReviewPass(source.lexicon!),
      roleplayFidelity: source.roleplayFidelity == null
          ? null
          : _copyReviewPass(source.roleplayFidelity!),
      decision: source.decision,
      refinementGuidance: source.refinementGuidance == null
          ? null
          : RefinementGuidance(
              plotIssues: source.refinementGuidance!.plotIssues,
              consistencyFixes: source.refinementGuidance!.consistencyFixes,
              styleTargets: source.refinementGuidance!.styleTargets,
              preserve: source.refinementGuidance!.preserve,
              focusInstruction: source.refinementGuidance!.focusInstruction,
            ),
    );

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
    test(
      'default review uses independent judge and consistency LLM passes',
      () async {
        final taskTypes = <String>[];
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final system = request.messages.first.content;
            final user = request.messages.last.content;
            if (system.contains('scene judge review')) {
              expect(system, contains('不属于本次 LLM 评审的否决理由'));
              taskTypes.add('judge');
              expect(
                user,
                contains('任务：scene_judge_review:preliminaryReview'),
              );
              expect(user, contains('评审类别：prose, scene_plan'));
            } else if (system.contains('scene consistency review')) {
              taskTypes.add('consistency');
              expect(
                user,
                contains('任务：scene_consistency_review:preliminaryReview'),
              );
              expect(
                user,
                contains(
                  'chapter_plan, continuity, character_state, world_state',
                ),
              );
            } else {
              throw StateError('Unexpected reviewer prompt');
            }
            return const AppLlmChatResult.success(
              text: '决定：PASS\n原因：冲突成立，动线合理。',
            );
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

        expect(fakeClient.requests, hasLength(2));
        expect(taskTypes, ['judge', 'consistency']);
        expect(result.judge.status, SceneReviewStatus.pass);
        expect(result.judge.reason, '冲突成立，动线合理。');
        expect(result.consistency.status, SceneReviewStatus.pass);
        expect(result.decision, SceneReviewDecision.pass);
      },
    );

    test('local review rejects prose that contradicts canon facts', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) =>
            const AppLlmChatResult.success(text: '决定：PASS\n原因：通过。'),
      );
      final store = _setupStore(fakeClient);
      final coordinator = SceneReviewCoordinator(
        settingsStore: store,
        canonKeeper: const CanonKeeper(),
      );

      final result = await coordinator.review(
        brief: _brief(metadata: const {'localReviewOnly': true}),
        director: _director,
        roleOutputs: _roleOutputs,
        prose: const SceneProseDraft(
          text: 'Warehouse door is blue. "货单呢？现在交出来。"她逼近一步。',
          attempt: 1,
        ),
        canonFacts: const [
          StoryMemoryChunk(
            id: 'canon-door-red',
            projectId: 'project-01',
            scopeId: 'chapter-01',
            kind: MemorySourceKind.worldFact,
            content: 'warehouse door is red',
            tier: MemoryTier.canon,
          ),
        ],
      );

      expect(fakeClient.requests, isEmpty);
      expect(result.decision, SceneReviewDecision.rewriteProse);
      expect(result.judge.reason, startsWith('Canon consistency violation:'));
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
      'blocking review mode metadata still uses independent review passes',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final system = request.messages.first.content;
            expect(
              system.contains('scene judge review') ||
                  system.contains('scene consistency review'),
              isTrue,
            );
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

        expect(fakeClient.requests, hasLength(2));
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

    test('consistency REPLAN_SCENE is confirmed by the adjudicator', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          if (system.contains('scene review adjudication')) {
            return const AppLlmChatResult.success(
              text: '决定：REPLAN_SCENE\n原因：角色行为与设定存在直接矛盾。',
            );
          }
          if (system.contains('scene consistency review')) {
            return const AppLlmChatResult.success(
              text: '决定：REPLAN_SCENE\n原因：角色行为与设定矛盾。',
            );
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
      );

      expect(result.consistency.status, SceneReviewStatus.replanScene);
      expect(result.adjudication?.status, SceneReviewStatus.replanScene);
      expect(result.decision, SceneReviewDecision.replanScene);
    });

    test(
      'adjudicator prevents an uncorroborated replan from overriding pass',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final system = request.messages.first.content;
            if (system.contains('scene review adjudication')) {
              return const AppLlmChatResult.success(
                text: '决定：PASS\n原因：正文没有可验证的重规划级矛盾。',
              );
            }
            if (system.contains('scene consistency review')) {
              return const AppLlmChatResult.success(
                text: '决定：REPLAN_SCENE\n原因：严重矛盾。',
              );
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
        );

        expect(result.adjudication?.status, SceneReviewStatus.pass);
        expect(result.decision, SceneReviewDecision.pass);
      },
    );

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
        expect(formatterTraceSink.entries, hasLength(2));
        final trace = formatterTraceSink.entries.first;
        expect(trace.chapterId, 'chapter-01');
        expect(trace.sceneId, 'scene-01');
        expect(trace.passLabel, 'judge');
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
            if (system.contains('scene judge review')) {
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
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：一致。');
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
        expect(formatterTraceSink.entries.first.repairAttempted, isTrue);
      },
    );
  });

  // ===========================================================================
  // Prompt construction
  // ===========================================================================
  group('SceneReviewCoordinator prompt construction', () {
    test('attaches each reviewer only to its independent categories', () async {
      final seenTaskTypes = <String>{};
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final user = request.messages.last.content;
          if (user.contains('任务：scene_judge_review')) {
            seenTaskTypes.add('judge');
            expect(user, contains('评审类别：prose, scene_plan'));
          } else if (user.contains('任务：scene_consistency_review')) {
            seenTaskTypes.add('consistency');
            expect(
              user,
              contains(
                'chapter_plan, continuity, character_state, world_state',
              ),
            );
          } else if (user.contains('任务：scene_reader_flow_review')) {
            seenTaskTypes.add('reader');
          } else if (user.contains('任务：scene_lexicon_review')) {
            seenTaskTypes.add('lexicon');
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

      expect(seenTaskTypes, {'judge', 'consistency', 'reader', 'lexicon'});
      expect(fakeClient.requests, hasLength(4));
      expect(result.judge.categories, [
        SceneReviewCategory.prose,
        SceneReviewCategory.scenePlan,
      ]);
      expect(result.consistency.categories, [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
        SceneReviewCategory.characterState,
        SceneReviewCategory.worldState,
      ]);
      expect(result.readerFlow!.categories, [SceneReviewCategory.prose]);
      expect(result.lexicon!.categories, [SceneReviewCategory.prose]);
    });

    test(
      'includes retrieval summary in every independent review pass',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final system = request.messages.first.content;
            if (system.contains('scene judge review') ||
                system.contains('scene consistency review')) {
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
      },
    );

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

      expect(result, isNotNull);
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

  group('SceneReviewCoordinator parsed-result provenance', () {
    const passResponse = '决定：PASS\n原因：证据与正文一致。';

    Future<FormalEvaluationFixtureRun<SceneReviewResult>> realReview({
      StoryGenerationEvaluationPhase? phase,
      bool includeOptionalPasses = false,
      bool requireAdjudication = false,
    }) {
      final responses = <String>[
        requireAdjudication ? '决定：REPLAN_SCENE\n原因：需要裁决是否重规划。' : passResponse,
        passResponse,
        if (includeOptionalPasses) passResponse,
        if (includeOptionalPasses) passResponse,
        if (requireAdjudication) passResponse,
      ];
      return runFormalEvaluationProvenanceFixture(
        responses: responses,
        body: (settingsStore) {
          final coordinator = SceneReviewCoordinator(
            settingsStore: settingsStore,
            hardGatesEnabled: false,
          );
          Future<SceneReviewResult> runReview() => coordinator.review(
            brief: _brief(formalExecution: true),
            director: _director,
            roleOutputs: _roleOutputs,
            prose: _prose,
            enableReaderFlowReview: includeOptionalPasses,
            enableLexiconReview: includeOptionalPasses,
          );

          return phase == null
              ? runReview()
              : StoryGenerationEvaluationScope.run(
                  phase: phase,
                  artifactText: _prose.text,
                  body: runReview,
                );
        },
      );
    }

    test(
      'byte-identical preliminary and final councils keep unique phase-bound intents',
      () async {
        final run = await runFormalEvaluationProvenanceFixture(
          responses: const <String>[
            passResponse,
            passResponse,
            passResponse,
            passResponse,
          ],
          body: (settingsStore) async {
            final coordinator = SceneReviewCoordinator(
              settingsStore: settingsStore,
              hardGatesEnabled: false,
            );
            Future<SceneReviewResult> reviewInPhase(
              StoryGenerationEvaluationPhase phase,
            ) => StoryGenerationEvaluationScope.run(
              phase: phase,
              artifactText: _prose.text,
              body: () => coordinator.review(
                brief: _brief(formalExecution: true),
                director: _director,
                roleOutputs: _roleOutputs,
                prose: _prose,
              ),
            );

            return <SceneReviewResult>[
              await reviewInPhase(
                StoryGenerationEvaluationPhase.preliminaryReview,
              ),
              await reviewInPhase(StoryGenerationEvaluationPhase.finalCouncil),
            ];
          },
        );

        expect(run.providerCallCount, 4);
        expect(
          run.attempts.map((attempt) => attempt.evaluationPhase),
          <StoryGenerationEvaluationPhase>[
            StoryGenerationEvaluationPhase.preliminaryReview,
            StoryGenerationEvaluationPhase.preliminaryReview,
            StoryGenerationEvaluationPhase.finalCouncil,
            StoryGenerationEvaluationPhase.finalCouncil,
          ],
        );
        expect(
          run.attempts.map((attempt) => attempt.logicalAttemptId).toSet(),
          hasLength(4),
        );
        expect(
          run.attempts.map((attempt) => attempt.resolvedVariablesDigest).toSet(),
          hasLength(4),
        );

        final artifactDigest = ArtifactDigest.fromUtf8String(_prose.text);
        final preliminary = consumeVerifiedSceneReviewProvenance(
          result: run.value[0],
          phase: StoryGenerationEvaluationPhase.preliminaryReview,
          artifactDigest: artifactDigest,
        );
        final finalCouncil = consumeVerifiedSceneReviewProvenance(
          result: run.value[1],
          phase: StoryGenerationEvaluationPhase.finalCouncil,
          artifactDigest: artifactDigest,
        );
        expect(preliminary, isNotNull);
        expect(finalCouncil, isNotNull);
        expect(
          preliminary!.orderedOutcomes.every(
            (outcome) =>
                outcome.evaluationPhase ==
                StoryGenerationEvaluationPhase.preliminaryReview,
          ),
          isTrue,
        );
        expect(
          finalCouncil!.orderedOutcomes.every(
            (outcome) =>
                outcome.evaluationPhase ==
                StoryGenerationEvaluationPhase.finalCouncil,
          ),
          isTrue,
        );
      },
    );

    test(
      'real durable council preserves fixed provider order and burns replay',
      () async {
        final run = await realReview(
          phase: StoryGenerationEvaluationPhase.finalCouncil,
          includeOptionalPasses: true,
          requireAdjudication: true,
        );
        expect(run.providerCallCount, 5);
        expect(run.attempts.map((attempt) => attempt.callSiteId), <String>[
          'judge',
          'consistency',
          'reader-flow',
          'lexicon',
          'adjudication',
        ]);
        final artifactDigest = ArtifactDigest.fromUtf8String(_prose.text);

        final rehydrated = _rehydrateReview(run.value);
        expect(
          canonicalSceneReviewEvaluationOutput(rehydrated),
          canonicalSceneReviewEvaluationOutput(run.value),
        );
        expect(
          consumeVerifiedSceneReviewProvenance(
            result: rehydrated,
            phase: StoryGenerationEvaluationPhase.finalCouncil,
            artifactDigest: artifactDigest,
          ),
          isNull,
        );

        final provenance = consumeVerifiedSceneReviewProvenance(
          result: run.value,
          phase: StoryGenerationEvaluationPhase.finalCouncil,
          artifactDigest: artifactDigest,
        );
        expect(provenance, isNotNull);
        expect(
          provenance!.orderedOutcomes.map((outcome) => outcome.callSiteId),
          <String>[
            'judge',
            'consistency',
            'reader-flow',
            'lexicon',
            'adjudication',
          ],
        );
        expect(provenance.orderedPasses, hasLength(5));
        expect(
          provenance.orderedPasses.every(
            (pass) => pass.parsedOutputDigest.startsWith('sha256:'),
          ),
          isTrue,
        );
        expect(
          provenance.parsedOutputDigest,
          storyGenerationParsedOutputDigest(
            canonicalSceneReviewEvaluationOutput(run.value),
          ),
        );
        expect(
          consumeVerifiedSceneReviewProvenance(
            result: run.value,
            phase: StoryGenerationEvaluationPhase.finalCouncil,
            artifactDigest: artifactDigest,
          ),
          isNull,
        );
      },
    );

    test('preliminary council cannot be presented as final council', () async {
      final run = await realReview();
      final artifactDigest = ArtifactDigest.fromUtf8String(_prose.text);

      expect(
        consumeVerifiedSceneReviewProvenance(
          result: run.value,
          phase: StoryGenerationEvaluationPhase.finalCouncil,
          artifactDigest: artifactDigest,
        ),
        isNull,
      );
      expect(
        consumeVerifiedSceneReviewProvenance(
          result: run.value,
          phase: StoryGenerationEvaluationPhase.preliminaryReview,
          artifactDigest: artifactDigest,
        ),
        isNull,
      );
    });

    test('adaptive fake provider result cannot mint aggregate proof', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(text: passResponse),
      );
      final result =
          await SceneReviewCoordinator(
            settingsStore: _setupStore(fakeClient),
            hardGatesEnabled: false,
          ).review(
            brief: _brief(),
            director: _director,
            roleOutputs: _roleOutputs,
            prose: _prose,
          );

      expect(
        consumeVerifiedSceneReviewProvenance(
          result: result,
          phase: StoryGenerationEvaluationPhase.preliminaryReview,
          artifactDigest: ArtifactDigest.fromUtf8String(_prose.text),
        ),
        isNull,
      );
    });

    test('canonical aggregate binds deterministic roleplay fidelity', () {
      const roleplayPass = SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: '公开行动与裁决事实一致。',
        rawText: 'deterministic roleplay fidelity pass',
        categories: [SceneReviewCategory.roleplayFidelity],
      );
      const withoutRoleplay = SceneReviewResult(
        judge: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '通过。',
          rawText: passResponse,
        ),
        consistency: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '通过。',
          rawText: passResponse,
        ),
        decision: SceneReviewDecision.pass,
      );
      const withRoleplay = SceneReviewResult(
        judge: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '通过。',
          rawText: passResponse,
        ),
        consistency: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '通过。',
          rawText: passResponse,
        ),
        roleplayFidelity: roleplayPass,
        decision: SceneReviewDecision.pass,
      );

      expect(
        canonicalSceneReviewEvaluationOutput(withRoleplay)['roleplayFidelity'],
        isNotNull,
      );
      expect(
        storyGenerationParsedOutputDigest(
          canonicalSceneReviewEvaluationOutput(withRoleplay),
        ),
        isNot(
          storyGenerationParsedOutputDigest(
            canonicalSceneReviewEvaluationOutput(withoutRoleplay),
          ),
        ),
      );
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
