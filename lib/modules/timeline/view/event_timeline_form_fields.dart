part of 'event_timeline_parts.dart';

class EventEditTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final int maxLines;

  const EventEditTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class EventTypeDropdown extends StatelessWidget {
  final EventType value;
  final ValueChanged<EventType?> onChanged;

  const EventTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<EventType>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: S.of(context)!.timeline_eventType,
        border: const OutlineInputBorder(),
      ),
      items: EventType.values.map((type) {
        return DropdownMenuItem(value: type, child: Text(type.label));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class EventImportanceDropdown extends StatelessWidget {
  final EventImportance value;
  final ValueChanged<EventImportance?> onChanged;

  const EventImportanceDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<EventImportance>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: S.of(context)!.timeline_importance,
        border: const OutlineInputBorder(),
      ),
      items: EventImportance.values.map((importance) {
        return DropdownMenuItem(
          value: importance,
          child: Text(importance.label),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
