import '../../../app/logging/app_event_log.dart';
import '../../../app/logging/app_event_log_privacy.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_settings_store.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_store_listenable.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_generation_run_store.dart';
import '../../author_feedback/data/author_feedback_store.dart';
import '../../author_feedback/domain/author_feedback_models.dart';
import '../../review_tasks/data/review_task_store.dart';
import '../../story_generation/data/generation_ledger_models.dart';
import '../data/workbench_ai_controller.dart';
import '../presentation/workbench_ai_revision_helpers.dart';
import '../presentation/workbench_editor_helpers.dart';
import '../presentation/workbench_types.dart';

// --- AI flow command results ---

sealed class AiGenerationCommand {}

class ShowAiNotReady extends AiGenerationCommand {}

class ShowAiOverlappingSelections extends AiGenerationCommand {}

/// The normal workbench action has started (and finished) a scene pipeline
/// run. Its candidate is rendered from [StoryGenerationRunStore], rather than
/// from a one-off chat completion review dialog.
class ShowAiSceneRunResult extends AiGenerationCommand {
  ShowAiSceneRunResult({required this.snapshot});

  final StoryGenerationRunSnapshot snapshot;
}

enum WorkbenchCandidateActionState {
  idle,
  accepting,
  rejecting,
  accepted,
  rejected,
  conflict,
  unavailable,
  cancelled,
  failed,
}

class WorkbenchCandidateActionFeedback {
  const WorkbenchCandidateActionFeedback({
    required this.state,
    this.message = '',
  });

  final WorkbenchCandidateActionState state;
  final String message;

  bool get isBusy =>
      state == WorkbenchCandidateActionState.accepting ||
      state == WorkbenchCandidateActionState.rejecting;

  bool get isError =>
      state == WorkbenchCandidateActionState.conflict ||
      state == WorkbenchCandidateActionState.unavailable ||
      state == WorkbenchCandidateActionState.cancelled ||
      state == WorkbenchCandidateActionState.failed;
}

class ShowAiReview extends AiGenerationCommand {
  ShowAiReview({
    required this.reviewTitle,
    required this.historyPrompt,
    required this.blocks,
    required this.metadata,
    required this.continueMode,
    required this.clearSelectionsOnAccept,
    required this.correlationId,
  });

  final String reviewTitle;
  final String historyPrompt;
  final List<WorkbenchAiReviewBlock> blocks;
  final AiRequestMetadata metadata;
  final bool continueMode;
  final bool clearSelectionsOnAccept;
  final String correlationId;
}

sealed class AiReplayCommand {}

class ShowAiReplayReview extends AiReplayCommand {
  ShowAiReplayReview({
    required this.reviewTitle,
    required this.historyPrompt,
    required this.blocks,
    required this.metadata,
    required this.continueMode,
    required this.correlationId,
  });

  final String reviewTitle;
  final String historyPrompt;
  final List<WorkbenchAiReviewBlock> blocks;
  final AiRequestMetadata metadata;
  final bool continueMode;
  final String correlationId;
}

// --- Orchestrator ---

class WorkbenchOrchestrator extends AppStoreListenable {
  WorkbenchOrchestrator({
    required this.draftStore,
    required this.versionStore,
    required this.settingsStore,
    required this.workspaceStore,
    required this.historyStore,
    required this.sceneContextStore,
    required this.simulationStore,
    required this.authorFeedbackStore,
    required this.reviewTaskStore,
    required this.storyRunStore,
    required this.eventLog,
  });

  // Data layer
  final AppDraftStore draftStore;
  final AppVersionStore versionStore;
  final AppSettingsStore settingsStore;
  final AppWorkspaceStore workspaceStore;
  final AppAiHistoryStore historyStore;
  final AppSceneContextStore sceneContextStore;
  final AppSimulationStore simulationStore;
  final AuthorFeedbackStore authorFeedbackStore;
  final ReviewTaskStore reviewTaskStore;
  final StoryGenerationRunStore storyRunStore;
  final AppEventLog eventLog;

  late final WorkbenchAiController aiController = WorkbenchAiController(
    settingsStore: settingsStore,
    workspaceStore: workspaceStore,
    eventLog: eventLog,
  );

  // --- UI State ---

  WorkbenchToolPanel? _activeToolPanel;
  AiToolMode _aiToolMode = AiToolMode.rewrite;
  bool _isGeneratingAi = false;
  bool _showContextSyncedBanner = false;
  final List<WorkbenchAiSelectionDraft> _aiSelections = [];
  bool _isChapterListOpen = true;
  WorkbenchCandidateActionFeedback _candidateActionFeedback =
      const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.idle,
      );

  WorkbenchToolPanel? get activeToolPanel => _activeToolPanel;
  AiToolMode get aiToolMode => _aiToolMode;
  bool get isGeneratingAi => _isGeneratingAi;
  bool get showContextSyncedBanner => _showContextSyncedBanner;
  List<WorkbenchAiSelectionDraft> get aiSelections =>
      List.unmodifiable(_aiSelections);
  bool get isChapterListOpen => _isChapterListOpen;
  WorkbenchCandidateActionFeedback get candidateActionFeedback =>
      _candidateActionFeedback;

  bool get canGenerateAi =>
      settingsStore.hasAnyReadyConfiguration &&
      !settingsStore.hasPersistenceIssue;
  String get draftText => draftStore.snapshot.text;
  bool get canDeleteCurrentScene => workspaceStore.canDeleteCurrentScene;

  // --- Simple actions ---

  void toggleToolPanel(WorkbenchToolPanel panel) {
    _activeToolPanel = _activeToolPanel == panel ? null : panel;
    notifyListeners();
  }

  void closeToolPanel() {
    _activeToolPanel = null;
    notifyListeners();
  }

  void selectAiMode(AiToolMode mode) {
    _aiToolMode = mode;
    notifyListeners();
  }

  void toggleChapterList() {
    _isChapterListOpen = !_isChapterListOpen;
    notifyListeners();
  }

  // --- Context sync ---

  void syncContext() {
    sceneContextStore.syncContext();
    _showContextSyncedBanner = true;
    notifyListeners();
  }

  // --- Selection management ---

  void addSelection(WorkbenchAiSelectionDraft selection) {
    _aiSelections.add(selection);
    notifyListeners();
  }

  void updateSelectionPrompt(int index, String prompt) {
    if (index >= 0 && index < _aiSelections.length) {
      _aiSelections[index] = _aiSelections[index].copyWith(prompt: prompt);
      notifyListeners();
    }
  }

  void removeSelection(int index) {
    if (index >= 0 && index < _aiSelections.length) {
      _aiSelections.removeAt(index);
      notifyListeners();
    }
  }

  void clearSelections() {
    _aiSelections.clear();
    notifyListeners();
  }

  void clearSelectionsIfNotEmpty() {
    if (_aiSelections.isNotEmpty) {
      _aiSelections.clear();
      notifyListeners();
    }
  }

  bool hasOverlappingSelections() =>
      _aiSelections.isNotEmpty &&
      WorkbenchAiRevisionHelpers.hasOverlappingSelections(_aiSelections);

  // --- AI generation flow ---

  AiRequestMetadata buildRequestMetadata() => aiController.buildRequestMetadata(
    settings: settingsStore.snapshot,
    sceneContext: sceneContextStore.snapshot,
    simulation: simulationStore.snapshot,
  );

  Future<AiGenerationCommand?> prepareAiGeneration(String prompt) async {
    if (!settingsStore.hasReadyConfiguration ||
        settingsStore.hasPersistenceIssue) {
      return ShowAiNotReady();
    }

    final metadata = buildRequestMetadata();
    final correlationId = eventLog.newCorrelationId('ai-generate');

    if (_aiToolMode == AiToolMode.rewrite && hasOverlappingSelections()) {
      return ShowAiOverlappingSelections();
    }

    await aiController.logEvent(
      category: AppEventLogCategory.ui,
      action: 'ui.ai.generate.started',
      status: AppEventLogStatus.started,
      message: 'Started AI generate flow.',
      correlationId: correlationId,
      metadata: {
        'mode': _aiToolMode.name,
        'selectionCount': _aiSelections.length,
        ...AppEventLogPrivacy.textMetadata(
          field: 'prompt',
          value: prompt.isEmpty
              ? WorkbenchAiRevisionHelpers.defaultIntent(
                  continueMode: _aiToolMode == AiToolMode.continueWriting,
                )
              : prompt,
        ),
      },
    );

    _isGeneratingAi = true;
    notifyListeners();

    try {
      if (_aiToolMode == AiToolMode.rewrite && _aiSelections.isNotEmpty) {
        final original = draftStore.snapshot.text;
        final selectionPrompt = '多选区改写（${_aiSelections.length}段）';
        final blocks = await aiController.requestSelectionReviewBlocks(
          original,
          _aiSelections,
          metadata,
          correlationId,
        );
        return ShowAiReview(
          reviewTitle: 'AI 修改确认',
          historyPrompt: selectionPrompt,
          blocks: blocks,
          metadata: metadata,
          continueMode: false,
          clearSelectionsOnAccept: true,
          correlationId: correlationId,
        );
      }

      // No selection means the author asked to write the current scene, not
      // to perform an inline edit. Keep that action on the single durable
      // StoryPipeline path so it receives context, review, and persistence.
      final effectivePrompt = prompt.isEmpty
          ? WorkbenchAiRevisionHelpers.defaultIntent(
              continueMode: _aiToolMode == AiToolMode.continueWriting,
            )
          : prompt;
      await storyRunStore.runCurrentScene(rulesOverride: effectivePrompt);
      final snapshot = storyRunStore.snapshot;
      await aiController.logEvent(
        category: AppEventLogCategory.ai,
        action: 'ai.scene_pipeline.completed',
        status: snapshot.candidatePresentation.canAccept
            ? AppEventLogStatus.succeeded
            : AppEventLogStatus.failed,
        message: snapshot.candidatePresentation.canAccept
            ? 'Scene pipeline generated a recoverable candidate.'
            : 'Scene pipeline did not produce a candidate.',
        correlationId: correlationId,
        metadata: {
          'runStatus': snapshot.status.name,
          'candidatePresentation': snapshot.candidatePresentation.state.name,
        },
      );
      return ShowAiSceneRunResult(snapshot: snapshot);
    } finally {
      _isGeneratingAi = false;
      notifyListeners();
    }
  }

  /// Requests one author acceptance through the run-store transaction entry
  /// point.  The UI never writes draft text from its cached prose preview.
  Future<void> acceptCurrentCandidate() async {
    if (_candidateActionFeedback.isBusy) return;
    if (!storyRunStore.snapshot.candidatePresentation.canAccept) {
      _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.unavailable,
        message: '候选 proof 或正文载荷不可用，不能采纳；系统没有自动恢复。',
      );
      notifyListeners();
      return;
    }
    _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
      state: WorkbenchCandidateActionState.accepting,
      message: '正在以候选证明提交作者采纳…',
    );
    notifyListeners();
    try {
      final result = await storyRunStore.acceptCurrentCandidate();
      _candidateActionFeedback = WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.accepted,
        message: result is GenerationCommitAlreadyApplied
            ? '该候选此前已经采纳；已返回原提交记录。'
            : '候选稿已采纳并完成事务提交。',
      );
    } on GenerationDraftConflict {
      _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.conflict,
        message: '正文在候选生成后已变更，候选未提交。请比较后重新生成；系统没有自动覆盖。',
      );
    } on GenerationMaterialConflict {
      _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.conflict,
        message: '项目资料在候选生成后已变更，候选未提交。请确认资料后重新生成；系统没有自动恢复。',
      );
    } on GenerationCandidateEvidenceConflict {
      _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.unavailable,
        message: '候选 proof 或正文载荷校验失败，候选未提交。请重新生成；系统没有自动恢复。',
      );
    } on GenerationCancelWonConflict {
      _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.cancelled,
        message: '取消操作先于采纳生效，候选没有提交。请创建新的运行。',
      );
    } on GenerationCommitConflict {
      _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.conflict,
        message: '候选提交发生冲突，未写入正文或长期记忆。请检查后重新生成。',
      );
    } catch (_) {
      _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.failed,
        message: '候选采纳未完成，未将缓存正文写入编辑器。请查看运行记录后重试。',
      );
    }
    notifyListeners();
  }

  /// Rejects only the staged candidate namespace.  Rejection never routes the
  /// cached prose through draft/version stores.
  Future<void> rejectCurrentCandidate() async {
    if (_candidateActionFeedback.isBusy) return;
    if (!storyRunStore.snapshot.candidatePresentation.canReject) {
      _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.unavailable,
        message: '候选 proof 或正文载荷不可用，不能拒绝；没有任何正文会被提交。',
      );
      notifyListeners();
      return;
    }
    _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
      state: WorkbenchCandidateActionState.rejecting,
      message: '正在丢弃未采纳候选…',
    );
    notifyListeners();
    try {
      final rejected = await storyRunStore.rejectCurrentCandidate();
      _candidateActionFeedback = rejected
          ? const WorkbenchCandidateActionFeedback(
              state: WorkbenchCandidateActionState.rejected,
              message: '候选稿已拒绝；正文、版本和长期记忆均未提交。',
            )
          : const WorkbenchCandidateActionFeedback(
              state: WorkbenchCandidateActionState.unavailable,
              message: '候选 proof 已不可用，无法拒绝；没有任何正文会被提交。',
            );
    } catch (_) {
      _candidateActionFeedback = const WorkbenchCandidateActionFeedback(
        state: WorkbenchCandidateActionState.failed,
        message: '拒绝候选未完成；没有将缓存正文写入编辑器。请刷新运行记录后重试。',
      );
    }
    notifyListeners();
  }

  // --- AI replay flow ---

  Future<AiReplayCommand?> prepareAiReplay(AiHistoryEntry entry) async {
    final original = draftStore.snapshot.text;
    final continueMode = entry.mode == '续写';
    final metadata = buildRequestMetadata();
    final correlationId = eventLog.newCorrelationId('ai-replay');

    await aiController.logEvent(
      category: AppEventLogCategory.ui,
      action: 'ui.ai.replay.started',
      status: AppEventLogStatus.started,
      message: 'Started AI history replay.',
      correlationId: correlationId,
      metadata: {
        'mode': entry.mode,
        ...AppEventLogPrivacy.textMetadata(
          field: 'prompt',
          value: entry.prompt,
        ),
      },
    );

    _isGeneratingAi = true;
    notifyListeners();

    try {
      final blocks = await aiController.requestFallbackReviewBlocks(
        original: original,
        prompt: entry.prompt,
        continueMode: continueMode,
        metadata: metadata,
        correlationId: correlationId,
      );
      return ShowAiReplayReview(
        reviewTitle: continueMode ? 'AI 续写确认' : 'AI 修改确认',
        historyPrompt: entry.prompt,
        blocks: blocks,
        metadata: metadata,
        continueMode: continueMode,
        correlationId: correlationId,
      );
    } finally {
      _isGeneratingAi = false;
      notifyListeners();
    }
  }

  // --- Feedback recording ---

  void recordAiReviewDecision({
    required AuthorFeedbackStatus status,
    required String historyPrompt,
    String? correlationId,
  }) {
    final workspace = workspaceStore;
    final runSnapshot = storyRunStore.snapshot;
    final promptText = historyPrompt.trim().isEmpty
        ? WorkbenchAiRevisionHelpers.defaultIntent(continueMode: false)
        : historyPrompt;
    final promptPreview = WorkbenchAiRevisionHelpers.previewText(
      promptText,
      120,
    );
    authorFeedbackStore.createFeedback(
      chapterId: workspace.currentScene.chapterLabel,
      sceneId: workspace.currentScene.id,
      sceneLabel: workspace.currentScene.displayLocation,
      note: status == AuthorFeedbackStatus.accepted
          ? '已采纳 AI 建议：$promptPreview'
          : '未采纳 AI 建议：$promptPreview',
      priority: AuthorFeedbackPriority.normal,
      status: status,
      sourceRunId: _sourceRunId(workspace.currentProject.id, runSnapshot),
      sourceRunLabel: _sourceRunLabel(runSnapshot),
      sourceReviewId: correlationId,
    );
  }

  // --- Scene management ---

  void selectScene(String sceneId, String recentLocation) {
    workspaceStore.updateCurrentScene(
      sceneId: sceneId,
      recentLocation: recentLocation,
    );
  }

  void createScene(String title) => workspaceStore.createScene(title);

  void renameCurrentScene(String title) =>
      workspaceStore.renameCurrentScene(title);

  void deleteCurrentScene() => workspaceStore.deleteCurrentScene();

  // --- History ---

  void addHistoryEntry({required String mode, required String prompt}) {
    historyStore.addEntry(mode: mode, prompt: prompt);
  }

  void removeHistoryEntry(int sequence) => historyStore.removeEntry(sequence);

  void clearHistory() => historyStore.clear();

  // --- Computed state for build() ---

  String? sourceRunId(String projectId) =>
      _sourceRunId(projectId, storyRunStore.snapshot);

  String? sourceRunLabel() => _sourceRunLabel(storyRunStore.snapshot);

  int get creativeGuideStageIndex => _creativeGuideStageIndex(
    hasCharacters: workspaceStore.characters.isNotEmpty,
    hasWorldNodes: workspaceStore.worldNodes.isNotEmpty,
    hasSceneSummary: workspaceStore.currentScene.summary.trim().isNotEmpty,
    hasDraft: draftStore.snapshot.text.trim().isNotEmpty,
    hasSceneCharacterBinding: sceneCharacterBinding,
    hasSceneWorldReference: sceneWorldReference,
    hasRun: storyRunStore.snapshot.hasRun,
  );

  bool get sceneCharacterBinding {
    final sceneContext = sceneContextStore.snapshot;
    final currentSceneId = workspaceStore.currentScene.id;
    final hasSynced = hasUsableWorkbenchSceneContext(
      sceneContext.characterSummary,
      '角色摘要',
    );
    final hasLinked = workspaceStore.characters.any(
      (c) => resourceBelongsToWorkbenchScene(
        linkedSceneIds: c.linkedSceneIds,
        currentSceneId: currentSceneId,
        resourceName: c.name,
        syncedSummary: sceneContext.characterSummary,
      ),
    );
    return hasLinked || (workspaceStore.characters.isNotEmpty && hasSynced);
  }

  bool get sceneWorldReference {
    final sceneContext = sceneContextStore.snapshot;
    final currentSceneId = workspaceStore.currentScene.id;
    final hasSynced = hasUsableWorkbenchSceneContext(
      sceneContext.worldSummary,
      '世界观摘要',
    );
    final hasLinked = workspaceStore.worldNodes.any(
      (n) => resourceBelongsToWorkbenchScene(
        linkedSceneIds: n.linkedSceneIds,
        currentSceneId: currentSceneId,
        resourceName: n.title,
        syncedSummary: sceneContext.worldSummary,
      ),
    );
    return hasLinked || (workspaceStore.worldNodes.isNotEmpty && hasSynced);
  }

  // --- Run recovery ---

  static const _restorableStatusNames = {
    'running',
    'draft',
    'candidate',
    'feedback',
    'check',
    'resume',
  };

  bool shouldPromptForRunRecovery(StoryGenerationRunSnapshot snapshot) {
    return snapshot.hasRun &&
        _restorableStatusNames.contains(snapshot.status.name);
  }

  Future<void> retryRecoveredRun() async {
    await storyRunStore.runCurrentScene();
  }

  /// Cancels the single active chapter run and persists the terminal state.
  ///
  /// The run store owns the cancellation token and ledger transition; the
  /// orchestrator only bridges that result to the Workbench listener so the
  /// status panel updates immediately.
  Future<bool> cancelCurrentRun() async {
    final cancelled = await storyRunStore.cancelCurrentRun();
    if (cancelled) notifyListeners();
    return cancelled;
  }

  /// Retries a failed or recoverable chapter run through the existing run
  /// store. No candidate or draft is written until the normal proof-gated
  /// pipeline completes.
  Future<void> retryCurrentRun() async {
    await storyRunStore.runCurrentScene();
    notifyListeners();
  }

  Future<void> discardRecoveredRun() async {
    final exported = await storyRunStore.exportProjectJson();
    final rawRunsByScope = exported['sceneRunsByScope'];
    final sceneRunsByScope = <String, Object?>{};
    if (rawRunsByScope is Map) {
      for (final entry in rawRunsByScope.entries) {
        final sceneScopeId = entry.key.toString();
        if (sceneScopeId != storyRunStore.activeSceneScopeId) {
          sceneRunsByScope[sceneScopeId] = entry.value;
        }
      }
    }
    await storyRunStore.importProjectJson({
      'projectId': exported['projectId'],
      'sceneRunsByScope': sceneRunsByScope,
    });
  }

  // --- Private helpers ---

  static String? _sourceRunId(
    String projectId,
    StoryGenerationRunSnapshot snapshot,
  ) {
    if (!snapshot.hasRun) return null;
    return '$projectId::${snapshot.sceneId}::${snapshot.status.name}';
  }

  static String? _sourceRunLabel(StoryGenerationRunSnapshot snapshot) {
    if (!snapshot.hasRun) return null;
    final stage = snapshot.stageSummary.trim();
    if (stage.isEmpty) return snapshot.headline;
    return '${snapshot.headline} · $stage';
  }

  static int _creativeGuideStageIndex({
    required bool hasCharacters,
    required bool hasWorldNodes,
    required bool hasSceneSummary,
    required bool hasDraft,
    required bool hasSceneCharacterBinding,
    required bool hasSceneWorldReference,
    required bool hasRun,
  }) {
    if (!hasCharacters || !hasWorldNodes) return 1;
    if (!hasSceneSummary) return 2;
    if (!hasSceneCharacterBinding || !hasSceneWorldReference) return 3;
    if (!hasDraft && !hasRun) return 4;
    if (hasRun) return 5;
    return 4;
  }
}
