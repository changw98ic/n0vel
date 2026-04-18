import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../view/editor_toolbar.dart';

List<Widget> buildChapterEditorActions({
  required BuildContext context,
  required Widget saveStatusIndicator,
  required bool isPanelVisible,
  required VoidCallback onEditTitle,
  required VoidCallback onSaveNow,
  required VoidCallback onTogglePanel,
  required ValueChanged<String> onMenuSelected,
}) {
  final s = S.of(context)!;

  return [
    Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: saveStatusIndicator,
    ),
    IconButton(
      tooltip: s.editor_rename,
      icon: const Icon(Icons.edit_rounded),
      onPressed: onEditTitle,
    ),
    IconButton(
      tooltip: s.editor_saveNow,
      icon: const Icon(Icons.save_rounded),
      onPressed: onSaveNow,
    ),
    IconButton(
      tooltip: isPanelVisible ? s.editor_hideSidebar : s.editor_showSidebar,
      icon: Icon(
        isPanelVisible
            ? Icons.dashboard_customize_rounded
            : Icons.dashboard_rounded,
      ),
      onPressed: onTogglePanel,
    ),
    PopupMenuButton<String>(
      onSelected: onMenuSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'format',
          child: ListTile(
            leading: const Icon(Icons.auto_fix_high_rounded),
            title: Text(s.editor_polishChapter),
          ),
        ),
        PopupMenuItem(
          value: 'smart_segment',
          child: ListTile(
            leading: const Icon(Icons.segment_rounded),
            title: Text(s.editor_smartSegment),
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: ListTile(
            leading: const Icon(Icons.file_download_rounded),
            title: Text(s.editor_exportChapter),
          ),
        ),
        PopupMenuItem(
          value: 'review',
          child: ListTile(
            leading: const Icon(Icons.rate_review_rounded),
            title: Text(s.editor_reviewChapter),
          ),
        ),
      ],
    ),
    SizedBox(width: 12.w),
  ];
}

class ChapterEditorResponsiveBody extends StatelessWidget {
  final bool isPanelVisible;
  final Widget editorWorkspace;
  final Widget sidePanel;

  const ChapterEditorResponsiveBody({
    super.key,
    required this.isPanelVisible,
    required this.editorWorkspace,
    required this.sidePanel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSideBySide =
            isPanelVisible && constraints.maxWidth >= 1220;
        final sidePanelHeight = constraints.maxWidth >= 960 ? 360.0 : 420.0;

        return Column(
          children: [
            Expanded(
              child: showSideBySide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: editorWorkspace),
                        SizedBox(width: 18.w),
                        Expanded(flex: 4, child: sidePanel),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: editorWorkspace),
                        if (isPanelVisible) ...[
                          SizedBox(height: 18.h),
                          SizedBox(height: sidePanelHeight, child: sidePanel),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class ChapterEditorWorkspace extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final VoidCallback onQuote;
  final VoidCallback onFormat;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final Widget statusBar;

  const ChapterEditorWorkspace({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.scrollController,
    required this.onQuote,
    required this.onFormat,
    required this.onUndo,
    required this.onRedo,
    required this.statusBar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        EditorToolbar(
          onQuote: onQuote,
          onFormat: onFormat,
          onUndo: onUndo,
          onRedo: onRedo,
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest
                  .withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    focusNode: focusNode,
                    scrollController: scrollController,
                    maxLines: null,
                    expands: true,
                    textAlign: TextAlign.start,
                    keyboardType: TextInputType.multiline,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const ['Noto Serif SC', 'serif'],
                      fontSize: 17.sp,
                      height: 1.85,
                      letterSpacing: 0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: S.of(context)!.editor_startWriting,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding:
                          EdgeInsets.fromLTRB(24.w, 14.h, 24.w, 24.h),
                    ),
                  ),
                ),
                statusBar,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ChapterEditorStatusBar extends StatelessWidget {
  final int wordCount;
  final int paragraphCount;
  final int reviewMinutes;
  final double? reviewScore;

  const ChapterEditorStatusBar({
    super.key,
    required this.wordCount,
    required this.paragraphCount,
    required this.reviewMinutes,
    required this.reviewScore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context)!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChapterEditorStatusItem(
            icon: Icons.text_fields_rounded,
            label: s.editor_words(wordCount),
          ),
          ChapterEditorStatusItem(
            icon: Icons.view_day_rounded,
            label: s.editor_paragraphs(paragraphCount),
          ),
          ChapterEditorStatusItem(
            icon: Icons.schedule_rounded,
            label: s.editor_readingTime(reviewMinutes),
          ),
          if (reviewScore != null)
            ChapterEditorStatusItem(
              icon: Icons.verified_rounded,
              label: s.editor_score(reviewScore!.toStringAsFixed(1)),
            ),
        ],
      ),
    );
  }
}

class ChapterEditorStatusItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const ChapterEditorStatusItem({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16.sp),
        SizedBox(width: 6.w),
        Text(label),
      ],
    );
  }
}
