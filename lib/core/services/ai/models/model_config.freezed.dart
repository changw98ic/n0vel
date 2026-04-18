// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ModelConfig _$ModelConfigFromJson(Map<String, dynamic> json) {
  return _ModelConfig.fromJson(json);
}

/// @nodoc
mixin _$ModelConfig {
  String get id => throw _privateConstructorUsedError;
  ModelTier get tier => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String get providerType => throw _privateConstructorUsedError;
  String get modelName => throw _privateConstructorUsedError;
  String? get apiEndpoint => throw _privateConstructorUsedError;
  double get temperature => throw _privateConstructorUsedError;
  int get maxOutputTokens => throw _privateConstructorUsedError;
  double get topP => throw _privateConstructorUsedError;
  double get frequencyPenalty => throw _privateConstructorUsedError;
  double get presencePenalty => throw _privateConstructorUsedError;
  bool get isEnabled => throw _privateConstructorUsedError;
  DateTime? get lastValidatedAt => throw _privateConstructorUsedError;
  bool get isValid => throw _privateConstructorUsedError;

  /// Serializes this ModelConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ModelConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ModelConfigCopyWith<ModelConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModelConfigCopyWith<$Res> {
  factory $ModelConfigCopyWith(
    ModelConfig value,
    $Res Function(ModelConfig) then,
  ) = _$ModelConfigCopyWithImpl<$Res, ModelConfig>;
  @useResult
  $Res call({
    String id,
    ModelTier tier,
    String displayName,
    String providerType,
    String modelName,
    String? apiEndpoint,
    double temperature,
    int maxOutputTokens,
    double topP,
    double frequencyPenalty,
    double presencePenalty,
    bool isEnabled,
    DateTime? lastValidatedAt,
    bool isValid,
  });
}

/// @nodoc
class _$ModelConfigCopyWithImpl<$Res, $Val extends ModelConfig>
    implements $ModelConfigCopyWith<$Res> {
  _$ModelConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ModelConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tier = null,
    Object? displayName = null,
    Object? providerType = null,
    Object? modelName = null,
    Object? apiEndpoint = freezed,
    Object? temperature = null,
    Object? maxOutputTokens = null,
    Object? topP = null,
    Object? frequencyPenalty = null,
    Object? presencePenalty = null,
    Object? isEnabled = null,
    Object? lastValidatedAt = freezed,
    Object? isValid = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            tier: null == tier
                ? _value.tier
                : tier // ignore: cast_nullable_to_non_nullable
                      as ModelTier,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            providerType: null == providerType
                ? _value.providerType
                : providerType // ignore: cast_nullable_to_non_nullable
                      as String,
            modelName: null == modelName
                ? _value.modelName
                : modelName // ignore: cast_nullable_to_non_nullable
                      as String,
            apiEndpoint: freezed == apiEndpoint
                ? _value.apiEndpoint
                : apiEndpoint // ignore: cast_nullable_to_non_nullable
                      as String?,
            temperature: null == temperature
                ? _value.temperature
                : temperature // ignore: cast_nullable_to_non_nullable
                      as double,
            maxOutputTokens: null == maxOutputTokens
                ? _value.maxOutputTokens
                : maxOutputTokens // ignore: cast_nullable_to_non_nullable
                      as int,
            topP: null == topP
                ? _value.topP
                : topP // ignore: cast_nullable_to_non_nullable
                      as double,
            frequencyPenalty: null == frequencyPenalty
                ? _value.frequencyPenalty
                : frequencyPenalty // ignore: cast_nullable_to_non_nullable
                      as double,
            presencePenalty: null == presencePenalty
                ? _value.presencePenalty
                : presencePenalty // ignore: cast_nullable_to_non_nullable
                      as double,
            isEnabled: null == isEnabled
                ? _value.isEnabled
                : isEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            lastValidatedAt: freezed == lastValidatedAt
                ? _value.lastValidatedAt
                : lastValidatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isValid: null == isValid
                ? _value.isValid
                : isValid // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ModelConfigImplCopyWith<$Res>
    implements $ModelConfigCopyWith<$Res> {
  factory _$$ModelConfigImplCopyWith(
    _$ModelConfigImpl value,
    $Res Function(_$ModelConfigImpl) then,
  ) = __$$ModelConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    ModelTier tier,
    String displayName,
    String providerType,
    String modelName,
    String? apiEndpoint,
    double temperature,
    int maxOutputTokens,
    double topP,
    double frequencyPenalty,
    double presencePenalty,
    bool isEnabled,
    DateTime? lastValidatedAt,
    bool isValid,
  });
}

/// @nodoc
class __$$ModelConfigImplCopyWithImpl<$Res>
    extends _$ModelConfigCopyWithImpl<$Res, _$ModelConfigImpl>
    implements _$$ModelConfigImplCopyWith<$Res> {
  __$$ModelConfigImplCopyWithImpl(
    _$ModelConfigImpl _value,
    $Res Function(_$ModelConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ModelConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tier = null,
    Object? displayName = null,
    Object? providerType = null,
    Object? modelName = null,
    Object? apiEndpoint = freezed,
    Object? temperature = null,
    Object? maxOutputTokens = null,
    Object? topP = null,
    Object? frequencyPenalty = null,
    Object? presencePenalty = null,
    Object? isEnabled = null,
    Object? lastValidatedAt = freezed,
    Object? isValid = null,
  }) {
    return _then(
      _$ModelConfigImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        tier: null == tier
            ? _value.tier
            : tier // ignore: cast_nullable_to_non_nullable
                  as ModelTier,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        providerType: null == providerType
            ? _value.providerType
            : providerType // ignore: cast_nullable_to_non_nullable
                  as String,
        modelName: null == modelName
            ? _value.modelName
            : modelName // ignore: cast_nullable_to_non_nullable
                  as String,
        apiEndpoint: freezed == apiEndpoint
            ? _value.apiEndpoint
            : apiEndpoint // ignore: cast_nullable_to_non_nullable
                  as String?,
        temperature: null == temperature
            ? _value.temperature
            : temperature // ignore: cast_nullable_to_non_nullable
                  as double,
        maxOutputTokens: null == maxOutputTokens
            ? _value.maxOutputTokens
            : maxOutputTokens // ignore: cast_nullable_to_non_nullable
                  as int,
        topP: null == topP
            ? _value.topP
            : topP // ignore: cast_nullable_to_non_nullable
                  as double,
        frequencyPenalty: null == frequencyPenalty
            ? _value.frequencyPenalty
            : frequencyPenalty // ignore: cast_nullable_to_non_nullable
                  as double,
        presencePenalty: null == presencePenalty
            ? _value.presencePenalty
            : presencePenalty // ignore: cast_nullable_to_non_nullable
                  as double,
        isEnabled: null == isEnabled
            ? _value.isEnabled
            : isEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastValidatedAt: freezed == lastValidatedAt
            ? _value.lastValidatedAt
            : lastValidatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isValid: null == isValid
            ? _value.isValid
            : isValid // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ModelConfigImpl extends _ModelConfig {
  const _$ModelConfigImpl({
    required this.id,
    required this.tier,
    required this.displayName,
    required this.providerType,
    required this.modelName,
    this.apiEndpoint,
    this.temperature = 0.7,
    this.maxOutputTokens = 16384,
    this.topP = 1.0,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.isEnabled = true,
    this.lastValidatedAt,
    this.isValid = false,
  }) : super._();

  factory _$ModelConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModelConfigImplFromJson(json);

  @override
  final String id;
  @override
  final ModelTier tier;
  @override
  final String displayName;
  @override
  final String providerType;
  @override
  final String modelName;
  @override
  final String? apiEndpoint;
  @override
  @JsonKey()
  final double temperature;
  @override
  @JsonKey()
  final int maxOutputTokens;
  @override
  @JsonKey()
  final double topP;
  @override
  @JsonKey()
  final double frequencyPenalty;
  @override
  @JsonKey()
  final double presencePenalty;
  @override
  @JsonKey()
  final bool isEnabled;
  @override
  final DateTime? lastValidatedAt;
  @override
  @JsonKey()
  final bool isValid;

  @override
  String toString() {
    return 'ModelConfig(id: $id, tier: $tier, displayName: $displayName, providerType: $providerType, modelName: $modelName, apiEndpoint: $apiEndpoint, temperature: $temperature, maxOutputTokens: $maxOutputTokens, topP: $topP, frequencyPenalty: $frequencyPenalty, presencePenalty: $presencePenalty, isEnabled: $isEnabled, lastValidatedAt: $lastValidatedAt, isValid: $isValid)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModelConfigImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tier, tier) || other.tier == tier) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.providerType, providerType) ||
                other.providerType == providerType) &&
            (identical(other.modelName, modelName) ||
                other.modelName == modelName) &&
            (identical(other.apiEndpoint, apiEndpoint) ||
                other.apiEndpoint == apiEndpoint) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature) &&
            (identical(other.maxOutputTokens, maxOutputTokens) ||
                other.maxOutputTokens == maxOutputTokens) &&
            (identical(other.topP, topP) || other.topP == topP) &&
            (identical(other.frequencyPenalty, frequencyPenalty) ||
                other.frequencyPenalty == frequencyPenalty) &&
            (identical(other.presencePenalty, presencePenalty) ||
                other.presencePenalty == presencePenalty) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled) &&
            (identical(other.lastValidatedAt, lastValidatedAt) ||
                other.lastValidatedAt == lastValidatedAt) &&
            (identical(other.isValid, isValid) || other.isValid == isValid));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tier,
    displayName,
    providerType,
    modelName,
    apiEndpoint,
    temperature,
    maxOutputTokens,
    topP,
    frequencyPenalty,
    presencePenalty,
    isEnabled,
    lastValidatedAt,
    isValid,
  );

  /// Create a copy of ModelConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ModelConfigImplCopyWith<_$ModelConfigImpl> get copyWith =>
      __$$ModelConfigImplCopyWithImpl<_$ModelConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ModelConfigImplToJson(this);
  }
}

abstract class _ModelConfig extends ModelConfig {
  const factory _ModelConfig({
    required final String id,
    required final ModelTier tier,
    required final String displayName,
    required final String providerType,
    required final String modelName,
    final String? apiEndpoint,
    final double temperature,
    final int maxOutputTokens,
    final double topP,
    final double frequencyPenalty,
    final double presencePenalty,
    final bool isEnabled,
    final DateTime? lastValidatedAt,
    final bool isValid,
  }) = _$ModelConfigImpl;
  const _ModelConfig._() : super._();

  factory _ModelConfig.fromJson(Map<String, dynamic> json) =
      _$ModelConfigImpl.fromJson;

  @override
  String get id;
  @override
  ModelTier get tier;
  @override
  String get displayName;
  @override
  String get providerType;
  @override
  String get modelName;
  @override
  String? get apiEndpoint;
  @override
  double get temperature;
  @override
  int get maxOutputTokens;
  @override
  double get topP;
  @override
  double get frequencyPenalty;
  @override
  double get presencePenalty;
  @override
  bool get isEnabled;
  @override
  DateTime? get lastValidatedAt;
  @override
  bool get isValid;

  /// Create a copy of ModelConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ModelConfigImplCopyWith<_$ModelConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
