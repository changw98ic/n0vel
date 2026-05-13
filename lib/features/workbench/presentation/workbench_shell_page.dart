import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/navigation/reading_route_data.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_generation_run_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../author_feedback/domain/author_feedback_models.dart';

import 'workbench_ai_revision_helpers.dart';
import 'workbench_editor_helpers.dart';
import 'workbench_tool_window_panel.dart';
import 'workbench_types.dart';
import 'workbench_ai_controller.dart';
import 'workbench_ai_review_dialog.dart';
import 'workbench_editor_pane.dart';
import 'workbench_orchestrator.dart';

export 'workbench_types.dart';

part 'workbench_shell_actions.dart';
part 'workbench_shell_components.dart';

class WorkbenchShellPage extends ConsumerStatefulWidget {
  const WorkbenchShellPage({
    super.key,
    this.uiState = WorkbenchUiState.defaultHidden,
  });

  static const menuDrawerHandleKey = ValueKey<String>(
    'workbench-menu-drawer-handle',
  );
  static const menuDrawerPanelKey = ValueKey<String>(
    'workbench-menu-drawer-panel',
  );
  static const breadcrumbKey = ValueKey<String>('workbench-breadcrumb');
  static const editorPaneKey = ValueKey<String>('workbench-editor-pane');
  static const editorSurfaceHeaderKey = ValueKey<String>(
    'workbench-editor-surface-header',
  );
  static const editorSurfaceMetaKey = ValueKey<String>(
    'workbench-editor-surface-meta',
  );
  static const editorTextFieldKey = ValueKey<String>(
    'workbench-editor-text-field',
  );
  static const toolRailKey = ValueKey<String>('workbench-tool-rail');
  static const chapterListToggleKey = ValueKey<String>(
    'workbench-chapter-list-toggle',
  );
  static const toolWindowKey = ValueKey<String>('workbench-tool-window');
  static const statusBarKey = ValueKey<String>('workbench-status-bar');
  static const runSimulationButtonKey = ValueKey<String>(
    'workbench-run-simulation-button',
  );
  static const failSimulationButtonKey = ValueKey<String>(
    'workbench-fail-simulation-button',
  );
  static const cancelRunButtonKey = ValueKey<String>(
    'workbench-cancel-run-button',
  );
  static const runSnapshotPanelKey = ValueKey<String>(
    'workbench-run-snapshot-panel',
  );
  static const runSnapshotHeadlineKey = ValueKey<String>(
    'workbench-run-snapshot-headline',
  );
  static const runSnapshotStageKey = ValueKey<String>(
    'workbench-run-snapshot-stage',
  );
  static const runRecoveryPromptKey = ValueKey<String>(
    'workbench-run-recovery-prompt',
  );
  static const runRecoveryRetryButtonKey = ValueKey<String>(
    'workbench-run-recovery-retry-button',
  );
  static const runRecoveryDiscardButtonKey = ValueKey<String>(
    'workbench-run-recovery-discard-button',
  );
  static const saveVersionButtonKey = ValueKey<String>(
    'workbench-save-version-button',
  );
  static const openVersionsButtonKey = ValueKey<String>(
    'workbench-open-versions-button',
  );
  static const resourcesToolButtonKey = ValueKey<String>(
    'workbench-tool-button-resources',
  );
  static const sceneTitleFieldKey = ValueKey<String>(
    'workbench-scene-title-field',
  );
  static const aiToolButtonKey = ValueKey<String>('workbench-tool-button-ai');
  static const settingsToolButtonKey = ValueKey<String>(
    'workbench-tool-button-settings',
  );
  static const feedbackToolButtonKey = ValueKey<String>(
    'workbench-tool-button-feedback',
  );
  static const reviewTasksToolButtonKey = ValueKey<String>(
    'workbench-tool-button-review-tasks',
  );
  static const mapReviewTasksButtonKey = ValueKey<String>(
    'workbench-map-review-tasks-button',
  );
  static const aiGenerateButtonKey = ValueKey<String>(
    'workbench-ai-generate-button',
  );
  static const aiPromptFieldKey = ValueKey<String>('workbench-ai-prompt-field');
  static const aiClearPromptButtonKey = ValueKey<String>(
    'workbench-ai-clear-prompt-button',
  );
  static const aiClearHistoryButtonKey = ValueKey<String>(
    'workbench-ai-clear-history-button',
  );
  static const aiRewriteModeButtonKey = ValueKey<String>(
    'workbench-ai-mode-rewrite',
  );
  static const aiContinueModeButtonKey = ValueKey<String>(
    'workbench-ai-mode-continue',
  );
  static const aiAddSelectionButtonKey = ValueKey<String>(
    'workbench-ai-add-selection-button',
  );
  static const aiSelectionListKey = ValueKey<String>(
    'workbench-ai-selection-list',
  );
  static const readingToolButtonKey = ValueKey<String>(
    'workbench-tool-button-reading',
  );
  static const aiRetrySecureStoreButtonKey = ValueKey<String>(
    'workbench-ai-retry-secure-store-button',
  );
  static const aiCopyDiagnosticButtonKey = ValueKey<String>(
    'workbench-ai-copy-diagnostic-button',
  );
  static const settingsRetrySecureStoreButtonKey = ValueKey<String>(
    'workbench-settings-retry-secure-store-button',
  );
  static const settingsCopyDiagnosticButtonKey = ValueKey<String>(
    'workbench-settings-copy-diagnostic-button',
  );

  static ValueKey<String> aiHistoryReplayButtonKey(int sequence) =>
      ValueKey<String>('workbench-ai-history-replay-$sequence');

  static ValueKey<String> aiHistoryDeleteButtonKey(int sequence) =>
      ValueKey<String>('workbench-ai-history-delete-$sequence');

  static ValueKey<String> aiHistoryPromptKey(int sequence) =>
      ValueKey<String>('workbench-ai-history-prompt-$sequence');

  static ValueKey<String> aiSelectionSummaryKey(int index) =>
      ValueKey<String>('workbench-ai-selection-summary-$index');

  static ValueKey<String> aiSelectionEditButtonKey(int index) =>
      ValueKey<String>('workbench-ai-selection-edit-$index');

  static ValueKey<String> aiSelectionRemoveButtonKey(int index) =>
      ValueKey<String>('workbench-ai-selection-remove-$index');

  final WorkbenchUiState uiState;

  @override
  ConsumerState<WorkbenchShellPage> createState() => _WorkbenchShellPageState();
}

class _WorkbenchShellPageState extends ConsumerState<WorkbenchShellPage> {
  WorkbenchOrchestrator? _orchestrator;
  final TextEditingController _aiPromptController = TextEditingController();
  final FocusNode _draftFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  TextEditingController? _draftController;
  AppDraftStore? _draftStore;
  TextSelection _lastEditorSelection = const TextSelection.collapsed(offset: 0);
  String _lastDraftText = '';
  String? _activeDraftScopeId;
  String? _activeSceneId;
  WorkbenchEditorReturnAnchor? _pendingReturnAnchor;

  WorkbenchOrchestrator get _orb => _orchestrator!;

  bool get _isInteractiveDefault =>
      widget.uiState == WorkbenchUiState.defaultHidden;

  bool get _isEditorDirty {
    final controller = _draftController;
    final store = _draftStore;
    if (controller == null || store == null) return false;
    return controller.text != store.snapshot.text;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orchestrator == null) {
      _orchestrator = WorkbenchOrchestrator(
        draftStore: ref.read(appDraftStoreProvider),
        versionStore: ref.read(appVersionStoreProvider),
        settingsStore: ref.read(appSettingsStoreProvider),
        workspaceStore: ref.read(appWorkspaceStoreProvider),
        historyStore: ref.read(appAiHistoryStoreProvider),
        sceneContextStore: ref.read(appSceneContextStoreProvider),
        simulationStore: ref.read(appSimulationStoreProvider),
        authorFeedbackStore: ref.read(authorFeedbackStoreProvider),
        reviewTaskStore: ref.read(reviewTaskStoreProvider),
        storyRunStore: ref.read(storyGenerationRunStoreProvider),
        eventLog: ref.read(appEventLogProvider),
      );
      _orchestrator!.addListener(_onOrchestratorChanged);
    }
    final draftStore = ref.read(appDraftStoreProvider);
    final workspace = ref.read(appWorkspaceStoreProvider);
    final sceneId = workspace.currentProjectOrNull?.sceneId;

    if (_draftController == null) {
      _draftStore = draftStore;
      _draftController = TextEditingController(
        text: _draftStore!.snapshot.text,
      );
      _lastDraftText = _draftStore!.snapshot.text;
      _activeDraftScopeId = _draftStore!.activeProjectId;
      _activeSceneId = sceneId;
      _draftController!.addListener(() {
        final next = _draftController!.text;
        if (_pendingReturnAnchor == null) {
          _lastEditorSelection = _draftController!.selection;
        }
        if (_lastDraftText != next) {
          _lastDraftText = next;
          _orb.clearSelectionsIfNotEmpty();
        }
        if (_draftStore!.snapshot.text != next) {
          _draftStore!.updateText(next);
        }
      });
      _lastEditorSelection = _draftController!.selection;
    } else if (sceneId != _activeSceneId) {
      _activeSceneId = sceneId;
      _draftStore = draftStore;
      final newText = draftStore.snapshot.text;
      _draftController!.text = newText;
      _lastDraftText = newText;
    }
  }

  void _onOrchestratorChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant WorkbenchShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uiState != widget.uiState && !_isInteractiveDefault) {}
  }

  @override
  void dispose() {
    _orchestrator?.removeListener(_onOrchestratorChanged);
    _orchestrator?.dispose();
    _aiPromptController.dispose();
    _draftFocusNode.dispose();
    _editorScrollController.dispose();
    _draftController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = ref.watch(appWorkspaceStoreProvider);
    final draft = ref.watch(appDraftStoreProvider).snapshot;
    final draftStore = ref.watch(appDraftStoreProvider);
    if (_activeDraftScopeId != draftStore.activeProjectId) {
      _activeDraftScopeId = draftStore.activeProjectId;
      _orb.clearSelections();
      _lastDraftText = draft.text;
      _lastEditorSelection = TextSelection.collapsed(offset: draft.text.length);
      if (_pendingReturnAnchor != null &&
          _pendingReturnAnchor!.sceneId != workspace.currentProject.sceneId) {
        _pendingReturnAnchor = null;
      }
      if (_draftController != null &&
          _pendingReturnAnchor == null &&
          _draftController!.text == draft.text) {
        _draftController!.selection = clampWorkbenchEditorSelection(
          _lastEditorSelection,
          _draftController!.text.length,
        );
      }
    }
    final selectionToRestore =
        _pendingReturnAnchor?.selection ?? _lastEditorSelection;
    if (_draftController != null && _draftController!.text != draft.text) {
      _draftController!.value = TextEditingValue(
        text: draft.text,
        selection: clampWorkbenchEditorSelection(
          selectionToRestore,
          draft.text.length,
        ),
      );
      _lastDraftText = draft.text;
    }
    _maybeApplyPendingReturnAnchor();
    final currentSelectionPreview = WorkbenchAiRevisionHelpers.selectionPreview(
      draft.text,
      _normalizedEditorSelection(draft.text),
    );
    final authorFeedbackStore = ref.watch(authorFeedbackStoreProvider);
    final reviewTaskStore = ref.watch(reviewTaskStoreProvider);
    final storyRunStore = ref.watch(storyGenerationRunStoreProvider);
    final storyRunSnapshot = storyRunStore.snapshot;
    final settingsStore = ref.watch(appSettingsStoreProvider);
    final settings = settingsStore.snapshot;
    final settingsFeedback = settingsStore.feedback;
    final diagnosticReport = settingsStore.diagnosticReport;
    final guideStageIndex = _orb.creativeGuideStageIndex;
    final hasSceneCharacterBinding = _orb.sceneCharacterBinding;
    final hasSceneWorldReference = _orb.sceneWorldReference;
    final statusBanner = _buildStatusBanner(
      theme,
      ref.watch(appSimulationStoreProvider).snapshot,
      showContextSynced: _orb.showContextSyncedBanner,
      canGenerateAi: _orb.canGenerateAi,
      hasSceneCharacterBinding: hasSceneCharacterBinding,
      hasSceneWorldReference: hasSceneWorldReference,
      storyRunCancelled:
          storyRunSnapshot.status == StoryGenerationRunStatus.cancelled,
    );
    final runRecoveryPrompt = _buildRunRecoveryPrompt(
      theme,
      storyRunStore,
      storyRunSnapshot,
    );

    return PopScope(
      canPop: !_isEditorDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          barrierLabel: '关闭',
          builder: (context) => DesktopModalDialog(
            title: '未保存的修改',
            description: '当前正文有未保存的修改，确定要离开吗？',
            body: const SizedBox.shrink(),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('继续编辑'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('离开'),
              ),
            ],
          ),
        );
        if (shouldLeave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: DesktopShellFrame(
        header: DesktopHeaderBar(
          tabs: const ['作品资料', '大纲', '正文'],
          activeTabIndex: 2,
          onTabChanged: (i) {
            if (i == 2) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            AppNavigator.push(context, AppRoutes.workSettingsHub);
          },
          actions: [_ModePillButton(onPressed: _openReadingMode)],
        ),
        body: LayoutBuilder(
          builder: (context, layoutConstraints) {
            final toolWindow = _orb.activeToolPanel != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppDesignTokens.radiusXLarge,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: _orb.activeToolPanel == WorkbenchToolPanel.ai
                            ? 18
                            : 20,
                        sigmaY: _orb.activeToolPanel == WorkbenchToolPanel.ai
                            ? 18
                            : 20,
                      ),
                      child: Container(
                        key: WorkbenchShellPage.toolWindowKey,
                        width: DesktopLayoutTokens.workbenchToolWindowWidth,
                        padding: const EdgeInsets.all(20),
                        decoration:
                            _orb.activeToolPanel == WorkbenchToolPanel.ai
                            ? darkAiPanelDecoration(context)
                            : glassPanelDecoration(context),
                        child: ToolWindowPanel(
                          activePanel: _orb.activeToolPanel!,
                          authorFeedbackStore: authorFeedbackStore,
                          reviewTaskStore: reviewTaskStore,
                          scenes: workspace.scenes,
                          currentSceneId:
                              workspace.currentProjectOrNull?.sceneId ?? '',
                          currentChapterId:
                              workspace.currentSceneOrNull?.chapterLabel ?? '',
                          currentSceneLabel:
                              workspace.currentSceneOrNull?.displayLocation ??
                              '',
                          sourceRunId: _orb.sourceRunId(
                            workspace.currentProjectOrNull?.id ?? '',
                          ),
                          sourceRunLabel: _orb.sourceRunLabel(),
                          sceneContext: ref
                              .watch(appSceneContextStoreProvider)
                              .snapshot,
                          uiState: widget.uiState,
                          settings: settings,
                          settingsFeedback: settingsFeedback,
                          settingsHasPersistenceIssue:
                              settingsStore.hasPersistenceIssue,
                          canGenerateAi: _orb.canGenerateAi,
                          isGeneratingAi: _orb.isGeneratingAi,
                          diagnosticReport: diagnosticReport,
                          aiToolMode: _orb.aiToolMode,
                          historyEntries: ref
                              .watch(appAiHistoryStoreProvider)
                              .entries,
                          aiPromptController: _aiPromptController,
                          onRetrySecureStore:
                              settingsStore.retrySecureStoreAccess,
                          draftText: draft.text,
                          currentSelectionPreview: currentSelectionPreview,
                          selectionDrafts:
                              List<WorkbenchAiSelectionDraft>.unmodifiable(
                                _orb.aiSelections,
                              ),
                          onSelectAiMode: (mode) {
                            setState(() {
                              _orb.selectAiMode(mode);
                            });
                          },
                          onGenerateAiSuggestion: _generateAiSuggestion,
                          onReplayAiHistory: _replayAiHistory,
                          onDeleteAiHistoryEntry: (entry) {
                            ref
                                .read(appAiHistoryStoreProvider)
                                .removeEntry(entry.sequence);
                          },
                          onClearAiHistory: () {
                            ref.read(appAiHistoryStoreProvider).clear();
                          },
                          onSyncContext: () {
                            _orb.syncContext();
                          },
                          onSelectScene: (scene) {
                            workspace.updateCurrentScene(
                              sceneId: scene.id,
                              recentLocation: scene.displayLocation,
                            );
                          },
                          onCreateScene: () => _showSceneDialog(
                            context,
                            title: '新建章节',
                            initialValue: '',
                            onConfirm: workspace.createScene,
                          ),
                          onRenameScene: () => _showSceneDialog(
                            context,
                            title: '重命名章节',
                            initialValue:
                                workspace.currentSceneOrNull?.title ?? '',
                            onConfirm: workspace.renameCurrentScene,
                          ),
                          onDeleteScene: () => _confirmDeleteScene(
                            context,
                            workspace.deleteCurrentScene,
                          ),
                          canDeleteScene: workspace.canDeleteCurrentScene,
                          onOpenSettings: () => _openSettingsAndRestoreAnchor(
                            closeToolPanel: true,
                          ),
                          onShowAiMetadata: () {
                            final metadata = _orb.buildRequestMetadata();
                            showAppSheet(
                              context: context,
                              title: 'AI 请求配置',
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('请求配置：${metadata.providerSummary}'),
                                    const SizedBox(height: 8),
                                    Text('接口：${metadata.endpointLabel}'),
                                    const SizedBox(height: 8),
                                    Text('风格约束：${metadata.styleSummary}'),
                                    const SizedBox(height: 8),
                                    Text('章节上下文：${metadata.sceneSummary}'),
                                    const SizedBox(height: 8),
                                    Text(metadata.characterSummary),
                                    const SizedBox(height: 8),
                                    Text(metadata.worldSummary),
                                    const SizedBox(height: 8),
                                    Text('模拟摘要：${metadata.simulationSummary}'),
                                  ],
                                ),
                              ),
                            );
                          },
                          onAddCurrentSelection: _addCurrentSelectionFromEditor,
                          onEditSelectionPrompt: _editSelectionPrompt,
                          onRemoveSelection: _removeSelection,
                          statusBanner: statusBanner,
                          creationGuide: _CreationGuideCard(
                            currentStageIndex: guideStageIndex,
                            hasCharacters: workspace.characters.isNotEmpty,
                            hasWorldNodes: workspace.worldNodes.isNotEmpty,
                            hasSceneSummary: workspace.currentScene.summary
                                .trim()
                                .isNotEmpty,
                            hasDraft: draft.text.trim().isNotEmpty,
                            hasSceneCharacterBinding: hasSceneCharacterBinding,
                            hasSceneWorldReference: hasSceneWorldReference,
                            hasRun: storyRunSnapshot.hasRun,
                            onOpenCharacters: () {
                              final anchor = _captureReturnAnchor();
                              AppNavigator.push(context, AppRoutes.characters);
                              _restoreReturnAnchor(anchor);
                            },
                            onOpenWorldbuilding: () {
                              final anchor = _captureReturnAnchor();
                              AppNavigator.push(
                                context,
                                AppRoutes.worldbuilding,
                              );
                              _restoreReturnAnchor(anchor);
                            },
                            onOpenOutline: () {
                              AppNavigator.push(
                                context,
                                AppRoutes.worldbuilding,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  )
                : null;

            final editorPane = WorkbenchEditorPane(
              hasScenes: workspace.scenes.isNotEmpty,
              sceneTitle: workspace.currentSceneOrNull?.title ?? '',
              draftText: draft.text,
              draftController: _draftController,
              focusNode: _draftFocusNode,
              scrollController: _editorScrollController,
              isToolPanelOpen: _orb.activeToolPanel != null,
              onToggleToolPanel: () => _toggleToolPanel(WorkbenchToolPanel.ai),
              onCreateFirstChapter: () => _showSceneDialog(
                context,
                title: '新建章节',
                initialValue: '',
                onConfirm: ref.read(appWorkspaceStoreProvider).createScene,
              ),
            );

            final chapterListPanel =
                _orb.isChapterListOpen && workspace.scenes.isNotEmpty
                ? _ChapterListPanel(
                    scenes: workspace.scenes,
                    currentSceneId:
                        workspace.currentProjectOrNull?.sceneId ?? '',
                    onSelectScene: (scene) {
                      workspace.updateCurrentScene(
                        sceneId: scene.id,
                        recentLocation: scene.displayLocation,
                      );
                    },
                    onCreateScene: () => _showSceneDialog(
                      context,
                      title: '新建章节',
                      initialValue: '',
                      onConfirm: workspace.createScene,
                    ),
                    onCollapse: () {
                      setState(() {
                        _orb.toggleChapterList();
                      });
                    },
                  )
                : null;

            const panelDivider = VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0x5CD6DDD0),
            );

            final workbenchBody = Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (chapterListPanel != null) ...[
                  chapterListPanel,
                  panelDivider,
                ],
                editorPane,
                if (toolWindow != null) ...[panelDivider, toolWindow],
              ],
            );
            if (runRecoveryPrompt == null) {
              return workbenchBody;
            }
            return Stack(
              children: [
                workbenchBody,
                Positioned(
                  top: 12,
                  left: 24,
                  right: toolWindow == null
                      ? 24
                      : DesktopLayoutTokens.workbenchToolWindowWidth + 48,
                  child: runRecoveryPrompt,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toggleToolPanel(WorkbenchToolPanel panel) {
    _orb.toggleToolPanel(panel);
  }

  Widget? _buildStatusBanner(
    ThemeData theme,
    AppSimulationSnapshot simulation, {
    required bool showContextSynced,
    required bool canGenerateAi,
    required bool hasSceneCharacterBinding,
    required bool hasSceneWorldReference,
    required bool storyRunCancelled,
  }) {
    switch (widget.uiState) {
      case WorkbenchUiState.defaultHidden:
      case WorkbenchUiState.simulationCompleted:
      case WorkbenchUiState.simulationFailedSummary:
      case WorkbenchUiState.noSimulationYet:
      case WorkbenchUiState.menuDrawerOpen:
      case WorkbenchUiState.apiKeyMissing:
      case WorkbenchUiState.missingCharacterBinding:
      case WorkbenchUiState.missingCharacterReference:
      case WorkbenchUiState.missingWorldReference:
      case WorkbenchUiState.contextSynced:
        return null;
    }
  }

  Widget? _buildRunRecoveryPrompt(
    ThemeData theme,
    StoryGenerationRunStore storyRunStore,
    StoryGenerationRunSnapshot snapshot,
  ) {
    if (!_shouldPromptForRunRecovery(snapshot)) {
      return null;
    }
    final palette = desktopPalette(context);
    final stageSummary = snapshot.stageSummary.trim();
    final sceneLabel = snapshot.sceneLabel.trim();
    return Material(
      key: WorkbenchShellPage.runRecoveryPromptKey,
      elevation: 12,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.elevated,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
          border: Border.all(color: workbenchAccentColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.restore_outlined,
              color: workbenchAccentColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('检测到未完成的 AI 试写', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    [
                          if (sceneLabel.isNotEmpty) sceneLabel,
                          if (stageSummary.isNotEmpty) stageSummary,
                        ].join(' · ').trim().isEmpty
                        ? '应用重启后恢复了一轮未完成的生成记录。可以重新开始当前章节，或丢弃这条恢复记录。'
                        : '${[if (sceneLabel.isNotEmpty) sceneLabel, if (stageSummary.isNotEmpty) stageSummary].join(' · ')}。可以重新开始当前章节，或丢弃这条恢复记录。',
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              key: WorkbenchShellPage.runRecoveryDiscardButtonKey,
              onPressed: () => _discardRecoveredRun(storyRunStore),
              child: const Text('丢弃'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: WorkbenchShellPage.runRecoveryRetryButtonKey,
              onPressed: () => _retryRecoveredRun(storyRunStore),
              child: const Text('重新开始'),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldPromptForRunRecovery(StoryGenerationRunSnapshot snapshot) {
    const restorableStatusNames = {
      'running',
      'draft',
      'candidate',
      'feedback',
      'check',
      'resume',
    };
    return snapshot.hasRun &&
        restorableStatusNames.contains(snapshot.status.name);
  }

  Future<void> _retryRecoveredRun(StoryGenerationRunStore storyRunStore) async {
    await storyRunStore.runCurrentScene();
  }

  Future<void> _discardRecoveredRun(
    StoryGenerationRunStore storyRunStore,
  ) async {
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
}
