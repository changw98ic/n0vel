import 'dart:async';

import 'package:get/get.dart';

import '../../../features/editor/data/chapter_repository.dart';
import '../../../features/editor/domain/chapter.dart';
import '../../../features/reading_mode/data/reading_service.dart';
import '../../../features/reading_mode/domain/reading_models.dart';
import '../../../shared/data/base_business/base_controller.dart';
import 'reader_state.dart';

/// Reader 业务逻辑
class ReaderLogic extends BaseController {
  final ReaderState state = ReaderState();

  final ChapterRepository _chapterRepository = Get.find<ChapterRepository>();
  final ReadingService _readingService = Get.find<ReadingService>();

  late final String workId;
  String? initialChapterId;

  Timer? _saveProgressTimer;
  bool _isDisposed = false;
  int _progressRequestId = 0;
  DateTime? _sessionStartTime;

  ReaderLogic();

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id']!;
    initialChapterId = Get.parameters['chapter'];
    state.currentChapterId.value = initialChapterId;
    _sessionStartTime = DateTime.now();
    loadSettings();
    loadReadingProgress();
    if (state.currentChapterId.value != null) {
      loadChapter(state.currentChapterId.value!);
    } else {
      loadChaptersForSelector();
    }
  }

  @override
  void onClose() {
    _isDisposed = true;
    _saveProgressTimer?.cancel();
    recordSession();
    super.onClose();
  }

  Future<void> loadSettings() async {
    final settings = await _readingService.getReadingSettings();
    state.settings.value = settings;
  }

  Future<void> loadReadingProgress() async {
    if (state.currentChapterId.value == null) return;

    try {
      final progress = await _readingService.getReadingProgress(workId);

      if (progress.currentChapterId.isNotEmpty) {
        state.currentChapterId.value = progress.currentChapterId;
        state.startPosition.value = progress.currentPosition;
        state.currentPosition.value = progress.currentPosition;
        loadChapter(state.currentChapterId.value!);
      }
    } catch (e) {
      // Ignore error on initial load
    }
  }

  Future<void> loadChapter(String chapterId) async {
    try {
      final chapter = await _chapterRepository.getChapterById(chapterId);
      state.loadedChapter.value = chapter;
      state.chapterError.value = null;
      state.currentChapter.value = chapter;
      loadReadingProgressForBar();
    } catch (e) {
      state.chapterError.value = e;
    }
  }

  Future<void> reloadChapter() async {
    if (state.currentChapterId.value != null) {
      state.loadedChapter.value = null;
      state.chapterError.value = null;
      await loadChapter(state.currentChapterId.value!);
    }
  }

  Future<void> loadReadingProgressForBar() async {
    try {
      final progress = await _readingService.getReadingProgress(workId);
      state.readingProgress.value = progress;
      state.readingProgressError.value = null;
    } catch (e) {
      state.readingProgressError.value = e;
    }
  }

  Future<void> loadChaptersForSelector() async {
    try {
      final chapters = await _chapterRepository.getChaptersByWorkId(workId);
      state.chaptersForSelector.value = chapters;
      state.chaptersForSelectorError.value = null;
    } catch (e) {
      state.chaptersForSelectorError.value = e;
    }
  }

  void setCurrentChapterId(String? id) {
    state.currentChapterId.value = id;
  }

  void setCurrentPosition(int position) {
    state.currentPosition.value = position;
    scheduleProgressSave();
  }

  void scheduleProgressSave() {
    _saveProgressTimer?.cancel();
    final requestId = ++_progressRequestId;
    _saveProgressTimer = Timer(
      const Duration(seconds: 2),
      () => saveReadingProgress(requestId: requestId),
    );
  }

  Future<void> saveReadingProgress({int? requestId}) async {
    if (state.currentChapterId.value == null || _isDisposed) return;

    final activeRequestId = requestId ?? ++_progressRequestId;
    try {
      await _readingService.recordReadingSession(
        workId: workId,
        chapterId: state.currentChapterId.value!,
        startTime: DateTime.now().subtract(const Duration(seconds: 1)),
        endTime: DateTime.now(),
        startPosition: state.startPosition.value,
        endPosition: state.currentPosition.value,
      );
    } catch (_) {
      if (_isDisposed || activeRequestId != _progressRequestId) return;
    }
  }

  void toggleToolbar() {
    state.isToolbarVisible.value = !state.isToolbarVisible.value;
  }

  void showSettings() {
    state.isSettingsVisible.value = true;
  }

  void hideSettings() {
    state.isSettingsVisible.value = false;
  }

  Future<void> updateSettings(ReadingSettings settings) async {
    await _readingService.saveReadingSettings(settings);
    state.settings.value = settings;
  }

  bool get hasPreviousChapter =>
      state.currentChapter.value != null &&
      state.currentChapter.value!.sortOrder > 1;

  bool get hasNextChapter =>
      state.currentChapter.value != null &&
      state.currentChapter.value!.sortOrder < 1000;

  Future<void> goToPreviousChapter() async {
    if (state.currentChapterId.value == null) return;
    await recordSession();

    final previous = await _chapterRepository
        .getPreviousChapter(state.currentChapterId.value!);

    if (previous != null) {
      state.currentChapterId.value = previous.id;
      state.currentChapter.value = previous;
      state.currentPosition.value = 0;
      state.startPosition.value = 0;
      _sessionStartTime = DateTime.now();
      state.loadedChapter.value = previous;
      loadReadingProgressForBar();
    } else {
      showErrorSnackbar('已经是第一章');
    }
  }

  Future<void> goToNextChapter() async {
    if (state.currentChapterId.value == null) return;
    await recordSession();

    final next = await _chapterRepository
        .getNextChapter(state.currentChapterId.value!);

    if (next != null) {
      state.currentChapterId.value = next.id;
      state.currentChapter.value = next;
      state.currentPosition.value = 0;
      state.startPosition.value = 0;
      _sessionStartTime = DateTime.now();
      state.loadedChapter.value = next;
      loadReadingProgressForBar();
    } else {
      showErrorSnackbar('已经是最后一章');
    }
  }

  Future<void> addHighlight(
    int start,
    int end,
    String text,
    HighlightColor color,
  ) async {
    await _readingService.saveHighlight(
      chapterId: state.currentChapterId.value!,
      workId: workId,
      startPosition: start,
      endPosition: end,
      selectedText: text,
      color: color,
    );
    showSuccessSnackbar('高亮已添加');
  }

  Future<void> addNote(
    int start,
    int end,
    String text,
    List<String> tags,
  ) async {
    await _readingService.saveNote(
      chapterId: state.currentChapterId.value!,
      workId: workId,
      startPosition: start,
      endPosition: end,
      selectedText: text,
      content: tags.join(', '), // This will be replaced with actual note content
      tags: tags.isNotEmpty ? tags : null,
    );
    showSuccessSnackbar('笔记已保存');
  }

  Future<void> saveBookmark(int position, String? note) async {
    await _readingService.saveBookmark(
      chapterId: state.currentChapterId.value!,
      workId: workId,
      position: position,
      note: note,
    );
    showSuccessSnackbar('书签已添加');
  }

  Future<void> deleteBookmark(String id) async {
    await _readingService.deleteBookmark(id);
  }

  Future<void> deleteNote(String id) async {
    await _readingService.deleteNote(id);
  }

  Future<void> deleteHighlight(String id) async {
    await _readingService.deleteHighlight(id);
  }

  Future<HubData> loadReadingHubData() async {
    final results = await Future.wait([
      _readingService.getReadingProgress(workId),
      _readingService.getWorkBookmarks(workId),
      _readingService.getWorkNotes(workId),
      _readingService.getWorkHighlights(workId),
      _chapterRepository.getChaptersByWorkId(workId),
    ]);

    final chapters = results[4] as List<Chapter>;
    final progress = results[0] as ReadingProgress;
    final bookmarks = results[1] as List<Bookmark>;
    final notes = results[2] as List<ReadingNote>;
    final highlights = results[3] as List<ReadingHighlight>;

    // Create a simple map for chapter titles
    final chapterTitles = <String, String>{};
    for (final ch in chapters) {
      chapterTitles[ch.id] = ch.title;
    }

    return HubData(
      progress: progress,
      bookmarks: bookmarks,
      notes: notes,
      highlights: highlights,
      chapterTitles: chapterTitles,
    );
  }

  Future<void> recordSession() async {
    if (_sessionStartTime == null || state.currentChapterId.value == null) return;

    await _readingService.recordReadingSession(
      workId: workId,
      chapterId: state.currentChapterId.value!,
      startTime: _sessionStartTime!,
      endTime: DateTime.now(),
      startPosition: state.startPosition.value,
      endPosition: state.currentPosition.value,
    );
  }

  String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Simple data class for reading hub
class HubData {
  final ReadingProgress progress;
  final List<Bookmark> bookmarks;
  final List<ReadingNote> notes;
  final List<ReadingHighlight> highlights;
  final Map<String, String> chapterTitles;

  HubData({
    required this.progress,
    required this.bookmarks,
    required this.notes,
    required this.highlights,
    required this.chapterTitles,
  });
}
