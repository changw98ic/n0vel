import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../features/timeline/domain/timeline_models.dart';
import '../view/conflict_indicator.dart';
import '../view/event_timeline_widget.dart';
import '../../../shared/data/base_business/base_page.dart';
import 'timeline_logic.dart';

/// 故事时间线页面
class TimelineView extends GetView<TimelineLogic> with BasePage {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AppPageScaffold(
      title: s.timeline_title,
      bodyPadding: EdgeInsets.zero,
      bottom: TabBar(
        controller: controller.tabController,
        tabs: [
          Tab(text: s.timeline_eventsTab),
          Tab(text: s.timeline_conflictsTab),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(context),
        ),
      ],
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Obx(() {
      if (controller.state.eventsLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final filteredEvents = controller.applyFilters(controller.state.events.toList());
      return TabBarView(
        controller: controller.tabController,
        children: [
          _buildEventsTab(context, filteredEvents),
          _buildConflictsTab(),
        ],
      );
    });
  }

  Widget _buildConflictsTab() {
    return Obx(() {
      if (controller.state.conflictsLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return ConflictIndicator(conflicts: controller.state.conflicts.toList());
    });
  }

  Widget _buildEventsTab(BuildContext context, List<StoryEvent> events) {
    final s = S.of(context)!;
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64.sp),
            SizedBox(height: 16.h),
            Text(s.timeline_noEventsYet),
          ],
        ),
      );
    }

    return Obx(() => switch (controller.state.viewMode.value) {
      'list' => _EventListView(events: events),
      _ => EventTimelineWidget(events: events),
    });
  }

  void _showFilterDialog(BuildContext context) {
    final s = S.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterDialogContent(
        controller: controller,
        s: s,
      ),
    );
  }
}

class _FilterDialogContent extends StatelessWidget {
  final TimelineLogic controller;
  final S s;

  const _FilterDialogContent({
    required this.controller,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.timeline_filterEvents),
          SizedBox(height: 16.h),
          Text(s.timeline_eventType),
          Obx(() => Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(s.timeline_all),
                selected: controller.state.filterType.value == null,
                onSelected: (_) {
                  controller.setFilterType(null);
                  Get.back();
                },
              ),
              ...EventType.values.map(
                (type) => ChoiceChip(
                  label: Text(type.label),
                  selected: controller.state.filterType.value == type,
                  onSelected: (_) {
                    controller.setFilterType(type);
                    Get.back();
                  },
                ),
              ),
            ],
          )),
          SizedBox(height: 16.h),
          Text(s.timeline_importance),
          Obx(() => Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(s.timeline_all),
                selected: controller.state.filterImportance.value == null,
                onSelected: (_) {
                  controller.setFilterImportance(null);
                  Get.back();
                },
              ),
              ...EventImportance.values.map(
                (importance) => ChoiceChip(
                  label: Text(importance.label),
                  selected: controller.state.filterImportance.value == importance,
                  onSelected: (_) {
                    controller.setFilterImportance(importance);
                    Get.back();
                  },
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }
}

class _EventListView extends StatelessWidget {
  final List<StoryEvent> events;

  const _EventListView({required this.events});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: events.length,
      itemBuilder: (context, index) => _EventListTile(event: events[index]),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final StoryEvent event;

  const _EventListTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: _EventIcon(type: event.type, importance: event.importance),
        title: Text(event.name),
        subtitle: Text(event.storyTime ?? event.description ?? ''),
        trailing: event.isKey
            ? Icon(Icons.star, color: Color(0xFFD4A94C))
            : null,
        onTap: () => _EventDetailDialog.show(context, event),
      ),
    );
  }
}

class _EventIcon extends StatelessWidget {
  final EventType type;
  final EventImportance importance;

  const _EventIcon({required this.type, required this.importance});

  static const _typeIcons = <EventType, (IconData, Color)>{
    EventType.main: (Icons.star, Colors.amber),
    EventType.sub: (Icons.circle, Colors.blue),
    EventType.daily: (Icons.radio_button_unchecked, Colors.grey),
    EventType.battle: (Icons.flash_on, Colors.red),
    EventType.romance: (Icons.favorite, Colors.pink),
    EventType.mystery: (Icons.help_outline, Colors.purple),
    EventType.turning: (Icons.change_history, Colors.orange),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _typeIcons[type] ?? (Icons.circle, Colors.grey);
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(icon, size: 20.sp, color: color),
    );
  }
}

class _EventDetailDialog extends StatelessWidget {
  final StoryEvent event;

  const _EventDetailDialog({required this.event});

  static void show(BuildContext context, StoryEvent event) {
    showDialog(
      context: context,
      builder: (context) => _EventDetailDialog(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(event.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('类型：${event.type.label}'),
            Text('重要程度：${event.importance.label}'),
            if (event.storyTime != null) Text('故事时间：${event.storyTime}'),
            if (event.relativeTime != null) Text('相对时间：${event.relativeTime}'),
            if (event.description != null) Text(event.description!),
            if (event.consequences != null) Text(event.consequences!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
