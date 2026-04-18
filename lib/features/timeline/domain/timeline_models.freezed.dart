// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'timeline_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

StoryEvent _$StoryEventFromJson(Map<String, dynamic> json) {
  return _StoryEvent.fromJson(json);
}

/// @nodoc
mixin _$StoryEvent {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  EventType get type => throw _privateConstructorUsedError;
  EventImportance get importance => throw _privateConstructorUsedError; // 时间定位
  String? get storyTime =>
      throw _privateConstructorUsedError; // 故事内时间（如：天元历1245年春）
  String? get relativeTime =>
      throw _privateConstructorUsedError; // 相对时间（如：入门后第156天）
  String? get chapterId => throw _privateConstructorUsedError; // 发生章节
  int? get chapterPosition => throw _privateConstructorUsedError; // 章节内位置
  // 地点和角色
  String? get locationId => throw _privateConstructorUsedError;
  List<String> get characterIds => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get consequences => throw _privateConstructorUsedError; // 事件关联
  String? get predecessorId => throw _privateConstructorUsedError;
  String? get successorId => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this StoryEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StoryEventCopyWith<StoryEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StoryEventCopyWith<$Res> {
  factory $StoryEventCopyWith(
    StoryEvent value,
    $Res Function(StoryEvent) then,
  ) = _$StoryEventCopyWithImpl<$Res, StoryEvent>;
  @useResult
  $Res call({
    String id,
    String workId,
    String name,
    EventType type,
    EventImportance importance,
    String? storyTime,
    String? relativeTime,
    String? chapterId,
    int? chapterPosition,
    String? locationId,
    List<String> characterIds,
    String? description,
    String? consequences,
    String? predecessorId,
    String? successorId,
    DateTime createdAt,
  });
}

/// @nodoc
class _$StoryEventCopyWithImpl<$Res, $Val extends StoryEvent>
    implements $StoryEventCopyWith<$Res> {
  _$StoryEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? type = null,
    Object? importance = null,
    Object? storyTime = freezed,
    Object? relativeTime = freezed,
    Object? chapterId = freezed,
    Object? chapterPosition = freezed,
    Object? locationId = freezed,
    Object? characterIds = null,
    Object? description = freezed,
    Object? consequences = freezed,
    Object? predecessorId = freezed,
    Object? successorId = freezed,
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
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as EventType,
            importance: null == importance
                ? _value.importance
                : importance // ignore: cast_nullable_to_non_nullable
                      as EventImportance,
            storyTime: freezed == storyTime
                ? _value.storyTime
                : storyTime // ignore: cast_nullable_to_non_nullable
                      as String?,
            relativeTime: freezed == relativeTime
                ? _value.relativeTime
                : relativeTime // ignore: cast_nullable_to_non_nullable
                      as String?,
            chapterId: freezed == chapterId
                ? _value.chapterId
                : chapterId // ignore: cast_nullable_to_non_nullable
                      as String?,
            chapterPosition: freezed == chapterPosition
                ? _value.chapterPosition
                : chapterPosition // ignore: cast_nullable_to_non_nullable
                      as int?,
            locationId: freezed == locationId
                ? _value.locationId
                : locationId // ignore: cast_nullable_to_non_nullable
                      as String?,
            characterIds: null == characterIds
                ? _value.characterIds
                : characterIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            consequences: freezed == consequences
                ? _value.consequences
                : consequences // ignore: cast_nullable_to_non_nullable
                      as String?,
            predecessorId: freezed == predecessorId
                ? _value.predecessorId
                : predecessorId // ignore: cast_nullable_to_non_nullable
                      as String?,
            successorId: freezed == successorId
                ? _value.successorId
                : successorId // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$StoryEventImplCopyWith<$Res>
    implements $StoryEventCopyWith<$Res> {
  factory _$$StoryEventImplCopyWith(
    _$StoryEventImpl value,
    $Res Function(_$StoryEventImpl) then,
  ) = __$$StoryEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String workId,
    String name,
    EventType type,
    EventImportance importance,
    String? storyTime,
    String? relativeTime,
    String? chapterId,
    int? chapterPosition,
    String? locationId,
    List<String> characterIds,
    String? description,
    String? consequences,
    String? predecessorId,
    String? successorId,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$StoryEventImplCopyWithImpl<$Res>
    extends _$StoryEventCopyWithImpl<$Res, _$StoryEventImpl>
    implements _$$StoryEventImplCopyWith<$Res> {
  __$$StoryEventImplCopyWithImpl(
    _$StoryEventImpl _value,
    $Res Function(_$StoryEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? type = null,
    Object? importance = null,
    Object? storyTime = freezed,
    Object? relativeTime = freezed,
    Object? chapterId = freezed,
    Object? chapterPosition = freezed,
    Object? locationId = freezed,
    Object? characterIds = null,
    Object? description = freezed,
    Object? consequences = freezed,
    Object? predecessorId = freezed,
    Object? successorId = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$StoryEventImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        workId: null == workId
            ? _value.workId
            : workId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as EventType,
        importance: null == importance
            ? _value.importance
            : importance // ignore: cast_nullable_to_non_nullable
                  as EventImportance,
        storyTime: freezed == storyTime
            ? _value.storyTime
            : storyTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        relativeTime: freezed == relativeTime
            ? _value.relativeTime
            : relativeTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterId: freezed == chapterId
            ? _value.chapterId
            : chapterId // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterPosition: freezed == chapterPosition
            ? _value.chapterPosition
            : chapterPosition // ignore: cast_nullable_to_non_nullable
                  as int?,
        locationId: freezed == locationId
            ? _value.locationId
            : locationId // ignore: cast_nullable_to_non_nullable
                  as String?,
        characterIds: null == characterIds
            ? _value._characterIds
            : characterIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        consequences: freezed == consequences
            ? _value.consequences
            : consequences // ignore: cast_nullable_to_non_nullable
                  as String?,
        predecessorId: freezed == predecessorId
            ? _value.predecessorId
            : predecessorId // ignore: cast_nullable_to_non_nullable
                  as String?,
        successorId: freezed == successorId
            ? _value.successorId
            : successorId // ignore: cast_nullable_to_non_nullable
                  as String?,
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
class _$StoryEventImpl extends _StoryEvent {
  const _$StoryEventImpl({
    required this.id,
    required this.workId,
    required this.name,
    this.type = EventType.main,
    this.importance = EventImportance.normal,
    this.storyTime,
    this.relativeTime,
    this.chapterId,
    this.chapterPosition,
    this.locationId,
    final List<String> characterIds = const [],
    this.description,
    this.consequences,
    this.predecessorId,
    this.successorId,
    required this.createdAt,
  }) : _characterIds = characterIds,
       super._();

  factory _$StoryEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$StoryEventImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String name;
  @override
  @JsonKey()
  final EventType type;
  @override
  @JsonKey()
  final EventImportance importance;
  // 时间定位
  @override
  final String? storyTime;
  // 故事内时间（如：天元历1245年春）
  @override
  final String? relativeTime;
  // 相对时间（如：入门后第156天）
  @override
  final String? chapterId;
  // 发生章节
  @override
  final int? chapterPosition;
  // 章节内位置
  // 地点和角色
  @override
  final String? locationId;
  final List<String> _characterIds;
  @override
  @JsonKey()
  List<String> get characterIds {
    if (_characterIds is EqualUnmodifiableListView) return _characterIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_characterIds);
  }

  @override
  final String? description;
  @override
  final String? consequences;
  // 事件关联
  @override
  final String? predecessorId;
  @override
  final String? successorId;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'StoryEvent(id: $id, workId: $workId, name: $name, type: $type, importance: $importance, storyTime: $storyTime, relativeTime: $relativeTime, chapterId: $chapterId, chapterPosition: $chapterPosition, locationId: $locationId, characterIds: $characterIds, description: $description, consequences: $consequences, predecessorId: $predecessorId, successorId: $successorId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StoryEventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.importance, importance) ||
                other.importance == importance) &&
            (identical(other.storyTime, storyTime) ||
                other.storyTime == storyTime) &&
            (identical(other.relativeTime, relativeTime) ||
                other.relativeTime == relativeTime) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.chapterPosition, chapterPosition) ||
                other.chapterPosition == chapterPosition) &&
            (identical(other.locationId, locationId) ||
                other.locationId == locationId) &&
            const DeepCollectionEquality().equals(
              other._characterIds,
              _characterIds,
            ) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.consequences, consequences) ||
                other.consequences == consequences) &&
            (identical(other.predecessorId, predecessorId) ||
                other.predecessorId == predecessorId) &&
            (identical(other.successorId, successorId) ||
                other.successorId == successorId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    workId,
    name,
    type,
    importance,
    storyTime,
    relativeTime,
    chapterId,
    chapterPosition,
    locationId,
    const DeepCollectionEquality().hash(_characterIds),
    description,
    consequences,
    predecessorId,
    successorId,
    createdAt,
  );

  /// Create a copy of StoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StoryEventImplCopyWith<_$StoryEventImpl> get copyWith =>
      __$$StoryEventImplCopyWithImpl<_$StoryEventImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StoryEventImplToJson(this);
  }
}

abstract class _StoryEvent extends StoryEvent {
  const factory _StoryEvent({
    required final String id,
    required final String workId,
    required final String name,
    final EventType type,
    final EventImportance importance,
    final String? storyTime,
    final String? relativeTime,
    final String? chapterId,
    final int? chapterPosition,
    final String? locationId,
    final List<String> characterIds,
    final String? description,
    final String? consequences,
    final String? predecessorId,
    final String? successorId,
    required final DateTime createdAt,
  }) = _$StoryEventImpl;
  const _StoryEvent._() : super._();

  factory _StoryEvent.fromJson(Map<String, dynamic> json) =
      _$StoryEventImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get name;
  @override
  EventType get type;
  @override
  EventImportance get importance; // 时间定位
  @override
  String? get storyTime; // 故事内时间（如：天元历1245年春）
  @override
  String? get relativeTime; // 相对时间（如：入门后第156天）
  @override
  String? get chapterId; // 发生章节
  @override
  int? get chapterPosition; // 章节内位置
  // 地点和角色
  @override
  String? get locationId;
  @override
  List<String> get characterIds;
  @override
  String? get description;
  @override
  String? get consequences; // 事件关联
  @override
  String? get predecessorId;
  @override
  String? get successorId;
  @override
  DateTime get createdAt;

  /// Create a copy of StoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StoryEventImplCopyWith<_$StoryEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CharacterTrajectoryPoint _$CharacterTrajectoryPointFromJson(
  Map<String, dynamic> json,
) {
  return _CharacterTrajectoryPoint.fromJson(json);
}

/// @nodoc
mixin _$CharacterTrajectoryPoint {
  String get characterId => throw _privateConstructorUsedError;
  String get chapterId => throw _privateConstructorUsedError;
  String? get locationId => throw _privateConstructorUsedError;
  String? get emotionalState => throw _privateConstructorUsedError;
  String? get keyAction => throw _privateConstructorUsedError;
  List<String> get interactedCharacterIds => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Serializes this CharacterTrajectoryPoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CharacterTrajectoryPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterTrajectoryPointCopyWith<CharacterTrajectoryPoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterTrajectoryPointCopyWith<$Res> {
  factory $CharacterTrajectoryPointCopyWith(
    CharacterTrajectoryPoint value,
    $Res Function(CharacterTrajectoryPoint) then,
  ) = _$CharacterTrajectoryPointCopyWithImpl<$Res, CharacterTrajectoryPoint>;
  @useResult
  $Res call({
    String characterId,
    String chapterId,
    String? locationId,
    String? emotionalState,
    String? keyAction,
    List<String> interactedCharacterIds,
    String? note,
  });
}

/// @nodoc
class _$CharacterTrajectoryPointCopyWithImpl<
  $Res,
  $Val extends CharacterTrajectoryPoint
>
    implements $CharacterTrajectoryPointCopyWith<$Res> {
  _$CharacterTrajectoryPointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterTrajectoryPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterId = null,
    Object? chapterId = null,
    Object? locationId = freezed,
    Object? emotionalState = freezed,
    Object? keyAction = freezed,
    Object? interactedCharacterIds = null,
    Object? note = freezed,
  }) {
    return _then(
      _value.copyWith(
            characterId: null == characterId
                ? _value.characterId
                : characterId // ignore: cast_nullable_to_non_nullable
                      as String,
            chapterId: null == chapterId
                ? _value.chapterId
                : chapterId // ignore: cast_nullable_to_non_nullable
                      as String,
            locationId: freezed == locationId
                ? _value.locationId
                : locationId // ignore: cast_nullable_to_non_nullable
                      as String?,
            emotionalState: freezed == emotionalState
                ? _value.emotionalState
                : emotionalState // ignore: cast_nullable_to_non_nullable
                      as String?,
            keyAction: freezed == keyAction
                ? _value.keyAction
                : keyAction // ignore: cast_nullable_to_non_nullable
                      as String?,
            interactedCharacterIds: null == interactedCharacterIds
                ? _value.interactedCharacterIds
                : interactedCharacterIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterTrajectoryPointImplCopyWith<$Res>
    implements $CharacterTrajectoryPointCopyWith<$Res> {
  factory _$$CharacterTrajectoryPointImplCopyWith(
    _$CharacterTrajectoryPointImpl value,
    $Res Function(_$CharacterTrajectoryPointImpl) then,
  ) = __$$CharacterTrajectoryPointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String characterId,
    String chapterId,
    String? locationId,
    String? emotionalState,
    String? keyAction,
    List<String> interactedCharacterIds,
    String? note,
  });
}

/// @nodoc
class __$$CharacterTrajectoryPointImplCopyWithImpl<$Res>
    extends
        _$CharacterTrajectoryPointCopyWithImpl<
          $Res,
          _$CharacterTrajectoryPointImpl
        >
    implements _$$CharacterTrajectoryPointImplCopyWith<$Res> {
  __$$CharacterTrajectoryPointImplCopyWithImpl(
    _$CharacterTrajectoryPointImpl _value,
    $Res Function(_$CharacterTrajectoryPointImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterTrajectoryPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterId = null,
    Object? chapterId = null,
    Object? locationId = freezed,
    Object? emotionalState = freezed,
    Object? keyAction = freezed,
    Object? interactedCharacterIds = null,
    Object? note = freezed,
  }) {
    return _then(
      _$CharacterTrajectoryPointImpl(
        characterId: null == characterId
            ? _value.characterId
            : characterId // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterId: null == chapterId
            ? _value.chapterId
            : chapterId // ignore: cast_nullable_to_non_nullable
                  as String,
        locationId: freezed == locationId
            ? _value.locationId
            : locationId // ignore: cast_nullable_to_non_nullable
                  as String?,
        emotionalState: freezed == emotionalState
            ? _value.emotionalState
            : emotionalState // ignore: cast_nullable_to_non_nullable
                  as String?,
        keyAction: freezed == keyAction
            ? _value.keyAction
            : keyAction // ignore: cast_nullable_to_non_nullable
                  as String?,
        interactedCharacterIds: null == interactedCharacterIds
            ? _value._interactedCharacterIds
            : interactedCharacterIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CharacterTrajectoryPointImpl implements _CharacterTrajectoryPoint {
  const _$CharacterTrajectoryPointImpl({
    required this.characterId,
    required this.chapterId,
    this.locationId,
    this.emotionalState,
    this.keyAction,
    final List<String> interactedCharacterIds = const [],
    this.note,
  }) : _interactedCharacterIds = interactedCharacterIds;

  factory _$CharacterTrajectoryPointImpl.fromJson(Map<String, dynamic> json) =>
      _$$CharacterTrajectoryPointImplFromJson(json);

  @override
  final String characterId;
  @override
  final String chapterId;
  @override
  final String? locationId;
  @override
  final String? emotionalState;
  @override
  final String? keyAction;
  final List<String> _interactedCharacterIds;
  @override
  @JsonKey()
  List<String> get interactedCharacterIds {
    if (_interactedCharacterIds is EqualUnmodifiableListView)
      return _interactedCharacterIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_interactedCharacterIds);
  }

  @override
  final String? note;

  @override
  String toString() {
    return 'CharacterTrajectoryPoint(characterId: $characterId, chapterId: $chapterId, locationId: $locationId, emotionalState: $emotionalState, keyAction: $keyAction, interactedCharacterIds: $interactedCharacterIds, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterTrajectoryPointImpl &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.locationId, locationId) ||
                other.locationId == locationId) &&
            (identical(other.emotionalState, emotionalState) ||
                other.emotionalState == emotionalState) &&
            (identical(other.keyAction, keyAction) ||
                other.keyAction == keyAction) &&
            const DeepCollectionEquality().equals(
              other._interactedCharacterIds,
              _interactedCharacterIds,
            ) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    characterId,
    chapterId,
    locationId,
    emotionalState,
    keyAction,
    const DeepCollectionEquality().hash(_interactedCharacterIds),
    note,
  );

  /// Create a copy of CharacterTrajectoryPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterTrajectoryPointImplCopyWith<_$CharacterTrajectoryPointImpl>
  get copyWith =>
      __$$CharacterTrajectoryPointImplCopyWithImpl<
        _$CharacterTrajectoryPointImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CharacterTrajectoryPointImplToJson(this);
  }
}

abstract class _CharacterTrajectoryPoint implements CharacterTrajectoryPoint {
  const factory _CharacterTrajectoryPoint({
    required final String characterId,
    required final String chapterId,
    final String? locationId,
    final String? emotionalState,
    final String? keyAction,
    final List<String> interactedCharacterIds,
    final String? note,
  }) = _$CharacterTrajectoryPointImpl;

  factory _CharacterTrajectoryPoint.fromJson(Map<String, dynamic> json) =
      _$CharacterTrajectoryPointImpl.fromJson;

  @override
  String get characterId;
  @override
  String get chapterId;
  @override
  String? get locationId;
  @override
  String? get emotionalState;
  @override
  String? get keyAction;
  @override
  List<String> get interactedCharacterIds;
  @override
  String? get note;

  /// Create a copy of CharacterTrajectoryPoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterTrajectoryPointImplCopyWith<_$CharacterTrajectoryPointImpl>
  get copyWith => throw _privateConstructorUsedError;
}

TimeConflict _$TimeConflictFromJson(Map<String, dynamic> json) {
  return _TimeConflict.fromJson(json);
}

/// @nodoc
mixin _$TimeConflict {
  String get id => throw _privateConstructorUsedError;
  ConflictType get type => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get eventId1 => throw _privateConstructorUsedError;
  String? get eventId2 => throw _privateConstructorUsedError;
  String? get suggestion => throw _privateConstructorUsedError;
  bool get isResolved => throw _privateConstructorUsedError;

  /// Serializes this TimeConflict to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TimeConflict
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimeConflictCopyWith<TimeConflict> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimeConflictCopyWith<$Res> {
  factory $TimeConflictCopyWith(
    TimeConflict value,
    $Res Function(TimeConflict) then,
  ) = _$TimeConflictCopyWithImpl<$Res, TimeConflict>;
  @useResult
  $Res call({
    String id,
    ConflictType type,
    String description,
    String eventId1,
    String? eventId2,
    String? suggestion,
    bool isResolved,
  });
}

/// @nodoc
class _$TimeConflictCopyWithImpl<$Res, $Val extends TimeConflict>
    implements $TimeConflictCopyWith<$Res> {
  _$TimeConflictCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimeConflict
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? description = null,
    Object? eventId1 = null,
    Object? eventId2 = freezed,
    Object? suggestion = freezed,
    Object? isResolved = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as ConflictType,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            eventId1: null == eventId1
                ? _value.eventId1
                : eventId1 // ignore: cast_nullable_to_non_nullable
                      as String,
            eventId2: freezed == eventId2
                ? _value.eventId2
                : eventId2 // ignore: cast_nullable_to_non_nullable
                      as String?,
            suggestion: freezed == suggestion
                ? _value.suggestion
                : suggestion // ignore: cast_nullable_to_non_nullable
                      as String?,
            isResolved: null == isResolved
                ? _value.isResolved
                : isResolved // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TimeConflictImplCopyWith<$Res>
    implements $TimeConflictCopyWith<$Res> {
  factory _$$TimeConflictImplCopyWith(
    _$TimeConflictImpl value,
    $Res Function(_$TimeConflictImpl) then,
  ) = __$$TimeConflictImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    ConflictType type,
    String description,
    String eventId1,
    String? eventId2,
    String? suggestion,
    bool isResolved,
  });
}

/// @nodoc
class __$$TimeConflictImplCopyWithImpl<$Res>
    extends _$TimeConflictCopyWithImpl<$Res, _$TimeConflictImpl>
    implements _$$TimeConflictImplCopyWith<$Res> {
  __$$TimeConflictImplCopyWithImpl(
    _$TimeConflictImpl _value,
    $Res Function(_$TimeConflictImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TimeConflict
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? description = null,
    Object? eventId1 = null,
    Object? eventId2 = freezed,
    Object? suggestion = freezed,
    Object? isResolved = null,
  }) {
    return _then(
      _$TimeConflictImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as ConflictType,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        eventId1: null == eventId1
            ? _value.eventId1
            : eventId1 // ignore: cast_nullable_to_non_nullable
                  as String,
        eventId2: freezed == eventId2
            ? _value.eventId2
            : eventId2 // ignore: cast_nullable_to_non_nullable
                  as String?,
        suggestion: freezed == suggestion
            ? _value.suggestion
            : suggestion // ignore: cast_nullable_to_non_nullable
                  as String?,
        isResolved: null == isResolved
            ? _value.isResolved
            : isResolved // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TimeConflictImpl implements _TimeConflict {
  const _$TimeConflictImpl({
    required this.id,
    required this.type,
    required this.description,
    required this.eventId1,
    this.eventId2,
    this.suggestion,
    this.isResolved = false,
  });

  factory _$TimeConflictImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimeConflictImplFromJson(json);

  @override
  final String id;
  @override
  final ConflictType type;
  @override
  final String description;
  @override
  final String eventId1;
  @override
  final String? eventId2;
  @override
  final String? suggestion;
  @override
  @JsonKey()
  final bool isResolved;

  @override
  String toString() {
    return 'TimeConflict(id: $id, type: $type, description: $description, eventId1: $eventId1, eventId2: $eventId2, suggestion: $suggestion, isResolved: $isResolved)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimeConflictImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.eventId1, eventId1) ||
                other.eventId1 == eventId1) &&
            (identical(other.eventId2, eventId2) ||
                other.eventId2 == eventId2) &&
            (identical(other.suggestion, suggestion) ||
                other.suggestion == suggestion) &&
            (identical(other.isResolved, isResolved) ||
                other.isResolved == isResolved));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    description,
    eventId1,
    eventId2,
    suggestion,
    isResolved,
  );

  /// Create a copy of TimeConflict
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimeConflictImplCopyWith<_$TimeConflictImpl> get copyWith =>
      __$$TimeConflictImplCopyWithImpl<_$TimeConflictImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TimeConflictImplToJson(this);
  }
}

abstract class _TimeConflict implements TimeConflict {
  const factory _TimeConflict({
    required final String id,
    required final ConflictType type,
    required final String description,
    required final String eventId1,
    final String? eventId2,
    final String? suggestion,
    final bool isResolved,
  }) = _$TimeConflictImpl;

  factory _TimeConflict.fromJson(Map<String, dynamic> json) =
      _$TimeConflictImpl.fromJson;

  @override
  String get id;
  @override
  ConflictType get type;
  @override
  String get description;
  @override
  String get eventId1;
  @override
  String? get eventId2;
  @override
  String? get suggestion;
  @override
  bool get isResolved;

  /// Create a copy of TimeConflict
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimeConflictImplCopyWith<_$TimeConflictImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StoryTimeSystem _$StoryTimeSystemFromJson(Map<String, dynamic> json) {
  return _StoryTimeSystem.fromJson(json);
}

/// @nodoc
mixin _$StoryTimeSystem {
  String get workId => throw _privateConstructorUsedError;
  String get startEpoch => throw _privateConstructorUsedError; // 故事起点描述
  String? get calendarType => throw _privateConstructorUsedError; // 纪年方式
  List<TimeUnit> get customUnits => throw _privateConstructorUsedError;

  /// Serializes this StoryTimeSystem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StoryTimeSystem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StoryTimeSystemCopyWith<StoryTimeSystem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StoryTimeSystemCopyWith<$Res> {
  factory $StoryTimeSystemCopyWith(
    StoryTimeSystem value,
    $Res Function(StoryTimeSystem) then,
  ) = _$StoryTimeSystemCopyWithImpl<$Res, StoryTimeSystem>;
  @useResult
  $Res call({
    String workId,
    String startEpoch,
    String? calendarType,
    List<TimeUnit> customUnits,
  });
}

/// @nodoc
class _$StoryTimeSystemCopyWithImpl<$Res, $Val extends StoryTimeSystem>
    implements $StoryTimeSystemCopyWith<$Res> {
  _$StoryTimeSystemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StoryTimeSystem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workId = null,
    Object? startEpoch = null,
    Object? calendarType = freezed,
    Object? customUnits = null,
  }) {
    return _then(
      _value.copyWith(
            workId: null == workId
                ? _value.workId
                : workId // ignore: cast_nullable_to_non_nullable
                      as String,
            startEpoch: null == startEpoch
                ? _value.startEpoch
                : startEpoch // ignore: cast_nullable_to_non_nullable
                      as String,
            calendarType: freezed == calendarType
                ? _value.calendarType
                : calendarType // ignore: cast_nullable_to_non_nullable
                      as String?,
            customUnits: null == customUnits
                ? _value.customUnits
                : customUnits // ignore: cast_nullable_to_non_nullable
                      as List<TimeUnit>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StoryTimeSystemImplCopyWith<$Res>
    implements $StoryTimeSystemCopyWith<$Res> {
  factory _$$StoryTimeSystemImplCopyWith(
    _$StoryTimeSystemImpl value,
    $Res Function(_$StoryTimeSystemImpl) then,
  ) = __$$StoryTimeSystemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String workId,
    String startEpoch,
    String? calendarType,
    List<TimeUnit> customUnits,
  });
}

/// @nodoc
class __$$StoryTimeSystemImplCopyWithImpl<$Res>
    extends _$StoryTimeSystemCopyWithImpl<$Res, _$StoryTimeSystemImpl>
    implements _$$StoryTimeSystemImplCopyWith<$Res> {
  __$$StoryTimeSystemImplCopyWithImpl(
    _$StoryTimeSystemImpl _value,
    $Res Function(_$StoryTimeSystemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StoryTimeSystem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workId = null,
    Object? startEpoch = null,
    Object? calendarType = freezed,
    Object? customUnits = null,
  }) {
    return _then(
      _$StoryTimeSystemImpl(
        workId: null == workId
            ? _value.workId
            : workId // ignore: cast_nullable_to_non_nullable
                  as String,
        startEpoch: null == startEpoch
            ? _value.startEpoch
            : startEpoch // ignore: cast_nullable_to_non_nullable
                  as String,
        calendarType: freezed == calendarType
            ? _value.calendarType
            : calendarType // ignore: cast_nullable_to_non_nullable
                  as String?,
        customUnits: null == customUnits
            ? _value._customUnits
            : customUnits // ignore: cast_nullable_to_non_nullable
                  as List<TimeUnit>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StoryTimeSystemImpl implements _StoryTimeSystem {
  const _$StoryTimeSystemImpl({
    required this.workId,
    required this.startEpoch,
    this.calendarType,
    final List<TimeUnit> customUnits = const [],
  }) : _customUnits = customUnits;

  factory _$StoryTimeSystemImpl.fromJson(Map<String, dynamic> json) =>
      _$$StoryTimeSystemImplFromJson(json);

  @override
  final String workId;
  @override
  final String startEpoch;
  // 故事起点描述
  @override
  final String? calendarType;
  // 纪年方式
  final List<TimeUnit> _customUnits;
  // 纪年方式
  @override
  @JsonKey()
  List<TimeUnit> get customUnits {
    if (_customUnits is EqualUnmodifiableListView) return _customUnits;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customUnits);
  }

  @override
  String toString() {
    return 'StoryTimeSystem(workId: $workId, startEpoch: $startEpoch, calendarType: $calendarType, customUnits: $customUnits)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StoryTimeSystemImpl &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.startEpoch, startEpoch) ||
                other.startEpoch == startEpoch) &&
            (identical(other.calendarType, calendarType) ||
                other.calendarType == calendarType) &&
            const DeepCollectionEquality().equals(
              other._customUnits,
              _customUnits,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    workId,
    startEpoch,
    calendarType,
    const DeepCollectionEquality().hash(_customUnits),
  );

  /// Create a copy of StoryTimeSystem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StoryTimeSystemImplCopyWith<_$StoryTimeSystemImpl> get copyWith =>
      __$$StoryTimeSystemImplCopyWithImpl<_$StoryTimeSystemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$StoryTimeSystemImplToJson(this);
  }
}

abstract class _StoryTimeSystem implements StoryTimeSystem {
  const factory _StoryTimeSystem({
    required final String workId,
    required final String startEpoch,
    final String? calendarType,
    final List<TimeUnit> customUnits,
  }) = _$StoryTimeSystemImpl;

  factory _StoryTimeSystem.fromJson(Map<String, dynamic> json) =
      _$StoryTimeSystemImpl.fromJson;

  @override
  String get workId;
  @override
  String get startEpoch; // 故事起点描述
  @override
  String? get calendarType; // 纪年方式
  @override
  List<TimeUnit> get customUnits;

  /// Create a copy of StoryTimeSystem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StoryTimeSystemImplCopyWith<_$StoryTimeSystemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TimeUnit _$TimeUnitFromJson(Map<String, dynamic> json) {
  return _TimeUnit.fromJson(json);
}

/// @nodoc
mixin _$TimeUnit {
  String get name => throw _privateConstructorUsedError;
  int get baseValue => throw _privateConstructorUsedError; // 相对于基准单位的比例
  String? get description => throw _privateConstructorUsedError;

  /// Serializes this TimeUnit to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TimeUnit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimeUnitCopyWith<TimeUnit> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimeUnitCopyWith<$Res> {
  factory $TimeUnitCopyWith(TimeUnit value, $Res Function(TimeUnit) then) =
      _$TimeUnitCopyWithImpl<$Res, TimeUnit>;
  @useResult
  $Res call({String name, int baseValue, String? description});
}

/// @nodoc
class _$TimeUnitCopyWithImpl<$Res, $Val extends TimeUnit>
    implements $TimeUnitCopyWith<$Res> {
  _$TimeUnitCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimeUnit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? baseValue = null,
    Object? description = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            baseValue: null == baseValue
                ? _value.baseValue
                : baseValue // ignore: cast_nullable_to_non_nullable
                      as int,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TimeUnitImplCopyWith<$Res>
    implements $TimeUnitCopyWith<$Res> {
  factory _$$TimeUnitImplCopyWith(
    _$TimeUnitImpl value,
    $Res Function(_$TimeUnitImpl) then,
  ) = __$$TimeUnitImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, int baseValue, String? description});
}

/// @nodoc
class __$$TimeUnitImplCopyWithImpl<$Res>
    extends _$TimeUnitCopyWithImpl<$Res, _$TimeUnitImpl>
    implements _$$TimeUnitImplCopyWith<$Res> {
  __$$TimeUnitImplCopyWithImpl(
    _$TimeUnitImpl _value,
    $Res Function(_$TimeUnitImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TimeUnit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? baseValue = null,
    Object? description = freezed,
  }) {
    return _then(
      _$TimeUnitImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        baseValue: null == baseValue
            ? _value.baseValue
            : baseValue // ignore: cast_nullable_to_non_nullable
                  as int,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TimeUnitImpl implements _TimeUnit {
  const _$TimeUnitImpl({
    required this.name,
    required this.baseValue,
    this.description,
  });

  factory _$TimeUnitImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimeUnitImplFromJson(json);

  @override
  final String name;
  @override
  final int baseValue;
  // 相对于基准单位的比例
  @override
  final String? description;

  @override
  String toString() {
    return 'TimeUnit(name: $name, baseValue: $baseValue, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimeUnitImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.baseValue, baseValue) ||
                other.baseValue == baseValue) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, baseValue, description);

  /// Create a copy of TimeUnit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimeUnitImplCopyWith<_$TimeUnitImpl> get copyWith =>
      __$$TimeUnitImplCopyWithImpl<_$TimeUnitImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TimeUnitImplToJson(this);
  }
}

abstract class _TimeUnit implements TimeUnit {
  const factory _TimeUnit({
    required final String name,
    required final int baseValue,
    final String? description,
  }) = _$TimeUnitImpl;

  factory _TimeUnit.fromJson(Map<String, dynamic> json) =
      _$TimeUnitImpl.fromJson;

  @override
  String get name;
  @override
  int get baseValue; // 相对于基准单位的比例
  @override
  String? get description;

  /// Create a copy of TimeUnit
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimeUnitImplCopyWith<_$TimeUnitImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
