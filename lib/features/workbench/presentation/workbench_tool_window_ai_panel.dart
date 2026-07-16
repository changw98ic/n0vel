part of 'workbench_tool_window_panel.dart';

Widget _buildAiPanel(ToolWindowPanel panel, BuildContext context) {
  final theme = Theme.of(context);
  final palette = desktopPalette(context);
  final diagnosticText = panel.diagnosticReport;
  String selectionPreviewForDraft(WorkbenchAiSelectionDraft selection) {
    final safeStart = selection.start.clamp(0, panel.draftText.length).toInt();
    final safeEnd = selection.end
        .clamp(safeStart, panel.draftText.length)
        .toInt();
    final excerpt = panel.draftText.substring(safeStart, safeEnd).trim();
    if (excerpt.isEmpty) {
      return '尚未选择正文片段';
    }
    if (excerpt.length <= 36) {
      return excerpt;
    }
    return '${excerpt.substring(0, 36)}...';
  }

  final hasSettingsWarning =
      panel.settingsHasPersistenceIssue && panel.settingsFeedback.title != null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '助手',
        style: theme.textTheme.labelSmall?.copyWith(
          color: const Color(0xFFC9D2C4),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '写作助手',
        style: theme.textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.normal,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '选段 · 续写 · 润色 · 对话',
        style: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFFDDE5D8),
          height: 1.45,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _AiModeTab(
              label: '续写',
              isActive: panel.aiToolMode == AiToolMode.continueWriting,
              onTap: () => panel.onSelectAiMode(AiToolMode.continueWriting),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AiModeTab(label: '润色', isActive: false, onTap: () {}),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AiModeTab(label: '对话', isActive: false, onTap: () {}),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            if (panel.statusBanner != null) ...[
              panel.statusBanner!,
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(
                  AppDesignTokens.radiusXLarge,
                ),
                border: Border.all(color: const Color(0x20FFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasSettingsWarning
                        ? 'AI 配置异常'
                        : panel.canGenerateAi
                        ? 'AI 已就绪'
                        : 'AI 暂不可用',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFFC9D2C4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasSettingsWarning
                        ? panel.settingsFeedback.title!
                        : panel.canGenerateAi
                        ? '当前模型：${panel.settings.model}'
                        : '需要生成候选稿时，再到设置连接模型服务。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  if (!hasSettingsWarning && panel.canGenerateAi) ...[
                    const SizedBox(height: 4),
                    Text(
                      '当前模式：${panel.aiToolMode == AiToolMode.rewrite ? '改写' : '续写'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                  if (hasSettingsWarning) ...[
                    const SizedBox(height: 4),
                    Text(
                      panel.settingsFeedback.message ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: appDangerColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          key: WorkbenchShellPage.aiRetrySecureStoreButtonKey,
                          onPressed: () => panel.onRetrySecureStore(),
                          child: const Text('重试配置'),
                        ),
                        TextButton(
                          onPressed: panel.onOpenSettings,
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
                  ] else if (!panel.canGenerateAi) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: panel.onOpenSettings,
                      child: const Text('前往设置'),
                    ),
                  ],
                ],
              ),
            ),
            if (panel.candidatePresentation.state !=
                StoryGenerationCandidatePresentationState.none) ...[
              const SizedBox(height: 12),
              WorkbenchCandidatePanel(
                presentation: panel.candidatePresentation,
                actionFeedback: panel.candidateActionFeedback,
                onAccept: panel.onAcceptCandidate,
                onReject: panel.onRejectCandidate,
              ),
            ],
            if (panel.canGenerateAi) ...[
              const SizedBox(height: 12),
              if (panel.selectionDrafts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: panel.selectionDrafts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final draft = panel.selectionDrafts[index];
                        return Container(
                          width: 200,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: palette.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '片段 ${index + 1}',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => panel.onRemoveSelection(index),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: palette.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Expanded(
                                child: Text(
                                  selectionPreviewForDraft(draft),
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (panel.historyEntries.isEmpty)
                Text(
                  '暂无 AI 历史',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFC9D2C4),
                  ),
                ),
              for (final entry in panel.historyEntries) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFAF6),
                      borderRadius: BorderRadius.circular(
                        AppDesignTokens.radiusXLarge,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GestureDetector(
                          key: WorkbenchShellPage.aiHistoryPromptKey(
                            entry.sequence,
                          ),
                          onTap: () {
                            panel.aiPromptController.text = entry.prompt;
                            panel.aiPromptController.selection =
                                TextSelection.collapsed(
                                  offset: entry.prompt.length,
                                );
                          },
                          child: Text(
                            entry.prompt,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF243226),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.mode,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF77736A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(
                        AppDesignTokens.radiusXLarge,
                      ),
                      border: Border.all(color: const Color(0x20FFFFFF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.mode,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFC9D2C4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '第${entry.sequence}次 · ${identical(entry, panel.historyEntries.first) ? '刚刚生成' : '较早记录'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            GestureDetector(
                              key: WorkbenchShellPage.aiHistoryReplayButtonKey(
                                entry.sequence,
                              ),
                              behavior: HitTestBehavior.translucent,
                              onTap: () => panel.onReplayAiHistory(entry),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  '再次执行',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFC9D2C4),
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              key: WorkbenchShellPage.aiHistoryDeleteButtonKey(
                                entry.sequence,
                              ),
                              behavior: HitTestBehavior.translucent,
                              onTap: () => panel.onDeleteAiHistoryEntry(entry),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  '删除',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFC9D2C4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
      if (panel.canGenerateAi)
        Container(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFAF6),
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.radiusLarge,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: WorkbenchShellPage.aiPromptFieldKey,
                        controller: panel.aiPromptController,
                        decoration: InputDecoration(
                          hintText:
                              '当前：${panel.aiToolMode == AiToolMode.rewrite ? "改写" : "续写"}',
                          hintStyle: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8A867C),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF243226),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: panel.isGeneratingAi
                          ? null
                          : panel.onGenerateAiSuggestion,
                      child: const Icon(
                        Icons.send,
                        size: 18,
                        color: Color(0xFF243226),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: WorkbenchShellPage.aiGenerateButtonKey,
                      onTap: panel.isGeneratingAi
                          ? null
                          : panel.onGenerateAiSuggestion,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppDesignTokens.radiusFull,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: panel.isGeneratingAi
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF243226),
                                ),
                              )
                            : Text(
                                '插入正文',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF243226),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(
                            AppDesignTokens.radiusFull,
                          ),
                          border: Border.all(color: const Color(0x24FFFFFF)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '对比版本',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
  );
}

class _AiModeTab extends StatelessWidget {
  const _AiModeTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF24382F) : const Color(0xFFF6F1E8),
          borderRadius: BorderRadius.circular(12),
          border: isActive ? null : Border.all(color: const Color(0xFFD8D2C2)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isActive ? Colors.white : const Color(0xFF243229),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
