import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/editor/data/chapter_repository.dart';
import '../../../features/review/data/review_service.dart';
import '../../../features/review/domain/review_report.dart';
import '../../../features/work/data/volume_repository.dart';
import '../../../shared/data/base_business/base_controller.dart';
import 'review_center_state.dart';

/// ReviewCenter 业务逻辑
class ReviewCenterLogic extends BaseController with GetTickerProviderStateMixin {
  final ReviewCenterState state = ReviewCenterState();
  late final TabController tabController;
  late final String workId;
  late final ReviewService _reviewService;
  late final VolumeRepository _volumeRepository;
  late final ChapterRepository _chapterRepository;

  ReviewCenterLogic();

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id']!;
    _reviewService = Get.find<ReviewService>();
    _volumeRepository = Get.find<VolumeRepository>();
    _chapterRepository = Get.find<ChapterRepository>();
    tabController = TabController(length: 3, vsync: this);
    state.tabController.value = tabController;
    loadData();
  }

  Future<void> loadData() async {
    await runWithLoading(() async {
      final results = await _reviewService.getReviewResults(workId);
      final statistics = await _reviewService.getReviewStatistics(workId);
      final volumes = await _volumeRepository.getVolumesByWorkId(workId);
      final chapters = await _chapterRepository.getChaptersByWorkId(workId);

      final reports = <String, ReviewReport>{};
      for (final result in results) {
        final report = await _reviewService.getReviewReport(result.chapterId);
        if (report != null) {
          reports[result.chapterId] = report;
        }
      }

      state.reviewResults.assignAll(results);
      state.statistics.value = statistics;
      state.reviewReports.assignAll(reports);
      state.volumes.assignAll(volumes);
      state.chapters.assignAll(chapters);
    });
  }

  List<ReviewIssue> get aggregatedIssues {
    return state.reviewReports.values
        .expand((report) => report.issues)
        .toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));
  }

  Future<void> ignoreIssue(String issueId) async {
    await runWithLoading(() async {
      await _reviewService.updateIssueStatus(issueId, IssueStatus.ignored);
      await loadData();
    });
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }
}
