// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'emotion_dimensions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EmotionDimensions _$EmotionDimensionsFromJson(Map<String, dynamic> json) {
  return _EmotionDimensions.fromJson(json);
}

/// @nodoc
mixin _$EmotionDimensions {
  int get affection => throw _privateConstructorUsedError; // 好感度 0-100
  int get trust => throw _privateConstructorUsedError; // 信任度 0-100
  int get respect => throw _privateConstructorUsedError; // 尊敬度 0-100
  int get fear => throw _privateConstructorUsedError;

  /// Serializes this EmotionDimensions to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmotionDimensions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmotionDimensionsCopyWith<EmotionDimensions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmotionDimensionsCopyWith<$Res> {
  factory $EmotionDimensionsCopyWith(
    EmotionDimensions value,
    $Res Function(EmotionDimensions) then,
  ) = _$EmotionDimensionsCopyWithImpl<$Res, EmotionDimensions>;
  @useResult
  $Res call({int affection, int trust, int respect, int fear});
}

/// @nodoc
class _$EmotionDimensionsCopyWithImpl<$Res, $Val extends EmotionDimensions>
    implements $EmotionDimensionsCopyWith<$Res> {
  _$EmotionDimensionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmotionDimensions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? affection = null,
    Object? trust = null,
    Object? respect = null,
    Object? fear = null,
  }) {
    return _then(
      _value.copyWith(
            affection: null == affection
                ? _value.affection
                : affection // ignore: cast_nullable_to_non_nullable
                      as int,
            trust: null == trust
                ? _value.trust
                : trust // ignore: cast_nullable_to_non_nullable
                      as int,
            respect: null == respect
                ? _value.respect
                : respect // ignore: cast_nullable_to_non_nullable
                      as int,
            fear: null == fear
                ? _value.fear
                : fear // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EmotionDimensionsImplCopyWith<$Res>
    implements $EmotionDimensionsCopyWith<$Res> {
  factory _$$EmotionDimensionsImplCopyWith(
    _$EmotionDimensionsImpl value,
    $Res Function(_$EmotionDimensionsImpl) then,
  ) = __$$EmotionDimensionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int affection, int trust, int respect, int fear});
}

/// @nodoc
class __$$EmotionDimensionsImplCopyWithImpl<$Res>
    extends _$EmotionDimensionsCopyWithImpl<$Res, _$EmotionDimensionsImpl>
    implements _$$EmotionDimensionsImplCopyWith<$Res> {
  __$$EmotionDimensionsImplCopyWithImpl(
    _$EmotionDimensionsImpl _value,
    $Res Function(_$EmotionDimensionsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EmotionDimensions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? affection = null,
    Object? trust = null,
    Object? respect = null,
    Object? fear = null,
  }) {
    return _then(
      _$EmotionDimensionsImpl(
        affection: null == affection
            ? _value.affection
            : affection // ignore: cast_nullable_to_non_nullable
                  as int,
        trust: null == trust
            ? _value.trust
            : trust // ignore: cast_nullable_to_non_nullable
                  as int,
        respect: null == respect
            ? _value.respect
            : respect // ignore: cast_nullable_to_non_nullable
                  as int,
        fear: null == fear
            ? _value.fear
            : fear // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EmotionDimensionsImpl extends _EmotionDimensions {
  const _$EmotionDimensionsImpl({
    this.affection = 50,
    this.trust = 50,
    this.respect = 50,
    this.fear = 0,
  }) : super._();

  factory _$EmotionDimensionsImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmotionDimensionsImplFromJson(json);

  @override
  @JsonKey()
  final int affection;
  // 好感度 0-100
  @override
  @JsonKey()
  final int trust;
  // 信任度 0-100
  @override
  @JsonKey()
  final int respect;
  // 尊敬度 0-100
  @override
  @JsonKey()
  final int fear;

  @override
  String toString() {
    return 'EmotionDimensions(affection: $affection, trust: $trust, respect: $respect, fear: $fear)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmotionDimensionsImpl &&
            (identical(other.affection, affection) ||
                other.affection == affection) &&
            (identical(other.trust, trust) || other.trust == trust) &&
            (identical(other.respect, respect) || other.respect == respect) &&
            (identical(other.fear, fear) || other.fear == fear));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, affection, trust, respect, fear);

  /// Create a copy of EmotionDimensions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmotionDimensionsImplCopyWith<_$EmotionDimensionsImpl> get copyWith =>
      __$$EmotionDimensionsImplCopyWithImpl<_$EmotionDimensionsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EmotionDimensionsImplToJson(this);
  }
}

abstract class _EmotionDimensions extends EmotionDimensions {
  const factory _EmotionDimensions({
    final int affection,
    final int trust,
    final int respect,
    final int fear,
  }) = _$EmotionDimensionsImpl;
  const _EmotionDimensions._() : super._();

  factory _EmotionDimensions.fromJson(Map<String, dynamic> json) =
      _$EmotionDimensionsImpl.fromJson;

  @override
  int get affection; // 好感度 0-100
  @override
  int get trust; // 信任度 0-100
  @override
  int get respect; // 尊敬度 0-100
  @override
  int get fear;

  /// Create a copy of EmotionDimensions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmotionDimensionsImplCopyWith<_$EmotionDimensionsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$EmotionChange {
  int get affectionDelta => throw _privateConstructorUsedError;
  int get trustDelta => throw _privateConstructorUsedError;
  int get respectDelta => throw _privateConstructorUsedError;
  int get fearDelta => throw _privateConstructorUsedError;

  /// Create a copy of EmotionChange
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmotionChangeCopyWith<EmotionChange> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmotionChangeCopyWith<$Res> {
  factory $EmotionChangeCopyWith(
    EmotionChange value,
    $Res Function(EmotionChange) then,
  ) = _$EmotionChangeCopyWithImpl<$Res, EmotionChange>;
  @useResult
  $Res call({
    int affectionDelta,
    int trustDelta,
    int respectDelta,
    int fearDelta,
  });
}

/// @nodoc
class _$EmotionChangeCopyWithImpl<$Res, $Val extends EmotionChange>
    implements $EmotionChangeCopyWith<$Res> {
  _$EmotionChangeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmotionChange
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? affectionDelta = null,
    Object? trustDelta = null,
    Object? respectDelta = null,
    Object? fearDelta = null,
  }) {
    return _then(
      _value.copyWith(
            affectionDelta: null == affectionDelta
                ? _value.affectionDelta
                : affectionDelta // ignore: cast_nullable_to_non_nullable
                      as int,
            trustDelta: null == trustDelta
                ? _value.trustDelta
                : trustDelta // ignore: cast_nullable_to_non_nullable
                      as int,
            respectDelta: null == respectDelta
                ? _value.respectDelta
                : respectDelta // ignore: cast_nullable_to_non_nullable
                      as int,
            fearDelta: null == fearDelta
                ? _value.fearDelta
                : fearDelta // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EmotionChangeImplCopyWith<$Res>
    implements $EmotionChangeCopyWith<$Res> {
  factory _$$EmotionChangeImplCopyWith(
    _$EmotionChangeImpl value,
    $Res Function(_$EmotionChangeImpl) then,
  ) = __$$EmotionChangeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int affectionDelta,
    int trustDelta,
    int respectDelta,
    int fearDelta,
  });
}

/// @nodoc
class __$$EmotionChangeImplCopyWithImpl<$Res>
    extends _$EmotionChangeCopyWithImpl<$Res, _$EmotionChangeImpl>
    implements _$$EmotionChangeImplCopyWith<$Res> {
  __$$EmotionChangeImplCopyWithImpl(
    _$EmotionChangeImpl _value,
    $Res Function(_$EmotionChangeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EmotionChange
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? affectionDelta = null,
    Object? trustDelta = null,
    Object? respectDelta = null,
    Object? fearDelta = null,
  }) {
    return _then(
      _$EmotionChangeImpl(
        affectionDelta: null == affectionDelta
            ? _value.affectionDelta
            : affectionDelta // ignore: cast_nullable_to_non_nullable
                  as int,
        trustDelta: null == trustDelta
            ? _value.trustDelta
            : trustDelta // ignore: cast_nullable_to_non_nullable
                  as int,
        respectDelta: null == respectDelta
            ? _value.respectDelta
            : respectDelta // ignore: cast_nullable_to_non_nullable
                  as int,
        fearDelta: null == fearDelta
            ? _value.fearDelta
            : fearDelta // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$EmotionChangeImpl extends _EmotionChange {
  const _$EmotionChangeImpl({
    required this.affectionDelta,
    required this.trustDelta,
    required this.respectDelta,
    required this.fearDelta,
  }) : super._();

  @override
  final int affectionDelta;
  @override
  final int trustDelta;
  @override
  final int respectDelta;
  @override
  final int fearDelta;

  @override
  String toString() {
    return 'EmotionChange(affectionDelta: $affectionDelta, trustDelta: $trustDelta, respectDelta: $respectDelta, fearDelta: $fearDelta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmotionChangeImpl &&
            (identical(other.affectionDelta, affectionDelta) ||
                other.affectionDelta == affectionDelta) &&
            (identical(other.trustDelta, trustDelta) ||
                other.trustDelta == trustDelta) &&
            (identical(other.respectDelta, respectDelta) ||
                other.respectDelta == respectDelta) &&
            (identical(other.fearDelta, fearDelta) ||
                other.fearDelta == fearDelta));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    affectionDelta,
    trustDelta,
    respectDelta,
    fearDelta,
  );

  /// Create a copy of EmotionChange
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmotionChangeImplCopyWith<_$EmotionChangeImpl> get copyWith =>
      __$$EmotionChangeImplCopyWithImpl<_$EmotionChangeImpl>(this, _$identity);
}

abstract class _EmotionChange extends EmotionChange {
  const factory _EmotionChange({
    required final int affectionDelta,
    required final int trustDelta,
    required final int respectDelta,
    required final int fearDelta,
  }) = _$EmotionChangeImpl;
  const _EmotionChange._() : super._();

  @override
  int get affectionDelta;
  @override
  int get trustDelta;
  @override
  int get respectDelta;
  @override
  int get fearDelta;

  /// Create a copy of EmotionChange
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmotionChangeImplCopyWith<_$EmotionChangeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
