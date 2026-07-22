import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/events/app_domain_events.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_delta_models.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_commit_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/data/character_visible_context_models.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';

import 'test_support/legacy_generation_candidate_seed.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage.dart';
import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/review_tasks/domain/review_task_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('StoryGenerationRunSnapshot lifecycle phase', () {
    test(
      'persists and restores the PRD workflow phase separately from status',
      () {
        const snapshot = StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.completed,
          phase: StoryGenerationRunPhase.feedback,
          sceneId: 'scene-1',
          sceneLabel: 'Project / Scene',
          headline: 'headline',
          summary: 'summary',
          stageSummary: 'stage',
        );

        final json = snapshot.toJson();
        expect(json['status'], StoryGenerationRunStatus.completed.name);
        expect(json['phase'], StoryGenerationRunPhase.feedback.name);

        final restored = StoryGenerationRunSnapshot.fromJson(json);
        expect(restored.status, StoryGenerationRunStatus.completed);
        expect(restored.phase, StoryGenerationRunPhase.feedback);
      },
    );

    test('validates PRD workflow phase transitions', () {
      expect(
        StoryGenerationRunPhaseTransitions.validate(
          StoryGenerationRunPhase.draft,
          StoryGenerationRunPhase.feedback,
        ).accepted,
        isFalse,
      );
      expect(
        StoryGenerationRunPhaseTransitions.validate(
          StoryGenerationRunPhase.feedback,
          StoryGenerationRunPhase.check,
        ).accepted,
        isTrue,
      );
      expect(
        StoryGenerationRunPhaseTransitions.validate(
          StoryGenerationRunPhase.cancel,
          StoryGenerationRunPhase.resume,
        ).accepted,
        isFalse,
      );
    });
  });

  group('StoryGenerationRunStore scene state persistence', () {
    late AppSettingsStore settingsStore;
    late AppWorkspaceStore workspaceStore;
    late StoryGenerationStore generationStore;

    setUp(() async {
      settingsStore = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      generationStore = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        workspaceStore: workspaceStore,
      );
      await generationStore.waitUntilReady();
    });

    tearDown(() {
      generationStore.dispose();
      workspaceStore.dispose();
      settingsStore.dispose();
    });

    test('passes current project materials into every pipeline run', () async {
      final orchestrator = _ControlledOrchestrator(
        settingsStore: settingsStore,
      );
      final runStore = StoryGenerationRunStore(
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        generationStore: generationStore,
        storage: InMemoryStoryGenerationRunStorage(),
        orchestratorFactory: (_) => orchestrator,
      );
      addTearDown(runStore.dispose);
      await runStore.waitUntilReady();

      final runFuture = runStore.runCurrentScene();
      await orchestrator.started.future;

      expect(orchestrator.receivedMaterials, isNotNull);
      expect(orchestrator.receivedMaterials!.worldFacts, isNotEmpty);
      expect(orchestrator.receivedMaterials!.characterProfiles, isNotEmpty);
      expect(orchestrator.receivedMaterials!.sceneSummaries, isNotEmpty);

      orchestrator.release.complete();
      await runFuture;
    });

    test(
      'formal first scene passes an explicit empty continuity ledger',
      () async {
        final orchestrator = _ControlledOrchestrator(
          settingsStore: settingsStore,
        );
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
          orchestratorFactory: (_) => orchestrator,
          allowLocalOnlyFallback: false,
          formalEvaluation: true,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        final runFuture = runStore.runCurrentScene();
        await orchestrator.started.future;

        expect(
          orchestrator.receivedBrief!.metadata,
          containsPair('continuityLedger', isEmpty),
        );

        orchestrator.release.complete();
        await runFuture;
      },
    );

    test(
      'reloads committed prior-scene continuity into brief and materials',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        DatabaseSchemaManager(
          migrations: authoringSchemaMigrations,
        ).ensureSchema(db);
        final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
        final currentScene = workspaceStore.currentScene;
        final priorScene = workspaceStore.scenes.first;
        expect(priorScene.id, isNot(currentScene.id));
        _commitPriorContinuity(
          ledger: ledger,
          db: db,
          projectId: workspaceStore.currentProjectId,
          chapterId: priorScene.chapterLabel,
          sceneId: priorScene.id,
          sourceSceneId: '${priorScene.chapterLabel}/${priorScene.id}',
        );

        final orchestrator = _ControlledOrchestrator(
          settingsStore: settingsStore,
        );
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
          generationLedger: ledger,
          orchestratorFactory: (_) => orchestrator,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        final runFuture = runStore.runCurrentScene();
        await orchestrator.started.future;

        final rawLedger =
            orchestrator.receivedBrief!.metadata['continuityLedger'] as List;
        expect(rawLedger, hasLength(1));
        expect((rawLedger.single as Map)['entityId'], 'evidence-phone');
        expect((rawLedger.single as Map)['holder'], 'character-liuxi');
        expect(
          orchestrator.receivedMaterials!.acceptedStates,
          contains(
            contains(
              '[连续性状态] evidence-phone（证据手机/手机）'
              '持有人：character-liuxi；地点：蓝色柜机；状态：held',
            ),
          ),
        );

        orchestrator.release.complete();
        await runFuture;
      },
    );

    test(
      'formal harness can inject the authoritative lifecycle run ID',
      () async {
        final orchestrator = _ControlledOrchestrator(
          settingsStore: settingsStore,
        );
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
          lifecycleRunIdFactory: (_) => 'eval-attempt-authority-1',
          orchestratorFactory: (_) => orchestrator,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        final runFuture = runStore.runCurrentScene();
        await orchestrator.started.future;
        expect(runStore.snapshot.runId, 'eval-attempt-authority-1');
        orchestrator.release.complete();
        await runFuture;
      },
    );

    test(
      'persists typed pipeline terminal states instead of flattening to failed',
      () async {
        final cases =
            <
              ({
                Object error,
                StoryGenerationRunStatus status,
                StoryGenerationRunPhase phase,
              })
            >[
              (
                error: const GenerationBudgetUnavailable('run-budget'),
                status: StoryGenerationRunStatus.budgetBlocked,
                phase: StoryGenerationRunPhase.budgetBlocked,
              ),
              (
                error: StateError(
                  'Preliminary review did not pass after 2 prose retries.',
                ),
                status: StoryGenerationRunStatus.preliminaryReviewBlocked,
                phase: StoryGenerationRunPhase.preliminaryReviewBlocked,
              ),
              (
                error: StateError(
                  'Final council review did not pass after 2 prose retries.',
                ),
                status: StoryGenerationRunStatus.finalReviewBlocked,
                phase: StoryGenerationRunPhase.finalReviewBlocked,
              ),
              (
                error: StateError('Quality gate blocked: overall=80.'),
                status: StoryGenerationRunStatus.qualityBlocked,
                phase: StoryGenerationRunPhase.qualityBlocked,
              ),
              (
                error: const PipelineRunCancelled('editorial'),
                status: StoryGenerationRunStatus.cancelled,
                phase: StoryGenerationRunPhase.cancel,
              ),
              (
                error: StateError('draft conflict'),
                status: StoryGenerationRunStatus.conflict,
                phase: StoryGenerationRunPhase.conflict,
              ),
            ];
        for (final entry in cases) {
          final storage = InMemoryStoryGenerationRunStorage();
          final runner = _TerminalErrorOrchestrator(
            settingsStore: settingsStore,
            error: entry.error,
          );
          final runStore = StoryGenerationRunStore(
            settingsStore: settingsStore,
            workspaceStore: workspaceStore,
            generationStore: generationStore,
            storage: storage,
            orchestratorFactory: (_) => runner,
          );
          await runStore.waitUntilReady();
          await runStore.runCurrentScene();

          expect(runStore.snapshot.status, entry.status);
          expect(runStore.snapshot.phase, entry.phase);
          expect(
            runStore.snapshot.status,
            isNot(StoryGenerationRunStatus.failed),
          );

          final persisted = await storage.load(
            sceneScopeId: workspaceStore.currentSceneScopeId,
          );
          final restored = StoryGenerationRunSnapshot.fromJson(persisted!);
          expect(restored.status, entry.status);
          expect(restored.phase, entry.phase);
          runStore.dispose();
        }
      },
    );

    test(
      'allows a blocked run to be explicitly cancelled but not resumed',
      () async {
        final runner = _TerminalErrorOrchestrator(
          settingsStore: settingsStore,
          error: const GenerationBudgetUnavailable('run-budget'),
        );
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
          orchestratorFactory: (_) => runner,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();
        await runStore.runCurrentScene();

        expect(
          runStore.snapshot.status,
          StoryGenerationRunStatus.budgetBlocked,
        );
        expect(await runStore.cancelCurrentRun(), isTrue);
        expect(runStore.snapshot.status, StoryGenerationRunStatus.cancelled);
        expect(runStore.snapshot.phase, StoryGenerationRunPhase.cancel);
      },
    );

    test(
      'builds a complete production SceneBrief and persists exact candidate prose',
      () async {
        final currentScene = workspaceStore.currentScene;
        final character = workspaceStore.characters.first;
        final worldNode = workspaceStore.worldNodes.first;
        workspaceStore
          ..setCharacterSceneLinked(
            characterId: character.id,
            sceneId: currentScene.id,
            linked: true,
          )
          ..setWorldNodeSceneLinked(
            nodeId: worldNode.id,
            sceneId: currentScene.id,
            linked: true,
          );
        final outlineStore = StoryOutlineStore(
          storage: InMemoryStoryOutlineStorage(),
          workspaceStore: workspaceStore,
        );
        addTearDown(outlineStore.dispose);
        outlineStore.replaceSnapshot(
          StoryOutlineSnapshot(
            projectId: workspaceStore.currentProjectId,
            executablePlan: NovelPlan(
              id: 'novel-plan',
              projectId: workspaceStore.currentProjectId,
              title: '测试小说',
              premise: '测试前提',
              chapters: [
                ChapterPlan(
                  id: 'chapter-plan',
                  novelPlanId: 'novel-plan',
                  title: '第一章',
                  summary: '章节摘要',
                  scenes: [
                    ScenePlan(
                      id: currentScene.id,
                      chapterPlanId: 'chapter-plan',
                      title: '计划场景',
                      summary: '计划场景摘要',
                      targetLength: 1200,
                      povCharacterId: character.id,
                      castIds: [character.id],
                      worldNodeIds: [worldNode.id],
                      beats: [
                        BeatPlan(
                          id: 'beat-1',
                          scenePlanId: currentScene.id,
                          sequence: 1,
                          beatType: 'action',
                          content: '主角必须拿到钥匙。',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        final storage = InMemoryStoryGenerationRunStorage();
        final orchestrator = _ControlledOrchestrator(
          settingsStore: settingsStore,
        );
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          outlineStore: outlineStore,
          storage: storage,
          orchestratorFactory: (_) => orchestrator,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        final runFuture = runStore.runCurrentScene(rulesOverride: '保持悬念。');
        await orchestrator.started.future;

        final brief = orchestrator.receivedBrief!;
        expect(brief.sceneIndex, 0);
        expect(brief.totalScenesInChapter, 1);
        expect(brief.targetLength, 1200);
        expect(brief.targetBeat, '主角必须拿到钥匙。');
        expect(brief.cast.single.characterId, character.id);
        expect(brief.characterProfiles.single.id, character.id);
        expect(brief.worldNodeIds, [worldNode.id]);
        expect(
          brief.knowledgeAtoms.map((atom) => atom.id),
          containsAll(['world:${worldNode.id}', 'character:${character.id}']),
        );
        expect(brief.metadata['authorRevisionRequests'], ['保持悬念。']);

        orchestrator.release.complete();
        await runFuture;

        expect(runStore.snapshot.status, StoryGenerationRunStatus.completed);
        expect(runStore.snapshot.candidateProse, 'prose');
        expect(
          runStore.snapshot.messages.any(
            (message) => message.title == '候选正文' && message.body == 'prose',
          ),
          isTrue,
        );

        final restored = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: storage,
        );
        addTearDown(restored.dispose);
        await restored.ready;
        expect(restored.snapshot.candidateProse, 'prose');
      },
    );

    test(
      'records running and success without clearing existing scene states',
      () async {
        final currentScene = workspaceStore.currentScene;
        final currentChapterId = currentScene.chapterLabel;
        generationStore.replaceSnapshot(
          StoryGenerationSnapshot(
            projectId: workspaceStore.currentProjectId,
            chapters: [
              StoryChapterGenerationState(
                chapterId: currentChapterId,
                status: StoryChapterGenerationStatus.invalidated,
                targetLength: 1200,
                actualLength: 300,
                participatingRoleIds: const ['existing-role'],
                worldNodeIds: const ['existing-world'],
                scenes: [
                  StorySceneGenerationState(
                    sceneId: 'preserved-scene',
                    status: StorySceneGenerationStatus.passed,
                    judgeStatus: StoryReviewStatus.passed,
                    consistencyStatus: StoryReviewStatus.passed,
                    proseRetryCount: 1,
                    directorRetryCount: 2,
                    upstreamFingerprint: 'preserved-fp',
                  ),
                ],
              ),
              StoryChapterGenerationState(
                chapterId: 'other-chapter',
                status: StoryChapterGenerationStatus.passed,
                scenes: [
                  StorySceneGenerationState(
                    sceneId: 'other-scene',
                    status: StorySceneGenerationStatus.passed,
                    judgeStatus: StoryReviewStatus.passed,
                    consistencyStatus: StoryReviewStatus.passed,
                    proseRetryCount: 0,
                    directorRetryCount: 0,
                    upstreamFingerprint: 'other-fp',
                  ),
                ],
              ),
            ],
          ),
        );

        final orchestrator = _ControlledOrchestrator(
          settingsStore: settingsStore,
        );
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
          orchestratorFactory: (_) => orchestrator,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        final runFuture = runStore.runCurrentScene();
        await orchestrator.started.future;

        expect(runStore.snapshot.phase, StoryGenerationRunPhase.draft);

        var chapter = generationStore.snapshot.chapters.firstWhere(
          (candidate) => candidate.chapterId == currentChapterId,
        );
        var current = chapter.scenes.firstWhere(
          (candidate) => candidate.sceneId == currentScene.id,
        );
        expect(chapter.status, StoryChapterGenerationStatus.inProgress);
        expect(current.status, StorySceneGenerationStatus.roleRunning);
        expect(current.judgeStatus, StoryReviewStatus.pending);
        expect(current.consistencyStatus, StoryReviewStatus.pending);

        orchestrator.release.complete();
        await runFuture;

        expect(runStore.snapshot.status, StoryGenerationRunStatus.completed);
        expect(runStore.snapshot.phase, StoryGenerationRunPhase.feedback);

        chapter = generationStore.snapshot.chapters.firstWhere(
          (candidate) => candidate.chapterId == currentChapterId,
        );
        current = chapter.scenes.firstWhere(
          (candidate) => candidate.sceneId == currentScene.id,
        );
        expect(chapter.status, StoryChapterGenerationStatus.passed);
        expect(current.status, StorySceneGenerationStatus.passed);
        expect(current.judgeStatus, StoryReviewStatus.passed);
        expect(current.consistencyStatus, StoryReviewStatus.passed);
        expect(
          chapter.scenes
              .singleWhere(
                (candidate) => candidate.sceneId == 'preserved-scene',
              )
              .status,
          StorySceneGenerationStatus.passed,
        );
        expect(
          generationStore.snapshot.chapters
              .singleWhere(
                (candidate) => candidate.chapterId == 'other-chapter',
              )
              .scenes
              .single
              .sceneId,
          'other-scene',
        );
      },
    );

    test(
      'records force-failure as blocked and preserves existing counters',
      () async {
        final currentScene = workspaceStore.currentScene;
        final currentChapterId = currentScene.chapterLabel;
        generationStore.replaceSnapshot(
          StoryGenerationSnapshot(
            projectId: workspaceStore.currentProjectId,
            chapters: [
              StoryChapterGenerationState(
                chapterId: currentChapterId,
                status: StoryChapterGenerationStatus.reviewing,
                scenes: [
                  StorySceneGenerationState(
                    sceneId: currentScene.id,
                    status: StorySceneGenerationStatus.reviewing,
                    judgeStatus: StoryReviewStatus.softFailed,
                    consistencyStatus: StoryReviewStatus.pending,
                    proseRetryCount: 3,
                    directorRetryCount: 4,
                    upstreamFingerprint: 'existing-fp',
                  ),
                ],
              ),
            ],
          ),
        );

        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        await runStore.runCurrentScene(forceFailure: true);

        expect(runStore.snapshot.status, StoryGenerationRunStatus.failed);
        expect(runStore.snapshot.phase, StoryGenerationRunPhase.fail);

        final chapter = generationStore.snapshot.chapters.singleWhere(
          (candidate) => candidate.chapterId == currentChapterId,
        );
        final current = chapter.scenes.singleWhere(
          (candidate) => candidate.sceneId == currentScene.id,
        );
        expect(chapter.status, StoryChapterGenerationStatus.blocked);
        expect(current.status, StorySceneGenerationStatus.blocked);
        expect(current.judgeStatus, StoryReviewStatus.failed);
        expect(current.consistencyStatus, StoryReviewStatus.failed);
        expect(current.proseRetryCount, 3);
        expect(current.directorRetryCount, 4);
        expect(current.upstreamFingerprint, 'existing-fp');
      },
    );

    test(
      'does not advance the visible snapshot when persistence fails',
      () async {
        final storage = _FailingStoryGenerationRunStorage();
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: storage,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        final initialSnapshot = runStore.snapshot;

        await expectLater(
          runStore.runCurrentScene(forceFailure: true),
          throwsA(isA<StateError>()),
        );

        expect(runStore.snapshot, same(initialSnapshot));
        expect(runStore.snapshot.status, StoryGenerationRunStatus.idle);
      },
    );

    test('cancels an active run and ignores later completion', () async {
      generationStore.dispose();
      final bus = AppEventBus();
      addTearDown(bus.dispose);
      final failedEvents = <StoryGenerationFailedEvent>[];
      final cancelledEvents = <StoryGenerationCancelledEvent>[];
      bus.listen<StoryGenerationFailedEvent>(failedEvents.add);
      bus.listen<StoryGenerationCancelledEvent>(cancelledEvents.add);
      generationStore = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        workspaceStore: workspaceStore,
        eventBus: bus,
      );
      await generationStore.waitUntilReady();

      final currentScene = workspaceStore.currentScene;
      final currentChapterId = currentScene.chapterLabel;
      final storage = InMemoryStoryGenerationRunStorage();
      final orchestrator = _ControlledOrchestrator(
        settingsStore: settingsStore,
      );
      final runStore = StoryGenerationRunStore(
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        generationStore: generationStore,
        storage: storage,
        orchestratorFactory: (_) => orchestrator,
      );
      addTearDown(runStore.dispose);
      await runStore.waitUntilReady();

      final runFuture = runStore.runCurrentScene();
      await orchestrator.started.future;

      expect(runStore.snapshot.status, StoryGenerationRunStatus.running);
      expect(runStore.snapshot.phase, StoryGenerationRunPhase.draft);
      expect(await runStore.cancelCurrentRun(), isTrue);
      expect(runStore.snapshot.status, StoryGenerationRunStatus.cancelled);
      expect(runStore.snapshot.phase, StoryGenerationRunPhase.cancel);
      expect(runStore.snapshot.stageSummary, '已取消');
      expect(
        runStore.snapshot.messages.map((message) => message.title),
        containsAll(<String>['进行中', '运行已取消']),
      );

      orchestrator.release.complete();
      await runFuture;

      expect(runStore.snapshot.status, StoryGenerationRunStatus.cancelled);
      expect(runStore.snapshot.headline, 'AI 试写已取消');
      final stored = await storage.load(
        sceneScopeId: workspaceStore.currentSceneScopeId,
      );
      expect(stored?['status'], StoryGenerationRunStatus.cancelled.name);
      expect(stored?['phase'], StoryGenerationRunPhase.cancel.name);

      final chapter = generationStore.snapshot.chapters.singleWhere(
        (candidate) => candidate.chapterId == currentChapterId,
      );
      final current = chapter.scenes.singleWhere(
        (candidate) => candidate.sceneId == currentScene.id,
      );
      expect(chapter.status, StoryChapterGenerationStatus.blocked);
      expect(current.status, StorySceneGenerationStatus.blocked);
      expect(current.judgeStatus, StoryReviewStatus.failed);
      expect(current.consistencyStatus, StoryReviewStatus.failed);
      expect(failedEvents, isEmpty);
      expect(cancelledEvents, hasLength(1));
      expect(cancelledEvents.first.projectId, generationStore.activeProjectId);
      expect(cancelledEvents.first.sceneId, currentScene.id);
    });

    test('double-clicking an active scene joins one provider run', () async {
      final orchestrator = _ControlledOrchestrator(
        settingsStore: settingsStore,
      );
      var factoryCalls = 0;
      final runStore = StoryGenerationRunStore(
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        generationStore: generationStore,
        storage: InMemoryStoryGenerationRunStorage(),
        orchestratorFactory: (_) {
          factoryCalls += 1;
          return orchestrator;
        },
      );
      addTearDown(runStore.dispose);
      await runStore.waitUntilReady();

      final first = runStore.runCurrentScene();
      await orchestrator.started.future;
      final second = runStore.runCurrentScene();
      await Future<void>.delayed(Duration.zero);

      expect(factoryCalls, 1);
      expect(runStore.snapshot.status, StoryGenerationRunStatus.running);
      orchestrator.release.complete();
      await Future.wait([first, second]);
      expect(runStore.snapshot.status, StoryGenerationRunStatus.completed);
    });

    test(
      'a fresh run after cancellation cannot be overwritten by old token',
      () async {
        final firstOrchestrator = _ControlledOrchestrator(
          settingsStore: settingsStore,
        );
        final secondOrchestrator = _ControlledOrchestrator(
          settingsStore: settingsStore,
        );
        var factoryCalls = 0;
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
          orchestratorFactory: (_) =>
              factoryCalls++ == 0 ? firstOrchestrator : secondOrchestrator,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        final oldRun = runStore.runCurrentScene();
        await firstOrchestrator.started.future;
        expect(await runStore.cancelCurrentRun(), isTrue);
        final freshRun = runStore.runCurrentScene();
        await secondOrchestrator.started.future;

        firstOrchestrator.release.complete();
        await oldRun;
        expect(runStore.snapshot.status, StoryGenerationRunStatus.running);
        secondOrchestrator.release.complete();
        await freshRun;

        expect(factoryCalls, 2);
        expect(runStore.snapshot.status, StoryGenerationRunStatus.completed);
        expect(runStore.snapshot.runId, isNotEmpty);
      },
    );

    test(
      'cancelled run must not persist character memory deltas from in-flight orchestrator',
      () async {
        final pausingStorage = _PausingStoryMemoryStorage();
        final characterMemorySpy = _RecordingCharacterMemoryStore();
        final orchestrator = _MemoryPausingOrchestrator(
          settingsStore: settingsStore,
          pausingStorage: pausingStorage,
          characterMemorySpy: characterMemorySpy,
        );
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
          orchestratorFactory: (_) => orchestrator,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        final runFuture = runStore.runCurrentScene();
        await pausingStorage.saveChunksEntered;

        expect(runStore.snapshot.status, StoryGenerationRunStatus.running);
        expect(runStore.snapshot.phase, StoryGenerationRunPhase.draft);
        expect(await runStore.cancelCurrentRun(), isTrue);

        pausingStorage.releaseSaveChunks();
        await runFuture;

        expect(runStore.snapshot.status, StoryGenerationRunStatus.cancelled);
        expect(runStore.snapshot.phase, StoryGenerationRunPhase.cancel);
        expect(characterMemorySpy.acceptedDeltaWrites, isEmpty);
      },
    );
  });

  group('StoryGenerationRunStore review task integration', () {
    late AppSettingsStore settingsStore;
    late AppWorkspaceStore workspaceStore;
    late StoryGenerationStore generationStore;

    setUp(() async {
      settingsStore = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      generationStore = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        workspaceStore: workspaceStore,
      );
      await generationStore.waitUntilReady();
    });

    tearDown(() {
      generationStore.dispose();
      workspaceStore.dispose();
      settingsStore.dispose();
    });

    test('rewrite review creates open review tasks', () async {
      final reviewTaskStore = ReviewTaskStore(
        storage: InMemoryReviewTaskStorage(),
        workspaceStore: workspaceStore,
      );
      addTearDown(reviewTaskStore.dispose);

      final orchestrator = _ControlledOrchestrator(
        settingsStore: settingsStore,
        reviewResult: const SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.rewriteProse,
            reason: 'prose needs improvement',
            rawText: '',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: 'consistent',
            rawText: '',
          ),
          decision: SceneReviewDecision.rewriteProse,
        ),
      );
      final runStore = StoryGenerationRunStore(
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        generationStore: generationStore,
        storage: InMemoryStoryGenerationRunStorage(),
        orchestratorFactory: (_) => orchestrator,
        reviewTaskStore: reviewTaskStore,
      );
      addTearDown(runStore.dispose);
      await runStore.waitUntilReady();

      final runFuture = runStore.runCurrentScene();
      await orchestrator.started.future;
      orchestrator.release.complete();
      await runFuture;

      expect(reviewTaskStore.tasks, isNotEmpty);
      for (final task in reviewTaskStore.tasks) {
        expect(task.status, ReviewTaskStatus.open);
        expect(task.body, contains('prose needs improvement'));
      }
    });

    test('pass review does not create review tasks', () async {
      final reviewTaskStore = ReviewTaskStore(
        storage: InMemoryReviewTaskStorage(),
        workspaceStore: workspaceStore,
      );
      addTearDown(reviewTaskStore.dispose);

      final orchestrator = _ControlledOrchestrator(
        settingsStore: settingsStore,
      );
      final runStore = StoryGenerationRunStore(
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        generationStore: generationStore,
        storage: InMemoryStoryGenerationRunStorage(),
        orchestratorFactory: (_) => orchestrator,
        reviewTaskStore: reviewTaskStore,
      );
      addTearDown(runStore.dispose);
      await runStore.waitUntilReady();

      final runFuture = runStore.runCurrentScene();
      await orchestrator.started.future;
      orchestrator.release.complete();
      await runFuture;

      expect(reviewTaskStore.tasks, isEmpty);
    });

    test(
      'replan review creates open review tasks for all failing passes',
      () async {
        final reviewTaskStore = ReviewTaskStore(
          storage: InMemoryReviewTaskStorage(),
          workspaceStore: workspaceStore,
        );
        addTearDown(reviewTaskStore.dispose);

        final orchestrator = _ControlledOrchestrator(
          settingsStore: settingsStore,
          reviewResult: const SceneReviewResult(
            judge: SceneReviewPassResult(
              status: SceneReviewStatus.replanScene,
              reason: 'plot contradiction detected',
              rawText: '',
            ),
            consistency: SceneReviewPassResult(
              status: SceneReviewStatus.replanScene,
              reason: 'timeline inconsistency',
              rawText: '',
            ),
            decision: SceneReviewDecision.replanScene,
          ),
        );
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
          orchestratorFactory: (_) => orchestrator,
          reviewTaskStore: reviewTaskStore,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        final runFuture = runStore.runCurrentScene();
        await orchestrator.started.future;
        orchestrator.release.complete();
        await runFuture;

        expect(reviewTaskStore.tasks.length, 2);
        for (final task in reviewTaskStore.tasks) {
          expect(task.status, ReviewTaskStatus.open);
        }
      },
    );

    test(
      'existing review task status is preserved on repeated upsert',
      () async {
        final reviewTaskStore = ReviewTaskStore(
          storage: InMemoryReviewTaskStorage(),
          workspaceStore: workspaceStore,
        );
        addTearDown(reviewTaskStore.dispose);

        const rewriteResult = SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.rewriteProse,
            reason: 'prose needs improvement',
            rawText: '',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: 'consistent',
            rawText: '',
          ),
          decision: SceneReviewDecision.rewriteProse,
        );

        final orchestrator1 = _ControlledOrchestrator(
          settingsStore: settingsStore,
          reviewResult: rewriteResult,
        );
        final orchestrator2 = _ControlledOrchestrator(
          settingsStore: settingsStore,
          reviewResult: rewriteResult,
        );
        var factoryCallCount = 0;
        final runStore = StoryGenerationRunStore(
          settingsStore: settingsStore,
          workspaceStore: workspaceStore,
          generationStore: generationStore,
          storage: InMemoryStoryGenerationRunStorage(),
          orchestratorFactory: (_) {
            factoryCallCount++;
            return factoryCallCount == 1 ? orchestrator1 : orchestrator2;
          },
          reviewTaskStore: reviewTaskStore,
        );
        addTearDown(runStore.dispose);
        await runStore.waitUntilReady();

        // First run: creates open review task.
        final runFuture1 = runStore.runCurrentScene();
        await orchestrator1.started.future;
        orchestrator1.release.complete();
        await runFuture1;

        expect(reviewTaskStore.tasks.length, 1);
        final taskId = reviewTaskStore.tasks.first.id;
        expect(reviewTaskStore.tasks.first.status, ReviewTaskStatus.open);

        // Manually advance status.
        reviewTaskStore.updateStatus(taskId, ReviewTaskStatus.inProgress);
        expect(reviewTaskStore.tasks.first.status, ReviewTaskStatus.inProgress);

        // Second run: same review result produces same task IDs.
        final runFuture2 = runStore.runCurrentScene();
        await orchestrator2.started.future;
        orchestrator2.release.complete();
        await runFuture2;

        expect(reviewTaskStore.tasks.length, 1);
        expect(
          reviewTaskStore.tasks.first.status,
          ReviewTaskStatus.inProgress,
          reason: 'upsertAll should preserve existing task status',
        );
      },
    );
  });
}

void _commitPriorContinuity({
  required GenerationLedgerSqliteStore ledger,
  required Database db,
  required String projectId,
  required String chapterId,
  required String sceneId,
  required String sourceSceneId,
}) {
  const runId = 'prior-continuity-run';
  const finalProse = '柳溪取得证据手机。';
  const writeId = 'prior-continuity-write';
  const candidateHash = 'prior-continuity-candidate';
  const materialDigest = 'prior-continuity-material';
  const inputDigest = 'prior-continuity-input';
  const deterministicGateHash = 'prior-continuity-gate';
  const finalCouncilHash = 'prior-continuity-council';
  const qualityHash = 'prior-continuity-quality';
  const baseDraft = '上一场景旧草稿。';
  final sceneScopeId = '$projectId::$sceneId';
  final finalProseHash = GenerationCommitDigest.text(finalProse);
  final payload = <String, Object?>{
    'kind': 'sceneSummaryContribution',
    'schemaVersion': 1,
    'projectId': projectId,
    'chapterId': chapterId,
    'sceneId': sceneId,
    'target': <String, Object?>{
      'projectId': projectId,
      'chapterId': chapterId,
      'sceneId': sceneId,
    },
    'contribution': <String, Object?>{
      'sceneId': sceneId,
      'finalProseHash': finalProseHash,
      'prose': finalProse,
      'continuityLedger': <Object?>[
        <String, Object?>{
          'entityId': 'evidence-phone',
          'aliases': <String>['证据手机', '手机'],
          'holder': 'character-liuxi',
          'location': '蓝色柜机',
          'status': 'held',
          'sourceSceneId': sourceSceneId,
        },
      ],
    },
  };
  final payloadJson = GenerationPendingWritePayloadIntegrity.canonicalJson(
    payload,
  );
  final payloadHash = GenerationPendingWritePayloadIntegrity.hashCanonicalJson(
    payloadJson,
  );
  final manifest = <Object?>[
    <String, Object?>{
      'writeId': writeId,
      'payloadHash': payloadHash,
      'runId': runId,
      'candidateRevision': 0,
    },
  ];
  final pendingWriteSetHash = GenerationPendingWritePayloadIntegrity.hashValue(
    manifest,
  );

  ledger.createRun(
    GenerationRunRecord(
      runId: runId,
      requestId: 'prior-continuity-request',
      projectId: projectId,
      chapterId: chapterId,
      sceneId: sceneId,
      sceneScopeId: sceneScopeId,
      status: 'running',
      phase: 'finalization',
      schemaVersion: 9,
      createdAtMs: 1,
      updatedAtMs: 1,
    ),
  );
  ledger.createWorkingProseRevision(
    WorkingProseRevisionRecord(
      runId: runId,
      proseRevision: 0,
      proseHash: finalProseHash,
      proseText: finalProse,
      sourceKind: 'polish',
      createdAtMs: 2,
    ),
  );
  ledger.reserveCandidateNamespace(
    const CandidateNamespaceRecord(
      runId: runId,
      candidateRevision: 0,
      sourceProseRevision: 0,
      reservedAtMs: 3,
    ),
  );
  ledger.upsertPendingWrite(
    PendingWriteRecord(
      runId: runId,
      candidateRevision: 0,
      writeId: writeId,
      projectId: projectId,
      chapterId: chapterId,
      sceneId: sceneId,
      logicalEntityId: sceneId,
      writeKind: 'sceneSummaryContribution',
      payloadHash: payloadHash,
      payloadJson: payloadJson,
      derivationClass: 'proseDerived',
      createdAtMs: 4,
      expiresAtMs: 1000,
    ),
  );
  seedHistoricalV1Candidate(
    db: db,
    runId: runId,
    candidateRevision: 0,
    projectId: projectId,
    chapterId: chapterId,
    sceneId: sceneId,
    sourceProseRevision: 0,
    candidateHash: candidateHash,
    finalProseHash: finalProseHash,
    deterministicGateEvidenceHash: deterministicGateHash,
    finalCouncilEvidenceHash: finalCouncilHash,
    qualityEvidenceHash: qualityHash,
    pendingWriteSetHash: pendingWriteSetHash,
    materialDigest: materialDigest,
    inputDigest: inputDigest,
    finalProse: finalProse,
    pendingWriteManifestJson:
        GenerationPendingWritePayloadIntegrity.canonicalJson(manifest),
    createdAtMs: 4,
    expiresAtMs: 1000,
  );
  db.execute(
    '''UPDATE story_generation_runs
       SET status = 'candidateReady', current_candidate_revision = 0
       WHERE run_id = ?''',
    <Object?>[runId],
  );
  db.execute(
    '''INSERT INTO draft_documents (project_id, text_body, updated_at_ms)
       VALUES (?, ?, ?)''',
    <Object?>[sceneScopeId, baseDraft, 4],
  );

  final result = (GenerationCommitCoordinator(db: db)..ensureTables()).accept(
    GenerationCommitRequest(
      acceptIdempotencyKey: 'prior-continuity-accept',
      runId: runId,
      candidateRevision: 0,
      projectId: projectId,
      sceneScopeId: sceneScopeId,
      candidateHash: candidateHash,
      expectedBaseDraftHash: GenerationCommitDigest.text(baseDraft),
      expectedMaterialDigest: materialDigest,
      expectedInputDigest: inputDigest,
      expectedFinalProseHash: finalProseHash,
      expectedDeterministicGateEvidenceHash: deterministicGateHash,
      expectedFinalCouncilEvidenceHash: finalCouncilHash,
      expectedQualityEvidenceHash: qualityHash,
      expectedPendingWriteSetHash: pendingWriteSetHash,
      committedAtMs: 5,
    ),
  );
  expect(result, isA<GenerationCommitApplied>());
}

class _FailingStoryGenerationRunStorage
    extends InMemoryStoryGenerationRunStorage {
  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String sceneScopeId,
  }) async {
    throw StateError('snapshot persistence failed');
  }
}

class _ControlledOrchestrator extends PipelineStageRunnerImpl {
  _ControlledOrchestrator({required super.settingsStore, this.reviewResult});

  final SceneReviewResult? reviewResult;
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  SceneBrief? receivedBrief;
  ProjectMaterialSnapshot? receivedMaterials;

  @override
  Future<SceneRuntimeOutput> runPreparedScene(
    PreparedSceneBrief prepared, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) async {
    final brief = prepared.brief;
    receivedBrief = brief;
    receivedMaterials = materials;
    started.complete();
    await release.future;
    return SceneRuntimeOutput(
      brief: brief,
      resolvedCast: const [],
      director: const SceneDirectorOutput(text: 'director output'),
      roleOutputs: const [],
      prose: const SceneProseDraft(text: 'prose', attempt: 1),
      review:
          reviewResult ??
          const SceneReviewResult(
            judge: SceneReviewPassResult(
              status: SceneReviewStatus.pass,
              reason: 'pass',
              rawText: '',
            ),
            consistency: SceneReviewPassResult(
              status: SceneReviewStatus.pass,
              reason: 'consistent',
              rawText: '',
            ),
            decision: SceneReviewDecision.pass,
          ),
      proseAttempts: 1,
      softFailureCount: 0,
    );
  }
}

class _TerminalErrorOrchestrator extends PipelineStageRunnerImpl {
  _TerminalErrorOrchestrator({
    required super.settingsStore,
    required this.error,
  });

  final Object error;

  @override
  Future<SceneRuntimeOutput> runPreparedScene(
    PreparedSceneBrief prepared, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) => Future<SceneRuntimeOutput>.error(error);
}

class _PausingStoryMemoryStorage implements StoryMemoryStorage {
  final Completer<void> _saveChunksEntered = Completer<void>();
  final Completer<void> _releaseSaveChunks = Completer<void>();
  int attemptedSaveChunksCount = 0;

  Future<void> get saveChunksEntered => _saveChunksEntered.future;

  void releaseSaveChunks() {
    if (!_releaseSaveChunks.isCompleted) {
      _releaseSaveChunks.complete();
    }
  }

  @override
  Future<void> saveChunks(
    String projectId,
    List<StoryMemoryChunk> chunks,
  ) async {
    attemptedSaveChunksCount++;
    if (!_saveChunksEntered.isCompleted) {
      _saveChunksEntered.complete();
    }
    await _releaseSaveChunks.future;
  }

  @override
  Future<void> saveSources(
    String projectId,
    List<StoryMemorySource> sources,
  ) async {}

  @override
  Future<List<StoryMemorySource>> loadSources(String projectId) async => [];

  @override
  Future<List<StoryMemoryChunk>> loadChunks(String projectId) async => [];

  @override
  Future<void> saveThoughts(
    String projectId,
    List<ThoughtAtom> thoughts,
  ) async {}

  @override
  Future<List<ThoughtAtom>> loadThoughts(String projectId) async => [];

  @override
  Future<void> clearProject(String projectId) async {}
}

class _RecordingCharacterMemoryStore implements CharacterMemoryStore {
  final List<List<CharacterMemoryDelta>> acceptedDeltaWrites = [];

  @override
  Future<void> saveAcceptedDeltas({
    required String projectId,
    required String chapterId,
    required String sceneId,
    required MemoryTier tier,
    required String producer,
    required List<CharacterMemoryDelta> deltas,
  }) async {
    acceptedDeltaWrites.add(List.unmodifiable(deltas));
  }

  @override
  Future<List<CharacterMemoryDelta>> loadCharacterMemories({
    required String projectId,
    required String characterId,
    required MemoryTier tier,
  }) async => [];

  @override
  Future<List<CharacterMemoryDelta>> loadPublicMemories({
    required String projectId,
    required MemoryTier tier,
  }) async => [];

  @override
  Future<void> clearProject(String projectId) async {}
}

class _MemoryPausingOrchestrator extends PipelineStageRunnerImpl {
  _MemoryPausingOrchestrator({
    required super.settingsStore,
    required this.pausingStorage,
    required this.characterMemorySpy,
  });

  final _PausingStoryMemoryStorage pausingStorage;
  final _RecordingCharacterMemoryStore characterMemorySpy;

  @override
  Future<SceneRuntimeOutput> runPreparedScene(
    PreparedSceneBrief prepared, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) async {
    final brief = prepared.brief;
    await pausingStorage.saveChunks(
      brief.projectId ?? brief.chapterId,
      const [],
    );
    if (isRunCancelled?.call() != true) {
      await characterMemorySpy.saveAcceptedDeltas(
        projectId: brief.projectId ?? brief.chapterId,
        chapterId: brief.chapterId,
        sceneId: brief.sceneId,
        tier: MemoryTier.character,
        producer: 'roleplay',
        deltas: [
          CharacterMemoryDelta(
            deltaId: 'test-delta-1',
            kind: CharacterMemoryDeltaKind.observation,
            content: 'should not persist after cancel',
            acl: VisibilityAcl(),
            sourceRound: 1,
            accepted: true,
          ),
        ],
      );
    }
    return SceneRuntimeOutput(
      brief: brief,
      resolvedCast: const [],
      director: const SceneDirectorOutput(text: 'director output'),
      roleOutputs: const [],
      prose: const SceneProseDraft(text: 'prose', attempt: 1),
      review: const SceneReviewResult(
        judge: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: 'pass',
          rawText: '',
        ),
        consistency: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: 'consistent',
          rawText: '',
        ),
        decision: SceneReviewDecision.pass,
      ),
      proseAttempts: 1,
      softFailureCount: 0,
    );
  }
}
