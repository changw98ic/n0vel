// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'story_arc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

StoryArcModel _$StoryArcModelFromJson(Map<String, dynamic> json) {
  return _StoryArcModel.fromJson(json);
}

/// @nodoc
mixin _$StoryArcModel {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  ArcType get arcType => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get startChapterId => throw _privateConstructorUsedError;
  String? get endChapterId => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;
  ArcStatus get status => throw _privateConstructorUsedError;
  String? get metadata => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $StoryArcModelCopyWith<StoryArcModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StoryArcModelCopyWith<$Res> {
  factory $StoryArcModelCopyWith(
          StoryArcModel value, $Res Function(StoryArcModel) then) =
      _$StoryArcModelCopyWithImpl<$Res, StoryArcModel>;
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      ArcType arcType,
      String? description,
      String? startChapterId,
      String? endChapterId,
      int sortOrder,
      ArcStatus status,
      String? metadata,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$StoryArcModelCopyWithImpl<$Res, $Val extends StoryArcModel>
    implements $StoryArcModelCopyWith<$Res> {
  _$StoryArcModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? arcType = null,
    Object? description = freezed,
    Object? startChapterId = freezed,
    Object? endChapterId = freezed,
    Object? sortOrder = null,
    Object? status = null,
    Object? metadata = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
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
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      arcType: null == arcType
          ? _value.arcType
          : arcType // ignore: cast_nullable_to_non_nullable
              as ArcType,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      startChapterId: freezed == startChapterId
          ? _value.startChapterId
          : startChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      endChapterId: freezed == endChapterId
          ? _value.endChapterId
          : endChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ArcStatus,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StoryArcModelImplCopyWith<$Res>
    implements $StoryArcModelCopyWith<$Res> {
  factory _$$StoryArcModelImplCopyWith(
          _$StoryArcModelImpl value, $Res Function(_$StoryArcModelImpl) then) =
      __$$StoryArcModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      ArcType arcType,
      String? description,
      String? startChapterId,
      String? endChapterId,
      int sortOrder,
      ArcStatus status,
      String? metadata,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$StoryArcModelImplCopyWithImpl<$Res>
    extends _$StoryArcModelCopyWithImpl<$Res, _$StoryArcModelImpl>
    implements _$$StoryArcModelImplCopyWith<$Res> {
  __$$StoryArcModelImplCopyWithImpl(
      _$StoryArcModelImpl _value, $Res Function(_$StoryArcModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? arcType = null,
    Object? description = freezed,
    Object? startChapterId = freezed,
    Object? endChapterId = freezed,
    Object? sortOrder = null,
    Object? status = null,
    Object? metadata = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$StoryArcModelImpl(
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
      arcType: null == arcType
          ? _value.arcType
          : arcType // ignore: cast_nullable_to_non_nullable
              as ArcType,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      startChapterId: freezed == startChapterId
          ? _value.startChapterId
          : startChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      endChapterId: freezed == endChapterId
          ? _value.endChapterId
          : endChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ArcStatus,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StoryArcModelImpl implements _StoryArcModel {
  const _$StoryArcModelImpl(
      {required this.id,
      required this.workId,
      required this.name,
      required this.arcType,
      this.description,
      this.startChapterId,
      this.endChapterId,
      this.sortOrder = 0,
      this.status = ArcStatus.active,
      this.metadata,
      this.createdAt,
      this.updatedAt});

  factory _$StoryArcModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$StoryArcModelImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String name;
  @override
  final ArcType arcType;
  @override
  final String? description;
  @override
  final String? startChapterId;
  @override
  final String? endChapterId;
  @override
  @JsonKey()
  final int sortOrder;
  @override
  @JsonKey()
  final ArcStatus status;
  @override
  final String? metadata;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'StoryArcModel(id: $id, workId: $workId, name: $name, arcType: $arcType, description: $description, startChapterId: $startChapterId, endChapterId: $endChapterId, sortOrder: $sortOrder, status: $status, metadata: $metadata, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StoryArcModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.arcType, arcType) || other.arcType == arcType) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.startChapterId, startChapterId) ||
                other.startChapterId == startChapterId) &&
            (identical(other.endChapterId, endChapterId) ||
                other.endChapterId == endChapterId) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.metadata, metadata) ||
                other.metadata == metadata) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      workId,
      name,
      arcType,
      description,
      startChapterId,
      endChapterId,
      sortOrder,
      status,
      metadata,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$StoryArcModelImplCopyWith<_$StoryArcModelImpl> get copyWith =>
      __$$StoryArcModelImplCopyWithImpl<_$StoryArcModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StoryArcModelImplToJson(
      this,
    );
  }
}

abstract class _StoryArcModel implements StoryArcModel {
  const factory _StoryArcModel(
      {required final String id,
      required final String workId,
      required final String name,
      required final ArcType arcType,
      final String? description,
      final String? startChapterId,
      final String? endChapterId,
      final int sortOrder,
      final ArcStatus status,
      final String? metadata,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$StoryArcModelImpl;

  factory _StoryArcModel.fromJson(Map<String, dynamic> json) =
      _$StoryArcModelImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get name;
  @override
  ArcType get arcType;
  @override
  String? get description;
  @override
  String? get startChapterId;
  @override
  String? get endChapterId;
  @override
  int get sortOrder;
  @override
  ArcStatus get status;
  @override
  String? get metadata;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$StoryArcModelImplCopyWith<_$StoryArcModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ArcChapterModel _$ArcChapterModelFromJson(Map<String, dynamic> json) {
  return _ArcChapterModel.fromJson(json);
}

/// @nodoc
mixin _$ArcChapterModel {
  String get id => throw _privateConstructorUsedError;
  String get arcId => throw _privateConstructorUsedError;
  String get chapterId => throw _privateConstructorUsedError;
  ArcChapterRole get role => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ArcChapterModelCopyWith<ArcChapterModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ArcChapterModelCopyWith<$Res> {
  factory $ArcChapterModelCopyWith(
          ArcChapterModel value, $Res Function(ArcChapterModel) then) =
      _$ArcChapterModelCopyWithImpl<$Res, ArcChapterModel>;
  @useResult
  $Res call(
      {String id,
      String arcId,
      String chapterId,
      ArcChapterRole role,
      String? note,
      int sortOrder});
}

/// @nodoc
class _$ArcChapterModelCopyWithImpl<$Res, $Val extends ArcChapterModel>
    implements $ArcChapterModelCopyWith<$Res> {
  _$ArcChapterModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? arcId = null,
    Object? chapterId = null,
    Object? role = null,
    Object? note = freezed,
    Object? sortOrder = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      arcId: null == arcId
          ? _value.arcId
          : arcId // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as ArcChapterRole,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ArcChapterModelImplCopyWith<$Res>
    implements $ArcChapterModelCopyWith<$Res> {
  factory _$$ArcChapterModelImplCopyWith(_$ArcChapterModelImpl value,
          $Res Function(_$ArcChapterModelImpl) then) =
      __$$ArcChapterModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String arcId,
      String chapterId,
      ArcChapterRole role,
      String? note,
      int sortOrder});
}

/// @nodoc
class __$$ArcChapterModelImplCopyWithImpl<$Res>
    extends _$ArcChapterModelCopyWithImpl<$Res, _$ArcChapterModelImpl>
    implements _$$ArcChapterModelImplCopyWith<$Res> {
  __$$ArcChapterModelImplCopyWithImpl(
      _$ArcChapterModelImpl _value, $Res Function(_$ArcChapterModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? arcId = null,
    Object? chapterId = null,
    Object? role = null,
    Object? note = freezed,
    Object? sortOrder = null,
  }) {
    return _then(_$ArcChapterModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      arcId: null == arcId
          ? _value.arcId
          : arcId // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as ArcChapterRole,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ArcChapterModelImpl implements _ArcChapterModel {
  const _$ArcChapterModelImpl(
      {required this.id,
      required this.arcId,
      required this.chapterId,
      this.role = ArcChapterRole.progression,
      this.note,
      this.sortOrder = 0});

  factory _$ArcChapterModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ArcChapterModelImplFromJson(json);

  @override
  final String id;
  @override
  final String arcId;
  @override
  final String chapterId;
  @override
  @JsonKey()
  final ArcChapterRole role;
  @override
  final String? note;
  @override
  @JsonKey()
  final int sortOrder;

  @override
  String toString() {
    return 'ArcChapterModel(id: $id, arcId: $arcId, chapterId: $chapterId, role: $role, note: $note, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ArcChapterModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.arcId, arcId) || other.arcId == arcId) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, arcId, chapterId, role, note, sortOrder);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ArcChapterModelImplCopyWith<_$ArcChapterModelImpl> get copyWith =>
      __$$ArcChapterModelImplCopyWithImpl<_$ArcChapterModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ArcChapterModelImplToJson(
      this,
    );
  }
}

abstract class _ArcChapterModel implements ArcChapterModel {
  const factory _ArcChapterModel(
      {required final String id,
      required final String arcId,
      required final String chapterId,
      final ArcChapterRole role,
      final String? note,
      final int sortOrder}) = _$ArcChapterModelImpl;

  factory _ArcChapterModel.fromJson(Map<String, dynamic> json) =
      _$ArcChapterModelImpl.fromJson;

  @override
  String get id;
  @override
  String get arcId;
  @override
  String get chapterId;
  @override
  ArcChapterRole get role;
  @override
  String? get note;
  @override
  int get sortOrder;
  @override
  @JsonKey(ignore: true)
  _$$ArcChapterModelImplCopyWith<_$ArcChapterModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ArcCharacterModel _$ArcCharacterModelFromJson(Map<String, dynamic> json) {
  return _ArcCharacterModel.fromJson(json);
}

/// @nodoc
mixin _$ArcCharacterModel {
  String get id => throw _privateConstructorUsedError;
  String get arcId => throw _privateConstructorUsedError;
  String get characterId => throw _privateConstructorUsedError;
  ArcCharacterRole get role => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ArcCharacterModelCopyWith<ArcCharacterModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ArcCharacterModelCopyWith<$Res> {
  factory $ArcCharacterModelCopyWith(
          ArcCharacterModel value, $Res Function(ArcCharacterModel) then) =
      _$ArcCharacterModelCopyWithImpl<$Res, ArcCharacterModel>;
  @useResult
  $Res call(
      {String id,
      String arcId,
      String characterId,
      ArcCharacterRole role,
      String? note});
}

/// @nodoc
class _$ArcCharacterModelCopyWithImpl<$Res, $Val extends ArcCharacterModel>
    implements $ArcCharacterModelCopyWith<$Res> {
  _$ArcCharacterModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? arcId = null,
    Object? characterId = null,
    Object? role = null,
    Object? note = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      arcId: null == arcId
          ? _value.arcId
          : arcId // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as ArcCharacterRole,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ArcCharacterModelImplCopyWith<$Res>
    implements $ArcCharacterModelCopyWith<$Res> {
  factory _$$ArcCharacterModelImplCopyWith(_$ArcCharacterModelImpl value,
          $Res Function(_$ArcCharacterModelImpl) then) =
      __$$ArcCharacterModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String arcId,
      String characterId,
      ArcCharacterRole role,
      String? note});
}

/// @nodoc
class __$$ArcCharacterModelImplCopyWithImpl<$Res>
    extends _$ArcCharacterModelCopyWithImpl<$Res, _$ArcCharacterModelImpl>
    implements _$$ArcCharacterModelImplCopyWith<$Res> {
  __$$ArcCharacterModelImplCopyWithImpl(_$ArcCharacterModelImpl _value,
      $Res Function(_$ArcCharacterModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? arcId = null,
    Object? characterId = null,
    Object? role = null,
    Object? note = freezed,
  }) {
    return _then(_$ArcCharacterModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      arcId: null == arcId
          ? _value.arcId
          : arcId // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as ArcCharacterRole,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ArcCharacterModelImpl implements _ArcCharacterModel {
  const _$ArcCharacterModelImpl(
      {required this.id,
      required this.arcId,
      required this.characterId,
      this.role = ArcCharacterRole.participant,
      this.note});

  factory _$ArcCharacterModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ArcCharacterModelImplFromJson(json);

  @override
  final String id;
  @override
  final String arcId;
  @override
  final String characterId;
  @override
  @JsonKey()
  final ArcCharacterRole role;
  @override
  final String? note;

  @override
  String toString() {
    return 'ArcCharacterModel(id: $id, arcId: $arcId, characterId: $characterId, role: $role, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ArcCharacterModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.arcId, arcId) || other.arcId == arcId) &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, arcId, characterId, role, note);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ArcCharacterModelImplCopyWith<_$ArcCharacterModelImpl> get copyWith =>
      __$$ArcCharacterModelImplCopyWithImpl<_$ArcCharacterModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ArcCharacterModelImplToJson(
      this,
    );
  }
}

abstract class _ArcCharacterModel implements ArcCharacterModel {
  const factory _ArcCharacterModel(
      {required final String id,
      required final String arcId,
      required final String characterId,
      final ArcCharacterRole role,
      final String? note}) = _$ArcCharacterModelImpl;

  factory _ArcCharacterModel.fromJson(Map<String, dynamic> json) =
      _$ArcCharacterModelImpl.fromJson;

  @override
  String get id;
  @override
  String get arcId;
  @override
  String get characterId;
  @override
  ArcCharacterRole get role;
  @override
  String? get note;
  @override
  @JsonKey(ignore: true)
  _$$ArcCharacterModelImplCopyWith<_$ArcCharacterModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ForeshadowModel _$ForeshadowModelFromJson(Map<String, dynamic> json) {
  return _ForeshadowModel.fromJson(json);
}

/// @nodoc
mixin _$ForeshadowModel {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get plantChapterId => throw _privateConstructorUsedError;
  int? get plantParagraphIndex => throw _privateConstructorUsedError;
  String? get payoffChapterId => throw _privateConstructorUsedError;
  int? get payoffParagraphIndex => throw _privateConstructorUsedError;
  ForeshadowStatus get status => throw _privateConstructorUsedError;
  ForeshadowImportance get importance => throw _privateConstructorUsedError;
  String? get arcId => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ForeshadowModelCopyWith<ForeshadowModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ForeshadowModelCopyWith<$Res> {
  factory $ForeshadowModelCopyWith(
          ForeshadowModel value, $Res Function(ForeshadowModel) then) =
      _$ForeshadowModelCopyWithImpl<$Res, ForeshadowModel>;
  @useResult
  $Res call(
      {String id,
      String workId,
      String description,
      String? plantChapterId,
      int? plantParagraphIndex,
      String? payoffChapterId,
      int? payoffParagraphIndex,
      ForeshadowStatus status,
      ForeshadowImportance importance,
      String? arcId,
      String? note,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$ForeshadowModelCopyWithImpl<$Res, $Val extends ForeshadowModel>
    implements $ForeshadowModelCopyWith<$Res> {
  _$ForeshadowModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? description = null,
    Object? plantChapterId = freezed,
    Object? plantParagraphIndex = freezed,
    Object? payoffChapterId = freezed,
    Object? payoffParagraphIndex = freezed,
    Object? status = null,
    Object? importance = null,
    Object? arcId = freezed,
    Object? note = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
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
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      plantChapterId: freezed == plantChapterId
          ? _value.plantChapterId
          : plantChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      plantParagraphIndex: freezed == plantParagraphIndex
          ? _value.plantParagraphIndex
          : plantParagraphIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      payoffChapterId: freezed == payoffChapterId
          ? _value.payoffChapterId
          : payoffChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      payoffParagraphIndex: freezed == payoffParagraphIndex
          ? _value.payoffParagraphIndex
          : payoffParagraphIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ForeshadowStatus,
      importance: null == importance
          ? _value.importance
          : importance // ignore: cast_nullable_to_non_nullable
              as ForeshadowImportance,
      arcId: freezed == arcId
          ? _value.arcId
          : arcId // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ForeshadowModelImplCopyWith<$Res>
    implements $ForeshadowModelCopyWith<$Res> {
  factory _$$ForeshadowModelImplCopyWith(_$ForeshadowModelImpl value,
          $Res Function(_$ForeshadowModelImpl) then) =
      __$$ForeshadowModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String workId,
      String description,
      String? plantChapterId,
      int? plantParagraphIndex,
      String? payoffChapterId,
      int? payoffParagraphIndex,
      ForeshadowStatus status,
      ForeshadowImportance importance,
      String? arcId,
      String? note,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$ForeshadowModelImplCopyWithImpl<$Res>
    extends _$ForeshadowModelCopyWithImpl<$Res, _$ForeshadowModelImpl>
    implements _$$ForeshadowModelImplCopyWith<$Res> {
  __$$ForeshadowModelImplCopyWithImpl(
      _$ForeshadowModelImpl _value, $Res Function(_$ForeshadowModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? description = null,
    Object? plantChapterId = freezed,
    Object? plantParagraphIndex = freezed,
    Object? payoffChapterId = freezed,
    Object? payoffParagraphIndex = freezed,
    Object? status = null,
    Object? importance = null,
    Object? arcId = freezed,
    Object? note = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ForeshadowModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      plantChapterId: freezed == plantChapterId
          ? _value.plantChapterId
          : plantChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      plantParagraphIndex: freezed == plantParagraphIndex
          ? _value.plantParagraphIndex
          : plantParagraphIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      payoffChapterId: freezed == payoffChapterId
          ? _value.payoffChapterId
          : payoffChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      payoffParagraphIndex: freezed == payoffParagraphIndex
          ? _value.payoffParagraphIndex
          : payoffParagraphIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ForeshadowStatus,
      importance: null == importance
          ? _value.importance
          : importance // ignore: cast_nullable_to_non_nullable
              as ForeshadowImportance,
      arcId: freezed == arcId
          ? _value.arcId
          : arcId // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ForeshadowModelImpl implements _ForeshadowModel {
  const _$ForeshadowModelImpl(
      {required this.id,
      required this.workId,
      required this.description,
      this.plantChapterId,
      this.plantParagraphIndex,
      this.payoffChapterId,
      this.payoffParagraphIndex,
      this.status = ForeshadowStatus.planted,
      this.importance = ForeshadowImportance.minor,
      this.arcId,
      this.note,
      this.createdAt,
      this.updatedAt});

  factory _$ForeshadowModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ForeshadowModelImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String description;
  @override
  final String? plantChapterId;
  @override
  final int? plantParagraphIndex;
  @override
  final String? payoffChapterId;
  @override
  final int? payoffParagraphIndex;
  @override
  @JsonKey()
  final ForeshadowStatus status;
  @override
  @JsonKey()
  final ForeshadowImportance importance;
  @override
  final String? arcId;
  @override
  final String? note;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ForeshadowModel(id: $id, workId: $workId, description: $description, plantChapterId: $plantChapterId, plantParagraphIndex: $plantParagraphIndex, payoffChapterId: $payoffChapterId, payoffParagraphIndex: $payoffParagraphIndex, status: $status, importance: $importance, arcId: $arcId, note: $note, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ForeshadowModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.plantChapterId, plantChapterId) ||
                other.plantChapterId == plantChapterId) &&
            (identical(other.plantParagraphIndex, plantParagraphIndex) ||
                other.plantParagraphIndex == plantParagraphIndex) &&
            (identical(other.payoffChapterId, payoffChapterId) ||
                other.payoffChapterId == payoffChapterId) &&
            (identical(other.payoffParagraphIndex, payoffParagraphIndex) ||
                other.payoffParagraphIndex == payoffParagraphIndex) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.importance, importance) ||
                other.importance == importance) &&
            (identical(other.arcId, arcId) || other.arcId == arcId) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      workId,
      description,
      plantChapterId,
      plantParagraphIndex,
      payoffChapterId,
      payoffParagraphIndex,
      status,
      importance,
      arcId,
      note,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ForeshadowModelImplCopyWith<_$ForeshadowModelImpl> get copyWith =>
      __$$ForeshadowModelImplCopyWithImpl<_$ForeshadowModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ForeshadowModelImplToJson(
      this,
    );
  }
}

abstract class _ForeshadowModel implements ForeshadowModel {
  const factory _ForeshadowModel(
      {required final String id,
      required final String workId,
      required final String description,
      final String? plantChapterId,
      final int? plantParagraphIndex,
      final String? payoffChapterId,
      final int? payoffParagraphIndex,
      final ForeshadowStatus status,
      final ForeshadowImportance importance,
      final String? arcId,
      final String? note,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$ForeshadowModelImpl;

  factory _ForeshadowModel.fromJson(Map<String, dynamic> json) =
      _$ForeshadowModelImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get description;
  @override
  String? get plantChapterId;
  @override
  int? get plantParagraphIndex;
  @override
  String? get payoffChapterId;
  @override
  int? get payoffParagraphIndex;
  @override
  ForeshadowStatus get status;
  @override
  ForeshadowImportance get importance;
  @override
  String? get arcId;
  @override
  String? get note;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$ForeshadowModelImplCopyWith<_$ForeshadowModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
