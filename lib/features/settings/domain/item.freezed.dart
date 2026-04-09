// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Item _$ItemFromJson(Map<String, dynamic> json) {
  return _Item.fromJson(json);
}

/// @nodoc
mixin _$Item {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get type => throw _privateConstructorUsedError;
  String? get rarity => throw _privateConstructorUsedError;
  String? get iconPath => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  List<String> get abilities => throw _privateConstructorUsedError;
  String? get holderId => throw _privateConstructorUsedError;
  bool get isArchived => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ItemCopyWith<Item> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ItemCopyWith<$Res> {
  factory $ItemCopyWith(Item value, $Res Function(Item) then) =
      _$ItemCopyWithImpl<$Res, Item>;
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      String? type,
      String? rarity,
      String? iconPath,
      String? description,
      List<String> abilities,
      String? holderId,
      bool isArchived,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$ItemCopyWithImpl<$Res, $Val extends Item>
    implements $ItemCopyWith<$Res> {
  _$ItemCopyWithImpl(this._value, this._then);

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
    Object? rarity = freezed,
    Object? iconPath = freezed,
    Object? description = freezed,
    Object? abilities = null,
    Object? holderId = freezed,
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
      rarity: freezed == rarity
          ? _value.rarity
          : rarity // ignore: cast_nullable_to_non_nullable
              as String?,
      iconPath: freezed == iconPath
          ? _value.iconPath
          : iconPath // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      abilities: null == abilities
          ? _value.abilities
          : abilities // ignore: cast_nullable_to_non_nullable
              as List<String>,
      holderId: freezed == holderId
          ? _value.holderId
          : holderId // ignore: cast_nullable_to_non_nullable
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
abstract class _$$ItemImplCopyWith<$Res> implements $ItemCopyWith<$Res> {
  factory _$$ItemImplCopyWith(
          _$ItemImpl value, $Res Function(_$ItemImpl) then) =
      __$$ItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      String? type,
      String? rarity,
      String? iconPath,
      String? description,
      List<String> abilities,
      String? holderId,
      bool isArchived,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$ItemImplCopyWithImpl<$Res>
    extends _$ItemCopyWithImpl<$Res, _$ItemImpl>
    implements _$$ItemImplCopyWith<$Res> {
  __$$ItemImplCopyWithImpl(_$ItemImpl _value, $Res Function(_$ItemImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? type = freezed,
    Object? rarity = freezed,
    Object? iconPath = freezed,
    Object? description = freezed,
    Object? abilities = null,
    Object? holderId = freezed,
    Object? isArchived = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$ItemImpl(
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
      rarity: freezed == rarity
          ? _value.rarity
          : rarity // ignore: cast_nullable_to_non_nullable
              as String?,
      iconPath: freezed == iconPath
          ? _value.iconPath
          : iconPath // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      abilities: null == abilities
          ? _value._abilities
          : abilities // ignore: cast_nullable_to_non_nullable
              as List<String>,
      holderId: freezed == holderId
          ? _value.holderId
          : holderId // ignore: cast_nullable_to_non_nullable
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
class _$ItemImpl extends _Item {
  const _$ItemImpl(
      {required this.id,
      required this.workId,
      required this.name,
      this.type,
      this.rarity,
      this.iconPath,
      this.description,
      final List<String> abilities = const [],
      this.holderId,
      this.isArchived = false,
      required this.createdAt,
      required this.updatedAt})
      : _abilities = abilities,
        super._();

  factory _$ItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ItemImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String name;
  @override
  final String? type;
  @override
  final String? rarity;
  @override
  final String? iconPath;
  @override
  final String? description;
  final List<String> _abilities;
  @override
  @JsonKey()
  List<String> get abilities {
    if (_abilities is EqualUnmodifiableListView) return _abilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_abilities);
  }

  @override
  final String? holderId;
  @override
  @JsonKey()
  final bool isArchived;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Item(id: $id, workId: $workId, name: $name, type: $type, rarity: $rarity, iconPath: $iconPath, description: $description, abilities: $abilities, holderId: $holderId, isArchived: $isArchived, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.rarity, rarity) || other.rarity == rarity) &&
            (identical(other.iconPath, iconPath) ||
                other.iconPath == iconPath) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other._abilities, _abilities) &&
            (identical(other.holderId, holderId) ||
                other.holderId == holderId) &&
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
      rarity,
      iconPath,
      description,
      const DeepCollectionEquality().hash(_abilities),
      holderId,
      isArchived,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ItemImplCopyWith<_$ItemImpl> get copyWith =>
      __$$ItemImplCopyWithImpl<_$ItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ItemImplToJson(
      this,
    );
  }
}

abstract class _Item extends Item {
  const factory _Item(
      {required final String id,
      required final String workId,
      required final String name,
      final String? type,
      final String? rarity,
      final String? iconPath,
      final String? description,
      final List<String> abilities,
      final String? holderId,
      final bool isArchived,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$ItemImpl;
  const _Item._() : super._();

  factory _Item.fromJson(Map<String, dynamic> json) = _$ItemImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get name;
  @override
  String? get type;
  @override
  String? get rarity;
  @override
  String? get iconPath;
  @override
  String? get description;
  @override
  List<String> get abilities;
  @override
  String? get holderId;
  @override
  bool get isArchived;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$ItemImplCopyWith<_$ItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
