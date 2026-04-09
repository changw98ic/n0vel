import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/timeline/data/timeline_repository.dart';
import '../../../features/timeline/domain/timeline_models.dart';
import '../../../shared/data/base_business/base_controller.dart';
import 'timeline_state.dart';

/// Timeline 业务逻辑
class TimelineLogic extends BaseController with GetTickerProviderStateMixin {
  final TimelineState state = TimelineState();
  late TabController tabController;

  final TimelineRepository _timelineRepository = Get.find<TimelineRepository>();

  late final String workId;

  TimelineLogic();

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id'] ?? '';
    tabController = TabController(length: 2, vsync: this);
    loadData();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  Future<void> loadData() async {
    await Future.wait([loadEvents(), loadConflicts()]);
  }

  Future<void> loadEvents() async {
    state.eventsLoading.value = true;
    try {
      final events = await _timelineRepository.getEvents(workId);
      state.events.assignAll(events);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      state.eventsLoading.value = false;
    }
  }

  Future<void> loadConflicts() async {
    state.conflictsLoading.value = true;
    try {
      final conflicts = await _timelineRepository.detectConflicts(workId);
      state.conflicts.assignAll(conflicts);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      state.conflictsLoading.value = false;
    }
  }

  List<StoryEvent> applyFilters(List<StoryEvent> events) {
    var filtered = events;
    if (state.filterType.value != null) {
      filtered = filtered.where((e) => e.type == state.filterType.value).toList();
    }
    if (state.filterImportance.value != null) {
      filtered = filtered
          .where((e) => e.importance == state.filterImportance.value)
          .toList();
    }
    return filtered;
  }

  void setViewMode(String mode) {
    state.viewMode.value = mode;
  }

  void setFilterType(EventType? type) {
    state.filterType.value = type;
  }

  void setFilterImportance(EventImportance? importance) {
    state.filterImportance.value = importance;
  }
}
