import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../view/reading_content_viewer.dart';
import '../view/reading_toolbar.dart';
import '../view/reading_settings_panel.dart';
import '../view/reading_hub_sheet.dart';
import '../view/reading_chapter_list_sheet.dart';
import '../view/reading_text_selection_menu.dart';
import 'reader_logic.dart';

/// 阅读模式页面
class ReaderView extends GetView<ReaderLogic> {
  const ReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      SystemChrome.setSystemUIOverlayStyle(
        controller.state.isToolbarVisible.value
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      );

      return Scaffold(
        body: Stack(
          children: [
            GestureDetector(
              onTap: controller.toggleToolbar,
              child: _buildReadingArea(context),
            ),
            if (controller.state.isToolbarVisible.value)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ReadingToolbar(
                  chapter: controller.state.currentChapter.value,
                  onBack: () => Get.back(),
                  onChapterList: () => _showChapterList(context),
                  onReadingHub: () => _showReadingHub(context),
                  onBookmark: () => _showBookmarkDialog(context),
                  onSettings: controller.showSettings,
                ),
              ),
            if (controller.state.isToolbarVisible.value)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildProgressBar(context),
              ),
            if (controller.state.isSettingsVisible.value)
              Positioned.fill(
                child: ReadingSettingsPanel(
                  settings: controller.state.settings.value,
                  onChanged: controller.updateSettings,
                  onClose: controller.hideSettings,
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildReadingArea(BuildContext context) {
    final s = S.of(context)!;
    if (controller.state.currentChapterId.value == null) {
      return _buildChapterSelector(context);
    }

    if (controller.state.chapterError.value != null) {
      return _ErrorState(
        message: '${s.loadFailed}: ${controller.state.chapterError.value}',
        actionLabel: s.retry,
        onPressed: controller.reloadChapter,
      );
    }

    return Obx(() {
      if (controller.state.loadedChapter.value == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final chapter = controller.state.loadedChapter.value!;

      return ReadingContentViewer(
        chapter: chapter,
        settings: controller.state.settings.value,
        scrollController: ScrollController(),
        onPositionChanged: (position) {
          controller.setCurrentPosition(position);
        },
        onPreviousChapter:
            controller.hasPreviousChapter ? controller.goToPreviousChapter : null,
        onNextChapter: controller.hasNextChapter ? controller.goToNextChapter : null,
        onTextSelected: _handleTextSelection,
      );
    });
  }

  Widget _buildChapterSelector(BuildContext context) {
    final s = S.of(context)!;
    return Obx(() {
      if (controller.state.chaptersForSelectorError.value != null) {
        return _ErrorState(
          message: '${s.loadFailed}: ${controller.state.chaptersForSelectorError.value}',
        );
      }
      if (controller.state.chaptersForSelector.value == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final chapters = controller.state.chaptersForSelector.value!;
      return Scaffold(
        appBar: AppBar(title: const Text('选择章节')),
        body: ListView.builder(
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            return ListTile(
              leading: CircleAvatar(radius: 12, child: Text('${chapter.sortOrder}')),
              title: Text(chapter.title),
              subtitle: Text('${chapter.wordCount} 字'),
              onTap: () {
                controller.setCurrentChapterId(chapter.id);
                controller.loadChapter(chapter.id);
              },
            );
          },
        ),
      );
    });
  }

  Widget _buildProgressBar(BuildContext context) {
    return Obx(() {
      if (controller.state.readingProgressError.value != null ||
          controller.state.readingProgress.value == null) {
        return const SizedBox.shrink();
      }

      final progress = controller.state.readingProgress.value!;
      final settings = controller.state.settings.value;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress.progressPercentage,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withOpacity(0.3),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      '第 ${controller.state.currentChapter.value?.sortOrder ?? 1} 章',
                      style: TextStyle(fontSize: 12.sp)),
                  Text(
                    '${(controller.state.currentPosition.value / settings.fontSize / 1.8).floor()} / ${controller.state.currentChapter.value?.wordCount ?? 0} 字',
                    style: TextStyle(fontSize: 12.sp),
                  ),
                  if (settings.showTime)
                    Text(
                      controller.formatTime(DateTime.now()),
                      style: TextStyle(fontSize: 12.sp),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  void _handleTextSelection(String selectedText, int start, int end) {
    final s = Get.context != null ? S.of(Get.context!)! : null;
    showModalBottomSheet(
      context: Get.context!,
      builder: (context) => ReadingTextSelectionMenu(
        selectedText: selectedText,
        onHighlight: (color) =>
            controller.addHighlight(start, end, selectedText, color),
        onNote: () => _addNote(start, end, selectedText),
        onCopy: () {
          Clipboard.setData(ClipboardData(text: selectedText));
          Get.back();
          Get.snackbar(
            '成功',
            s?.copied ?? '已复制',
            snackPosition: SnackPosition.BOTTOM,
          );
        },
      ),
    );
  }

  Future<void> _addNote(int start, int end, String text) async {
    Get.back();

    final noteController = TextEditingController();
    final tagsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('添加笔记'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  text.length > 100 ? '${text.substring(0, 100)}...' : text,
                  style: TextStyle(fontSize: 12.sp),
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: '笔记内容',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                autofocus: true,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: '标签',
                  hintText: '逗号分隔',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (noteController.text.trim().isNotEmpty) {
                Get.back(result: true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      noteController.dispose();
      tagsController.dispose();
      return;
    }

    final tags = tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    await controller.addNote(start, end, text, tags);

    noteController.dispose();
    tagsController.dispose();
  }

  void _showChapterList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReadingChapterListSheet(
        workId: controller.workId,
        currentChapterId: controller.state.currentChapterId.value,
        onChapterSelected: (chapter) {
          controller.setCurrentChapterId(chapter.id);
          controller.loadChapter(chapter.id);
          Get.back();
        },
      ),
    );
  }

  void _showBookmarkDialog(BuildContext context) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加书签'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '第 ${controller.state.currentChapter.value?.sortOrder ?? 1} 章 · 位置 ${controller.state.currentPosition.value}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text('保存')),
        ],
      ),
    );

    if (confirmed == true && controller.state.currentChapterId.value != null) {
      await controller.saveBookmark(
        controller.state.currentPosition.value,
        noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );
    }
    noteController.dispose();
  }

  void _showReadingHub(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.88,
        child: FutureBuilder<dynamic>(
          future: controller.loadReadingHubData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: '加载失败: ${snapshot.error}',
                actionLabel: '重试',
                onPressed: () {
                  Get.back();
                  _showReadingHub(context);
                },
              );
            }

            return ReadingHubSheet(
              data: snapshot.data!,
              currentChapterId: controller.state.currentChapterId.value,
              currentPosition: controller.state.currentPosition.value,
              onOpenChapter: (chapterId, position) async {
                Get.back();
                controller.setCurrentChapterId(chapterId);
                await controller.loadChapter(chapterId);
              },
              onDeleteBookmark: (id) async {
                await controller.deleteBookmark(id);
                if (!context.mounted) return;
                Get.back();
                _showReadingHub(context);
              },
              onDeleteNote: (id) async {
                await controller.deleteNote(id);
                if (!context.mounted) return;
                Get.back();
                _showReadingHub(context);
              },
              onDeleteHighlight: (id) async {
                await controller.deleteHighlight(id);
                if (!context.mounted) return;
                Get.back();
                _showReadingHub(context);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _ErrorState({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48.sp),
          SizedBox(height: 16.h),
          Text(message),
          if (actionLabel != null && onPressed != null) ...[
            SizedBox(height: 12.h),
            ElevatedButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
