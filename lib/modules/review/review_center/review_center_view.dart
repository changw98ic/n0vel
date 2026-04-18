import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../shared/data/base_business/base_page.dart';
import '../view/quick_review_dialog.dart';
import '../view/review_config_dialog.dart';
import '../view/review_progress_dialog.dart';
import 'review_center_logic.dart';
import 'review_center_widgets.dart';

class ReviewCenterView extends GetView<ReviewCenterLogic> with BasePage {
  const ReviewCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return AppPageScaffold(
      title: s.review_center_title,
      bodyPadding: EdgeInsets.zero,
      bottom: Obx(
        () => TabBar(
          controller: controller.state.tabController.value,
          tabs: [
            Tab(text: s.review_tab_overview),
            Tab(text: s.review_tab_issues),
            Tab(text: s.review_tab_statistics),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: controller.loadData,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => showDialog(
            context: context,
            builder: (context) => const ReviewConfigDialog(),
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'review_fab',
        onPressed: () => controller.startQuickReview(context),
        icon: const Icon(Icons.play_arrow),
        label: Text(s.review_quickReview),
      ),
      child: Obx(() {
        final tabController = controller.state.tabController.value;
        if (tabController == null) {
          return const SizedBox.shrink();
        }

        if (controller.isLoading.value &&
            controller.state.reviewResults.isEmpty &&
            controller.state.statistics.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return TabBarView(
          controller: tabController,
          children: [
            ReviewCenterOverviewTab(controller: controller),
            ReviewCenterIssueListTab(controller: controller),
            ReviewCenterStatisticsTab(controller: controller),
          ],
        );
      }),
    );
  }
}

extension ReviewCenterLogicMethods on ReviewCenterLogic {
  Future<void> startQuickReview(BuildContext context) async {
    final result = await showDialog<QuickReviewRequest>(
      context: context,
      builder: (context) => QuickReviewDialog(
        workId: workId,
        volumes: state.volumes,
        chapters: state.chapters,
      ),
    );

    if (result != null && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ReviewProgressDialog(
          workId: workId,
          scope: result.scope,
          dimensions: result.dimensions,
          volumeId: result.volumeId,
          chapterId: result.chapterId,
        ),
      );
      await loadData();
    }
  }
}
