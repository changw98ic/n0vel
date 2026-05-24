part of 'workbench_shell_page.dart';

// ---------------------------------------------------------------------------
// Three-pane layout components
// ---------------------------------------------------------------------------

class _PaneDivider extends StatefulWidget {
  const _PaneDivider({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<_PaneDivider> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _isDragging = true);
          widget.onDragStart();
        },
        onPanUpdate: (details) => widget.onDragUpdate(details.delta.dx),
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          widget.onDragEnd();
        },
        child: Container(
          width: _isDragging ? 4.0 : (_isHovering ? 3.0 : 1.0),
          color: const Color(0x5CD6DDD0),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Draft sync helpers
// ---------------------------------------------------------------------------

void _draftControllerListener(_WorkbenchShellPageState state) {
  final next = state._draftController!.text;
  if (state._pendingReturnAnchor == null) {
    state._lastEditorSelection = state._draftController!.selection;
  }
  if (state._lastDraftText != next) {
    state._lastDraftText = next;
    state._orb.clearSelectionsIfNotEmpty();
  }
  if (state._draftStore!.snapshot.text != next) {
    state._draftStore!.updateText(next);
  }
}

void _syncDraftScopeChange(
  _WorkbenchShellPageState state,
  AppDraftSnapshot draft,
  AppDraftStore draftStore,
  AppWorkspaceStore workspace,
) {
  if (state._activeDraftScopeId != draftStore.activeProjectId) {
    state._activeDraftScopeId = draftStore.activeProjectId;
    state._orb.clearSelections();
    state._lastDraftText = draft.text;
    state._lastEditorSelection = TextSelection.collapsed(offset: draft.text.length);
    if (state._pendingReturnAnchor != null &&
        state._pendingReturnAnchor!.sceneId != workspace.currentProject.sceneId) {
      state._pendingReturnAnchor = null;
    }
    if (state._draftController != null &&
        state._pendingReturnAnchor == null &&
        state._draftController!.text == draft.text) {
      state._draftController!.selection = clampWorkbenchEditorSelection(
        state._lastEditorSelection,
        state._draftController!.text.length,
      );
    }
  }
}

void _applyDraftTextSync(
  _WorkbenchShellPageState state,
  AppDraftSnapshot draft,
  TextSelection selectionToRestore,
) {
  if (state._draftController != null && state._draftController!.text != draft.text) {
    state._draftController!.value = TextEditingValue(
      text: draft.text,
      selection: clampWorkbenchEditorSelection(
        selectionToRestore,
        draft.text.length,
      ),
    );
    state._lastDraftText = draft.text;
  }
}

TextSelection? _normalizedEditorSelection(
  _WorkbenchShellPageState state,
  String text,
) {
  final controller = state._draftController;
  if (controller == null) return null;
  final selection = clampWorkbenchEditorSelection(controller.selection, text.length);
  if (!selection.isValid || selection.isCollapsed) return null;
  return TextSelection(baseOffset: selection.start, extentOffset: selection.end);
}

// ---------------------------------------------------------------------------
// Status banner (reserved for future use)
// ---------------------------------------------------------------------------

Widget? _buildStatusBanner(WorkbenchUiState uiState) {
  switch (uiState) {
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

// ---------------------------------------------------------------------------
// Run recovery prompt widget
// ---------------------------------------------------------------------------

class _RunRecoveryPrompt extends StatelessWidget {
  const _RunRecoveryPrompt({
    required this.snapshot,
    required this.onRetry,
    required this.onDiscard,
  });

  final StoryGenerationRunSnapshot snapshot;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final stageSummary = snapshot.stageSummary.trim();
    final sceneLabel = snapshot.sceneLabel.trim();
    final detailParts = [
      if (sceneLabel.isNotEmpty) sceneLabel,
      if (stageSummary.isNotEmpty) stageSummary,
    ];
    final detailText = detailParts.join(' · ').trim().isEmpty
        ? '应用重启后恢复了一轮未完成的生成记录。可以重新开始当前章节，或丢弃这条恢复记录。'
        : '${detailParts.join(' · ')}。可以重新开始当前章节，或丢弃这条恢复记录。';
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
                    detailText,
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
              onPressed: onDiscard,
              child: const Text('丢弃'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: WorkbenchShellPage.runRecoveryRetryButtonKey,
              onPressed: onRetry,
              child: const Text('重新开始'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell body builder (main build delegate)
// ---------------------------------------------------------------------------

/// Empty state for panes that are not yet implemented.
/// Shows a subtle, polished empty state instead of placeholder text.
Widget _buildEmptyPane({
  required BuildContext context,
  IconData? icon,
  String? message,
}) {
  final palette = desktopPalette(context);
  final theme = Theme.of(context);

  return Container(
    decoration: BoxDecoration(
      color: palette.surface,
      border: Border.all(
        color: const Color(0x5CD6DDD0),
        width: 1,
      ),
    ),
    child: Center(
      child: Opacity(
        opacity: 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: 32,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// AI tool panel invitation for the center pane.
/// Shows a helpful affordance to open the AI tool panel for content generation.
Widget _buildAiToolInvitationPane({
  required BuildContext context,
  required VoidCallback onOpenAiTool,
}) {
  final palette = desktopPalette(context);
  final theme = Theme.of(context);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: palette.surface,
      border: Border.all(
        color: const Color(0x5CD6DDD0),
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Text(
              'AI 写作助手',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit_note_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  '开始 AI 辅助创作',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '续写、润色、对话等多种模式',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: onOpenAiTool,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('打开 AI 面板'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildShellBody(_WorkbenchShellPageState state, BuildContext context) {
  final workspace = state.ref.watch(appWorkspaceStoreProvider);
  final draft = state.ref.watch(appDraftStoreProvider).snapshot;
  final draftStore = state.ref.watch(appDraftStoreProvider);

  _syncDraftScopeChange(state, draft, draftStore, workspace);

  final selectionToRestore =
      state._pendingReturnAnchor?.selection ?? state._lastEditorSelection;
  _applyDraftTextSync(state, draft, selectionToRestore);
  state._maybeApplyPendingReturnAnchor();

  final currentSelectionPreview = WorkbenchAiRevisionHelpers.selectionPreview(
    draft.text,
    _normalizedEditorSelection(state, draft.text),
  );
  final authorFeedbackStore = state.ref.watch(authorFeedbackStoreProvider);
  final reviewTaskStore = state.ref.watch(reviewTaskStoreProvider);
  final storyRunStore = state.ref.watch(storyGenerationRunStoreProvider);
  final storyRunSnapshot = storyRunStore.snapshot;
  final settingsStore = state.ref.watch(appSettingsStoreProvider);
  final settings = settingsStore.snapshot;
  final settingsFeedback = settingsStore.feedback;
  final diagnosticReport = settingsStore.diagnosticReport;
  final guideStageIndex = state._orb.creativeGuideStageIndex;
  final hasSceneCharacterBinding = state._orb.sceneCharacterBinding;
  final hasSceneWorldReference = state._orb.sceneWorldReference;
  final statusBanner = _buildStatusBanner(state.widget.uiState);
  final runRecoveryPrompt = state._orb.shouldPromptForRunRecovery(storyRunSnapshot)
      ? _RunRecoveryPrompt(
          snapshot: storyRunSnapshot,
          onRetry: () => state._orb.retryRecoveredRun(),
          onDiscard: () => state._orb.discardRecoveredRun(),
        )
      : null;

  return PopScope(
    canPop: !state._isEditorDirty,
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
        actions: [_ModePillButton(onPressed: state._openReadingMode)],
      ),
      body: LayoutBuilder(
        builder: (context, layoutConstraints) {
          final toolWindow = _buildToolWindow(
            state,
            context: context,
            workspace: workspace,
            draft: draft,
            authorFeedbackStore: authorFeedbackStore,
            reviewTaskStore: reviewTaskStore,
            storyRunSnapshot: storyRunSnapshot,
            settings: settings,
            settingsFeedback: settingsFeedback,
            diagnosticReport: diagnosticReport,
            settingsStore: settingsStore,
            currentSelectionPreview: currentSelectionPreview,
            guideStageIndex: guideStageIndex,
            hasSceneCharacterBinding: hasSceneCharacterBinding,
            hasSceneWorldReference: hasSceneWorldReference,
            statusBanner: statusBanner,
          );

          final editorPane = WorkbenchEditorPane(
            hasScenes: workspace.scenes.isNotEmpty,
            sceneTitle: workspace.currentSceneOrNull?.title ?? '',
            draftText: draft.text,
            draftController: state._draftController,
            focusNode: state._draftFocusNode,
            scrollController: state._editorScrollController,
            isToolPanelOpen: state._orb.activeToolPanel != null,
            isRunCenterOpen: state._orb.activeToolPanel == WorkbenchToolPanel.runCenter,
            onToggleToolPanel: () => state._orb.toggleToolPanel(WorkbenchToolPanel.ai),
            onOpenRunCenter: () => state._orb.toggleToolPanel(WorkbenchToolPanel.runCenter),
            onCreateFirstChapter: () => state._showSceneDialog(
              context,
              title: '新建章节',
              initialValue: '',
              onConfirm: state.ref.read(appWorkspaceStoreProvider).createScene,
            ),
          );

          const panelDivider = VerticalDivider(
            width: 1,
            thickness: 1,
            color: Color(0x5CD6DDD0),
          );

          // Left pane: editor + optional chapter list
          final leftPane = Column(
            children: [
              if (state._orb.isChapterListOpen && workspace.scenes.isNotEmpty)
                SizedBox(
                  height: 200.0,
                  child: _ChapterListPanel(
                    scenes: workspace.scenes,
                    currentSceneId: workspace.currentProjectOrNull?.sceneId ?? '',
                    onSelectScene: (scene) async {
                      await state._confirmSceneSwitch(
                        scene,
                        () => workspace.updateCurrentScene(
                          sceneId: scene.id,
                          recentLocation: scene.displayLocation,
                        ),
                      );
                    },
                    onCreateScene: () => state._showSceneDialog(
                      context,
                      title: '新建章节',
                      initialValue: '',
                      onConfirm: workspace.createScene,
                    ),
                    onCollapse: () => state._orb.toggleChapterList(),
                  ),
                ),
              Expanded(child: editorPane),
            ],
          );

          // Center pane: AI tool invitation
          final centerPane = _buildAiToolInvitationPane(
            context: context,
            onOpenAiTool: () => state._orb.toggleToolPanel(WorkbenchToolPanel.ai),
          );

          // Right pane: summary area (empty state for future implementation)
          final rightPane = _buildEmptyPane(
            context: context,
            icon: Icons.summarize_outlined,
          );

          // Calculate pane widths with overflow protection
          final totalAvailableWidth = layoutConstraints.maxWidth;
          final hasToolWindow = toolWindow != null;
          final toolWindowWidth = hasToolWindow
              ? DesktopLayoutTokens.workbenchToolWindowWidth + 1.0 // divider
              : 0.0;
          final effectiveWidth = totalAvailableWidth - toolWindowWidth;

          // Ensure we have minimum width for all panes
          final totalFixedWidth = state._leftPaneWidth + state._rightPaneWidth + (2 * _WorkbenchShellPageState._dividerWidth);
          final centerPaneCalculatedWidth = effectiveWidth - totalFixedWidth;

          // For constrained widths, use Flexible to let panes shrink gracefully.
          // Use flexible layout when current left/right widths leave center pane below minimum.
          final useFlexibleLayout = effectiveWidth <= 0 || centerPaneCalculatedWidth < _WorkbenchShellPageState._minPaneWidth;

          final workbenchBody = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (useFlexibleLayout)
                Expanded(flex: 4, child: leftPane)
              else
                SizedBox(width: state._leftPaneWidth, child: leftPane),
              _PaneDivider(
                onDragStart: state._handleLeftDividerDragStart,
                onDragUpdate: (deltaX) => state._handleLeftDividerDragUpdate(deltaX, effectiveWidth),
                onDragEnd: state._handleLeftDividerDragEnd,
              ),
              if (useFlexibleLayout)
                Expanded(flex: 3, child: centerPane)
              else
                SizedBox(width: centerPaneCalculatedWidth.clamp(_WorkbenchShellPageState._minPaneWidth, double.infinity), child: centerPane),
              _PaneDivider(
                onDragStart: state._handleRightDividerDragStart,
                onDragUpdate: (deltaX) => state._handleRightDividerDragUpdate(deltaX, effectiveWidth),
                onDragEnd: state._handleRightDividerDragEnd,
              ),
              if (useFlexibleLayout)
                Expanded(flex: 3, child: rightPane)
              else
                SizedBox(width: state._rightPaneWidth, child: rightPane),
              if (toolWindow != null) ...[panelDivider, toolWindow],
            ],
          );
          if (runRecoveryPrompt == null) return workbenchBody;
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

// ---------------------------------------------------------------------------
// Tool window builder
// ---------------------------------------------------------------------------

Widget? _buildToolWindow(
  _WorkbenchShellPageState state, {
  required BuildContext context,
  required AppWorkspaceStore workspace,
  required AppDraftSnapshot draft,
  required AuthorFeedbackStore authorFeedbackStore,
  required ReviewTaskStore reviewTaskStore,
  required StoryGenerationRunSnapshot storyRunSnapshot,
  required AppSettingsSnapshot settings,
  required AppSettingsFeedback settingsFeedback,
  required String? diagnosticReport,
  required AppSettingsStore settingsStore,
  required String currentSelectionPreview,
  required int guideStageIndex,
  required bool hasSceneCharacterBinding,
  required bool hasSceneWorldReference,
  required Widget? statusBanner,
}) {
  if (state._orb.activeToolPanel == null) return null;

  final isAiPanel = state._orb.activeToolPanel == WorkbenchToolPanel.ai;
  return ClipRRect(
    borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: isAiPanel ? 18 : 20,
        sigmaY: isAiPanel ? 18 : 20,
      ),
      child: Container(
        key: WorkbenchShellPage.toolWindowKey,
        width: DesktopLayoutTokens.workbenchToolWindowWidth,
        padding: const EdgeInsets.all(20),
        decoration: isAiPanel
            ? darkAiPanelDecoration(context)
            : glassPanelDecoration(context),
        child: ToolWindowPanel(
          activePanel: state._orb.activeToolPanel!,
          authorFeedbackStore: authorFeedbackStore,
          reviewTaskStore: reviewTaskStore,
          scenes: workspace.scenes,
          currentSceneId:
              workspace.currentProjectOrNull?.sceneId ?? '',
          currentChapterId:
              workspace.currentSceneOrNull?.chapterLabel ?? '',
          currentSceneLabel:
              workspace.currentSceneOrNull?.displayLocation ?? '',
          sourceRunId: state._orb.sourceRunId(
            workspace.currentProjectOrNull?.id ?? '',
          ),
          sourceRunLabel: state._orb.sourceRunLabel(),
          sceneContext: state.ref
              .watch(appSceneContextStoreProvider)
              .snapshot,
          uiState: state.widget.uiState,
          settings: settings,
          settingsFeedback: settingsFeedback,
          settingsHasPersistenceIssue:
              settingsStore.hasPersistenceIssue,
          canGenerateAi: state._orb.canGenerateAi,
          isGeneratingAi: state._orb.isGeneratingAi,
          diagnosticReport: diagnosticReport,
          aiToolMode: state._orb.aiToolMode,
          historyEntries: state.ref
              .watch(appAiHistoryStoreProvider)
              .entries,
          aiPromptController: state._aiPromptController,
          onRetrySecureStore:
              settingsStore.retrySecureStoreAccess,
          draftText: draft.text,
          currentSelectionPreview: currentSelectionPreview,
          selectionDrafts:
              List<WorkbenchAiSelectionDraft>.unmodifiable(
                state._orb.aiSelections,
              ),
          onSelectAiMode: (mode) {
            state._orb.selectAiMode(mode);
          },
          onGenerateAiSuggestion: state._generateAiSuggestion,
          onReplayAiHistory: state._replayAiHistory,
          onDeleteAiHistoryEntry: (entry) {
            state.ref
                .read(appAiHistoryStoreProvider)
                .removeEntry(entry.sequence);
          },
          onClearAiHistory: () {
            state.ref.read(appAiHistoryStoreProvider).clear();
          },
          onSyncContext: () {
            state._orb.syncContext();
          },
          onSelectScene: (scene) async {
            await state._confirmSceneSwitch(
              scene,
              () => workspace.updateCurrentScene(
                sceneId: scene.id,
                recentLocation: scene.displayLocation,
              ),
            );
          },
          onCreateScene: () => state._showSceneDialog(
            context,
            title: '新建章节',
            initialValue: '',
            onConfirm: workspace.createScene,
          ),
          onRenameScene: () => state._showSceneDialog(
            context,
            title: '重命名章节',
            initialValue:
                workspace.currentSceneOrNull?.title ?? '',
            onConfirm: workspace.renameCurrentScene,
          ),
          onDeleteScene: () => state._confirmDeleteScene(
            context,
            workspace.deleteCurrentScene,
          ),
          canDeleteScene: workspace.canDeleteCurrentScene,
          onOpenSettings: () => state._openSettingsAndRestoreAnchor(
            closeToolPanel: true,
          ),
          onShowAiMetadata: () {
            final metadata = state._orb.buildRequestMetadata();
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
          onAddCurrentSelection: state._addCurrentSelectionFromEditor,
          onEditSelectionPrompt: state._editSelectionPrompt,
          onRemoveSelection: state._removeSelection,
          // Run Center v1 parameters
          runSnapshot: storyRunSnapshot,
          isRunActive:
              storyRunSnapshot.status == StoryGenerationRunStatus.running,
          canCancelRun:
              storyRunSnapshot.status == StoryGenerationRunStatus.running,
          canRetryRun: state._orb.canRetryRun(storyRunSnapshot),
          onRetryRun: () => state._orb.retryRecoveredRun(),
          onDiscardRun: () => state._orb.discardRecoveredRun(),
          onCancelRun: () async {
            final storyRunStore = state.ref.read(storyGenerationRunStoreProvider);
            await storyRunStore.cancelCurrentRun();
          },
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
              final anchor = state._captureReturnAnchor();
              AppNavigator.push(context, AppRoutes.characters);
              state._restoreReturnAnchor(anchor);
            },
            onOpenWorldbuilding: () {
              final anchor = state._captureReturnAnchor();
              AppNavigator.push(context, AppRoutes.worldbuilding);
              state._restoreReturnAnchor(anchor);
            },
            onOpenOutline: () {
              AppNavigator.push(context, AppRoutes.worldbuilding);
            },
          ),
        ),
      ),
    ),
  );
}
