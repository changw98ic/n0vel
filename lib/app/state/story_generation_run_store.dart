import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/author_feedback/data/author_feedback_store.dart';
import '../../features/author_feedback/domain/author_feedback_models.dart';
import '../../features/story_generation/data/chapter_generation_orchestrator.dart';
import '../../features/story_generation/data/scene_context_assembler.dart';
import '../../features/story_generation/data/story_generation_models.dart';
import 'app_scene_context_store.dart';
import 'app_settings_store.dart';
import 'app_storage_clone.dart';
import 'app_workspace_store.dart';
import 'story_generation_run_storage.dart';
import 'story_generation_store.dart';
import 'story_outline_store.dart';

enum StoryGenerationRunStatus { idle, running, completed, failed, cancelled }

enum StoryGenerationRunMessageKind {
  status,
  director,
  roleTurn,
  beat,
  editorial,
  review,
  authorFeedback,
  error,
}

class StoryGenerationRunParticipant {
  const StoryGenerationRunParticipant({
    required this.id,
    required this.name,
    required this.role,
    required this.summary,
    required this.statusSummary,
  });

  final String id;
  final String name;
  final String role;
  final String summary;
  final String statusSummary;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'summary': summary,
      'statusSummary': statusSummary,
    };
  }

  static StoryGenerationRunParticipant fromJson(Map<String, Object?> json) {
    return StoryGenerationRunParticipant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      statusSummary: json['statusSummary']?.toString() ?? '',
    );
  }
}

class StoryGenerationRunMessage {
  const StoryGenerationRunMessage({
    required this.title,
    required this.body,
    required this.kind,
    this.participantId,
  });

  final String title;
  final String body;
  final StoryGenerationRunMessageKind kind;
  final String? participantId;

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'body': body,
      'kind': kind.name,
      'participantId': participantId,
    };
  }

  static StoryGenerationRunMessage fromJson(Map<String, Object?> json) {
    final kindName = json['kind']?.toString() ?? '';
    final kind = StoryGenerationRunMessageKind.values.firstWhere(
      (candidate) => candidate.name == kindName,
      orElse: () => StoryGenerationRunMessageKind.status,
    );
    return StoryGenerationRunMessage(
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      kind: kind,
      participantId: json['participantId']?.toString(),
    );
  }
}

class StoryGenerationRunSnapshot {
  const StoryGenerationRunSnapshot({
    required this.status,
    required this.sceneId,
    required this.sceneLabel,
    required this.headline,
    required this.summary,
    required this.stageSummary,
    this.turnLabel = '',
    this.errorDetail = '',
    this.participants = const [],
    this.messages = const [],
  });

  final StoryGenerationRunStatus status;
  final String sceneId;
  final String sceneLabel;
  final String headline;
  final String summary;
  final String stageSummary;
  final String turnLabel;
  final String errorDetail;
  final List<StoryGenerationRunParticipant> participants;
  final List<StoryGenerationRunMessage> messages;

  bool get hasRun => status != StoryGenerationRunStatus.idle;

  Map<String, Object?> toJson() {
    return {
      'status': status.name,
      'sceneId': sceneId,
      'sceneLabel': sceneLabel,
      'headline': headline,
      'summary': summary,
      'stageSummary': stageSummary,
      'turnLabel': turnLabel,
      'errorDetail': errorDetail,
      'participants': [
        for (final participant in participants) participant.toJson(),
      ],
      'messages': [for (final message in messages) message.toJson()],
    };
  }

  static StoryGenerationRunSnapshot fromJson(Map<String, Object?> json) {
    final statusName = json['status']?.toString() ?? '';
    final status = StoryGenerationRunStatus.values.firstWhere(
      (candidate) => candidate.name == statusName,
      orElse: () => StoryGenerationRunStatus.idle,
    );
    return StoryGenerationRunSnapshot(
      status: status,
      sceneId: json['sceneId']?.toString() ?? '',
      sceneLabel: json['sceneLabel']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      stageSummary: json['stageSummary']?.toString() ?? '',
      turnLabel: json['turnLabel']?.toString() ?? '',
      errorDetail: json['errorDetail']?.toString() ?? '',
      participants: [
        for (final raw in (json['participants'] as List<Object?>? ?? const []))
          if (raw is Map)
            StoryGenerationRunParticipant.fromJson(_asStringObjectMap(raw)),
      ],
      messages: [
        for (final raw in (json['messages'] as List<Object?>? ?? const []))
          if (raw is Map)
            StoryGenerationRunMessage.fromJson(_asStringObjectMap(raw)),
      ],
    );
  }

  StoryGenerationRunSnapshot copyWith({
    StoryGenerationRunStatus? status,
    String? sceneId,
    String? sceneLabel,
    String? headline,
    String? summary,
    String? stageSummary,
    String? turnLabel,
    String? errorDetail,
    List<StoryGenerationRunParticipant>? participants,
    List<StoryGenerationRunMessage>? messages,
  }) {
    return StoryGenerationRunSnapshot(
      status: status ?? this.status,
      sceneId: sceneId ?? this.sceneId,
      sceneLabel: sceneLabel ?? this.sceneLabel,
      headline: headline ?? this.headline,
      summary: summary ?? this.summary,
      stageSummary: stageSummary ?? this.stageSummary,
      turnLabel: turnLabel ?? this.turnLabel,
      errorDetail: errorDetail ?? this.errorDetail,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
    );
  }
}

class StoryGenerationRunStore extends ChangeNotifier {
  StoryGenerationRunStore({
    required AppSettingsStore settingsStore,
    required AppWorkspaceStore workspaceStore,
    required StoryGenerationStore generationStore,
    AppSceneContextStore? sceneContextStore,
    StoryOutlineStore? outlineStore,
    AuthorFeedbackStore? authorFeedbackStore,
    StoryGenerationRunStorage? storage,
    SceneContextAssembler? sceneContextAssembler,
    ChapterGenerationOrchestrator Function(AppSettingsStore settingsStore)?
    orchestratorFactory,
  }) : _settingsStore = settingsStore,
       _workspaceStore = workspaceStore,
       _generationStore = generationStore,
       _sceneContextStore = sceneContextStore,
       _outlineStore = outlineStore,
       _authorFeedbackStore = authorFeedbackStore,
       _storage =
           storage ??
           debugStorageOverride ??
           createDefaultStoryGenerationRunStorage(),
       _sceneContextAssembler =
           sceneContextAssembler ?? SceneContextAssembler(),
       _orchestratorFactory =
           orchestratorFactory ??
           debugOrchestratorFactoryOverride ??
           ((settingsStore) =>
               ChapterGenerationOrchestrator(settingsStore: settingsStore)) {
    _activeSceneScopeId = _workspaceStore.currentSceneScopeId;
    _snapshot = _idleSnapshotForCurrentScene();
    _workspaceStore.addListener(_handleWorkspaceChanged);
    _readyFuture = _restoreCurrentScene();
    unawaited(_readyFuture);
  }

  static StoryGenerationRunStorage? debugStorageOverride;
  static ChapterGenerationOrchestrator Function(AppSettingsStore settingsStore)?
  debugOrchestratorFactoryOverride;

  final AppSettingsStore _settingsStore;
  final AppWorkspaceStore _workspaceStore;
  // ignore: unused_field
  final StoryGenerationStore _generationStore;
  // ignore: unused_field
  final AppSceneContextStore? _sceneContextStore;
  // ignore: unused_field
  final StoryOutlineStore? _outlineStore;
  final AuthorFeedbackStore? _authorFeedbackStore;
  final StoryGenerationRunStorage _storage;
  // ignore: unused_field
  final SceneContextAssembler _sceneContextAssembler;
  final ChapterGenerationOrchestrator Function(AppSettingsStore settingsStore)
  _orchestratorFactory;
  final Map<String, StoryGenerationRunSnapshot> _snapshotsBySceneScope =
      <String, StoryGenerationRunSnapshot>{};
  final Map<String, List<String>> _directorFeedbackBySceneScope =
      <String, List<String>>{};
  late String _activeSceneScopeId;
  late StoryGenerationRunSnapshot _snapshot;
  Future<void> _readyFuture = Future<void>.value();
  int _mutationVersion = 0;
  int _runToken = 0;
  int? _activeRunToken;
  String? _activeRunSceneScopeId;

  StoryGenerationRunSnapshot get snapshot => _snapshot;
  String get activeSceneScopeId => _activeSceneScopeId;
  Future<void> get ready => _readyFuture;

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
      chapterId: currentScene.chapterLabel,
      chapterTitle: currentScene.chapterLabel,
      sceneId: currentScene.id,
      sceneTitle: currentScene.title,
      sceneSummary: currentScene.summary,
      metadata: _runtimeMetadata(revisionRequests: revisionRequests),
    );
    final baseParticipants = _participantsForBrief(brief);
    _setSnapshot(
      StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.running,
        sceneId: brief.sceneId,
        sceneLabel: _sceneLabel(),
        headline: '角色编排进行中',
        summary: '正在为当前场景生成 director、角色回合、裁定与审查。',
        stageSummary: '正在准备场景任务卡',
        participants: baseParticipants,
        messages: [
          const StoryGenerationRunMessage(
            title: '运行开始',
            body: '新 roleplay runtime 已接管当前场景。',
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
      _setSnapshot(
        _snapshot.copyWith(
          status: StoryGenerationRunStatus.failed,
          headline: '角色编排失败',
          summary: '当前场景在进入正式正文前被显式中止。',
          stageSummary: '失败',
          errorDetail: 'force-failure',
          messages: [
            ..._snapshot.messages,
            const StoryGenerationRunMessage(
              title: '运行失败摘要',
              body: '当前场景的角色编排在测试入口被中止。',
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
      final output = await orchestrator.runScene(
        brief,
        onStatus: (message) {
          if (!_isCurrentRun(runToken, runSceneScopeId)) {
            return;
          }
          _setSnapshot(
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
      if (!_isCurrentRun(runToken, runSceneScopeId)) {
        return;
      }
      _recordSceneState(
        brief: brief,
        status: StorySceneGenerationStatus.passed,
        reviewStatus: StoryReviewStatus.passed,
      );
      _setSnapshot(_snapshotFromOutput(output));
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
      _setSnapshot(
        StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.failed,
          sceneId: brief.sceneId,
          sceneLabel: _sceneLabel(),
          headline: '角色编排失败',
          summary: '当前场景没有通过新的 roleplay runtime。',
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

  bool cancelCurrentRun() {
    if (_snapshot.status != StoryGenerationRunStatus.running ||
        _activeRunToken == null ||
        _activeRunSceneScopeId != _activeSceneScopeId) {
      return false;
    }
    _recordSceneStateForCurrentRun(
      status: StorySceneGenerationStatus.blocked,
      reviewStatus: StoryReviewStatus.failed,
    );
    _setSnapshot(
      _snapshot.copyWith(
        status: StoryGenerationRunStatus.cancelled,
        headline: '角色编排已取消',
        summary: '当前场景的 roleplay 运行已停止，已保留取消前记录的消息与状态。',
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

  void sendDirectorFeedback(String feedback) {
    final trimmed = feedback.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final feedbacks = List<String>.from(
      _directorFeedbackBySceneScope[_activeSceneScopeId] ?? const <String>[],
    )..add(trimmed);
    _directorFeedbackBySceneScope[_activeSceneScopeId] = feedbacks;
    _setSnapshot(
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

  void _handleWorkspaceChanged() {
    final nextSceneScopeId = _workspaceStore.currentSceneScopeId;
    if (nextSceneScopeId == _activeSceneScopeId) {
      return;
    }
    if (_snapshot.status == StoryGenerationRunStatus.running &&
        _activeRunSceneScopeId == _activeSceneScopeId) {
      cancelCurrentRun();
    }
    _mutationVersion += 1;
    _activeSceneScopeId = nextSceneScopeId;
    _snapshot = _idleSnapshotForCurrentScene();
    _readyFuture = _restoreCurrentScene();
    unawaited(_readyFuture);
    notifyListeners();
  }

  StoryGenerationRunSnapshot _idleSnapshotForCurrentScene() {
    return StoryGenerationRunSnapshot(
      status: StoryGenerationRunStatus.idle,
      sceneId: _workspaceStore.currentScene.id,
      sceneLabel: _sceneLabel(),
      headline: '还没有角色编排记录',
      summary: '请先在当前场景发起一次新的 roleplay 运行。',
      stageSummary: '未开始',
    );
  }

  List<StoryGenerationRunParticipant> _participantsForBrief(SceneBrief brief) {
    return [
      const StoryGenerationRunParticipant(
        id: 'director',
        name: '导演',
        role: '固定编排代理',
        summary: '负责生成场景任务卡并调度动态角色。',
        statusSummary: '等待发放任务卡',
      ),
      for (final cast in brief.cast)
        StoryGenerationRunParticipant(
          id: cast.characterId,
          name: cast.name,
          role: cast.role,
          summary: cast.metadata['summary']?.toString() ?? cast.role,
          statusSummary: '等待进入角色回合',
        ),
    ];
  }

  StoryGenerationRunSnapshot _snapshotFromOutput(SceneRuntimeOutput output) {
    final roleTurnsByCharacter = {
      for (final turn in output.roleTurns) turn.characterId: turn,
    };
    final participants = [
      StoryGenerationRunParticipant(
        id: 'director',
        name: '导演',
        role: '固定编排代理',
        summary: output.director.taskCard?.sceneGoal ?? output.director.text,
        statusSummary: '任务卡已生成',
      ),
      for (final member in output.resolvedCast)
        StoryGenerationRunParticipant(
          id: member.characterId,
          name: member.name,
          role: member.role,
          summary:
              roleTurnsByCharacter[member.characterId]?.intent ?? member.role,
          statusSummary:
              roleTurnsByCharacter[member.characterId]?.proposedStateChange ??
              '已完成当前角色回合',
        ),
    ];
    return StoryGenerationRunSnapshot(
      status: StoryGenerationRunStatus.completed,
      sceneId: output.brief.sceneId,
      sceneLabel: _sceneLabel(),
      headline: '角色编排已完成',
      summary:
          '${output.resolvedCast.length} 名动态角色完成当前场景，审查结果为 ${output.review.decision.name}。',
      stageSummary: output.review.feedback.isEmpty
          ? '审查通过'
          : output.review.feedback,
      turnLabel: output.roleTurns.isEmpty
          ? '第 0 回合'
          : '第 ${output.sceneState?.turnIndex ?? 1} 回合',
      participants: participants,
      messages: [
        ..._authorFeedbackMessages(),
        StoryGenerationRunMessage(
          title: '导演任务卡',
          body: output.director.text,
          kind: StoryGenerationRunMessageKind.director,
          participantId: 'director',
        ),
        for (final turn in output.roleTurns)
          StoryGenerationRunMessage(
            title:
                '${_participantName(output.resolvedCast, turn.characterId)} · 角色回合',
            body: turn.toLegacyRoleText(),
            kind: StoryGenerationRunMessageKind.roleTurn,
            participantId: turn.characterId,
          ),
        for (final beat in output.resolvedBeats)
          StoryGenerationRunMessage(
            title: '拍 ${beat.beatIndex} · 裁定',
            body: beat.actionAccepted
                ? [
                    if (beat.acceptedAction.trim().isNotEmpty)
                      beat.acceptedAction.trim(),
                    if (beat.acceptedSpeech.trim().isNotEmpty)
                      beat.acceptedSpeech.trim(),
                    if (beat.stateDelta.isNotEmpty)
                      '状态变化：${beat.stateDelta.join(' / ')}',
                  ].join('\n')
                : beat.rejectionReason,
            kind: StoryGenerationRunMessageKind.beat,
            participantId: beat.actorId,
          ),
        if (output.editorialDraft != null)
          StoryGenerationRunMessage(
            title: '编辑稿',
            body: output.editorialDraft!.text,
            kind: StoryGenerationRunMessageKind.editorial,
          ),
        StoryGenerationRunMessage(
          title: '审查结果',
          body: output.review.feedback.isEmpty
              ? output.review.decision.name
              : output.review.feedback,
          kind: StoryGenerationRunMessageKind.review,
        ),
      ],
    );
  }

  List<StoryGenerationRunMessage> _authorFeedbackMessages() {
    return [
      for (final feedback
          in _directorFeedbackBySceneScope[_activeSceneScopeId] ??
              const <String>[])
        StoryGenerationRunMessage(
          title: '作者反馈',
          body: feedback,
          kind: StoryGenerationRunMessageKind.authorFeedback,
        ),
    ];
  }

  void _recordSceneState({
    required SceneBrief brief,
    required StorySceneGenerationStatus status,
    required StoryReviewStatus reviewStatus,
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
  }

  void _recordSceneStateForCurrentRun({
    required StorySceneGenerationStatus status,
    required StoryReviewStatus reviewStatus,
  }) {
    final currentScene = _workspaceStore.currentScene;
    _recordSceneState(
      brief: SceneBrief(
        chapterId: currentScene.chapterLabel,
        chapterTitle: currentScene.chapterLabel,
        sceneId: currentScene.id,
        sceneTitle: currentScene.title,
        sceneSummary: currentScene.summary,
        metadata: _runtimeMetadata(
          revisionRequests: _activeRevisionRequestsForCurrentScene(
            chapterId: currentScene.chapterLabel,
            sceneId: currentScene.id,
          ),
        ),
      ),
      status: status,
      reviewStatus: reviewStatus,
    );
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

  List<AuthorFeedbackItem> _activeRevisionRequestsForCurrentScene({
    required String chapterId,
    required String sceneId,
  }) {
    return _authorFeedbackStore?.activeRevisionRequestsForScene(
          chapterId: chapterId,
          sceneId: sceneId,
        ) ??
        const <AuthorFeedbackItem>[];
  }

  Map<String, Object?> _runtimeMetadata({
    List<AuthorFeedbackItem> revisionRequests = const [],
  }) {
    final localOnly = !_settingsStore.hasReadyConfiguration;
    final revisionNotes = [
      for (final request in revisionRequests)
        if (request.note.trim().isNotEmpty) request.note.trim(),
    ];
    return {
      'structuredRoleplayPipeline': true,
      'maxStructuredRounds': 2,
      if (revisionNotes.isNotEmpty)
        'authorRevisionRequests': List<String>.unmodifiable(revisionNotes),
      if (localOnly) 'localDirectorOnly': true,
      if (localOnly) 'localStructuredRoleplayOnly': true,
      if (localOnly) 'localEditorialOnly': true,
      if (localOnly) 'localReviewOnly': true,
    };
  }

  List<StoryGenerationRunMessage> _revisionRequestMessages(
    List<AuthorFeedbackItem> revisionRequests,
  ) {
    return [
      for (final request in revisionRequests)
        StoryGenerationRunMessage(
          title: '已纳入修订请求',
          body: request.note,
          kind: StoryGenerationRunMessageKind.authorFeedback,
        ),
    ];
  }

  String _sceneLabel() {
    return '${_workspaceStore.currentProject.title} / ${_workspaceStore.currentScene.displayLocation}';
  }

  Future<void> _restoreCurrentScene() async {
    final restoreVersion = _mutationVersion;
    final sceneScopeId = _activeSceneScopeId;
    final restored = await _storage.load(sceneScopeId: sceneScopeId);
    if (restoreVersion != _mutationVersion || restored == null) {
      return;
    }
    final snapshot = StoryGenerationRunSnapshot.fromJson({
      for (final entry in restored.entries)
        entry.key: cloneStorageValue(entry.value),
    });
    _snapshot = snapshot;
    _snapshotsBySceneScope[sceneScopeId] = snapshot;
    _syncFeedbackCache(snapshot);
    notifyListeners();
  }

  Future<void> _persistCurrentScene() {
    return _storage.save({
      ..._snapshot.toJson(),
      'sceneScopeId': _activeSceneScopeId,
    }, sceneScopeId: _activeSceneScopeId);
  }

  void _syncFeedbackCache(StoryGenerationRunSnapshot snapshot) {
    _directorFeedbackBySceneScope[_activeSceneScopeId] = [
      for (final message in snapshot.messages)
        if (message.kind == StoryGenerationRunMessageKind.authorFeedback &&
            message.body.trim().isNotEmpty)
          message.body.trim(),
    ];
  }

  String _participantName(
    List<ResolvedSceneCastMember> cast,
    String characterId,
  ) {
    for (final member in cast) {
      if (member.characterId == characterId) {
        return member.name;
      }
    }
    return characterId;
  }

  void _setSnapshot(StoryGenerationRunSnapshot next) {
    _mutationVersion += 1;
    _snapshot = next;
    _snapshotsBySceneScope[_activeSceneScopeId] = next;
    _syncFeedbackCache(next);
    unawaited(_persistCurrentScene());
    notifyListeners();
  }

  @override
  void dispose() {
    _workspaceStore.removeListener(_handleWorkspaceChanged);
    super.dispose();
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
