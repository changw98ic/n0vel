// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ReviewResult {
  String get chapterId => throw _privateConstructorUsedError;
  String get chapterTitle => throw _privateConstructorUsedError;
  double? get score => throw _privateConstructorUsedError;
  int get issueCount => throw _privateConstructorUsedError;
  int get criticalCount => throw _privateConstructorUsedError;
  ReviewStatus get status => throw _privateConstructorUsedError;
  DateTime? get reviewedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ReviewResultCopyWith<ReviewResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewResultCopyWith<$Res> {
  factory $ReviewResultCopyWith(
          ReviewResult value, $Res Function(ReviewResult) then) =
      _$ReviewResultCopyWithImpl<$Res, ReviewResult>;
  @useResult
  $Res call(
      {String chapterId,
      String chapterTitle,
      double? score,
      int issueCount,
      int criticalCount,
      ReviewStatus status,
      DateTime? reviewedAt});
}

/// @nodoc
class _$ReviewResultCopyWithImpl<$Res, $Val extends ReviewResult>
    implements $ReviewResultCopyWith<$Res> {
  _$ReviewResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? chapterTitle = null,
    Object? score = freezed,
    Object? issueCount = null,
    Object? criticalCount = null,
    Object? status = null,
    Object? reviewedAt = freezed,
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
      score: freezed == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double?,
      issueCount: null == issueCount
          ? _value.issueCount
          : issueCount // ignore: cast_nullable_to_non_nullable
              as int,
      criticalCount: null == criticalCount
          ? _value.criticalCount
          : criticalCount // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ReviewStatus,
      reviewedAt: freezed == reviewedAt
          ? _value.reviewedAt
          : reviewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReviewResultImplCopyWith<$Res>
    implements $ReviewResultCopyWith<$Res> {
  factory _$$ReviewResultImplCopyWith(
          _$ReviewResultImpl value, $Res Function(_$ReviewResultImpl) then) =
      __$$ReviewResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String chapterId,
      String chapterTitle,
      double? score,
      int issueCount,
      int criticalCount,
      ReviewStatus status,
      DateTime? reviewedAt});
}

/// @nodoc
class __$$ReviewResultImplCopyWithImpl<$Res>
    extends _$ReviewResultCopyWithImpl<$Res, _$ReviewResultImpl>
    implements _$$ReviewResultImplCopyWith<$Res> {
  __$$ReviewResultImplCopyWithImpl(
      _$ReviewResultImpl _value, $Res Function(_$ReviewResultImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? chapterTitle = null,
    Object? score = freezed,
    Object? issueCount = null,
    Object? criticalCount = null,
    Object? status = null,
    Object? reviewedAt = freezed,
  }) {
    return _then(_$ReviewResultImpl(
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      chapterTitle: null == chapterTitle
          ? _value.chapterTitle
          : chapterTitle // ignore: cast_nullable_to_non_nullable
              as String,
      score: freezed == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double?,
      issueCount: null == issueCount
          ? _value.issueCount
          : issueCount // ignore: cast_nullable_to_non_nullable
              as int,
      criticalCount: null == criticalCount
          ? _value.criticalCount
          : criticalCount // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ReviewStatus,
      reviewedAt: freezed == reviewedAt
          ? _value.reviewedAt
          : reviewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$ReviewResultImpl implements _ReviewResult {
  const _$ReviewResultImpl(
      {required this.chapterId,
      required this.chapterTitle,
      this.score,
      this.issueCount = 0,
      this.criticalCount = 0,
      required this.status,
      this.reviewedAt});

  @override
  final String chapterId;
  @override
  final String chapterTitle;
  @override
  final double? score;
  @override
  @JsonKey()
  final int issueCount;
  @override
  @JsonKey()
  final int criticalCount;
  @override
  final ReviewStatus status;
  @override
  final DateTime? reviewedAt;

  @override
  String toString() {
    return 'ReviewResult(chapterId: $chapterId, chapterTitle: $chapterTitle, score: $score, issueCount: $issueCount, criticalCount: $criticalCount, status: $status, reviewedAt: $reviewedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewResultImpl &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.chapterTitle, chapterTitle) ||
                other.chapterTitle == chapterTitle) &&
            (identical(other.score, score) || other.score == score) &&
            (identical(other.issueCount, issueCount) ||
                other.issueCount == issueCount) &&
            (identical(other.criticalCount, criticalCount) ||
                other.criticalCount == criticalCount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chapterId, chapterTitle, score,
      issueCount, criticalCount, status, reviewedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewResultImplCopyWith<_$ReviewResultImpl> get copyWith =>
      __$$ReviewResultImplCopyWithImpl<_$ReviewResultImpl>(this, _$identity);
}

abstract class _ReviewResult implements ReviewResult {
  const factory _ReviewResult(
      {required final String chapterId,
      required final String chapterTitle,
      final double? score,
      final int issueCount,
      final int criticalCount,
      required final ReviewStatus status,
      final DateTime? reviewedAt}) = _$ReviewResultImpl;

  @override
  String get chapterId;
  @override
  String get chapterTitle;
  @override
  double? get score;
  @override
  int get issueCount;
  @override
  int get criticalCount;
  @override
  ReviewStatus get status;
  @override
  DateTime? get reviewedAt;
  @override
  @JsonKey(ignore: true)
  _$$ReviewResultImplCopyWith<_$ReviewResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DimensionScoreDetail {
  ReviewDimension get dimension => throw _privateConstructorUsedError;
  double get score => throw _privateConstructorUsedError;
  int get issueCount => throw _privateConstructorUsedError;
  String? get comment => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DimensionScoreDetailCopyWith<DimensionScoreDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DimensionScoreDetailCopyWith<$Res> {
  factory $DimensionScoreDetailCopyWith(DimensionScoreDetail value,
          $Res Function(DimensionScoreDetail) then) =
      _$DimensionScoreDetailCopyWithImpl<$Res, DimensionScoreDetail>;
  @useResult
  $Res call(
      {ReviewDimension dimension,
      double score,
      int issueCount,
      String? comment});
}

/// @nodoc
class _$DimensionScoreDetailCopyWithImpl<$Res,
        $Val extends DimensionScoreDetail>
    implements $DimensionScoreDetailCopyWith<$Res> {
  _$DimensionScoreDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dimension = null,
    Object? score = null,
    Object? issueCount = null,
    Object? comment = freezed,
  }) {
    return _then(_value.copyWith(
      dimension: null == dimension
          ? _value.dimension
          : dimension // ignore: cast_nullable_to_non_nullable
              as ReviewDimension,
      score: null == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double,
      issueCount: null == issueCount
          ? _value.issueCount
          : issueCount // ignore: cast_nullable_to_non_nullable
              as int,
      comment: freezed == comment
          ? _value.comment
          : comment // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DimensionScoreDetailImplCopyWith<$Res>
    implements $DimensionScoreDetailCopyWith<$Res> {
  factory _$$DimensionScoreDetailImplCopyWith(_$DimensionScoreDetailImpl value,
          $Res Function(_$DimensionScoreDetailImpl) then) =
      __$$DimensionScoreDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ReviewDimension dimension,
      double score,
      int issueCount,
      String? comment});
}

/// @nodoc
class __$$DimensionScoreDetailImplCopyWithImpl<$Res>
    extends _$DimensionScoreDetailCopyWithImpl<$Res, _$DimensionScoreDetailImpl>
    implements _$$DimensionScoreDetailImplCopyWith<$Res> {
  __$$DimensionScoreDetailImplCopyWithImpl(_$DimensionScoreDetailImpl _value,
      $Res Function(_$DimensionScoreDetailImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dimension = null,
    Object? score = null,
    Object? issueCount = null,
    Object? comment = freezed,
  }) {
    return _then(_$DimensionScoreDetailImpl(
      dimension: null == dimension
          ? _value.dimension
          : dimension // ignore: cast_nullable_to_non_nullable
              as ReviewDimension,
      score: null == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double,
      issueCount: null == issueCount
          ? _value.issueCount
          : issueCount // ignore: cast_nullable_to_non_nullable
              as int,
      comment: freezed == comment
          ? _value.comment
          : comment // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$DimensionScoreDetailImpl implements _DimensionScoreDetail {
  const _$DimensionScoreDetailImpl(
      {required this.dimension,
      required this.score,
      required this.issueCount,
      this.comment});

  @override
  final ReviewDimension dimension;
  @override
  final double score;
  @override
  final int issueCount;
  @override
  final String? comment;

  @override
  String toString() {
    return 'DimensionScoreDetail(dimension: $dimension, score: $score, issueCount: $issueCount, comment: $comment)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DimensionScoreDetailImpl &&
            (identical(other.dimension, dimension) ||
                other.dimension == dimension) &&
            (identical(other.score, score) || other.score == score) &&
            (identical(other.issueCount, issueCount) ||
                other.issueCount == issueCount) &&
            (identical(other.comment, comment) || other.comment == comment));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, dimension, score, issueCount, comment);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DimensionScoreDetailImplCopyWith<_$DimensionScoreDetailImpl>
      get copyWith =>
          __$$DimensionScoreDetailImplCopyWithImpl<_$DimensionScoreDetailImpl>(
              this, _$identity);
}

abstract class _DimensionScoreDetail implements DimensionScoreDetail {
  const factory _DimensionScoreDetail(
      {required final ReviewDimension dimension,
      required final double score,
      required final int issueCount,
      final String? comment}) = _$DimensionScoreDetailImpl;

  @override
  ReviewDimension get dimension;
  @override
  double get score;
  @override
  int get issueCount;
  @override
  String? get comment;
  @override
  @JsonKey(ignore: true)
  _$$DimensionScoreDetailImplCopyWith<_$DimensionScoreDetailImpl>
      get copyWith => throw _privateConstructorUsedError;
}
