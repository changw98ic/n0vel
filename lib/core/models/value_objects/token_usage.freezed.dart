// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'token_usage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TokenUsage {
  int get inputTokens => throw _privateConstructorUsedError;
  int get outputTokens => throw _privateConstructorUsedError;
  String get modelId => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TokenUsageCopyWith<TokenUsage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TokenUsageCopyWith<$Res> {
  factory $TokenUsageCopyWith(
          TokenUsage value, $Res Function(TokenUsage) then) =
      _$TokenUsageCopyWithImpl<$Res, TokenUsage>;
  @useResult
  $Res call(
      {int inputTokens, int outputTokens, String modelId, DateTime timestamp});
}

/// @nodoc
class _$TokenUsageCopyWithImpl<$Res, $Val extends TokenUsage>
    implements $TokenUsageCopyWith<$Res> {
  _$TokenUsageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputTokens = null,
    Object? outputTokens = null,
    Object? modelId = null,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      inputTokens: null == inputTokens
          ? _value.inputTokens
          : inputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      outputTokens: null == outputTokens
          ? _value.outputTokens
          : outputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      modelId: null == modelId
          ? _value.modelId
          : modelId // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TokenUsageImplCopyWith<$Res>
    implements $TokenUsageCopyWith<$Res> {
  factory _$$TokenUsageImplCopyWith(
          _$TokenUsageImpl value, $Res Function(_$TokenUsageImpl) then) =
      __$$TokenUsageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int inputTokens, int outputTokens, String modelId, DateTime timestamp});
}

/// @nodoc
class __$$TokenUsageImplCopyWithImpl<$Res>
    extends _$TokenUsageCopyWithImpl<$Res, _$TokenUsageImpl>
    implements _$$TokenUsageImplCopyWith<$Res> {
  __$$TokenUsageImplCopyWithImpl(
      _$TokenUsageImpl _value, $Res Function(_$TokenUsageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputTokens = null,
    Object? outputTokens = null,
    Object? modelId = null,
    Object? timestamp = null,
  }) {
    return _then(_$TokenUsageImpl(
      inputTokens: null == inputTokens
          ? _value.inputTokens
          : inputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      outputTokens: null == outputTokens
          ? _value.outputTokens
          : outputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      modelId: null == modelId
          ? _value.modelId
          : modelId // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class _$TokenUsageImpl extends _TokenUsage {
  const _$TokenUsageImpl(
      {required this.inputTokens,
      required this.outputTokens,
      required this.modelId,
      required this.timestamp})
      : super._();

  @override
  final int inputTokens;
  @override
  final int outputTokens;
  @override
  final String modelId;
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'TokenUsage(inputTokens: $inputTokens, outputTokens: $outputTokens, modelId: $modelId, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TokenUsageImpl &&
            (identical(other.inputTokens, inputTokens) ||
                other.inputTokens == inputTokens) &&
            (identical(other.outputTokens, outputTokens) ||
                other.outputTokens == outputTokens) &&
            (identical(other.modelId, modelId) || other.modelId == modelId) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, inputTokens, outputTokens, modelId, timestamp);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TokenUsageImplCopyWith<_$TokenUsageImpl> get copyWith =>
      __$$TokenUsageImplCopyWithImpl<_$TokenUsageImpl>(this, _$identity);
}

abstract class _TokenUsage extends TokenUsage {
  const factory _TokenUsage(
      {required final int inputTokens,
      required final int outputTokens,
      required final String modelId,
      required final DateTime timestamp}) = _$TokenUsageImpl;
  const _TokenUsage._() : super._();

  @override
  int get inputTokens;
  @override
  int get outputTokens;
  @override
  String get modelId;
  @override
  DateTime get timestamp;
  @override
  @JsonKey(ignore: true)
  _$$TokenUsageImplCopyWith<_$TokenUsageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TokenUsageStats {
  int get totalInputTokens => throw _privateConstructorUsedError;
  int get totalOutputTokens => throw _privateConstructorUsedError;
  int get requestCount => throw _privateConstructorUsedError;
  double get estimatedCost => throw _privateConstructorUsedError;
  Map<String, int> get byFunction => throw _privateConstructorUsedError;
  Map<String, int> get byModel => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TokenUsageStatsCopyWith<TokenUsageStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TokenUsageStatsCopyWith<$Res> {
  factory $TokenUsageStatsCopyWith(
          TokenUsageStats value, $Res Function(TokenUsageStats) then) =
      _$TokenUsageStatsCopyWithImpl<$Res, TokenUsageStats>;
  @useResult
  $Res call(
      {int totalInputTokens,
      int totalOutputTokens,
      int requestCount,
      double estimatedCost,
      Map<String, int> byFunction,
      Map<String, int> byModel});
}

/// @nodoc
class _$TokenUsageStatsCopyWithImpl<$Res, $Val extends TokenUsageStats>
    implements $TokenUsageStatsCopyWith<$Res> {
  _$TokenUsageStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalInputTokens = null,
    Object? totalOutputTokens = null,
    Object? requestCount = null,
    Object? estimatedCost = null,
    Object? byFunction = null,
    Object? byModel = null,
  }) {
    return _then(_value.copyWith(
      totalInputTokens: null == totalInputTokens
          ? _value.totalInputTokens
          : totalInputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      totalOutputTokens: null == totalOutputTokens
          ? _value.totalOutputTokens
          : totalOutputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      requestCount: null == requestCount
          ? _value.requestCount
          : requestCount // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedCost: null == estimatedCost
          ? _value.estimatedCost
          : estimatedCost // ignore: cast_nullable_to_non_nullable
              as double,
      byFunction: null == byFunction
          ? _value.byFunction
          : byFunction // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      byModel: null == byModel
          ? _value.byModel
          : byModel // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TokenUsageStatsImplCopyWith<$Res>
    implements $TokenUsageStatsCopyWith<$Res> {
  factory _$$TokenUsageStatsImplCopyWith(_$TokenUsageStatsImpl value,
          $Res Function(_$TokenUsageStatsImpl) then) =
      __$$TokenUsageStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int totalInputTokens,
      int totalOutputTokens,
      int requestCount,
      double estimatedCost,
      Map<String, int> byFunction,
      Map<String, int> byModel});
}

/// @nodoc
class __$$TokenUsageStatsImplCopyWithImpl<$Res>
    extends _$TokenUsageStatsCopyWithImpl<$Res, _$TokenUsageStatsImpl>
    implements _$$TokenUsageStatsImplCopyWith<$Res> {
  __$$TokenUsageStatsImplCopyWithImpl(
      _$TokenUsageStatsImpl _value, $Res Function(_$TokenUsageStatsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalInputTokens = null,
    Object? totalOutputTokens = null,
    Object? requestCount = null,
    Object? estimatedCost = null,
    Object? byFunction = null,
    Object? byModel = null,
  }) {
    return _then(_$TokenUsageStatsImpl(
      totalInputTokens: null == totalInputTokens
          ? _value.totalInputTokens
          : totalInputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      totalOutputTokens: null == totalOutputTokens
          ? _value.totalOutputTokens
          : totalOutputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      requestCount: null == requestCount
          ? _value.requestCount
          : requestCount // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedCost: null == estimatedCost
          ? _value.estimatedCost
          : estimatedCost // ignore: cast_nullable_to_non_nullable
              as double,
      byFunction: null == byFunction
          ? _value._byFunction
          : byFunction // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      byModel: null == byModel
          ? _value._byModel
          : byModel // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
}

/// @nodoc

class _$TokenUsageStatsImpl implements _TokenUsageStats {
  const _$TokenUsageStatsImpl(
      {required this.totalInputTokens,
      required this.totalOutputTokens,
      required this.requestCount,
      required this.estimatedCost,
      required final Map<String, int> byFunction,
      required final Map<String, int> byModel})
      : _byFunction = byFunction,
        _byModel = byModel;

  @override
  final int totalInputTokens;
  @override
  final int totalOutputTokens;
  @override
  final int requestCount;
  @override
  final double estimatedCost;
  final Map<String, int> _byFunction;
  @override
  Map<String, int> get byFunction {
    if (_byFunction is EqualUnmodifiableMapView) return _byFunction;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_byFunction);
  }

  final Map<String, int> _byModel;
  @override
  Map<String, int> get byModel {
    if (_byModel is EqualUnmodifiableMapView) return _byModel;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_byModel);
  }

  @override
  String toString() {
    return 'TokenUsageStats(totalInputTokens: $totalInputTokens, totalOutputTokens: $totalOutputTokens, requestCount: $requestCount, estimatedCost: $estimatedCost, byFunction: $byFunction, byModel: $byModel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TokenUsageStatsImpl &&
            (identical(other.totalInputTokens, totalInputTokens) ||
                other.totalInputTokens == totalInputTokens) &&
            (identical(other.totalOutputTokens, totalOutputTokens) ||
                other.totalOutputTokens == totalOutputTokens) &&
            (identical(other.requestCount, requestCount) ||
                other.requestCount == requestCount) &&
            (identical(other.estimatedCost, estimatedCost) ||
                other.estimatedCost == estimatedCost) &&
            const DeepCollectionEquality()
                .equals(other._byFunction, _byFunction) &&
            const DeepCollectionEquality().equals(other._byModel, _byModel));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalInputTokens,
      totalOutputTokens,
      requestCount,
      estimatedCost,
      const DeepCollectionEquality().hash(_byFunction),
      const DeepCollectionEquality().hash(_byModel));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TokenUsageStatsImplCopyWith<_$TokenUsageStatsImpl> get copyWith =>
      __$$TokenUsageStatsImplCopyWithImpl<_$TokenUsageStatsImpl>(
          this, _$identity);
}

abstract class _TokenUsageStats implements TokenUsageStats {
  const factory _TokenUsageStats(
      {required final int totalInputTokens,
      required final int totalOutputTokens,
      required final int requestCount,
      required final double estimatedCost,
      required final Map<String, int> byFunction,
      required final Map<String, int> byModel}) = _$TokenUsageStatsImpl;

  @override
  int get totalInputTokens;
  @override
  int get totalOutputTokens;
  @override
  int get requestCount;
  @override
  double get estimatedCost;
  @override
  Map<String, int> get byFunction;
  @override
  Map<String, int> get byModel;
  @override
  @JsonKey(ignore: true)
  _$$TokenUsageStatsImplCopyWith<_$TokenUsageStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
