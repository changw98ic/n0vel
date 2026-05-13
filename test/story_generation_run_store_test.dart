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
import 'package:novel_writer/features/story_generation/data/character_visible_context_models.dart';
import 'package:novel_writer/features/story_generation/data/chapter_generation_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

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
    required List<CharacterMemoryDelta> deltas,
  }) async {
    acceptedDeltaWrites.add(List.unmodifiable(deltas));
  }

  @override
  Future<List<CharacterMemoryDelta>> loadCharacterMemories({
    required String projectId,
    required String characterId,
  }) async => [];

  @override
  Future<List<CharacterMemoryDelta>> loadPublicMemories({
    required String projectId,
  }) async => [];

  @override
  Future<void> clearProject(String projectId) async {}
}

class _MemoryPausingOrchestrator extends ChapterGenerationOrchestrator {
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
    void Function(String message)? onStatus,
    void Function()? onSpeculationReady,
  }) async {
    onStatus?.call('pausing at saveChunks');
    await pausingStorage.saveChunks(brief.chapterId, const []);
    onStatus?.call('post-saveChunks: persisting character deltas');
    if (isRunCancelled?.call() != true) {
      await characterMemorySpy.saveAcceptedDeltas(
        projectId: brief.chapterId,
        chapterId: brief.chapterId,
        sceneId: brief.sceneId,
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
