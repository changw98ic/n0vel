// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'volume.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Volume _$VolumeFromJson(Map<String, dynamic> json) {
  return _Volume.fromJson(json);
}

/// @nodoc
mixin _$Volume {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Volume to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Volume
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VolumeCopyWith<Volume> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VolumeCopyWith<$Res> {
  factory $VolumeCopyWith(Volume value, $Res Function(Volume) then) =
      _$VolumeCopyWithImpl<$Res, Volume>;
  @useResult
  $Res call({
    String id,
    String workId,
    String name,
    int sortOrder,
    DateTime createdAt,
  });
}

/// @nodoc
class _$VolumeCopyWithImpl<$Res, $Val extends Volume>
    implements $VolumeCopyWith<$Res> {
  _$VolumeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Volume
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? sortOrder = null,
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
            sortOrder: null == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                      as int,
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
abstract class _$$VolumeImplCopyWith<$Res> implements $VolumeCopyWith<$Res> {
  factory _$$VolumeImplCopyWith(
    _$VolumeImpl value,
    $Res Function(_$VolumeImpl) then,
  ) = __$$VolumeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String workId,
    String name,
    int sortOrder,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$VolumeImplCopyWithImpl<$Res>
    extends _$VolumeCopyWithImpl<$Res, _$VolumeImpl>
    implements _$$VolumeImplCopyWith<$Res> {
  __$$VolumeImplCopyWithImpl(
    _$VolumeImpl _value,
    $Res Function(_$VolumeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Volume
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? name = null,
    Object? sortOrder = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$VolumeImpl(
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
        sortOrder: null == sortOrder
            ? _value.sortOrder
            : sortOrder // ignore: cast_nullable_to_non_nullable
                  as int,
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
class _$VolumeImpl extends _Volume {
  const _$VolumeImpl({
    required this.id,
    required this.workId,
    required this.name,
    this.sortOrder = 0,
    required this.createdAt,
  }) : super._();

  factory _$VolumeImpl.fromJson(Map<String, dynamic> json) =>
      _$$VolumeImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String name;
  @override
  @JsonKey()
  final int sortOrder;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Volume(id: $id, workId: $workId, name: $name, sortOrder: $sortOrder, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VolumeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, workId, name, sortOrder, createdAt);

  /// Create a copy of Volume
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VolumeImplCopyWith<_$VolumeImpl> get copyWith =>
      __$$VolumeImplCopyWithImpl<_$VolumeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VolumeImplToJson(this);
  }
}

abstract class _Volume extends Volume {
  const factory _Volume({
    required final String id,
    required final String workId,
    required final String name,
    final int sortOrder,
    required final DateTime createdAt,
  }) = _$VolumeImpl;
  const _Volume._() : super._();

  factory _Volume.fromJson(Map<String, dynamic> json) = _$VolumeImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get name;
  @override
  int get sortOrder;
  @override
  DateTime get createdAt;

  /// Create a copy of Volume
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VolumeImplCopyWith<_$VolumeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
