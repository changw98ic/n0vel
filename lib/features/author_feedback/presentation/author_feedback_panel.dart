import 'package:flutter/material.dart';

import '../../../app/widgets/desktop_theme.dart';
import '../data/author_feedback_store.dart';
import '../domain/author_feedback_models.dart';

class AuthorFeedbackPanel extends StatefulWidget {
  const AuthorFeedbackPanel({
    super.key,
    required this.store,
    required this.chapterId,
    required this.sceneId,
    required this.sceneLabel,
    this.sourceRunId,
    this.sourceRunLabel,
  });

  static const noteFieldKey = ValueKey<String>('author-feedback-note-field');
  static const createButtonKey = ValueKey<String>(
    'author-feedback-create-button',
  );
  static const requestRevisionButtonKey = ValueKey<String>(
    'author-feedback-request-revision-button',
  );
  static const listKey = ValueKey<String>('author-feedback-list');

  final AuthorFeedbackStore store;
  final String chapterId;
  final String sceneId;
  final String sceneLabel;
  final String? sourceRunId;
  final String? sourceRunLabel;

  @override
  State<AuthorFeedbackPanel> createState() => _AuthorFeedbackPanelState();
}

class _AuthorFeedbackPanelState extends State<AuthorFeedbackPanel> {
  final TextEditingController _noteController = TextEditingController();
  AuthorFeedbackPriority _priority = AuthorFeedbackPriority.normal;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final palette = desktopPalette(context);
        final items = widget.store.itemsForScene(widget.sceneId);
        final activeCount = items.where((item) => item.isActive).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('作者反馈', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '$activeCount 个待处理 · ${widget.sceneLabel}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              key: AuthorFeedbackPanel.noteFieldKey,
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '记录作者意见、审稿问题或下一轮修订要求',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final priority in AuthorFeedbackPriority.values)
                  ChoiceChip(
                    label: Text(_priorityLabel(priority)),
                    selected: _priority == priority,
                    onSelected: (_) {
                      setState(() {
                        _priority = priority;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: AuthorFeedbackPanel.createButtonKey,
                  onPressed: _createOpenFeedback,
                  child: const Text('记录反馈'),
                ),
                OutlinedButton(
                  key: AuthorFeedbackPanel.requestRevisionButtonKey,
                  onPressed: _createRevisionRequest,
                  child: const Text('请求修订'),
                ),
              ],
            ),
            if (widget.sourceRunLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                '来源：${widget.sourceRunLabel}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                key: AuthorFeedbackPanel.listKey,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.elevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border),
                ),
                child: items.isEmpty
                    ? Text('当前场景暂无反馈。', style: theme.textTheme.bodySmall)
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _FeedbackItemCard(
                            item: item,
                            onRequestRevision: () =>
                                widget.store.requestRevision(
                                  item.id,
                                  sourceRunId: widget.sourceRunId,
                                ),
                            onAccept: () => widget.store.accept(item.id),
                            onReject: () => widget.store.reject(item.id),
                            onResolve: () => widget.store.resolve(item.id),
                            onRemove: () => widget.store.remove(item.id),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _createOpenFeedback() {
    _createFeedback(AuthorFeedbackStatus.open);
  }

  void _createRevisionRequest() {
    _createFeedback(AuthorFeedbackStatus.revisionRequested);
  }

  void _createFeedback(AuthorFeedbackStatus status) {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      return;
    }
    widget.store.createFeedback(
      chapterId: widget.chapterId,
      sceneId: widget.sceneId,
      sceneLabel: widget.sceneLabel,
      note: note,
      priority: _priority,
      status: status,
      sourceRunId: widget.sourceRunId,
      sourceRunLabel: widget.sourceRunLabel,
    );
    _noteController.clear();
    setState(() {
      _priority = AuthorFeedbackPriority.normal;
    });
  }
}

class _FeedbackItemCard extends StatelessWidget {
  const _FeedbackItemCard({
    required this.item,
    required this.onRequestRevision,
    required this.onAccept,
    required this.onReject,
    required this.onResolve,
    required this.onRemove,
  });

  final AuthorFeedbackItem item;
  final VoidCallback onRequestRevision;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onResolve;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                _statusLabel(item.status),
                style: theme.textTheme.labelLarge,
              ),
              Text(
                _priorityLabel(item.priority),
                style: theme.textTheme.bodySmall,
              ),
              if (item.sourceRunLabel != null)
                Text(item.sourceRunLabel!, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.note, style: theme.textTheme.bodyMedium),
          if (item.decisions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '最近决策：${item.decisions.first.note}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed:
                    item.status == AuthorFeedbackStatus.revisionRequested ||
                        item.status == AuthorFeedbackStatus.inProgress
                    ? null
                    : onRequestRevision,
                child: const Text('转修订'),
              ),
              TextButton(onPressed: onAccept, child: const Text('接受')),
              TextButton(onPressed: onReject, child: const Text('驳回')),
              TextButton(onPressed: onResolve, child: const Text('解决')),
              TextButton(onPressed: onRemove, child: const Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}

String _priorityLabel(AuthorFeedbackPriority priority) {
  return switch (priority) {
    AuthorFeedbackPriority.low => '低优先级',
    AuthorFeedbackPriority.normal => '普通',
    AuthorFeedbackPriority.high => '高优先级',
  };
}

String _statusLabel(AuthorFeedbackStatus status) {
  return switch (status) {
    AuthorFeedbackStatus.open => '待处理',
    AuthorFeedbackStatus.revisionRequested => '已请求修订',
    AuthorFeedbackStatus.inProgress => '修订中',
    AuthorFeedbackStatus.resolved => '已解决',
    AuthorFeedbackStatus.accepted => '已接受',
    AuthorFeedbackStatus.rejected => '已驳回',
  };
}
