import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/timeline/domain/timeline_models.dart';
import '../../../features/timeline/data/timeline_repository.dart';

/// 冲突指示器组件
class ConflictIndicator extends StatelessWidget {
  final List<TimeConflict> conflicts;

  const ConflictIndicator({
    super.key,
    required this.conflicts,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    if (conflicts.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(s.timeline_noTimeConflicts),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.orange,
                ),
                SizedBox(width: 8.w),
                Text(
                  s.timeline_detectedConflicts(conflicts.length),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...conflicts.map((conflict) => _ConflictItem(conflict: conflict)),
        ],
      ),
    );
  }
}

/// 冲突项
class _ConflictItem extends StatelessWidget {
  final TimeConflict conflict;

  const _ConflictItem({required this.conflict});

  @override
  Widget build(BuildContext context) {
    final color = _getConflictColor(conflict.type);

    return ListTile(
      leading: Icon(_getConflictIcon(conflict.type), color: color),
      title: Text(conflict.description),
      subtitle: Text(conflict.type.label),
      trailing: conflict.isResolved
          ? const Icon(Icons.check, color: Colors.green)
          : TextButton(
              onPressed: () => _showResolutionDialog(context, conflict),
              child: Text(S.of(context)!.timeline_fix),
            ),
    );
  }

  IconData _getConflictIcon(ConflictType type) {
    return switch (type) {
      ConflictType.timeSequence => Icons.schedule,
      ConflictType.locationConflict => Icons.place,
      ConflictType.stateConflict => Icons.person,
      ConflictType.characterAvailability => Icons.people,
    };
  }

  Color _getConflictColor(ConflictType type) {
    return switch (type) {
      ConflictType.timeSequence => Colors.red,
      ConflictType.locationConflict => Colors.orange,
      ConflictType.stateConflict => Colors.amber,
      ConflictType.characterAvailability => Colors.green,
    };
  }

  /// 显示修复建议对话框
  void _showResolutionDialog(BuildContext context, TimeConflict conflict) {
    showDialog(
      context: context,
      builder: (context) => _ConflictResolutionDialog(conflict: conflict),
    );
  }
}

/// 冲突修复对话框
class _ConflictResolutionDialog extends StatefulWidget {
  final TimeConflict conflict;

  const _ConflictResolutionDialog({required this.conflict});

  @override
  State<_ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<_ConflictResolutionDialog> {
  bool _isApplyingFix = false;

  Future<void> _applyAIFix() async {
    final s = S.of(context)!;
    setState(() => _isApplyingFix = true);

    try {
      // 获取AI建议的修复方案
      final aiSuggestion = await _getAISuggestion();

      if (mounted && aiSuggestion != null) {
        // 应用修复方案
        await _applyFix(aiSuggestion);

        if (mounted) {
          // 标记冲突为已解决
          await _markAsResolved();

          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.timeline_conflictFixed)),
          );
        }
      }
    } catch (e) {
      setState(() => _isApplyingFix = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.timeline_applyFixFailed('$e'))),
        );
      }
    }
  }

  Future<String?> _getAISuggestion() async {
    // 这里应该调用AI服务获取修复建议
    // 目前返回默认建议
    return _getDefaultSuggestion(widget.conflict.type);
  }

  Future<void> _applyFix(String suggestion) async {
    // 根据冲突类型应用不同的修复策略
    // ignore: unused_local_variable
    final repository = Get.find<TimelineRepository>();

    switch (widget.conflict.type) {
      case ConflictType.locationConflict:
        // 对于地点冲突，可能需要更新事件地点
        // 这里简化处理，实际应该解析AI建议并执行相应操作
        break;
      case ConflictType.timeSequence:
        // 调整事件时间顺序
        break;
      case ConflictType.stateConflict:
        // 更新角色状态
        break;
      case ConflictType.characterAvailability:
        // 调整角色可用性
        break;
    }
  }

  Future<void> _markAsResolved() async {
    // 更新冲突状态
    // 这里需要在数据库中添加冲突表来持久化冲突状态
    // 目前简化处理
  }

  Future<void> _markAsManuallyResolved() async {
    final s = S.of(context)!;
    await _markAsResolved();
    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.timeline_conflictMarkedResolved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context)!;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: 8.w),
          Text(s.timeline_resolutionSuggestion),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 冲突描述
            Text(
              '${s.timeline_conflictType}${widget.conflict.type.label}',
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: 8.h),
            Text(
              widget.conflict.description,
              style: theme.textTheme.bodyMedium,
            ),
            SizedBox(height: 16.h),

            // 修复建议
            if (widget.conflict.suggestion != null) ...[
              Text(
                s.timeline_suggestedFix,
                style: theme.textTheme.titleSmall,
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  widget.conflict.suggestion!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ] else ...[
              Text(
                s.timeline_suggestedFix,
                style: theme.textTheme.titleSmall,
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  _getDefaultSuggestion(widget.conflict.type),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
            SizedBox(height: 16.h),

            // AI修复选项
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      s.timeline_aiAutoFix,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isApplyingFix ? null : () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: _isApplyingFix ? null : _markAsManuallyResolved,
          child: Text(s.timeline_markAsResolved),
        ),
        FilledButton(
          onPressed: _isApplyingFix ? null : _applyAIFix,
          child: _isApplyingFix
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 16.sp),
                    SizedBox(width: 4.w),
                    Text(s.timeline_aiAutoFixButton),
                  ],
                ),
        ),
      ],
    );
  }

  String _getDefaultSuggestion(ConflictType type) {
    final s = S.of(context)!;
    return switch (type) {
      ConflictType.timeSequence => s.timeline_timeSequenceFix,
      ConflictType.locationConflict => s.timeline_locationConflictFix,
      ConflictType.stateConflict => s.timeline_stateConflictFix,
      ConflictType.characterAvailability => s.timeline_characterAvailabilityFix,
    };
  }
}
