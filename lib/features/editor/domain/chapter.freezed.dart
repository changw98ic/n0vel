// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chapter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Chapter _$ChapterFromJson(Map<String, dynamic> json) {
  return _Chapter.fromJson(json);
}

/// @nodoc
mixin _$Chapter {
  String get id => throw _privateConstructorUsedError;
  String get volumeId => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  int get wordCount => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;
  ChapterStatus get status => throw _privateConstructorUsedError;
  double? get reviewScore => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChapterCopyWith<Chapter> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChapterCopyWith<$Res> {
  factory $ChapterCopyWith(Chapter value, $Res Function(Chapter) then) =
      _$ChapterCopyWithImpl<$Res, Chapter>;
  @useResult
  $Res call(
      {String id,
      String volumeId,
      String workId,
      String title,
      String? content,
      int wordCount,
      int sortOrder,
      ChapterStatus status,
      double? reviewScore,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$ChapterCopyWithImpl<$Res, $Val extends Chapter>
    implements $ChapterCopyWith<$Res> {
  _$ChapterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? volumeId = null,
    Object? workId = null,
    Object? title = null,
    Object? content = freezed,
    Object? wordCount = null,
    Object? sortOrder = null,
    Object? status = null,
    Object? reviewScore = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      volumeId: null == volumeId
          ? _value.volumeId
          : volumeId // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      wordCount: null == wordCount
          ? _value.wordCount
          : wordCount // ignore: cast_nullable_to_non_nullable
              as int,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ChapterStatus,
      reviewScore: freezed == reviewScore
          ? _value.reviewScore
          : reviewScore // ignore: cast_nullable_to_non_nullable
              as double?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChapterImplCopyWith<$Res> implements $ChapterCopyWith<$Res> {
  factory _$$ChapterImplCopyWith(
          _$ChapterImpl value, $Res Function(_$ChapterImpl) then) =
      __$$ChapterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String volumeId,
      String workId,
      String title,
      String? content,
      int wordCount,
      int sortOrder,
      ChapterStatus status,
      double? reviewScore,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$ChapterImplCopyWithImpl<$Res>
    extends _$ChapterCopyWithImpl<$Res, _$ChapterImpl>
    implements _$$ChapterImplCopyWith<$Res> {
  __$$ChapterImplCopyWithImpl(
      _$ChapterImpl _value, $Res Function(_$ChapterImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? volumeId = null,
    Object? workId = null,
    Object? title = null,
    Object? content = freezed,
    Object? wordCount = null,
    Object? sortOrder = null,
    Object? status = null,
    Object? reviewScore = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$ChapterImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      volumeId: null == volumeId
          ? _value.volumeId
          : volumeId // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      wordCount: null == wordCount
          ? _value.wordCount
          : wordCount // ignore: cast_nullable_to_non_nullable
              as int,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ChapterStatus,
      reviewScore: freezed == reviewScore
          ? _value.reviewScore
          : reviewScore // ignore: cast_nullable_to_non_nullable
              as double?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChapterImpl extends _Chapter {
  const _$ChapterImpl(
      {required this.id,
      required this.volumeId,
      required this.workId,
      required this.title,
      this.content,
      this.wordCount = 0,
      this.sortOrder = 0,
      this.status = ChapterStatus.draft,
      this.reviewScore,
      required this.createdAt,
      required this.updatedAt})
      : super._();

  factory _$ChapterImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChapterImplFromJson(json);

  @override
  final String id;
  @override
  final String volumeId;
  @override
  final String workId;
  @override
  final String title;
  @override
  final String? content;
  @override
  @JsonKey()
  final int wordCount;
  @override
  @JsonKey()
  final int sortOrder;
  @override
  @JsonKey()
  final ChapterStatus status;
  @override
  final double? reviewScore;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Chapter(id: $id, volumeId: $volumeId, workId: $workId, title: $title, content: $content, wordCount: $wordCount, sortOrder: $sortOrder, status: $status, reviewScore: $reviewScore, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChapterImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.volumeId, volumeId) ||
                other.volumeId == volumeId) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.reviewScore, reviewScore) ||
                other.reviewScore == reviewScore) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, volumeId, workId, title,
      content, wordCount, sortOrder, status, reviewScore, createdAt, updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChapterImplCopyWith<_$ChapterImpl> get copyWith =>
      __$$ChapterImplCopyWithImpl<_$ChapterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChapterImplToJson(
      this,
    );
  }
}

abstract class _Chapter extends Chapter {
  const factory _Chapter(
      {required final String id,
      required final String volumeId,
      required final String workId,
      required final String title,
      final String? content,
      final int wordCount,
      final int sortOrder,
      final ChapterStatus status,
      final double? reviewScore,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$ChapterImpl;
  const _Chapter._() : super._();

  factory _Chapter.fromJson(Map<String, dynamic> json) = _$ChapterImpl.fromJson;

  @override
  String get id;
  @override
  String get volumeId;
  @override
  String get workId;
  @override
  String get title;
  @override
  String? get content;
  @override
  int get wordCount;
  @override
  int get sortOrder;
  @override
  ChapterStatus get status;
  @override
  double? get reviewScore;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$ChapterImplCopyWith<_$ChapterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Segment _$SegmentFromJson(Map<String, dynamic> json) {
  return _Segment.fromJson(json);
}

/// @nodoc
mixin _$Segment {
  String get id => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  SegmentType get type => throw _privateConstructorUsedError;
  bool get needsIndent => throw _privateConstructorUsedError;
  String? get speakerId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SegmentCopyWith<Segment> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SegmentCopyWith<$Res> {
  factory $SegmentCopyWith(Segment value, $Res Function(Segment) then) =
      _$SegmentCopyWithImpl<$Res, Segment>;
  @useResult
  $Res call(
      {String id,
      String text,
      SegmentType type,
      bool needsIndent,
      String? speakerId});
}

/// @nodoc
class _$SegmentCopyWithImpl<$Res, $Val extends Segment>
    implements $SegmentCopyWith<$Res> {
  _$SegmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? type = null,
    Object? needsIndent = null,
    Object? speakerId = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SegmentType,
      needsIndent: null == needsIndent
          ? _value.needsIndent
          : needsIndent // ignore: cast_nullable_to_non_nullable
              as bool,
      speakerId: freezed == speakerId
          ? _value.speakerId
          : speakerId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SegmentImplCopyWith<$Res> implements $SegmentCopyWith<$Res> {
  factory _$$SegmentImplCopyWith(
          _$SegmentImpl value, $Res Function(_$SegmentImpl) then) =
      __$$SegmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String text,
      SegmentType type,
      bool needsIndent,
      String? speakerId});
}

/// @nodoc
class __$$SegmentImplCopyWithImpl<$Res>
    extends _$SegmentCopyWithImpl<$Res, _$SegmentImpl>
    implements _$$SegmentImplCopyWith<$Res> {
  __$$SegmentImplCopyWithImpl(
      _$SegmentImpl _value, $Res Function(_$SegmentImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? type = null,
    Object? needsIndent = null,
    Object? speakerId = freezed,
  }) {
    return _then(_$SegmentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SegmentType,
      needsIndent: null == needsIndent
          ? _value.needsIndent
          : needsIndent // ignore: cast_nullable_to_non_nullable
              as bool,
      speakerId: freezed == speakerId
          ? _value.speakerId
          : speakerId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SegmentImpl extends _Segment {
  const _$SegmentImpl(
      {required this.id,
      required this.text,
      required this.type,
      this.needsIndent = false,
      this.speakerId})
      : super._();

  factory _$SegmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$SegmentImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  final SegmentType type;
  @override
  @JsonKey()
  final bool needsIndent;
  @override
  final String? speakerId;

  @override
  String toString() {
    return 'Segment(id: $id, text: $text, type: $type, needsIndent: $needsIndent, speakerId: $speakerId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SegmentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.needsIndent, needsIndent) ||
                other.needsIndent == needsIndent) &&
            (identical(other.speakerId, speakerId) ||
                other.speakerId == speakerId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, text, type, needsIndent, speakerId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SegmentImplCopyWith<_$SegmentImpl> get copyWith =>
      __$$SegmentImplCopyWithImpl<_$SegmentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SegmentImplToJson(
      this,
    );
  }
}

abstract class _Segment extends Segment {
  const factory _Segment(
      {required final String id,
      required final String text,
      required final SegmentType type,
      final bool needsIndent,
      final String? speakerId}) = _$SegmentImpl;
  const _Segment._() : super._();

  factory _Segment.fromJson(Map<String, dynamic> json) = _$SegmentImpl.fromJson;

  @override
  String get id;
  @override
  String get text;
  @override
  SegmentType get type;
  @override
  bool get needsIndent;
  @override
  String? get speakerId;
  @override
  @JsonKey(ignore: true)
  _$$SegmentImplCopyWith<_$SegmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
