import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/editor/domain/chapter.dart';
import '../../../features/review/data/review_repository.dart';
import '../../../features/review/domain/review_report.dart';
import '../../../features/review/domain/review_result.dart';
import '../../../features/work/domain/volume.dart';

/// ReviewCenter 页面响应式状态
class ReviewCenterState {
  final tabController = Rx<TabController?>(null);
  final reviewResults = <ReviewResult>[].obs;
  final reviewReports = <String, ReviewReport>{}.obs;
  final statistics = Rxn<ReviewStatistics>();
  final volumes = <Volume>[].obs;
  final chapters = <Chapter>[].obs;
}
