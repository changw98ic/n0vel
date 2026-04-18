import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_routes.dart';
import '../../../features/workflow/data/workflow_task_runner.dart';
import '../../../features/workflow/domain/workflow_models.dart';
import 'workflow_clarification_dialog.dart';

class WorkflowTaskPage extends StatefulWidget {
  final String taskId;

  const WorkflowTaskPage({
    super.key,
    required this.taskId,
  });

  @override
  State<WorkflowTaskPage> createState() => _WorkflowTaskPageState();
}

class _WorkflowTaskPageState extends State<WorkflowTaskPage> {
  WorkflowTaskSummary? _task;
  WorkflowClarificationRequest? _clarification;
  String _displayText = '';
  bool _loading = true;
  bool _submitting = false;
  String? _errorText;

  WorkflowTaskRunner get _runner => Get.find<WorkflowTaskRunner>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final task = await _runner.getStatus(widget.taskId);
      final clarification = await _runner.getPendingClarification(widget.taskId);
      final displayText = await _runner.getDisplayText(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = task;
        _clarification = clarification;
        _displayText = displayText;
        _loading = false;
        _errorText = task == null ? '任务不存在或已被删除。' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = error.toString();
      });
    }
  }

  Future<void> _handleClarification() async {
    final submitted = await WorkflowClarificationDialog.show(
      context,
      taskId: widget.taskId,
    );
    if (submitted == true) {
      await _load();
    }
  }

  Future<void> _submitReviewDecision(bool approved) async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await _runner.submitReviewDecision(
        taskId: widget.taskId,
        approved: approved,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflow 任务'),
        actions: [
          if (_task != null)
            IconButton(
              onPressed: () => Get.toNamed(
                AppRoutes.workflowTasks.replaceFirst(':workId', _task!.workId),
              ),
              icon: const Icon(Icons.list_alt_rounded),
              tooltip: '同作品任务列表',
            ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final task = _task;
    if (task == null) {
      return Center(
        child: Text(_errorText ?? '任务不存在。'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetaCard(task: task),
        const SizedBox(height: 16),
        if (_clarification != null) ...[
          _SectionCard(
            title: '待补充信息',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_clarification!.prompt.trim().isNotEmpty)
                  Text(_clarification!.prompt),
                if (_clarification!.questions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final question in _clarification!.questions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('- $question'),
                    ),
                ],
                if (_clarification!.existingAnswers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '已填写内容',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(_clarification!.existingAnswers.toString()),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitting ? null : _handleClarification,
                  child: const Text('补充信息'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_displayText.trim().isNotEmpty) ...[
          _SectionCard(
            title: '结果',
            child: SelectableText(_displayText),
          ),
          const SizedBox(height: 16),
        ],
        if (task.status == WorkflowTaskStatus.waitingReview) ...[
          _SectionCard(
            title: '审核操作',
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => _submitReviewDecision(false),
                    child: const Text('重新生成'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : () => _submitReviewDecision(true),
                    child: const Text('通过'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_errorText != null)
          Text(
            _errorText!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  final WorkflowTaskSummary task;

  const _MetaCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Task ID: ${task.id}'),
            Text('类型: ${task.type}'),
            Text('状态: ${task.status.name}'),
            Text('进度: ${(task.progress * 100).toInt()}%'),
            Text('当前节点: ${task.currentNodeIndex}'),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
