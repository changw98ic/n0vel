import 'package:flutter/material.dart';

import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/desktop_theme.dart';
import '../data/review_task_store.dart';
import '../domain/review_task_models.dart';

class ReviewTaskPanel extends StatelessWidget {
  const ReviewTaskPanel({
    super.key,
    required this.store,
    this.title = 'Review tasks',
  });

  static const listKey = ValueKey<String>('review-task-list');
  static const emptyKey = ValueKey<String>('review-task-empty');

  final ReviewTaskStore store;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final grouped = store.groupedByStatus();
        final hasTasks = store.tasks.isNotEmpty;
        final theme = Theme.of(context);
        final palette = desktopPalette(context);

        return Container(
          decoration: appPanelDecoration(context),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  Text(
                    '${store.openCount} active',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasTasks)
                const Expanded(
                  child: AppEmptyState(
                    key: emptyKey,
                    title: 'No review tasks',
                    message: 'Review findings will appear here after mapping.',
                  ),
                )
              else
                Expanded(
                  key: listKey,
                  child: ListView(
                    children: [
                      for (final status in ReviewTaskStatus.values)
                        if ((grouped[status] ?? const []).isNotEmpty)
                          _ReviewTaskStatusGroup(
                            status: status,
                            tasks: grouped[status] ?? const [],
                            onStatusChanged: store.updateStatus,
                          ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewTaskStatusGroup extends StatelessWidget {
  const _ReviewTaskStatusGroup({
    required this.status,
    required this.tasks,
    required this.onStatusChanged,
  });

  final ReviewTaskStatus status;
  final List<ReviewTask> tasks;
  final bool Function(String taskId, ReviewTaskStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_statusLabel(status)} (${tasks.length})',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReviewTaskTile(
                task: task,
                onStatusChanged: onStatusChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewTaskTile extends StatelessWidget {
  const _ReviewTaskTile({required this.task, required this.onStatusChanged});

  final ReviewTask task;
  final bool Function(String taskId, ReviewTaskStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.subtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(task.title, style: theme.textTheme.titleSmall),
              ),
              const SizedBox(width: 8),
              _SeverityBadge(severity: task.severity),
              PopupMenuButton<ReviewTaskStatus>(
                tooltip: 'Change status',
                initialValue: task.status,
                onSelected: (status) => onStatusChanged(task.id, status),
                itemBuilder: (context) => [
                  for (final status in ReviewTaskStatus.values)
                    PopupMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(task.body, style: theme.textTheme.bodyMedium),
          if (_referenceLabel(task.reference).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _referenceLabel(task.reference),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final ReviewTaskSeverity severity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (severity) {
      ReviewTaskSeverity.info => const Color(0xFF3C6E71),
      ReviewTaskSeverity.warning => const Color(0xFF9A6A18),
      ReviewTaskSeverity.critical => const Color(0xFF9B332C),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        severity.name,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

String _referenceLabel(ReviewTaskReference reference) {
  return [
    if (reference.chapterTitle.isNotEmpty) reference.chapterTitle,
    if (reference.sceneTitle.isNotEmpty) reference.sceneTitle,
  ].join(' / ');
}

String _statusLabel(ReviewTaskStatus status) {
  return switch (status) {
    ReviewTaskStatus.open => 'Open',
    ReviewTaskStatus.inProgress => 'In progress',
    ReviewTaskStatus.resolved => 'Resolved',
    ReviewTaskStatus.ignored => 'Ignored',
  };
}
