import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/events/app_domain_events.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_delta_models.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_store.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/data/character_visible_context_models.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/review_tasks/domain/review_task_models.dart';

void main() {
  group('StoryGenerationRunEventSubscriptions', () {
    test(
      'routes run store events and stops forwarding after dispose',
      () async {
        final eventBus = AppEventBus();
        addTearDown(eventBus.dispose);
        final deletedProjects = <String>[];
        final sceneScopes = <String>[];

        final subscriptions = StoryGenerationRunEventSubscriptions(
          eventBus: eventBus,
          onProjectDeleted: (event) => deletedProjects.add(event.projectId),
          onSceneScopeChanged: sceneScopes.add,
        );

        eventBus
          ..publish(const ProjectDeletedEvent(projectId: 'project-a'))
          ..publish(
            const SceneChangedEvent(
              projectId: 'project-a',
              sceneId: 'scene-1',
              sceneScopeId: 'project-a::scene-1',
            ),
          )
          ..publish(
            const ProjectScopeChangedEvent(
              projectId: 'project-b',
              sceneScopeId: 'project-b::scene-2',
            ),
          );

        expect(deletedProjects, ['project-a']);
        expect(sceneScopes, ['project-a::scene-1', 'project-b::scene-2']);

        subscriptions.dispose();

        eventBus
          ..publish(const ProjectDeletedEvent(projectId: 'project-c'))
          ..publish(
            const SceneChangedEvent(
              projectId: 'project-c',
              sceneId: 'scene-3',
              sceneScopeId: 'project-c::scene-3',
            ),
          );

        expect(deletedProjects, ['project-a']);
        expect(sceneScopes, ['project-a::scene-1', 'project-b::scene-2']);
      },
    );

    test('allows stores without an event bus', () async {
      final subscriptions = StoryGenerationRunEventSubscriptions(
        eventBus: null,
        onProjectDeleted: (_) => fail('project deleted should not fire'),
        onSceneScopeChanged: (_) => fail('scene scope should not change'),
      );

      subscriptions.dispose();
    });
  });

  group('StoryGenerationRunPipelineFactory', () {
    test('builds default pipeline runners from workspace style settings', () {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
      );
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(settingsStore.dispose);
      addTearDown(workspaceStore.dispose);

      workspaceStore.updateStyleQuestionnaireField('profile_name', '测试风格');
      workspaceStore.updateStyleQuestionnaireField(
        'pov_mode',
        'third_person_limited',
      );
      workspaceStore.updateStyleQuestionnaireField('dialogue_ratio', 'medium');
      workspaceStore.updateStyleQuestionnaireField(
        'description_density',
        'medium',
      );
      workspaceStore.updateStyleQuestionnaireField(
        'emotional_intensity',
        'medium',
      );
      workspaceStore.updateStyleQuestionnaireField('rhythm_profile', 'tight');
      workspaceStore.updateStyleQuestionnaireField('genre_tags', const ['悬疑']);
      workspaceStore.generateStyleProfileFromQuestionnaire();

      final runner = StoryGenerationRunPipelineFactory(
        workspaceStore: workspaceStore,
      ).create(settingsStore);

      expect(runner.enableWritingReference, isTrue);
      expect(runner.styleReferenceConfig.enabled, isTrue);
      expect(runner.styleReferenceConfig.profileName, '测试风格');
      expect(runner.maxProseRetries, 1);
    });
  });

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
      'preserves stage timeline across run lifecycle: running with first stage active, completed with all stages completed',
      () async {
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

        // Start the run and wait for the orchestrator to start
        final runFuture = runStore.runCurrentScene();
        await orchestrator.started.future;

        // Assert: running snapshot has the stage timeline with first stage marked running
        expect(runStore.snapshot.status, StoryGenerationRunStatus.running);
        expect(runStore.snapshot.stageTimeline, isNotEmpty);
        expect(
          runStore.snapshot.stageTimeline.first.status,
          StoryGenerationRunStageStatus.running,
          reason:
              'First stage should be marked as running while orchestrator is active',
        );
        expect(
          runStore.snapshot.stageTimeline
              .skip(1)
              .any((s) => s.status == StoryGenerationRunStageStatus.running),
          isFalse,
          reason: 'Only the first stage should be marked as running initially',
        );

        // Release the orchestrator and await completion
        orchestrator.release.complete();
        await runFuture;

        // Assert: completed snapshot still has the timeline and all stages are completed
        expect(runStore.snapshot.status, StoryGenerationRunStatus.completed);
        expect(
          runStore.snapshot.stageTimeline,
          isNotEmpty,
          reason: 'Completed snapshot should preserve the stage timeline',
        );
        for (final stage in runStore.snapshot.stageTimeline) {
          expect(
            stage.status,
            StoryGenerationRunStageStatus.completed,
            reason:
                'All stages should be marked as completed after successful run',
          );
        }

        // Assert: persisted run storage also includes non-empty stageTimeline
        final stored = await storage.load(
          sceneScopeId: workspaceStore.currentSceneScopeId,
        );
        expect(stored, isNotNull);
        final storedTimeline = stored!['stageTimeline'] as List<Object?>?;
        expect(storedTimeline, isNotNull);
        expect(
          storedTimeline,
          isNotEmpty,
          reason: 'Persisted storage should include non-empty stageTimeline',
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

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) async {
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
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) async {
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
