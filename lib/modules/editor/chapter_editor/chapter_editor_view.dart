import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../../app/widgets/app_shell.dart';
import '../../../features/editor/data/smart_segment_service.dart';
import '../editor_chat/editor_chat_view.dart';
import '../view/editor_toolbar.dart';
import '../view/statistics_panel.dart';
import '../view/review_options_dialog.dart';
import 'chapter_editor_logic.dart';

/// 章节编辑器页面
///
/// NOTE: This View remains as StatefulWidget to manage Flutter UI primitives:
/// - TextEditingController
/// - FocusNode
/// - ScrollController
///
/// All business logic is delegated to ChapterEditorLogic
class ChapterEditorView extends StatefulWidget {
  final String chapterId;

  const ChapterEditorView({super.key, required this.chapterId});

  @override
  State<ChapterEditorView> createState() => _ChapterEditorViewState();
}

class _ChapterEditorViewState extends State<ChapterEditorView> {
  late final ChapterEditorLogic _controller;

  // Flutter UI primitives - managed by StatefulWidget
  final _textController = TextEditingController();
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _smartSegmentService = SmartSegmentService();

  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ChapterEditorLogic>();
    _initialize();
  }

  Future<void> _initialize() async {
    await _controller.loadChapter();

    final chapter = _controller.state.chapter.value;
    if (chapter != null) {
      _titleController.text = chapter.title;
      _textController.text = chapter.content ?? '';
    }

    _textController.addListener(_onTextChanged);
    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    // Save final state before disposing
    _controller.saveOnDispose(_textController.text);
    _controller.disposeController();

    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _controller.onTextChanged(_textController.text);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Obx(() {
      final chapter = _controller.state.chapter.value;
      if (_isInitializing || chapter == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      return Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(
              onInvoke: (_) => _controller.saveContent()),
          _UndoIntent:
              CallbackAction<_UndoIntent>(onInvoke: (_) => _handleUndo()),
          _RedoIntent:
              CallbackAction<_RedoIntent>(onInvoke: (_) => _handleRedo()),
        },
        child: Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
                const _SaveIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
                const _UndoIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
                const _RedoIntent(),
          },
          child: AppPageScaffold(
          title: chapter.title,
          constrainWidth: false,
          bodyPadding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h),
          actions: [
            // Save status indicator
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: _SaveStatusDot(
                isSaving: _controller.state.isSaving.value,
                lastSavedAt: _controller.state.lastSavedAt.value,
              ),
            ),
            IconButton(
              tooltip: s.editor_rename,
              icon: const Icon(Icons.edit_rounded),
              onPressed: _editTitle,
            ),
            IconButton(
              tooltip: s.editor_saveNow,
              icon: const Icon(Icons.save_rounded),
              onPressed: () => _controller.saveContent(
                content: _textController.text,
              ),
            ),
            IconButton(
              tooltip: _controller.state.isPanelVisible.value
                  ? s.editor_hideSidebar
                  : s.editor_showSidebar,
              icon: Icon(_controller.state.isPanelVisible.value
                  ? Icons.dashboard_customize_rounded
                  : Icons.dashboard_rounded),
              onPressed: _controller.togglePanel,
            ),
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'format',
                    child: ListTile(
                        leading: const Icon(Icons.auto_fix_high_rounded),
                        title: Text(s.editor_polishChapter))),
                PopupMenuItem(
                    value: 'smart_segment',
                    child: ListTile(
                        leading: const Icon(Icons.segment_rounded),
                        title: Text(s.editor_smartSegment))),
                PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                        leading: const Icon(Icons.file_download_rounded),
                        title: Text(s.editor_exportChapter))),
                PopupMenuItem(
                    value: 'review',
                    child: ListTile(
                        leading: const Icon(Icons.rate_review_rounded),
                        title: Text(s.editor_reviewChapter))),
              ],
            ),
            SizedBox(width: 12.w),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showSideBySide =
                  _controller.state.isPanelVisible.value && constraints.maxWidth >= 1220;
              final sidePanelHeight =
                  constraints.maxWidth >= 960 ? 360.0 : 420.0;

              return Column(
                children: [
                  Expanded(
                    child: showSideBySide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 8, child: _buildEditorWorkspace()),
                              SizedBox(width: 18.w),
                              Expanded(flex: 4, child: _buildSidePanel()),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: _buildEditorWorkspace()),
                              if (_controller.state.isPanelVisible.value) ...[
                                SizedBox(height: 18.h),
                                SizedBox(
                                    height: sidePanelHeight, child: _buildSidePanel()),
                              ],
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        ),
      );
    });
  }

  Widget _buildEditorWorkspace() {
    final theme = Theme.of(context);

    return Column(
      children: [
        EditorToolbar(
          onQuote: _insertDialogueQuotes,
          onFormat: _formatText,
          onUndo: _handleUndo,
          onRedo: _handleRedo,
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                    controller: _textController,
                    focusNode: _focusNode,
                    scrollController: _scrollController,
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
                _buildStatusBar(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidePanel() {
    final theme = Theme.of(context);
    final s = S.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: TabBar(
                  tabs: [
                    Tab(text: s.editor_tab_ai),
                    Tab(text: s.editor_tab_statistics),
                    Tab(text: s.editor_tab_characters),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: TabBarView(
                children: [
                  EditorChatPanel(
                    chapterContent: () => _textController.text,
                    onInsert: _insertText,
                  ),
                  StatisticsPanel(content: _textController.text),
                  _CharacterQuickAccess(controller: _controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    final s = S.of(context)!;
    final wordCount = _controller.getWordCount(_textController.text);
    final paragraphCount = _controller.getParagraphCount(_textController.text);
    final reviewMinutes = (wordCount / 300).ceil();
    final chapter = _controller.state.chapter.value;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(
            top:
                BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45))),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusItem(icon: Icons.text_fields_rounded, label: s.editor_words(wordCount)),
          _StatusItem(icon: Icons.view_day_rounded, label: s.editor_paragraphs(paragraphCount)),
          _StatusItem(icon: Icons.schedule_rounded, label: s.editor_readingTime(reviewMinutes)),
          if (chapter?.reviewScore != null)
            _StatusItem(icon: Icons.verified_rounded, label: s.editor_score(chapter!.reviewScore!.toStringAsFixed(1))),
        ],
      ),
    );
  }

  void _editTitle() {
    final s = S.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.editor_renameTitle),
        content: TextField(
          controller: _titleController,
          autofocus: true,
          decoration: InputDecoration(hintText: s.editor_chapterTitleHint),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text(s.editor_cancel)),
          FilledButton(
            onPressed: () async {
              await _controller.updateTitle(_titleController.text);
              if (!context.mounted) return;
              Get.back();
              await _initialize();
            },
            child: Text(s.editor_save),
          ),
        ],
      ),
    );
  }

  void _insertDialogueQuotes() {
    final text = _textController.text;
    final cursorPos = _textController.selection.baseOffset;
    final newText = _controller.insertDialogueQuotes(text, cursorPos);
    if (newText != text) {
      _textController.text = newText;
      _textController.selection =
          TextSelection.collapsed(offset: cursorPos + 1);
    }
  }

  void _formatText() {
    _textController.text =
        _controller.formatText(_textController.text);
  }

  void _handleUndo() {
    _controller.undo();
    final previousText = _controller.getUndoState();
    _textController.text = previousText;
    _textController.selection =
        TextSelection.collapsed(offset: previousText.length);
  }

  void _handleRedo() {
    _controller.redo();
    final nextText = _controller.getUndoState();
    _textController.text = nextText;
    _textController.selection =
        TextSelection.collapsed(offset: nextText.length);
  }

  void _insertText(String text) {
    final cursorPos = _textController.selection.baseOffset;
    final currentText = _textController.text;
    final safeCursor = cursorPos < 0 ? currentText.length : cursorPos;
    _textController.text =
        currentText.substring(0, safeCursor) + text + currentText.substring(safeCursor);
    _textController.selection =
        TextSelection.collapsed(offset: safeCursor + text.length);
    _controller.scheduleAutoSave();
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'format':
        _formatText();
      case 'smart_segment':
        _showSmartSegmentPreview();
      case 'export':
        _exportChapter();
      case 'review':
        _startReview();
    }
  }

  void _showSmartSegmentPreview() async {
    final s = S.of(context)!;
    final chapter = _controller.state.chapter.value;
    if (chapter == null) return;

    final segments = _smartSegmentService.segment(_textController.text);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.editor_smartSegmentPreview),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: ListView.builder(
            itemCount: segments.segments.length,
            itemBuilder: (context, index) {
              final segment = segments.segments[index];
              return Card(
                margin: EdgeInsets.only(bottom: 10.h),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(segment.text.trim(),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${segment.text.length} chars · ${segment.type.name}'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text(s.editor_cancel)),
          FilledButton(
            onPressed: () {
              _textController.text =
                  segments.segments.map((s) => s.text).join('\n\n');
              Get.back();
              Get.snackbar(
                '成功',
                s.editor_applySegmentResult,
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Text(s.editor_apply),
          ),
        ],
      ),
    );
  }

  void _exportChapter() async {
    final s = S.of(context)!;
    final chapter = _controller.state.chapter.value;
    if (chapter == null) return;

    final format = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(s.editor_exportChapter),
        children: [
          SimpleDialogOption(
              onPressed: () => Get.back(result: 'txt'),
              child: Text(s.editor_exportFormatText)),
          SimpleDialogOption(
              onPressed: () => Get.back(result: 'markdown'),
              child: Text(s.editor_exportFormatMarkdown)),
        ],
      ),
    );

    if (format != null && context.mounted) {
      try {
        final content = _controller.formatExportContent(
            chapter, _textController.text, format);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.editor_exportPreview(format)),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child:
                  SingleChildScrollView(child: SelectableText(content)),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text(s.editor_close)),
              FilledButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  Get.snackbar(
                    '成功',
                    s.editor_copiedToClipboard,
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
                child: Text(s.editor_copy),
              ),
            ],
          ),
        );
      } catch (e) {
        if (context.mounted) {
          Get.snackbar(
            '失败',
            s.editor_exportFailed('$e'),
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    }
  }

  void _startReview() async {
    final s = S.of(context)!;
    final chapter = _controller.state.chapter.value;
    if (chapter == null) return;

    _controller.state.isPanelVisible.value = true;

    final dimensions = await showDialog<List<String>>(
      context: context,
      builder: (context) => ReviewOptionsDialog(chapterTitle: chapter.title),
    );

    if (dimensions != null && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.editor_reviewChapter),
          content: Text(s.editor_reviewConfirmation(
              '${dimensions.length}', chapter.title)),
          actions: [
            TextButton(
                onPressed: () => Get.back(result: false),
                child: Text(s.editor_cancel)),
            FilledButton(
              onPressed: () => Get.back(result: true),
              child: Text(s.editor_startReview),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        Get.snackbar(
          '提示',
          s.editor_reviewStarted,
          snackPosition: SnackPosition.BOTTOM,
        );
        Get.toNamed('/work/${chapter.workId}/review');
      }
    }
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusItem({required this.icon, required this.label});

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

class _CharacterQuickAccess extends StatelessWidget {
  final ChapterEditorLogic controller;
  const _CharacterQuickAccess({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = S.of(context)!;
    final workId = controller.workId;

    return Obx(() {
      final characters = controller.state.characters;

      if (characters.isEmpty) {
        return Center(
          child: AppEmptyState(
            icon: Icons.people_alt_outlined,
            title: '暂无角色',
            description: '点击下方按钮前往角色管理，为作品添加角色后即可在此快速查看',
            action: workId != null
                ? FilledButton.tonal(
                    onPressed: () => Get.toNamed('/work/$workId/characters'),
                    child: Text(s.editor_tab_characters),
                  )
                : null,
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: characters.length,
        itemBuilder: (context, index) {
          final c = characters[index];
          final tierLabel = switch (c.tier.name) {
            'protagonist' => '主角',
            'supporting' => '配角',
            'minor' => '龙套',
            _ => c.tier.name,
          };
          final tierColor = switch (c.tier.name) {
            'protagonist' => colorScheme.primary,
            'supporting' => colorScheme.secondary,
            'minor' => colorScheme.tertiary,
            _ => colorScheme.onSurfaceVariant,
          };
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16.r,
              backgroundColor: tierColor.withValues(alpha: 0.15),
              child: Text(
                c.name.isNotEmpty ? c.name.substring(0, 1) : '?',
                style: TextStyle(color: tierColor, fontWeight: FontWeight.w600),
              ),
            ),
            title: Text(c.name, style: theme.textTheme.bodyMedium),
            subtitle: Text(tierLabel, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              onPressed: workId != null
                  ? () => Get.toNamed('/work/$workId/characters/${c.id}')
                  : null,
            ),
            onTap: workId != null
                ? () => Get.toNamed('/work/$workId/characters/${c.id}')
                : null,
          );
        },
      );
    });
  }
}

class _SaveStatusDot extends StatelessWidget {
  final bool isSaving;
  final DateTime? lastSavedAt;

  const _SaveStatusDot({required this.isSaving, this.lastSavedAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isSaving) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(width: 6.w),
          Text('保存中...', style: theme.textTheme.bodySmall),
        ],
      );
    }

    if (lastSavedAt != null) {
      final time =
          '${lastSavedAt!.hour.toString().padLeft(2, '0')}:${lastSavedAt!.minute.toString().padLeft(2, '0')}';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.green.shade400,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text('已保存 $time', style: theme.textTheme.bodySmall),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// Keyboard shortcut intents
class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}
