// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ProviderConfig _$ProviderConfigFromJson(Map<String, dynamic> json) {
  return _ProviderConfig.fromJson(json);
}

/// @nodoc
mixin _$ProviderConfig {
  String get id => throw _privateConstructorUsedError;
  AIProviderType get type => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get apiKey => throw _privateConstructorUsedError; // 加密存储
  String? get apiEndpoint => throw _privateConstructorUsedError; // 自定义端点
  Map<String, String> get headers =>
      throw _privateConstructorUsedError; // 自定义请求头
  int get timeoutSeconds => throw _privateConstructorUsedError;
  int get maxRetries => throw _privateConstructorUsedError;
  bool get isEnabled => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ProviderConfigCopyWith<ProviderConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProviderConfigCopyWith<$Res> {
  factory $ProviderConfigCopyWith(
          ProviderConfig value, $Res Function(ProviderConfig) then) =
      _$ProviderConfigCopyWithImpl<$Res, ProviderConfig>;
  @useResult
  $Res call(
      {String id,
      AIProviderType type,
      String name,
      String? apiKey,
      String? apiEndpoint,
      Map<String, String> headers,
      int timeoutSeconds,
      int maxRetries,
      bool isEnabled,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$ProviderConfigCopyWithImpl<$Res, $Val extends ProviderConfig>
    implements $ProviderConfigCopyWith<$Res> {
  _$ProviderConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = null,
    Object? apiKey = freezed,
    Object? apiEndpoint = freezed,
    Object? headers = null,
    Object? timeoutSeconds = null,
    Object? maxRetries = null,
    Object? isEnabled = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AIProviderType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: freezed == apiKey
          ? _value.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String?,
      apiEndpoint: freezed == apiEndpoint
          ? _value.apiEndpoint
          : apiEndpoint // ignore: cast_nullable_to_non_nullable
              as String?,
      headers: null == headers
          ? _value.headers
          : headers // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      timeoutSeconds: null == timeoutSeconds
          ? _value.timeoutSeconds
          : timeoutSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxRetries: null == maxRetries
          ? _value.maxRetries
          : maxRetries // ignore: cast_nullable_to_non_nullable
              as int,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
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
abstract class _$$ProviderConfigImplCopyWith<$Res>
    implements $ProviderConfigCopyWith<$Res> {
  factory _$$ProviderConfigImplCopyWith(_$ProviderConfigImpl value,
          $Res Function(_$ProviderConfigImpl) then) =
      __$$ProviderConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      AIProviderType type,
      String name,
      String? apiKey,
      String? apiEndpoint,
      Map<String, String> headers,
      int timeoutSeconds,
      int maxRetries,
      bool isEnabled,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$ProviderConfigImplCopyWithImpl<$Res>
    extends _$ProviderConfigCopyWithImpl<$Res, _$ProviderConfigImpl>
    implements _$$ProviderConfigImplCopyWith<$Res> {
  __$$ProviderConfigImplCopyWithImpl(
      _$ProviderConfigImpl _value, $Res Function(_$ProviderConfigImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = null,
    Object? apiKey = freezed,
    Object? apiEndpoint = freezed,
    Object? headers = null,
    Object? timeoutSeconds = null,
    Object? maxRetries = null,
    Object? isEnabled = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ProviderConfigImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AIProviderType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: freezed == apiKey
          ? _value.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String?,
      apiEndpoint: freezed == apiEndpoint
          ? _value.apiEndpoint
          : apiEndpoint // ignore: cast_nullable_to_non_nullable
              as String?,
      headers: null == headers
          ? _value._headers
          : headers // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      timeoutSeconds: null == timeoutSeconds
          ? _value.timeoutSeconds
          : timeoutSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxRetries: null == maxRetries
          ? _value.maxRetries
          : maxRetries // ignore: cast_nullable_to_non_nullable
              as int,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
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
class _$ProviderConfigImpl extends _ProviderConfig {
  const _$ProviderConfigImpl(
      {required this.id,
      required this.type,
      required this.name,
      this.apiKey,
      this.apiEndpoint,
      final Map<String, String> headers = const {},
      this.timeoutSeconds = 30,
      this.maxRetries = 3,
      this.isEnabled = true,
      this.createdAt,
      this.updatedAt})
      : _headers = headers,
        super._();

  factory _$ProviderConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProviderConfigImplFromJson(json);

  @override
  final String id;
  @override
  final AIProviderType type;
  @override
  final String name;
  @override
  final String? apiKey;
// 加密存储
  @override
  final String? apiEndpoint;
// 自定义端点
  final Map<String, String> _headers;
// 自定义端点
  @override
  @JsonKey()
  Map<String, String> get headers {
    if (_headers is EqualUnmodifiableMapView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_headers);
  }

// 自定义请求头
  @override
  @JsonKey()
  final int timeoutSeconds;
  @override
  @JsonKey()
  final int maxRetries;
  @override
  @JsonKey()
  final bool isEnabled;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ProviderConfig(id: $id, type: $type, name: $name, apiKey: $apiKey, apiEndpoint: $apiEndpoint, headers: $headers, timeoutSeconds: $timeoutSeconds, maxRetries: $maxRetries, isEnabled: $isEnabled, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProviderConfigImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            (identical(other.apiEndpoint, apiEndpoint) ||
                other.apiEndpoint == apiEndpoint) &&
            const DeepCollectionEquality().equals(other._headers, _headers) &&
            (identical(other.timeoutSeconds, timeoutSeconds) ||
                other.timeoutSeconds == timeoutSeconds) &&
            (identical(other.maxRetries, maxRetries) ||
                other.maxRetries == maxRetries) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled) &&
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
      type,
      name,
      apiKey,
      apiEndpoint,
      const DeepCollectionEquality().hash(_headers),
      timeoutSeconds,
      maxRetries,
      isEnabled,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ProviderConfigImplCopyWith<_$ProviderConfigImpl> get copyWith =>
      __$$ProviderConfigImplCopyWithImpl<_$ProviderConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProviderConfigImplToJson(
      this,
    );
  }
}

abstract class _ProviderConfig extends ProviderConfig {
  const factory _ProviderConfig(
      {required final String id,
      required final AIProviderType type,
      required final String name,
      final String? apiKey,
      final String? apiEndpoint,
      final Map<String, String> headers,
      final int timeoutSeconds,
      final int maxRetries,
      final bool isEnabled,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$ProviderConfigImpl;
  const _ProviderConfig._() : super._();

  factory _ProviderConfig.fromJson(Map<String, dynamic> json) =
      _$ProviderConfigImpl.fromJson;

  @override
  String get id;
  @override
  AIProviderType get type;
  @override
  String get name;
  @override
  String? get apiKey;
  @override // 加密存储
  String? get apiEndpoint;
  @override // 自定义端点
  Map<String, String> get headers;
  @override // 自定义请求头
  int get timeoutSeconds;
  @override
  int get maxRetries;
  @override
  bool get isEnabled;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$ProviderConfigImplCopyWith<_$ProviderConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FunctionMapping _$FunctionMappingFromJson(Map<String, dynamic> json) {
  return _FunctionMapping.fromJson(json);
}

/// @nodoc
mixin _$FunctionMapping {
  String get functionKey => throw _privateConstructorUsedError; // 使用 key 而非枚举
  String? get overrideModelId =>
      throw _privateConstructorUsedError; // 覆盖默认层级，使用指定模型
  bool get useOverride => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FunctionMappingCopyWith<FunctionMapping> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FunctionMappingCopyWith<$Res> {
  factory $FunctionMappingCopyWith(
          FunctionMapping value, $Res Function(FunctionMapping) then) =
      _$FunctionMappingCopyWithImpl<$Res, FunctionMapping>;
  @useResult
  $Res call({String functionKey, String? overrideModelId, bool useOverride});
}

/// @nodoc
class _$FunctionMappingCopyWithImpl<$Res, $Val extends FunctionMapping>
    implements $FunctionMappingCopyWith<$Res> {
  _$FunctionMappingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? functionKey = null,
    Object? overrideModelId = freezed,
    Object? useOverride = null,
  }) {
    return _then(_value.copyWith(
      functionKey: null == functionKey
          ? _value.functionKey
          : functionKey // ignore: cast_nullable_to_non_nullable
              as String,
      overrideModelId: freezed == overrideModelId
          ? _value.overrideModelId
          : overrideModelId // ignore: cast_nullable_to_non_nullable
              as String?,
      useOverride: null == useOverride
          ? _value.useOverride
          : useOverride // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FunctionMappingImplCopyWith<$Res>
    implements $FunctionMappingCopyWith<$Res> {
  factory _$$FunctionMappingImplCopyWith(_$FunctionMappingImpl value,
          $Res Function(_$FunctionMappingImpl) then) =
      __$$FunctionMappingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String functionKey, String? overrideModelId, bool useOverride});
}

/// @nodoc
class __$$FunctionMappingImplCopyWithImpl<$Res>
    extends _$FunctionMappingCopyWithImpl<$Res, _$FunctionMappingImpl>
    implements _$$FunctionMappingImplCopyWith<$Res> {
  __$$FunctionMappingImplCopyWithImpl(
      _$FunctionMappingImpl _value, $Res Function(_$FunctionMappingImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? functionKey = null,
    Object? overrideModelId = freezed,
    Object? useOverride = null,
  }) {
    return _then(_$FunctionMappingImpl(
      functionKey: null == functionKey
          ? _value.functionKey
          : functionKey // ignore: cast_nullable_to_non_nullable
              as String,
      overrideModelId: freezed == overrideModelId
          ? _value.overrideModelId
          : overrideModelId // ignore: cast_nullable_to_non_nullable
              as String?,
      useOverride: null == useOverride
          ? _value.useOverride
          : useOverride // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FunctionMappingImpl extends _FunctionMapping {
  const _$FunctionMappingImpl(
      {required this.functionKey,
      this.overrideModelId,
      this.useOverride = false})
      : super._();

  factory _$FunctionMappingImpl.fromJson(Map<String, dynamic> json) =>
      _$$FunctionMappingImplFromJson(json);

  @override
  final String functionKey;
// 使用 key 而非枚举
  @override
  final String? overrideModelId;
// 覆盖默认层级，使用指定模型
  @override
  @JsonKey()
  final bool useOverride;

  @override
  String toString() {
    return 'FunctionMapping(functionKey: $functionKey, overrideModelId: $overrideModelId, useOverride: $useOverride)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FunctionMappingImpl &&
            (identical(other.functionKey, functionKey) ||
                other.functionKey == functionKey) &&
            (identical(other.overrideModelId, overrideModelId) ||
                other.overrideModelId == overrideModelId) &&
            (identical(other.useOverride, useOverride) ||
                other.useOverride == useOverride));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, functionKey, overrideModelId, useOverride);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FunctionMappingImplCopyWith<_$FunctionMappingImpl> get copyWith =>
      __$$FunctionMappingImplCopyWithImpl<_$FunctionMappingImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FunctionMappingImplToJson(
      this,
    );
  }
}

abstract class _FunctionMapping extends FunctionMapping {
  const factory _FunctionMapping(
      {required final String functionKey,
      final String? overrideModelId,
      final bool useOverride}) = _$FunctionMappingImpl;
  const _FunctionMapping._() : super._();

  factory _FunctionMapping.fromJson(Map<String, dynamic> json) =
      _$FunctionMappingImpl.fromJson;

  @override
  String get functionKey;
  @override // 使用 key 而非枚举
  String? get overrideModelId;
  @override // 覆盖默认层级，使用指定模型
  bool get useOverride;
  @override
  @JsonKey(ignore: true)
  _$$FunctionMappingImplCopyWith<_$FunctionMappingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
