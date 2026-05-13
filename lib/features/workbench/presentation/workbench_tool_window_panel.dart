import 'package:flutter/material.dart';

import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_settings_store.dart';
import '../../../domain/workspace_models.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../author_feedback/data/author_feedback_store.dart';
import '../../review_tasks/data/review_task_store.dart';
import 'workbench_ai_revision_helpers.dart';
import 'workbench_shell_page.dart';

part 'workbench_tool_window_ai_panel.dart';

class ToolWindowPanel extends StatelessWidget {
  const ToolWindowPanel({
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
    this.statusBanner,
    this.creationGuide,
    super.key,
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
  final List<WorkbenchAiSelectionDraft> selectionDrafts;
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
  final Widget? statusBanner;
  final Widget? creationGuide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final diagnosticText = diagnosticReport;
    String selectionPreviewForDraft(WorkbenchAiSelectionDraft selection) {
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
      WorkbenchToolPanel.resources => ('章节资料', '本章会使用的人物、世界观和章节摘要会显示在这里。'),
      WorkbenchToolPanel.ai => ('AI 写作助手', '选择写作动作、查看历史记录，并告诉 AI 你想怎么改。'),
      WorkbenchToolPanel.settings => ('设置快捷面板', '当前模型服务、模型、界面模式和快速入口会显示在这里。'),
    };

    if (activePanel == WorkbenchToolPanel.settings) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(description, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.elevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('模型服务', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  settings.model.isEmpty
                      ? '尚未配置模型'
                      : '${settings.providerName} · ${settings.model}',
                  style: theme.textTheme.bodySmall,
                ),
                if (settingsFeedback.message != null &&
                    settingsFeedback.message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    settingsFeedback.message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: settingsHasPersistenceIssue
                          ? appDangerColor
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: onOpenSettings,
                      child: const Text('打开完整设置'),
                    ),
                    TextButton(
                      key: WorkbenchShellPage
                          .settingsRetrySecureStoreButtonKey,
                      onPressed: () => onRetrySecureStore(),
                      child: const Text('重试配置'),
                    ),
                    if (diagnosticText != null)
                      TextButton(
                        key: WorkbenchShellPage
                            .settingsCopyDiagnosticButtonKey,
                        onPressed: () => copyDiagnosticToClipboard(
                          context,
                          diagnosticText,
                        ),
                        child: const Text('复制诊断'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (activePanel == WorkbenchToolPanel.ai) {
      return _buildAiPanel(this, context);
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
                  if (uiState ==
                      WorkbenchUiState.missingCharacterReference) ...[
                    Text(
                      '出场人物需要重新确认',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: appDangerColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (uiState == WorkbenchUiState.missingWorldReference) ...[
                    Text(
                      '世界观资料需要重新确认',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: appDangerColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (scenes.isNotEmpty) ...[
                    Text('章节列表', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    for (final scene in scenes)
                      TextButton(
                        onPressed: () => onSelectScene(scene),
                        child: Text(scene.title),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (sceneContext.characterSummary.trim().isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 16, color: palette.primary),
                        const SizedBox(width: 6),
                        Text('出场人物', style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        sceneContext.characterSummary,
                        style: theme.textTheme.bodySmall,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (sceneContext.worldSummary.trim().isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.public_outlined, size: 16, color: palette.primary),
                        const SizedBox(width: 6),
                        Text('世界观', style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        sceneContext.worldSummary,
                        style: theme.textTheme.bodySmall,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (sceneContext.sceneSummary.trim().isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.summarize_outlined, size: 16, color: palette.primary),
                        const SizedBox(width: 6),
                        Text('章节目标', style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        sceneContext.sceneSummary,
                        style: theme.textTheme.bodySmall,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onSyncContext,
                      icon: const Icon(Icons.refresh_outlined, size: 16),
                      label: const Text('刷新当前章节资料'),
                    ),
                  ),
                ],
                if (activePanel == WorkbenchToolPanel.ai) ...[
                  if (creationGuide != null) ...[
                    const SizedBox(height: 8),
                    creationGuide!,
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

