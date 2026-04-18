import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/workflow/data/workflow_task_runner.dart';
import '../../../features/workflow/domain/workflow_models.dart';
import 'workflow_task_page.dart';

class WorkflowTaskListPage extends StatefulWidget {
  final String workId;

  const WorkflowTaskListPage({
    super.key,
    required this.workId,
  });

  @override
  State<WorkflowTaskListPage> createState() => _WorkflowTaskListPageState();
}

class _WorkflowTaskListPageState extends State<WorkflowTaskListPage> {
  List<WorkflowTaskSummary> _tasks = const [];
  bool _loading = true;
  String? _errorText;

  WorkflowTaskRunner get _runner => Get.find<WorkflowTaskRunner>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await _runner.getTasksByWorkId(widget.workId);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflow 任务列表'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorText != null) {
      return Center(child: Text(_errorText!));
    }
    if (_tasks.isEmpty) {
      return const Center(child: Text('当前作品还没有 workflow 任务。'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return Card(
          child: ListTile(
            title: Text(task.name),
            subtitle: Text(
              '类型: ${task.type} | 状态: ${task.status.name} | 进度: ${(task.progress * 100).toInt()}%',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Get.to(() => WorkflowTaskPage(taskId: task.id)),
          ),
        );
      },
    );
  }
}
