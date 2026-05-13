import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/writing_stats_models.dart';

// ============================================================================
// 统计卡片
// ============================================================================

/// 单个指标统计卡片。
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.icon,
    this.color,
  });

  final String label;
  final int value;
  final String unit;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: effectiveColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatNumber(value),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatNumber(int n) {
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}万';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toString();
  }
}

// ============================================================================
// 目标进度条
// ============================================================================

/// 单个目标的进度指示器。
class GoalProgressIndicator extends StatelessWidget {
  const GoalProgressIndicator({
    super.key,
    required this.goal,
    required this.progress,
    this.onToggle,
    this.onDelete,
  });

  final WritingGoal goal;
  final double progress;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = progress >= 1.0;
    final color = reached ? Colors.green : theme.colorScheme.primary;
    final label = switch (goal.goalType) {
      WritingGoalType.dailyChars => '每日 ${goal.targetValue} 字',
      WritingGoalType.weeklyChars => '每周 ${goal.targetValue} 字',
      WritingGoalType.projectTotalChars => '项目 ${goal.targetValue} 字',
      WritingGoalType.dailyChapters => '每日 ${goal.targetValue} 章',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  reached ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onToggle != null)
                  IconButton(
                    icon: Icon(
                      goal.enabled ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                    ),
                    onPressed: onToggle,
                    tooltip: goal.enabled ? '关闭提醒' : '开启提醒',
                    visualDensity: VisualDensity.compact,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDelete,
                    tooltip: '删除目标',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 日趋势条形图（纯 CustomPainter，无第三方依赖）
// ============================================================================

/// 7 天字数趋势条形图。
class DailyTrendChart extends StatelessWidget {
  const DailyTrendChart({
    super.key,
    required this.dailyStats,
    this.maxDays = 7,
  });

  final List<WritingDailyStat> dailyStats;
  final int maxDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _aggregateByDate();
    if (data.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '暂无写作数据',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 140,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarChartPainter(
          data: data,
          barColor: theme.colorScheme.primary,
          textColor: theme.colorScheme.onSurfaceVariant,
          gridColor: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
    );
  }

  /// 按日期聚合 deltaChars，取最近 maxDays 天。
  List<_ChartDatum> _aggregateByDate() {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: maxDays - 1));
    final startStr = _dateStr(startDate);

    final map = <String, int>{};
    for (final stat in dailyStats) {
      if (stat.date.compareTo(startStr) >= 0) {
        map[stat.date] = (map[stat.date] ?? 0) + stat.deltaChars;
      }
    }

    return List.generate(maxDays, (i) {
      final date = startDate.add(Duration(days: i));
      final key = _dateStr(date);
      return _ChartDatum(
        label: '${date.month}/${date.day}',
        value: map[key] ?? 0,
      );
    });
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _ChartDatum {
  const _ChartDatum({required this.label, required this.value});
  final String label;
  final int value;
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.barColor,
    required this.textColor,
    required this.gridColor,
  });

  final List<_ChartDatum> data;
  final Color barColor;
  final Color textColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const bottomPadding = 24.0;
    const leftPadding = 4.0;
    const topPadding = 8.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final chartWidth = size.width - leftPadding;
    final barWidth = (chartWidth / data.length) * 0.6;
    final gap = (chartWidth / data.length) * 0.4;

    final maxValue = data.map((d) => d.value).reduce(math.max);
    final effectiveMax = maxValue > 0 ? maxValue : 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < data.length; i++) {
      final x = leftPadding + i * (barWidth + gap) + gap / 2;
      final barHeight = (data[i].value / effectiveMax) * chartHeight;
      final y = topPadding + chartHeight - barHeight;

      // 绘制网格线
      if (i == 0) {
        for (var g = 0; g <= 4; g++) {
          final gy = topPadding + chartHeight * (1 - g / 4);
          canvas.drawLine(
            Offset(leftPadding, gy),
            Offset(size.width, gy),
            Paint()
              ..color = gridColor
              ..strokeWidth = 0.5,
          );
        }
      }

      // 绘制柱体
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = barColor.withAlpha(data[i].value > 0 ? 200 : 60),
      );

      // 绘制标签
      textPainter.text = TextSpan(
        text: data[i].label,
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + (barWidth - textPainter.width) / 2,
          size.height - bottomPadding + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.barColor != barColor;
}

// ============================================================================
// 添加目标对话框
// ============================================================================

class AddGoalDialog extends StatefulWidget {
  const AddGoalDialog({super.key, required this.projectId});

  final String projectId;

  @override
  State<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<AddGoalDialog> {
  WritingGoalType _goalType = WritingGoalType.dailyChars;
  final _targetController = TextEditingController(text: '2000');

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加写作目标'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<WritingGoalType>(
            initialValue: _goalType,
            decoration: const InputDecoration(labelText: '目标类型'),
            items: const [
              DropdownMenuItem(
                value: WritingGoalType.dailyChars,
                child: Text('每日字数'),
              ),
              DropdownMenuItem(
                value: WritingGoalType.weeklyChars,
                child: Text('每周字数'),
              ),
              DropdownMenuItem(
                value: WritingGoalType.projectTotalChars,
                child: Text('项目总字数'),
              ),
              DropdownMenuItem(
                value: WritingGoalType.dailyChapters,
                child: Text('每日章节'),
              ),
            ],
            onChanged: (v) => setState(() => _goalType = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            decoration: const InputDecoration(labelText: '目标值'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('添加'),
        ),
      ],
    );
  }

  void _submit() {
    final target = int.tryParse(_targetController.text);
    if (target == null || target <= 0) return;
    final period = switch (_goalType) {
      WritingGoalType.dailyChars || WritingGoalType.dailyChapters =>
        WritingGoalPeriod.daily,
      WritingGoalType.weeklyChars => WritingGoalPeriod.weekly,
      WritingGoalType.projectTotalChars => WritingGoalPeriod.project,
    };
    final goal = WritingGoal(
      id: 'goal-${DateTime.now().millisecondsSinceEpoch}',
      projectId: widget.projectId,
      goalType: _goalType,
      targetValue: target,
      period: period,
      enabled: true,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    Navigator.pop(context, goal);
  }
}
