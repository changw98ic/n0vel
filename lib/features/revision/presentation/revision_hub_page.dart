import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_generation_run_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../author_feedback/data/author_feedback_store.dart';
import '../../author_feedback/domain/author_feedback_models.dart';
import '../../review_tasks/data/review_task_store.dart';
import '../../review_tasks/domain/review_task_models.dart';
import 'revision_hub_components.dart';

class RevisionHubPage extends ConsumerWidget {
  const RevisionHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceStore = ref.watch(appWorkspaceStoreProvider);
    final reviewTaskStore = ref.watch(reviewTaskStoreProvider);
    final authorFeedbackStore = ref.watch(authorFeedbackStoreProvider);
    final simulationStore = ref.watch(appSimulationStoreProvider);
    final runStore = ref.watch(storyGenerationRunStoreProvider);
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
            title: '推演写作',
            subtitle: summary.headerSubtitle,
            showBackButton: true,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final palette = desktopPalette(context);

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Inline stat bar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: palette.subtle.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 6,
                        children: [
                          RevisionHubStatChip(
                            icon: Icons.report_problem_outlined,
                            label: '问题',
                            value: summary.issueCount,
                          ),
                          RevisionHubStatChip(
                            icon: Icons.pending_actions_outlined,
                            label: '任务',
                            value: summary.taskStatus,
                          ),
                          RevisionHubStatChip(
                            icon: Icons.rate_review_outlined,
                            label: '反馈',
                            value: summary.recentFeedback,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // List navigation
                    ...[
                      RevisionHubNavItem(
                        icon: Icons.search_outlined,
                        title: '问题检查',
                        subtitle: summary.auditSubtitle,
                        onTap: () =>
                            AppNavigator.push(context, AppRoutes.audit),
                      ),
                      RevisionHubNavItem(
                        icon: Icons.task_outlined,
                        title: '改稿任务',
                        subtitle: summary.taskSubtitle,
                        onTap: () => AppNavigator.push(
                          context,
                          AppRoutes.reviewTasks,
                        ),
                      ),
                      RevisionHubNavItem(
                        icon: Icons.dashboard_outlined,
                        title: '生产看板',
                        subtitle: summary.productionSubtitle,
                        onTap: () => AppNavigator.push(
                          context,
                          AppRoutes.productionBoard,
                        ),
                      ),
                    ],
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
