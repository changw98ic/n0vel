import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/artifact_recorder.dart';
import 'package:novel_writer/features/story_generation/data/chapter_generation_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/dynamic_role_agent_runner.dart';
import 'package:novel_writer/features/story_generation/data/scene_cast_resolver.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_director_orchestrator.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  group('SceneCastResolver', () {
    test('excludes background-only characters from the resolved cast', () {
      final resolver = SceneCastResolver();
      final brief = SceneBrief(
        chapterId: 'chapter-01',
        chapterTitle: '第一章 雨夜码头',
        sceneId: 'scene-01',
        sceneTitle: '仓库门外',
        sceneSummary: '柳溪在风雨里拦住准备离开的岳刃。',
        cast: [
          SceneCastCandidate(
            characterId: 'char-liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: const SceneCastParticipation(
              action: '挡在岳刃面前，逼问货单去向',
            ),
          ),
          SceneCastCandidate(
            characterId: 'char-porter',
            name: '码头搬运工',
            role: '路人',
          ),
          SceneCastCandidate(
            characterId: 'char-yueren',
            name: '岳刃',
            role: '走私联络人',
            participation: const SceneCastParticipation(
              dialogue: '“你今晚不该来这里。”',
            ),
          ),
        ],
      );

      final resolved = resolver.resolve(brief);

      expect(resolved.map((member) => member.characterId), [
        'char-liuxi',
        'char-yueren',
      ]);
      expect(
        resolved.first.contributions,
        contains(SceneCastContribution.action),
      );
      expect(
        resolved.last.contributions,
        contains(SceneCastContribution.dialogue),
      );
    });

    test('scene models keep inbound collections isolated and immutable', () {
      final cast = <SceneCastCandidate>[
        SceneCastCandidate(
          characterId: 'char-liuxi',
          name: '柳溪',
          role: '调查记者',
          participation: const SceneCastParticipation(action: '挡住退路'),
        ),
      ];
      final metadata = <String, Object?>{'weather': 'storm'};
      final brief = SceneBrief(
        chapterId: 'chapter-01',
        chapterTitle: '第一章 雨夜码头',
        sceneId: 'scene-01',
        sceneTitle: '仓库门外',
        sceneSummary: '摘要',
        cast: cast,
        metadata: metadata,
      );

      cast.add(
        SceneCastCandidate(characterId: 'char-yueren', name: '岳刃', role: '联络人'),
      );
      metadata['weather'] = 'sunny';

      expect(brief.cast, hasLength(1));
      expect(brief.metadata['weather'], 'storm');
      expect(
        () => brief.cast.add(
          SceneCastCandidate(characterId: 'char-crowd', name: '路人', role: '背景'),
        ),
        throwsUnsupportedError,
      );
      expect(() => brief.metadata['weather'] = 'fog', throwsUnsupportedError);
    });

    test('scene context models keep collections isolated and immutable', () {
      final profile = CharacterProfile(
        characterId: 'char-liuxi',
        name: '柳溪',
        role: '调查记者',
        coreDrives: ['不轻信口头承诺'],
      );
      final belief = BeliefState(
        ownerCharacterId: 'char-liuxi',
        aboutCharacterId: 'char-yueren',
        perceivedGoal: '找到账本',
        perceivedLoyalty: '自保',
        perceivedCompetence: '高',
        perceivedRisk: '中',
        perceivedEmotionalState: '警惕',
        confidence: 0.7,
      );
      final presentation = PresentationState(
        characterId: 'char-liuxi',
        projectedPersona: '冷静追问',
        concealments: ['害怕沈渡也卷入走私'],
      );

      expect(profile.coreDrives, contains('不轻信口头承诺'));
      expect(belief.confidence, 0.7);
      expect(presentation.projectedPersona, '冷静追问');
      expect(
        () => profile.coreDrives.add('should fail'),
        throwsUnsupportedError,
      );
    });
  });

  group('SceneDirectorOrchestrator', () {
    test('falls back to the local scene plan when polish fails', () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'Connection reset by peer',
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
            contributions: const [
              SceneCastContribution.action,
              SceneCastContribution.interaction,
            ],
          ),
          ResolvedSceneCastMember(
            characterId: 'char-shendu',
            name: '沈渡',
            role: '港区向导',
            contributions: const [SceneCastContribution.dialogue],
          ),
        ],
      );

      expect(output.text, contains('目标：'));
      expect(output.text, contains('冲突：'));
      expect(output.text, contains('推进：'));
      expect(output.text, contains('约束：'));
      expect(output.text, contains('账本去向'));
    });
  });

  group('ChapterGenerationOrchestrator', () {
    test(
      'runs scene role agents concurrently up to the configured request limit',
      () async {
        final release = Completer<void>();
        final bothStarted = Completer<void>();
        var activeRequests = 0;
        var maxActiveRequests = 0;
        var roleCalls = 0;

        final fakeClient = FakeAppLlmClient(
          responder: (request) async {
            final userPrompt = request.messages.last.content;
            if (userPrompt.contains('任务：scene_roleplay_arbitrate')) {
              return const AppLlmChatResult.success(
                text: '事实：柳溪与沈渡同时逼近\n状态：对峙推进\n压力：升级\n收束：是',
              );
            }
            if (!userPrompt.contains('任务：scene_roleplay_turn')) {
              return const AppLlmChatResult.success(text: 'unused');
            }

            roleCalls += 1;
            activeRequests += 1;
            if (activeRequests > maxActiveRequests) {
              maxActiveRequests = activeRequests;
            }
            if (roleCalls == 2 && !bothStarted.isCompleted) {
              bothStarted.complete();
            }

            await release.future;
            activeRequests -= 1;
            return const AppLlmChatResult.success(
              text: '意图：压迫\n可见动作：逼近半步\n对白：继续\n内心：先稳住节奏',
            );
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);
        await settingsStore.save(
          providerName: 'Ollama Cloud',
          baseUrl: 'https://ollama.com/v1',
          model: 'kimi-k2.6',
          apiKey: 'sk-test',
          timeout: AppLlmTimeoutConfig.uniform(180000),
          maxConcurrentRequests: 2,
        );

        final runner = DynamicRoleAgentRunner(settingsStore: settingsStore);
        final future = runner.run(
          brief: _brief(),
          director: const SceneDirectorOutput(text: '目标：逼问\n冲突：顶压'),
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

        await bothStarted.future.timeout(const Duration(seconds: 2));
        expect(maxActiveRequests, 2);

        release.complete();
        final outputs = await future;
        expect(outputs, hasLength(2));
      },
    );

    test(
      'uses compact structured prompts for non-prose scene passes',
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
            if (roleplay != null) {
              return roleplay;
            }
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[动作] @char-liuxi 柳溪逼近半步\n[事实] @narrator 岳刃露出破绽',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(text: '正文：柳溪逼近半步，岳刃露出破绽。');
            }
            if (systemPrompt.contains('scene judge review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：推进成立。');
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

        final orchestrator = ChapterGenerationOrchestrator(
          settingsStore: settingsStore,
        );

        await orchestrator.runScene(_brief());

        final directorRequest = fakeClient.requests.firstWhere(
          (request) =>
              request.messages.first.content.contains('scene plan polisher'),
        );
        expect(
          directorRequest.messages.first.content,
          contains('Polish the existing plan'),
        );
        expect(directorRequest.messages.last.content, contains('本地计划：'));

        final roleRequest = fakeClient.requests.firstWhere(
          (request) =>
              request.messages.last.content.contains('任务：scene_roleplay_turn'),
        );
        expect(
          roleRequest.messages.first.content,
          contains('Use this five-line shape'),
        );
        expect(roleRequest.messages.last.content, contains('当前行动角色：'));

        final judgeRequest = fakeClient.requests.firstWhere(
          (request) =>
              request.messages.first.content.contains('scene judge review'),
        );
        expect(
          judgeRequest.messages.first.content,
          contains('Use a 2-line review format'),
        );
        expect(judgeRequest.messages.first.content, contains('原因：'));
        expect(judgeRequest.messages.last.content, contains('正文：'));
      },
    );

    test(
      'runs role retrieval through capsules and edits only resolved beats',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final userPrompt = request.messages.last.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(
                text: '目标：逼出账本\n冲突：互相试探\n推进：沈渡被拖入\n约束：雨夜码头',
              );
            }
            if (userPrompt.contains('任务：scene_roleplay_turn')) {
              return const AppLlmChatResult.success(
                text:
                    '意图：柳溪不再相信岳刃\n'
                    '可见动作：柳溪用旧照片逼问岳刃\n'
                    '对白：你还想骗我第二次？\n'
                    '内心：先守住沈渡涉案这条线',
              );
            }
            if (userPrompt.contains('任务：scene_roleplay_arbitrate')) {
              return const AppLlmChatResult.success(
                text: '事实：柳溪用旧照片逼问岳刃\n状态：岳刃被迫回应\n压力：升级\n收束：是',
              );
            }
            if (systemPrompt.contains('scene beat resolver')) {
              expect(userPrompt, contains('柳溪用旧照片逼问岳刃'));
              expect(userPrompt, isNot(contains('RAW_TOOL_PAYLOAD')));
              return const AppLlmChatResult.success(
                text:
                    '[事实] @char-liuxi 柳溪不再相信岳刃\n'
                    '[动作] @char-liuxi 柳溪用旧照片逼问岳刃',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              expect(userPrompt, contains('场景拍：'));
              expect(userPrompt, contains('[事实]'));
              expect(userPrompt, isNot(contains('角色输入：')));
              expect(userPrompt, isNot(contains('检索：past_event')));
              expect(userPrompt, isNot(contains('RAW_TOOL_PAYLOAD')));
              return const AppLlmChatResult.success(
                text: '柳溪把旧照片按在雨水里，逼岳刃说出账本去向。',
              );
            }
            if (systemPrompt.contains('scene judge review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：推进成立。');
            }
            if (systemPrompt.contains('scene consistency review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：事实一致。');
            }

            throw StateError('Unexpected prompt: $systemPrompt\n$userPrompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final orchestrator = ChapterGenerationOrchestrator(
          settingsStore: settingsStore,
        );

        final result = await orchestrator.runScene(
          SceneBrief(
            chapterId: 'chapter-01',
            chapterTitle: '第一章 雨夜码头',
            sceneId: 'scene-01',
            sceneTitle: '仓库门外',
            sceneSummary: '柳溪在风雨中拦住岳刃，必须逼出货单去向。',
            knowledgeAtoms: [
              KnowledgeAtom(
                id: 'k-yueren-before',
                type: 'past_event',
                content: '岳刃三天前引导柳溪离开码头。',
                ownerScope: 'char-liuxi',
                visibility: KnowledgeVisibility.agentPrivate,
              ),
            ],
            cast: [
              SceneCastCandidate(
                characterId: 'char-liuxi',
                name: '柳溪',
                role: '调查记者',
                participation: const SceneCastParticipation(
                  action: '逼问账本',
                  dialogue: '“你还想骗我第二次？”',
                ),
                metadata: const {
                  'stableTraits': ['不轻信口头承诺'],
                  'beliefs': [
                    {
                      'subjectId': 'char-yueren',
                      'belief': '岳刃知道账本去向',
                      'confidence': 0.7,
                    },
                  ],
                  'presentation': {
                    'outwardMask': '冷静追问',
                    'concealedTruth': '害怕沈渡也涉案',
                  },
                },
              ),
            ],
          ),
        );

        expect(result.roleOutputs, hasLength(1));
        expect(result.roleOutputs.single.text, contains('柳溪不再相信岳刃'));
        expect(result.resolvedBeats, hasLength(greaterThanOrEqualTo(2)));
        expect(result.prose.text, contains('旧照片'));
        expect(
          fakeClient.requests
              .where(
                (request) => request.messages.last.content.contains(
                  '任务：scene_roleplay_turn',
                ),
              )
              .length,
          1,
        );
      },
    );

    test(
      'retries editorial prose without rerunning roleplay for soft review failures',
      () async {
        var proseAttempts = 0;
        var speculationReadyCount = 0;
        final roleplayRounds = <int>[];
        final arbitrationRounds = <int>[];
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final userPrompt = request.messages.last.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(text: '导演计划：先试探，再摊牌。');
            }

            if (userPrompt.contains('任务：scene_roleplay_turn')) {
              final round = _roundFromPrompt(userPrompt);
              roleplayRounds.add(round);
              return AppLlmChatResult.success(
                text:
                    '意图：压住怒气第$round轮\n'
                    '可见动作：柳溪逼近半步\n'
                    '对白：货单在哪\n'
                    '内心：必须逼出破绽',
              );
            }

            if (userPrompt.contains('任务：scene_roleplay_arbitrate')) {
              final round = _roundFromPrompt(userPrompt);
              arbitrationRounds.add(round);
              return AppLlmChatResult.success(
                text:
                    '事实：柳溪持续施压第$round轮\n'
                    '状态：岳刃退让\n'
                    '压力：升级\n'
                    '收束：否',
              );
            }

            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[动作] @char-liuxi 柳溪逼近半步\n[事实] @char-yueren 岳刃当场失守',
              );
            }

            if (systemPrompt.contains('scene editor')) {
              proseAttempts += 1;
              return AppLlmChatResult.success(
                text: proseAttempts == 1
                    ? '第一稿：场面成立，但冲突推进偏弱。'
                    : '第二稿：柳溪逼近半步，岳刃当场失守，冲突完整落地。',
              );
            }

            if (systemPrompt.contains('scene judge review')) {
              return AppLlmChatResult.success(
                text: userPrompt.contains('第一稿')
                    ? '决定：REWRITE_PROSE\n原因：冲突升级不足，保持导演计划不变。'
                    : '决定：PASS\n原因：冲突升级成立。',
              );
            }

            if (systemPrompt.contains('scene consistency review')) {
              return const AppLlmChatResult.success(
                text: '决定：PASS\n原因：角色行动与场面调度一致。',
              );
            }

            if (systemPrompt.contains('scene roleplay fidelity review')) {
              return const AppLlmChatResult.success(
                text: '决定：PASS\n原因：角色扮演过程忠实落地。',
              );
            }

            throw StateError('Unexpected prompt: $systemPrompt\n$userPrompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final orchestrator = ChapterGenerationOrchestrator(
          settingsStore: settingsStore,
          maxProseRetries: 2,
        );
        final result = await orchestrator.runScene(
          SceneBrief(
            chapterId: 'chapter-01',
            chapterTitle: '第一章 雨夜码头',
            sceneId: 'scene-01',
            sceneTitle: '仓库门外',
            sceneSummary: '柳溪在风雨中拦住岳刃，必须逼出货单去向。',
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
                characterId: 'char-crowd',
                name: '避雨的人群',
                role: '背景',
              ),
            ],
          ),
          onSpeculationReady: () {
            speculationReadyCount += 1;
          },
        );

        expect(result.review.decision, SceneReviewDecision.pass);
        expect(result.review.judge.status, SceneReviewStatus.pass);
        expect(result.review.consistency.status, SceneReviewStatus.pass);
        expect(result.prose.attempt, 2);
        expect(result.prose.text, contains('第二稿'));
        expect(result.resolvedCast.map((member) => member.characterId), [
          'char-liuxi',
        ]);
        expect(roleplayRounds, [1]);
        expect(arbitrationRounds, [1]);
        expect(result.roleplaySession?.rounds, hasLength(1));
        expect(speculationReadyCount, 1);
        expect(result.softFailureCount, 1);
        expect(
          fakeClient.requests
              .where(
                (request) =>
                    request.messages.first.content.contains('scene editor'),
              )
              .length,
          2,
        );
      },
    );

    test(
      'returns replan decision when the combined review requests replanning',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(text: '导演计划：逼问线索。');
            }
            final roleplay = _defaultRoleplayResponse(request);
            if (roleplay != null) {
              return roleplay;
            }
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[动作] @char-liuxi 柳溪反压\n[事实] @narrator 空间关系混乱',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(text: '正文：冲突形成但空间关系混乱。');
            }
            if (systemPrompt.contains('scene combined review')) {
              return const AppLlmChatResult.success(
                text: '决定：REPLAN_SCENE\n原因：空间调度自相矛盾，需要重排场面。',
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

        final orchestrator = ChapterGenerationOrchestrator(
          settingsStore: settingsStore,
          maxProseRetries: 2,
        );

        final result = await orchestrator.runScene(_brief());

        expect(result.review.decision, SceneReviewDecision.replanScene);
        expect(result.review.judge.status, SceneReviewStatus.replanScene);
        expect(result.review.consistency.status, SceneReviewStatus.replanScene);
        expect(result.prose.attempt, 1);
        expect(result.softFailureCount, 0);
      },
    );

    test('counts every soft failure when retry budget is exhausted', () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;

          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(text: '导演计划：连续逼问。');
          }
          final roleplay = _defaultRoleplayResponse(request);
          if (roleplay != null) {
            return roleplay;
          }
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[动作] @char-liuxi 持续对抗\n[事实] @narrator 冲突仍然偏弱',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            return const AppLlmChatResult.success(text: '正文：仍然偏弱。');
          }
          if (systemPrompt.contains('scene judge review')) {
            return const AppLlmChatResult.success(
              text: '决定：REWRITE_PROSE\n原因：冲突升级仍然不足。',
            );
          }
          if (systemPrompt.contains('scene consistency review')) {
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：设定一致。');
          }

          throw StateError('Unexpected prompt: $systemPrompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = ChapterGenerationOrchestrator(
        settingsStore: settingsStore,
        maxProseRetries: 1,
      );

      final result = await orchestrator.runScene(_brief());

      expect(result.review.decision, SceneReviewDecision.rewriteProse);
      expect(result.prose.attempt, 2);
      expect(result.softFailureCount, 2);
    });

    test(
      'retries editorial draft locally when prose exceeds hard length limit',
      () async {
        var proseAttempts = 0;
        var reviewCalls = 0;
        final overlongDraft = List.filled(1701, '长').join();
        const compactDraft = '柳溪逼近半步，岳刃终于交出账本线索。';
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final userPrompt = request.messages.last.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(text: '导演计划：逼问账本。');
            }
            if (userPrompt.contains('任务：scene_roleplay_turn')) {
              return const AppLlmChatResult.success(
                text: '意图：压迫对方\n可见动作：柳溪逼近半步\n对白：账本在哪\n内心：必须问出来',
              );
            }
            if (userPrompt.contains('任务：scene_roleplay_arbitrate')) {
              return const AppLlmChatResult.success(
                text: '事实：柳溪逼近半步，岳刃露出破绽\n状态：逼问推进\n压力：升级\n收束：是',
              );
            }
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[动作] @char-liuxi 柳溪逼近半步\n[事实] @char-yueren 岳刃露出破绽',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              proseAttempts += 1;
              return AppLlmChatResult.success(
                text: proseAttempts == 1 ? overlongDraft : compactDraft,
              );
            }
            if (systemPrompt.contains('scene judge review')) {
              reviewCalls += 1;
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：推进成立。');
            }
            if (systemPrompt.contains('scene consistency review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：设定一致。');
            }

            throw StateError('Unexpected prompt: $systemPrompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final orchestrator = ChapterGenerationOrchestrator(
          settingsStore: settingsStore,
          maxProseRetries: 1,
        );

        final result = await orchestrator.runScene(
          _brief().copyWith(targetLength: 800),
        );

        expect(result.prose.attempt, 2);
        expect(result.prose.text, compactDraft);
        expect(result.review.decision, SceneReviewDecision.pass);
        expect(result.softFailureCount, 1);
        expect(reviewCalls, 1);
      },
    );

    test(
      'retries transient dynamic role pass failures before failing scene',
      () async {
        var roleAttempts = 0;
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;
            final userPrompt = request.messages.last.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(text: '导演计划：先压住，再追问。');
            }
            if (userPrompt.contains('任务：scene_roleplay_turn')) {
              roleAttempts += 1;
              if (roleAttempts == 1) {
                return const AppLlmChatResult.failure(
                  failureKind: AppLlmFailureKind.network,
                  detail: 'Connection reset by peer',
                );
              }
              return const AppLlmChatResult.success(
                text: '意图：继续施压\n可见动作：我盯住对方\n对白：别躲\n内心：逼出破绽',
              );
            }
            if (userPrompt.contains('任务：scene_roleplay_arbitrate')) {
              return const AppLlmChatResult.success(
                text: '事实：柳溪继续施压\n状态：对峙升级\n压力：升级\n收束：是',
              );
            }
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[动作] @char-liuxi 继续施压\n[事实] @narrator 对峙升级',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(text: '正文：对峙升级并落到实处。');
            }
            if (systemPrompt.contains('scene judge review')) {
              return const AppLlmChatResult.success(
                text: '决定：PASS\n原因：戏剧推进成立。',
              );
            }
            if (systemPrompt.contains('scene consistency review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：设定一致。');
            }

            throw StateError('Unexpected prompt: $systemPrompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final orchestrator = ChapterGenerationOrchestrator(
          settingsStore: settingsStore,
        );

        final result = await orchestrator.runScene(_brief());

        expect(result.review.decision, SceneReviewDecision.pass);
        expect(result.roleOutputs, hasLength(1));
        expect(
          fakeClient.requests
              .where(
                (request) => request.messages.last.content.contains(
                  '任务：scene_roleplay_turn',
                ),
              )
              .length,
          2,
        );
      },
    );

    test('retries transient review pass failures before judging scene', () async {
      var judgeAttempts = 0;
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;

          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(text: '导演计划：逼近后突然转问。');
          }
          final roleplay = _defaultRoleplayResponse(request);
          if (roleplay != null) {
            return roleplay;
          }
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[动作] @char-liuxi 继续压迫\n[事实] @narrator 逼问推进',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            return const AppLlmChatResult.success(text: '正文：逼问推进到破防。');
          }
          if (systemPrompt.contains('scene judge review')) {
            judgeAttempts += 1;
            if (judgeAttempts == 1) {
              return const AppLlmChatResult.failure(
                failureKind: AppLlmFailureKind.server,
                detail:
                    'Bad state: Connection closed before full header was received',
              );
            }
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：冲突闭环成立。');
          }
          if (systemPrompt.contains('scene consistency review')) {
            return const AppLlmChatResult.success(text: '决定：PASS\n原因：角色动线一致。');
          }

          throw StateError('Unexpected prompt: $systemPrompt');
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      addTearDown(settingsStore.dispose);

      final orchestrator = ChapterGenerationOrchestrator(
        settingsStore: settingsStore,
      );

      final result = await orchestrator.runScene(_brief());

      expect(result.review.decision, SceneReviewDecision.pass);
      expect(result.review.judge.status, SceneReviewStatus.pass);
      expect(
        fakeClient.requests
            .where(
              (request) =>
                  request.messages.first.content.contains('scene judge review'),
            )
            .length,
        2,
      );
    });

    test(
      'malformed review output degrades without restarting the scene',
      () async {
        final fakeClient = FakeAppLlmClient(
          responder: (request) {
            final systemPrompt = request.messages.first.content;

            if (systemPrompt.contains('scene plan polisher')) {
              return const AppLlmChatResult.success(text: '导演计划：试压。');
            }
            final roleplay = _defaultRoleplayResponse(request);
            if (roleplay != null) {
              return roleplay;
            }
            if (systemPrompt.contains('scene beat resolver')) {
              return const AppLlmChatResult.success(
                text: '[动作] @char-liuxi 试探\n[事实] @narrator 第一稿形成',
              );
            }
            if (systemPrompt.contains('scene editor')) {
              return const AppLlmChatResult.success(text: '正文：第一稿。');
            }
            if (systemPrompt.contains('scene judge review')) {
              return const AppLlmChatResult.success(text: '这不是合法决定行\n原因：格式错误。');
            }
            if (systemPrompt.contains('scene consistency review')) {
              return const AppLlmChatResult.success(text: '决定：PASS\n原因：一致。');
            }

            throw StateError('Unexpected prompt: $systemPrompt');
          },
        );
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: fakeClient,
        );
        addTearDown(settingsStore.dispose);

        final orchestrator = ChapterGenerationOrchestrator(
          settingsStore: settingsStore,
        );

        final result = await orchestrator.runScene(_brief());

        expect(result.review.decision, SceneReviewDecision.rewriteProse);
        expect(result.review.judge.reason, contains('评审决定格式异常'));
        expect(result.proseAttempts, 2);
      },
    );
  });

  group('PipelineArtifact', () {
    test('JSON round-trip preserves all fields', () {
      final original = PipelineArtifact(
        id: 'art-1',
        sceneId: 'scene-01',
        chapterId: 'chapter-01',
        artifactType: 'director_cue',
        sourceId: 'director-pass-1',
        data: {'cue': '逼问', 'intensity': 0.8},
        recordedAtMs: 1000,
        sourceTraceIds: ['outline-1'],
      );

      final json = original.toJson();
      final roundTripped = PipelineArtifact.fromJson(json);

      expect(roundTripped.id, 'art-1');
      expect(roundTripped.sceneId, 'scene-01');
      expect(roundTripped.chapterId, 'chapter-01');
      expect(roundTripped.artifactType, 'director_cue');
      expect(roundTripped.sourceId, 'director-pass-1');
      expect(roundTripped.data['cue'], '逼问');
      expect(roundTripped.data['intensity'], 0.8);
      expect(roundTripped.recordedAtMs, 1000);
      expect(roundTripped.sourceTraceIds, ['outline-1']);
    });

    test('fromJson handles missing optional collections', () {
      final minimal = PipelineArtifact.fromJson({
        'id': 'art-x',
        'sceneId': 'scene-x',
        'chapterId': 'ch-x',
        'artifactType': 'review',
        'sourceId': 'src-x',
        'recordedAtMs': 42,
      });

      expect(minimal.data, isEmpty);
      expect(minimal.sourceTraceIds, isEmpty);
    });
  });

  group('ArtifactRecorder pipeline tracking', () {
    late ArtifactRecorder recorder;

    setUp(() {
      recorder = ArtifactRecorder();
    });

    test('recordArtifact stores artifact', () {
      final artifact = _makeArtifact(id: 'a1', sceneId: 's1', type: 'outline');
      recorder.recordArtifact(artifact);

      expect(recorder.artifactsForScene('s1'), [artifact]);
    });

    test('artifactsForScene returns only matching scene artifacts', () {
      final a1 = _makeArtifact(id: 'a1', sceneId: 's1', type: 'outline');
      final a2 = _makeArtifact(id: 'a2', sceneId: 's2', type: 'outline');
      final a3 = _makeArtifact(id: 'a3', sceneId: 's1', type: 'director_cue');
      recorder.recordArtifact(a1);
      recorder.recordArtifact(a2);
      recorder.recordArtifact(a3);

      final result = recorder.artifactsForScene('s1');
      expect(result, hasLength(2));
      expect(result.map((a) => a.id), ['a1', 'a3']);
    });

    test('artifactsByType filters correctly', () {
      recorder.recordArtifact(
        _makeArtifact(id: 'a1', sceneId: 's1', type: 'outline'),
      );
      recorder.recordArtifact(
        _makeArtifact(id: 'a2', sceneId: 's1', type: 'director_cue'),
      );
      recorder.recordArtifact(
        _makeArtifact(id: 'a3', sceneId: 's2', type: 'outline'),
      );

      final outlines = recorder.artifactsByType('outline');
      expect(outlines, hasLength(2));
      expect(outlines.map((a) => a.id), ['a1', 'a3']);

      final cues = recorder.artifactsByType('director_cue');
      expect(cues, hasLength(1));
      expect(cues.first.id, 'a2');
    });

    test('traceChain follows sourceTraceIds', () {
      final root = _makeArtifact(
        id: 'root',
        sceneId: 's1',
        type: 'outline',
        traceIds: [],
      );
      final mid = _makeArtifact(
        id: 'mid',
        sceneId: 's1',
        type: 'director_cue',
        traceIds: ['root'],
      );
      final leaf = _makeArtifact(
        id: 'leaf',
        sceneId: 's1',
        type: 'review',
        traceIds: ['mid'],
      );
      recorder.recordArtifact(root);
      recorder.recordArtifact(mid);
      recorder.recordArtifact(leaf);

      final chain = recorder.traceChain('leaf');
      expect(chain.map((a) => a.id), ['root', 'mid', 'leaf']);
    });

    test('clearSceneArtifacts removes only target scene', () {
      recorder.recordArtifact(
        _makeArtifact(id: 'a1', sceneId: 's1', type: 'outline'),
      );
      recorder.recordArtifact(
        _makeArtifact(id: 'a2', sceneId: 's2', type: 'outline'),
      );

      recorder.clearSceneArtifacts('s1');

      expect(recorder.artifactsForScene('s1'), isEmpty);
      expect(recorder.artifactsForScene('s2'), hasLength(1));
    });

    test('debugSummary produces non-empty string', () {
      recorder.recordArtifact(
        _makeArtifact(id: 'a1', sceneId: 's1', type: 'outline'),
      );
      recorder.recordArtifact(
        _makeArtifact(id: 'a2', sceneId: 's1', type: 'outline'),
      );
      recorder.recordArtifact(
        _makeArtifact(id: 'a3', sceneId: 's1', type: 'review'),
      );

      final summary = recorder.debugSummary('s1');
      expect(summary, contains('s1'));
      expect(summary, contains('outline:2'));
      expect(summary, contains('review:1'));
    });

    test('debugSummary returns bracket notation for empty scene', () {
      expect(recorder.debugSummary('unknown'), '[]');
    });

    test('multiple artifacts for same scene are all returned', () {
      for (var i = 0; i < 5; i++) {
        recorder.recordArtifact(
          _makeArtifact(id: 'a$i', sceneId: 's1', type: 'event'),
        );
      }

      expect(recorder.artifactsForScene('s1'), hasLength(5));
    });

    test('source trace IDs are preserved across recording and retrieval', () {
      final artifact = _makeArtifact(
        id: 'a1',
        sceneId: 's1',
        type: 'cognition',
        traceIds: ['src-a', 'src-b', 'src-c'],
      );
      recorder.recordArtifact(artifact);

      final retrieved = recorder.artifactsForScene('s1').single;
      expect(retrieved.sourceTraceIds, ['src-a', 'src-b', 'src-c']);
    });
  });
}

PipelineArtifact _makeArtifact({
  required String id,
  required String sceneId,
  required String type,
  List<String>? traceIds,
}) {
  return PipelineArtifact(
    id: id,
    sceneId: sceneId,
    chapterId: 'chapter-01',
    artifactType: type,
    sourceId: 'source-$id',
    data: {},
    recordedAtMs: DateTime.now().millisecondsSinceEpoch,
    sourceTraceIds: traceIds ?? const [],
  );
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
      SceneCastCandidate(characterId: 'char-crowd', name: '避雨的人群', role: '背景'),
    ],
  );
}

int _roundFromPrompt(String prompt) {
  final match = RegExp(r'回合：(\d+)').firstMatch(prompt);
  return int.parse(match!.group(1)!);
}

AppLlmChatResult? _defaultRoleplayResponse(AppLlmChatRequest request) {
  final userPrompt = request.messages.last.content;
  if (userPrompt.contains('任务：scene_roleplay_turn')) {
    return const AppLlmChatResult.success(
      text: '意图：压迫对方\n可见动作：柳溪逼近半步\n对白：账本在哪\n内心：必须问出来',
    );
  }
  if (userPrompt.contains('任务：scene_roleplay_arbitrate')) {
    return const AppLlmChatResult.success(
      text: '事实：柳溪逼近半步，岳刃露出破绽\n状态：逼问推进\n压力：升级\n收束：是',
    );
  }
  return null;
}
