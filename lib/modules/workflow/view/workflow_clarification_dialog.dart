import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/workflow/data/workflow_task_runner.dart';
import '../../../features/workflow/domain/workflow_models.dart';

class WorkflowClarificationDialog extends StatefulWidget {
  final String taskId;

  const WorkflowClarificationDialog({
    super.key,
    required this.taskId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String taskId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => WorkflowClarificationDialog(taskId: taskId),
    );
  }

  @override
  State<WorkflowClarificationDialog> createState() =>
      _WorkflowClarificationDialogState();
}

class _WorkflowClarificationDialogState
    extends State<WorkflowClarificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};

  WorkflowClarificationRequest? _request;
  bool _loading = true;
  bool _submitting = false;
  String? _errorText;

  WorkflowTaskRunner get _runner => Get.find<WorkflowTaskRunner>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final request =
          await _runner.getPendingClarification(widget.taskId);
      if (!mounted) return;

      if (request != null) {
        for (final field in request.requiredFields) {
          _controllers[field] = TextEditingController(
            text: request.existingAnswers[field]?.toString() ?? '',
          );
        }
      }

      setState(() {
        _request = request;
        _loading = false;
        _errorText = request == null ? '当前任务没有待补充的信息。' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = error.toString();
      });
    }
  }

  Future<void> _submit() async {
    final request = _request;
    if (request == null) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final answers = <String, dynamic>{};
    for (final field in request.requiredFields) {
      answers[field] = _controllers[field]?.text.trim() ?? '';
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await _runner.submitClarificationAnswers(
        taskId: request.taskId,
        nodeId: request.responseKey.isNotEmpty
            ? request.responseKey
            : request.nodeId,
        answers: answers,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('补充任务信息'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _buildBody(),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting || _request == null ? null : _submit,
          child: Text(_submitting ? '提交中...' : '提交并继续'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final request = _request;
    if (request == null) {
      return Text(_errorText ?? '没有待补充的信息。');
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (request.prompt.trim().isNotEmpty) ...[
              Text(
                request.prompt,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            for (var i = 0; i < request.requiredFields.length; i++) ...[
              Text(
                _labelForField(request, i),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _controllers[request.requiredFields[i]],
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: _hintForField(request.requiredFields[i]),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return '请填写此项';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_errorText != null)
              Text(
                _errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _labelForField(WorkflowClarificationRequest request, int index) {
    if (index < request.questions.length) {
      return request.questions[index];
    }
    return _humanizeFieldName(request.requiredFields[index]);
  }

  String _hintForField(String field) {
    return '填写${_humanizeFieldName(field)}';
  }

  String _humanizeFieldName(String field) {
    switch (field) {
      case 'previousContent':
        return '前文内容';
      case 'continuationRequest':
        return '续写要求';
      case 'sceneDescription':
        return '场景描述';
      case 'textContent':
        return '源文本';
      default:
        return field;
    }
  }
}
