import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/author_feedback/data/author_feedback_store.dart';
import '../../features/author_feedback/domain/author_feedback_models.dart';
import '../../features/review_tasks/data/review_task_mapper.dart';
import '../../features/review_tasks/data/review_task_store.dart';
// Intentional: run store bridges app state to feature pipeline.
import '../../features/story_generation/data/pipeline_stage_runner_impl.dart';
import '../../features/story_generation/data/pipeline_definition.dart'
    show BuiltInPresets, PipelinePreset, PipelineStageId;
import '../../features/story_generation/data/generation_pipeline_config.dart';
import '../../features/story_generation/data/scene_context_assembler.dart';
import '../../features/story_generation/data/story_generation_models.dart';
import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';
import 'app_store_listenable.dart';
import 'app_scene_context_store.dart';
import 'app_settings_store.dart';
import 'app_storage_clone.dart';
import 'app_workspace_store.dart';
import 'story_generation_run_storage.dart';
import 'story_generation_store.dart';
import 'story_outline_store.dart';

part 'story_generation_run/story_generation_run_snapshot.dart';
part 'story_generation_run/story_generation_run_scene_brief.dart';
part 'story_generation_run/story_generation_run_scene_state.dart';
part 'story_generation_run/story_generation_run_snapshot_mapping.dart';
part 'story_generation_run/story_generation_run_snapshot_persistence.dart';
part 'story_generation_run/story_generation_run_snapshot_repository.dart';
part 'story_generation_run/story_generation_run_event_subscriptions.dart';
part 'story_generation_run/story_generation_run_lifecycle_coordinator.dart';
part 'story_generation_run/story_generation_run_pipeline_factory.dart';
part 'story_generation_run/story_generation_run_scene_switch_policy.dart';
part 'story_generation_run/story_generation_run_session_controller.dart';

class StoryGenerationRunStore extends AppStoreListenable {
  StoryGenerationRunStore({
    required AppSettingsStore settingsStore,
    required AppWorkspaceStore workspaceStore,
    required StoryGenerationStore generationStore,
    AppSceneContextStore? sceneContextStore,
    StoryOutlineStore? outlineStore,
    AuthorFeedbackStore? authorFeedbackStore,
    RoleplaySessionStore? roleplaySessionStore,
    CharacterMemoryStore? characterMemoryStore,
    ReviewTaskStore? reviewTaskStore,
    AppEventBus? eventBus,
    StoryGenerationRunStorage? storage,
    SceneContextAssembler? sceneContextAssembler,
    StoryGenerationRunLifecycleCoordinator? lifecycleCoordinator,
    StoryGenerationRunPipelineFactory? pipelineFactory,
    StoryGenerationRunSceneSwitchPolicy sceneSwitchPolicy =
        const StoryGenerationRunSceneSwitchPolicy(),
    PipelineStageRunnerImpl Function(AppSettingsStore settingsStore)?
    orchestratorFactory,
  }) : _settingsStore = settingsStore,
       _workspaceStore = workspaceStore,
       _generationStore = generationStore,
       _authorFeedbackStore = authorFeedbackStore,
       _reviewTaskStore = reviewTaskStore,
       _snapshotRepository = StoryGenerationRunSnapshotRepository(
         storage ?? createDefaultStoryGenerationRunStorage(),
       ),
       _lifecycle =
           lifecycleCoordinator ??
           StoryGenerationRunLifecycleCoordinator(
             initialSceneScopeId: workspaceStore.currentSceneScopeId,
           ),
       _sceneSwitchPolicy = sceneSwitchPolicy,
       _orchestratorFactory =
           orchestratorFactory ??
           (pipelineFactory ??
                   StoryGenerationRunPipelineFactory(
                     workspaceStore: workspaceStore,
                     roleplaySessionStore: roleplaySessionStore,
                     characterMemoryStore: characterMemoryStore,
                   ))
               .create {
    _snapshot = _idleSnapshotForCurrentScene();
    _eventSubscriptions = StoryGenerationRunEventSubscriptions(
      eventBus: eventBus,
      onProjectDeleted: _handleProjectDeleted,
      onSceneScopeChanged: _handleSceneScopeChanged,
    );
    _scheduleRestoreCurrentScene();
  }

  final AppSettingsStore _settingsStore;
  final AppWorkspaceStore _workspaceStore;
  final StoryGenerationStore _generationStore;
  final AuthorFeedbackStore? _authorFeedbackStore;
  final ReviewTaskStore? _reviewTaskStore;
  final StoryGenerationRunSnapshotRepository _snapshotRepository;
  final StoryGenerationRunLifecycleCoordinator _lifecycle;
  final StoryGenerationRunSceneSwitchPolicy _sceneSwitchPolicy;
  final StoryGenerationRunSessionController _runSession =
      StoryGenerationRunSessionController();
  late final StoryGenerationRunEventSubscriptions _eventSubscriptions;
  final PipelineStageRunnerImpl Function(AppSettingsStore settingsStore)
  _orchestratorFactory;
  final Map<String, List<String>> _directorFeedbackBySceneScope =
      <String, List<String>>{};
  late StoryGenerationRunSnapshot _snapshot;

  StoryGenerationRunSnapshot get snapshot => _snapshot;
  String get activeSceneScopeId => _lifecycle.activeSceneScopeId;
  Future<void> get ready => _lifecycle.ready;

  Future<StoryGenerationRunPhaseTransitionResult> transitionCurrentPhase(
    StoryGenerationRunPhase nextPhase,
  ) async {
    final transition = StoryGenerationRunPhaseTransitions.validate(
      _snapshot.phase,
      nextPhase,
    );
    if (!transition.accepted) {
      return transition;
    }
    await _setSnapshot(_snapshot.copyWith(phase: nextPhase));
    return transition;
  }

  Future<Map<String, Object?>> exportProjectJson() async {
    await waitUntilReady();
    final projectId = _workspaceStore.currentProjectId;
    final sceneScopeIds = <String>[
      for (final scene in _workspaceStore.scenes) '$projectId::${scene.id}',
    ];
    final cachedSnapshots = _snapshotRepository.exportProjectSnapshots(
      sceneScopeIds,
    );
    final storedSnapshots = await _snapshotRepository.exportStoredSnapshots(
      sceneScopeIds,
    );
    return {
      'projectId': projectId,
      'sceneRunsByScope': {...cachedSnapshots, ...storedSnapshots},
    };
  }

  Future<void> importProjectJson(Map<String, Object?> data) async {
    final projectId = _workspaceStore.currentProjectId;
    final knownSceneScopeIds = <String>[
      for (final scene in _workspaceStore.scenes) '$projectId::${scene.id}',
    ];
    for (final sceneScopeId in knownSceneScopeIds) {
      _directorFeedbackBySceneScope.remove(sceneScopeId);
    }

    final rawByScope = data['sceneRunsByScope'];
    if (rawByScope is Map) {
      await _snapshotRepository.importProjectSnapshots(
        _asStringObjectMap(rawByScope),
        knownSceneScopeIds,
      );
    } else {
      await _snapshotRepository.clearKnownScopes(knownSceneScopeIds);
    }

    final snapshotMap = rawByScope is Map ? rawByScope : const {};
    for (final entry in snapshotMap.entries) {
      final sceneScopeId = entry.key.toString();
      if (entry.value is! Map) {
        continue;
      }
      final payload = _asStringObjectMap(entry.value);
      final restoredSnapshot = StoryGenerationRunSnapshot.fromJson(payload);
      _directorFeedbackBySceneScope[sceneScopeId] = [
        for (final message in restoredSnapshot.messages)
          if (message.kind == StoryGenerationRunMessageKind.authorFeedback &&
              message.body.trim().isNotEmpty)
            message.body.trim(),
      ];
    }

    _snapshot = _idleSnapshotForCurrentScene();
    _lifecycle.markMutated();
    _scheduleRestoreCurrentScene();
    notifyListeners();
  }

  Future<void> waitUntilReady() => _lifecycle.waitUntilReady();

  void _handleProjectDeleted(ProjectDeletedEvent event) {
    final sceneScopePrefix = '${event.projectId}::';
    _lifecycle.markMutated();
    _snapshotRepository.clearCachedProject(event.projectId);
    _directorFeedbackBySceneScope.removeWhere(
      (key, _) => key == event.projectId || key.startsWith(sceneScopePrefix),
    );
    _runSession.clearProject(event.projectId);
    unawaited(_snapshotRepository.clearProjectStorage(event.projectId));
  }

  Future<void> runCurrentScene({bool forceFailure = false}) async {
    await _generationStore.waitUntilReady();
    await _authorFeedbackStore?.waitUntilReady();
    final runToken = _beginRun();
    final runSceneScopeId = activeSceneScopeId;
    final currentScene = _workspaceStore.currentScene;
    final revisionRequests = _activeRevisionRequestsForCurrentScene(
      chapterId: currentScene.chapterLabel,
      sceneId: currentScene.id,
    );
    _authorFeedbackStore?.markRevisionRequestsInProgress(
      revisionRequests,
      sourceRunId: runSceneScopeId,
    );
    final brief = SceneBrief(
      projectId: _workspaceStore.currentProjectId,
      chapterId: currentScene.chapterLabel,
      chapterTitle: currentScene.chapterLabel,
      sceneId: currentScene.id,
      sceneTitle: currentScene.title,
      sceneSummary: currentScene.summary,
      metadata: _runtimeMetadata(revisionRequests: revisionRequests),
    );
    final baseParticipants = _participantsForBrief(brief);
    final baseTimeline = StoryGenerationRunStageSnapshot.fromPreset(
      BuiltInPresets.defaultNineStage,
    );
    final runningTimeline = _markFirstStageRunning(baseTimeline);
    await _setSnapshot(
      StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.running,
        phase: StoryGenerationRunPhase.draft,
        sceneId: brief.sceneId,
        sceneLabel: _sceneLabel(),
        headline: 'AI 正在准备本章',
        summary: '正在整理章节目标、出场人物和改稿检查；正文不会被直接覆盖。',
        stageSummary: '正在准备候选稿',
        participants: baseParticipants,
        messages: [
          const StoryGenerationRunMessage(
            title: '进行中',
            body: 'AI 已开始按当前章节资料试写；生成内容会先作为候选记录，等待作者确认。',
            kind: StoryGenerationRunMessageKind.status,
          ),
          ..._revisionRequestMessages(revisionRequests),
        ],
        stageTimeline: runningTimeline,
      ),
    );
    _recordSceneState(
      brief: brief,
      status: StorySceneGenerationStatus.roleRunning,
      reviewStatus: StoryReviewStatus.pending,
    );
    if (forceFailure) {
      if (!_isCurrentRun(runToken, runSceneScopeId)) {
        return;
      }
      _recordSceneState(
        brief: brief,
        status: StorySceneGenerationStatus.blocked,
        reviewStatus: StoryReviewStatus.failed,
      );
      final failedTimeline = _markStageFailed(
        _snapshot.stageTimeline,
        PipelineStageId.scenePlanning,
        'orchestrator',
        '强制失败',
      );
      await _setSnapshot(
        _snapshot.copyWith(
          status: StoryGenerationRunStatus.failed,
          phase: StoryGenerationRunPhase.fail,
          headline: 'AI 试写失败',
          summary: 'AI 写作在生成正文前停止，正文未被改动。',
          stageSummary: '失败',
          errorDetail: 'force-failure',
          messages: [
            ..._snapshot.messages,
            const StoryGenerationRunMessage(
              title: '运行失败摘要',
              body: '这次 AI 试写已被停止，正文未被改动。',
              kind: StoryGenerationRunMessageKind.error,
            ),
          ],
          stageTimeline: failedTimeline,
        ),
      );
      _finishRun(runToken);
      return;
    }

    try {
      final orchestrator = _orchestratorFactory(_settingsStore);
      orchestrator.isRunCancelled = () =>
          !_isCurrentRun(runToken, runSceneScopeId);
      final output = await orchestrator.runScene(brief);
      if (!_isCurrentRun(runToken, runSceneScopeId)) {
        return;
      }
      final (sceneStatus, reviewStatus) = switch (output.review.decision) {
        SceneReviewDecision.pass => (
          StorySceneGenerationStatus.passed,
          StoryReviewStatus.passed,
        ),
        SceneReviewDecision.rewriteProse => (
          StorySceneGenerationStatus.blocked,
          StoryReviewStatus.softFailed,
        ),
        SceneReviewDecision.replanScene => (
          StorySceneGenerationStatus.blocked,
          StoryReviewStatus.failed,
        ),
      };
      _recordSceneState(
        brief: brief,
        status: sceneStatus,
        reviewStatus: reviewStatus,
      );
      await _setSnapshot(
        _snapshot.copyWith(
          phase: StoryGenerationRunPhase.candidate,
          stageSummary: '候选稿已生成',
        ),
      );
      await _setSnapshot(_snapshotFromOutput(output));
      _persistReviewTasks(output.review, brief, runSceneScopeId);
      _finishRun(runToken);
    } catch (error) {
      if (!_isCurrentRun(runToken, runSceneScopeId)) {
        return;
      }
      _recordSceneState(
        brief: brief,
        status: StorySceneGenerationStatus.blocked,
        reviewStatus: StoryReviewStatus.failed,
      );
      final failedTimeline = _markStageFailed(
        _snapshot.stageTimeline,
        PipelineStageId.scenePlanning,
        'orchestrator',
        error.toString(),
      );
      await _setSnapshot(
        StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.failed,
          phase: StoryGenerationRunPhase.fail,
          sceneId: brief.sceneId,
          sceneLabel: _sceneLabel(),
          headline: 'AI 试写失败',
          summary: '这次 AI 试写没有完成。',
          stageSummary: '失败',
          errorDetail: error.toString(),
          participants: baseParticipants,
          messages: [
            ..._authorFeedbackMessages(),
            StoryGenerationRunMessage(
              title: '运行失败摘要',
              body: error.toString(),
              kind: StoryGenerationRunMessageKind.error,
            ),
          ],
          stageTimeline: failedTimeline,
        ),
      );
      _finishRun(runToken);
    }
  }

  Future<bool> cancelCurrentRun() async {
    if (_snapshot.status != StoryGenerationRunStatus.running ||
        !_runSession.isActiveRunForScene(activeSceneScopeId)) {
      return false;
    }
    _recordSceneStateForCurrentRun(
      status: StorySceneGenerationStatus.blocked,
      reviewStatus: StoryReviewStatus.failed,
      terminalReason: 'cancelled',
    );
    await _setSnapshot(
      _snapshot.copyWith(
        status: StoryGenerationRunStatus.cancelled,
        phase: StoryGenerationRunPhase.cancel,
        headline: 'AI 试写已取消',
        summary: '这次 AI 试写已停止，已保留停止前的记录。',
        stageSummary: '已取消',
        errorDetail: 'cancelled',
        messages: [
          ..._snapshot.messages,
          const StoryGenerationRunMessage(
            title: '运行已取消',
            body: '用户停止了当前运行；已完成的阶段记录会保留，后续异步结果将被忽略。',
            kind: StoryGenerationRunMessageKind.status,
          ),
        ],
      ),
    );
    _runSession.clearActiveRun();
    return true;
  }

  Future<void> sendDirectorFeedback(String feedback) async {
    final trimmed = feedback.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final feedbacks = List<String>.from(
      _directorFeedbackBySceneScope[activeSceneScopeId] ?? const <String>[],
    )..add(trimmed);
    _directorFeedbackBySceneScope[activeSceneScopeId] = feedbacks;
    await _setSnapshot(
      _snapshot.copyWith(
        messages: [
          ..._snapshot.messages,
          StoryGenerationRunMessage(
            title: '作者反馈',
            body: trimmed,
            kind: StoryGenerationRunMessageKind.authorFeedback,
          ),
        ],
      ),
    );
  }

  void _handleSceneScopeChanged(String nextSceneScopeId) {
    final decision = _sceneSwitchPolicy.decide(
      currentSceneScopeId: activeSceneScopeId,
      nextSceneScopeId: nextSceneScopeId,
      currentStatus: _snapshot.status,
      hasActiveRunForCurrentScene: _runSession.isActiveRunForScene(
        activeSceneScopeId,
      ),
    );
    if (!decision.shouldSwitchScene) {
      return;
    }
    if (decision.action == StoryGenerationRunSceneSwitchAction.cancelRun) {
      unawaited(cancelCurrentRun());
    }
    _lifecycle.moveToSceneScope(decision.nextSceneScopeId);
    _snapshot = _idleSnapshotForCurrentScene();
    _scheduleRestoreCurrentScene();
    notifyListeners();
  }

  int _beginRun() {
    return _runSession.begin(activeSceneScopeId);
  }

  bool _isCurrentRun(int runToken, String sceneScopeId) {
    return _runSession.isCurrent(
      runToken: runToken,
      runSceneScopeId: sceneScopeId,
      visibleSceneScopeId: activeSceneScopeId,
    );
  }

  void _finishRun(int runToken) {
    _runSession.finish(runToken);
  }

  void _persistReviewTasks(
    SceneReviewResult review,
    SceneBrief brief,
    String runId,
  ) {
    final store = _reviewTaskStore;
    if (store == null) return;
    final tasks = const ReviewTaskMapper().fromSceneReviewResult(
      result: review,
      brief: brief,
      runId: runId,
    );
    if (tasks.isNotEmpty) {
      store.upsertAll(tasks);
    }
  }

  @override
  void dispose() {
    _eventSubscriptions.dispose();
    super.dispose();
  }

  void _notifySnapshotListeners() {
    notifyListeners();
  }

  void _scheduleRestoreCurrentScene() {
    unawaited(_lifecycle.trackReady(_restoreCurrentScene()));
  }

  /// Marks the specified stage as failed and all subsequent stages as pending.
  ///
  /// Used when a pipeline run fails to capture the failed stage information
  /// for display in the Run Center.
  List<StoryGenerationRunStageSnapshot> _markStageFailed(
    List<StoryGenerationRunStageSnapshot> timeline,
    PipelineStageId failedStageId,
    String failureCode,
    String summary,
  ) {
    final result = <StoryGenerationRunStageSnapshot>[];
    var foundFailed = false;
    for (final stage in timeline) {
      if (stage.stageId == failedStageId) {
        result.add(
          stage.copyWith(
            status: StoryGenerationRunStageStatus.failed,
            failureCode: failureCode,
            summary: summary,
          ),
        );
        foundFailed = true;
      } else if (foundFailed) {
        // Stages after the failed stage remain pending
        result.add(stage);
      } else {
        // Stages before the failed stage are marked completed
        result.add(
          stage.copyWith(status: StoryGenerationRunStageStatus.completed),
        );
      }
    }
    // If the failed stage wasn't found (e.g., custom pipeline), mark first stage as failed
    if (!foundFailed && timeline.isNotEmpty) {
      return [
        timeline.first.copyWith(
          status: StoryGenerationRunStageStatus.failed,
          failureCode: failureCode,
          summary: summary,
        ),
        ...timeline.skip(1),
      ];
    }
    return result;
  }
}

Map<String, Object?> _asStringObjectMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): cloneStorageValue(entry.value),
  };
}

class StoryGenerationRunScope
    extends InheritedNotifier<StoryGenerationRunStore> {
  const StoryGenerationRunScope({
    super.key,
    required StoryGenerationRunStore store,
    required super.child,
  }) : super(notifier: store);

  static StoryGenerationRunStore of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<StoryGenerationRunScope>();
    assert(
      scope != null,
      'StoryGenerationRunScope is missing in the widget tree.',
    );
    return scope!.notifier!;
  }
}
