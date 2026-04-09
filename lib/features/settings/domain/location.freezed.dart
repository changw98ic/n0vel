// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'location.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Location _$LocationFromJson(Map<String, dynamic> json) {
  return _Location.fromJson(json);
}

/// @nodoc
mixin _$Location {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get type => throw _privateConstructorUsedError;
  String? get parentId => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  List<String> get importantPlaces => throw _privateConstructorUsedError;
  List<String> get characterIds => throw _privateConstructorUsedError;
  bool get isArchived => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LocationCopyWith<Location> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LocationCopyWith<$Res> {
  factory $LocationCopyWith(Location value, $Res Function(Location) then) =
      _$LocationCopyWithImpl<$Res, Location>;
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      String? type,
      String? parentId,
      String? description,
      List<String> importantPlaces,
      List<String> characterIds,
      bool isArchived,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$LocationCopyWithImpl<$Res, $Val extends Location>
    implements $LocationCopyWith<$Res> {
  _$LocationCopyWithImpl(this._value, this._then);

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
    Object? parentId = freezed,
    Object? description = freezed,
    Object? importantPlaces = null,
    Object? characterIds = null,
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
      parentId: freezed == parentId
          ? _value.parentId
          : parentId // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      importantPlaces: null == importantPlaces
          ? _value.importantPlaces
          : importantPlaces // ignore: cast_nullable_to_non_nullable
              as List<String>,
      characterIds: null == characterIds
          ? _value.characterIds
          : characterIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
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
abstract class _$$LocationImplCopyWith<$Res>
    implements $LocationCopyWith<$Res> {
  factory _$$LocationImplCopyWith(
          _$LocationImpl value, $Res Function(_$LocationImpl) then) =
      __$$LocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String workId,
      String name,
      String? type,
      String? parentId,
      String? description,
      List<String> importantPlaces,
      List<String> characterIds,
      bool isArchived,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$LocationImplCopyWithImpl<$Res>
    extends _$LocationCopyWithImpl<$Res, _$LocationImpl>
    implements _$$LocationImplCopyWith<$Res> {
  __$$LocationImplCopyWithImpl(
      _$LocationImpl _value, $Res Function(_$LocationImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? type = freezed,
    Object? parentId = freezed,
    Object? description = freezed,
    Object? importantPlaces = null,
    Object? characterIds = null,
    Object? isArchived = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$LocationImpl(
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
      parentId: freezed == parentId
          ? _value.parentId
          : parentId // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      importantPlaces: null == importantPlaces
          ? _value._importantPlaces
          : importantPlaces // ignore: cast_nullable_to_non_nullable
              as List<String>,
      characterIds: null == characterIds
          ? _value._characterIds
          : characterIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
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
class _$LocationImpl extends _Location {
  const _$LocationImpl(
      {required this.id,
      required this.workId,
      required this.name,
      this.type,
      this.parentId,
      this.description,
      final List<String> importantPlaces = const [],
      final List<String> characterIds = const [],
      this.isArchived = false,
      required this.createdAt,
      required this.updatedAt})
      : _importantPlaces = importantPlaces,
        _characterIds = characterIds,
        super._();

  factory _$LocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$LocationImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String name;
  @override
  final String? type;
  @override
  final String? parentId;
  @override
  final String? description;
  final List<String> _importantPlaces;
  @override
  @JsonKey()
  List<String> get importantPlaces {
    if (_importantPlaces is EqualUnmodifiableListView) return _importantPlaces;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_importantPlaces);
  }

  final List<String> _characterIds;
  @override
  @JsonKey()
  List<String> get characterIds {
    if (_characterIds is EqualUnmodifiableListView) return _characterIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_characterIds);
  }

  @override
  @JsonKey()
  final bool isArchived;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Location(id: $id, workId: $workId, name: $name, type: $type, parentId: $parentId, description: $description, importantPlaces: $importantPlaces, characterIds: $characterIds, isArchived: $isArchived, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LocationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other._importantPlaces, _importantPlaces) &&
            const DeepCollectionEquality()
                .equals(other._characterIds, _characterIds) &&
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
      parentId,
      description,
      const DeepCollectionEquality().hash(_importantPlaces),
      const DeepCollectionEquality().hash(_characterIds),
      isArchived,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$LocationImplCopyWith<_$LocationImpl> get copyWith =>
      __$$LocationImplCopyWithImpl<_$LocationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LocationImplToJson(
      this,
    );
  }
}

abstract class _Location extends Location {
  const factory _Location(
      {required final String id,
      required final String workId,
      required final String name,
      final String? type,
      final String? parentId,
      final String? description,
      final List<String> importantPlaces,
      final List<String> characterIds,
      final bool isArchived,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$LocationImpl;
  const _Location._() : super._();

  factory _Location.fromJson(Map<String, dynamic> json) =
      _$LocationImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get name;
  @override
  String? get type;
  @override
  String? get parentId;
  @override
  String? get description;
  @override
  List<String> get importantPlaces;
  @override
  List<String> get characterIds;
  @override
  bool get isArchived;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$LocationImplCopyWith<_$LocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LocationCharacter _$LocationCharacterFromJson(Map<String, dynamic> json) {
  return _LocationCharacter.fromJson(json);
}

/// @nodoc
mixin _$LocationCharacter {
  String get id => throw _privateConstructorUsedError;
  String get locationId => throw _privateConstructorUsedError;
  String get characterId => throw _privateConstructorUsedError;
  String? get relationship => throw _privateConstructorUsedError;
  String? get startChapterId => throw _privateConstructorUsedError;
  String? get endChapterId => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LocationCharacterCopyWith<LocationCharacter> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LocationCharacterCopyWith<$Res> {
  factory $LocationCharacterCopyWith(
          LocationCharacter value, $Res Function(LocationCharacter) then) =
      _$LocationCharacterCopyWithImpl<$Res, LocationCharacter>;
  @useResult
  $Res call(
      {String id,
      String locationId,
      String characterId,
      String? relationship,
      String? startChapterId,
      String? endChapterId,
      String status,
      DateTime createdAt});
}

/// @nodoc
class _$LocationCharacterCopyWithImpl<$Res, $Val extends LocationCharacter>
    implements $LocationCharacterCopyWith<$Res> {
  _$LocationCharacterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? locationId = null,
    Object? characterId = null,
    Object? relationship = freezed,
    Object? startChapterId = freezed,
    Object? endChapterId = freezed,
    Object? status = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      locationId: null == locationId
          ? _value.locationId
          : locationId // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      relationship: freezed == relationship
          ? _value.relationship
          : relationship // ignore: cast_nullable_to_non_nullable
              as String?,
      startChapterId: freezed == startChapterId
          ? _value.startChapterId
          : startChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      endChapterId: freezed == endChapterId
          ? _value.endChapterId
          : endChapterId // ignore: cast_nullable_to_non_nullable
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
abstract class _$$LocationCharacterImplCopyWith<$Res>
    implements $LocationCharacterCopyWith<$Res> {
  factory _$$LocationCharacterImplCopyWith(_$LocationCharacterImpl value,
          $Res Function(_$LocationCharacterImpl) then) =
      __$$LocationCharacterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String locationId,
      String characterId,
      String? relationship,
      String? startChapterId,
      String? endChapterId,
      String status,
      DateTime createdAt});
}

/// @nodoc
class __$$LocationCharacterImplCopyWithImpl<$Res>
    extends _$LocationCharacterCopyWithImpl<$Res, _$LocationCharacterImpl>
    implements _$$LocationCharacterImplCopyWith<$Res> {
  __$$LocationCharacterImplCopyWithImpl(_$LocationCharacterImpl _value,
      $Res Function(_$LocationCharacterImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? locationId = null,
    Object? characterId = null,
    Object? relationship = freezed,
    Object? startChapterId = freezed,
    Object? endChapterId = freezed,
    Object? status = null,
    Object? createdAt = null,
  }) {
    return _then(_$LocationCharacterImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      locationId: null == locationId
          ? _value.locationId
          : locationId // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      relationship: freezed == relationship
          ? _value.relationship
          : relationship // ignore: cast_nullable_to_non_nullable
              as String?,
      startChapterId: freezed == startChapterId
          ? _value.startChapterId
          : startChapterId // ignore: cast_nullable_to_non_nullable
              as String?,
      endChapterId: freezed == endChapterId
          ? _value.endChapterId
          : endChapterId // ignore: cast_nullable_to_non_nullable
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
class _$LocationCharacterImpl implements _LocationCharacter {
  const _$LocationCharacterImpl(
      {required this.id,
      required this.locationId,
      required this.characterId,
      this.relationship,
      this.startChapterId,
      this.endChapterId,
      this.status = 'active',
      required this.createdAt});

  factory _$LocationCharacterImpl.fromJson(Map<String, dynamic> json) =>
      _$$LocationCharacterImplFromJson(json);

  @override
  final String id;
  @override
  final String locationId;
  @override
  final String characterId;
  @override
  final String? relationship;
  @override
  final String? startChapterId;
  @override
  final String? endChapterId;
  @override
  @JsonKey()
  final String status;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'LocationCharacter(id: $id, locationId: $locationId, characterId: $characterId, relationship: $relationship, startChapterId: $startChapterId, endChapterId: $endChapterId, status: $status, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LocationCharacterImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.locationId, locationId) ||
                other.locationId == locationId) &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.relationship, relationship) ||
                other.relationship == relationship) &&
            (identical(other.startChapterId, startChapterId) ||
                other.startChapterId == startChapterId) &&
            (identical(other.endChapterId, endChapterId) ||
                other.endChapterId == endChapterId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, locationId, characterId,
      relationship, startChapterId, endChapterId, status, createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$LocationCharacterImplCopyWith<_$LocationCharacterImpl> get copyWith =>
      __$$LocationCharacterImplCopyWithImpl<_$LocationCharacterImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LocationCharacterImplToJson(
      this,
    );
  }
}

abstract class _LocationCharacter implements LocationCharacter {
  const factory _LocationCharacter(
      {required final String id,
      required final String locationId,
      required final String characterId,
      final String? relationship,
      final String? startChapterId,
      final String? endChapterId,
      final String status,
      required final DateTime createdAt}) = _$LocationCharacterImpl;

  factory _LocationCharacter.fromJson(Map<String, dynamic> json) =
      _$LocationCharacterImpl.fromJson;

  @override
  String get id;
  @override
  String get locationId;
  @override
  String get characterId;
  @override
  String? get relationship;
  @override
  String? get startChapterId;
  @override
  String? get endChapterId;
  @override
  String get status;
  @override
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$LocationCharacterImplCopyWith<_$LocationCharacterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
