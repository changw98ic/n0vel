import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../features/statistics/domain/statistics_models.dart';
import '../view/chapter_progress_widget.dart';
import '../view/statistics_overview.dart';
import '../view/word_count_chart.dart';

const statisticsChapterStatusColors = <ChapterStatus, Color>{
  ChapterStatus.draft: Colors.grey,
  ChapterStatus.writing: Colors.blue,
  ChapterStatus.revision: Colors.teal,
  ChapterStatus.review: Colors.indigo,
  ChapterStatus.published: Colors.green,
};

String formatStatisticsDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class StatisticsOverviewTabContent extends StatelessWidget {
  final WorkStatistics stats;

  const StatisticsOverviewTabContent({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatisticsOverview(stats: stats),
          SizedBox(height: 24.h),
          AppSectionCard(
            title: '杩戞湡瀛楁暟瓒嬪娍',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                SizedBox(
                  height: 200,
                  child: WordCountChart(data: stats.recentWordCounts),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          ChapterProgressWidget(
            chapters: stats.chapterProgressList,
            totalWords: stats.totalWords,
          ),
        ],
      ),
    );
  }
}

class StatisticsTrendContent extends StatelessWidget {
  final WordCountTrend trend;

  const StatisticsTrendContent({
    super.key,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppStatCard(
                  icon: Icons.trending_up,
                  label: '鎬诲闀?',
                  value: '${trend.totalGrowth} 瀛?',
                  hint: '',
                  accent: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: AppStatCard(
                  icon: Icons.percent,
                  label: '澧為暱鐜?',
                  value: '${(trend.growthRate * 100).toStringAsFixed(1)}%',
                  hint: '',
                  accent: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          AppSectionCard(
            title: '瀛楁暟瓒嬪娍',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                SizedBox(
                  height: 300,
                  child: StatisticsTrendChart(dataPoints: trend.dataPoints),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          AppSectionCard(
            title: '璇︾粏鏁版嵁',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                StatisticsTrendDataTable(dataPoints: trend.dataPoints),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatisticsProgressTabContent extends StatelessWidget {
  final WorkStatistics stats;

  const StatisticsProgressTabContent({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionCard(
            title: '瀹屾垚杩涘害',
            subtitle: '${(stats.completionRate * 100).toStringAsFixed(1)}%',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                LinearProgressIndicator(
                  value: stats.completionRate.clamp(0.0, 1.0),
                  minHeight: 8.h,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                if (stats.estimatedCompletionDate != null) ...[
                  SizedBox(height: 16.h),
                  Text(
                    '棰勮瀹屾垚鏃ユ湡锛?{formatStatisticsDate(stats.estimatedCompletionDate!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '棰勮杩橀渶 ${stats.estimatedDaysToComplete} 澶?',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 24.h),
          AppSectionCard(
            title: '绔犺妭鐘舵€佸垎甯?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                Row(
                  children: [
                    StatisticsStatusChip(
                      label: '宸插彂甯?',
                      count: stats.publishedChapters,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    StatisticsStatusChip(
                      label: '鑽夌',
                      count: stats.draftChapters,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    SizedBox(width: 8.w),
                    StatisticsStatusChip(
                      label: '鎬昏',
                      count: stats.totalChapters,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          AppSectionCard(
            title: '绔犺妭鍒楄〃',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                ...stats.chapterProgressList.map(
                  (chapter) => ListTile(
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: statisticsChapterStatusColors[chapter.status] ??
                          Theme.of(context).colorScheme.outline,
                      child: Text(
                        '${chapter.order}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                    title: Text(chapter.chapterTitle),
                    subtitle: Text('${chapter.wordCount} 瀛?'),
                    trailing: StatisticsStatusBadge(status: chapter.status),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatisticsStatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const StatisticsStatusChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontSize: 12.sp),
      ),
    );
  }
}

class StatisticsStatusBadge extends StatelessWidget {
  final ChapterStatus status;

  const StatisticsStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        statisticsChapterStatusColors[status] ?? Theme.of(context).colorScheme.outline;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 12.sp),
      ),
    );
  }
}

class StatisticsTrendChart extends StatelessWidget {
  final List<TrendDataPoint> dataPoints;

  const StatisticsTrendChart({
    super.key,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return const Center(child: Text('鏆傛棤鏁版嵁'));
    }

    return CustomPaint(
      size: const Size(double.infinity, 300),
      painter: StatisticsTrendChartPainter(
        dataPoints,
        Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class StatisticsTrendChartPainter extends CustomPainter {
  final List<TrendDataPoint> dataPoints;
  final Color color;

  StatisticsTrendChartPainter(this.dataPoints, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final maxValue =
        dataPoints.map((point) => point.value).reduce((a, b) => a > b ? a : b);
    final barWidth = size.width / dataPoints.length - 4;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var index = 0; index < dataPoints.length; index++) {
      final point = dataPoints[index];
      final barHeight = (point.value / maxValue) * (size.height - 40);
      final x = index * (barWidth + 4) + 2;
      final y = size.height - barHeight - 20;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StatisticsTrendDataTable extends StatelessWidget {
  final List<TrendDataPoint> dataPoints;

  const StatisticsTrendDataTable({
    super.key,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('鏃ユ湡')),
        DataColumn(label: Text('褰撴棩瀛楁暟')),
        DataColumn(label: Text('绱瀛楁暟')),
      ],
      rows: dataPoints.reversed.take(10).map((point) {
        return DataRow(
          cells: [
            DataCell(Text('${point.date.month}/${point.date.day}')),
            DataCell(Text('${point.value}')),
            DataCell(Text('${point.cumulativeValue}')),
          ],
        );
      }).toList(),
    );
  }
}
