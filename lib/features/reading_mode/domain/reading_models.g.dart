// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReadingProgressImpl _$$ReadingProgressImplFromJson(
        Map<String, dynamic> json) =>
    _$ReadingProgressImpl(
      workId: json['workId'] as String,
      currentChapterId: json['currentChapterId'] as String,
      currentPosition: (json['currentPosition'] as num).toInt(),
      progressPercentage: (json['progressPercentage'] as num).toDouble(),
      lastReadAt: DateTime.parse(json['lastReadAt'] as String),
      totalReadingTime: (json['totalReadingTime'] as num).toInt(),
      averageSpeed: (json['averageSpeed'] as num).toDouble(),
      chapterProgressList: (json['chapterProgressList'] as List<dynamic>?)
              ?.map((e) => ChapterProgress.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      bookmarks: (json['bookmarks'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
    );

Map<String, dynamic> _$$ReadingProgressImplToJson(
        _$ReadingProgressImpl instance) =>
    <String, dynamic>{
      'workId': instance.workId,
      'currentChapterId': instance.currentChapterId,
      'currentPosition': instance.currentPosition,
      'progressPercentage': instance.progressPercentage,
      'lastReadAt': instance.lastReadAt.toIso8601String(),
      'totalReadingTime': instance.totalReadingTime,
      'averageSpeed': instance.averageSpeed,
      'chapterProgressList': instance.chapterProgressList,
      'bookmarks': instance.bookmarks,
    };

_$ChapterProgressImpl _$$ChapterProgressImplFromJson(
        Map<String, dynamic> json) =>
    _$ChapterProgressImpl(
      chapterId: json['chapterId'] as String,
      chapterTitle: json['chapterTitle'] as String,
      totalWords: (json['totalWords'] as num).toInt(),
      readWords: (json['readWords'] as num).toInt(),
      isCompleted: json['isCompleted'] as bool,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      lastReadAt: DateTime.parse(json['lastReadAt'] as String),
      readingCount: (json['readingCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ChapterProgressImplToJson(
        _$ChapterProgressImpl instance) =>
    <String, dynamic>{
      'chapterId': instance.chapterId,
      'chapterTitle': instance.chapterTitle,
      'totalWords': instance.totalWords,
      'readWords': instance.readWords,
      'isCompleted': instance.isCompleted,
      'completedAt': instance.completedAt?.toIso8601String(),
      'lastReadAt': instance.lastReadAt.toIso8601String(),
      'readingCount': instance.readingCount,
    };

_$BookmarkImpl _$$BookmarkImplFromJson(Map<String, dynamic> json) =>
    _$BookmarkImpl(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      workId: json['workId'] as String,
      position: (json['position'] as num).toInt(),
      selectedText: json['selectedText'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      color: json['color'] as String?,
    );

Map<String, dynamic> _$$BookmarkImplToJson(_$BookmarkImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chapterId': instance.chapterId,
      'workId': instance.workId,
      'position': instance.position,
      'selectedText': instance.selectedText,
      'note': instance.note,
      'createdAt': instance.createdAt.toIso8601String(),
      'color': instance.color,
    };

_$ReadingNoteImpl _$$ReadingNoteImplFromJson(Map<String, dynamic> json) =>
    _$ReadingNoteImpl(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      workId: json['workId'] as String,
      startPosition: (json['startPosition'] as num).toInt(),
      endPosition: (json['endPosition'] as num).toInt(),
      selectedText: json['selectedText'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      color: json['color'] as String?,
    );

Map<String, dynamic> _$$ReadingNoteImplToJson(_$ReadingNoteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chapterId': instance.chapterId,
      'workId': instance.workId,
      'startPosition': instance.startPosition,
      'endPosition': instance.endPosition,
      'selectedText': instance.selectedText,
      'content': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'tags': instance.tags,
      'color': instance.color,
    };

_$ReadingHighlightImpl _$$ReadingHighlightImplFromJson(
        Map<String, dynamic> json) =>
    _$ReadingHighlightImpl(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      workId: json['workId'] as String,
      startPosition: (json['startPosition'] as num).toInt(),
      endPosition: (json['endPosition'] as num).toInt(),
      selectedText: json['selectedText'] as String,
      color: $enumDecode(_$HighlightColorEnumMap, json['color']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ReadingHighlightImplToJson(
        _$ReadingHighlightImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chapterId': instance.chapterId,
      'workId': instance.workId,
      'startPosition': instance.startPosition,
      'endPosition': instance.endPosition,
      'selectedText': instance.selectedText,
      'color': _$HighlightColorEnumMap[instance.color]!,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$HighlightColorEnumMap = {
  HighlightColor.yellow: 'yellow',
  HighlightColor.green: 'green',
  HighlightColor.blue: 'blue',
  HighlightColor.pink: 'pink',
  HighlightColor.purple: 'purple',
};

_$ReadingSettingsImpl _$$ReadingSettingsImplFromJson(
        Map<String, dynamic> json) =>
    _$ReadingSettingsImpl(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.8,
      fontFamily: json['fontFamily'] as String? ?? 'serif',
      background:
          $enumDecodeNullable(_$ReadingBackgroundEnumMap, json['background']) ??
              ReadingBackground.white,
      pageMargin: (json['pageMargin'] as num?)?.toDouble() ?? 16,
      wordsPerPage: (json['wordsPerPage'] as num?)?.toInt() ?? 500,
      autoScroll: json['autoScroll'] as bool? ?? false,
      autoScrollSpeed: (json['autoScrollSpeed'] as num?)?.toDouble() ?? 5,
      showProgressBar: json['showProgressBar'] as bool? ?? true,
      showTime: json['showTime'] as bool? ?? true,
      orientation: $enumDecodeNullable(
              _$ScreenOrientationEnumMap, json['orientation']) ??
          ScreenOrientation.portrait,
    );

Map<String, dynamic> _$$ReadingSettingsImplToJson(
        _$ReadingSettingsImpl instance) =>
    <String, dynamic>{
      'fontSize': instance.fontSize,
      'lineHeight': instance.lineHeight,
      'fontFamily': instance.fontFamily,
      'background': _$ReadingBackgroundEnumMap[instance.background]!,
      'pageMargin': instance.pageMargin,
      'wordsPerPage': instance.wordsPerPage,
      'autoScroll': instance.autoScroll,
      'autoScrollSpeed': instance.autoScrollSpeed,
      'showProgressBar': instance.showProgressBar,
      'showTime': instance.showTime,
      'orientation': _$ScreenOrientationEnumMap[instance.orientation]!,
    };

const _$ReadingBackgroundEnumMap = {
  ReadingBackground.white: 'white',
  ReadingBackground.sepia: 'sepia',
  ReadingBackground.dark: 'dark',
};

const _$ScreenOrientationEnumMap = {
  ScreenOrientation.portrait: 'portrait',
  ScreenOrientation.landscape: 'landscape',
  ScreenOrientation.auto: 'auto',
};

_$ReadingSessionImpl _$$ReadingSessionImplFromJson(Map<String, dynamic> json) =>
    _$ReadingSessionImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      chapterId: json['chapterId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      wordsRead: (json['wordsRead'] as num).toInt(),
      startPosition: (json['startPosition'] as num).toInt(),
      endPosition: (json['endPosition'] as num).toInt(),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$ReadingSessionImplToJson(
        _$ReadingSessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'chapterId': instance.chapterId,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'wordsRead': instance.wordsRead,
      'startPosition': instance.startPosition,
      'endPosition': instance.endPosition,
      'notes': instance.notes,
    };
