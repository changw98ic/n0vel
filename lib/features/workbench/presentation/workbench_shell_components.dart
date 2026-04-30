part of 'workbench_shell_page.dart';

class _StoryGenerationRunPanel extends StatelessWidget {
  const _StoryGenerationRunPanel({
    required this.store,
    required this.canRun,
    required this.onRun,
    required this.onForceFailure,
    required this.onCancel,
    required this.onMapReviewTasks,
  });

  final StoryGenerationRunStore store;
  final bool canRun;
  final VoidCallback onRun;
  final VoidCallback onForceFailure;
  final VoidCallback onCancel;
  final ValueChanged<StoryGenerationRunSnapshot> onMapReviewTasks;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final snapshot = store.snapshot;
        final isRunning = snapshot.status == StoryGenerationRunStatus.running;
        final canStart = canRun && !isRunning;
        final messages = _highValueMessages(snapshot.messages);
        final reviewIssueMessages = _reviewIssueMessages(snapshot);
        final palette = desktopPalette(context);
        final theme = Theme.of(context);
        return Container(
          key: WorkbenchShellPage.runSnapshotPanelKey,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.elevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.headline,
                        key: WorkbenchShellPage.runSnapshotHeadlineKey,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.stageSummary,
                        key: WorkbenchShellPage.runSnapshotStageKey,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        key: WorkbenchShellPage.runSimulationButtonKey,
                        onPressed: canStart ? onRun : null,
                        child: Text(snapshot.hasRun ? '重跑' : '运行当前场景'),
                      ),
                      OutlinedButton(
                        key: WorkbenchShellPage.failSimulationButtonKey,
                        onPressed: canStart ? onForceFailure : null,
                        child: const Text('模拟失败'),
                      ),
                      if (isRunning)
                        OutlinedButton(
                          key: WorkbenchShellPage.cancelRunButtonKey,
                          onPressed: onCancel,
                          child: const Text('停止'),
                        ),
                      if (reviewIssueMessages.isNotEmpty)
                        OutlinedButton(
                          key: WorkbenchShellPage.mapReviewTasksButtonKey,
                          onPressed: () => onMapReviewTasks(snapshot),
                          child: const Text('转为任务'),
                        ),
                    ],
                  );
                  if (constraints.maxWidth < 340) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(height: 8),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 8),
                      actions,
                    ],
                  );
                },
              ),
              if (messages.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final message in messages)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${message.title}：${_compactMessageBody(message.body)}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<StoryGenerationRunMessage> _highValueMessages(
    List<StoryGenerationRunMessage> messages,
  ) {
    const preferredKinds = {
      StoryGenerationRunMessageKind.director,
      StoryGenerationRunMessageKind.roleTurn,
      StoryGenerationRunMessageKind.beat,
      StoryGenerationRunMessageKind.review,
      StoryGenerationRunMessageKind.error,
      StoryGenerationRunMessageKind.authorFeedback,
    };
    final preferred = [
      for (final message in messages)
        if (preferredKinds.contains(message.kind)) message,
    ];
    final source = preferred.isEmpty ? messages : preferred;
    if (source.length <= 3) {
      return source;
    }
    final authorFeedbackIndex = source.indexWhere(
      (message) => message.kind == StoryGenerationRunMessageKind.authorFeedback,
    );
    final directorIndex = source.indexWhere(
      (message) => message.kind == StoryGenerationRunMessageKind.director,
    );
    if (directorIndex < 0) {
      if (authorFeedbackIndex >= 0) {
        final authorFeedback = source[authorFeedbackIndex];
        final trailing = [
          for (var i = 0; i < source.length; i++)
            if (i != authorFeedbackIndex) source[i],
        ];
        return [authorFeedback, ...trailing.sublist(trailing.length - 2)];
      }
      return source.sublist(source.length - 3);
    }
    final director = source[directorIndex];
    final authorFeedback = authorFeedbackIndex >= 0
        ? source[authorFeedbackIndex]
        : null;
    final trailing = [
      for (var i = 0; i < source.length; i++)
        if (i != directorIndex && i != authorFeedbackIndex) source[i],
    ];
    final anchors = [if (authorFeedback != null) authorFeedback, director];
    return [
      ...anchors,
      ...trailing.sublist(trailing.length - (3 - anchors.length)),
    ];
  }

  String _compactMessageBody(String body) {
    final compact = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= 96) {
      return compact;
    }
    return '${compact.substring(0, 96)}...';
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final foreground = isSelected
        ? Theme.of(context).colorScheme.onPrimary
        : palette.primary;
    final background = isSelected ? palette.primary : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolWindowPanel extends StatelessWidget {
  const _ToolWindowPanel({
    required this.activePanel,
    required this.authorFeedbackStore,
    required this.reviewTaskStore,
    required this.sceneContext,
    required this.scenes,
    required this.currentSceneId,
    required this.currentChapterId,
    required this.currentSceneLabel,
    required this.sourceRunId,
    required this.sourceRunLabel,
    required this.uiState,
    required this.settings,
    required this.settingsFeedback,
    required this.settingsHasPersistenceIssue,
    required this.canGenerateAi,
    required this.isGeneratingAi,
    required this.diagnosticReport,
    required this.aiToolMode,
    required this.historyEntries,
    required this.aiPromptController,
    required this.onRetrySecureStore,
    required this.draftText,
    required this.currentSelectionPreview,
    required this.selectionDrafts,
    required this.onSelectAiMode,
    required this.onAddCurrentSelection,
    required this.onEditSelectionPrompt,
    required this.onRemoveSelection,
    required this.onGenerateAiSuggestion,
    required this.onReplayAiHistory,
    required this.onDeleteAiHistoryEntry,
    required this.onClearAiHistory,
    required this.onSyncContext,
    required this.onSelectScene,
    required this.onCreateScene,
    required this.onRenameScene,
    required this.onDeleteScene,
    required this.canDeleteScene,
    required this.onOpenSettings,
  });

  final WorkbenchToolPanel activePanel;
  final AuthorFeedbackStore authorFeedbackStore;
  final ReviewTaskStore reviewTaskStore;
  final AppSceneContextSnapshot sceneContext;
  final List<SceneRecord> scenes;
  final String currentSceneId;
  final String currentChapterId;
  final String currentSceneLabel;
  final String? sourceRunId;
  final String? sourceRunLabel;
  final WorkbenchUiState uiState;
  final AppSettingsSnapshot settings;
  final AppSettingsFeedback settingsFeedback;
  final bool settingsHasPersistenceIssue;
  final bool canGenerateAi;
  final bool isGeneratingAi;
  final String? diagnosticReport;
  final AiToolMode aiToolMode;
  final List<AiHistoryEntry> historyEntries;
  final TextEditingController aiPromptController;
  final Future<void> Function() onRetrySecureStore;
  final String draftText;
  final String currentSelectionPreview;
  final List<_AiSelectionDraft> selectionDrafts;
  final ValueChanged<AiToolMode> onSelectAiMode;
  final VoidCallback onAddCurrentSelection;
  final ValueChanged<int> onEditSelectionPrompt;
  final ValueChanged<int> onRemoveSelection;
  final VoidCallback onGenerateAiSuggestion;
  final ValueChanged<AiHistoryEntry> onReplayAiHistory;
  final ValueChanged<AiHistoryEntry> onDeleteAiHistoryEntry;
  final VoidCallback onClearAiHistory;
  final VoidCallback onSyncContext;
  final ValueChanged<SceneRecord> onSelectScene;
  final VoidCallback onCreateScene;
  final VoidCallback onRenameScene;
  final VoidCallback onDeleteScene;
  final bool canDeleteScene;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final diagnosticText = diagnosticReport;
    String selectionPreviewForDraft(_AiSelectionDraft selection) {
      final safeStart = selection.start.clamp(0, draftText.length).toInt();
      final safeEnd = selection.end.clamp(safeStart, draftText.length).toInt();
      final excerpt = draftText.substring(safeStart, safeEnd).trim();
      if (excerpt.isEmpty) {
        return '尚未选择正文片段';
      }
      if (excerpt.length <= 36) {
        return excerpt;
      }
      return '${excerpt.substring(0, 36)}...';
    }

    final (title, description) = switch (activePanel) {
      WorkbenchToolPanel.resources => ('资料窗口', '角色摘要 / 世界观摘要 / 当前场景资料会显示在这里。'),
      WorkbenchToolPanel.ai => ('AI 工具窗口', '工具模式 / 历史区 / 输入区会在这里展开。'),
      WorkbenchToolPanel.feedback => ('作者反馈', '记录审稿意见、修订请求和采纳/驳回决策。'),
      WorkbenchToolPanel.reviewTasks => ('审查任务', '把审查发现转成可跟进的修订任务。'),
      WorkbenchToolPanel.settings => ('设置快捷面板', '当前提供方、模型、界面模式和快速入口会显示在这里。'),
    };

    if (activePanel == WorkbenchToolPanel.ai) {
      final hasSettingsWarning =
          settingsHasPersistenceIssue && settingsFeedback.title != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(description, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasSettingsWarning
                        ? 'AI 配置异常'
                        : canGenerateAi
                        ? 'AI 已就绪'
                        : 'AI 功能暂不可用',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasSettingsWarning
                        ? settingsFeedback.title!
                        : canGenerateAi
                        ? '当前模型：${settings.model}'
                        : '请先前往设置补全密钥与提供方配置。',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (hasSettingsWarning) ...[
                    const SizedBox(height: 8),
                    Text(
                      settingsFeedback.message ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: appDangerColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          key: WorkbenchShellPage.aiRetrySecureStoreButtonKey,
                          onPressed: () => onRetrySecureStore(),
                          child: const Text('重试配置'),
                        ),
                        TextButton(
                          onPressed: onOpenSettings,
                          child: const Text('检查设置'),
                        ),
                        if (diagnosticText != null)
                          TextButton(
                            key: WorkbenchShellPage.aiCopyDiagnosticButtonKey,
                            onPressed: () => copyDiagnosticToClipboard(
                              context,
                              diagnosticText,
                            ),
                            child: const Text('复制诊断'),
                          ),
                      ],
                    ),
                  ] else if (!canGenerateAi) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: onOpenSettings,
                      child: const Text('前往设置'),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text(
                      '当前模式：${aiToolMode == AiToolMode.rewrite ? '改写' : '续写'}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          key: WorkbenchShellPage.aiRewriteModeButtonKey,
                          label: const Text('改写'),
                          selected: aiToolMode == AiToolMode.rewrite,
                          onSelected: (_) => onSelectAiMode(AiToolMode.rewrite),
                        ),
                        ChoiceChip(
                          key: WorkbenchShellPage.aiContinueModeButtonKey,
                          label: const Text('续写'),
                          selected: aiToolMode == AiToolMode.continueWriting,
                          onSelected: (_) =>
                              onSelectAiMode(AiToolMode.continueWriting),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: WorkbenchShellPage.aiPromptFieldKey,
                      controller: aiPromptController,
                      decoration: InputDecoration(
                        hintText: aiToolMode == AiToolMode.rewrite
                            ? '输入修改意图，例如：压缩节奏'
                            : '输入续写意图，例如：补一段',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: WorkbenchShellPage.aiClearPromptButtonKey,
                        onPressed: () {
                          aiPromptController.clear();
                        },
                        child: const Text('清空当前意图'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('多处选区', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      key: WorkbenchShellPage.aiSelectionListKey,
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.elevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前正文选区：$currentSelectionPreview',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            key: WorkbenchShellPage.aiAddSelectionButtonKey,
                            onPressed: aiToolMode == AiToolMode.rewrite
                                ? onAddCurrentSelection
                                : null,
                            child: const Text('添加当前选区'),
                          ),
                          if (aiToolMode != AiToolMode.rewrite)
                            Text(
                              '多处选区仅用于改写模式；续写仍按整段生成。',
                              style: theme.textTheme.bodySmall,
                            )
                          else if (selectionDrafts.isEmpty)
                            Text(
                              '还没有加入多处改写片段。可在正文中先选中一段，再加入列表。',
                              style: theme.textTheme.bodySmall,
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (
                                  var index = 0;
                                  index < selectionDrafts.length;
                                  index += 1
                                ) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: palette.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: palette.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '片段 ${index + 1} · ${selectionDrafts[index].start}-${selectionDrafts[index].end}',
                                          key:
                                              WorkbenchShellPage.aiSelectionSummaryKey(
                                                index,
                                              ),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          selectionPreviewForDraft(
                                            selectionDrafts[index],
                                          ),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '意图：${selectionDrafts[index].prompt}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            TextButton(
                                              key:
                                                  WorkbenchShellPage.aiSelectionEditButtonKey(
                                                    index,
                                                  ),
                                              onPressed: () =>
                                                  onEditSelectionPrompt(index),
                                              child: const Text('编辑意图'),
                                            ),
                                            TextButton(
                                              key:
                                                  WorkbenchShellPage.aiSelectionRemoveButtonKey(
                                                    index,
                                                  ),
                                              onPressed: () =>
                                                  onRemoveSelection(index),
                                              child: const Text('移除'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('历史区', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.elevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: historyEntries.isEmpty
                          ? Text('暂无 AI 历史', style: theme.textTheme.bodySmall)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final entry in historyEntries) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: palette.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: palette.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextButton(
                                          key:
                                              WorkbenchShellPage.aiHistoryPromptKey(
                                                entry.sequence,
                                              ),
                                          onPressed: () {
                                            aiPromptController.text =
                                                entry.prompt;
                                            aiPromptController.selection =
                                                TextSelection.collapsed(
                                                  offset: entry.prompt.length,
                                                );
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            alignment: Alignment.centerLeft,
                                          ),
                                          child: Text(
                                            '${entry.mode} · ${entry.prompt}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                        Text(
                                          '第${entry.sequence}次 · ${identical(entry, historyEntries.first) ? '刚刚生成' : '较早记录'}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            GestureDetector(
                                              key:
                                                  WorkbenchShellPage.aiHistoryReplayButtonKey(
                                                    entry.sequence,
                                                  ),
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onTap: () =>
                                                  onReplayAiHistory(entry),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Text(
                                                  '再次执行',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              key:
                                                  WorkbenchShellPage.aiHistoryDeleteButtonKey(
                                                    entry.sequence,
                                                  ),
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onTap: () =>
                                                  onDeleteAiHistoryEntry(entry),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Text(
                                                  '删除第${entry.sequence}次',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    key: WorkbenchShellPage
                                        .aiClearHistoryButtonKey,
                                    onPressed: onClearAiHistory,
                                    child: const Text('清空历史'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (canGenerateAi) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: WorkbenchShellPage.aiGenerateButtonKey,
                onPressed: isGeneratingAi ? null : onGenerateAiSuggestion,
                child: Text(
                  isGeneratingAi
                      ? '生成中…'
                      : aiToolMode == AiToolMode.rewrite
                      ? '生成改写建议'
                      : '生成续写建议',
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (activePanel == WorkbenchToolPanel.feedback) {
      return AuthorFeedbackPanel(
        store: authorFeedbackStore,
        chapterId: currentChapterId,
        sceneId: currentSceneId,
        sceneLabel: currentSceneLabel,
        sourceRunId: sourceRunId,
        sourceRunLabel: sourceRunLabel,
      );
    }

    if (activePanel == WorkbenchToolPanel.reviewTasks) {
      return ReviewTaskPanel(store: reviewTaskStore, title: title);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(description, style: theme.textTheme.bodySmall),
                if (activePanel == WorkbenchToolPanel.resources) ...[
                  const SizedBox(height: 16),
                  Text(
                    sceneContext.sceneSummary,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final scene in scenes)
                        ChoiceChip(
                          label: Text(scene.title),
                          selected: scene.id == currentSceneId,
                          onSelected: (_) => onSelectScene(scene),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        key: WorkbenchShellPage.createSceneButtonKey,
                        onPressed: onCreateScene,
                        child: const Text('新建场景'),
                      ),
                      TextButton(
                        key: WorkbenchShellPage.renameSceneButtonKey,
                        onPressed: onRenameScene,
                        child: const Text('重命名场景'),
                      ),
                      TextButton(
                        key: WorkbenchShellPage.deleteSceneButtonKey,
                        onPressed: canDeleteScene ? onDeleteScene : null,
                        child: const Text('删除场景'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onSyncContext,
                    child: const Text('同步到工作台'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiState == WorkbenchUiState.missingCharacterReference
                        ? '角色引用已失效'
                        : sceneContext.characterSummary,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiState == WorkbenchUiState.missingWorldReference
                        ? '世界观引用已失效'
                        : sceneContext.worldSummary,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
                if (activePanel == WorkbenchToolPanel.ai) ...[],
                if (activePanel == WorkbenchToolPanel.settings) ...[
                  const SizedBox(height: 16),
                  Text(
                    settingsHasPersistenceIssue &&
                            settingsFeedback.title != null
                        ? settingsFeedback.title!
                        : settings.hasApiKey
                        ? '提供方已配置'
                        : '提供方未配置',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settingsHasPersistenceIssue &&
                            settingsFeedback.message != null
                        ? settingsFeedback.message!
                        : settings.hasApiKey
                        ? '${settings.providerName} · ${settings.model}'
                        : '请先补全密钥与提供方配置。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: settingsHasPersistenceIssue
                          ? appDangerColor
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.themePreference == AppThemePreference.dark
                        ? '当前界面：深色模式'
                        : '当前界面：浅色模式',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (settingsHasPersistenceIssue)
                        TextButton(
                          key: WorkbenchShellPage
                              .settingsRetrySecureStoreButtonKey,
                          onPressed: () => onRetrySecureStore(),
                          child: const Text('重试配置'),
                        ),
                      if (settingsHasPersistenceIssue && diagnosticText != null)
                        TextButton(
                          key: WorkbenchShellPage
                              .settingsCopyDiagnosticButtonKey,
                          onPressed: () => copyDiagnosticToClipboard(
                            context,
                            diagnosticText,
                          ),
                          child: const Text('复制诊断'),
                        ),
                      TextButton(
                        onPressed: onOpenSettings,
                        child: const Text('打开完整设置'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: desktopPalette(context).elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: desktopPalette(context).border),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      activePanel == WorkbenchToolPanel.settings
                          ? settingsHasPersistenceIssue &&
                                    settingsFeedback.title != null
                                ? '检测到配置异常，建议先进入完整设置处理后再继续使用 AI。'
                                : '从这里快速确认主题、模型和密钥配置，再进入完整设置做细调。'
                          : '',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkbenchDialogField extends StatelessWidget {
  const _WorkbenchDialogField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.title,
    required this.message,
    required this.accentColor,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: accentColor, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
