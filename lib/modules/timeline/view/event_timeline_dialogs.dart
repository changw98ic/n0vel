part of 'event_timeline_parts.dart';

class EventDetailDialog extends StatelessWidget {
  final StoryEvent event;

  const EventDetailDialog({super.key, required this.event});

  static void show(BuildContext context, StoryEvent event) {
    showDialog(
      context: context,
      builder: (context) => EventDetailDialog(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = eventTimelineMeta(event.type);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventDetailDialogHeader(
                event: event,
                icon: icon,
                color: color,
              ),
              const Divider(height: 32),
              EventInfoSection(
                title: S.of(context)!.timeline_basicInfo,
                children: [
                  if (event.storyTime != null)
                    EventInfoRow(
                      icon: Icons.access_time,
                      label: S.of(context)!.timeline_storyTime(''),
                      value: event.storyTime!,
                    ),
                  if (event.relativeTime != null)
                    EventInfoRow(
                      icon: Icons.schedule,
                      label: S.of(context)!.timeline_relativeTime(''),
                      value: event.relativeTime!,
                    ),
                  if (event.chapterId != null)
                    EventInfoRow(
                      icon: Icons.book,
                      label: S.of(context)!.timeline_belongsToChapter,
                      value: S.of(context)!.timeline_chapterNumber(
                        event.chapterId!,
                      ),
                    ),
                ],
              ),
              if (event.description != null) ...[
                SizedBox(height: 16.h),
                EventInfoSection(
                  title: S.of(context)!.timeline_eventDescription,
                  children: [
                    Text(
                      event.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              if (event.consequences != null) ...[
                SizedBox(height: 16.h),
                EventInfoSection(
                  title: S.of(context)!.timeline_subsequentImpact,
                  children: [
                    Text(
                      event.consequences!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              SizedBox(height: 16.h),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  EventTimelineTag(label: event.type.label, color: color),
                  EventTimelineTag(
                    label: event.importance.label,
                    color: Colors.orange,
                  ),
                ],
              ),
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
                      EventEditDialog.show(context, event);
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

class EventDetailDialogHeader extends StatelessWidget {
  final StoryEvent event;
  final IconData icon;
  final Color color;

  const EventDetailDialogHeader({
    super.key,
    required this.event,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
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
    );
  }
}

class EventInfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const EventInfoSection({
    super.key,
    required this.title,
    required this.children,
  });

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

class EventInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const EventInfoRow({
    super.key,
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

class EventEditDialog extends StatefulWidget {
  final StoryEvent event;

  const EventEditDialog({super.key, required this.event});

  static void show(BuildContext context, StoryEvent event) {
    showDialog(
      context: context,
      builder: (context) => EventEditDialog(event: event),
    );
  }

  @override
  State<EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<EventEditDialog> {
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
              EventEditTextField(
                controller: _nameController,
                labelText: s.timeline_eventName,
              ),
              SizedBox(height: 16.h),
              EventTypeDropdown(
                value: _selectedType,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              SizedBox(height: 16.h),
              EventImportanceDropdown(
                value: _selectedImportance,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedImportance = value);
                  }
                },
              ),
              SizedBox(height: 16.h),
              EventEditTextField(
                controller: _storyTimeController,
                labelText: s.timeline_storyTime(''),
                hintText: s.timeline_storyTimeHint,
              ),
              SizedBox(height: 16.h),
              EventEditTextField(
                controller: _relativeTimeController,
                labelText: s.timeline_relativeTime(''),
                hintText: s.timeline_relativeTimeHint,
              ),
              SizedBox(height: 16.h),
              EventEditTextField(
                controller: _descriptionController,
                labelText: s.timeline_eventDescriptionLabel,
                maxLines: 3,
              ),
              SizedBox(height: 16.h),
              EventEditTextField(
                controller: _consequencesController,
                labelText: s.timeline_subsequentImpactLabel,
                maxLines: 3,
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
