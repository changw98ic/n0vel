import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/review/data/review_service.dart';
import '../../../features/workflow/domain/workflow_models.dart';

class ReviewProgressDialog extends StatefulWidget {
  final String workId;
  final String scope;
  final List<String> dimensions;
  final String? volumeId;
  final String? chapterId;

  const ReviewProgressDialog({
    super.key,
    required this.workId,
    required this.scope,
    required this.dimensions,
    this.volumeId,
    this.chapterId,
  });

  @override
  State<ReviewProgressDialog> createState() => _ReviewProgressDialogState();
}

class _ReviewProgressDialogState extends State<ReviewProgressDialog> {
  double _progress = 0.0;
  String _currentStatus = '准备审查...';
  bool _isCompleted = false;
  bool _isFailed = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    unawaited(_startReview());
  }

  Future<void> _startReview() async {
    final s = S.of(context)!;
    try {
      final reviewService = Get.find<ReviewService>();
      setState(() {
        _currentStatus = s.review_progressLoading;
        _progress = 0.1;
      });

      final taskId = await reviewService.startReviewWorkflow(
        workId: widget.workId,
        scope: widget.scope,
        dimensionNames: widget.dimensions,
        volumeId: widget.volumeId,
        chapterId: widget.chapterId,
      );

      await _pollTaskStatus(reviewService, taskId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isFailed = true;
        _errorText = error.toString();
        _currentStatus = error.toString();
      });
    }
  }

  Future<void> _pollTaskStatus(
    ReviewService reviewService,
    String taskId,
  ) async {
    final s = S.of(context)!;
    while (mounted) {
      final task = await reviewService.getWorkflowStatus(taskId);
      if (task == null) {
        throw StateError('Review task disappeared: $taskId');
      }

      final nextProgress = task.progress.clamp(0.0, 1.0);
      final nextStatus = switch (task.status) {
        WorkflowTaskStatus.pending => s.review_progressLoading,
        WorkflowTaskStatus.running => nextProgress < 0.5
            ? s.review_progressAnalyzing
            : s.review_progressGenerating,
        WorkflowTaskStatus.paused => s.review_progressFinished,
        WorkflowTaskStatus.completed => s.review_progressCompleted,
        WorkflowTaskStatus.failed => task.errorMessage ?? 'Review failed',
        WorkflowTaskStatus.cancelled => 'Review cancelled',
      };

      if (!mounted) return;
      setState(() {
        _progress = nextProgress;
        _currentStatus = nextStatus;
        _isCompleted =
            task.status == WorkflowTaskStatus.completed ||
            task.status == WorkflowTaskStatus.paused;
        _isFailed = task.status == WorkflowTaskStatus.failed;
        _errorText = task.errorMessage;
      });

      if (_isCompleted || _isFailed) {
        return;
      }

      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final statusText = _currentStatus;

    return AlertDialog(
      title: Text(s.review_progress_title),
      content: SizedBox(
        width: 400.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _isFailed ? null : _progress,
            ),
            SizedBox(height: 16.h),
            Text(statusText),
            SizedBox(height: 8.h),
            if (!_isFailed) Text('${(_progress * 100).toInt()}%'),
            if (_errorText != null) ...[
              SizedBox(height: 8.h),
              Text(
                _isFailed ? '审查执行失败，请稍后重试。' : _errorText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isCompleted || _isFailed)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _isFailed ? s.editor_close : s.review_progress_viewResult,
            ),
          ),
      ],
    );
  }
}
