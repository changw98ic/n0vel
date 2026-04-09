import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

class ReviewOptionsDialog extends StatefulWidget {
  final String chapterTitle;

  const ReviewOptionsDialog({super.key, required this.chapterTitle});

  @override
  State<ReviewOptionsDialog> createState() => _ReviewOptionsDialogState();
}

class _ReviewOptionsDialogState extends State<ReviewOptionsDialog> {
  final Set<String> _selectedDimensions = {
    'consistency',
    'characterOOC',
    'plotLogic',
    'pacing',
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AlertDialog(
      title: Text(s.editor_reviewTitle(widget.chapterTitle)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.editor_reviewDescription),
            SizedBox(height: 16.h),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(s.editor_dimension_consistency, 'consistency'),
                _chip(s.editor_dimension_characterOOC, 'characterOOC'),
                _chip(s.editor_dimension_plotLogic, 'plotLogic'),
                _chip(s.editor_dimension_pacing, 'pacing'),
                _chip(s.editor_dimension_spelling, 'spelling'),
                _chip(s.editor_dimension_aiStyle, 'aiStyle'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.editor_cancel),
        ),
        FilledButton(
          onPressed: _selectedDimensions.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedDimensions.toList()),
          child: Text(s.editor_continue),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    final isSelected = _selectedDimensions.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          if (isSelected) {
            _selectedDimensions.remove(value);
          } else {
            _selectedDimensions.add(value);
          }
        });
      },
    );
  }
}
