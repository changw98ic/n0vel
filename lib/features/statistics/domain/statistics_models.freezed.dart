// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'statistics_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WorkStatistics _$WorkStatisticsFromJson(Map<String, dynamic> json) {
  return _WorkStatistics.fromJson(json);
}

/// @nodoc
mixin _$WorkStatistics {
  String get workId => throw _privateConstructorUsedError;
  String get workTitle => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError; // 基础统计
  int get totalVolumes => throw _privateConstructorUsedError;
  int get totalChapters => throw _privateConstructorUsedError;
  int get publishedChapters => throw _privateConstructorUsedError;
  int get draftChapters => throw _privateConstructorUsedError; // 字数统计
  int get totalWords => throw _privateConstructorUsedError;
  int get publishedWords => throw _privateConstructorUsedError;
  int get dailyAverageWords => throw _privateConstructorUsedError;
  int get maxChapterWords => throw _privateConstructorUsedError;
  int get minChapterWords => throw _privateConstructorUsedError;
  double get averageChapterWords => throw _privateConstructorUsedError; // 时间统计
  int get writingDays => throw _privateConstructorUsedError;
  int get totalWritingMinutes => throw _privateConstructorUsedError;
  double get averageDailyWritingMinutes =>
      throw _privateConstructorUsedError; // 进度统计
  double get completionRate => throw _privateConstructorUsedError;
  int get estimatedDaysToComplete => throw _privateConstructorUsedError;
  DateTime? get estimatedCompletionDate =>
      throw _privateConstructorUsedError; // 角色统计
  int get totalCharacters => throw _privateConstructorUsedError;
  int get protagonistCount => throw _privateConstructorUsedError;
  int get supportingCount => throw _privateConstructorUsedError;
  int get minorCount => throw _privateConstructorUsedError; // 近期活动
  List<DailyWordCount> get recentWordCounts =>
      throw _privateConstructorUsedError;
  List<ChapterProgress> get chapterProgressList =>
      throw _privateConstructorUsedError;

  /// Serializes this WorkStatistics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkStatistics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkStatisticsCopyWith<WorkStatistics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkStatisticsCopyWith<$Res> {
  factory $WorkStatisticsCopyWith(
    WorkStatistics value,
    $Res Function(WorkStatistics) then,
  ) = _$WorkStatisticsCopyWithImpl<$Res, WorkStatistics>;
  @useResult
  $Res call({
    String workId,
    String workTitle,
    DateTime createdAt,
    DateTime updatedAt,
    int totalVolumes,
    int totalChapters,
    int publishedChapters,
    int draftChapters,
    int totalWords,
    int publishedWords,
    int dailyAverageWords,
    int maxChapterWords,
    int minChapterWords,
    double averageChapterWords,
    int writingDays,
    int totalWritingMinutes,
    double averageDailyWritingMinutes,
    double completionRate,
    int estimatedDaysToComplete,
    DateTime? estimatedCompletionDate,
    int totalCharacters,
    int protagonistCount,
    int supportingCount,
    int minorCount,
    List<DailyWordCount> recentWordCounts,
    List<ChapterProgress> chapterProgressList,
  });
}

/// @nodoc
class _$WorkStatisticsCopyWithImpl<$Res, $Val extends WorkStatistics>
    implements $WorkStatisticsCopyWith<$Res> {
  _$WorkStatisticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkStatistics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workId = null,
    Object? workTitle = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? totalVolumes = null,
    Object? totalChapters = null,
    Object? publishedChapters = null,
    Object? draftChapters = null,
    Object? totalWords = null,
    Object? publishedWords = null,
    Object? dailyAverageWords = null,
    Object? maxChapterWords = null,
    Object? minChapterWords = null,
    Object? averageChapterWords = null,
    Object? writingDays = null,
    Object? totalWritingMinutes = null,
    Object? averageDailyWritingMinutes = null,
    Object? completionRate = null,
    Object? estimatedDaysToComplete = null,
    Object? estimatedCompletionDate = freezed,
    Object? totalCharacters = null,
    Object? protagonistCount = null,
    Object? supportingCount = null,
    Object? minorCount = null,
    Object? recentWordCounts = null,
    Object? chapterProgressList = null,
  }) {
    return _then(
      _value.copyWith(
            workId: null == workId
                ? _value.workId
                : workId // ignore: cast_nullable_to_non_nullable
                      as String,
            workTitle: null == workTitle
                ? _value.workTitle
                : workTitle // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            totalVolumes: null == totalVolumes
                ? _value.totalVolumes
                : totalVolumes // ignore: cast_nullable_to_non_nullable
                      as int,
            totalChapters: null == totalChapters
                ? _value.totalChapters
                : totalChapters // ignore: cast_nullable_to_non_nullable
                      as int,
            publishedChapters: null == publishedChapters
                ? _value.publishedChapters
                : publishedChapters // ignore: cast_nullable_to_non_nullable
                      as int,
            draftChapters: null == draftChapters
                ? _value.draftChapters
                : draftChapters // ignore: cast_nullable_to_non_nullable
                      as int,
            totalWords: null == totalWords
                ? _value.totalWords
                : totalWords // ignore: cast_nullable_to_non_nullable
                      as int,
            publishedWords: null == publishedWords
                ? _value.publishedWords
                : publishedWords // ignore: cast_nullable_to_non_nullable
                      as int,
            dailyAverageWords: null == dailyAverageWords
                ? _value.dailyAverageWords
                : dailyAverageWords // ignore: cast_nullable_to_non_nullable
                      as int,
            maxChapterWords: null == maxChapterWords
                ? _value.maxChapterWords
                : maxChapterWords // ignore: cast_nullable_to_non_nullable
                      as int,
            minChapterWords: null == minChapterWords
                ? _value.minChapterWords
                : minChapterWords // ignore: cast_nullable_to_non_nullable
                      as int,
            averageChapterWords: null == averageChapterWords
                ? _value.averageChapterWords
                : averageChapterWords // ignore: cast_nullable_to_non_nullable
                      as double,
            writingDays: null == writingDays
                ? _value.writingDays
                : writingDays // ignore: cast_nullable_to_non_nullable
                      as int,
            totalWritingMinutes: null == totalWritingMinutes
                ? _value.totalWritingMinutes
                : totalWritingMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            averageDailyWritingMinutes: null == averageDailyWritingMinutes
                ? _value.averageDailyWritingMinutes
                : averageDailyWritingMinutes // ignore: cast_nullable_to_non_nullable
                      as double,
            completionRate: null == completionRate
                ? _value.completionRate
                : completionRate // ignore: cast_nullable_to_non_nullable
                      as double,
            estimatedDaysToComplete: null == estimatedDaysToComplete
                ? _value.estimatedDaysToComplete
                : estimatedDaysToComplete // ignore: cast_nullable_to_non_nullable
                      as int,
            estimatedCompletionDate: freezed == estimatedCompletionDate
                ? _value.estimatedCompletionDate
                : estimatedCompletionDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            totalCharacters: null == totalCharacters
                ? _value.totalCharacters
                : totalCharacters // ignore: cast_nullable_to_non_nullable
                      as int,
            protagonistCount: null == protagonistCount
                ? _value.protagonistCount
                : protagonistCount // ignore: cast_nullable_to_non_nullable
                      as int,
            supportingCount: null == supportingCount
                ? _value.supportingCount
                : supportingCount // ignore: cast_nullable_to_non_nullable
                      as int,
            minorCount: null == minorCount
                ? _value.minorCount
                : minorCount // ignore: cast_nullable_to_non_nullable
                      as int,
            recentWordCounts: null == recentWordCounts
                ? _value.recentWordCounts
                : recentWordCounts // ignore: cast_nullable_to_non_nullable
                      as List<DailyWordCount>,
            chapterProgressList: null == chapterProgressList
                ? _value.chapterProgressList
                : chapterProgressList // ignore: cast_nullable_to_non_nullable
                      as List<ChapterProgress>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WorkStatisticsImplCopyWith<$Res>
    implements $WorkStatisticsCopyWith<$Res> {
  factory _$$WorkStatisticsImplCopyWith(
    _$WorkStatisticsImpl value,
    $Res Function(_$WorkStatisticsImpl) then,
  ) = __$$WorkStatisticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String workId,
    String workTitle,
    DateTime createdAt,
    DateTime updatedAt,
    int totalVolumes,
    int totalChapters,
    int publishedChapters,
    int draftChapters,
    int totalWords,
    int publishedWords,
    int dailyAverageWords,
    int maxChapterWords,
    int minChapterWords,
    double averageChapterWords,
    int writingDays,
    int totalWritingMinutes,
    double averageDailyWritingMinutes,
    double completionRate,
    int estimatedDaysToComplete,
    DateTime? estimatedCompletionDate,
    int totalCharacters,
    int protagonistCount,
    int supportingCount,
    int minorCount,
    List<DailyWordCount> recentWordCounts,
    List<ChapterProgress> chapterProgressList,
  });
}

/// @nodoc
class __$$WorkStatisticsImplCopyWithImpl<$Res>
    extends _$WorkStatisticsCopyWithImpl<$Res, _$WorkStatisticsImpl>
    implements _$$WorkStatisticsImplCopyWith<$Res> {
  __$$WorkStatisticsImplCopyWithImpl(
    _$WorkStatisticsImpl _value,
    $Res Function(_$WorkStatisticsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WorkStatistics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workId = null,
    Object? workTitle = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? totalVolumes = null,
    Object? totalChapters = null,
    Object? publishedChapters = null,
    Object? draftChapters = null,
    Object? totalWords = null,
    Object? publishedWords = null,
    Object? dailyAverageWords = null,
    Object? maxChapterWords = null,
    Object? minChapterWords = null,
    Object? averageChapterWords = null,
    Object? writingDays = null,
    Object? totalWritingMinutes = null,
    Object? averageDailyWritingMinutes = null,
    Object? completionRate = null,
    Object? estimatedDaysToComplete = null,
    Object? estimatedCompletionDate = freezed,
    Object? totalCharacters = null,
    Object? protagonistCount = null,
    Object? supportingCount = null,
    Object? minorCount = null,
    Object? recentWordCounts = null,
    Object? chapterProgressList = null,
  }) {
    return _then(
      _$WorkStatisticsImpl(
        workId: null == workId
            ? _value.workId
            : workId // ignore: cast_nullable_to_non_nullable
                  as String,
        workTitle: null == workTitle
            ? _value.workTitle
            : workTitle // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        totalVolumes: null == totalVolumes
            ? _value.totalVolumes
            : totalVolumes // ignore: cast_nullable_to_non_nullable
                  as int,
        totalChapters: null == totalChapters
            ? _value.totalChapters
            : totalChapters // ignore: cast_nullable_to_non_nullable
                  as int,
        publishedChapters: null == publishedChapters
            ? _value.publishedChapters
            : publishedChapters // ignore: cast_nullable_to_non_nullable
                  as int,
        draftChapters: null == draftChapters
            ? _value.draftChapters
            : draftChapters // ignore: cast_nullable_to_non_nullable
                  as int,
        totalWords: null == totalWords
            ? _value.totalWords
            : totalWords // ignore: cast_nullable_to_non_nullable
                  as int,
        publishedWords: null == publishedWords
            ? _value.publishedWords
            : publishedWords // ignore: cast_nullable_to_non_nullable
                  as int,
        dailyAverageWords: null == dailyAverageWords
            ? _value.dailyAverageWords
            : dailyAverageWords // ignore: cast_nullable_to_non_nullable
                  as int,
        maxChapterWords: null == maxChapterWords
            ? _value.maxChapterWords
            : maxChapterWords // ignore: cast_nullable_to_non_nullable
                  as int,
        minChapterWords: null == minChapterWords
            ? _value.minChapterWords
            : minChapterWords // ignore: cast_nullable_to_non_nullable
                  as int,
        averageChapterWords: null == averageChapterWords
            ? _value.averageChapterWords
            : averageChapterWords // ignore: cast_nullable_to_non_nullable
                  as double,
        writingDays: null == writingDays
            ? _value.writingDays
            : writingDays // ignore: cast_nullable_to_non_nullable
                  as int,
        totalWritingMinutes: null == totalWritingMinutes
            ? _value.totalWritingMinutes
            : totalWritingMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        averageDailyWritingMinutes: null == averageDailyWritingMinutes
            ? _value.averageDailyWritingMinutes
            : averageDailyWritingMinutes // ignore: cast_nullable_to_non_nullable
                  as double,
        completionRate: null == completionRate
            ? _value.completionRate
            : completionRate // ignore: cast_nullable_to_non_nullable
                  as double,
        estimatedDaysToComplete: null == estimatedDaysToComplete
            ? _value.estimatedDaysToComplete
            : estimatedDaysToComplete // ignore: cast_nullable_to_non_nullable
                  as int,
        estimatedCompletionDate: freezed == estimatedCompletionDate
            ? _value.estimatedCompletionDate
            : estimatedCompletionDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        totalCharacters: null == totalCharacters
            ? _value.totalCharacters
            : totalCharacters // ignore: cast_nullable_to_non_nullable
                  as int,
        protagonistCount: null == protagonistCount
            ? _value.protagonistCount
            : protagonistCount // ignore: cast_nullable_to_non_nullable
                  as int,
        supportingCount: null == supportingCount
            ? _value.supportingCount
            : supportingCount // ignore: cast_nullable_to_non_nullable
                  as int,
        minorCount: null == minorCount
            ? _value.minorCount
            : minorCount // ignore: cast_nullable_to_non_nullable
                  as int,
        recentWordCounts: null == recentWordCounts
            ? _value._recentWordCounts
            : recentWordCounts // ignore: cast_nullable_to_non_nullable
                  as List<DailyWordCount>,
        chapterProgressList: null == chapterProgressList
            ? _value._chapterProgressList
            : chapterProgressList // ignore: cast_nullable_to_non_nullable
                  as List<ChapterProgress>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkStatisticsImpl implements _WorkStatistics {
  const _$WorkStatisticsImpl({
    required this.workId,
    required this.workTitle,
    required this.createdAt,
    required this.updatedAt,
    required this.totalVolumes,
    required this.totalChapters,
    required this.publishedChapters,
    required this.draftChapters,
    required this.totalWords,
    required this.publishedWords,
    required this.dailyAverageWords,
    required this.maxChapterWords,
    required this.minChapterWords,
    required this.averageChapterWords,
    required this.writingDays,
    required this.totalWritingMinutes,
    required this.averageDailyWritingMinutes,
    required this.completionRate,
    required this.estimatedDaysToComplete,
    required this.estimatedCompletionDate,
    required this.totalCharacters,
    required this.protagonistCount,
    required this.supportingCount,
    required this.minorCount,
    required final List<DailyWordCount> recentWordCounts,
    required final List<ChapterProgress> chapterProgressList,
  }) : _recentWordCounts = recentWordCounts,
       _chapterProgressList = chapterProgressList;

  factory _$WorkStatisticsImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkStatisticsImplFromJson(json);

  @override
  final String workId;
  @override
  final String workTitle;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  // 基础统计
  @override
  final int totalVolumes;
  @override
  final int totalChapters;
  @override
  final int publishedChapters;
  @override
  final int draftChapters;
  // 字数统计
  @override
  final int totalWords;
  @override
  final int publishedWords;
  @override
  final int dailyAverageWords;
  @override
  final int maxChapterWords;
  @override
  final int minChapterWords;
  @override
  final double averageChapterWords;
  // 时间统计
  @override
  final int writingDays;
  @override
  final int totalWritingMinutes;
  @override
  final double averageDailyWritingMinutes;
  // 进度统计
  @override
  final double completionRate;
  @override
  final int estimatedDaysToComplete;
  @override
  final DateTime? estimatedCompletionDate;
  // 角色统计
  @override
  final int totalCharacters;
  @override
  final int protagonistCount;
  @override
  final int supportingCount;
  @override
  final int minorCount;
  // 近期活动
  final List<DailyWordCount> _recentWordCounts;
  // 近期活动
  @override
  List<DailyWordCount> get recentWordCounts {
    if (_recentWordCounts is EqualUnmodifiableListView)
      return _recentWordCounts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentWordCounts);
  }

  final List<ChapterProgress> _chapterProgressList;
  @override
  List<ChapterProgress> get chapterProgressList {
    if (_chapterProgressList is EqualUnmodifiableListView)
      return _chapterProgressList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapterProgressList);
  }

  @override
  String toString() {
    return 'WorkStatistics(workId: $workId, workTitle: $workTitle, createdAt: $createdAt, updatedAt: $updatedAt, totalVolumes: $totalVolumes, totalChapters: $totalChapters, publishedChapters: $publishedChapters, draftChapters: $draftChapters, totalWords: $totalWords, publishedWords: $publishedWords, dailyAverageWords: $dailyAverageWords, maxChapterWords: $maxChapterWords, minChapterWords: $minChapterWords, averageChapterWords: $averageChapterWords, writingDays: $writingDays, totalWritingMinutes: $totalWritingMinutes, averageDailyWritingMinutes: $averageDailyWritingMinutes, completionRate: $completionRate, estimatedDaysToComplete: $estimatedDaysToComplete, estimatedCompletionDate: $estimatedCompletionDate, totalCharacters: $totalCharacters, protagonistCount: $protagonistCount, supportingCount: $supportingCount, minorCount: $minorCount, recentWordCounts: $recentWordCounts, chapterProgressList: $chapterProgressList)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkStatisticsImpl &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.workTitle, workTitle) ||
                other.workTitle == workTitle) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.totalVolumes, totalVolumes) ||
                other.totalVolumes == totalVolumes) &&
            (identical(other.totalChapters, totalChapters) ||
                other.totalChapters == totalChapters) &&
            (identical(other.publishedChapters, publishedChapters) ||
                other.publishedChapters == publishedChapters) &&
            (identical(other.draftChapters, draftChapters) ||
                other.draftChapters == draftChapters) &&
            (identical(other.totalWords, totalWords) ||
                other.totalWords == totalWords) &&
            (identical(other.publishedWords, publishedWords) ||
                other.publishedWords == publishedWords) &&
            (identical(other.dailyAverageWords, dailyAverageWords) ||
                other.dailyAverageWords == dailyAverageWords) &&
            (identical(other.maxChapterWords, maxChapterWords) ||
                other.maxChapterWords == maxChapterWords) &&
            (identical(other.minChapterWords, minChapterWords) ||
                other.minChapterWords == minChapterWords) &&
            (identical(other.averageChapterWords, averageChapterWords) ||
                other.averageChapterWords == averageChapterWords) &&
            (identical(other.writingDays, writingDays) ||
                other.writingDays == writingDays) &&
            (identical(other.totalWritingMinutes, totalWritingMinutes) ||
                other.totalWritingMinutes == totalWritingMinutes) &&
            (identical(
                  other.averageDailyWritingMinutes,
                  averageDailyWritingMinutes,
                ) ||
                other.averageDailyWritingMinutes ==
                    averageDailyWritingMinutes) &&
            (identical(other.completionRate, completionRate) ||
                other.completionRate == completionRate) &&
            (identical(
                  other.estimatedDaysToComplete,
                  estimatedDaysToComplete,
                ) ||
                other.estimatedDaysToComplete == estimatedDaysToComplete) &&
            (identical(
                  other.estimatedCompletionDate,
                  estimatedCompletionDate,
                ) ||
                other.estimatedCompletionDate == estimatedCompletionDate) &&
            (identical(other.totalCharacters, totalCharacters) ||
                other.totalCharacters == totalCharacters) &&
            (identical(other.protagonistCount, protagonistCount) ||
                other.protagonistCount == protagonistCount) &&
            (identical(other.supportingCount, supportingCount) ||
                other.supportingCount == supportingCount) &&
            (identical(other.minorCount, minorCount) ||
                other.minorCount == minorCount) &&
            const DeepCollectionEquality().equals(
              other._recentWordCounts,
              _recentWordCounts,
            ) &&
            const DeepCollectionEquality().equals(
              other._chapterProgressList,
              _chapterProgressList,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    workId,
    workTitle,
    createdAt,
    updatedAt,
    totalVolumes,
    totalChapters,
    publishedChapters,
    draftChapters,
    totalWords,
    publishedWords,
    dailyAverageWords,
    maxChapterWords,
    minChapterWords,
    averageChapterWords,
    writingDays,
    totalWritingMinutes,
    averageDailyWritingMinutes,
    completionRate,
    estimatedDaysToComplete,
    estimatedCompletionDate,
    totalCharacters,
    protagonistCount,
    supportingCount,
    minorCount,
    const DeepCollectionEquality().hash(_recentWordCounts),
    const DeepCollectionEquality().hash(_chapterProgressList),
  ]);

  /// Create a copy of WorkStatistics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkStatisticsImplCopyWith<_$WorkStatisticsImpl> get copyWith =>
      __$$WorkStatisticsImplCopyWithImpl<_$WorkStatisticsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkStatisticsImplToJson(this);
  }
}

abstract class _WorkStatistics implements WorkStatistics {
  const factory _WorkStatistics({
    required final String workId,
    required final String workTitle,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    required final int totalVolumes,
    required final int totalChapters,
    required final int publishedChapters,
    required final int draftChapters,
    required final int totalWords,
    required final int publishedWords,
    required final int dailyAverageWords,
    required final int maxChapterWords,
    required final int minChapterWords,
    required final double averageChapterWords,
    required final int writingDays,
    required final int totalWritingMinutes,
    required final double averageDailyWritingMinutes,
    required final double completionRate,
    required final int estimatedDaysToComplete,
    required final DateTime? estimatedCompletionDate,
    required final int totalCharacters,
    required final int protagonistCount,
    required final int supportingCount,
    required final int minorCount,
    required final List<DailyWordCount> recentWordCounts,
    required final List<ChapterProgress> chapterProgressList,
  }) = _$WorkStatisticsImpl;

  factory _WorkStatistics.fromJson(Map<String, dynamic> json) =
      _$WorkStatisticsImpl.fromJson;

  @override
  String get workId;
  @override
  String get workTitle;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt; // 基础统计
  @override
  int get totalVolumes;
  @override
  int get totalChapters;
  @override
  int get publishedChapters;
  @override
  int get draftChapters; // 字数统计
  @override
  int get totalWords;
  @override
  int get publishedWords;
  @override
  int get dailyAverageWords;
  @override
  int get maxChapterWords;
  @override
  int get minChapterWords;
  @override
  double get averageChapterWords; // 时间统计
  @override
  int get writingDays;
  @override
  int get totalWritingMinutes;
  @override
  double get averageDailyWritingMinutes; // 进度统计
  @override
  double get completionRate;
  @override
  int get estimatedDaysToComplete;
  @override
  DateTime? get estimatedCompletionDate; // 角色统计
  @override
  int get totalCharacters;
  @override
  int get protagonistCount;
  @override
  int get supportingCount;
  @override
  int get minorCount; // 近期活动
  @override
  List<DailyWordCount> get recentWordCounts;
  @override
  List<ChapterProgress> get chapterProgressList;

  /// Create a copy of WorkStatistics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkStatisticsImplCopyWith<_$WorkStatisticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DailyWordCount _$DailyWordCountFromJson(Map<String, dynamic> json) {
  return _DailyWordCount.fromJson(json);
}

/// @nodoc
mixin _$DailyWordCount {
  DateTime get date => throw _privateConstructorUsedError;
  int get wordCount => throw _privateConstructorUsedError;
  int get chapterCount => throw _privateConstructorUsedError;
  int get writingMinutes => throw _privateConstructorUsedError;

  /// Serializes this DailyWordCount to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DailyWordCount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyWordCountCopyWith<DailyWordCount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyWordCountCopyWith<$Res> {
  factory $DailyWordCountCopyWith(
    DailyWordCount value,
    $Res Function(DailyWordCount) then,
  ) = _$DailyWordCountCopyWithImpl<$Res, DailyWordCount>;
  @useResult
  $Res call({
    DateTime date,
    int wordCount,
    int chapterCount,
    int writingMinutes,
  });
}

/// @nodoc
class _$DailyWordCountCopyWithImpl<$Res, $Val extends DailyWordCount>
    implements $DailyWordCountCopyWith<$Res> {
  _$DailyWordCountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyWordCount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? wordCount = null,
    Object? chapterCount = null,
    Object? writingMinutes = null,
  }) {
    return _then(
      _value.copyWith(
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            wordCount: null == wordCount
                ? _value.wordCount
                : wordCount // ignore: cast_nullable_to_non_nullable
                      as int,
            chapterCount: null == chapterCount
                ? _value.chapterCount
                : chapterCount // ignore: cast_nullable_to_non_nullable
                      as int,
            writingMinutes: null == writingMinutes
                ? _value.writingMinutes
                : writingMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DailyWordCountImplCopyWith<$Res>
    implements $DailyWordCountCopyWith<$Res> {
  factory _$$DailyWordCountImplCopyWith(
    _$DailyWordCountImpl value,
    $Res Function(_$DailyWordCountImpl) then,
  ) = __$$DailyWordCountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DateTime date,
    int wordCount,
    int chapterCount,
    int writingMinutes,
  });
}

/// @nodoc
class __$$DailyWordCountImplCopyWithImpl<$Res>
    extends _$DailyWordCountCopyWithImpl<$Res, _$DailyWordCountImpl>
    implements _$$DailyWordCountImplCopyWith<$Res> {
  __$$DailyWordCountImplCopyWithImpl(
    _$DailyWordCountImpl _value,
    $Res Function(_$DailyWordCountImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DailyWordCount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? wordCount = null,
    Object? chapterCount = null,
    Object? writingMinutes = null,
  }) {
    return _then(
      _$DailyWordCountImpl(
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        wordCount: null == wordCount
            ? _value.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterCount: null == chapterCount
            ? _value.chapterCount
            : chapterCount // ignore: cast_nullable_to_non_nullable
                  as int,
        writingMinutes: null == writingMinutes
            ? _value.writingMinutes
            : writingMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyWordCountImpl implements _DailyWordCount {
  const _$DailyWordCountImpl({
    required this.date,
    required this.wordCount,
    required this.chapterCount,
    required this.writingMinutes,
  });

  factory _$DailyWordCountImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyWordCountImplFromJson(json);

  @override
  final DateTime date;
  @override
  final int wordCount;
  @override
  final int chapterCount;
  @override
  final int writingMinutes;

  @override
  String toString() {
    return 'DailyWordCount(date: $date, wordCount: $wordCount, chapterCount: $chapterCount, writingMinutes: $writingMinutes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyWordCountImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.chapterCount, chapterCount) ||
                other.chapterCount == chapterCount) &&
            (identical(other.writingMinutes, writingMinutes) ||
                other.writingMinutes == writingMinutes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, date, wordCount, chapterCount, writingMinutes);

  /// Create a copy of DailyWordCount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyWordCountImplCopyWith<_$DailyWordCountImpl> get copyWith =>
      __$$DailyWordCountImplCopyWithImpl<_$DailyWordCountImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyWordCountImplToJson(this);
  }
}

abstract class _DailyWordCount implements DailyWordCount {
  const factory _DailyWordCount({
    required final DateTime date,
    required final int wordCount,
    required final int chapterCount,
    required final int writingMinutes,
  }) = _$DailyWordCountImpl;

  factory _DailyWordCount.fromJson(Map<String, dynamic> json) =
      _$DailyWordCountImpl.fromJson;

  @override
  DateTime get date;
  @override
  int get wordCount;
  @override
  int get chapterCount;
  @override
  int get writingMinutes;

  /// Create a copy of DailyWordCount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyWordCountImplCopyWith<_$DailyWordCountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChapterProgress _$ChapterProgressFromJson(Map<String, dynamic> json) {
  return _ChapterProgress.fromJson(json);
}

/// @nodoc
mixin _$ChapterProgress {
  String get chapterId => throw _privateConstructorUsedError;
  String get chapterTitle => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;
  int get wordCount => throw _privateConstructorUsedError;
  ChapterStatus get status => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  double? get reviewScore => throw _privateConstructorUsedError;

  /// Serializes this ChapterProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChapterProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChapterProgressCopyWith<ChapterProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChapterProgressCopyWith<$Res> {
  factory $ChapterProgressCopyWith(
    ChapterProgress value,
    $Res Function(ChapterProgress) then,
  ) = _$ChapterProgressCopyWithImpl<$Res, ChapterProgress>;
  @useResult
  $Res call({
    String chapterId,
    String chapterTitle,
    int order,
    int wordCount,
    ChapterStatus status,
    DateTime updatedAt,
    double? reviewScore,
  });
}

/// @nodoc
class _$ChapterProgressCopyWithImpl<$Res, $Val extends ChapterProgress>
    implements $ChapterProgressCopyWith<$Res> {
  _$ChapterProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChapterProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? chapterTitle = null,
    Object? order = null,
    Object? wordCount = null,
    Object? status = null,
    Object? updatedAt = null,
    Object? reviewScore = freezed,
  }) {
    return _then(
      _value.copyWith(
            chapterId: null == chapterId
                ? _value.chapterId
                : chapterId // ignore: cast_nullable_to_non_nullable
                      as String,
            chapterTitle: null == chapterTitle
                ? _value.chapterTitle
                : chapterTitle // ignore: cast_nullable_to_non_nullable
                      as String,
            order: null == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                      as int,
            wordCount: null == wordCount
                ? _value.wordCount
                : wordCount // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as ChapterStatus,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            reviewScore: freezed == reviewScore
                ? _value.reviewScore
                : reviewScore // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChapterProgressImplCopyWith<$Res>
    implements $ChapterProgressCopyWith<$Res> {
  factory _$$ChapterProgressImplCopyWith(
    _$ChapterProgressImpl value,
    $Res Function(_$ChapterProgressImpl) then,
  ) = __$$ChapterProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String chapterId,
    String chapterTitle,
    int order,
    int wordCount,
    ChapterStatus status,
    DateTime updatedAt,
    double? reviewScore,
  });
}

/// @nodoc
class __$$ChapterProgressImplCopyWithImpl<$Res>
    extends _$ChapterProgressCopyWithImpl<$Res, _$ChapterProgressImpl>
    implements _$$ChapterProgressImplCopyWith<$Res> {
  __$$ChapterProgressImplCopyWithImpl(
    _$ChapterProgressImpl _value,
    $Res Function(_$ChapterProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChapterProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? chapterTitle = null,
    Object? order = null,
    Object? wordCount = null,
    Object? status = null,
    Object? updatedAt = null,
    Object? reviewScore = freezed,
  }) {
    return _then(
      _$ChapterProgressImpl(
        chapterId: null == chapterId
            ? _value.chapterId
            : chapterId // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterTitle: null == chapterTitle
            ? _value.chapterTitle
            : chapterTitle // ignore: cast_nullable_to_non_nullable
                  as String,
        order: null == order
            ? _value.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        wordCount: null == wordCount
            ? _value.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as ChapterStatus,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        reviewScore: freezed == reviewScore
            ? _value.reviewScore
            : reviewScore // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChapterProgressImpl implements _ChapterProgress {
  const _$ChapterProgressImpl({
    required this.chapterId,
    required this.chapterTitle,
    required this.order,
    required this.wordCount,
    required this.status,
    required this.updatedAt,
    required this.reviewScore,
  });

  factory _$ChapterProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChapterProgressImplFromJson(json);

  @override
  final String chapterId;
  @override
  final String chapterTitle;
  @override
  final int order;
  @override
  final int wordCount;
  @override
  final ChapterStatus status;
  @override
  final DateTime updatedAt;
  @override
  final double? reviewScore;

  @override
  String toString() {
    return 'ChapterProgress(chapterId: $chapterId, chapterTitle: $chapterTitle, order: $order, wordCount: $wordCount, status: $status, updatedAt: $updatedAt, reviewScore: $reviewScore)';
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
            (identical(other.order, order) || other.order == order) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.reviewScore, reviewScore) ||
                other.reviewScore == reviewScore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    chapterId,
    chapterTitle,
    order,
    wordCount,
    status,
    updatedAt,
    reviewScore,
  );

  /// Create a copy of ChapterProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChapterProgressImplCopyWith<_$ChapterProgressImpl> get copyWith =>
      __$$ChapterProgressImplCopyWithImpl<_$ChapterProgressImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ChapterProgressImplToJson(this);
  }
}

abstract class _ChapterProgress implements ChapterProgress {
  const factory _ChapterProgress({
    required final String chapterId,
    required final String chapterTitle,
    required final int order,
    required final int wordCount,
    required final ChapterStatus status,
    required final DateTime updatedAt,
    required final double? reviewScore,
  }) = _$ChapterProgressImpl;

  factory _ChapterProgress.fromJson(Map<String, dynamic> json) =
      _$ChapterProgressImpl.fromJson;

  @override
  String get chapterId;
  @override
  String get chapterTitle;
  @override
  int get order;
  @override
  int get wordCount;
  @override
  ChapterStatus get status;
  @override
  DateTime get updatedAt;
  @override
  double? get reviewScore;

  /// Create a copy of ChapterProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChapterProgressImplCopyWith<_$ChapterProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WritingSessionStats _$WritingSessionStatsFromJson(Map<String, dynamic> json) {
  return _WritingSessionStats.fromJson(json);
}

/// @nodoc
mixin _$WritingSessionStats {
  DateTime get date => throw _privateConstructorUsedError;
  int get totalMinutes => throw _privateConstructorUsedError;
  int get totalWords => throw _privateConstructorUsedError;
  int get sessionCount => throw _privateConstructorUsedError;
  Map<int, int> get hourlyDistribution => throw _privateConstructorUsedError;

  /// Serializes this WritingSessionStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WritingSessionStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WritingSessionStatsCopyWith<WritingSessionStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WritingSessionStatsCopyWith<$Res> {
  factory $WritingSessionStatsCopyWith(
    WritingSessionStats value,
    $Res Function(WritingSessionStats) then,
  ) = _$WritingSessionStatsCopyWithImpl<$Res, WritingSessionStats>;
  @useResult
  $Res call({
    DateTime date,
    int totalMinutes,
    int totalWords,
    int sessionCount,
    Map<int, int> hourlyDistribution,
  });
}

/// @nodoc
class _$WritingSessionStatsCopyWithImpl<$Res, $Val extends WritingSessionStats>
    implements $WritingSessionStatsCopyWith<$Res> {
  _$WritingSessionStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WritingSessionStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? totalMinutes = null,
    Object? totalWords = null,
    Object? sessionCount = null,
    Object? hourlyDistribution = null,
  }) {
    return _then(
      _value.copyWith(
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            totalMinutes: null == totalMinutes
                ? _value.totalMinutes
                : totalMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            totalWords: null == totalWords
                ? _value.totalWords
                : totalWords // ignore: cast_nullable_to_non_nullable
                      as int,
            sessionCount: null == sessionCount
                ? _value.sessionCount
                : sessionCount // ignore: cast_nullable_to_non_nullable
                      as int,
            hourlyDistribution: null == hourlyDistribution
                ? _value.hourlyDistribution
                : hourlyDistribution // ignore: cast_nullable_to_non_nullable
                      as Map<int, int>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WritingSessionStatsImplCopyWith<$Res>
    implements $WritingSessionStatsCopyWith<$Res> {
  factory _$$WritingSessionStatsImplCopyWith(
    _$WritingSessionStatsImpl value,
    $Res Function(_$WritingSessionStatsImpl) then,
  ) = __$$WritingSessionStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DateTime date,
    int totalMinutes,
    int totalWords,
    int sessionCount,
    Map<int, int> hourlyDistribution,
  });
}

/// @nodoc
class __$$WritingSessionStatsImplCopyWithImpl<$Res>
    extends _$WritingSessionStatsCopyWithImpl<$Res, _$WritingSessionStatsImpl>
    implements _$$WritingSessionStatsImplCopyWith<$Res> {
  __$$WritingSessionStatsImplCopyWithImpl(
    _$WritingSessionStatsImpl _value,
    $Res Function(_$WritingSessionStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WritingSessionStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? totalMinutes = null,
    Object? totalWords = null,
    Object? sessionCount = null,
    Object? hourlyDistribution = null,
  }) {
    return _then(
      _$WritingSessionStatsImpl(
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        totalMinutes: null == totalMinutes
            ? _value.totalMinutes
            : totalMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        totalWords: null == totalWords
            ? _value.totalWords
            : totalWords // ignore: cast_nullable_to_non_nullable
                  as int,
        sessionCount: null == sessionCount
            ? _value.sessionCount
            : sessionCount // ignore: cast_nullable_to_non_nullable
                  as int,
        hourlyDistribution: null == hourlyDistribution
            ? _value._hourlyDistribution
            : hourlyDistribution // ignore: cast_nullable_to_non_nullable
                  as Map<int, int>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WritingSessionStatsImpl implements _WritingSessionStats {
  const _$WritingSessionStatsImpl({
    required this.date,
    required this.totalMinutes,
    required this.totalWords,
    required this.sessionCount,
    required final Map<int, int> hourlyDistribution,
  }) : _hourlyDistribution = hourlyDistribution;

  factory _$WritingSessionStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$WritingSessionStatsImplFromJson(json);

  @override
  final DateTime date;
  @override
  final int totalMinutes;
  @override
  final int totalWords;
  @override
  final int sessionCount;
  final Map<int, int> _hourlyDistribution;
  @override
  Map<int, int> get hourlyDistribution {
    if (_hourlyDistribution is EqualUnmodifiableMapView)
      return _hourlyDistribution;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_hourlyDistribution);
  }

  @override
  String toString() {
    return 'WritingSessionStats(date: $date, totalMinutes: $totalMinutes, totalWords: $totalWords, sessionCount: $sessionCount, hourlyDistribution: $hourlyDistribution)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WritingSessionStatsImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.totalMinutes, totalMinutes) ||
                other.totalMinutes == totalMinutes) &&
            (identical(other.totalWords, totalWords) ||
                other.totalWords == totalWords) &&
            (identical(other.sessionCount, sessionCount) ||
                other.sessionCount == sessionCount) &&
            const DeepCollectionEquality().equals(
              other._hourlyDistribution,
              _hourlyDistribution,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    date,
    totalMinutes,
    totalWords,
    sessionCount,
    const DeepCollectionEquality().hash(_hourlyDistribution),
  );

  /// Create a copy of WritingSessionStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WritingSessionStatsImplCopyWith<_$WritingSessionStatsImpl> get copyWith =>
      __$$WritingSessionStatsImplCopyWithImpl<_$WritingSessionStatsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WritingSessionStatsImplToJson(this);
  }
}

abstract class _WritingSessionStats implements WritingSessionStats {
  const factory _WritingSessionStats({
    required final DateTime date,
    required final int totalMinutes,
    required final int totalWords,
    required final int sessionCount,
    required final Map<int, int> hourlyDistribution,
  }) = _$WritingSessionStatsImpl;

  factory _WritingSessionStats.fromJson(Map<String, dynamic> json) =
      _$WritingSessionStatsImpl.fromJson;

  @override
  DateTime get date;
  @override
  int get totalMinutes;
  @override
  int get totalWords;
  @override
  int get sessionCount;
  @override
  Map<int, int> get hourlyDistribution;

  /// Create a copy of WritingSessionStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WritingSessionStatsImplCopyWith<_$WritingSessionStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WordCountTrend _$WordCountTrendFromJson(Map<String, dynamic> json) {
  return _WordCountTrend.fromJson(json);
}

/// @nodoc
mixin _$WordCountTrend {
  TrendPeriod get period => throw _privateConstructorUsedError;
  List<TrendDataPoint> get dataPoints => throw _privateConstructorUsedError;
  double get growthRate => throw _privateConstructorUsedError;
  int get totalGrowth => throw _privateConstructorUsedError;

  /// Serializes this WordCountTrend to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WordCountTrend
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WordCountTrendCopyWith<WordCountTrend> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WordCountTrendCopyWith<$Res> {
  factory $WordCountTrendCopyWith(
    WordCountTrend value,
    $Res Function(WordCountTrend) then,
  ) = _$WordCountTrendCopyWithImpl<$Res, WordCountTrend>;
  @useResult
  $Res call({
    TrendPeriod period,
    List<TrendDataPoint> dataPoints,
    double growthRate,
    int totalGrowth,
  });
}

/// @nodoc
class _$WordCountTrendCopyWithImpl<$Res, $Val extends WordCountTrend>
    implements $WordCountTrendCopyWith<$Res> {
  _$WordCountTrendCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WordCountTrend
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? period = null,
    Object? dataPoints = null,
    Object? growthRate = null,
    Object? totalGrowth = null,
  }) {
    return _then(
      _value.copyWith(
            period: null == period
                ? _value.period
                : period // ignore: cast_nullable_to_non_nullable
                      as TrendPeriod,
            dataPoints: null == dataPoints
                ? _value.dataPoints
                : dataPoints // ignore: cast_nullable_to_non_nullable
                      as List<TrendDataPoint>,
            growthRate: null == growthRate
                ? _value.growthRate
                : growthRate // ignore: cast_nullable_to_non_nullable
                      as double,
            totalGrowth: null == totalGrowth
                ? _value.totalGrowth
                : totalGrowth // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WordCountTrendImplCopyWith<$Res>
    implements $WordCountTrendCopyWith<$Res> {
  factory _$$WordCountTrendImplCopyWith(
    _$WordCountTrendImpl value,
    $Res Function(_$WordCountTrendImpl) then,
  ) = __$$WordCountTrendImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    TrendPeriod period,
    List<TrendDataPoint> dataPoints,
    double growthRate,
    int totalGrowth,
  });
}

/// @nodoc
class __$$WordCountTrendImplCopyWithImpl<$Res>
    extends _$WordCountTrendCopyWithImpl<$Res, _$WordCountTrendImpl>
    implements _$$WordCountTrendImplCopyWith<$Res> {
  __$$WordCountTrendImplCopyWithImpl(
    _$WordCountTrendImpl _value,
    $Res Function(_$WordCountTrendImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WordCountTrend
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? period = null,
    Object? dataPoints = null,
    Object? growthRate = null,
    Object? totalGrowth = null,
  }) {
    return _then(
      _$WordCountTrendImpl(
        period: null == period
            ? _value.period
            : period // ignore: cast_nullable_to_non_nullable
                  as TrendPeriod,
        dataPoints: null == dataPoints
            ? _value._dataPoints
            : dataPoints // ignore: cast_nullable_to_non_nullable
                  as List<TrendDataPoint>,
        growthRate: null == growthRate
            ? _value.growthRate
            : growthRate // ignore: cast_nullable_to_non_nullable
                  as double,
        totalGrowth: null == totalGrowth
            ? _value.totalGrowth
            : totalGrowth // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WordCountTrendImpl implements _WordCountTrend {
  const _$WordCountTrendImpl({
    required this.period,
    required final List<TrendDataPoint> dataPoints,
    required this.growthRate,
    required this.totalGrowth,
  }) : _dataPoints = dataPoints;

  factory _$WordCountTrendImpl.fromJson(Map<String, dynamic> json) =>
      _$$WordCountTrendImplFromJson(json);

  @override
  final TrendPeriod period;
  final List<TrendDataPoint> _dataPoints;
  @override
  List<TrendDataPoint> get dataPoints {
    if (_dataPoints is EqualUnmodifiableListView) return _dataPoints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dataPoints);
  }

  @override
  final double growthRate;
  @override
  final int totalGrowth;

  @override
  String toString() {
    return 'WordCountTrend(period: $period, dataPoints: $dataPoints, growthRate: $growthRate, totalGrowth: $totalGrowth)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WordCountTrendImpl &&
            (identical(other.period, period) || other.period == period) &&
            const DeepCollectionEquality().equals(
              other._dataPoints,
              _dataPoints,
            ) &&
            (identical(other.growthRate, growthRate) ||
                other.growthRate == growthRate) &&
            (identical(other.totalGrowth, totalGrowth) ||
                other.totalGrowth == totalGrowth));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    period,
    const DeepCollectionEquality().hash(_dataPoints),
    growthRate,
    totalGrowth,
  );

  /// Create a copy of WordCountTrend
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WordCountTrendImplCopyWith<_$WordCountTrendImpl> get copyWith =>
      __$$WordCountTrendImplCopyWithImpl<_$WordCountTrendImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WordCountTrendImplToJson(this);
  }
}

abstract class _WordCountTrend implements WordCountTrend {
  const factory _WordCountTrend({
    required final TrendPeriod period,
    required final List<TrendDataPoint> dataPoints,
    required final double growthRate,
    required final int totalGrowth,
  }) = _$WordCountTrendImpl;

  factory _WordCountTrend.fromJson(Map<String, dynamic> json) =
      _$WordCountTrendImpl.fromJson;

  @override
  TrendPeriod get period;
  @override
  List<TrendDataPoint> get dataPoints;
  @override
  double get growthRate;
  @override
  int get totalGrowth;

  /// Create a copy of WordCountTrend
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WordCountTrendImplCopyWith<_$WordCountTrendImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TrendDataPoint _$TrendDataPointFromJson(Map<String, dynamic> json) {
  return _TrendDataPoint.fromJson(json);
}

/// @nodoc
mixin _$TrendDataPoint {
  DateTime get date => throw _privateConstructorUsedError;
  int get value => throw _privateConstructorUsedError;
  int get cumulativeValue => throw _privateConstructorUsedError;

  /// Serializes this TrendDataPoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TrendDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TrendDataPointCopyWith<TrendDataPoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TrendDataPointCopyWith<$Res> {
  factory $TrendDataPointCopyWith(
    TrendDataPoint value,
    $Res Function(TrendDataPoint) then,
  ) = _$TrendDataPointCopyWithImpl<$Res, TrendDataPoint>;
  @useResult
  $Res call({DateTime date, int value, int cumulativeValue});
}

/// @nodoc
class _$TrendDataPointCopyWithImpl<$Res, $Val extends TrendDataPoint>
    implements $TrendDataPointCopyWith<$Res> {
  _$TrendDataPointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TrendDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? value = null,
    Object? cumulativeValue = null,
  }) {
    return _then(
      _value.copyWith(
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as int,
            cumulativeValue: null == cumulativeValue
                ? _value.cumulativeValue
                : cumulativeValue // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TrendDataPointImplCopyWith<$Res>
    implements $TrendDataPointCopyWith<$Res> {
  factory _$$TrendDataPointImplCopyWith(
    _$TrendDataPointImpl value,
    $Res Function(_$TrendDataPointImpl) then,
  ) = __$$TrendDataPointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime date, int value, int cumulativeValue});
}

/// @nodoc
class __$$TrendDataPointImplCopyWithImpl<$Res>
    extends _$TrendDataPointCopyWithImpl<$Res, _$TrendDataPointImpl>
    implements _$$TrendDataPointImplCopyWith<$Res> {
  __$$TrendDataPointImplCopyWithImpl(
    _$TrendDataPointImpl _value,
    $Res Function(_$TrendDataPointImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TrendDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? value = null,
    Object? cumulativeValue = null,
  }) {
    return _then(
      _$TrendDataPointImpl(
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as int,
        cumulativeValue: null == cumulativeValue
            ? _value.cumulativeValue
            : cumulativeValue // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TrendDataPointImpl implements _TrendDataPoint {
  const _$TrendDataPointImpl({
    required this.date,
    required this.value,
    required this.cumulativeValue,
  });

  factory _$TrendDataPointImpl.fromJson(Map<String, dynamic> json) =>
      _$$TrendDataPointImplFromJson(json);

  @override
  final DateTime date;
  @override
  final int value;
  @override
  final int cumulativeValue;

  @override
  String toString() {
    return 'TrendDataPoint(date: $date, value: $value, cumulativeValue: $cumulativeValue)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TrendDataPointImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.cumulativeValue, cumulativeValue) ||
                other.cumulativeValue == cumulativeValue));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, value, cumulativeValue);

  /// Create a copy of TrendDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TrendDataPointImplCopyWith<_$TrendDataPointImpl> get copyWith =>
      __$$TrendDataPointImplCopyWithImpl<_$TrendDataPointImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TrendDataPointImplToJson(this);
  }
}

abstract class _TrendDataPoint implements TrendDataPoint {
  const factory _TrendDataPoint({
    required final DateTime date,
    required final int value,
    required final int cumulativeValue,
  }) = _$TrendDataPointImpl;

  factory _TrendDataPoint.fromJson(Map<String, dynamic> json) =
      _$TrendDataPointImpl.fromJson;

  @override
  DateTime get date;
  @override
  int get value;
  @override
  int get cumulativeValue;

  /// Create a copy of TrendDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TrendDataPointImplCopyWith<_$TrendDataPointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CharacterAppearanceStats _$CharacterAppearanceStatsFromJson(
  Map<String, dynamic> json,
) {
  return _CharacterAppearanceStats.fromJson(json);
}

/// @nodoc
mixin _$CharacterAppearanceStats {
  String get characterId => throw _privateConstructorUsedError;
  String get characterName => throw _privateConstructorUsedError;
  int get appearanceCount => throw _privateConstructorUsedError;
  int get dialogueCount => throw _privateConstructorUsedError;
  List<String> get chapterIds => throw _privateConstructorUsedError;
  double get screenTimePercentage => throw _privateConstructorUsedError;

  /// Serializes this CharacterAppearanceStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CharacterAppearanceStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterAppearanceStatsCopyWith<CharacterAppearanceStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterAppearanceStatsCopyWith<$Res> {
  factory $CharacterAppearanceStatsCopyWith(
    CharacterAppearanceStats value,
    $Res Function(CharacterAppearanceStats) then,
  ) = _$CharacterAppearanceStatsCopyWithImpl<$Res, CharacterAppearanceStats>;
  @useResult
  $Res call({
    String characterId,
    String characterName,
    int appearanceCount,
    int dialogueCount,
    List<String> chapterIds,
    double screenTimePercentage,
  });
}

/// @nodoc
class _$CharacterAppearanceStatsCopyWithImpl<
  $Res,
  $Val extends CharacterAppearanceStats
>
    implements $CharacterAppearanceStatsCopyWith<$Res> {
  _$CharacterAppearanceStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterAppearanceStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterId = null,
    Object? characterName = null,
    Object? appearanceCount = null,
    Object? dialogueCount = null,
    Object? chapterIds = null,
    Object? screenTimePercentage = null,
  }) {
    return _then(
      _value.copyWith(
            characterId: null == characterId
                ? _value.characterId
                : characterId // ignore: cast_nullable_to_non_nullable
                      as String,
            characterName: null == characterName
                ? _value.characterName
                : characterName // ignore: cast_nullable_to_non_nullable
                      as String,
            appearanceCount: null == appearanceCount
                ? _value.appearanceCount
                : appearanceCount // ignore: cast_nullable_to_non_nullable
                      as int,
            dialogueCount: null == dialogueCount
                ? _value.dialogueCount
                : dialogueCount // ignore: cast_nullable_to_non_nullable
                      as int,
            chapterIds: null == chapterIds
                ? _value.chapterIds
                : chapterIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            screenTimePercentage: null == screenTimePercentage
                ? _value.screenTimePercentage
                : screenTimePercentage // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterAppearanceStatsImplCopyWith<$Res>
    implements $CharacterAppearanceStatsCopyWith<$Res> {
  factory _$$CharacterAppearanceStatsImplCopyWith(
    _$CharacterAppearanceStatsImpl value,
    $Res Function(_$CharacterAppearanceStatsImpl) then,
  ) = __$$CharacterAppearanceStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String characterId,
    String characterName,
    int appearanceCount,
    int dialogueCount,
    List<String> chapterIds,
    double screenTimePercentage,
  });
}

/// @nodoc
class __$$CharacterAppearanceStatsImplCopyWithImpl<$Res>
    extends
        _$CharacterAppearanceStatsCopyWithImpl<
          $Res,
          _$CharacterAppearanceStatsImpl
        >
    implements _$$CharacterAppearanceStatsImplCopyWith<$Res> {
  __$$CharacterAppearanceStatsImplCopyWithImpl(
    _$CharacterAppearanceStatsImpl _value,
    $Res Function(_$CharacterAppearanceStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterAppearanceStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterId = null,
    Object? characterName = null,
    Object? appearanceCount = null,
    Object? dialogueCount = null,
    Object? chapterIds = null,
    Object? screenTimePercentage = null,
  }) {
    return _then(
      _$CharacterAppearanceStatsImpl(
        characterId: null == characterId
            ? _value.characterId
            : characterId // ignore: cast_nullable_to_non_nullable
                  as String,
        characterName: null == characterName
            ? _value.characterName
            : characterName // ignore: cast_nullable_to_non_nullable
                  as String,
        appearanceCount: null == appearanceCount
            ? _value.appearanceCount
            : appearanceCount // ignore: cast_nullable_to_non_nullable
                  as int,
        dialogueCount: null == dialogueCount
            ? _value.dialogueCount
            : dialogueCount // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterIds: null == chapterIds
            ? _value._chapterIds
            : chapterIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        screenTimePercentage: null == screenTimePercentage
            ? _value.screenTimePercentage
            : screenTimePercentage // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CharacterAppearanceStatsImpl implements _CharacterAppearanceStats {
  const _$CharacterAppearanceStatsImpl({
    required this.characterId,
    required this.characterName,
    required this.appearanceCount,
    required this.dialogueCount,
    required final List<String> chapterIds,
    required this.screenTimePercentage,
  }) : _chapterIds = chapterIds;

  factory _$CharacterAppearanceStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$CharacterAppearanceStatsImplFromJson(json);

  @override
  final String characterId;
  @override
  final String characterName;
  @override
  final int appearanceCount;
  @override
  final int dialogueCount;
  final List<String> _chapterIds;
  @override
  List<String> get chapterIds {
    if (_chapterIds is EqualUnmodifiableListView) return _chapterIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapterIds);
  }

  @override
  final double screenTimePercentage;

  @override
  String toString() {
    return 'CharacterAppearanceStats(characterId: $characterId, characterName: $characterName, appearanceCount: $appearanceCount, dialogueCount: $dialogueCount, chapterIds: $chapterIds, screenTimePercentage: $screenTimePercentage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterAppearanceStatsImpl &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.characterName, characterName) ||
                other.characterName == characterName) &&
            (identical(other.appearanceCount, appearanceCount) ||
                other.appearanceCount == appearanceCount) &&
            (identical(other.dialogueCount, dialogueCount) ||
                other.dialogueCount == dialogueCount) &&
            const DeepCollectionEquality().equals(
              other._chapterIds,
              _chapterIds,
            ) &&
            (identical(other.screenTimePercentage, screenTimePercentage) ||
                other.screenTimePercentage == screenTimePercentage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    characterId,
    characterName,
    appearanceCount,
    dialogueCount,
    const DeepCollectionEquality().hash(_chapterIds),
    screenTimePercentage,
  );

  /// Create a copy of CharacterAppearanceStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterAppearanceStatsImplCopyWith<_$CharacterAppearanceStatsImpl>
  get copyWith =>
      __$$CharacterAppearanceStatsImplCopyWithImpl<
        _$CharacterAppearanceStatsImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CharacterAppearanceStatsImplToJson(this);
  }
}

abstract class _CharacterAppearanceStats implements CharacterAppearanceStats {
  const factory _CharacterAppearanceStats({
    required final String characterId,
    required final String characterName,
    required final int appearanceCount,
    required final int dialogueCount,
    required final List<String> chapterIds,
    required final double screenTimePercentage,
  }) = _$CharacterAppearanceStatsImpl;

  factory _CharacterAppearanceStats.fromJson(Map<String, dynamic> json) =
      _$CharacterAppearanceStatsImpl.fromJson;

  @override
  String get characterId;
  @override
  String get characterName;
  @override
  int get appearanceCount;
  @override
  int get dialogueCount;
  @override
  List<String> get chapterIds;
  @override
  double get screenTimePercentage;

  /// Create a copy of CharacterAppearanceStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterAppearanceStatsImplCopyWith<_$CharacterAppearanceStatsImpl>
  get copyWith => throw _privateConstructorUsedError;
}

WritingGoal _$WritingGoalFromJson(Map<String, dynamic> json) {
  return _WritingGoal.fromJson(json);
}

/// @nodoc
mixin _$WritingGoal {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  GoalType get type => throw _privateConstructorUsedError;
  int get targetValue => throw _privateConstructorUsedError;
  int get currentValue => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime? get endDate => throw _privateConstructorUsedError;
  bool get isCompleted => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this WritingGoal to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WritingGoal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WritingGoalCopyWith<WritingGoal> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WritingGoalCopyWith<$Res> {
  factory $WritingGoalCopyWith(
    WritingGoal value,
    $Res Function(WritingGoal) then,
  ) = _$WritingGoalCopyWithImpl<$Res, WritingGoal>;
  @useResult
  $Res call({
    String id,
    String workId,
    GoalType type,
    int targetValue,
    int currentValue,
    DateTime startDate,
    DateTime? endDate,
    bool isCompleted,
    DateTime createdAt,
  });
}

/// @nodoc
class _$WritingGoalCopyWithImpl<$Res, $Val extends WritingGoal>
    implements $WritingGoalCopyWith<$Res> {
  _$WritingGoalCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WritingGoal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? type = null,
    Object? targetValue = null,
    Object? currentValue = null,
    Object? startDate = null,
    Object? endDate = freezed,
    Object? isCompleted = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            workId: null == workId
                ? _value.workId
                : workId // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as GoalType,
            targetValue: null == targetValue
                ? _value.targetValue
                : targetValue // ignore: cast_nullable_to_non_nullable
                      as int,
            currentValue: null == currentValue
                ? _value.currentValue
                : currentValue // ignore: cast_nullable_to_non_nullable
                      as int,
            startDate: null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endDate: freezed == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isCompleted: null == isCompleted
                ? _value.isCompleted
                : isCompleted // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WritingGoalImplCopyWith<$Res>
    implements $WritingGoalCopyWith<$Res> {
  factory _$$WritingGoalImplCopyWith(
    _$WritingGoalImpl value,
    $Res Function(_$WritingGoalImpl) then,
  ) = __$$WritingGoalImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String workId,
    GoalType type,
    int targetValue,
    int currentValue,
    DateTime startDate,
    DateTime? endDate,
    bool isCompleted,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$WritingGoalImplCopyWithImpl<$Res>
    extends _$WritingGoalCopyWithImpl<$Res, _$WritingGoalImpl>
    implements _$$WritingGoalImplCopyWith<$Res> {
  __$$WritingGoalImplCopyWithImpl(
    _$WritingGoalImpl _value,
    $Res Function(_$WritingGoalImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WritingGoal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? type = null,
    Object? targetValue = null,
    Object? currentValue = null,
    Object? startDate = null,
    Object? endDate = freezed,
    Object? isCompleted = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$WritingGoalImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        workId: null == workId
            ? _value.workId
            : workId // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as GoalType,
        targetValue: null == targetValue
            ? _value.targetValue
            : targetValue // ignore: cast_nullable_to_non_nullable
                  as int,
        currentValue: null == currentValue
            ? _value.currentValue
            : currentValue // ignore: cast_nullable_to_non_nullable
                  as int,
        startDate: null == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endDate: freezed == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isCompleted: null == isCompleted
            ? _value.isCompleted
            : isCompleted // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WritingGoalImpl implements _WritingGoal {
  const _$WritingGoalImpl({
    required this.id,
    required this.workId,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.startDate,
    required this.endDate,
    required this.isCompleted,
    required this.createdAt,
  });

  factory _$WritingGoalImpl.fromJson(Map<String, dynamic> json) =>
      _$$WritingGoalImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final GoalType type;
  @override
  final int targetValue;
  @override
  final int currentValue;
  @override
  final DateTime startDate;
  @override
  final DateTime? endDate;
  @override
  final bool isCompleted;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'WritingGoal(id: $id, workId: $workId, type: $type, targetValue: $targetValue, currentValue: $currentValue, startDate: $startDate, endDate: $endDate, isCompleted: $isCompleted, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WritingGoalImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.targetValue, targetValue) ||
                other.targetValue == targetValue) &&
            (identical(other.currentValue, currentValue) ||
                other.currentValue == currentValue) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    workId,
    type,
    targetValue,
    currentValue,
    startDate,
    endDate,
    isCompleted,
    createdAt,
  );

  /// Create a copy of WritingGoal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WritingGoalImplCopyWith<_$WritingGoalImpl> get copyWith =>
      __$$WritingGoalImplCopyWithImpl<_$WritingGoalImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WritingGoalImplToJson(this);
  }
}

abstract class _WritingGoal implements WritingGoal {
  const factory _WritingGoal({
    required final String id,
    required final String workId,
    required final GoalType type,
    required final int targetValue,
    required final int currentValue,
    required final DateTime startDate,
    required final DateTime? endDate,
    required final bool isCompleted,
    required final DateTime createdAt,
  }) = _$WritingGoalImpl;

  factory _WritingGoal.fromJson(Map<String, dynamic> json) =
      _$WritingGoalImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  GoalType get type;
  @override
  int get targetValue;
  @override
  int get currentValue;
  @override
  DateTime get startDate;
  @override
  DateTime? get endDate;
  @override
  bool get isCompleted;
  @override
  DateTime get createdAt;

  /// Create a copy of WritingGoal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WritingGoalImplCopyWith<_$WritingGoalImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WritingReport _$WritingReportFromJson(Map<String, dynamic> json) {
  return _WritingReport.fromJson(json);
}

/// @nodoc
mixin _$WritingReport {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  ReportPeriod get period => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  int get totalWords => throw _privateConstructorUsedError;
  int get averageDailyWords => throw _privateConstructorUsedError;
  int get writingDays => throw _privateConstructorUsedError;
  int get chaptersCompleted => throw _privateConstructorUsedError;
  int get chaptersPublished => throw _privateConstructorUsedError;
  List<DailyWordCount> get dailyBreakdown => throw _privateConstructorUsedError;
  Map<String, dynamic> get insights => throw _privateConstructorUsedError;
  DateTime get generatedAt => throw _privateConstructorUsedError;

  /// Serializes this WritingReport to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WritingReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WritingReportCopyWith<WritingReport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WritingReportCopyWith<$Res> {
  factory $WritingReportCopyWith(
    WritingReport value,
    $Res Function(WritingReport) then,
  ) = _$WritingReportCopyWithImpl<$Res, WritingReport>;
  @useResult
  $Res call({
    String id,
    String workId,
    ReportPeriod period,
    DateTime startDate,
    DateTime endDate,
    int totalWords,
    int averageDailyWords,
    int writingDays,
    int chaptersCompleted,
    int chaptersPublished,
    List<DailyWordCount> dailyBreakdown,
    Map<String, dynamic> insights,
    DateTime generatedAt,
  });
}

/// @nodoc
class _$WritingReportCopyWithImpl<$Res, $Val extends WritingReport>
    implements $WritingReportCopyWith<$Res> {
  _$WritingReportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WritingReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? period = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? totalWords = null,
    Object? averageDailyWords = null,
    Object? writingDays = null,
    Object? chaptersCompleted = null,
    Object? chaptersPublished = null,
    Object? dailyBreakdown = null,
    Object? insights = null,
    Object? generatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            workId: null == workId
                ? _value.workId
                : workId // ignore: cast_nullable_to_non_nullable
                      as String,
            period: null == period
                ? _value.period
                : period // ignore: cast_nullable_to_non_nullable
                      as ReportPeriod,
            startDate: null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endDate: null == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            totalWords: null == totalWords
                ? _value.totalWords
                : totalWords // ignore: cast_nullable_to_non_nullable
                      as int,
            averageDailyWords: null == averageDailyWords
                ? _value.averageDailyWords
                : averageDailyWords // ignore: cast_nullable_to_non_nullable
                      as int,
            writingDays: null == writingDays
                ? _value.writingDays
                : writingDays // ignore: cast_nullable_to_non_nullable
                      as int,
            chaptersCompleted: null == chaptersCompleted
                ? _value.chaptersCompleted
                : chaptersCompleted // ignore: cast_nullable_to_non_nullable
                      as int,
            chaptersPublished: null == chaptersPublished
                ? _value.chaptersPublished
                : chaptersPublished // ignore: cast_nullable_to_non_nullable
                      as int,
            dailyBreakdown: null == dailyBreakdown
                ? _value.dailyBreakdown
                : dailyBreakdown // ignore: cast_nullable_to_non_nullable
                      as List<DailyWordCount>,
            insights: null == insights
                ? _value.insights
                : insights // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            generatedAt: null == generatedAt
                ? _value.generatedAt
                : generatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WritingReportImplCopyWith<$Res>
    implements $WritingReportCopyWith<$Res> {
  factory _$$WritingReportImplCopyWith(
    _$WritingReportImpl value,
    $Res Function(_$WritingReportImpl) then,
  ) = __$$WritingReportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String workId,
    ReportPeriod period,
    DateTime startDate,
    DateTime endDate,
    int totalWords,
    int averageDailyWords,
    int writingDays,
    int chaptersCompleted,
    int chaptersPublished,
    List<DailyWordCount> dailyBreakdown,
    Map<String, dynamic> insights,
    DateTime generatedAt,
  });
}

/// @nodoc
class __$$WritingReportImplCopyWithImpl<$Res>
    extends _$WritingReportCopyWithImpl<$Res, _$WritingReportImpl>
    implements _$$WritingReportImplCopyWith<$Res> {
  __$$WritingReportImplCopyWithImpl(
    _$WritingReportImpl _value,
    $Res Function(_$WritingReportImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WritingReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? period = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? totalWords = null,
    Object? averageDailyWords = null,
    Object? writingDays = null,
    Object? chaptersCompleted = null,
    Object? chaptersPublished = null,
    Object? dailyBreakdown = null,
    Object? insights = null,
    Object? generatedAt = null,
  }) {
    return _then(
      _$WritingReportImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        workId: null == workId
            ? _value.workId
            : workId // ignore: cast_nullable_to_non_nullable
                  as String,
        period: null == period
            ? _value.period
            : period // ignore: cast_nullable_to_non_nullable
                  as ReportPeriod,
        startDate: null == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endDate: null == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        totalWords: null == totalWords
            ? _value.totalWords
            : totalWords // ignore: cast_nullable_to_non_nullable
                  as int,
        averageDailyWords: null == averageDailyWords
            ? _value.averageDailyWords
            : averageDailyWords // ignore: cast_nullable_to_non_nullable
                  as int,
        writingDays: null == writingDays
            ? _value.writingDays
            : writingDays // ignore: cast_nullable_to_non_nullable
                  as int,
        chaptersCompleted: null == chaptersCompleted
            ? _value.chaptersCompleted
            : chaptersCompleted // ignore: cast_nullable_to_non_nullable
                  as int,
        chaptersPublished: null == chaptersPublished
            ? _value.chaptersPublished
            : chaptersPublished // ignore: cast_nullable_to_non_nullable
                  as int,
        dailyBreakdown: null == dailyBreakdown
            ? _value._dailyBreakdown
            : dailyBreakdown // ignore: cast_nullable_to_non_nullable
                  as List<DailyWordCount>,
        insights: null == insights
            ? _value._insights
            : insights // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        generatedAt: null == generatedAt
            ? _value.generatedAt
            : generatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WritingReportImpl implements _WritingReport {
  const _$WritingReportImpl({
    required this.id,
    required this.workId,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalWords,
    required this.averageDailyWords,
    required this.writingDays,
    required this.chaptersCompleted,
    required this.chaptersPublished,
    required final List<DailyWordCount> dailyBreakdown,
    required final Map<String, dynamic> insights,
    required this.generatedAt,
  }) : _dailyBreakdown = dailyBreakdown,
       _insights = insights;

  factory _$WritingReportImpl.fromJson(Map<String, dynamic> json) =>
      _$$WritingReportImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final ReportPeriod period;
  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  @override
  final int totalWords;
  @override
  final int averageDailyWords;
  @override
  final int writingDays;
  @override
  final int chaptersCompleted;
  @override
  final int chaptersPublished;
  final List<DailyWordCount> _dailyBreakdown;
  @override
  List<DailyWordCount> get dailyBreakdown {
    if (_dailyBreakdown is EqualUnmodifiableListView) return _dailyBreakdown;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dailyBreakdown);
  }

  final Map<String, dynamic> _insights;
  @override
  Map<String, dynamic> get insights {
    if (_insights is EqualUnmodifiableMapView) return _insights;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_insights);
  }

  @override
  final DateTime generatedAt;

  @override
  String toString() {
    return 'WritingReport(id: $id, workId: $workId, period: $period, startDate: $startDate, endDate: $endDate, totalWords: $totalWords, averageDailyWords: $averageDailyWords, writingDays: $writingDays, chaptersCompleted: $chaptersCompleted, chaptersPublished: $chaptersPublished, dailyBreakdown: $dailyBreakdown, insights: $insights, generatedAt: $generatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WritingReportImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.period, period) || other.period == period) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.totalWords, totalWords) ||
                other.totalWords == totalWords) &&
            (identical(other.averageDailyWords, averageDailyWords) ||
                other.averageDailyWords == averageDailyWords) &&
            (identical(other.writingDays, writingDays) ||
                other.writingDays == writingDays) &&
            (identical(other.chaptersCompleted, chaptersCompleted) ||
                other.chaptersCompleted == chaptersCompleted) &&
            (identical(other.chaptersPublished, chaptersPublished) ||
                other.chaptersPublished == chaptersPublished) &&
            const DeepCollectionEquality().equals(
              other._dailyBreakdown,
              _dailyBreakdown,
            ) &&
            const DeepCollectionEquality().equals(other._insights, _insights) &&
            (identical(other.generatedAt, generatedAt) ||
                other.generatedAt == generatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    workId,
    period,
    startDate,
    endDate,
    totalWords,
    averageDailyWords,
    writingDays,
    chaptersCompleted,
    chaptersPublished,
    const DeepCollectionEquality().hash(_dailyBreakdown),
    const DeepCollectionEquality().hash(_insights),
    generatedAt,
  );

  /// Create a copy of WritingReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WritingReportImplCopyWith<_$WritingReportImpl> get copyWith =>
      __$$WritingReportImplCopyWithImpl<_$WritingReportImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WritingReportImplToJson(this);
  }
}

abstract class _WritingReport implements WritingReport {
  const factory _WritingReport({
    required final String id,
    required final String workId,
    required final ReportPeriod period,
    required final DateTime startDate,
    required final DateTime endDate,
    required final int totalWords,
    required final int averageDailyWords,
    required final int writingDays,
    required final int chaptersCompleted,
    required final int chaptersPublished,
    required final List<DailyWordCount> dailyBreakdown,
    required final Map<String, dynamic> insights,
    required final DateTime generatedAt,
  }) = _$WritingReportImpl;

  factory _WritingReport.fromJson(Map<String, dynamic> json) =
      _$WritingReportImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  ReportPeriod get period;
  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  int get totalWords;
  @override
  int get averageDailyWords;
  @override
  int get writingDays;
  @override
  int get chaptersCompleted;
  @override
  int get chaptersPublished;
  @override
  List<DailyWordCount> get dailyBreakdown;
  @override
  Map<String, dynamic> get insights;
  @override
  DateTime get generatedAt;

  /// Create a copy of WritingReport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WritingReportImplCopyWith<_$WritingReportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StatisticsExportOptions _$StatisticsExportOptionsFromJson(
  Map<String, dynamic> json,
) {
  return _StatisticsExportOptions.fromJson(json);
}

/// @nodoc
mixin _$StatisticsExportOptions {
  StatisticsExportFormat get format => throw _privateConstructorUsedError;
  bool get includeWorkStatistics => throw _privateConstructorUsedError;
  bool get includeWordCountTrend => throw _privateConstructorUsedError;
  bool get includeCharacterAppearances => throw _privateConstructorUsedError;
  bool get includeDailyBreakdown => throw _privateConstructorUsedError;
  bool get includeAIUsage => throw _privateConstructorUsedError;
  DateTime? get startDate => throw _privateConstructorUsedError;
  DateTime? get endDate => throw _privateConstructorUsedError;
  int? get days => throw _privateConstructorUsedError;

  /// Serializes this StatisticsExportOptions to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StatisticsExportOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatisticsExportOptionsCopyWith<StatisticsExportOptions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatisticsExportOptionsCopyWith<$Res> {
  factory $StatisticsExportOptionsCopyWith(
    StatisticsExportOptions value,
    $Res Function(StatisticsExportOptions) then,
  ) = _$StatisticsExportOptionsCopyWithImpl<$Res, StatisticsExportOptions>;
  @useResult
  $Res call({
    StatisticsExportFormat format,
    bool includeWorkStatistics,
    bool includeWordCountTrend,
    bool includeCharacterAppearances,
    bool includeDailyBreakdown,
    bool includeAIUsage,
    DateTime? startDate,
    DateTime? endDate,
    int? days,
  });
}

/// @nodoc
class _$StatisticsExportOptionsCopyWithImpl<
  $Res,
  $Val extends StatisticsExportOptions
>
    implements $StatisticsExportOptionsCopyWith<$Res> {
  _$StatisticsExportOptionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StatisticsExportOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? format = null,
    Object? includeWorkStatistics = null,
    Object? includeWordCountTrend = null,
    Object? includeCharacterAppearances = null,
    Object? includeDailyBreakdown = null,
    Object? includeAIUsage = null,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? days = freezed,
  }) {
    return _then(
      _value.copyWith(
            format: null == format
                ? _value.format
                : format // ignore: cast_nullable_to_non_nullable
                      as StatisticsExportFormat,
            includeWorkStatistics: null == includeWorkStatistics
                ? _value.includeWorkStatistics
                : includeWorkStatistics // ignore: cast_nullable_to_non_nullable
                      as bool,
            includeWordCountTrend: null == includeWordCountTrend
                ? _value.includeWordCountTrend
                : includeWordCountTrend // ignore: cast_nullable_to_non_nullable
                      as bool,
            includeCharacterAppearances: null == includeCharacterAppearances
                ? _value.includeCharacterAppearances
                : includeCharacterAppearances // ignore: cast_nullable_to_non_nullable
                      as bool,
            includeDailyBreakdown: null == includeDailyBreakdown
                ? _value.includeDailyBreakdown
                : includeDailyBreakdown // ignore: cast_nullable_to_non_nullable
                      as bool,
            includeAIUsage: null == includeAIUsage
                ? _value.includeAIUsage
                : includeAIUsage // ignore: cast_nullable_to_non_nullable
                      as bool,
            startDate: freezed == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            endDate: freezed == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            days: freezed == days
                ? _value.days
                : days // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StatisticsExportOptionsImplCopyWith<$Res>
    implements $StatisticsExportOptionsCopyWith<$Res> {
  factory _$$StatisticsExportOptionsImplCopyWith(
    _$StatisticsExportOptionsImpl value,
    $Res Function(_$StatisticsExportOptionsImpl) then,
  ) = __$$StatisticsExportOptionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    StatisticsExportFormat format,
    bool includeWorkStatistics,
    bool includeWordCountTrend,
    bool includeCharacterAppearances,
    bool includeDailyBreakdown,
    bool includeAIUsage,
    DateTime? startDate,
    DateTime? endDate,
    int? days,
  });
}

/// @nodoc
class __$$StatisticsExportOptionsImplCopyWithImpl<$Res>
    extends
        _$StatisticsExportOptionsCopyWithImpl<
          $Res,
          _$StatisticsExportOptionsImpl
        >
    implements _$$StatisticsExportOptionsImplCopyWith<$Res> {
  __$$StatisticsExportOptionsImplCopyWithImpl(
    _$StatisticsExportOptionsImpl _value,
    $Res Function(_$StatisticsExportOptionsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StatisticsExportOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? format = null,
    Object? includeWorkStatistics = null,
    Object? includeWordCountTrend = null,
    Object? includeCharacterAppearances = null,
    Object? includeDailyBreakdown = null,
    Object? includeAIUsage = null,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? days = freezed,
  }) {
    return _then(
      _$StatisticsExportOptionsImpl(
        format: null == format
            ? _value.format
            : format // ignore: cast_nullable_to_non_nullable
                  as StatisticsExportFormat,
        includeWorkStatistics: null == includeWorkStatistics
            ? _value.includeWorkStatistics
            : includeWorkStatistics // ignore: cast_nullable_to_non_nullable
                  as bool,
        includeWordCountTrend: null == includeWordCountTrend
            ? _value.includeWordCountTrend
            : includeWordCountTrend // ignore: cast_nullable_to_non_nullable
                  as bool,
        includeCharacterAppearances: null == includeCharacterAppearances
            ? _value.includeCharacterAppearances
            : includeCharacterAppearances // ignore: cast_nullable_to_non_nullable
                  as bool,
        includeDailyBreakdown: null == includeDailyBreakdown
            ? _value.includeDailyBreakdown
            : includeDailyBreakdown // ignore: cast_nullable_to_non_nullable
                  as bool,
        includeAIUsage: null == includeAIUsage
            ? _value.includeAIUsage
            : includeAIUsage // ignore: cast_nullable_to_non_nullable
                  as bool,
        startDate: freezed == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        endDate: freezed == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        days: freezed == days
            ? _value.days
            : days // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StatisticsExportOptionsImpl implements _StatisticsExportOptions {
  const _$StatisticsExportOptionsImpl({
    required this.format,
    this.includeWorkStatistics = true,
    this.includeWordCountTrend = true,
    this.includeCharacterAppearances = true,
    this.includeDailyBreakdown = true,
    this.includeAIUsage = false,
    this.startDate,
    this.endDate,
    this.days,
  });

  factory _$StatisticsExportOptionsImpl.fromJson(Map<String, dynamic> json) =>
      _$$StatisticsExportOptionsImplFromJson(json);

  @override
  final StatisticsExportFormat format;
  @override
  @JsonKey()
  final bool includeWorkStatistics;
  @override
  @JsonKey()
  final bool includeWordCountTrend;
  @override
  @JsonKey()
  final bool includeCharacterAppearances;
  @override
  @JsonKey()
  final bool includeDailyBreakdown;
  @override
  @JsonKey()
  final bool includeAIUsage;
  @override
  final DateTime? startDate;
  @override
  final DateTime? endDate;
  @override
  final int? days;

  @override
  String toString() {
    return 'StatisticsExportOptions(format: $format, includeWorkStatistics: $includeWorkStatistics, includeWordCountTrend: $includeWordCountTrend, includeCharacterAppearances: $includeCharacterAppearances, includeDailyBreakdown: $includeDailyBreakdown, includeAIUsage: $includeAIUsage, startDate: $startDate, endDate: $endDate, days: $days)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatisticsExportOptionsImpl &&
            (identical(other.format, format) || other.format == format) &&
            (identical(other.includeWorkStatistics, includeWorkStatistics) ||
                other.includeWorkStatistics == includeWorkStatistics) &&
            (identical(other.includeWordCountTrend, includeWordCountTrend) ||
                other.includeWordCountTrend == includeWordCountTrend) &&
            (identical(
                  other.includeCharacterAppearances,
                  includeCharacterAppearances,
                ) ||
                other.includeCharacterAppearances ==
                    includeCharacterAppearances) &&
            (identical(other.includeDailyBreakdown, includeDailyBreakdown) ||
                other.includeDailyBreakdown == includeDailyBreakdown) &&
            (identical(other.includeAIUsage, includeAIUsage) ||
                other.includeAIUsage == includeAIUsage) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.days, days) || other.days == days));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    format,
    includeWorkStatistics,
    includeWordCountTrend,
    includeCharacterAppearances,
    includeDailyBreakdown,
    includeAIUsage,
    startDate,
    endDate,
    days,
  );

  /// Create a copy of StatisticsExportOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatisticsExportOptionsImplCopyWith<_$StatisticsExportOptionsImpl>
  get copyWith =>
      __$$StatisticsExportOptionsImplCopyWithImpl<
        _$StatisticsExportOptionsImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StatisticsExportOptionsImplToJson(this);
  }
}

abstract class _StatisticsExportOptions implements StatisticsExportOptions {
  const factory _StatisticsExportOptions({
    required final StatisticsExportFormat format,
    final bool includeWorkStatistics,
    final bool includeWordCountTrend,
    final bool includeCharacterAppearances,
    final bool includeDailyBreakdown,
    final bool includeAIUsage,
    final DateTime? startDate,
    final DateTime? endDate,
    final int? days,
  }) = _$StatisticsExportOptionsImpl;

  factory _StatisticsExportOptions.fromJson(Map<String, dynamic> json) =
      _$StatisticsExportOptionsImpl.fromJson;

  @override
  StatisticsExportFormat get format;
  @override
  bool get includeWorkStatistics;
  @override
  bool get includeWordCountTrend;
  @override
  bool get includeCharacterAppearances;
  @override
  bool get includeDailyBreakdown;
  @override
  bool get includeAIUsage;
  @override
  DateTime? get startDate;
  @override
  DateTime? get endDate;
  @override
  int? get days;

  /// Create a copy of StatisticsExportOptions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatisticsExportOptionsImplCopyWith<_$StatisticsExportOptionsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
