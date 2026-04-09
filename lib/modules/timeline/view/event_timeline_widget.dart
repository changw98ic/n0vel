import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/timeline/domain/timeline_models.dart';
import '../../../features/timeline/data/timeline_repository.dart';

const _eventTypeMeta = <EventType, (IconData, Color)>{
  EventType.main: (Icons.star, Colors.amber),
  EventType.sub: (Icons.circle, Colors.green),
  EventType.daily: (Icons.radio_button_unchecked, Colors.grey),
  EventType.battle: (Icons.flash_on, Colors.red),
  EventType.romance: (Icons.favorite, Colors.pink),
  EventType.mystery: (Icons.help_outline, Colors.purple),
  EventType.turning: (Icons.change_history, Colors.orange),
};

(IconData, Color) _eventMeta(EventType type) => _eventTypeMeta[type] ?? (Icons.circle, Colors.grey);

/// 事件时间线组件
class EventTimelineWidget extends StatelessWidget {
  final List<StoryEvent> events;

  const EventTimelineWidget({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final chapterEvents = <String?, List<StoryEvent>>{};
    for (final event in events) {
      chapterEvents.putIfAbsent(event.chapterId, () => []).add(event);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegend(theme),
          SizedBox(height: 24.h),

          // 时间线
          ...chapterEvents.entries.map((entry) {
            return _ChapterTimeline(chapterId: entry.key, events: entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Wrap(
          spacing: 16.w,
          runSpacing: 8.h,
          children: EventType.values.map((type) {
            final (icon, color) = _eventMeta(type);
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

/// 章节时间线
class _ChapterTimeline extends StatelessWidget {
  final String? chapterId;
  final List<StoryEvent> events;

  const _ChapterTimeline({required this.chapterId, required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 章节标题
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

        // 事件节点
        ...events.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == events.length - 1;

          return _TimelineNode(event: event, isLast: isLast);
        }),

        SizedBox(height: 32.h),
      ],
    );
  }
}

/// 时间线节点
class _TimelineNode extends StatelessWidget {
  final StoryEvent event;
  final bool isLast;

  const _TimelineNode({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, color) = _eventMeta(event.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间线
          Column(
            children: [
              // 节点
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
              // 连接线
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          SizedBox(width: 16.w),
          // 内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: GestureDetector(
                onTap: () => _EventDetailDialog.show(context, event),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题行
                        Row(
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
                        ),
                        SizedBox(height: 8.h),
                        // 时间
                        if (event.storyTime != null)
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14.sp,
                                color: theme.colorScheme.outline,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                event.storyTime!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        SizedBox(height: 8.h),
                        // 描述
                        if (event.description != null)
                          Text(
                            event.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        SizedBox(height: 12.h),
                        // 底部标签
                        Wrap(
                          spacing: 8,
                          children: [
                            _Tag(label: event.type.label, color: color),
                            if (event.importance != EventImportance.normal)
                              _Tag(
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

/// 标签
class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

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

/// 事件详情对话框
class _EventDetailDialog extends StatelessWidget {
  final StoryEvent event;

  const _EventDetailDialog({required this.event});

  /// 显示事件详情对话框
  static void show(BuildContext context, StoryEvent event) {
    showDialog(
      context: context,
      builder: (context) => _EventDetailDialog(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, color) = _eventMeta(event.type);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.name, style: theme.textTheme.titleLarge),
                        if (event.isKey)
                          Text(
                            S.of(context)!.timeline_keyEvent,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.amber,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 32),

              // 基本信息
              _InfoSection(
                title: S.of(context)!.timeline_basicInfo,
                children: [
                  if (event.storyTime != null)
                    _InfoRow(
                      icon: Icons.access_time,
                      label: S.of(context)!.timeline_storyTime(''),
                      value: event.storyTime!,
                    ),
                  if (event.relativeTime != null)
                    _InfoRow(
                      icon: Icons.schedule,
                      label: S.of(context)!.timeline_relativeTime(''),
                      value: event.relativeTime!,
                    ),
                  if (event.chapterId != null)
                    _InfoRow(
                      icon: Icons.book,
                      label: S.of(context)!.timeline_belongsToChapter,
                      value: S.of(context)!.timeline_chapterNumber(event.chapterId!),
                    ),
                ],
              ),

              // 描述
              if (event.description != null) ...[
                SizedBox(height: 16.h),
                _InfoSection(
                  title: S.of(context)!.timeline_eventDescription,
                  children: [
                    Text(event.description!, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ],

              // 后果
              if (event.consequences != null) ...[
                SizedBox(height: 16.h),
                _InfoSection(
                  title: S.of(context)!.timeline_subsequentImpact,
                  children: [
                    Text(
                      event.consequences!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],

              // 标签
              SizedBox(height: 16.h),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(label: event.type.label, color: color),
                  _Tag(label: event.importance.label, color: Colors.orange),
                ],
              ),

              // 操作按钮
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(S.of(context)!.timeline_close),
                  ),
                  SizedBox(width: 8.w),
                  FilledButton(
                    onPressed: () {
                      _EventEditDialog.show(context, event);
                    },
                    child: Text(S.of(context)!.timeline_edit),
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

/// 信息区块
class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        ...children,
      ],
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: theme.colorScheme.outline),
          SizedBox(width: 8.w),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 事件编辑对话框
class _EventEditDialog extends StatefulWidget {
  final StoryEvent event;

  const _EventEditDialog({required this.event});

  static void show(BuildContext context, StoryEvent event) {
    showDialog(
      context: context,
      builder: (context) => _EventEditDialog(event: event),
    );
  }

  @override
  State<_EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<_EventEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _storyTimeController;
  late final TextEditingController _relativeTimeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _consequencesController;
  late EventType _selectedType;
  late EventImportance _selectedImportance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event.name);
    _storyTimeController = TextEditingController(
      text: widget.event.storyTime ?? '',
    );
    _relativeTimeController = TextEditingController(
      text: widget.event.relativeTime ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.event.description ?? '',
    );
    _consequencesController = TextEditingController(
      text: widget.event.consequences ?? '',
    );
    _selectedType = widget.event.type;
    _selectedImportance = widget.event.importance;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storyTimeController.dispose();
    _relativeTimeController.dispose();
    _descriptionController.dispose();
    _consequencesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AlertDialog(
      title: Text(s.timeline_editEvent),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 事件名称
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: s.timeline_eventName,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.h),

              // 事件类型
              DropdownButtonFormField<EventType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: s.timeline_eventType,
                  border: OutlineInputBorder(),
                ),
                items: EventType.values.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type.label));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              SizedBox(height: 16.h),

              // 重要性
              DropdownButtonFormField<EventImportance>(
                initialValue: _selectedImportance,
                decoration: InputDecoration(
                  labelText: s.timeline_importance,
                  border: OutlineInputBorder(),
                ),
                items: EventImportance.values.map((importance) {
                  return DropdownMenuItem(
                    value: importance,
                    child: Text(importance.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedImportance = value);
                  }
                },
              ),
              SizedBox(height: 16.h),

              // 故事时间
              TextField(
                controller: _storyTimeController,
                decoration: InputDecoration(
                  labelText: s.timeline_storyTime(''),
                  hintText: s.timeline_storyTimeHint,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.h),

              // 相对时间
              TextField(
                controller: _relativeTimeController,
                decoration: InputDecoration(
                  labelText: s.timeline_relativeTime(''),
                  hintText: s.timeline_relativeTimeHint,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.h),

              // 描述
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: s.timeline_eventDescriptionLabel,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.h),

              // 后果
              TextField(
                controller: _consequencesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: s.timeline_subsequentImpactLabel,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _saveEvent, child: Text(s.save)),
      ],
    );
  }

  Future<void> _saveEvent() async {
    final s = S.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.timeline_pleaseEnterEventName)));
      return;
    }

    try {
      final updatedEvent = StoryEvent(
        id: widget.event.id,
        workId: widget.event.workId,
        name: _nameController.text.trim(),
        type: _selectedType,
        importance: _selectedImportance,
        storyTime: _storyTimeController.text.trim().isEmpty
            ? null
            : _storyTimeController.text.trim(),
        relativeTime: _relativeTimeController.text.trim().isEmpty
            ? null
            : _relativeTimeController.text.trim(),
        chapterId: widget.event.chapterId,
        locationId: widget.event.locationId,
        characterIds: widget.event.characterIds,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        consequences: _consequencesController.text.trim().isEmpty
            ? null
            : _consequencesController.text.trim(),
        predecessorId: widget.event.predecessorId,
        successorId: widget.event.successorId,
        createdAt: widget.event.createdAt,
      );

      final repository = Get.find<TimelineRepository>();
      await repository.updateEvent(updatedEvent);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.timeline_eventUpdated)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.timeline_saveFailed('$e'))));
      }
    }
  }
}
