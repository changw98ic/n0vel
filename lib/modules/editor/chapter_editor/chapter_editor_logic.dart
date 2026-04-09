import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/editor/data/chapter_repository.dart';
import '../../../features/editor/data/smart_segment_service.dart';
import '../../../features/editor/domain/chapter.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../core/services/extraction_service.dart';
import '../../../modules/editor/view/extraction_review_sheet.dart';
import '../../../shared/data/base_business/base_controller.dart';
import 'chapter_editor_state.dart';

/// ChapterEditor 业务逻辑
class ChapterEditorLogic extends BaseController {
  final ChapterEditorState state = ChapterEditorState();

  final ChapterRepository _chapterRepository = Get.find<ChapterRepository>();
  final CharacterRepository _characterRepository = Get.find<CharacterRepository>();
  final SmartSegmentService _smartSegmentService = SmartSegmentService();

  late final String chapterId;

  Timer? _autoSaveTimer;
  bool _isDisposed = false;
  int _saveRequestId = 0;
  static const int _maxHistorySize = 50;
  static const int _extractionWordThreshold = 3000;
  static const Duration _extractionCooldown = Duration(hours: 1);
  final Map<String, DateTime> _lastExtractionTime = {};

  ChapterEditorLogic();

  @override
  void onInit() {
    super.onInit();
    chapterId = Get.parameters['chapterId']!;
    loadChapter();
  }

  @override
  void onClose() {
    disposeController();
    super.onClose();
  }

  /// Call this from View's dispose to save final state
  void disposeController() {
    _isDisposed = true;
    _autoSaveTimer?.cancel();
  }

  /// Call this from View's dispose with final content
  Future<void> saveOnDispose(String content) async {
    if (state.chapter.value != null) {
      final wordCount = _calculateWordCount(content);
      try {
        await _chapterRepository.updateContent(
          state.chapter.value!.id,
          content,
          wordCount,
        );
      } catch (e) {
        debugPrint('[Editor] Save on dispose failed: $e');
      }
    }
  }

  Future<void> loadChapter() async {
    final chapter = await _chapterRepository.getChapterById(chapterId);
    state.chapter.value = chapter;

    if (chapter != null) {
      // Initialize undo stack with initial content
      state.undoStack.clear();
      state.undoStack.add(chapter.content ?? '');
      state.redoStack.clear();
      // Load characters for this work
      await loadCharacters();
    }
  }

  Future<void> loadCharacters() async {
    final chapter = state.chapter.value;
    if (chapter == null) return;
    try {
      final chars = await _characterRepository.getCharactersByWorkId(chapter.workId);
      state.characters.value = chars;
    } catch (_) {}
  }

  String? get workId => state.chapter.value?.workId;

  Future<void> updateTitle(String newTitle) async {
    await _chapterRepository.updateTitle(chapterId, newTitle);
    await loadChapter();
  }

  void onTextChanged(String newText) {
    final undoStack = state.undoStack;
    if (undoStack.isEmpty || undoStack.last != newText) {
      undoStack.add(newText);
      if (undoStack.length > _maxHistorySize) {
        undoStack.removeAt(0);
      }
      state.redoStack.clear();
    }
    scheduleAutoSave();
  }

  void scheduleAutoSave() {
    final requestId = _queueSaveRequest();
    _autoSaveTimer = Timer(
      const Duration(seconds: 2),
      () => saveContent(requestId: requestId),
    );
  }

  Future<void> saveContent({String? content, int? requestId}) async {
    if (state.chapter.value == null ||
        state.isSaving.value ||
        _isDisposed) return;

    _autoSaveTimer?.cancel();
    final textToSave = content ?? state.undoStack.last;
    final wordCount = _calculateWordCount(textToSave);
    final activeRequestId = requestId ?? ++_saveRequestId;

    state.isSaving.value = true;

    try {
      await _chapterRepository.updateContent(
        state.chapter.value!.id,
        textToSave,
        wordCount,
      );

      if (_shouldDiscardSaveResult(activeRequestId)) return;

      state.chapter.value = state.chapter.value!.copyWith(
        content: textToSave,
        wordCount: wordCount,
        updatedAt: DateTime.now(),
      );
      state.lastSavedAt.value = DateTime.now();

      // 后台自动提取（>= 3000 字 + 冷却检查）
      if (wordCount >= _extractionWordThreshold &&
          _shouldRunExtraction(chapterId)) {
        unawaited(_triggerBackgroundExtraction(textToSave));
      }
    } catch (e) {
      showErrorSnackbar('保存失败: $e');
    } finally {
      state.isSaving.value = false;
    }
  }

  int _queueSaveRequest() {
    _autoSaveTimer?.cancel();
    return ++_saveRequestId;
  }

  bool _shouldDiscardSaveResult(int requestId) {
    return _isDisposed || requestId != _saveRequestId;
  }

  void togglePanel() {
    state.isPanelVisible.value = !state.isPanelVisible.value;
  }

  String insertDialogueQuotes(String text, int cursorPos) {
    return _smartSegmentService.addDialogueQuotes(text, cursorPos);
  }

  String formatText(String text) {
    var formatted = text;
    formatted = _smartSegmentService.cleanupEmptyLines(formatted);
    formatted = _smartSegmentService.unifyPunctuation(formatted);
    formatted = _smartSegmentService.formatWithIndent(formatted);
    return formatted;
  }

  void undo() {
    final undoStack = state.undoStack;
    final redoStack = state.redoStack;

    if (undoStack.length <= 1) return;

    redoStack.add(undoStack.last);
    undoStack.removeLast();
  }

  void redo() {
    final redoStack = state.redoStack;
    if (redoStack.isEmpty) return;

    state.undoStack.add(redoStack.last);
    redoStack.removeLast();
  }

  String getUndoState() {
    return state.undoStack.last;
  }

  int getWordCount(String text) {
    return _calculateWordCount(text);
  }

  int getParagraphCount(String text) {
    return text
        .split(RegExp(r'\n+'))
        .where((segment) => segment.trim().isNotEmpty)
        .length;
  }

  int _calculateWordCount(String text) {
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final englishCount = RegExp(r'[a-zA-Z]+').allMatches(text).length;
    return chineseCount + englishCount;
  }

  SmartSegmentResult getSmartSegments(String text) {
    final result = _smartSegmentService.segment(text);
    return SmartSegmentResult(result.segments.map((s) =>
      SmartSegment(s.text, SmartSegmentType.values.firstWhere(
        (type) => type.name == s.type.name,
        orElse: () => SmartSegmentType.narration,
      )),
    ).toList());
  }

  // ---------------------------------------------------------------------------
  // Background extraction
  // ---------------------------------------------------------------------------

  bool _shouldRunExtraction(String chapterId) {
    final lastTime = _lastExtractionTime[chapterId];
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) > _extractionCooldown;
  }

  Future<void> _triggerBackgroundExtraction(String content) async {
    _lastExtractionTime[chapterId] = DateTime.now();
    final workId = state.chapter.value?.workId;
    if (workId == null) return;

    try {
      final extractionService = Get.find<ExtractionService>();
      final result = await extractionService.extractFromChapter(
        chapterContent: content,
        workId: workId,
      );

      if (result.totalCount == 0) return;

      final candidates = await extractionService.findNewEntities(result, workId);
      final newCandidates = candidates.where((c) => c.isNew).toList();

      if (newCandidates.isEmpty) return;

      // 通知用户
      if (!_isDisposed) {
        Get.snackbar(
          '发现新实体',
          '发现 ${newCandidates.length} 个新实体，点击查看',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () {
              ExtractionReviewSheet.show(
                candidates: candidates,
                workId: workId,
                onDone: loadCharacters,
              );
            },
            child: const Text('查看'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Editor] 后台提取失败: $e');
    }
  }

  String formatExportContent(Chapter chapter, String content, String format) {
    final buffer = StringBuffer();
    if (format == 'markdown') {
      buffer.writeln('# ${chapter.title}');
      buffer.writeln();
      buffer.writeln(content);
    } else {
      buffer.writeln('=== ${chapter.title} ===');
      buffer.writeln();
      buffer.writeln(content);
    }
    return buffer.toString();
  }
}

/// Helper class for smart segment results
class SmartSegmentResult {
  final List<SmartSegment> segments;

  SmartSegmentResult(this.segments);
}

/// Helper class for smart segment
class SmartSegment {
  final String text;
  final SmartSegmentType type;

  SmartSegment(this.text, this.type);
}

enum SmartSegmentType {
  dialogue,
  narration,
  action,
  description,
}
