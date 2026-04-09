import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/statistics/domain/statistics_models.dart';

/// 字数图表组件
class WordCountChart extends StatelessWidget {
  final List<DailyWordCount> data;
  final ChartType type;
  final bool showCumulative;

  const WordCountChart({
    super.key,
    required this.data,
    this.type = ChartType.bar,
    this.showCumulative = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(s.statistics_noData, style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 图例
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(color: Theme.of(context).colorScheme.primary, label: s.statistics_wordCount),
            if (showCumulative) ...[
              SizedBox(width: 24.w),
              _LegendItem(color: Colors.orange, label: s.statistics_cumulative),
            ],
          ],
        ),
        SizedBox(height: 16.h),

        // 图表
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ChartPainter(
              data: data,
              type: type,
              showCumulative: showCumulative,
              primaryColor: Theme.of(context).colorScheme.primary,
              secondaryColor: Colors.orange,
            ),
          ),
        ),

        // 底部日期标签
        _buildDateLabels(context),
      ],
    );
  }

  Widget _buildDateLabels(BuildContext context) {
    // 只显示部分日期标签避免拥挤
    final step = (data.length / 5).ceil();
    final labels = <Widget>[];

    for (int i = 0; i < data.length; i += step) {
      final item = data[i];
      labels.add(
        Text(
          '${item.date.month}/${item.date.day}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels,
    );
  }
}

/// 图表类型
enum ChartType {
  bar,     // 柱状图
  line,    // 折线图
  area,    // 面积图
}

/// 图例项
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 4.w),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// 图表绘制器
class _ChartPainter extends CustomPainter {
  final List<DailyWordCount> data;
  final ChartType type;
  final bool showCumulative;
  final Color primaryColor;
  final Color secondaryColor;

  _ChartPainter({
    required this.data,
    required this.type,
    required this.showCumulative,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = data.map((e) => e.wordCount).reduce((a, b) => a > b ? a : b);
    final cumulativeMax = showCumulative
        ? data.fold<int>(0, (sum, e) => sum + e.wordCount)
        : 0;

    final chartHeight = size.height - 40;
    final chartWidth = size.width;

    // 绘制网格线
    _drawGridLines(canvas, size, chartHeight);

    // 根据类型绘制图表
    switch (type) {
      case ChartType.bar:
        _drawBarChart(canvas, size, chartHeight, chartWidth, maxValue);
        break;
      case ChartType.line:
        _drawLineChart(canvas, size, chartHeight, chartWidth, maxValue);
        break;
      case ChartType.area:
        _drawAreaChart(canvas, size, chartHeight, chartWidth, maxValue);
        break;
    }

    // 绘制累计线
    if (showCumulative) {
      _drawCumulativeLine(canvas, size, chartHeight, chartWidth, cumulativeMax);
    }
  }

  void _drawGridLines(Canvas canvas, Size size, double chartHeight) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = (chartHeight / 4) * i + 20;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawBarChart(
    Canvas canvas,
    Size size,
    double chartHeight,
    double chartWidth,
    int maxValue,
  ) {
    final barWidth = chartWidth / data.length - 4;
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final barHeight = (item.wordCount / maxValue) * chartHeight;
      final x = i * (chartWidth / data.length) + 2;
      final y = chartHeight - barHeight + 20;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  void _drawLineChart(
    Canvas canvas,
    Size size,
    double chartHeight,
    double chartWidth,
    int maxValue,
  ) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final x = (i / (data.length - 1)) * chartWidth;
      final y = chartHeight - (item.wordCount / maxValue) * chartHeight + 20;
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);

      // 绘制数据点
      final dotPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      for (final point in points) {
        canvas.drawCircle(point, 4, dotPaint);
      }
    }
  }

  void _drawAreaChart(
    Canvas canvas,
    Size size,
    double chartHeight,
    double chartWidth,
    int maxValue,
  ) {
    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path = Path();

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final x = (i / (data.length - 1)) * chartWidth;
      final y = chartHeight - (item.wordCount / maxValue) * chartHeight + 20;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.lineTo(chartWidth, chartHeight + 20);
    path.lineTo(0, chartHeight + 20);
    path.close();

    canvas.drawPath(path, paint);

    // 绘制顶部线条
    _drawLineChart(canvas, size, chartHeight, chartWidth, maxValue);
  }

  void _drawCumulativeLine(
    Canvas canvas,
    Size size,
    double chartHeight,
    double chartWidth,
    int maxValue,
  ) {
    final paint = Paint()
      ..color = secondaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    int cumulative = 0;

    for (int i = 0; i < data.length; i++) {
      cumulative += data[i].wordCount;
      final x = (i / (data.length - 1)) * chartWidth;
      final y = chartHeight - (cumulative / maxValue) * chartHeight + 20;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
