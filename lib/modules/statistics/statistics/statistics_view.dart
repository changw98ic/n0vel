import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../features/statistics/data/statistics_service.dart';
import '../../../features/statistics/domain/statistics_models.dart';
import '../../../shared/data/base_business/base_page.dart';
import '../view/writing_goals_widget.dart';
import 'statistics_logic.dart';
import 'statistics_sections.dart';

/// 缁熻椤甸潰
class StatisticsView extends GetView<StatisticsLogic> with BasePage {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AppPageScaffold(
      title: s.statistics_title,
      bodyPadding: EdgeInsets.zero,
      bottom: Obx(
        () => TabBar(
          controller: controller.state.tabController.value,
          tabs: [
            Tab(text: s.statistics_overviewTab),
            Tab(text: s.statistics_wordCountTrendTab),
            Tab(text: s.statistics_chapterProgressTab),
            Tab(text: s.statistics_writingGoalsTab),
          ],
        ),
      ),
      actions: [
        Obx(
          () => PopupMenuButton<TrendPeriod>(
            initialValue: controller.state.selectedPeriod.value,
            onSelected: controller.setSelectedPeriod,
            itemBuilder: (context) => TrendPeriod.values.map((period) {
              return PopupMenuItem(
                value: period,
                child: Text(period.label),
              );
            }).toList(),
            icon: const Icon(Icons.calendar_today),
          ),
        ),
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

      final statistics = controller.state.statistics.value;
      if (statistics == null) {
        return Center(child: Text(s.statistics_loadFailed));
      }

      return TabBarView(
        controller: controller.state.tabController.value,
        children: [
          _OverviewTab(stats: statistics),
          _TrendTab(
            workId: controller.workId,
            period: controller.state.selectedPeriod.value,
          ),
          _ProgressTab(stats: statistics),
          _GoalsTab(workId: controller.workId),
        ],
      );
    });
  }

  Future<void> _exportReport(BuildContext context) async {
    final s = S.of(context)!;
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
      late final String content;
      late final String fileName;
      final date = DateTime.now().toIso8601String().split('T')[0];

      switch (format) {
        case ExportFormat.json:
          content = await controller.exportReportJson();
          fileName = 'statistics_${controller.workId}_$date.json';
        case ExportFormat.csv:
          content = await controller.exportReportCsv();
          fileName = 'statistics_${controller.workId}_$date.csv';
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);

      final prefs = await SharedPreferences.getInstance();
      final recentExports = prefs.getStringList('recent_exports') ?? [];
      recentExports.add('${file.path}|${DateTime.now().toIso8601String()}');
      if (recentExports.length > 10) {
        recentExports.removeAt(0);
      }
      await prefs.setStringList('recent_exports', recentExports);

      if (!context.mounted) return;
      Get.snackbar(
        '鎴愬姛',
        s.statistics_reportExported(file.path),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      if (!context.mounted) return;
      Get.snackbar(
        '澶辫触',
        s.statistics_exportFailed(error.toString()),
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

/// 姒傝鏍囩椤?
class _OverviewTab extends StatelessWidget {
  final WorkStatistics stats;

  const _OverviewTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    return StatisticsOverviewTabContent(stats: stats);
  }
}

/// 瓒嬪娍鏍囩椤?
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
      final trend = await service.getWordCountTrend(
        widget.workId,
        period: widget.period,
      );
      setState(() {
        _trend = trend;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trend == null) {
      return const Center(child: Text('鍔犺浇澶辫触'));
    }

    return StatisticsTrendContent(trend: _trend!);
  }
}

/// 杩涘害鏍囩椤?
class _ProgressTab extends StatelessWidget {
  final WorkStatistics stats;

  const _ProgressTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    return StatisticsProgressTabContent(stats: stats);
  }
}

/// 鐩爣鏍囩椤?
class _GoalsTab extends StatelessWidget {
  final String workId;

  const _GoalsTab({required this.workId});

  @override
  Widget build(BuildContext context) {
    return WritingGoalsWidget(workId: workId);
  }
}

/// 瀵煎嚭鏍煎紡
enum ExportFormat {
  json,
  csv,
  ;

  String get label => switch (this) {
    json => 'JSON',
    csv => 'CSV',
  };
}
