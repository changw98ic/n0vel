import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../features/editor/domain/chapter.dart';

class ReadingToolbar extends StatelessWidget {
  final Chapter? chapter;
  final VoidCallback onBack;
  final VoidCallback onChapterList;
  final VoidCallback onReadingHub;
  final VoidCallback onBookmark;
  final VoidCallback onSettings;

  const ReadingToolbar({
    super.key,
    required this.chapter,
    required this.onBack,
    required this.onChapterList,
    required this.onReadingHub,
    required this.onBookmark,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1714).withValues(alpha: 0.7),
            const Color(0xFF1A1714).withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onChapterList,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chapter?.title ?? '阅读中',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chapter != null)
                        Text(
                          '第 ${chapter!.sortOrder} 章',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.sp,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.library_books_outlined,
                  color: Colors.white,
                ),
                onPressed: onReadingHub,
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_border, color: Colors.white),
                onPressed: onBookmark,
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
