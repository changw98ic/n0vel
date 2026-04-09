import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/editor/domain/chapter.dart';
import '../../../features/review/domain/review_result.dart';
import '../../../features/work/domain/volume.dart';

class QuickReviewRequest {
  final String scope;
  final List<String> dimensions;
  final String? volumeId;
  final String? chapterId;

  const QuickReviewRequest(
    this.scope,
    this.dimensions, {
    this.volumeId,
    this.chapterId,
  });
}

class QuickReviewDialog extends StatefulWidget {
  final String workId;
  final List<Volume> volumes;
  final List<Chapter> chapters;

  const QuickReviewDialog({
    super.key,
    required this.workId,
    required this.volumes,
    required this.chapters,
  });

  @override
  State<QuickReviewDialog> createState() => _QuickReviewDialogState();
}

class _QuickReviewDialogState extends State<QuickReviewDialog> {
  String _scope = 'all';
  String? _selectedVolumeId;
  String? _selectedChapterId;
  final Set<String> _selectedDimensions = {};

  @override
  void initState() {
    super.initState();
    _selectedDimensions.addAll(ReviewDimension.values.map((d) => d.name));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AlertDialog(
      title: Text(s.review_quickReview_title),
      content: SizedBox(
        width: 400.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.review_reviewScope,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: 8.h),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'all', label: Text(s.review_scope_all)),
                ButtonSegment(
                  value: 'volume',
                  label: Text(s.review_scope_volume),
                ),
                ButtonSegment(
                  value: 'chapter',
                  label: Text(s.review_scope_chapter),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (selection) {
                setState(() {
                  _scope = selection.first;
                  if (_scope != 'volume') {
                    _selectedVolumeId = null;
                  }
                  if (_scope != 'chapter') {
                    _selectedChapterId = null;
                  }
                });
              },
            ),
            if (_scope == 'volume') ...[
              SizedBox(height: 16.h),
              DropdownButtonFormField<String>(
                initialValue: _selectedVolumeId,
                decoration: const InputDecoration(
                  labelText: '选择卷',
                  border: OutlineInputBorder(),
                ),
                items: widget.volumes
                    .map(
                      (volume) => DropdownMenuItem(
                        value: volume.id,
                        child: Text(volume.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVolumeId = value;
                  });
                },
              ),
            ],
            if (_scope == 'chapter') ...[
              SizedBox(height: 16.h),
              DropdownButtonFormField<String>(
                initialValue: _selectedChapterId,
                decoration: const InputDecoration(
                  labelText: '选择章节',
                  border: OutlineInputBorder(),
                ),
                items: widget.chapters
                    .map(
                      (chapter) => DropdownMenuItem(
                        value: chapter.id,
                        child: Text(chapter.title),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedChapterId = value;
                  });
                },
              ),
            ],
            SizedBox(height: 16.h),
            Text(
              s.review_reviewDimensions,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReviewDimension.values.map((dimension) {
                final isSelected =
                    _selectedDimensions.contains(dimension.name);
                return FilterChip(
                  label: Text(dimension.label),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      if (isSelected) {
                        _selectedDimensions.remove(dimension.name);
                      } else {
                        _selectedDimensions.add(dimension.name);
                      }
                    });
                  },
                );
              }).toList(),
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
          onPressed: _canSubmit
              ? () => Navigator.pop(
                    context,
                    QuickReviewRequest(
                      _scope,
                      _selectedDimensions.toList(),
                      volumeId: _selectedVolumeId,
                      chapterId: _selectedChapterId,
                    ),
                  )
              : null,
          child: Text(s.review_startReview),
        ),
      ],
    );
  }

  bool get _canSubmit {
    if (_selectedDimensions.isEmpty) {
      return false;
    }
    if (_scope == 'volume') {
      return _selectedVolumeId != null;
    }
    if (_scope == 'chapter') {
      return _selectedChapterId != null;
    }
    return true;
  }
}
