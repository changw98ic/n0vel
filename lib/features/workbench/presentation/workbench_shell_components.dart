part of 'workbench_shell_page.dart';

class _CreationGuideCard extends StatelessWidget {
  const _CreationGuideCard({
    required this.currentStageIndex,
    required this.hasCharacters,
    required this.hasWorldNodes,
    required this.hasSceneSummary,
    required this.hasDraft,
    required this.hasSceneCharacterBinding,
    required this.hasSceneWorldReference,
    required this.hasRun,
    required this.onOpenCharacters,
    required this.onOpenWorldbuilding,
    required this.onOpenOutline,
  });

  final int currentStageIndex;
  final bool hasCharacters;
  final bool hasWorldNodes;
  final bool hasSceneSummary;
  final bool hasDraft;
  final bool hasSceneCharacterBinding;
  final bool hasSceneWorldReference;
  final bool hasRun;
  final VoidCallback onOpenCharacters;
  final VoidCallback onOpenWorldbuilding;
  final VoidCallback onOpenOutline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final steps = [
      const _GuideStep('作品设定', true),
      _GuideStep('人物 / 世界观', hasCharacters && hasWorldNodes),
      _GuideStep('大纲 / 场景目标', hasSceneSummary),
      _GuideStep('本场资料', hasSceneCharacterBinding && hasSceneWorldReference),
      _GuideStep('生成候选稿', hasDraft || hasRun),
      _GuideStep('改稿 / 定稿', hasRun),
    ];
    final currentStep = steps[currentStageIndex.clamp(0, steps.length - 1)];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: appPanelDecoration(context, color: palette.surface),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.flag_outlined, size: 18, color: _appAccentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('创作向导', style: theme.textTheme.titleSmall),
                Text(
                  '当前：${currentStep.label}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                for (var index = 0; index < steps.length; index += 1)
                  Icon(
                    steps[index].done
                        ? Icons.check_circle
                        : index == currentStageIndex
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                    size: 13,
                    color: steps[index].done
                        ? appSuccessColor
                        : index == currentStageIndex
                        ? _appAccentColor
                        : theme.disabledColor,
                    semanticLabel: steps[index].label,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: onOpenCharacters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('人物'),
              ),
              TextButton(
                onPressed: onOpenWorldbuilding,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('世界观'),
              ),
              TextButton(
                onPressed: onOpenOutline,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('资料'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep(this.label, this.done);

  final String label;
  final bool done;
}

String? _candidateDraftText(StoryGenerationRunSnapshot snapshot) {
  for (final message in snapshot.messages.reversed) {
    if (message.kind == StoryGenerationRunMessageKind.editorial &&
        message.body.trim().isNotEmpty) {
      return message.body.trim();
    }
  }
  return null;
}

class _CandidateDraftCard extends StatelessWidget {
  const _CandidateDraftCard({
    required this.text,
    required this.onAccept,
    required this.onRevise,
    required this.onDismiss,
  });

  final String text;
  final VoidCallback onAccept;
  final VoidCallback onRevise;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final preview = _candidatePreview(text);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appSuccessColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('采纳到正文'),
              ),
              OutlinedButton(
                onPressed: onRevise,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('继续修改'),
              ),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('放弃'),
              ),
            ],
          );
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI 候选稿', style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                preview,
                style: theme.textTheme.bodySmall,
                maxLines: constraints.maxWidth < 520 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 6), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 8),
              actions,
            ],
          );
        },
      ),
    );
  }
}

String _candidatePreview(String text) {
  final normalized = text.trim();
  if (normalized.length <= 240) {
    return normalized;
  }
  return '${normalized.substring(0, 240)}...';
}

class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StoryGenerationRunPanel extends StatelessWidget {
  const _StoryGenerationRunPanel({
    required this.store,
    required this.canRun,
    required this.dismissedCandidateText,
    required this.onRun,
    required this.onForceFailure,
    required this.onCancel,
    required this.onAcceptCandidate,
    required this.onReviseCandidate,
    required this.onDismissCandidate,
    required this.onMapReviewTasks,
  });

  final StoryGenerationRunStore store;
  final bool canRun;
  final String? dismissedCandidateText;
  final VoidCallback onRun;
  final VoidCallback onForceFailure;
  final VoidCallback onCancel;
  final ValueChanged<String> onAcceptCandidate;
  final ValueChanged<String> onReviseCandidate;
  final ValueChanged<String> onDismissCandidate;
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
        final candidateDraft = _candidateDraftText(snapshot);
        final showCandidateDraft =
            candidateDraft != null &&
            candidateDraft.trim().isNotEmpty &&
            candidateDraft.trim() != dismissedCandidateText?.trim();
        final palette = desktopPalette(context);
        final theme = Theme.of(context);
        return Container(
          key: WorkbenchShellPage.runSnapshotPanelKey,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      Text(
                        snapshot.stageSummary,
                        key: WorkbenchShellPage.runSnapshotStageKey,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
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
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(snapshot.hasRun ? '重新试写' : '让 AI 写这一场'),
                      ),
                      OutlinedButton(
                        key: WorkbenchShellPage.failSimulationButtonKey,
                        onPressed: canStart ? onForceFailure : null,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('标记未完成'),
                      ),
                      if (isRunning)
                        OutlinedButton(
                          key: WorkbenchShellPage.cancelRunButtonKey,
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('停止'),
                        ),
                      if (reviewIssueMessages.isNotEmpty)
                        OutlinedButton(
                          key: WorkbenchShellPage.mapReviewTasksButtonKey,
                          onPressed: () => onMapReviewTasks(snapshot),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
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
              if (showCandidateDraft) ...[
                const SizedBox(height: 10),
                _CandidateDraftCard(
                  text: candidateDraft,
                  onAccept: () => onAcceptCandidate(candidateDraft),
                  onRevise: () => onReviseCandidate(candidateDraft),
                  onDismiss: () => onDismissCandidate(candidateDraft),
                ),
              ],
              if (messages.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final message in messages)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${message.title}：${_compactMessageBody(message.body)}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
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
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final foreground = isSelected
        ? theme.colorScheme.onPrimary
        : palette.primary;
    final background = isSelected ? palette.primary : Colors.transparent;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(10),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return isSelected
                ? Colors.white.withValues(alpha: 0.14)
                : palette.subtle.withValues(alpha: 0.86);
          }
          if (states.contains(WidgetState.hovered)) {
            return isSelected
                ? Colors.white.withValues(alpha: 0.08)
                : palette.subtle.withValues(alpha: 0.56);
          }
          return null;
        }),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? palette.borderStrong : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
    required this.onShowAiMetadata,
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
  final VoidCallback onShowAiMetadata;

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
      WorkbenchToolPanel.resources => ('场景资料', '这一场会使用的人物、世界观和场景摘要会显示在这里。'),
      WorkbenchToolPanel.ai => ('AI 写作助手', '选择写作动作、查看历史记录，并告诉 AI 你想怎么改。'),
      WorkbenchToolPanel.feedback => ('作者反馈', '记录审稿意见、修订请求和采纳/驳回决策。'),
      WorkbenchToolPanel.reviewTasks => ('改稿任务', '把问题检查结果变成可跟进的改稿任务。'),
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
                        : 'AI 暂不可用',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasSettingsWarning
                        ? settingsFeedback.title!
                        : canGenerateAi
                        ? '当前模型：${settings.model}'
                        : '请先在设置里补全密钥与模型提供方。',
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onShowAiMetadata,
                        child: const Text('查看请求配置'),
                      ),
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
                          key: ValueKey<String>(
                            'workbench-scene-chip-${scene.id}',
                          ),
                          label: Text(
                            scene.title,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          tooltip: scene.title,
                          selected: scene.id == currentSceneId,
                          onSelected: (_) {
                            if (scene.id != currentSceneId) {
                              onSelectScene(scene);
                            }
                          },
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
                    child: const Text('刷新当前场景资料'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiState == WorkbenchUiState.missingCharacterReference
                        ? '出场人物需要重新确认'
                        : sceneContext.characterSummary,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiState == WorkbenchUiState.missingWorldReference
                        ? '世界观资料需要重新确认'
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
                if (activePanel == WorkbenchToolPanel.settings)
                  AppPopover(
                    child: Text(
                      settingsHasPersistenceIssue &&
                              settingsFeedback.title != null
                          ? '检测到配置异常，建议先进入完整设置处理后再继续使用 AI。'
                          : '从这里快速确认主题、模型和密钥配置，再进入完整设置做细调。',
                      style: theme.textTheme.bodySmall,
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

class _GenerationProcessSheetContent extends StatelessWidget {
  const _GenerationProcessSheetContent({
    required this.snapshot,
    required this.simulation,
    required this.fallbackStatus,
    required this.failureMode,
  });

  final StoryGenerationRunSnapshot snapshot;
  final AppSimulationSnapshot simulation;
  final SimulationStatus fallbackStatus;
  final bool failureMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final effectiveStatus = simulation.status == SimulationStatus.none
        ? fallbackStatus
        : simulation.status;
    final accent = failureMode || effectiveStatus == SimulationStatus.failed
        ? appDangerColor
        : effectiveStatus == SimulationStatus.completed
        ? appSuccessColor
        : _appAccentColor;
    final messages = snapshot.messages.isEmpty
        ? <StoryGenerationRunMessage>[
            StoryGenerationRunMessage(
              title: snapshot.headline,
              body: snapshot.stageSummary,
              kind: StoryGenerationRunMessageKind.status,
            ),
          ]
        : snapshot.messages;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_outlined, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.headline,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.stageSummary.trim().isEmpty
                            ? simulation.summary
                            : snapshot.stageSummary,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GenerationPill(
                label: '状态',
                value: _generationStatusLabel(effectiveStatus),
                accent: accent,
              ),
              _GenerationPill(
                label: '场景',
                value: snapshot.sceneLabel.trim().isEmpty
                    ? simulation.sceneLabel
                    : snapshot.sceneLabel,
                accent: _appAccentColor,
              ),
              if (snapshot.turnLabel.trim().isNotEmpty)
                _GenerationPill(
                  label: '轮次',
                  value: snapshot.turnLabel,
                  accent: _appAccentColor,
                ),
            ],
          ),
          if (snapshot.participants.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('参与角色', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final participant in snapshot.participants)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GenerationProcessRow(
                  title: '${participant.name} · ${participant.role}',
                  body: participant.statusSummary.trim().isEmpty
                      ? participant.summary
                      : participant.statusSummary,
                  accent: _appAccentColor,
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text('生成记录', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GenerationProcessRow(
                title: '${_messageKindLabel(message.kind)} · ${message.title}',
                body: message.body,
                accent: _messageKindAccent(message.kind, accent),
              ),
            ),
          if (snapshot.errorDetail.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _GenerationProcessRow(
              title: '错误详情',
              body: snapshot.errorDetail,
              accent: appDangerColor,
            ),
          ],
        ],
      ),
    );
  }

  String _generationStatusLabel(SimulationStatus status) {
    return switch (status) {
      SimulationStatus.none => '未开始',
      SimulationStatus.running => '生成中',
      SimulationStatus.completed => '已完成',
      SimulationStatus.failed => '未完成',
    };
  }

  String _messageKindLabel(StoryGenerationRunMessageKind kind) {
    return switch (kind) {
      StoryGenerationRunMessageKind.status => '状态',
      StoryGenerationRunMessageKind.director => '导演',
      StoryGenerationRunMessageKind.roleTurn => '角色',
      StoryGenerationRunMessageKind.beat => '节拍',
      StoryGenerationRunMessageKind.editorial => '候选稿',
      StoryGenerationRunMessageKind.review => '审查',
      StoryGenerationRunMessageKind.authorFeedback => '作者反馈',
      StoryGenerationRunMessageKind.error => '错误',
    };
  }

  Color _messageKindAccent(StoryGenerationRunMessageKind kind, Color fallback) {
    return switch (kind) {
      StoryGenerationRunMessageKind.error => appDangerColor,
      StoryGenerationRunMessageKind.review => appInfoColor,
      StoryGenerationRunMessageKind.editorial => appSuccessColor,
      _ => fallback,
    };
  }
}

class _GenerationPill extends StatelessWidget {
  const _GenerationPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        '$label：$value',
        style: theme.textTheme.bodySmall?.copyWith(color: palette.primary),
      ),
    );
  }
}

class _GenerationProcessRow extends StatelessWidget {
  const _GenerationProcessRow({
    required this.title,
    required this.body,
    required this.accent,
  });

  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  body.trim().isEmpty ? '暂无记录' : body.trim(),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasAction = actionLabel != null;
          final inline = !hasAction || constraints.maxWidth >= 260;
          final bannerBody = [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ];

          final actionButton = hasAction
              ? [
                  if (!inline) const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
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
                  ),
                ]
              : <Widget>[];

          if (inline) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: accentColor, size: 18),
                const SizedBox(width: 12),
                ...bannerBody,
                if (hasAction) ...[const SizedBox(width: 12), ...actionButton],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: accentColor, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: bannerBody,
                    ),
                  ),
                ],
              ),
              ...actionButton,
            ],
          );
        },
      ),
    );
  }
}
