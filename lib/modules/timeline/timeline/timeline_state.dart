import 'package:get/get.dart';

import '../../../features/timeline/domain/timeline_models.dart';

/// Timeline 页面响应式状态
class TimelineState {
  final viewMode = 'timeline'.obs;
  final filterType = Rx<EventType?>(null);
  final filterImportance = Rx<EventImportance?>(null);

  final events = <StoryEvent>[].obs;
  final eventsLoading = true.obs;

  final conflicts = <TimeConflict>[].obs;
  final conflictsLoading = true.obs;
}
