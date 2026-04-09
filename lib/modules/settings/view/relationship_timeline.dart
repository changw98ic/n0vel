import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../features/settings/domain/relationship.dart';
import '../../../features/settings/domain/character.dart';
import '../../../core/models/value_objects/emotion_dimensions.dart';
import '../../../features/settings/data/relationship_repository.dart';
import '../../../features/settings/data/character_repository.dart';

// Shared constants and utilities

const _relationColors = <RelationType, Color>{
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

const _relationIcons = <RelationType, IconData>{
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

String _formatDate(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class RelationshipTimelineView extends StatefulWidget {
  final String characterId;
  final String workId;

  const RelationshipTimelineView({super.key, required this.characterId, required this.workId});

  @override
  State<RelationshipTimelineView> createState() => _RelationshipTimelineViewState();
}

class _RelationshipTimelineViewState extends State<RelationshipTimelineView> {
  List<RelationshipHead> _relationships = [];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRelationships();
  }

  Future<void> _loadRelationships() async {
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final repo = Get.find<RelationshipRepository>();
      final relationships = await repo.getRelationshipsByCharacterId(widget.characterId);
      if (mounted) setState(() { _relationships = relationships; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _loadError = e; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) return Center(child: Text('加载失败: $_loadError'));

    if (_relationships.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48.sp),
            SizedBox(height: 16.h),
            const Text('还没有建立关系'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _relationships.length,
      itemBuilder: (context, index) => _RelationshipCard(
        relationship: _relationships[index],
        workId: widget.workId,
        currentCharacterId: widget.characterId,
        onTap: () => _showDetails(context, _relationships[index]),
        onRefresh: _loadRelationships,
      ),
    );
  }

  void _showDetails(BuildContext context, RelationshipHead relationship) {
    showDialog(
      context: context,
      builder: (context) => RelationshipDetailsDialog(
        relationship: relationship,
        workId: widget.workId,
        currentCharacterId: widget.characterId,
      ),
    );
  }
}

class _RelationshipCard extends StatefulWidget {
  final RelationshipHead relationship;
  final String workId;
  final String currentCharacterId;
  final VoidCallback? onTap;
  final VoidCallback onRefresh;

  const _RelationshipCard({
    required this.relationship,
    required this.workId,
    required this.currentCharacterId,
    this.onTap,
    required this.onRefresh,
  });

  @override
  State<_RelationshipCard> createState() => _RelationshipCardState();
}

class _RelationshipCardState extends State<_RelationshipCard> {
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
    if (mounted) setState(() { _otherCharacter = character; _isLoadingCharacter = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relColor = _relationColors[widget.relationship.relationType] ?? Colors.grey;

    return Card(
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAvatar(theme),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _isLoadingCharacter
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: 100, height: 14, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4.r))),
                              SizedBox(height: 4.h),
                              Container(width: 60, height: 12, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4.r))),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_otherCharacter?.name ?? '未知角色', style: theme.textTheme.titleMedium),
                              Text(widget.relationship.relationType.label, style: theme.textTheme.bodySmall?.copyWith(color: relColor)),
                            ],
                          ),
                  ),
                  if (widget.relationship.eventCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12.r)),
                      child: Text('${widget.relationship.eventCount}次变化', style: TextStyle(fontSize: 12.sp, color: theme.colorScheme.primary)),
                    ),
                ],
              ),
              if (widget.relationship.emotionDimensions != null) ...[
                SizedBox(height: 16.h),
                _EmotionBar(dimensions: widget.relationship.emotionDimensions!),
              ],
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14.sp, color: theme.colorScheme.outline),
                  SizedBox(width: 4.w),
                  Text('最近更新于 ${_formatDate(widget.relationship.updatedAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    if (_isLoadingCharacter) {
      return const CircleAvatar(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_otherCharacter?.avatarPath != null && _otherCharacter!.avatarPath!.isNotEmpty) {
      return CircleAvatar(backgroundImage: FileImage(File(_otherCharacter!.avatarPath!)));
    }
    return CircleAvatar(
      child: Text(_otherCharacter?.name.substring(0, 1).toUpperCase() ?? '?', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _EmotionBar extends StatelessWidget {
  final EmotionDimensions dimensions;
  const _EmotionBar({required this.dimensions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _EmotionItem(icon: Icons.favorite, label: '好感', value: dimensions.affection, color: Colors.pink),
        _EmotionItem(icon: Icons.handshake, label: '信任', value: dimensions.trust, color: Colors.blue),
        _EmotionItem(icon: Icons.military_tech, label: '尊敬', value: dimensions.respect, color: Colors.amber),
        _EmotionItem(icon: Icons.warning, label: '恐惧', value: dimensions.fear, color: Colors.red),
      ],
    );
  }
}

class _EmotionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _EmotionItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(height: 4.h),
          Text('$value', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: color)),
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
    if (events.isEmpty) return const Center(child: Text('暂无变更记录'));
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) => _TimelineItem(
        event: events[index],
        isFirst: index == 0,
        isLast: index == events.length - 1,
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final RelationshipEvent event;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({required this.event, required this.isFirst, required this.isLast});

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
                if (!isFirst) Expanded(child: Container(width: 2, color: theme.colorScheme.outline)),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: event.isKeyEvent ? theme.colorScheme.primary : theme.colorScheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: theme.colorScheme.outline)),
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
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(4.r)),
                          child: Text(event.changeType.label, style: TextStyle(fontSize: 12.sp, color: theme.colorScheme.primary)),
                        ),
                        if (event.isKeyEvent) ...[
                          SizedBox(width: 8.w),
                          Icon(Icons.star, size: 16.sp, color: Colors.amber),
                        ],
                      ],
                    ),
                    SizedBox(height: 8.h),
                    if (event.prevRelationType != null)
                      Row(children: [Text(event.prevRelationType!.label), Icon(Icons.arrow_forward, size: 16.sp), Text(event.newRelationType.label, style: const TextStyle(fontWeight: FontWeight.bold))])
                    else
                      Text('建立关系：${event.newRelationType.label}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (event.changeReason != null) ...[
                      SizedBox(height: 8.h),
                      Text('原因：${event.changeReason}', style: theme.textTheme.bodySmall),
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

class RelationshipDetailsDialog extends StatelessWidget {
  final RelationshipHead relationship;
  final String workId;
  final String currentCharacterId;

  const RelationshipDetailsDialog({super.key, required this.relationship, required this.workId, required this.currentCharacterId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relColor = _relationColors[relationship.relationType] ?? Colors.grey;
    final relIcon = _relationIcons[relationship.relationType] ?? Icons.people;

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
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(relIcon, color: theme.colorScheme.primary),
                  SizedBox(width: 12.w),
                  Expanded(child: Text('关系详情', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Relation type
                    Text('关系类型', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8.r)),
                      child: Row(children: [Icon(relIcon, color: relColor), SizedBox(width: 12.w), Text(relationship.relationType.label, style: theme.textTheme.titleMedium?.copyWith(color: relColor, fontWeight: FontWeight.bold))]),
                    ),
                    SizedBox(height: 16.h),
                    if (relationship.emotionDimensions != null) ...[
                      Text('情感维度', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8.h),
                      _EmotionBar(dimensions: relationship.emotionDimensions!),
                      SizedBox(height: 16.h),
                    ],
                    // Info rows
                    _InfoRow(label: '变更次数', value: '${relationship.eventCount} 次'),
                    SizedBox(height: 8.h),
                    _InfoRow(label: '创建时间', value: _formatDateTime(relationship.createdAt)),
                    SizedBox(height: 8.h),
                    _InfoRow(label: '最近更新', value: _formatDateTime(relationship.updatedAt)),
                    SizedBox(height: 24.h),
                    Text('历史事件', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8.h),
                    _RelationshipEventsList(headId: relationship.id),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _RelationshipEventsList extends StatefulWidget {
  final String headId;
  const _RelationshipEventsList({required this.headId});

  @override
  State<_RelationshipEventsList> createState() => _RelationshipEventsListState();
}

class _RelationshipEventsListState extends State<_RelationshipEventsList> {
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
    if (mounted) setState(() { _events = events; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: Padding(padding: EdgeInsets.all(16.w), child: const CircularProgressIndicator()));
    if (_events.isEmpty) return Padding(padding: EdgeInsets.all(16.w), child: const Center(child: Text('暂无变更记录')));
    return RelationshipEventTimeline(events: _events);
  }
}
