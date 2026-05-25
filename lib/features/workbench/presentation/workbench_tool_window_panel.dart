import 'package:flutter/material.dart';

import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_settings_store.dart';
import '../../../app/state/story_generation_run_store.dart';
import '../../../domain/workspace_models.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../author_feedback/data/author_feedback_store.dart';
import '../../characters/presentation/character_state_card.dart';
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
    required this.characters,
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
    required this.onUpdateCharacterState,
    required this.onSyncContext,
    required this.onSelectScene,
    required this.onCreateScene,
    required this.onRenameScene,
    required this.onDeleteScene,
    required this.canDeleteScene,
    required this.onOpenSettings,
    required this.onShowAiMetadata,
    // Run Center v1 fields
    required this.runSnapshot,
    required this.isRunActive,
    required this.canCancelRun,
    required this.canRetryRun,
    required this.onRetryRun,
    required this.onDiscardRun,
    required this.onCancelRun,
    this.statusBanner,
    this.creationGuide,
    super.key,
  });

  final WorkbenchToolPanel activePanel;
  final AuthorFeedbackStore authorFeedbackStore;
  final ReviewTaskStore reviewTaskStore;
  final AppSceneContextSnapshot sceneContext;
  final List<CharacterRecord> characters;
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
  final void Function(CharacterRecord, CharacterStateUpdate)
  onUpdateCharacterState;
  final VoidCallback onSyncContext;
  final Future<void> Function(SceneRecord) onSelectScene;
  final VoidCallback onCreateScene;
  final VoidCallback onRenameScene;
  final VoidCallback onDeleteScene;
  final bool canDeleteScene;
  final VoidCallback onOpenSettings;
  final VoidCallback onShowAiMetadata;
  final Widget? statusBanner;
  final Widget? creationGuide;

  // Run Center v1 fields
  final StoryGenerationRunSnapshot runSnapshot;
  final bool isRunActive;
  final bool canCancelRun;
  final bool canRetryRun;
  final VoidCallback onRetryRun;
  final VoidCallback onDiscardRun;
  final VoidCallback onCancelRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final diagnosticText = diagnosticReport;
    final activeCharacter = _selectedCharacterForStateCard(
      characters: characters,
      currentSceneId: currentSceneId,
    );

    final (title, description) = switch (activePanel) {
      WorkbenchToolPanel.resources => ('章节资料', '本章会使用的人物、世界观和章节摘要会显示在这里。'),
      WorkbenchToolPanel.ai => ('AI 写作助手', '选择写作动作、查看历史记录，并告诉 AI 你想怎么改。'),
      WorkbenchToolPanel.settings => ('设置快捷面板', '当前模型服务、模型、界面模式和快速入口会显示在这里。'),
      WorkbenchToolPanel.runCenter => ('运行中心', '当前章节 AI 试写状态和操作。'),
    };

    if (activePanel == WorkbenchToolPanel.runCenter) {
      return _buildRunCenterPanel(this, context);
    }

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
                      key: WorkbenchShellPage.settingsRetrySecureStoreButtonKey,
                      onPressed: () => onRetrySecureStore(),
                      child: const Text('重试配置'),
                    ),
                    if (diagnosticText != null)
                      TextButton(
                        key: WorkbenchShellPage.settingsCopyDiagnosticButtonKey,
                        onPressed: () =>
                            copyDiagnosticToClipboard(context, diagnosticText),
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
                  if (activeCharacter != null) ...[
                    CharacterStateCard(
                      characterName: activeCharacter.name,
                      role: activeCharacter.role,
                      currentState: characterCurrentStateForRecord(
                        activeCharacter,
                      ),
                      recentChange: characterRecentChangeForRecord(
                        activeCharacter,
                      ),
                      history: characterStateHistoryForRecord(activeCharacter),
                      compact: true,
                      onStateSubmitted: (update) =>
                          onUpdateCharacterState(activeCharacter, update),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                        key: ValueKey(
                          'workbench-chapter-list-scene-${scene.id}',
                        ),
                        onPressed: () async {
                          await onSelectScene(scene);
                        },
                        child: Text(scene.title),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (sceneContext.characterSummary.trim().isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 16,
                          color: palette.primary,
                        ),
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
                        Icon(
                          Icons.public_outlined,
                          size: 16,
                          color: palette.primary,
                        ),
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
                        Icon(
                          Icons.summarize_outlined,
                          size: 16,
                          color: palette.primary,
                        ),
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

CharacterRecord? _selectedCharacterForStateCard({
  required List<CharacterRecord> characters,
  required String currentSceneId,
}) {
  if (characters.isEmpty) {
    return null;
  }
  if (currentSceneId.trim().isNotEmpty) {
    for (final character in characters) {
      if (character.linkedSceneIds.contains(currentSceneId)) {
        return character;
      }
    }
  }
  return characters.first;
}

Widget _buildRunCenterPanel(ToolWindowPanel panel, BuildContext context) {
  final theme = Theme.of(context);
  final palette = desktopPalette(context);
  final snapshot = panel.runSnapshot;

  const runCenterPanelKey = ValueKey<String>('workbench-run-center-panel');
  const runCenterCancelButtonKey = ValueKey<String>(
    'workbench-run-center-cancel-button',
  );
  const runCenterRetryButtonKey = ValueKey<String>(
    'workbench-run-center-retry-button',
  );

  final statusColor = switch (snapshot.status) {
    StoryGenerationRunStatus.idle => palette.secondaryText,
    StoryGenerationRunStatus.running => appSuccessColor,
    StoryGenerationRunStatus.completed => appSuccessColor,
    StoryGenerationRunStatus.failed => appDangerColor,
    StoryGenerationRunStatus.cancelled => palette.secondaryText,
  };

  final statusLabel = switch (snapshot.status) {
    StoryGenerationRunStatus.idle => '未运行',
    StoryGenerationRunStatus.running => '进行中',
    StoryGenerationRunStatus.completed => '已完成',
    StoryGenerationRunStatus.failed => '失败',
    StoryGenerationRunStatus.cancelled => '已取消',
  };

  final phaseLabel = snapshot.hasRun
      ? switch (snapshot.phase) {
          StoryGenerationRunPhase.draft => '准备候选稿',
          StoryGenerationRunPhase.candidate => '候选稿已生成',
          StoryGenerationRunPhase.feedback => '作者反馈中',
          StoryGenerationRunPhase.check => '审核中',
          StoryGenerationRunPhase.commit => '已提交',
          StoryGenerationRunPhase.fail => '失败',
          StoryGenerationRunPhase.cancel => '已取消',
          StoryGenerationRunPhase.resume => '恢复中',
        }
      : '';

  return Column(
    key: runCenterPanelKey,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('运行中心', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text('当前章节 AI 试写状态', style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (snapshot.status) {
                    StoryGenerationRunStatus.running => Icons.sync,
                    StoryGenerationRunStatus.completed => Icons.check_circle,
                    StoryGenerationRunStatus.failed => Icons.error,
                    StoryGenerationRunStatus.cancelled => Icons.cancel,
                    StoryGenerationRunStatus.idle => Icons.circle_outlined,
                  },
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: statusColor,
                  ),
                ),
                if (snapshot.hasRun && phaseLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· $phaseLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
            if (snapshot.hasRun) ...[
              const SizedBox(height: 12),
              Text(snapshot.headline, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                snapshot.summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.secondaryText,
                ),
              ),
              if (snapshot.stageSummary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  snapshot.stageSummary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.secondaryText,
                  ),
                ),
              ],
              if (snapshot.stageTimeline.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildStageTimeline(
                  snapshot.stageTimeline,
                  theme,
                  palette,
                  snapshot.status,
                ),
              ],
              if (snapshot.errorDetail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: appDangerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: appDangerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    snapshot.errorDetail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: appDangerColor,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (panel.isRunActive && panel.canCancelRun)
        FilledButton(
          key: runCenterCancelButtonKey,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(36),
            backgroundColor: appDangerColor,
          ),
          onPressed: panel.onCancelRun,
          child: const Text('取消运行'),
        )
      else if (panel.canRetryRun)
        FilledButton(
          key: runCenterRetryButtonKey,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36)),
          onPressed: panel.onRetryRun,
          child: const Text('重新运行'),
        )
      else if (snapshot.hasRun &&
          snapshot.status != StoryGenerationRunStatus.idle)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(36),
          ),
          onPressed: panel.onDiscardRun,
          child: const Text('丢弃记录'),
        )
      else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '尚未运行',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text('当前章节还没有 AI 试写记录。', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
    ],
  );
}

/// Builds a compact stage timeline visualization for the Run Center.
///
/// Each stage shows as a labeled row with an icon indicating its status:
/// - pending: circle_outlined (grey)
/// - running: sync (spin animation, green)
/// - completed: check_circle (green)
/// - failed: error (red, with failure summary)
///
/// The failed-stage label has a stable key for widget tests.
Widget _buildStageTimeline(
  List<StoryGenerationRunStageSnapshot> timeline,
  ThemeData theme,
  DesktopPalette palette,
  StoryGenerationRunStatus runStatus,
) {
  return Column(
    key: const ValueKey<String>('workbench-stage-timeline'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '生成阶段',
        style: theme.textTheme.titleSmall?.copyWith(
          color: palette.secondaryText,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final stage in timeline)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildStageTimelineRow(stage, theme, palette, runStatus),
              ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildStageTimelineRow(
  StoryGenerationRunStageSnapshot stage,
  ThemeData theme,
  DesktopPalette palette,
  StoryGenerationRunStatus runStatus,
) {
  final isFailed = stage.status == StoryGenerationRunStageStatus.failed;

  final rowKey = ValueKey<String>('stage-timeline-row-${stage.stageId.name}');
  final failedLabelKey = isFailed
      ? ValueKey<String>('stage-failed-label-${stage.stageId.name}')
      : null;

  final statusColor = switch (stage.status) {
    StoryGenerationRunStageStatus.pending => palette.secondaryText,
    StoryGenerationRunStageStatus.running => appSuccessColor,
    StoryGenerationRunStageStatus.completed => appSuccessColor,
    StoryGenerationRunStageStatus.failed => appDangerColor,
  };

  final statusIcon = switch (stage.status) {
    StoryGenerationRunStageStatus.pending => Icons.circle_outlined,
    StoryGenerationRunStageStatus.running => Icons.sync,
    StoryGenerationRunStageStatus.completed => Icons.check_circle,
    StoryGenerationRunStageStatus.failed => Icons.error,
  };

  return Row(
    key: rowKey,
    children: [
      Icon(statusIcon, size: 14, color: statusColor),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          stage.label,
          style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
        ),
      ),
      if (isFailed && stage.summary != null)
        Flexible(
          child: Text(
            stage.summary!,
            key: failedLabelKey,
            style: theme.textTheme.bodySmall?.copyWith(color: appDangerColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
}
