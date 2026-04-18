import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/timeline/data/timeline_repository.dart';
import '../../../features/timeline/domain/timeline_models.dart';

part 'event_timeline_dialogs.dart';
part 'event_timeline_form_fields.dart';

const eventTimelineTypeMeta = <EventType, (IconData, Color)>{
  EventType.main: (Icons.star, Colors.amber),
  EventType.sub: (Icons.circle, Colors.green),
  EventType.daily: (Icons.radio_button_unchecked, Colors.grey),
  EventType.battle: (Icons.flash_on, Colors.red),
  EventType.romance: (Icons.favorite, Colors.pink),
  EventType.mystery: (Icons.help_outline, Colors.purple),
  EventType.turning: (Icons.change_history, Colors.orange),
};

(IconData, Color) eventTimelineMeta(EventType type) =>
    eventTimelineTypeMeta[type] ?? (Icons.circle, Colors.grey);

class EventTimelineLegend extends StatelessWidget {
  const EventTimelineLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Wrap(
          spacing: 16.w,
          runSpacing: 8.h,
          children: EventType.values.map((type) {
            final (icon, color) = eventTimelineMeta(type);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16.sp, color: color),
                SizedBox(width: 4.w),
                Text(type.label),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class EventTimelineChapterTimeline extends StatelessWidget {
  final String? chapterId;
  final List<StoryEvent> events;

  const EventTimelineChapterTimeline({
    super.key,
    required this.chapterId,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                chapterId != null
                    ? S.of(context)!.timeline_chapterNumber(chapterId!)
                    : S.of(context)!.timeline_unassignedChapter,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Container(
                height: 2,
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        ...events.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          return EventTimelineNode(
            event: event,
            isLast: index == events.length - 1,
          );
        }),
        SizedBox(height: 32.h),
      ],
    );
  }
}

class EventTimelineNode extends StatelessWidget {
  final StoryEvent event;
  final bool isLast;

  const EventTimelineNode({
    super.key,
    required this.event,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = eventTimelineMeta(event.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventTimelineNodeMarker(
            icon: icon,
            color: color,
            isLast: isLast,
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: GestureDetector(
                onTap: () => EventDetailDialog.show(context, event),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EventTimelineNodeHeader(event: event),
                        SizedBox(height: 8.h),
                        if (event.storyTime != null)
                          EventTimelineTimeRow(storyTime: event.storyTime!),
                        SizedBox(height: 8.h),
                        if (event.description != null)
                          Text(
                            event.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        SizedBox(height: 12.h),
                        Wrap(
                          spacing: 8,
                          children: [
                            EventTimelineTag(
                              label: event.type.label,
                              color: color,
                            ),
                            if (event.importance != EventImportance.normal)
                              EventTimelineTag(
                                label: event.importance.label,
                                color: Colors.orange,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EventTimelineNodeMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isLast;

  const EventTimelineNodeMarker({
    super.key,
    required this.icon,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, size: 16.sp, color: color),
        ),
        if (!isLast)
          Expanded(
            child: Container(
              width: 2,
              color: theme.colorScheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

class EventTimelineNodeHeader extends StatelessWidget {
  final StoryEvent event;

  const EventTimelineNodeHeader({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            event.name,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (event.isKey)
          Icon(Icons.star, color: Colors.amber, size: 20.sp),
      ],
    );
  }
}

class EventTimelineTimeRow extends StatelessWidget {
  final String storyTime;

  const EventTimelineTimeRow({super.key, required this.storyTime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 14.sp,
          color: theme.colorScheme.outline,
        ),
        SizedBox(width: 4.w),
        Text(
          storyTime,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class EventTimelineTag extends StatelessWidget {
  final String label;
  final Color color;

  const EventTimelineTag({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(label, style: TextStyle(fontSize: 12.sp, color: color)),
    );
  }
}
