import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_models.freezed.dart';
part 'reading_models.g.dart';

@freezed
class ReadingProgress with _$ReadingProgress {
  const factory ReadingProgress({
    required String workId,
    required String currentChapterId,
    required int currentPosition,
    required double progressPercentage,
    required DateTime lastReadAt,
    required int totalReadingTime,
    required double averageSpeed,
    @Default([]) List<ChapterProgress> chapterProgressList,
    @Default({}) Map<String, int> bookmarks,
  }) = _ReadingProgress;

  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      _$ReadingProgressFromJson(json);
}

@freezed
class ChapterProgress with _$ChapterProgress {
  const factory ChapterProgress({
    required String chapterId,
    required String chapterTitle,
    required int totalWords,
    required int readWords,
    required bool isCompleted,
    required DateTime? completedAt,
    required DateTime lastReadAt,
    @Default(0) int readingCount,
  }) = _ChapterProgress;

  factory ChapterProgress.fromJson(Map<String, dynamic> json) =>
      _$ChapterProgressFromJson(json);
}

@freezed
class Bookmark with _$Bookmark {
  const factory Bookmark({
    required String id,
    required String chapterId,
    required String workId,
    required int position,
    required String? selectedText,
    required String? note,
    required DateTime createdAt,
    String? color,
  }) = _Bookmark;

  factory Bookmark.fromJson(Map<String, dynamic> json) =>
      _$BookmarkFromJson(json);
}

@freezed
class ReadingNote with _$ReadingNote {
  const factory ReadingNote({
    required String id,
    required String chapterId,
    required String workId,
    required int startPosition,
    required int endPosition,
    required String selectedText,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default([]) List<String> tags,
    String? color,
  }) = _ReadingNote;

  factory ReadingNote.fromJson(Map<String, dynamic> json) =>
      _$ReadingNoteFromJson(json);
}

@freezed
class ReadingHighlight with _$ReadingHighlight {
  const factory ReadingHighlight({
    required String id,
    required String chapterId,
    required String workId,
    required int startPosition,
    required int endPosition,
    required String selectedText,
    required HighlightColor color,
    required DateTime createdAt,
  }) = _ReadingHighlight;

  factory ReadingHighlight.fromJson(Map<String, dynamic> json) =>
      _$ReadingHighlightFromJson(json);
}

enum HighlightColor {
  yellow,
  green,
  blue,
  pink,
  purple,
  ;

  String get value => switch (this) {
    yellow => '#FFF59D',
    green => '#A5D6A8',
    blue => '#90CAF9',
    pink => '#F48FB1',
    purple => '#CE93D8',
  };

  String get label => switch (this) {
    yellow => '黄色',
    green => '绿色',
    blue => '蓝色',
    pink => '粉色',
    purple => '紫色',
  };
}

@freezed
class ReadingSettings with _$ReadingSettings {
  const factory ReadingSettings({
    @Default(16) double fontSize,
    @Default(1.8) double lineHeight,
    @Default('serif') String fontFamily,
    @Default(ReadingBackground.white) ReadingBackground background,
    @Default(16) double pageMargin,
    @Default(500) int wordsPerPage,
    @Default(false) bool autoScroll,
    @Default(5) double autoScrollSpeed,
    @Default(true) bool showProgressBar,
    @Default(true) bool showTime,
    @Default(ScreenOrientation.portrait) ScreenOrientation orientation,
  }) = _ReadingSettings;

  factory ReadingSettings.fromJson(Map<String, dynamic> json) =>
      _$ReadingSettingsFromJson(json);
}

enum ReadingBackground {
  white,
  sepia,
  dark,
  ;

  String get value => switch (this) {
    white => '#FFFFFF',
    sepia => '#F4ECD8',
    dark => '#1A1A1A',
  };

  String get label => switch (this) {
    white => '白色',
    sepia => '护眼',
    dark => '深色',
  };
}

enum ScreenOrientation {
  portrait,
  landscape,
  auto,
  ;

  String get label => switch (this) {
    portrait => '竖屏',
    landscape => '横屏',
    auto => '自动',
  };
}

@freezed
class ReadingSession with _$ReadingSession {
  const factory ReadingSession({
    required String id,
    required String workId,
    required String chapterId,
    required DateTime startTime,
    required DateTime endTime,
    required int wordsRead,
    required int startPosition,
    required int endPosition,
    String? notes,
  }) = _ReadingSession;

  factory ReadingSession.fromJson(Map<String, dynamic> json) =>
      _$ReadingSessionFromJson(json);
}
