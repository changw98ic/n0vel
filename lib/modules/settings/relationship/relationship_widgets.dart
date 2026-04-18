import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/models/value_objects/emotion_dimensions.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../features/settings/data/relationship_repository.dart';
import '../../../features/settings/domain/relationship.dart' as domain;
import '../../../l10n/app_localizations.dart';
import '../view/relationship_dialogs.dart';
import 'relationship_logic.dart';

const relationshipRelationColors = <domain.RelationType, Color>{
  domain.RelationType.enemy: Colors.red,
  domain.RelationType.hostile: Colors.deepOrange,
  domain.RelationType.neutral: Colors.grey,
  domain.RelationType.acquaintance: Colors.blueGrey,
  domain.RelationType.friendly: Colors.lightBlue,
  domain.RelationType.friend: Colors.blue,
  domain.RelationType.closeFriend: Colors.indigo,
  domain.RelationType.lover: Colors.pink,
  domain.RelationType.family: Colors.purple,
  domain.RelationType.mentor: Colors.teal,
  domain.RelationType.rival: Colors.orange,
};

const relationshipRelationIcons = <domain.RelationType, IconData>{
  domain.RelationType.enemy: Icons.gavel,
  domain.RelationType.hostile: Icons.warning,
  domain.RelationType.neutral: Icons.balance,
  domain.RelationType.acquaintance: Icons.person_outline,
  domain.RelationType.friendly: Icons.thumb_up,
  domain.RelationType.friend: Icons.people,
  domain.RelationType.closeFriend: Icons.favorite,
  domain.RelationType.lover: Icons.favorite_border,
  domain.RelationType.family: Icons.family_restroom,
  domain.RelationType.mentor: Icons.school,
  domain.RelationType.rival: Icons.compare_arrows,
};

class RelationshipFilterBar extends StatelessWidget {
  final RelationshipLogic controller;

  const RelationshipFilterBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(
          () => Row(
            children: [
              FilterChip(
                label: Text(S.of(context)!.settings_all),
                selected: controller.state.selectedType.value == null,
                onSelected: (_) => controller.setFilter(null),
              ),
              SizedBox(width: 8.w),
              ...domain.RelationType.values.map(
                (type) => Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: FilterChip(
                    label: Text(type.label),
                    selected: controller.state.selectedType.value == type.name,
                    onSelected: (_) => controller.setFilter(
                      controller.state.selectedType.value == type.name
                          ? null
                          : type.name,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RelationshipList extends StatelessWidget {
  final RelationshipLogic controller;

  const RelationshipList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final filtered = controller.filteredRelationships;

    if (filtered.isEmpty) {
      return RelationshipEmptyState(controller: controller);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: filtered.length,
      itemBuilder: (context, index) => RelationshipCard(
        relationship: filtered[index],
        workId: controller.workId,
        onDelete: () => controller.deleteRelationship(filtered[index]),
        onEdit: () => showDialog(
          context: context,
          builder: (ctx) => EditRelationshipDialog(
            relationship: filtered[index],
            onUpdated: controller.loadRelationships,
          ),
        ),
        onRefresh: controller.loadRelationships,
      ),
    );
  }
}

class RelationshipEmptyState extends StatelessWidget {
  final RelationshipLogic controller;

  const RelationshipEmptyState({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64.sp, color: outlineColor),
          SizedBox(height: 16.h),
          Text(
            s.settings_noRelationshipsCreated,
            style: TextStyle(color: outlineColor),
          ),
          SizedBox(height: 16.h),
          FilledButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => CreateRelationshipDialog(
                workId: controller.workId,
                onCreated: controller.loadRelationships,
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(s.settings_newRelationship),
          ),
        ],
      ),
    );
  }
}

class RelationshipCard extends StatefulWidget {
  final domain.RelationshipHead relationship;
  final String workId;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  const RelationshipCard({
    super.key,
    required this.relationship,
    required this.workId,
    required this.onDelete,
    required this.onEdit,
    required this.onRefresh,
  });

  @override
  State<RelationshipCard> createState() => _RelationshipCardState();
}

class _RelationshipCardState extends State<RelationshipCard> {
  _CharacterPair? _characterPair;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    final s = S.of(context)!;
    final repo = Get.find<CharacterRepository>();
    final results = await Future.wait([
      repo.getCharacterById(widget.relationship.characterAId),
      repo.getCharacterById(widget.relationship.characterBId),
    ]);
    if (mounted) {
      setState(() {
        _characterPair = _CharacterPair(
          nameA: results[0]?.name ?? s.settings_unknownCharacter,
          nameB: results[1]?.name ?? s.settings_unknownCharacter,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final type = widget.relationship.relationType;
    final color = relationshipRelationColors[type] ?? Colors.grey;

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ExpansionTile(
        leading: RelationshipTypeIcon(type: type, color: color),
        title: Text(
          _characterPair != null
              ? '${_characterPair!.nameA} 鈫?${_characterPair!.nameB}'
              : '...',
        ),
        subtitle: Text(
          '${type.label} 路 ${s.settings_eventCountChanges(widget.relationship.eventCount)}',
        ),
        trailing: RelationshipCardMenu(
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.relationship.emotionDimensions != null) ...[
                  Text(
                    s.settings_emotionalDimensions,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SizedBox(height: 8.h),
                  RelationshipEmotionBar(
                    dimensions: widget.relationship.emotionDimensions!,
                  ),
                  SizedBox(height: 16.h),
                ],
                Text(
                  s.settings_firstAppeared(
                    formatRelationshipDate(widget.relationship.createdAt),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  s.settings_recentlyUpdated(
                    formatRelationshipDate(widget.relationship.updatedAt),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: 8.h),
                OutlinedButton.icon(
                  onPressed: () => _showEvents(context),
                  icon: Icon(Icons.history, size: 18.sp),
                  label: Text(s.settings_viewChangeHistory),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEvents(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => RelationshipEventsSheet(
          headId: widget.relationship.id,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class RelationshipTypeIcon extends StatelessWidget {
  final domain.RelationType type;
  final Color color;

  const RelationshipTypeIcon({
    super.key,
    required this.type,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(relationshipRelationIcons[type] ?? Icons.link, color: color),
    );
  }
}

class RelationshipCardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RelationshipCardMenu({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return PopupMenuButton<String>(
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20.sp),
              SizedBox(width: 8.w),
              Text(s.settings_edit),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20.sp, color: Colors.red),
              SizedBox(width: 8.w),
              Text(
                s.settings_delete,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CharacterPair {
  final String nameA;
  final String nameB;

  const _CharacterPair({required this.nameA, required this.nameB});
}

class RelationshipEmotionBar extends StatelessWidget {
  final EmotionDimensions dimensions;

  const RelationshipEmotionBar({super.key, required this.dimensions});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Column(
      children: [
        RelationshipEmotionRow(
          label: s.settings_affection,
          value: dimensions.affection / 100.0,
          color: Colors.pink,
        ),
        SizedBox(height: 4.h),
        RelationshipEmotionRow(
          label: s.settings_trust,
          value: dimensions.trust / 100.0,
          color: Colors.blue,
        ),
        SizedBox(height: 4.h),
        RelationshipEmotionRow(
          label: s.settings_respect,
          value: dimensions.respect / 100.0,
          color: Colors.amber,
        ),
        SizedBox(height: 4.h),
        RelationshipEmotionRow(
          label: s.settings_fear,
          value: dimensions.fear / 100.0,
          color: Colors.red,
        ),
      ],
    );
  }
}

class RelationshipEmotionRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const RelationshipEmotionRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6.h,
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 36,
          child: Text(
            '${(value * 100).toInt()}%',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class RelationshipEventsSheet extends StatefulWidget {
  final String headId;
  final ScrollController scrollController;

  const RelationshipEventsSheet({
    super.key,
    required this.headId,
    required this.scrollController,
  });

  @override
  State<RelationshipEventsSheet> createState() =>
      _RelationshipEventsSheetState();
}

class _RelationshipEventsSheetState extends State<RelationshipEventsSheet> {
  List<domain.RelationshipEvent> _events = [];
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
    final s = S.of(context)!;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            s.settings_changeHistory,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _events.isEmpty
                  ? Center(child: Text(s.settings_noChangeRecords))
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: _events.length,
                      itemBuilder: (context, index) =>
                          RelationshipEventTile(event: _events[index]),
                    ),
        ),
      ],
    );
  }
}

class RelationshipEventTile extends StatelessWidget {
  final domain.RelationshipEvent event;

  const RelationshipEventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final (icon, color) = switch (event.changeType) {
      domain.ChangeType.create => (Icons.add_circle, Colors.green),
      domain.ChangeType.update => (Icons.edit, Colors.blue),
      domain.ChangeType.majorShift => (Icons.trending_up, Colors.orange),
    };

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('${event.changeType.label}: ${event.newRelationType.label}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.prevRelationType != null)
              Text(s.settings_fromChange(event.prevRelationType!.label)),
            if (event.changeReason != null)
              Text(s.settings_reason(event.changeReason!)),
            Text(formatRelationshipDateTime(event.createdAt)),
          ],
        ),
        trailing: event.isKeyEvent
            ? Icon(Icons.star, color: Colors.amber, size: 20.sp)
            : null,
      ),
    );
  }
}

String formatRelationshipDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String formatRelationshipDateTime(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
