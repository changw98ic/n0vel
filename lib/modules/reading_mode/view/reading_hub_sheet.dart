import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../features/reading_mode/domain/reading_models.dart';

class ReadingHubData {
  final ReadingProgress progress;
  final List<Bookmark> bookmarks;
  final List<ReadingNote> notes;
  final List<ReadingHighlight> highlights;
  final Map<String, String> chapterTitles;

  const ReadingHubData({
    required this.progress,
    required this.bookmarks,
    required this.notes,
    required this.highlights,
    required this.chapterTitles,
  });
}

class ReadingHubSheet extends StatelessWidget {
  final ReadingHubData data;
  final String? currentChapterId;
  final int currentPosition;
  final Future<void> Function(String chapterId, int position) onOpenChapter;
  final Future<void> Function(String bookmarkId) onDeleteBookmark;
  final Future<void> Function(String noteId) onDeleteNote;
  final Future<void> Function(String highlightId) onDeleteHighlight;

  const ReadingHubSheet({
    super.key,
    required this.data,
    required this.currentChapterId,
    required this.currentPosition,
    required this.onOpenChapter,
    required this.onDeleteBookmark,
    required this.onDeleteNote,
    required this.onDeleteHighlight,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 8.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '阅读中心',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (currentChapterId != null)
                  Text(
                    '位置 $currentPosition',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: '进度'),
              Tab(text: '书签'),
              Tab(text: '笔记'),
              Tab(text: '高亮'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ProgressTab(
                  progress: data.progress,
                  chapterTitles: data.chapterTitles,
                  currentChapterId: currentChapterId,
                  onOpenChapter: onOpenChapter,
                ),
                _BookmarkTab(
                  bookmarks: data.bookmarks,
                  chapterTitles: data.chapterTitles,
                  onOpenChapter: onOpenChapter,
                  onDeleteBookmark: onDeleteBookmark,
                ),
                _NoteTab(
                  notes: data.notes,
                  chapterTitles: data.chapterTitles,
                  onOpenChapter: onOpenChapter,
                  onDeleteNote: onDeleteNote,
                ),
                _HighlightTab(
                  highlights: data.highlights,
                  chapterTitles: data.chapterTitles,
                  onOpenChapter: onOpenChapter,
                  onDeleteHighlight: onDeleteHighlight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressTab extends StatelessWidget {
  final ReadingProgress progress;
  final Map<String, String> chapterTitles;
  final String? currentChapterId;
  final Future<void> Function(String chapterId, int position) onOpenChapter;

  const _ProgressTab({
    required this.progress,
    required this.chapterTitles,
    required this.currentChapterId,
    required this.onOpenChapter,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('整体进度', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 12.h),
                LinearProgressIndicator(value: progress.progressPercentage),
                SizedBox(height: 12.h),
                Text('总阅读时长 ${progress.totalReadingTime} 分钟'),
                Text('平均阅读速度 ${progress.averageSpeed.toStringAsFixed(1)} 字/分钟'),
                Text(
                  '最近阅读 ${chapterTitles[progress.currentChapterId] ?? progress.currentChapterId}',
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        ...progress.chapterProgressList.map(
          (chapter) => Card(
            child: ListTile(
              title: Text(chapter.chapterTitle),
              subtitle: Text(
                '${chapter.readWords}/${chapter.totalWords} 字 · ${chapter.readingCount} 次阅读',
              ),
              trailing: chapter.chapterId == currentChapterId
                  ? const Icon(Icons.play_circle_fill)
                  : null,
              onTap: () => onOpenChapter(chapter.chapterId, 0),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookmarkTab extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final Map<String, String> chapterTitles;
  final Future<void> Function(String chapterId, int position) onOpenChapter;
  final Future<void> Function(String bookmarkId) onDeleteBookmark;

  const _BookmarkTab({
    required this.bookmarks,
    required this.chapterTitles,
    required this.onOpenChapter,
    required this.onDeleteBookmark,
  });

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return const Center(child: Text('还没有书签'));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return Card(
          child: ListTile(
            title: Text(chapterTitles[bookmark.chapterId] ?? bookmark.chapterId),
            subtitle: Text(
              bookmark.note?.isNotEmpty == true
                  ? '${bookmark.note} · 位置 ${bookmark.position}'
                  : '位置 ${bookmark.position}',
            ),
            onTap: () => onOpenChapter(bookmark.chapterId, bookmark.position),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDeleteBookmark(bookmark.id),
            ),
          ),
        );
      },
    );
  }
}

class _NoteTab extends StatelessWidget {
  final List<ReadingNote> notes;
  final Map<String, String> chapterTitles;
  final Future<void> Function(String chapterId, int position) onOpenChapter;
  final Future<void> Function(String noteId) onDeleteNote;

  const _NoteTab({
    required this.notes,
    required this.chapterTitles,
    required this.onOpenChapter,
    required this.onDeleteNote,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(child: Text('还没有笔记'));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Card(
          child: ListTile(
            title: Text(chapterTitles[note.chapterId] ?? note.chapterId),
            subtitle: Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => onOpenChapter(note.chapterId, note.startPosition),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDeleteNote(note.id),
            ),
          ),
        );
      },
    );
  }
}

class _HighlightTab extends StatelessWidget {
  final List<ReadingHighlight> highlights;
  final Map<String, String> chapterTitles;
  final Future<void> Function(String chapterId, int position) onOpenChapter;
  final Future<void> Function(String highlightId) onDeleteHighlight;

  const _HighlightTab({
    required this.highlights,
    required this.chapterTitles,
    required this.onOpenChapter,
    required this.onDeleteHighlight,
  });

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return const Center(child: Text('还没有高亮'));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: highlights.length,
      itemBuilder: (context, index) {
        final highlight = highlights[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(
                int.parse(highlight.color.value.replaceFirst('#', '0xFF')),
              ),
            ),
            title: Text(chapterTitles[highlight.chapterId] ?? highlight.chapterId),
            subtitle: Text(highlight.selectedText, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => onOpenChapter(highlight.chapterId, highlight.startPosition),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDeleteHighlight(highlight.id),
            ),
          ),
        );
      },
    );
  }
}
