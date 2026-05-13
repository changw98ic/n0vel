import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/author_feedback/data/author_feedback_store.dart';
import '../../features/author_feedback/domain/author_feedback_models.dart';
import '../../features/review_tasks/data/review_task_mapper.dart';
import '../../features/review_tasks/data/review_task_store.dart';
// Intentional: run store bridges app state to feature pipeline.
import '../../features/story_generation/data/chapter_generation_orchestrator.dart';
import '../../features/story_generation/data/scene_context_assembler.dart';
import '../../features/story_generation/data/story_generation_models.dart';
import '../../features/story_generation/data/style_reference_config.dart';
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

StyleReferenceConfig _styleReferenceConfigFromWorkspace(
  AppWorkspaceStore workspaceStore,
) {
  final profile = workspaceStore.selectedStyleProfile;
  if (profile == null) {
    return const StyleReferenceConfig(enabled: false);
  }
  return StyleReferenceConfig.fromProfile(
    intensity: workspaceStore.styleIntensity,
    profileId: profile.id,
    profileName: profile.name,
    profileSource: profile.source,
    profileJson: profile.jsonData,
  );
}

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
    ChapterGenerationOrchestrator Function(AppSettingsStore settingsStore)?
    orchestratorFactory,
  }) : _settingsStore = settingsStore,
       _workspaceStore = workspaceStore,
       _generationStore = generationStore,
       _authorFeedbackStore = authorFeedbackStore,
       _reviewTaskStore = reviewTaskStore,
       _eventBus = eventBus,
       _storage = storage ?? createDefaultStoryGenerationRunStorage(),
       _orchestratorFactory =
           orchestratorFactory ??
           ((settingsStore) {
             final styleReferenceConfig = _styleReferenceConfigFromWorkspace(
               workspaceStore,
             );
             return ChapterGenerationOrchestrator(
               settingsStore: settingsStore,
               enableWritingReference: styleReferenceConfig.enabled,
               styleReferenceConfig: styleReferenceConfig,
               roleplaySessionStore: roleplaySessionStore,
               characterMemoryStore: characterMemoryStore,
             );
           }) {
    _activeSceneScopeId = _workspaceStore.currentSceneScopeId;
    _snapshot = _idleSnapshotForCurrentScene();
    _projectDeletedSubscription = _eventBus?.listen<ProjectDeletedEvent>(
      _handleProjectDeleted,
    );
    _sceneChangedSubscription = _eventBus?.listen<SceneChangedEvent>(
      (e) => _handleSceneScopeChanged(e.sceneScopeId),
    );
    _projectScopeChangedSubscription =
        _eventBus?.listen<ProjectScopeChangedEvent>(
          (e) => _handleSceneScopeChanged(e.sceneScopeId),
        );
    _readyFuture = _restoreCurrentScene();
    unawaited(_readyFuture);
  }

  final AppSettingsStore _settingsStore;
  final AppWorkspaceStore _workspaceStore;
  final StoryGenerationStore _generationStore;
  final AuthorFeedbackStore? _authorFeedbackStore;
  final ReviewTaskStore? _reviewTaskStore;
  final AppEventBus? _eventBus;
  final StoryGenerationRunStorage _storage;
  final ChapterGenerationOrchestrator Function(AppSettingsStore settingsStore)
  _orchestratorFactory;
  final Map<String, StoryGenerationRunSnapshot> _snapshotsBySceneScope =
      <String, StoryGenerationRunSnapshot>{};
  final Map<String, List<String>> _directorFeedbackBySceneScope =
      <String, List<String>>{};
  late String _activeSceneScopeId;
  late StoryGenerationRunSnapshot _snapshot;
  Future<void> _readyFuture = Future<void>.value();
  Future<void> _queuedSnapshotPersistence = Future<void>.value();
  AsyncError? _queuedSnapshotPersistenceError;
  int _mutationVersion = 0;
  int _runToken = 0;
  int? _activeRunToken;
  String? _activeRunSceneScopeId;
  StreamSubscription<ProjectDeletedEvent>? _projectDeletedSubscription;
  StreamSubscription<SceneChangedEvent>? _sceneChangedSubscription;
  StreamSubscription<ProjectScopeChangedEvent>? _projectScopeChangedSubscription;

  StoryGenerationRunSnapshot get snapshot => _snapshot;
  String get activeSceneScopeId => _activeSceneScopeId;
  Future<void> get ready => _readyFuture;

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
    final sceneRunsByScope = <String, Object?>{};
    for (final scene in _workspaceStore.scenes) {
      final sceneScopeId = '$projectId::${scene.id}';
      final cached = _snapshotsBySceneScope[sceneScopeId];
      if (cached != null && cached.hasRun) {
        sceneRunsByScope[sceneScopeId] = cached.toJson();
        continue;
      }
      final restored = await _storage.load(sceneScopeId: sceneScopeId);
      if (restored == null) {
        continue;
      }
      final restoredSnapshot = StoryGenerationRunSnapshot.fromJson({
        for (final entry in restored.entries)
          entry.key: cloneStorageValue(entry.value),
      });
      if (!restoredSnapshot.hasRun) {
        continue;
      }
      sceneRunsByScope[sceneScopeId] = restoredSnapshot.toJson();
    }
    return {'projectId': projectId, 'sceneRunsByScope': sceneRunsByScope};
  }

  Future<void> importProjectJson(Map<String, Object?> data) async {
    final projectId = _workspaceStore.currentProjectId;
    final knownSceneScopeIds = {
      for (final scene in _workspaceStore.scenes) '$projectId::${scene.id}',
    };
    for (final sceneScopeId in knownSceneScopeIds) {
      _snapshotsBySceneScope.remove(sceneScopeId);
      _directorFeedbackBySceneScope.remove(sceneScopeId);
      await _storage.clear(sceneScopeId: sceneScopeId);
    }

    final rawByScope = data['sceneRunsByScope'];
    if (rawByScope is Map) {
      for (final entry in rawByScope.entries) {
        final sceneScopeId = entry.key.toString();
        if (entry.value is! Map) {
          continue;
        }
        final payload = _asStringObjectMap(entry.value);
        await _storage.save(payload, sceneScopeId: sceneScopeId);
        final restoredSnapshot = StoryGenerationRunSnapshot.fromJson(payload);
        _snapshotsBySceneScope[sceneScopeId] = restoredSnapshot;
        _directorFeedbackBySceneScope[sceneScopeId] = [
          for (final message in restoredSnapshot.messages)
            if (message.kind == StoryGenerationRunMessageKind.authorFeedback &&
                message.body.trim().isNotEmpty)
              message.body.trim(),
        ];
      }
    }

    _mutationVersion += 1;
    _snapshot = _idleSnapshotForCurrentScene();
    _readyFuture = _restoreCurrentScene();
    unawaited(_readyFuture);
    notifyListeners();
  }

  Future<void> waitUntilReady() async {
    while (true) {
      final currentReadyFuture = _readyFuture;
      await currentReadyFuture;
      if (identical(currentReadyFuture, _readyFuture)) {
        return;
      }
    }
  }

  void _handleProjectDeleted(ProjectDeletedEvent event) {
    final sceneScopePrefix = '${event.projectId}::';
    _mutationVersion += 1;
    _snapshotsBySceneScope.removeWhere(
      (key, _) => key == event.projectId || key.startsWith(sceneScopePrefix),
    );
    _directorFeedbackBySceneScope.removeWhere(
      (key, _) => key == event.projectId || key.startsWith(sceneScopePrefix),
    );
    if (_activeRunSceneScopeId == event.projectId ||
        (_activeRunSceneScopeId?.startsWith(sceneScopePrefix) ?? false)) {
      _activeRunToken = null;
      _activeRunSceneScopeId = null;
      _runToken += 1;
    }
    unawaited(_storage.clearProject(event.projectId));
  }

  Future<void> runCurrentScene({bool forceFailure = false}) async {
    await _generationStore.waitUntilReady();
    await _authorFeedbackStore?.waitUntilReady();
    final runToken = _beginRun();
    final runSceneScopeId = _activeSceneScopeId;
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
            title: '运行开始',
            body: 'AI 已开始按当前章节资料试写；生成内容会先作为候选记录，等待作者确认。',
            kind: StoryGenerationRunMessageKind.status,
          ),
          ..._revisionRequestMessages(revisionRequests),
        ],
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
        ),
      );
      _finishRun(runToken);
      return;
    }

    try {
      final orchestrator = _orchestratorFactory(_settingsStore);
      orchestrator.isRunCancelled = () =>
          !_isCurrentRun(runToken, runSceneScopeId);
      final output = await orchestrator.runScene(
        brief,
        onStatus: (message) {
          if (!_isCurrentRun(runToken, runSceneScopeId)) {
            return;
          }
          _queueSnapshotPersistence(
            _snapshot.copyWith(
              stageSummary: message,
              messages: [
                ..._snapshot.messages.where(
                  (entry) => entry.kind != StoryGenerationRunMessageKind.status,
                ),
                StoryGenerationRunMessage(
                  title: '进行中',
                  body: message,
                  kind: StoryGenerationRunMessageKind.status,
                ),
              ],
            ),
          );
        },
      );
      await _waitForQueuedSnapshotPersistence();
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
        ),
      );
      _finishRun(runToken);
    }
  }

  Future<bool> cancelCurrentRun() async {
    if (_snapshot.status != StoryGenerationRunStatus.running ||
        _activeRunToken == null ||
        _activeRunSceneScopeId != _activeSceneScopeId) {
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
    _activeRunToken = null;
    _activeRunSceneScopeId = null;
    return true;
  }

  Future<void> sendDirectorFeedback(String feedback) async {
    final trimmed = feedback.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final feedbacks = List<String>.from(
      _directorFeedbackBySceneScope[_activeSceneScopeId] ?? const <String>[],
    )..add(trimmed);
    _directorFeedbackBySceneScope[_activeSceneScopeId] = feedbacks;
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
    if (nextSceneScopeId == _activeSceneScopeId) {
      return;
    }
    if (_snapshot.status == StoryGenerationRunStatus.running &&
        _activeRunSceneScopeId == _activeSceneScopeId) {
      unawaited(cancelCurrentRun());
    }
    _mutationVersion += 1;
    _activeSceneScopeId = nextSceneScopeId;
    _snapshot = _idleSnapshotForCurrentScene();
    _readyFuture = _restoreCurrentScene();
    unawaited(_readyFuture);
    notifyListeners();
  }

  int _beginRun() {
    _runToken += 1;
    _activeRunToken = _runToken;
    _activeRunSceneScopeId = _activeSceneScopeId;
    return _runToken;
  }

  bool _isCurrentRun(int runToken, String sceneScopeId) {
    return _activeRunToken == runToken &&
        _activeRunSceneScopeId == sceneScopeId &&
        _activeSceneScopeId == sceneScopeId;
  }

  void _finishRun(int runToken) {
    if (_activeRunToken != runToken) {
      return;
    }
    _activeRunToken = null;
    _activeRunSceneScopeId = null;
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
    unawaited(_projectDeletedSubscription?.cancel());
    _projectDeletedSubscription = null;
    unawaited(_sceneChangedSubscription?.cancel());
    _sceneChangedSubscription = null;
    unawaited(_projectScopeChangedSubscription?.cancel());
    _projectScopeChangedSubscription = null;
    super.dispose();
  }

  void _notifySnapshotListeners() {
    notifyListeners();
  }
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
