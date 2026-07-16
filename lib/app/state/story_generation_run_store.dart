import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/author_feedback/data/author_feedback_store.dart';
import '../../features/author_feedback/domain/author_feedback_models.dart';
import '../../features/review_tasks/data/review_task_mapper.dart';
import '../../features/review_tasks/data/review_task_store.dart';
// Intentional: run store bridges app state to feature pipeline.
import '../../features/story_generation/data/pipeline_stage_runner_impl.dart';
import '../../features/story_generation/data/generation_commit_coordinator.dart';
import '../../features/story_generation/data/generation_ledger.dart';
import '../../features/story_generation/data/generation_ledger_candidate_finalizer.dart';
import '../../features/story_generation/data/generation_ledger_digest.dart';
import '../../features/story_generation/data/generation_ledger_models.dart';
import '../../features/story_generation/data/generation_outbox_worker.dart';
import '../../features/story_generation/data/generation_stage_checkpoint_codec.dart';
import '../../features/story_generation/data/generation_pipeline_config.dart';
import '../../features/story_generation/data/formal_evaluation_policy.dart';
import '../../features/story_generation/data/scene_context_assembler.dart';
import '../../features/story_generation/data/story_generation_models.dart';
import '../../features/story_generation/data/story_material_snapshot_builder.dart';
import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';
import 'app_store_listenable.dart';
import 'app_scene_context_store.dart';
import 'app_draft_store.dart';
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

typedef StoryGenerationLifecycleRunIdFactory =
    String Function(String sceneScopeId);

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
    StoryMaterialSnapshotBuilder? materialSnapshotBuilder,
    AppDraftStore? draftStore,
    GenerationLedgerSqliteStore? generationLedger,
    GenerationLedgerCandidateFinalizer? generationCandidateFinalizer,
    GenerationCommitCoordinator? generationCommitCoordinator,
    GenerationOutboxWorker? generationOutboxWorker,
    PipelineStageRunnerImpl Function(AppSettingsStore settingsStore)?
    orchestratorFactory,
    StoryGenerationLifecycleRunIdFactory? lifecycleRunIdFactory,
    this.allowLocalOnlyFallback = true,
    this.formalEvaluation = false,
  }) : _settingsStore = settingsStore,
       _workspaceStore = workspaceStore,
       _generationStore = generationStore,
       _sceneContextStore = sceneContextStore,
       _outlineStore = outlineStore,
       _authorFeedbackStore = authorFeedbackStore,
       _reviewTaskStore = reviewTaskStore,
       _materialSnapshotBuilder =
           materialSnapshotBuilder ?? const StoryMaterialSnapshotBuilder(),
       _draftStore = draftStore,
       _generationLedger = generationLedger,
       _generationCandidateFinalizer = generationCandidateFinalizer,
       _generationCommitCoordinator = generationCommitCoordinator,
       _generationOutboxWorker = generationOutboxWorker,
       _eventBus = eventBus,
       _storage = storage ?? createDefaultStoryGenerationRunStorage(),
       _lifecycleRunIdFactory = lifecycleRunIdFactory,
       _orchestratorFactory =
           orchestratorFactory ??
           ((settingsStore) {
             return PipelineStageRunnerImpl(
               settingsStore: settingsStore,
               pipelineConfig: GenerationPipelineConfig.fromWorkspace(
                 workspaceStore,
               ),
               roleplaySessionStore: roleplaySessionStore,
               characterMemoryStore: characterMemoryStore,
             );
           }) {
    if (formalEvaluation && allowLocalOnlyFallback) {
      throw ArgumentError('formal evaluation cannot allow local-only fallback');
    }
    _activeSceneScopeId = _workspaceStore.currentSceneScopeId;
    _snapshot = _idleSnapshotForCurrentScene();
    _projectDeletedSubscription = _eventBus?.listen<ProjectDeletedEvent>(
      _handleProjectDeleted,
    );
    _sceneChangedSubscription = _eventBus?.listen<SceneChangedEvent>(
      (e) => _handleSceneScopeChanged(e.sceneScopeId),
    );
    _projectScopeChangedSubscription = _eventBus
        ?.listen<ProjectScopeChangedEvent>(
          (e) => _handleSceneScopeChanged(e.sceneScopeId),
        );
    _readyFuture = _restoreCurrentScene();
    unawaited(_readyFuture);
  }

  final AppSettingsStore _settingsStore;
  final AppWorkspaceStore _workspaceStore;
  final StoryGenerationStore _generationStore;
  final AppSceneContextStore? _sceneContextStore;
  final StoryOutlineStore? _outlineStore;
  final AuthorFeedbackStore? _authorFeedbackStore;
  final ReviewTaskStore? _reviewTaskStore;
  final StoryMaterialSnapshotBuilder _materialSnapshotBuilder;
  final AppDraftStore? _draftStore;
  final GenerationLedgerSqliteStore? _generationLedger;
  final GenerationLedgerCandidateFinalizer? _generationCandidateFinalizer;
  final GenerationCommitCoordinator? _generationCommitCoordinator;
  final GenerationOutboxWorker? _generationOutboxWorker;
  final Set<Future<int>> _pendingOutboxDrains = <Future<int>>{};
  final AppEventBus? _eventBus;
  final StoryGenerationRunStorage _storage;
  final StoryGenerationLifecycleRunIdFactory? _lifecycleRunIdFactory;

  /// Allows the interactive app to use deterministic local generation when
  /// its provider configuration is not ready.
  ///
  /// A formal evaluation runtime disables this fallback after validating its
  /// frozen route so a newly released or purpose-built model identifier still
  /// exercises the real production pipeline.
  final bool allowLocalOnlyFallback;
  final bool formalEvaluation;
  final PipelineStageRunnerImpl Function(AppSettingsStore settingsStore)
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
  int? _editedTargetCandidateRevision;
  int? _editedTargetProseRevision;
  StreamSubscription<ProjectDeletedEvent>? _projectDeletedSubscription;
  StreamSubscription<SceneChangedEvent>? _sceneChangedSubscription;
  StreamSubscription<ProjectScopeChangedEvent>?
  _projectScopeChangedSubscription;

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

  Future<void> runCurrentScene({
    bool forceFailure = false,
    String? outlineOverride,
    String? rulesOverride,
  }) async {
    await _generationStore.waitUntilReady();
    await _authorFeedbackStore?.waitUntilReady();
    await _reviewTaskStore?.waitUntilReady();
    // A second click must join the already active scene run. In particular it
    // must not increment the token and cause the first provider request to be
    // treated as stale while a second request is dispatched.
    if (_activeRunToken != null &&
        _activeRunSceneScopeId == _activeSceneScopeId) {
      return;
    }
    // An explicit author edit always reuses the run's ledger namespace even
    // when a controlled/offline runner produced no stage checkpoint.  Treating
    // it as a new run violates the one-active-run-per-scene constraint and,
    // more importantly, would detach N+1 from its source candidate.
    final pendingEditedNamespace =
        _editedTargetCandidateRevision == null &&
            _generationLedger != null &&
            _snapshot.runId.isNotEmpty
        ? _generationLedger.loadUnfinalizedCandidateNamespace(
            runId: _snapshot.runId,
          )
        : null;
    if (pendingEditedNamespace != null) {
      _editedTargetCandidateRevision = pendingEditedNamespace.candidateRevision;
      _editedTargetProseRevision = pendingEditedNamespace.sourceProseRevision;
    }
    final continuingEditedCandidate = _editedTargetCandidateRevision != null;
    final resuming = continuingEditedCandidate || _canResumeSnapshot(_snapshot);
    final lifecycleRunId = resuming
        ? _snapshot.runId
        : _newLifecycleRunId(_activeSceneScopeId);
    final runToken = _beginRun();
    final runSceneScopeId = _activeSceneScopeId;
    final currentScene = _workspaceStore.currentScene;
    final revisionRequests = _activeRevisionRequestsForCurrentScene(
      chapterId: currentScene.chapterLabel,
      sceneId: currentScene.id,
    );
    final committedContinuityLedger = _committedContinuityLedgerBefore(
      currentScene.id,
    );
    final brief = _materialSnapshotBuilder.buildSceneBrief(
      workspaceStore: _workspaceStore,
      outlineStore: _outlineStore,
      sceneSummaryOverride: outlineOverride,
      runtimeMetadata: _runtimeMetadata(
        revisionRequests: revisionRequests,
        rulesOverride: rulesOverride,
        continuityLedger: committedContinuityLedger,
      ),
      formalExecution: formalEvaluation,
    );
    final baseParticipants = _participantsForBrief(brief);
    final materials = _materialsWithContinuityLedger(
      _materialSnapshotBuilder.build(
        workspaceStore: _workspaceStore,
        sceneContextStore: _sceneContextStore,
        outlineStore: _outlineStore,
        reviewTaskStore: _reviewTaskStore,
      ),
      brief.metadata['continuityLedger'],
    );
    await _setSnapshot(
      StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.running,
        phase: StoryGenerationRunPhase.draft,
        sceneId: brief.sceneId,
        sceneLabel: _sceneLabel(),
        headline: resuming ? 'AI 正在恢复本章' : 'AI 正在准备本章',
        summary: '正在整理章节目标、出场人物和改稿检查；正文不会被直接覆盖。',
        stageSummary: resuming ? '正在校验并恢复阶段记录' : '正在准备候选稿',
        runId: lifecycleRunId,
        checkpoints: resuming ? _snapshot.checkpoints : const [],
        participants: baseParticipants,
        messages: [
          const StoryGenerationRunMessage(
            title: '进行中',
            body: 'AI 已开始按当前章节资料试写；生成内容会先作为候选记录，等待作者确认。',
            kind: StoryGenerationRunMessageKind.status,
          ),
          ..._revisionRequestMessages(revisionRequests),
        ],
      ),
    );
    await _recordSceneState(
      brief: brief,
      status: StorySceneGenerationStatus.roleRunning,
      reviewStatus: StoryReviewStatus.pending,
    );
    if (forceFailure) {
      if (!_isCurrentRun(runToken, runSceneScopeId)) {
        return;
      }
      await _recordSceneState(
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
      GenerationRunCapture? ledgerCapture;
      final ledgerFinalizer = _generationCandidateFinalizer;
      if (ledgerFinalizer != null) {
        final baseDraft = _draftStore == null
            ? ''
            : await _draftStore.readTextForScope(runSceneScopeId);
        ledgerCapture = ledgerFinalizer.startRun(
          runId: lifecycleRunId,
          requestId: lifecycleRunId,
          projectId: brief.projectId ?? '',
          chapterId: brief.chapterId,
          sceneId: brief.sceneId,
          sceneScopeId: runSceneScopeId,
          baseDraft: baseDraft,
          brief: brief,
          materials: materials,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
      final orchestrator = _orchestratorFactory(_settingsStore);
      orchestrator.generationLedger = _generationLedger;
      orchestrator.deferFinalizationCheckpointToCandidateLedger =
          ledgerFinalizer != null;
      orchestrator.isRunCancelled = () =>
          !_isCurrentRun(runToken, runSceneScopeId);
      orchestrator.checkpointRunId = lifecycleRunId;
      orchestrator.checkpointProseRevision = _editedTargetProseRevision ?? 0;
      final ledger = _generationLedger;
      if (ledger != null && ledgerCapture != null) {
        // V10 ledger is the recovery authority. The presentation snapshot may
        // still cache stage labels, but never decides which provider work can
        // be skipped after a restart.
        orchestrator.checkpointProvenance = GenerationCheckpointProvenance(
          baseDraftDigest: _checkpointDigest(ledgerCapture.baseDraftHash),
          materialDigest: _checkpointDigest(ledgerCapture.materialDigest),
          promptDigest: _checkpointDigest(
            GenerationLedgerDigest.object({
              'pipelinePromptContract': 'pipeline-prompts-v10',
              // Stage input DTOs are intentionally compact, so the immutable
              // run capture must bind the brief as well as provider language.
              // A changed outline/target can never replay a prior prefix.
              'runInputDigest': ledgerCapture.inputDigest,
              'promptLanguage': _settingsStore.promptLanguage.name,
            }),
          ),
          modelDigest: _checkpointDigest(
            GenerationLedgerDigest.text(
              'prompt-language:${_settingsStore.promptLanguage.name}',
            ),
          ),
        );
        orchestrator.checkpointStore = GenerationLedgerCheckpointStore(
          ledger: ledger,
          provenance: orchestrator.checkpointProvenance!,
        );
      } else {
        orchestrator.checkpointStore = _SnapshotPipelineCheckpointStore(
          owner: this,
          runId: lifecycleRunId,
          sceneScopeId: runSceneScopeId,
        );
      }
      final output = await orchestrator.runScene(brief, materials: materials);
      if (!_isCurrentRun(runToken, runSceneScopeId)) {
        return;
      }
      if (output.prose.text.trim().isEmpty) {
        throw StateError(
          'Story pipeline completed without candidate prose; refusing to '
          'claim that a recoverable candidate was retained.',
        );
      }
      DurableCandidateReference? durableCandidate;
      if (ledgerFinalizer != null) {
        durableCandidate = ledgerFinalizer.finalize(
          runId: lifecycleRunId,
          output: output,
          capture: ledgerCapture!,
          nowMs: DateTime.now().millisecondsSinceEpoch,
          targetCandidateRevision: _editedTargetCandidateRevision,
        );
        _editedTargetCandidateRevision = null;
        _editedTargetProseRevision = null;
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
      await _recordSceneState(
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
      await _setSnapshot(
        _snapshotFromOutput(output, durableCandidate: durableCandidate),
      );
      _persistReviewTasks(output.review, brief, runSceneScopeId);
      _finishRun(runToken);
    } catch (error) {
      if (!_isCurrentRun(runToken, runSceneScopeId)) {
        return;
      }
      final terminal = _terminalSnapshotForPipelineError(error);
      final ledger = _generationLedger;
      if (ledger != null) {
        try {
          ledger.markRunTerminal(
            runId: lifecycleRunId,
            status: terminal.status.name,
            phase: terminal.phase.name,
            blockedStage: _blockedStageFor(terminal.status),
            errorCode: _terminalErrorCode(error),
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          );
        } on GenerationLedgerInvariantViolation {
          // Preserve the original pipeline failure. Recovery bookkeeping may
          // legitimately lose a race with an already-terminal run and must
          // never replace the actionable provider/pipeline error.
        }
      }
      await _recordSceneState(
        brief: brief,
        status: StorySceneGenerationStatus.blocked,
        reviewStatus: StoryReviewStatus.failed,
      );
      await _setSnapshot(
        _snapshot.copyWith(
          status: terminal.status,
          phase: terminal.phase,
          sceneId: brief.sceneId,
          sceneLabel: _sceneLabel(),
          headline: terminal.headline,
          summary: terminal.summary,
          stageSummary: terminal.stageSummary,
          errorDetail: error.toString(),
          messages: [
            ..._authorFeedbackMessages(),
            StoryGenerationRunMessage(
              title: terminal.messageTitle,
              body: terminal.messageBody,
              kind: StoryGenerationRunMessageKind.error,
            ),
          ],
        ),
      );
      _finishRun(runToken);
    }
  }

  Future<void> beginEditedCandidateRevision(String prose) async {
    final ledger = _generationLedger;
    final sourceRevision = _snapshot.candidateRevision;
    if (ledger == null || sourceRevision == null || _snapshot.runId.isEmpty) {
      throw StateError('no durable candidate is available for author editing');
    }
    final namespace = ledger.createEditedWorkingRevision(
      runId: _snapshot.runId,
      sourceCandidateRevision: sourceRevision,
      prose: prose,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    _editedTargetCandidateRevision = namespace.candidateRevision;
    _editedTargetProseRevision = namespace.sourceProseRevision;
    await _setSnapshot(
      _snapshot.copyWith(
        status: StoryGenerationRunStatus.running,
        phase: StoryGenerationRunPhase.candidate,
        candidateProse: prose,
        clearCandidateRevision: true,
        candidateHash: '',
        candidateFinalProseHash: '',
        candidateDeterministicGateEvidenceHash: '',
        candidateFinalCouncilEvidenceHash: '',
        candidateQualityEvidenceHash: '',
        candidatePendingWriteSetHash: '',
        headline: '作者改稿待复审',
        summary: '已建立新的候选命名空间，等待终审与质量门。',
        stageSummary: '等待重新验证',
      ),
    );
  }

  Future<bool> cancelCurrentRun() async {
    final activeRun =
        _snapshot.status == StoryGenerationRunStatus.running &&
        _activeRunToken != null &&
        _activeRunSceneScopeId == _activeSceneScopeId;
    final blockedRun = switch (_snapshot.status) {
      StoryGenerationRunStatus.preliminaryReviewBlocked ||
      StoryGenerationRunStatus.finalReviewBlocked ||
      StoryGenerationRunStatus.qualityBlocked ||
      StoryGenerationRunStatus.budgetBlocked ||
      StoryGenerationRunStatus.conflict => true,
      StoryGenerationRunStatus.idle ||
      StoryGenerationRunStatus.running ||
      StoryGenerationRunStatus.completed ||
      StoryGenerationRunStatus.failed ||
      StoryGenerationRunStatus.cancelled => false,
    };
    if (!activeRun && !blockedRun) {
      return false;
    }
    await _recordSceneStateForCurrentRun(
      status: StorySceneGenerationStatus.blocked,
      reviewStatus: StoryReviewStatus.failed,
      terminalReason: 'cancelled',
    );
    final runId = _snapshot.runId;
    if (_generationLedger != null && runId.isNotEmpty) {
      _generationLedger.markRunTerminal(
        runId: runId,
        status: 'cancelled',
        phase: 'cancel',
        errorCode: 'cancelled',
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
    await _setSnapshot(
      _snapshot.copyWith(
        status: StoryGenerationRunStatus.cancelled,
        phase: StoryGenerationRunPhase.cancel,
        headline: 'AI 试写已取消',
        summary: activeRun
            ? '这次 AI 试写已停止，已保留停止前的记录。'
            : '作者已取消这条被阻断的运行；没有候选或权威写入会被提交。',
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

  /// Commits the currently displayed durable proof.  Snapshot prose is never
  /// used as commit input; every hash comes from the proof pointer persisted
  /// at finalization time.
  Future<GenerationCommitResult> acceptCurrentCandidate({
    String? acceptIdempotencyKey,
    bool scheduleOutboxDrain = true,
  }) async {
    final coordinator = _generationCommitCoordinator;
    final candidate = _snapshot;
    if (coordinator == null || !candidate.hasDurableCandidateProof) {
      throw StateError(
        'No durable candidate proof is available for author acceptance.',
      );
    }
    final ledger = _generationLedger;
    if (ledger == null ||
        !ledger.isRunBoundToGenerationBundle(
          runId: candidate.runId,
          generationBundleHash: candidate.candidateGenerationBundleHash,
        )) {
      throw StateError(
        'Candidate generation bundle evidence is unavailable or mismatched.',
      );
    }
    final result = coordinator.accept(
      GenerationCommitRequest(
        acceptIdempotencyKey:
            acceptIdempotencyKey ??
            'accept:${candidate.runId}:${candidate.candidateRevision}',
        runId: candidate.runId,
        candidateRevision: candidate.candidateRevision!,
        projectId: _workspaceStore.currentProjectId,
        sceneScopeId: _activeSceneScopeId,
        candidateHash: candidate.candidateHash,
        expectedBaseDraftHash: candidate.candidateBaseDraftHash,
        expectedMaterialDigest: candidate.candidateMaterialDigest,
        expectedInputDigest: candidate.candidateInputDigest,
        expectedFinalProseHash: candidate.candidateFinalProseHash,
        expectedDeterministicGateEvidenceHash:
            candidate.candidateDeterministicGateEvidenceHash,
        expectedFinalCouncilEvidenceHash:
            candidate.candidateFinalCouncilEvidenceHash,
        expectedQualityEvidenceHash: candidate.candidateQualityEvidenceHash,
        expectedPendingWriteSetHash: candidate.candidatePendingWriteSetHash,
        committedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _setSnapshot(
      _snapshot.copyWith(
        phase: StoryGenerationRunPhase.commit,
        headline: '候选稿已采纳',
        summary: '作者已采纳候选稿；正文和已批准的生成写入已通过同一事务提交。',
        stageSummary: '已提交',
      ),
    );
    // Derived indexing is receipt-bound and retryable. A worker failure must
    // never compensate or hide the already committed author transaction.
    final outboxWorker = _generationOutboxWorker;
    if (outboxWorker != null && scheduleOutboxDrain) {
      late final Future<int> drain;
      drain = outboxWorker.drainSafely(
        leaseOwner: 'run-store:${candidate.runId}',
      );
      _pendingOutboxDrains.add(drain);
      unawaited(
        drain.whenComplete(() {
          _pendingOutboxDrains.remove(drain);
        }),
      );
    }
    return result;
  }

  /// Test/shutdown coordination point for best-effort derived indexing.
  /// Author acceptance never depends on this work, but owners that are about
  /// to close the shared database can await it to avoid abandoning a claimed
  /// outbox lease.
  Future<void> waitForPendingOutboxDrains() async {
    while (_pendingOutboxDrains.isNotEmpty) {
      await Future.wait(_pendingOutboxDrains.toList(growable: false));
    }
  }

  /// Waits for the durable derived work associated with one accepted receipt.
  /// A timeout is recoverable and does not authorize replaying generation or
  /// the already committed author acceptance.
  Future<void> drainReceiptOutboxUntilCompleted({
    required String receiptId,
    required int deadlineAtMs,
    required String leaseOwner,
  }) async {
    final worker = _generationOutboxWorker;
    if (worker == null) {
      throw StateError('generation outbox worker is unavailable');
    }
    await worker.drainUntilCompleted(
      receiptId: receiptId,
      leaseOwner: leaseOwner,
      deadlineAtMs: deadlineAtMs,
    );
  }

  /// Rejects a candidate by discarding only its staged namespace.  It cannot
  /// mutate drafts, versions, or authoritative story memory.
  Future<bool> rejectCurrentCandidate() async {
    final ledger = _generationLedger;
    final candidate = _snapshot;
    if (ledger == null || !candidate.hasDurableCandidateProof) return false;
    ledger.rejectCandidate(
      runId: candidate.runId,
      candidateRevision: candidate.candidateRevision!,
      rejectedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _setSnapshot(
      _snapshot.copyWith(
        phase: StoryGenerationRunPhase.feedback,
        headline: '候选稿已拒绝',
        summary: '作者未采纳这份候选稿；没有正文、版本或记忆被提交。',
        stageSummary: '已拒绝',
        candidateProse: '',
        clearCandidateRevision: true,
        candidateHash: '',
        candidateFinalProseHash: '',
        candidateDeterministicGateEvidenceHash: '',
        candidateFinalCouncilEvidenceHash: '',
        candidateQualityEvidenceHash: '',
        candidatePendingWriteSetHash: '',
        candidateMaterialDigest: '',
        candidateInputDigest: '',
        candidateBaseDraftHash: '',
        candidateGenerationBundleHash: '',
      ),
    );
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

  bool _canResumeSnapshot(StoryGenerationRunSnapshot snapshot) {
    if (snapshot.runId.trim().isEmpty || snapshot.checkpoints.isEmpty) {
      return false;
    }
    // A cancelled run is terminal. Reusing its token/checkpoints would allow
    // a late async result to race with a fresh author-initiated run.
    return snapshot.status == StoryGenerationRunStatus.failed ||
        snapshot.status == StoryGenerationRunStatus.running;
  }

  _PipelineTerminalSnapshot _terminalSnapshotForPipelineError(Object error) {
    if (error is PipelineRunCancelled) {
      return const _PipelineTerminalSnapshot(
        status: StoryGenerationRunStatus.cancelled,
        phase: StoryGenerationRunPhase.cancel,
        headline: 'AI 试写已取消',
        summary: '这次 AI 试写已停止，未采纳内容不会写入正文或长期记忆。',
        stageSummary: '已取消',
        messageTitle: '运行已取消',
        messageBody: '生成在阶段边界被取消；后续结果不会被采纳。',
      );
    }
    if (error is GenerationBudgetUnavailable) {
      return const _PipelineTerminalSnapshot(
        status: StoryGenerationRunStatus.budgetBlocked,
        phase: StoryGenerationRunPhase.budgetBlocked,
        headline: '预算门禁阻断了本场生成',
        summary: '当前运行的预算已耗尽，不能继续请求模型。',
        stageSummary: '预算已耗尽',
        messageTitle: '预算阻断',
        messageBody: '只能取消此运行或创建新的运行；不会自动恢复或追加预算。',
      );
    }
    if (error is GenerationCommitConflict ||
        error is GenerationLedgerInvariantViolation) {
      return const _PipelineTerminalSnapshot(
        status: StoryGenerationRunStatus.conflict,
        phase: StoryGenerationRunPhase.conflict,
        headline: '资料或正文发生冲突',
        summary: '运行没有提交任何候选或权威写入。',
        stageSummary: '冲突',
        messageTitle: '运行冲突',
        messageBody: '请确认正文和资料后创建新的运行；系统没有自动覆盖或恢复。',
      );
    }
    final detail = error.toString().toLowerCase();
    if (detail.contains('sqliteexception')) {
      return const _PipelineTerminalSnapshot(
        status: StoryGenerationRunStatus.failed,
        phase: StoryGenerationRunPhase.fail,
        headline: '候选持久化失败',
        summary: '候选证明没有完整落盘，系统没有展示或提交候选。',
        stageSummary: '持久化失败',
        messageTitle: '候选持久化失败',
        messageBody: '数据库事务已回滚；可以重新生成。',
      );
    }
    if (detail.contains('preliminary review did not pass')) {
      return const _PipelineTerminalSnapshot(
        status: StoryGenerationRunStatus.preliminaryReviewBlocked,
        phase: StoryGenerationRunPhase.preliminaryReviewBlocked,
        headline: '初审阻断了候选生成',
        summary: '初审重试已耗尽，当前正文不能进入候选阶段。',
        stageSummary: '初审未通过',
        messageTitle: '初审阻断',
        messageBody: '当前 revision 只能查看、取消或由作者编辑后重新生成；不会自动恢复。',
      );
    }
    if (detail.contains('final council review did not pass')) {
      return const _PipelineTerminalSnapshot(
        status: StoryGenerationRunStatus.finalReviewBlocked,
        phase: StoryGenerationRunPhase.finalReviewBlocked,
        headline: '终审阻断了候选生成',
        summary: '终审重试已耗尽，当前正文不能进入候选阶段。',
        stageSummary: '终审未通过',
        messageTitle: '终审阻断',
        messageBody: '当前 revision 只能查看、取消或由作者编辑后重新生成；不会自动恢复。',
      );
    }
    if (detail.contains('quality gate blocked') ||
        detail.contains('quality scoring')) {
      return const _PipelineTerminalSnapshot(
        status: StoryGenerationRunStatus.qualityBlocked,
        phase: StoryGenerationRunPhase.qualityBlocked,
        headline: '质量门禁未通过',
        summary: '质量评分或证据未满足候选门禁。',
        stageSummary: '质量未通过',
        messageTitle: '质量阻断',
        messageBody: '只有仍有预算且形成新正文后才能重新尝试；不会自动恢复。',
      );
    }
    if (detail.contains('material') || detail.contains('draft')) {
      return const _PipelineTerminalSnapshot(
        status: StoryGenerationRunStatus.conflict,
        phase: StoryGenerationRunPhase.conflict,
        headline: '资料或正文发生冲突',
        summary: '运行没有提交任何候选或权威写入。',
        stageSummary: '冲突',
        messageTitle: '运行冲突',
        messageBody: '请确认正文和资料后创建新的运行；系统没有自动覆盖或恢复。',
      );
    }
    return const _PipelineTerminalSnapshot(
      status: StoryGenerationRunStatus.failed,
      phase: StoryGenerationRunPhase.fail,
      headline: 'AI 试写失败',
      summary: '这次 AI 试写没有完成。',
      stageSummary: '失败',
      messageTitle: '运行失败摘要',
      messageBody: '本次运行未产生可采纳候选。',
    );
  }

  String? _blockedStageFor(StoryGenerationRunStatus status) => switch (status) {
    StoryGenerationRunStatus.preliminaryReviewBlocked => 'preliminary_review',
    StoryGenerationRunStatus.finalReviewBlocked => 'final_council_review',
    StoryGenerationRunStatus.qualityBlocked => 'quality_gate',
    StoryGenerationRunStatus.budgetBlocked => 'budget',
    StoryGenerationRunStatus.conflict => 'cas',
    StoryGenerationRunStatus.idle ||
    StoryGenerationRunStatus.running ||
    StoryGenerationRunStatus.completed ||
    StoryGenerationRunStatus.failed ||
    StoryGenerationRunStatus.cancelled => null,
  };

  String _terminalErrorCode(Object error) {
    if (error is GenerationBudgetUnavailable) return 'budget_unavailable';
    if (error is PipelineRunCancelled) return 'cancelled';
    if (error is GenerationCommitConflict) return 'commit_conflict';
    if (error is GenerationLedgerInvariantViolation) return 'ledger_invariant';
    final detail = error.toString().toLowerCase();
    if (detail.contains('preliminary review did not pass')) {
      return 'preliminary_review_blocked';
    }
    if (detail.contains('final council review did not pass')) {
      return 'final_review_blocked';
    }
    if (detail.contains('quality gate blocked') ||
        detail.contains('quality scoring')) {
      return 'quality_blocked';
    }
    return 'pipeline_failed';
  }

  String _newLifecycleRunId(String sceneScopeId) {
    final injected = _lifecycleRunIdFactory?.call(sceneScopeId);
    if (injected != null) {
      final normalized = injected.trim();
      if (normalized.isEmpty) {
        throw StateError('injected story generation run ID must not be empty');
      }
      return normalized;
    }
    final safeScope = sceneScopeId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'local-$safeScope-${DateTime.now().microsecondsSinceEpoch}-${_runToken + 1}';
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

class _PipelineTerminalSnapshot {
  const _PipelineTerminalSnapshot({
    required this.status,
    required this.phase,
    required this.headline,
    required this.summary,
    required this.stageSummary,
    required this.messageTitle,
    required this.messageBody,
  });

  final StoryGenerationRunStatus status;
  final StoryGenerationRunPhase phase;
  final String headline;
  final String summary;
  final String stageSummary;
  final String messageTitle;
  final String messageBody;
}

String _checkpointDigest(String value) =>
    value.startsWith('sha256:') ? value.substring('sha256:'.length) : value;

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
