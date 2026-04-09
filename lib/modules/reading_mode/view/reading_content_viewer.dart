import 'package:flutter/material.dart';

import '../../../features/editor/domain/chapter.dart';
import '../../../features/reading_mode/domain/reading_models.dart';

class ReadingContentViewer extends StatefulWidget {
  final Chapter chapter;
  final ReadingSettings settings;
  final ScrollController scrollController;
  final ValueChanged<int>? onPositionChanged;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final void Function(String text, int start, int end)? onTextSelected;

  const ReadingContentViewer({
    super.key,
    required this.chapter,
    required this.settings,
    required this.scrollController,
    this.onPositionChanged,
    this.onPreviousChapter,
    this.onNextChapter,
    this.onTextSelected,
  });

  @override
  State<ReadingContentViewer> createState() => _ReadingContentViewerState();
}

class _ReadingContentViewerState extends State<ReadingContentViewer> {
  final TextEditingController _textController = TextEditingController();
  String _content = '';
  int _currentPosition = 0;

  @override
  void initState() {
    super.initState();
    _syncChapterContent();
  }

  @override
  void didUpdateWidget(ReadingContentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.id != widget.chapter.id) {
      _syncChapterContent();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.settings.background == ReadingBackground.dark
        ? Colors.white
        : Colors.black;

    return Container(
      color: _backgroundColor(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final position = _calculatePosition(notification.metrics.pixels);
            if (position != _currentPosition) {
              _currentPosition = position;
              widget.onPositionChanged?.call(position);
            }
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.all(widget.settings.pageMargin),
          child: SelectableText.rich(
            TextSpan(
              text: _content,
              style: TextStyle(
                fontFamily: widget.settings.fontFamily,
                fontSize: widget.settings.fontSize,
                height: widget.settings.lineHeight,
                color: textColor,
              ),
            ),
            onSelectionChanged: (selection, cause) {
              if (cause != SelectionChangedCause.longPress ||
                  selection.start < 0 ||
                  selection.end > _content.length ||
                  selection.start >= selection.end) {
                return;
              }
              widget.onTextSelected?.call(
                _content.substring(selection.start, selection.end),
                selection.start,
                selection.end,
              );
            },
          ),
        ),
      ),
    );
  }

  void _syncChapterContent() {
    _content = widget.chapter.content ?? '';
    _textController.text = _content;
    _currentPosition = 0;
  }

  Color _backgroundColor() {
    final value = widget.settings.background.value;
    return Color(int.parse(value.replaceFirst('#', '0xFF')));
  }

  int _calculatePosition(double pixels) {
    final charHeight = widget.settings.fontSize * widget.settings.lineHeight;
    final linesScrolled = pixels / charHeight;
    const charsPerLine = 30;
    return (linesScrolled * charsPerLine).floor();
  }
}
