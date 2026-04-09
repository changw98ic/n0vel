import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/statistics/domain/statistics_models.dart';

/// 章节进度组件
class ChapterProgressWidget extends StatelessWidget {
  final List<ChapterProgress> chapters;
  final int totalWords;

  const ChapterProgressWidget({
    super.key,
    required this.chapters,
    required this.totalWords,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context)!;

    if (chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(s.statistics_noChapterData, style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.statistics_chapterProgress,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  s.statistics_totalChapters(chapters.length),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // 进度条
            _buildProgressBar(context),
            SizedBox(height: 24.h),

            // 章节列表
            ...chapters.map((chapter) => _ChapterProgressItem(
                  chapter: chapter,
                  totalWords: totalWords,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final statusCounts = <ChapterStatus, int>{};
    for (final chapter in chapters) {
      statusCounts[chapter.status] = (statusCounts[chapter.status] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: Row(
            children: ChapterStatus.values.map((status) {
              final count = statusCounts[status] ?? 0;
              final percentage = chapters.isNotEmpty ? count / chapters.length : 0.0;

              if (percentage == 0) return const SizedBox.shrink();

              return Expanded(
                flex: (percentage * 100).round(),
                child: Container(
                  height: 8,
                  color: _getStatusColor(status),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 16,
          children: ChapterStatus.values.map((status) {
            final count = statusCounts[status] ?? 0;
            if (count == 0) return const SizedBox.shrink();

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  '${status.label} $count',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getStatusColor(ChapterStatus status) {
    return switch (status) {
      ChapterStatus.draft => Colors.grey,
      ChapterStatus.writing => Colors.blue,
      ChapterStatus.revision => Colors.orange,
      ChapterStatus.review => Colors.purple,
      ChapterStatus.published => Colors.green,
    };
  }
}

/// 章节进度项
class _ChapterProgressItem extends StatelessWidget {
  final ChapterProgress chapter;
  final int totalWords;

  const _ChapterProgressItem({
    required this.chapter,
    required this.totalWords,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wordPercentage = totalWords > 0 ? chapter.wordCount / totalWords : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          // 序号
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getStatusColor(chapter.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: Text(
                '${chapter.order}',
                style: TextStyle(
                  color: _getStatusColor(chapter.status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),

          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chapter.chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: _getStatusColor(chapter.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        chapter.status.label,
                        style: TextStyle(
                          color: _getStatusColor(chapter.status),
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      '${chapter.wordCount} 字',
                      style: theme.textTheme.bodySmall,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2.r),
                        child: LinearProgressIndicator(
                          value: wordPercentage.clamp(0.0, 1.0) * 10, // 放大显示
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getStatusColor(chapter.status),
                          ),
                          minHeight: 4.h,
                        ),
                      ),
                    ),
                    if (chapter.reviewScore != null) ...[
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.star,
                        size: 14.sp,
                        color: Colors.amber,
                      ),
                      Text(
                        chapter.reviewScore!.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ChapterStatus status) {
    return switch (status) {
      ChapterStatus.draft => Colors.grey,
      ChapterStatus.writing => Colors.blue,
      ChapterStatus.revision => Colors.orange,
      ChapterStatus.review => Colors.purple,
      ChapterStatus.published => Colors.green,
    };
  }
}
