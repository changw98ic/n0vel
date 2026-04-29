import 'package:flutter/material.dart';

import '../../../../app/widgets/desktop_shell.dart';

class StyleModeButton extends StatelessWidget {
  const StyleModeButton({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return FilledButton(
        key: buttonKey,
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class StyleModeFramingCard extends StatelessWidget {
  const StyleModeFramingCard({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class StyleQuestionnaireTextField extends StatelessWidget {
  const StyleQuestionnaireTextField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class StyleQuestionnaireChoiceGroup extends StatelessWidget {
  const StyleQuestionnaireChoiceGroup({
    super.key,
    required this.label,
    required this.currentValue,
    required this.values,
    required this.onSelected,
  });

  final String label;
  final String currentValue;
  final Map<String, String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in values.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: currentValue == entry.key,
                onSelected: (_) => onSelected(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

class StyleQuestionnaireTagGroup extends StatelessWidget {
  const StyleQuestionnaireTagGroup({
    super.key,
    required this.label,
    required this.selectedValues,
    required this.values,
    required this.onToggle,
  });

  final String label;
  final List<String> selectedValues;
  final List<String> values;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              FilterChip(
                label: Text(value),
                selected: selectedValues.contains(value),
                onSelected: (_) => onToggle(value),
              ),
          ],
        ),
      ],
    );
  }
}

List<String> styleStringListFromRaw(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return [
    for (final item in raw)
      if (item.toString().trim().isNotEmpty) item.toString(),
  ];
}
