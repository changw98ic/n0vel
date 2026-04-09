import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../features/statistics/domain/statistics_models.dart';
import '../../../features/statistics/data/statistics_service.dart';
import '../view/statistics_overview.dart';
import '../view/word_count_chart.dart';
import '../view/chapter_progress_widget.dart';
import '../view/writing_goals_widget.dart';
import '../../../shared/data/base_business/base_page.dart';
import 'statistics_logic.dart';

const _chapterStatusColors = <ChapterStatus, Color>{
  ChapterStatus.draft: Colors.grey,
  ChapterStatus.writing: Colors.blue,
  ChapterStatus.revision: Colors.teal,
  ChapterStatus.review: Colors.indigo,
  ChapterStatus.published: Colors.green,
};

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// 统计页面
class StatisticsView extends GetView<StatisticsLogic> with BasePage {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AppPageScaffold(
      title: s.statistics_title,
      bodyPadding: EdgeInsets.zero,
      bottom: Obx(() => TabBar(
        controller: controller.state.tabController.value,
        tabs: [
          Tab(text: s.statistics_overviewTab),
          Tab(text: s.statistics_wordCountTrendTab),
          Tab(text: s.statistics_chapterProgressTab),
          Tab(text: s.statistics_writingGoalsTab),
        ],
      )),
      actions: [
        // 周期选择
        Obx(() => PopupMenuButton<TrendPeriod>(
          initialValue: controller.state.selectedPeriod.value,
          onSelected: controller.setSelectedPeriod,
          itemBuilder: (context) => TrendPeriod.values.map((period) {
            return PopupMenuItem(
              value: period,
              child: Text(period.label),
            );
          }).toList(),
          icon: const Icon(Icons.calendar_today),
        )),
        // 导出报告
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: () => _exportReport(context),
          tooltip: s.statistics_exportReport,
        ),
      ],
      child: _buildBody(context, s),
    );
  }

  Widget _buildBody(BuildContext context, S s) {
    return Obx(() {
      if (controller.state.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.state.statistics.value == null) {
        return Center(child: Text(s.statistics_loadFailed));
      }

      return TabBarView(
        controller: controller.state.tabController.value,
        children: [
          _OverviewTab(stats: controller.state.statistics.value!),
          _TrendTab(
            workId: controller.workId,
            period: controller.state.selectedPeriod.value,
          ),
          _ProgressTab(stats: controller.state.statistics.value!),
          _GoalsTab(workId: controller.workId),
        ],
      );
    });
  }

  Future<void> _exportReport(BuildContext context) async {
    final s = S.of(context)!;
    // 显示格式选择对话框
    final format = await showDialog<ExportFormat>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.statistics_selectExportFormat),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description),
              title: Text(s.statistics_jsonFormat),
              subtitle: Text(s.statistics_jsonFormatDescription),
              onTap: () => Get.back(result: ExportFormat.json),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: Text(s.statistics_csvFormat),
              subtitle: Text(s.statistics_csvFormatDescription),
              onTap: () => Get.back(result: ExportFormat.csv),
            ),
          ],
        ),
      ),
    );

    if (format == null) return;

    try {
      String content;
      String fileName;

      switch (format) {
        case ExportFormat.json:
          content = await controller.exportReportJson();
          fileName = 'statistics_${controller.workId}_${DateTime.now().toIso8601String().split('T')[0]}.json';
          break;
        case ExportFormat.csv:
          content = await controller.exportReportCsv();
          fileName = 'statistics_${controller.workId}_${DateTime.now().toIso8601String().split('T')[0]}.csv';
          break;
      }

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);

      // 保存到最近导出记录
      final prefs = await SharedPreferences.getInstance();
      final recentExports = prefs.getStringList('recent_exports') ?? [];
      recentExports.add('${file.path}|${DateTime.now().toIso8601String()}');
      if (recentExports.length > 10) {
        recentExports.removeAt(0);
      }
      await prefs.setStringList('recent_exports', recentExports);

      if (!context.mounted) return;
      Get.snackbar(
        '成功',
        s.statistics_reportExported(file.path),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (!context.mounted) return;
      Get.snackbar(
        '失败',
        s.statistics_exportFailed(e.toString()),
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

/// 概览标签页
class _OverviewTab extends StatelessWidget {
  final WorkStatistics stats;

  const _OverviewTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 核心指标卡片
          StatisticsOverview(stats: stats),
          SizedBox(height: 24.h),

          // 字数趋势图
          AppSectionCard(
            title: '近期字数趋势',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                SizedBox(
                  height: 200,
                  child: WordCountChart(
                    data: stats.recentWordCounts,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // 章节进度
          ChapterProgressWidget(
            chapters: stats.chapterProgressList,
            totalWords: stats.totalWords,
          ),
        ],
      ),
    );
  }
}

/// 趋势标签页
class _TrendTab extends StatefulWidget {
  final String workId;
  final TrendPeriod period;

  const _TrendTab({
    required this.workId,
    required this.period,
  });

  @override
  State<_TrendTab> createState() => _TrendTabState();
}

class _TrendTabState extends State<_TrendTab> {
  WordCountTrend? _trend;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  @override
  void didUpdateWidget(_TrendTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _loadTrend();
    }
  }

  Future<void> _loadTrend() async {
    setState(() => _isLoading = true);
    try {
      final service = Get.find<StatisticsService>();
      final trend = await service.getWordCountTrend(widget.workId, period: widget.period);
      setState(() {
        _trend = trend;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trend == null) {
      return const Center(child: Text('加载失败'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 增长统计卡片
          Row(
            children: [
              Expanded(
                child: AppStatCard(
                  icon: Icons.trending_up,
                  label: '总增长',
                  value: '${_trend!.totalGrowth} 字',
                  hint: '',
                  accent: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: AppStatCard(
                  icon: Icons.percent,
                  label: '增长率',
                  value: '${(_trend!.growthRate * 100).toStringAsFixed(1)}%',
                  hint: '',
                  accent: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // 趋势图
          AppSectionCard(
            title: '字数趋势',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                SizedBox(
                  height: 300,
                  child: _TrendChart(dataPoints: _trend!.dataPoints),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // 数据表格
          AppSectionCard(
            title: '详细数据',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                _DataTable(dataPoints: _trend!.dataPoints),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 进度标签页
class _ProgressTab extends StatelessWidget {
  final WorkStatistics stats;

  const _ProgressTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 完成进度
          AppSectionCard(
            title: '完成进度',
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
                    '预计完成日期：${_formatDate(stats.estimatedCompletionDate!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '预计还需 ${stats.estimatedDaysToComplete} 天',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // 章节状态分布
          AppSectionCard(
            title: '章节状态分布',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                Row(
                  children: [
                    _StatusChip(
                      label: '已发布',
                      count: stats.publishedChapters,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    _StatusChip(
                      label: '草稿',
                      count: stats.draftChapters,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    SizedBox(width: 8.w),
                    _StatusChip(
                      label: '总计',
                      count: stats.totalChapters,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // 章节列表
          AppSectionCard(
            title: '章节列表',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                ...stats.chapterProgressList.map((chapter) => ListTile(
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: _chapterStatusColors[chapter.status] ?? Theme.of(context).colorScheme.outline,
                        child: Text(
                          '${chapter.order}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10.sp,
                          ),
                        ),
                      ),
                      title: Text(chapter.chapterTitle),
                      subtitle: Text('${chapter.wordCount} 字'),
                      trailing: _StatusBadge(status: chapter.status),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 目标标签页
class _GoalsTab extends StatelessWidget {
  final String workId;

  const _GoalsTab({required this.workId});

  @override
  Widget build(BuildContext context) {
    return WritingGoalsWidget(workId: workId);
  }
}

/// 状态标签
class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip({
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

/// 状态徽章
class _StatusBadge extends StatelessWidget {
  final ChapterStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _chapterStatusColors[status] ?? Theme.of(context).colorScheme.outline;

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

/// 趋势图表
class _TrendChart extends StatelessWidget {
  final List<TrendDataPoint> dataPoints;

  const _TrendChart({required this.dataPoints});

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    // 简单的柱状图展示
    return CustomPaint(
      size: const Size(double.infinity, 300),
      painter: _TrendChartPainter(dataPoints, Theme.of(context).colorScheme.primary),
    );
  }
}

/// 趋势图表绘制器
class _TrendChartPainter extends CustomPainter {
  final List<TrendDataPoint> dataPoints;
  final Color color;

  _TrendChartPainter(this.dataPoints, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final maxValue = dataPoints.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final barWidth = size.width / dataPoints.length - 4;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dataPoints.length; i++) {
      final point = dataPoints[i];
      final barHeight = (point.value / maxValue) * (size.height - 40);
      final x = i * (barWidth + 4) + 2;
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

/// 数据表格
class _DataTable extends StatelessWidget {
  final List<TrendDataPoint> dataPoints;

  const _DataTable({required this.dataPoints});

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('日期')),
        DataColumn(label: Text('当日字数')),
        DataColumn(label: Text('累计字数')),
      ],
      rows: dataPoints.reversed.take(10).map((point) {
        return DataRow(cells: [
          DataCell(Text('${point.date.month}/${point.date.day}')),
          DataCell(Text('${point.value}')),
          DataCell(Text('${point.cumulativeValue}')),
        ]);
      }).toList(),
    );
  }
}

/// 导出格式
enum ExportFormat {
  json,
  csv,
  ;

  String get label => switch (this) {
    json => 'JSON',
    csv => 'CSV',
  };
}
