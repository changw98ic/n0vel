import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/models/value_objects/emotion_dimensions.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../features/settings/domain/character.dart';
import '../../../features/settings/domain/relationship.dart';
import 'relationship_timeline_details.dart';

const relationshipTimelineRelationColors = <RelationType, Color>{
  RelationType.enemy: Colors.red,
  RelationType.hostile: Colors.red,
  RelationType.neutral: Colors.grey,
  RelationType.acquaintance: Colors.blue,
  RelationType.friendly: Colors.lightBlue,
  RelationType.friend: Colors.green,
  RelationType.closeFriend: Colors.teal,
  RelationType.lover: Colors.pink,
  RelationType.family: Colors.amber,
  RelationType.mentor: Colors.purple,
  RelationType.rival: Colors.orange,
};

const relationshipTimelineRelationIcons = <RelationType, IconData>{
  RelationType.enemy: Icons.warning,
  RelationType.hostile: Icons.warning,
  RelationType.neutral: Icons.remove_circle_outline,
  RelationType.acquaintance: Icons.waving_hand,
  RelationType.friendly: Icons.sentiment_satisfied,
  RelationType.friend: Icons.sentiment_very_satisfied,
  RelationType.closeFriend: Icons.favorite,
  RelationType.lover: Icons.favorite_border,
  RelationType.family: Icons.family_restroom,
  RelationType.mentor: Icons.school,
  RelationType.rival: Icons.emoji_events,
};

String formatRelationshipTimelineDate(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

String formatRelationshipTimelineDateTime(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class RelationshipTimelineEmptyState extends StatelessWidget {
  const RelationshipTimelineEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48.sp),
          SizedBox(height: 16.h),
          const Text('杩樻病鏈夊缓绔嬪叧绯?'),
        ],
      ),
    );
  }
}

class RelationshipTimelineCard extends StatefulWidget {
  final RelationshipHead relationship;
  final String workId;
  final String currentCharacterId;
  final VoidCallback? onRefresh;

  const RelationshipTimelineCard({
    super.key,
    required this.relationship,
    required this.workId,
    required this.currentCharacterId,
    this.onRefresh,
  });

  @override
  State<RelationshipTimelineCard> createState() =>
      _RelationshipTimelineCardState();
}

class _RelationshipTimelineCardState extends State<RelationshipTimelineCard> {
  Character? _otherCharacter;
  bool _isLoadingCharacter = true;

  @override
  void initState() {
    super.initState();
    _loadOtherCharacter();
  }

  Future<void> _loadOtherCharacter() async {
    final otherId = widget.relationship.characterAId == widget.currentCharacterId
        ? widget.relationship.characterBId
        : widget.relationship.characterAId;
    final repo = Get.find<CharacterRepository>();
    final character = await repo.getCharacterById(otherId);
    if (mounted) {
      setState(() {
        _otherCharacter = character;
        _isLoadingCharacter = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relColor = relationshipTimelineRelationColors[
            widget.relationship.relationType] ??
        Colors.grey;

    return Card(
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (context) => RelationshipDetailsDialog(
            relationship: widget.relationship,
            workId: widget.workId,
            currentCharacterId: widget.currentCharacterId,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RelationshipAvatar(
                    isLoadingCharacter: _isLoadingCharacter,
                    otherCharacter: _otherCharacter,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _isLoadingCharacter
                        ? RelationshipTimelineCharacterSkeleton(theme: theme)
                        : RelationshipTimelineCharacterInfo(
                            name: _otherCharacter?.name ?? '鏈煡瑙掕壊',
                            relationLabel: widget.relationship.relationType.label,
                            relationColor: relColor,
                          ),
                  ),
                  if (widget.relationship.eventCount > 0)
                    RelationshipTimelineEventCountBadge(
                      count: widget.relationship.eventCount,
                    ),
                ],
              ),
              if (widget.relationship.emotionDimensions != null) ...[
                SizedBox(height: 16.h),
                RelationshipTimelineEmotionBar(
                  dimensions: widget.relationship.emotionDimensions!,
                ),
              ],
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14.sp,
                    color: theme.colorScheme.outline,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '鏈€杩戞洿鏂颁簬 ${formatRelationshipTimelineDate(widget.relationship.updatedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationshipAvatar extends StatelessWidget {
  final bool isLoadingCharacter;
  final Character? otherCharacter;

  const _RelationshipAvatar({
    required this.isLoadingCharacter,
    required this.otherCharacter,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingCharacter) {
      return const CircleAvatar(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (otherCharacter?.avatarPath != null &&
        otherCharacter!.avatarPath!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: FileImage(File(otherCharacter!.avatarPath!)),
      );
    }
    return CircleAvatar(
      child: Text(
        otherCharacter?.name.substring(0, 1).toUpperCase() ?? '?',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class RelationshipTimelineCharacterSkeleton extends StatelessWidget {
  final ThemeData theme;

  const RelationshipTimelineCharacterSkeleton({
    super.key,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100,
          height: 14,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          width: 60,
          height: 12,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ],
    );
  }
}

class RelationshipTimelineCharacterInfo extends StatelessWidget {
  final String name;
  final String relationLabel;
  final Color relationColor;

  const RelationshipTimelineCharacterInfo({
    super.key,
    required this.name,
    required this.relationLabel,
    required this.relationColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.titleMedium),
        Text(
          relationLabel,
          style: theme.textTheme.bodySmall?.copyWith(color: relationColor),
        ),
      ],
    );
  }
}

class RelationshipTimelineEventCountBadge extends StatelessWidget {
  final int count;

  const RelationshipTimelineEventCountBadge({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        '$count娆″彉鍖?',
        style: TextStyle(fontSize: 12.sp, color: theme.colorScheme.primary),
      ),
    );
  }
}

class RelationshipTimelineEmotionBar extends StatelessWidget {
  final EmotionDimensions dimensions;

  const RelationshipTimelineEmotionBar({
    super.key,
    required this.dimensions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RelationshipTimelineEmotionItem(
          icon: Icons.favorite,
          label: '濂芥劅',
          value: dimensions.affection,
          color: Colors.pink,
        ),
        RelationshipTimelineEmotionItem(
          icon: Icons.handshake,
          label: '淇′换',
          value: dimensions.trust,
          color: Colors.blue,
        ),
        RelationshipTimelineEmotionItem(
          icon: Icons.military_tech,
          label: '灏婃暚',
          value: dimensions.respect,
          color: Colors.amber,
        ),
        RelationshipTimelineEmotionItem(
          icon: Icons.warning,
          label: '鎭愭儳',
          value: dimensions.fear,
          color: Colors.red,
        ),
      ],
    );
  }
}

class RelationshipTimelineEmotionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const RelationshipTimelineEmotionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(height: 4.h),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class RelationshipEventTimeline extends StatelessWidget {
  final List<RelationshipEvent> events;

  const RelationshipEventTimeline({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(child: Text('鏆傛棤鍙樻洿璁板綍'));
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) => RelationshipTimelineItem(
        event: events[index],
        isFirst: index == 0,
        isLast: index == events.length - 1,
      ),
    );
  }
}

class RelationshipTimelineItem extends StatelessWidget {
  final RelationshipEvent event;
  final bool isFirst;
  final bool isLast;

  const RelationshipTimelineItem({
    super.key,
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(width: 2, color: theme.colorScheme.outline),
                  ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: event.isKeyEvent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Card(
              margin: EdgeInsets.only(bottom: 8.h),
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            event.changeType.label,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        if (event.isKeyEvent) ...[
                          SizedBox(width: 8.w),
                          Icon(Icons.star, size: 16.sp, color: Colors.amber),
                        ],
                      ],
                    ),
                    SizedBox(height: 8.h),
                    if (event.prevRelationType != null)
                      Row(
                        children: [
                          Text(event.prevRelationType!.label),
                          Icon(Icons.arrow_forward, size: 16.sp),
                          Text(
                            event.newRelationType.label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    else
                      Text(
                        '寤虹珛鍏崇郴锛?{event.newRelationType.label}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (event.changeReason != null) ...[
                      SizedBox(height: 8.h),
                      Text(
                        '鍘熷洜锛?{event.changeReason}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RelationshipTimelineInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const RelationshipTimelineInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
