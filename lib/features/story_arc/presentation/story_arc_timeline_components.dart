import 'package:flutter/material.dart';

import '../../../app/theme/app_design_tokens.dart';
import '../../story_generation/data/narrative_arc_models.dart';

/// 时间线中的场景卡片
///
/// 显示场景 ID、关联的情节线和伏笔数量，支持拖拽手柄。
class TimelineSceneCard extends StatelessWidget {
  const TimelineSceneCard({
    super.key,
    required this.sceneId,
    required this.index,
    required this.threads,
    required this.foreshadowing,
  });

  final String sceneId;
  final int index;
  final List<PlotThread> threads;
  final List<Foreshadowing> foreshadowing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAlerts = foreshadowing.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: AppDesignTokens.space4,
        horizontal: AppDesignTokens.space4,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {}, // 预留：点击跳转到场景编辑
        child: Row(
          children: [
            // 拖拽手柄 + 序号
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(
                vertical: AppDesignTokens.space12,
              ),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.drag_indicator,
                    size: AppDesignTokens.iconSmall,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: AppDesignTokens.space4),
                  Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            // 场景内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppDesignTokens.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 场景标题行
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sceneId,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasAlerts) _AlertBadge(count: foreshadowing.length),
                      ],
                    ),
                    if (threads.isNotEmpty) ...[
                      const SizedBox(height: AppDesignTokens.space8),
                      Wrap(
                        spacing: AppDesignTokens.space4,
                        runSpacing: AppDesignTokens.space4,
                        children: [
                          for (final thread in threads)
                            _ThreadChip(thread: thread),
                        ],
                      ),
                    ],
                    if (foreshadowing.isNotEmpty) ...[
                      const SizedBox(height: AppDesignTokens.space8),
                      Wrap(
                        spacing: AppDesignTokens.space4,
                        runSpacing: AppDesignTokens.space4,
                        children: [
                          for (final f in foreshadowing)
                            _ForeshadowingChip(foreshadowing: f),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 张力曲线图表
///
/// 用简易 CustomPaint 绘制情节线活跃度和伏笔紧急度的走势。
class TensionCurveChart extends StatelessWidget {
  const TensionCurveChart({
    super.key,
    required this.threads,
    required this.foreshadowing,
  });

  final List<PlotThread> threads;
  final List<Foreshadowing> foreshadowing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = threads.isNotEmpty || foreshadowing.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.show_chart,
                  size: AppDesignTokens.iconSmall,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppDesignTokens.space8),
                Text(
                  '张力曲线',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _LegendDot(
                  color: theme.colorScheme.primary,
                  label: '情节线',
                ),
                const SizedBox(width: AppDesignTokens.space12),
                _LegendDot(
                  color: theme.colorScheme.error,
                  label: '伏笔',
                ),
              ],
            ),
            const SizedBox(height: AppDesignTokens.space8),
            SizedBox(
              height: 80,
              child: hasData
                  ? CustomPaint(
                      painter: _TensionCurvePainter(
                        threads: threads,
                        foreshadowing: foreshadowing,
                        primaryColor: theme.colorScheme.primary,
                        errorColor: theme.colorScheme.error,
                        surfaceColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                      size: Size.infinite,
                    )
                  : Center(
                      child: Text(
                        '暂无数据',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TensionCurvePainter extends CustomPainter {
  _TensionCurvePainter({
    required this.threads,
    required this.foreshadowing,
    required this.primaryColor,
    required this.errorColor,
    required this.surfaceColor,
  });

  final List<PlotThread> threads;
  final List<Foreshadowing> foreshadowing;
  final Color primaryColor;
  final Color errorColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // 背景网格线
    final gridPaint = Paint()
      ..color = surfaceColor
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (threads.isEmpty && foreshadowing.isEmpty) return;

    // 绘制情节线走势（基于 status 编码为数值）
    paint.color = primaryColor;
    _drawCurve(canvas, size, threads.length, (i) {
      final status = threads[i].status;
      return switch (status) {
        PlotThreadStatus.rising => 0.3,
        PlotThreadStatus.climax => 0.9,
        PlotThreadStatus.falling => 0.6,
        PlotThreadStatus.resolved => 0.1,
      };
    }, paint);

    // 绘制伏笔紧急度走势
    paint.color = errorColor;
    _drawCurve(canvas, size, foreshadowing.length, (i) {
      return (foreshadowing[i].urgency.clamp(0, 2)) / 2.0;
    }, paint);
  }

  void _drawCurve(
    Canvas canvas,
    Size size,
    int count,
    double Function(int) valueAt,
    Paint paint,
  ) {
    if (count == 0) return;
    final path = Path();
    for (var i = 0; i < count; i++) {
      final x = count == 1 ? size.width / 2 : size.width * i / (count - 1);
      final y = size.height * (1.0 - valueAt(i));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TensionCurvePainter old) =>
      old.threads != threads || old.foreshadowing != foreshadowing;
}

/// 伏笔卡片
class ForeshadowingCard extends StatelessWidget {
  const ForeshadowingCard({
    super.key,
    required this.foreshadowing,
    required this.isResolved,
    this.onResolve,
    this.onUrgencyChanged,
  });

  final Foreshadowing foreshadowing;
  final bool isResolved;
  final VoidCallback? onResolve;
  final ValueChanged<int>? onUrgencyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgencyColor = _urgencyColor(foreshadowing.urgency, theme);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppDesignTokens.space4),
      color: isResolved
          ? theme.colorScheme.surfaceContainerHighest
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 紧急度指示器
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isResolved
                        ? theme.colorScheme.outlineVariant
                        : urgencyColor,
                    borderRadius: AppDesignTokens.borderRadiusSmall,
                  ),
                ),
                const SizedBox(width: AppDesignTokens.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        foreshadowing.hint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: isResolved
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (foreshadowing.plannedPayoff.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppDesignTokens.space4,
                          ),
                          child: Text(
                            '预期回收: ${foreshadowing.plannedPayoff}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 操作按钮
                if (!isResolved && onResolve != null)
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    tooltip: '标记已回收',
                    onPressed: onResolve,
                  ),
              ],
            ),
            // 紧急度调节
            if (!isResolved && onUrgencyChanged != null) ...[
              const SizedBox(height: AppDesignTokens.space8),
              Row(
                children: [
                  Text(
                    '紧急度',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: AppDesignTokens.space8),
                  for (var i = 0; i <= 2; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppDesignTokens.space4,
                      ),
                      child: InkWell(
                        onTap: () => onUrgencyChanged!(i),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: foreshadowing.urgency >= i
                                ? _urgencyColor(i, theme)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: AppDesignTokens.borderRadiusSmall,
                          ),
                          child: Center(
                            child: Text(
                              ['低', '中', '高'][i],
                              style: TextStyle(
                                fontSize: 10,
                                color: foreshadowing.urgency >= i
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _urgencyColor(int urgency, ThemeData theme) {
    return switch (urgency) {
      0 => theme.colorScheme.primary,
      1 => theme.colorScheme.tertiary,
      _ => theme.colorScheme.error,
    };
  }
}

// ============================================================================
// 内部组件
// ============================================================================

class _AlertBadge extends StatelessWidget {
  const _AlertBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.space8,
        vertical: AppDesignTokens.space4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber,
            size: 12,
            color: Theme.of(context).colorScheme.onError,
          ),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadChip extends StatelessWidget {
  const _ThreadChip({required this.thread});

  final PlotThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (thread.status) {
      PlotThreadStatus.rising => theme.colorScheme.primary,
      PlotThreadStatus.climax => theme.colorScheme.error,
      PlotThreadStatus.falling => theme.colorScheme.tertiary,
      PlotThreadStatus.resolved => theme.colorScheme.outline,
    };
    final label = switch (thread.status) {
      PlotThreadStatus.rising => '升',
      PlotThreadStatus.climax => '峰',
      PlotThreadStatus.falling => '降',
      PlotThreadStatus.resolved => '结',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppDesignTokens.borderRadiusSmall,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              thread.description,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForeshadowingChip extends StatelessWidget {
  const _ForeshadowingChip({required this.foreshadowing});

  final Foreshadowing foreshadowing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUrgent = foreshadowing.urgency >= 2;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isUrgent
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.tertiaryContainer,
        borderRadius: AppDesignTokens.borderRadiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUrgent) ...[
            Icon(
              Icons.priority_high,
              size: 10,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 2),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              foreshadowing.hint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isUrgent
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onTertiaryContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
