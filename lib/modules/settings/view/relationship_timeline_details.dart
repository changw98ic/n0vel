import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../features/settings/data/relationship_repository.dart';
import '../../../features/settings/domain/relationship.dart';
import 'relationship_timeline_sections.dart';

class RelationshipDetailsDialog extends StatelessWidget {
  final RelationshipHead relationship;
  final String workId;
  final String currentCharacterId;

  const RelationshipDetailsDialog({
    super.key,
    required this.relationship,
    required this.workId,
    required this.currentCharacterId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relColor = relationshipTimelineRelationColors[
            relationship.relationType] ??
        Colors.grey;
    final relIcon = relationshipTimelineRelationIcons[
            relationship.relationType] ??
        Icons.people;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(relIcon, color: theme.colorScheme.primary),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      '鍏崇郴璇︽儏',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '鍏崇郴绫诲瀷',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(relIcon, color: relColor),
                          SizedBox(width: 12.w),
                          Text(
                            relationship.relationType.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: relColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (relationship.emotionDimensions != null) ...[
                      Text(
                        '鎯呮劅缁村害',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      RelationshipTimelineEmotionBar(
                        dimensions: relationship.emotionDimensions!,
                      ),
                      SizedBox(height: 16.h),
                    ],
                    RelationshipTimelineInfoRow(
                      label: '鍙樻洿娆℃暟',
                      value: '${relationship.eventCount} 娆?',
                    ),
                    SizedBox(height: 8.h),
                    RelationshipTimelineInfoRow(
                      label: '鍒涘缓鏃堕棿',
                      value: formatRelationshipTimelineDateTime(
                        relationship.createdAt,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    RelationshipTimelineInfoRow(
                      label: '鏈€杩戞洿鏂?',
                      value: formatRelationshipTimelineDateTime(
                        relationship.updatedAt,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      '鍘嗗彶浜嬩欢',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    RelationshipTimelineEventsList(headId: relationship.id),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RelationshipTimelineEventsList extends StatefulWidget {
  final String headId;

  const RelationshipTimelineEventsList({
    super.key,
    required this.headId,
  });

  @override
  State<RelationshipTimelineEventsList> createState() =>
      _RelationshipTimelineEventsListState();
}

class _RelationshipTimelineEventsListState
    extends State<RelationshipTimelineEventsList> {
  List<RelationshipEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final repo = Get.find<RelationshipRepository>();
    final events = await repo.getEventsByHeadId(widget.headId);
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (_events.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16.w),
        child: const Center(child: Text('鏆傛棤鍙樻洿璁板綍')),
      );
    }
    return RelationshipEventTimeline(events: _events);
  }
}
