// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'faction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Faction _$FactionFromJson(Map<String, dynamic> json) {
  return _Faction.fromJson(json);
}

/// @nodoc
mixin _$Faction {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get type => throw _privateConstructorUsedError;
  String? get emblemPath => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  List<String> get traits => throw _privateConstructorUsedError;
  String? get leaderId => throw _privateConstructorUsedError;
  bool get isArchived => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FactionCopyWith<Faction> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FactionCopyWith<$Res> {
  factory $FactionCopyWith(Faction value, $Res Function(Faction) then) =
      _$FactionCopyWithImpl<$Res, Faction>;
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      String? type,
      String? emblemPath,
      String? description,
      List<String> traits,
      String? leaderId,
      bool isArchived,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$FactionCopyWithImpl<$Res, $Val extends Faction>
    implements $FactionCopyWith<$Res> {
  _$FactionCopyWithImpl(this._value, this._then);

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
    Object? type = freezed,
    Object? emblemPath = freezed,
    Object? description = freezed,
    Object? traits = null,
    Object? leaderId = freezed,
    Object? isArchived = null,
    Object? createdAt = null,
    Object? updatedAt = null,
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
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String?,
      emblemPath: freezed == emblemPath
          ? _value.emblemPath
          : emblemPath // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      traits: null == traits
          ? _value.traits
          : traits // ignore: cast_nullable_to_non_nullable
              as List<String>,
      leaderId: freezed == leaderId
          ? _value.leaderId
          : leaderId // ignore: cast_nullable_to_non_nullable
              as String?,
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
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
abstract class _$$FactionImplCopyWith<$Res> implements $FactionCopyWith<$Res> {
  factory _$$FactionImplCopyWith(
          _$FactionImpl value, $Res Function(_$FactionImpl) then) =
      __$$FactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      String? type,
      String? emblemPath,
      String? description,
      List<String> traits,
      String? leaderId,
      bool isArchived,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$FactionImplCopyWithImpl<$Res>
    extends _$FactionCopyWithImpl<$Res, _$FactionImpl>
    implements _$$FactionImplCopyWith<$Res> {
  __$$FactionImplCopyWithImpl(
      _$FactionImpl _value, $Res Function(_$FactionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? type = freezed,
    Object? emblemPath = freezed,
    Object? description = freezed,
    Object? traits = null,
    Object? leaderId = freezed,
    Object? isArchived = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$FactionImpl(
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
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String?,
      emblemPath: freezed == emblemPath
          ? _value.emblemPath
          : emblemPath // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      traits: null == traits
          ? _value._traits
          : traits // ignore: cast_nullable_to_non_nullable
              as List<String>,
      leaderId: freezed == leaderId
          ? _value.leaderId
          : leaderId // ignore: cast_nullable_to_non_nullable
              as String?,
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
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
class _$FactionImpl extends _Faction {
  const _$FactionImpl(
      {required this.id,
      required this.workId,
      required this.name,
      this.type,
      this.emblemPath,
      this.description,
      final List<String> traits = const [],
      this.leaderId,
      this.isArchived = false,
      required this.createdAt,
      required this.updatedAt})
      : _traits = traits,
        super._();

  factory _$FactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$FactionImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String name;
  @override
  final String? type;
  @override
  final String? emblemPath;
  @override
  final String? description;
  final List<String> _traits;
  @override
  @JsonKey()
  List<String> get traits {
    if (_traits is EqualUnmodifiableListView) return _traits;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_traits);
  }

  @override
  final String? leaderId;
  @override
  @JsonKey()
  final bool isArchived;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Faction(id: $id, workId: $workId, name: $name, type: $type, emblemPath: $emblemPath, description: $description, traits: $traits, leaderId: $leaderId, isArchived: $isArchived, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.emblemPath, emblemPath) ||
                other.emblemPath == emblemPath) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._traits, _traits) &&
            (identical(other.leaderId, leaderId) ||
                other.leaderId == leaderId) &&
            (identical(other.isArchived, isArchived) ||
                other.isArchived == isArchived) &&
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
      type,
      emblemPath,
      description,
      const DeepCollectionEquality().hash(_traits),
      leaderId,
      isArchived,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FactionImplCopyWith<_$FactionImpl> get copyWith =>
      __$$FactionImplCopyWithImpl<_$FactionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FactionImplToJson(
      this,
    );
  }
}

abstract class _Faction extends Faction {
  const factory _Faction(
      {required final String id,
      required final String workId,
      required final String name,
      final String? type,
      final String? emblemPath,
      final String? description,
      final List<String> traits,
      final String? leaderId,
      final bool isArchived,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$FactionImpl;
  const _Faction._() : super._();

  factory _Faction.fromJson(Map<String, dynamic> json) = _$FactionImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get name;
  @override
  String? get type;
  @override
  String? get emblemPath;
  @override
  String? get description;
  @override
  List<String> get traits;
  @override
  String? get leaderId;
  @override
  bool get isArchived;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$FactionImplCopyWith<_$FactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FactionMember _$FactionMemberFromJson(Map<String, dynamic> json) {
  return _FactionMember.fromJson(json);
}

/// @nodoc
mixin _$FactionMember {
  String get id => throw _privateConstructorUsedError;
  String get factionId => throw _privateConstructorUsedError;
  String get characterId => throw _privateConstructorUsedError;
  String? get role => throw _privateConstructorUsedError;
  String? get joinChapterId => throw _privateConstructorUsedError;
  String? get leaveChapterId => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FactionMemberCopyWith<FactionMember> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FactionMemberCopyWith<$Res> {
  factory $FactionMemberCopyWith(
          FactionMember value, $Res Function(FactionMember) then) =
      _$FactionMemberCopyWithImpl<$Res, FactionMember>;
  @useResult
  $Res call(
      {String id,
      String factionId,
      String characterId,
      String? role,
      String? joinChapterId,
      String? leaveChapterId,
      String status,
      DateTime createdAt});
}

/// @nodoc
class _$FactionMemberCopyWithImpl<$Res, $Val extends FactionMember>
    implements $FactionMemberCopyWith<$Res> {
  _$FactionMemberCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? factionId = null,
    Object? characterId = null,
    Object? role = freezed,
    Object? joinChapterId = freezed,
    Object? leaveChapterId = freezed,
    Object? status = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      factionId: null == factionId
          ? _value.factionId
          : factionId // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      role: freezed == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String?,
      joinChapterId: freezed == joinChapterId
          ? _value.joinChapterId
          : joinChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      leaveChapterId: freezed == leaveChapterId
          ? _value.leaveChapterId
          : leaveChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FactionMemberImplCopyWith<$Res>
    implements $FactionMemberCopyWith<$Res> {
  factory _$$FactionMemberImplCopyWith(
          _$FactionMemberImpl value, $Res Function(_$FactionMemberImpl) then) =
      __$$FactionMemberImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String factionId,
      String characterId,
      String? role,
      String? joinChapterId,
      String? leaveChapterId,
      String status,
      DateTime createdAt});
}

/// @nodoc
class __$$FactionMemberImplCopyWithImpl<$Res>
    extends _$FactionMemberCopyWithImpl<$Res, _$FactionMemberImpl>
    implements _$$FactionMemberImplCopyWith<$Res> {
  __$$FactionMemberImplCopyWithImpl(
      _$FactionMemberImpl _value, $Res Function(_$FactionMemberImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? factionId = null,
    Object? characterId = null,
    Object? role = freezed,
    Object? joinChapterId = freezed,
    Object? leaveChapterId = freezed,
    Object? status = null,
    Object? createdAt = null,
  }) {
    return _then(_$FactionMemberImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      factionId: null == factionId
          ? _value.factionId
          : factionId // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      role: freezed == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String?,
      joinChapterId: freezed == joinChapterId
          ? _value.joinChapterId
          : joinChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      leaveChapterId: freezed == leaveChapterId
          ? _value.leaveChapterId
          : leaveChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FactionMemberImpl implements _FactionMember {
  const _$FactionMemberImpl(
      {required this.id,
      required this.factionId,
      required this.characterId,
      this.role,
      this.joinChapterId,
      this.leaveChapterId,
      this.status = 'active',
      required this.createdAt});

  factory _$FactionMemberImpl.fromJson(Map<String, dynamic> json) =>
      _$$FactionMemberImplFromJson(json);

  @override
  final String id;
  @override
  final String factionId;
  @override
  final String characterId;
  @override
  final String? role;
  @override
  final String? joinChapterId;
  @override
  final String? leaveChapterId;
  @override
  @JsonKey()
  final String status;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'FactionMember(id: $id, factionId: $factionId, characterId: $characterId, role: $role, joinChapterId: $joinChapterId, leaveChapterId: $leaveChapterId, status: $status, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FactionMemberImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.factionId, factionId) ||
                other.factionId == factionId) &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.joinChapterId, joinChapterId) ||
                other.joinChapterId == joinChapterId) &&
            (identical(other.leaveChapterId, leaveChapterId) ||
                other.leaveChapterId == leaveChapterId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, factionId, characterId, role,
      joinChapterId, leaveChapterId, status, createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FactionMemberImplCopyWith<_$FactionMemberImpl> get copyWith =>
      __$$FactionMemberImplCopyWithImpl<_$FactionMemberImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FactionMemberImplToJson(
      this,
    );
  }
}

abstract class _FactionMember implements FactionMember {
  const factory _FactionMember(
      {required final String id,
      required final String factionId,
      required final String characterId,
      final String? role,
      final String? joinChapterId,
      final String? leaveChapterId,
      final String status,
      required final DateTime createdAt}) = _$FactionMemberImpl;

  factory _FactionMember.fromJson(Map<String, dynamic> json) =
      _$FactionMemberImpl.fromJson;

  @override
  String get id;
  @override
  String get factionId;
  @override
  String get characterId;
  @override
  String? get role;
  @override
  String? get joinChapterId;
  @override
  String? get leaveChapterId;
  @override
  String get status;
  @override
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$FactionMemberImplCopyWith<_$FactionMemberImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
