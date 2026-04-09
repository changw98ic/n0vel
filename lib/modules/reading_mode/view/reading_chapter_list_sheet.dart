import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/editor/data/chapter_repository.dart';
import '../../../features/editor/domain/chapter.dart';

class ReadingChapterListSheet extends StatefulWidget {
  final String workId;
  final String? currentChapterId;
  final ValueChanged<Chapter> onChapterSelected;

  const ReadingChapterListSheet({
    super.key,
    required this.workId,
    this.currentChapterId,
    required this.onChapterSelected,
  });

  @override
  State<ReadingChapterListSheet> createState() =>
      _ReadingChapterListSheetState();
}

class _ReadingChapterListSheetState extends State<ReadingChapterListSheet> {
  List<Chapter>? _chapters;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final chapterRepo = Get.find<ChapterRepository>();
      final chapters = await chapterRepo.getChaptersByWorkId(widget.workId);
      if (mounted) {
        setState(() {
          _chapters = chapters;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            ListTile(
              title: const Text('章节列表'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Divider(),
            Expanded(child: _buildContent(scrollController)),
          ],
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    final s = S.of(context)!;
    if (_error != null) {
      return Center(child: Text('${s.loadFailed}: $_error'));
    }
    if (_chapters == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final chapters = _chapters!;
    return ListView.builder(
      controller: scrollController,
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final isCurrent = chapter.id == widget.currentChapterId;

        return ListTile(
          leading: CircleAvatar(
            radius: 12,
            backgroundColor: isCurrent ? Theme.of(context).colorScheme.primary : null,
            child: Text(
              '${chapter.sortOrder}',
              style: TextStyle(color: isCurrent ? Colors.white : null),
            ),
          ),
          title: Text(chapter.title),
          subtitle: Text('${chapter.wordCount} 字'),
          trailing: isCurrent ? const Icon(Icons.check, color: Colors.green) : null,
          onTap: () => widget.onChapterSelected(chapter),
        );
      },
    );
  }
}
