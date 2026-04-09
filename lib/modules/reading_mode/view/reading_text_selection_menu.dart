import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../features/reading_mode/domain/reading_models.dart';

class ReadingTextSelectionMenu extends StatelessWidget {
  final String selectedText;
  final Function(HighlightColor) onHighlight;
  final VoidCallback onNote;
  final VoidCallback onCopy;

  const ReadingTextSelectionMenu({
    super.key,
    required this.selectedText,
    required this.onHighlight,
    required this.onNote,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              selectedText.length > 100
                  ? '${selectedText.substring(0, 100)}...'
                  : selectedText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 16.h),
          const Text('高亮颜色'),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: HighlightColor.values.map((color) {
              return GestureDetector(
                onTap: () => onHighlight(color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(
                      int.parse(color.value.replaceFirst('#', '0xFF')),
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNote,
                  icon: const Icon(Icons.note_add),
                  label: const Text('添加笔记'),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy),
                  label: const Text('复制'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
