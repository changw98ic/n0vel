import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:get/get.dart' hide Value;

import '../../../core/database/database.dart';
import '../../editor/data/chapter_repository.dart';
import '../domain/reading_models.dart' as models;

class ReadingService {
  final AppDatabase _db;

  ReadingService(this._db);

  Future<models.ReadingProgress> getReadingProgress(String workId) async {
    final chapterRepo = Get.find<ChapterRepository>();
    final chapters = await chapterRepo.getChaptersByWorkId(workId);

    final progressData = await (_db.select(
      _db.readingProgressTable,
    )..where((tbl) => tbl.workId.equals(workId))).getSingleOrNull();

    final currentChapterId =
        progressData?.currentChapterId ??
        (chapters.isNotEmpty ? chapters.first.id : '');

    final chapterProgressList = <models.ChapterProgress>[];
    var totalWords = 0;

    for (final chapter in chapters) {
      totalWords += chapter.wordCount;

      final sessions =
          await (_db.select(_db.readingSessions)
                ..where((tbl) => tbl.chapterId.equals(chapter.id))
                ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)]))
              .get();

      final readingCount = sessions.length;
      final isCompleted = sessions.any(
        (s) => s.endPosition >= chapter.wordCount,
      );
      final lastReadAt = sessions.isNotEmpty
          ? sessions.first.startTime
          : chapter.updatedAt;

      chapterProgressList.add(
        models.ChapterProgress(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          totalWords: chapter.wordCount,
          readWords: isCompleted
              ? chapter.wordCount
              : (readingCount > 0 ? (chapter.wordCount * 0.5).toInt() : 0),
          isCompleted: isCompleted,
          completedAt: isCompleted ? lastReadAt : null,
          lastReadAt: lastReadAt,
          readingCount: readingCount,
        ),
      );
    }

    final readWords = chapterProgressList.fold<int>(
      0,
      (sum, cp) => sum + cp.readWords,
    );
    final progressPercentage = totalWords > 0 ? readWords / totalWords : 0.0;

    final allSessions = await (_db.select(
      _db.readingSessions,
    )..where((tbl) => tbl.workId.equals(workId))).get();

    final totalReadingTime = allSessions.fold<int>(
      0,
      (sum, session) =>
          sum + session.endTime.difference(session.startTime).inMinutes,
    );

    final totalWordsRead = allSessions.fold<int>(
      0,
      (sum, session) => sum + session.wordsRead,
    );
    final averageSpeed = totalReadingTime > 0
        ? totalWordsRead / totalReadingTime
        : 0.0;

    final bookmarks = await (_db.select(
      _db.bookmarks,
    )..where((tbl) => tbl.workId.equals(workId))).get();

    final bookmarkMap = <String, int>{};
    for (final bookmark in bookmarks) {
      bookmarkMap[bookmark.chapterId] = bookmark.position;
    }

    return models.ReadingProgress(
      workId: workId,
      currentChapterId: currentChapterId,
      currentPosition: progressData?.currentPosition ?? 0,
      progressPercentage: progressPercentage,
      lastReadAt: progressData?.lastReadAt ?? DateTime.now(),
      totalReadingTime: totalReadingTime,
      averageSpeed: averageSpeed,
      chapterProgressList: chapterProgressList,
      bookmarks: bookmarkMap,
    );
  }

  Future<models.Bookmark> saveBookmark({
    required String chapterId,
    required String workId,
    required int position,
    String? selectedText,
    String? note,
    String? color,
  }) async {
    final id = 'bm_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    await _db
        .into(_db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: id,
            chapterId: chapterId,
            workId: workId,
            position: position,
            selectedText: Value(selectedText),
            note: Value(note),
            color: Value(color),
            createdAt: now,
          ),
        );

    return models.Bookmark(
      id: id,
      chapterId: chapterId,
      workId: workId,
      position: position,
      selectedText: selectedText,
      note: note,
      createdAt: now,
      color: color,
    );
  }

  Future<List<models.Bookmark>> getChapterBookmarks(String chapterId) async {
    final bookmarkData =
        await (_db.select(_db.bookmarks)
              ..where((tbl) => tbl.chapterId.equals(chapterId))
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
            .get();

    return bookmarkData
        .map(
          (data) => models.Bookmark(
            id: data.id,
            chapterId: data.chapterId,
            workId: data.workId,
            position: data.position,
            selectedText: data.selectedText,
            note: data.note,
            createdAt: data.createdAt,
            color: data.color,
          ),
        )
        .toList();
  }

  Future<List<models.Bookmark>> getWorkBookmarks(String workId) async {
    final bookmarkData =
        await (_db.select(_db.bookmarks)
              ..where((tbl) => tbl.workId.equals(workId))
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
            .get();

    return bookmarkData
        .map(
          (data) => models.Bookmark(
            id: data.id,
            chapterId: data.chapterId,
            workId: data.workId,
            position: data.position,
            selectedText: data.selectedText,
            note: data.note,
            createdAt: data.createdAt,
            color: data.color,
          ),
        )
        .toList();
  }

  Future<void> deleteBookmark(String bookmarkId) async {
    await (_db.delete(
      _db.bookmarks,
    )..where((tbl) => tbl.id.equals(bookmarkId))).go();
  }

  Future<models.ReadingNote> saveNote({
    required String chapterId,
    required String workId,
    required int startPosition,
    required int endPosition,
    required String selectedText,
    required String content,
    List<String>? tags,
    String? color,
  }) async {
    final id = 'note_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final tagsJson = tags == null ? null : jsonEncode(tags);

    await _db
        .into(_db.readingNotes)
        .insert(
          ReadingNotesCompanion.insert(
            id: id,
            chapterId: chapterId,
            workId: workId,
            startPosition: startPosition,
            endPosition: endPosition,
            selectedText: selectedText,
            content: content,
            tags: Value(tagsJson),
            color: Value(color),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return models.ReadingNote(
      id: id,
      chapterId: chapterId,
      workId: workId,
      startPosition: startPosition,
      endPosition: endPosition,
      selectedText: selectedText,
      content: content,
      createdAt: now,
      updatedAt: now,
      tags: tags ?? const [],
      color: color,
    );
  }

  Future<List<models.ReadingNote>> getChapterNotes(String chapterId) async {
    final noteData =
        await (_db.select(_db.readingNotes)
              ..where((tbl) => tbl.chapterId.equals(chapterId))
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
            .get();

    return noteData.map((data) {
      final tags = data.tags == null
          ? const <String>[]
          : (jsonDecode(data.tags!) as List<dynamic>)
                .map((e) => e.toString())
                .toList();

      return models.ReadingNote(
        id: data.id,
        chapterId: data.chapterId,
        workId: data.workId,
        startPosition: data.startPosition,
        endPosition: data.endPosition,
        selectedText: data.selectedText,
        content: data.content,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
        tags: tags,
        color: data.color,
      );
    }).toList();
  }

  Future<List<models.ReadingNote>> getWorkNotes(String workId) async {
    final noteData =
        await (_db.select(_db.readingNotes)
              ..where((tbl) => tbl.workId.equals(workId))
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
            .get();

    return noteData.map(_noteToDomain).toList();
  }

  Future<void> deleteNote(String noteId) async {
    await (_db.delete(
      _db.readingNotes,
    )..where((tbl) => tbl.id.equals(noteId))).go();
  }

  Future<models.ReadingHighlight> saveHighlight({
    required String chapterId,
    required String workId,
    required int startPosition,
    required int endPosition,
    required String selectedText,
    required models.HighlightColor color,
  }) async {
    final id = 'hl_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    await _db
        .into(_db.readingHighlights)
        .insert(
          ReadingHighlightsCompanion.insert(
            id: id,
            chapterId: chapterId,
            workId: workId,
            startPosition: startPosition,
            endPosition: endPosition,
            selectedText: selectedText,
            color: color.name,
            createdAt: now,
          ),
        );

    return models.ReadingHighlight(
      id: id,
      chapterId: chapterId,
      workId: workId,
      startPosition: startPosition,
      endPosition: endPosition,
      selectedText: selectedText,
      color: color,
      createdAt: now,
    );
  }

  Future<List<models.ReadingHighlight>> getChapterHighlights(
    String chapterId,
  ) async {
    final highlightData =
        await (_db.select(_db.readingHighlights)
              ..where((tbl) => tbl.chapterId.equals(chapterId))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.startPosition)]))
            .get();

    return highlightData.map((data) {
      return _highlightToDomain(data);
    }).toList();
  }

  Future<List<models.ReadingHighlight>> getWorkHighlights(String workId) async {
    final highlightData =
        await (_db.select(_db.readingHighlights)
              ..where((tbl) => tbl.workId.equals(workId))
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
            .get();

    return highlightData.map(_highlightToDomain).toList();
  }

  Future<void> deleteHighlight(String highlightId) async {
    await (_db.delete(
      _db.readingHighlights,
    )..where((tbl) => tbl.id.equals(highlightId))).go();
  }

  Future<void> recordReadingSession({
    required String workId,
    required String chapterId,
    required DateTime startTime,
    required DateTime endTime,
    required int startPosition,
    required int endPosition,
    String? notes,
  }) async {
    final id = 'rs_${DateTime.now().millisecondsSinceEpoch}';

    await _db
        .into(_db.readingSessions)
        .insert(
          ReadingSessionsCompanion.insert(
            id: id,
            workId: workId,
            chapterId: chapterId,
            startTime: startTime,
            endTime: endTime,
            wordsRead: endPosition - startPosition,
            startPosition: startPosition,
            endPosition: endPosition,
            notes: Value(notes),
          ),
        );

    final existingProgress = await (_db.select(
      _db.readingProgressTable,
    )..where((tbl) => tbl.workId.equals(workId))).getSingleOrNull();

    if (existingProgress != null) {
      await (_db.update(
        _db.readingProgressTable,
      )..where((tbl) => tbl.workId.equals(workId))).write(
        ReadingProgressTableCompanion(
          currentChapterId: Value(chapterId),
          currentPosition: Value(endPosition),
          lastReadAt: Value(DateTime.now()),
        ),
      );
    } else {
      await _db
          .into(_db.readingProgressTable)
          .insert(
            ReadingProgressTableCompanion.insert(
              workId: workId,
              currentChapterId: chapterId,
              currentPosition: endPosition,
              progressPercentage: 0.0,
              lastReadAt: DateTime.now(),
            ),
          );
    }
  }

  Future<models.ReadingSettings> getReadingSettings() async {
    return const models.ReadingSettings();
  }

  Future<void> saveReadingSettings(models.ReadingSettings settings) async {
    return;
  }

  models.ReadingNote _noteToDomain(dynamic data) {
    final tags = data.tags == null
        ? const <String>[]
        : (jsonDecode(data.tags!) as List<dynamic>)
              .map((entry) => entry.toString())
              .toList();

    return models.ReadingNote(
      id: data.id,
      chapterId: data.chapterId,
      workId: data.workId,
      startPosition: data.startPosition,
      endPosition: data.endPosition,
      selectedText: data.selectedText,
      content: data.content,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      tags: tags,
      color: data.color,
    );
  }

  models.ReadingHighlight _highlightToDomain(dynamic data) {
    final color = models.HighlightColor.values.firstWhere(
      (entry) => entry.name == data.color,
      orElse: () => models.HighlightColor.yellow,
    );

    return models.ReadingHighlight(
      id: data.id,
      chapterId: data.chapterId,
      workId: data.workId,
      startPosition: data.startPosition,
      endPosition: data.endPosition,
      selectedText: data.selectedText,
      color: color,
      createdAt: data.createdAt,
    );
  }
}
