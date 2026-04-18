// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'relationship.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RelationshipHead _$RelationshipHeadFromJson(Map<String, dynamic> json) {
  return _RelationshipHead.fromJson(json);
}

/// @nodoc
mixin _$RelationshipHead {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get characterAId => throw _privateConstructorUsedError; // id较小者
  String get characterBId => throw _privateConstructorUsedError; // id较大者
  RelationType get relationType => throw _privateConstructorUsedError;
  EmotionDimensions? get emotionDimensions =>
      throw _privateConstructorUsedError;
  String? get firstChapterId => throw _privateConstructorUsedError;
  String? get latestChapterId => throw _privateConstructorUsedError;
  int get eventCount => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this RelationshipHead to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RelationshipHead
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RelationshipHeadCopyWith<RelationshipHead> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RelationshipHeadCopyWith<$Res> {
  factory $RelationshipHeadCopyWith(
    RelationshipHead value,
    $Res Function(RelationshipHead) then,
  ) = _$RelationshipHeadCopyWithImpl<$Res, RelationshipHead>;
  @useResult
  $Res call({
    String id,
    String workId,
    String characterAId,
    String characterBId,
    RelationType relationType,
    EmotionDimensions? emotionDimensions,
    String? firstChapterId,
    String? latestChapterId,
    int eventCount,
    DateTime createdAt,
    DateTime updatedAt,
  });

  $EmotionDimensionsCopyWith<$Res>? get emotionDimensions;
}

/// @nodoc
class _$RelationshipHeadCopyWithImpl<$Res, $Val extends RelationshipHead>
    implements $RelationshipHeadCopyWith<$Res> {
  _$RelationshipHeadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RelationshipHead
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? characterAId = null,
    Object? characterBId = null,
    Object? relationType = null,
    Object? emotionDimensions = freezed,
    Object? firstChapterId = freezed,
    Object? latestChapterId = freezed,
    Object? eventCount = null,
    Object? createdAt = null,
    Object? updatedAt = null,
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
            characterAId: null == characterAId
                ? _value.characterAId
                : characterAId // ignore: cast_nullable_to_non_nullable
                      as String,
            characterBId: null == characterBId
                ? _value.characterBId
                : characterBId // ignore: cast_nullable_to_non_nullable
                      as String,
            relationType: null == relationType
                ? _value.relationType
                : relationType // ignore: cast_nullable_to_non_nullable
                      as RelationType,
            emotionDimensions: freezed == emotionDimensions
                ? _value.emotionDimensions
                : emotionDimensions // ignore: cast_nullable_to_non_nullable
                      as EmotionDimensions?,
            firstChapterId: freezed == firstChapterId
                ? _value.firstChapterId
                : firstChapterId // ignore: cast_nullable_to_non_nullable
                      as String?,
            latestChapterId: freezed == latestChapterId
                ? _value.latestChapterId
                : latestChapterId // ignore: cast_nullable_to_non_nullable
                      as String?,
            eventCount: null == eventCount
                ? _value.eventCount
                : eventCount // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }

  /// Create a copy of RelationshipHead
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EmotionDimensionsCopyWith<$Res>? get emotionDimensions {
    if (_value.emotionDimensions == null) {
      return null;
    }

    return $EmotionDimensionsCopyWith<$Res>(_value.emotionDimensions!, (value) {
      return _then(_value.copyWith(emotionDimensions: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RelationshipHeadImplCopyWith<$Res>
    implements $RelationshipHeadCopyWith<$Res> {
  factory _$$RelationshipHeadImplCopyWith(
    _$RelationshipHeadImpl value,
    $Res Function(_$RelationshipHeadImpl) then,
  ) = __$$RelationshipHeadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String workId,
    String characterAId,
    String characterBId,
    RelationType relationType,
    EmotionDimensions? emotionDimensions,
    String? firstChapterId,
    String? latestChapterId,
    int eventCount,
    DateTime createdAt,
    DateTime updatedAt,
  });

  @override
  $EmotionDimensionsCopyWith<$Res>? get emotionDimensions;
}

/// @nodoc
class __$$RelationshipHeadImplCopyWithImpl<$Res>
    extends _$RelationshipHeadCopyWithImpl<$Res, _$RelationshipHeadImpl>
    implements _$$RelationshipHeadImplCopyWith<$Res> {
  __$$RelationshipHeadImplCopyWithImpl(
    _$RelationshipHeadImpl _value,
    $Res Function(_$RelationshipHeadImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RelationshipHead
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? characterAId = null,
    Object? characterBId = null,
    Object? relationType = null,
    Object? emotionDimensions = freezed,
    Object? firstChapterId = freezed,
    Object? latestChapterId = freezed,
    Object? eventCount = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$RelationshipHeadImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        workId: null == workId
            ? _value.workId
            : workId // ignore: cast_nullable_to_non_nullable
                  as String,
        characterAId: null == characterAId
            ? _value.characterAId
            : characterAId // ignore: cast_nullable_to_non_nullable
                  as String,
        characterBId: null == characterBId
            ? _value.characterBId
            : characterBId // ignore: cast_nullable_to_non_nullable
                  as String,
        relationType: null == relationType
            ? _value.relationType
            : relationType // ignore: cast_nullable_to_non_nullable
                  as RelationType,
        emotionDimensions: freezed == emotionDimensions
            ? _value.emotionDimensions
            : emotionDimensions // ignore: cast_nullable_to_non_nullable
                  as EmotionDimensions?,
        firstChapterId: freezed == firstChapterId
            ? _value.firstChapterId
            : firstChapterId // ignore: cast_nullable_to_non_nullable
                  as String?,
        latestChapterId: freezed == latestChapterId
            ? _value.latestChapterId
            : latestChapterId // ignore: cast_nullable_to_non_nullable
                  as String?,
        eventCount: null == eventCount
            ? _value.eventCount
            : eventCount // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RelationshipHeadImpl extends _RelationshipHead {
  const _$RelationshipHeadImpl({
    required this.id,
    required this.workId,
    required this.characterAId,
    required this.characterBId,
    required this.relationType,
    this.emotionDimensions,
    this.firstChapterId,
    this.latestChapterId,
    this.eventCount = 0,
    required this.createdAt,
    required this.updatedAt,
  }) : super._();

  factory _$RelationshipHeadImpl.fromJson(Map<String, dynamic> json) =>
      _$$RelationshipHeadImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String characterAId;
  // id较小者
  @override
  final String characterBId;
  // id较大者
  @override
  final RelationType relationType;
  @override
  final EmotionDimensions? emotionDimensions;
  @override
  final String? firstChapterId;
  @override
  final String? latestChapterId;
  @override
  @JsonKey()
  final int eventCount;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'RelationshipHead(id: $id, workId: $workId, characterAId: $characterAId, characterBId: $characterBId, relationType: $relationType, emotionDimensions: $emotionDimensions, firstChapterId: $firstChapterId, latestChapterId: $latestChapterId, eventCount: $eventCount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RelationshipHeadImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.characterAId, characterAId) ||
                other.characterAId == characterAId) &&
            (identical(other.characterBId, characterBId) ||
                other.characterBId == characterBId) &&
            (identical(other.relationType, relationType) ||
                other.relationType == relationType) &&
            (identical(other.emotionDimensions, emotionDimensions) ||
                other.emotionDimensions == emotionDimensions) &&
            (identical(other.firstChapterId, firstChapterId) ||
                other.firstChapterId == firstChapterId) &&
            (identical(other.latestChapterId, latestChapterId) ||
                other.latestChapterId == latestChapterId) &&
            (identical(other.eventCount, eventCount) ||
                other.eventCount == eventCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    workId,
    characterAId,
    characterBId,
    relationType,
    emotionDimensions,
    firstChapterId,
    latestChapterId,
    eventCount,
    createdAt,
    updatedAt,
  );

  /// Create a copy of RelationshipHead
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RelationshipHeadImplCopyWith<_$RelationshipHeadImpl> get copyWith =>
      __$$RelationshipHeadImplCopyWithImpl<_$RelationshipHeadImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RelationshipHeadImplToJson(this);
  }
}

abstract class _RelationshipHead extends RelationshipHead {
  const factory _RelationshipHead({
    required final String id,
    required final String workId,
    required final String characterAId,
    required final String characterBId,
    required final RelationType relationType,
    final EmotionDimensions? emotionDimensions,
    final String? firstChapterId,
    final String? latestChapterId,
    final int eventCount,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$RelationshipHeadImpl;
  const _RelationshipHead._() : super._();

  factory _RelationshipHead.fromJson(Map<String, dynamic> json) =
      _$RelationshipHeadImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get characterAId; // id较小者
  @override
  String get characterBId; // id较大者
  @override
  RelationType get relationType;
  @override
  EmotionDimensions? get emotionDimensions;
  @override
  String? get firstChapterId;
  @override
  String? get latestChapterId;
  @override
  int get eventCount;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of RelationshipHead
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RelationshipHeadImplCopyWith<_$RelationshipHeadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RelationshipEvent _$RelationshipEventFromJson(Map<String, dynamic> json) {
  return _RelationshipEvent.fromJson(json);
}

/// @nodoc
mixin _$RelationshipEvent {
  String get id => throw _privateConstructorUsedError;
  String get headId => throw _privateConstructorUsedError;
  String get chapterId => throw _privateConstructorUsedError;
  ChangeType get changeType => throw _privateConstructorUsedError;
  RelationType? get prevRelationType => throw _privateConstructorUsedError;
  RelationType get newRelationType => throw _privateConstructorUsedError;
  EmotionDimensions? get prevEmotionDimensions =>
      throw _privateConstructorUsedError;
  EmotionDimensions? get newEmotionDimensions =>
      throw _privateConstructorUsedError;
  String? get changeReason => throw _privateConstructorUsedError;
  bool get isKeyEvent => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this RelationshipEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RelationshipEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RelationshipEventCopyWith<RelationshipEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RelationshipEventCopyWith<$Res> {
  factory $RelationshipEventCopyWith(
    RelationshipEvent value,
    $Res Function(RelationshipEvent) then,
  ) = _$RelationshipEventCopyWithImpl<$Res, RelationshipEvent>;
  @useResult
  $Res call({
    String id,
    String headId,
    String chapterId,
    ChangeType changeType,
    RelationType? prevRelationType,
    RelationType newRelationType,
    EmotionDimensions? prevEmotionDimensions,
    EmotionDimensions? newEmotionDimensions,
    String? changeReason,
    bool isKeyEvent,
    DateTime createdAt,
  });

  $EmotionDimensionsCopyWith<$Res>? get prevEmotionDimensions;
  $EmotionDimensionsCopyWith<$Res>? get newEmotionDimensions;
}

/// @nodoc
class _$RelationshipEventCopyWithImpl<$Res, $Val extends RelationshipEvent>
    implements $RelationshipEventCopyWith<$Res> {
  _$RelationshipEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RelationshipEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? headId = null,
    Object? chapterId = null,
    Object? changeType = null,
    Object? prevRelationType = freezed,
    Object? newRelationType = null,
    Object? prevEmotionDimensions = freezed,
    Object? newEmotionDimensions = freezed,
    Object? changeReason = freezed,
    Object? isKeyEvent = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            headId: null == headId
                ? _value.headId
                : headId // ignore: cast_nullable_to_non_nullable
                      as String,
            chapterId: null == chapterId
                ? _value.chapterId
                : chapterId // ignore: cast_nullable_to_non_nullable
                      as String,
            changeType: null == changeType
                ? _value.changeType
                : changeType // ignore: cast_nullable_to_non_nullable
                      as ChangeType,
            prevRelationType: freezed == prevRelationType
                ? _value.prevRelationType
                : prevRelationType // ignore: cast_nullable_to_non_nullable
                      as RelationType?,
            newRelationType: null == newRelationType
                ? _value.newRelationType
                : newRelationType // ignore: cast_nullable_to_non_nullable
                      as RelationType,
            prevEmotionDimensions: freezed == prevEmotionDimensions
                ? _value.prevEmotionDimensions
                : prevEmotionDimensions // ignore: cast_nullable_to_non_nullable
                      as EmotionDimensions?,
            newEmotionDimensions: freezed == newEmotionDimensions
                ? _value.newEmotionDimensions
                : newEmotionDimensions // ignore: cast_nullable_to_non_nullable
                      as EmotionDimensions?,
            changeReason: freezed == changeReason
                ? _value.changeReason
                : changeReason // ignore: cast_nullable_to_non_nullable
                      as String?,
            isKeyEvent: null == isKeyEvent
                ? _value.isKeyEvent
                : isKeyEvent // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }

  /// Create a copy of RelationshipEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EmotionDimensionsCopyWith<$Res>? get prevEmotionDimensions {
    if (_value.prevEmotionDimensions == null) {
      return null;
    }

    return $EmotionDimensionsCopyWith<$Res>(_value.prevEmotionDimensions!, (
      value,
    ) {
      return _then(_value.copyWith(prevEmotionDimensions: value) as $Val);
    });
  }

  /// Create a copy of RelationshipEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EmotionDimensionsCopyWith<$Res>? get newEmotionDimensions {
    if (_value.newEmotionDimensions == null) {
      return null;
    }

    return $EmotionDimensionsCopyWith<$Res>(_value.newEmotionDimensions!, (
      value,
    ) {
      return _then(_value.copyWith(newEmotionDimensions: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RelationshipEventImplCopyWith<$Res>
    implements $RelationshipEventCopyWith<$Res> {
  factory _$$RelationshipEventImplCopyWith(
    _$RelationshipEventImpl value,
    $Res Function(_$RelationshipEventImpl) then,
  ) = __$$RelationshipEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String headId,
    String chapterId,
    ChangeType changeType,
    RelationType? prevRelationType,
    RelationType newRelationType,
    EmotionDimensions? prevEmotionDimensions,
    EmotionDimensions? newEmotionDimensions,
    String? changeReason,
    bool isKeyEvent,
    DateTime createdAt,
  });

  @override
  $EmotionDimensionsCopyWith<$Res>? get prevEmotionDimensions;
  @override
  $EmotionDimensionsCopyWith<$Res>? get newEmotionDimensions;
}

/// @nodoc
class __$$RelationshipEventImplCopyWithImpl<$Res>
    extends _$RelationshipEventCopyWithImpl<$Res, _$RelationshipEventImpl>
    implements _$$RelationshipEventImplCopyWith<$Res> {
  __$$RelationshipEventImplCopyWithImpl(
    _$RelationshipEventImpl _value,
    $Res Function(_$RelationshipEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RelationshipEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? headId = null,
    Object? chapterId = null,
    Object? changeType = null,
    Object? prevRelationType = freezed,
    Object? newRelationType = null,
    Object? prevEmotionDimensions = freezed,
    Object? newEmotionDimensions = freezed,
    Object? changeReason = freezed,
    Object? isKeyEvent = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$RelationshipEventImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        headId: null == headId
            ? _value.headId
            : headId // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterId: null == chapterId
            ? _value.chapterId
            : chapterId // ignore: cast_nullable_to_non_nullable
                  as String,
        changeType: null == changeType
            ? _value.changeType
            : changeType // ignore: cast_nullable_to_non_nullable
                  as ChangeType,
        prevRelationType: freezed == prevRelationType
            ? _value.prevRelationType
            : prevRelationType // ignore: cast_nullable_to_non_nullable
                  as RelationType?,
        newRelationType: null == newRelationType
            ? _value.newRelationType
            : newRelationType // ignore: cast_nullable_to_non_nullable
                  as RelationType,
        prevEmotionDimensions: freezed == prevEmotionDimensions
            ? _value.prevEmotionDimensions
            : prevEmotionDimensions // ignore: cast_nullable_to_non_nullable
                  as EmotionDimensions?,
        newEmotionDimensions: freezed == newEmotionDimensions
            ? _value.newEmotionDimensions
            : newEmotionDimensions // ignore: cast_nullable_to_non_nullable
                  as EmotionDimensions?,
        changeReason: freezed == changeReason
            ? _value.changeReason
            : changeReason // ignore: cast_nullable_to_non_nullable
                  as String?,
        isKeyEvent: null == isKeyEvent
            ? _value.isKeyEvent
            : isKeyEvent // ignore: cast_nullable_to_non_nullable
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
class _$RelationshipEventImpl extends _RelationshipEvent {
  const _$RelationshipEventImpl({
    required this.id,
    required this.headId,
    required this.chapterId,
    required this.changeType,
    this.prevRelationType,
    required this.newRelationType,
    this.prevEmotionDimensions,
    this.newEmotionDimensions,
    this.changeReason,
    this.isKeyEvent = false,
    required this.createdAt,
  }) : super._();

  factory _$RelationshipEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$RelationshipEventImplFromJson(json);

  @override
  final String id;
  @override
  final String headId;
  @override
  final String chapterId;
  @override
  final ChangeType changeType;
  @override
  final RelationType? prevRelationType;
  @override
  final RelationType newRelationType;
  @override
  final EmotionDimensions? prevEmotionDimensions;
  @override
  final EmotionDimensions? newEmotionDimensions;
  @override
  final String? changeReason;
  @override
  @JsonKey()
  final bool isKeyEvent;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'RelationshipEvent(id: $id, headId: $headId, chapterId: $chapterId, changeType: $changeType, prevRelationType: $prevRelationType, newRelationType: $newRelationType, prevEmotionDimensions: $prevEmotionDimensions, newEmotionDimensions: $newEmotionDimensions, changeReason: $changeReason, isKeyEvent: $isKeyEvent, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RelationshipEventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.headId, headId) || other.headId == headId) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.changeType, changeType) ||
                other.changeType == changeType) &&
            (identical(other.prevRelationType, prevRelationType) ||
                other.prevRelationType == prevRelationType) &&
            (identical(other.newRelationType, newRelationType) ||
                other.newRelationType == newRelationType) &&
            (identical(other.prevEmotionDimensions, prevEmotionDimensions) ||
                other.prevEmotionDimensions == prevEmotionDimensions) &&
            (identical(other.newEmotionDimensions, newEmotionDimensions) ||
                other.newEmotionDimensions == newEmotionDimensions) &&
            (identical(other.changeReason, changeReason) ||
                other.changeReason == changeReason) &&
            (identical(other.isKeyEvent, isKeyEvent) ||
                other.isKeyEvent == isKeyEvent) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    headId,
    chapterId,
    changeType,
    prevRelationType,
    newRelationType,
    prevEmotionDimensions,
    newEmotionDimensions,
    changeReason,
    isKeyEvent,
    createdAt,
  );

  /// Create a copy of RelationshipEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RelationshipEventImplCopyWith<_$RelationshipEventImpl> get copyWith =>
      __$$RelationshipEventImplCopyWithImpl<_$RelationshipEventImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RelationshipEventImplToJson(this);
  }
}

abstract class _RelationshipEvent extends RelationshipEvent {
  const factory _RelationshipEvent({
    required final String id,
    required final String headId,
    required final String chapterId,
    required final ChangeType changeType,
    final RelationType? prevRelationType,
    required final RelationType newRelationType,
    final EmotionDimensions? prevEmotionDimensions,
    final EmotionDimensions? newEmotionDimensions,
    final String? changeReason,
    final bool isKeyEvent,
    required final DateTime createdAt,
  }) = _$RelationshipEventImpl;
  const _RelationshipEvent._() : super._();

  factory _RelationshipEvent.fromJson(Map<String, dynamic> json) =
      _$RelationshipEventImpl.fromJson;

  @override
  String get id;
  @override
  String get headId;
  @override
  String get chapterId;
  @override
  ChangeType get changeType;
  @override
  RelationType? get prevRelationType;
  @override
  RelationType get newRelationType;
  @override
  EmotionDimensions? get prevEmotionDimensions;
  @override
  EmotionDimensions? get newEmotionDimensions;
  @override
  String? get changeReason;
  @override
  bool get isKeyEvent;
  @override
  DateTime get createdAt;

  /// Create a copy of RelationshipEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RelationshipEventImplCopyWith<_$RelationshipEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
