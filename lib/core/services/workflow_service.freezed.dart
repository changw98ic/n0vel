// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workflow_service.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$NodeResult {
  String get nodeId => throw _privateConstructorUsedError;
  NodeStatus get status => throw _privateConstructorUsedError;
  dynamic get output => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  int? get inputTokens => throw _privateConstructorUsedError;
  int? get outputTokens => throw _privateConstructorUsedError;

  /// Create a copy of NodeResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NodeResultCopyWith<NodeResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NodeResultCopyWith<$Res> {
  factory $NodeResultCopyWith(
    NodeResult value,
    $Res Function(NodeResult) then,
  ) = _$NodeResultCopyWithImpl<$Res, NodeResult>;
  @useResult
  $Res call({
    String nodeId,
    NodeStatus status,
    dynamic output,
    String? error,
    int? inputTokens,
    int? outputTokens,
  });
}

/// @nodoc
class _$NodeResultCopyWithImpl<$Res, $Val extends NodeResult>
    implements $NodeResultCopyWith<$Res> {
  _$NodeResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NodeResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeId = null,
    Object? status = null,
    Object? output = freezed,
    Object? error = freezed,
    Object? inputTokens = freezed,
    Object? outputTokens = freezed,
  }) {
    return _then(
      _value.copyWith(
            nodeId: null == nodeId
                ? _value.nodeId
                : nodeId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as NodeStatus,
            output: freezed == output
                ? _value.output
                : output // ignore: cast_nullable_to_non_nullable
                      as dynamic,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
            inputTokens: freezed == inputTokens
                ? _value.inputTokens
                : inputTokens // ignore: cast_nullable_to_non_nullable
                      as int?,
            outputTokens: freezed == outputTokens
                ? _value.outputTokens
                : outputTokens // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NodeResultImplCopyWith<$Res>
    implements $NodeResultCopyWith<$Res> {
  factory _$$NodeResultImplCopyWith(
    _$NodeResultImpl value,
    $Res Function(_$NodeResultImpl) then,
  ) = __$$NodeResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String nodeId,
    NodeStatus status,
    dynamic output,
    String? error,
    int? inputTokens,
    int? outputTokens,
  });
}

/// @nodoc
class __$$NodeResultImplCopyWithImpl<$Res>
    extends _$NodeResultCopyWithImpl<$Res, _$NodeResultImpl>
    implements _$$NodeResultImplCopyWith<$Res> {
  __$$NodeResultImplCopyWithImpl(
    _$NodeResultImpl _value,
    $Res Function(_$NodeResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NodeResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeId = null,
    Object? status = null,
    Object? output = freezed,
    Object? error = freezed,
    Object? inputTokens = freezed,
    Object? outputTokens = freezed,
  }) {
    return _then(
      _$NodeResultImpl(
        nodeId: null == nodeId
            ? _value.nodeId
            : nodeId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as NodeStatus,
        output: freezed == output
            ? _value.output
            : output // ignore: cast_nullable_to_non_nullable
                  as dynamic,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        inputTokens: freezed == inputTokens
            ? _value.inputTokens
            : inputTokens // ignore: cast_nullable_to_non_nullable
                  as int?,
        outputTokens: freezed == outputTokens
            ? _value.outputTokens
            : outputTokens // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc

class _$NodeResultImpl implements _NodeResult {
  const _$NodeResultImpl({
    required this.nodeId,
    required this.status,
    this.output,
    this.error,
    this.inputTokens,
    this.outputTokens,
  });

  @override
  final String nodeId;
  @override
  final NodeStatus status;
  @override
  final dynamic output;
  @override
  final String? error;
  @override
  final int? inputTokens;
  @override
  final int? outputTokens;

  @override
  String toString() {
    return 'NodeResult(nodeId: $nodeId, status: $status, output: $output, error: $error, inputTokens: $inputTokens, outputTokens: $outputTokens)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NodeResultImpl &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.output, output) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.inputTokens, inputTokens) ||
                other.inputTokens == inputTokens) &&
            (identical(other.outputTokens, outputTokens) ||
                other.outputTokens == outputTokens));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    nodeId,
    status,
    const DeepCollectionEquality().hash(output),
    error,
    inputTokens,
    outputTokens,
  );

  /// Create a copy of NodeResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NodeResultImplCopyWith<_$NodeResultImpl> get copyWith =>
      __$$NodeResultImplCopyWithImpl<_$NodeResultImpl>(this, _$identity);
}

abstract class _NodeResult implements NodeResult {
  const factory _NodeResult({
    required final String nodeId,
    required final NodeStatus status,
    final dynamic output,
    final String? error,
    final int? inputTokens,
    final int? outputTokens,
  }) = _$NodeResultImpl;

  @override
  String get nodeId;
  @override
  NodeStatus get status;
  @override
  dynamic get output;
  @override
  String? get error;
  @override
  int? get inputTokens;
  @override
  int? get outputTokens;

  /// Create a copy of NodeResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NodeResultImplCopyWith<_$NodeResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
