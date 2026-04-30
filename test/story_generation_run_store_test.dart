import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/features/story_generation/data/chapter_generation_orchestrator.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
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

    test('cancels an active run and ignores later completion', () async {
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
      expect(runStore.cancelCurrentRun(), isTrue);
      expect(runStore.snapshot.status, StoryGenerationRunStatus.cancelled);
      expect(runStore.snapshot.stageSummary, '已取消');
      expect(
        runStore.snapshot.messages.map((message) => message.title),
        containsAll(<String>['进行中', '运行已取消']),
      );

      orchestrator.release.complete();
      await runFuture;

      expect(runStore.snapshot.status, StoryGenerationRunStatus.cancelled);
      expect(runStore.snapshot.headline, '角色编排已取消');
      final stored = await storage.load(
        sceneScopeId: workspaceStore.currentSceneScopeId,
      );
      expect(stored?['status'], StoryGenerationRunStatus.cancelled.name);

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
    });
  });
}

class _ControlledOrchestrator extends ChapterGenerationOrchestrator {
  _ControlledOrchestrator({required super.settingsStore});

  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function(String message)? onStatus,
    void Function()? onSpeculationReady,
  }) async {
    onStatus?.call('fake orchestrator running');
    started.complete();
    await release.future;
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
