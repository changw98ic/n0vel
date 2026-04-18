// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_service.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AIResponse {
  String get content => throw _privateConstructorUsedError;
  int get inputTokens => throw _privateConstructorUsedError;
  int get outputTokens => throw _privateConstructorUsedError;
  String get modelId => throw _privateConstructorUsedError;
  Duration get responseTime => throw _privateConstructorUsedError;
  bool get fromCache => throw _privateConstructorUsedError;
  String? get requestId => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;
  List<ToolCall> get toolCalls => throw _privateConstructorUsedError;
  String? get thinking => throw _privateConstructorUsedError;

  /// Create a copy of AIResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AIResponseCopyWith<AIResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AIResponseCopyWith<$Res> {
  factory $AIResponseCopyWith(
    AIResponse value,
    $Res Function(AIResponse) then,
  ) = _$AIResponseCopyWithImpl<$Res, AIResponse>;
  @useResult
  $Res call({
    String content,
    int inputTokens,
    int outputTokens,
    String modelId,
    Duration responseTime,
    bool fromCache,
    String? requestId,
    Map<String, dynamic>? metadata,
    List<ToolCall> toolCalls,
    String? thinking,
  });
}

/// @nodoc
class _$AIResponseCopyWithImpl<$Res, $Val extends AIResponse>
    implements $AIResponseCopyWith<$Res> {
  _$AIResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AIResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? inputTokens = null,
    Object? outputTokens = null,
    Object? modelId = null,
    Object? responseTime = null,
    Object? fromCache = null,
    Object? requestId = freezed,
    Object? metadata = freezed,
    Object? toolCalls = null,
    Object? thinking = freezed,
  }) {
    return _then(
      _value.copyWith(
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
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
            responseTime: null == responseTime
                ? _value.responseTime
                : responseTime // ignore: cast_nullable_to_non_nullable
                      as Duration,
            fromCache: null == fromCache
                ? _value.fromCache
                : fromCache // ignore: cast_nullable_to_non_nullable
                      as bool,
            requestId: freezed == requestId
                ? _value.requestId
                : requestId // ignore: cast_nullable_to_non_nullable
                      as String?,
            metadata: freezed == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            toolCalls: null == toolCalls
                ? _value.toolCalls
                : toolCalls // ignore: cast_nullable_to_non_nullable
                      as List<ToolCall>,
            thinking: freezed == thinking
                ? _value.thinking
                : thinking // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AIResponseImplCopyWith<$Res>
    implements $AIResponseCopyWith<$Res> {
  factory _$$AIResponseImplCopyWith(
    _$AIResponseImpl value,
    $Res Function(_$AIResponseImpl) then,
  ) = __$$AIResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String content,
    int inputTokens,
    int outputTokens,
    String modelId,
    Duration responseTime,
    bool fromCache,
    String? requestId,
    Map<String, dynamic>? metadata,
    List<ToolCall> toolCalls,
    String? thinking,
  });
}

/// @nodoc
class __$$AIResponseImplCopyWithImpl<$Res>
    extends _$AIResponseCopyWithImpl<$Res, _$AIResponseImpl>
    implements _$$AIResponseImplCopyWith<$Res> {
  __$$AIResponseImplCopyWithImpl(
    _$AIResponseImpl _value,
    $Res Function(_$AIResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AIResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? inputTokens = null,
    Object? outputTokens = null,
    Object? modelId = null,
    Object? responseTime = null,
    Object? fromCache = null,
    Object? requestId = freezed,
    Object? metadata = freezed,
    Object? toolCalls = null,
    Object? thinking = freezed,
  }) {
    return _then(
      _$AIResponseImpl(
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
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
        responseTime: null == responseTime
            ? _value.responseTime
            : responseTime // ignore: cast_nullable_to_non_nullable
                  as Duration,
        fromCache: null == fromCache
            ? _value.fromCache
            : fromCache // ignore: cast_nullable_to_non_nullable
                  as bool,
        requestId: freezed == requestId
            ? _value.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as String?,
        metadata: freezed == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        toolCalls: null == toolCalls
            ? _value._toolCalls
            : toolCalls // ignore: cast_nullable_to_non_nullable
                  as List<ToolCall>,
        thinking: freezed == thinking
            ? _value.thinking
            : thinking // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$AIResponseImpl implements _AIResponse {
  const _$AIResponseImpl({
    required this.content,
    required this.inputTokens,
    required this.outputTokens,
    required this.modelId,
    required this.responseTime,
    required this.fromCache,
    this.requestId,
    final Map<String, dynamic>? metadata,
    final List<ToolCall> toolCalls = const [],
    this.thinking,
  }) : _metadata = metadata,
       _toolCalls = toolCalls;

  @override
  final String content;
  @override
  final int inputTokens;
  @override
  final int outputTokens;
  @override
  final String modelId;
  @override
  final Duration responseTime;
  @override
  final bool fromCache;
  @override
  final String? requestId;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final List<ToolCall> _toolCalls;
  @override
  @JsonKey()
  List<ToolCall> get toolCalls {
    if (_toolCalls is EqualUnmodifiableListView) return _toolCalls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_toolCalls);
  }

  @override
  final String? thinking;

  @override
  String toString() {
    return 'AIResponse(content: $content, inputTokens: $inputTokens, outputTokens: $outputTokens, modelId: $modelId, responseTime: $responseTime, fromCache: $fromCache, requestId: $requestId, metadata: $metadata, toolCalls: $toolCalls, thinking: $thinking)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AIResponseImpl &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.inputTokens, inputTokens) ||
                other.inputTokens == inputTokens) &&
            (identical(other.outputTokens, outputTokens) ||
                other.outputTokens == outputTokens) &&
            (identical(other.modelId, modelId) || other.modelId == modelId) &&
            (identical(other.responseTime, responseTime) ||
                other.responseTime == responseTime) &&
            (identical(other.fromCache, fromCache) ||
                other.fromCache == fromCache) &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            const DeepCollectionEquality().equals(
              other._toolCalls,
              _toolCalls,
            ) &&
            (identical(other.thinking, thinking) ||
                other.thinking == thinking));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    content,
    inputTokens,
    outputTokens,
    modelId,
    responseTime,
    fromCache,
    requestId,
    const DeepCollectionEquality().hash(_metadata),
    const DeepCollectionEquality().hash(_toolCalls),
    thinking,
  );

  /// Create a copy of AIResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AIResponseImplCopyWith<_$AIResponseImpl> get copyWith =>
      __$$AIResponseImplCopyWithImpl<_$AIResponseImpl>(this, _$identity);
}

abstract class _AIResponse implements AIResponse {
  const factory _AIResponse({
    required final String content,
    required final int inputTokens,
    required final int outputTokens,
    required final String modelId,
    required final Duration responseTime,
    required final bool fromCache,
    final String? requestId,
    final Map<String, dynamic>? metadata,
    final List<ToolCall> toolCalls,
    final String? thinking,
  }) = _$AIResponseImpl;

  @override
  String get content;
  @override
  int get inputTokens;
  @override
  int get outputTokens;
  @override
  String get modelId;
  @override
  Duration get responseTime;
  @override
  bool get fromCache;
  @override
  String? get requestId;
  @override
  Map<String, dynamic>? get metadata;
  @override
  List<ToolCall> get toolCalls;
  @override
  String? get thinking;

  /// Create a copy of AIResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AIResponseImplCopyWith<_$AIResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AIRequestConfig {
  AIFunction get function => throw _privateConstructorUsedError;
  String? get systemPrompt => throw _privateConstructorUsedError;
  String get userPrompt => throw _privateConstructorUsedError;
  Map<String, dynamic>? get variables => throw _privateConstructorUsedError;
  ModelTier? get overrideTier => throw _privateConstructorUsedError;
  String? get overrideModelId => throw _privateConstructorUsedError;
  bool get useCache => throw _privateConstructorUsedError;
  bool get stream => throw _privateConstructorUsedError;
  double get temperature => throw _privateConstructorUsedError;
  int? get maxTokens => throw _privateConstructorUsedError;
  void Function(String)? get onStreamChunk =>
      throw _privateConstructorUsedError;

  /// Create a copy of AIRequestConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AIRequestConfigCopyWith<AIRequestConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AIRequestConfigCopyWith<$Res> {
  factory $AIRequestConfigCopyWith(
    AIRequestConfig value,
    $Res Function(AIRequestConfig) then,
  ) = _$AIRequestConfigCopyWithImpl<$Res, AIRequestConfig>;
  @useResult
  $Res call({
    AIFunction function,
    String? systemPrompt,
    String userPrompt,
    Map<String, dynamic>? variables,
    ModelTier? overrideTier,
    String? overrideModelId,
    bool useCache,
    bool stream,
    double temperature,
    int? maxTokens,
    void Function(String)? onStreamChunk,
  });
}

/// @nodoc
class _$AIRequestConfigCopyWithImpl<$Res, $Val extends AIRequestConfig>
    implements $AIRequestConfigCopyWith<$Res> {
  _$AIRequestConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AIRequestConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? function = null,
    Object? systemPrompt = freezed,
    Object? userPrompt = null,
    Object? variables = freezed,
    Object? overrideTier = freezed,
    Object? overrideModelId = freezed,
    Object? useCache = null,
    Object? stream = null,
    Object? temperature = null,
    Object? maxTokens = freezed,
    Object? onStreamChunk = freezed,
  }) {
    return _then(
      _value.copyWith(
            function: null == function
                ? _value.function
                : function // ignore: cast_nullable_to_non_nullable
                      as AIFunction,
            systemPrompt: freezed == systemPrompt
                ? _value.systemPrompt
                : systemPrompt // ignore: cast_nullable_to_non_nullable
                      as String?,
            userPrompt: null == userPrompt
                ? _value.userPrompt
                : userPrompt // ignore: cast_nullable_to_non_nullable
                      as String,
            variables: freezed == variables
                ? _value.variables
                : variables // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            overrideTier: freezed == overrideTier
                ? _value.overrideTier
                : overrideTier // ignore: cast_nullable_to_non_nullable
                      as ModelTier?,
            overrideModelId: freezed == overrideModelId
                ? _value.overrideModelId
                : overrideModelId // ignore: cast_nullable_to_non_nullable
                      as String?,
            useCache: null == useCache
                ? _value.useCache
                : useCache // ignore: cast_nullable_to_non_nullable
                      as bool,
            stream: null == stream
                ? _value.stream
                : stream // ignore: cast_nullable_to_non_nullable
                      as bool,
            temperature: null == temperature
                ? _value.temperature
                : temperature // ignore: cast_nullable_to_non_nullable
                      as double,
            maxTokens: freezed == maxTokens
                ? _value.maxTokens
                : maxTokens // ignore: cast_nullable_to_non_nullable
                      as int?,
            onStreamChunk: freezed == onStreamChunk
                ? _value.onStreamChunk
                : onStreamChunk // ignore: cast_nullable_to_non_nullable
                      as void Function(String)?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AIRequestConfigImplCopyWith<$Res>
    implements $AIRequestConfigCopyWith<$Res> {
  factory _$$AIRequestConfigImplCopyWith(
    _$AIRequestConfigImpl value,
    $Res Function(_$AIRequestConfigImpl) then,
  ) = __$$AIRequestConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    AIFunction function,
    String? systemPrompt,
    String userPrompt,
    Map<String, dynamic>? variables,
    ModelTier? overrideTier,
    String? overrideModelId,
    bool useCache,
    bool stream,
    double temperature,
    int? maxTokens,
    void Function(String)? onStreamChunk,
  });
}

/// @nodoc
class __$$AIRequestConfigImplCopyWithImpl<$Res>
    extends _$AIRequestConfigCopyWithImpl<$Res, _$AIRequestConfigImpl>
    implements _$$AIRequestConfigImplCopyWith<$Res> {
  __$$AIRequestConfigImplCopyWithImpl(
    _$AIRequestConfigImpl _value,
    $Res Function(_$AIRequestConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AIRequestConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? function = null,
    Object? systemPrompt = freezed,
    Object? userPrompt = null,
    Object? variables = freezed,
    Object? overrideTier = freezed,
    Object? overrideModelId = freezed,
    Object? useCache = null,
    Object? stream = null,
    Object? temperature = null,
    Object? maxTokens = freezed,
    Object? onStreamChunk = freezed,
  }) {
    return _then(
      _$AIRequestConfigImpl(
        function: null == function
            ? _value.function
            : function // ignore: cast_nullable_to_non_nullable
                  as AIFunction,
        systemPrompt: freezed == systemPrompt
            ? _value.systemPrompt
            : systemPrompt // ignore: cast_nullable_to_non_nullable
                  as String?,
        userPrompt: null == userPrompt
            ? _value.userPrompt
            : userPrompt // ignore: cast_nullable_to_non_nullable
                  as String,
        variables: freezed == variables
            ? _value._variables
            : variables // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        overrideTier: freezed == overrideTier
            ? _value.overrideTier
            : overrideTier // ignore: cast_nullable_to_non_nullable
                  as ModelTier?,
        overrideModelId: freezed == overrideModelId
            ? _value.overrideModelId
            : overrideModelId // ignore: cast_nullable_to_non_nullable
                  as String?,
        useCache: null == useCache
            ? _value.useCache
            : useCache // ignore: cast_nullable_to_non_nullable
                  as bool,
        stream: null == stream
            ? _value.stream
            : stream // ignore: cast_nullable_to_non_nullable
                  as bool,
        temperature: null == temperature
            ? _value.temperature
            : temperature // ignore: cast_nullable_to_non_nullable
                  as double,
        maxTokens: freezed == maxTokens
            ? _value.maxTokens
            : maxTokens // ignore: cast_nullable_to_non_nullable
                  as int?,
        onStreamChunk: freezed == onStreamChunk
            ? _value.onStreamChunk
            : onStreamChunk // ignore: cast_nullable_to_non_nullable
                  as void Function(String)?,
      ),
    );
  }
}

/// @nodoc

class _$AIRequestConfigImpl implements _AIRequestConfig {
  const _$AIRequestConfigImpl({
    required this.function,
    this.systemPrompt,
    required this.userPrompt,
    final Map<String, dynamic>? variables,
    this.overrideTier,
    this.overrideModelId,
    this.useCache = true,
    this.stream = true,
    this.temperature = 1.0,
    this.maxTokens,
    this.onStreamChunk,
  }) : _variables = variables;

  @override
  final AIFunction function;
  @override
  final String? systemPrompt;
  @override
  final String userPrompt;
  final Map<String, dynamic>? _variables;
  @override
  Map<String, dynamic>? get variables {
    final value = _variables;
    if (value == null) return null;
    if (_variables is EqualUnmodifiableMapView) return _variables;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final ModelTier? overrideTier;
  @override
  final String? overrideModelId;
  @override
  @JsonKey()
  final bool useCache;
  @override
  @JsonKey()
  final bool stream;
  @override
  @JsonKey()
  final double temperature;
  @override
  final int? maxTokens;
  @override
  final void Function(String)? onStreamChunk;

  @override
  String toString() {
    return 'AIRequestConfig(function: $function, systemPrompt: $systemPrompt, userPrompt: $userPrompt, variables: $variables, overrideTier: $overrideTier, overrideModelId: $overrideModelId, useCache: $useCache, stream: $stream, temperature: $temperature, maxTokens: $maxTokens, onStreamChunk: $onStreamChunk)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AIRequestConfigImpl &&
            (identical(other.function, function) ||
                other.function == function) &&
            (identical(other.systemPrompt, systemPrompt) ||
                other.systemPrompt == systemPrompt) &&
            (identical(other.userPrompt, userPrompt) ||
                other.userPrompt == userPrompt) &&
            const DeepCollectionEquality().equals(
              other._variables,
              _variables,
            ) &&
            (identical(other.overrideTier, overrideTier) ||
                other.overrideTier == overrideTier) &&
            (identical(other.overrideModelId, overrideModelId) ||
                other.overrideModelId == overrideModelId) &&
            (identical(other.useCache, useCache) ||
                other.useCache == useCache) &&
            (identical(other.stream, stream) || other.stream == stream) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature) &&
            (identical(other.maxTokens, maxTokens) ||
                other.maxTokens == maxTokens) &&
            (identical(other.onStreamChunk, onStreamChunk) ||
                other.onStreamChunk == onStreamChunk));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    function,
    systemPrompt,
    userPrompt,
    const DeepCollectionEquality().hash(_variables),
    overrideTier,
    overrideModelId,
    useCache,
    stream,
    temperature,
    maxTokens,
    onStreamChunk,
  );

  /// Create a copy of AIRequestConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AIRequestConfigImplCopyWith<_$AIRequestConfigImpl> get copyWith =>
      __$$AIRequestConfigImplCopyWithImpl<_$AIRequestConfigImpl>(
        this,
        _$identity,
      );
}

abstract class _AIRequestConfig implements AIRequestConfig {
  const factory _AIRequestConfig({
    required final AIFunction function,
    final String? systemPrompt,
    required final String userPrompt,
    final Map<String, dynamic>? variables,
    final ModelTier? overrideTier,
    final String? overrideModelId,
    final bool useCache,
    final bool stream,
    final double temperature,
    final int? maxTokens,
    final void Function(String)? onStreamChunk,
  }) = _$AIRequestConfigImpl;

  @override
  AIFunction get function;
  @override
  String? get systemPrompt;
  @override
  String get userPrompt;
  @override
  Map<String, dynamic>? get variables;
  @override
  ModelTier? get overrideTier;
  @override
  String? get overrideModelId;
  @override
  bool get useCache;
  @override
  bool get stream;
  @override
  double get temperature;
  @override
  int? get maxTokens;
  @override
  void Function(String)? get onStreamChunk;

  /// Create a copy of AIRequestConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AIRequestConfigImplCopyWith<_$AIRequestConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
