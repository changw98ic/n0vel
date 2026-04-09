// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ReadingProgress _$ReadingProgressFromJson(Map<String, dynamic> json) {
  return _ReadingProgress.fromJson(json);
}

/// @nodoc
mixin _$ReadingProgress {
  String get workId => throw _privateConstructorUsedError;
  String get currentChapterId => throw _privateConstructorUsedError;
  int get currentPosition => throw _privateConstructorUsedError;
  double get progressPercentage => throw _privateConstructorUsedError;
  DateTime get lastReadAt => throw _privateConstructorUsedError;
  int get totalReadingTime => throw _privateConstructorUsedError;
  double get averageSpeed => throw _privateConstructorUsedError;
  List<ChapterProgress> get chapterProgressList =>
      throw _privateConstructorUsedError;
  Map<String, int> get bookmarks => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ReadingProgressCopyWith<ReadingProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReadingProgressCopyWith<$Res> {
  factory $ReadingProgressCopyWith(
          ReadingProgress value, $Res Function(ReadingProgress) then) =
      _$ReadingProgressCopyWithImpl<$Res, ReadingProgress>;
  @useResult
  $Res call(
      {String workId,
      String currentChapterId,
      int currentPosition,
      double progressPercentage,
      DateTime lastReadAt,
      int totalReadingTime,
      double averageSpeed,
      List<ChapterProgress> chapterProgressList,
      Map<String, int> bookmarks});
}

/// @nodoc
class _$ReadingProgressCopyWithImpl<$Res, $Val extends ReadingProgress>
    implements $ReadingProgressCopyWith<$Res> {
  _$ReadingProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workId = null,
    Object? currentChapterId = null,
    Object? currentPosition = null,
    Object? progressPercentage = null,
    Object? lastReadAt = null,
    Object? totalReadingTime = null,
    Object? averageSpeed = null,
    Object? chapterProgressList = null,
    Object? bookmarks = null,
  }) {
    return _then(_value.copyWith(
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      currentChapterId: null == currentChapterId
          ? _value.currentChapterId
          : currentChapterId // ignore: cast_nullable_to_non_nullable
              as String,
      currentPosition: null == currentPosition
          ? _value.currentPosition
          : currentPosition // ignore: cast_nullable_to_non_nullable
              as int,
      progressPercentage: null == progressPercentage
          ? _value.progressPercentage
          : progressPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      lastReadAt: null == lastReadAt
          ? _value.lastReadAt
          : lastReadAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalReadingTime: null == totalReadingTime
          ? _value.totalReadingTime
          : totalReadingTime // ignore: cast_nullable_to_non_nullable
              as int,
      averageSpeed: null == averageSpeed
          ? _value.averageSpeed
          : averageSpeed // ignore: cast_nullable_to_non_nullable
              as double,
      chapterProgressList: null == chapterProgressList
          ? _value.chapterProgressList
          : chapterProgressList // ignore: cast_nullable_to_non_nullable
              as List<ChapterProgress>,
      bookmarks: null == bookmarks
          ? _value.bookmarks
          : bookmarks // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReadingProgressImplCopyWith<$Res>
    implements $ReadingProgressCopyWith<$Res> {
  factory _$$ReadingProgressImplCopyWith(_$ReadingProgressImpl value,
          $Res Function(_$ReadingProgressImpl) then) =
      __$$ReadingProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String workId,
      String currentChapterId,
      int currentPosition,
      double progressPercentage,
      DateTime lastReadAt,
      int totalReadingTime,
      double averageSpeed,
      List<ChapterProgress> chapterProgressList,
      Map<String, int> bookmarks});
}

/// @nodoc
class __$$ReadingProgressImplCopyWithImpl<$Res>
    extends _$ReadingProgressCopyWithImpl<$Res, _$ReadingProgressImpl>
    implements _$$ReadingProgressImplCopyWith<$Res> {
  __$$ReadingProgressImplCopyWithImpl(
      _$ReadingProgressImpl _value, $Res Function(_$ReadingProgressImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workId = null,
    Object? currentChapterId = null,
    Object? currentPosition = null,
    Object? progressPercentage = null,
    Object? lastReadAt = null,
    Object? totalReadingTime = null,
    Object? averageSpeed = null,
    Object? chapterProgressList = null,
    Object? bookmarks = null,
  }) {
    return _then(_$ReadingProgressImpl(
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      currentChapterId: null == currentChapterId
          ? _value.currentChapterId
          : currentChapterId // ignore: cast_nullable_to_non_nullable
              as String,
      currentPosition: null == currentPosition
          ? _value.currentPosition
          : currentPosition // ignore: cast_nullable_to_non_nullable
              as int,
      progressPercentage: null == progressPercentage
          ? _value.progressPercentage
          : progressPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      lastReadAt: null == lastReadAt
          ? _value.lastReadAt
          : lastReadAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalReadingTime: null == totalReadingTime
          ? _value.totalReadingTime
          : totalReadingTime // ignore: cast_nullable_to_non_nullable
              as int,
      averageSpeed: null == averageSpeed
          ? _value.averageSpeed
          : averageSpeed // ignore: cast_nullable_to_non_nullable
              as double,
      chapterProgressList: null == chapterProgressList
          ? _value._chapterProgressList
          : chapterProgressList // ignore: cast_nullable_to_non_nullable
              as List<ChapterProgress>,
      bookmarks: null == bookmarks
          ? _value._bookmarks
          : bookmarks // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReadingProgressImpl implements _ReadingProgress {
  const _$ReadingProgressImpl(
      {required this.workId,
      required this.currentChapterId,
      required this.currentPosition,
      required this.progressPercentage,
      required this.lastReadAt,
      required this.totalReadingTime,
      required this.averageSpeed,
      final List<ChapterProgress> chapterProgressList = const [],
      final Map<String, int> bookmarks = const {}})
      : _chapterProgressList = chapterProgressList,
        _bookmarks = bookmarks;

  factory _$ReadingProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReadingProgressImplFromJson(json);

  @override
  final String workId;
  @override
  final String currentChapterId;
  @override
  final int currentPosition;
  @override
  final double progressPercentage;
  @override
  final DateTime lastReadAt;
  @override
  final int totalReadingTime;
  @override
  final double averageSpeed;
  final List<ChapterProgress> _chapterProgressList;
  @override
  @JsonKey()
  List<ChapterProgress> get chapterProgressList {
    if (_chapterProgressList is EqualUnmodifiableListView)
      return _chapterProgressList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapterProgressList);
  }

  final Map<String, int> _bookmarks;
  @override
  @JsonKey()
  Map<String, int> get bookmarks {
    if (_bookmarks is EqualUnmodifiableMapView) return _bookmarks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_bookmarks);
  }

  @override
  String toString() {
    return 'ReadingProgress(workId: $workId, currentChapterId: $currentChapterId, currentPosition: $currentPosition, progressPercentage: $progressPercentage, lastReadAt: $lastReadAt, totalReadingTime: $totalReadingTime, averageSpeed: $averageSpeed, chapterProgressList: $chapterProgressList, bookmarks: $bookmarks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadingProgressImpl &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.currentChapterId, currentChapterId) ||
                other.currentChapterId == currentChapterId) &&
            (identical(other.currentPosition, currentPosition) ||
                other.currentPosition == currentPosition) &&
            (identical(other.progressPercentage, progressPercentage) ||
                other.progressPercentage == progressPercentage) &&
            (identical(other.lastReadAt, lastReadAt) ||
                other.lastReadAt == lastReadAt) &&
            (identical(other.totalReadingTime, totalReadingTime) ||
                other.totalReadingTime == totalReadingTime) &&
            (identical(other.averageSpeed, averageSpeed) ||
                other.averageSpeed == averageSpeed) &&
            const DeepCollectionEquality()
                .equals(other._chapterProgressList, _chapterProgressList) &&
            const DeepCollectionEquality()
                .equals(other._bookmarks, _bookmarks));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      workId,
      currentChapterId,
      currentPosition,
      progressPercentage,
      lastReadAt,
      totalReadingTime,
      averageSpeed,
      const DeepCollectionEquality().hash(_chapterProgressList),
      const DeepCollectionEquality().hash(_bookmarks));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadingProgressImplCopyWith<_$ReadingProgressImpl> get copyWith =>
      __$$ReadingProgressImplCopyWithImpl<_$ReadingProgressImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReadingProgressImplToJson(
      this,
    );
  }
}

abstract class _ReadingProgress implements ReadingProgress {
  const factory _ReadingProgress(
      {required final String workId,
      required final String currentChapterId,
      required final int currentPosition,
      required final double progressPercentage,
      required final DateTime lastReadAt,
      required final int totalReadingTime,
      required final double averageSpeed,
      final List<ChapterProgress> chapterProgressList,
      final Map<String, int> bookmarks}) = _$ReadingProgressImpl;

  factory _ReadingProgress.fromJson(Map<String, dynamic> json) =
      _$ReadingProgressImpl.fromJson;

  @override
  String get workId;
  @override
  String get currentChapterId;
  @override
  int get currentPosition;
  @override
  double get progressPercentage;
  @override
  DateTime get lastReadAt;
  @override
  int get totalReadingTime;
  @override
  double get averageSpeed;
  @override
  List<ChapterProgress> get chapterProgressList;
  @override
  Map<String, int> get bookmarks;
  @override
  @JsonKey(ignore: true)
  _$$ReadingProgressImplCopyWith<_$ReadingProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChapterProgress _$ChapterProgressFromJson(Map<String, dynamic> json) {
  return _ChapterProgress.fromJson(json);
}

/// @nodoc
mixin _$ChapterProgress {
  String get chapterId => throw _privateConstructorUsedError;
  String get chapterTitle => throw _privateConstructorUsedError;
  int get totalWords => throw _privateConstructorUsedError;
  int get readWords => throw _privateConstructorUsedError;
  bool get isCompleted => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  DateTime get lastReadAt => throw _privateConstructorUsedError;
  int get readingCount => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChapterProgressCopyWith<ChapterProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChapterProgressCopyWith<$Res> {
  factory $ChapterProgressCopyWith(
          ChapterProgress value, $Res Function(ChapterProgress) then) =
      _$ChapterProgressCopyWithImpl<$Res, ChapterProgress>;
  @useResult
  $Res call(
      {String chapterId,
      String chapterTitle,
      int totalWords,
      int readWords,
      bool isCompleted,
      DateTime? completedAt,
      DateTime lastReadAt,
      int readingCount});
}

/// @nodoc
class _$ChapterProgressCopyWithImpl<$Res, $Val extends ChapterProgress>
    implements $ChapterProgressCopyWith<$Res> {
  _$ChapterProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? chapterTitle = null,
    Object? totalWords = null,
    Object? readWords = null,
    Object? isCompleted = null,
    Object? completedAt = freezed,
    Object? lastReadAt = null,
    Object? readingCount = null,
  }) {
    return _then(_value.copyWith(
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      chapterTitle: null == chapterTitle
          ? _value.chapterTitle
          : chapterTitle // ignore: cast_nullable_to_non_nullable
              as String,
      totalWords: null == totalWords
          ? _value.totalWords
          : totalWords // ignore: cast_nullable_to_non_nullable
              as int,
      readWords: null == readWords
          ? _value.readWords
          : readWords // ignore: cast_nullable_to_non_nullable
              as int,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastReadAt: null == lastReadAt
          ? _value.lastReadAt
          : lastReadAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      readingCount: null == readingCount
          ? _value.readingCount
          : readingCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChapterProgressImplCopyWith<$Res>
    implements $ChapterProgressCopyWith<$Res> {
  factory _$$ChapterProgressImplCopyWith(_$ChapterProgressImpl value,
          $Res Function(_$ChapterProgressImpl) then) =
      __$$ChapterProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String chapterId,
      String chapterTitle,
      int totalWords,
      int readWords,
      bool isCompleted,
      DateTime? completedAt,
      DateTime lastReadAt,
      int readingCount});
}

/// @nodoc
class __$$ChapterProgressImplCopyWithImpl<$Res>
    extends _$ChapterProgressCopyWithImpl<$Res, _$ChapterProgressImpl>
    implements _$$ChapterProgressImplCopyWith<$Res> {
  __$$ChapterProgressImplCopyWithImpl(
      _$ChapterProgressImpl _value, $Res Function(_$ChapterProgressImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? chapterTitle = null,
    Object? totalWords = null,
    Object? readWords = null,
    Object? isCompleted = null,
    Object? completedAt = freezed,
    Object? lastReadAt = null,
    Object? readingCount = null,
  }) {
    return _then(_$ChapterProgressImpl(
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      chapterTitle: null == chapterTitle
          ? _value.chapterTitle
          : chapterTitle // ignore: cast_nullable_to_non_nullable
              as String,
      totalWords: null == totalWords
          ? _value.totalWords
          : totalWords // ignore: cast_nullable_to_non_nullable
              as int,
      readWords: null == readWords
          ? _value.readWords
          : readWords // ignore: cast_nullable_to_non_nullable
              as int,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastReadAt: null == lastReadAt
          ? _value.lastReadAt
          : lastReadAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      readingCount: null == readingCount
          ? _value.readingCount
          : readingCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChapterProgressImpl implements _ChapterProgress {
  const _$ChapterProgressImpl(
      {required this.chapterId,
      required this.chapterTitle,
      required this.totalWords,
      required this.readWords,
      required this.isCompleted,
      required this.completedAt,
      required this.lastReadAt,
      this.readingCount = 0});

  factory _$ChapterProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChapterProgressImplFromJson(json);

  @override
  final String chapterId;
  @override
  final String chapterTitle;
  @override
  final int totalWords;
  @override
  final int readWords;
  @override
  final bool isCompleted;
  @override
  final DateTime? completedAt;
  @override
  final DateTime lastReadAt;
  @override
  @JsonKey()
  final int readingCount;

  @override
  String toString() {
    return 'ChapterProgress(chapterId: $chapterId, chapterTitle: $chapterTitle, totalWords: $totalWords, readWords: $readWords, isCompleted: $isCompleted, completedAt: $completedAt, lastReadAt: $lastReadAt, readingCount: $readingCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChapterProgressImpl &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.chapterTitle, chapterTitle) ||
                other.chapterTitle == chapterTitle) &&
            (identical(other.totalWords, totalWords) ||
                other.totalWords == totalWords) &&
            (identical(other.readWords, readWords) ||
                other.readWords == readWords) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.lastReadAt, lastReadAt) ||
                other.lastReadAt == lastReadAt) &&
            (identical(other.readingCount, readingCount) ||
                other.readingCount == readingCount));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      chapterId,
      chapterTitle,
      totalWords,
      readWords,
      isCompleted,
      completedAt,
      lastReadAt,
      readingCount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChapterProgressImplCopyWith<_$ChapterProgressImpl> get copyWith =>
      __$$ChapterProgressImplCopyWithImpl<_$ChapterProgressImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChapterProgressImplToJson(
      this,
    );
  }
}

abstract class _ChapterProgress implements ChapterProgress {
  const factory _ChapterProgress(
      {required final String chapterId,
      required final String chapterTitle,
      required final int totalWords,
      required final int readWords,
      required final bool isCompleted,
      required final DateTime? completedAt,
      required final DateTime lastReadAt,
      final int readingCount}) = _$ChapterProgressImpl;

  factory _ChapterProgress.fromJson(Map<String, dynamic> json) =
      _$ChapterProgressImpl.fromJson;

  @override
  String get chapterId;
  @override
  String get chapterTitle;
  @override
  int get totalWords;
  @override
  int get readWords;
  @override
  bool get isCompleted;
  @override
  DateTime? get completedAt;
  @override
  DateTime get lastReadAt;
  @override
  int get readingCount;
  @override
  @JsonKey(ignore: true)
  _$$ChapterProgressImplCopyWith<_$ChapterProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Bookmark _$BookmarkFromJson(Map<String, dynamic> json) {
  return _Bookmark.fromJson(json);
}

/// @nodoc
mixin _$Bookmark {
  String get id => throw _privateConstructorUsedError;
  String get chapterId => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  int get position => throw _privateConstructorUsedError;
  String? get selectedText => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String? get color => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BookmarkCopyWith<Bookmark> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BookmarkCopyWith<$Res> {
  factory $BookmarkCopyWith(Bookmark value, $Res Function(Bookmark) then) =
      _$BookmarkCopyWithImpl<$Res, Bookmark>;
  @useResult
  $Res call(
      {String id,
      String chapterId,
      String workId,
      int position,
      String? selectedText,
      String? note,
      DateTime createdAt,
      String? color});
}

/// @nodoc
class _$BookmarkCopyWithImpl<$Res, $Val extends Bookmark>
    implements $BookmarkCopyWith<$Res> {
  _$BookmarkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chapterId = null,
    Object? workId = null,
    Object? position = null,
    Object? selectedText = freezed,
    Object? note = freezed,
    Object? createdAt = null,
    Object? color = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      selectedText: freezed == selectedText
          ? _value.selectedText
          : selectedText // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      color: freezed == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BookmarkImplCopyWith<$Res>
    implements $BookmarkCopyWith<$Res> {
  factory _$$BookmarkImplCopyWith(
          _$BookmarkImpl value, $Res Function(_$BookmarkImpl) then) =
      __$$BookmarkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String chapterId,
      String workId,
      int position,
      String? selectedText,
      String? note,
      DateTime createdAt,
      String? color});
}

/// @nodoc
class __$$BookmarkImplCopyWithImpl<$Res>
    extends _$BookmarkCopyWithImpl<$Res, _$BookmarkImpl>
    implements _$$BookmarkImplCopyWith<$Res> {
  __$$BookmarkImplCopyWithImpl(
      _$BookmarkImpl _value, $Res Function(_$BookmarkImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chapterId = null,
    Object? workId = null,
    Object? position = null,
    Object? selectedText = freezed,
    Object? note = freezed,
    Object? createdAt = null,
    Object? color = freezed,
  }) {
    return _then(_$BookmarkImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      selectedText: freezed == selectedText
          ? _value.selectedText
          : selectedText // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      color: freezed == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BookmarkImpl implements _Bookmark {
  const _$BookmarkImpl(
      {required this.id,
      required this.chapterId,
      required this.workId,
      required this.position,
      required this.selectedText,
      required this.note,
      required this.createdAt,
      this.color});

  factory _$BookmarkImpl.fromJson(Map<String, dynamic> json) =>
      _$$BookmarkImplFromJson(json);

  @override
  final String id;
  @override
  final String chapterId;
  @override
  final String workId;
  @override
  final int position;
  @override
  final String? selectedText;
  @override
  final String? note;
  @override
  final DateTime createdAt;
  @override
  final String? color;

  @override
  String toString() {
    return 'Bookmark(id: $id, chapterId: $chapterId, workId: $workId, position: $position, selectedText: $selectedText, note: $note, createdAt: $createdAt, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BookmarkImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.selectedText, selectedText) ||
                other.selectedText == selectedText) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, chapterId, workId, position,
      selectedText, note, createdAt, color);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BookmarkImplCopyWith<_$BookmarkImpl> get copyWith =>
      __$$BookmarkImplCopyWithImpl<_$BookmarkImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BookmarkImplToJson(
      this,
    );
  }
}

abstract class _Bookmark implements Bookmark {
  const factory _Bookmark(
      {required final String id,
      required final String chapterId,
      required final String workId,
      required final int position,
      required final String? selectedText,
      required final String? note,
      required final DateTime createdAt,
      final String? color}) = _$BookmarkImpl;

  factory _Bookmark.fromJson(Map<String, dynamic> json) =
      _$BookmarkImpl.fromJson;

  @override
  String get id;
  @override
  String get chapterId;
  @override
  String get workId;
  @override
  int get position;
  @override
  String? get selectedText;
  @override
  String? get note;
  @override
  DateTime get createdAt;
  @override
  String? get color;
  @override
  @JsonKey(ignore: true)
  _$$BookmarkImplCopyWith<_$BookmarkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ReadingNote _$ReadingNoteFromJson(Map<String, dynamic> json) {
  return _ReadingNote.fromJson(json);
}

/// @nodoc
mixin _$ReadingNote {
  String get id => throw _privateConstructorUsedError;
  String get chapterId => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  int get startPosition => throw _privateConstructorUsedError;
  int get endPosition => throw _privateConstructorUsedError;
  String get selectedText => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  String? get color => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ReadingNoteCopyWith<ReadingNote> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReadingNoteCopyWith<$Res> {
  factory $ReadingNoteCopyWith(
          ReadingNote value, $Res Function(ReadingNote) then) =
      _$ReadingNoteCopyWithImpl<$Res, ReadingNote>;
  @useResult
  $Res call(
      {String id,
      String chapterId,
      String workId,
      int startPosition,
      int endPosition,
      String selectedText,
      String content,
      DateTime createdAt,
      DateTime updatedAt,
      List<String> tags,
      String? color});
}

/// @nodoc
class _$ReadingNoteCopyWithImpl<$Res, $Val extends ReadingNote>
    implements $ReadingNoteCopyWith<$Res> {
  _$ReadingNoteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chapterId = null,
    Object? workId = null,
    Object? startPosition = null,
    Object? endPosition = null,
    Object? selectedText = null,
    Object? content = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? tags = null,
    Object? color = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      startPosition: null == startPosition
          ? _value.startPosition
          : startPosition // ignore: cast_nullable_to_non_nullable
              as int,
      endPosition: null == endPosition
          ? _value.endPosition
          : endPosition // ignore: cast_nullable_to_non_nullable
              as int,
      selectedText: null == selectedText
          ? _value.selectedText
          : selectedText // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      color: freezed == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReadingNoteImplCopyWith<$Res>
    implements $ReadingNoteCopyWith<$Res> {
  factory _$$ReadingNoteImplCopyWith(
          _$ReadingNoteImpl value, $Res Function(_$ReadingNoteImpl) then) =
      __$$ReadingNoteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String chapterId,
      String workId,
      int startPosition,
      int endPosition,
      String selectedText,
      String content,
      DateTime createdAt,
      DateTime updatedAt,
      List<String> tags,
      String? color});
}

/// @nodoc
class __$$ReadingNoteImplCopyWithImpl<$Res>
    extends _$ReadingNoteCopyWithImpl<$Res, _$ReadingNoteImpl>
    implements _$$ReadingNoteImplCopyWith<$Res> {
  __$$ReadingNoteImplCopyWithImpl(
      _$ReadingNoteImpl _value, $Res Function(_$ReadingNoteImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chapterId = null,
    Object? workId = null,
    Object? startPosition = null,
    Object? endPosition = null,
    Object? selectedText = null,
    Object? content = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? tags = null,
    Object? color = freezed,
  }) {
    return _then(_$ReadingNoteImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      startPosition: null == startPosition
          ? _value.startPosition
          : startPosition // ignore: cast_nullable_to_non_nullable
              as int,
      endPosition: null == endPosition
          ? _value.endPosition
          : endPosition // ignore: cast_nullable_to_non_nullable
              as int,
      selectedText: null == selectedText
          ? _value.selectedText
          : selectedText // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      color: freezed == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReadingNoteImpl implements _ReadingNote {
  const _$ReadingNoteImpl(
      {required this.id,
      required this.chapterId,
      required this.workId,
      required this.startPosition,
      required this.endPosition,
      required this.selectedText,
      required this.content,
      required this.createdAt,
      required this.updatedAt,
      final List<String> tags = const [],
      this.color})
      : _tags = tags;

  factory _$ReadingNoteImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReadingNoteImplFromJson(json);

  @override
  final String id;
  @override
  final String chapterId;
  @override
  final String workId;
  @override
  final int startPosition;
  @override
  final int endPosition;
  @override
  final String selectedText;
  @override
  final String content;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  final String? color;

  @override
  String toString() {
    return 'ReadingNote(id: $id, chapterId: $chapterId, workId: $workId, startPosition: $startPosition, endPosition: $endPosition, selectedText: $selectedText, content: $content, createdAt: $createdAt, updatedAt: $updatedAt, tags: $tags, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadingNoteImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.startPosition, startPosition) ||
                other.startPosition == startPosition) &&
            (identical(other.endPosition, endPosition) ||
                other.endPosition == endPosition) &&
            (identical(other.selectedText, selectedText) ||
                other.selectedText == selectedText) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      chapterId,
      workId,
      startPosition,
      endPosition,
      selectedText,
      content,
      createdAt,
      updatedAt,
      const DeepCollectionEquality().hash(_tags),
      color);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadingNoteImplCopyWith<_$ReadingNoteImpl> get copyWith =>
      __$$ReadingNoteImplCopyWithImpl<_$ReadingNoteImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReadingNoteImplToJson(
      this,
    );
  }
}

abstract class _ReadingNote implements ReadingNote {
  const factory _ReadingNote(
      {required final String id,
      required final String chapterId,
      required final String workId,
      required final int startPosition,
      required final int endPosition,
      required final String selectedText,
      required final String content,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      final List<String> tags,
      final String? color}) = _$ReadingNoteImpl;

  factory _ReadingNote.fromJson(Map<String, dynamic> json) =
      _$ReadingNoteImpl.fromJson;

  @override
  String get id;
  @override
  String get chapterId;
  @override
  String get workId;
  @override
  int get startPosition;
  @override
  int get endPosition;
  @override
  String get selectedText;
  @override
  String get content;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  List<String> get tags;
  @override
  String? get color;
  @override
  @JsonKey(ignore: true)
  _$$ReadingNoteImplCopyWith<_$ReadingNoteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ReadingHighlight _$ReadingHighlightFromJson(Map<String, dynamic> json) {
  return _ReadingHighlight.fromJson(json);
}

/// @nodoc
mixin _$ReadingHighlight {
  String get id => throw _privateConstructorUsedError;
  String get chapterId => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  int get startPosition => throw _privateConstructorUsedError;
  int get endPosition => throw _privateConstructorUsedError;
  String get selectedText => throw _privateConstructorUsedError;
  HighlightColor get color => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ReadingHighlightCopyWith<ReadingHighlight> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReadingHighlightCopyWith<$Res> {
  factory $ReadingHighlightCopyWith(
          ReadingHighlight value, $Res Function(ReadingHighlight) then) =
      _$ReadingHighlightCopyWithImpl<$Res, ReadingHighlight>;
  @useResult
  $Res call(
      {String id,
      String chapterId,
      String workId,
      int startPosition,
      int endPosition,
      String selectedText,
      HighlightColor color,
      DateTime createdAt});
}

/// @nodoc
class _$ReadingHighlightCopyWithImpl<$Res, $Val extends ReadingHighlight>
    implements $ReadingHighlightCopyWith<$Res> {
  _$ReadingHighlightCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chapterId = null,
    Object? workId = null,
    Object? startPosition = null,
    Object? endPosition = null,
    Object? selectedText = null,
    Object? color = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      startPosition: null == startPosition
          ? _value.startPosition
          : startPosition // ignore: cast_nullable_to_non_nullable
              as int,
      endPosition: null == endPosition
          ? _value.endPosition
          : endPosition // ignore: cast_nullable_to_non_nullable
              as int,
      selectedText: null == selectedText
          ? _value.selectedText
          : selectedText // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as HighlightColor,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReadingHighlightImplCopyWith<$Res>
    implements $ReadingHighlightCopyWith<$Res> {
  factory _$$ReadingHighlightImplCopyWith(_$ReadingHighlightImpl value,
          $Res Function(_$ReadingHighlightImpl) then) =
      __$$ReadingHighlightImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String chapterId,
      String workId,
      int startPosition,
      int endPosition,
      String selectedText,
      HighlightColor color,
      DateTime createdAt});
}

/// @nodoc
class __$$ReadingHighlightImplCopyWithImpl<$Res>
    extends _$ReadingHighlightCopyWithImpl<$Res, _$ReadingHighlightImpl>
    implements _$$ReadingHighlightImplCopyWith<$Res> {
  __$$ReadingHighlightImplCopyWithImpl(_$ReadingHighlightImpl _value,
      $Res Function(_$ReadingHighlightImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chapterId = null,
    Object? workId = null,
    Object? startPosition = null,
    Object? endPosition = null,
    Object? selectedText = null,
    Object? color = null,
    Object? createdAt = null,
  }) {
    return _then(_$ReadingHighlightImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      startPosition: null == startPosition
          ? _value.startPosition
          : startPosition // ignore: cast_nullable_to_non_nullable
              as int,
      endPosition: null == endPosition
          ? _value.endPosition
          : endPosition // ignore: cast_nullable_to_non_nullable
              as int,
      selectedText: null == selectedText
          ? _value.selectedText
          : selectedText // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as HighlightColor,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReadingHighlightImpl implements _ReadingHighlight {
  const _$ReadingHighlightImpl(
      {required this.id,
      required this.chapterId,
      required this.workId,
      required this.startPosition,
      required this.endPosition,
      required this.selectedText,
      required this.color,
      required this.createdAt});

  factory _$ReadingHighlightImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReadingHighlightImplFromJson(json);

  @override
  final String id;
  @override
  final String chapterId;
  @override
  final String workId;
  @override
  final int startPosition;
  @override
  final int endPosition;
  @override
  final String selectedText;
  @override
  final HighlightColor color;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'ReadingHighlight(id: $id, chapterId: $chapterId, workId: $workId, startPosition: $startPosition, endPosition: $endPosition, selectedText: $selectedText, color: $color, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadingHighlightImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.startPosition, startPosition) ||
                other.startPosition == startPosition) &&
            (identical(other.endPosition, endPosition) ||
                other.endPosition == endPosition) &&
            (identical(other.selectedText, selectedText) ||
                other.selectedText == selectedText) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, chapterId, workId,
      startPosition, endPosition, selectedText, color, createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadingHighlightImplCopyWith<_$ReadingHighlightImpl> get copyWith =>
      __$$ReadingHighlightImplCopyWithImpl<_$ReadingHighlightImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReadingHighlightImplToJson(
      this,
    );
  }
}

abstract class _ReadingHighlight implements ReadingHighlight {
  const factory _ReadingHighlight(
      {required final String id,
      required final String chapterId,
      required final String workId,
      required final int startPosition,
      required final int endPosition,
      required final String selectedText,
      required final HighlightColor color,
      required final DateTime createdAt}) = _$ReadingHighlightImpl;

  factory _ReadingHighlight.fromJson(Map<String, dynamic> json) =
      _$ReadingHighlightImpl.fromJson;

  @override
  String get id;
  @override
  String get chapterId;
  @override
  String get workId;
  @override
  int get startPosition;
  @override
  int get endPosition;
  @override
  String get selectedText;
  @override
  HighlightColor get color;
  @override
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$ReadingHighlightImplCopyWith<_$ReadingHighlightImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ReadingSettings _$ReadingSettingsFromJson(Map<String, dynamic> json) {
  return _ReadingSettings.fromJson(json);
}

/// @nodoc
mixin _$ReadingSettings {
  double get fontSize => throw _privateConstructorUsedError;
  double get lineHeight => throw _privateConstructorUsedError;
  String get fontFamily => throw _privateConstructorUsedError;
  ReadingBackground get background => throw _privateConstructorUsedError;
  double get pageMargin => throw _privateConstructorUsedError;
  int get wordsPerPage => throw _privateConstructorUsedError;
  bool get autoScroll => throw _privateConstructorUsedError;
  double get autoScrollSpeed => throw _privateConstructorUsedError;
  bool get showProgressBar => throw _privateConstructorUsedError;
  bool get showTime => throw _privateConstructorUsedError;
  ScreenOrientation get orientation => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ReadingSettingsCopyWith<ReadingSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReadingSettingsCopyWith<$Res> {
  factory $ReadingSettingsCopyWith(
          ReadingSettings value, $Res Function(ReadingSettings) then) =
      _$ReadingSettingsCopyWithImpl<$Res, ReadingSettings>;
  @useResult
  $Res call(
      {double fontSize,
      double lineHeight,
      String fontFamily,
      ReadingBackground background,
      double pageMargin,
      int wordsPerPage,
      bool autoScroll,
      double autoScrollSpeed,
      bool showProgressBar,
      bool showTime,
      ScreenOrientation orientation});
}

/// @nodoc
class _$ReadingSettingsCopyWithImpl<$Res, $Val extends ReadingSettings>
    implements $ReadingSettingsCopyWith<$Res> {
  _$ReadingSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fontSize = null,
    Object? lineHeight = null,
    Object? fontFamily = null,
    Object? background = null,
    Object? pageMargin = null,
    Object? wordsPerPage = null,
    Object? autoScroll = null,
    Object? autoScrollSpeed = null,
    Object? showProgressBar = null,
    Object? showTime = null,
    Object? orientation = null,
  }) {
    return _then(_value.copyWith(
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as double,
      lineHeight: null == lineHeight
          ? _value.lineHeight
          : lineHeight // ignore: cast_nullable_to_non_nullable
              as double,
      fontFamily: null == fontFamily
          ? _value.fontFamily
          : fontFamily // ignore: cast_nullable_to_non_nullable
              as String,
      background: null == background
          ? _value.background
          : background // ignore: cast_nullable_to_non_nullable
              as ReadingBackground,
      pageMargin: null == pageMargin
          ? _value.pageMargin
          : pageMargin // ignore: cast_nullable_to_non_nullable
              as double,
      wordsPerPage: null == wordsPerPage
          ? _value.wordsPerPage
          : wordsPerPage // ignore: cast_nullable_to_non_nullable
              as int,
      autoScroll: null == autoScroll
          ? _value.autoScroll
          : autoScroll // ignore: cast_nullable_to_non_nullable
              as bool,
      autoScrollSpeed: null == autoScrollSpeed
          ? _value.autoScrollSpeed
          : autoScrollSpeed // ignore: cast_nullable_to_non_nullable
              as double,
      showProgressBar: null == showProgressBar
          ? _value.showProgressBar
          : showProgressBar // ignore: cast_nullable_to_non_nullable
              as bool,
      showTime: null == showTime
          ? _value.showTime
          : showTime // ignore: cast_nullable_to_non_nullable
              as bool,
      orientation: null == orientation
          ? _value.orientation
          : orientation // ignore: cast_nullable_to_non_nullable
              as ScreenOrientation,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReadingSettingsImplCopyWith<$Res>
    implements $ReadingSettingsCopyWith<$Res> {
  factory _$$ReadingSettingsImplCopyWith(_$ReadingSettingsImpl value,
          $Res Function(_$ReadingSettingsImpl) then) =
      __$$ReadingSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double fontSize,
      double lineHeight,
      String fontFamily,
      ReadingBackground background,
      double pageMargin,
      int wordsPerPage,
      bool autoScroll,
      double autoScrollSpeed,
      bool showProgressBar,
      bool showTime,
      ScreenOrientation orientation});
}

/// @nodoc
class __$$ReadingSettingsImplCopyWithImpl<$Res>
    extends _$ReadingSettingsCopyWithImpl<$Res, _$ReadingSettingsImpl>
    implements _$$ReadingSettingsImplCopyWith<$Res> {
  __$$ReadingSettingsImplCopyWithImpl(
      _$ReadingSettingsImpl _value, $Res Function(_$ReadingSettingsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fontSize = null,
    Object? lineHeight = null,
    Object? fontFamily = null,
    Object? background = null,
    Object? pageMargin = null,
    Object? wordsPerPage = null,
    Object? autoScroll = null,
    Object? autoScrollSpeed = null,
    Object? showProgressBar = null,
    Object? showTime = null,
    Object? orientation = null,
  }) {
    return _then(_$ReadingSettingsImpl(
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as double,
      lineHeight: null == lineHeight
          ? _value.lineHeight
          : lineHeight // ignore: cast_nullable_to_non_nullable
              as double,
      fontFamily: null == fontFamily
          ? _value.fontFamily
          : fontFamily // ignore: cast_nullable_to_non_nullable
              as String,
      background: null == background
          ? _value.background
          : background // ignore: cast_nullable_to_non_nullable
              as ReadingBackground,
      pageMargin: null == pageMargin
          ? _value.pageMargin
          : pageMargin // ignore: cast_nullable_to_non_nullable
              as double,
      wordsPerPage: null == wordsPerPage
          ? _value.wordsPerPage
          : wordsPerPage // ignore: cast_nullable_to_non_nullable
              as int,
      autoScroll: null == autoScroll
          ? _value.autoScroll
          : autoScroll // ignore: cast_nullable_to_non_nullable
              as bool,
      autoScrollSpeed: null == autoScrollSpeed
          ? _value.autoScrollSpeed
          : autoScrollSpeed // ignore: cast_nullable_to_non_nullable
              as double,
      showProgressBar: null == showProgressBar
          ? _value.showProgressBar
          : showProgressBar // ignore: cast_nullable_to_non_nullable
              as bool,
      showTime: null == showTime
          ? _value.showTime
          : showTime // ignore: cast_nullable_to_non_nullable
              as bool,
      orientation: null == orientation
          ? _value.orientation
          : orientation // ignore: cast_nullable_to_non_nullable
              as ScreenOrientation,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReadingSettingsImpl implements _ReadingSettings {
  const _$ReadingSettingsImpl(
      {this.fontSize = 16,
      this.lineHeight = 1.8,
      this.fontFamily = 'serif',
      this.background = ReadingBackground.white,
      this.pageMargin = 16,
      this.wordsPerPage = 500,
      this.autoScroll = false,
      this.autoScrollSpeed = 5,
      this.showProgressBar = true,
      this.showTime = true,
      this.orientation = ScreenOrientation.portrait});

  factory _$ReadingSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReadingSettingsImplFromJson(json);

  @override
  @JsonKey()
  final double fontSize;
  @override
  @JsonKey()
  final double lineHeight;
  @override
  @JsonKey()
  final String fontFamily;
  @override
  @JsonKey()
  final ReadingBackground background;
  @override
  @JsonKey()
  final double pageMargin;
  @override
  @JsonKey()
  final int wordsPerPage;
  @override
  @JsonKey()
  final bool autoScroll;
  @override
  @JsonKey()
  final double autoScrollSpeed;
  @override
  @JsonKey()
  final bool showProgressBar;
  @override
  @JsonKey()
  final bool showTime;
  @override
  @JsonKey()
  final ScreenOrientation orientation;

  @override
  String toString() {
    return 'ReadingSettings(fontSize: $fontSize, lineHeight: $lineHeight, fontFamily: $fontFamily, background: $background, pageMargin: $pageMargin, wordsPerPage: $wordsPerPage, autoScroll: $autoScroll, autoScrollSpeed: $autoScrollSpeed, showProgressBar: $showProgressBar, showTime: $showTime, orientation: $orientation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadingSettingsImpl &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.lineHeight, lineHeight) ||
                other.lineHeight == lineHeight) &&
            (identical(other.fontFamily, fontFamily) ||
                other.fontFamily == fontFamily) &&
            (identical(other.background, background) ||
                other.background == background) &&
            (identical(other.pageMargin, pageMargin) ||
                other.pageMargin == pageMargin) &&
            (identical(other.wordsPerPage, wordsPerPage) ||
                other.wordsPerPage == wordsPerPage) &&
            (identical(other.autoScroll, autoScroll) ||
                other.autoScroll == autoScroll) &&
            (identical(other.autoScrollSpeed, autoScrollSpeed) ||
                other.autoScrollSpeed == autoScrollSpeed) &&
            (identical(other.showProgressBar, showProgressBar) ||
                other.showProgressBar == showProgressBar) &&
            (identical(other.showTime, showTime) ||
                other.showTime == showTime) &&
            (identical(other.orientation, orientation) ||
                other.orientation == orientation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      fontSize,
      lineHeight,
      fontFamily,
      background,
      pageMargin,
      wordsPerPage,
      autoScroll,
      autoScrollSpeed,
      showProgressBar,
      showTime,
      orientation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadingSettingsImplCopyWith<_$ReadingSettingsImpl> get copyWith =>
      __$$ReadingSettingsImplCopyWithImpl<_$ReadingSettingsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReadingSettingsImplToJson(
      this,
    );
  }
}

abstract class _ReadingSettings implements ReadingSettings {
  const factory _ReadingSettings(
      {final double fontSize,
      final double lineHeight,
      final String fontFamily,
      final ReadingBackground background,
      final double pageMargin,
      final int wordsPerPage,
      final bool autoScroll,
      final double autoScrollSpeed,
      final bool showProgressBar,
      final bool showTime,
      final ScreenOrientation orientation}) = _$ReadingSettingsImpl;

  factory _ReadingSettings.fromJson(Map<String, dynamic> json) =
      _$ReadingSettingsImpl.fromJson;

  @override
  double get fontSize;
  @override
  double get lineHeight;
  @override
  String get fontFamily;
  @override
  ReadingBackground get background;
  @override
  double get pageMargin;
  @override
  int get wordsPerPage;
  @override
  bool get autoScroll;
  @override
  double get autoScrollSpeed;
  @override
  bool get showProgressBar;
  @override
  bool get showTime;
  @override
  ScreenOrientation get orientation;
  @override
  @JsonKey(ignore: true)
  _$$ReadingSettingsImplCopyWith<_$ReadingSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ReadingSession _$ReadingSessionFromJson(Map<String, dynamic> json) {
  return _ReadingSession.fromJson(json);
}

/// @nodoc
mixin _$ReadingSession {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get chapterId => throw _privateConstructorUsedError;
  DateTime get startTime => throw _privateConstructorUsedError;
  DateTime get endTime => throw _privateConstructorUsedError;
  int get wordsRead => throw _privateConstructorUsedError;
  int get startPosition => throw _privateConstructorUsedError;
  int get endPosition => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ReadingSessionCopyWith<ReadingSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReadingSessionCopyWith<$Res> {
  factory $ReadingSessionCopyWith(
          ReadingSession value, $Res Function(ReadingSession) then) =
      _$ReadingSessionCopyWithImpl<$Res, ReadingSession>;
  @useResult
  $Res call(
      {String id,
      String workId,
      String chapterId,
      DateTime startTime,
      DateTime endTime,
      int wordsRead,
      int startPosition,
      int endPosition,
      String? notes});
}

/// @nodoc
class _$ReadingSessionCopyWithImpl<$Res, $Val extends ReadingSession>
    implements $ReadingSessionCopyWith<$Res> {
  _$ReadingSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? chapterId = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? wordsRead = null,
    Object? startPosition = null,
    Object? endPosition = null,
    Object? notes = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      wordsRead: null == wordsRead
          ? _value.wordsRead
          : wordsRead // ignore: cast_nullable_to_non_nullable
              as int,
      startPosition: null == startPosition
          ? _value.startPosition
          : startPosition // ignore: cast_nullable_to_non_nullable
              as int,
      endPosition: null == endPosition
          ? _value.endPosition
          : endPosition // ignore: cast_nullable_to_non_nullable
              as int,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReadingSessionImplCopyWith<$Res>
    implements $ReadingSessionCopyWith<$Res> {
  factory _$$ReadingSessionImplCopyWith(_$ReadingSessionImpl value,
          $Res Function(_$ReadingSessionImpl) then) =
      __$$ReadingSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String workId,
      String chapterId,
      DateTime startTime,
      DateTime endTime,
      int wordsRead,
      int startPosition,
      int endPosition,
      String? notes});
}

/// @nodoc
class __$$ReadingSessionImplCopyWithImpl<$Res>
    extends _$ReadingSessionCopyWithImpl<$Res, _$ReadingSessionImpl>
    implements _$$ReadingSessionImplCopyWith<$Res> {
  __$$ReadingSessionImplCopyWithImpl(
      _$ReadingSessionImpl _value, $Res Function(_$ReadingSessionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? chapterId = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? wordsRead = null,
    Object? startPosition = null,
    Object? endPosition = null,
    Object? notes = freezed,
  }) {
    return _then(_$ReadingSessionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      wordsRead: null == wordsRead
          ? _value.wordsRead
          : wordsRead // ignore: cast_nullable_to_non_nullable
              as int,
      startPosition: null == startPosition
          ? _value.startPosition
          : startPosition // ignore: cast_nullable_to_non_nullable
              as int,
      endPosition: null == endPosition
          ? _value.endPosition
          : endPosition // ignore: cast_nullable_to_non_nullable
              as int,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReadingSessionImpl implements _ReadingSession {
  const _$ReadingSessionImpl(
      {required this.id,
      required this.workId,
      required this.chapterId,
      required this.startTime,
      required this.endTime,
      required this.wordsRead,
      required this.startPosition,
      required this.endPosition,
      this.notes});

  factory _$ReadingSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReadingSessionImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String chapterId;
  @override
  final DateTime startTime;
  @override
  final DateTime endTime;
  @override
  final int wordsRead;
  @override
  final int startPosition;
  @override
  final int endPosition;
  @override
  final String? notes;

  @override
  String toString() {
    return 'ReadingSession(id: $id, workId: $workId, chapterId: $chapterId, startTime: $startTime, endTime: $endTime, wordsRead: $wordsRead, startPosition: $startPosition, endPosition: $endPosition, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadingSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.wordsRead, wordsRead) ||
                other.wordsRead == wordsRead) &&
            (identical(other.startPosition, startPosition) ||
                other.startPosition == startPosition) &&
            (identical(other.endPosition, endPosition) ||
                other.endPosition == endPosition) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, workId, chapterId, startTime,
      endTime, wordsRead, startPosition, endPosition, notes);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadingSessionImplCopyWith<_$ReadingSessionImpl> get copyWith =>
      __$$ReadingSessionImplCopyWithImpl<_$ReadingSessionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReadingSessionImplToJson(
      this,
    );
  }
}

abstract class _ReadingSession implements ReadingSession {
  const factory _ReadingSession(
      {required final String id,
      required final String workId,
      required final String chapterId,
      required final DateTime startTime,
      required final DateTime endTime,
      required final int wordsRead,
      required final int startPosition,
      required final int endPosition,
      final String? notes}) = _$ReadingSessionImpl;

  factory _ReadingSession.fromJson(Map<String, dynamic> json) =
      _$ReadingSessionImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get chapterId;
  @override
  DateTime get startTime;
  @override
  DateTime get endTime;
  @override
  int get wordsRead;
  @override
  int get startPosition;
  @override
  int get endPosition;
  @override
  String? get notes;
  @override
  @JsonKey(ignore: true)
  _$$ReadingSessionImplCopyWith<_$ReadingSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
