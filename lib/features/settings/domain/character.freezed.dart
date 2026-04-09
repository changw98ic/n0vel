// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'character.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Character _$CharacterFromJson(Map<String, dynamic> json) {
  return _Character.fromJson(json);
}

/// @nodoc
mixin _$Character {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<String> get aliases => throw _privateConstructorUsedError;
  CharacterTier get tier => throw _privateConstructorUsedError;
  String? get avatarPath => throw _privateConstructorUsedError;
  String? get gender => throw _privateConstructorUsedError;
  String? get age => throw _privateConstructorUsedError;
  String? get identity => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  LifeStatus get lifeStatus => throw _privateConstructorUsedError;
  String? get deathChapterId => throw _privateConstructorUsedError;
  String? get deathReason => throw _privateConstructorUsedError;
  bool get isArchived => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CharacterCopyWith<Character> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterCopyWith<$Res> {
  factory $CharacterCopyWith(Character value, $Res Function(Character) then) =
      _$CharacterCopyWithImpl<$Res, Character>;
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      List<String> aliases,
      CharacterTier tier,
      String? avatarPath,
      String? gender,
      String? age,
      String? identity,
      String? bio,
      LifeStatus lifeStatus,
      String? deathChapterId,
      String? deathReason,
      bool isArchived,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$CharacterCopyWithImpl<$Res, $Val extends Character>
    implements $CharacterCopyWith<$Res> {
  _$CharacterCopyWithImpl(this._value, this._then);

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
    Object? aliases = null,
    Object? tier = null,
    Object? avatarPath = freezed,
    Object? gender = freezed,
    Object? age = freezed,
    Object? identity = freezed,
    Object? bio = freezed,
    Object? lifeStatus = null,
    Object? deathChapterId = freezed,
    Object? deathReason = freezed,
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
      aliases: null == aliases
          ? _value.aliases
          : aliases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      tier: null == tier
          ? _value.tier
          : tier // ignore: cast_nullable_to_non_nullable
              as CharacterTier,
      avatarPath: freezed == avatarPath
          ? _value.avatarPath
          : avatarPath // ignore: cast_nullable_to_non_nullable
              as String?,
      gender: freezed == gender
          ? _value.gender
          : gender // ignore: cast_nullable_to_non_nullable
              as String?,
      age: freezed == age
          ? _value.age
          : age // ignore: cast_nullable_to_non_nullable
              as String?,
      identity: freezed == identity
          ? _value.identity
          : identity // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      lifeStatus: null == lifeStatus
          ? _value.lifeStatus
          : lifeStatus // ignore: cast_nullable_to_non_nullable
              as LifeStatus,
      deathChapterId: freezed == deathChapterId
          ? _value.deathChapterId
          : deathChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      deathReason: freezed == deathReason
          ? _value.deathReason
          : deathReason // ignore: cast_nullable_to_non_nullable
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
abstract class _$$CharacterImplCopyWith<$Res>
    implements $CharacterCopyWith<$Res> {
  factory _$$CharacterImplCopyWith(
          _$CharacterImpl value, $Res Function(_$CharacterImpl) then) =
      __$$CharacterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      List<String> aliases,
      CharacterTier tier,
      String? avatarPath,
      String? gender,
      String? age,
      String? identity,
      String? bio,
      LifeStatus lifeStatus,
      String? deathChapterId,
      String? deathReason,
      bool isArchived,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$CharacterImplCopyWithImpl<$Res>
    extends _$CharacterCopyWithImpl<$Res, _$CharacterImpl>
    implements _$$CharacterImplCopyWith<$Res> {
  __$$CharacterImplCopyWithImpl(
      _$CharacterImpl _value, $Res Function(_$CharacterImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? aliases = null,
    Object? tier = null,
    Object? avatarPath = freezed,
    Object? gender = freezed,
    Object? age = freezed,
    Object? identity = freezed,
    Object? bio = freezed,
    Object? lifeStatus = null,
    Object? deathChapterId = freezed,
    Object? deathReason = freezed,
    Object? isArchived = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$CharacterImpl(
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
      aliases: null == aliases
          ? _value._aliases
          : aliases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      tier: null == tier
          ? _value.tier
          : tier // ignore: cast_nullable_to_non_nullable
              as CharacterTier,
      avatarPath: freezed == avatarPath
          ? _value.avatarPath
          : avatarPath // ignore: cast_nullable_to_non_nullable
              as String?,
      gender: freezed == gender
          ? _value.gender
          : gender // ignore: cast_nullable_to_non_nullable
              as String?,
      age: freezed == age
          ? _value.age
          : age // ignore: cast_nullable_to_non_nullable
              as String?,
      identity: freezed == identity
          ? _value.identity
          : identity // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      lifeStatus: null == lifeStatus
          ? _value.lifeStatus
          : lifeStatus // ignore: cast_nullable_to_non_nullable
              as LifeStatus,
      deathChapterId: freezed == deathChapterId
          ? _value.deathChapterId
          : deathChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      deathReason: freezed == deathReason
          ? _value.deathReason
          : deathReason // ignore: cast_nullable_to_non_nullable
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
class _$CharacterImpl extends _Character {
  const _$CharacterImpl(
      {required this.id,
      required this.workId,
      required this.name,
      final List<String> aliases = const [],
      required this.tier,
      this.avatarPath,
      this.gender,
      this.age,
      this.identity,
      this.bio,
      this.lifeStatus = LifeStatus.alive,
      this.deathChapterId,
      this.deathReason,
      this.isArchived = false,
      required this.createdAt,
      required this.updatedAt})
      : _aliases = aliases,
        super._();

  factory _$CharacterImpl.fromJson(Map<String, dynamic> json) =>
      _$$CharacterImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String name;
  final List<String> _aliases;
  @override
  @JsonKey()
  List<String> get aliases {
    if (_aliases is EqualUnmodifiableListView) return _aliases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_aliases);
  }

  @override
  final CharacterTier tier;
  @override
  final String? avatarPath;
  @override
  final String? gender;
  @override
  final String? age;
  @override
  final String? identity;
  @override
  final String? bio;
  @override
  @JsonKey()
  final LifeStatus lifeStatus;
  @override
  final String? deathChapterId;
  @override
  final String? deathReason;
  @override
  @JsonKey()
  final bool isArchived;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Character(id: $id, workId: $workId, name: $name, aliases: $aliases, tier: $tier, avatarPath: $avatarPath, gender: $gender, age: $age, identity: $identity, bio: $bio, lifeStatus: $lifeStatus, deathChapterId: $deathChapterId, deathReason: $deathReason, isArchived: $isArchived, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._aliases, _aliases) &&
            (identical(other.tier, tier) || other.tier == tier) &&
            (identical(other.avatarPath, avatarPath) ||
                other.avatarPath == avatarPath) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.age, age) || other.age == age) &&
            (identical(other.identity, identity) ||
                other.identity == identity) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.lifeStatus, lifeStatus) ||
                other.lifeStatus == lifeStatus) &&
            (identical(other.deathChapterId, deathChapterId) ||
                other.deathChapterId == deathChapterId) &&
            (identical(other.deathReason, deathReason) ||
                other.deathReason == deathReason) &&
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
      const DeepCollectionEquality().hash(_aliases),
      tier,
      avatarPath,
      gender,
      age,
      identity,
      bio,
      lifeStatus,
      deathChapterId,
      deathReason,
      isArchived,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterImplCopyWith<_$CharacterImpl> get copyWith =>
      __$$CharacterImplCopyWithImpl<_$CharacterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CharacterImplToJson(
      this,
    );
  }
}

abstract class _Character extends Character {
  const factory _Character(
      {required final String id,
      required final String workId,
      required final String name,
      final List<String> aliases,
      required final CharacterTier tier,
      final String? avatarPath,
      final String? gender,
      final String? age,
      final String? identity,
      final String? bio,
      final LifeStatus lifeStatus,
      final String? deathChapterId,
      final String? deathReason,
      final bool isArchived,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$CharacterImpl;
  const _Character._() : super._();

  factory _Character.fromJson(Map<String, dynamic> json) =
      _$CharacterImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get name;
  @override
  List<String> get aliases;
  @override
  CharacterTier get tier;
  @override
  String? get avatarPath;
  @override
  String? get gender;
  @override
  String? get age;
  @override
  String? get identity;
  @override
  String? get bio;
  @override
  LifeStatus get lifeStatus;
  @override
  String? get deathChapterId;
  @override
  String? get deathReason;
  @override
  bool get isArchived;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$CharacterImplCopyWith<_$CharacterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CreateCharacterParams {
  String get workId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<String>? get aliases => throw _privateConstructorUsedError;
  CharacterTier get tier => throw _privateConstructorUsedError;
  String? get avatarPath => throw _privateConstructorUsedError;
  String? get gender => throw _privateConstructorUsedError;
  String? get age => throw _privateConstructorUsedError;
  String? get identity => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $CreateCharacterParamsCopyWith<CreateCharacterParams> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CreateCharacterParamsCopyWith<$Res> {
  factory $CreateCharacterParamsCopyWith(CreateCharacterParams value,
          $Res Function(CreateCharacterParams) then) =
      _$CreateCharacterParamsCopyWithImpl<$Res, CreateCharacterParams>;
  @useResult
  $Res call(
      {String workId,
      String name,
      List<String>? aliases,
      CharacterTier tier,
      String? avatarPath,
      String? gender,
      String? age,
      String? identity,
      String? bio});
}

/// @nodoc
class _$CreateCharacterParamsCopyWithImpl<$Res,
        $Val extends CreateCharacterParams>
    implements $CreateCharacterParamsCopyWith<$Res> {
  _$CreateCharacterParamsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workId = null,
    Object? name = null,
    Object? aliases = freezed,
    Object? tier = null,
    Object? avatarPath = freezed,
    Object? gender = freezed,
    Object? age = freezed,
    Object? identity = freezed,
    Object? bio = freezed,
  }) {
    return _then(_value.copyWith(
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      aliases: freezed == aliases
          ? _value.aliases
          : aliases // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tier: null == tier
          ? _value.tier
          : tier // ignore: cast_nullable_to_non_nullable
              as CharacterTier,
      avatarPath: freezed == avatarPath
          ? _value.avatarPath
          : avatarPath // ignore: cast_nullable_to_non_nullable
              as String?,
      gender: freezed == gender
          ? _value.gender
          : gender // ignore: cast_nullable_to_non_nullable
              as String?,
      age: freezed == age
          ? _value.age
          : age // ignore: cast_nullable_to_non_nullable
              as String?,
      identity: freezed == identity
          ? _value.identity
          : identity // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CreateCharacterParamsImplCopyWith<$Res>
    implements $CreateCharacterParamsCopyWith<$Res> {
  factory _$$CreateCharacterParamsImplCopyWith(
          _$CreateCharacterParamsImpl value,
          $Res Function(_$CreateCharacterParamsImpl) then) =
      __$$CreateCharacterParamsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String workId,
      String name,
      List<String>? aliases,
      CharacterTier tier,
      String? avatarPath,
      String? gender,
      String? age,
      String? identity,
      String? bio});
}

/// @nodoc
class __$$CreateCharacterParamsImplCopyWithImpl<$Res>
    extends _$CreateCharacterParamsCopyWithImpl<$Res,
        _$CreateCharacterParamsImpl>
    implements _$$CreateCharacterParamsImplCopyWith<$Res> {
  __$$CreateCharacterParamsImplCopyWithImpl(_$CreateCharacterParamsImpl _value,
      $Res Function(_$CreateCharacterParamsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workId = null,
    Object? name = null,
    Object? aliases = freezed,
    Object? tier = null,
    Object? avatarPath = freezed,
    Object? gender = freezed,
    Object? age = freezed,
    Object? identity = freezed,
    Object? bio = freezed,
  }) {
    return _then(_$CreateCharacterParamsImpl(
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      aliases: freezed == aliases
          ? _value._aliases
          : aliases // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tier: null == tier
          ? _value.tier
          : tier // ignore: cast_nullable_to_non_nullable
              as CharacterTier,
      avatarPath: freezed == avatarPath
          ? _value.avatarPath
          : avatarPath // ignore: cast_nullable_to_non_nullable
              as String?,
      gender: freezed == gender
          ? _value.gender
          : gender // ignore: cast_nullable_to_non_nullable
              as String?,
      age: freezed == age
          ? _value.age
          : age // ignore: cast_nullable_to_non_nullable
              as String?,
      identity: freezed == identity
          ? _value.identity
          : identity // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$CreateCharacterParamsImpl implements _CreateCharacterParams {
  const _$CreateCharacterParamsImpl(
      {required this.workId,
      required this.name,
      final List<String>? aliases,
      required this.tier,
      this.avatarPath,
      this.gender,
      this.age,
      this.identity,
      this.bio})
      : _aliases = aliases;

  @override
  final String workId;
  @override
  final String name;
  final List<String>? _aliases;
  @override
  List<String>? get aliases {
    final value = _aliases;
    if (value == null) return null;
    if (_aliases is EqualUnmodifiableListView) return _aliases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final CharacterTier tier;
  @override
  final String? avatarPath;
  @override
  final String? gender;
  @override
  final String? age;
  @override
  final String? identity;
  @override
  final String? bio;

  @override
  String toString() {
    return 'CreateCharacterParams(workId: $workId, name: $name, aliases: $aliases, tier: $tier, avatarPath: $avatarPath, gender: $gender, age: $age, identity: $identity, bio: $bio)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CreateCharacterParamsImpl &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._aliases, _aliases) &&
            (identical(other.tier, tier) || other.tier == tier) &&
            (identical(other.avatarPath, avatarPath) ||
                other.avatarPath == avatarPath) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.age, age) || other.age == age) &&
            (identical(other.identity, identity) ||
                other.identity == identity) &&
            (identical(other.bio, bio) || other.bio == bio));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      workId,
      name,
      const DeepCollectionEquality().hash(_aliases),
      tier,
      avatarPath,
      gender,
      age,
      identity,
      bio);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CreateCharacterParamsImplCopyWith<_$CreateCharacterParamsImpl>
      get copyWith => __$$CreateCharacterParamsImplCopyWithImpl<
          _$CreateCharacterParamsImpl>(this, _$identity);
}

abstract class _CreateCharacterParams implements CreateCharacterParams {
  const factory _CreateCharacterParams(
      {required final String workId,
      required final String name,
      final List<String>? aliases,
      required final CharacterTier tier,
      final String? avatarPath,
      final String? gender,
      final String? age,
      final String? identity,
      final String? bio}) = _$CreateCharacterParamsImpl;

  @override
  String get workId;
  @override
  String get name;
  @override
  List<String>? get aliases;
  @override
  CharacterTier get tier;
  @override
  String? get avatarPath;
  @override
  String? get gender;
  @override
  String? get age;
  @override
  String? get identity;
  @override
  String? get bio;
  @override
  @JsonKey(ignore: true)
  _$$CreateCharacterParamsImplCopyWith<_$CreateCharacterParamsImpl>
      get copyWith => throw _privateConstructorUsedError;
}
