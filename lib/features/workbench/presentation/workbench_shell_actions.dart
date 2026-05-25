part of 'workbench_shell_page.dart';

extension _WorkbenchShellActions on _WorkbenchShellPageState {
  Future<void> _showSceneDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required ValueChanged<String> onConfirm,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      barrierLabel: '关闭',
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: title,
          description: '创建后会出现在当前项目的章节列表中，并立即可在工作台中继续写作。',
          body: _WorkbenchDialogField(
            label: '章节标题',
            child: TextField(
              key: WorkbenchShellPage.sceneTitleFieldKey,
              controller: controller,
              decoration: const InputDecoration(hintText: '输入章节标题'),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (result == null || result.trim().isEmpty) {
      return;
    }
    onConfirm(result);
  }

  Future<void> _confirmDeleteScene(
    BuildContext context,
    VoidCallback onConfirm,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierLabel: '关闭',
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: '删除章节',
          description: '删除后会从当前项目的章节列表中移除，工作台会自动切换到相邻章节，并同步刷新相关引用摘要。',
          body: _WorkbenchDialogField(
            label: '当前章节',
            child: Text(
              ref.read(appWorkspaceStoreProvider).currentScene.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (shouldDelete == true) {
      onConfirm();
    }
  }

  Future<void> _confirmSceneSwitch(
    SceneRecord targetScene,
    VoidCallback onConfirm,
  ) async {
    final workspace = ref.read(appWorkspaceStoreProvider);
    final storyRunStore = ref.read(storyGenerationRunStoreProvider);
    final runCommands = ref.read(runCommandsProvider);
    final runSnapshot = storyRunStore.snapshot;

    // If target scene is already current, no prompt/no-op
    if (targetScene.id == workspace.currentScene.id) {
      onConfirm();
      return;
    }

    final isRunActive = runSnapshot.status == StoryGenerationRunStatus.running;
    final isEditorDirty = _isEditorDirty;

    // If no active run and editor is clean, allow switch without prompt
    if (!isRunActive && !isEditorDirty) {
      onConfirm();
      return;
    }

    // Build dialog description based on what's at risk
    final descriptionParts = <String>[];
    if (isEditorDirty) {
      descriptionParts.add('当前正文有未保存的修改，切换章节将丢失这些修改。');
    }
    if (isRunActive) {
      descriptionParts.add('当前章节有 AI 试写正在运行，切换章节将取消此次运行。');
    }
    final description = descriptionParts.join(
      isEditorDirty && isRunActive ? '\n' : '',
    );

    final shouldSwitch = await showDialog<bool>(
      context: context,
      barrierLabel: '关闭',
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: '切换章节',
          description: description,
          body: isRunActive
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: desktopPalette(dialogContext).glassCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '当前：${runSnapshot.headline}',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        runSnapshot.summary,
                        style: Theme.of(dialogContext).textTheme.bodySmall
                            ?.copyWith(
                              color: desktopPalette(
                                dialogContext,
                              ).secondaryText,
                            ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('留在当前章节'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: appDangerColor),
              child: isEditorDirty && isRunActive
                  ? const Text('放弃修改并取消运行，切换')
                  : isEditorDirty
                  ? const Text('放弃修改并切换')
                  : const Text('取消运行并切换'),
            ),
          ],
        );
      },
    );
    if (shouldSwitch == true) {
      if (isRunActive) {
        await runCommands.cancelCurrentRun();
      }
      onConfirm();
    }
  }

  Future<void> _openSettingsAndRestoreAnchor({
    bool closeToolPanel = false,
  }) async {
    final anchor = _captureReturnAnchor();
    if (closeToolPanel) {
      _orb.closeToolPanel();
    }
    await AppNavigator.push(context, AppRoutes.settings);
    if (!mounted) {
      return;
    }
    await _restoreReturnAnchor(anchor);
  }

  Future<void> _openBibleAndRestoreAnchor() async {
    final anchor = _captureReturnAnchor();
    await AppNavigator.push(context, AppRoutes.bible);
    if (!mounted) {
      return;
    }
    await _restoreReturnAnchor(anchor);
  }

  Future<void> _openReadingMode() async {
    final workspace = ref.read(appWorkspaceStoreProvider);
    final draftStore = ref.read(appDraftStoreProvider);
    final anchor = _captureReturnAnchor();
    final documents = <ReadingSceneDocument>[];
    for (final scene in workspace.scenes) {
      final scopeId = '${workspace.currentProject.id}::${scene.id}';
      final text = await draftStore.readTextForScope(scopeId);
      documents.add(
        ReadingSceneDocument(
          sceneId: scene.id,
          locationLabel: scene.displayLocation,
          text: text,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    await AppNavigator.push(
      context,
      AppRoutes.reading,
      arguments: ReadingSessionData(
        projectTitle: workspace.currentProject.title,
        initialSceneId: workspace.currentProject.sceneId,
        documents: documents,
      ),
    );
    if (!mounted) {
      return;
    }
    await _restoreReturnAnchor(anchor);
  }

  WorkbenchEditorReturnAnchor _captureReturnAnchor() {
    final workspace = ref.read(appWorkspaceStoreProvider);
    final selection = clampWorkbenchEditorSelection(
      _draftController?.selection ?? _lastEditorSelection,
      _draftController?.text.length ?? 0,
    );
    final scrollOffset = _editorScrollController.hasClients
        ? _editorScrollController.offset
        : 0.0;
    return WorkbenchEditorReturnAnchor(
      sceneId: workspace.currentProjectOrNull?.sceneId ?? '',
      selection: selection,
      scrollOffset: scrollOffset,
      expectedText: _draftController?.text ?? '',
    );
  }

  Future<void> _restoreReturnAnchor(WorkbenchEditorReturnAnchor anchor) async {
    final workspace = ref.read(appWorkspaceStoreProvider);
    final draftStore = ref.read(appDraftStoreProvider);
    var pendingAnchor = anchor;
    final projectId = workspace.currentProjectOrNull?.id ?? '';
    final sceneId = workspace.currentProjectOrNull?.sceneId ?? '';
    if (projectId.isEmpty || sceneId != anchor.sceneId) {
      final targetScene = workspace.scenes.where(
        (scene) => scene.id == anchor.sceneId,
      );
      if (targetScene.isNotEmpty && projectId.isNotEmpty) {
        final scene = targetScene.first;
        final targetScopeId = '$projectId::${scene.id}';
        pendingAnchor = WorkbenchEditorReturnAnchor(
          sceneId: anchor.sceneId,
          selection: anchor.selection,
          scrollOffset: anchor.scrollOffset,
          expectedText: await draftStore.readTextForScope(targetScopeId),
        );
        workspace.updateCurrentScene(
          sceneId: scene.id,
          recentLocation: scene.displayLocation,
        );
      }
    }
    _pendingReturnAnchor = pendingAnchor;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeApplyPendingReturnAnchor(),
    );
  }

  void _maybeApplyPendingReturnAnchor() {
    final pendingAnchor = _pendingReturnAnchor;
    if (!mounted || _draftController == null || pendingAnchor == null) {
      return;
    }
    final workspace = ref.read(appWorkspaceStoreProvider);
    if ((workspace.currentProjectOrNull?.sceneId ?? '') !=
        pendingAnchor.sceneId) {
      return;
    }
    final controller = _draftController!;
    if (controller.text != pendingAnchor.expectedText) {
      return;
    }
    final clampedSelection = clampWorkbenchEditorSelection(
      pendingAnchor.selection,
      controller.text.length,
    );
    controller.selection = clampedSelection;
    _lastEditorSelection = clampedSelection;
    if (_editorScrollController.hasClients) {
      final maxOffset = _editorScrollController.position.maxScrollExtent;
      final targetOffset = pendingAnchor.scrollOffset
          .clamp(0.0, maxOffset)
          .toDouble();
      _editorScrollController.jumpTo(targetOffset);
    }
    _draftFocusNode.requestFocus();
    _pendingReturnAnchor = null;
  }

  TextSelection? _normalizedEditorSelection(String text) {
    final controller = _draftController;
    if (controller == null) {
      return null;
    }
    final selection = clampWorkbenchEditorSelection(
      controller.selection,
      text.length,
    );
    if (!selection.isValid || selection.isCollapsed) {
      return null;
    }
    return TextSelection(
      baseOffset: selection.start,
      extentOffset: selection.end,
    );
  }

  Future<void> _addCurrentSelectionFromEditor() async {
    final controller = _draftController;
    if (controller == null) {
      return;
    }
    final selection = _normalizedEditorSelection(controller.text);
    if (selection == null) {
      await _showMessageDialog(
        title: '请先选中正文片段',
        message: '在正文中框选一段内容后，再把它加入多处改写列表。',
      );
      return;
    }
    final prompt = _aiPromptController.text.trim().isEmpty
        ? '调整语气与节奏'
        : _aiPromptController.text.trim();
    _orb.addSelection(
      WorkbenchAiSelectionDraft(
        start: selection.start,
        end: selection.end,
        prompt: prompt,
      ),
    );
    _aiPromptController.clear();
    _draftFocusNode.requestFocus();
  }

  Future<void> _editSelectionPrompt(int index) async {
    final current = _orb.aiSelections[index];
    final controller = TextEditingController(text: current.prompt);
    final nextPrompt = await showDialog<String>(
      context: context,
      barrierLabel: '关闭',
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: '编辑该段修改意图',
          width: 520,
          body: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '输入这段的单独修改要求'),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (nextPrompt == null || nextPrompt.isEmpty) {
      return;
    }
    _orb.updateSelectionPrompt(index, nextPrompt);
  }

  void _removeSelection(int index) {
    _orb.removeSelection(index);
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      barrierLabel: '关闭',
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: title,
          width: 460,
          body: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('返回正文'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOverlappingSelectionsDialog() async {
    await _showMessageDialog(
      title: '多处选区重叠',
      message: '当前请求未发出。请取消或合并重叠选区后再继续生成改写建议。',
    );
  }

  Future<void> _generateAiSuggestion() async {
    final prompt = _aiPromptController.text.trim();
    try {
      final command = await _orb.prepareAiGeneration(prompt);
      if (command == null || !mounted) return;
      switch (command) {
        case ShowAiNotReady():
          await _showMessageDialog(
            title: '生成候选稿前需要连接模型服务',
            message: '当前章节仍可继续编辑；需要 AI 候选稿时，请先连接可用的模型服务并处理配置异常。',
          );
        case ShowAiOverlappingSelections():
          await _showOverlappingSelectionsDialog();
        case ShowAiReview():
          await showAiReviewDialog(
            context: context,
            reviewTitle: command.reviewTitle,
            historyPrompt: command.historyPrompt,
            blocks: command.blocks,
            metadata: command.metadata,
            continueMode: command.continueMode,
            clearSelectionsOnAccept: command.clearSelectionsOnAccept,
            draftStore: ref.read(appDraftStoreProvider),
            versionStore: ref.read(appVersionStoreProvider),
            historyStore: ref.read(appAiHistoryStoreProvider),
            aiController: _orb.aiController,
            correlationId: command.correlationId,
            onAccepted: () {
              _orb.recordAiReviewDecision(
                status: AuthorFeedbackStatus.accepted,
                historyPrompt: command.historyPrompt,
                correlationId: command.correlationId,
              );
              if (command.clearSelectionsOnAccept) {
                _orb.clearSelections();
              }
              _draftFocusNode.requestFocus();
            },
            onRejected: () {
              _orb.recordAiReviewDecision(
                status: AuthorFeedbackStatus.rejected,
                historyPrompt: command.historyPrompt,
                correlationId: command.correlationId,
              );
            },
          );
      }
    } on AiRequestException catch (error) {
      await _showMessageDialog(title: error.title, message: error.message);
    }
  }

  Future<void> _replayAiHistory(AiHistoryEntry entry) async {
    _aiPromptController.text = entry.prompt;
    _aiPromptController.selection = TextSelection.collapsed(
      offset: entry.prompt.length,
    );
    try {
      final command = await _orb.prepareAiReplay(entry);
      if (command == null || !mounted) return;
      switch (command) {
        case ShowAiReplayReview():
          await showAiReviewDialog(
            context: context,
            reviewTitle: command.reviewTitle,
            historyPrompt: command.historyPrompt,
            blocks: command.blocks,
            metadata: command.metadata,
            continueMode: command.continueMode,
            clearSelectionsOnAccept: false,
            draftStore: ref.read(appDraftStoreProvider),
            versionStore: ref.read(appVersionStoreProvider),
            historyStore: ref.read(appAiHistoryStoreProvider),
            aiController: _orb.aiController,
            correlationId: command.correlationId,
            onAccepted: () {
              _orb.recordAiReviewDecision(
                status: AuthorFeedbackStatus.accepted,
                historyPrompt: command.historyPrompt,
                correlationId: command.correlationId,
              );
              _draftFocusNode.requestFocus();
            },
            onRejected: () {
              _orb.recordAiReviewDecision(
                status: AuthorFeedbackStatus.rejected,
                historyPrompt: command.historyPrompt,
                correlationId: command.correlationId,
              );
            },
          );
      }
    } on AiRequestException catch (error) {
      await _showMessageDialog(title: error.title, message: error.message);
    }
  }
}
