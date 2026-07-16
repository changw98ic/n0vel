part of '../story_generation_run_store.dart';

extension _StoryGenerationRunSceneState on StoryGenerationRunStore {
  Future<void> _recordSceneState({
    required SceneBrief brief,
    required StorySceneGenerationStatus status,
    required StoryReviewStatus reviewStatus,
    String terminalReason = '',
  }) {
    final snapshot = _generationStore.snapshot;
    final chapters = List<StoryChapterGenerationState>.from(snapshot.chapters);
    final chapterIndex = chapters.indexWhere(
      (chapter) => chapter.chapterId == brief.chapterId,
    );
    final existingChapter = chapterIndex == -1
        ? StoryChapterGenerationState(
            chapterId: brief.chapterId,
            status: _chapterStatusForSceneStatus(status),
            targetLength: brief.targetLength,
            participatingRoleIds: _castRoleIdsForBrief(brief),
            worldNodeIds: brief.worldNodeIds,
          )
        : chapters[chapterIndex];

    final scenes = List<StorySceneGenerationState>.from(existingChapter.scenes);
    final sceneIndex = scenes.indexWhere(
      (scene) => scene.sceneId == brief.sceneId,
    );
    final nextScene = sceneIndex == -1
        ? StorySceneGenerationState(
            sceneId: brief.sceneId,
            status: status,
            judgeStatus: reviewStatus,
            consistencyStatus: reviewStatus,
            proseRetryCount: 0,
            directorRetryCount: 0,
            castRoleIds: _castRoleIdsForBrief(brief),
            worldNodeIds: brief.worldNodeIds,
            upstreamFingerprint: '',
            terminalReason: terminalReason,
          )
        : scenes[sceneIndex].copyWith(
            status: status,
            judgeStatus: reviewStatus,
            consistencyStatus: reviewStatus,
            castRoleIds: scenes[sceneIndex].castRoleIds.isEmpty
                ? _castRoleIdsForBrief(brief)
                : null,
            worldNodeIds: scenes[sceneIndex].worldNodeIds.isEmpty
                ? brief.worldNodeIds
                : null,
            terminalReason: terminalReason,
          );
    if (sceneIndex == -1) {
      scenes.add(nextScene);
    } else {
      scenes[sceneIndex] = nextScene;
    }

    final nextChapter = existingChapter.copyWith(
      status: _chapterStatusForSceneStatus(status),
      targetLength: existingChapter.targetLength == 0
          ? brief.targetLength
          : existingChapter.targetLength,
      participatingRoleIds: existingChapter.participatingRoleIds.isEmpty
          ? _castRoleIdsForBrief(brief)
          : null,
      worldNodeIds: existingChapter.worldNodeIds.isEmpty
          ? brief.worldNodeIds
          : null,
      scenes: scenes,
    );
    if (chapterIndex == -1) {
      chapters.add(nextChapter);
    } else {
      chapters[chapterIndex] = nextChapter;
    }

    _generationStore.replaceSnapshot(snapshot.copyWith(chapters: chapters));
    // StoryGenerationStorage may persist on a helper isolate. Await its
    // durable completion before the authoritative run/ledger connection
    // enters the next write boundary; otherwise two writers can overlap and
    // a long busy timeout merely hides the lifecycle race.
    return _generationStore.waitUntilReady();
  }

  Future<void> _recordSceneStateForCurrentRun({
    required StorySceneGenerationStatus status,
    required StoryReviewStatus reviewStatus,
    String terminalReason = '',
  }) {
    final currentScene = _workspaceStore.currentScene;
    return _recordSceneState(
      brief: SceneBrief(
        chapterId: currentScene.chapterLabel,
        chapterTitle: currentScene.chapterLabel,
        sceneId: currentScene.id,
        sceneTitle: currentScene.title,
        sceneSummary: currentScene.summary,
        formalExecution: formalEvaluation,
        metadata: _runtimeMetadata(
          revisionRequests: _activeRevisionRequestsForCurrentScene(
            chapterId: currentScene.chapterLabel,
            sceneId: currentScene.id,
          ),
        ),
      ),
      status: status,
      reviewStatus: reviewStatus,
      terminalReason: terminalReason,
    );
  }

  StoryChapterGenerationStatus _chapterStatusForSceneStatus(
    StorySceneGenerationStatus status,
  ) {
    return switch (status) {
      StorySceneGenerationStatus.passed => StoryChapterGenerationStatus.passed,
      StorySceneGenerationStatus.blocked =>
        StoryChapterGenerationStatus.blocked,
      StorySceneGenerationStatus.invalidated =>
        StoryChapterGenerationStatus.invalidated,
      StorySceneGenerationStatus.reviewing =>
        StoryChapterGenerationStatus.reviewing,
      StorySceneGenerationStatus.pending =>
        StoryChapterGenerationStatus.pending,
      StorySceneGenerationStatus.directing ||
      StorySceneGenerationStatus.roleRunning ||
      StorySceneGenerationStatus.drafting =>
        StoryChapterGenerationStatus.inProgress,
    };
  }

  List<String> _castRoleIdsForBrief(SceneBrief brief) {
    return [for (final cast in brief.cast) cast.characterId];
  }
}
