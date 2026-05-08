import 'package:flutter/material.dart';

import '../../../app/di/service_scope.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_generation_run_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../author_feedback/data/author_feedback_store.dart';
import '../../author_feedback/domain/author_feedback_models.dart';
import '../../review_tasks/data/review_task_store.dart';
import '../../review_tasks/domain/review_task_models.dart';

class RevisionHubPage extends StatelessWidget {
  const RevisionHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workspaceStore = AppWorkspaceScope.of(context);
    final reviewTaskStore = ReviewTaskScope.of(context);
    final authorFeedbackStore = AuthorFeedbackScope.of(context);
    final simulationStore = AppSimulationScope.of(context);
    final runStore = ServiceScope.of(
      context,
    ).resolve<StoryGenerationRunStore>();
    final merged = Listenable.merge([
      workspaceStore,
      reviewTaskStore,
      authorFeedbackStore,
      simulationStore,
      runStore,
    ]);

    return ListenableBuilder(
      listenable: merged,
      builder: (context, _) {
        final summary = _RevisionSummary.fromStores(
          workspaceStore: workspaceStore,
          reviewTaskStore: reviewTaskStore,
          authorFeedbackStore: authorFeedbackStore,
          simulation: simulationStore.snapshot,
          run: runStore.snapshot,
        );

        return DesktopShellFrame(
          header: DesktopHeaderBar(
            title: '改稿',
            subtitle: summary.headerSubtitle,
            showBackButton: true,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 960
                  ? 280.0
                  : constraints.maxWidth > 600
                  ? 240.0
                  : double.infinity;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _ContextCard(
                            icon: Icons.report_problem_outlined,
                            title: '问题数量',
                            body: summary.issueCount,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _ContextCard(
                            icon: Icons.pending_actions_outlined,
                            title: '改稿任务状态',
                            body: summary.taskStatus,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _ContextCard(
                            icon: Icons.rate_review_outlined,
                            title: '最近反馈',
                            body: summary.recentFeedback,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _HubCard(
                            icon: Icons.search_outlined,
                            title: '问题检查',
                            subtitle: summary.auditSubtitle,
                            onTap: () =>
                                AppNavigator.push(context, AppRoutes.audit),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _HubCard(
                            icon: Icons.task_outlined,
                            title: '改稿任务',
                            subtitle: summary.taskSubtitle,
                            onTap: () => AppNavigator.push(
                              context,
                              AppRoutes.reviewTasks,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _HubCard(
                            icon: Icons.dashboard_outlined,
                            title: '生产看板',
                            subtitle: summary.productionSubtitle,
                            onTap: () => AppNavigator.push(
                              context,
                              AppRoutes.productionBoard,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          statusBar: DesktopStatusStrip(leftText: summary.statusText),
        );
      },
    );
  }
}

class _RevisionSummary {
  const _RevisionSummary({
    required this.headerSubtitle,
    required this.issueCount,
    required this.taskStatus,
    required this.recentFeedback,
    required this.auditSubtitle,
    required this.taskSubtitle,
    required this.productionSubtitle,
    required this.statusText,
  });

  final String headerSubtitle;
  final String issueCount;
  final String taskStatus;
  final String recentFeedback;
  final String auditSubtitle;
  final String taskSubtitle;
  final String productionSubtitle;
  final String statusText;

  factory _RevisionSummary.fromStores({
    required AppWorkspaceStore workspaceStore,
    required ReviewTaskStore reviewTaskStore,
    required AuthorFeedbackStore authorFeedbackStore,
    required AppSimulationSnapshot simulation,
    required StoryGenerationRunSnapshot run,
  }) {
    final project = workspaceStore.currentProjectOrNull;
    final scene = workspaceStore.currentSceneOrNull;
    final projectTitle = _fallback(project?.title, '未选择项目');
    final sceneLabel =
        (scene == null ? null : chapterLocationLabel(scene.displayLocation)) ??
        chapterLocationLabel(_fallback(project?.recentLocation, '未选择章节'));
    final auditIssues = workspaceStore.auditIssues;
    final openAuditCount = auditIssues.where((issue) => issue.isOpen).length;
    final criticalTasks = reviewTaskStore.tasks
        .where(
          (task) =>
              task.severity == ReviewTaskSeverity.critical &&
              _isActiveTask(task),
        )
        .length;
    final activeTaskCount = reviewTaskStore.openCount;
    final activeFeedback = authorFeedbackStore.items
        .where((item) => item.isActive)
        .toList(growable: false);
    final sceneFeedbackCount = scene == null
        ? activeFeedback.length
        : authorFeedbackStore.activeCountForScene(scene.id);
    final feedbackText = _recentFeedback(
      feedbackItems: authorFeedbackStore.items,
      run: run,
      simulation: simulation,
    );
    final generationState = _generationState(run, simulation);

    return _RevisionSummary(
      headerSubtitle: '$projectTitle · $sceneLabel',
      issueCount: auditIssues.isEmpty
          ? '还没有问题列表；先运行一次检查。'
          : '待处理 $openAuditCount / ${auditIssues.length} · 当前：${_compact(workspaceStore.selectedAuditIssue.title)}',
      taskStatus: reviewTaskStore.tasks.isEmpty
          ? '尚未生成改稿任务；审查或反馈映射后会出现在这里。'
          : '待处理 $activeTaskCount 项 · 高危 $criticalTasks 项 · 最近：${_recentTaskLabel(reviewTaskStore.tasks)}',
      recentFeedback: _compact(feedbackText, maxLength: 72),
      auditSubtitle: auditIssues.isEmpty
          ? '待检查 · 尚未生成问题'
          : '待处理 $openAuditCount / ${auditIssues.length}',
      taskSubtitle: reviewTaskStore.tasks.isEmpty
          ? '尚未生成改稿任务'
          : '待处理 $activeTaskCount 项 · 当前章节反馈 $sceneFeedbackCount 条',
      productionSubtitle: generationState,
      statusText: _nextStep(
        hasAudit: auditIssues.isNotEmpty,
        openAuditCount: openAuditCount,
        activeTaskCount: activeTaskCount,
        activeFeedbackCount: activeFeedback.length,
        generationState: generationState,
      ),
    );
  }

  static bool _isActiveTask(ReviewTask task) {
    return task.status == ReviewTaskStatus.open ||
        task.status == ReviewTaskStatus.inProgress;
  }

  static String _recentFeedback({
    required List<AuthorFeedbackItem> feedbackItems,
    required StoryGenerationRunSnapshot run,
    required AppSimulationSnapshot simulation,
  }) {
    final latestAuthorFeedback = feedbackItems.isEmpty
        ? null
        : feedbackItems.reduce(
            (latest, item) =>
                item.updatedAt.isAfter(latest.updatedAt) ? item : latest,
          );
    if (latestAuthorFeedback != null) {
      return '${_feedbackStatusLabel(latestAuthorFeedback.status)}：${latestAuthorFeedback.note}';
    }
    final runFeedback = run.messages.reversed
        .where(
          (message) =>
              message.kind == StoryGenerationRunMessageKind.authorFeedback ||
              message.kind == StoryGenerationRunMessageKind.review,
        )
        .cast<StoryGenerationRunMessage?>()
        .firstWhere((message) => message != null, orElse: () => null);
    if (runFeedback != null && runFeedback.body.trim().isNotEmpty) {
      return '${runFeedback.title}：${runFeedback.body.trim()}';
    }
    final simulationFeedback = simulation.messages.reversed
        .where((message) => message.kind == SimulationMessageKind.verdict)
        .cast<SimulationChatMessage?>()
        .firstWhere((message) => message != null, orElse: () => null);
    if (simulationFeedback != null &&
        simulationFeedback.body.trim().isNotEmpty) {
      return '${simulationFeedback.title}：${simulationFeedback.body.trim()}';
    }
    return '尚未生成反馈；先运行问题检查或试写审查。';
  }

  static String _recentTaskLabel(List<ReviewTask> tasks) {
    final latest = tasks.reduce(
      (previous, current) =>
          current.updatedAt.isAfter(previous.updatedAt) ? current : previous,
    );
    return _compact(latest.title.trim().isEmpty ? '未命名任务' : latest.title);
  }

  static String _generationState(
    StoryGenerationRunSnapshot run,
    AppSimulationSnapshot simulation,
  ) {
    if (run.hasRun) {
      return '${_runStatusLabel(run.status)} · ${_fallback(run.stageSummary, run.sceneLabel)}';
    }
    if (simulation.hasRun) {
      return '${_simulationStatusLabel(simulation.status)} · ${_fallback(simulation.stageSummary, simulation.sceneLabel)}';
    }
    return '尚未生成 · 生产状态待同步';
  }

  static String _nextStep({
    required bool hasAudit,
    required int openAuditCount,
    required int activeTaskCount,
    required int activeFeedbackCount,
    required String generationState,
  }) {
    if (!hasAudit) {
      return '待检查 · 先生成问题列表';
    }
    if (openAuditCount > 0) {
      return '优先处理 $openAuditCount 个待处理问题';
    }
    if (activeTaskCount > 0) {
      return '继续推进 $activeTaskCount 个改稿任务';
    }
    if (activeFeedbackCount > 0) {
      return '把 $activeFeedbackCount 条作者反馈映射为改稿任务';
    }
    return generationState;
  }
}

String _fallback(String? value, String fallback) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

String _compact(String value, {int maxLength = 24}) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength - 1)}…';
}

String _feedbackStatusLabel(AuthorFeedbackStatus status) {
  return switch (status) {
    AuthorFeedbackStatus.open => '待处理',
    AuthorFeedbackStatus.revisionRequested => '已请求修订',
    AuthorFeedbackStatus.inProgress => '修订中',
    AuthorFeedbackStatus.resolved => '已解决',
    AuthorFeedbackStatus.accepted => '已接受',
    AuthorFeedbackStatus.rejected => '已驳回',
  };
}

String _runStatusLabel(StoryGenerationRunStatus status) {
  return switch (status) {
    StoryGenerationRunStatus.idle => '尚未生成',
    StoryGenerationRunStatus.running => '生成中',
    StoryGenerationRunStatus.completed => '已生成',
    StoryGenerationRunStatus.failed => '生成失败',
    StoryGenerationRunStatus.cancelled => '已取消',
  };
}

String _simulationStatusLabel(SimulationStatus status) {
  return switch (status) {
    SimulationStatus.none => '尚未生成',
    SimulationStatus.running => '试写中',
    SimulationStatus.completed => '试写完成',
    SimulationStatus.failed => '试写失败',
  };
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
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

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Material(
      color: palette.elevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: palette.primary),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
