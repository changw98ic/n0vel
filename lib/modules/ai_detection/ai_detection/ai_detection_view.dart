import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';
import '../../../../../shared/data/base_business/base_page.dart';
import 'ai_detection_logic.dart';
import '../../../../../features/ai_detection/domain/detection_result.dart';

class AIDetectionView extends GetView<AIDetectionLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return _AIDetectionPageContent(s: s);
  }
}

class _AIDetectionPageContent extends StatefulWidget {
  final S s;

  const _AIDetectionPageContent({required this.s});

  @override
  State<_AIDetectionPageContent> createState() => _AIDetectionPageContentState();
}

class _AIDetectionPageContentState extends State<_AIDetectionPageContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final AIDetectionLogic controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<AIDetectionLogic>();
    _tabController = TabController(length: 5, vsync: this);
    controller.tabController = _tabController;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.s.aiDetection_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.analyze,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => controller.openSettings(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Obx(() {
            final report = controller.state.report.value;
            if (report == null) return const SizedBox.shrink();

            return TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(text: '${widget.s.aiDetection_overview} (${report.totalIssues})'),
                Tab(
                  text:
                      '${widget.s.aiDetection_forbiddenPatterns} (${report.typeCounts[DetectionType.forbiddenPattern.name] ?? 0})',
                ),
                Tab(
                  text:
                      '${widget.s.aiDetection_punctuationAbuse} (${report.typeCounts[DetectionType.punctuationAbuse.name] ?? 0})',
                ),
                Tab(
                  text:
                      '${widget.s.aiDetection_aiVocabulary} (${report.typeCounts[DetectionType.aiVocabulary.name] ?? 0})',
                ),
                Tab(
                  text:
                      '${widget.s.aiDetection_other} (${controller.otherIssueCount(report)})',
                ),
              ],
            );
          }),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (controller.state.isAnalyzing.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final report = controller.state.report.value;
      if (report == null) {
        return Center(child: Text(widget.s.aiDetection_analyzing));
      }

      return TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(report: report),
          _ResultListTab(
            results: report.getResultsByType(DetectionType.forbiddenPattern),
          ),
          _ResultListTab(
            results: report.getResultsByType(DetectionType.punctuationAbuse),
          ),
          _ResultListTab(
            results: report.getResultsByType(DetectionType.aiVocabulary),
          ),
          _ResultListTab(results: controller.buildOtherResults(report)),
        ],
      );
    });
  }
}

class _OverviewTab extends StatelessWidget {
  final DetectionReport report;

  const _OverviewTab({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context)!;
    final severityColor = report.totalIssues == 0
        ? Colors.green
        : report.totalIssues < 10
            ? Colors.orange
            : Colors.red;

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                Icon(Icons.analytics, size: 48.sp, color: severityColor),
                SizedBox(height: 16.h),
                Text(
                  report.totalIssues == 0
                      ? s.aiDetection_noIssues
                      : s.aiDetection_foundIssues(report.totalIssues.toString()),
                  style: theme.textTheme.titleLarge,
                ),
                SizedBox(height: 8.h),
                Text(
                  s.aiDetection_issueDensity(report.issueDensity.toStringAsFixed(1)),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Text(s.aiDetection_issueDistribution, style: theme.textTheme.titleMedium),
        SizedBox(height: 8.h),
        ...DetectionType.values.map((type) {
          final count = report.typeCounts[type.name] ?? 0;
          if (count == 0) {
            return const SizedBox.shrink();
          }

          return Card(
            child: ListTile(
              title: Text(type.label),
              trailing: Text('$count'),
            ),
          );
        }),
      ],
    );
  }
}

class _ResultListTab extends StatelessWidget {
  final List<DetectionResult> results;

  const _ResultListTab({required this.results});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 48.sp, color: Colors.green),
            SizedBox(height: 16.h),
            Text(s.aiDetection_noProblemsFound),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: results.length,
      itemBuilder: (context, index) => _ResultCard(result: results[index]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final DetectionResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context)!;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.type.label,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (result.pattern != null)
                  Text(
                    result.pattern!,
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
            SizedBox(height: 8.h),
            SelectableText(
              result.matchedText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (result.description != null) ...[
              SizedBox(height: 8.h),
              Text(result.description!),
            ],
            if (result.suggestion != null) ...[
              SizedBox(height: 8.h),
              Text(
                s.aiDetection_suggestion(result.suggestion!),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
