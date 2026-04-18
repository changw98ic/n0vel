import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../features/timeline/domain/timeline_models.dart';
import 'event_timeline_parts.dart';

/// 浜嬩欢鏃堕棿绾跨粍浠?
class EventTimelineWidget extends StatelessWidget {
  final List<StoryEvent> events;

  const EventTimelineWidget({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final chapterEvents = _groupEventsByChapter(events);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EventTimelineLegend(),
          SizedBox(height: 24.h),
          ...chapterEvents.entries.map((entry) {
            return EventTimelineChapterTimeline(
              chapterId: entry.key,
              events: entry.value,
            );
          }),
        ],
      ),
    );
  }
}

Map<String?, List<StoryEvent>> _groupEventsByChapter(List<StoryEvent> events) {
  final chapterEvents = <String?, List<StoryEvent>>{};
  for (final event in events) {
    chapterEvents.putIfAbsent(event.chapterId, () => []).add(event);
  }
  return chapterEvents;
}
